import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/models/mini_app.dart';

/// A full-screen Three.js planet rendered inside an [InAppWebView].
///
/// Flutter ↔ JS communication:
///   JS → Flutter  : callHandler('onReady' | 'onAppTap' | 'onAppDelete' | 'onHaptic', data)
///   Flutter → JS  : evaluateJavascript("initGlobe(...)" | "refreshApps(...)")
class PlanetWebView extends StatefulWidget {
  /// Current list of installed apps to display as pins on the planet.
  final List<MiniApp> apps;

  /// Called when the user double-taps a pin (intent to open the app).
  final void Function(MiniApp app) onAppTap;

  /// Called when the user long-presses and selects "Désinstaller".
  final void Function(MiniApp app) onAppDelete;

  const PlanetWebView({
    super.key,
    required this.apps,
    required this.onAppTap,
    required this.onAppDelete,
  });

  @override
  State<PlanetWebView> createState() => PlanetWebViewState();
}

class PlanetWebViewState extends State<PlanetWebView> {
  InAppWebViewController? _controller;
  bool _jsReady = false;
  String? _htmlSrc;

  @override
  void initState() {
    super.initState();
    _preloadHtml();
  }

  // ─── Asset loading ─────────────────────────────────────────

  Future<void> _preloadHtml() async {
    final html = await rootBundle.loadString('assets/planet/planet.html');
    if (mounted) setState(() => _htmlSrc = html);
  }

  // ─── Public API (called by MyAppsScreen) ───────────────────

  /// Send a refreshed app list to the running Three.js scene.
  Future<void> refreshApps(List<MiniApp> apps) async {
    if (!_jsReady || _controller == null) return;
    final json = await _buildJson(apps);
    await _controller!.evaluateJavascript(
      source: 'window.refreshApps && window.refreshApps(${_escapeJson(json)})',
    );
  }

  // ─── Helpers ───────────────────────────────────────────────

  /// Build a JSON string with all app data (converts file-path icons to base64).
  Future<String> _buildJson(List<MiniApp> apps) async {
    final list = <Map<String, dynamic>>[];
    for (final app in apps) {
      String? iconBase64;
      final url = app.iconUrl;

      // Convert local file paths to base64 so the WebView can render them
      if (url.isNotEmpty &&
          !url.startsWith('http://') &&
          !url.startsWith('https://')) {
        try {
          var path = url;
          if (path.startsWith('file://')) {
            path = Uri.parse(path).toFilePath();
          }
          path = Uri.decodeFull(path);
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final ext = path.split('.').last.toLowerCase();
            final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
            iconBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
          }
        } catch (_) {}
      }

      list.add({
        'id': app.id,
        'name': app.name,
        'iconUrl': (url.startsWith('http://') || url.startsWith('https://'))
            ? url
            : null,
        'iconBase64': iconBase64,
      });
    }
    return jsonEncode(list);
  }

  /// Wraps a JSON string so it's safe to embed inside a JS string argument.
  String _escapeJson(String json) {
    // Surround with single quotes; the JSON itself uses double quotes so no
    // escaping is needed beyond ensuring it's passed as a JS string literal.
    // We use JSON.stringify at call site to be safe:
    return "'${json.replaceAll("'", "\\'")}'" ;
  }

  // ─── JavaScript handlers ────────────────────────────────────

  void  _registerHandlers(InAppWebViewController ctrl) {
    // Three.js scene signals it has finished initialising.
    ctrl.addJavaScriptHandler(
      handlerName: 'onReady',
      callback: (_) async {
        _jsReady = true;
        final json = await _buildJson(widget.apps);
        await ctrl.evaluateJavascript(
          source: 'window.initGlobe && window.initGlobe(${_escapeJson(json)})',
        );
      },
    );

    // User double-tapped a pin → open that app.
    ctrl.addJavaScriptHandler(
      handlerName: 'onAppTap',
      callback: (args) {
        if (args.isEmpty) return;
        final data = _argMap(args[0]);
        final appId = data['appId']?.toString() ?? '';
        final app = _findApp(appId);
        if (app != null) widget.onAppTap(app);
      },
    );

    // User chose "Désinstaller" from the context menu.
    ctrl.addJavaScriptHandler(
      handlerName: 'onAppDelete',
      callback: (args) {
        if (args.isEmpty) return;
        final data = _argMap(args[0]);
        final appId = data['appId']?.toString() ?? '';
        final app = _findApp(appId);
        if (app != null) widget.onAppDelete(app);
      },
    );

    // JS requesting a haptic feedback pulse.
    ctrl.addJavaScriptHandler(
      handlerName: 'onHaptic',
      callback: (args) {
        final type = args.isNotEmpty
            ? (_argMap(args[0])['type']?.toString() ?? 'light')
            : 'light';
        switch (type) {
          case 'heavy':
            HapticFeedback.heavyImpact();
          case 'medium':
            HapticFeedback.mediumImpact();
          default:
            HapticFeedback.lightImpact();
        }
      },
    );
  }

  // Safely cast JS handler arg (Map or primitive) to Map<String,dynamic>.
  Map<String, dynamic> _argMap(dynamic arg) {
    if (arg is Map) return Map<String, dynamic>.from(arg);
    return {};
  }

  MiniApp? _findApp(String id) {
    try {
      return widget.apps.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_htmlSrc == null) {
      // Still loading the HTML asset — show the same bg colour so there's
      // no jarring flash.
      return const ColoredBox(color: Color(0xFF0A0A0A));
    }

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _htmlSrc!,
        mimeType: 'text/html',
        encoding: 'utf-8',
        // A real HTTPS origin so CDN scripts (Three.js) load without CORS issues.
        baseUrl: WebUri('https://ondes.local'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
        supportZoom: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        mediaPlaybackRequiresUserGesture: false,
        // Never show a scroll indicator through the planet canvas.
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        // Prevents the WebView from swallowing back-button naviagtion.
        useWideViewPort: false,
      ),
      onWebViewCreated: (ctrl) {
        _controller = ctrl;
        _registerHandlers(ctrl);
      },
      onLoadStop: (ctrl, _) {
        // Fallback: if flutterInAppWebViewPlatformReady fired before our
        // JS handler was registered, the scene will have called onReady
        // immediately. Ensure we still send app data.
        if (!_jsReady) {
          ctrl.evaluateJavascript(source: 'typeof window.initGlobe').then((v) {
            if (v == 'function') {
              _jsReady = true;
              _buildJson(widget.apps).then((json) {
                ctrl.evaluateJavascript(
                  source:
                      'window.initGlobe && window.initGlobe(${_escapeJson(json)})',
                );
              });
            }
          });
        }
      },
    );
  }
}
