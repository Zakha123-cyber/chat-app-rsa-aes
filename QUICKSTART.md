# 🎯 QUICK START GUIDE

## Implementasi Enkripsi E2E untuk Chat App

### 📦 File Structure

```
lib/
├── services/
│   ├── encryption_service.dart          ⭐ Core cryptography
│   ├── storage_service.dart             ⭐ Secure key storage
│   └── chat_encryption_helper.dart      ⭐ High-level helper
└── examples/
    ├── encryption_example.dart          📖 Full demo
    └── ui_integration_example.dart      📖 Flutter UI example

test/
└── encryption_test.dart                 ✅ Test script
```

### 🚀 Running Demo

```bash
# Quick test (recommended)
dart test/encryption_test.dart

# Full demo dengan Flutter
flutter run lib/examples/encryption_example.dart
```

### ⚡ Quick Usage

#### 1️⃣ Registration

```dart
final helper = ChatEncryptionHelper();

final data = await helper.registerUser(
  username: 'alice',
  password: 'password123',
);

// Send to server:
// - data['username']
// - data['password_hash']
// - data['public_key']
```

#### 2️⃣ Start Chat

```dart
// Get receiver's public key from server
final bobPublicKey = await getPublicKeyFromServer('bob');

// Start session
final encryptedSessionKey = await helper.startChatSession(
  chatId: 'alice_bob',
  receiverPublicKey: bobPublicKey,
);

// Send encryptedSessionKey to server
```

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
