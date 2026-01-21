import 'dart:async';
import '../bridge/js_bridge.dart';
import '../models/chat.dart';

/// Chat module for end-to-end encrypted messaging.
///
/// Provides real-time messaging with **automatic E2EE encryption**.
/// All messages are encrypted before sending and decrypted on receipt.
/// Developers work with plain text - encryption is transparent.
///
/// ## E2EE Security
/// - **Key Exchange:** X25519 (Curve25519)
/// - **Encryption:** AES-256-GCM
/// - **Authentication:** HMAC (built into GCM)
///
/// Keys are generated automatically at user login. No configuration needed.
///
/// ## Example
/// ```dart
/// // Initialize chat (connects WebSocket)
/// await Ondes.chat.init();
///
/// // Start a private conversation
/// final conv = await Ondes.chat.startChat('alice');
///
/// // Send a message (encrypted automatically)
/// await Ondes.chat.send(conv.id, 'Hello, Alice!');
///
/// // Listen for new messages (decrypted automatically)
/// Ondes.chat.onMessage((msg) {
///   print('${msg.sender}: ${msg.content}');
/// });
/// ```
class OndesChat {
  final OndesJsBridge _bridge;
  
  // Message callbacks
  final List<void Function(ChatMessage)> _messageCallbacks = [];
  final List<void Function(ChatTypingEvent)> _typingCallbacks = [];
  final List<void Function(ChatReceiptEvent)> _receiptCallbacks = [];
  final List<void Function(ChatConnectionStatus)> _connectionCallbacks = [];
  
  Timer? _pollTimer;
  bool _isPolling = false;

  OndesChat(this._bridge);

  // ============== INITIALIZATION ==============

  /// Initializes the chat service and connects to WebSocket.
  ///
  /// E2EE keys are already configured at login - this just establishes
  /// the real-time connection for message delivery.
  ///
  /// Returns `true` if connection successful.
  ///
  /// ```dart
  /// final result = await Ondes.chat.init();
  /// if (result) {
  ///   print('Chat ready!');
  /// }
  /// ```
  Future<bool> init() async {
    final result = await _bridge.call<Map<String, dynamic>>('Ondes.Chat.init');
    final success = result?['success'] as bool? ?? false;
    
    if (success) {
      _startPolling();
    }
    
    return success;
  }

  /// Disconnects from the chat service.
  Future<void> disconnect() async {
    _stopPolling();
    await _bridge.call('Ondes.Chat.disconnect');
  }

  /// Checks if the chat service is ready.
  Future<bool> isReady() async {
    final result = await _bridge.call<bool>('Ondes.Chat.isReady');
    return result ?? false;
  }

  // ============== CONVERSATIONS ==============

  /// Gets all conversations for the current user.
  ///
  /// Returns a list of conversations with last message preview (decrypted).
  ///
  /// ```dart
  /// final conversations = await Ondes.chat.getConversations();
  /// for (final conv in conversations) {
  ///   print('${conv.name}: ${conv.lastMessage?.content}');
  /// }
  /// ```
  Future<List<ChatConversation>> getConversations() async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Chat.getConversations');
    if (result == null) return [];
    
    return result
        .map((json) => ChatConversation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific conversation by ID.
  Future<ChatConversation?> getConversation(String conversationId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.getConversation',
      [conversationId],
    );
    if (result == null) return null;
    return ChatConversation.fromJson(result);
  }

