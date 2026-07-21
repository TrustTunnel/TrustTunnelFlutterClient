import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores, retrieves and generates the app id used as the database
/// encryption key.
class DatabaseKeyManager {
  static const _appIdKey = 'app_id';

  final SharedPreferences _preferences;

  const DatabaseKeyManager({
    required SharedPreferences preferences,
  }) : _preferences = preferences;

  /// Returns the stored app id, or `null` if none is stored.
  String? getAppId() => _preferences.getString(_appIdKey);

  /// Stores the given [appId].
  Future<void> setAppId(String appId) => _preferences.setString(_appIdKey, appId);

  /// Generates a random string, e.g. `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`.
  String generateAppId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant (RFC 4122) bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
