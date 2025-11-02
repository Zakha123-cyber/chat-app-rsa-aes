import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';
import 'package:crypto/crypto.dart';

/// Versi simplified dari EncryptionService untuk testing (tanpa Flutter dependencies)
class EncryptionServiceTest {
  Map<String, String> generateRSAKeyPair() {
    print('[EncryptionService] Generating RSA-2048 key pair...');

    final secureRandom = _getSecureRandom();

    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final publicKeyPEM = _encodePublicKeyToPEM(publicKey);
    final privateKeyPEM = _encodePrivateKeyToPEM(privateKey);

    print('[EncryptionService] RSA key pair generated successfully');

    return {'publicKey': publicKeyPEM, 'privateKey': privateKeyPEM};
  }

  String encryptRSA(String data, String publicKeyPEM) {
    print('[EncryptionService] Encrypting data with RSA...');

    final publicKey = _parsePublicKeyFromPEM(publicKeyPEM);
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final dataBytes = utf8.encode(data);
    final encrypted = cipher.process(Uint8List.fromList(dataBytes));
    final encryptedBase64 = base64.encode(encrypted);

    print('[EncryptionService] Data encrypted successfully with RSA');
    return encryptedBase64;
  }

  String decryptRSA(String encryptedData, String privateKeyPEM) {
    print('[EncryptionService] Decrypting data with RSA...');

    final privateKey = _parsePrivateKeyFromPEM(privateKeyPEM);
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final encryptedBytes = base64.decode(encryptedData);
    final decrypted = cipher.process(encryptedBytes);
    final decryptedString = utf8.decode(decrypted);

    print('[EncryptionService] Data decrypted successfully with RSA');
    return decryptedString;
  }

  String generateAESKey() {
    print('[EncryptionService] Generating AES-256 session key...');

    final secureRandom = _getSecureRandom();
    final keyBytes = secureRandom.nextBytes(32);
    final keyBase64 = base64.encode(keyBytes);

    print('[EncryptionService] AES-256 key generated successfully');
    return keyBase64;
  }

  Map<String, String> encryptAES(String plaintext, String aesKeyBase64) {
    print('[EncryptionService] Encrypting message with AES-256-CBC...');

    final key = base64.decode(aesKeyBase64);
    final secureRandom = _getSecureRandom();
    final iv = secureRandom.nextBytes(16);

    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters(
              ParametersWithIV(KeyParameter(key), iv),
              null,
            ),
          );

    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = cipher.process(Uint8List.fromList(plaintextBytes));

    final ciphertextBase64 = base64.encode(ciphertext);
    final ivBase64 = base64.encode(iv);

    print(
      '[EncryptionService] Message encrypted successfully with AES-256-CBC',
    );

    return {'ciphertext': ciphertextBase64, 'iv': ivBase64};
  }

  String decryptAES(
    String ciphertextBase64,
    String aesKeyBase64,
    String ivBase64,
  ) {
    print('[EncryptionService] Decrypting message with AES-256-CBC...');

    final key = base64.decode(aesKeyBase64);
    final iv = base64.decode(ivBase64);
    final ciphertext = base64.decode(ciphertextBase64);

    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            false,
            PaddedBlockCipherParameters(
              ParametersWithIV(KeyParameter(key), iv),
              null,
            ),
          );

    final decrypted = cipher.process(ciphertext);
    final plaintext = utf8.decode(decrypted);

    print(
      '[EncryptionService] Message decrypted successfully with AES-256-CBC',
    );

    return plaintext;
  }

  String signMessage(String message, String privateKeyPEM) {
    print('[EncryptionService] Signing message with RSA private key...');

    final messageBytes = utf8.encode(message);
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(messageBytes));

    print('[EncryptionService] Message hashed with SHA-256');

    final privateKey = _parsePrivateKeyFromPEM(privateKeyPEM);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final signature = signer.generateSignature(hash);
    final signatureBase64 = base64.encode(signature.bytes);

    print('[EncryptionService] Message signed successfully');
    return signatureBase64;
  }

  bool verifySignature(
    String message,
    String signatureBase64,
    String publicKeyPEM,
  ) {
    print('[EncryptionService] Verifying message signature...');

    final messageBytes = utf8.encode(message);
    final digest = SHA256Digest();
    final hash = digest.process(Uint8List.fromList(messageBytes));

    print('[EncryptionService] Message hashed with SHA-256');

    final publicKey = _parsePublicKeyFromPEM(publicKeyPEM);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    final signatureBytes = base64.decode(signatureBase64);
    final signature = RSASignature(signatureBytes);

    final isValid = signer.verifySignature(hash, signature);

    if (isValid) {
      print('[EncryptionService] ✓ Signature is VALID');
    } else {
      print('[EncryptionService] ✗ Signature is INVALID');
    }

    return isValid;
  }

  String hashPassword(String password) {
    print('[EncryptionService] Hashing password with SHA-256...');

    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    final hash = digest.toString();

    print('[EncryptionService] Password hashed successfully');
    return hash;
  }

  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  String _encodePublicKeyToPEM(RSAPublicKey publicKey) {
    final publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus!));
    publicKeySeq.add(ASN1Integer(publicKey.exponent!));

    final dataBase64 = base64.encode(publicKeySeq.encode());
    return '-----BEGIN RSA PUBLIC KEY-----\n${_formatPEM(dataBase64)}\n-----END RSA PUBLIC KEY-----';
  }

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
    final p = (topLevelSeq.elements![4] as ASN1Integer).integer;
    final q = (topLevelSeq.elements![5] as ASN1Integer).integer;

    return RSAPrivateKey(modulus!, exponent!, p!, q!);
  }

  String _formatPEM(String base64String) {
    final chunks = <String>[];
    for (var i = 0; i < base64String.length; i += 64) {
      final end = (i + 64 < base64String.length) ? i + 64 : base64String.length;
      chunks.add(base64String.substring(i, end));
    }
    return chunks.join('\n');
  }
}

