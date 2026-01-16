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
    _registerGetAuthToken();
    _registerIsAuthenticated();
  }

  void _registerGetProfile() {
    addSyncHandler('Ondes.User.getProfile', (args) {
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

  void _registerGetAuthToken() {
    addSyncHandler('Ondes.User.getAuthToken', (args) {
      return AuthService().token;
    });
  }

  void _registerIsAuthenticated() {
    addSyncHandler('Ondes.User.isAuthenticated', (args) {
      return AuthService().isAuthenticated;
    });
  }
}
