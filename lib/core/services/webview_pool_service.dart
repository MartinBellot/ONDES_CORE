import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../bridge/ondes_js_injection.dart';

class WebViewPoolService {
  static final WebViewPoolService _instance = WebViewPoolService._internal();
  factory WebViewPoolService() => _instance;
  WebViewPoolService._internal();

  final List<String> _poolIds = ['webview_pool_1', 'webview_pool_2'];
  final List<String> _availableIds = [];
  
  // Storage for the KeepAlive objects
  final Map<String, InAppWebViewKeepAlive> _keepAliveObjects = {};
  
  // We keep headless instances to prevent them from being GC'd while warming up,
  // making sure they stay alive until the UI claims them.
  final Map<String, HeadlessInAppWebView> _headlessInstances = {};

  bool _isInitialized = false;

  /// Initialise la piscine de WebViews
  Future<void> init() async {
    if (_isInitialized) return;
    
    // On préchauffe les WebViews
    for (var id in _poolIds) {
      await _createHeadlessWarmer(id);
    }
    
    _isInitialized = true;
  }

  /// Crée une WebView Headless "chaude" prête à être utilisée
  Future<void> _createHeadlessWarmer(String id) async {
    print("🔥 [WebViewPool] Warming up $id...");

    // Create a new KeepAlive object for this slot
    final keepAlive = InAppWebViewKeepAlive();
    _keepAliveObjects[id] = keepAlive;
    
    final headless = HeadlessInAppWebView(
      // webViewEnvironment: await WebViewEnvironment.create(), // Not supported on macOS/iOS
      initialUrlRequest: URLRequest(url: WebUri("about:blank")),
      keepAlive: keepAlive, // Moved to constructor
      initialSettings: InAppWebViewSettings(
        isInspectable: true,
        // Performance settings
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        iframeAllow: "camera; microphone",
        transparentBackground: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (controller) async {
        // Pre-injection context if needed
      },
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(source: ondesBridgeJs);
        if (!_availableIds.contains(id)) {
            _availableIds.add(id);
            print("✅ [WebViewPool] $id is ready and available.");
        }
      },
    );

    _headlessInstances[id] = headless;
    
    // Start the engine
    await headless.run();
  }

  /// Récupère un objet KeepAlive chaud si disponible
  InAppWebViewKeepAlive? getAvailableKeepAlive() {
    if (_availableIds.isNotEmpty) {
      final id = _availableIds.removeAt(0);
      
      // We retrieve the KeepAlive object
      final keepAlive = _keepAliveObjects[id];
      
      // Dispose headless wrapper because we are moving the native view to the UI.
      // The native view survives because of KeepAlive.
      _headlessInstances[id]?.dispose(); 
      _headlessInstances.remove(id);
      
      // Remove reference so we don't return it again as 'available'
      _keepAliveObjects.remove(id);

      print("🚀 [WebViewPool] Using warm view from slot: $id");
      return keepAlive;
    }
    return null;
  }

  /// Called when UI is closed. We can trigger a new warm up.
  void releaseAndRefill() {
     if (_availableIds.length < _poolIds.length) {
       for (var id in _poolIds) {
         if (!_availableIds.contains(id) && !_headlessInstances.containsKey(id)) {
            // Wait a bit to not lag the UI closing animation
            Future.delayed(const Duration(milliseconds: 500), () {
               _createHeadlessWarmer(id);
            });
         }
       }
     }
  }
}
