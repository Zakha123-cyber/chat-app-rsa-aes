import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/services/storage_service.dart';

/// DEMO LENGKAP: End-to-End Encryption Chat System
///
/// Flow yang didemonstrasikan:
/// 1. REGISTRASI: Generate RSA key pair
/// 2. KEY EXCHANGE: Enkripsi AES session key dengan RSA
/// 3. SEND MESSAGE: Enkripsi pesan dengan AES + Digital Signature
/// 4. RECEIVE MESSAGE: Dekripsi pesan + Verifikasi Signature
///
/// Simulasi 2 user: Alice dan Bob
Future<void> runEncryptionDemo() async {
  print('\n');
  print('=' * 80);
  print('DEMO: End-to-End Encryption Chat System');
  print('Using AES-256-CBC + RSA-2048 + SHA-256');
  print('=' * 80);
  print('\n');

  final encryptionService = EncryptionService();
  final storageService = StorageService();

  // ============================================================================
  // PHASE 1: REGISTRASI
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('PHASE 1: REGISTRASI USER');
  print('─' * 80);
  print('\n');

  // Simulasi: Alice melakukan registrasi
  print('>>> ALICE melakukan registrasi...\n');

  // Generate RSA key pair untuk Alice
  final aliceKeys = encryptionService.generateRSAKeyPair();
  final alicePublicKey = aliceKeys['publicKey']!;
  final alicePrivateKey = aliceKeys['privateKey']!;

  print('Alice Public Key (akan dikirim ke server):');
  print(alicePublicKey.substring(0, 100) + '...\n');

  // Simpan private key Alice di secure storage
  await storageService.savePrivateKey(alicePrivateKey, username: 'alice');
  await storageService.savePublicKey(alicePublicKey);
  await storageService.saveUsername('alice');

  // Hash password Alice sebelum dikirim ke server
  final alicePassword = 'alice_secure_password_123';
  final alicePasswordHash = encryptionService.hashPassword(alicePassword);
  print('Alice Password Hash (akan dikirim ke server):');
  print('$alicePasswordHash\n');

  print('✓ Alice berhasil registrasi!\n');
  print('Data yang dikirim ke server:');
  print('  - Username: alice');
  print('  - Password Hash: $alicePasswordHash');
  print('  - Public Key: [akan disimpan di server]');
  print('\nData yang disimpan di device Alice:');
  print('  - Private Key: [tersimpan aman di secure storage]');
  print('  - Public Key: [cached di secure storage]\n');

  // Simulasi: Bob melakukan registrasi
  print('\n>>> BOB melakukan registrasi...\n');

  final bobKeys = encryptionService.generateRSAKeyPair();
  final bobPublicKey = bobKeys['publicKey']!;
  final bobPrivateKey = bobKeys['privateKey']!;

  print('Bob Public Key (akan dikirim ke server):');
  print(bobPublicKey.substring(0, 100) + '...\n');

  final bobPassword = 'bob_secure_password_456';
  final bobPasswordHash = encryptionService.hashPassword(bobPassword);
  print('Bob Password Hash (akan dikirim ke server):');
  print('$bobPasswordHash\n');

  print('✓ Bob berhasil registrasi!\n');

  // ============================================================================
  // PHASE 2: KEY EXCHANGE (Memulai Chat Session)
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('PHASE 2: KEY EXCHANGE');
  print('─' * 80);
  print('\n');

  print('>>> ALICE ingin memulai chat dengan BOB...\n');

  // Alice generate AES session key
  final sessionKey = encryptionService.generateAESKey();
  print('Alice generate AES-256 session key:');
  print('$sessionKey\n');

  // Alice request public key Bob dari server (simulasi)
  print('Alice request public key Bob dari server...');
  final bobPublicKeyFromServer = bobPublicKey; // Simulasi dapat dari server
  print('✓ Public key Bob diterima\n');

  // Alice enkripsi session key dengan public key Bob
  print('Alice enkripsi session key dengan RSA public key Bob...');
  final encryptedSessionKey = encryptionService.encryptRSA(
    sessionKey,
    bobPublicKeyFromServer,
  );
  print('Encrypted Session Key (akan dikirim ke server):');
  print('${encryptedSessionKey.substring(0, 100)}...\n');

  // Simpan session key di device Alice
  await storageService.saveSessionKey('alice_bob_chat', sessionKey);
  print('✓ Session key tersimpan di device Alice\n');

  print('Data yang dikirim ke server:');
  print('  - Chat ID: alice_bob_chat');
  print('  - Encrypted Session Key: [untuk Bob]\n');

  // Simulasi: Bob menerima encrypted session key
  print('\n>>> BOB menerima encrypted session key dari ALICE...\n');

  // Bob dekripsi session key dengan private key-nya
  print('Bob dekripsi session key dengan RSA private key...');
  final decryptedSessionKey = encryptionService.decryptRSA(
    encryptedSessionKey,
    bobPrivateKey,
  );
  print('Decrypted Session Key:');
  print('$decryptedSessionKey\n');

  // Verifikasi session key sama
  if (decryptedSessionKey == sessionKey) {
    print('✓ Session key berhasil di-decrypt oleh Bob!');
    print(
      '✓ Key exchange SUKSES! Alice dan Bob sekarang punya session key yang sama\n',
    );
  } else {
    print('✗ ERROR: Session key tidak match!');
    return;
  }

  // Simpan session key di device Bob
  await storageService.saveSessionKey('alice_bob_chat', decryptedSessionKey);

  // ============================================================================
  // PHASE 3: MENGIRIM PESAN
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('PHASE 3: MENGIRIM PESAN');
  print('─' * 80);
  print('\n');

  print('>>> ALICE mengirim pesan ke BOB...\n');

  // Pesan plaintext dari Alice
  final plaintextMessage =
      'Halo Bob! Ini adalah pesan rahasia dari Alice. Kriptografi modern sangat penting untuk keamanan komunikasi digital. 🔒';
  print('Plaintext Message:');
  print('"$plaintextMessage"\n');

  // Enkripsi pesan dengan AES-256-CBC
  print('Enkripsi pesan dengan AES-256-CBC...');
  final encrypted = encryptionService.encryptAES(plaintextMessage, sessionKey);
  final ciphertext = encrypted['ciphertext']!;
  final iv = encrypted['iv']!;

  print('Ciphertext:');
  print('${ciphertext.substring(0, 100)}...');
  print('\nIV (Initialization Vector):');
  print('$iv\n');

  // Sign pesan dengan private key Alice
  print('Sign pesan dengan RSA private key Alice...');
  final signature = encryptionService.signMessage(
    plaintextMessage,
    alicePrivateKey,
  );
  print('Digital Signature:');
  print('${signature.substring(0, 100)}...\n');

  print('✓ Pesan berhasil dienkripsi dan di-sign!\n');

  print('Data yang dikirim ke server:');
  print('  - Chat ID: alice_bob_chat');
  print('  - Ciphertext: [encrypted message]');
  print('  - IV: $iv');
  print('  - Signature: [digital signature]');
  print('  - Sender: alice\n');

  // ============================================================================
  // PHASE 4: MENERIMA PESAN
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('PHASE 4: MENERIMA PESAN');
  print('─' * 80);
  print('\n');

  print('>>> BOB menerima pesan dari ALICE...\n');

  // Bob load session key dari storage
  print('Bob load session key dari secure storage...');
  final bobSessionKey = await storageService.loadSessionKey('alice_bob_chat');
  if (bobSessionKey == null) {
    print('✗ ERROR: Session key tidak ditemukan!');
    return;
  }
  print('✓ Session key loaded\n');

  // Dekripsi ciphertext dengan AES
  print('Dekripsi ciphertext dengan AES-256-CBC...');
  final decryptedMessage = encryptionService.decryptAES(
    ciphertext,
    bobSessionKey,
    iv,
  );
  print('Decrypted Message:');
  print('"$decryptedMessage"\n');

  // Bob request public key Alice dari server (untuk verify signature)
  print('Bob request public key Alice dari server...');
  final alicePublicKeyFromServer = alicePublicKey; // Simulasi dapat dari server
  print('✓ Public key Alice diterima\n');

  // Verify digital signature
  print('Verify digital signature dengan RSA public key Alice...');
  final isSignatureValid = encryptionService.verifySignature(
    decryptedMessage,
    signature,
    alicePublicKeyFromServer,
  );

  print('\n');
  if (isSignatureValid) {
    print('✓✓✓ SIGNATURE VALID ✓✓✓');
    print('✓ Pesan AUTHENTIC (benar dari Alice)');
    print('✓ Pesan INTEGRITY terjaga (tidak dimodifikasi)');
    print('\nBob dapat membaca pesan dengan aman! ✅\n');
  } else {
    print('✗✗✗ SIGNATURE INVALID ✗✗✗');
    print('✗ PERINGATAN: Pesan mungkin dipalsukan atau dimodifikasi!');
    print('✗ JANGAN PERCAYA pesan ini!\n');
    return;
  }

  // ============================================================================
  // SIMULASI: Bob membalas pesan Alice
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('DEMO: BOB MEMBALAS PESAN');
  print('─' * 80);
  print('\n');

  print('>>> BOB membalas pesan ALICE...\n');

  final bobReplyMessage =
      'Terima kasih Alice! Pesan kamu sudah aku terima dengan aman. E2E encryption memang keren! 👍';
  print('Bob\'s Message:');
  print('"$bobReplyMessage"\n');

  // Enkripsi dengan AES
  final bobEncrypted = encryptionService.encryptAES(
    bobReplyMessage,
    bobSessionKey,
  );
  final bobCiphertext = bobEncrypted['ciphertext']!;
  final bobIV = bobEncrypted['iv']!;

  // Sign dengan private key Bob
  final bobSignature = encryptionService.signMessage(
    bobReplyMessage,
    bobPrivateKey,
  );

  print('✓ Pesan Bob terenkripsi dan ter-sign\n');

  // Alice menerima dan decrypt
  print('>>> ALICE menerima balasan dari BOB...\n');

  final aliceSessionKey = await storageService.loadSessionKey('alice_bob_chat');
  final aliceDecrypted = encryptionService.decryptAES(
    bobCiphertext,
    aliceSessionKey!,
    bobIV,
  );

  final isBobSignatureValid = encryptionService.verifySignature(
    aliceDecrypted,
    bobSignature,
    bobPublicKey,
  );

  if (isBobSignatureValid) {
    print('Alice berhasil decrypt pesan Bob:');
    print('"$aliceDecrypted"');
    print('\n✓ Signature valid! Pesan benar dari Bob.\n');
  }

  // ============================================================================
  // SECURITY DEMO
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('DEMO: SECURITY TEST - Simulasi Serangan');
  print('─' * 80);
  print('\n');

  print('>>> Simulasi: Eve (attacker) mencoba memodifikasi pesan...\n');

  // Eve modifikasi ciphertext
  final tamperedMessage = 'Pesan ini telah dimodifikasi oleh Eve!';
  print('Eve mencoba mengirim pesan palsu ke Bob:');
  print('"$tamperedMessage"\n');

  // Eve enkripsi dengan session key yang dia curi (worst case scenario)
  final eveEncrypted = encryptionService.encryptAES(
    tamperedMessage,
    sessionKey,
  );

  // Tapi Eve tidak punya private key Alice, jadi dia tidak bisa sign
  // Dia coba pakai signature lama
  print('Eve menggunakan signature lama dari pesan Alice...\n');

  // Bob coba verify
  final bobDecryptTampered = encryptionService.decryptAES(
    eveEncrypted['ciphertext']!,
    bobSessionKey,
    eveEncrypted['iv']!,
  );

  print('Bob decrypt pesan dari Eve:');
  print('"$bobDecryptTampered"\n');

  print('Bob verify signature...');
  final isTamperedValid = encryptionService.verifySignature(
    bobDecryptTampered,
    signature, // Signature lama dari Alice
    alicePublicKeyFromServer,
  );

  print('\n');
  if (!isTamperedValid) {
    print('✓✓✓ SERANGAN TERDETEKSI! ✓✓✓');
    print('✓ Signature TIDAK VALID');
    print('✓ Bob tahu bahwa pesan ini BUKAN dari Alice');
    print('✓ Digital Signature berhasil mencegah serangan!\n');
  } else {
    print('✗ ERROR: Serangan tidak terdeteksi!');
  }

  // ============================================================================
  // CLEANUP & SUMMARY
  // ============================================================================

  print('\n');
  print('─' * 80);
  print('CLEANUP');
  print('─' * 80);
  print('\n');

  // Debug: print semua keys yang tersimpan
  await storageService.debugPrintAllKeys();

  print('\n>>> Clearing all data from secure storage...\n');
  await storageService.clearAll();
  print('✓ All data cleared\n');

  // ============================================================================
  // SUMMARY
  // ============================================================================

  print('\n');
  print('=' * 80);
  print('SUMMARY: End-to-End Encryption Demo');
  print('=' * 80);
  print('\n');

  print('✅ PHASE 1: Registrasi');
  print('   - Generate RSA-2048 key pair');
  print('   - Private key disimpan aman di device');
  print('   - Public key & password hash dikirim ke server\n');

  print('✅ PHASE 2: Key Exchange');
  print('   - Generate AES-256 session key');
  print('   - Enkripsi session key dengan RSA public key penerima');
  print('   - Dekripsi session key dengan RSA private key\n');

  print('✅ PHASE 3: Send Message');
  print('   - Enkripsi pesan dengan AES-256-CBC');
  print('   - Generate random IV untuk setiap pesan');
  print('   - Sign pesan dengan RSA private key\n');

  print('✅ PHASE 4: Receive Message');
  print('   - Dekripsi pesan dengan AES session key');
  print('   - Verify signature dengan RSA public key pengirim');
  print('   - Detect jika pesan dimodifikasi (signature invalid)\n');

  print('🔒 SECURITY FEATURES:');
  print('   ✓ Confidentiality: AES-256-CBC encryption');
  print('   ✓ Authenticity: RSA digital signature');
  print('   ✓ Integrity: SHA-256 hashing');
  print('   ✓ Forward Secrecy: Random session key per chat');
  print('   ✓ Secure Storage: flutter_secure_storage\n');

  print('=' * 80);
  print('\n');
}

/// Main function untuk menjalankan demo
void main() async {
  try {
    await runEncryptionDemo();
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('\nStack Trace:');
    print(stackTrace);
  }
}
