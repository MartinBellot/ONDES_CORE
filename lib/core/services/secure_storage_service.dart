import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service centralisé pour le stockage sécurisé (Keychain iOS / Keystore Android).
/// Utilisé pour les tokens, clés E2EE, et clés de conversation.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // ============== Auth ==============

  Future<String?> getAuthToken() => _storage.read(key: 'auth_token');

  Future<void> setAuthToken(String token) =>
      _storage.write(key: 'auth_token', value: token);

  Future<void> deleteAuthToken() => _storage.delete(key: 'auth_token');

  // ============== E2EE Keys ==============

  Future<String?> getPrivateKey() => _storage.read(key: 'chat_private_key');

  Future<void> setPrivateKey(String key) =>
      _storage.write(key: 'chat_private_key', value: key);

  Future<String?> getPublicKey() => _storage.read(key: 'chat_public_key');

  Future<void> setPublicKey(String key) =>
      _storage.write(key: 'chat_public_key', value: key);

  Future<void> deleteE2EEKeys() async {
    await _storage.delete(key: 'chat_private_key');
    await _storage.delete(key: 'chat_public_key');
  }

  // ============== Conversation Keys ==============

  Future<String?> getConversationKey(String conversationId) =>
      _storage.read(key: 'chat_conv_key_$conversationId');

  Future<void> setConversationKey(String conversationId, String key) =>
      _storage.write(key: 'chat_conv_key_$conversationId', value: key);

  Future<void> deleteConversationKey(String conversationId) =>
      _storage.delete(key: 'chat_conv_key_$conversationId');

  /// Supprime toutes les clés de conversation (utilisé au logout)
  Future<void> deleteAllConversationKeys() async {
    final allEntries = await _storage.readAll();
    for (final key in allEntries.keys) {
      if (key.startsWith('chat_conv_key_')) {
        await _storage.delete(key: key);
      }
    }
  }

  /// Supprime TOUT le stockage sécurisé (logout complet)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
