import '../lib/services/encryption_service.dart';

void main() {
  print('Generating RSA-2048 key pair for mock receiver...');
  print('This will take a few seconds...\n');

  final service = EncryptionService();
  final keys = service.generateRSAKeyPair();

  print('=== PUBLIC KEY (use this in chat_screen.dart) ===');
  print(keys['publicKey']);
  print('\n=== DONE ===');
}
