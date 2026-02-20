import 'dart:convert';
import 'package:dio/dio.dart';
import 'configuration_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GenesisQuota
// ─────────────────────────────────────────────────────────────────────────────

class GenesisQuota {
  final String plan;
  final int creationsThisMonth;
  final int monthlyLimit;
  final int extraCredits;
  final int remainingCreations;
  final DateTime monthResetDate;
  final String subscriptionPeriod; // 'monthly' | 'yearly' | ''
  final DateTime? subscriptionEndDate;

  GenesisQuota({
    required this.plan,
    required this.creationsThisMonth,
    required this.monthlyLimit,
    required this.extraCredits,
    required this.remainingCreations,
    required this.monthResetDate,
    this.subscriptionPeriod = '',
    this.subscriptionEndDate,
  });

  factory GenesisQuota.fromJson(Map<String, dynamic> json) {
    return GenesisQuota(
      plan: json['plan'] as String,
      creationsThisMonth: json['creations_this_month'] as int,
      monthlyLimit: json['monthly_limit'] as int,
      extraCredits: json['extra_credits'] as int,
      remainingCreations: json['remaining_creations'] as int,
      monthResetDate: DateTime.parse(json['month_reset_date'] as String),
      subscriptionPeriod: json['subscription_period'] as String? ?? '',
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.parse(json['subscription_end_date'] as String)
          : null,
    );
  }

