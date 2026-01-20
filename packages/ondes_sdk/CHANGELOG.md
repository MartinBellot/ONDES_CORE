# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
