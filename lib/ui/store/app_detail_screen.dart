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

class _AppDetailScreenState extends State<AppDetailScreen> {
  final _storeService = StoreService();
  final _installer = AppInstallerService();
  final _server = LocalServerService();
  final _library = AppLibraryService();

  MiniApp? _app;
  bool _isLoading = true;
  bool _isInstalling = false;
  bool _isInstalled = false;
  bool _hasUpdate = false;
  double _installProgress = 0;
  String _installedVersion = '';

  // Review form
  int _userRating = 0;
  final _reviewTitleController = TextEditingController();
  final _reviewContentController = TextEditingController();
  bool _isSubmittingReview = false;

  String get _installedVersionDisplay => _installedVersion.isEmpty ? '' : 'v$_installedVersion';

  /// Formate une date en format lisible
  String _formatDate(DateTime date) {
    const months = ['jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _app = widget.initialApp;
    _loadAppDetails();
  }

  @override
  void dispose() {
    _reviewTitleController.dispose();
    _reviewContentController.dispose();
    super.dispose();
  }

  Future<void> _loadAppDetails() async {
    setState(() => _isLoading = true);

    // Charger les détails complets
    final app = await _storeService.getAppDetail(widget.appId);

    // Vérifier si installée localement
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

    // Pre-fill user review if exists
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

    // Track download
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasUpdate ? 'Mise à jour terminée !' : 'Installation terminée !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openApp() async {
    if (_app == null) return;

    await _server.startServer(appId: _app!.id);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)),
      );
    }
  }

  Future<void> _submitReview() async {
    if (_app?.dbId == null || _userRating == 0) return;
    if (!AuthService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour laisser un avis')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avis publié !'), backgroundColor: Colors.green),
        );
        _loadAppDetails(); // Reload to get updated reviews
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la publication'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _app == null
              ? const Center(child: Text('Application introuvable', style: TextStyle(color: Colors.white)))
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildContent()),
                  ],
                ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: _app!.bannerUrl.isNotEmpty ? 280 : 180,
      pinned: true,
      backgroundColor: const Color(0xFF1c1c1e),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner ou gradient
            if (_app!.bannerUrl.isNotEmpty)
              Image.network(
                _app!.bannerUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientBanner(),
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
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),

            // App info at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _app!.iconUrl.isNotEmpty
                          ? Image.network(
                              _app!.iconUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                            )
                          : _buildDefaultIcon(),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name & Author
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _app!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _app!.authorName.isNotEmpty ? _app!.authorName : 'Développeur',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 16,
                          ),
                        ),
                      ],
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

  Widget _buildGradientBanner() {
    // Generate color from category or default
    Color baseColor = Colors.blue;
    if (_app!.categorySlug.isNotEmpty) {
      final hash = _app!.categorySlug.hashCode;
      baseColor = Color((hash & 0xFFFFFF) | 0xFF000000).withOpacity(1);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            baseColor.withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      color: Colors.grey.shade800,
      child: const Icon(Icons.apps, color: Colors.white54, size: 50),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(),
          const SizedBox(height: 24),
          _buildQuickInfo(),
          const SizedBox(height: 24),
          if (_app!.screenshots.isNotEmpty) ...[
            _buildScreenshots(),
            const SizedBox(height: 24),
          ],
          _buildDescription(),
          const SizedBox(height: 24),
          if (_app!.whatsNew.isNotEmpty) ...[
            _buildWhatsNew(),
            const SizedBox(height: 24),
          ],
          _buildRatingsSection(),
          const SizedBox(height: 24),
          _buildReviewForm(),
          const SizedBox(height: 24),
          _buildReviewsList(),
          const SizedBox(height: 24),
          _buildInfoSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _isInstalling
              ? Column(
                  children: [
                    LinearProgressIndicator(
                      value: _installProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Installation... ${(_installProgress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUpdate
                        ? Colors.amber
                        : _isInstalled
                            ? Colors.grey.shade700
                            : Colors.blue,
                    foregroundColor: _hasUpdate ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isInstalled && !_hasUpdate ? _openApp : _installOrUpdate,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hasUpdate
                            ? 'Mettre à jour'
                            : _isInstalled
                                ? 'Ouvrir'
                                : 'Installer',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (_isInstalled && _installedVersionDisplay.isNotEmpty)
                        Text(
                          _installedVersionDisplay,
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            // Share functionality
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Partage bientôt disponible')),
            );
          },
          icon: const Icon(Icons.share_outlined, color: Colors.blue),
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            '${_app!.averageRating.toStringAsFixed(1)}',
            '${_app!.ratingsCount} avis',
            icon: Icons.star,
            iconColor: Colors.amber,
          ),
          _buildDivider(),
          _buildInfoItem(
            _app!.ageRating,
            'Âge',
            icon: Icons.person_outline,
          ),
          _buildDivider(),
          _buildInfoItem(
            _app!.categoryName.isNotEmpty ? _app!.categoryName : 'App',
            'Catégorie',
            icon: Icons.category_outlined,
          ),
          _buildDivider(),
          _buildInfoItem(
            _app!.sizeFormatted.isNotEmpty ? _app!.sizeFormatted : 'N/A',
            'Taille',
            icon: Icons.storage_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String value, String label, {IconData? icon, Color? iconColor}) {
    return Column(
      children: [
        if (icon != null)
          Icon(icon, color: iconColor ?? Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildScreenshots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aperçu',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _app!.screenshots.length,
            itemBuilder: (context, index) {
              final screenshot = _app!.screenshots[index];
              return GestureDetector(
                onTap: () => _showFullScreenImage(screenshot.imageUrl),
                child: Container(
                  margin: EdgeInsets.only(right: index < _app!.screenshots.length - 1 ? 12 : 0),
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      screenshot.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
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
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    final description = _app!.fullDescription.isNotEmpty ? _app!.fullDescription : _app!.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildWhatsNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nouveautés',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Version ${_app!.version}',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            _app!.whatsNew,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingsSection() {
    if (_app!.ratingsCount == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.star_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Aucun avis',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Soyez le premier à donner votre avis !',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes et avis',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big rating number
            Column(
              children: [
                Text(
                  _app!.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'sur 5',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
            const SizedBox(width: 24),

            // Rating bars
            Expanded(
              child: Column(
                children: List.generate(5, (index) {
                  final star = 5 - index;
                  final dist = _app!.ratingDistribution?[star];
                  final percentage = dist?.percentage ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(Colors.amber),
                              minHeight: 8,
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
        const SizedBox(height: 8),
        Text(
          '${_app!.ratingsCount} avis',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _app!.userReview != null ? 'Modifier votre avis' : 'Laisser un avis',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _userRating = index + 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < _userRating ? Icons.star : Icons.star_outline,
                    color: Colors.amber,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _reviewTitleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Titre (optionnel)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Content
          TextField(
            controller: _reviewContentController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Votre avis (optionnel)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _userRating > 0 && !_isSubmittingReview ? _submitReview : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmittingReview
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _app!.userReview != null ? 'Mettre à jour' : 'Publier',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_app!.reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Avis récents',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_app!.ratingsCount > _app!.reviews.length)
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full reviews list
                },
                child: const Text('Voir tout'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_app!.reviews.take(5).map((review) => _buildReviewCard(review))),
      ],
    );
  }

  Widget _buildReviewCard(AppReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.withOpacity(0.2),
                backgroundImage: review.author.avatarUrl != null
                    ? NetworkImage(review.author.avatarUrl!)
                    : null,
                child: review.author.avatarUrl == null
                    ? Text(
                        review.author.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.blue),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author.username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_outline,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Title
          if (review.title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],

          // Content
          if (review.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.content,
              style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.4),
            ),
          ],

          // Developer response
          if (review.developerResponse != null && review.developerResponse!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Réponse du développeur',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review.developerResponse!,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // Helpful button
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final count = await _storeService.markReviewHelpful(review.id);
                  if (count != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Merci pour votre retour !')),
                    );
                  }
                },
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: Text('Utile (${review.helpfulCount})'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Développeur', _app!.authorName),
        _buildInfoRow('Bundle ID', _app!.id),
        _buildInfoRow('Version', _app!.version),
        _buildInfoRow('Taille', _app!.sizeFormatted.isNotEmpty ? _app!.sizeFormatted : 'N/A'),
        _buildInfoRow('Catégorie', _app!.categoryName.isNotEmpty ? _app!.categoryName : 'N/A'),
        _buildInfoRow('Classification', _app!.ageRating),
        _buildInfoRow('Langues', _app!.languages.join(', ')),
        if (_app!.createdAt != null)
          _buildInfoRow('Publié le', _formatDate(_app!.createdAt!)),
        if (_app!.updatedAt != null)
          _buildInfoRow('Mis à jour le', _formatDate(_app!.updatedAt!)),

        const SizedBox(height: 16),

        // Links
        Wrap(
          spacing: 12,
          runSpacing: 8,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String label, IconData icon, String url) {
    return OutlinedButton.icon(
      onPressed: () {
        // Open URL
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ouverture: $url')),
        );
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
