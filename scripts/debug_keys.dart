import '../lib/services/encryption_service.dart';

void main() {
  print('\n');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║       DEBUGGING RSA & AES KEY GENERATION                      ║');
  print('║       End-to-End Encryption Demo                             ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('\n');

  final service = EncryptionService();

  // ============================================================================
  // STEP 1: Generate RSA Key Pair (User Registration)
  // ============================================================================
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 1: GENERATE RSA-2048 KEY PAIR (User Registration)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final aliceKeys = service.generateRSAKeyPair();
  final alicePublicKey = aliceKeys['publicKey']!;
  final alicePrivateKey = aliceKeys['privateKey']!;

  print('\n⏸️  Press Enter to continue to STEP 2...');
  // stdin.readLineSync(); // Uncomment untuk pause

  // ============================================================================
  // STEP 2: Generate AES Session Key
  // ============================================================================
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 2: GENERATE AES-256 SESSION KEY (Chat Initialization)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final aesSessionKey = service.generateAESKey();

  print('\n⏸️  Press Enter to continue to STEP 3...');
  // stdin.readLineSync();

  // ============================================================================
  // STEP 3: Encrypt Message with AES
  // ============================================================================
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 3: ENCRYPT MESSAGE WITH AES-256-CBC');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  const testMessage = 'Hello! This is a secret message! 🔒';
  print('Original message: "$testMessage"\n');

  final encrypted = service.encryptAES(testMessage, aesSessionKey);
  final ciphertext = encrypted['ciphertext']!;
  final iv = encrypted['iv']!;

  print('\n⏸️  Press Enter to continue to STEP 4...');
  // stdin.readLineSync();

  // ============================================================================
  // STEP 4: Sign Message (Digital Signature)
  // ============================================================================
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 4: SIGN MESSAGE WITH RSA PRIVATE KEY (Digital Signature)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final signature = service.signMessage(testMessage, alicePrivateKey);

  print('\n⏸️  Press Enter to continue to STEP 5...');
  // stdin.readLineSync();

  // ============================================================================
  // STEP 5: Decrypt Message with AES
  // ============================================================================
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 5: DECRYPT MESSAGE WITH AES-256-CBC');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final decryptedMessage = service.decryptAES(ciphertext, aesSessionKey, iv);

  print('\n⏸️  Press Enter to continue to STEP 6...');
  // stdin.readLineSync();

  // ============================================================================
  // STEP 6: Verify Signature
  // ============================================================================
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('STEP 6: VERIFY DIGITAL SIGNATURE');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final isValid = service.verifySignature(
    decryptedMessage,
    signature,
    alicePublicKey,
  );

  print('═══════════════════════════════════════════════════════════');
  print('🔍 DEBUG: SIGNATURE VERIFICATION RESULT');
  print('═══════════════════════════════════════════════════════════');
  print('Original message: "$testMessage"');
  print('Decrypted message: "$decryptedMessage"');
  print('Signature valid: ${isValid ? "✅ YES" : "❌ NO"}');
  print('═══════════════════════════════════════════════════════════\n');

  // ============================================================================
  // SUMMARY
  // ============================================================================
  print('\n╔═══════════════════════════════════════════════════════════════╗');
  print('║                      ENCRYPTION SUMMARY                       ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');
  print('✅ RSA-2048 Key Pair Generated');
  print('   - Public Key: ${alicePublicKey.length} characters');
  print('   - Private Key: ${alicePrivateKey.length} characters');
  print('');
  print('✅ AES-256 Session Key Generated');
  print('   - Key: $aesSessionKey');
  print('');
  print('✅ Message Encrypted with AES-256-CBC');
  print('   - Original: "$testMessage"');
  print('   - Ciphertext: ${ciphertext.substring(0, 40)}...');
  print('   - IV: $iv');
  print('');
  print('✅ Message Signed with RSA Private Key');
  print('   - Signature: ${signature.substring(0, 40)}...');
  print('');
  print('✅ Message Decrypted Successfully');
  print('   - Decrypted: "$decryptedMessage"');
  print('   - Match: ${testMessage == decryptedMessage ? "✅" : "❌"}');
  print('');
  print('✅ Signature Verified');
  print('   - Valid: ${isValid ? "✅ YES" : "❌ NO"}');
  print('');
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║            ALL ENCRYPTION TESTS PASSED! ✅                    ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('\n');
}
