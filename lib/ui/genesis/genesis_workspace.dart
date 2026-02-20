import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import '../../bridge/bridge_controller.dart';
import '../../bridge/ondes_js_injection.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/genesis_service.dart';
import '../../core/services/genesis_island_service.dart';
import '../../core/services/permission_manager_service.dart';
import '../../core/utils/logger.dart';
import '../lab/app_edit_screen.dart';
import 'genesis_quota_widget.dart';

// ---------------------------------------------------------------------------
// Error-capture JS snippet injected alongside the Bridge.
// Sends window.onerror events back to Flutter via a dedicated JS handler.
// ---------------------------------------------------------------------------
const String _errorCaptureJs = r"""
(function() {
    window.onerror = function(message, source, lineno, colno, error) {
        try {
            window.flutter_inappwebview.callHandler(
                'Genesis.reportError',
                { message: String(message), source: String(source || ''), lineno: lineno || 0 }
            );
        } catch(e) {}
        return false; // let default handling continue
    };
    window.addEventListener('unhandledrejection', function(event) {
        try {
            window.flutter_inappwebview.callHandler(
                'Genesis.reportError',
                { message: String(event.reason || 'Unhandled Promise rejection'), source: '', lineno: 0 }
            );
        } catch(e) {}
    });
})();
""";

// ---------------------------------------------------------------------------
// GenesisWorkspace
// Full-screen AI Mini-App creator: WebView preview + chat interface.
// ---------------------------------------------------------------------------

class GenesisWorkspace extends StatefulWidget {
  /// Pass an existing project to continue working on it.
  /// Pass null to start from a fresh prompt.
  final GenesisProject? project;

  const GenesisWorkspace({super.key, this.project});

  @override
  State<GenesisWorkspace> createState() => _GenesisWorkspaceState();
}

