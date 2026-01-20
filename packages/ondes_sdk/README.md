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
  ondes_sdk: ^1.1.0
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
  
  // Get auth token for API requests
  final token = await Ondes.user.getAuthToken();
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
