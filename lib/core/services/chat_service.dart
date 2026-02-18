import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

/// Représente une clé publique utilisateur pour E2EE
class UserPublicKey {
  final int userId;
  final String username;
  final String publicKey;
  final String keySignature;
  final int version;

  UserPublicKey({
    required this.userId,
    required this.username,
    required this.publicKey,
    required this.keySignature,
    required this.version,
  });

  factory UserPublicKey.fromJson(Map<String, dynamic> json) {
    return UserPublicKey(
      userId: json['user_id'],
      username: json['username'] ?? '',
      publicKey: json['public_key'],
      keySignature: json['key_signature'] ?? '',
      version: json['version'] ?? 1,
    );
  }
}

/// Représente un membre de conversation
class ChatMember {
  final int userId;
  final String username;
  final String? avatar;
  final String role;
  final String? publicKey;
  final String encryptedConversationKey;

  ChatMember({
    required this.userId,
    required this.username,
    this.avatar,
    required this.role,
    this.publicKey,
    required this.encryptedConversationKey,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      userId: json['user_id'],
      username: json['username'],
      avatar: json['avatar'],
      role: json['role'] ?? 'member',
      publicKey: json['public_key'],
      encryptedConversationKey: json['encrypted_conversation_key'] ?? '',
    );
  }
}

/// Représente un message (chiffré)
class ChatMessage {
  final String uuid;
  final String conversationUuid;
  final int? senderId;
  final String senderUsername;
  final String messageType;
  final String encryptedContent;
  final String? encryptedMetadata;
  final String? replyToUuid;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final Map<String, List<int>> receipts;

  ChatMessage({
    required this.uuid,
    required this.conversationUuid,
    this.senderId,
    required this.senderUsername,
    required this.messageType,
    required this.encryptedContent,
    this.encryptedMetadata,
    this.replyToUuid,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.receipts = const {},
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      uuid: json['uuid'],
      conversationUuid: json['conversation_uuid'] ?? '',
      senderId: json['sender_id'],
      senderUsername: json['sender_username'] ?? 'Unknown',
      messageType: json['message_type'] ?? 'text',
      encryptedContent: json['encrypted_content'] ?? '',
      encryptedMetadata: json['encrypted_metadata'],
      replyToUuid: json['reply_to_uuid'],
      createdAt: DateTime.parse(json['created_at']),
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      isDeleted: json['is_deleted'] ?? false,
      receipts: json['receipts'] != null ? {
        'delivered': List<int>.from(json['receipts']['delivered'] ?? []),
        'read': List<int>.from(json['receipts']['read'] ?? []),
      } : {},
    );
  }
}

/// Représente une conversation
class Conversation {
  final String uuid;
  final String name;
  final String conversationType;
  final String? avatar;
  final List<ChatMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.uuid,
    required this.name,
    required this.conversationType,
    this.avatar,
    required this.members,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      uuid: json['uuid'],
      name: json['name'] ?? '',
      conversationType: json['conversation_type'] ?? 'private',
      avatar: json['avatar'],
      members: (json['members'] as List?)
          ?.map((m) => ChatMember.fromJson(m))
          .toList() ?? [],
      lastMessage: json['last_message'] != null 
          ? ChatMessage.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  /// Obtenir le nom d'affichage (pour les DM, afficher le nom de l'autre utilisateur)
  String getDisplayName(int currentUserId) {
    if (conversationType == 'private') {
      final other = members.where((m) => m.userId != currentUserId).firstOrNull;
      return other?.username ?? name;
    }
    return name;
  }
}

