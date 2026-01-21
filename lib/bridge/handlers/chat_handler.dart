import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/e2ee_service.dart';
import 'base_handler.dart';

/// Handler for Ondes.Chat namespace
/// Manages end-to-end encrypted chat functionality
/// 
/// LE CHIFFREMENT E2EE EST 100% AUTOMATIQUE ET TRANSPARENT:
/// - Les clés sont générées automatiquement au LOGIN (via E2EEService)
/// - TOUS les utilisateurs ont une clé publique par défaut
/// - Pas de fallback nécessaire - X25519 fonctionne toujours
class ChatHandler extends BaseHandler {
  final ChatService _chatService = ChatService();
  final E2EEService _e2eeService = E2EEService();
  
  // Chiffrement E2EE toujours activé
  static const bool _encryptionEnabled = true;
  
  // AES-256-GCM pour le chiffrement des messages
  final _aesGcm = AesGcm.with256bits();
  
  // Cache des clés de conversation (dérivées via X25519)
  final Map<String, SecretKey> _conversationKeys = {};
  
  // Subscriptions for cleanup
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _receiptSubscription;
  StreamSubscription? _connectionSubscription;

  // Message queues for polling (like WebSocket handler)
  final List<Map<String, dynamic>> _globalMessageQueue = [];
  final List<Map<String, dynamic>> _globalTypingQueue = [];
  final List<Map<String, dynamic>> _globalReceiptQueue = [];
  
  ChatHandler(BuildContext context) : super(context);

  @override
  void registerHandlers() {
    // Initialisation (WebSocket uniquement - E2EE déjà fait au login)
    _registerInit();
    _registerDisconnect();
    
    // Conversations
    _registerGetConversations();
    _registerGetConversation();
    _registerStartPrivateChat();
    _registerCreateGroup();
    
    // Messages (chiffrement/déchiffrement automatique)
    _registerGetMessages();
    _registerSendMessage();
    _registerEditMessage();
    _registerDeleteMessage();
    _registerMarkAsRead();
    
    // Typing
    _registerSendTyping();
    
    // Polling pour les événements
    _registerPollMessages();
    _registerPollTyping();
    _registerPollReceipts();
  }

  // ============== E2EE CRYPTO (SIMPLIFIÉ) ==============

  /// Chiffre un message avec AES-256-GCM
  Future<String> _encrypt(String plaintext, SecretKey key) async {
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    
    // Format: nonce (12) + ciphertext + tag (16)
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    
    return base64Encode(combined);
  }

