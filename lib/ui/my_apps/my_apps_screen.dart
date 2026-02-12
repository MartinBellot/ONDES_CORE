// ignore_for_file: unused_field, unused_element

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/local_server_service.dart';
import '../webview_screen.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> with SingleTickerProviderStateMixin {
  final AppLibraryService _library = AppLibraryService();
  final LocalServerService _server = LocalServerService();
  final TransformationController _transformController = TransformationController();
  
  List<MiniApp> _apps = [];
  bool _isLoading = true;
  bool _hasCentered = false;
  String? _focusedAppId; // Track which app is long-pressed
  
  // Animation for the 'breathing' effect of the universe
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _loadApps();
    
    _breathingController = AnimationController(
        vsync: this, 
        duration: const Duration(seconds: 4)
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final installedApps = await _library.getInstalledApps();
    
    if (mounted) {
      setState(() {
        _apps = installedApps;
        _isLoading = false;
      });
    }
  }

  Future<void> _openApp(MiniApp app) async {
    // If we are in delete mode, clicking an app (even the focused one) should probably just exit delete mode
    // unless we specifically want to allow opening while in edit mode.
    // Let's standard behavior: if focused, just clearing focus is handled by background tap, 
    // but tapping the focused app again usually opens it or toggles.
    // Let's say: If an app is focused, we can't open ANY app. We must clear focus first.
    if (_focusedAppId != null) {
      if (_focusedAppId == app.id) {
         // Tapping the focused app again -> clear focus?
         setState(() => _focusedAppId = null);
         return;
      }
      setState(() => _focusedAppId = null);
      return; 
    }

    try {
      await _server.startServer(appId: app.id);
      final url = _server.localUrl;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              url: url,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: \$e')),
        );
      }
    }
  }

  void _centerGalaxy() {
    const double universeSize = 3000;
    const Offset center = Offset(universeSize / 2, universeSize / 2);
    final size = MediaQuery.of(context).size;
    final double initialScale = 1.0; 
    
    final x = (size.width / 2) - (center.dx * initialScale);
    final y = (size.height / 2) - (center.dy * initialScale);
    
    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(x, y)
      ..scale(initialScale);
    
    // Animate to center
    // For simplicity we just set it, or we could animate _transformController value.
    // Let's just set it directly for the button action to be instant/snappy or use a simple animation loop.
    // Since _breathingController is user for stars, let's just set value for now to keep it simple and robust.
    _transformController.value = endMatrix;
  }

  Future<void> _uninstallApp(MiniApp app) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${app.name} ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      )
    );

    if (confirm == true) {
      await _library.uninstallApp(app.id);
      setState(() {
        _focusedAppId = null;
      });
      _loadApps();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bubble_chart_outlined, size: 64, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(height: 16),
            Text(
              'Votre univers est vide',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Installez des apps pour créer votre galaxie')
          ],
        ),
      );
    }

    // Canvas size for our universe
    const double universeSize = 3000;
    const Offset center = Offset(universeSize / 2, universeSize / 2);

    // Center on arrival
    if (!_hasCentered) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerGalaxy();
       });
      _hasCentered = true;
    }

    return Stack(
      children: [
        // Background Color
        Positioned.fill(
          child: Container(
            color: const Color(0xFF1E1E1E),
          ),
        ),

        // Universe of Bubbles
        InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(universeSize), 
          minScale: 0.1,
          maxScale: 4.0,
          constrained: false, 
          child: GestureDetector(
            onTap: () {
               if (_focusedAppId != null) {
                 setState(() => _focusedAppId = null);
               }
            },
            behavior: HitTestBehavior.translucent, // Catch taps on empty space
            child: SizedBox(
                width: universeSize,
                height: universeSize,
                child: Stack(
                clipBehavior: Clip.none,
                children: [
                    // Grid that moves with the content
                    Positioned.fill(
                        child: CustomPaint(
                            painter: GridBackgroundPainter(),
                        ),
                    ),
                    ..._buildBubbleGalaxy(center, universeSize),
                ],
                ),
            ),
          ),
        ),
        
        // Navigation / Hint overlay
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: 0.5,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    Icon(Icons.touch_app, color: Colors.white.withOpacity(0.3), size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'EXPLORER L\'UNIVERS',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Re-center Button
        Positioned(
            top: 64, // Below standard status bar/pill area
            right: 20,
            child: FloatingActionButton(
                mini: true,
                heroTag: 'center_galaxy',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 3,
                onPressed: _centerGalaxy,
                child: const Icon(Icons.center_focus_strong_outlined, size: 20),
            ),
        ),
      ],
    );
  }

  List<Widget> _buildBubbleGalaxy(Offset center, double universeSize) {
    List<Widget> backgroundBubbles = [];
    Widget? foregroundBubble;
    
    // Hexagonal Packing / Honeycomb-like spiral
    double bubbleSize = 88.0; 
    double gap = 12.0; 
    double unit = bubbleSize + gap;
    
    // Positions (q, r) in axial coordinates
    // Spiral generator
    List<Offset> hexPositions = [const Offset(0, 0)];
    int count = _apps.length;
    
    // If more than 1, generate rings
    if (count > 1) {
        int radius = 1;
        while (hexPositions.length < count) {
            int itemsInThisRing = radius * 6;
            for (int i = 0; i < itemsInThisRing; i++) {
                double angle = (2 * pi / itemsInThisRing) * i;
                double r = radius * unit;
                hexPositions.add(Offset(r * cos(angle), r * sin(angle)));
                
                if (hexPositions.length >= count) break;
            }
            radius++;
        }
    }

    for (int i = 0; i < _apps.length; i++) {
        Offset pos = hexPositions[i];
        // Convert local relative pos to universe center
        double left = center.dx + pos.dx - (bubbleSize / 2);
        double top = center.dy + pos.dy - (bubbleSize / 2);
        
        final bubble = Positioned(
                left: left,
                top: top,
                child: BubbleAppNode(
                    app: _apps[i],
                    size: bubbleSize,
                    isFocused: _apps[i].id == _focusedAppId,
                    onTap: () => _openApp(_apps[i]),
                    onFocus: () {
                        HapticFeedback.heavyImpact();
                        setState(() => _focusedAppId = _apps[i].id);
                    },
                    onDelete: () => _uninstallApp(_apps[i]),
                ),
            );

        if (_apps[i].id == _focusedAppId) {
            foregroundBubble = bubble;
        } else {
            backgroundBubbles.add(bubble);
        }
    }
    
    // Return list with focused bubble LAST (on top)
    if (foregroundBubble != null) {
        return [...backgroundBubbles, foregroundBubble];
    }
    return backgroundBubbles;
  }
}

