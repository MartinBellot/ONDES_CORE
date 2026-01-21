# 🌊 Ondes SDK

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Flutter SDK for building mini-apps that run inside the **Ondes Core Bridge**.

This package provides a Dart API to communicate with the native host application, giving you access to native UI, device features, storage, social features, and more.

## 📦 Installation

```bash
flutter pub add ondes_sdk
```

Or add manually to your `pubspec.yaml`:

```yaml
dependencies:
  ondes_sdk: ^1.5.0
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:ondes_sdk/ondes_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Wait for the bridge to be ready
  await Ondes.ensureReady();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await Ondes.ui.showToast(
                message: "Hello from Flutter!",
                type: ToastType.success,
              );
            },
            child: const Text('Show Toast'),
          ),
        ),
      ),
    );
  }
}
```

## 📚 Modules

### 🎨 UI (`Ondes.ui`)

Native UI components like toasts, alerts, and bottom sheets.

```dart
// Toast notification
await Ondes.ui.showToast(
  message: "Operation successful!",
  type: ToastType.success, // info, success, error, warning
);

// Alert dialog
await Ondes.ui.showAlert(
  title: "Information",
  message: "This is an alert.",
  buttonText: "OK",
);

// Confirmation dialog
final confirmed = await Ondes.ui.showConfirm(
  title: "Delete",
  message: "Are you sure?",
  confirmText: "Yes",
  cancelText: "No",
);

// Bottom sheet menu
final choice = await Ondes.ui.showBottomSheet(
  title: "Choose action",
  items: [
    BottomSheetItem(label: "Edit", value: "edit", icon: "edit"),
    BottomSheetItem(label: "Delete", value: "delete", icon: "delete"),
  ],
);

// Configure app bar
await Ondes.ui.configureAppBar(
  title: "My App",
  backgroundColor: "#2196F3",
  foregroundColor: "#FFFFFF",
);
```

### 👤 User (`Ondes.user`)

Current user authentication and profile.

```dart
// Check authentication
if (await Ondes.user.isAuthenticated()) {
  // Get user profile
  final profile = await Ondes.user.getProfile();
  print("Hello, ${profile?.username}!");
}
```

### 📱 Device (`Ondes.device`)

Hardware features like haptics, GPS, and QR scanner.

```dart
// Haptic feedback
await Ondes.device.hapticFeedback(HapticStyle.success);

// Vibration
await Ondes.device.vibrate(200); // 200ms

// QR Code scanner
try {
  final code = await Ondes.device.scanQRCode();
  print("Scanned: $code");
} catch (e) {
  print("Cancelled or denied");
}

// GPS Position
final position = await Ondes.device.getGPSPosition();
print("Location: ${position.latitude}, ${position.longitude}");

// Device info
final info = await Ondes.device.getInfo();
print("Platform: ${info.platform}, Dark mode: ${info.isDarkMode}");
```

### 💾 Storage (`Ondes.storage`)

Persistent key-value storage scoped to your mini-app.

```dart
// Save data
await Ondes.storage.set('user_prefs', {
  'theme': 'dark',
  'language': 'fr',
});

// Load data
final prefs = await Ondes.storage.get<Map<String, dynamic>>('user_prefs');
print(prefs?['theme']); // 'dark'

// List keys
final keys = await Ondes.storage.getKeys();

// Remove specific key
await Ondes.storage.remove('user_prefs');

// Clear all data
await Ondes.storage.clear();
```

### 📦 App (`Ondes.app`)

Mini-app lifecycle and information.

```dart
// Get app info
final info = await Ondes.app.getInfo();
print("${info.name} v${info.version}");

// Get manifest
final manifest = await Ondes.app.getManifest();

// Close mini-app
await Ondes.app.close();
```

### 👥 Friends (`Ondes.friends`)

Friend relationships and social graph.

```dart
// Get friends list
final friends = await Ondes.friends.list();

// Send friend request
await Ondes.friends.request(username: 'john_doe');

// Get pending requests
final pending = await Ondes.friends.getPendingRequests();

// Accept/reject requests
await Ondes.friends.accept(requestId);
await Ondes.friends.reject(requestId);

// Block/unblock users
await Ondes.friends.block(username: 'spammer');
await Ondes.friends.unblock(userId);

// Search users
final results = await Ondes.friends.search('john');
```

### 🌍 Social (`Ondes.social`)

Posts, feed, stories, and social interactions.

```dart
// Get feed
final posts = await Ondes.social.getFeed(limit: 20);

// Publish a post
final post = await Ondes.social.publish(
  content: "Hello world!",
  visibility: PostVisibility.followers,
  tags: ['flutter', 'ondes'],
);

// Like/unlike
await Ondes.social.likePost(postUuid);
await Ondes.social.unlikePost(postUuid);

// Comments
await Ondes.social.addComment(postUuid, "Great post!");
final comments = await Ondes.social.getComments(postUuid);

// Bookmarks
await Ondes.social.bookmarkPost(postUuid);
final saved = await Ondes.social.getBookmarks();

// Stories
final stories = await Ondes.social.getStories();
await Ondes.social.createStory(mediaPath, duration: 5);
await Ondes.social.viewStory(storyUuid);

// Follow/unfollow
await Ondes.social.follow(username: 'john_doe');
await Ondes.social.unfollow(userId: 123);

// Media picker
final media = await Ondes.social.pickMedia(
  multiple: true,
  allowVideo: true,
);
```

### 🔌 WebSocket (`Ondes.websocket`)

Bidirectional WebSocket connections for real-time communication.

