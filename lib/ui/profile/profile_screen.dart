import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/configuration_service.dart';
import '../../core/services/dev_studio_service.dart';
import '../../core/models/mini_app.dart';
import '../../main.dart' show authWrapperKey;

import 'permission_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _bioCtrl = TextEditingController();
  File? _newAvatar;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  List<MiniApp> _myApps = [];
  bool _isLoading = false;
  bool _isLoadingStats = true;
  int _cacheSizeBytes = 0;
  bool _isLoadingCache = false;
  bool _isClearingCache = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _user = AuthService().currentUser;
      _bioCtrl.text = _user?['bio'] ?? "";
    });
    await Future.wait([_loadStats(), _loadCacheSize()]);
    _animationController.forward();
  }

  Future<void> _loadCacheSize() async {
    setState(() => _isLoadingCache = true);
    try {
      // WKWebView (iOS/macOS) stocke TOUTES ses données dans Library/WebKit/ :
      //   • WebsiteData/CacheStorage/ → modèles WebLLM (Cache Storage API)
      //   • WebsiteData/IndexedDB/    → bases de données
      //   • WebsiteData/LocalStorage/ → localStorage
      //   • NetworkCache/             → cache HTTP WebKit
      //
      // Sur Android, le cache WebView est dans getCacheDir() + les données
      // website dans getFilesDir()/app_webview/.
      //
      // IMPORTANT : getApplicationCacheDirectory() → Library/Caches/com.ondes.core
      // ce répertoire est VIDE, ce n'est pas là que WKWebView écrit.

      final candidates = <Directory>[];
      final seenPaths = <String>{};

      void addIfNew(Directory d) {
        if (seenPaths.add(d.path)) candidates.add(d);
      }

      if (Platform.isMacOS || Platform.isIOS) {
        // Répertoire principal : Library/WebKit/
        try {
          final lib = await getLibraryDirectory();
          addIfNew(Directory('${lib.path}/WebKit'));
        } catch (_) {}
      } else if (Platform.isAndroid) {
        // Cache HTTP Android WebView
        try { addIfNew(await getTemporaryDirectory()); } catch (_) {}
        // Données website (IndexedDB, CacheStorage)
        try {
          final support = await getApplicationSupportDirectory();
          addIfNew(Directory('${support.path}/app_webview'));
        } catch (_) {}
      } else {
        // Fallback générique (Linux, Windows, etc.)
        try { addIfNew(await getApplicationCacheDirectory()); } catch (_) {}
        try { addIfNew(await getTemporaryDirectory()); } catch (_) {}
      }

      int total = 0;
      for (final dir in candidates) {
        if (await dir.exists()) {
          total += await _computeDirSize(dir);
        }
      }

      if (mounted) setState(() { _cacheSizeBytes = total; _isLoadingCache = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCache = false);
    }
  }

  /// Calcule récursivement la taille d'un répertoire en octets.
  Future<int> _computeDirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  Future<void> _clearWebViewCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text("Vider le cache", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Le cache WebView sera supprimé (modèles IA mis en cache, données web).\nCette action est irréversible.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Vider", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingCache = true);
    try {
      await InAppWebViewController.clearAllCache();

      await _loadCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Cache vidé avec succès"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await AuthService().getDeveloperStats();
      final apps = await DevStudioService().getMyApps();
      if (mounted) {
        setState(() {
          _stats = stats;
          _myApps = apps;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Changer la photo de profil",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: "Galerie",
                  color: Colors.purple,
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                _buildImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: "Caméra",
                  color: Colors.blue,
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _newAvatar = File(picked.path);
      });
      // Sauvegarde automatique de l'avatar
      await _saveAvatar();
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Future<void> _saveAvatar() async {
    if (_newAvatar == null) return;

    setState(() => _isLoading = true);
    final success = await AuthService().updateProfile(avatar: _newAvatar);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _newAvatar = null;
          _loadData();
        }
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la mise à jour",
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    await AuthService().updateProfile(bio: _bioCtrl.text, avatar: _newAvatar);
    setState(() {
      _isLoading = false;
      _loadData();
      _newAvatar = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profil mis à jour !"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  Future<void> _deleteAllApps() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text("Attention", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Voulez-vous vraiment supprimer toutes les applications locales ?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Supprimer tout",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await AppLibraryService().deleteAllApps();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_order');

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Applications supprimées"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushReplacementNamed('/');
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Non connecté", style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // === Header avec avatar ===
          _buildHeader(),

          // === Contenu ===
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // === Statistiques ===
                    _buildStatsSection(),

                    const SizedBox(height: 28),

                    // === Mes Apps ===
                    _buildMyAppsSection(),

                    const SizedBox(height: 28),

                    // === Bio ===
                    _buildBioSection(),

                    const SizedBox(height: 28),

                    // === Cache ===
                    _buildCacheSection(),

                    const SizedBox(height: 28),

                    // === Actions ===
                    _buildActionsSection(),

                    const SizedBox(height: 200),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    ImageProvider avatarProvider;
    if (_newAvatar != null) {
      avatarProvider = FileImage(_newAvatar!);
    } else if (_user!['avatar'] != null) {
      String url = _user!['avatar'];
      if (!url.startsWith('http')) url = "${ConfigurationService().baseUrl}$url";
      avatarProvider = NetworkImage(url);
    } else {
      avatarProvider = const NetworkImage(
        "https://placehold.co/150/1a1a2e/ffffff/png?text=👤",
      );
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey.shade900,
                            backgroundImage: avatarProvider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "@${_user!['username']}",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _user!['email'] ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
      ),
      actions: [
        IconButton(
          onPressed: _logout,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsSection() {
    final stats = _stats?['stats'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.purple.shade300,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              "Statistiques",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingStats)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.apps_rounded,
                  label: "Apps créées",
                  value: _formatNumber(stats?['total_apps'] ?? 0),
                  gradient: [Colors.purple.shade600, Colors.purple.shade900],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.download_rounded,
                  label: "Téléchargements",
                  value: _formatNumber(stats?['total_downloads'] ?? 0),
                  gradient: [Colors.blue.shade600, Colors.blue.shade900],
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.star_rounded,
                label: "Note moyenne",
                value: (stats?['average_rating'] ?? 0.0).toStringAsFixed(1),
                gradient: [Colors.orange.shade600, Colors.orange.shade900],
                suffix: " ★",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.rate_review_rounded,
                label: "Avis reçus",
                value: _formatNumber(stats?['total_reviews'] ?? 0),
                gradient: [Colors.teal.shade600, Colors.teal.shade900],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
    String suffix = "",
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.apps_outage_rounded,
                  color: Colors.blue.shade300,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  "Mes Applications",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (_myApps.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Navigate to Lab (index 3)
                  authWrapperKey.currentState?.navigateToTab(3);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Voir tout",
                      style: TextStyle(color: Colors.purple.shade300),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.purple.shade300,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingStats)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_myApps.isEmpty)
          _buildEmptyAppsCard()
        else
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _myApps.length,
              itemBuilder: (context, index) {
                return _buildAppCard(_myApps[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyAppsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: 40,
              color: Colors.purple.shade300,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Aucune application créée",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Créez votre première app dans le Lab !",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Lab (index 3)
              authWrapperKey.currentState?.navigateToTab(3);
            },
            icon: const Icon(Icons.science_rounded, size: 18),
            label: const Text("Ouvrir le Lab"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(MiniApp app) {
    String iconUrl = app.iconUrl;
    if (iconUrl.isNotEmpty && !iconUrl.startsWith('http')) {
      iconUrl = "${ConfigurationService().baseUrl}$iconUrl";
    }

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navigate to app detail
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade800,
                    image: iconUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(iconUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: iconUrl.isEmpty
                      ? Icon(Icons.apps, color: Colors.grey.shade600)
                      : null,
                ),
                const Spacer(),
                Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatNumber(app.downloadsCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const Spacer(),
                    if (app.averageRating > 0) ...[
                      Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Colors.amber.shade400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        app.averageRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              color: Colors.green.shade300,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              "Biographie",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _bioCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Décrivez-vous en quelques mots...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isLoading
                  ? "Enregistrement..."
                  : "Enregistrer les modifications",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCacheSection() {
    final sizeLabel = _isLoadingCache ? "Calcul…" : _formatBytes(_cacheSizeBytes);
    // Couleur de la jauge selon la taille
    // Les modèles WebLLM pèsent 750 MB – 2.2 GB chacun → seuils adaptés
    Color gaugeColor;
    if (_cacheSizeBytes > 7 * 1024 * 1024 * 1024) {
      gaugeColor = Colors.red.shade400;
    } else if (_cacheSizeBytes > 3 * 1024 * 1024 * 1024) {
      gaugeColor = Colors.orange.shade400;
    } else {
      gaugeColor = Colors.green.shade400;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.cyan.shade300, size: 22),
            const SizedBox(width: 10),
            const Text(
              "Caches",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.web_rounded, color: Colors.cyan.shade300, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Données mises en cache",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "WebView · modèles IA · ressources web",
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
                        ),
                      ],
                    ),
                  ),
                  _isLoadingCache
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                        )
                      : Text(
                          sizeLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: gaugeColor,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 16),
              // Barre visuelle (max représentatif : 10 GB — modèles WebLLM inclus)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _isLoadingCache
                      ? null
                      : (_cacheSizeBytes / (10.0 * 1024 * 1024 * 1024)).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "0 B",
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                  ),
                  Text(
                    "10 GB",
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingCache ? null : _loadCacheSize,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Actualiser"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isClearingCache ? null : _clearWebViewCache,
                      icon: _isClearingCache
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text(_isClearingCache ? "Nettoyage…" : "Vider le cache"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_rounded, color: Colors.grey.shade400, size: 22),
            const SizedBox(width: 10),
            const Text(
              "Actions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildActionTile(
                icon: Icons.security_rounded,
                title: "Gestion des permissions",
                subtitle: "Voir et révoquer les accès",
                iconColor: Colors.blue,
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => const PermissionManagementScreen()));
                },
              ),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              _buildActionTile(
                icon: Icons.delete_sweep_rounded,
                title: "Supprimer les apps locales",
                subtitle: "Libère l'espace de stockage",
                iconColor: Colors.orange,
                onTap: _deleteAllApps,
              ),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              _buildActionTile(
                icon: Icons.logout_rounded,
                title: "Se déconnecter",
                subtitle: "Retour à l'écran de connexion",
                iconColor: Colors.red,
                onTap: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
