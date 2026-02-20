import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/logger.dart';
import 'dev_studio_screen.dart';
import '../webview_screen.dart';
import '../common/scanner_screen.dart';
import '../genesis/genesis_screen.dart';

// ─────────────────────────────────────────────
// Design tokens (mirror main.dart ultraDarkTheme)
// ─────────────────────────────────────────────
const _bgPrimary    = Color(0xFF0A0A0A);
const _bgCard       = Color(0xFF1C1C1E);
const _bgCardBorder = Color(0xFF2C2C2E);
const _accentBlue   = Color(0xFF007AFF);
const _accentPurple = Color(0xFF7C3AED);
const _accentTeal   = Color(0xFF06B6D4);
const _textPrimary  = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFFEBEBF5);
const _textMuted    = Color(0xFF8E8E93);

class LabScreen extends StatefulWidget {
  const LabScreen({Key? key}) : super(key: key);

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with TickerProviderStateMixin {
  final TextEditingController _ipController =
      TextEditingController(text: "http://192.168.1.15:3000");
  final FocusNode _urlFocusNode = FocusNode();

  bool _isConnecting = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _urlFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _urlFocusNode.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('lab_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() => _ipController.text = savedUrl);
    }
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lab_url', url);
  }

  Future<List<String>?> _fetchManifestPermissions(String baseUrl) async {
    try {
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      final manifestUrl = '$baseUrl/manifest.json';
      AppLogger.debug('Lab', 'Fetching manifest from $manifestUrl');
      final dio = Dio();
      final response = await dio.get(manifestUrl);
      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          try { data = jsonDecode(data); } catch (_) {}
        }
        if (data is Map && data.containsKey('permissions')) {
          final perms = data['permissions'];
          if (perms is List) return perms.map((e) => e.toString()).toList();
        }
        return [];
      }
    } catch (e) {
      AppLogger.error('Lab', 'Failed to fetch manifest', e);
    }
    return null;
  }

  void _launchLiveServer() async {
    final url = _ipController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isConnecting = true);
    _saveUrl(url);

    _showSnack("Connexion au serveur…", icon: Icons.wifi_rounded, color: _accentBlue);

    final permissions = await _fetchManifestPermissions(url);

    if (!mounted) return;
    setState(() => _isConnecting = false);

    if (permissions == null) {
      _showSnack("Manifest introuvable — permissions désactivées", icon: Icons.warning_amber_rounded, color: Colors.orange);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => WebViewScreen(url: url, labPermissions: permissions)),
    );
  }

  void _scanQrCode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const CodeScannerScreen()),
    );
    if (code != null) {
      if (code.startsWith("http")) {
        setState(() => _ipController.text = code);
        _launchLiveServer();
      } else {
        _showSnack("QR Code invalide (pas une URL)", icon: Icons.error_outline, color: Colors.redAccent);
      }
    }
  }

  void _openStudio() {
    if (!AuthService().isAuthenticated) {
      _showSnack("Connectez-vous d'abord (Onglet Compte)", icon: Icons.lock_outline, color: Colors.orange);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (c) => const DevStudioScreen()));
  }

  void _openDocumentation() async {
    const url = 'https://martinbellot.github.io/ONDES_CORE/mini_app_guide/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnack("Impossible d'ouvrir le lien", icon: Icons.error_outline, color: Colors.redAccent);
    }
  }

  void _showSnack(String msg, {IconData? icon, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: color ?? _accentBlue, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(msg, style: const TextStyle(color: _textPrimary, fontSize: 14))),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildLiveServerCard(),
                const SizedBox(height: 16),
                _buildStudioCard(),
                const SizedBox(height: 16),
                _buildGenesisCard(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 150),
          ),
        ],
      ),
    );
  }

  // ─── Sliver Header ───────────────────────────

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _accentBlue.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.science_rounded, color: _accentBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Dev Lab',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Publication de Mini-Apps, serveur local, GENESIS AI...',
                      style: TextStyle(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
      ),
      actions: [
      ],
    );
  }

  // ─── Live Server Card ────────────────────────
  Widget _buildLiveServerCard() {
    final isFocused = _urlFocusNode.hasFocus;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          _SectionLabel(
            icon: Icons.wifi_tethering_rounded,
            iconColor: _accentBlue,
            title: 'Serveur local',
            subtitle: 'Connectez votre dev-server pour tester en temps réel.',
          ),
          const SizedBox(height: 20),
          _buildDocumentationCard(),
            const SizedBox(height: 12),

          // URL Input
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused ? _accentBlue : _bgCardBorder,
                width: isFocused ? 1.5 : 1,
              ),
              boxShadow: isFocused
                  ? [BoxShadow(color: _accentBlue.withOpacity(0.15), blurRadius: 12, spreadRadius: 2)]
                  : [],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.link_rounded, color: isFocused ? _accentBlue : _textMuted, size: 20),
                ),
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    focusNode: _urlFocusNode,
                    style: const TextStyle(color: _textPrimary, fontSize: 14, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "http://192.168.1.x:3000",
                      hintStyle: TextStyle(color: _textMuted, fontSize: 14),
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                // Clear button
                if (_ipController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _ipController.clear()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.cancel_rounded, color: _textMuted, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'QR Code',
                  onTap: _scanQrCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _isConnecting
                    ? _GradientButton(
                        icon: Icons.hourglass_empty_rounded,
                        label: 'Connexion…',
                        colors: [_accentBlue.withOpacity(0.6), _accentBlue.withOpacity(0.4)],
                        onTap: null,
                      )
                    : AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => _GradientButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Lancer',
                          colors: const [_accentBlue, Color(0xFF0055CC)],
                          onTap: _launchLiveServer,
                          glowOpacity: _pulseAnim.value * 0.3,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Genesis Card ────────────────────────────
  Widget _buildGenesisCard() {
    return _SectionCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF120D24), Color(0xFF0A0F1A)],
      ),
      borderColor: _accentPurple.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_accentPurple, _accentTeal],
                ).createShader(b),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_accentPurple, _accentTeal],
                ).createShader(b),
                child: const Text(
                  'GENESIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentPurple.withOpacity(0.4)),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: _accentPurple,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Génère, itère et déploie des Mini-Apps complètes par conversation. Le code est produit en temps réel et injecté dans la WebView.',
            style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              icon: Icons.rocket_launch_rounded,
              label: 'Ouvrir GENESIS',
              colors: const [_accentPurple, _accentTeal],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenesisScreen())),
              glowColor: _accentPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentationCard() {
    return GestureDetector(
      onTap: _openDocumentation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bgPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bgCardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: _textMuted, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Documentation officielle', style: TextStyle(color: _textSecondary, fontSize: 13)),
            ),
            const Icon(Icons.open_in_new_rounded, color: _textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  // ─── Studio Card ─────────────────────────────
  Widget _buildStudioCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            icon: Icons.dashboard_customize_rounded,
            iconColor: const Color(0xFFAF52DE), // accentPurple from theme
            title: 'Ondes Studio',
            subtitle: 'Gérez vos apps, publiez des mises à jour et suivez vos déploiements.',
          ),
          const SizedBox(height: 20),

          // Doc link row
          _buildDocumentationCard(),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              icon: Icons.build_circle_rounded,
              label: 'Ouvrir le Studio',
              colors: const [Color(0xFFAF52DE), Color(0xFF7C3AED)],
              onTap: _openStudio,
              glowColor: const Color(0xFFAF52DE),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Widget Primitives
// ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? borderColor;

  const _SectionCard({
    required this.child,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? _bgCard : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? _bgCardBorder, width: 1),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withOpacity(0.25)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;
  final double glowOpacity;
  final Color? glowColor;

  const _GradientButton({
    required this.icon,
    required this.label,
    required this.colors,
    this.onTap,
    this.glowOpacity = 0.25,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (glowColor ?? colors.first).withOpacity(glowOpacity),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _OutlineButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: _bgPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bgCardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _textSecondary, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
