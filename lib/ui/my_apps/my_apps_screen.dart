// ignore_for_file: unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/local_server_service.dart';
import '../../core/services/permission_manager_service.dart';
import '../common/permission_request_screen.dart';
import '../webview_screen.dart';
import 'planet_webview.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  final AppLibraryService _library = AppLibraryService();
  final LocalServerService _server = LocalServerService();

  /// Key used to push refreshed app lists to the Three.js planet.
  final GlobalKey<PlanetWebViewState> _planetKey =
      GlobalKey<PlanetWebViewState>();

  List<MiniApp> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final installed = await _library.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _apps = installed;
      _isLoading = false;
    });
    // Push the updated list to the planet. No-op if the WebView is not ready
    // yet — the planet's own onReady callback will call initGlobe().
    _planetKey.currentState?.refreshApps(_apps);
  }

  Future<void> _openApp(MiniApp app) async {
    // Permission Check Phase (Modern UX)
    final permissions = app.permissions;
    final bool hasGranted = PermissionManagerService().hasAcceptedManifest(app.id);
    
    // Si l'app demande des permissions et que l'user n'a pas encore validé
    if (permissions.isNotEmpty && !hasGranted) {
      // Afficher l'écran de demande
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.5),
        pageBuilder: (context, anim1, anim2) {
          return FadeTransition(
            opacity: anim1,
            child: PermissionRequestScreen(
              app: app,
              onAccepted: () {
                Navigator.of(context).pop();
                _launchApp(app);
              },
              onDenied: () {
                Navigator.of(context).pop();
              },
            ),
          );
        },
      );
      return;
    }

    // Launch directly if no permissions required or already granted
    await _launchApp(app);
  }

  Future<void> _launchApp(MiniApp app) async {
    try {
      await _server.startServer(appId: app.id);
      final url = _server.localUrl;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url,
              appId: app.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }


  Future<void> _uninstallApp(MiniApp app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${app.name} ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await PermissionManagerService().revokePermissions(app.id);
      await _library.uninstallApp(app.id);
      _loadApps(); // also refreshes the planet
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 3-D planet (handles its own empty/loading states in JS) ──
        Positioned.fill(
          child: PlanetWebView(
            key: _planetKey,
            apps: _apps,
            onAppTap: _openApp,
            onAppDelete: _uninstallApp,
          ),
        ),

        // ── Loading overlay — only shown on the very first data fetch ──
        if (_isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeInOut,
                      builder: (context, v, _) => Opacity(
                        opacity: v,
                        child: const Icon(
                          Icons.bubble_chart_outlined,
                          size: 48,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        backgroundColor: const Color(0xFF1C1C1E),
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
