import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'configuration_service.dart';
import '../models/mini_app.dart';

/// Service pour interagir avec l'API Store
class StoreService {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  final String _baseUrl = ConfigurationService().apiBaseUrl;
  final Dio _dio = Dio();

  String? get _token => AuthService().token;

  Options get _authOptions => Options(
    headers: _token != null ? {'Authorization': 'Token $_token'} : null,
  );

  // ============== APPS ==============

  /// Récupère la liste des apps avec filtres et pagination
  Future<StoreAppsResponse> getApps({
    String? search,
    String? category,
    String? ageRating,
    String sort = 'featured',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (ageRating != null && ageRating.isNotEmpty) {
        queryParams['age_rating'] = ageRating;
      }

      final response = await _dio.get(
        '$_baseUrl/apps/',
        queryParameters: queryParams,
        options: _authOptions,
      );

      final List appsData = response.data['apps'] ?? [];
      final apps = appsData.map((json) => MiniApp.fromJson(json)).toList();

      return StoreAppsResponse(
        apps: apps,
        total: response.data['total'] ?? 0,
        limit: response.data['limit'] ?? limit,
        offset: response.data['offset'] ?? offset,
      );
    } catch (e) {
      print("Get Apps Error: $e");
      return StoreAppsResponse(apps: [], total: 0, limit: limit, offset: offset);
    }
  }

  /// Récupère les détails complets d'une app
  Future<MiniApp?> getAppDetail(int appId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/apps/$appId/',
        options: _authOptions,
      );
      return MiniApp.fromDetailJson(response.data);
    } catch (e) {
      print("Get App Detail Error: $e");
      return null;
    }
  }

  /// Récupère les apps mises en avant
  Future<List<MiniApp>> getFeaturedApps() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/apps/featured/',
        options: _authOptions,
      );
      final List data = response.data;
      return data.map((json) => MiniApp.fromJson(json)).toList();
    } catch (e) {
      print("Get Featured Apps Error: $e");
      return [];
    }
  }

  /// Récupère le top des apps
  Future<List<MiniApp>> getTopApps({
    String? category,
    String type = 'downloads',
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'type': type,
        'limit': limit,
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final response = await _dio.get(
        '$_baseUrl/apps/top/',
        queryParameters: queryParams,
        options: _authOptions,
      );
      final List data = response.data;
      return data.map((json) => MiniApp.fromJson(json)).toList();
    } catch (e) {
      print("Get Top Apps Error: $e");
      return [];
    }
  }

  /// Incrémente le compteur de téléchargements
  Future<void> trackDownload(int appId) async {
    try {
      await _dio.post(
        '$_baseUrl/apps/$appId/download/',
        options: _authOptions,
      );
    } catch (e) {
      print("Track Download Error: $e");
    }
  }

  // ============== CATEGORIES ==============

  /// Récupère toutes les catégories
  Future<List<AppCategory>> getCategories() async {
    try {
      final response = await _dio.get('$_baseUrl/categories/');
      final List data = response.data;
      return data.map((json) => AppCategory.fromJson(json)).toList();
    } catch (e) {
      print("Get Categories Error: $e");
      return [];
    }
  }

  /// Récupère les apps d'une catégorie
  Future<CategoryAppsResponse> getCategoryApps(
    String slug, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/categories/$slug/',
        queryParameters: {'limit': limit, 'offset': offset},
      );

      final category = AppCategory.fromJson(response.data['category']);
      final List appsData = response.data['apps'] ?? [];
      final apps = appsData.map((json) => MiniApp.fromJson(json)).toList();

      return CategoryAppsResponse(
        category: category,
        apps: apps,
        total: response.data['total'] ?? 0,
      );
    } catch (e) {
      print("Get Category Apps Error: $e");
      return CategoryAppsResponse(
        category: AppCategory(id: 0, slug: slug, name: slug),
        apps: [],
        total: 0,
      );
    }
  }

  // ============== REVIEWS ==============

  /// Récupère les avis d'une app
  Future<ReviewsResponse> getAppReviews(
    int appId, {
    String sort = 'recent',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/apps/$appId/reviews/',
        queryParameters: {
          'sort': sort,
          'limit': limit,
          'offset': offset,
        },
        options: _authOptions,
      );

      final List reviewsData = response.data['reviews'] ?? [];
      final reviews = reviewsData.map((json) => AppReview.fromJson(json)).toList();

      return ReviewsResponse(
        reviews: reviews,
        total: response.data['total'] ?? 0,
        averageRating: (response.data['average_rating'] ?? 0).toDouble(),
        ratingsCount: response.data['ratings_count'] ?? 0,
      );
    } catch (e) {
      print("Get Reviews Error: $e");
      return ReviewsResponse(
        reviews: [],
        total: 0,
        averageRating: 0,
        ratingsCount: 0,
      );
    }
  }

  /// Soumet un avis
  Future<AppReview?> submitReview(
    int appId, {
    required int rating,
    String title = '',
    String content = '',
    String appVersion = '',
  }) async {
    if (_token == null) return null;
    
    try {
      final response = await _dio.post(
        '$_baseUrl/apps/$appId/reviews/',
        data: {
          'rating': rating,
          'title': title,
          'content': content,
          'app_version': appVersion,
        },
        options: _authOptions,
      );
      return AppReview.fromJson(response.data);
    } catch (e) {
      print("Submit Review Error: $e");
      return null;
    }
  }

  /// Supprime un avis
  Future<bool> deleteReview(String reviewId) async {
    if (_token == null) return false;
    
    try {
      await _dio.delete(
        '$_baseUrl/reviews/$reviewId/',
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print("Delete Review Error: $e");
      return false;
    }
  }

  /// Marque un avis comme utile
  Future<int?> markReviewHelpful(String reviewId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/reviews/$reviewId/helpful/',
        options: _authOptions,
      );
      return response.data['helpful_count'];
    } catch (e) {
      print("Mark Helpful Error: $e");
      return null;
    }
  }

  /// Répond à un avis (dev uniquement)
  Future<bool> respondToReview(String reviewId, String response) async {
    if (_token == null) return false;
    
    try {
      await _dio.post(
        '$_baseUrl/reviews/$reviewId/respond/',
        data: {'response': response},
        options: _authOptions,
      );
      return true;
    } catch (e) {
      print("Respond Review Error: $e");
      return false;
    }
  }
}

/// Réponse paginée pour les apps
class StoreAppsResponse {
  final List<MiniApp> apps;
  final int total;
  final int limit;
  final int offset;

  StoreAppsResponse({
    required this.apps,
    required this.total,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + apps.length < total;
}

/// Réponse pour les apps d'une catégorie
class CategoryAppsResponse {
  final AppCategory category;
  final List<MiniApp> apps;
  final int total;

  CategoryAppsResponse({
    required this.category,
    required this.apps,
    required this.total,
  });
}

/// Réponse pour les avis
class ReviewsResponse {
  final List<AppReview> reviews;
  final int total;
  final double averageRating;
  final int ratingsCount;

  ReviewsResponse({
    required this.reviews,
    required this.total,
    required this.averageRating,
    required this.ratingsCount,
  });
}
