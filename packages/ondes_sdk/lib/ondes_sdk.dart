/// Ondes SDK - Flutter SDK for Ondes Core Bridge
///
/// This package provides a Dart API to communicate with the native
/// Ondes Core Bridge when running Flutter Web apps inside the host application.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:ondes_sdk/ondes_sdk.dart';
///
/// void main() async {
///   await Ondes.ensureReady();
///
///   await Ondes.ui.showToast(
///     message: "Hello from Flutter!",
///     type: ToastType.success,
///   );
///
///   final profile = await Ondes.user.getProfile();
///   print("Logged in as ${profile?.username}");
/// }
/// ```
library;

// Core
export 'src/ondes.dart';

// Modules
export 'src/modules/ui.dart';
export 'src/modules/user.dart';
export 'src/modules/device.dart';
export 'src/modules/storage.dart';
export 'src/modules/app.dart';
export 'src/modules/friends.dart';
export 'src/modules/social.dart';

// Models
export 'src/models/user_profile.dart';
export 'src/models/device_info.dart';
export 'src/models/gps_position.dart';
export 'src/models/app_info.dart';
export 'src/models/friend.dart';
export 'src/models/friend_request.dart';
export 'src/models/post.dart';
export 'src/models/comment.dart';
export 'src/models/story.dart';
export 'src/models/media.dart';
export 'src/models/social_user.dart';

// Exceptions
export 'src/models/exceptions.dart';

// Enums
export 'src/models/enums.dart';
