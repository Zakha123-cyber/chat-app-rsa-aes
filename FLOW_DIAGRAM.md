# 📊 FLOW DIAGRAM - End-to-End Encryption Chat System

## 🔄 COMPLETE ENCRYPTION FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 1: REGISTRASI                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Client)                            FIREBASE (Backend)
    ──────────────                            ──────────────────
         │
         │  1. Input: email, password, username
         │
         │  2. Generate RSA-2048 Key Pair
         │     ┌─────────────────────────┐
         │     │ Public Key  (2048-bit)  │ ──┐
         │     │ Private Key (2048-bit)  │   │
         │     └─────────────────────────┘   │
         │                                    │
         │  3. Save Private Key (Secure Storage - LOCAL ONLY!)
         │     [flutter_secure_storage]      │
         │     ✓ Encrypted by Android Keystore / iOS Keychain
         │     ✓ NEVER leaves device         │
         │                                    │
         │  4. Register with Firebase Auth   │
         ├────────────────────────────────────>
         │     email: "alice@example.com"    │
         │     password: "password123"       │
         │                                    │
         │                           5. Firebase Auth
         │                              Create User Account
         │  6. Receive User ID (UID)         ✓ userId: "abc123..."
         │<────────────────────────────────────
         │     userId: "abc123..."           │
         │                                    │
         │  7. Send User Data + Public Key   │
         ├────────────────────────────────────>
         │     Firestore: /users/{userId}    │
         │     {                              │
         │       username: "alice",           │
         │       email: "alice@example.com",  │
         │       publicKey: "-----BEGIN...",  │  8. Store in Firestore
         │       isOnline: true,              │     /users collection
         │       createdAt: timestamp         │     ✓ publicKey (PUBLIC)
         │     }                              │     ✓ username
         │                                    │     ✓ email
         │                                    │     ✓ online status
         │
    ✓ Registration Complete (Private key ONLY on device)


┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 2: KEY EXCHANGE (Start Chat)                        │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Initiator)                FIREBASE FIRESTORE           BOB (Receiver)
    ─────────────────               ──────────────────           ──────────────
         │
         │  1. Open chat with Bob
         │     (tap user "Bob" di contacts)
         │
         │  2. Generate Session ID (deterministic)
         │     sessionId = sort([alice_id, bob_id]).join("_")
         │     = "abc123_xyz789"
         │
         │  3. Check local storage
         │     hasSessionKey("abc123_xyz789")?
         │     → NO (first time chat)
         │
         │  4. Generate AES-256 Session Key
         │     [32 random bytes]
         │     sessionKey = "rT8kP2mN..."
         │
         │  5. Get Bob's Public Key
         ├────────────────────>
         │   Query: /users/{bob_id}    6. Return Bob's public key
         │<────────────────────
         │   { publicKey: "-----BEGIN RSA..." }
         │
         │  7. Encrypt Session Key (RSA)
         │     RSA_Encrypt(sessionKey, bob_public_key)
         │     = encryptedSessionKey = "aH8j2K..."
         │
         │  8. Save Session Key LOCALLY
         │     flutter_secure_storage.save(
         │       "session_abc123_xyz789",
         │       sessionKey  ← Original, not encrypted!
         │     )
         │     ✓ Stored on device
         │
         │  9. Send Encrypted Session Key to Firestore
         ├────────────────────>
         │   /chatSessions              10. Store encrypted session key
         │   {                               ✓ encryptedSessionKey (RSA encrypted!)
         │     sessionId: "abc123_xyz789",   ✓ participants
         │     participants: [alice_id, bob_id],  ✓ timestamps
         │     encryptedSessionKey: "aH8j2K...",
         │     createdAt: timestamp,
         │     lastMessageAt: timestamp
         │   }                          │
         │                              │
    ✓ Alice session ready             │        [Bob opens chat later...]
                                       │                    │
                                       │                    │  11. Bob opens chat with Alice
                                       │                    │
                                       │                    │  12. Generate SAME Session ID
                                       │                    │      (deterministic algorithm)
                                       │                    │      = "abc123_xyz789"
                                       │                    │
                                       │                    │  13. Check local storage
                                       │                    │      hasSessionKey?
                                       │                    │      → NO
                                       │                    │
                                       │                    │  14. Get Encrypted Session Key
                                       │                    ├─────────────>
                                       │                    │   Query: /chatSessions
                                       │                    │   where sessionId == "abc123..."
                                       │               15. Return encrypted key
                                       │                    │<─────────────
                                       │                    │   { encryptedSessionKey: "aH8j2K..." }
                                       │                    │
                                       │                    │  16. Load Private Key
                                       │                    │      (from secure storage)
                                       │                    │      bob_private_key
                                       │                    │
                                       │                    │  17. Decrypt Session Key (RSA)
                                       │                    │      RSA_Decrypt(encryptedSessionKey, bob_private_key)
                                       │                    │      = sessionKey = "rT8kP2mN..."
                                       │                    │
                                       │                    │  18. Save Session Key LOCALLY
                                       │                    │      ✓ Stored on device
                                       │                    │
                                       │                    ✓ Bob session ready

    PENTING:
    ✅ Alice & Bob punya session key SAMA ("rT8kP2mN...")
    ✅ Session key di-encrypt dengan RSA sebelum dikirim
    ✅ Hanya Bob yang bisa decrypt (dengan private key-nya)
    ✅ Firestore simpan encrypted session key (tidak bisa dibaca server)
    ✅ After decryption, both dapat encrypt/decrypt messages


