import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Base class for all Ondes Bridge handlers
/// Each handler type (UI, User, Device, etc.) extends this class
abstract class BaseHandler {
  final BuildContext context;
  InAppWebViewController? _webViewController;

  BaseHandler(this.context);

  /// Set the WebView controller and register handlers
  void attach(InAppWebViewController controller) {
    _webViewController = controller;
    registerHandlers();
  }

  /// Get the current WebView controller
  InAppWebViewController? get webViewController => _webViewController;

  /// Register all JavaScript handlers for this module
  /// Override in subclasses to add specific handlers
  @protected
  void registerHandlers();

  /// Helper method to add a JavaScript handler
  @protected
  void addHandler(String name, Future<dynamic> Function(List<dynamic>) callback) {
    _webViewController?.addJavaScriptHandler(
      handlerName: name,
      callback: callback,
    );
  }

  /// Helper to add a sync handler (wrapped in async)
  @protected
  void addSyncHandler(String name, dynamic Function(List<dynamic>) callback) {
    _webViewController?.addJavaScriptHandler(
      handlerName: name,
      callback: (args) async => callback(args),
    );
  }
}
