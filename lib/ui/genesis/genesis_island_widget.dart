import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/genesis_island_service.dart';
import '../../core/utils/app_navigator.dart';
import '../../core/utils/logger.dart';
import 'genesis_workspace.dart';

// ---------------------------------------------------------------------------
// GenesisIslandWidget
// A Dynamic Island–style floating pill rendered on top of the entire app
// (placed in MaterialApp.builder). It listens to GenesisIslandService and
// animates between three states: generating → done → error.
// ---------------------------------------------------------------------------
class GenesisIslandWidget extends StatefulWidget {
  const GenesisIslandWidget({super.key});

  @override
  State<GenesisIslandWidget> createState() => _GenesisIslandWidgetState();
}

class _GenesisIslandWidgetState extends State<GenesisIslandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinCtrl;
  Timer? _autoDismissTimer;
  IslandState _prevState = IslandState.idle;

  @override
  void initState() {
    super.initState();
    // The spinning arc used while generating.
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    GenesisIslandService().addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    final svc = GenesisIslandService();
    final newState = svc.state;

    // Auto-dismiss "done" island after 8 s unless user already acted.
    if (newState == IslandState.done && _prevState != IslandState.done) {
      _autoDismissTimer?.cancel();
      _autoDismissTimer = Timer(const Duration(seconds: 8), () {
        GenesisIslandService().dismiss();
      });
    } else if (newState != IslandState.done) {
      _autoDismissTimer?.cancel();
    }

    _prevState = newState;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _autoDismissTimer?.cancel();
    GenesisIslandService().removeListener(_onServiceChanged);
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openWorkspace() {
    final project = GenesisIslandService().result;
    if (project == null) return;
    GenesisIslandService().dismiss();
    try {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => GenesisWorkspace(project: project),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      AppLogger.error('GenesisIsland', 'navigation failed', e);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = GenesisIslandService();
    final topPad = MediaQuery.of(context).padding.top;
    final isVisible = svc.isVisible;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 450),
          curve: isVisible ? Curves.easeOutBack : Curves.easeInCubic,
          offset: isVisible ? Offset.zero : const Offset(0, -2.0),
          child: AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: EdgeInsets.only(top: topPad + 10),
              child: Center(
                child: _buildPill(svc),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(GenesisIslandService svc) {
    // Size varies per state.
    double width;
    double height;

    switch (svc.state) {
      case IslandState.generating:
        width = 230;
        height = 42;
        break;
      case IslandState.done:
        width = 320;
        height = 60;
        break;
      case IslandState.error:
        width = 270;
        height = 52;
        break;
      case IslandState.idle:
        width = 120;
        height = 36;
        break;
    }

    // Border / glow color.
    Color borderColor;
    Color glowColor;
    switch (svc.state) {
      case IslandState.done:
        borderColor = const Color(0xFF00E676).withAlpha(180);
        glowColor = const Color(0xFF00E676).withAlpha(60);
        break;
      case IslandState.error:
        borderColor = const Color(0xFFEF4444).withAlpha(180);
        glowColor = const Color(0xFFEF4444).withAlpha(60);
        break;
      default:
        borderColor = const Color(0xFF7C3AED).withAlpha(180);
        glowColor = const Color(0xFF7C3AED).withAlpha(50);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(150),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildContent(svc),
        ),
      ),
    );
  }

  Widget _buildContent(GenesisIslandService svc) {
    switch (svc.state) {
      case IslandState.generating:
        return _GeneratingContent(
          key: const ValueKey('generating'),
          title: svc.title,
          spinCtrl: _spinCtrl,
        );

      case IslandState.done:
        return _DoneContent(
          key: const ValueKey('done'),
          title: svc.title,
          onOpen: _openWorkspace,
          onDismiss: GenesisIslandService().dismiss,
        );

      case IslandState.error:
        return _ErrorContent(
          key: const ValueKey('error'),
          onDismiss: GenesisIslandService().dismiss,
        );

      case IslandState.idle:
        return const SizedBox.shrink(key: ValueKey('idle'));
    }
  }
}

// ---------------------------------------------------------------------------
// Generating sub-widget
// ---------------------------------------------------------------------------
class _GeneratingContent extends StatelessWidget {
  final String title;
  final AnimationController spinCtrl;

  const _GeneratingContent({
    super.key,
    required this.title,
    required this.spinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning arc
            AnimatedBuilder(
              animation: spinCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(18, 18),
                painter: _ArcSpinnerPainter(
                  progress: spinCtrl.value,
                  color: const Color(0xFF7C3AED),
                  accentColor: const Color(0xFF06B6D4),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                ).createShader(b),
                child: const Text(
                  'GENESIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF888BA8),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      )
    );
  }
}

// ---------------------------------------------------------------------------
// Done sub-widget
// ---------------------------------------------------------------------------
class _DoneContent extends StatelessWidget {
  final String title;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _DoneContent({
    super.key,
    required this.title,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Check icon with green glow
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E676).withAlpha(30),
              border: Border.all(
                color: const Color(0xFF00E676).withAlpha(150),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF00E676),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Génération terminée',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Open button
          GestureDetector(
            onTap: onOpen,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Ouvrir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Dismiss
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error sub-widget
// ---------------------------------------------------------------------------
class _ErrorContent extends StatelessWidget {
  final VoidCallback onDismiss;

  const _ErrorContent({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withAlpha(30),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'La génération a échoué',
              style: TextStyle(
                color: Color(0xFFFCA5A5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arc spinner painter — a rotating gradient arc.
// ---------------------------------------------------------------------------
class _ArcSpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color accentColor;

  const _ArcSpinnerPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;

    // Background track
    final trackPaint = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Spinning arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [color, accentColor],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final startAngle = 2 * math.pi * progress - math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 1.2,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcSpinnerPainter old) =>
      old.progress != progress;
}
