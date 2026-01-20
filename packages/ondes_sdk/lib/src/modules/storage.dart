import '../bridge/js_bridge.dart';

/// Storage module for persistent key-value data.
///
/// Data is scoped to the mini-app and persists across sessions.
///
/// ## Example
/// ```dart
/// // Save data
/// await Ondes.storage.set('user_prefs', {'theme': 'dark', 'language': 'fr'});
///
/// // Retrieve data
/// final prefs = await Ondes.storage.get('user_prefs');
/// print(prefs['theme']); // 'dark'
///
/// // List all keys
/// final keys = await Ondes.storage.getKeys();
/// ```
class OndesStorage {
  final OndesJsBridge _bridge;

  OndesStorage(this._bridge);

  /// Stores a value with the given key.
  ///
  /// [key] The storage key.
  /// [value] The value to store (will be JSON-serialized).
  ///
  /// Returns `true` if successful.
  Future<bool> set(String key, dynamic value) async {
    final result = await _bridge.call<bool>('Ondes.Storage.set', [
      [key, value]
    ]);
    return result ?? false;
  }

  /// Retrieves a value by key.
  ///
  /// Returns `null` if the key doesn't exist.
  Future<T?> get<T>(String key) async {
    final result = await _bridge.call<T>('Ondes.Storage.get', [key]);
    return result;
  }

  /// Removes a value by key.
  ///
  /// Returns `true` if successful.
  Future<bool> remove(String key) async {
    final result = await _bridge.call<bool>('Ondes.Storage.remove', [key]);
    return result ?? false;
  }

  /// Clears all stored data for this mini-app.
  ///
  /// Returns `true` if successful.
  Future<bool> clear() async {
    final result = await _bridge.call<bool>('Ondes.Storage.clear');
    return result ?? false;
  }

  /// Gets all storage keys for this mini-app.
  Future<List<String>> getKeys() async {
    final result = await _bridge.call<List<dynamic>>('Ondes.Storage.getKeys');
    return result?.map((e) => e.toString()).toList() ?? [];
  }
}