┌─────────────────────────────────────────────────────────────────────────────┐
│                       PHASE 3: SEND MESSAGE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Sender)              FIREBASE FIRESTORE          BOB (Receiver)
    ──────────────            ────────────────────        ──────────────
         │
         │  1. User types message
         │     plaintext = "Hello Bob!"
         │
         │  2. Load Session Key (from local storage)
         │     sessionKey = "rT8kP..."
         │
         │  3. Generate Random IV (16 bytes)
         │     iv = [random 16 bytes]
         │
         │  4. Encrypt Message (AES-256-CBC)
         │     AES_Encrypt(plaintext, sessionKey, iv)
         │     = ciphertext = "cj7w..."
         │
         │  5. Load Private Key (from secure storage)
         │     alice_private_key
         │
         │  6. Hash Message (SHA-256)
         │     hash = SHA256("Hello Bob!")
         │
         │  7. Sign Hash (RSA Digital Signature)
         │     signature = RSA_Sign(hash, alice_private_key)
         │     = "A0lA..."
         │
         │  8. Send to Firestore
         ├────────────────────>
         │   /messages collection       9. Store encrypted message
         │   {                              ✓ ciphertext (encrypted!)
         │     sessionId: "abc123_xyz789",  ✓ iv
         │     senderId: alice_id,          ✓ signature
         │     receiverId: bob_id,          ✓ metadata
         │     ciphertext: "cj7w...",
         │     iv: "3Xgds...",
         │     signature: "A0lA...",
         │     timestamp: serverTime,
         │     isDelivered: false,
         │     isRead: false
         │   }                           │
         │                               │
         │  10. Update Unread Count      │
         ├────────────────────>         │
         │   /users/{bob_id}/unreadCounts/{alice_id}
         │   {                           │
         │     count: increment(1),      │
         │     sessionId: "abc123...",   │
         │     lastMessageAt: serverTime │
         │   }                           │
         │                               │
    ✓ Message sent (encrypted)         │
                                        │
    ⚠️  Firestore CANNOT decrypt message!
    ⚠️  Only Bob can decrypt with his session key


