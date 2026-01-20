import 'dart:io';
import 'package:flutter/foundation.dart';

class ConfigurationService {
  static final ConfigurationService _instance = ConfigurationService._internal();

  factory ConfigurationService() {
    return _instance;
  }

  ConfigurationService._internal();

  String get apiBaseUrl {
    if (kIsWeb) {
      return "http://192.168.1.25:8000/api";
    } else if (Platform.isAndroid) {
      return "http://10.0.2.2:8000/api";
    } else {
      return "http://192.168.1.25:8000/api";
    }
  }
}
