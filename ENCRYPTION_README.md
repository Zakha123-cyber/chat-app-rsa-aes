# Implementasi End-to-End Encryption untuk Chat App

Implementasi kriptografi modern untuk aplikasi chat dengan enkripsi end-to-end menggunakan kombinasi **AES-256** dan **RSA-2048**.

## 📋 Overview

Project ini adalah bagian dari tugas kuliah **Kriptografi Modern** yang mengimplementasikan sistem enkripsi end-to-end untuk aplikasi chat mobile menggunakan Flutter.

### Tech Stack

- **Frontend**: Flutter (Dart)
- **Cryptography Libraries**:
  - `pointycastle` ^3.7.3 - RSA, AES, SHA-256
  - `encrypt` ^5.0.3 - High-level encryption
  - `crypto` ^3.0.3 - Hash functions
  - `flutter_secure_storage` ^9.0.0 - Secure key storage

## 🔐 Fitur Keamanan

### 1. RSA-2048

- **Key Generation**: Generate pasangan public/private key (2048-bit)
- **Key Exchange**: Enkripsi AES session key dengan public key penerima
- **Digital Signature**: Sign dan verify pesan untuk authenticity & integrity

### 2. AES-256-CBC

- **Message Encryption**: Enkripsi pesan chat dengan mode CBC
- **Random IV**: Generate IV baru untuk setiap pesan (16 bytes)
- **Session Key**: Random session key untuk setiap chat (32 bytes)

### 3. SHA-256

- **Message Hashing**: Hash pesan sebelum digital signature
- **Password Hashing**: Hash password sebelum dikirim ke server

### 4. Secure Storage

- **Private Key Storage**: Simpan private key terenkripsi di device
- **Session Key Storage**: Cache session keys per chat
- **Hardware-backed**: Menggunakan Android Keystore / iOS Keychain

## 📁 Struktur File

```
lib/
├── services/
│   ├── encryption_service.dart    # Core cryptography operations
│   └── storage_service.dart       # Secure storage management
└── examples/
    └── encryption_example.dart    # Full demo & usage examples

test/
└── encryption_test.dart           # Simplified test (no Flutter dependencies)
```

## 🚀 Cara Menggunakan

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Running Demo

**Option A: Dart Console (Recommended untuk test cepat)**

```bash
dart test/encryption_test.dart
```

**Option B: Flutter App**

```bash
flutter run lib/examples/encryption_example.dart
```

### 3. Import di Project

```dart
import 'package:chat_app/services/encryption_service.dart';
import 'package:chat_app/services/storage_service.dart';

final encryptionService = EncryptionService();
final storageService = StorageService();
```

## 📖 Usage Examples

### Phase 1: Registrasi User

```dart
// Generate RSA key pair
final keyPair = encryptionService.generateRSAKeyPair();
final publicKey = keyPair['publicKey']!;   // Kirim ke server
final privateKey = keyPair['privateKey']!; // Simpan di device

// Save private key securely
await storageService.savePrivateKey(privateKey, username: 'alice');

// Hash password
final passwordHash = encryptionService.hashPassword('password123');
// Kirim username, passwordHash, dan publicKey ke server
```

### Phase 2: Key Exchange (Mulai Chat)

```dart
// Alice: Generate session key
final sessionKey = encryptionService.generateAESKey();

// Alice: Get Bob's public key dari server
final bobPublicKey = await fetchPublicKeyFromServer('bob');

// Alice: Encrypt session key dengan Bob's public key
final encryptedSessionKey = encryptionService.encryptRSA(
  sessionKey,
  bobPublicKey,
);

// Alice: Send encrypted session key ke server
await sendToServer(encryptedSessionKey);

// Alice: Save session key locally
await storageService.saveSessionKey('alice_bob_chat', sessionKey);

// ===== Di sisi Bob =====

// Bob: Load private key
final bobPrivateKey = await storageService.loadPrivateKey();

// Bob: Decrypt session key
final decryptedSessionKey = encryptionService.decryptRSA(
  encryptedSessionKey,
  bobPrivateKey!,
);

// Bob: Save session key
await storageService.saveSessionKey('alice_bob_chat', decryptedSessionKey);
```

### Phase 3: Mengirim Pesan

```dart
// Alice: Load session key
final sessionKey = await storageService.loadSessionKey('alice_bob_chat');

// Alice: Encrypt message
final message = 'Hello Bob! This is a secret message.';
final encrypted = encryptionService.encryptAES(message, sessionKey!);
final ciphertext = encrypted['ciphertext']!;
final iv = encrypted['iv']!;

// Alice: Sign message
final privateKey = await storageService.loadPrivateKey();
final signature = encryptionService.signMessage(message, privateKey!);

// Alice: Send to server
await sendMessageToServer({
  'ciphertext': ciphertext,
  'iv': iv,
  'signature': signature,
  'sender': 'alice',
  'receiver': 'bob',
});
```

