import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shell_mode.dart';

// ============================================================
// VAULT — persistence layer (prefs + secure storage)
// ============================================================
// Plain flags live in SharedPreferences; URLs live in encrypted
// secure storage. Keys are deliberately terse/neutral so they do
// not reveal intent in a prefs dump.
// ============================================================

class Vault {
  Vault({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kMode = 'shell_mode_v1';
  static const String _kCachedLink = 'cl_blob';
  static const String _kLinkTtl = 'cl_ttl';
  static const String _kInviteUntil = 'invite_until';
  static const String _kPushAllowed = 'push_allowed';
  static const String _kPushBlockedByOs = 'push_blocked_os';
  static const String _kPendingLink = 'pl_blob';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Shell mode ──
  ShellMode readMode() => ShellMode.decode(_prefs.getString(_kMode));

  Future<void> writeMode(ShellMode mode) =>
      _prefs.setString(_kMode, mode.encode());

  // ── Cached content link (secure) ──
  Future<String?> readCachedLink() => _secure.read(key: _kCachedLink);

  Future<void> writeCachedLink(String link) =>
      _secure.write(key: _kCachedLink, value: link);

  // ── Link expiry ──
  int? readLinkTtl() => _prefs.getInt(_kLinkTtl);

  Future<void> writeLinkTtl(int unixSeconds) =>
      _prefs.setInt(_kLinkTtl, unixSeconds);

  bool isLinkStale() {
    final int? ttl = readLinkTtl();
    if (ttl == null) return true;
    return _nowSeconds() >= ttl;
  }

  // ── Push permission state ──
  bool isPushAllowed() => _prefs.getBool(_kPushAllowed) ?? false;

  Future<void> markPushAllowed(bool value) =>
      _prefs.setBool(_kPushAllowed, value);

  /// True once the user denied the OS dialog — it can never be shown again,
  /// so the invite screen must stop reappearing.
  bool isPushBlockedByOs() => _prefs.getBool(_kPushBlockedByOs) ?? false;

  Future<void> markPushBlockedByOs() =>
      _prefs.setBool(_kPushBlockedByOs, true);

  int? readInviteCooldown() => _prefs.getInt(_kInviteUntil);

  Future<void> writeInviteCooldown(int unixSeconds) =>
      _prefs.setInt(_kInviteUntil, unixSeconds);

  /// Decides whether to show the push-invite promo before the WebView.
  bool shouldOfferPushInvite() {
    if (isPushAllowed()) return false; // already granted
    if (isPushBlockedByOs()) return false; // OS will ignore further requests
    final int? until = readInviteCooldown();
    if (until == null) return true; // never shown
    return _nowSeconds() >= until; // cooldown elapsed
  }

  // ── One-time push link (secure) ──
  Future<void> stashPendingLink(String? link) async {
    if (link == null) {
      await _secure.delete(key: _kPendingLink);
    } else {
      await _secure.write(key: _kPendingLink, value: link);
    }
  }

  Future<String?> takePendingLink() async {
    final String? link = await _secure.read(key: _kPendingLink);
    if (link != null) await _secure.delete(key: _kPendingLink);
    return link;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
