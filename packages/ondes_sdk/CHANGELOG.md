# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-01-20

### Added
- **Cross-platform compilation support**: Package now compiles on all platforms (iOS, Android, macOS, Windows, Linux)
- Added conditional exports for web vs non-web platforms using `dart.library.js_interop`
- Created stub implementations for non-web platforms that throw `UnsupportedError` with clear messages

### Changed
- Removed `platforms: web:` restriction from pubspec.yaml
- Refactored `js_bridge.dart` to use conditional exports (`js_bridge_stub.dart` / `js_bridge_web.dart`)
- Refactored `udp.dart` to use conditional exports (`udp_stub.dart` / `udp_web.dart`)

### Note
- The SDK still only functions on web platform inside the Ondes Core host
- Non-web platforms will compile but throw `UnsupportedError` at runtime when Ondes features are used

## [1.3.3] - 2026-01-20

### Added
- **Documentation**: Added WebSocket and UDP module documentation to README
- **Documentation**: Added Communication section to mkdocs.yml

### Fixed
- **WebSocket Module**: Implemented polling-based message delivery for macOS compatibility
- Fixed `MissingPluginException` when using `evaluateJavascript` on macOS
- Bridge now queues messages and SDK polls every 50ms for responsive delivery

## [1.3.2] - 2026-01-20

### Fixed
- **UDP Module**: Fixed all `as int` casts to use `(num).toInt()` for JavaScript compatibility
- Numbers from JS are always doubles, so direct int casts fail
- Fixed `UdpSocket.fromJson`, `UdpMessage.fromJson`, `UdpSendResult.fromJson`, `UdpBroadcastResult.fromJson`

## [1.3.1] - 2026-01-20

### Fixed
- **UDP Module**: Fixed message callback registration - `onMessage()` now properly receives messages from the native bridge by registering JS callbacks
- Added proper JS interop for UDP message events

## [1.3.0] - 2026-01-20

### Added
- **UDP Module** (`Ondes.udp`)
  - `bind()` - Bind to a UDP port and start listening
  - `send()` - Send a UDP message to a specific address
  - `broadcast()` - Broadcast a message to multiple addresses
  - `close()` - Close a UDP socket
  - `onMessage()` - Stream of incoming UDP messages
  - `onClose()` - Stream of socket close events
  - `getInfo()` - Get socket information
  - `list()` - List all active sockets
  - `closeAll()` - Close all sockets
- New models: `UdpSocket`, `UdpMessage`, `UdpSendResult`, `UdpBroadcastResult`, `UdpBindOptions`

## [1.2.0] - 2026-01-20

### Added
- **Websocket Module** (`Ondes.websocket`)
  - `connect()` - Connect to a WebSocket server with auto-reconnect support
  - `disconnect()` - Close a WebSocket connection
  - `send()` - Send messages (text or JSON)
  - `onMessage()` - Stream of incoming messages
  - `onStatusChange()` - Stream of connection status changes
  - `getStatus()` - Get current connection status
  - `list()` - List all active connections
  - `disconnectAll()` - Close all connections
- New models: `WebsocketConnection`, `WebsocketStatus`, `WebsocketConnectOptions`

## [1.1.0] - 2026-01-20

### Changed
- Automated publishing via GitHub Actions

## [1.0.0] - 2026-01-20

### Added
- Initial release of `ondes_sdk`
- **UI Module** (`Ondes.ui`)
  - `showToast()` - Display native toast notifications
  - `showAlert()` - Display alert dialogs
  - `showConfirm()` - Display confirmation dialogs
  - `showBottomSheet()` - Display bottom sheet menus
  - `configureAppBar()` - Configure the native app bar
- **User Module** (`Ondes.user`)
  - `getProfile()` - Get current user profile
  - `isAuthenticated()` - Check authentication status
  - `getAuthToken()` - Get authentication token for API calls
- **Device Module** (`Ondes.device`)
  - `hapticFeedback()` - Trigger haptic feedback
  - `vibrate()` - Vibrate the device
  - `scanQRCode()` - Scan QR codes using camera
  - `getGPSPosition()` - Get current GPS location
  - `getInfo()` - Get device information
- **Storage Module** (`Ondes.storage`)
  - `get()` / `set()` - Read/write persistent data
  - `remove()` / `clear()` - Delete stored data
  - `getKeys()` - List all stored keys
- **App Module** (`Ondes.app`)
  - `getInfo()` - Get mini-app information
  - `getManifest()` - Get manifest.json contents
  - `close()` - Close the mini-app
- **Friends Module** (`Ondes.friends`)
  - `list()` - Get friends list
  - `request()` / `accept()` / `reject()` - Manage friend requests
  - `block()` / `unblock()` - Block management
  - `search()` - Search users
- **Social Module** (`Ondes.social`)
  - `getFeed()` - Get social feed
  - `publish()` - Create new posts
  - `likePost()` / `unlikePost()` - Like management
  - `addComment()` / `getComments()` - Comments
  - `getStories()` / `createStory()` - Stories
  - `pickMedia()` - Native media picker
  - `follow()` / `unfollow()` - Follow management
- **JS Bridge** for Web communication
- **Strongly-typed models** for all data structures
- **OndesException** for error handling
- Example Flutter Web application
