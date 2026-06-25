import 'legal_links.dart';
import 'secure_strings.dart';

// ============================================================
// TOWER FACADE — single access point for app-wide constants
// ============================================================
// Identity values are plain; endpoints/credentials resolve lazily
// through the obfuscator so plaintext never lands in the binary.
// ============================================================

class TowerFacade {
  TowerFacade._();

  // -- Identity --
  static const String packageId = 'com.riverstone.skywardtowers';
  static const String marketId = 'com.riverstone.skywardtowers';
  static const String displayName = 'Skyward Towers';

  // iOS App Store numeric id (unused on Android).
  static const String storeNumericId = '';

  // -- Resolved endpoints / credentials --
  static String get gateEndpoint => unlockConfigEndpoint();
  static String get attributionKey => unlockAttributionKey();
  static String get messagingProject => unlockMessagingProject();

  // -- Public links --
  static const String privacyUrl = privacyPolicyLink;
  static const String helpUrl = supportLink;
  static const String homeUrl = siteHome;

  // -- Timing knobs --
  // Re-prompt the push invite this many seconds after a Skip (3 days).
  static const int pushInviteCooldown = 3 * 24 * 60 * 60;

  // Delay before retrying attribution via GCD when the first callback
  // reports a (possibly false) Organic status.
  static const int organicRecheckDelay = 5;
}
