import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/store_service.dart';
import '../../core/services/app_installer_service.dart';
import '../../core/services/local_server_service.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/auth_service.dart';
import '../webview_screen.dart';

class AppDetailScreen extends StatefulWidget {
  final int appId;
  final MiniApp? initialApp;

  const AppDetailScreen({
    Key? key,
    required this.appId,
    this.initialApp,
  }) : super(key: key);

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> with TickerProviderStateMixin {
  final _storeService = StoreService();
  final _installer = AppInstallerService();
  final _server = LocalServerService();
  final _library = AppLibraryService();

  // Animation controllers
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _heroController;
  late ScrollController _scrollController;

  MiniApp? _app;
  bool _isLoading = true;
  bool _isInstalling = false;
  bool _isInstalled = false;
  bool _hasUpdate = false;
  double _installProgress = 0;
  String _installedVersion = '';
  double _scrollOffset = 0;
  bool _showFloatingButton = false;

  // Review form
  int _userRating = 0;
  final _reviewTitleController = TextEditingController();
  final _reviewContentController = TextEditingController();
  bool _isSubmittingReview = false;

  // Design constants - matching ultraDarkTheme
  static const _bgPrimary = Color(0xFF0A0A0A);
  static const _bgSecondary = Color(0xFF1C1C1E);
  static const _bgTertiary = Color(0xFF2C2C2E);
  static const _accentPrimary = Color(0xFFFFFFFF);
  static const _accentSecondary = Color(0xFFEBEBF5);
  static const _accentMuted = Color(0xFF8E8E93);
  static const _highlightColor = Color(0xFF007AFF);
  static const _accentTeal = Color(0xFF5AC8FA);
  static const _accentPurple = Color(0xFFAF52DE);
  static const _accentOrange = Color(0xFFFF9500);
  static const _accentPink = Color(0xFFFF2D55);
  static const _accentGreen = Color(0xFF30D158);

  String get _installedVersionDisplay => _installedVersion.isEmpty ? '' : 'v$_installedVersion';

  String _formatDate(DateTime date) {
    const months = ['jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _app = widget.initialApp;
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _scrollController = ScrollController()..addListener(_onScroll);
    
    _loadAppDetails();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _heroController.dispose();
    _scrollController.dispose();
    _reviewTitleController.dispose();
    _reviewContentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
      _showFloatingButton = _scrollOffset > 300;
    });
  }

  Future<void> _loadAppDetails() async {
    setState(() => _isLoading = true);

    final app = await _storeService.getAppDetail(widget.appId);
    final installedApps = await _library.getInstalledApps();
    bool isInstalled = false;
    bool hasUpdate = false;
    String installedVersion = '';

    if (app != null) {
      try {
        final installed = installedApps.firstWhere((a) => a.id == app.id);
        isInstalled = true;
        installedVersion = installed.version;
        if (installed.version != app.version) {
          hasUpdate = true;
        }
      } catch (_) {}
    }

    if (app?.userReview != null) {
      _userRating = app!.userReview!.rating;
      _reviewTitleController.text = app.userReview!.title;
      _reviewContentController.text = app.userReview!.content;
    }

    if (mounted) {
      setState(() {
        _app = app;
        _isLoading = false;
        _isInstalled = isInstalled;
        _hasUpdate = hasUpdate;
        _installedVersion = installedVersion;
      });
    }
  }

  Future<void> _installOrUpdate() async {
    if (_app == null || _app!.downloadUrl.isEmpty) return;

    setState(() {
      _isInstalling = true;
      _installProgress = 0;
    });

    if (_app!.dbId != null) {
      _storeService.trackDownload(_app!.dbId!);
    }

    await _installer.installApp(_app!, (progress) {
      if (mounted) {
        setState(() => _installProgress = progress);
      }
    });

    setState(() {
      _isInstalling = false;
      _isInstalled = true;
      _hasUpdate = false;
      _installedVersion = _app!.version;
    });

    if (mounted) {
      _showSuccessToast(_hasUpdate ? 'Mise à jour terminée !' : 'Installation terminée !');
    }
  }

