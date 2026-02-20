
/// Catégorie d'application
class AppCategory {
  final int id;
  final String slug;
  final String name;
  final String icon;
  final String color;
  final int appsCount;

  AppCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.icon = '',
    this.color = '#007AFF',
    this.appsCount = 0,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      color: json['color'] ?? '#007AFF',
      appsCount: json['apps_count'] ?? 0,
    );
  }
}

/// Screenshot d'application
class AppScreenshot {
  final int id;
  final String imageUrl;
  final String deviceType;
  final int order;
  final String caption;

  AppScreenshot({
    required this.id,
    required this.imageUrl,
    this.deviceType = 'phone',
    this.order = 0,
    this.caption = '',
  });

  factory AppScreenshot.fromJson(Map<String, dynamic> json) {
    return AppScreenshot(
      id: json['id'] ?? 0,
      imageUrl: json['image'] ?? '',
      deviceType: json['device_type'] ?? 'phone',
      order: json['order'] ?? 0,
      caption: json['caption'] ?? '',
    );
  }
}

/// Auteur d'un avis
class ReviewAuthor {
  final int id;
  final String username;
  final String? avatarUrl;

  ReviewAuthor({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) {
    return ReviewAuthor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      avatarUrl: json['avatar'],
    );
  }
}

/// Avis utilisateur
class AppReview {
  final String id;
  final ReviewAuthor author;
  final int rating;
  final String title;
  final String content;
  final String? developerResponse;
  final DateTime? developerResponseDate;
  final String appVersion;
  final int helpfulCount;
  final DateTime createdAt;

