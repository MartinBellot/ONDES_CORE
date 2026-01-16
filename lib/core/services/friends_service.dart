import 'package:dio/dio.dart';
import 'auth_service.dart';

/// Model représentant un ami
class Friend {
  final int id;
  final String username;
  final String avatar;
  final String bio;
  final int friendshipId;
  final DateTime? friendsSince;

  Friend({
    required this.id,
    required this.username,
    required this.avatar,
    required this.bio,
    required this.friendshipId,
    this.friendsSince,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'] ?? '',
      bio: json['bio'] ?? '',
      friendshipId: json['friendship_id'],
      friendsSince: json['friends_since'] != null 
          ? DateTime.parse(json['friends_since']) 
          : null,
    );
  }
}

/// Model représentant une demande d'amitié
class FriendshipRequest {
  final int id;
  final Map<String, dynamic> fromUser;
  final Map<String, dynamic> toUser;
  final String status;
  final String statusDisplay;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  FriendshipRequest({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.status,
    required this.statusDisplay,
    required this.createdAt,
    this.acceptedAt,
  });

  factory FriendshipRequest.fromJson(Map<String, dynamic> json) {
    return FriendshipRequest(
      id: json['id'],
      fromUser: json['from_user'],
      toUser: json['to_user'],
      status: json['status'],
      statusDisplay: json['status_display'] ?? json['status'],
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt: json['accepted_at'] != null 
          ? DateTime.parse(json['accepted_at']) 
          : null,
    );
  }
}

/// Model pour les résultats de recherche d'utilisateurs
class UserSearchResult {
  final int id;
  final String username;
  final String avatar;
  final String bio;
  final String? friendshipStatus;
  final int? friendshipId;

  UserSearchResult({
    required this.id,
    required this.username,
    required this.avatar,
    required this.bio,
    this.friendshipStatus,
    this.friendshipId,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      username: json['username'],
      avatar: json['avatar'] ?? '',
      bio: json['bio'] ?? '',
      friendshipStatus: json['friendship_status'],
      friendshipId: json['friendship_id'],
    );
  }
}

/// Service pour gérer les amitiés via l'API
class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  final Dio _dio = Dio();

  String get _baseUrl => AuthService().baseUrl;
  
  Options get _authOptions => Options(
    headers: {'Authorization': 'Token ${AuthService().token}'},
  );

  /// Récupère la liste des amis
  Future<List<Friend>> getFriends() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/',
        options: _authOptions,
      );
      
      return (response.data as List)
          .map((json) => Friend.fromJson(json))
          .toList();
    } catch (e) {
      print('FriendsService.getFriends Error: $e');
      rethrow;
    }
  }

  /// Envoie une demande d'amitié par username
  Future<FriendshipRequest> sendRequest({String? username, int? userId}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (userId != null) data['user_id'] = userId;
      
      final response = await _dio.post(
        '$_baseUrl/friends/request/',
        data: data,
        options: _authOptions,
      );
      
      return FriendshipRequest.fromJson(response.data['friendship']);
    } catch (e) {
      print('FriendsService.sendRequest Error: $e');
      rethrow;
    }
  }

  /// Récupère les demandes d'amitié reçues en attente
  Future<List<FriendshipRequest>> getPendingRequests() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/pending/',
        options: _authOptions,
      );
      
      return (response.data['received'] as List)
          .map((json) => FriendshipRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('FriendsService.getPendingRequests Error: $e');
      rethrow;
    }
  }

  /// Récupère les demandes d'amitié envoyées
  Future<List<FriendshipRequest>> getSentRequests() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/sent/',
        options: _authOptions,
      );
      
      return (response.data['sent'] as List)
          .map((json) => FriendshipRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('FriendsService.getSentRequests Error: $e');
      rethrow;
    }
  }

  /// Accepte une demande d'amitié
  Future<FriendshipRequest> acceptRequest(int friendshipId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/friends/$friendshipId/accept/',
        options: _authOptions,
      );
      
      return FriendshipRequest.fromJson(response.data['friendship']);
    } catch (e) {
      print('FriendsService.acceptRequest Error: $e');
      rethrow;
    }
  }

  /// Refuse une demande d'amitié
  Future<void> rejectRequest(int friendshipId) async {
    try {
      await _dio.post(
        '$_baseUrl/friends/$friendshipId/reject/',
        options: _authOptions,
      );
    } catch (e) {
      print('FriendsService.rejectRequest Error: $e');
      rethrow;
    }
  }

  /// Supprime un ami
  Future<void> removeFriend(int friendshipId) async {
    try {
      await _dio.post(
        '$_baseUrl/friends/$friendshipId/remove/',
        options: _authOptions,
      );
    } catch (e) {
      print('FriendsService.removeFriend Error: $e');
      rethrow;
    }
  }

  /// Bloque un utilisateur
  Future<void> blockUser({String? username, int? userId}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (userId != null) data['user_id'] = userId;
      
      await _dio.post(
        '$_baseUrl/friends/block/',
        data: data,
        options: _authOptions,
      );
    } catch (e) {
      print('FriendsService.blockUser Error: $e');
      rethrow;
    }
  }

  /// Débloque un utilisateur
  Future<void> unblockUser(int userId) async {
    try {
      await _dio.post(
        '$_baseUrl/friends/unblock/',
        data: {'user_id': userId},
        options: _authOptions,
      );
    } catch (e) {
      print('FriendsService.unblockUser Error: $e');
      rethrow;
    }
  }

  /// Récupère la liste des utilisateurs bloqués
  Future<List<FriendshipRequest>> getBlockedUsers() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/blocked/',
        options: _authOptions,
      );
      
      return (response.data['blocked'] as List)
          .map((json) => FriendshipRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('FriendsService.getBlockedUsers Error: $e');
      rethrow;
    }
  }

  /// Recherche des utilisateurs
  Future<List<UserSearchResult>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/search/',
        queryParameters: {'q': query},
        options: _authOptions,
      );
      
      return (response.data as List)
          .map((json) => UserSearchResult.fromJson(json))
          .toList();
    } catch (e) {
      print('FriendsService.searchUsers Error: $e');
      rethrow;
    }
  }

  /// Compte le nombre de demandes en attente
  Future<int> getPendingCount() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/friends/pending/',
        options: _authOptions,
      );
      return response.data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
