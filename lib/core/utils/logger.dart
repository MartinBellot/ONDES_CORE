import 'package:flutter/foundation.dart';

/// Logger conditionnel : n'affiche les logs qu'en mode debug.
/// Remplace tous les print() dans l'app pour éviter les fuites
/// d'informations sensibles en production.
class AppLogger {
  AppLogger._();

  static void debug(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ℹ️ $message');
    }
  }

  static void warning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ⚠️ $message');
    }
  }

  static void error(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$tag] ❌ $message${error != null ? ': $error' : ''}');
    }
  }

  static void success(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ✅ $message');
    }
  }
}
