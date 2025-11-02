import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service untuk menyimpan private key secara aman
/// Menggunakan flutter_secure_storage untuk enkripsi di level OS
///
/// SECURITY NOTE:
/// - Private key TIDAK PERNAH dikirim ke server
/// - Disimpan terenkripsi di device storage
/// - Menggunakan hardware-backed keystore (Android) atau Keychain (iOS)
class StorageService {
  // Instance dari FlutterSecureStorage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const String _privateKeyKey = 'user_private_key';
  static const String _publicKeyKey = 'user_public_key';
  static const String _usernameKey = 'username';
  static const String _mockReceiverPublicKeyKey = 'mock_receiver_public_key';

  // ============================================================================
  // PRIVATE KEY OPERATIONS
  // ============================================================================

  /// Simpan RSA private key ke secure storage
  ///
  /// [privateKeyPEM]: Private key dalam format PEM
  /// [username]: Username untuk identifikasi (opsional, untuk multi-account)
  ///
  /// IMPORTANT: Private key akan dienkripsi oleh OS sebelum disimpan
  Future<void> savePrivateKey(String privateKeyPEM, {String? username}) async {
    try {
      print('[StorageService] Saving private key to secure storage...');

      // Simpan private key
      await _secureStorage.write(key: _privateKeyKey, value: privateKeyPEM);

      // Simpan username jika ada
      if (username != null) {
        await _secureStorage.write(key: _usernameKey, value: username);
      }

      print('[StorageService] ✓ Private key saved successfully');
    } catch (e) {
      print('[StorageService] ERROR saving private key: $e');
      rethrow;
    }
  }

  /// Load RSA private key dari secure storage
  ///
  /// Returns: Private key dalam format PEM, atau null jika tidak ditemukan
  Future<String?> loadPrivateKey() async {
    try {
      print('[StorageService] Loading private key from secure storage...');

      final privateKeyPEM = await _secureStorage.read(key: _privateKeyKey);

      if (privateKeyPEM != null) {
        print('[StorageService] ✓ Private key loaded successfully');
      } else {
        print('[StorageService] ⚠ Private key not found');
      }

      return privateKeyPEM;
    } catch (e) {
      print('[StorageService] ERROR loading private key: $e');
      rethrow;
    }
  }

  /// Hapus RSA private key dari secure storage
  /// Digunakan saat logout atau hapus akun
  Future<void> deletePrivateKey() async {
    try {
      print('[StorageService] Deleting private key from secure storage...');

      await _secureStorage.delete(key: _privateKeyKey);

      print('[StorageService] ✓ Private key deleted successfully');
    } catch (e) {
      print('[StorageService] ERROR deleting private key: $e');
      rethrow;
    }
  }

  /// Cek apakah private key sudah tersimpan
  ///
  /// Returns: true jika private key ada, false jika tidak
  Future<bool> hasPrivateKey() async {
    try {
      final privateKey = await _secureStorage.read(key: _privateKeyKey);
      return privateKey != null;
    } catch (e) {
      print('[StorageService] ERROR checking private key: $e');
      return false;
    }
  }

  // ============================================================================
  // PUBLIC KEY OPERATIONS (Optional - untuk caching)
  // ============================================================================

  /// Simpan RSA public key ke secure storage (opsional, untuk caching)
  ///
  /// [publicKeyPEM]: Public key dalam format PEM
  Future<void> savePublicKey(String publicKeyPEM) async {
    try {
      print('[StorageService] Saving public key to secure storage...');

      await _secureStorage.write(key: _publicKeyKey, value: publicKeyPEM);

      print('[StorageService] ✓ Public key saved successfully');
    } catch (e) {
      print('[StorageService] ERROR saving public key: $e');
      rethrow;
    }
  }

  /// Load RSA public key dari secure storage
  ///
  /// Returns: Public key dalam format PEM, atau null jika tidak ditemukan
  Future<String?> loadPublicKey() async {
    try {
      print('[StorageService] Loading public key from secure storage...');

      final publicKeyPEM = await _secureStorage.read(key: _publicKeyKey);

      if (publicKeyPEM != null) {
        print('[StorageService] ✓ Public key loaded successfully');
      } else {
        print('[StorageService] ⚠ Public key not found');
      }

      return publicKeyPEM;
    } catch (e) {
      print('[StorageService] ERROR loading public key: $e');
      rethrow;
    }
  }

  /// Hapus RSA public key dari secure storage
  Future<void> deletePublicKey() async {
    try {
      print('[StorageService] Deleting public key from secure storage...');

      await _secureStorage.delete(key: _publicKeyKey);

      print('[StorageService] ✓ Public key deleted successfully');
    } catch (e) {
      print('[StorageService] ERROR deleting public key: $e');
      rethrow;
    }
  }

  /// Check apakah public key sudah tersimpan
  Future<bool> hasPublicKey() async {
    final publicKey = await loadPublicKey();
    return publicKey != null;
  }

  // ============================================================================
  // MOCK RECEIVER KEY OPERATIONS (For Demo)
  // ============================================================================

