import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/permission_manager_service.dart';
import '../../core/services/app_library_service.dart';

class PermissionManagementScreen extends StatefulWidget {
  const PermissionManagementScreen({super.key});

  @override
  State<PermissionManagementScreen> createState() => _PermissionManagementScreenState();
}

class _PermissionManagementScreenState extends State<PermissionManagementScreen> {
  final _permissionService = PermissionManagerService();
  final _libraryService = AppLibraryService();
  
  List<String> _appIds = [];
  Map<String, MiniApp> _appDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // 1. Get IDs with permissions
    final ids = _permissionService.getGrantedApps();
    
    // 2. Resolve Apps details
    final installedApps = await _libraryService.getInstalledApps();
    final Map<String, MiniApp> detailsMap = {};
    
    for (var app in installedApps) {
      if (ids.contains(app.id)) {
        detailsMap[app.id] = app;
      }
    }

    if (mounted) {
      setState(() {
        _appIds = ids;
        _appDetails = detailsMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeForApp(String appId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Révoquer les permissions ?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "L'application ne pourra plus accéder aux fonctionnalités sensibles jusqu'à ce que vous les autorisiez à nouveau.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Révoquer", style: TextStyle(color: Colors.red)),
          )
        ],
      )
    );

    if (confirmed == true) {
      await _permissionService.revokePermissions(appId);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permissions révoquées"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Gestion des Permissions"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _appIds.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _appIds.length,
              itemBuilder: (context, index) {
                final appId = _appIds[index];
                return _buildAppItem(appId);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security, size: 60, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          Text(
            "Aucune permission accordée",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(String appId) {
    final app = _appDetails[appId];
    final permissions = _permissionService.getPermissionsForApp(appId);
    final name = app?.name ?? appId; // Fallback to ID if not found (e.g. uninstalled but permission kept)
    final iconPath = app?.iconUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
            image: (iconPath != null && iconPath.isNotEmpty)
                ? DecorationImage(image: FileImage(File(iconPath)), fit: BoxFit.cover)
                : null
          ),
          child: (iconPath == null || iconPath.isEmpty) 
              ? const Icon(Icons.extension, color: Colors.white54)
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "${permissions.length} permissions",
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(color: Colors.white10),
          ...permissions.map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(_getPermissionIcon(p), size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(p, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _revokeForApp(appId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text("Révoquer l'accès"),
            ),
          )
        ],
      ),
    );
  }

  IconData _getPermissionIcon(String permission) {
    switch (permission.toLowerCase()) {
      case 'camera': return Icons.camera_alt;
      case 'microphone': return Icons.mic;
      case 'location': return Icons.location_on;
      case 'storage': return Icons.folder;
      case 'notifications': return Icons.notifications;
      case 'contacts': return Icons.contacts;
      case 'user': return Icons.person;
      case 'social': return Icons.share;
      default: return Icons.security;
    }
  }
}
