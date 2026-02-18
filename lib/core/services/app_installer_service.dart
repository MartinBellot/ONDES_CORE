import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../models/mini_app.dart';
import '../utils/logger.dart';

class AppInstallerService {
  final Dio _dio = Dio();

  // Downloads + Unzips
  Future<String?> installApp(MiniApp app, Function(double) onProgress) async {
    try {
      // 1. Get Directories
      final docsDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      
      // 2. Download ZIP
      final zipPath = '${tempDir.path}/${app.id}.zip';
      await _dio.download(
        app.downloadUrl, 
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
             onProgress(received / total);
          }
        }
      );

      // 3. Prepare Install Directory
      final installPath = "${docsDir.path}/apps/${app.id}";
      final installDir = Directory(installPath);
      if (installDir.existsSync()) {
        await installDir.delete(recursive: true);
      }
      await installDir.create(recursive: true);

      // 4. Unzip avec validation de sécurité (anti path-traversal)
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(inputStream);
      
      // Vérifier chaque entrée avant extraction
      for (final file in archive.files) {
        final normalizedPath = Uri.parse(file.name).normalizePath().path;
        if (normalizedPath.contains('..') || normalizedPath.startsWith('/')) {
          AppLogger.error('AppInstaller', 'Blocked malicious ZIP entry: ${file.name}');
          throw Exception('ZIP archive contient un chemin dangereux: ${file.name}');
        }
      }
      
      extractArchiveToDisk(archive, installPath);
      
      // 5. Flatten if necessary
      await _flattenIfNecessary(installDir);

      return installPath;
    } catch (e) {
      AppLogger.error('AppInstaller', 'Install failed', e);
      return null;
    }
  }

  /// Checks if the directory contains only one folder (ignoring system files) and no manifest at root.
  /// If so, moves everything up one level.
  Future<void> _flattenIfNecessary(Directory dir) async {
    final List<FileSystemEntity> entities = dir.listSync();
    
    // Ignore macOS system files
    final validEntities = entities.where((e) {
      final name = e.uri.pathSegments.last; // Using uri segments safest for cross-platform
      if (name.isEmpty) { // Trailing slash case
         final parts = e.path.split(Platform.pathSeparator);
         final last = parts.last.isEmpty ? parts[parts.length - 2] : parts.last;
         return !last.startsWith('.') && last != '__MACOSX';
      }
      return !name.startsWith('.') && name != '__MACOSX';
    }).toList();

    // If we have a manifest.json at root, it's correct.
    bool hasManifest = validEntities.any((e) => e.path.toLowerCase().endsWith('manifest.json'));
    if (hasManifest) return;

    // If no manifest, and only 1 directory (ignoring junk), move it up
    final dirs = validEntities.whereType<Directory>().toList();
    if (dirs.length == 1) {
      final subDir = dirs.first;
      AppLogger.info('AppInstaller', 'Detected nested root folder, flattening: ${subDir.path}');
      
      final subEntities = subDir.listSync();
      for (final entity in subEntities) {
        final segments = entity.uri.pathSegments;
        // Last segment might be empty if path ends with separator
        String name = segments.last;
        if (name.isEmpty && segments.length > 1) name = segments[segments.length - 2];
        
        final newPath = "${dir.path}${Platform.pathSeparator}$name";
        // Handle files and directories rename
        try {
           entity.renameSync(newPath);
        } catch(e) {
           // Fallback for cross-device/partition rename issues (copy & delete)
           if (entity is File) {
             entity.copySync(newPath);
             entity.deleteSync();
           } else if (entity is Directory) {
             // Basic directory move (recursive copy) - naive implementation sufficient for flattening
             // actually for folders we can just try rename, usually works on same volume
             AppLogger.error('AppInstaller', 'Could not rename dir', e);
           }
        }
      }
      // Delete empty subdir
      try {
        subDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<List<MiniApp>> getInstalledApps() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appsDir = Directory("${docsDir.path}/apps");
    if (!appsDir.existsSync()) return [];

    List<MiniApp> installed = [];
    // Scan directories, verify manifest.json...
    // For now, return mock
    return installed;
  }
}
