import 'package:flutter/foundation.dart';
import 'genesis_service.dart';

/// States of the floating GENESIS Dynamic Island.
enum IslandState { idle, generating, done, error }

// ---------------------------------------------------------------------------
// GenesisIslandService
// Singleton ChangeNotifier that drives the global Dynamic Island overlay.
// It is notified by GenesisWorkspace when an LLM call starts / completes,
// so the island can persist and notify the user even after they navigate away.
// ---------------------------------------------------------------------------
class GenesisIslandService extends ChangeNotifier {
  static final GenesisIslandService _instance =
      GenesisIslandService._internal();
  factory GenesisIslandService() => _instance;
  GenesisIslandService._internal();

  // ── State ────────────────────────────────────────────────────────────────

  IslandState _state = IslandState.idle;
  String _title = '';
  String? _projectId;
  GenesisProject? _result;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────

  IslandState get state => _state;
  String get title => _title;
  String? get projectId => _projectId;
  GenesisProject? get result => _result;
  String? get errorMessage => _errorMessage;

  /// True whenever the island should be visible (any non-idle state).
  bool get isVisible => _state != IslandState.idle;

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Call before starting an LLM request. [projectId] may be null when
  /// creating a brand-new project (it will be filled later by [complete]).
  void startGeneration({required String title, String? projectId}) {
    _state = IslandState.generating;
    _title = title;
    _projectId = projectId;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Call when the LLM request succeeds — regardless of screen state.
  void complete(GenesisProject project) {
    _state = IslandState.done;
    _title = project.title;
    _projectId = project.id;
    _result = project;
    _errorMessage = null;
    notifyListeners();
  }

  /// Call when the LLM request fails.
  void fail(String error) {
    _state = IslandState.error;
    _errorMessage = error;
    notifyListeners();
  }

  /// Hides the island.
  void dismiss() {
    _state = IslandState.idle;
    notifyListeners();
  }
}
