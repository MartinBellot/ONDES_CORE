import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
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
      // Basic profile info is public for installed apps
      final user = AuthService().currentUser;
      if (user != null) {
        String? avatarUrl = user['avatar'];
        if (avatarUrl != null && !avatarUrl.startsWith('http')) {
          avatarUrl = "${AuthService().baseUrl.replaceAll('/api', '')}$avatarUrl";
        }

        return {
          'id': user['id'].toString(),
          'username': user['username'],
          'email': user['email'],
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
