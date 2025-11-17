import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/services/firebase_auth_service.dart';

/// Firebase Database Service
/// Handles Firestore operations for:
/// - User profiles
/// - Chat sessions (key exchange)
/// - Encrypted messages
class FirebaseDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _messagesCollection =>
      _firestore.collection('messages');
  CollectionReference get _chatSessionsCollection =>
      _firestore.collection('chatSessions');

  // ============================================================================
  // USER OPERATIONS
  // ============================================================================

  /// Get all users except current user (for contacts list)
  Stream<QuerySnapshot> getAllUsers() {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Simple query without multiple orderBy to avoid index requirement
    return _usersCollection
        .where('uid', isNotEqualTo: currentUserId)
        .orderBy('uid')
        .snapshots();
  }

  /// Get user by ID
  Future<DocumentSnapshot> getUserById(String userId) {
    return _usersCollection.doc(userId).get();
  }

  /// Get user's public key
  Future<String?> getUserPublicKey(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['publicKey'] as String?;
    } catch (e) {
      print('[FirebaseDB] Error getting public key: $e');
      return null;
    }
  }

  /// Search users by username
  Stream<QuerySnapshot> searchUsersByUsername(String query) {
    return _usersCollection
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots();
  }

  // ============================================================================
  // CHAT SESSION OPERATIONS (Key Exchange)
  // ============================================================================

  /// Create or get chat session between two users
  /// Stores the encrypted AES session key
  Future<String> createChatSession({
    required String receiverId,
    required String encryptedSessionKey,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Create session ID (sorted user IDs for consistency)
      final sessionId = generateSessionId(currentUserId, receiverId);

      print('[FirebaseDB] Creating chat session: $sessionId');

      // Check if session already exists
      final sessionDoc = await _chatSessionsCollection.doc(sessionId).get();

      if (!sessionDoc.exists) {
        // Create new session
        await _chatSessionsCollection.doc(sessionId).set({
          'sessionId': sessionId,
          'participants': [currentUserId, receiverId],
          'encryptedSessionKey': encryptedSessionKey,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
        });

        print('[FirebaseDB] ✓ Chat session created');
      } else {
        print('[FirebaseDB] Chat session already exists');
      }

      return sessionId;
    } catch (e) {
      print('[FirebaseDB] ✗ Error creating chat session: $e');
      rethrow;
    }
  }

  /// Get chat session by session ID
  Future<DocumentSnapshot> getChatSession(String sessionId) {
    return _chatSessionsCollection.doc(sessionId).get();
  }

  /// Get encrypted session key from Firestore
  Future<String?> getEncryptedSessionKey(String sessionId) async {
    try {
      final doc = await _chatSessionsCollection.doc(sessionId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['encryptedSessionKey'] as String?;
    } catch (e) {
      print('[FirebaseDB] Error getting session key: $e');
      return null;
    }
  }

  /// Generate consistent session ID from two user IDs (PUBLIC method)
  String generateSessionId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Send encrypted message to Firestore
  Future<void> sendMessage({
    required String receiverId,
    required String sessionId,
    required String ciphertext,
    required String iv,
    required String signature,
  }) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('[FirebaseDB] Sending message...');

      // Add message to Firestore
      await _messagesCollection.add({
        'sessionId': sessionId,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'ciphertext': ciphertext,
        'iv': iv,
        'signature': signature,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': false,
      });

      // Update chat session's last message time
      await _chatSessionsCollection.doc(sessionId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for receiver
      await _incrementUnreadCount(receiverId, currentUserId, sessionId);

      print('[FirebaseDB] ✓ Message sent successfully');
    } catch (e) {
      print('[FirebaseDB] ✗ Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages for a chat session (real-time)
  Stream<QuerySnapshot> getMessages(String sessionId) {
    // Use simple query to avoid composite index requirement
    // We'll sort in the UI instead
    return _messagesCollection
        .where('sessionId', isEqualTo: sessionId)
        .snapshots();
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[FirebaseDB] Error marking message as read: $e');
    }
  }

  /// Mark message as delivered
  Future<void> markMessageAsDelivered(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).update({
        'isDelivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[FirebaseDB] Error marking message as delivered: $e');
    }
  }

  /// Get unread message count for a session
  Future<int> getUnreadMessageCount(String sessionId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return 0;

      final snapshot = await _messagesCollection
          .where('sessionId', isEqualTo: sessionId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('[FirebaseDB] Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete message (optional)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).delete();
      print('[FirebaseDB] Message deleted');
    } catch (e) {
      print('[FirebaseDB] Error deleting message: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CHAT LIST OPERATIONS
  // ============================================================================

  /// Get all chat sessions for current user
  Stream<QuerySnapshot> getUserChatSessions() {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _chatSessionsCollection
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  /// Get last message in a chat session
  Future<DocumentSnapshot?> getLastMessage(String sessionId) async {
    try {
      final snapshot = await _messagesCollection
          .where('sessionId', isEqualTo: sessionId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first;
    } catch (e) {
      print('[FirebaseDB] Error getting last message: $e');
      return null;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Clear all messages in a chat session (for testing)
  Future<void> clearChatSession(String sessionId) async {
    try {
      final snapshot = await _messagesCollection
          .where('sessionId', isEqualTo: sessionId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('[FirebaseDB] Chat session cleared');
    } catch (e) {
      print('[FirebaseDB] Error clearing chat session: $e');
      rethrow;
    }
  }

  /// Batch delete old messages (optional - for cleanup)
  Future<void> deleteOldMessages(Duration olderThan) async {
    try {
      final cutoffTime = Timestamp.fromDate(DateTime.now().subtract(olderThan));

      final snapshot = await _messagesCollection
          .where('timestamp', isLessThan: cutoffTime)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('[FirebaseDB] Deleted ${snapshot.docs.length} old messages');
    } catch (e) {
      print('[FirebaseDB] Error deleting old messages: $e');
    }
  }

  // ============================================================================
  // UNREAD COUNT OPERATIONS (for notification badges)
  // ============================================================================

  /// Increment unread count for receiver
  Future<void> _incrementUnreadCount(
    String receiverId,
    String senderId,
    String sessionId,
  ) async {
    try {
      // Get or create unreadCounts document for receiver
      final unreadDoc = _usersCollection
          .doc(receiverId)
          .collection('unreadCounts')
          .doc(senderId);

      await unreadDoc.set({
        'count': FieldValue.increment(1),
        'sessionId': sessionId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('[FirebaseDB] ✓ Unread count incremented for $receiverId');
    } catch (e) {
      print('[FirebaseDB] Error incrementing unread count: $e');
    }
  }

  /// Get unread count from a specific user
  Future<int> getUnreadCount(String fromUserId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return 0;

      final doc = await _usersCollection
          .doc(currentUserId)
          .collection('unreadCounts')
          .doc(fromUserId)
          .get();

      if (!doc.exists) return 0;

      final data = doc.data() as Map<String, dynamic>?;
      return (data?['count'] as int?) ?? 0;
    } catch (e) {
      print('[FirebaseDB] Error getting unread count: $e');
      return 0;
    }
  }

  /// Get stream of unread count from a specific user (real-time)
  Stream<int> getUnreadCountStream(String fromUserId) {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _usersCollection
        .doc(currentUserId)
        .collection('unreadCounts')
        .doc(fromUserId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0;
          final data = doc.data() as Map<String, dynamic>?;
          return (data?['count'] as int?) ?? 0;
        });
  }

  /// Reset unread count when user opens chat
  Future<void> resetUnreadCount(String fromUserId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return;

      await _usersCollection
          .doc(currentUserId)
          .collection('unreadCounts')
          .doc(fromUserId)
          .delete();

      print('[FirebaseDB] ✓ Unread count reset for messages from $fromUserId');
    } catch (e) {
      print('[FirebaseDB] Error resetting unread count: $e');
    }
  }

  /// Mark all messages in a session as read
  Future<void> markAllMessagesAsRead(String sessionId) async {
    try {
      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) return;

      // Get all unread messages where current user is receiver
      final snapshot = await _messagesCollection
          .where('sessionId', isEqualTo: sessionId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('[FirebaseDB] ✓ Marked ${snapshot.docs.length} messages as read');
    } catch (e) {
      print('[FirebaseDB] Error marking messages as read: $e');
    }
  }
}
