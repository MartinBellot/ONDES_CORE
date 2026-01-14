import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../models/mini_app.dart';

class DevStudioService {
  static final DevStudioService _instance = DevStudioService._internal();
  factory DevStudioService() => _instance;
  DevStudioService._internal();

  final String _baseUrl = "http://127.0.0.1:8000/api/studio";
  final Dio _dio = Dio();

  String? get _token => AuthService().token;

  Future<List<MiniApp>> getMyApps() async {
    if (_token == null) return [];
    try {
      final response = await _dio.get(
        '$_baseUrl/apps/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      final List data = response.data;
      return data.map((json) => MiniApp.fromJson(json)).toList();
    } catch (e) {
      print("Get My Apps Error: $e");
      return [];
    }
  }

  Future<MiniApp?> createApp({
    required String name,
    required String bundleId,
    required String description,
    File? icon,
  }) async {
    if (_token == null) return null;
    try {
      FormData formData = FormData.fromMap({
        'name': name,
        'bundle_id': bundleId,
        'description': description,
      });

      if (icon != null) {
        formData.files.add(MapEntry(
          'icon',
          await MultipartFile.fromFile(icon.path, filename: 'icon.png'),
        ));
      }

      final response = await _dio.post(
        '$_baseUrl/apps/',
        data: formData,
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      
      // The API returns the created app JSON, but it won't have an ID unless we exposed it. 
      // The MiniApp.fromJson expects backend schema. 
      // Ensure backend Serializer includes 'id'.
      return MiniApp.fromJson(response.data);
    } catch (e) {
      print("Create App Error: $e");
      return null;
    }
  }

  Future<bool> uploadVersion({
    required int appId,
    required String versionNumber,
    required String releaseNotes,
    required String zipPath
  }) async {
    if (_token == null) return false;
    try {
      FormData formData = FormData.fromMap({
        'version_number': versionNumber,
        'release_notes': releaseNotes,
        'zip_file': await MultipartFile.fromFile(zipPath, filename: 'app_bundle.zip'),
      });

      await _dio.post(
        '$_baseUrl/apps/$appId/versions/',
        data: formData,
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return true;
    } catch (e) {
      print("Upload Version Error: $e");
      return false;
    }
  }

  Future<MiniApp?> updateApp({
    required int appId,
    String? name,
    String? description,
    File? icon,
  }) async {
    if (_token == null) return null;
    try {
      final map = <String, dynamic>{};
      if (name != null) map['name'] = name;
      if (description != null) map['description'] = description;
      
      FormData formData = FormData.fromMap(map);

      if (icon != null) {
        formData.files.add(MapEntry(
          'icon',
          await MultipartFile.fromFile(icon.path, filename: 'icon.png'),
        ));
      }

      final response = await _dio.patch(
        '$_baseUrl/apps/$appId/',
        data: formData,
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      
      return MiniApp.fromJson(response.data);
    } catch (e) {
      print("Update App Error: $e");
      return null;
    }
  }

  Future<bool> deleteApp(int appId) async {
    if (_token == null) return false;
    try {
      await _dio.delete(
        '$_baseUrl/apps/$appId/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return true;
    } catch (e) {
      print("Delete App Error: $e");
      return false;
    }
  }
}
