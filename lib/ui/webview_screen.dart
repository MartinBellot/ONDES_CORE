import 'package:flutter/material.dart';
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
  double progress = 0;
  
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
    return Scaffold(
      backgroundColor: Colors.black, // Immersive
      appBar: _appBarVisible 
          ? AppBar(
              title: Text(_appBarTitle, style: TextStyle(color: _appBarTextColor)),
              backgroundColor: _appBarColor,
              iconTheme: IconThemeData(color: _appBarTextColor),
              elevation: 0,
            )
          : null,
      body: SafeArea(
        top: !_appBarVisible, // If appbar is hidden, safe area is needed for status bar
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                isInspectable: true, // Specific for debugging/Lab
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone",
                
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
              onProgressChanged: (controller, p) {
                setState(() {
                  progress = p / 100;
                });
              },
              onConsoleMessage: (controller, msg) {
                print("JS Console: ${msg.message}");
              },
            ),
            if (progress < 1.0)
              LinearProgressIndicator(value: progress, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}
