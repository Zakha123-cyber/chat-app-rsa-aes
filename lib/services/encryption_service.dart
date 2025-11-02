import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import 'package:crypto/crypto.dart';

/// Service untuk menangani semua operasi kriptografi
/// Menggunakan RSA-2048 untuk key exchange dan digital signature
/// Menggunakan AES-256-CBC untuk enkripsi pesan
/// Menggunakan SHA-256 untuk hashing
class EncryptionService {
  // ============================================================================
  // RSA OPERATIONS (2048-bit)
  // ============================================================================

  /// Generate RSA key pair (2048-bit)
  /// Returns: Map dengan 'publicKey' dan 'privateKey' dalam format PEM
  ///
  /// Digunakan saat registrasi user baru
  /// Public key akan dikirim ke server, private key disimpan secara aman
  Map<String, String> generateRSAKeyPair() {
    try {
      print('[EncryptionService] Generating RSA-2048 key pair...');

      // Setup secure random number generator
      final secureRandom = _getSecureRandom();

      // Setup RSA key generator dengan 2048-bit
      final keyGen = RSAKeyGenerator()
        ..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(
              BigInt.parse('65537'), // public exponent (e)
              2048, // key size in bits
              64, // certainty for prime generation
            ),
            secureRandom,
          ),
        );

      // Generate key pair
      final pair = keyGen.generateKeyPair();
      final publicKey = pair.publicKey as RSAPublicKey;
      final privateKey = pair.privateKey as RSAPrivateKey;

      // Convert to PEM format
      final publicKeyPEM = _encodePublicKeyToPEM(publicKey);
      final privateKeyPEM = _encodePrivateKeyToPEM(privateKey);

      print('[EncryptionService] RSA key pair generated successfully');
      print(
        '[EncryptionService] Public key modulus length: ${publicKey.modulus!.bitLength} bits',
      );