  bool get isPro => plan == 'pro';
  bool get canCreate => remainingCreations > 0;
  double get usagePercent =>
      monthlyLimit == 0 ? 1.0 : (creationsThisMonth / monthlyLimit).clamp(0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// GenesisProject
// ─────────────────────────────────────────────────────────────────────────────

/// Data model for a Genesis project.
class GenesisProject {
  final String id;
  final String title;
  final bool isDeployed;
  /// The genesis version_number that was last pushed to the Store (0 = never).
  final int deployedVersionNumber;
  /// The Store MiniApp db id linked to this project (null if not published yet).
  final int? storeAppId;
  /// Whether the linked store app is visible in the public store (false = draft).
  final bool storeAppIsPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectVersion? currentVersion;
  final List<VersionSummary> versions;
  final List<ConversationTurn> conversation;
  final GenesisQuota? quota;

  GenesisProject({
    required this.id,
    required this.title,
    required this.isDeployed,
    this.deployedVersionNumber = 0,
    this.storeAppId,
    this.storeAppIsPublished = false,
    required this.createdAt,
    required this.updatedAt,
    this.currentVersion,
    this.versions = const [],
    this.conversation = const [],
    this.quota,
  });

  /// True when the current genesis version is newer than what was last pushed.
  bool get hasUnpublishedChanges =>
      currentVersion != null &&
      currentVersion!.versionNumber > deployedVersionNumber;

  /// True when the app is a draft in the store (pushed but metadata not completed).
  bool get isStoreDraft => isDeployed && storeAppId != null && !storeAppIsPublished;

  factory GenesisProject.fromJson(Map<String, dynamic> json) {
    return GenesisProject(
      id: json['id'] as String,
      title: json['title'] as String,
      isDeployed: json['is_deployed'] as bool,
      deployedVersionNumber: json['deployed_version_number'] as int? ?? 0,
      storeAppId: json['store_app_id'] as int?,
      storeAppIsPublished: json['store_app_is_published'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      currentVersion: json['current_version'] != null
          ? ProjectVersion.fromJson(json['current_version'] as Map<String, dynamic>)
          : null,
      versions: (json['versions'] as List<dynamic>? ?? [])
          .map((v) => VersionSummary.fromJson(v as Map<String, dynamic>))
          .toList(),
      conversation: (json['conversation'] as List<dynamic>? ?? [])
          .map((t) => ConversationTurn.fromJson(t as Map<String, dynamic>))
          .toList(),
      quota: json['quota'] != null
          ? GenesisQuota.fromJson(json['quota'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// One generated snapshot of the HTML code.
class ProjectVersion {
  final int id;
  final int versionNumber;
  final String htmlCode;
  final String changeDescription;
  final DateTime createdAt;

  ProjectVersion({
    required this.id,
    required this.versionNumber,
    required this.htmlCode,
    required this.changeDescription,
    required this.createdAt,
  });

  factory ProjectVersion.fromJson(Map<String, dynamic> json) {
    return ProjectVersion(
      id: json['id'] as int,
      versionNumber: json['version_number'] as int,
      htmlCode: json['html_code'] as String,
      changeDescription: json['change_description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Lightweight version summary — no HTML content. Used in version history lists.
class VersionSummary {
  final int id;
  final int versionNumber;
  final String changeDescription;
  final DateTime createdAt;

  VersionSummary({
    required this.id,
    required this.versionNumber,
    required this.changeDescription,
    required this.createdAt,
  });

  factory VersionSummary.fromJson(Map<String, dynamic> json) {
    return VersionSummary(
      id: json['id'] as int,
      versionNumber: json['version_number'] as int,
      changeDescription: json['change_description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One message in the conversation with GENESIS.
class ConversationTurn {
  final int id;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;

  ConversationTurn({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Service that wraps every GENESIS API endpoint.
class GenesisService {
  static final GenesisService _instance = GenesisService._internal();
  factory GenesisService() => _instance;
  GenesisService._internal();

  final Dio _dio = Dio();

  String get _base => '${ConfigurationService().apiBaseUrl}/genesis';

  Map<String, String> get _headers {
    final token = AuthService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // -----------------------------------------------------------------------
  // List
  // -----------------------------------------------------------------------

  Future<List<GenesisProject>> listProjects() async {
    try {
      final response = await _dio.get(
        '$_base/',
        options: Options(headers: _headers),
      );
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => GenesisProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('GenesisService', 'listProjects failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Create
  // -----------------------------------------------------------------------

  /// Sends the first user prompt; returns the created project with v1 code.
  Future<GenesisProject> createProject({
    required String prompt,
    String? title,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/create/',
        data: jsonEncode({
          'prompt': prompt,
          if (title != null) 'title': title,
        }),
        options: Options(
          headers: _headers,
          // No receive timeout — LLM with 64K tokens can take several minutes.
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'createProject failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Get
  // -----------------------------------------------------------------------

  Future<GenesisProject> getProject(String projectId) async {
    try {
      final response = await _dio.get(
        '$_base/$projectId/',
        options: Options(headers: _headers),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'getProject failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Iterate
  // -----------------------------------------------------------------------

  /// Send a change request; returns the updated project with the new version.
  Future<GenesisProject> iterate({
    required String projectId,
    required String feedback,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$projectId/iterate/',
        data: jsonEncode({'feedback': feedback}),
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'iterate failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Report Error (auto-fix)
  // -----------------------------------------------------------------------

  Future<GenesisProject> reportError({
    required String projectId,
    required String message,
    String? source,
    int? lineno,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$projectId/report_error/',
        data: jsonEncode({
          'message': message,
          if (source != null) 'source': source,
          if (lineno != null) 'lineno': lineno,
        }),
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'reportError failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Publish to Store (first publish + subsequent updates)
  // -----------------------------------------------------------------------

  /// Publishes or updates the current genesis version on the Ondes Store.
  /// Returns the updated [GenesisProject] which includes [storeAppId].
  Future<GenesisProject> publishToStore(String projectId) async {
    try {
      final response = await _dio.post(
        '$_base/$projectId/publish_to_store/',
        options: Options(headers: _headers),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'publishToStore failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Deploy
  // -----------------------------------------------------------------------

  Future<GenesisProject> deploy(String projectId) async {
    try {
      final response = await _dio.post(
        '$_base/$projectId/deploy/',
        options: Options(headers: _headers),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'deploy failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Delete
  // -----------------------------------------------------------------------

  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete(
        '$_base/$projectId/',
        options: Options(headers: _headers),
      );
    } catch (e) {
      AppLogger.error('GenesisService', 'deleteProject failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Version detail (fetch HTML for a historical version)
  // -----------------------------------------------------------------------

  Future<ProjectVersion> getVersionHtml(String projectId, int versionId) async {
    try {
      final response = await _dio.get(
        '$_base/$projectId/versions/$versionId/',
        options: Options(headers: _headers),
      );
      return ProjectVersion.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'getVersionHtml failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Save manual HTML edit
  // -----------------------------------------------------------------------

  Future<GenesisProject> saveEdit({
    required String projectId,
    required String htmlCode,
    String description = 'Édition manuelle',
  }) async {
    try {
      final response = await _dio.post(
        '$_base/$projectId/save_edit/',
        data: jsonEncode({
          'html_code': htmlCode,
          'description': description,
        }),
        options: Options(headers: _headers),
      );
      return GenesisProject.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'saveEdit failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Quota
  // -----------------------------------------------------------------------

  Future<GenesisQuota> getQuota() async {
    try {
      final response = await _dio.get(
        '$_base/quota/',
        options: Options(headers: _headers),
      );
      return GenesisQuota.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('GenesisService', 'getQuota failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Stripe Checkout
  // -----------------------------------------------------------------------

  /// Returns Stripe Checkout URL for the given price.
  Future<String> getCheckoutUrl({
    required String priceId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await _dio.post(
        '$_base/checkout/',
        data: jsonEncode({
          'price_id': priceId,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        }),
        options: Options(headers: _headers),
      );
      return response.data['checkout_url'] as String;
    } catch (e) {
      AppLogger.error('GenesisService', 'getCheckoutUrl failed', e);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Stripe Customer Portal
  // -----------------------------------------------------------------------

  /// Returns Stripe Customer Portal URL.
  Future<String> getPortalUrl({required String returnUrl}) async {
    try {
      final response = await _dio.post(
        '$_base/portal/',
        data: jsonEncode({'return_url': returnUrl}),
        options: Options(headers: _headers),
      );
      return response.data['portal_url'] as String;
    } catch (e) {
      AppLogger.error('GenesisService', 'getPortalUrl failed', e);
      rethrow;
    }
  }
}
