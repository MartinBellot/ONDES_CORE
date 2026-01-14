import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/app_installer_service.dart';
import '../../core/services/local_server_service.dart';
import '../../core/services/app_library_service.dart';
import '../webview_screen.dart';
import '../widgets/glass_window.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _installer = AppInstallerService();
  final _server = LocalServerService();
  final _library = AppLibraryService();
  
  List<MiniApp> _storeApps = [];
  List<MiniApp> _installedApps = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Store
      const String apiUrl = "http://127.0.0.1:8000/api/apps/"; 
      final response = await Dio().get(apiUrl);
      final List data = response.data;
      final storeApps = data.map((json) => MiniApp.fromJson(json)).toList();

      // 2. Fetch Local
      final localApps = await _library.getInstalledApps();

      setState(() {
        _storeApps = storeApps;
        _installedApps = localApps;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = "Impossible de charger le Store.\n$e";
        _isLoading = false;
      });
    }
  }

  Future<void> _installAndOpen(MiniApp app) async {
     if (app.downloadUrl.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien de téléchargement manquant")));
       return;
     }

     showDialog(
       context: context, 
       barrierDismissible: false, 
       builder: (c) => const Center(child: CircularProgressIndicator())
     );
     
     await _installer.installApp(app, (p) {
        // print("Download: $p");
     });
     
     // Refresh local list to update UI state
     final localApps = await _library.getInstalledApps();
     setState(() {
       _installedApps = localApps;
     });

     await _server.startServer(appId: app.id);
     
     if (mounted) {
       Navigator.pop(context); // Close loading
       Navigator.push(context, MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)));
     }
  }

  Future<void> _openApp(String appId) async {
     await _server.startServer(appId: appId);
     if (mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (c) => WebViewScreen(url: _server.localUrl)));
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
         children: [
            Positioned.fill(
              child: Image.network(
                "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=2670&auto=format&fit=crop", 
                fit: BoxFit.cover,
              ),
            ),
            Container(color: Colors.black54),
            
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ondes Store", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: _fetchApps, icon: const Icon(Icons.refresh, color: Colors.white))
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    if (_isLoading) 
                      const Expanded(child: Center(child: CircularProgressIndicator())),
                    
                    if (_error != null)
                      Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center))),

                    if (!_isLoading && _error == null)
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _storeApps.length,
                        itemBuilder: (context, index) {
                          final app = _storeApps[index];
                          
                          // Check installation status
                          bool isInstalled = false;
                          bool isUpdateAvailable = false;
                          
                          try {
                            final installed = _installedApps.firstWhere((a) => a.id == app.id);
                            isInstalled = true;
                            if (installed.version != app.version) {
                              isUpdateAvailable = true;
                            }
                          } catch (e) {
                            // Not installed
                          }

                          return GlassWindow(
                            width: double.infinity,
                            height: double.infinity,
                            title: app.name,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  app.iconUrl.isNotEmpty 
                                  ? Image.network(
                                      app.iconUrl, 
                                      height: 60,
                                      errorBuilder: (c,e,s) => const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                    )
                                  : const Icon(Icons.apps, color: Colors.white, size: 60),
                                  
                                  const SizedBox(height: 12),
                                  Text(app.description, 
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const Spacer(),
                                  Text("v${app.version}", style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  
                                  // Dynamic Button
                                  if (isUpdateAvailable)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                      onPressed: () => _installAndOpen(app),
                                      child: const Text("Mettre à jour"),
                                    )
                                  else if (isInstalled)
                                     ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                                      onPressed: () => _openApp(app.id),
                                      child: const Text("Ouvrir"),
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                                      onPressed: () => _installAndOpen(app),
                                      child: const Text("Installer"),
                                    )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            )
         ],
      ),
    );
  }
}

