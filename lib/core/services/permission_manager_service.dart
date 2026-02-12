import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PermissionManagerService {
  static final PermissionManagerService _instance = PermissionManagerService._internal();
  factory PermissionManagerService() => _instance;
  PermissionManagerService._internal();

  // Cache: AppID -> List<GrantedPermissions>
  final Map<String, List<String>> _grantedPermissions = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadPermissions();
    _isInitialized = true;
  }

  Future<void> _loadPermissions() async {
    try {
      final file = await _getPermissionsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        data.forEach((key, value) {
          _grantedPermissions[key] = List<String>.from(value);
        });
      }
    } catch (e) {
      debugPrint("Error loading permissions: $e");
    }
  }

  Future<void> _savePermissions() async {
    try {
      final file = await _getPermissionsFile();
      await file.writeAsString(jsonEncode(_grantedPermissions));
    } catch (e) {
      debugPrint("Error saving permissions: $e");
    }
  }

  Future<File> _getPermissionsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/ondes_app_permissions.json');
  }

  /// Vérifie si l'utilisateur a déjà accepté les permissions pour cette app
  bool hasAcceptedManifest(String appId) {
    return _grantedPermissions.containsKey(appId);
  }

  /// Enregistre l'acceptation des permissions
  Future<void> grantPermissions(String appId, List<String> permissions) async {
    _grantedPermissions[appId] = permissions;
    await _savePermissions();
  }

  /// Appelle cette fonction pour révoquer (pour debug ou settings)
  Future<void> revokePermissions(String appId) async {
    _grantedPermissions.remove(appId);
    await _savePermissions();
  }

  /// Sandbox Check: Vérifie si une permission spécifique est active pour l'app
  bool isPermissionGranted(String appId, String permission) {
    // Si l'app n'a pas de permissions définies (ex: vieux manifest), on refuse par défaut en Sandbox strict
    // Sauf si la liste est vide (pas de permissions requises)
    if (!_grantedPermissions.containsKey(appId)) return false;
    
    return _grantedPermissions[appId]!.contains(permission);
  }
}