  /// Déchiffre un message avec AES-256-GCM
  Future<String> _decrypt(String encryptedBase64, SecretKey key) async {
    try {
      final combined = base64Decode(encryptedBase64);
      
      // Extraire nonce (12), ciphertext, et tag (16)
      final nonce = combined.sublist(0, 12);
      final cipherText = combined.sublist(12, combined.length - 16);
      final mac = combined.sublist(combined.length - 16);
      
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(mac),
      );
      
      final decrypted = await _aesGcm.decrypt(secretBox, secretKey: key);
      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('[ChatHandler] Decryption error: $e');
      return '[Erreur de déchiffrement]';
    }
  }

  /// Obtient la clé d'une conversation via X25519
  /// Tous les utilisateurs ont une clé publique (générée au login)
  Future<SecretKey> _getConversationKey(String conversationId) async {
    // Cache mémoire
    if (_conversationKeys.containsKey(conversationId)) {
      return _conversationKeys[conversationId]!;
    }
    
    // Cache persistant
    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'chat_conv_key_$conversationId';
    final storedKey = prefs.getString(storageKey);
    
    if (storedKey != null) {
      final keyBytes = base64Decode(storedKey);
      final convKey = SecretKey(keyBytes);
      _conversationKeys[conversationId] = convKey;
      return convKey;
    }
    
    // Dériver la clé via X25519 avec l'autre membre
    final conversation = await _chatService.getConversation(conversationId);
    final currentUser = AuthService().currentUser;
    final myId = currentUser?['id'] as int?;
    
    // Trouver l'autre membre
    ChatMember? otherMember;
    for (final member in conversation.members) {
      if (member.userId != myId) {
        otherMember = member;
        break;
      }
    }
    
    if (otherMember == null || otherMember.publicKey == null || otherMember.publicKey!.isEmpty) {
      throw Exception('Other member has no public key - this should not happen');
    }
    
    // Dériver le secret partagé X25519 (identique des deux côtés!)
    final sharedSecret = await _e2eeService.deriveSharedSecret(otherMember.publicKey!);
    
    // Mettre en cache et persister
    _conversationKeys[conversationId] = sharedSecret;
    final keyBytes = await sharedSecret.extractBytes();
    await prefs.setString(storageKey, base64Encode(keyBytes));
    
    debugPrint('[ChatHandler] ✅ Derived X25519 key for conversation $conversationId');
    return sharedSecret;
  }

  void _setupListeners() {
    // Écouter les messages entrants et les déchiffrer automatiquement
    _messageSubscription = _chatService.onMessage.listen((message) async {
      String content = '';
      
      if (message.isDeleted) {
        content = '[Message supprimé]';
      } else if (message.encryptedContent.isNotEmpty) {
        try {
          final key = await _getConversationKey(message.conversationUuid);
          content = await _decrypt(message.encryptedContent, key);
        } catch (e) {
          content = '[Impossible de déchiffrer]';
        }
      }
      
      final data = {
        'id': message.uuid,
        'conversationId': message.conversationUuid,
        'senderId': message.senderId,
        'sender': message.senderUsername,
        'content': content,  // ✅ Déjà déchiffré!
        'type': message.messageType,
        'createdAt': message.createdAt.toIso8601String(),
        'editedAt': message.editedAt?.toIso8601String(),
        'isDeleted': message.isDeleted,
        'replyTo': message.replyToUuid,
      };
      
      _globalMessageQueue.add(data);
    });

    // Écouter les indicateurs de frappe
    _typingSubscription = _chatService.onTyping.listen((data) {
      _globalTypingQueue.add({
        'conversationId': data['conversation_uuid'],
        'userId': data['user_id'],
        'username': data['username'],
        'isTyping': data['is_typing'],
      });
    });

    // Écouter les accusés de réception
    _receiptSubscription = _chatService.onReceipt.listen((data) {
      _globalReceiptQueue.add({
        'messageId': data['message_uuid'],
        'userId': data['user_id'],
        'readAt': data['timestamp'],
      });
    });

    // Écouter les changements de connexion
    _connectionSubscription = _chatService.onConnectionChange.listen((status) {
      debugPrint('[ChatHandler] Connection status: $status');
    });
  }

  // ============== INITIALISATION ==============

  void _registerInit() {
    addHandler('Ondes.Chat.init', (args) async {
      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      // Les clés E2EE sont déjà initialisées au login (via E2EEService)
      // Ici on connecte juste au WebSocket
      
      // Vérifier que E2EE est initialisé
      if (!_e2eeService.isInitialized) {
        debugPrint('[ChatHandler] ⚠️ E2EE not yet initialized, initializing now...');
        await _e2eeService.initialize();
      }
      
      // Connecter au WebSocket
      final connected = await _chatService.connect();
      
      if (connected) {
        _setupListeners();
      }
      
      return {
        'success': connected,
        'userId': AuthService().currentUser?['id'],
      };
    });
  }

  void _registerDisconnect() {
    addHandler('Ondes.Chat.disconnect', (args) async {
      _chatService.disconnect();
      _messageSubscription?.cancel();
      _typingSubscription?.cancel();
      _receiptSubscription?.cancel();
      _connectionSubscription?.cancel();
      return {'success': true};
    });
  }

  // ============== CONVERSATIONS ==============

  void _registerGetConversations() {
    addHandler('Ondes.Chat.getConversations', (args) async {
      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      final conversations = await _chatService.getConversations();
      
      return Future.wait(conversations.map((c) async {
        String? lastMessageContent;
        if (c.lastMessage != null && !c.lastMessage!.isDeleted) {
          try {
            final key = await _getConversationKey(c.uuid);
            lastMessageContent = await _decrypt(c.lastMessage!.encryptedContent, key);
          } catch (e) {
            lastMessageContent = '[Message chiffré]';
          }
        }
        
        String displayName = c.name.isNotEmpty ? c.name : c.members.map((m) => m.username).join(', ');
        
        return {
          'id': c.uuid,
          'name': displayName,
          'type': c.conversationType,
          'avatar': c.avatar,
          'members': c.members.map((m) => <String, dynamic>{
              'id': m.userId,
              'username': m.username,
              'avatar': m.avatar,
          }).toList(),
          'lastMessage': c.lastMessage != null ? {
            'content': lastMessageContent,
            'sender': c.lastMessage!.senderUsername,
            'createdAt': c.lastMessage!.createdAt.toIso8601String(),
          } : null,
          'unreadCount': c.unreadCount,
          'updatedAt': c.updatedAt.toIso8601String(),
        };
      }));
    });
  }

  void _registerGetConversation() {
    addHandler('Ondes.Chat.getConversation', (args) async {
      if (args.isEmpty) throw Exception('conversationId required');
      
      final uuid = args[0] as String;
      final conversation = await _chatService.getConversation(uuid);
      
      return {
        'id': conversation.uuid,
        'name': conversation.name,
        'type': conversation.conversationType,
        'members': conversation.members.map((m) => <String, dynamic>{
            'id': m.userId,
            'username': m.username,
            'avatar': m.avatar,
        }).toList(),
      };
    });
  }

  void _registerStartPrivateChat() {
    addHandler('Ondes.Chat.startPrivate', (args) async {
      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) throw Exception('options required');
      
      final options = Map<String, dynamic>.from(args[0] as Map);
      final userId = options['userId'] as int?;
      final username = options['username'] as String?;
      
      if (userId == null && username == null) {
        throw Exception('userId or username required');
      }
      
      // Créer la conversation d'abord
      final result = await _chatService.startPrivateConversation(
        userId: userId,
        username: username,
        encryptedKeys: {},
      );
      
      final conversation = result['conversation'] as Conversation;
      
      // Obtenir la clé via _getConversationKey (qui gère X25519 ou fallback déterministe)
      // Cela garantit que la même clé sera utilisée à chaque fois
      await _getConversationKey(conversation.uuid);
      
      String displayName = conversation.name.isNotEmpty ? conversation.name : conversation.members.map((m) => m.username).join(', ');
      
      return {
        'id': conversation.uuid,
        'name': displayName,
        'type': conversation.conversationType,
        'members': conversation.members.map((m) => <String, dynamic>{
            'id': m.userId,
            'username': m.username,
        }).toList(),
      };
    });
  }

  void _registerCreateGroup() {
    addHandler('Ondes.Chat.createGroup', (args) async {
      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) throw Exception('options required');
      
      final options = Map<String, dynamic>.from(args[0] as Map);
      final name = options['name'] as String;
      final members = options['members'] as List;
      
      // Convertir les membres en liste d'IDs
      final memberIds = members.map((m) {
        if (m is int) return m;
        if (m is String) return int.tryParse(m) ?? 0;
        return 0;
      }).where((id) => id > 0).toList().cast<int>();
      
      // Créer le groupe d'abord, puis obtenir la clé via _getConversationKey
      // Cela garantit la cohérence avec le système de dérivation
      final conversation = await _chatService.createGroup(
        name: name,
        memberIds: memberIds,
        encryptedKeys: {},
      );
      
      // Obtenir/dériver la clé (sera persistée automatiquement)
      await _getConversationKey(conversation.uuid);
      
      return {
        'id': conversation.uuid,
        'name': conversation.name,
        'type': 'group',
        'members': conversation.members.map((m) => <String, dynamic>{
            'id': m.userId,
            'username': m.username,
        }).toList(),
      };
    });
  }

  // ============== MESSAGES ==============

  void _registerGetMessages() {
    addHandler('Ondes.Chat.getMessages', (args) async {
      if (!AuthService().isAuthenticated) {
        throw Exception('User not authenticated');
      }
      
      if (args.isEmpty) throw Exception('conversationId required');
      
      final conversationId = args[0] as String;
      final options = args.length > 1 && args[1] is Map 
          ? Map<String, dynamic>.from(args[1] as Map) 
          : <String, dynamic>{};
      final limit = options['limit'] as int? ?? 50;
      final beforeId = options['before'] as String?;
      
      final messages = await _chatService.getMessages(
        conversationId,
        limit: limit,
        beforeUuid: beforeId,
      );
      
      // Obtenir la clé de conversation pour déchiffrer
      final key = await _getConversationKey(conversationId);
      
      // Déchiffrer tous les messages
      return Future.wait(messages.map((m) async {
        String content = '';
        if (m.isDeleted) {
          content = '[Message supprimé]';
        } else {
          try {
            content = await _decrypt(m.encryptedContent, key);
          } catch (e) {
            content = '[Erreur de déchiffrement]';
          }
        }
        
        return {
          'id': m.uuid,
          'conversationId': m.conversationUuid,
          'senderId': m.senderId,
          'sender': m.senderUsername,
          'content': content,  // ✅ Déjà déchiffré!
          'type': m.messageType,
          'createdAt': m.createdAt.toIso8601String(),
          'editedAt': m.editedAt?.toIso8601String(),
          'isDeleted': m.isDeleted,
          'replyTo': m.replyToUuid,
        };
      }));
    });
  }

  void _registerSendMessage() {
    addHandler('Ondes.Chat.send', (args) async {
      debugPrint('[ChatHandler] send called with args: $args');
      
      if (!_chatService.isConnected) {
        throw Exception('Chat not connected. Call Ondes.Chat.init() first.');
      }
      
      if (args.isEmpty) throw Exception('options required');
      
      final options = Map<String, dynamic>.from(args[0] as Map);
      final conversationId = options['conversationId'] as String;
      final message = options['message'] as String;  // ✅ Texte clair!
      final messageType = options['type'] as String? ?? 'text';
      final replyTo = options['replyTo'] as String?;
      
      debugPrint('[ChatHandler] Sending to $conversationId: $message');
      
      // Obtenir la clé et chiffrer automatiquement
      final key = await _getConversationKey(conversationId);
      final encryptedContent = await _encrypt(message, key);
      
      debugPrint('[ChatHandler] Encrypted content length: ${encryptedContent.length}');
      
      _chatService.sendMessage(
        conversationUuid: conversationId,
        encryptedContent: encryptedContent,
        messageType: messageType,
        replyToUuid: replyTo,
      );
      
      debugPrint('[ChatHandler] Message sent via WebSocket');
      
      return {'success': true};
    });
  }

  void _registerEditMessage() {
    addHandler('Ondes.Chat.editMessage', (args) async {
      if (!_chatService.isConnected) {
        throw Exception('Chat not connected');
      }
      
      if (args.length < 2) {
        throw Exception('messageId and newContent required');
      }
      
      final messageId = args[0] as String;
      final newContent = args[1] as String;
      final conversationId = args.length > 2 ? args[2] as String : null;
      
      // Chiffrer le nouveau contenu si on a le conversationId
      String contentToSend = newContent;
      if (conversationId != null && _encryptionEnabled) {
        final key = await _getConversationKey(conversationId);
        contentToSend = await _encrypt(newContent, key);
      }
      
      _chatService.editMessage(messageId, contentToSend);
      
      return {'success': true};
    });
  }

  void _registerDeleteMessage() {
    addHandler('Ondes.Chat.deleteMessage', (args) async {
      if (!_chatService.isConnected) {
        throw Exception('Chat not connected');
      }
      
      if (args.isEmpty) throw Exception('messageId required');
      
      final messageId = args[0] as String;
      _chatService.deleteMessage(messageId);
      
      return {'success': true};
    });
  }

  void _registerMarkAsRead() {
    addHandler('Ondes.Chat.markAsRead', (args) async {
      if (!_chatService.isConnected) {
        throw Exception('Chat not connected');
      }
      
      if (args.isEmpty) throw Exception('messageIds required');
      
      final messageIds = (args[0] as List).cast<String>();
      _chatService.markAsRead(messageIds);
      
      return {'success': true};
    });
  }

  // ============== TYPING ==============

  void _registerSendTyping() {
    addHandler('Ondes.Chat.typing', (args) async {
      if (!_chatService.isConnected) {
        throw Exception('Chat not connected');
      }
      
      if (args.isEmpty) throw Exception('conversationId required');
      
      final conversationId = args[0] as String;
      final isTyping = args.length > 1 ? args[1] as bool : true;
      
      _chatService.sendTypingIndicator(conversationId, isTyping);
      
      return {'success': true};
    });
  }

  // ============== POLLING ==============

  void _registerPollMessages() {
    addHandler('Ondes.Chat.pollMessages', (args) async {
      final messages = List.from(_globalMessageQueue);
      _globalMessageQueue.clear();
      return {'messages': messages};
    });
  }

  void _registerPollTyping() {
    addHandler('Ondes.Chat.pollTyping', (args) async {
      final typing = List.from(_globalTypingQueue);
      _globalTypingQueue.clear();
      return {'typing': typing};
    });
  }

  void _registerPollReceipts() {
    addHandler('Ondes.Chat.pollReceipts', (args) async {
      final receipts = List.from(_globalReceiptQueue);
      _globalReceiptQueue.clear();
      return {'receipts': receipts};
    });
  }

  /// Cleanup subscriptions
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _receiptSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
