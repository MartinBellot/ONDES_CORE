import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../models/mini_app.dart';

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

      // 4. Unzip
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(inputStream);
      extractArchiveToDisk(archive, installPath);
      
      return installPath;

    } catch (e) {
      print("❌ Install Error: $e");
      return null;
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