  /// Simpan mock receiver's public key (untuk demo)
  Future<void> saveMockReceiverPublicKey(String publicKeyPEM) async {
    try {
      print('[StorageService] Saving mock receiver public key...');
      await _secureStorage.write(
        key: _mockReceiverPublicKeyKey,
        value: publicKeyPEM,
      );
      print('[StorageService] ✓ Mock receiver public key saved');
    } catch (e) {
      print('[StorageService] ERROR saving mock receiver public key: $e');
      rethrow;
    }
  }

  /// Load mock receiver's public key (untuk demo)
  Future<String?> loadMockReceiverPublicKey() async {
    try {
      print('[StorageService] Loading mock receiver public key...');
      final publicKeyPEM = await _secureStorage.read(
        key: _mockReceiverPublicKeyKey,
      );
      if (publicKeyPEM != null) {
        print('[StorageService] ✓ Mock receiver public key loaded');
      } else {
        print('[StorageService] ⚠ Mock receiver public key not found');
      }
      return publicKeyPEM;
    } catch (e) {
      print('[StorageService] ERROR loading mock receiver public key: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USERNAME OPERATIONS
  // ============================================================================

  /// Simpan username
  Future<void> saveUsername(String username) async {
    try {
      await _secureStorage.write(key: _usernameKey, value: username);
      print('[StorageService] Username saved: $username');
    } catch (e) {
      print('[StorageService] ERROR saving username: $e');
      rethrow;
    }
  }

  /// Load username
  Future<String?> loadUsername() async {
    try {
      return await _secureStorage.read(key: _usernameKey);
    } catch (e) {
      print('[StorageService] ERROR loading username: $e');
      return null;
    }
  }

  /// Hapus username
  Future<void> deleteUsername() async {
    try {
      await _secureStorage.delete(key: _usernameKey);
      print('[StorageService] Username deleted');
    } catch (e) {
      print('[StorageService] ERROR deleting username: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SESSION KEY OPERATIONS (untuk AES session keys)
  // ============================================================================

  /// Simpan AES session key untuk chat tertentu
  ///
  /// [chatId]: ID unik dari chat (misal: "user1_user2")
  /// [sessionKey]: AES session key dalam format Base64
  Future<void> saveSessionKey(String chatId, String sessionKey) async {
    try {
      print('[StorageService] Saving session key for chat: $chatId');

      final key = 'session_key_$chatId';
      await _secureStorage.write(key: key, value: sessionKey);

      print('[StorageService] ✓ Session key saved for chat: $chatId');
    } catch (e) {
      print('[StorageService] ERROR saving session key: $e');
      rethrow;
    }
  }

  /// Load AES session key untuk chat tertentu
  ///
  /// [chatId]: ID unik dari chat
  /// Returns: Session key dalam format Base64, atau null jika tidak ditemukan
  Future<String?> loadSessionKey(String chatId) async {
    try {
      print('[StorageService] Loading session key for chat: $chatId');

      final key = 'session_key_$chatId';
      final sessionKey = await _secureStorage.read(key: key);

      if (sessionKey != null) {
        print('[StorageService] ✓ Session key loaded for chat: $chatId');
      } else {
        print('[StorageService] ⚠ Session key not found for chat: $chatId');
      }

      return sessionKey;
    } catch (e) {
      print('[StorageService] ERROR loading session key: $e');
      rethrow;
    }
  }

  /// Hapus AES session key untuk chat tertentu
  ///
  /// [chatId]: ID unik dari chat
  Future<void> deleteSessionKey(String chatId) async {
    try {
      print('[StorageService] Deleting session key for chat: $chatId');

      final key = 'session_key_$chatId';
      await _secureStorage.delete(key: key);

      print('[StorageService] ✓ Session key deleted for chat: $chatId');
    } catch (e) {
      print('[StorageService] ERROR deleting session key: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITY OPERATIONS
  // ============================================================================

  /// Hapus semua data dari secure storage
  /// Digunakan saat logout atau reset aplikasi
  Future<void> clearAll() async {
    try {
      print('[StorageService] Clearing all data from secure storage...');

      await _secureStorage.deleteAll();

      print('[StorageService] ✓ All data cleared successfully');
    } catch (e) {
      print('[StorageService] ERROR clearing all data: $e');
      rethrow;
    }
  }

  /// Get semua keys yang tersimpan (untuk debugging)
  Future<Map<String, String>> getAllKeys() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      print('[StorageService] ERROR reading all keys: $e');
      return {};
    }
  }

  /// Print semua keys yang tersimpan (untuk debugging)
  Future<void> debugPrintAllKeys() async {
    try {
      final allKeys = await getAllKeys();
      print('[StorageService] === Stored Keys ===');
      allKeys.forEach((key, value) {
        // Jangan print value private key untuk security
        if (key.contains('private') || key.contains('session')) {
          print('  $key: [HIDDEN]');
        } else {
          print(
            '  $key: ${value.substring(0, value.length > 50 ? 50 : value.length)}...',
          );
        }
      });
      print('[StorageService] === End of Keys ===');
    } catch (e) {
      print('[StorageService] ERROR debugging keys: $e');
    }
  }
}