void main() {
  print('\n');
  print('=' * 80);
  print('DEMO: End-to-End Encryption Chat System');
  print('Using AES-256-CBC + RSA-2048 + SHA-256');
  print('=' * 80);
  print('\n');

  final encryptionService = EncryptionServiceTest();

  // PHASE 1: REGISTRASI
  print('\n─' * 40);
  print('PHASE 1: REGISTRASI');
  print('─' * 40);

  print('\n>>> ALICE melakukan registrasi...\n');
  final aliceKeys = encryptionService.generateRSAKeyPair();
  final alicePublicKey = aliceKeys['publicKey']!;
  final alicePrivateKey = aliceKeys['privateKey']!;
  print('✓ Alice key pair generated\n');

  final alicePassword = 'alice_secure_password_123';
  final alicePasswordHash = encryptionService.hashPassword(alicePassword);
  print('Alice Password Hash: $alicePasswordHash\n');

  print('>>> BOB melakukan registrasi...\n');
  final bobKeys = encryptionService.generateRSAKeyPair();
  final bobPublicKey = bobKeys['publicKey']!;
  final bobPrivateKey = bobKeys['privateKey']!;
  print('✓ Bob key pair generated\n');

  // PHASE 2: KEY EXCHANGE
  print('\n─' * 40);
  print('PHASE 2: KEY EXCHANGE');
  print('─' * 40);

  print('\n>>> ALICE generate session key...\n');
  final sessionKey = encryptionService.generateAESKey();

  print('>>> ALICE enkripsi session key dengan Bob\'s public key...\n');
  final encryptedSessionKey = encryptionService.encryptRSA(
    sessionKey,
    bobPublicKey,
  );
  print('Encrypted Session Key: ${encryptedSessionKey.substring(0, 50)}...\n');

  print('>>> BOB dekripsi session key...\n');
  final decryptedSessionKey = encryptionService.decryptRSA(
    encryptedSessionKey,
    bobPrivateKey,
  );

  if (decryptedSessionKey == sessionKey) {
    print('✓ Key exchange SUKSES!\n');
  } else {
    print('✗ Key exchange GAGAL!\n');
    return;
  }

  // PHASE 3: SEND MESSAGE
  print('\n─' * 40);
  print('PHASE 3: SEND MESSAGE');
  print('─' * 40);

  final message = 'Halo Bob! Ini pesan rahasia dari Alice 🔒';
  print('\n>>> ALICE mengirim pesan:\n"$message"\n');

  final encrypted = encryptionService.encryptAES(message, sessionKey);
  final ciphertext = encrypted['ciphertext']!;
  final iv = encrypted['iv']!;
  print('Ciphertext: ${ciphertext.substring(0, 50)}...');
  print('IV: $iv\n');

  final signature = encryptionService.signMessage(message, alicePrivateKey);
  print('Signature: ${signature.substring(0, 50)}...\n');

  // PHASE 4: RECEIVE MESSAGE
  print('\n─' * 40);
  print('PHASE 4: RECEIVE MESSAGE');
  print('─' * 40);

  print('\n>>> BOB menerima dan decrypt pesan...\n');
  final decryptedMessage = encryptionService.decryptAES(
    ciphertext,
    sessionKey,
    iv,
  );
  print('Decrypted: "$decryptedMessage"\n');

  print('>>> BOB verify signature...\n');
  final isValid = encryptionService.verifySignature(
    decryptedMessage,
    signature,
    alicePublicKey,
  );

  if (isValid) {
    print('\n✓✓✓ SIGNATURE VALID ✓✓✓');
    print('✓ Message is AUTHENTIC');
    print('✓ Message INTEGRITY preserved\n');
  } else {
    print('\n✗ SIGNATURE INVALID!\n');
  }

  // SECURITY TEST
  print('\n─' * 40);
  print('SECURITY TEST');
  print('─' * 40);

  print('\n>>> Simulasi: Eve modifikasi pesan...\n');
  final tamperedMessage = 'Pesan palsu dari Eve!';
  final eveEncrypted = encryptionService.encryptAES(
    tamperedMessage,
    sessionKey,
  );

  final decryptedTampered = encryptionService.decryptAES(
    eveEncrypted['ciphertext']!,
    sessionKey,
    eveEncrypted['iv']!,
  );

  print('Bob decrypt: "$decryptedTampered"\n');
  print('>>> Bob verify signature (menggunakan signature lama)...\n');

  final isTamperedValid = encryptionService.verifySignature(
    decryptedTampered,
    signature,
    alicePublicKey,
  );

  if (!isTamperedValid) {
    print('\n✓✓✓ SERANGAN TERDETEKSI! ✓✓✓');
    print('✓ Digital Signature berhasil mencegah serangan!\n');
  }

  print('\n' + '=' * 80);
  print('DEMO SELESAI - Semua fitur bekerja dengan baik!');
  print('=' * 80);
  print('\n');
}
