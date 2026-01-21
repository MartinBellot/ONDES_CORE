import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'handlers/handlers.dart';

/// Main controller for the Ondes Bridge
/// Manages all handlers and their lifecycle
class OndesBridgeController {
  final BuildContext context;
  InAppWebViewController? webViewController;
  final Function(Map<String, dynamic>)? onAppBarConfig;
  final Function(Map<String, dynamic>)? onDrawerConfig;
  final Function(String action, Map<String, dynamic>? data)? onDrawerAction;
  final VoidCallback? onClose;
  
  // App info (optional)
  final String? appBundleId;
  final String? appVersion;
  final String? appName;

  // Handlers
  late final UIHandler _uiHandler;
  late final UserHandler _userHandler;
  late final DeviceHandler _deviceHandler;
  late final StorageHandler _storageHandler;
  late final AppHandler _appHandler;
  late final FriendsHandler _friendsHandler;
  late final SocialHandler _socialHandler;
  late final WebsocketHandler _websocketHandler;
  late final UdpHandler _udpHandler;
  late final ChatHandler _chatHandler;

  OndesBridgeController(
    this.context, {
    this.onAppBarConfig,
    this.onDrawerConfig,
    this.onDrawerAction,
    this.onClose,
    this.appBundleId,
    this.appVersion,
    this.appName,
  }) {
    // Initialize handlers
    _uiHandler = UIHandler(
      context, 
      onAppBarConfig: onAppBarConfig,
      onDrawerConfig: onDrawerConfig,
      onDrawerAction: onDrawerAction,
    );
    _userHandler = UserHandler(context);
    _deviceHandler = DeviceHandler(context);
    _storageHandler = StorageHandler(context, appBundleId: appBundleId);
    _appHandler = AppHandler(
      context,
      appBundleId: appBundleId,
      appVersion: appVersion,
      appName: appName,
      onClose: onClose,
    );
    _friendsHandler = FriendsHandler(context);
    _socialHandler = SocialHandler(context);
    _websocketHandler = WebsocketHandler(context);
    _udpHandler = UdpHandler(context);
    _chatHandler = ChatHandler(context);
  }

  void setController(InAppWebViewController controller) {
    webViewController = controller;
    _registerAllHandlers();
  }

  void _registerAllHandlers() {
    if (webViewController == null) return;

    // Attach all handlers to the WebView controller
    _uiHandler.attach(webViewController!);
    _userHandler.attach(webViewController!);
    _deviceHandler.attach(webViewController!);
    _storageHandler.attach(webViewController!);
    _appHandler.attach(webViewController!);
    _friendsHandler.attach(webViewController!);
    _socialHandler.attach(webViewController!);
    _websocketHandler.attach(webViewController!);
    _chatHandler.attach(webViewController!);
    _udpHandler.attach(webViewController!);
  }

  // Expose handlers for direct access if needed
  UIHandler get uiHandler => _uiHandler;
  UserHandler get userHandler => _userHandler;
  DeviceHandler get deviceHandler => _deviceHandler;
  StorageHandler get storageHandler => _storageHandler;
  AppHandler get appHandler => _appHandler;
  FriendsHandler get friendsHandler => _friendsHandler;
  SocialHandler get socialHandler => _socialHandler;
  WebsocketHandler get websocketHandler => _websocketHandler;
  ChatHandler get chatHandler => _chatHandler;
  UdpHandler get udpHandler => _udpHandler;
}
