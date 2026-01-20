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
    // _registerGetAuthToken() - REMOVED for security: tokens should not be exposed to mini-apps
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

  // SECURITY: Removed getAuthToken() method
  // Authentication tokens should NEVER be exposed to mini-apps as they could
  // be stolen by malicious apps and used to impersonate users.
  // Mini-apps should use the provided bridge APIs (Social, Friends, etc.) 
  // which handle authentication internally.
  //
  // void _registerGetAuthToken() {
  //   addSyncHandler('Ondes.User.getAuthToken', (args) {
  //     return AuthService().token;
  //   });
  // }

  void _registerIsAuthenticated() {
    addSyncHandler('Ondes.User.isAuthenticated', (args) {
      return AuthService().isAuthenticated;
    });
  }
}
