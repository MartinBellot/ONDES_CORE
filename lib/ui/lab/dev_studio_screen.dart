import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/dev_studio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class DevStudioScreen extends StatefulWidget {
  const DevStudioScreen({super.key});

  @override
  State<DevStudioScreen> createState() => _DevStudioScreenState();
}

class _DevStudioScreenState extends State<DevStudioScreen> {
  final _service = DevStudioService();
  List<MiniApp> _myApps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyApps();
  }

  Future<void> _loadMyApps() async {
    setState(() => _isLoading = true);
    final apps = await _service.getMyApps();
    setState(() {
      _myApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _createNewApp() async {
    // Show Dialog to create basic app info
    final nameCtrl = TextEditingController();
    final bundleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouvelle Application"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: bundleCtrl, decoration: const InputDecoration(labelText: "Bundle ID (com.example.app)")),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final app = await _service.createApp(
                name: nameCtrl.text,
                bundleId: bundleCtrl.text,
                description: descCtrl.text
              );
              if (app != null) {
                _loadMyApps();
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur création")));
              }
            },
            child: const Text("Créer"),
          )
        ],
      )
    );
  }

  Future<void> _uploadVersion(MiniApp app) async {
    if (app.dbId == null) return;

    // 1. Pick Folder
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // 2. Ask Version Number
    final versionCtrl = TextEditingController(text: "1.0.0");
    final notesCtrl = TextEditingController();
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Publier une version pour ${app.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Dossier source: ...${selectedDirectory.substring(selectedDirectory.length - 20)}"),
            TextField(controller: versionCtrl, decoration: const InputDecoration(labelText: "Numéro de version")),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: "Notes de version")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Publier"))
        ],
      )
    );

    if (proceed != true) return;

    setState(() => _isLoading = true);
    
    try {
       // 3. Zip Folder
       final tempDir = await getTemporaryDirectory();
       final zipPath = '${tempDir.path}/${app.id}_v${versionCtrl.text}.zip';
       
       final encoder = ZipFileEncoder();
       encoder.create(zipPath);
       
       // Add directory content, not the directory itself as root
       // archive package: addDirectory adds the dir as a folder inside zip.
       // We want index.html at root of zip. 
       // Workaround: Iterate files and add them.
       final dir = Directory(selectedDirectory);
       final List<FileSystemEntity> files = dir.listSync(recursive: true);
       for (var file in files) {
         if (file is File) {
            final relPath = file.path.substring(dir.path.length + 1);
            encoder.addFile(file, relPath);
         }
       }
       encoder.close();

       // 4. Upload
       final success = await _service.uploadVersion(
         appId: app.dbId!,
         versionNumber: versionCtrl.text,
         releaseNotes: notesCtrl.text,
         zipPath: zipPath
       );

       if (success) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Version publiée avec succès !")));
         _loadMyApps();
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Échec de la publication.")));
       }

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ondes Studio"),
        actions: [
          IconButton(onPressed: _createNewApp, icon: const Icon(Icons.add))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _myApps.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.code, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("Vous n'avez pas encore créé d'application."),
                   const SizedBox(height: 16),
                   ElevatedButton(onPressed: _createNewApp, child: const Text("Créer ma première app"))
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myApps.length,
              itemBuilder: (context, index) {
                final app = _myApps[index];
                return Card(
                  color: Colors.white10,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: app.iconUrl.isNotEmpty 
                      ? Image.network(app.iconUrl, width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.apps)) 
                      : const Icon(Icons.apps),
                    title: Text(app.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${app.id} • Dernière v${app.version}", style: const TextStyle(color: Colors.white70)),
                    trailing: IconButton(
                       icon: const Icon(Icons.cloud_upload, color: Colors.blueAccent),
                       onPressed: () => _uploadVersion(app),
                       tooltip: "Publier une mise à jour",
                    ),
                  ),
                );
              },
            ),
    );
  }
}
