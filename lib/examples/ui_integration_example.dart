import 'package:flutter/material.dart';
import 'package:chat_app/services/chat_encryption_helper.dart';

/// Example: Cara menggunakan ChatEncryptionHelper dalam Flutter UI
///
/// File ini menunjukkan integration pattern untuk:
/// 1. Registration screen
/// 2. Chat screen
/// 3. Message handling

// ============================================================================
// 1. REGISTRATION SCREEN EXAMPLE
// ============================================================================

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _chatHelper = ChatEncryptionHelper();
  bool _isLoading = false;

  Future<void> _handleRegistration() async {
    setState(() => _isLoading = true);

    try {
      // Get user input
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // Validate input
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Username dan password tidak boleh kosong');
      }

      // Register user (generate keys, hash password, etc.)
      final registrationData = await _chatHelper.registerUser(
        username: username,
        password: password,
      );

      // Send registration data to server
      // await apiService.register(registrationData);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Registrasi berhasil!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home/chat screen
        // Navigator.pushReplacement(context, ...);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Registrasi gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegistration,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ============================================================================
// 2. CHAT SCREEN EXAMPLE
// ============================================================================

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverUsername;
  final String receiverPublicKey;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverUsername,
    required this.receiverPublicKey,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _chatHelper = ChatEncryptionHelper();
  final List<ChatMessage> _messages = [];
  bool _isSessionReady = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeChatSession();
  }

  Future<void> _initializeChatSession() async {
    try {
      // Check if session already exists
      final hasSession = await _chatHelper.hasSessionKey(widget.chatId);

      if (!hasSession) {
        // Start new session (as initiator)
        print('Starting new chat session...');
        final encryptedSessionKey = await _chatHelper.startChatSession(
          chatId: widget.chatId,
          receiverPublicKey: widget.receiverPublicKey,
        );

        // Send encrypted session key to server
        // await apiService.sendSessionKey(
        //   chatId: widget.chatId,
        //   encryptedSessionKey: encryptedSessionKey,
        // );

        print('Session key sent to server');
      }

      setState(() => _isSessionReady = true);
    } catch (e) {
      print('Failed to initialize chat session: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final message = _messageController.text.trim();

      // Encrypt and sign message
      final messageData = await _chatHelper.prepareMessageToSend(
        chatId: widget.chatId,
        message: message,
      );

      // Send to server
      // await apiService.sendMessage(
      //   chatId: widget.chatId,
      //   ciphertext: messageData['ciphertext']!,
      //   iv: messageData['iv']!,
      //   signature: messageData['signature']!,
      // );

      // Add to local messages (optimistic update)
      setState(() {
        _messages.add(
          ChatMessage(
            message: message,
            isSentByMe: true,
            isVerified: true,
            timestamp: DateTime.now(),
          ),
        );
      });

      _messageController.clear();
    } catch (e) {
      print('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _handleReceivedMessage({
    required String ciphertext,
    required String iv,
    required String signature,
    required String senderPublicKey,
  }) async {
    try {
      // Decrypt and verify message
      final decryptedMessage = await _chatHelper.processReceivedMessage(
        chatId: widget.chatId,
        ciphertext: ciphertext,
        iv: iv,
        signature: signature,
        senderPublicKey: senderPublicKey,
      );

      // Add to messages
      setState(() {
        _messages.add(
          ChatMessage(
            message: decryptedMessage.message,
            isSentByMe: false,
            isVerified: decryptedMessage.isSignatureValid,
            timestamp: DateTime.now(),
          ),
        );
      });

      // Show warning if signature is invalid
      if (!decryptedMessage.isSignatureValid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Warning: Message signature invalid!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Failed to process received message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverUsername),
            Text(
              _isSessionReady ? '🔒 Encrypted' : 'Initializing...',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Message input
          if (_isSessionReady)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isSentByMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: message.isSentByMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isVerified)
                  const Icon(Icons.warning, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '${message.timestamp.hour}:${message.timestamp.minute}',
                  style: TextStyle(
                    fontSize: 10,
                    color: message.isSentByMe ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

// ============================================================================
// 3. DATA MODELS
// ============================================================================

class ChatMessage {
  final String message;
  final bool isSentByMe;
  final bool isVerified;
  final DateTime timestamp;

  ChatMessage({
    required this.message,
    required this.isSentByMe,
    required this.isVerified,
    required this.timestamp,
  });
}

// ============================================================================
// 4. USAGE NOTES
// ============================================================================

/*

INTEGRATION CHECKLIST:

1. REGISTRATION:
   ✓ Call ChatEncryptionHelper.registerUser()
   ✓ Send result to server (username, password_hash, public_key)
   ✓ Server stores: username, password_hash, public_key
   ✓ Private key stays on device (secure storage)

2. START CHAT:
   ✓ Get receiver's public key from server
   ✓ Call ChatEncryptionHelper.startChatSession()
   ✓ Send encrypted session key to server
   ✓ Server forwards encrypted session key to receiver

3. ACCEPT CHAT (Receiver):
   ✓ Receive encrypted session key from server
   ✓ Call ChatEncryptionHelper.acceptChatSession()
   ✓ Session key decrypted and stored locally

4. SEND MESSAGE:
   ✓ Call ChatEncryptionHelper.prepareMessageToSend()
   ✓ Send ciphertext, IV, signature to server
   ✓ Server forwards to receiver (can't decrypt!)

5. RECEIVE MESSAGE:
   ✓ Get sender's public key from server
   ✓ Call ChatEncryptionHelper.processReceivedMessage()
   ✓ Display message if signature valid
   ✓ Show warning if signature invalid

6. LOGOUT:
   ✓ Call ChatEncryptionHelper.logout()
   ✓ All keys deleted from device

SERVER API ENDPOINTS (Example):

POST /api/register
Body: { username, password_hash, public_key }

GET /api/users/:username/public_key
Response: { public_key }

POST /api/chats/:chatId/session_key
Body: { encrypted_session_key }

POST /api/chats/:chatId/messages
Body: { ciphertext, iv, signature, sender }

GET /api/chats/:chatId/messages
Response: [ { ciphertext, iv, signature, sender, timestamp } ]

*/
