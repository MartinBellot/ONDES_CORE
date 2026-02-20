import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models/mini_app.dart';
import '../../core/services/dev_studio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_edit_screen.dart';

class DevStudioScreen extends StatefulWidget {
  const DevStudioScreen({super.key});

  @override
  State<DevStudioScreen> createState() => _DevStudioScreenState();
}

class _DevStudioScreenState extends State<DevStudioScreen> {
  final _service = DevStudioService();
  List<MiniApp> _myApps = [];
  List<AppCategory> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final apps = await _service.getMyApps();
    final cats = await _service.getCategories();
    if (mounted) {
      setState(() {
        _myApps = apps;
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  /// Compare two semantic versions. Returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal.
  int _compareVersions(String v1, String v2) {
    try {
      List<int> n1 = v1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      List<int> n2 = v2.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      
      // Normalize lengths
      int len = n1.length > n2.length ? n1.length : n2.length;
      for (int i = 0; i < len; i++) {
        int v1Part = i < n1.length ? n1[i] : 0;
        int v2Part = i < n2.length ? n2[i] : 0;
        
        if (v1Part > v2Part) return 1;
        if (v1Part < v2Part) return -1;
      }
      return 0;
    } catch (e) {
      return 0; // Fallback
    }
  }

  // --- Step 1: Create App Flow ---

  Future<void> _handleCreateApp() async {
    // 0. Show Tutorial/Instructions
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text("Créer une nouvelle application", style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pour créer une application, vous devez avoir préparé un dossier local contenant votre code source.", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text("Ce dossier doit impérativement contenir :", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _TutorialItem(text: "Un fichier manifest.json à la racine"),
            _TutorialItem(text: "Votre fichier index.html (pour le web)"),
            _TutorialItem(text: "Vos icônes et ressources"),
            const SizedBox(height: 24),
            InkWell(
              onTap: () async {
                 const url = 'https://martinbellot.github.io/ONDES_CORE/';
                 if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                 }
              },
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text("Consulter la documentation", style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("À l'étape suivante, sélectionnez ce dossier.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("J'ai compris, sélectionner le dossier"),
          )
        ],
      )
    );

    // 1. Select Folder
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Sélectionnez le dossier de votre projet (contenant manifest.json)"
    );
    
    if (selectedDirectory == null) return;

    // 2. Read Manifest
    final manifestFile = File("$selectedDirectory/manifest.json");
    if (!manifestFile.existsSync()) {
      if (mounted) _showSnack("Erreur: manifest.json introuvable dans ce dossier.", isError: true);
      return;
    }

    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content);
      
      final String name = json['name'] ?? "";
      final String bundleId = json['id'] ?? "";
      final String version = json['version'] ?? "1.0.0";
      final String description = json['description'] ?? "";
      final String iconPath = json['icon'] ?? "";
      
      if (name.isEmpty || bundleId.isEmpty) {
        if (mounted) _showSnack("Le manifest doit contenir 'name' et 'id'.", isError: true);
        return;
      }

      // Check for icon file
      File? iconFile;
      if (iconPath.isNotEmpty) {
        final f = File("$selectedDirectory/$iconPath");
        if (f.existsSync()) iconFile = f;
      }
      
      // 3. Show Enhanced Form
      if (mounted) {
        _showCreateAppForm(
          initialName: name, 
          initialId: bundleId,
          initialVersion: version, // Pass version
          initialDesc: description,
          iconFile: iconFile,
          folderPath: selectedDirectory,
        );
      }

    } catch (e) {
      if (mounted) _showSnack("Erreur lors de la lecture du manifest: $e", isError: true);
    }
  }

  void _showCreateAppForm({
    required String initialVersion,
    required String initialName,
    required String initialId,
    required String initialDesc,
    required File? iconFile,
    required String folderPath,
  }) {
    final formKey = GlobalKey<FormState>();
    
    // Form Controllers
    final fullDescCtrl = TextEditingController();
    final websiteCtrl = TextEditingController();
    final privacyCtrl = TextEditingController();
    
    // State variables for the dialog
    int? selectedCategoryId;
    String selectedAge = "4+";
    List<String> ageRatings = ["4+", "9+", "12+", "17+"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: Text("Finaliser la création", style: theme.textTheme.titleLarge),
            scrollable: true,
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Immutable Info Card (Glassy)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1))
                      ),
                      child: Row(
                        children: [
                          if (iconFile != null) 
                            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(iconFile, width: 48, height: 48, fit: BoxFit.cover))
                          else
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10)
                              ),
                              child: Icon(Icons.extension, color: theme.colorScheme.onPrimaryContainer),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(initialName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                Text(initialId, style: theme.textTheme.bodySmall?.copyWith(fontFamily: "monospace", color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text(initialDesc, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("Informations", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const SizedBox(height: 16),
                    
                    // Category
                    DropdownButtonFormField<int>(
                      dropdownColor: theme.colorScheme.surface,
                      decoration: InputDecoration(
                        labelText: "Catégorie", 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                      ),
                      value: selectedCategoryId,
                      items: _categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [Text(c.icon), const SizedBox(width: 8), Text(c.name)]),
                      )).toList(), 
                      onChanged: (v) => setStateDialog(() => selectedCategoryId = v),
                      validator: (v) => v == null ? 'Veuillez choisir une catégorie' : null,
                    ),
                    const SizedBox(height: 16),

                    // Age Rating
                    DropdownButtonFormField<String>(
                      dropdownColor: theme.colorScheme.surface,
                      decoration: InputDecoration(
                        labelText: "Classification d'âge", 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                      ),
                      value: selectedAge,
                      items: ageRatings.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      onChanged: (v) => setStateDialog(() => selectedAge = v!),
                    ),
                    const SizedBox(height: 16),

                    // Long Description
                    TextFormField(
                      controller: fullDescCtrl,
                      decoration: InputDecoration(
                        labelText: "Description longue / Readme", 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                             controller: websiteCtrl,
                             decoration: InputDecoration(
                               labelText: "Site Web", 
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                               prefixIcon: const Icon(Icons.language),
                               filled: true,
                               fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                             ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                             controller: privacyCtrl,
                             decoration: InputDecoration(
                               labelText: "Confidentialité (URL)", 
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                               prefixIcon: const Icon(Icons.lock_outline),
                               filled: true,
                               fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                             ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              FilledButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    await _performCreateApp(
                      name: initialName,
                      initialVersion: initialVersion, // Pass version
                      bundleId: initialId,
                      shortDesc: initialDesc,
                      folderPath: folderPath,
                      iconFile: iconFile,
                      fullDesc: fullDescCtrl.text,
                      categoryId: selectedCategoryId,
                      ageRating: selectedAge,
                      website: websiteCtrl.text,
                      privacy: privacyCtrl.text,
                    );
                  }
                },
                child: const Text("Créer l'application"),
              )
            ],
          );
        }
      )
    );
  }

  Future<void> _performCreateApp({
    required String name,
    required String bundleId,
    required String initialVersion,
    required String shortDesc,
    required String folderPath,
    File? iconFile,
    String? fullDesc,
    int? categoryId,
    String? ageRating,
    String? website,
    String? privacy,
  }) async {
    setState(() => _isLoading = true);
    
    final newApp = await _service.createApp(
      name: name,
      bundleId: bundleId,
      description: shortDesc,
      icon: iconFile,
      fullDescription: fullDesc,
      categoryId: categoryId,
      ageRating: ageRating,
      websiteUrl: website,
      privacyUrl: privacy,
    );

    if (newApp != null) {
      // Auto-upload first version
      try {
        final tempDir = await getTemporaryDirectory();
        final zipPath = '${tempDir.path}/${newApp.id}_v$initialVersion.zip';
        
        final archive = Archive();
        final dir = Directory(folderPath);
        
        if (dir.existsSync()) {
          final files = dir.listSync(recursive: true);
          for (var file in files) {
            if (file is File) {
              final filename = file.uri.pathSegments.last;
              if (filename == '.DS_Store' || filename.startsWith('._')) continue;

              String relPath = file.path.substring(dir.path.length);
              if (relPath.startsWith(Platform.pathSeparator)) {
                relPath = relPath.substring(1);
              }
              String zipEntryName = relPath.replaceAll(Platform.pathSeparator, '/');
              
              final bytes = await file.readAsBytes();
              final archiveFile = ArchiveFile(zipEntryName, bytes.lengthInBytes, bytes);
              archive.addFile(archiveFile);
            }
          }
        }
        
        final zipEncoder = ZipEncoder();
        final encodedBytes = zipEncoder.encode(archive);
        if (encodedBytes.isEmpty) throw Exception("Failed to encode zip");
        
        final zipFile = File(zipPath);
        await zipFile.writeAsBytes(encodedBytes);

        final success = await _service.uploadVersion(
          appId: newApp.dbId!,
          versionNumber: initialVersion,
          releaseNotes: "Version initiale",
          zipPath: zipPath
        );

        if (success) {
           _showSnack("Application '$name' (v$initialVersion) créée et publiée avec succès !");
        } else {
           _showSnack("App créée, mais échec de l'upload du paquet.", isError: true);
        }
      } catch (e) {
         _showSnack("App créée, mais erreur zip: $e", isError: true);
      }
      
      _loadData();
    } else {
      setState(() => _isLoading = false);
      _showSnack("Erreur lors de la création.", isError: true);
    }
  }

  // --- Step 2: Upload Version Flow ---

  Future<void> _handleUploadVersion(MiniApp app) async {
    // 1. Pick Directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    // 2. Validate Manifest
    final manifestFile = File("$selectedDirectory/manifest.json");
    if (!manifestFile.existsSync()) {
      _showSnack("Erreur: manifest.json manquant.", isError: true);
      return;
    }

    try {
      final content = await manifestFile.readAsString();
      final json = jsonDecode(content);
      
      final String manifestId = json['id'] ?? "";
      final String manifestVersion = json['version'] ?? "1.0.0";
      final String manifestIcon = json['icon'] ?? "";
      
      if (manifestId != app.id) {
         _showSnack("Erreur: ID Bundle incorrect ($manifestId vs ${app.id})", isError: true);
         return;
      }

      // 3. SEMVER CHECK
      final comp = _compareVersions(manifestVersion, app.version);
      if (comp <= 0) {
        // New version is smaller or equal to current
        _showErrorDialog(
          "Version invalide", 
          "La version du manifest ($manifestVersion) doit être supérieure à la version actuelle (${app.version}).\n\nVeuillez incrémenter la version dans manifest.json."
        );
        return;
      }

      // 4. Scan files for preview
      final dir = Directory(selectedDirectory);
      final List<FileSystemEntity> entities = dir.listSync(recursive: true);
      final fileList = entities.whereType<File>().toList();
      final totalSize = fileList.fold<int>(0, (prev, element) => prev + element.lengthSync());
      
      // Check for icon changes
      File? newIconFile;
      bool iconChanged = false;
      if (manifestIcon.isNotEmpty) {
        final f = File("$selectedDirectory/$manifestIcon");
        if (f.existsSync()) newIconFile = f;
      }
      if (newIconFile != null) iconChanged = true;


      // 5. Show Preview Dialog
      if (mounted) {
        final theme = Theme.of(context);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: Text("Mise à jour v$manifestVersion", style: theme.textTheme.titleLarge),
            content: SizedBox(
              width: 500,
              height: 450,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version Compare
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                       color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                       borderRadius: BorderRadius.circular(16)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _VersionBadge(version: app.version, label: "Actuelle", color: theme.colorScheme.onSurfaceVariant),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary)),
                        _VersionBadge(version: manifestVersion, label: "Nouvelle", color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                       _StatItem(label: "Fichiers", value: "${fileList.length}"),
                       Container(width: 1, height: 30, color: theme.dividerColor),
                       _StatItem(label: "Taille", value: "${(totalSize / 1024).toStringAsFixed(1)} KB"),
                       Container(width: 1, height: 30, color: theme.dividerColor),
                       _StatItem(label: "Icone", value: iconChanged ? "Inclus" : "Inchangé"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Fichiers inclus", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // File List Preview
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.1))
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: fileList.length,
                        itemBuilder: (context, index) {
                          final f = fileList[index];
                          final relPath = f.path.substring(dir.path.length + 1);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  relPath.endsWith('json') ? Icons.data_object : 
                                  (relPath.endsWith('png') || relPath.endsWith('jpg')) ? Icons.image : 
                                  Icons.insert_drive_file_outlined, 
                                  size: 14, color: theme.colorScheme.secondary
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(relPath, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text("${(f.lengthSync() / 1024).toStringAsFixed(1)} KB", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextField(
                     decoration: InputDecoration(
                        labelText: "Notes de version",
                        hintText: "Quelles sont les nouveautés de cette version ?",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3)
                     ),
                     maxLines: 2,
                  )
                ],
              ),
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
               FilledButton.icon(
                 icon: const Icon(Icons.cloud_upload_outlined),
                 label: const Text("Publier"),
                 onPressed: () => Navigator.pop(ctx, true),
               )
            ],
          )
        );

        if (confirm == true) {
           _performUpload(app, manifestVersion, "Mise à jour v$manifestVersion", selectedDirectory, json);
        }
      }

    } catch (e) {
      if (mounted) _showSnack("Erreur lors de l'analyse: $e", isError: true);
    }
  }

  Future<void> _performUpload(MiniApp app, String version, String notes, String sourcePath, Map<String,dynamic> manifestJson) async {
    setState(() => _isLoading = true);

    try {
       final tempDir = await getTemporaryDirectory();
       final zipPath = '${tempDir.path}/${app.id}_v$version.zip';
       
       // Create Archive in memory
       final archive = Archive();
       final dir = Directory(sourcePath);
       
       if (dir.existsSync()) {
         final files = dir.listSync(recursive: true);
         for (var file in files) {
           if (file is File) {
             final filename = file.uri.pathSegments.last;
             if (filename == '.DS_Store' || filename.startsWith('._')) continue;

             String relPath = file.path.substring(dir.path.length);
             if (relPath.startsWith(Platform.pathSeparator)) {
               relPath = relPath.substring(1);
             }
             String zipEntryName = relPath.replaceAll(Platform.pathSeparator, '/');
             
             final bytes = await file.readAsBytes();
             final archiveFile = ArchiveFile(zipEntryName, bytes.lengthInBytes, bytes);
             archive.addFile(archiveFile);
           }
         }
       }
       
       // Encode to Zip
       final zipEncoder = ZipEncoder();
       final encodedBytes = zipEncoder.encode(archive);
       if (encodedBytes.isEmpty) throw Exception("Failed to encode zip");
       
       // Write to disk
       final zipFile = File(zipPath);
       await zipFile.writeAsBytes(encodedBytes);

       final success = await _service.uploadVersion(
         appId: app.dbId!,
         versionNumber: version,
         releaseNotes: notes,
         zipPath: zipPath
       );

       if (success) {
         _showSnack("Mise à jour v$version publiée avec succès !");
         _loadData();
       } else {
         _showSnack("Échec de la publication.", isError: true);
         setState(() => _isLoading = false);
       }

    } catch (e) {
      _showSnack("Erreur upload: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  // --- Other Actions ---

  Future<void> _editApp(MiniApp app) async {
    if (app.dbId == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (c) => AppEditScreen(app: app)));
    _loadData();
  }

  Future<void> _deleteApp(MiniApp app) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text("Supprimer ${app.name} ?", style: theme.textTheme.titleLarge),
        content: const Text("Toutes les version seront supprimées.\nCette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("SUPPRIMER", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold))),
        ],
      )
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      await _service.deleteApp(app.dbId!);
      _loadData();
    }
  }


  // --- UI Helpers ---

  void _showSnack(String msg, {bool isError = false}) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
       content: Text(msg),
       behavior: SnackBarBehavior.floating,
       backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
     ));
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
         title: Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), const SizedBox(width: 12), Text(title)]),
         content: Text(content),
         actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ondes Studio", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _handleCreateApp, 
              icon: const Icon(Icons.add_rounded), 
              label: const Text("Nouvelle App"),
            ),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _myApps.isEmpty 
          ? _buildEmptyState(theme)
          : _buildAppGrid(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5)
            ),
            child: Icon(Icons.rocket_launch_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text("Ondes Studio", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Créez, testez et publiez vos mini-apps.", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          TextButton(
             onPressed: _handleCreateApp,
             child: const Text("Créer ma première App"),
          )
        ],
      ),
    );
  }

  Widget _buildAppGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width > 600) crossAxisCount = 2;
        if (width > 1100) crossAxisCount = 3;

        return GridView.builder(
           padding: const EdgeInsets.all(24),
           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: crossAxisCount,
             crossAxisSpacing: 20,
             mainAxisSpacing: 20,
             childAspectRatio: 1.6, 
           ),
           itemCount: _myApps.length,
           itemBuilder: (context, index) {
              final app = _myApps[index];
              return _GlassCard(
                child: _AppContent(
                  app: app, 
                  onEdit: () => _editApp(app),
                  onUpload: () => _handleUploadVersion(app),
                  onDelete: () => _deleteApp(app),
                ),
              );
           },
        );
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mimic the GlassWindow style but simpler for cards
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5), // Semi transparent surface
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glass effect
          child: child,
        ),
      ),
    );
  }
}

