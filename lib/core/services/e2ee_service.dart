import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'configuration_service.dart';
import 'secure_storage_service.dart';
import '../utils/logger.dart';

/// Service centralisé pour la gestion des clés E2EE.
/// 
/// Ce service est appelé automatiquement après chaque login/register
/// pour garantir que TOUS les utilisateurs ont une clé publique.
/// Cela permet un chiffrement E2EE fiable sans fallback.
class E2EEService {
  static final E2EEService _instance = E2EEService._internal();
  factory E2EEService() => _instance;
  E2EEService._internal();

  final String _baseUrl = ConfigurationService().apiBaseUrl;
  final Dio _dio = Dio();
  
  // Cryptography
  final _x25519 = X25519();
  
  // État
  SimpleKeyPair? _keyPair;
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  SimpleKeyPair? get keyPair => _keyPair;

  /// Initialise les clés E2EE de l'utilisateur.
  /// Appelé automatiquement après login/register.
  /// 
  /// Cette méthode:
  /// 1. Charge ou génère une paire de clés X25519
  /// 2. Enregistre la clé publique sur le serveur
  Future<void> initialize() async {
    if (!AuthService().isAuthenticated) {
      AppLogger.warning('E2EEService', 'Not authenticated, skipping E2EE init');
      return;
    }
    
    try {
      final secureStorage = SecureStorageService();
      final storedPrivateKey = await secureStorage.getPrivateKey();
      final storedPublicKey = await secureStorage.getPublicKey();
      
      if (storedPrivateKey != null && storedPublicKey != null) {
        // Recharger les clés existantes
        final privateBytes = base64Decode(storedPrivateKey);
        final publicBytes = base64Decode(storedPublicKey);
        _keyPair = SimpleKeyPairData(
          privateBytes,
          publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
        AppLogger.success('E2EEService', 'E2EE keys loaded from secure storage');
      } else {
        // Générer une nouvelle paire de clés
        _keyPair = await _x25519.newKeyPair();
        
        // Sauvegarder dans le stockage sécurisé
        final privateBytes = await _keyPair!.extractPrivateKeyBytes();
        final publicKey = await _keyPair!.extractPublicKey();
        
        await secureStorage.setPrivateKey(base64Encode(privateBytes));
        await secureStorage.setPublicKey(base64Encode(publicKey.bytes));
        
        AppLogger.success('E2EEService', 'New E2EE keys generated and stored securely');
      }
      
      // Vérifier/enregistrer la clé publique sur le serveur (seulement si nécessaire)
      await _syncPublicKeyWithServer();
      
      _isInitialized = true;
      AppLogger.success('E2EEService', 'E2EE initialized successfully');
    } catch (e) {
      AppLogger.error('E2EEService', 'E2EE initialization failed', e);
      // Ne pas bloquer le login si E2EE échoue
    }
  }

  /// Vérifie si la clé publique est déjà sur le serveur, l'enregistre si nécessaire
  Future<void> _syncPublicKeyWithServer() async {
    if (_keyPair == null) return;
    
    final localPublicKey = await _keyPair!.extractPublicKey();
    final localKeyBase64 = base64Encode(localPublicKey.bytes);
    final token = AuthService().token;
    final options = Options(headers: {'Authorization': 'Token $token'});
    
    try {
      // 1. Vérifier si la clé existe déjà sur le serveur
      final response = await _dio.get(
        '$_baseUrl/chat/keys/',
        options: options,
      );
      
      final serverKeyBase64 = response.data['public_key'] as String?;
      
      // 2. Comparer avec la clé locale
      if (serverKeyBase64 == localKeyBase64) {
        AppLogger.success('E2EEService', 'Public key already registered (no change)');
        return;
      }
      
      // 3. Clé différente sur le serveur - mettre à jour
      AppLogger.warning('E2EEService', 'Server key differs, updating...');
      await _registerPublicKey(localKeyBase64, options);
      
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Clé n'existe pas sur le serveur - l'enregistrer
        AppLogger.info('E2EEService', 'No key on server, registering...');
        await _registerPublicKey(localKeyBase64, options);
      } else {
        AppLogger.warning('E2EEService', 'Failed to check server key: $e');
      }
    }
  }

  /// Enregistre la clé publique sur le serveur
  Future<void> _registerPublicKey(String publicKeyBase64, Options options) async {
    try {
      await _dio.post(
        '$_baseUrl/chat/keys/',
        data: {'public_key': publicKeyBase64},
        options: options,
      );
      AppLogger.success('E2EEService', 'Public key registered on server');
    } catch (e) {
      AppLogger.warning('E2EEService', 'Failed to register public key: $e');
    }
  }

  /// Dérive un secret partagé X25519 avec la clé publique d'un autre utilisateur
  Future<SecretKey> deriveSharedSecret(String theirPublicKeyBase64) async {
    if (_keyPair == null) {
      throw Exception('E2EE not initialized');
    }
    
    final theirPublicBytes = base64Decode(theirPublicKeyBase64);
    final theirPublicKey = SimplePublicKey(theirPublicBytes, type: KeyPairType.x25519);
    
    return await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: theirPublicKey,
    );
  }

  /// Récupère la clé publique locale en base64
  Future<String?> getPublicKeyBase64() async {
    if (_keyPair == null) return null;
    final publicKey = await _keyPair!.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Nettoie les clés lors de la déconnexion
  Future<void> clear() async {
    _keyPair = null;
    _isInitialized = false;
    
    // Supprimer les clés du stockage sécurisé
    await SecureStorageService().deleteE2EEKeys();
    AppLogger.info('E2EEService', 'E2EE state cleared');
  }
}
