import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/services/storage_service.dart';

/// Helper class untuk mempermudah integrasi dengan UI
/// Menyediakan high-level functions untuk chat operations
class ChatEncryptionHelper {
  final EncryptionService _encryptionService = EncryptionService();
  final StorageService _storageService = StorageService();

  // ============================================================================
  // USER REGISTRATION
  // ============================================================================

  /// Complete registration flow
  /// Returns data yang perlu dikirim ke server
  Future<Map<String, String>> registerUser({
    required String username,
    required String password,
  }) async {
    try {
      print(
        '\n╔═══════════════════════════════════════════════════════════════════╗',
      );
      print(
        '║         👤  USER REGISTRATION PROCESS                            ║',
      );
      print(
        '╚═══════════════════════════════════════════════════════════════════╝',
      );
      print('  Username: $username\n');

      // 1. Generate RSA key pair
      print('  [1/3] Generating RSA key pair...');
      final keyPair = _encryptionService.generateRSAKeyPair();
      final publicKey = keyPair['publicKey']!;
      final privateKey = keyPair['privateKey']!;

      // 2. Save private key securely
      print('  [2/3] Saving keys to secure storage...');
      await _storageService.savePrivateKey(privateKey, username: username);
      await _storageService.savePublicKey(publicKey);
      await _storageService.saveUsername(username);
      print('      ✓ Private key saved securely');
      print('      ✓ Public key cached');

      // 3. Hash password
      print('  [3/3] Hashing password with SHA-256...');
      final passwordHash = _encryptionService.hashPassword(password);
      print('      ✓ Password hashed');

      print('\n  ✅ Registration completed successfully');
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );

      // Return data untuk dikirim ke server
      return {
        'username': username,
        'password_hash': passwordHash,
        'public_key': publicKey,
      };
    } catch (e) {
      print('[ChatHelper] ✗ Registration failed: $e');
      rethrow;
    }
  }

  /// Verify user sudah registered (punya private key)
  Future<bool> isUserRegistered() async {
    return await _storageService.hasPrivateKey();
  }

  /// Get username yang tersimpan
  Future<String?> getUsername() async {
    return await _storageService.loadUsername();
  }

  // ============================================================================
  // CHAT SESSION MANAGEMENT
  // ============================================================================

  /// Start new chat session (as initiator)
  /// Returns encrypted session key untuk dikirim ke server
  Future<String> startChatSession({
    required String chatId,
    required String receiverPublicKey,
  }) async {
    try {
      print(
        '\n╔═══════════════════════════════════════════════════════════════════╗',
      );
      print(
        '║         🔐  CHAT SESSION KEY EXCHANGE                            ║',
      );
      print(
        '╚═══════════════════════════════════════════════════════════════════╝',
      );
      print(
        '  Session ID: ${chatId.length > 30 ? chatId.substring(0, 30) + '...' : chatId}\n',
      );

      // 1. Generate AES session key
      print('  [1/3] Generating AES-256 session key...');
      final sessionKey = _encryptionService.generateAESKey();

      // 2. Encrypt session key dengan receiver's public key
      print(
        '  [2/3] Encrypting session key with receiver\'s RSA public key...',
      );
      final encryptedSessionKey = _encryptionService.encryptRSA(
        sessionKey,
        receiverPublicKey,
      );
      print('      ✓ Session key encrypted');

      // 3. Save session key locally
      print('  [3/3] Saving session key to local storage...');
      await _storageService.saveSessionKey(chatId, sessionKey);
      print('      ✓ Session key saved');

      print('\n  ✅ Chat session initialized successfully');
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );

      // Return encrypted session key untuk dikirim ke server
      return encryptedSessionKey;
    } catch (e) {
      print('[ChatHelper] ✗ Failed to start chat session: $e');
      rethrow;
    }
  }

  /// Accept chat session (as receiver)
  /// Decrypt encrypted session key yang diterima dari server
  Future<void> acceptChatSession({
    required String chatId,
    required String encryptedSessionKey,
  }) async {
    try {
      print(
        '\n╔═══════════════════════════════════════════════════════════════════╗',
      );
      print(
        '║         🔓  ACCEPTING CHAT SESSION (Receiver)                    ║',
      );
      print(
        '╚═══════════════════════════════════════════════════════════════════╝',
      );
      print(
        '  Session ID: ${chatId.length > 30 ? chatId.substring(0, 30) + '...' : chatId}\n',
      );

      // 1. Load private key
      print('  [1/3] Loading private key from secure storage...');
      final privateKey = await _storageService.loadPrivateKey();
      if (privateKey == null) {
        throw Exception('Private key not found. Please register first.');
      }
      print('      ✓ Private key loaded');

      // 2. Decrypt session key dengan RSA private key
      print('  [2/3] Decrypting session key with RSA private key...');
      final sessionKey = _encryptionService.decryptRSA(
        encryptedSessionKey,
        privateKey,
      );
      print('      ✓ Session key decrypted');

      // 3. Save session key locally
      print('  [3/3] Saving decrypted session key to local storage...');
      await _storageService.saveSessionKey(chatId, sessionKey);
      print('      ✓ Session key saved');

      print('\n  ✅ Chat session accepted successfully');
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );
    } catch (e) {
      print('[ChatHelper] ✗ Failed to accept chat session: $e');
      rethrow;
    }
  }

  /// Check if chat session exists
  Future<bool> hasSessionKey(String chatId) async {
    final sessionKey = await _storageService.loadSessionKey(chatId);
    return sessionKey != null;
  }

  // ============================================================================
  // SEND MESSAGE
  // ============================================================================

  /// Encrypt and sign message for sending
  /// Returns data yang perlu dikirim ke server
  Future<Map<String, String>> prepareMessageToSend({
    required String chatId,
    required String message,
  }) async {
    try {
      print(
        '\n╔═══════════════════════════════════════════════════════════════════╗',
      );
      print(
        '║         📤  PREPARING MESSAGE TO SEND                            ║',
      );
      print(
        '╚═══════════════════════════════════════════════════════════════════╝',
      );
      print(
        '  Message: "${message.length > 50 ? message.substring(0, 50) + '...' : message}"\n',
      );

      // 1. Load session key
      print('  [1/4] Loading session key from storage...');
      final sessionKey = await _storageService.loadSessionKey(chatId);
      if (sessionKey == null) {
        throw Exception('Session key not found for chat: $chatId');
      }
      print('      ✓ Session key loaded');

      // 2. Load private key untuk signing
      print('  [2/4] Loading private key for signing...');
      final privateKey = await _storageService.loadPrivateKey();
      if (privateKey == null) {
        throw Exception('Private key not found');
      }
      print('      ✓ Private key loaded');

      // 3. Encrypt message
      print('  [3/4] Encrypting message with AES-256-CBC...');
      final encrypted = _encryptionService.encryptAES(message, sessionKey);
      final ciphertext = encrypted['ciphertext']!;
      final iv = encrypted['iv']!;

      // 4. Sign message
      print('  [4/4] Creating digital signature...');
      final signature = _encryptionService.signMessage(message, privateKey);

      print('\n  ✅ Message ready to send');
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );

      // Return data untuk dikirim ke server
      return {'ciphertext': ciphertext, 'iv': iv, 'signature': signature};
    } catch (e) {
      print('[ChatHelper] ✗ Failed to prepare message: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RECEIVE MESSAGE
  // ============================================================================

  /// Decrypt and verify received message
  /// Returns plaintext message jika valid, null jika signature invalid
  Future<DecryptedMessage> processReceivedMessage({
    required String chatId,
    required String ciphertext,
    required String iv,
    required String signature,
    required String senderPublicKey,
  }) async {
    try {
      print(
        '\n╔═══════════════════════════════════════════════════════════════════╗',
      );
      print(
        '║         📥  PROCESSING RECEIVED MESSAGE                          ║',
      );
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );

      // 1. Load session key
      print('  [1/3] Loading session key from storage...');
      final sessionKey = await _storageService.loadSessionKey(chatId);
      if (sessionKey == null) {
        throw Exception('Session key not found for chat: $chatId');
      }
      print('      ✓ Session key loaded');

      // 2. Decrypt message
      print('  [2/3] Decrypting message with AES-256-CBC...');
      final plaintext = _encryptionService.decryptAES(
        ciphertext,
        sessionKey,
        iv,
      );

      // 3. Verify signature
      print('  [3/3] Verifying digital signature...');
      final isSignatureValid = _encryptionService.verifySignature(
        plaintext,
        signature,
        senderPublicKey,
      );
      if (isSignatureValid) {
        print('      ✅ Signature VALID - Message is authentic');
      } else {
        print('      ⚠️  Signature INVALID - Message may be tampered!');
      }

      print('\n  ✅ Message processing completed');
      print(
        '╚═══════════════════════════════════════════════════════════════════╝\n',
      );

      return DecryptedMessage(
        message: plaintext,
        isSignatureValid: isSignatureValid,
      );
    } catch (e) {
      print('[ChatHelper] ✗ Failed to process message: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LOGOUT & CLEANUP
  // ============================================================================

  /// Logout user dan hapus semua data
  Future<void> logout() async {
    try {
      print('[ChatHelper] Logging out...');
      await _storageService.clearAll();
      print('[ChatHelper] ✓ Logout successful');
    } catch (e) {
      print('[ChatHelper] ✗ Logout failed: $e');
      rethrow;
    }
  }

  /// Delete specific chat session
  Future<void> deleteChatSession(String chatId) async {
    try {
      print('[ChatHelper] Deleting chat session: $chatId');
      await _storageService.deleteSessionKey(chatId);
      print('[ChatHelper] ✓ Chat session deleted');
    } catch (e) {
      print('[ChatHelper] ✗ Failed to delete chat session: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Get cached public key
  Future<String?> getCachedPublicKey() async {
    return await _storageService.loadPublicKey();
  }

  /// Debug: Print all stored keys
  Future<void> debugPrintStorage() async {
    await _storageService.debugPrintAllKeys();
  }
}

/// Data class untuk hasil dekripsi pesan
class DecryptedMessage {
  final String message;
  final bool isSignatureValid;

  DecryptedMessage({required this.message, required this.isSignatureValid});

  /// Apakah pesan aman untuk ditampilkan?
  bool get isSafe => isSignatureValid;

  @override
  String toString() {
    return 'DecryptedMessage(message: $message, isValid: $isSignatureValid)';
  }
}
