import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/configuration_service.dart';
import 'base_handler.dart';

/// Handler for Ondes.User namespace
/// Manages user profile and authentication
class UserHandler extends BaseHandler {
  UserHandler(BuildContext context) : super(context);

  @override
  void registerHandlers() {
    _registerGetProfile();
    _registerIsAuthenticated();
  }

  void _registerGetProfile() {
    addHandler('Ondes.User.getProfile', (args) async {
      // Profil basique sans PII (pas d'email) — accessible par les apps installées
      final user = AuthService().currentUser;
      if (user != null) {
        String? avatarUrl = user['avatar'];
        if (avatarUrl != null && !avatarUrl.startsWith('http')) {
          avatarUrl = "${ConfigurationService().baseUrl}$avatarUrl";
        }

        return {
          'id': user['id'].toString(),
          'username': user['username'],
          'avatar': avatarUrl ?? 
              'https://api.dicebear.com/7.x/avataaars/png?seed=${user['username']}',
          'bio': user['bio'] ?? "",
        };
      }
      return null;
    });
  }

  void _registerIsAuthenticated() {
    addSyncHandler('Ondes.User.isAuthenticated', (args) {
      return AuthService().isAuthenticated;
    });
  }
}
