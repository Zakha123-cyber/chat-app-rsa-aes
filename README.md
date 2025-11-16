# 🔐 Secure Chat - End-to-End Encrypted Messaging

> **Tugas Kuliah Kriptografi Modern**  
> Aplikasi Chat dengan Enkripsi End-to-End menggunakan kombinasi **AES-256** dan **RSA-2048**

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![Encryption](https://img.shields.io/badge/Encryption-AES--256%20%2B%20RSA--2048-green)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🎯 **Fitur Utama**

✅ **End-to-End Encryption** dengan AES-256-CBC + RSA-2048  
✅ **Digital Signature** untuk verifikasi integritas pesan  
✅ **Firebase Authentication** (Email/Password)  
✅ **Real-time Messaging** dengan Firestore  
✅ **Secure Key Storage** menggunakan Flutter Secure Storage  
✅ **Online/Offline Status** untuk setiap user  
✅ **Material Design 3** UI yang modern dan responsif

---

## 🏗️ **Arsitektur Aplikasi**

### **Tech Stack**

- **Frontend**: Flutter 3.8.1+ (Web, Android, iOS support)
- **Backend**: Firebase (Authentication + Firestore)
- **Cryptography**:
  - `pointycastle` v3.7.3 - RSA-2048 & AES-256-CBC
  - `encrypt` v5.0.3 - High-level encryption wrapper
  - `crypto` v3.0.3 - SHA-256 hashing
- **Storage**: `flutter_secure_storage` v9.0.0

### **File Structure**

```
lib/
├── main.dart                           # App entry point + auth wrapper
├── firebase_options.dart               # Firebase configuration
├── services/
│   ├── encryption_service.dart         # Core AES + RSA encryption
│   ├── storage_service.dart            # Secure key storage (local)
│   ├── chat_encryption_helper.dart     # High-level encryption helper
│   ├── firebase_auth_service.dart      # Firebase authentication
│   └── firebase_database_service.dart  # Firestore operations
└── screens/
    ├── login_screen.dart               # Email/password login
    ├── signup_screen.dart              # User registration + RSA keygen
    ├── contacts_screen.dart            # List all users
    └── chat_screen.dart                # E2E encrypted chat room

firestore.rules                         # Firestore security rules
```

---

## 🔐 **Implementasi Kriptografi**

### **1. Registration & Key Generation**

Saat user mendaftar:

1. Generate **RSA-2048 key pair** (public + private key)
2. Hash password dengan **SHA-256**
3. Simpan private key di **Flutter Secure Storage** (local device)
4. Upload username, password hash, dan public key ke **Firestore**

```dart
final helper = ChatEncryptionHelper();

final data = await helper.registerUser(
  username: 'alice',
  password: 'password123',
);

// Data yang dikirim ke Firebase:
// - username: 'alice'
// - passwordHash: SHA-256 hash
// - publicKey: RSA public key (PEM format)
```

### **2. Key Exchange Protocol**

Saat memulai chat:

1. Generate random **AES-256 session key**
2. Encrypt session key dengan **receiver's RSA public key**
3. Simpan encrypted session key di Firestore `chatSessions` collection
4. Gunakan session key untuk encrypt semua pesan di chat tersebut

```dart
await helper.startChatSession(
  chatId: 'session_alice_bob',
  receiverPublicKey: bobPublicKey,
);

// Session key tersimpan di local storage device
// Hanya bisa di-decrypt oleh receiver menggunakan private key mereka
```

````

### **3. Configure Firebase**
1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Buat project baru atau gunakan yang sudah ada
3. Enable **Authentication** (Email/Password method)
4. Create **Firestore Database** (Test mode)
5. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules
````

### **4. Run on Chrome (Web)**

```bash
flutter run -d chrome
```

### **5. Testing dengan 2 User**

1. **Tab 1**: Signup sebagai User A (misal: `alice@gmail.com`)
2. **Tab 2**: Signup sebagai User B (misal: `bob@gmail.com`)
3. **Tab 1**: Login as Alice → klik Bob di contacts → kirim pesan
4. **Tab 2**: Login as Bob → klik Alice di contacts → balas pesan
5. ✅ **Verifikasi**: Pesan terenkripsi E2E, ada icon ✅ (signature valid)

---

## 📊 **Database Schema (Firestore)**

### **Collection: `users`**

```json
{
  "uid": "firebase_user_id",
  "username": "alice",
  "publicKey": "-----BEGIN PUBLIC KEY-----\nMIIBIj...",
  "isOnline": true,
  "lastSeen": "2025-11-17T10:30:00Z"
}
```

### **Collection: `messages`**

```json
{
  "sessionId": "uid1_uid2",
  "senderId": "alice_uid",
  "receiverId": "bob_uid",
  "ciphertext": "base64_encrypted_data",
  "iv": "base64_initialization_vector",
  "signature": "base64_rsa_signature",
  "timestamp": "Firestore ServerTimestamp",
  "isRead": false,
  "isDelivered": true
}
```

### **Collection: `chatSessions`**

```json
{
  "sessionId": "uid1_uid2",
  "participants": ["alice_uid", "bob_uid"],
  "encryptedSessionKey": "placeholder_or_encrypted_aes_key",
  "createdAt": "Firestore ServerTimestamp",
  "lastMessageAt": "Firestore ServerTimestamp"
}
```

---

## 🔒 **Security Features**

### **Firestore Security Rules**

- ✅ User hanya bisa baca/tulis data mereka sendiri
- ✅ Message hanya bisa dibaca oleh sender & receiver
- ✅ Validasi struktur data di server-side
- ✅ Audit trail: message tidak bisa dihapus

### **Encryption Details**

| Komponen       | Algorithm | Key Size | Mode    |
| -------------- | --------- | -------- | ------- |
| **Symmetric**  | AES       | 256-bit  | CBC     |
| **Asymmetric** | RSA       | 2048-bit | OAEP    |
| **Hashing**    | SHA-256   | 256-bit  | -       |
| **Signature**  | RSA-PSS   | 2048-bit | SHA-256 |

### **Key Storage**

- **Private Keys**: Disimpan di Flutter Secure Storage (local device, encrypted by OS)
- **Public Keys**: Disimpan di Firestore (bisa diakses semua user untuk enkripsi)
- **Session Keys**: Disimpan di local storage dengan chat ID sebagai identifier

---

## 🧪 **Testing & Verification**

### **Unit Tests**

```bash
# Run enkripsi tests
dart test/encryption_test.dart
```

### **Manual Testing Checklist**

- [ ] User registration dengan RSA key generation
- [ ] Login dengan email/password
- [ ] Contacts list menampilkan online/offline status
- [ ] Start chat session (key exchange)
- [ ] Send encrypted message
- [ ] Receive message & verify signature
- [ ] Long-press message → lihat encryption details
- [ ] Logout → online status berubah
- [ ] Multi-device: pesan di device A muncul realtime di device B

### **Expected Output (Console Logs)**

```
[ChatScreen] Initializing chat session...
[StorageService] √ Public key loaded successfully
[ChatScreen] Session ID: alice_uid_bob_uid
[ChatScreen] √ Session key already exists
[ChatHelper] Preparing message to send...
[EncryptionService] Encrypting with AES-256-CBC...
[EncryptionService] Signing message with RSA-2048...
[FirebaseDB] √ Message sent successfully
[ChatHelper] Processing received message...
[EncryptionService] Decrypting message with AES-256-CBC...
[EncryptionService] √ Signature is VALID - Message is authentic
```

---

## 📸 **Screenshots**

### Login Screen

![Login](screenshots/login.png)

### Signup Screen (RSA Key Generation)

![Signup](screenshots/signup.png)

### Contacts List (Online Status)

![Contacts](screenshots/contacts.png)

### Chat Screen (E2E Encrypted)

![Chat](screenshots/chat.png)

### Encryption Details Dialog

![Encryption Details](screenshots/encryption_details.png)

---

## 🎓 **Konsep Kriptografi yang Diimplementasikan**

### **1. Hybrid Encryption**

Kombinasi **symmetric** (AES) dan **asymmetric** (RSA):

- AES: Enkripsi pesan (cepat, efficient untuk data besar)
- RSA: Enkripsi AES session key (secure key exchange)

### **2. Digital Signature**

Menggunakan **RSA-PSS** dengan SHA-256:

- Membuktikan pesan tidak diubah (integrity)
- Membuktikan pengirim adalah pemilik private key (authentication)
- Non-repudiation: pengirim tidak bisa menyangkal mengirim pesan

### **3. Forward Secrecy**

- Setiap chat session memiliki **unique AES session key**
- Jika 1 session key bocor, session lain tetap aman
- Private key hanya digunakan untuk sign/verify, bukan encrypt pesan langsung

### **4. Key Management**

- **Private keys** NEVER leave device
- **Public keys** didistribusikan melalui trusted channel (Firebase)
- **Session keys** di-rotate per chat session

---

## 🐛 **Known Limitations**

1. **Session Key Exchange**: Saat ini menggunakan placeholder. Production app perlu:

   - Encrypt AES session key dengan receiver's RSA public key
   - Store encrypted session key di Firestore
   - Receiver decrypt dengan private key mereka

2. **Key Rotation**: Session key tidak di-rotate secara periodik

3. **Perfect Forward Secrecy**: Tidak menggunakan Diffie-Hellman key exchange

4. **Metadata Leakage**: Timestamp dan online status tidak terenkripsi

---

## 📚 **Referensi**

- [RFC 3447 - RSA Cryptography Specifications](https://www.rfc-editor.org/rfc/rfc3447)
- [NIST SP 800-38A - AES Modes of Operation](https://csrc.nist.gov/publications/detail/sp/800-38a/final)
- [Signal Protocol Specifications](https://signal.org/docs/)
- [Flutter Secure Storage Documentation](https://pub.dev/packages/flutter_secure_storage)
- [PointyCastle Dart Crypto Library](https://pub.dev/packages/pointycastle)

---

## 👨‍💻 **Author**

**Zakha123-cyber**  
Mahasiswa Semester 5 - Tugas Kriptografi Modern  
Repository: [chat-app-rsa-aes](https://github.com/Zakha123-cyber/chat-app-rsa-aes)

---

## 📄 **License**

MIT License - Lihat [LICENSE](LICENSE) untuk detail lengkap.

---

## 🙏 **Acknowledgments**

- Firebase team untuk backend infrastructure
- Flutter team untuk cross-platform framework
- PointyCastle contributors untuk Dart cryptography library
- Signal Foundation untuk inspiration E2E encryption protocol

---

**⭐ Jangan lupa kasih star kalau repo ini membantu! 🚀**

Setiap pesan dienkripsi dengan **AES-256-CBC**:

1. Encrypt plaintext dengan AES session key
2. Generate random **IV (Initialization Vector)** per message
3. Sign ciphertext dengan **RSA private key** (digital signature)
4. Kirim `{ciphertext, iv, signature}` ke Firestore

```dart
final messageData = await helper.prepareMessageToSend(
  chatId: 'session_alice_bob',
  message: 'Hello Bob! 🔒',
);

// Hasil:
// {
//   'ciphertext': 'base64_encrypted_message',
//   'iv': 'base64_iv',
//   'signature': 'base64_rsa_signature'
// }
```

### **4. Message Decryption**

Saat menerima pesan:

1. Decrypt ciphertext dengan AES session key + IV
2. Verify signature dengan **sender's RSA public key**
3. Tampilkan plaintext hanya jika signature valid ✅

```dart
final decrypted = await helper.processReceivedMessage(
  chatId: 'session_alice_bob',
  ciphertext: message['ciphertext'],
  iv: message['iv'],
  signature: message['signature'],
  senderPublicKey: alicePublicKey,
);

// Hasil:
// {
//   'message': 'Hello Bob! 🔒',
//   'isSignatureValid': true  ✅
// }
```

---

## 🚀 **Cara Menjalankan Aplikasi**

### **Prerequisites**

- Flutter SDK 3.8.1 atau lebih baru
- Firebase project (sudah dikonfigurasi)
- Chrome browser (untuk web testing)

### **1. Clone Repository**

```bash
git clone https://github.com/Zakha123-cyber/chat-app-rsa-aes.git
cd chat-app-rsa-aes
```

### **2. Install Dependencies**

````bash
flutter pub get

```dart
// Get receiver's public key from server
final bobPublicKey = await getPublicKeyFromServer('bob');

// Start session
final encryptedSessionKey = await helper.startChatSession(
  chatId: 'alice_bob',
  receiverPublicKey: bobPublicKey,
);

// Send encryptedSessionKey to server
````

#### 3️⃣ Send Message

```dart
final messageData = await helper.prepareMessageToSend(
  chatId: 'alice_bob',
  message: 'Hello Bob!',
);

// Send to server:
// - messageData['ciphertext']
// - messageData['iv']
// - messageData['signature']
```

#### 4️⃣ Receive Message

```dart
// Get from server: ciphertext, iv, signature, senderPublicKey
final decrypted = await helper.processReceivedMessage(
  chatId: 'alice_bob',
  ciphertext: receivedData['ciphertext'],
  iv: receivedData['iv'],
  signature: receivedData['signature'],
  senderPublicKey: alicePublicKey,
);

if (decrypted.isSignatureValid) {
  print('✓ ${decrypted.message}');
} else {
  print('⚠️ Warning: Invalid signature!');
}
```

### 🔐 Security Checklist

- ✅ **RSA-2048** for key exchange & signatures
- ✅ **AES-256-CBC** for message encryption
- ✅ **SHA-256** for hashing & signatures
- ✅ **Random IV** for each message
- ✅ **Secure storage** with flutter_secure_storage
- ✅ **Private keys** never leave device
- ✅ **Digital signatures** for authenticity
- ✅ **Tamper detection** via signature verification

### 📊 Test Results

```
✓ PHASE 1: Registrasi - RSA key pair generated
✓ PHASE 2: Key Exchange - Session key encrypted & decrypted
✓ PHASE 3: Send Message - Encrypted with AES + signed
✓ PHASE 4: Receive Message - Decrypted & signature verified
✓ SECURITY TEST: Tampered message detected ✓
```

### 📚 API Reference

Lihat `ENCRYPTION_README.md` untuk dokumentasi lengkap.

### 🐛 Common Issues

**Q: "Private key not found"**  
A: Panggil `registerUser()` terlebih dahulu

**Q: "Session key not found"**  
A: Panggil `startChatSession()` atau `acceptChatSession()`

**Q: "Signature verification failed"**  
A: Pesan mungkin dimodifikasi atau gunakan public key yang salah

### 🎓 Next Steps

1. ✅ Test enkripsi → `dart test/encryption_test.dart`
2. 📖 Baca dokumentasi → `ENCRYPTION_README.md`
3. 🔌 Integrasikan dengan UI → Lihat `ui_integration_example.dart`
4. 🌐 Buat Backend API → FastAPI (Python)
5. 📱 Build Mobile App → Flutter

### 📞 Support

Untuk pertanyaan lebih lanjut, lihat dokumentasi lengkap di `ENCRYPTION_README.md`.

---

**Status**: ✅ Production-ready for academic project  
**Last Updated**: November 2, 2025
