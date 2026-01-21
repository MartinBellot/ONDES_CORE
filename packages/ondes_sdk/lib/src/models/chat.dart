// Models for the Chat module.

/// Represents a chat conversation member.
class ChatMember {
  /// User ID.
  final int id;

  /// Username.
  final String username;

  /// Avatar URL.
  final String? avatar;

  ChatMember({
    required this.id,
    required this.username,
    this.avatar,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      avatar: json['avatar'] as String?,
    );
  }
}

/// Represents a chat conversation.
class ChatConversation {
  /// Unique UUID of the conversation.
  final String id;

  /// Display name (for groups or derived from members).
  final String name;

  /// Type: 'private' or 'group'.
  final String type;

  /// Avatar URL (for groups).
  final String? avatar;

  /// List of members.
  final List<ChatMember> members;

  /// Last message in the conversation.
  final ChatLastMessage? lastMessage;

  /// Number of unread messages.
  final int unreadCount;

  /// Last update timestamp.
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.name,
    required this.type,
    this.avatar,
    required this.members,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      avatar: json['avatar'] as String?,
      members: (json['members'] as List?)
              ?.map((m) => ChatMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? ChatLastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Last message preview in a conversation.
class ChatLastMessage {
  /// Decrypted content.
  final String content;

  /// Sender username.
  final String sender;

  /// Creation timestamp.
  final DateTime createdAt;

  ChatLastMessage({
    required this.content,
    required this.sender,
    required this.createdAt,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatLastMessage(
      content: json['content'] as String,
      sender: json['sender'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Represents a chat message.
class ChatMessage {
  /// Unique UUID of the message.
  final String id;

  /// Conversation UUID.
  final String conversationId;

  /// Sender user ID.
  final int senderId;

  /// Sender username.
  final String sender;

  /// Decrypted message content.
  final String content;

  /// Message type ('text', 'image', etc.).
  final String type;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Edit timestamp (if edited).
  final DateTime? editedAt;

  /// Whether the message was deleted.
  final bool isDeleted;

  /// UUID of the message this replies to.
  final String? replyTo;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sender,
    required this.content,
    required this.type,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: (json['senderId'] as num).toInt(),
      sender: json['sender'] as String,
      content: json['content'] as String,
      type: json['type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      replyTo: json['replyTo'] as String?,
    );
  }
}

/// Typing indicator event.
class ChatTypingEvent {
  /// Conversation UUID.
  final String conversationId;

  /// User ID who is typing.
  final int userId;

  /// Username of the typer.
  final String username;

  /// Whether they are typing.
  final bool isTyping;

  ChatTypingEvent({
    required this.conversationId,
    required this.userId,
    required this.username,
    required this.isTyping,
  });

  factory ChatTypingEvent.fromJson(Map<String, dynamic> json) {
    return ChatTypingEvent(
      conversationId: json['conversationId'] as String,
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      isTyping: json['isTyping'] as bool,
    );
  }
}

/// Read receipt event.
class ChatReceiptEvent {
  /// Message UUID.
  final String messageId;

  /// User ID who read the message.
  final int userId;

  /// Timestamp when read.
  final DateTime readAt;

  ChatReceiptEvent({
    required this.messageId,
    required this.userId,
    required this.readAt,
  });

  factory ChatReceiptEvent.fromJson(Map<String, dynamic> json) {
    return ChatReceiptEvent(
      messageId: json['messageId'] as String,
      userId: (json['userId'] as num).toInt(),
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }
}

/// Connection status.
enum ChatConnectionStatus {
  connected,
  disconnected,
  error,
}
