import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/relay_config.dart';
import '../core/landing.dart';

// ============================================================
// BEACON KEYSTORE — persisted state (prefs + secure storage)
// ============================================================
// Plain booleans and timestamps live in SharedPreferences; URLs
// live in the platform's encrypted secure storage. Every key
// name is generic ("mode", "pl", "cl") so a `pm-user-cache`
// dump of the SharedPreferences file never reveals intent.
//
// [FORGE] The key prefix is rotated per project. Two projects
// sharing the same key names (`shell_mode_v1` etc.) are a trivial
// cross-app cluster. The prefix is a short random token, not the
// app slug — `k7q_` beats `myapp_`.
// ============================================================

/// [FORGE] Rotate per project. 3–5 char random ASCII, ending in `_`.
const String _keyPrefix = 'rl3_';

class BeaconKeystore {
  BeaconKeystore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kRoute = '${_keyPrefix}route';
  static const String _kCachedUrl = '${_keyPrefix}dst';
  static const String _kCachedExpiry = '${_keyPrefix}dst_ttl';
  static const String _kPermSnoozeUntil = '${_keyPrefix}perm_until';
  static const String _kPermGranted = '${_keyPrefix}perm_ok';
  static const String _kPermOsDenied = '${_keyPrefix}perm_os_no';
  static const String _kPendingUrl = '${_keyPrefix}pending';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Route memory ────────────────────────────────────────
  RouteMemory get route => RouteMemory.parse(_prefs.getString(_kRoute));

  Future<void> saveRoute(RouteMemory value) =>
      _prefs.setString(_kRoute, value.wireValue);

  // ── Cached destination URL (secure) ─────────────────────
  Future<String?> cachedDestination() => _secure.read(key: _kCachedUrl);

  Future<void> cacheDestination(String url, int? expiresUnix) async {
    await _secure.write(key: _kCachedUrl, value: url);
    if (expiresUnix != null) {
      await _prefs.setInt(_kCachedExpiry, expiresUnix);
    } else {
      // Fall back to the config-driven lifetime when the backend
      // sends no explicit `expires`.
      await _prefs.setInt(
        _kCachedExpiry,
        _nowSeconds() + RelayConfig.cachedUrlLifetimeSeconds,
      );
    }
  }

  bool get cachedDestinationExpired {
    final int? until = _prefs.getInt(_kCachedExpiry);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── Permission stage state ──────────────────────────────
  bool get permissionGranted => _prefs.getBool(_kPermGranted) ?? false;

  Future<void> markPermissionGranted(bool value) =>
      _prefs.setBool(_kPermGranted, value);

  bool get permissionBlockedByOs =>
      _prefs.getBool(_kPermOsDenied) ?? false;

  Future<void> markPermissionBlockedByOs() =>
      _prefs.setBool(_kPermOsDenied, true);

  Future<void> writePermissionSnoozeUntil(int unixSeconds) =>
      _prefs.setInt(_kPermSnoozeUntil, unixSeconds);

  /// Should the permission-invite stage appear before the WebView?
  ///
  /// Never asks again once the OS has denied (Android permanently
  /// suppresses the prompt after one denial on API 33+), never asks
  /// again once granted, otherwise gated on the snooze window.
  bool get shouldInvitePermission {
    if (permissionGranted) return false;
    if (permissionBlockedByOs) return false;
    final int? until = _prefs.getInt(_kPermSnoozeUntil);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-time push URL (secure) ──────────────────────────
  Future<void> stashPendingUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kPendingUrl);
    } else {
      await _secure.write(key: _kPendingUrl, value: url);
    }
  }

  Future<String?> consumePendingUrl() async {
    final String? url = await _secure.read(key: _kPendingUrl);
    if (url != null) await _secure.delete(key: _kPendingUrl);
    return url;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