class BubbleAppNode extends StatefulWidget {
  final MiniApp app;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onFocus; // Long press trigger
  final VoidCallback onDelete;
  final bool isFocused;

  const BubbleAppNode({
    super.key,
    required this.app,
    required this.size,
    required this.onTap,
    required this.onFocus,
    required this.onDelete,
    this.isFocused = false,
  });

  @override
  State<BubbleAppNode> createState() => _BubbleAppNodeState();
}

class _BubbleAppNodeState extends State<BubbleAppNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad)
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String url) {
    if (url.isEmpty) return const AssetImage('assets/placeholder.png'); 
    
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    
    // Everything else is treated as file
    String path = url;
    if (url.startsWith('file://')) {
      try {
        path = Uri.parse(url).toFilePath();
      } catch (e) {
        path = url.replaceFirst('file://', '');
      }
    }
    
    // Decode URI if needed
    path = Uri.decodeFull(path);
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    // Basic scale animation for tap
    final double tapScale = _scaleAnim.value;
    // Focus scale (pop out)
    final double focusScale = widget.isFocused ? 1.3 : 1.0;
    final double totalScale = tapScale * focusScale;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onLongPress: widget.onFocus,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnim]),
        builder: (context, child) => Transform.scale(
            scale: totalScale,
            alignment: Alignment.center,
            child: child,
        ),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
             clipBehavior: Clip.none,
             children: [
                // The Bubble
                Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black, // Base
                        boxShadow: [
                        BoxShadow(
                            color: widget.isFocused 
                                ? Colors.red.withOpacity(0.4) 
                                : Colors.white.withOpacity(0.1),
                            blurRadius: widget.isFocused ? 20 : 10,
                            spreadRadius: widget.isFocused ? 5 : 1,
                        )
                        ]
                    ),
                    child: ClipOval(
                        child: Stack(
                            fit: StackFit.expand,
                            children: [
                                // Icon
                                widget.app.iconUrl.isNotEmpty 
                                ? Image(
                                    image: _getImageProvider(widget.app.iconUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                        return _buildFallbackIcon();
                                    },
                                )
                                : _buildFallbackIcon(),
                                
                                // Glass Gloss (Apple Watch bubble style shine)
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: widget.size * 0.4,
                                    child: Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                    Colors.white.withOpacity(0.3),
                                                    Colors.transparent
                                                ]
                                            )
                                        ),
                                    ),
                                ),
                                
                                // Border Ring
                                Container(
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: widget.isFocused 
                                                ? Colors.red.withOpacity(0.8)
                                                : Colors.white.withOpacity(0.15),
                                            width: widget.isFocused ? 3.0 : 1.5,
                                        )
                                    ),
                                )
                            ],
                        ),
                    ),
                ),

                // Delete Button overlay (only when focused)
                if (widget.isFocused)
                    Positioned(
                        top: -10,
                        right: -10,
                        child: GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                        BoxShadow(
                                            color: Colors.black26, 
                                            blurRadius: 4, 
                                            offset: Offset(0, 2)
                                        )
                                    ]
                                ),
                                child: const Icon(
                                    Icons.delete_forever, 
                                    color: Colors.white, 
                                    size: 20
                                ),
                            ),
                        ),
                    )
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
        color: const Color(0xFF1C1C1E),
        child: Center(
            child: Text(
                widget.app.name.isNotEmpty ? widget.app.name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                    fontSize: 32, 
                    fontWeight: FontWeight.w700, 
                    color: Colors.white
                ),
            ),
        ),
    );
  }
}

class GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;

    const double step = 40.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
