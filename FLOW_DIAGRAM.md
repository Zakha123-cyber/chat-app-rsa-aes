# 📊 FLOW DIAGRAM - End-to-End Encryption Chat System

## 🔄 COMPLETE ENCRYPTION FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 1: REGISTRASI                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Client)                                      SERVER
    ──────────────                                    ──────────
         │
         │  1. Input: username, password
         │
         │  2. Generate RSA-2048 Key Pair
         │     ┌─────────────────────────┐
         │     │ Public Key  (2048-bit)  │ ──┐
         │     │ Private Key (2048-bit)  │   │
         │     └─────────────────────────┘   │
         │                                    │
         │  3. Save Private Key (Secure Storage)
         │     [flutter_secure_storage]      │
         │     ✓ Encrypted at OS level       │
         │                                    │
         │  4. Hash Password (SHA-256)       │
         │     password → SHA-256 → hash     │
         │                                    │
         │  5. Send Registration Data        │
         ├────────────────────────────────────>
         │     {                              │
         │       username: "alice",           │
         │       password_hash: "13441c...",  │
         │       public_key: "-----BEGIN..."  │
         │     }                              │
         │                                    │
         │                            6. Store in DB
         │                               ✓ public_key
         │                               ✓ password_hash
         │                               ✓ username
         │
    ✓ Registration Complete


┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 2: KEY EXCHANGE (Start Chat)                        │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Initiator)                SERVER              BOB (Receiver)
    ─────────────────               ────────             ──────────────
         │
         │  1. Generate AES-256 Session Key
         │     [32 random bytes]
         │     sessionKey = "rT8kP..."
         │
         │  2. Request Bob's Public Key
         ├────────────────────>
         │                        3. Fetch from DB
         │                           Bob's public_key
         │  4. Receive Public Key
         │<────────────────────
         │     bob_public_key
         │
         │  5. Encrypt Session Key (RSA)
         │     RSA_Encrypt(sessionKey, bob_public_key)
         │     = encryptedSessionKey
         │
         │  6. Send Encrypted Session Key
         ├────────────────────>
         │   {                     7. Forward to Bob
         │     chat_id: "alice_bob",  ├──────────────>
         │     encrypted_key: "ahH..."  │
         │   }                          │  8. Receive
         │                              │     encrypted_key
         │  9. Save Session Key         │
         │     (Local Storage)          │  10. Load Private Key
         │     ✓ Stored                 │      (Secure Storage)
         │                              │
         │                              │  11. Decrypt Session Key (RSA)
         │                              │      RSA_Decrypt(encrypted_key, bob_private_key)
         │                              │      = sessionKey
         │                              │
         │                              │  12. Save Session Key
         │                              │      (Local Storage)
         │                              │      ✓ Stored
         │
    ✓ Both have same session key now!


┌─────────────────────────────────────────────────────────────────────────────┐
│                       PHASE 3: SEND MESSAGE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Sender)                  SERVER              BOB (Receiver)
    ──────────────                ────────             ──────────────
         │
         │  1. User types message
         │     plaintext = "Hello Bob!"
         │
         │  2. Load Session Key
         │     sessionKey = "rT8kP..."
         │
         │  3. Generate Random IV (16 bytes)
         │     iv = [random 16 bytes]
         │
         │  4. Encrypt Message (AES-256-CBC)
         │     AES_Encrypt(plaintext, sessionKey, iv)
         │     = ciphertext
         │
         │  5. Load Private Key
         │     alice_private_key
         │
         │  6. Hash Message (SHA-256)
         │     hash = SHA256(plaintext)
         │
         │  7. Sign Hash (RSA)
         │     signature = RSA_Sign(hash, alice_private_key)
         │
         │  8. Send Encrypted Message
         ├────────────────────>
         │   {                     9. Forward to Bob
         │     ciphertext: "cj7w...",  ├──────────────>
         │     iv: "3Xgds...",          │
         │     signature: "A0lA...",    │
         │     sender: "alice"          │
         │   }                          │
         │                              │
    ✓ Message sent (encrypted)          │
                                         │
                                    (Server cannot decrypt!)


┌─────────────────────────────────────────────────────────────────────────────┐
│                      PHASE 4: RECEIVE MESSAGE                                │
└─────────────────────────────────────────────────────────────────────────────┘

    ALICE (Sender)                  SERVER              BOB (Receiver)
    ──────────────                ────────             ──────────────
                                                             │
                                                             │  1. Receive Message
                                                             │<────────────
                                                             │   {
                                                             │     ciphertext,
                                                             │     iv,
                                                             │     signature,
                                                             │     sender: "alice"
                                                             │   }
                                                             │
                                                             │  2. Load Session Key
                                                             │     sessionKey
                                                             │
                                                             │  3. Decrypt Message (AES-256-CBC)
                                                             │     AES_Decrypt(ciphertext, sessionKey, iv)
                                                             │     = plaintext
                                                             │     = "Hello Bob!"
                                                             │
                                                             │  4. Request Alice's Public Key
                                                             ├────────────>
                                                             │     sender: "alice"
                                                        5. Send Public Key
                                                             │<────────────
                                                             │     alice_public_key
                                                             │
                                                             │  6. Hash Decrypted Message
                                                             │     hash = SHA256(plaintext)
                                                             │
                                                             │  7. Verify Signature (RSA)
                                                             │     RSA_Verify(hash, signature, alice_public_key)
                                                             │     = true/false
                                                             │
                                                             │  8. Check Result
                                                             │     if (valid) {
                                                             │       ✓ Display: "Hello Bob!"
                                                             │       ✓ Mark as verified
                                                             │     } else {
                                                             │       ✗ Show warning
                                                             │       ✗ Message tampered!
                                                             │     }
                                                             │
                                                        ✓ Message received & verified!


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

    ALICE's DEVICE                              SERVER DATABASE
    ──────────────                            ─────────────────

    Secure Storage                             Users Table
    (flutter_secure_storage)                   ───────────
    ┌──────────────────────┐                   ┌──────────────────────┐
    │ user_private_key     │                   │ username             │
    │ [Encrypted by OS]    │                   │ password_hash        │
    │ ✓ RSA-2048 Private   │                   │ public_key           │
    │                      │                   │ created_at           │
    │ user_public_key      │                   └──────────────────────┘
    │ [Cached]             │
    │ ✓ RSA-2048 Public    │                   Messages Table
    │                      │                   ──────────────
    │ username             │                   ┌──────────────────────┐
    │ alice                │                   │ chat_id              │
    │                      │                   │ sender               │
    │ session_key_*        │                   │ ciphertext           │
    │ [Per Chat]           │                   │ iv                   │
    │ ✓ AES-256 Keys       │                   │ signature            │
    └──────────────────────┘                   │ timestamp            │
                                               └──────────────────────┘
    ✓ Private keys NEVER leave device!
    ✓ Server stores only encrypted data!          ✓ Server cannot decrypt!
    ✓ Hardware-backed encryption!                 ✓ Zero-knowledge!


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

- **Private keys**: NEVER leave the device
- **Session keys**: Encrypted with RSA before transmission
- **IV (Initialization Vector)**: Random 16 bytes per message
- **Signatures**: Prove authenticity & detect tampering
- **Server**: Stores only encrypted data (zero-knowledge)

## 🔒 Security Level

- **RSA**: 2048-bit (equivalent to ~112-bit symmetric security)
- **AES**: 256-bit (highest standard security level)
- **SHA-256**: 256-bit (collision-resistant hash)

**Conclusion**: Production-ready for academic/prototype applications! 🎓
