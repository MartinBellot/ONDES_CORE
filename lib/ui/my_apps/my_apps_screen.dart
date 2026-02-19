// ignore_for_file: unused_field, unused_element

import 'dart:io';

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

class _MyAppsScreenState extends State<MyAppsScreen>
    with SingleTickerProviderStateMixin {
  final AppLibraryService _library = AppLibraryService();
  final LocalServerService _server = LocalServerService();

  final GlobalKey<PlanetWebViewState> _planetKey =
      GlobalKey<PlanetWebViewState>();

  List<MiniApp> _apps = [];
  bool _isLoading = true;

  // ── HUD panel ──────────────────────────────────────────────
  MiniApp? _focusedApp;
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(1.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
    _panelFade = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);
    _loadApps();
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final installed = await _library.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _apps = installed;
      _isLoading = false;
    });
    _planetKey.currentState?.refreshApps(_apps);
  }

  // ── HUD panel control ──────────────────────────────────────

  void _showAppPanel(MiniApp app) {
    setState(() => _focusedApp = app);
    _panelCtrl.forward(from: 0);
  }

  void _hideAppPanel() {
    _panelCtrl.reverse().then((_) {
      if (mounted) setState(() => _focusedApp = null);
    });
  }

  // ── App launch ─────────────────────────────────────────────

  Future<void> _openApp(MiniApp app) async {
    final permissions = app.permissions;
    final bool hasGranted =
        PermissionManagerService().hasAcceptedManifest(app.id);

    if (permissions.isNotEmpty && !hasGranted) {
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
    await _launchApp(app);
  }

  Future<void> _launchApp(MiniApp app) async {
    _hideAppPanel();
    try {
      await _server.startServer(appId: app.id);
      final url = _server.localUrl;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(url: url, appId: app.id),
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
    _hideAppPanel();
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
      _loadApps();
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 3-D planet ──
        Positioned.fill(
          child: PlanetWebView(
            key: _planetKey,
            apps: _apps,
            onAppTap: _openApp,
            onAppDelete: _uninstallApp,
            onAppFocus: _showAppPanel,
            onAppClose: _hideAppPanel,
          ),
        ),

        // ── Tap-outside scrim (visible only when panel is open) ──
        if (_focusedApp != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideAppPanel,
              child: FadeTransition(
                opacity: _panelFade,
                child: const SizedBox.expand(),
              ),
            ),
          ),

        // ── HUD app panel (Flutter native, slides in from right) ──
        if (_focusedApp != null)
          Positioned(
            top: MediaQuery.of(context).size.height/2 - 120, // panel height is max 400, so we center it vertically
            bottom: 90,
            right: 0,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                right: 10,
              ),
              child: SlideTransition(
                position: _panelSlide,
                child: FadeTransition(
                  opacity: _panelFade,
                  child: _AppInfoPanel(
                    app: _focusedApp!,
                    onOpen: () => _openApp(_focusedApp!),
                    onDelete: () => _uninstallApp(_focusedApp!),
                    onClose: _hideAppPanel,
                  ),
                ),
              ),
            ),
          ),

        // ── Loading overlay ──
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

// ══════════════════════════════════════════════════════════════
// HUD APP INFO PANEL  (pure Flutter widget)
// ══════════════════════════════════════════════════════════════

class _AppInfoPanel extends StatelessWidget {
  final MiniApp app;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _AppInfoPanel({
    required this.app,
    required this.onOpen,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xF0141416),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withOpacity(0.13),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.72),
            blurRadius: 48,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header with close button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xAAFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Icon ──
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: _AppIcon(iconUrl: app.iconUrl, name: app.name),
            ),

            // ── Name ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // ── Author + version ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                app.authorName.isNotEmpty ? app.authorName : app.version,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.38),
                ),
              ),
            ),

            // ── Description snippet ──
            if (app.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  app.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Colors.white.withOpacity(0.42),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Column(
                children: [
                  // Open
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: onOpen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A84FF), Color(0xFF005FCC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withOpacity(0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Ouvrir',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  // Delete
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C0606),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFF453A).withOpacity(0.38),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          'Désinstaller',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF453A),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App icon widget (handles local file + network + fallback) ──

class _AppIcon extends StatelessWidget {
  final String iconUrl;
  final String name;

  const _AppIcon({required this.iconUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
      image = Image.network(
        iconUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (iconUrl.isNotEmpty) {
      final path = iconUrl.startsWith('file://')
          ? Uri.parse(iconUrl).toFilePath()
          : iconUrl;
      image = Image.file(
        File(Uri.decodeFull(path)),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  Widget _fallback() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

