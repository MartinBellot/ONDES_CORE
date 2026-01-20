import '../bridge/js_bridge.dart';
import '../models/user_profile.dart';

/// User module for authentication and profile.
///
/// Get current user info and authentication status.
/// 
/// **SECURITY NOTE:** Direct token access has been removed for security reasons.
/// Malicious mini-apps could steal tokens and impersonate users. Use the 
/// provided bridge APIs (Social, Friends, Storage, etc.) which handle 
/// authentication internally and securely.
///
/// ## Example
/// ```dart
/// if (await Ondes.user.isAuthenticated()) {
///   final profile = await Ondes.user.getProfile();
///   print("Hello, ${profile?.username}!");
/// }
/// ```
class OndesUser {
  final OndesJsBridge _bridge;

  OndesUser(this._bridge);

  /// Gets the current user's profile.
  ///
  /// Returns `null` if not authenticated.
  Future<UserProfile?> getProfile() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.User.getProfile');
    if (result == null) return null;
    return UserProfile.fromJson(result);
  }

  // SECURITY: getAuthToken() has been removed.
  // 
  // Authentication tokens should NEVER be exposed to mini-apps as they could
  // be stolen by malicious apps and used to impersonate users.
  // 
  // Use the provided bridge APIs (Social, Friends, Storage, etc.) which
  // handle authentication internally and securely.

  /// Checks if the user is authenticated.
  Future<bool> isAuthenticated() async {
    final result = await _bridge.call<bool>('Ondes.User.isAuthenticated');
    return result ?? false;
  }
}
