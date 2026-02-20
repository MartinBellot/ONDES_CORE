import 'package:flutter/material.dart';
import '../../core/services/genesis_service.dart';
import '../../core/utils/logger.dart';
import 'genesis_workspace.dart';
import 'genesis_quota_widget.dart';

/// Lists all Genesis projects for the current user and allows creating a new one.
class GenesisScreen extends StatefulWidget {
  const GenesisScreen({super.key});

  @override
  State<GenesisScreen> createState() => _GenesisScreenState();
}

class _GenesisScreenState extends State<GenesisScreen> {
  List<GenesisProject> _projects = [];
  bool _loading = true;
  GenesisQuota? _quota;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        GenesisService().listProjects(),
        GenesisService().getQuota(),
      ]);
      _projects = results[0] as List<GenesisProject>;
      _quota = results[1] as GenesisQuota;
    } catch (e) {
      AppLogger.error('GenesisScreen', 'load failed', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNew() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const GenesisWorkspace(),
        fullscreenDialog: true,
      ),
    );
    _load();
  }

  Future<void> _openProject(GenesisProject p) async {
    // Fetch full detail first (includes html_code)
    GenesisProject? full;
    try {
      full = await GenesisService().getProject(p.id);
    } catch (_) {
      full = p;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GenesisWorkspace(project: full),
        fullscreenDialog: true,
      ),
    );
    _load();
  }

  Future<void> _delete(GenesisProject p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Supprimer ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Supprimer "${p.title}" et toutes ses versions ?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF818CF8))),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444))),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GenesisService().deleteProject(p.id);
      _load();
    } catch (e) {
      AppLogger.error('GenesisScreen', 'delete failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
          ).createShader(b),
          child: const Text(
            'GENESIS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
        actions: [
          if (_quota != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GenesisQuotaBadge(quota: _quota!),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
              ),
            )
          : _projects.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF7C3AED),
                  backgroundColor: const Color(0xFF0D0D1A),
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _projects.length,
                    itemBuilder: (_, i) => _buildProjectCard(_projects[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text(
          'Nouvelle App',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(b),
            child: const Icon(Icons.rocket_launch, size: 72, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune Mini-App générée',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Appuie sur « Nouvelle App » pour commencer',
            style: TextStyle(color: Color(0xFF888BA8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(GenesisProject project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: project.isDeployed
              ? const Color(0xFF00E676).withOpacity(0.3)
              : const Color(0xFF2D2B55),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: project.isDeployed
                  ? [const Color(0xFF059669), const Color(0xFF34D399)]
                  : [const Color(0xFF7C3AED), const Color(0xFF06B6D4)],
            ),
          ),
          child: Icon(
            project.isDeployed ? Icons.rocket_launch : Icons.auto_awesome,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          project.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${_formatDate(project.updatedAt)}  •  '
          '${project.currentVersionNumber > 0 ? "v${project.currentVersionNumber}" : "Aucune version"}',
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.isDeployed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFF4B5563), size: 20),
              onPressed: () => _delete(project),
              tooltip: 'Supprimer',
            ),
          ],
        ),
        onTap: () => _openProject(project),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// Extension for list screen compatibility (uses currentVersionNumber, not full object)
extension GenesisProjectListExt on GenesisProject {
  int get currentVersionNumber => currentVersion?.versionNumber ?? 0;
}
