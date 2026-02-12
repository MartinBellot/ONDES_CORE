import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/store_service.dart';
import '../../core/services/app_installer_service.dart';
import '../../core/services/local_server_service.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/permission_manager_service.dart';
import '../webview_screen.dart';
import '../common/permission_request_screen.dart';
import 'app_detail_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  final _storeService = StoreService();
  final _installer = AppInstallerService();
  final _server = LocalServerService();
  final _library = AppLibraryService();

  // Animation controllers
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _popupController;
  late AnimationController _shimmerController;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // Data
  List<MiniApp> _featuredApps = [];
  List<MiniApp> _allApps = [];
  List<MiniApp> _searchResults = [];
  List<AppCategory> _categories = [];
  List<MiniApp> _installedApps = [];

  // State
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'featured';
  String? _error;
  bool _showTrendingPopup = false;
  bool _showNewReleasesPopup = false;
  int _hoveredAppIndex = -1;

  // Design constants - matching ultraDarkTheme from main.dart
  static const _bgPrimary = Color(0xFF0A0A0A); // surfaceColor
  static const _bgSecondary = Color(0xFF1C1C1E); // primarySurface
  static const _bgTertiary = Color(0xFF2C2C2E); // secondarySurface
  static const _accentPrimary = Color(0xFFFFFFFF); // textPrimary
  static const _accentSecondary = Color(0xFFEBEBF5); // textSecondary
  static const _accentMuted = Color(0xFF8E8E93); // textTertiary
  static const _highlightColor = Color(0xFF007AFF); // accentBlue
  static const _accentTeal = Color(0xFF5AC8FA);
  static const _accentPurple = Color(0xFFAF52DE);
  static const _accentOrange = Color(0xFFFF9500);
  static const _accentPink = Color(0xFFFF2D55);

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _popupController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _loadData();
    _scrollController.addListener(_onScroll);

    // Show popups after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _featuredApps.isNotEmpty) {
        setState(() => _showNewReleasesPopup = true);
        _popupController.forward();
      }
    });
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _popupController.dispose();
    _shimmerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Hide popups when scrolling
    if (_showTrendingPopup || _showNewReleasesPopup) {
      setState(() {
        _showTrendingPopup = false;
        _showNewReleasesPopup = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _storeService.getFeaturedApps(),
        _storeService.getApps(limit: 50),
        _storeService.getCategories(),
        _library.getInstalledApps(),
      ]);

      setState(() {
        _featuredApps = results[0] as List<MiniApp>;
        _allApps = (results[1] as StoreAppsResponse).apps;
        _categories = results[2] as List<AppCategory>;
        _installedApps = results[3] as List<MiniApp>;
        _isLoading = false;
      });

      // Trigger popup after load
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _allApps.isNotEmpty) {
          setState(() => _showNewReleasesPopup = true);
          _popupController.forward();
        }
      });
    } catch (e) {
      setState(() {
        _error = "Impossible de charger le Store.\n$e";
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    final response = await _storeService.getApps(
      search: query,
      category: _selectedCategory,
      sort: _sortBy,
    );

    if (mounted && _searchQuery == query) {
      setState(() {
        _searchResults = response.apps;
        _isSearching = false;
      });
    }
  }

  Future<void> _filterByCategory(String? categorySlug) async {
    setState(() {
      _selectedCategory = categorySlug;
      _isLoading = true;
    });

    final response = await _storeService.getApps(
      category: categorySlug,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      sort: _sortBy,
    );

    if (mounted) {
      setState(() {
        _allApps = response.apps;
        _isLoading = false;
      });
    }
  }

  bool _isAppInstalled(MiniApp app) {
    return _installedApps.any((a) => a.id == app.id);
  }

  bool _hasUpdate(MiniApp app) {
    try {
      final installed = _installedApps.firstWhere((a) => a.id == app.id);
      return installed.version != app.version;
    } catch (_) {
      return false;
    }
  }

  Future<void> _installAndOpen(MiniApp app) async {
    if (app.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lien de téléchargement manquant"),
          backgroundColor: _bgTertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (c) => _buildInstallDialog(app),
    );

    if (app.dbId != null) {
      _storeService.trackDownload(app.dbId!);
    }

    final installPath = await _installer.installApp(app, (p) {});
    debugPrint("Install path: $installPath");
    // If install failed (returned null), stop here and show error.
    if (installPath == null) {
      if (mounted) {
         Navigator.pop(context); // Close dialog
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Échec de l'installation. Vérifiez le paquet."), backgroundColor: Colors.red),
         );
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    await _refreshLocalApps();
    
    if (mounted) {
      Navigator.pop(context); // Close "Installing" dialog

      // 1. Get the Fresh "Installed" version of the app (from disk) to get correct Permissions
      // The 'app' object from Store might not match local manifest exactly or format
      final installedList = await _library.getInstalledApps();
      MiniApp? localApp;
      try {
         localApp = installedList.firstWhere((a) => a.id == app.id);
      } catch (_) {}

      if (localApp == null) {
        // Fallback (Should not happen if install success)
        _launch(app); 
        return;
      }

      // 2. Permission Check Logic
      final permissions = localApp.permissions;
      final bool hasGranted = PermissionManagerService().hasAcceptedManifest(localApp.id);
      
      if (permissions.isNotEmpty && !hasGranted) {
        // Show Permission Screen
        await showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.5),
          pageBuilder: (context, anim1, anim2) {
            return FadeTransition(
              opacity: anim1,
              child: PermissionRequestScreen(
                app: localApp!,
                onAccepted: () {
                  Navigator.of(context).pop();
                  _launch(localApp!);
                },
                onDenied: () {
                  Navigator.of(context).pop();
                },
              ),
            );
          },
        );
      } else {
        // Direct launch
        _launch(localApp);
      }
    }
  }

  Future<void> _launch(MiniApp app) async {
    await _server.startServer(appId: app.id);
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => WebViewScreen(
          url: _server.localUrl,
          appId: app.id, // IMPORTANT: Pass ID for Sandbox
        ),
      ),
    );
    _refreshLocalApps();
  }

  Widget _buildInstallDialog(MiniApp app) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _highlightColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _highlightColor.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated loader
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              _highlightColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: RotationTransition(
                            turns: _waveController,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: 0.3,
                              valueColor: AlwaysStoppedAnimation(
                                _highlightColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Installation de ${app.name}',
                    style: TextStyle(
                      color: _accentPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Text(
                        'Veuillez patienter...',
                        style: TextStyle(
                          color: _accentMuted.withOpacity(
                            0.5 + _pulseController.value * 0.5,
                          ),
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openApp(String appId) async {
    await _server.startServer(appId: appId);
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)),
      );
      _refreshLocalApps();
    }
  }

  Future<void> _refreshLocalApps() async {
    final localApps = await _library.getInstalledApps();
    if (mounted) {
      setState(() => _installedApps = localApps);
    }
  }

  void _navigateToDetail(MiniApp app) {
    if (app.dbId != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AppDetailScreen(appId: app.dbId!, initialApp: app),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ).then((_) => _refreshLocalApps());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Stack(
        children: [
          // Animated background elements
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchArea(),
                _buildQuickActions(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _error != null
                      ? _buildErrorState()
                      : _buildMainContent(),
                ),
              ],
            ),
          ),

          // Floating popups
          if (_showNewReleasesPopup) _buildNewReleasesPopup(),
          if (_showTrendingPopup) _buildTrendingPopup(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          painter: _BackgroundPainter(
            animation: _waveController.value,
            color: _highlightColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // Animated logo
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(_floatingController.value * math.pi) * 3,
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_highlightColor, _accentTeal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _highlightColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [_accentPrimary, _accentTeal],
                  ).createShader(bounds),
                  child: const Text(
                    'Découvrir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Text(
                      '${_allApps.length} apps disponibles',
                      style: TextStyle(color: _accentMuted, fontSize: 13),
                    );
                  },
                ),
              ],
            ),
          ),
          // Notification bell with animation
          _buildNotificationButton(),
          const SizedBox(width: 8),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showTrendingPopup = !_showTrendingPopup);
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTrendingPopup
                    ? _highlightColor
                    : _accentMuted.withOpacity(0.2),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: _showTrendingPopup
                        ? _accentOrange
                        : _accentSecondary,
                    size: 22,
                  ),
                ),
                // Notification dot
                Positioned(
                  top: 8,
                  right: 8,
                  child: Transform.scale(
                    scale: 0.8 + _pulseController.value * 0.4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _accentOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accentOrange.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _loadData();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentMuted.withOpacity(0.2)),
        ),
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _isLoading ? _waveController.value * 2 * math.pi : 0,
              child: Icon(
                Icons.refresh_rounded,
                color: _accentSecondary,
                size: 22,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: GestureDetector(
        onTap: () => HapticFeedback.selectionClick(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 52,
          decoration: BoxDecoration(
            color: _bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchController.text.isNotEmpty
                  ? _highlightColor.withOpacity(0.5)
                  : _accentMuted.withOpacity(0.15),
              width: _searchController.text.isNotEmpty ? 2 : 1,
            ),
            boxShadow: _searchController.text.isNotEmpty
                ? [
                    BoxShadow(
                      color: _highlightColor.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Icon(
                    Icons.search_rounded,
                    color: _searchController.text.isNotEmpty
                        ? _highlightColor
                        : _accentMuted.withOpacity(
                            0.5 + _pulseController.value * 0.3,
                          ),
                    size: 22,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: _accentPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une app, un jeu...',
                    hintStyle: TextStyle(color: _accentMuted, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => _search(value),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _search('');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      color: _accentMuted,
                      size: 18,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildQuickActionChip(
            'Tendances',
            Icons.local_fire_department_rounded,
            _accentOrange,
            () {
              HapticFeedback.selectionClick();
              setState(() => _showTrendingPopup = true);
            },
          ),
          _buildQuickActionChip(
            'Nouveautés',
            Icons.auto_awesome_rounded,
            _accentPurple,
            () {
              HapticFeedback.selectionClick();
              setState(() => _showNewReleasesPopup = true);
            },
          ),
          _buildQuickActionChip(
            'Top Notés',
            Icons.star_rounded,
            _accentTeal,
            () async {
              HapticFeedback.selectionClick();
              setState(() => _sortBy = 'rating');
              final response = await _storeService.getApps(sort: 'rating');
              if (mounted) setState(() => _allApps = response.apps);
            },
          ),
          _buildQuickActionChip(
            'Jeux',
            Icons.sports_esports_rounded,
            _accentPink,
            () {
              HapticFeedback.selectionClick();
              _filterByCategory('games');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final animValue = ((_waveController.value + delay) % 1.0);
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
            style: TextStyle(
              color: _accentMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
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
              child: Icon(
                Icons.cloud_off_rounded,
                color: _accentPink,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops ! Connexion perdue',
              style: TextStyle(
                color: _accentPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: _accentMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_highlightColor, _accentTeal],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _highlightColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final displayApps = _searchQuery.isNotEmpty ? _searchResults : _allApps;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _highlightColor,
      backgroundColor: _bgSecondary,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Categories carousel
          SliverToBoxAdapter(child: _buildCategoriesCarousel()),

          // Featured section with parallax
          if (_featuredApps.isNotEmpty && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'En vedette',
                icon: Icons.bolt_rounded,
                showSeeAll: true,
              ),
            ),
            SliverToBoxAdapter(child: _buildFeaturedCarousel()),
          ],

          // Main apps grid
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              _searchQuery.isNotEmpty ? 'Résultats' : 'Toutes les apps',
              icon: _searchQuery.isNotEmpty
                  ? Icons.search_rounded
                  : Icons.apps_rounded,
              count: displayApps.length,
            ),
          ),

          if (_isSearching)
            SliverFillRemaining(child: _buildLoadingState())
          else if (displayApps.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildAppCard(displayApps[index], index),
                  childCount: displayApps.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesCarousel() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(null, 'Tout', true);
          }
          final category = _categories[index - 1];
          return _buildCategoryChip(
            category.slug,
            category.name,
            _selectedCategory == category.slug,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String? slug, String name, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _filterByCategory(slug);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _highlightColor : _bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _highlightColor : _accentMuted.withOpacity(0.2),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _highlightColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : _accentSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    IconData? icon,
    bool showSeeAll = false,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: _highlightColor, size: 22),
            const SizedBox(width: 8),
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
          if (count != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _highlightColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: _highlightColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (showSeeAll)
            GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Text(
                'Voir tout',
                style: TextStyle(
                  color: _highlightColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: _featuredApps.length,
        itemBuilder: (context, index) {
          final app = _featuredApps[index];
          return AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(
                        (_floatingController.value + index * 0.3) * math.pi,
                      ) *
                      2,
                ),
                child: GestureDetector(
                  onTap: () => _navigateToDetail(app),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getGradientColor(index),
                          _getGradientColor(index).withOpacity(0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getGradientColor(index).withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Pattern overlay
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CustomPaint(
                              painter: _PatternPainter(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '✨ App du jour',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: app.iconUrl.isNotEmpty
                                          ? Image.network(
                                              app.iconUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.white24,
                                              child: const Icon(
                                                Icons.apps,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          app.description,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getGradientColor(int index) {
    final colors = [
      _highlightColor,
      _accentPurple,
      _accentTeal,
      _accentOrange,
      _accentPink,
    ];
    return colors[index % colors.length];
  }

  Widget _buildAppCard(MiniApp app, int index) {
    final isInstalled = _isAppInstalled(app);
    final hasUpdate = _hasUpdate(app);
    final isHovered = _hoveredAppIndex == index;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hoveredAppIndex = index),
              onExit: (_) => setState(() => _hoveredAppIndex = -1),
              child: GestureDetector(
                onTap: () => _navigateToDetail(app),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isHovered ? _bgTertiary : _bgSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isHovered
                          ? _highlightColor.withOpacity(0.3)
                          : _accentMuted.withOpacity(0.1),
                    ),
                    boxShadow: isHovered
                        ? [
                            BoxShadow(
                              color: _highlightColor.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      // App icon with glow
                      Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isHovered
                                  ? [
                                      BoxShadow(
                                        color: _highlightColor.withOpacity(0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: app.iconUrl.isNotEmpty
                                  ? Image.network(
                                      app.iconUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: _bgTertiary,
                                      child: Icon(
                                        Icons.apps,
                                        color: _accentMuted,
                                      ),
                                    ),
                            ),
                          ),
                          if (hasUpdate)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: _accentOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _bgSecondary,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        app.name,
                        style: TextStyle(
                          color: _accentPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.categoryName.isNotEmpty ? app.categoryName : 'App',
                        style: TextStyle(color: _accentMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (app.ratingsCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: _accentOrange,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              app.averageRating.toStringAsFixed(1),
                              style: TextStyle(
                                color: _accentSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      // Action button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (isInstalled && !hasUpdate) {
                            _openApp(app.id);
                          } else {
                            _installAndOpen(app);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: (!isInstalled || hasUpdate)
                                ? LinearGradient(
                                    colors: hasUpdate
                                        ? [
                                            _accentOrange,
                                            _accentOrange.withOpacity(0.8),
                                          ]
                                        : [_highlightColor, _accentTeal],
                                  )
                                : null,
                            color: isInstalled && !hasUpdate
                                ? _bgTertiary
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              hasUpdate
                                  ? 'Mettre à jour'
                                  : isInstalled
                                  ? 'Ouvrir'
                                  : 'Installer',
                              style: TextStyle(
                                color: isInstalled && !hasUpdate
                                    ? _accentSecondary
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: _accentMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat pour "$_searchQuery"'
                : 'Aucune application',
            style: TextStyle(color: _accentMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ==================== POPUPS ====================

  Widget _buildNewReleasesPopup() {
    final newApps = _allApps.take(3).toList();

    return _buildAnimatedPopup(
      title: 'Sorties du moment',
      icon: Icons.auto_awesome_rounded,
      subtitle: 'Découvrez les dernières nouveautés',
      color: _accentPurple,
      apps: newApps,
      onClose: () => setState(() => _showNewReleasesPopup = false),
      position: Alignment.bottomRight,
    );
  }

  Widget _buildTrendingPopup() {
    final trendingApps = _allApps
        .where((a) => a.ratingsCount > 0)
        .take(3)
        .toList();

    return _buildAnimatedPopup(
      title: 'Tendances',
      icon: Icons.local_fire_department_rounded,
      subtitle: 'Les apps les plus populaires',
      color: _accentOrange,
      apps: trendingApps,
      onClose: () => setState(() => _showTrendingPopup = false),
      position: Alignment.bottomLeft,
    );
  }

  Widget _buildAnimatedPopup({
    required String title,
    required IconData icon,
    required String subtitle,
    required Color color,
    required List<MiniApp> apps,
    required VoidCallback onClose,
    required Alignment position,
  }) {
    return Positioned(
      bottom: 120,
      left: position == Alignment.bottomLeft ? 16 : null,
      right: position == Alignment.bottomRight ? 16 : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(
              position == Alignment.bottomLeft
                  ? -30 * (1 - value)
                  : 30 * (1 - value),
              20 * (1 - value),
            ),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgSecondary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: _accentPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: _accentMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: onClose,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _bgTertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: _accentMuted,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Apps list
                        ...apps.asMap().entries.map((entry) {
                          final index = entry.key;
                          final app = entry.value;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 300 + index * 100),
                            curve: Curves.easeOutCubic,
                            builder: (context, animValue, child) {
                              return Transform.translate(
                                offset: Offset(20 * (1 - animValue), 0),
                                child: Opacity(
                                  opacity: animValue,
                                  child: GestureDetector(
                                    onTap: () {
                                      onClose();
                                      _navigateToDetail(app);
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        bottom: index < apps.length - 1
                                            ? 10
                                            : 0,
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _bgTertiary.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: app.iconUrl.isNotEmpty
                                                ? Image.network(
                                                    app.iconUrl,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: _bgTertiary,
                                                    child: Icon(
                                                      Icons.apps,
                                                      color: _accentMuted,
                                                      size: 20,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  app.name,
                                                  style: TextStyle(
                                                    color: _accentPrimary,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  app.categoryName,
                                                  style: TextStyle(
                                                    color: _accentMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: color,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
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

// ==================== CUSTOM PAINTERS ====================

class _BackgroundPainter extends CustomPainter {
  final double animation;
  final Color color;

  _BackgroundPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Animated circles in background
    for (int i = 0; i < 3; i++) {
      final progress = (animation + i * 0.33) % 1.0;
      final x = size.width * (0.2 + i * 0.3);
      final y = size.height * (0.3 + math.sin(progress * math.pi * 2) * 0.1);
      final radius = 100.0 + progress * 50;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
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

    // Grid pattern
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