class _AppContent extends StatelessWidget {
  final MiniApp app;
  final VoidCallback onEdit;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  const _AppContent({required this.app, required this.onEdit, required this.onUpload, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surfaceVariant,
                    image: app.iconUrl.isNotEmpty 
                      ? DecorationImage(image: NetworkImage(app.iconUrl), fit: BoxFit.cover)
                      : null,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                    ]
                  ),
                  child: app.iconUrl.isEmpty ? Icon(Icons.extension, size: 32, color: theme.colorScheme.onSurfaceVariant) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text("v${app.version}", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ),
                          if (!app.isPublished) ...[  
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 11, color: Colors.amber),
                                  SizedBox(width: 3),
                                  Text('BROUILLON', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(app.id, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )
              ],
            ),
            const Spacer(),
            const Divider(height: 32),
            Row(
              children: [
                 _MiniStat(icon: Icons.download_rounded, value: "${app.downloadsCount}", color: theme.colorScheme.green),
                 const SizedBox(width: 16),
                 _MiniStat(icon: Icons.star_rounded, value: app.averageRating.toStringAsFixed(1), color: Colors.amber),
                 const Spacer(),
                 IconButton(
                    onPressed: onUpload, 
                    icon: const Icon(Icons.cloud_upload_outlined), 
                    color: theme.colorScheme.primary,
                    tooltip: "Mettre à jour",
                 ),
                 IconButton(
                    onPressed: onDelete, 
                    icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error.withOpacity(0.7)),
                    tooltip: "Supprimer",
                 )
              ],
            )
          ],
        ),
      ),
    );
  }
}

extension CustomColors on ColorScheme {
  // Little helper only if you have custom colors defined in theme ext, 
  // otherwise we map to standard.
  Color get green => const Color(0xFF34C759); // Apple Green
}


class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TutorialItem extends StatelessWidget {
  final String text;
  const _TutorialItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String version;
  final String label;
  final Color color;
  const _VersionBadge({required this.version, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3))
          ),
          child: Text(
            version, 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)
          ),
        )
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
