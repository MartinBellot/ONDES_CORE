import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/services/permission_manager_service.dart';

/// Base class for all Ondes Bridge handlers
/// Each handler type (UI, User, Device, etc.) extends this class
abstract class BaseHandler {
  final BuildContext context;
  InAppWebViewController? _webViewController;
  
  // Sandbox Security
  String? _currentAppId;
  
  BaseHandler(this.context);

  void setAppId(String? appId) {
    _currentAppId = appId;
  }

  /// Set the WebView controller and register handlers
  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    registerHandlers();
  }

  /// Helper to enforce permission (Sandbox)
  /// Throws an error if permission is missing
  Future<void> requirePermission(String permission) async {
    if (_currentAppId == null) return; // Mode Lab/Debug
    
    final isGranted = PermissionManagerService().isPermissionGranted(_currentAppId!, permission);
    if (!isGranted) {
      print("🚫 [Sandbox] Permission denied: $permission for app $_currentAppId");
      
      // UX: Show Popup explanation
      // We run this in a microtask or just await it if we want to block
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text("Permission manquante"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Cette application tente d'accéder à :"),
              SizedBox(height: 8),
              Chip(label: Text(permission, style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(height: 16),
              Text("Cependant, cette permission n'est pas déclarée dans son fichier (manifest.json)."),
              SizedBox(height: 8),
              Text("Pour votre sécurité, l'action a été bloquée.", style: TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Compris"),
            ),
          ],
        ),
      );

      throw Exception("Ondes Sandbox Error: Permission '$permission' not granted in manifest.json");
    }
  }

  /// Get the current WebView controller
  InAppWebViewController? get webViewController => _webViewController;

  /// Register all JavaScript handlers for this module
  /// Override in subclasses to add specific handlers
  @protected
  void registerHandlers();

  /// Helper method to add a JavaScript handler
  @protected
  void addHandler(String name, Future<dynamic> Function(List<dynamic>) callback) {
    _webViewController?.addJavaScriptHandler(
      handlerName: name,
      callback: callback,
    );
  }

  /// Helper to add a sync handler (wrapped in async)
  @protected
  void addSyncHandler(String name, dynamic Function(List<dynamic>) callback) {
    _webViewController?.addJavaScriptHandler(
      handlerName: name,
      callback: (args) async => callback(args),
    );
  }
}
