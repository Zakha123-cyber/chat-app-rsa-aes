import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/services/storage_service.dart';

/// Firebase Authentication Service
/// Handles user registration, login, logout
/// Integrates with existing E2E encryption system
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final StorageService _storageService = StorageService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================================
  // REGISTRATION
  // ============================================================================

  /// Register new user with email, password, and username
  /// Automatically generates RSA-2048 key pair for E2E encryption
  ///
  /// Steps:
  /// 1. Create Firebase Auth user
  /// 2. Generate RSA key pair
  /// 3. Store public key in Firestore
  /// 4. Store private key locally (secure storage)
  /// 5. Create user document in Firestore
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      print('[FirebaseAuth] Registering user: $email');

      // 1. Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }

      print('[FirebaseAuth] User created with UID: ${user.uid}');

      // 2. Generate RSA key pair for encryption
      print('[FirebaseAuth] Generating RSA-2048 key pair...');
      final keyPair = _encryptionService.generateRSAKeyPair();
      final publicKey = keyPair['publicKey']!;
      final privateKey = keyPair['privateKey']!;

      // 3. Store private key locally (NEVER send to server!)
      await _storageService.savePrivateKey(privateKey, username: username);
      await _storageService.savePublicKey(publicKey);
      await _storageService.saveUsername(username);

      print('[FirebaseAuth] Private key stored locally');

      // 4. Create user document in Firestore with public key
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
        'publicKey': publicKey,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      });

      print('[FirebaseAuth] ✓ Registration completed successfully');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[FirebaseAuth] ✗ Registration failed: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('[FirebaseAuth] ✗ Registration error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LOGIN
  // ============================================================================

  /// Login with email and password
  /// Checks if user has RSA keys stored locally
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('[FirebaseAuth] Logging in user: $email');

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed');
      }

      print('[FirebaseAuth] Login successful, UID: ${user.uid}');

      // Verify user has private key stored locally
      final hasPrivateKey = await _storageService.hasPrivateKey();
      if (!hasPrivateKey) {
        print('[FirebaseAuth] ⚠️  Private key not found locally!');
        throw Exception(
          'Private key not found. Please re-register on this device.',
        );
      }

      // Update online status
      await _updateOnlineStatus(user.uid, true);

      print('[FirebaseAuth] ✓ Login completed successfully');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('[FirebaseAuth] ✗ Login failed: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('[FirebaseAuth] ✗ Login error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LOGOUT
  // ============================================================================

  /// Logout current user and update online status
  Future<void> signOut() async {
    try {
      print('[FirebaseAuth] Logging out user...');

      final userId = currentUserId;
      if (userId != null) {
        // Update online status before logging out
        await _updateOnlineStatus(userId, false);
      }

      await _auth.signOut();

      print('[FirebaseAuth] ✓ Logout successful');
    } catch (e) {
      print('[FirebaseAuth] ✗ Logout error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USER STATUS
  // ============================================================================

  /// Update user's online status
  Future<void> _updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      print('[FirebaseAuth] Online status updated: $isOnline');
    } catch (e) {
      print('[FirebaseAuth] Failed to update online status: $e');
    }
  }

  /// Mark user as online (call on app resume)
  Future<void> markOnline() async {
    final userId = currentUserId;
    if (userId != null) {
      await _updateOnlineStatus(userId, true);
    }
  }

  /// Mark user as offline (call on app pause)
  Future<void> markOffline() async {
    final userId = currentUserId;
    if (userId != null) {
      await _updateOnlineStatus(userId, false);
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('[FirebaseAuth] Error fetching user data: $e');
      return null;
    }
  }

  /// Get current user's username
  Future<String?> getCurrentUsername() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final userData = await getUserData(userId);
    return userData?['username'] as String?;
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  /// Delete user account (optional - for future use)
  Future<void> deleteAccount() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('No user logged in');

      // Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete local keys
      await _storageService.clearAll();

      // Delete Firebase Auth user
      await currentUser?.delete();

      print('[FirebaseAuth] ✓ Account deleted successfully');
    } catch (e) {
      print('[FirebaseAuth] ✗ Delete account error: $e');
      rethrow;
    }
  }
}