### Phase 4: Menerima Pesan

```dart
// Bob: Receive message dari server
final receivedMessage = await receiveMessageFromServer();

// Bob: Load session key
final sessionKey = await storageService.loadSessionKey('alice_bob_chat');

// Bob: Decrypt message
final plaintext = encryptionService.decryptAES(
  receivedMessage['ciphertext'],
  sessionKey!,
  receivedMessage['iv'],
);

// Bob: Get Alice's public key dari server
final alicePublicKey = await fetchPublicKeyFromServer('alice');

// Bob: Verify signature
final isValid = encryptionService.verifySignature(
  plaintext,
  receivedMessage['signature'],
  alicePublicKey,
);

if (isValid) {
  // ✓ Message is authentic and not tampered
  displayMessage(plaintext);
} else {
  // ✗ Warning: Message may be forged or tampered!
  showWarning('Message verification failed!');
}
```

## 🔧 API Reference

### EncryptionService

#### RSA Operations

##### `generateRSAKeyPair()`

Generate RSA-2048 key pair.

**Returns**: `Map<String, String>`

```dart
{
  'publicKey': '-----BEGIN RSA PUBLIC KEY-----...',
  'privateKey': '-----BEGIN RSA PRIVATE KEY-----...'
}
```

##### `encryptRSA(String data, String publicKeyPEM)`

Encrypt data dengan RSA public key (untuk key exchange).

**Parameters**:

- `data`: Data yang akan dienkripsi (biasanya AES session key)
- `publicKeyPEM`: Public key penerima dalam format PEM

**Returns**: `String` - Encrypted data (Base64)

##### `decryptRSA(String encryptedData, String privateKeyPEM)`

Decrypt data dengan RSA private key.

**Parameters**:

- `encryptedData`: Data terenkripsi (Base64)
- `privateKeyPEM`: Private key sendiri dalam format PEM

**Returns**: `String` - Decrypted data

#### AES Operations

##### `generateAESKey()`

Generate random AES-256 session key.

**Returns**: `String` - AES key (Base64, 32 bytes)

##### `encryptAES(String plaintext, String aesKeyBase64)`

Encrypt pesan dengan AES-256-CBC.

**Parameters**:

- `plaintext`: Pesan yang akan dienkripsi
- `aesKeyBase64`: AES session key (Base64)

**Returns**: `Map<String, String>`

```dart
{
  'ciphertext': 'base64_encrypted_message',
  'iv': 'base64_initialization_vector'
}
```

##### `decryptAES(String ciphertextBase64, String aesKeyBase64, String ivBase64)`

Decrypt pesan dengan AES-256-CBC.

**Parameters**:

- `ciphertextBase64`: Ciphertext (Base64)
- `aesKeyBase64`: AES session key (Base64)
- `ivBase64`: Initialization Vector (Base64)

**Returns**: `String` - Decrypted message

#### Digital Signature

##### `signMessage(String message, String privateKeyPEM)`

Sign pesan dengan RSA private key.

**Parameters**:

- `message`: Pesan yang akan di-sign (plaintext)
- `privateKeyPEM`: Private key pengirim (PEM)

**Returns**: `String` - Digital signature (Base64)

##### `verifySignature(String message, String signature, String publicKeyPEM)`

Verify digital signature dengan RSA public key.

**Parameters**:

- `message`: Pesan yang sudah didekripsi (plaintext)
- `signature`: Digital signature (Base64)
- `publicKeyPEM`: Public key pengirim (PEM)

**Returns**: `bool` - `true` jika valid, `false` jika tidak

#### Utilities

##### `hashPassword(String password)`

Hash password dengan SHA-256.

**Parameters**:

- `password`: Password plaintext

**Returns**: `String` - SHA-256 hash (hexadecimal)

### StorageService

#### Private Key Operations

##### `savePrivateKey(String privateKeyPEM, {String? username})`

Simpan private key ke secure storage.

##### `loadPrivateKey()`

Load private key dari secure storage.

**Returns**: `Future<String?>` - Private key atau null

##### `deletePrivateKey()`

Hapus private key dari secure storage.

##### `hasPrivateKey()`

Check apakah private key sudah tersimpan.

**Returns**: `Future<bool>`

#### Session Key Operations

##### `saveSessionKey(String chatId, String sessionKey)`

Simpan AES session key untuk chat tertentu.

##### `loadSessionKey(String chatId)`

Load AES session key untuk chat tertentu.

**Returns**: `Future<String?>` - Session key atau null

##### `deleteSessionKey(String chatId)`

Hapus session key untuk chat tertentu.

#### Utility Operations

##### `clearAll()`

Hapus semua data dari secure storage (untuk logout).

##### `debugPrintAllKeys()`

Print semua keys yang tersimpan (untuk debugging).

## 🔒 Security Features

### Confidentiality (Kerahasiaan)

