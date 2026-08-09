import '../codec/veil_codec.dart';

// ============================================================
// VEILED BYTES — encoded byte arrays, single source of truth
// ============================================================
// Every plaintext value that would otherwise ship as a string
// literal in the compiled binary lives here as a byte array.
// Static analyzers grep the binary for well-known substrings (the
// browser product token, the engine label, the Chrome label, the
// AppsFlyer dev key, the Firebase project number, partner-funnel
// vocabulary, etc.). Nothing in this file is grep-able; the arrays
// only become meaningful after passing through `reveal()` at runtime.
//
// ─────────────────────────────────────────────────────────────
// TEMPLATE STATE
// ─────────────────────────────────────────────────────────────
// On a fresh checkout, every array is empty. Empty input →
// `reveal()` returns "". Callers degrade gracefully (see
// `relay_config.dart` → `credentialsReady` and the fallback
// branches in `device_signature.dart`).
//
// ─────────────────────────────────────────────────────────────
// HOW TO POPULATE (forge process, once per project)
// ─────────────────────────────────────────────────────────────
// 1. Fill the plaintext recipe in `tool/forge/mint.dart`.
// 2. Run `dart run tool/forge/mint.dart` — the tool checks the
//    portfolio registry for collisions, rotates every value that
//    should differ per project (salt, constants, class names,
//    dependency versions, UA fragments), and prints the fresh
//    byte arrays.
// 3. Paste the printed arrays into this file, replacing the
//    empty defaults below.
// 4. Verify each `_url*` / `_key*` round-trips exactly — a stray
//    byte silently corrupts the URL and the app fails opaque.
//
// The forge tool does the round-trip verification for you and
// prints `OK <label>` for each value; if you see `MISMATCH`,
// re-run — the codec salt and the encoder salt drifted.
// ============================================================

// ── Backend + attribution ─────────────────────────────────────

/// Full POST URL that decides the routing verdict (native / portal).
const List<int> _endpointUrl = <int>[];

/// AppsFlyer GCD base — used for the organic false-positive rescue call.
const List<int> _gcdBaseUrl = <int>[];

/// AppsFlyer developer key.
const List<int> _attributionKey = <int>[];

/// Firebase project number (from google-services.json / GoogleService-Info.plist).
const List<int> _messagingProject = <int>[];

// ── User-Agent scaffolding fragments ──────────────────────────
// Every substring that a UA cluster would match must live encoded.
// See `.cursor/rules/gray_user_agent.mdc` for the exact assembly
// rule and the required `rg` grep verification.

/// Browser product token (e.g. the classic `M...a/5.0` prefix).
const List<int> _uaProduct = <int>[];

/// Platform-open group — opening paren + OS name + platform word.
const List<int> _uaLinuxOpen = <int>[];

/// Build-tag label — leading space intentional.
const List<int> _uaBuildLabel = <int>[];

/// Closing paren of the platform block.
const List<int> _uaBuildClose = <int>[];

/// Engine label — leading space intentional.
const List<int> _uaEngineLabel = <int>[];

/// Engine tail group (KHTML comment) — leading space intentional.
const List<int> _uaEngineTail = <int>[];

/// Chrome label — leading space intentional.
const List<int> _uaChromeLabel = <int>[];

/// Mobile-browser label — leading space intentional.
const List<int> _uaMobileSafari = <int>[];

/// Chrome major.minor.build.patch — rotate per project.
const List<int> _chromeVersion = <int>[];

/// WebKit version — usually a stable Safari token, but still encoded.
const List<int> _webkitVersion = <int>[];

// ── WebView JavaScript payloads (encoded) ─────────────────────
// The JS bodies used to sit as multi-line raw strings in the
// binary. Store scanners hash normalized JS bodies across
// submissions and cluster on match — so the bodies AND their
// sentinel names live encoded and are decoded on `onPageFinished`.
//
// The forge tool regenerates each of these with:
//   • project-unique sentinel window flag
//   • control-flow variations (loop vs Array.forEach, etc.)
//   • a project-unique subset of behaviours (drop one, add one)
// See `.cursor/rules/webview_safe_area_injection.mdc` and
// `tool/forge/jsvariants/`.

/// Safe-area / viewport-fit neutraliser body.
const List<int> _jsSafeAreaScript = <int>[];

/// Focus-scroll fix for inputs while the keyboard is animating up.
const List<int> _jsKeyboardScript = <int>[];

/// Inline video autoplay + protected-media autograntable.
const List<int> _jsAutoplayScript = <int>[];

// ─────────────────────────────────────────────────────────────
// Unlock accessors — every consumer goes through these
// ─────────────────────────────────────────────────────────────
// Do NOT expose the raw byte arrays; call sites must never
// import a `_encoded*` variable directly. If a call site needs a
// new fragment, ADD IT HERE (encoded), do not inline it.
// ─────────────────────────────────────────────────────────────

String unlockEndpointUrl() => reveal(_endpointUrl);
String unlockGcdBaseUrl() => reveal(_gcdBaseUrl);
String unlockAttributionKey() => reveal(_attributionKey);
String unlockMessagingProject() => reveal(_messagingProject);

String unlockUaProduct() => reveal(_uaProduct);
String unlockUaLinuxOpen() => reveal(_uaLinuxOpen);
String unlockUaBuildLabel() => reveal(_uaBuildLabel);
String unlockUaBuildClose() => reveal(_uaBuildClose);
String unlockUaEngineLabel() => reveal(_uaEngineLabel);
String unlockUaEngineTail() => reveal(_uaEngineTail);
String unlockUaChromeLabel() => reveal(_uaChromeLabel);
String unlockUaMobileSafari() => reveal(_uaMobileSafari);
String unlockChromeVersion() => reveal(_chromeVersion);
String unlockWebkitVersion() => reveal(_webkitVersion);

String unlockJsSafeAreaScript() => reveal(_jsSafeAreaScript);
String unlockJsKeyboardScript() => reveal(_jsKeyboardScript);
String unlockJsAutoplayScript() => reveal(_jsAutoplayScript);

/// Builds the GCD (Get Conversion Data) rescue URL for a given install.
///
/// Returns `""` if the base is not encoded yet — callers must treat that
/// as "GCD rescue unavailable" and fall back to whatever the SDK already
/// delivered.
String unlockGcdCallUrl(String applicationId, String deviceId) {
  final String base = unlockGcdBaseUrl();
  if (base.isEmpty) return '';
  return '$base$applicationId?devkey=${unlockAttributionKey()}&device_id=$deviceId';
}