/// Service principal pour le Chat E2EE
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final Dio _dio = Dio();
  WebSocketChannel? _wsChannel;
  
  String get _baseUrl => AuthService().baseUrl;
  String get _wsUrl => _baseUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');
  
  Options get _authOptions => Options(
    headers: {'Authorization': 'Token ${AuthService().token}'},
  );

  // Callbacks pour les événements temps réel
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _receiptController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<String>.broadcast();

  Stream<ChatMessage> get onMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onReceipt => _receiptController.stream;
  Stream<String> get onConnectionChange => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ============== GESTION DES CLÉS E2EE ==============

  /// Enregistrer sa clé publique
  Future<Map<String, dynamic>> registerPublicKey(String publicKey, {String? signature}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/keys/',
        data: {
          'public_key': publicKey,
          if (signature != null) 'key_signature': signature,
        },
        options: _authOptions,
      );
      return response.data;
    } catch (e) {
      AppLogger.error('ChatService', 'registerPublicKey failed', e);
      rethrow;
    }
  }

  /// Récupérer les clés publiques d'utilisateurs
  Future<List<UserPublicKey>> getPublicKeys(List<int> userIds) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/keys/public/',
        data: {'user_ids': userIds},
        options: _authOptions,
      );
      return (response.data as List)
          .map((json) => UserPublicKey.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('ChatService', 'getPublicKeys failed', e);
      rethrow;
    }
  }

  // ============== GESTION DES CONVERSATIONS ==============

  /// Récupérer toutes les conversations
  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/chat/conversations/',
        options: _authOptions,
      );
      return (response.data as List)
          .map((json) => Conversation.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('ChatService', 'getConversations failed', e);
      rethrow;
    }
  }

  /// Récupérer une conversation spécifique
  Future<Conversation> getConversation(String uuid) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/chat/conversations/$uuid/',
        options: _authOptions,
      );
      return Conversation.fromJson(response.data);
    } catch (e) {
      AppLogger.error('ChatService', 'getConversation failed', e);
      rethrow;
    }
  }

  /// Démarrer une conversation privée
  Future<Map<String, dynamic>> startPrivateConversation({
    int? userId,
    String? username,
    required Map<String, String> encryptedKeys,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/dm/',
        data: {
          if (userId != null) 'user_id': userId,
          if (username != null) 'username': username,
          'encrypted_keys': encryptedKeys,
        },
        options: _authOptions,
      );
      return {
        'created': response.data['created'],
        'conversation': Conversation.fromJson(response.data['conversation']),
      };
    } catch (e) {
      AppLogger.error('ChatService', 'startPrivateConversation failed', e);
      rethrow;
    }
  }

  /// Créer un groupe
  Future<Conversation> createGroup({
    required String name,
    required List<int> memberIds,
    required Map<String, String> encryptedKeys,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/conversations/',
        data: {
          'conversation_type': 'group',
          'name': name,
          'member_ids': memberIds,
          'encrypted_keys': encryptedKeys,
        },
        options: _authOptions,
      );
      return Conversation.fromJson(response.data);
    } catch (e) {
      AppLogger.error('ChatService', 'createGroup failed', e);
      rethrow;
    }
  }

  /// Récupérer les messages d'une conversation
  Future<List<ChatMessage>> getMessages(String conversationUuid, {
    int limit = 50,
    String? beforeUuid,
  }) async {
    try {
      final params = {'limit': limit.toString()};
      if (beforeUuid != null) params['before'] = beforeUuid;
      
      final response = await _dio.get(
        '$_baseUrl/chat/conversations/$conversationUuid/messages/',
        queryParameters: params,
        options: _authOptions,
      );
      return (response.data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('ChatService', 'getMessages failed', e);
      rethrow;
    }
  }

  // ============== WEBSOCKET TEMPS RÉEL ==============

  /// Se connecter au WebSocket Chat
  Future<bool> connect() async {
    if (_isConnected) return true;
    
    try {
      final token = AuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Sécurisation : ne pas envoyer le token dans l'URL
      // On se connecte d'abord, puis on s'authentifie dans le premier message
      final wsUri = Uri.parse('$_wsUrl/ws/chat/');
      _wsChannel = WebSocketChannel.connect(wsUri);
      
      await _wsChannel!.ready;
      
      // Authentification via le premier message WebSocket (pas dans l'URL)
      _wsChannel!.sink.add(jsonEncode({
        'action': 'authenticate',
        'data': {'token': token},
      }));
      
      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClosed,
      );

      _isConnected = true;
      _connectionController.add('connected');
      AppLogger.success('ChatService', 'WebSocket connected');
      
      return true;
    } catch (e) {
      AppLogger.error('ChatService', 'WebSocket connection failed', e);
      _isConnected = false;
      _connectionController.add('error');
      return false;
    }
  }

  /// Se déconnecter du WebSocket
  void disconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _connectionController.add('disconnected');
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      AppLogger.debug('ChatService', 'WebSocket received message');
      final message = jsonDecode(data.toString()) as Map<String, dynamic>;
      final type = message['type'];
      AppLogger.debug('ChatService', 'Message type: $type');

      switch (type) {
        case 'new_message':
          AppLogger.debug('ChatService', 'New message received');
          final msg = ChatMessage.fromJson(message['message']);
          _messageController.add(msg);
          break;
        case 'typing':
          _typingController.add(message['data']);
          break;
        case 'receipt':
          _receiptController.add(message['data']);
          break;
        case 'message_edited':
          // Émettre comme un message avec flag edit
          _messageController.add(ChatMessage(
            uuid: message['data']['message_uuid'],
            conversationUuid: '',
            senderUsername: '',
            messageType: 'edit',
            encryptedContent: message['data']['encrypted_content'],
            createdAt: DateTime.now(),
            editedAt: DateTime.parse(message['data']['edited_at']),
          ));
          break;
        case 'message_deleted':
          _messageController.add(ChatMessage(
            uuid: message['data']['message_uuid'],
            conversationUuid: '',
            senderUsername: '',
            messageType: 'delete',
            encryptedContent: '',
            createdAt: DateTime.now(),
            isDeleted: true,
          ));
          break;
        case 'connection_established':
          AppLogger.success('ChatService', 'Connected as ${message['username']}');
          break;
        case 'error':
          AppLogger.error('ChatService', 'Server error: ${message['message']}');
          break;
      }
    } catch (e) {
      AppLogger.error('ChatService', 'Error parsing message', e);
    }
  }

  void _handleWebSocketError(error) {
    AppLogger.error('ChatService', 'WebSocket error', error);
    _isConnected = false;
    _connectionController.add('error');
  }

  void _handleWebSocketClosed() {
    AppLogger.info('ChatService', 'WebSocket closed');
    _isConnected = false;
    _connectionController.add('disconnected');
  }

  /// Envoyer une action WebSocket
  void _sendAction(String action, Map<String, dynamic> data) {
    if (!_isConnected || _wsChannel == null) {
      throw Exception('WebSocket not connected');
    }
    _wsChannel!.sink.add(jsonEncode({
      'action': action,
      'data': data,
    }));
  }

  /// Envoyer un message chiffré
  void sendMessage({
    required String conversationUuid,
    required String encryptedContent,
    String messageType = 'text',
    String? encryptedMetadata,
    String? replyToUuid,
  }) {
    _sendAction('send_message', {
      'conversation_uuid': conversationUuid,
      'encrypted_content': encryptedContent,
      'message_type': messageType,
      if (encryptedMetadata != null) 'encrypted_metadata': encryptedMetadata,
      if (replyToUuid != null) 'reply_to_uuid': replyToUuid,
    });
  }

  /// Envoyer un indicateur de frappe
  void sendTypingIndicator(String conversationUuid, bool isTyping) {
    _sendAction('typing', {
      'conversation_uuid': conversationUuid,
      'is_typing': isTyping,
    });
  }

  /// Marquer des messages comme lus
  void markAsRead(List<String> messageUuids) {
    _sendAction('read_receipt', {
      'message_uuids': messageUuids,
    });
  }

  /// Modifier un message
  void editMessage(String messageUuid, String encryptedContent) {
    _sendAction('edit_message', {
      'message_uuid': messageUuid,
      'encrypted_content': encryptedContent,
    });
  }

  /// Supprimer un message
  void deleteMessage(String messageUuid) {
    _sendAction('delete_message', {
      'message_uuid': messageUuid,
    });
  }

  /// Récupérer l'historique via WebSocket
  void requestHistory(String conversationUuid, {int limit = 50, String? beforeUuid}) {
    _sendAction('get_messages', {
      'conversation_uuid': conversationUuid,
      'limit': limit,
      if (beforeUuid != null) 'before_uuid': beforeUuid,
    });
  }

  /// Rejoindre une conversation
  void joinConversation(String conversationUuid) {
    _sendAction('join_conversation', {
      'conversation_uuid': conversationUuid,
    });
  }

  /// Libérer les ressources
  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _receiptController.close();
    _connectionController.close();
  }
}