```dart
// Connect to a WebSocket server
final conn = await Ondes.websocket.connect(
  'ws://192.168.1.42:4583',
  options: const WebsocketConnectOptions(
    reconnect: true,
    timeout: 10000,
  ),
);
print('Connected: ${conn.id}');

// Listen for messages
Ondes.websocket.onMessage(conn.id).listen((message) {
  print('Received: $message');
});

// Listen for status changes
Ondes.websocket.onStatusChange(conn.id).listen((event) {
  print('Status: ${event.status.name}');
});

// Send messages
await Ondes.websocket.send(conn.id, '<100s50>');
await Ondes.websocket.send(conn.id, {'type': 'command', 'value': 42});

// Get connection status
final status = await Ondes.websocket.getStatus(conn.id);

// List all connections
final connections = await Ondes.websocket.list();

// Disconnect
await Ondes.websocket.disconnect(conn.id);

// Disconnect all
await Ondes.websocket.disconnectAll();
```

### 📡 UDP (`Ondes.udp`)

UDP sockets for device discovery and lightweight communication.

```dart
// Bind to a UDP port
final socket = await Ondes.udp.bind(
  port: 0,           // 0 = auto-assign
  broadcast: true,
  reuseAddress: true,
);
print('Bound to port: ${socket.port}');

// Listen for messages
Ondes.udp.onMessage(socket.id).listen((msg) {
  print('From ${msg.address}:${msg.port}: ${msg.data}');
});

// Send a message to specific address
await Ondes.udp.send(
  socket.id,
  'Hello',
  '192.168.1.100',
  12345,
);

// Broadcast to multiple addresses (for device discovery)
final result = await Ondes.udp.broadcast(
  socket.id,
  'DISCOVER',
  ['192.168.1.255', '192.168.4.1', '172.20.10.1'],
  12345,
);
print('Sent to ${result.results.length} addresses');

// Close the socket
await Ondes.udp.close(socket.id);
```

### 💬 Chat (`Ondes.chat`)

End-to-end encrypted messaging with **automatic E2EE**.

Messages are encrypted before sending and decrypted on receipt - you just work with plain text!

```dart
// Initialize (connects WebSocket for real-time messages)
await Ondes.chat.init();

// Start a private conversation
final conv = await Ondes.chat.startChat('alice');

// Send a message (encrypted automatically)
await Ondes.chat.send(conv!.id, 'Hello, Alice!');

// Get conversation history (decrypted automatically)
final messages = await Ondes.chat.getMessages(conv.id);
for (final msg in messages) {
  print('${msg.sender}: ${msg.content}');
}

// Listen for new messages in real-time
final unsubscribe = Ondes.chat.onMessage((msg) {
  print('New message: ${msg.content}');
});

// Listen for typing indicators
Ondes.chat.onTyping((event) {
  if (event.isTyping) {
    print('${event.username} is typing...');
  }
});

// Send typing indicator
await Ondes.chat.setTyping(conv.id, true);

// Create a group conversation
final group = await Ondes.chat.createGroup('Project Team', ['alice', 'bob']);

// Reply to a message
await Ondes.chat.send(conv.id, 'I agree!', replyTo: 'msg-uuid');

// Get all conversations
final conversations = await Ondes.chat.getConversations();

// Disconnect when done
await Ondes.chat.disconnect();
```

**E2EE Security:**
- 🔐 **X25519** key exchange (Curve25519)
- 🔒 **AES-256-GCM** message encryption
- ✅ Keys generated automatically at login - no configuration needed!

## 🔧 Models

The SDK provides strongly-typed models:

- `UserProfile` - User profile data
- `DeviceInfo` - Device information
- `GpsPosition` - GPS coordinates
- `AppInfo` - Mini-app information
- `Friend` - Friend relationship
- `FriendRequest` - Friend request
- `Post` - Social post
- `PostComment` - Comment on a post
- `Story` - Temporary story
- `SocialUser` - User with social info
- `PostMedia` - Media attached to post
- `PickedMedia` - Media from picker
- `WebsocketConnection` - WebSocket connection info
- `WebsocketConnectOptions` - Connection options
- `WebsocketStatus` - Connection status enum
- `WebsocketStatusEvent` - Status change event
- `UdpSocket` - UDP socket info
- `UdpMessage` - Received UDP message
- `UdpSendResult` - Send operation result
- `UdpBroadcastResult` - Broadcast operation result
- `ChatConversation` - Chat conversation with members
- `ChatMessage` - Chat message (decrypted)
- `ChatMember` - Conversation member
- `ChatTypingEvent` - Typing indicator event
- `ChatReceiptEvent` - Read receipt event

## ⚠️ Error Handling

All methods can throw `OndesException` with standard error codes:

```dart
try {
  await Ondes.device.scanQRCode();
} on OndesException catch (e) {
  switch (e.code) {
    case 'PERMISSION_DENIED':
      print('Camera access denied');
      break;
    case 'CANCELLED':
      print('User cancelled');
      break;
    case 'AUTH_REQUIRED':
      print('Login required');
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

## 🎯 Important Notes

1. **Web Only**: This SDK is designed for Flutter Web apps running inside the Ondes Core host.

2. **Bridge Ready**: Always call `await Ondes.ensureReady()` before using any SDK methods.

3. **Running Outside Host**: When running outside the Ondes Core host (e.g., during development), `ensureReady()` will timeout. Use `Ondes.isReady` to check availability.

```dart
if (Ondes.isReady) {
  await Ondes.ui.showToast(message: "Hello!");
} else {
  // Fallback for development
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Hello!")),
  );
}
```

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
