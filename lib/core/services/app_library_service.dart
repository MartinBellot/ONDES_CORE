import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/mini_app.dart';

class AppLibraryService {
  
  Future<List<MiniApp>> getInstalledApps() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appsDir = Directory("${docsDir.path}/apps");
    
    if (!appsDir.existsSync()) {
      return [];
    }

    List<MiniApp> installedApps = [];
    final List<FileSystemEntity> entities = appsDir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        final manifestFile = File("${entity.path}/manifest.json");
        if (manifestFile.existsSync()) {
          try {
            final content = manifestFile.readAsStringSync();
            final json = jsonDecode(content);
            
            // Handle Icon Path (Local)
            final String iconFilename = json['icon'] ?? "";
            final String iconPath = iconFilename.isNotEmpty 
                ? "${entity.path}/$iconFilename" 
                : "";

            installedApps.add(MiniApp(
              id: json['id'],
              name: json['name'],
              version: json['version'],
              description: json['description'] ?? "",
              iconUrl: iconPath, // Local absolute path
              downloadUrl: "", // Not needed for installed
              isInstalled: true,
              localPath: entity.path,
            ));
          } catch (e) {
            print("Error parsing manifest for ${entity.path}: $e");
          }
        }
      }
    }
    return installedApps;
  }

  Future<void> uninstallApp(String appId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory("${docsDir.path}/apps/$appId");
    if (appDir.existsSync()) {
      await appDir.delete(recursive: true);
    }
  }
}
