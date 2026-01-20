import '../bridge/js_bridge.dart';
import '../models/user_profile.dart';

/// User module for authentication and profile.
///
/// Get current user info, auth token, and authentication status.
///
/// ## Example
/// ```dart
/// if (await Ondes.user.isAuthenticated()) {
///   final profile = await Ondes.user.getProfile();
///   print("Hello, ${profile?.username}!");
///
///   final token = await Ondes.user.getAuthToken();
///   // Use token for API requests
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

  /// Gets the authentication token for API requests.
  ///
  /// Returns `null` if not authenticated.
  Future<String?> getAuthToken() async {
    final result = await _bridge.call<String>('Ondes.User.getAuthToken');
    return result;
  }

  /// Checks if the user is authenticated.
  Future<bool> isAuthenticated() async {
    final result = await _bridge.call<bool>('Ondes.User.isAuthenticated');
    return result ?? false;
  }
}
