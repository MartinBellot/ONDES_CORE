import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../bridge/bridge_controller.dart';
import '../bridge/ondes_js_injection.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({Key? key, required this.url}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late OndesBridgeController _bridge;
  
  // AppBar State
  bool _appBarVisible = false;
  String _appBarTitle = "";
  Color _appBarColor = Colors.white;
  Color _appBarTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _bridge = OndesBridgeController(context, onAppBarConfig: _updateAppBar);
  }

  void _updateAppBar(Map<String, dynamic> config) {
    setState(() {
      if (config.containsKey('visible')) _appBarVisible = config['visible'];
      if (config.containsKey('title')) _appBarTitle = config['title'];
      
      if (config.containsKey('backgroundColor')) {
         _appBarColor = _parseColor(config['backgroundColor']);
      }
      if (config.containsKey('foregroundColor')) {
         _appBarTextColor = _parseColor(config['foregroundColor']);
      }
    });
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse("0x$hex"));
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent for immersive experience
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, 
    ));

    return Scaffold(
      backgroundColor: Colors.black, // Immersive
      extendBody: true,
      extendBodyBehindAppBar: false,
      appBar: _appBarVisible 
          ? AppBar(
              title: Text(_appBarTitle, style: TextStyle(color: _appBarTextColor)),
              backgroundColor: _appBarColor,
              iconTheme: IconThemeData(color: _appBarTextColor),
              elevation: 0,
            )
          : null,
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              isInspectable: true, // Specific for debugging/Lab
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              transparentBackground: true,
              
              // Allow Local Server (HTTP)
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) {
              _bridge.setController(controller);
            },
            onLoadStart: (controller, url) {
              // Reinject just in case, though UserScript is better
            },
            onLoadStop: (controller, url) async {
                // Inject the Bridge JS
                await controller.evaluateJavascript(source: ondesBridgeJs);
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            onConsoleMessage: (controller, msg) {
              print("JS Console: ${msg.message}");
            },
          ),
          // Fallback Back Button (only if no native AppBar is visible)
          if (!_appBarVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