┌─────────────────────────────────────────────────────────────────────────────┐
│              PHASE 4: RECEIVE MESSAGE (Real-time Stream)                     │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Sender)            FIREBASE FIRESTORE          BOB (Receiver)
    ──────────────          ────────────────────        ──────────────
                                                               │
                                                               │  1. Open Chat Screen
                                                               │     Subscribe to real-time stream
                                                               │
                                                               │  StreamBuilder<QuerySnapshot>
                                                               │  /messages
                                                               │    .where(sessionId == "abc123...")
                                                               │    .orderBy(timestamp)
                                                               │    .snapshots() ← Real-time!
                                                               │
                                                          2. New Message Event!
                                                               │<────────────────
                                                               │   Document snapshot:
                                                               │   {
                                                               │     ciphertext: "cj7w...",
                                                               │     iv: "3Xgds...",
                                                               │     signature: "A0lA...",
                                                               │     senderId: alice_id
                                                               │   }
                                                               │
                                                               │  3. Load Session Key (local)
                                                               │     sessionKey = "pL9x..."
                                                               │
                                                               │  4. Decrypt Message (AES-256-CBC)
                                                               │     AES_Decrypt(ciphertext, sessionKey, iv)
                                                               │     = plaintext = "Hello Bob!"
                                                               │
                                                               │  5. Get Alice's Public Key
                                                               ├─────────────>
                                                               │   Query: /users/{alice_id}
                                                          6. Return public key
                                                               │<─────────────
                                                               │   { publicKey: "-----BEGIN..." }
                                                               │
                                                               │  7. Hash Decrypted Message
                                                               │     hash = SHA256("Hello Bob!")
                                                               │
                                                               │  8. Verify Signature (RSA)
                                                               │     RSA_Verify(hash, signature, alice_public_key)
                                                               │     = true ✅
                                                               │
                                                               │  9. Display Message
                                                               │     ✅ "Hello Bob!"
                                                               │     ✅ Show verified checkmark icon
                                                               │
                                                               │  10. Mark as Delivered
                                                               ├─────────────>
                                                               │   /messages/{messageId}
                                                               │   { isDelivered: true }
                                                               │
                                                               │  11. Reset Unread Count
                                                               ├─────────────>
                                                               │   /users/{bob_id}/unreadCounts/{alice_id}
                                                               │   DELETE document
                                                               │
                                                          ✅ Message received, decrypted & verified!
                                                          ✅ Badge hilang dari contacts screen


    REAL-TIME UPDATES:
    • Messages muncul instant tanpa refresh
    • Firestore snapshots() provide live stream
    • Decrypt on-the-fly saat message diterima
    • UI auto-update dengan StreamBuilder


┌─────────────────────────────────────────────────────────────────────────────┐
│                     SECURITY TEST: Attack Scenario                           │
└─────────────────────────────────────────────────────────────────────────────┘

    EVE (Attacker)                  SERVER              BOB (Receiver)
    ──────────────                ────────             ──────────────
         │
         │  1. Intercept Session Key (worst case)
         │     sessionKey = "rT8kP..."
         │
         │  2. Create Fake Message
         │     fake_message = "Send money!"
         │
         │  3. Encrypt Fake Message (AES)
         │     ciphertext_fake = AES_Encrypt(fake_message, sessionKey, iv)
         │
         │  4. Try to Send (Cannot Sign!)
         │     ✗ Eve doesn't have Alice's private key
         │     ✗ Uses old signature or random signature
         ├────────────────────>
         │   {                     5. Forward to Bob
         │     ciphertext_fake,        ├──────────────>
         │     iv,                     │
         │     signature_old,          │
         │     sender: "alice" (fake)  │
         │   }                         │
         │                             │  6. Bob receives
         │                             │     & decrypts
         │                             │     plaintext = "Send money!"
         │                             │
         │                             │  7. Bob verifies signature
         │                             │     RSA_Verify(hash, signature_old, alice_public_key)
         │                             │     = FALSE ✗
         │                             │
         │                             │  8. Bob sees warning
         │                             │     ⚠️ "Message verification failed!"
         │                             │     ⚠️ "Message may be tampered!"
         │                             │     ✓ Attack detected!
         │                             │
    ✓ Digital Signature successfully prevents attack!