      return {'publicKey': publicKeyPEM, 'privateKey': privateKeyPEM};
    } catch (e) {
      print('[EncryptionService] ERROR generating RSA key pair: $e');
      rethrow;
    }
  }

  /// Enkripsi data menggunakan RSA public key
  /// Digunakan untuk mengenkripsi AES session key
  ///
  /// [data]: Data yang akan dienkripsi (misal: AES key)
  /// [publicKeyPEM]: Public key penerima dalam format PEM
  /// Returns: Encrypted data dalam format Base64
  String encryptRSA(String data, String publicKeyPEM) {
    try {
      print('[EncryptionService] Encrypting data with RSA...');

      final publicKey = _parsePublicKeyFromPEM(publicKeyPEM);
      final cipher = OAEPEncoding(RSAEngine())
        ..init(
          true, // true = encryption
          PublicKeyParameter<RSAPublicKey>(publicKey),
        );

      final dataBytes = utf8.encode(data);
      final encrypted = cipher.process(Uint8List.fromList(dataBytes));
      final encryptedBase64 = base64.encode(encrypted);

      print('[EncryptionService] Data encrypted successfully with RSA');
      return encryptedBase64;
    } catch (e) {
      print('[EncryptionService] ERROR encrypting with RSA: $e');
      rethrow;
    }
  }

  /// Dekripsi data menggunakan RSA private key
  /// Digunakan untuk mendekripsi AES session key yang diterima
  ///
  /// [encryptedData]: Data terenkripsi dalam format Base64
  /// [privateKeyPEM]: Private key sendiri dalam format PEM
  /// Returns: Decrypted data (plaintext)
  String decryptRSA(String encryptedData, String privateKeyPEM) {
    try {
      print('[EncryptionService] Decrypting data with RSA...');

      final privateKey = _parsePrivateKeyFromPEM(privateKeyPEM);
      final cipher = OAEPEncoding(RSAEngine())
        ..init(
          false, // false = decryption
          PrivateKeyParameter<RSAPrivateKey>(privateKey),
        );

      final encryptedBytes = base64.decode(encryptedData);
      final decrypted = cipher.process(encryptedBytes);
      final decryptedString = utf8.decode(decrypted);

      print('[EncryptionService] Data decrypted successfully with RSA');
      return decryptedString;
    } catch (e) {
      print('[EncryptionService] ERROR decrypting with RSA: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AES OPERATIONS (256-bit CBC mode)
  // ============================================================================

  /// Generate random AES-256 key untuk session
  /// Returns: AES key dalam format Base64 (32 bytes = 256 bits)
  ///
  /// Key ini akan dienkripsi dengan RSA public key penerima
  /// dan digunakan untuk enkripsi semua pesan dalam session tersebut
  String generateAESKey() {
    try {
      print('[EncryptionService] Generating AES-256 session key...');

      final secureRandom = _getSecureRandom();
      final keyBytes = secureRandom.nextBytes(32); // 32 bytes = 256 bits
      final keyBase64 = base64.encode(keyBytes);

      print('[EncryptionService] AES-256 key generated successfully');
      return keyBase64;
    } catch (e) {
      print('[EncryptionService] ERROR generating AES key: $e');
      rethrow;
    }
  }

  /// Enkripsi plaintext menggunakan AES-256-CBC
  /// Generate IV baru setiap kali enkripsi (untuk security)
  ///
  /// [plaintext]: Pesan yang akan dienkripsi
  /// [aesKeyBase64]: AES session key dalam format Base64
  /// Returns: Map dengan 'ciphertext' dan 'iv' (keduanya Base64)
  Map<String, String> encryptAES(String plaintext, String aesKeyBase64) {
    try {
      print('[EncryptionService] Encrypting message with AES-256-CBC...');

      // Decode AES key dari Base64
      final key = base64.decode(aesKeyBase64);

      // Generate random IV (16 bytes untuk AES)
      final secureRandom = _getSecureRandom();
      final iv = secureRandom.nextBytes(16);

      // Setup AES cipher dalam mode CBC dengan PKCS7 padding
      final cipher =
          PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              true, // true = encryption
              PaddedBlockCipherParameters(
                ParametersWithIV(KeyParameter(key), iv),
                null,
              ),
            );

      // Enkripsi plaintext
      final plaintextBytes = utf8.encode(plaintext);
      final ciphertext = cipher.process(Uint8List.fromList(plaintextBytes));

      // Encode ke Base64
      final ciphertextBase64 = base64.encode(ciphertext);
      final ivBase64 = base64.encode(iv);

      print(
        '[EncryptionService] Message encrypted successfully with AES-256-CBC',
      );
      print('[EncryptionService] Plaintext length: ${plaintext.length} chars');
      print(
        '[EncryptionService] Ciphertext length: ${ciphertext.length} bytes',
      );

      return {'ciphertext': ciphertextBase64, 'iv': ivBase64};
    } catch (e) {
      print('[EncryptionService] ERROR encrypting with AES: $e');
      rethrow;
    }
  }

  /// Dekripsi ciphertext menggunakan AES-256-CBC
  ///
  /// [ciphertextBase64]: Ciphertext dalam format Base64
  /// [aesKeyBase64]: AES session key dalam format Base64
  /// [ivBase64]: IV yang digunakan saat enkripsi, dalam format Base64
  /// Returns: Plaintext (pesan asli)
  String decryptAES(
    String ciphertextBase64,
    String aesKeyBase64,
    String ivBase64,
  ) {
    try {
      print('[EncryptionService] Decrypting message with AES-256-CBC...');

      // Decode dari Base64
      final key = base64.decode(aesKeyBase64);
      final iv = base64.decode(ivBase64);
      final ciphertext = base64.decode(ciphertextBase64);

      // Setup AES cipher dalam mode CBC dengan PKCS7 padding
      final cipher =
          PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              false, // false = decryption
              PaddedBlockCipherParameters(
                ParametersWithIV(KeyParameter(key), iv),
                null,
              ),
            );

      // Dekripsi ciphertext
      final decrypted = cipher.process(ciphertext);
      final plaintext = utf8.decode(decrypted);

      print(
        '[EncryptionService] Message decrypted successfully with AES-256-CBC',
      );
      print(
        '[EncryptionService] Decrypted message length: ${plaintext.length} chars',
      );

      return plaintext;
    } catch (e) {
      print('[EncryptionService] ERROR decrypting with AES: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DIGITAL SIGNATURE (RSA with SHA-256)
  // ============================================================================

  /// Sign pesan dengan private key untuk memastikan authenticity & integrity
  ///
  /// [message]: Pesan yang akan di-sign (plaintext)
  /// [privateKeyPEM]: Private key pengirim dalam format PEM
  /// Returns: Digital signature dalam format Base64
  String signMessage(String message, String privateKeyPEM) {
    try {
      print('[EncryptionService] Signing message with RSA private key...');

      // Hash message dengan SHA-256
      final messageBytes = utf8.encode(message);
      final digest = SHA256Digest();
      final hash = digest.process(Uint8List.fromList(messageBytes));

      print('[EncryptionService] Message hashed with SHA-256');

      // Sign hash dengan RSA private key
      final privateKey = _parsePrivateKeyFromPEM(privateKeyPEM);
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final signature = signer.generateSignature(hash);
      final signatureBase64 = base64.encode(signature.bytes);

      print('[EncryptionService] Message signed successfully');
      return signatureBase64;
    } catch (e) {
      print('[EncryptionService] ERROR signing message: $e');
      rethrow;
    }
  }

  /// Verify signature dengan public key pengirim
  ///
  /// [message]: Pesan yang telah didekripsi (plaintext)
  /// [signatureBase64]: Digital signature dalam format Base64
  /// [publicKeyPEM]: Public key pengirim dalam format PEM
  /// Returns: true jika signature valid, false jika tidak
  bool verifySignature(
    String message,
    String signatureBase64,
    String publicKeyPEM,
  ) {
    try {
      print('[EncryptionService] Verifying message signature...');

      // Hash message dengan SHA-256
      final messageBytes = utf8.encode(message);
      final digest = SHA256Digest();
      final hash = digest.process(Uint8List.fromList(messageBytes));

      print('[EncryptionService] Message hashed with SHA-256');

      // Verify signature dengan RSA public key
      final publicKey = _parsePublicKeyFromPEM(publicKeyPEM);
      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      final signatureBytes = base64.decode(signatureBase64);
      final signature = RSASignature(signatureBytes);

      final isValid = signer.verifySignature(hash, signature);

      if (isValid) {
        print(
          '[EncryptionService] ✓ Signature is VALID - Message is authentic',
        );
      } else {
        print(
          '[EncryptionService] ✗ Signature is INVALID - Message may be tampered!',
        );
      }

      return isValid;
    } catch (e) {
      print('[EncryptionService] ERROR verifying signature: $e');
      return false;
    }
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  /// Hash password dengan SHA-256 sebelum dikirim ke server
  ///
  /// [password]: Password plaintext
  /// Returns: Hash dalam format hexadecimal
  String hashPassword(String password) {
    try {
      print('[EncryptionService] Hashing password with SHA-256...');

      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      final hash = digest.toString();

      print('[EncryptionService] Password hashed successfully');
      return hash;
    } catch (e) {
      print('[EncryptionService] ERROR hashing password: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE HELPER FUNCTIONS
  // ============================================================================

  /// Generate secure random number generator
  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Encode RSA public key ke format PEM
  String _encodePublicKeyToPEM(RSAPublicKey publicKey) {
    final publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(ASN1Integer(publicKey.exponent!));

    final dataBase64 = base64.encode(publicKeySeq.encode());
    return '-----BEGIN RSA PUBLIC KEY-----\n${_formatPEM(dataBase64)}\n-----END RSA PUBLIC KEY-----';
  }

  /// Encode RSA private key ke format PEM
  String _encodePrivateKeyToPEM(RSAPrivateKey privateKey) {
    final topLevelSeq = ASN1Sequence();
    topLevelSeq.add(ASN1Integer(BigInt.from(0)));
    topLevelSeq.add(ASN1Integer(privateKey.modulus!));
    topLevelSeq.add(ASN1Integer(privateKey.exponent!));
    topLevelSeq.add(ASN1Integer(privateKey.d!));
    topLevelSeq.add(ASN1Integer(privateKey.p!));
    topLevelSeq.add(ASN1Integer(privateKey.q!));
    topLevelSeq.add(ASN1Integer(privateKey.d! % (privateKey.p! - BigInt.one)));
    topLevelSeq.add(ASN1Integer(privateKey.d! % (privateKey.q! - BigInt.one)));
    topLevelSeq.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

    final dataBase64 = base64.encode(topLevelSeq.encode());

    return '-----BEGIN RSA PRIVATE KEY-----\n${_formatPEM(dataBase64)}\n-----END RSA PRIVATE KEY-----';
  }

  /// Parse RSA public key dari format PEM
  RSAPublicKey _parsePublicKeyFromPEM(String pem) {
    final lines = pem
        .split('\n')
        .where(
          (line) =>
              !line.startsWith('-----BEGIN') && !line.startsWith('-----END'),
        )
        .join('');

    final bytes = base64.decode(lines);
    final asn1Parser = ASN1Parser(bytes);
    final publicKeySeq = asn1Parser.nextObject() as ASN1Sequence;
    final modulus = (publicKeySeq.elements![0] as ASN1Integer).integer;
    final exponent = (publicKeySeq.elements![1] as ASN1Integer).integer;

    return RSAPublicKey(modulus!, exponent!);
  }

  /// Parse RSA private key dari format PEM
  RSAPrivateKey _parsePrivateKeyFromPEM(String pem) {
    final lines = pem
        .split('\n')
        .where(
          (line) =>
              !line.startsWith('-----BEGIN') && !line.startsWith('-----END'),
        )
        .join('');

    final bytes = base64.decode(lines);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    final modulus = (topLevelSeq.elements![1] as ASN1Integer).integer;
    final exponent = (topLevelSeq.elements![2] as ASN1Integer).integer;
    // final d = (topLevelSeq.elements![3] as ASN1Integer).integer; // Not used for decryption
    final p = (topLevelSeq.elements![4] as ASN1Integer).integer;
    final q = (topLevelSeq.elements![5] as ASN1Integer).integer;

    return RSAPrivateKey(modulus!, exponent!, p!, q!);
  }

  /// Format Base64 string untuk PEM (64 karakter per baris)
  String _formatPEM(String base64String) {
    final chunks = <String>[];
    for (var i = 0; i < base64String.length; i += 64) {
      final end = (i + 64 < base64String.length) ? i + 64 : base64String.length;
      chunks.add(base64String.substring(i, end));
    }
    return chunks.join('\n');
  }
}