class _GenesisWorkspaceState extends State<GenesisWorkspace>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  GenesisProject? _project;
  bool _loading = false;
  String? _errorMessage;
  GenesisQuota? _quota;

  // When non-null the WebView shows this historical version instead of current.
  ProjectVersion? _viewingVersion;

  // Panel visibility
  bool _chatOpen = true;

  // Text input
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // WebView
  InAppWebViewController? _webController;
  late OndesBridgeController _bridge;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // All permissions GENESIS preview is allowed to use.
  // GENESIS is a first-party trusted environment — it may generate apps that
  // use any SDK feature, so we grant the full set upfront.
  static const List<String> _allPermissions = [
    'location', 'camera', 'storage', 'social',
    'chat', 'websocket', 'udp', 'friends', 'user',
  ];

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _project = widget.project;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    // Pre-grant all permissions so the sandbox never blocks AI-generated code.
    PermissionManagerService().grantPermissions('genesis.preview', _allPermissions);

    // If a project with existing code is passed in, show it immediately (opacity = 1).
    if (widget.project?.currentVersion?.htmlCode.isNotEmpty == true) {
      _animController.value = 1.0;
    }

    _bridge = OndesBridgeController(
      context,
      appBundleId: 'genesis.preview',
    );

    _loadQuota();

    // ── Re-sync with a possible in-flight generation ──────────────────────
    // The user may have navigated away while the LLM was running (the island
    // kept the request alive). On re-entry we restore the correct UI state.
    final island = GenesisIslandService();
    final myId = _project?.id;
    final islandForMe = island.projectId == null ||
        myId == null ||
        island.projectId == myId;

    if (islandForMe) {
      if (island.state == IslandState.generating) {
        // LLM still running → show spinner immediately.
        _loading = true;
      } else if (island.state == IslandState.done && island.result != null) {
        // LLM finished while we were gone → apply result right away.
        _project = island.result;
        if (_project?.currentVersion?.htmlCode.isNotEmpty == true) {
          _animController.value = 1.0;
        }
      }
    }

    island.addListener(_onIslandChanged);
  }

  @override
  void dispose() {
    GenesisIslandService().removeListener(_onIslandChanged);
    _inputController.dispose();
    _chatScrollController.dispose();
    _animController.dispose();
    _bridge.dispose();
    // Revoke permissions when the workspace is closed.
    PermissionManagerService().revokePermissions('genesis.preview');
    super.dispose();
  }

  // ── Island listener ──────────────────────────────────────────────────

  void _onIslandChanged() {
    if (!mounted) return;
    final island = GenesisIslandService();
    final myId = _project?.id;

    // Only react to events that concern our project (or a new creation).
    if (island.projectId != null &&
        myId != null &&
        island.projectId != myId) {
      return;
    }

    if (island.state == IslandState.done && island.result != null) {
      final updated = island.result!;
      setState(() {
        _project = updated;
        _viewingVersion = null;
        _loading = false;
      });
      _scrollToBottom();
      if (updated.currentVersion?.htmlCode.isNotEmpty == true) {
        _loadHtmlInWebView(updated.currentVersion!.htmlCode).then((_) {
          if (mounted) _animController.forward(from: 0);
        });
      }
    } else if (island.state == IslandState.error) {
      setState(() {
        _loading = false;
        _errorMessage = island.errorMessage;
      });
    } else if (island.state == IslandState.generating) {
      if (!_loading) setState(() => _loading = true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// HTML currently displayed — either a historical preview or the live version.
  String? get _currentHtml =>
      _viewingVersion?.htmlCode ?? _project?.currentVersion?.htmlCode;

  List<ConversationTurn> get _conversation =>
      _project?.conversation
          .where((t) => t.role != 'system')
          .toList() ??
      [];

  /// Load the generated HTML into the WebView as a data URI.
  Future<void> _loadHtmlInWebView(String html) async {
    if (_webController == null) return;
    // Use loadData for isolated HTML content (no origin)
    await _webController!.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  /// Scroll chat to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Quota ─────────────────────────────────────────────────────────────────

  Future<void> _loadQuota() async {
    try {
      final quota = await GenesisService().getQuota();
      if (mounted) setState(() => _quota = quota);
    } catch (_) {}
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    _inputController.clear();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Notify the Dynamic Island — the user can now navigate away freely
    // while the LLM is running; the island will notify them on completion.
    final islandTitle =
        _project?.title ?? text.substring(0, text.length.clamp(0, 50));
    GenesisIslandService().startGeneration(
      title: islandTitle,
      projectId: _project?.id,
    );

    try {
      GenesisProject updated;
      if (_project == null) {
        // First message → create project
        updated = await GenesisService().createProject(prompt: text);
      } else {
        // Subsequent messages → iterate
        updated = await GenesisService().iterate(
          projectId: _project!.id,
          feedback: text,
        );
      }

      // Signal completion to the island regardless of whether the workspace
      // is still mounted (user may have navigated away).
      GenesisIslandService().complete(updated);

      if (!mounted) return;

      if (updated.quota != null) {
        _quota = updated.quota;
      }
      setState(() {
        _project = updated;
        _viewingVersion = null;
      });
      _scrollToBottom();

      if (updated.currentVersion?.htmlCode.isNotEmpty == true) {
        await _loadHtmlInWebView(updated.currentVersion!.htmlCode);
        _animController.forward(from: 0);
        // Automatically show the preview when code arrives
        if (_chatOpen && updated.currentVersion!.versionNumber == 1) {
          if (mounted) setState(() => _chatOpen = false);
        }
      }
    } catch (e) {
      AppLogger.error('GenesisWorkspace', 'API call failed', e);
      GenesisIslandService().fail(e.toString());
      if (!mounted) return;

      String errorMsg = e.toString();
      if (e is DioException && e.response?.statusCode == 402) {
        final data = e.response?.data as Map<String, dynamic>?;
        errorMsg = data?['message'] as String? ?? 'Quota de créations épuisé.';
        if (data?['quota'] != null) {
          _quota = GenesisQuota.fromJson(data!['quota'] as Map<String, dynamic>);
        } else {
          _loadQuota();
        }
        setState(() => _errorMessage = errorMsg);
        GenesisQuotaBadge.openSheet(context, _quota);
      } else {
        setState(() => _errorMessage = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleError(Map<String, dynamic> payload) async {
    if (_project == null) return;
    final message = payload['message']?.toString() ?? '';
    final source = payload['source']?.toString();
    final lineno = payload['lineno'] as int?;

    AppLogger.warning('GenesisWorkspace', 'JS Error caught: $message');

    if (mounted) setState(() => _loading = true);
    GenesisIslandService().startGeneration(
      title: _project!.title,
      projectId: _project!.id,
    );

    try {
      final updated = await GenesisService().reportError(
        projectId: _project!.id,
        message: message,
        source: source,
        lineno: lineno,
      );
      GenesisIslandService().complete(updated);
      if (!mounted) return;
      setState(() => _project = updated);
      if (updated.currentVersion?.htmlCode.isNotEmpty == true) {
        await _loadHtmlInWebView(updated.currentVersion!.htmlCode);
      }
    } catch (e) {
      AppLogger.error('GenesisWorkspace', 'auto-fix failed', e);
      GenesisIslandService().fail(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePublishOrUpdate() async {
    if (_project == null || _loading) return;
    final isUpdate = _project!.isDeployed;
    final title = isUpdate ? 'Mettre à jour sur le Store' : 'Créer un brouillon';
    final description = isUpdate
        ? 'La version v${_project!.currentVersion?.versionNumber} remplacera la version précédente sur le Store Ondes.'
        : 'Un brouillon sera créé pour "${_project!.title}". Tu pourras ensuite compléter sa fiche (icône, catégorie, description…) pour le publier sur le Store.';
    final ctaLabel = isUpdate ? 'Mettre à jour' : 'Créer le brouillon';

    // ── Confirmation bottom sheet ──────────────────────────────────────────
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GenesisPublishSheet(
        title: title,
        description: description,
        appName: _project!.title,
        versionNumber: _project!.currentVersion?.versionNumber ?? 1,
        ctaLabel: ctaLabel,
        isUpdate: isUpdate,
      ),
    );
    if (confirmed != true || !mounted) return;

    // ── Call API ──────────────────────────────────────────────────────────
    setState(() => _loading = true);
    try {
      final updated = await GenesisService().publishToStore(_project!.id);
      setState(() => _project = updated);
      if (!mounted) return;

      // ── Success bottom sheet ──────────────────────────────────────────
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        builder: (ctx) => _GenesisPublishSuccessSheet(
          appName: updated.title,
          storeAppId: updated.storeAppId,
          isUpdate: isUpdate,
          onCompleteMetadata: updated.storeAppId != null
              ? () {
                  Navigator.pop(ctx);
                  // Build a minimal MiniApp shell so AppEditScreen can fetch details
                  final shell = MiniApp(
                    dbId: updated.storeAppId,
                    id: 'genesis.${updated.id}',
                    name: updated.title,
                    version: '1.0.0',
                    description: '',
                    iconUrl: '',
                    downloadUrl: '',
                    sourceType: 'genesis',
                    genesisProjectId: updated.id,
                    isPublished: false,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AppEditScreen(app: shell)),
                  );
                }
              : null,
        ),
      );
    } catch (e) {
      AppLogger.error('GenesisWorkspace', 'publishToStore failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  // ── Version preview ───────────────────────────────────────────────────────

  /// Fetches the full HTML for [summary] and loads it in the WebView.
  Future<void> _loadVersionForPreview(VersionSummary summary) async {
    if (_project == null) return;
    setState(() => _loading = true);
    try {
      final version = await GenesisService().getVersionHtml(
        _project!.id,
        summary.id,
      );
      setState(() => _viewingVersion = version);
      await _loadHtmlInWebView(version.htmlCode);
      // Close history sheet if still open
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      AppLogger.error('GenesisWorkspace', 'loadVersionForPreview failed', e);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Restore the currently-previewed historical version as a new version.
  Future<void> _restoreVersion() async {
    final html = _viewingVersion?.htmlCode;
    if (html == null || _project == null) return;
    final vNum = _viewingVersion!.versionNumber;
    setState(() => _loading = true);
    try {
      final updated = await GenesisService().saveEdit(
        projectId: _project!.id,
        htmlCode: html,
        description: 'Restauration de la v$vNum',
      );
      setState(() {
        _project = updated;
        _viewingVersion = null;
      });
      await _loadHtmlInWebView(updated.currentVersion!.htmlCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u2705 Version $vNum restaur\u00e9e comme nouvelle version'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('GenesisWorkspace', 'restoreVersion failed', e);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Opens the version history bottom sheet.
  void _showVersionHistory() {
    final versions = _project?.versions ?? [];
    if (versions.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentVersionNumber =
            _project?.currentVersion?.versionNumber ?? 0;
        // Sort descending so the latest is on top.
        final sorted = [...versions]
          ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3F3F6E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                    ).createShader(b),
                    child: const Icon(Icons.history, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Historique des versions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF1E293B), height: 1),
                itemBuilder: (_, i) {
                  final v = sorted[i];
                  final isCurrent = v.versionNumber == currentVersionNumber;
                  final isViewing =
                      _viewingVersion?.versionNumber == v.versionNumber;

                  return ListTile(
                    onTap: isCurrent
                        ? null
                        : () => _loadVersionForPreview(v),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isCurrent
                              ? [const Color(0xFF7C3AED), const Color(0xFF06B6D4)]
                              : [const Color(0xFF1E1B4B), const Color(0xFF1E1B4B)],
                        ),
                        border: Border.all(
                          color: isCurrent
                              ? Colors.transparent
                              : const Color(0xFF3F3F6E),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'v${v.versionNumber}',
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : const Color(0xFF818CF8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      v.changeDescription,
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatRelativeDate(v.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF4338CA), width: 0.8),
                            ),
                            child: const Text(
                              'actuelle',
                              style: TextStyle(
                                  color: Color(0xFF818CF8), fontSize: 10),
                            ),
                          )
                        else if (isViewing)
                          const Icon(Icons.visibility,
                              size: 16, color: Color(0xFF06B6D4))
                        else
                          const Icon(Icons.chevron_right,
                              size: 16, color: Color(0xFF4B5563)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// Opens the HTML code editor (developer feature).
  void _showCodeEditor() {
    final initialHtml = _currentHtml ?? '';
    final codeController = TextEditingController(text: initialHtml);
    final descController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F3F6E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.code,
                            color: Color(0xFF06B6D4), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          '\u00c9diteur HTML',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.save_rounded,
                              size: 16, color: Color(0xFF06B6D4)),
                          label: const Text(
                            'Sauvegarder',
                            style: TextStyle(color: Color(0xFF06B6D4)),
                          ),
                          onPressed: () async {
                            final html = codeController.text.trim();
                            if (html.isEmpty) return;
                            Navigator.pop(ctx);
                            setState(() => _loading = true);
                            try {
                              final desc = descController.text.trim().isEmpty
                                  ? '\u00c9dition manuelle'
                                  : descController.text.trim();
                              final updated = await GenesisService().saveEdit(
                                projectId: _project!.id,
                                htmlCode: html,
                                description: desc,
                              );
                              setState(() {
                                _project = updated;
                                _viewingVersion = null;
                              });
                              await _loadHtmlInWebView(
                                  updated.currentVersion!.htmlCode);
                              _animController.forward(from: 0);
                            } catch (e) {
                              AppLogger.error(
                                  'GenesisWorkspace', 'saveEdit failed', e);
                            } finally {
                              setState(() => _loading = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Description field
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: descController,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Description de la modification (optionnel)',
                        hintStyle: const TextStyle(
                            color: Color(0xFF4B5563), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF13131F),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D2B55)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF2D2B55)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF06B6D4)),
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  // Code editor
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      child: Container(
                        color: const Color(0xFF0D1117),
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: codeController,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      codeController.dispose();
      descController.dispose();
    });
  }

  String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "\u00e0 l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Preview ──
          Expanded(
            flex: _chatOpen ? 1 : 3,
            child: _buildPreview(),
          ),
          // ── Divider + toggle ──
          _buildPanelDivider(),
          // ── Chat ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _chatOpen
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: _buildChatPanel(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D1A),
      elevation: 0,
      title: Row(
        children: [
          // Neon GENESIS logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
            ).createShader(bounds),
            child: const Text(
              'GENESIS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 18,
              ),
            ),
          ),
          if (_project != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _project!.title,
                style: const TextStyle(
                  color: Color(0xFF888BA8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_quota != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GenesisQuotaBadge(quota: _quota!, isCompact: true),
          ),
        if (_project?.currentVersion != null) ...[
          // Version history button
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 20),
            color: const Color(0xFF888BA8),
            tooltip: 'Historique des versions',
            onPressed: _showVersionHistory,
          ),
          // Code editor button (developer feature)
          IconButton(
            icon: const Icon(Icons.code_rounded, size: 20),
            color: const Color(0xFF888BA8),
            tooltip: 'Éditeur HTML',
            onPressed: _showCodeEditor,
          ),
          // Version chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4338CA), width: 0.8),
            ),
            alignment: Alignment.center,
            child: Text(
              'v${_project!.currentVersion!.versionNumber}',
              style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
            ),
          ),
          // Deploy / Update / In-sync / Draft button
          if (_project!.isDeployed && !_project!.isStoreDraft && !_project!.hasUnpublishedChanges)
            // Already in sync — disabled green rocket
            GestureDetector(
              onTap: () {
                
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: 'Store à jour',
                  child: Icon(
                    Icons.rocket_launch,
                    color: const Color(0xFF00E676),
                    size: 22,
                  ),
                ),
              )
            )
          else if (_project!.isStoreDraft)
            // Draft: pushed but metadata not completed
            Tooltip(
              message: 'Compléter la fiche pour publier',
              child: IconButton(
                icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                onPressed: () {
                  final shell = MiniApp(
                    dbId: _project!.storeAppId,
                    id: 'genesis.${_project!.id}',
                    name: _project!.title,
                    version: '1.0.0',
                    description: '',
                    iconUrl: '',
                    downloadUrl: '',
                    sourceType: 'genesis',
                    genesisProjectId: _project!.id,
                    isPublished: false,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AppEditScreen(app: shell)),
                  ).then((_) async {
                    // Reload project to reflect new storeAppIsPublished
                    try {
                      final updated = await GenesisService().getProject(_project!.id);
                      if (mounted) setState(() => _project = updated);
                    } catch (_) {}
                  });
                },
              ),
            )
          else
            IconButton(
              icon: Icon(
                _project!.isDeployed
                    ? Icons.system_update_alt_rounded
                    : Icons.rocket_launch_outlined,
                color: _project!.isDeployed
                    ? const Color(0xFF06B6D4)   // cyan = update
                    : const Color(0xFF888BA8),   // grey = not yet published
              ),
              tooltip: _project!.isDeployed ? 'Mettre à jour le Store' : 'Publier sur le Store',
              onPressed: _handlePublishOrUpdate,
            ),
        ],
        // Toggle chat panel
        IconButton(
          icon: Icon(
            _chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
            color: const Color(0xFF7C3AED),
          ),
          tooltip: _chatOpen ? 'Masquer le chat' : 'Afficher le chat',
          onPressed: () => setState(() => _chatOpen = !_chatOpen),
        ),
      ],
    );
  }

  // ── Preview pane ──────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (_currentHtml == null) {
      return _buildEmptyPreview();
    }

    return Stack(
      children: [
        FadeTransition(
          opacity: _fadeAnim,
          child: _buildWebView(),
        ),
        if (_loading)
          Container(
            color: Colors.black54,
            child: const Center(child: _NeonLoader()),
          ),
        // Historical version banner
        if (_viewingVersion != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildVersionBanner(_viewingVersion!),
          ),
      ],
    );
  }

  Widget _buildVersionBanner(ProjectVersion version) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.92),
            const Color(0xFF1E1040).withOpacity(0.92),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            'Aperçu v${version.versionNumber}',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '— ${version.changeDescription}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Restore button
          GestureDetector(
            onTap: _loading ? null : _restoreVersion,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF06B6D4).withOpacity(0.6), width: 0.8),
              ),
              child: const Text(
                'Restaurer',
                style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Close preview
          GestureDetector(
            onTap: () async {
              setState(() => _viewingVersion = null);
              final html = _project?.currentVersion?.htmlCode;
              if (html != null) await _loadHtmlInWebView(html);
            },
            child: const Icon(Icons.close, size: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreview() {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(b),
              child: const Icon(Icons.auto_awesome, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Décris ta Mini-App ci-dessous\npour la générer avec GENESIS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF888BA8),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return ClipRRect(
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: _currentHtml ?? '<html><body></body></html>',
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          transparentBackground: true,
          isInspectable: false,
        ),
        onWebViewCreated: (controller) {
          _webController = controller;
          _bridge.setController(controller);

          // Register error handler
          controller.addJavaScriptHandler(
            handlerName: 'Genesis.reportError',
            callback: (args) {
              if (args.isNotEmpty) {
                final payload = args.first;
                if (payload is Map) {
                  _handleError(Map<String, dynamic>.from(payload));
                }
              }
            },
          );
        },
        onLoadStop: (controller, url) async {
          // 1. Inject the Ondes Bridge
          await controller.evaluateJavascript(source: ondesBridgeJs);
          // 2. Inject the error capture snippet to send to api
          await controller.evaluateJavascript(source: _errorCaptureJs);
        },
        onConsoleMessage: (controller, msg) {
          AppLogger.debug('Genesis WebView', msg.message);
        },
      ),
    );
  }

  // ── Panel divider ─────────────────────────────────────────────────────────

  Widget _buildPanelDivider() {
    return GestureDetector(
      onTap: () => setState(() => _chatOpen = !_chatOpen),
      child: Container(
        height: 28,
        color: const Color(0xFF0D0D1A),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3F3F6E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── Chat panel ────────────────────────────────────────────────────────────

  Widget _buildChatPanel() {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: Column(
        children: [
          // Message list
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _conversation.length + (_errorMessage != null ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_errorMessage != null && i == _conversation.length) {
                  return _buildErrorBubble(_errorMessage!);
                }
                return _buildMessageBubble(_conversation[i]);
              },
            ),
          ),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationTurn turn) {
    final isUser = turn.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // GENESIS avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                ),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF1E1B4B)
                    : const Color(0xFF13131F),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF4338CA).withOpacity(0.4)
                      : const Color(0xFF1E293B),
                ),
              ),
              child: Text(
                turn.content,
                style: TextStyle(
                  color: isUser
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBubble(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A0A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFF13131F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D2B55)),
              ),
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _project == null
                      ? 'Décris ta Mini-App…'
                      : 'Modifie, ajoute une fonctionnalité…',
                  hintStyle:
                      const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                    ),
                  ),
                )
              : _SendButton(onTap: _handleSend),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _NeonLoader extends StatefulWidget {
  const _NeonLoader();

  @override
  State<_NeonLoader> createState() => _NeonLoaderState();
}

