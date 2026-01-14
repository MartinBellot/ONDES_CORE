import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<MiniApp?> _apps = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  int _currentPage = 0;
  late AnimationController _shakeController;

  static const int _columns = 4;
  static const int _rows = 5;
  static const int _itemsPerPage = _columns * _rows;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadApps();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final installedApps = await _library.getInstalledApps();
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('app_order') ?? [];

    // Create a map for quick lookup
    final appMap = {for (var app in installedApps) app.id: app};
    
    // Determine the size of the grid. 
    // It should be at least (savedOrder.length) or (installedApps.length) rounded up to full pages.
    // Actually we just use a loose list and fill gaps with nulls.
    int maxIndex = 0;
    // savedOrder may contain "NULL" strings for empty slots
    
    // First, reconstruct the grid based on saved order
    List<MiniApp?> reconstructedGrid = [];
    
    // We treat savedOrder as the grid state.
    
    // Rebuild grid from saved order
    final processedIds = <String>{}; // Track processed IDs to prevent duplicates
    
    for (String id in savedOrder) {
        if (id == "NULL") {
            reconstructedGrid.add(null);
        } else if (appMap.containsKey(id) && !processedIds.contains(id)) {
            reconstructedGrid.add(appMap[id]);
            processedIds.add(id);
            appMap.remove(id); // Mark as placed
        } else {
            // ID in config but not installed OR already processed?
            if (!processedIds.contains(id)) {
               reconstructedGrid.add(null);
            }
        }
    }

    // Append any newly installed apps that weren't in the saved config
    if (appMap.isNotEmpty) {
         reconstructedGrid.addAll(appMap.values);
         // If we added new apps, we should probably save the order so they are persisted immediately?
         // But we can't do that easily inside initState/build lifecycle without care.
         // Let's defer or just accept they are at the end.
    }

    // Ensure the list is a multiple of _itemsPerPage so we have full pages
    int totalSlots = reconstructedGrid.length;
    int neededSlots = (totalSlots / _itemsPerPage).ceil() * _itemsPerPage;
    if (neededSlots == 0) neededSlots = _itemsPerPage; // Minimum 1 page
    
    while (reconstructedGrid.length < neededSlots) {
        reconstructedGrid.add(null);
    }

    setState(() {
      _apps = reconstructedGrid;
      _isLoading = false;
    });
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    // Save list of IDs, using "NULL" for empty slots.
    // We should trim trailing nulls to avoid infinite growth, but keep internal gaps.
    
    // Find last non-null index
    int lastNonNullIndex = _apps.lastIndexWhere((element) => element != null);
    if (lastNonNullIndex == -1) {
        await prefs.setStringList('app_order', []);
        return;
    }

    List<String> orderToSave = _apps.sublist(0, lastNonNullIndex + 1)
        .map((app) => app?.id ?? "NULL")
        .toList();
        
    await prefs.setStringList('app_order', orderToSave);
  }

  void _enterEditMode() {
    setState(() => _isEditMode = true);
    _shakeController.repeat();
  }

  void _exitEditMode() {
    setState(() => _isEditMode = false);
    _shakeController.reset();
    _saveOrder(); // Save on exit
  }

  Future<void> _openApp(MiniApp app) async {
    if (_isEditMode) return;
    
    // Start Server
    await _server.startServer(appId: app.id, appPath: app.localPath);
    // Navigate
    if (mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)));
    }
  }

  Future<void> _deleteApp(MiniApp app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Supprimer ${app.name} ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true) {
      await _library.uninstallApp(app.id);
      
      // Update UI locally to avoid full reload flicker and state issues
      setState(() {
         final index = _apps.indexOf(app);
         if (index != -1) {
           // Should we leave a hole (null) or remove?
           // Apple behavior: remove and shift back.
           // _apps[index] = null; // Leaves hole
           _apps.removeAt(index); // Removes and shifts
           _apps.add(null); // Maintain page size if needed? 
           // Actually, _loadApps ensures padding. If we remove, we might shrink the list.
           // Let's rely on re-padding logic if we were to reload, but here let's just remove to be clean.
         }
      });
      await _saveOrder();
    }
  }

  void _moveApp(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    
    // Ensure both indices are within bounds
    // Since we pad with nulls for full pages, if newIndex is outside, we might need to expand grid?
    // In this UI, newIndex comes from a visible slot, so it should be within the generated pages.
    if (oldIndex < 0 || oldIndex >= _apps.length) return;
    if (newIndex < 0 || newIndex >= _apps.length) return;

    setState(() {
      // Logic: Swap or Insert?
      // "Place anywhere" typically means you can move an item to an empty slot without shifting others.
      // But if you move to an occupied slot, what happens? Swap?
      // Let's implement Swap for flexibility.

      final itemToMove = _apps[oldIndex];
      final targetItem = _apps[newIndex];

      _apps[newIndex] = itemToMove;
      _apps[oldIndex] = targetItem;
    });
    _saveOrder();
  }

  @override
  Widget build(BuildContext context) {
    final int pageCount = (_apps.length / _itemsPerPage).ceil();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isEditMode 
          ? const Text("Modifier l'écran d'accueil", style: TextStyle(color: Colors.white, fontSize: 16))
          : const SizedBox(),
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _exitEditMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          if (!_isEditMode)
             IconButton(
               icon: const Icon(Icons.refresh, color: Colors.white70),
               onPressed: _loadApps,
             )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1c1c1e), Color(0xFF000000)],
          ),
        ),
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : Column(
            children: [
              const SizedBox(height: 100), // Space for AppBar
              Expanded(
                child: PageView.builder(
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: pageCount == 0 ? 1 : pageCount,
                  physics: _isEditMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                  itemBuilder: (context, pageIndex) {
                    return _buildGridPage(pageIndex);
                  },
                ),
              ),
              _buildPageIndicator(pageCount),
              const SizedBox(height: 30),
            ],
          ),
      ),
    );
  }

  Widget _buildGridPage(int pageIndex) {
    final startIndex = pageIndex * _itemsPerPage;
    // For "Place anywhere", we always show full page of slots
    // final endIndex = min(startIndex + _itemsPerPage, _apps.length);
    // Ensure we don't go out of bounds if something is wrong, but we padded _apps so it should be fine.
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const NeverScrollableScrollPhysics(), // Handled by PageView
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _itemsPerPage, 
      itemBuilder: (context, slotIndex) {
        final globalIndex = startIndex + slotIndex;
        // Safety check
        if (globalIndex >= _apps.length) return const SizedBox(); 

        final app = _apps[globalIndex];
        
        if (app != null) {
          return SizedBox(
            key: ValueKey("app_${app.id}"),
            child: _buildDraggableAppIcon(app, globalIndex),
          );
        } else {
          return DragTarget<int>(
            key: ValueKey("slot_$globalIndex"),
            onWillAccept: (data) => _isEditMode,
            onAccept: (fromIndex) {
              _moveApp(fromIndex, globalIndex);
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                 decoration: BoxDecoration(
                   color: candidateData.isNotEmpty ? Colors.white.withOpacity(0.1) : Colors.transparent,
                   borderRadius: BorderRadius.circular(16)
                 ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildDraggableAppIcon(MiniApp app, int globalIndex) {
    Widget appIcon = _buildAppIcon(app);

    if (_isEditMode) {
      return LongPressDraggable<int>(
        data: globalIndex,
        feedback: Transform.scale(
          scale: 1.1,
          child: Opacity(opacity: 0.9, child: _buildAppIcon(app, isFeedback: true)),
        ),
        childWhenDragging: Opacity(opacity: 0.0, child: const SizedBox()), // Hide original when dragging
        onDragStarted: () {},
        child: DragTarget<int>(
          onWillAccept: (data) => _isEditMode && data != globalIndex,
          onAccept: (fromIndex) => _moveApp(fromIndex, globalIndex),
          builder: (context, candidateData, rejectedData) {
            return AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final double offset = 2.0 * sin(_shakeController.value * 2 * pi * 3);
                return Transform.rotate(
                  angle: offset * pi / 180,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      child!,
                      Positioned(
                        left: -8,
                        top: -8,
                        child: GestureDetector(
                          onTap: () => _deleteApp(app),
                          child: Container(
                             width: 24,
                             height: 24,
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove, size: 16, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
              child: appIcon,
            );
          },
        ),
      );
    } else {
      return GestureDetector(
        onLongPress: _enterEditMode,
        onTap: () => _openApp(app),
        child: appIcon,
      );
    }
  }

  Widget _buildAppIcon(MiniApp app, {bool isFeedback = false}) {
    ImageProvider image;
    if (app.iconUrl.isNotEmpty && File(app.iconUrl).existsSync()) {
      image = FileImage(File(app.iconUrl));
    } else {
      image = const NetworkImage("https://placehold.co/200/png");
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(image: image, fit: BoxFit.cover),
            boxShadow: [
              if (!isFeedback)
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)
          ),
        ),
        const SizedBox(height: 8),
        if (!isFeedback)
          Text(
            app.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildPageIndicator(int pageCount) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        );
      }),
    );
  }
}
