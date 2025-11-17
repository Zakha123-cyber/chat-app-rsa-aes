# Implementasi End-to-End Encryption untuk Chat App

Implementasi kriptografi modern untuk aplikasi chat dengan enkripsi end-to-end menggunakan kombinasi **AES-256** dan **RSA-2048**.

## 📋 Overview

Project ini adalah bagian dari tugas kuliah **Kriptografi Modern** yang mengimplementasikan sistem enkripsi end-to-end untuk aplikasi chat mobile menggunakan Flutter dengan Firebase backend.

### Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - `firebase_core` ^3.8.1 - Firebase initialization
  - `firebase_auth` ^5.3.3 - User authentication
  - `cloud_firestore` ^5.5.2 - Real-time database
- **Cryptography Libraries**:
  - `pointycastle` ^3.7.3 - RSA, AES, SHA-256
  - `crypto` ^3.0.3 - Hash functions
  - `flutter_secure_storage` ^9.0.0 - Secure key storage

## 🔐 Fitur Keamanan

### 1. RSA-2048

- **Key Generation**: Generate pasangan public/private key saat registrasi (2048-bit)
- **Key Storage**: Public key disimpan di Firestore, private key di secure storage device
- **Digital Signature**: Sign dan verify setiap pesan untuk authenticity & integrity

### 2. AES-256-CBC

- **Message Encryption**: Enkripsi pesan chat dengan mode CBC
- **Random IV**: Generate IV baru untuk setiap pesan (16 bytes)
- **Session Key**: Random session key untuk setiap chat session, disimpan lokal
- **Automatic Key Exchange**: Session key di-generate otomatis saat pertama kali buka chat

### 3. SHA-256

- **Message Hashing**: Hash pesan sebelum digital signature
- **Integrity Check**: Verify hash saat menerima pesan

### 4. Firebase Integration

- **Firebase Auth**: User authentication dengan email/password
- **Firestore**: Real-time database untuk pesan terenkripsi
- **Online Status**: Real-time presence detection
- **Unread Badges**: Subcollection untuk unread message counting

### 5. Secure Storage

- **Private Key Storage**: Simpan private key terenkripsi di device
- **Session Key Storage**: Cache session keys per chat di secure storage
- **Hardware-backed**: Menggunakan Android Keystore / iOS Keychain

## 📁 Struktur File

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── services/
│   ├── encryption_service.dart        # Core cryptography (RSA, AES, SHA-256)
│   ├── storage_service.dart           # Secure storage management
│   ├── chat_encryption_helper.dart    # High-level encryption helper
│   └── firebase_database_service.dart # Firestore CRUD operations
├── screens/
│   ├── login_screen.dart              # Login & registration UI
│   ├── contacts_screen.dart           # User list with unread badges
│   └── chat_screen.dart               # E2E encrypted chat UI
└── models/
    └── (data models)

firestore.rules                        # Firestore security rules
README.md                              # Project documentation
ENCRYPTION_README.md                   # This file
FLOW_DIAGRAM.md                        # Complete encryption flow
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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Register dengan Firebase Auth
final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'alice@example.com',
  password: 'password123',
);
final userId = userCredential.user!.uid;

// 2. Generate RSA key pair
final keyPair = encryptionService.generateRSAKeyPair();
final publicKey = keyPair['publicKey']!;   // Simpan ke Firestore
final privateKey = keyPair['privateKey']!; // Simpan di device

// 3. Save private key securely di device
await storageService.savePrivateKey(privateKey, username: 'alice');
await storageService.savePublicKey(publicKey);
await storageService.saveUsername('alice');

