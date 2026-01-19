import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'configuration_service.dart';
import '../models/mini_app.dart';

class DevStudioService {
  static final DevStudioService _instance = DevStudioService._internal();
  factory DevStudioService() => _instance;
  DevStudioService._internal();

  final String _baseUrl = "${ConfigurationService().apiBaseUrl}/studio";
  final String _apiUrl = ConfigurationService().apiBaseUrl;
  final Dio _dio = Dio();

  String? get _token => AuthService().token;

  /// Récupère les catégories disponibles
  Future<List<AppCategory>> getCategories() async {
    try {
      final response = await _dio.get('$_apiUrl/categories/');
      final List data = response.data;
      return data.map((json) => AppCategory.fromJson(json)).toList();
    } catch (e) {
      print("Get Categories Error: $e");
      return [];
    }
  }

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
    String? fullDescription,
    String? whatsNew,
    int? categoryId,
    String? ageRating,
    String? privacyUrl,
    String? supportUrl,
    String? websiteUrl,
    List<String>? languages,
    List<String>? tags,
    File? icon,
    File? banner,
  }) async {
    if (_token == null) return null;
    try {
      final map = <String, dynamic>{};
      if (name != null) map['name'] = name;
      if (description != null) map['description'] = description;
      if (fullDescription != null) map['full_description'] = fullDescription;
      if (whatsNew != null) map['whats_new'] = whatsNew;
      if (categoryId != null) map['category'] = categoryId;
      if (ageRating != null) map['age_rating'] = ageRating;
      if (privacyUrl != null) map['privacy_policy_url'] = privacyUrl;
      if (supportUrl != null) map['support_url'] = supportUrl;
      if (websiteUrl != null) map['website_url'] = websiteUrl;
      if (languages != null) map['languages'] = languages.join(',');
      if (tags != null) map['tags'] = tags.join(',');
      
      FormData formData = FormData.fromMap(map);

      if (icon != null) {
        formData.files.add(MapEntry(
          'icon',
          await MultipartFile.fromFile(icon.path, filename: 'icon.png'),
        ));
      }
      
      if (banner != null) {
        formData.files.add(MapEntry(
          'banner',
          await MultipartFile.fromFile(banner.path, filename: 'banner.png'),
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

  /// Upload a screenshot for the app
  Future<bool> uploadScreenshot({
    required int appId,
    required File screenshot,
    int? order,
    String? caption,
    String? deviceType,
  }) async {
    if (_token == null) return false;
    try {
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(screenshot.path, filename: 'screenshot.png'),
        if (order != null) 'order': order,
        if (caption != null) 'caption': caption,
        if (deviceType != null) 'device_type': deviceType,
      });

      await _dio.post(
        '$_baseUrl/apps/$appId/screenshots/',
        data: formData,
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return true;
    } catch (e) {
      print("Upload Screenshot Error: $e");
      return false;
    }
  }

  /// Delete a screenshot
  Future<bool> deleteScreenshot({required int appId, required int screenshotId}) async {
    if (_token == null) return false;
    try {
      await _dio.delete(
        '$_baseUrl/apps/$appId/screenshots/$screenshotId/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return true;
    } catch (e) {
      print("Delete Screenshot Error: $e");
      return false;
    }
  }

  /// Get detailed app info (with screenshots, etc.)
  Future<MiniApp?> getAppDetail(int appId) async {
    if (_token == null) return null;
    try {
      final response = await _dio.get(
        '$_baseUrl/apps/$appId/',
        options: Options(headers: {'Authorization': 'Token $_token'}),
      );
      return MiniApp.fromDetailJson(response.data);
    } catch (e) {
      print("Get App Detail Error: $e");
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
