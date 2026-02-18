import 'package:flutter/material.dart';
import '../../core/services/friends_service.dart';
import '../../core/services/auth_service.dart';
import 'base_handler.dart';

/// Handler for Ondes.Friends namespace
/// Manages friend relationships via the Django API
class FriendsHandler extends BaseHandler {
  final FriendsService _friendsService = FriendsService();

  FriendsHandler(BuildContext context) : super(context);

  @override
  void registerHandlers() {
    _registerGetFriends();
    _registerSendRequest();
    _registerGetPendingRequests();
    _registerGetSentRequests();
    _registerAcceptRequest();
    _registerRejectRequest();
    _registerRemoveFriend();
    _registerBlockUser();
    _registerUnblockUser();
    _registerGetBlockedUsers();
    _registerSearchUsers();
    _registerGetPendingCount();
  }

  /// Ondes.Friends.list() - Récupère la liste des amis
  void _registerGetFriends() {
    addHandler('Ondes.Friends.list', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final friends = await _friendsService.getFriends();
      return friends.map((f) => {
        'id': f.id,
        'username': f.username,
        'avatar': f.avatar,
        'bio': f.bio,
        'friendshipId': f.friendshipId,
        'friendsSince': f.friendsSince?.toIso8601String(),
      }).toList();
    });
  }

  /// Ondes.Friends.request(options) - Envoie une demande d'amitié
  /// options: { username: string } ou { userId: number }
  void _registerSendRequest() {
    addHandler('Ondes.Friends.request', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final username = options['username'] as String?;
      final userId = options['userId'] as int?;
      
      if (username == null && userId == null) {
        throw Exception('username or userId required');
      }
      
      final request = await _friendsService.sendRequest(
        username: username,
        userId: userId,
      );
      
      return {
        'id': request.id,
        'status': request.status,
        'toUser': request.toUser,
        'createdAt': request.createdAt.toIso8601String(),
      };
    });
  }

  /// Ondes.Friends.getPendingRequests() - Récupère les demandes reçues en attente
  void _registerGetPendingRequests() {
    addHandler('Ondes.Friends.getPendingRequests', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final requests = await _friendsService.getPendingRequests();
      return requests.map((r) => {
        'id': r.id,
        'fromUser': r.fromUser,
        'status': r.status,
        'createdAt': r.createdAt.toIso8601String(),
      }).toList();
    });
  }

  /// Ondes.Friends.getSentRequests() - Récupère les demandes envoyées
  void _registerGetSentRequests() {
    addHandler('Ondes.Friends.getSentRequests', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final requests = await _friendsService.getSentRequests();
      return requests.map((r) => {
        'id': r.id,
        'toUser': r.toUser,
        'status': r.status,
        'createdAt': r.createdAt.toIso8601String(),
      }).toList();
    });
  }

  /// Ondes.Friends.accept(friendshipId) - Accepte une demande
  void _registerAcceptRequest() {
    addHandler('Ondes.Friends.accept', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) {
        throw Exception('friendshipId required');
      }
      
      final friendshipId = args[0] as int;
      final result = await _friendsService.acceptRequest(friendshipId);
      
      return {
        'success': true,
        'friendship': {
          'id': result.id,
          'status': result.status,
          'acceptedAt': result.acceptedAt?.toIso8601String(),
        },
      };
    });
  }

  /// Ondes.Friends.reject(friendshipId) - Refuse une demande
  void _registerRejectRequest() {
    addHandler('Ondes.Friends.reject', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) {
        throw Exception('friendshipId required');
      }
      
      final friendshipId = args[0] as int;
      await _friendsService.rejectRequest(friendshipId);
      
      return {'success': true};
    });
  }

  /// Ondes.Friends.remove(friendshipId) - Supprime un ami
  void _registerRemoveFriend() {
    addHandler('Ondes.Friends.remove', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) {
        throw Exception('friendshipId required');
      }
      
      final friendshipId = args[0] as int;
      await _friendsService.removeFriend(friendshipId);
      
      return {'success': true};
    });
  }

  /// Ondes.Friends.block(options) - Bloque un utilisateur
  /// options: { username: string } ou { userId: number }
  void _registerBlockUser() {
    addHandler('Ondes.Friends.block', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final options = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
      final username = options['username'] as String?;
      final userId = options['userId'] as int?;
      
      if (username == null && userId == null) {
        throw Exception('username or userId required');
      }
      
      await _friendsService.blockUser(username: username, userId: userId);
      
      return {'success': true};
    });
  }

  /// Ondes.Friends.unblock(userId) - Débloque un utilisateur
  void _registerUnblockUser() {
    addHandler('Ondes.Friends.unblock', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) {
        throw Exception('userId required');
      }
      
      final userId = args[0] as int;
      await _friendsService.unblockUser(userId);
      
      return {'success': true};
    });
  }

  /// Ondes.Friends.getBlocked() - Récupère les utilisateurs bloqués
  void _registerGetBlockedUsers() {
    addHandler('Ondes.Friends.getBlocked', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final blocked = await _friendsService.getBlockedUsers();
      return blocked.map((r) => {
        'id': r.id,
        'user': r.toUser,
        'blockedAt': r.createdAt.toIso8601String(),
      }).toList();
    });
  }

  /// Ondes.Friends.search(query) - Recherche des utilisateurs
  void _registerSearchUsers() {
    addHandler('Ondes.Friends.search', (args) async {
      await requirePermission('friends');

      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) {
        throw Exception('Search query required');
      }
      
      final query = args[0] as String;
      if (query.length < 2) {
        throw Exception('Query must be at least 2 characters');
      }
      
      final results = await _friendsService.searchUsers(query);
      return results.map((u) => {
        'id': u.id,
        'username': u.username,
        'avatar': u.avatar,
        'bio': u.bio,
        'friendshipStatus': u.friendshipStatus,
        'friendshipId': u.friendshipId,
      }).toList();
    });
  }

  /// Ondes.Friends.getPendingCount() - Compte les demandes en attente
  void _registerGetPendingCount() {
    addHandler('Ondes.Friends.getPendingCount', (args) async {
      if (!AuthService().isAuthenticated) {
        return 0;
      }
      
      return await _friendsService.getPendingCount();
    });
  }
}