  AppReview({
    required this.id,
    required this.author,
    required this.rating,
    this.title = '',
    this.content = '',
    this.developerResponse,
    this.developerResponseDate,
    this.appVersion = '',
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory AppReview.fromJson(Map<String, dynamic> json) {
    return AppReview(
      id: json['id'] ?? '',
      author: ReviewAuthor.fromJson(json['user'] ?? {}),
      rating: json['rating'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      developerResponse: json['developer_response'],
      developerResponseDate: json['developer_response_date'] != null 
          ? DateTime.parse(json['developer_response_date']) 
          : null,
      appVersion: json['app_version'] ?? '',
      helpfulCount: json['helpful_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Distribution des notes
class RatingDistribution {
  final int count;
  final double percentage;

  RatingDistribution({required this.count, required this.percentage});

  factory RatingDistribution.fromJson(Map<String, dynamic> json) {
    return RatingDistribution(
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

/// Application mini-app
class MiniApp {
  // Identité
  final int? dbId;
  final String id; // bundle_id
  final String name;
  final String version;
  
  // Description
  final String description;
  final String fullDescription;
  final String whatsNew;
  
  // Médias
  final String iconUrl;
  final String bannerUrl;
  final List<AppScreenshot> screenshots;
  
  // Catégorisation
  final AppCategory? category;
  final String categoryName;
  final String categorySlug;
  final List<String> tags;
  final String ageRating;
  
  // Métadonnées
  final String authorName;
  final int? authorId;
  final int sizeBytes;
  final String sizeFormatted;
  final List<String> languages;
  final String privacyUrl;
  final String supportUrl;
  final String websiteUrl;
  
  // Statistiques
  final int downloadsCount;
  final double averageRating;
  final int ratingsCount;
  final Map<int, RatingDistribution>? ratingDistribution;
  final bool featured;
  
  // Avis
  final List<AppReview> reviews;
  final AppReview? userReview;
  
  // Téléchargement
  final String downloadUrl;
  
  // État local
  bool isInstalled;
  String? localPath;
  
  // Permissions (Sandbox)
  final List<String> permissions;
  
  // Dates
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Genesis AI source
  final String sourceType; // 'manual' | 'genesis'
  final String? genesisProjectId;
  final bool isPublished; // false = draft (not yet visible in public store)

  MiniApp({
    this.dbId,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.fullDescription = '',
    this.whatsNew = '',
    required this.iconUrl,
    this.bannerUrl = '',
    this.screenshots = const [],
    this.category,
    this.categoryName = '',
    this.categorySlug = '',
    this.tags = const [],
    this.ageRating = '4+',
    this.authorName = '',
    this.authorId,
    this.sizeBytes = 0,
    this.sizeFormatted = '',
    this.languages = const ['fr'],
    this.privacyUrl = '',
    this.supportUrl = '',
    this.websiteUrl = '',
    this.downloadsCount = 0,
    this.averageRating = 0.0,
    this.ratingsCount = 0,
    this.ratingDistribution,
    this.featured = false,
    this.reviews = const [],
    this.userReview,
    required this.downloadUrl,
    this.isInstalled = false,
    this.localPath,
    this.permissions = const [],
    this.createdAt,
    this.updatedAt,
    this.sourceType = 'manual',
    this.genesisProjectId,
    this.isPublished = true,
  });

  /// Parse depuis JSON liste (léger)
  factory MiniApp.fromJson(Map<String, dynamic> json) {
    return MiniApp(
      dbId: json['id'],
      id: json['bundle_id'] ?? '',
      name: json['name'] ?? '',
      version: json['latest_version'] ?? '0.0.0',
      description: json['description'] ?? '',
      iconUrl: json['icon'] ?? '',
      categoryName: json['category_name'] ?? '',
      categorySlug: json['category_slug'] ?? '',
      ageRating: json['age_rating'] ?? '4+',
      authorName: json['author_name'] ?? '',
      downloadsCount: json['downloads_count'] ?? 0,
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      ratingsCount: json['ratings_count'] ?? 0,
      featured: json['featured'] ?? false,
      downloadUrl: json['download_url'] ?? '',
      permissions: (json['permissions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sourceType: json['source_type'] ?? 'manual',
      genesisProjectId: json['genesis_project_id']?.toString(),
      isPublished: json['is_published'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  /// Parse depuis JSON détail (complet)
  factory MiniApp.fromDetailJson(Map<String, dynamic> json) {
    //debugPrint('Parsing MiniApp from detail JSON: $json');
    // Parse screenshots
    List<AppScreenshot> screenshots = [];
    if (json['screenshots'] != null) {
      screenshots = (json['screenshots'] as List)
          .map((s) => AppScreenshot.fromJson(s))
          .toList();
    }

    // Parse reviews
    List<AppReview> reviews = [];
    if (json['reviews'] != null) {
      reviews = (json['reviews'] as List)
          .map((r) => AppReview.fromJson(r))
          .toList();
    }

    // Parse category
    AppCategory? category;
    if (json['category'] != null) {
      category = AppCategory.fromJson(json['category']);
    }

    // Parse tags
    List<String> tags = [];
    if (json['tags'] != null && json['tags'] is String) {
      tags = (json['tags'] as String).split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    // Parse languages
    List<String> languages = ['fr'];
    if (json['languages'] != null && json['languages'] is String) {
      languages = (json['languages'] as String).split(',').map((l) => l.trim()).toList();
    }

    // Parse rating distribution
    Map<int, RatingDistribution>? ratingDist;
    if (json['rating_distribution'] != null) {
      ratingDist = {};
      (json['rating_distribution'] as Map<String, dynamic>).forEach((key, value) {
        ratingDist![int.parse(key)] = RatingDistribution.fromJson(value);
      });
    }

    // Parse user review
    AppReview? userReview;
    if (json['user_review'] != null) {
      userReview = AppReview.fromJson(json['user_review']);
    }

    return MiniApp(
      dbId: json['id'],
      id: json['bundle_id'] ?? '',
      name: json['name'] ?? '',
      version: json['latest_version'] ?? '0.0.0',
      description: json['description'] ?? '',
      fullDescription: json['full_description'] ?? '',
      whatsNew: json['whats_new'] ?? '',
      iconUrl: json['icon'] ?? '',
      bannerUrl: json['banner'] ?? '',
      screenshots: screenshots,
      category: category,
      categoryName: category?.name ?? '',
      categorySlug: category?.slug ?? '',
      tags: tags,
      ageRating: json['age_rating'] ?? '4+',
      authorName: json['author_name'] ?? '',
      authorId: json['author_id'],
      sizeBytes: json['size_bytes'] ?? 0,
      sizeFormatted: json['size_formatted'] ?? '',
      languages: languages,
      privacyUrl: json['privacy_url'] ?? '',
      supportUrl: json['support_url'] ?? '',
      websiteUrl: json['website_url'] ?? '',
      downloadsCount: json['downloads_count'] ?? 0,
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      ratingsCount: json['ratings_count'] ?? 0,
      ratingDistribution: ratingDist,
      featured: json['featured'] ?? false,
      reviews: reviews,
      userReview: userReview,
      downloadUrl: json['download_url'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      sourceType: json['source_type'] ?? 'manual',
      genesisProjectId: json['genesis_project_id']?.toString(),
      isPublished: json['is_published'] ?? true,
    );
  }

  /// Nombre d'étoiles pour affichage
  String get starsDisplay {
    final fullStars = averageRating.floor();
    final halfStar = (averageRating - fullStars) >= 0.5;
    String result = '★' * fullStars;
    if (halfStar && fullStars < 5) result += '½';
    result += '☆' * (5 - fullStars - (halfStar ? 1 : 0));
    return result;
  }

  bool get isGenesisApp => sourceType == 'genesis';

  /// Téléchargements formatés
  String get downloadsFormatted {
    if (downloadsCount >= 1000000) {
      return '${(downloadsCount / 1000000).toStringAsFixed(1)}M';
    } else if (downloadsCount >= 1000) {
      return '${(downloadsCount / 1000).toStringAsFixed(1)}K';
    }
    return downloadsCount.toString();
  }
}