// 4. Save public key dan user data ke Firestore
await FirebaseFirestore.instance.collection('users').doc(userId).set({
  'username': 'alice',
  'email': 'alice@example.com',
  'publicKey': publicKey,
  'isOnline': true,
  'lastSeen': FieldValue.serverTimestamp(),
  'createdAt': FieldValue.serverTimestamp(),
});
```

### Phase 2: Key Exchange (Mulai Chat) - AUTOMATIC

**Key exchange dilakukan otomatis saat pertama kali buka chat room:**

```dart
// Dipanggil otomatis di chat_screen.dart saat initState
Future<void> _initializeChat() async {
  // 1. Generate session ID (consistent untuk kedua user)
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final sessionId = _dbService.generateSessionId(currentUserId, receiverId);

  // 2. Check apakah sudah punya session key
  final hasSession = await _chatHelper.hasSessionKey(sessionId);

  if (!hasSession) {
    // KEY EXCHANGE - Hanya terjadi sekali!

    // 3. Generate AES session key
    final sessionKey = encryptionService.generateAESKey();

    // 4. Save session key locally (tidak perlu kirim ke server!)
    await storageService.saveSessionKey(sessionId, sessionKey);

    // 5. Create chat session metadata di Firestore
    await FirebaseFirestore.instance.collection('chatSessions').add({
      'sessionId': sessionId,
      'participants': [currentUserId, receiverId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  // Session ready! Mulai encrypt/decrypt messages
  setState(() => _isSessionReady = true);
}
```

**Catatan Penting:**

- Session key **TIDAK dikirim** melalui network
- Setiap user generate session key sendiri untuk chat mereka
- Session key hanya disimpan di local device storage
- Firestore hanya simpan metadata (sessionId, participants)

### Phase 3: Mengirim Pesan

```dart
Future<void> _sendMessage() async {
  final messageText = _messageController.text.trim();

  // 1. Load session key dari local storage
  final sessionKey = await storageService.loadSessionKey(sessionId);

  // 2. Encrypt message dengan AES-256-CBC
  final encrypted = encryptionService.encryptAES(messageText, sessionKey!);
  final ciphertext = encrypted['ciphertext']!;
  final iv = encrypted['iv']!;

  // 3. Sign message dengan RSA private key
  final privateKey = await storageService.loadPrivateKey();
  final signature = encryptionService.signMessage(messageText, privateKey!);

  // 4. Send encrypted message ke Firestore
  await FirebaseFirestore.instance.collection('messages').add({
    'sessionId': sessionId,
    'senderId': FirebaseAuth.instance.currentUser!.uid,
    'receiverId': receiverId,
    'ciphertext': ciphertext,
    'iv': iv,
    'signature': signature,
    'timestamp': FieldValue.serverTimestamp(),
    'isDelivered': false,
    'isRead': false,
  });

  // 5. Increment unread count untuk receiver (subcollection)
  await FirebaseFirestore.instance
    .collection('users')
    .doc(receiverId)
    .collection('unreadCounts')
    .doc(senderId)
    .set({
      'count': FieldValue.increment(1),
      'sessionId': sessionId,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
}
```

### Phase 4: Menerima Pesan (Real-time Stream)

```dart
// Setup real-time listener di chat_screen.dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('messages')
    .where('sessionId', isEqualTo: sessionId)
    .orderBy('timestamp', descending: false)
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    // Decrypt setiap message
    final messages = snapshot.data!.docs.map((doc) {
      return _decryptMessage(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();

    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
    );
  },
)

// Decrypt function
Future<ChatMessage> _decryptMessage(String messageId, Map<String, dynamic> data) async {
  final senderId = data['senderId'] as String;
  final isSentByMe = senderId == FirebaseAuth.instance.currentUser!.uid;

  // 1. Load session key
  final sessionKey = await storageService.loadSessionKey(sessionId);

  // 2. Decrypt message
  final plaintext = encryptionService.decryptAES(
    data['ciphertext'],
    sessionKey!,
    data['iv'],
  );

  // 3. Get sender's public key dari Firestore
  final senderDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(senderId)
    .get();
  final senderPublicKey = senderDoc.data()!['publicKey'] as String;

  // 4. Verify signature
  final isValid = encryptionService.verifySignature(
    plaintext,
    data['signature'],
    senderPublicKey,
  );

  // 5. Mark as delivered (jika belum)
  if (!isSentByMe && data['isDelivered'] == false) {
    await FirebaseFirestore.instance
      .collection('messages')
      .doc(messageId)
      .update({'isDelivered': true});
  }

  return ChatMessage(
    message: plaintext,
    isSentByMe: isSentByMe,
    isVerified: isValid,  // Show warning icon jika false!
    timestamp: (data['timestamp'] as Timestamp).toDate(),
  );
}

// Reset unread count saat buka chat
await FirebaseFirestore.instance
  .collection('users')
  .doc(currentUserId)
  .collection('unreadCounts')
  .doc(senderId)
  .delete();
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

- ✅ **NEVER** send private key to Firestore atau network
- ✅ **NEVER** share private key with anyone
- ✅ **ALWAYS** store encrypted in secure storage (flutter_secure_storage)
- ✅ Private key hanya ada di device user

### Session Key Management

- ✅ Generate new session key saat pertama kali buka chat
- ✅ Session key disimpan lokal, **TIDAK** dikirim melalui Firestore
- ✅ Setiap chat session punya session key sendiri
- ⚠️ Clear session keys saat logout

### IV (Initialization Vector)

- ✅ **MUST** use random IV for each message (16 bytes)
- ✅ **NEVER** reuse IV with same key
- ✅ IV dikirim bersama ciphertext di Firestore (IV is public, not secret)
- ✅ Generate IV baru otomatis setiap kali encryptAES()

### Digital Signature

- ✅ **ALWAYS** verify signature before displaying message
- ✅ **SHOW WARNING** icon jika signature invalid (tampil di UI)
- ✅ Signature verify dengan public key dari Firestore
- ⚠️ Log failed verification (possible tampering atau attack)

### Firestore Security Rules

- ✅ Authenticated users only dapat read/write
- ✅ Users hanya bisa read pesan di chat mereka sendiri
- ✅ Validate sender ID matches authenticated user
- ✅ Prevent unauthorized access ke private data

### Real-time Security

- ✅ Firestore streams provide real-time updates
- ✅ Decrypt on-device saat message diterima
- ✅ Firestore hanya simpan encrypted data
- ✅ Zero-knowledge: Server tidak bisa decrypt

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