┌─────────────────────────────────────────────────────────────────────────────┐
│                         KEY STORAGE DIAGRAM                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE's DEVICE                              FIREBASE FIRESTORE
    ──────────────                            ──────────────────

    Secure Storage                             /users/{alice_id}
    (flutter_secure_storage)                   ────────────────
    ┌──────────────────────┐                   ┌──────────────────────┐
    │ user_private_key     │                   │ username             │
    │ [Encrypted by OS]    │                   │ email                │
    │ ✓ RSA-2048 Private   │                   │ publicKey            │
    │ ✗ NEVER synced!      │                   │ isOnline             │
    │                      │                   │ lastSeen             │
    │ user_public_key      │                   │ createdAt            │
    │ [Cached]             │                   └──────────────────────┘
    │ ✓ RSA-2048 Public    │
    │                      │                   /messages/{messageId}
    │ username             │                   ───────────────────────
    │ alice                │                   ┌──────────────────────┐
    │                      │                   │ sessionId            │
    │ session_key_abc123   │                   │ senderId             │
    │ [Per Chat]           │                   │ receiverId           │
    │ ✓ AES-256 Key        │                   │ ciphertext ← ENCRYPTED!
    │ = "rT8kP2mN..."      │                   │ iv                   │
    │ ✗ NOT encrypted!     │                   │ signature            │
    └──────────────────────┘                   │ timestamp            │
                                               │ isDelivered          │
    ✅ Private keys stored locally             │ isRead               │
    ✅ Session keys decrypted & stored         └──────────────────────┘
    ✅ Hardware-backed encryption
    ✅ Android Keystore / iOS Keychain         /chatSessions/{docId}
    ✅ Biometric protection available          ───────────────────────
    ⛔ Private key NEVER leaves device!        ┌──────────────────────┐
                                               │ sessionId            │
                                               │ participants[]       │
    BOB's DEVICE (Similar Structure)           │ encryptedSessionKey  │ ← RSA encrypted!
    ────────────────────────────               │ createdAt            │
    Secure Storage                             │ lastMessageAt        │
    ┌──────────────────────┐                   └──────────────────────┘
    │ bob_private_key      │
    │ bob_public_key       │                   /users/{bob_id}/unreadCounts/{alice_id}
    │ session_key_abc123   │                   ──────────────────────────────────────
    │ = "rT8kP2mN..."      │                   ┌──────────────────────┐
    │ (SAME as Alice!)     │                   │ count                │
    └──────────────────────┘                   │ sessionId            │
                                               │ lastMessageAt        │
    ✅ Alice & Bob have SAME                    └──────────────────────┘
       session key after decryption!
    ✅ Session key encrypted with RSA          ✅ Firestore: Zero-knowledge storage
       before transmission                      ✅ Stores encrypted session key (RSA)
    ✅ Only Bob can decrypt with his            ✅ Stores encrypted messages (AES)
       private key                              ✅ Cannot decrypt either!
    ✅ True End-to-End Encryption!              ✅ Real-time sync & streams


┌─────────────────────────────────────────────────────────────────────────────┐
│                     CRYPTOGRAPHIC ALGORITHMS USED                            │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │   RSA-2048      │
    ├─────────────────┤
    │ • Key Exchange  │ ──> Encrypt/Decrypt AES session key
    │ • Signatures    │ ──> Sign/Verify message authenticity
    │ • 2048-bit keys │ ──> Public/Private key pair
    └─────────────────┘

    ┌─────────────────┐
    │  AES-256-CBC    │
    ├─────────────────┤
    │ • Encryption    │ ──> Encrypt/Decrypt chat messages
    │ • 256-bit key   │ ──> Session key (32 bytes)
    │ • CBC mode      │ ──> With random IV per message
    │ • PKCS7 padding │ ──> Block padding
    └─────────────────┘

    ┌─────────────────┐
    │    SHA-256      │
    ├─────────────────┤
    │ • Hashing       │ ──> Hash messages before signing
    │ • 256-bit hash  │ ──> Password hashing
    │ • Integrity     │ ──> Tamper detection
    └─────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY GUARANTEES                                 │
└─────────────────────────────────────────────────────────────────────────────┘

    ✅ CONFIDENTIALITY
       • Messages encrypted with AES-256
       • Only sender & receiver can decrypt
       • Server cannot read messages

    ✅ AUTHENTICITY
       • Digital signatures prove sender identity
       • Cannot be forged without private key
       • Detect impersonation attempts

    ✅ INTEGRITY
       • Signatures detect message tampering
       • SHA-256 hash ensures data unchanged
       • Warning shown if modified

    ✅ FORWARD SECRECY
       • Unique session key per chat
       • Compromise of one session doesn't affect others
       • Can rotate session keys

    ✅ NON-REPUDIATION
       • Digital signatures prove who sent message
       • Sender cannot deny sending
       • Cryptographic proof of origin
```

## 📝 Notes

- **Private keys**: NEVER leave the device (stored in secure storage)
- **Session keys**: Generated by Alice, encrypted with RSA, sent to Firestore
- **Bob decrypts**: Uses his private key to decrypt the session key
- **Same session key**: Alice & Bob use the same AES key after key exchange
- **IV (Initialization Vector)**: Random 16 bytes per message
- **Signatures**: Prove authenticity & detect tampering with RSA private key
- **Firestore**: Stores encrypted session key (RSA) + encrypted messages (AES)

## 🔒 Security Level

- **RSA**: 2048-bit (equivalent to ~112-bit symmetric security)
- **AES**: 256-bit (highest standard security level)
- **SHA-256**: 256-bit (collision-resistant hash)

**Conclusion**: Production-ready for academic/prototype applications! 🎓
