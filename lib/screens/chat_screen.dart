import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chat_app/services/chat_encryption_helper.dart';
import 'dart:math' show Random;

/// Modern & Polished Chat Screen with E2E Encryption
/// Features:
/// - Mock receiver (Bob)
/// - Real-time encryption/decryption demo
/// - Message bubbles with verification status
/// - Smooth animations
/// - Copy encrypted data feature
class ChatScreen extends StatefulWidget {
  final String username;

  const ChatScreen({super.key, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatHelper = ChatEncryptionHelper();
  final List<ChatMessage> _messages = [];

  // Mock data
  final String _chatId = 'demo_chat';
  late String _receiverName;
  String? _receiverPublicKey;
  String? _myPublicKey;

  bool _isSessionReady = false;
  bool _isSending = false;
  bool _showEncryptionDetails = false;

  @override
  void initState() {
    super.initState();
    _receiverName = widget.username == 'Alice' ? 'Bob' : 'Alice';
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Generate mock receiver keys
      print('Initializing chat session...');

      // Get our public key first
      _myPublicKey = await _chatHelper.getCachedPublicKey();
      if (_myPublicKey == null) {
        throw Exception(
          'Your keys not found. Please go back and register again.',
        );
      }

      // In real app, receiver key would be fetched from server
      // For demo, we generate a second key pair for "receiver"
      // Using a simpler approach to avoid long generation time
      final receiverKeys = await _generateMockReceiverKeys();
      _receiverPublicKey = receiverKeys['public_key']; // Fixed: use snake_case
      if (_receiverPublicKey == null) {
        throw Exception('Failed to generate mock receiver keys');
      }

      // Start session
      final hasSession = await _chatHelper.hasSessionKey(_chatId);
      if (!hasSession) {
        await _chatHelper.startChatSession(
          chatId: _chatId,
          receiverPublicKey: _receiverPublicKey!,
        );
      }

      setState(() => _isSessionReady = true);

      // Show welcome message
      _addSystemMessage(
        '🔒 End-to-end encrypted chat started with $_receiverName',
      );
      _addSystemMessage(
        'All messages are encrypted with AES-256 before sending',
      );
    } catch (e) {
      print('Failed to initialize chat: $e');
      setState(() {
        _isSessionReady = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<Map<String, String>> _generateMockReceiverKeys() async {
    // For demo purposes, we use a pre-generated mock receiver key
    // This makes the chat screen load INSTANTLY without waiting for RSA generation
    // In production, this would come from the server

    // OPTION A: Use hardcoded pre-generated key (INSTANT! No generation needed)
    // This is best for demo purposes - chat screen opens in <100ms
    const mockReceiverPublicKey = '''-----BEGIN RSA PUBLIC KEY-----
MIIBCgKCAQEAj4btcKsC+yLeFYe9vDzs1N7UF7mnpuxCMVKrgYVL2kPeaa2pzaS2
5/o6W1URzlcjM3hjyVuTK8VU19rfbXe+Rs3bF9N/Ezi3Y8I+1GBfqe7QnPxuz25H
0TxQAwlyurP4249bBrMF+lBzcod6W/E+zyNa6pMhTNmeg8ADk2gCFuQ2IlpXUMbU
ZP7LuF15uDQOOvmeT2WabGP8j35HS/o2V1mvtGOlk4/BWEKEURP7AYMc10jbZtbF
7Y5mHXBTrcPvXBtBoe4N7m0d7roauMKUpyW7gtkPBagvbxVD3ZWmEcmnAb9N8mcL
4EgaqkKrwvv8sOmUEYq7vhjtRJCHHa5EMQIDAQAB
-----END RSA PUBLIC KEY-----''';

    print('Using pre-generated mock receiver keys (instant!)');
    return {
      'username': _receiverName,
      'public_key': mockReceiverPublicKey,
      'password_hash': 'demo_hash',
    };

    /* OPTION B: Cache-based generation (use this if you want dynamic keys)
    // Uncomment this section if you want to generate fresh keys each time
    // WARNING: This will make chat screen take 2-3 seconds to load!
    
    final storage = StorageService();
    final cachedPublicKey = await storage.loadMockReceiverPublicKey();

    if (cachedPublicKey != null) {
      print('Using cached mock receiver keys');
      return {
        'username': _receiverName,
        'public_key': cachedPublicKey,
        'password_hash': 'demo_hash',
      };
    }

    // Generate new keys only if not cached (slow!)
    print('Generating new mock receiver keys...');
    final encryptionService = ChatEncryptionHelper();
    final result = await encryptionService.registerUser(
      username: _receiverName,
      password: 'demo_password',
    );

    // Cache the mock receiver's public key
    await storage.saveMockReceiverPublicKey(result['public_key']!);

    return result;
    */
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          message: text,
          isSentByMe: false,
          isVerified: true,
          timestamp: DateTime.now(),
          isSystem: true,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      // Prepare message (encrypt + sign)
      final messageData = await _chatHelper.prepareMessageToSend(
        chatId: _chatId,
        message: messageText,
      );

      // Add sent message
      setState(() {
        _messages.add(
          ChatMessage(
            message: messageText,
            isSentByMe: true,
            isVerified: true,
            timestamp: DateTime.now(),
            encryptedData: messageData,
          ),
        );
      });

      _scrollToBottom();

      // Simulate receiver getting the message
      await Future.delayed(const Duration(milliseconds: 500));
      _simulateReceivedMessage(messageData);
    } catch (e) {
      print('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _simulateReceivedMessage(
    Map<String, String> encryptedData,
  ) async {
    try {
      // Guard clause for null keys
      if (_myPublicKey == null) {
        throw Exception('Public key not available');
      }

      // Simulate processing received message (verify it can be decrypted)
      await _chatHelper.processReceivedMessage(
        chatId: _chatId,
        ciphertext: encryptedData['ciphertext']!,
        iv: encryptedData['iv']!,
        signature: encryptedData['signature']!,
        senderPublicKey: _myPublicKey!, // In demo, we verify our own signature
      );

      // Simulate auto-reply from receiver
      await Future.delayed(const Duration(seconds: 1));

      final replies = [
        'Got your encrypted message! 🔒',
        'Message received and verified! ✅',
        'Cool! The encryption works perfectly! 🎉',
        'Your message was decrypted successfully! 👍',
      ];

      final reply = replies[Random().nextInt(replies.length)];

      // "Send" reply
      final replyData = await _chatHelper.prepareMessageToSend(
        chatId: _chatId,
        message: reply,
      );

      setState(() {
        _messages.add(
          ChatMessage(
            message: reply,
            isSentByMe: false,
            isVerified: true,
            timestamp: DateTime.now(),
            encryptedData: replyData,
          ),
        );
      });

      _scrollToBottom();
    } catch (e) {
      print('Failed to simulate received message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showEncryptionDetailsDialog(ChatMessage message) {
    if (message.encryptedData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Text('Encryption Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem(
                'Original Message',
                message.message,
                Icons.message,
              ),
              const Divider(height: 24),
              _buildDetailItem(
                'Ciphertext (AES-256-CBC)',
                message.encryptedData!['ciphertext']!,
                Icons.lock,
                copyable: true,
              ),
              const Divider(height: 24),
              _buildDetailItem(
                'IV (Initialization Vector)',
                message.encryptedData!['iv']!,
                Icons.shuffle,
                copyable: true,
              ),
              const Divider(height: 24),
              _buildDetailItem(
                'Digital Signature (RSA-2048)',
                message.encryptedData!['signature']!,
                Icons.verified_user,
                copyable: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔒 Security Info:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Encrypted with AES-256-CBC\n'
                      '• Random IV per message\n'
                      '• Signed with RSA-2048\n'
                      '• Server cannot decrypt',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon, {
    bool copyable = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.length > 100 ? '${value.substring(0, 100)}...' : value,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              if (copyable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_receiverName),
            Text(
              _isSessionReady ? '🔒 End-to-end encrypted' : 'Initializing...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showEncryptionDetails ? Icons.info : Icons.info_outline,
            ),
            onPressed: () {
              setState(() {
                _showEncryptionDetails = !_showEncryptionDetails;
              });
            },
            tooltip: 'Toggle encryption details',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'keys') {
                _showKeysDialog();
              } else if (value == 'clear') {
                setState(() => _messages.clear());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'keys',
                child: Row(
                  children: [
                    Icon(Icons.key),
                    SizedBox(width: 8),
                    Text('View Keys'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Messages'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: !_isSessionReady
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Setting up encryption...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generating secure keys',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to see encryption in action',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Message Input
          if (_isSessionReady)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isSending,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _isSending ? null : _sendMessage,
                      mini: true,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.message,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: message.isSentByMe
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: message.encryptedData != null
              ? () => _showEncryptionDetailsDialog(message)
              : null,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: message.isSentByMe
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                    )
                  : null,
              color: message.isSentByMe ? null : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: TextStyle(
                    color: message.isSentByMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isVerified && !message.isSystem)
                      Icon(
                        Icons.verified,
                        size: 12,
                        color: message.isSentByMe
                            ? Colors.white70
                            : Colors.green,
                      ),
                    if (message.isVerified && !message.isSystem)
                      const SizedBox(width: 4),
                    Text(
                      '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: message.isSentByMe
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                    if (_showEncryptionDetails && message.encryptedData != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.lock,
                          size: 10,
                          color: message.isSentByMe
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showKeysDialog() {
    // Guard clause for null keys
    if (_myPublicKey == null || _receiverPublicKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keys not available yet. Please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encryption Keys'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeyInfo('My Public Key', _myPublicKey!),
              const Divider(height: 24),
              _buildKeyInfo(
                '$_receiverName\'s Public Key',
                _receiverPublicKey!,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔐 Key Information:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• RSA-2048 key pairs\n'
                      '• Public keys used for encryption\n'
                      '• Private keys stored securely\n'
                      '• Never transmitted over network',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInfo(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${key.substring(0, 50)}...',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: key));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Public key copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Data model for chat messages
class ChatMessage {
  final String message;
  final bool isSentByMe;
  final bool isVerified;
  final DateTime timestamp;
  final bool isSystem;
  final Map<String, String>? encryptedData;

  ChatMessage({
    required this.message,
    required this.isSentByMe,
    required this.isVerified,
    required this.timestamp,
    this.isSystem = false,
    this.encryptedData,
  });
}
