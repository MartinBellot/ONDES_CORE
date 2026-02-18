import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/services/permission_manager_service.dart';
import '../../core/utils/logger.dart';

/// Base class for all Ondes Bridge handlers
/// Each handler type (UI, User, Device, etc.) extends this class
abstract class BaseHandler {
  final BuildContext context;
  InAppWebViewController? _webViewController;
  
  // Sandbox Security
  String? _currentAppId;
  List<String>? _labPermissions;
  
  BaseHandler(this.context);

  void setAppId(String? appId) {
    _currentAppId = appId;
  }

  void setLabPermissions(List<String>? permissions) {
    _labPermissions = permissions;
  }

  /// Set the WebView controller and register handlers
  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    registerHandlers();
  }

  /// Helper to enforce permission (Sandbox)
  /// Throws an error if permission is missing
  Future<void> requirePermission(String permission) async {
    // Mode Lab/Debug avec permissions définies
    if (_currentAppId == null) {
        // Si pas de permissions Lab définies, refuser par défaut (deny all)
        if (_labPermissions == null) {
           debugPrint("⚠️ [Lab] No permissions defined — denying '$permission'. Add a manifest.json with permissions.");
           throw Exception("Lab Error: No permissions defined. Add a manifest.json with a 'permissions' array.");
        }
        if (!_labPermissions!.contains(permission)) {
           debugPrint("⚠️ [Lab] Permission missing: $permission in manifest");
           await showDialog(
             context: context, 
             builder: (ctx) => AlertDialog(
               title: const Text("⚠️ Permission manquante (Lab)"),
               content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Votre code tente d'utiliser :"),
                    const SizedBox(height: 8),
                    Chip(label: Text(permission, style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16),
                    const Text("Cette permission n'est PAS déclarée dans le manifest.json de votre serveur de dev."),
                    const SizedBox(height: 8),
                    const Text("Ajoutez-la pour que cela fonctionne en production :"),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade200,
                      child: Text('"permissions": [\n  ...,\n  "$permission"\n]', style: const TextStyle(fontFamily: 'Courier', fontSize: 12)),
                    )
                  ],
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK, je vais l'ajouter"))
               ],
             )
           );
           // On ne bloque pas forcément en Lab, mais ici l'utilisateur a demandé d'indiquer les permissions manquantes.
           // On bloque pour forcer la bonne pratique ? 
           // Le prompt dit "indique les permissions qu'il doit ajouter".
           // Une popup c'est bien. On peut throw pour stopper l'exécution aussi, comme ça le dev voit que ça casse.
           throw Exception("Lab Error: Permission '$permission' missing in server manifest.json");
        }
        return; 
    }
    
    final isGranted = PermissionManagerService().isPermissionGranted(_currentAppId!, permission);
    if (!isGranted) {
      AppLogger.warning('Sandbox', 'Permission denied: $permission for app $_currentAppId');
      
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
