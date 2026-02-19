import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  HttpServer? _server;
  int _port = 0;
  String? _currentAppId;   // ID de l'app actuellement servie
  String? _currentAppPath; // Chemin résolu actuellement servi

  // ─── Port déterministe ───────────────────────────────────────────────────
  //
  // WKWebView traite chaque `http://127.0.0.1:PORT` comme une origine distincte.
  // Un port aléatoire crée une nouvelle origin à chaque session → WebLLM et
  // tous les autres outils (Cache Storage, IndexedDB) repartent de zéro et
  // accumulent des Go sur le disque.
  //
  // Avec un port stable par appId :
  //   • même origin = même partition Cache Storage = modèles réutilisés ✅
  //   • IndexedDB / localStorage persistent entre les sessions ✅
  //   • fini l'accumulation infinie sur le disque ✅
  //
  // Plage choisie : 49200–51199 (ports éphémères privés, hors plages connues).
  int _stablePortFor(String? id) {
    if (id == null || id.isEmpty) return 49200;
    return 49200 + (id.hashCode.abs() % 2000);
  }

  // ─── startServer ─────────────────────────────────────────────────────────

  Future<void> startServer({String? appId, String? appPath}) async {
    // Résoudre le chemin physique à servir
    final String webPath;
    if (appPath != null) {
      webPath = appPath;
    } else if (appId != null) {
      final docsDir = await getApplicationDocumentsDirectory();
      webPath = "${docsDir.path}/apps/$appId";
    } else {
      AppLogger.error('LocalServer', 'Missing parameters');
      return;
    }

    // ── Réutiliser le serveur si c'est déjà la bonne app ──────────────────
    // Évite un stop/start inutile (et la fenêtre de TIME_WAIT) quand l'user
    // ouvre deux fois la même app de suite.
    if (_server != null &&
        _currentAppId == appId &&
        _currentAppPath == webPath) {
      AppLogger.info('LocalServer', 'Already serving $appId on port $_port — reusing');
      return;
    }

    // ── Arrêter proprement le serveur précédent ────────────────────────────
    // close(force: true) libère le port immédiatement (pas de TIME_WAIT).
    // close() (gracieux) laisse le port occupé quelques secondes et cause
    // l'erreur "port busy" observée avec bind() multiple sur même adresse.
    await stopServer();

    if (!Directory(webPath).existsSync()) {
      AppLogger.error('LocalServer', 'App directory not found: $webPath');
      return;
    }

    final targetPort = _stablePortFor(appId);

    final handler = createStaticHandler(
      webPath,
      defaultDocument: 'index.html',
      listDirectories: false,
    );

    final pipeline = Pipeline().addMiddleware((inner) {
      return (request) async {
        final response = await inner(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': 'http://127.0.0.1:$targetPort',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      };
    }).addHandler(handler);

    try {
      _server = await shelf_io.serve(pipeline, '127.0.0.1', targetPort);
      _port = _server!.port;
      _currentAppId = appId;
      _currentAppPath = webPath;
      AppLogger.success('LocalServer', 'Serving $appId on http://127.0.0.1:$_port');
    } catch (e) {
      // Le port est occupé par un processus externe. On réinitialise l'état
      // pour que localUrl ne renvoie PAS l'URL de l'app précédente (bug
      // "la mauvaise app s'ouvre").
      _port = 0;
      _currentAppId = null;
      _currentAppPath = null;
      AppLogger.error('LocalServer', 'Could not bind port $targetPort: $e');
      rethrow; // Propage l'erreur → _launchApp affiche un SnackBar
    }
  }

  // ─── stopServer ──────────────────────────────────────────────────────────

  Future<void> stopServer() async {
    if (_server != null) {
      // force: true → fermeture immédiate, libération instantanée du port.
      await _server!.close(force: true);
      _server = null;
      _currentAppId = null;
      _currentAppPath = null;
      AppLogger.info('LocalServer', 'Server stopped');
    }
  }

  // ─── Accesseurs ──────────────────────────────────────────────────────────

  String get localUrl => "http://127.0.0.1:$_port";
  bool get isRunning => _server != null;
  String? get currentAppId => _currentAppId;
}