  /// Starts a private conversation with a user.
  ///
  /// E2EE is configured automatically using X25519 key exchange.
  ///
  /// [user] can be a username (String) or user ID (int).
  ///
  /// ```dart
  /// // By username
  /// final conv = await Ondes.chat.startChat('alice');
  ///
  /// // By user ID
  /// final conv = await Ondes.chat.startChat(42);
  /// ```
  Future<ChatConversation?> startChat(dynamic user) async {
    final options = user is String 
        ? {'username': user} 
        : {'userId': user};
    
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.startPrivate',
      [options],
    );
    if (result == null) return null;
    return ChatConversation.fromJson(result);
  }

  /// Creates a group conversation.
  ///
  /// [members] can be usernames (String) or user IDs (int).
  ///
  /// ```dart
  /// final group = await Ondes.chat.createGroup(
  ///   'Project Team',
  ///   ['alice', 'bob', 42],
  /// );
  /// ```
  Future<ChatConversation?> createGroup(String name, List<dynamic> members) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.createGroup',
      [{'name': name, 'members': members}],
    );
    if (result == null) return null;
    return ChatConversation.fromJson(result);
  }

  // ============== MESSAGES ==============

  /// Sends a message to a conversation.
  ///
  /// The message is **automatically encrypted** before sending.
  /// Just pass plain text - the SDK handles E2EE.
  ///
  /// [options] can include:
  /// - `replyTo`: UUID of message to reply to
  /// - `type`: Message type ('text', 'image', etc.)
  ///
  /// ```dart
  /// // Simple message
  /// await Ondes.chat.send(conv.id, 'Hello!');
  ///
  /// // Reply to a message
  /// await Ondes.chat.send(conv.id, 'I agree!', replyTo: 'msg-uuid');
  /// ```
  Future<bool> send(
    String conversationId,
    String message, {
    String? replyTo,
    String type = 'text',
  }) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.send',
      [{
        'conversationId': conversationId,
        'message': message,
        if (replyTo != null) 'replyTo': replyTo,
        'type': type,
      }],
    );
    return result?['success'] as bool? ?? false;
  }

  /// Gets messages from a conversation.
  ///
  /// Messages are **automatically decrypted**.
  ///
  /// [limit]: Maximum number of messages (default: 50)
  /// [before]: UUID for pagination (get messages before this one)
  ///
  /// ```dart
  /// // Get latest 50 messages
  /// final messages = await Ondes.chat.getMessages(conv.id);
  ///
  /// // Pagination
  /// final older = await Ondes.chat.getMessages(
  ///   conv.id,
  ///   limit: 20,
  ///   before: messages.last.id,
  /// );
  /// ```
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final options = <String, dynamic>{
      'limit': limit,
      if (before != null) 'before': before,
    };
    
    final result = await _bridge.call<List<dynamic>>(
      'Ondes.Chat.getMessages',
      [conversationId, options],
    );
    if (result == null) return [];
    
    return result
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Edits an existing message.
  ///
  /// [conversationId] is optional but recommended for E2EE encryption.
  Future<bool> editMessage(
    String messageId,
    String newContent, {
    String? conversationId,
  }) async {
    final args = conversationId != null
        ? [messageId, newContent, conversationId]
        : [messageId, newContent];
    
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.editMessage',
      args,
    );
    return result?['success'] as bool? ?? false;
  }

  /// Deletes a message.
  Future<bool> deleteMessage(String messageId) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.deleteMessage',
      [messageId],
    );
    return result?['success'] as bool? ?? false;
  }

  /// Marks messages as read.
  Future<bool> markAsRead(List<String> messageIds) async {
    final result = await _bridge.call<Map<String, dynamic>>(
      'Ondes.Chat.markAsRead',
      [messageIds],
    );
    return result?['success'] as bool? ?? false;
  }

  // ============== TYPING INDICATOR ==============

  /// Sends a typing indicator.
  ///
  /// ```dart
  /// // User started typing
  /// await Ondes.chat.setTyping(conv.id, true);
  ///
  /// // User stopped typing
  /// await Ondes.chat.setTyping(conv.id, false);
  /// ```
  Future<void> setTyping(String conversationId, bool isTyping) async {
    await _bridge.call(
      'Ondes.Chat.typing',
      [conversationId, isTyping],
    );
  }

  // ============== EVENT LISTENERS ==============

  /// Listens for new messages.
  ///
  /// Messages are **automatically decrypted**.
  /// Returns a function to unsubscribe.
  ///
  /// ```dart
  /// final unsubscribe = Ondes.chat.onMessage((msg) {
  ///   print('${msg.sender}: ${msg.content}');
  /// });
  ///
  /// // Later, to stop listening:
  /// unsubscribe();
  /// ```
  void Function() onMessage(void Function(ChatMessage) callback) {
    _messageCallbacks.add(callback);
    return () => _messageCallbacks.remove(callback);
  }

  /// Listens for typing indicators.
  ///
  /// ```dart
  /// Ondes.chat.onTyping((event) {
  ///   if (event.isTyping) {
  ///     print('${event.username} is typing...');
  ///   }
  /// });
  /// ```
  void Function() onTyping(void Function(ChatTypingEvent) callback) {
    _typingCallbacks.add(callback);
    return () => _typingCallbacks.remove(callback);
  }

  /// Listens for read receipts.
  void Function() onReceipt(void Function(ChatReceiptEvent) callback) {
    _receiptCallbacks.add(callback);
    return () => _receiptCallbacks.remove(callback);
  }

  /// Listens for connection status changes.
  void Function() onConnectionChange(void Function(ChatConnectionStatus) callback) {
    _connectionCallbacks.add(callback);
    return () => _connectionCallbacks.remove(callback);
  }

  // ============== POLLING ==============

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      await _pollEvents();
    });
  }

  void _stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollEvents() async {
    try {
      // Poll messages
      final msgResult = await _bridge.call<Map<String, dynamic>>('Ondes.Chat.pollMessages');
      final messages = msgResult?['messages'] as List<dynamic>?;
      if (messages != null && messages.isNotEmpty) {
        for (final json in messages) {
          final msg = ChatMessage.fromJson(json as Map<String, dynamic>);
          for (final callback in _messageCallbacks) {
            callback(msg);
          }
        }
      }

      // Poll typing
      final typingResult = await _bridge.call<Map<String, dynamic>>('Ondes.Chat.pollTyping');
      final typing = typingResult?['typing'] as List<dynamic>?;
      if (typing != null && typing.isNotEmpty) {
        for (final json in typing) {
          final event = ChatTypingEvent.fromJson(json as Map<String, dynamic>);
          for (final callback in _typingCallbacks) {
            callback(event);
          }
        }
      }

      // Poll receipts
      final receiptResult = await _bridge.call<Map<String, dynamic>>('Ondes.Chat.pollReceipts');
      final receipts = receiptResult?['receipts'] as List<dynamic>?;
      if (receipts != null && receipts.isNotEmpty) {
        for (final json in receipts) {
          final event = ChatReceiptEvent.fromJson(json as Map<String, dynamic>);
          for (final callback in _receiptCallbacks) {
            callback(event);
          }
        }
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }
}
