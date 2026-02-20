import 'dart:io';
import 'package:flutter/foundation.dart';

class ConfigurationService {
  static final ConfigurationService _instance = ConfigurationService._internal();

  factory ConfigurationService() {
    return _instance;
  }

  ConfigurationService._internal();

  /// URL de production
  static const String _productionUrl = 'https://api.ondes.pro/api';

  String get apiBaseUrl {
    // En mode release, toujours utiliser HTTPS
    if (kReleaseMode) {
      return _productionUrl;
    }

    // Mode debug : serveur local
    if (kIsWeb) {
      return 'http://192.168.1.25:8000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://127.0.0.1:8000/api';
    }
  }

  /// Retourne l'URL de base sans /api (pour les assets, avatars, etc.)
  String get baseUrl {
    final api = apiBaseUrl;
    return api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
  }
}
