import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/permission_manager_service.dart';

class PermissionRequestScreen extends StatelessWidget {
  final MiniApp app;
  final VoidCallback onAccepted;
  final VoidCallback onDenied;

  const PermissionRequestScreen({
    Key? key,
    required this.app,
    required this.onAccepted,
    required this.onDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child:
    Stack(
      children: [
        // Background Blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.6),
          ),
        ),
        
        // Modal
        Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Column(
                  children: [
                    if (app.iconUrl.isNotEmpty)
                      CircleAvatar(
                        backgroundImage: app.isInstalled && app.localPath != null
                          ? FileImage(File('${app.localPath!}/icon.png')) as ImageProvider
                          : NetworkImage(app.iconUrl),
                        radius: 30,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "requiert l'accès aux fonctionnalités suivantes",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Permissions List
                ...app.permissions.map((perm) => _buildPermissionRow(perm)),
                
                if (app.permissions.isEmpty)
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 20),
                     child: Text(
                       "Aucune permission spéciale requise",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                     ),
                   ),

                const SizedBox(height: 24),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onDenied,
                        child: Text(
                          "Annuler",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                           PermissionManagerService().grantPermissions(app.id, app.permissions);
                           onAccepted();
                        },
                        child: const Text(
                          "Accepter",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    )
    );
  }

  Widget _buildPermissionRow(String permission) {
    IconData icon;
    String label;
    String description;

    switch (permission) {
      case 'camera':
        icon = Icons.camera_alt;
        label = "Caméra";
        description = "Prendre des photos et vidéos";
        break;
      case 'microphone':
        icon = Icons.mic;
        label = "Microphone";
        description = "Enregistrer de l'audio";
        break;
      case 'location':
        icon = Icons.location_on;
        label = "Position";
        description = "Accéder à votre géolocalisation";
        break;
      case 'storage':
        icon = Icons.folder;
        label = "Stockage";
        description = "Lire et écrire des fichiers";
        break;
      case 'notifications':
        icon = Icons.notifications;
        label = "Notifications";
        description = "Vous envoyer des alertes";
        break;
      case 'contacts':
        icon = Icons.contacts;
        label = "Contacts";
        description = "Accéder à votre carnet d'adresses";
        break;
      case 'bluetooth':
        icon = Icons.bluetooth;
        label = "Bluetooth";
        description = "Se connecter aux appareils proches";
        break;
      default:
        icon = Icons.security;
        label = permission;
        description = "Permission requise par l'app";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.1),
               shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
