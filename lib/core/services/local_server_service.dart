import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path_provider/path_provider.dart';

class LocalServerService {
  HttpServer? _server;
  int _port = 8080;

  Future<void> startServer({required String appId}) async {
    if (_server != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final appPath = "${docsDir.path}/apps/$appId";
    final webDir = Directory(appPath);

    if (!webDir.existsSync()) {
      print("❌ App directory not found: $appPath");
      return;
    }

    var handler = createStaticHandler(
      appPath, 
      defaultDocument: 'index.html',
      listDirectories: false
    );

    // Add CORS headers just in case
    final pipeline = Pipeline().addMiddleware((innerHandler) {
      return (request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      };
    }).addHandler(handler);

    try {
      _server = await shelf_io.serve(pipeline, '127.0.0.1', 8080); // Localhost only
      _port = _server!.port;
      print('🚀 Ondes Local Server running on http://127.0.0.1:$_port for App: $appId');
    } catch (e) {
      print("⚠️ Could not start server: $e");
      // Try random port
      _server = await shelf_io.serve(pipeline, '127.0.0.1', 0);
      _port = _server!.port;
      print('🚀 Ondes Local Server running on http://127.0.0.1:$_port (Fallback)');
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print("🛑 Server stopped");
    }
  }

  String get localUrl => "http://127.0.0.1:$_port";
}
