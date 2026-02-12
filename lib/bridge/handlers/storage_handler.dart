import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_handler.dart';

/// Handler for Ondes.Storage namespace
/// Manages persistent key-value storage per app
class StorageHandler extends BaseHandler {
  final String? appBundleId;
  
  StorageHandler(BuildContext context, {this.appBundleId}) : super(context);

  /// Generate storage key with app namespace
  String _getKey(String key) {
    if (appBundleId != null) {
      return 'ondes_app_${appBundleId}_$key';
    }
    return 'ondes_storage_$key';
  }

  @override
  void registerHandlers() {
    _registerSet();
    _registerGet();
    _registerRemove();
    _registerClear();
    _registerGetKeys();
  }

  void _registerSet() {
    addHandler('Ondes.Storage.set', (args) async {
      await requirePermission('storage');
      
      if (args.isEmpty) return false;
      
      final params = args[0] as List;
      if (params.length < 2) return false;
      
      final key = params[0].toString();
      final value = params[1];
      
      final prefs = await SharedPreferences.getInstance();
      final jsonValue = jsonEncode(value);
      await prefs.setString(_getKey(key), jsonValue);
      return true;
    });
  }

  void _registerGet() {
    addHandler('Ondes.Storage.get', (args) async {
      await requirePermission('storage');

      if (args.isEmpty) return null;
      
      final key = args[0].toString();
      final prefs = await SharedPreferences.getInstance();
      final jsonValue = prefs.getString(_getKey(key));
      
      if (jsonValue != null) {
        try {
          return jsonDecode(jsonValue);
        } catch (e) {
          return jsonValue;
        }
      }
      return null;
    });
  }

  void _registerRemove() {
    addHandler('Ondes.Storage.remove', (args) async {
      await requirePermission('storage');

      if (args.isEmpty) return false;
      
      final key = args[0].toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey(key));
      return true;
    });
  }

  void _registerClear() {
    addHandler('Ondes.Storage.clear', (args) async {
      await requirePermission('storage');

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final prefix = appBundleId != null ? 'ondes_app_${appBundleId}_' : 'ondes_storage_';
      
      for (final key in keys) {
        if (key.startsWith(prefix)) {
          await prefs.remove(key);
        }
      }
      return true;
    });
  }

  void _registerGetKeys() {
    addHandler('Ondes.Storage.getKeys', (args) async {
      await requirePermission('storage');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final prefix = appBundleId != null ? 'ondes_app_${appBundleId}_' : 'ondes_storage_';
      
      return keys
          .where((key) => key.startsWith(prefix))
          .map((key) => key.replaceFirst(prefix, ''))
          .toList();
    });
  }
}
