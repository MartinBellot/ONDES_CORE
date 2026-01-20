import '../bridge/js_bridge.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/social_user.dart';

/// Friends module for social relationships.
///
/// Manage friend lists, requests, blocks, and search users.
///
/// ## Example
/// ```dart
/// // Get friends list
/// final friends = await Ondes.friends.list();
///
/// // Send a friend request
/// await Ondes.friends.request(username: 'john_doe');
///
/// // Accept a pending request
/// final pending = await Ondes.friends.getPendingRequests();
/// if (pending.isNotEmpty) {
///   await Ondes.friends.accept(pending.first.id);
/// }
/// ```
class OndesFriends {
  final OndesJsBridge _bridge;

  OndesFriends(this._bridge);

  /// Gets the list of friends.
  Future<List<Friend>> list() async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Friends.list');
    return result
            ?.map((e) => Friend.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Sends a friend request.
  ///
  /// Provide either [username] or [userId].
  Future<FriendRequest> request({
    String? username,
    int? userId,
  }) async {
    if (username == null && userId == null) {
      throw const OndesBridgeException(
        code: 'INVALID_ARGUMENT',
        message: 'Either username or userId is required',
      );
    }

    final options = <String, dynamic>{};
    if (username != null) options['username'] = username;
    if (userId != null) options['userId'] = userId;

    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.request',
      [options],
    );
    return FriendRequest.fromJson(result ?? {});
  }

  /// Gets pending friend requests (received).
  Future<List<FriendRequest>> getPendingRequests() async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Friends.getPendingRequests',
    );
    return result
            ?.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Gets sent friend requests.
  Future<List<FriendRequest>> getSentRequests() async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Friends.getSentRequests',
    );
    return result
            ?.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Accepts a friend request.
  ///
  /// [friendshipId] The ID of the friendship request.
  Future<bool> accept(int friendshipId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.accept',
      [friendshipId],
    );
    return result?['success'] == true;
  }

  /// Rejects a friend request.
  ///
  /// [friendshipId] The ID of the friendship request.
  Future<bool> reject(int friendshipId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.reject',
      [friendshipId],
    );
    return result?['success'] == true;
  }

  /// Removes a friend.
  ///
  /// [friendshipId] The ID of the friendship.
  Future<bool> remove(int friendshipId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.remove',
      [friendshipId],
    );
    return result?['success'] == true;
  }

  /// Blocks a user.
  ///
  /// Provide either [username] or [userId].
  Future<bool> block({
    String? username,
    int? userId,
  }) async {
    if (username == null && userId == null) {
      throw const OndesBridgeException(
        code: 'INVALID_ARGUMENT',
        message: 'Either username or userId is required',
      );
    }

    final options = <String, dynamic>{};
    if (username != null) options['username'] = username;
    if (userId != null) options['userId'] = userId;

    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.block',
      [options],
    );
    return result?['success'] == true;
  }

  /// Unblocks a user.
  ///
  /// [userId] The ID of the user to unblock.
  Future<bool> unblock(int userId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Friends.unblock',
      [userId],
    );
    return result?['success'] == true;
  }

  /// Gets the list of blocked users.
  Future<List<Map<String, dynamic>>> getBlocked() async {
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Friends.getBlocked',
    );
    return result?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }

  /// Searches for users by query.
  ///
  /// [query] Search term (minimum 2 characters).
  Future<List<SocialUser>> search(String query) async {
    if (query.length < 2) {
      throw const OndesBridgeException(
        code: 'INVALID_ARGUMENT',
        message: 'Query must be at least 2 characters',
      );
    }

    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Friends.search',
      [query],
    );
    return result
            ?.map((e) => SocialUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Gets the count of pending friend requests.
  Future<int> getPendingCount() async {
    final result = await _bridge.call<int>('Ondes.Friends.getPendingCount');
    return result ?? 0;
  }
}