- ✅ AES-256-CBC encryption untuk pesan
- ✅ RSA-2048 untuk key exchange
- ✅ Random IV untuk setiap pesan
- ✅ Private key tidak pernah meninggalkan device

### Authenticity (Keaslian)

- ✅ Digital signature dengan RSA private key
- ✅ Verification dengan RSA public key
- ✅ Detect pesan palsu atau dari pengirim tidak sah

### Integrity (Integritas)

- ✅ SHA-256 hashing sebelum sign
- ✅ Signature verification detect perubahan pesan
- ✅ Tamper detection

### Forward Secrecy

- ✅ Session key unik per chat
- ✅ Session key dapat di-rotate
- ✅ Compromise satu session tidak affect session lain

### Secure Storage

- ✅ flutter_secure_storage dengan hardware-backed encryption
- ✅ Android Keystore / iOS Keychain
- ✅ Private keys encrypted at rest

## ⚠️ Security Notes

### Private Key Management

- **NEVER** send private key to server
- **NEVER** share private key with anyone
- **ALWAYS** store encrypted in secure storage
- **CONSIDER** adding password-based encryption layer

### Session Key Management

- Generate new session key per chat session
- Consider rotating session keys periodically
- Clear old session keys when chat ends

### IV (Initialization Vector)

- **MUST** use random IV for each message
- **NEVER** reuse IV with same key
- Send IV along with ciphertext (IV is public, not secret)

### Digital Signature

- **ALWAYS** verify signature before displaying message
- **SHOW WARNING** jika signature invalid
- **LOG** failed signature attempts (possible attack)

## 🧪 Testing

### Run Test Demo

```bash
# Test tanpa Flutter (console output)
dart test/encryption_test.dart

# Test dengan Flutter
flutter run lib/examples/encryption_example.dart
```

### Test Coverage

- ✅ RSA key generation (2048-bit)
- ✅ RSA encryption/decryption
- ✅ AES key generation (256-bit)
- ✅ AES encryption/decryption with random IV
- ✅ Digital signature creation
- ✅ Signature verification
- ✅ Password hashing (SHA-256)
- ✅ Security test: tampered message detection

### Expected Output

Demo akan menampilkan:

1. **Phase 1**: Registrasi Alice & Bob
2. **Phase 2**: Key exchange sukses
3. **Phase 3**: Alice kirim pesan terenkripsi + signature
4. **Phase 4**: Bob terima, decrypt, dan verify signature ✓
5. **Security Test**: Eve coba kirim pesan palsu → terdeteksi ✓

## 📊 Performance Notes

### RSA Operations

- Key generation: ~1-2 detik (2048-bit)
- Encryption: ~10-50 ms
- Decryption: ~50-100 ms
- Signing: ~50-100 ms
- Verification: ~10-50 ms

### AES Operations

- Key generation: <1 ms
- Encryption: 1-5 ms per message
- Decryption: 1-5 ms per message

### Recommendations

- Cache public keys dari server
- Generate session key once per chat
- Don't regenerate RSA keys frequently
- Use background isolate untuk RSA operations di production

## 🐛 Troubleshooting

### Error: "Unable to find suitable Visual Studio toolchain"

Solution: Run sebagai Dart script instead:

```bash
dart test/encryption_test.dart
```

### Error: "Private key not found"

Solution: Pastikan sudah call `savePrivateKey()` setelah generate key pair.

### Error: "Signature verification failed"

Possible causes:

- Message telah dimodifikasi (tampered)
- Menggunakan wrong public key untuk verify
- Corruption saat transmit

### Error: "Session key not found"

Solution: Pastikan sudah call `saveSessionKey()` setelah key exchange.

## 📝 License

Project ini dibuat untuk keperluan akademik (tugas kuliah Kriptografi Modern).

## 👨‍💻 Author

Tugas Kuliah - Kriptografi Modern  
Semester 5

## 🙏 Acknowledgments

- **PointyCastle**: Pure Dart implementation of cryptographic algorithms
- **Flutter Secure Storage**: Secure key-value storage for Flutter
- **Crypto**: Dart package for hash functions

## 📚 References

1. [AES (Advanced Encryption Standard)](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard)
2. [RSA (Rivest–Shamir–Adleman)](<https://en.wikipedia.org/wiki/RSA_(cryptosystem)>)
3. [Digital Signature](https://en.wikipedia.org/wiki/Digital_signature)
4. [End-to-End Encryption](https://en.wikipedia.org/wiki/End-to-end_encryption)
5. [CBC Mode](<https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Cipher_block_chaining_(CBC)>)

---

**⚡ Catatan**: Ini adalah implementasi prototype untuk keperluan edukasi. Untuk production, pertimbangkan:

- Key rotation mechanism
- Perfect forward secrecy (PFS)
- Certificate pinning
- Rate limiting
- Audit logging
- Professional security audit