class _NeonLoaderState extends State<_NeonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _ctrl,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF06B6D4), Colors.transparent],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0A0A0F),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'GENESIS génère…',
          style: TextStyle(
            color: Color(0xFF7C3AED),
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Publish / Update confirmation bottom sheet
// ---------------------------------------------------------------------------

class _GenesisPublishSheet extends StatelessWidget {
  final String title;
  final String description;
  final String appName;
  final int versionNumber;
  final String ctaLabel;
  final bool isUpdate;

  const _GenesisPublishSheet({
    required this.title,
    required this.description,
    required this.appName,
    required this.versionNumber,
    required this.ctaLabel,
    required this.isUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2B55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Icon + title
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
            ).createShader(b),
            child: Icon(
              isUpdate ? Icons.system_update_alt_rounded : Icons.rocket_launch_outlined,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // App pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4338CA), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF818CF8)),
                const SizedBox(width: 6),
                Text(
                  appName,
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF312E81),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'v1.${versionNumber - 1}.0',
                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(ctaLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF4B5563), fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Publish / Update success bottom sheet
// ---------------------------------------------------------------------------

class _GenesisPublishSuccessSheet extends StatelessWidget {
  final String appName;
  final int? storeAppId;
  final bool isUpdate;
  final VoidCallback? onCompleteMetadata;

  const _GenesisPublishSuccessSheet({
    required this.appName,
    required this.storeAppId,
    required this.isUpdate,
    this.onCompleteMetadata,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2B55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Success icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E676).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF00E676), size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            isUpdate ? 'Store mis à jour !' : 'Brouillon créé !',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isUpdate
                ? '"$appName" est maintenant mise à jour sur le Store Ondes.'
                : 'Complète la fiche de "${appName.length > 30 ? "${appName.substring(0, 30)}..." : appName}" pour la rendre\nvisible dans le Store.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const SizedBox(height: 24),
          // Actions
          if (!isUpdate && onCompleteMetadata != null) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton.icon(
                  onPressed: onCompleteMetadata,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    'Compléter la fiche (Studio)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Color(0xFF4B5563), fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
