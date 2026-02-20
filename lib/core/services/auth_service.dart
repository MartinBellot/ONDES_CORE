import 'dart:io';
import 'package:dio/dio.dart';
import 'configuration_service.dart';
import 'e2ee_service.dart';
import 'secure_storage_service.dart';
import '../utils/logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String _baseUrl = ConfigurationService().apiBaseUrl;
  final Dio _dio = Dio();
  
  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;
  String get baseUrl => _baseUrl;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    _token = await SecureStorageService().getAuthToken();
    if (_token != null) {
      await fetchProfile();
      if (_currentUser == null) {
        // Le token est expiré ou invalide (ex: 401) → supprimer le token local
        // pour que l'app affiche le LoginScreen dès le démarrage.
        AppLogger.error('AuthService', 'Token invalide ou expiré, nettoyage', null);
        _token = null;
        await SecureStorageService().deleteAuthToken();
      } else {
        // Initialiser E2EE seulement si le profil a bien été chargé
        await E2EEService().initialize();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/login/', data: {
        'username': username,
        'password': password,
      });
      
      _token = response.data['token'];
      await SecureStorageService().setAuthToken(_token!);
      
      await fetchProfile();
      
      // Initialiser E2EE automatiquement après login réussi
      await E2EEService().initialize();
      
      return true;
    } catch (e) {
      AppLogger.error('AuthService', 'Login failed', e);
      return false;
    }
  }

  Future<bool> register(String username, String password, String email) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/register/', data: {
        'username': username,
        'password': password,
        'email': email,
      });
      
      _token = response.data['token'];
      await SecureStorageService().setAuthToken(_token!);
      
      await fetchProfile();
      
      // Initialiser E2EE automatiquement après inscription réussie
      await E2EEService().initialize();
      
      return true;
    } catch (e) {
      AppLogger.error('AuthService', 'Register failed', e);
      return false;
    }
  }

  Future<void> fetchProfile() async {
    if (_token == null) return;
    try {
      final response = await _dio.get(
        '$_baseUrl/auth/profile/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      _currentUser = response.data;
    } catch (e) {
      AppLogger.error('AuthService', 'Profile fetch failed', e);
    }
  }

  Future<bool> updateProfile({String? bio, File? avatar}) async {
    if (_token == null) return false;
    try {
      FormData formData = FormData.fromMap({});
      if (bio != null) formData.fields.add(MapEntry('bio', bio));
      if (avatar != null) {
        formData.files.add(MapEntry(
          'avatar',
          await MultipartFile.fromFile(avatar.path, filename: 'avatar.jpg'),
        ));
      }

      final response = await _dio.put(
        '$_baseUrl/auth/profile/',
        data: formData,
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      _currentUser = response.data;
      return true;
    } catch (e) {
      AppLogger.error('AuthService', 'Update profile failed', e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> getDeveloperStats() async {
    if (_token == null) return null;
    try {
      final response = await _dio.get(
        '$_baseUrl/auth/stats/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return response.data;
    } catch (e) {
      AppLogger.error('AuthService', 'Get developer stats failed', e);
      return null;
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await SecureStorageService().deleteAuthToken();
    // Nettoyer les clés E2EE et les clés de conversation
    await E2EEService().clear();
    await SecureStorageService().deleteE2EEKeys();
    await SecureStorageService().deleteAllConversationKeys();
  }
}