  void _showSuccessToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: _accentGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: _bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openApp() async {
    if (_app == null) return;

    await _server.startServer(appId: _app!.id);
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
            WebViewScreen(url: _server.localUrl),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    if (_app?.dbId == null || _userRating == 0) return;
    if (!AuthService().isAuthenticated) {
      _showSuccessToast('Connectez-vous pour laisser un avis');
      return;
    }

    setState(() => _isSubmittingReview = true);

    final review = await _storeService.submitReview(
      _app!.dbId!,
      rating: _userRating,
      title: _reviewTitleController.text,
      content: _reviewContentController.text,
      appVersion: _app!.version,
    );

    if (mounted) {
      setState(() => _isSubmittingReview = false);

      if (review != null) {
        _showSuccessToast('Avis publié !');
        _loadAppDetails();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),
          
          // Main content
          _isLoading
              ? _buildLoadingState()
              : _app == null
                  ? _buildErrorState()
                  : _buildContent(),
          
          // Floating action button
          if (_showFloatingButton && _app != null) _buildFloatingActionButton(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return CustomPaint(
          painter: _DetailBackgroundPainter(
            animation: _floatingController.value,
            scrollOffset: _scrollOffset,
            color: _app != null ? _getCategoryColor(_app!.categorySlug) : _highlightColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final animValue = ((_shimmerController.value + delay) % 1.0);
                  return Transform.scale(
                    scale: 0.5 + animValue * 1.5,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _highlightColor.withOpacity(1 - animValue),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement...',
            style: TextStyle(color: _accentMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentPink.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, color: _accentPink, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'Application introuvable',
            style: TextStyle(color: _accentPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _accentMuted.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Retour', style: TextStyle(color: _accentPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeroHeader(),
        SliverToBoxAdapter(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildHeroHeader() {
    final headerHeight = 380.0;
    final shrinkOffset = _scrollOffset.clamp(0.0, headerHeight - 100);
    final shrinkRatio = shrinkOffset / (headerHeight - 100);
    
    return SliverAppBar(
      expandedHeight: headerHeight,
      pinned: true,
      backgroundColor: _bgPrimary.withOpacity(0.95),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _bgSecondary.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Icon(Icons.arrow_back, color: _accentPrimary, size: 20),
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSuccessToast('Partage bientôt disponible');
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bgSecondary.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.ios_share, color: _accentPrimary, size: 20),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _heroController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - _heroController.value)),
              child: Opacity(
                opacity: _heroController.value.clamp(0.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner with parallax
                    if (_app!.bannerUrl.isNotEmpty)
                      Transform.translate(
                        offset: Offset(0, _scrollOffset * 0.5),
                        child: Image.network(
                          _app!.bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildGradientBanner(),
                        ),
                      )
                    else
                      _buildGradientBanner(),

                    // Overlay gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _bgPrimary.withOpacity(0.3),
                            _bgPrimary.withOpacity(0.95),
                            _bgPrimary,
                          ],
                          stops: const [0.0, 0.4, 0.8, 1.0],
                        ),
                      ),
                    ),

                    // App info
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: _buildAppInfo(shrinkRatio),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGradientBanner() {
    final baseColor = _getCategoryColor(_app!.categorySlug);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, baseColor.withOpacity(0.4)],
        ),
      ),
      child: CustomPaint(
        painter: _PatternPainter(color: Colors.white.withOpacity(0.03)),
      ),
    );
  }

  Color _getCategoryColor(String slug) {
    switch (slug) {
      case 'games': return _accentPurple;
      case 'entertainment': return _accentPink;
      case 'social': return _highlightColor;
      case 'productivity': return _accentTeal;
      case 'utilities': return _accentOrange;
      default: return _highlightColor;
    }
  }

  Widget _buildAppInfo(double shrinkRatio) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Animated icon
        AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, math.sin(_floatingController.value * math.pi) * 3),
              child: Container(
                width: 90 - shrinkRatio * 30,
                height: 90 - shrinkRatio * 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _getCategoryColor(_app!.categorySlug).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _app!.iconUrl.isNotEmpty
                      ? Image.network(_app!.iconUrl, fit: BoxFit.cover)
                      : _buildDefaultIcon(),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _app!.name,
                style: TextStyle(
                  color: _accentPrimary,
                  fontSize: 24 - shrinkRatio * 6,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(_app!.categorySlug).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _app!.categoryName.isNotEmpty ? _app!.categoryName : 'App',
                      style: TextStyle(
                        color: _getCategoryColor(_app!.categorySlug),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_app!.ratingsCount > 0) ...[
                    Icon(Icons.star_rounded, color: _accentOrange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _app!.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        color: _accentSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (_app!.authorName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _app!.authorName,
                  style: TextStyle(color: _accentMuted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      color: _bgTertiary,
      child: Icon(Icons.apps, color: _accentMuted, size: 40),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(),
          const SizedBox(height: 28),
          _buildQuickStats(),
          const SizedBox(height: 28),
          if (_app!.screenshots.isNotEmpty) ...[
            _buildScreenshots(),
            const SizedBox(height: 28),
          ],
          _buildDescription(),
          const SizedBox(height: 28),
          if (_app!.whatsNew.isNotEmpty) ...[
            _buildWhatsNew(),
            const SizedBox(height: 28),
          ],
          _buildRatingsSection(),
          const SizedBox(height: 28),
          _buildReviewForm(),
          const SizedBox(height: 28),
          _buildReviewsList(),
          const SizedBox(height: 28),
          _buildInfoSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return _isInstalling 
        ? _buildInstallProgress()
        : Row(
            children: [
              Expanded(child: _buildMainActionButton()),
              const SizedBox(width: 12),
              _buildSecondaryAction(Icons.ios_share, () {
                HapticFeedback.lightImpact();
              }),
              const SizedBox(width: 8),
              _buildSecondaryAction(Icons.more_horiz, () {
                HapticFeedback.lightImpact();
              }),
            ],
          );
  }

  Widget _buildInstallProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _highlightColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _installProgress,
                  valueColor: AlwaysStoppedAnimation(_highlightColor),
                  backgroundColor: _bgTertiary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Installation en cours...',
                      style: TextStyle(color: _accentPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_installProgress * 100).toInt()}%',
                      style: TextStyle(color: _accentMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _installProgress,
              backgroundColor: _bgTertiary,
              valueColor: AlwaysStoppedAnimation(_highlightColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton() {
    final isAction = _isInstalled && !_hasUpdate;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        isAction ? _openApp() : _installOrUpdate();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _hasUpdate
              ? LinearGradient(colors: [_accentOrange, _accentOrange.withOpacity(0.8)])
              : isAction
                  ? null
                  : LinearGradient(colors: [_highlightColor, _accentTeal]),
          color: isAction ? _bgTertiary : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: !isAction ? [
            BoxShadow(
              color: (_hasUpdate ? _accentOrange : _highlightColor).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                _hasUpdate ? 'Mettre à jour' : isAction ? 'Ouvrir' : 'Installer',
                style: TextStyle(
                  color: _accentPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isInstalled && _installedVersionDisplay.isNotEmpty)
                Text(
                  _installedVersionDisplay,
                  style: TextStyle(color: _accentMuted, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentMuted.withOpacity(0.2)),
        ),
        child: Icon(icon, color: _accentSecondary, size: 22),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentMuted.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            _app!.ratingsCount > 0 ? _app!.averageRating.toStringAsFixed(1) : '-',
            '${_app!.ratingsCount} avis',
            Icons.star_rounded,
            _accentOrange,
          ),
          _buildStatDivider(),
          _buildStatItem(
            _app!.ageRating,
            'Âge',
            Icons.person_outline_rounded,
            _accentTeal,
          ),
          _buildStatDivider(),
          _buildStatItem(
            _app!.sizeFormatted.isNotEmpty ? _app!.sizeFormatted : 'N/A',
            'Taille',
            Icons.data_usage_rounded,
            _accentPurple,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'v${_app!.version}',
            'Version',
            Icons.update_rounded,
            _accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: _accentPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: _accentMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 50,
      color: _accentMuted.withOpacity(0.1),
    );
  }

  Widget _buildScreenshots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Aperçu', icon: Icons.photo_library_outlined),
        const SizedBox(height: 16),
        SizedBox(
          height: 420,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _app!.screenshots.length,
            itemBuilder: (context, index) {
              final screenshot = _app!.screenshots[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + index * 100),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(screenshot.imageUrl),
                        child: Container(
                          margin: EdgeInsets.only(right: index < _app!.screenshots.length - 1 ? 14 : 0),
                          width: 210,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              screenshot.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: _bgTertiary,
                                child: Icon(Icons.broken_image, color: _accentMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        child: Image.network(imageUrl),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      right: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bgSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: _accentPrimary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: _highlightColor, size: 20),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: TextStyle(
            color: _accentPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildDescription() {
    final description = _app!.fullDescription.isNotEmpty ? _app!.fullDescription : _app!.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Description', icon: Icons.article_outlined),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgSecondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            description,
            style: TextStyle(
              color: _accentSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Nouveautés',
          icon: Icons.new_releases_outlined,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'v${_app!.version}',
              style: TextStyle(color: _accentGreen, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accentGreen.withOpacity(0.1),
                _accentGreen.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accentGreen.withOpacity(0.2)),
          ),
          child: Text(
            _app!.whatsNew,
            style: TextStyle(
              color: _accentSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingsSection() {
    if (_app!.ratingsCount == 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accentOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_outline_rounded, color: _accentOrange, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun avis',
              style: TextStyle(color: _accentPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Soyez le premier à donner votre avis !',
              style: TextStyle(color: _accentMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notes et avis', icon: Icons.reviews_outlined),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big rating
              Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [_accentOrange, _accentPink],
                    ).createShader(bounds),
                    child: Text(
                      _app!.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text('sur 5', style: TextStyle(color: _accentMuted)),
                  const SizedBox(height: 6),
                  Text(
                    '${_app!.ratingsCount} avis',
                    style: TextStyle(color: _accentSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 28),

              // Rating bars
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final star = 5 - index;
                    final dist = _app!.ratingDistribution?[star];
                    final percentage = dist?.percentage ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            child: Text(
                              '$star',
                              style: TextStyle(color: _accentMuted, fontSize: 12),
                            ),
                          ),
                          Icon(Icons.star_rounded, color: _accentOrange, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: percentage / 100),
                                duration: Duration(milliseconds: 800 + index * 100),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: _bgTertiary,
                                    valueColor: AlwaysStoppedAnimation(_accentOrange),
                                    minHeight: 8,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _highlightColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _highlightColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.rate_review_outlined, color: _highlightColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                _app!.userReview != null ? 'Modifier votre avis' : 'Laisser un avis',
                style: TextStyle(color: _accentPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Star rating
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _userRating = index + 1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: index < _userRating ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        index < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: _accentOrange,
                        size: 40,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Title field
          _buildTextField(
            controller: _reviewTitleController,
            hint: 'Titre (optionnel)',
            maxLines: 1,
          ),
          const SizedBox(height: 12),

          // Content field
          _buildTextField(
            controller: _reviewContentController,
            hint: 'Votre avis (optionnel)',
            maxLines: 4,
          ),
          const SizedBox(height: 20),

          // Submit button
          GestureDetector(
            onTap: _userRating > 0 && !_isSubmittingReview ? _submitReview : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _userRating > 0
                    ? LinearGradient(colors: [_highlightColor, _accentTeal])
                    : null,
                color: _userRating == 0 ? _bgTertiary : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _isSubmittingReview
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_accentPrimary),
                        ),
                      )
                    : Text(
                        _app!.userReview != null ? 'Mettre à jour' : 'Publier',
                        style: TextStyle(
                          color: _userRating > 0 ? _accentPrimary : _accentMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: _accentPrimary),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _accentMuted),
        filled: true,
        fillColor: _bgTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _highlightColor.withOpacity(0.5), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_app!.reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Avis récents',
          icon: Icons.forum_outlined,
          trailing: _app!.ratingsCount > _app!.reviews.length
              ? GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Voir tout',
                    style: TextStyle(color: _highlightColor, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        ...(_app!.reviews.take(5).toList().asMap().entries.map((entry) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + entry.key * 100),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: _buildReviewCard(entry.value),
                ),
              );
            },
          );
        })),
      ],
    );
  }

  Widget _buildReviewCard(AppReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_highlightColor, _accentTeal],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: review.author.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(review.author.avatarUrl!, fit: BoxFit.cover),
                      )
                    : Center(
                        child: Text(
                          review.author.username[0].toUpperCase(),
                          style: TextStyle(color: _accentPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author.username,
                      style: TextStyle(color: _accentPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: _accentOrange,
                          size: 14,
                        )),
                        const SizedBox(width: 10),
                        Text(
                          _formatDate(review.createdAt),
                          style: TextStyle(color: _accentMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Title & Content
          if (review.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              review.title,
              style: TextStyle(color: _accentPrimary, fontWeight: FontWeight.w700),
            ),
          ],

          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content,
              style: TextStyle(color: _accentSecondary, height: 1.5),
            ),
          ],

          // Developer response
          if (review.developerResponse != null && review.developerResponse!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _highlightColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _highlightColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply_rounded, color: _highlightColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Réponse du développeur',
                        style: TextStyle(color: _highlightColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    review.developerResponse!,
                    style: TextStyle(color: _accentSecondary, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],

          // Helpful
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              final count = await _storeService.markReviewHelpful(review.id);
              if (count != null && mounted) {
                _showSuccessToast('Merci pour votre retour !');
              }
            },
            child: Row(
              children: [
                Icon(Icons.thumb_up_outlined, color: _accentMuted, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Utile (${review.helpfulCount})',
                  style: TextStyle(color: _accentMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Informations', icon: Icons.info_outline_rounded),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgSecondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildInfoRow('Développeur', _app!.authorName, Icons.person_outline),
              _buildInfoRow('Bundle ID', _app!.id, Icons.code),
              _buildInfoRow('Version', _app!.version, Icons.update),
              _buildInfoRow('Taille', _app!.sizeFormatted.isNotEmpty ? _app!.sizeFormatted : 'N/A', Icons.storage),
              _buildInfoRow('Catégorie', _app!.categoryName.isNotEmpty ? _app!.categoryName : 'N/A', Icons.category),
              _buildInfoRow('Classification', _app!.ageRating, Icons.shield_outlined),
              _buildInfoRow('Langues', _app!.languages.join(', '), Icons.language),
              if (_app!.createdAt != null)
                _buildInfoRow('Publié le', _formatDate(_app!.createdAt!), Icons.calendar_today),
              if (_app!.updatedAt != null)
                _buildInfoRow('Mis à jour', _formatDate(_app!.updatedAt!), Icons.history),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Links
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_app!.websiteUrl.isNotEmpty)
              _buildLinkButton('Site web', Icons.language, _app!.websiteUrl),
            if (_app!.supportUrl.isNotEmpty)
              _buildLinkButton('Support', Icons.help_outline, _app!.supportUrl),
            if (_app!.privacyUrl.isNotEmpty)
              _buildLinkButton('Confidentialité', Icons.privacy_tip_outlined, _app!.privacyUrl),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _accentMuted, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: _accentMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(color: _accentPrimary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String label, IconData icon, String url) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSuccessToast('Ouverture: $url');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _highlightColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _highlightColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: _highlightColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 60 * (1 - value)),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgSecondary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentMuted.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _app!.iconUrl.isNotEmpty
                              ? Image.network(_app!.iconUrl, width: 44, height: 44, fit: BoxFit.cover)
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: _bgTertiary,
                                  child: Icon(Icons.apps, color: _accentMuted),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _app!.name,
                                style: TextStyle(
                                  color: _accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _app!.categoryName,
                                style: TextStyle(color: _accentMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _isInstalled && !_hasUpdate ? _openApp() : _installOrUpdate();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _hasUpdate
                                  ? LinearGradient(colors: [_accentOrange, _accentOrange.withOpacity(0.8)])
                                  : _isInstalled
                                      ? null
                                      : LinearGradient(colors: [_highlightColor, _accentTeal]),
                              color: _isInstalled && !_hasUpdate ? _bgTertiary : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _hasUpdate ? 'MAJ' : _isInstalled ? 'Ouvrir' : 'Installer',
                              style: TextStyle(
                                color: _accentPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom painters
class _DetailBackgroundPainter extends CustomPainter {
  final double animation;
  final double scrollOffset;
  final Color color;

  _DetailBackgroundPainter({
    required this.animation,
    required this.scrollOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    // Animated blob
    final centerX = size.width * 0.7;
    final centerY = 150.0 - scrollOffset * 0.3;
    final radius = 200.0 + math.sin(animation * math.pi) * 30;
    
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    
    // Second blob
    final paint2 = Paint()
      ..color = color.withOpacity(0.015)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.2, 300 - scrollOffset * 0.2),
      150 + math.cos(animation * math.pi) * 20,
      paint2,
    );
  }

  @override
  bool shouldRepaint(covariant _DetailBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.scrollOffset != scrollOffset;
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
