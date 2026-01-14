import 'dart:io';
import 'dart:convert';
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

    // 1.5 Validate Manifest
    final manifestFile = File("$selectedDirectory/manifest.json");
    if (!manifestFile.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: manifest.json introuvable à la racine du dossier.")));
      }
      return;
    }

    String manifestVersion = "1.0.0";
    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content);
      final String manifestId = json['id'] ?? "";
      manifestVersion = json['version'] ?? "1.0.0";
      
      if (manifestId != app.id) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("ID Mismatch: Le manifest indique '$manifestId' mais vous publiez pour '${app.id}'."),
              backgroundColor: Colors.red,
            ));
         }
         return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lecture manifest: $e")));
      }
      return;
    }

    // 2. Ask Version Number
    final versionCtrl = TextEditingController(text: manifestVersion);
    final notesCtrl = TextEditingController();
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Publier une version pour ${app.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Dossier source: ...${selectedDirectory.substring(selectedDirectory.length - 20)}"),
            const SizedBox(height: 10),
            TextField(
              controller: versionCtrl, 
              decoration: const InputDecoration(
                labelText: "Numéro de version (manifest.json)",
                helperText: "Doit correspondre au fichier manifest.json"
              ),
              readOnly: true, // Force user to edit file
              style: const TextStyle(color: Colors.grey),
            ),
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

    // Check version strict equality (even though field is readOnly, good practice)
    if (versionCtrl.text != manifestVersion) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur: La version du manifest ($manifestVersion) ne correspond pas (${versionCtrl.text})."),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() => _isLoading = true);
    
    try {
       // 3. Zip Folder
       final tempDir = await getTemporaryDirectory();
       final zipPath = '${tempDir.path}/${app.id}_v${versionCtrl.text}.zip';
       
       final encoder = ZipFileEncoder();
       encoder.create(zipPath);
       
       final dir = Directory(selectedDirectory);
       final List<FileSystemEntity> files = dir.listSync(recursive: true);

       for (var file in files) {
         if (file is File) {
            String relPath = file.path.substring(dir.path.length + 1);
            if (Platform.isWindows) {
              relPath = relPath.replaceAll(Platform.pathSeparator, '/');
            }
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

  Future<void> _editApp(MiniApp app) async {
    final nameCtrl = TextEditingController(text: app.name);
    final descCtrl = TextEditingController(text: app.description);
    
    File? newIcon;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) { 
            return AlertDialog(
            title: Text("Modifier ${app.name}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (newIcon != null) 
                        Image.file(newIcon!, width: 40, height: 40)
                    else 
                        app.iconUrl.isNotEmpty 
                          ? Image.network(app.iconUrl, width: 40, height: 40, errorBuilder: (c,e,s) => const Icon(Icons.apps)) 
                          : const Icon(Icons.apps),
                    const SizedBox(width: 16),
                    TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text("Changer l'icône"),
                        onPressed: () async {
                           final result = await FilePicker.platform.pickFiles(type: FileType.image);
                           if (result != null) {
                               setStateBuilder(() {
                                   newIcon = File(result.files.single.path!);
                               });
                           }
                        },
                    )
                  ],
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (app.dbId == null) return;

                  setState(() => _isLoading = true);
                  final updatedApp = await _service.updateApp(
                    appId: app.dbId!,
                    name: nameCtrl.text,
                    description: descCtrl.text,
                    icon: newIcon
                  );
                  
                  if (updatedApp != null) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application modifiée")));
                    _loadMyApps();
                  } else {
                    setState(() => _isLoading = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur modification")));
                  }
                },
                child: const Text("Enregistrer"),
              )
            ],
          );
        }
      )
    );
  }

  Future<void> _deleteApp(MiniApp app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Supprimer ${app.name} ?"),
        content: const Text("Cette action supprimera l'application et tout son historique de versions. C'est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true && app.dbId != null) {
      setState(() => _isLoading = true);
      final success = await _service.deleteApp(app.dbId!);
      if (success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application supprimée")));
        _loadMyApps();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la suppression")));
      }
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                           icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                           onPressed: () => _editApp(app),
                           tooltip: "Modifier l'application",
                        ),
                        IconButton(
                           icon: const Icon(Icons.cloud_upload, color: Colors.blueAccent),
                           onPressed: () => _uploadVersion(app),
                           tooltip: "Publier une mise à jour",
                        ),
                        IconButton(
                           icon: const Icon(Icons.delete, color: Colors.redAccent),
                           onPressed: () => _deleteApp(app),
                           tooltip: "Supprimer l'application",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
