import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/store_service.dart';
import '../../core/services/app_installer_service.dart';
import '../../core/services/local_server_service.dart';
import '../../core/services/app_library_service.dart';
import '../webview_screen.dart';
import 'app_detail_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  final _storeService = StoreService();
  final _installer = AppInstallerService();
  final _server = LocalServerService();
  final _library = AppLibraryService();

  late TabController _tabController;
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scroll logic can be added here
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load in parallel
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
        const SnackBar(content: Text("Lien de téléchargement manquant")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Track download
    if (app.dbId != null) {
      _storeService.trackDownload(app.dbId!);
    }

    await _installer.installApp(app, (p) {});

    await Future.delayed(const Duration(milliseconds: 300));
    await _refreshLocalApps();

    await _server.startServer(appId: app.id);

    if (mounted) {
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)),
      );
      _refreshLocalApps();
    }
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
        MaterialPageRoute(
          builder: (c) => AppDetailScreen(appId: app.dbId!, initialApp: app),
        ),
      ).then((_) => _refreshLocalApps());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(),
            _buildSearchBar(),
            _buildCategoryChips(),
            _buildTabBar(),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTodayTab(),
                        _buildAppsTab(),
                        _buildCategoriesTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: const Color(0xFF121212),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            "Ondes Store",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Rechercher des apps...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) => _search(value),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildCategoryChip(null, 'Tout', Icons.apps);
            }
            final category = _categories[index - 1];
            return _buildCategoryChip(
              category.slug,
              category.name,
              _getCategoryIcon(category.slug),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? slug, String name, IconData icon) {
    final isSelected = _selectedCategory == slug;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          _filterByCategory(slug);
        },
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white54),
        label: Text(name),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
        selectedColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  IconData _getCategoryIcon(String slug) {
    switch (slug) {
      case 'games':
        return Icons.sports_esports;
      case 'entertainment':
        return Icons.movie;
      case 'social':
        return Icons.people;
      case 'productivity':
        return Icons.work;
      case 'utilities':
        return Icons.build;
      case 'education':
        return Icons.school;
      case 'lifestyle':
        return Icons.favorite;
      case 'finance':
        return Icons.account_balance;
      case 'health':
        return Icons.fitness_center;
      case 'music':
        return Icons.music_note;
      case 'photo_video':
        return Icons.photo_camera;
      case 'weather':
        return Icons.cloud;
      case 'travel':
        return Icons.flight;
      case 'food':
        return Icons.restaurant;
      case 'sports':
        return Icons.sports_soccer;
      case 'shopping':
        return Icons.shopping_cart;
      case 'news':
        return Icons.newspaper;
      case 'books':
        return Icons.menu_book;
      default:
        return Icons.apps;
    }
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Aujourd'hui"),
            Tab(text: "Apps"),
            Tab(text: "Catégories"),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayTab() {
    final displayApps = _searchQuery.isNotEmpty ? _searchResults : _allApps;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Featured Section
          if (_featuredApps.isNotEmpty && _searchQuery.isEmpty) ...[
            _buildSectionHeader('En vedette', null),
            const SizedBox(height: 12),
            _buildFeaturedCarousel(),
            const SizedBox(height: 24),
          ],

          // Search results or popular apps
          _buildSectionHeader(
            _searchQuery.isNotEmpty ? 'Résultats' : 'Populaires',
            _searchQuery.isNotEmpty ? '${_searchResults.length} apps' : null,
          ),
          const SizedBox(height: 12),

          if (_isSearching)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (displayApps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Aucun résultat pour "$_searchQuery"'
                          : 'Aucune application disponible',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayApps.map((app) => _buildAppListTile(app)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54),
          ),
      ],
    );
  }

  Widget _buildFeaturedCarousel() {
    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: _featuredApps.length,
        itemBuilder: (context, index) {
          final app = _featuredApps[index];
          return GestureDetector(
            onTap: () => _navigateToDetail(app),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getGradientColor(index),
                    _getGradientColor(index).withOpacity(0.6),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: app.bannerUrl.isNotEmpty
                          ? Image.network(
                              app.bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            )
                          : const SizedBox(),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            app.categoryName.isNotEmpty ? app.categoryName : 'App du jour',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: app.iconUrl.isNotEmpty
                                  ? Image.network(
                                      app.iconUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.white24,
                                        child: const Icon(Icons.apps, color: Colors.white),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.white24,
                                      child: const Icon(Icons.apps, color: Colors.white),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    app.description,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
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
          );
        },
      ),
    );
  }

  Color _getGradientColor(int index) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildAppListTile(MiniApp app) {
    final isInstalled = _isAppInstalled(app);
    final hasUpdate = _hasUpdate(app);

    return GestureDetector(
      onTap: () => _navigateToDetail(app),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: app.iconUrl.isNotEmpty
                  ? Image.network(
                      app.iconUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.apps, color: Colors.white54),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.apps, color: Colors.white54),
                    ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Rating
                      if (app.ratingsCount > 0) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          app.averageRating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Category
                      if (app.categoryName.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            app.categoryName,
                            style: const TextStyle(color: Colors.blue, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Age rating
                      Text(
                        app.ageRating,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            SizedBox(
              width: 80,
              child: ElevatedButton(
                onPressed: () {
                  if (isInstalled && !hasUpdate) {
                    _openApp(app.id);
                  } else {
                    _installAndOpen(app);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasUpdate
                      ? Colors.amber
                      : isInstalled
                          ? Colors.grey.shade700
                          : Colors.blue,
                  foregroundColor: hasUpdate ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  hasUpdate ? 'MAJ' : isInstalled ? 'Ouvrir' : 'Installer',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sort options
          Row(
            children: [
              const Text('Trier par: ', style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 8),
              _buildSortChip('En vedette', 'featured'),
              _buildSortChip('Populaire', 'popular'),
              _buildSortChip('Nouveau', 'newest'),
              _buildSortChip('Note', 'rating'),
            ],
          ),
          const SizedBox(height: 16),

          // Apps grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _allApps.length,
            itemBuilder: (context, index) => _buildAppCard(_allApps[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) async {
          setState(() => _sortBy = value);
          final response = await _storeService.getApps(
            sort: value,
            category: _selectedCategory,
          );
          if (mounted) {
            setState(() => _allApps = response.apps);
          }
        },
        label: Text(label, style: const TextStyle(fontSize: 12)),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
        backgroundColor: Colors.white.withOpacity(0.1),
        selectedColor: Colors.blue,
      ),
    );
  }

  Widget _buildAppCard(MiniApp app) {
    final isInstalled = _isAppInstalled(app);
    final hasUpdate = _hasUpdate(app);

    return GestureDetector(
      onTap: () => _navigateToDetail(app),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: app.iconUrl.isNotEmpty
                  ? Image.network(
                      app.iconUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.apps, color: Colors.white54),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.apps, color: Colors.white54),
                    ),
            ),
            const SizedBox(height: 10),

            // Name
            Text(
              app.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Category
            Text(
              app.categoryName.isNotEmpty ? app.categoryName : app.description,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Rating
            if (app.ratingsCount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    app.averageRating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isInstalled && !hasUpdate) {
                    _openApp(app.id);
                  } else {
                    _installAndOpen(app);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasUpdate
                      ? Colors.amber
                      : isInstalled
                          ? Colors.grey.shade700
                          : Colors.blue,
                  foregroundColor: hasUpdate ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  hasUpdate ? 'MAJ' : isInstalled ? 'Ouvrir' : 'Installer',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return GestureDetector(
          onTap: () => _filterByCategory(category.slug),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getGradientColor(index).withOpacity(0.3),
                  _getGradientColor(index).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getGradientColor(index),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(category.slug),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${category.appsCount} applications',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF121212),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

