import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String _baseUrl = "http://127.0.0.1:8000/api"; // Adjust for Android (10.0.2.2) if needed
  final Dio _dio = Dio();
  
  String? _token;
  Map<String, dynamic>? _currentUser;

  String? get token => _token;
  String get baseUrl => _baseUrl;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      await fetchProfile();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _dio.post('$_baseUrl/auth/login/', data: {
        'username': username,
        'password': password,
      });
      
      _token = response.data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      
      await fetchProfile();
      return true;
    } catch (e) {
      print("Login Error: $e");
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      
      await fetchProfile();
      return true;
    } catch (e) {
      print("Register Error: $e");
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
      print("Profile Error: $e");
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
      print("Update Profile Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}
