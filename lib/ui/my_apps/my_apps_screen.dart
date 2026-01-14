import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/app_library_service.dart';
import '../../core/services/local_server_service.dart';
import '../webview_screen.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  final AppLibraryService _library = AppLibraryService();
  final LocalServerService _server = LocalServerService();
  
  List<MiniApp> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _library.getInstalledApps();
    setState(() {
      _apps = apps;
      _isLoading = false;
    });
  }

  Future<void> _openApp(MiniApp app) async {
    // Start Server
    await _server.startServer(appId: app.id);
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
      _loadApps();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Apps"),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _loadApps, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _apps.isEmpty 
          ? const Center(child: Text("Aucune application installée.", style: TextStyle(color: Colors.white54)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _apps.length,
              itemBuilder: (context, index) {
                final app = _apps[index];
                return _buildAppCard(app);
              },
            ),
    );
  }

  Widget _buildAppCard(MiniApp app) {
    // Check if icon is local file
    ImageProvider image;
    if (app.iconUrl.isNotEmpty) {
      image = FileImage(File(app.iconUrl));
    } else {
      // Fallback or network if somehow url (unlikely for installed)
      image = const NetworkImage("https://via.placeholder.com/150"); 
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openApp(app),
          onLongPress: () => _deleteApp(app),
          child: Stack(
            children: [
               Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(image: image, fit: BoxFit.cover, onError: (e,s) => {}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      app.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "v${app.version}",
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 0)
                        ),
                        onPressed: () => _openApp(app),
                        child: const Text("Ouvrir"),
                      ),
                    )
                  ],
                ),
              ),
              Positioned(
                 top: 8,
                 right: 8,
                 child: InkWell(
                   onTap: () => _deleteApp(app),
                   child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                   ),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
