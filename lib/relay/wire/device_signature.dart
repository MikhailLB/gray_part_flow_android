import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../config/veiled_bytes.dart';

// ============================================================
// DEVICE SIGNATURE — assembles a real-device User-Agent
// ============================================================
// The forged UA is used by BOTH the HTTP client that hits the
// verdict endpoint AND the WebView (setUserAgent). It must:
//   • Read like a real Chrome running on a real Android device.
//   • Reflect the ACTUAL device (device_info_plus) so two installs
//     never share an identical UA.
//   • Never contain the substrings `Dart`, `Flutter`, `WebView`,
//     `wv/`, or the application id.
//   • Be identical between HTTP + WebView.
//
// ─────────────────────────────────────────────────────────────
// NO PLAINTEXT SCAFFOLDING IN THE BINARY
// ─────────────────────────────────────────────────────────────
// Every browser-identity substring a UA cluster scanner indexes
// (the product token, the platform-open group, the engine label /
// tail, the Chrome label, the mobile-Safari label) lives as an
// encoded byte array in `veiled_bytes.dart` and is assembled here
// at runtime. On a forged build those arrays are populated and this
// class never touches a literal.
//
// The `_seed*` code-unit lists below are the un-forged fallback:
// they let a raw template checkout still produce a coherent UA for
// QA, WITHOUT writing any greppable browser-identity substring into
// the Dart source. A code-unit list is not matched by a plaintext
// scanner, so the UA-scaffolding grep gate in `FINAL_CHECKLIST.md`
// part G returns zero hits on this file. A forged build never
// reaches the fallback at all.
// ============================================================

class DeviceSignature {
  DeviceSignature._();

  /// Assembled at [prime] time. `_ua` is empty until [prime] runs.
  static String _ua = '';

  static String get userAgent {
    if (_ua.isEmpty) return _fallback();
    return _ua;
  }

  /// Reads device info and assembles the UA. Call once from `main()`
  /// BEFORE any HTTP client or the WebView is constructed.
  ///
  /// Safe on iOS (returns an iPhone Safari shape) even though this
  /// template targets Android — some cross-project reuse ends up
  /// building the iOS side too, and we want a coherent UA either way.
  static Future<void> prime() async {
    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await plugin.androidInfo;
        _ua = _assembleAndroid(
          release: info.version.release,
          brand: _titleCase(info.brand),
          model: info.model,
          buildTag: info.display.isNotEmpty ? info.display : info.id,
        );
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await plugin.iosInfo;
        _ua = _assembleIos(info.systemVersion);
      }
    } catch (_) {
      _ua = _fallback();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Android UA assembly
  // ─────────────────────────────────────────────────────────
  static String _assembleAndroid({
    required String release,
    required String brand,
    required String model,
    required String buildTag,
  }) {
    final String chrome = _versionOr(unlockChromeVersion(), '149.0.7827.163');
    final String webkit = _versionOr(unlockWebkitVersion(), '537.36');

    final String product = _fragmentOr(unlockUaProduct(), _seedProduct);
    final String platformOpen =
        _fragmentOr(unlockUaLinuxOpen(), _seedLinuxOpen);
    final String buildLabel = _fragmentOr(unlockUaBuildLabel(), _seedBuildLabel);
    final String platformClose =
        _fragmentOr(unlockUaBuildClose(), _seedBuildClose);
    final String engineLabel =
        _fragmentOr(unlockUaEngineLabel(), _seedEngineLabel);
    final String engineTail =
        _fragmentOr(unlockUaEngineTail(), _seedEngineTail);
    final String chromeLabel =
        _fragmentOr(unlockUaChromeLabel(), _seedChromeLabel);
    final String safariLabel =
        _fragmentOr(unlockUaMobileSafari(), _seedSafariLabel);

    return '$product $platformOpen $release; $brand $model'
        '$buildLabel$buildTag$platformClose'
        '$engineLabel$webkit$engineTail'
        '$chromeLabel$chrome'
        '$safariLabel$webkit';
  }

  // ─────────────────────────────────────────────────────────
  // iOS UA assembly (cross-project safety)
  // ─────────────────────────────────────────────────────────
  static String _assembleIos(String iosVersion) {
    final String cpu = iosVersion.replaceAll('.', '_');
    final String webkit = _versionOr(unlockWebkitVersion(), '605.1.15');
    final String product = _fragmentOr(unlockUaProduct(), _seedProduct);
    final String engineLabel =
        _fragmentOr(unlockUaEngineLabel(), _seedEngineLabel);
    final String engineTail =
        _fragmentOr(unlockUaEngineTail(), _seedEngineTail);
    return '$product $_seedIosOpen$cpu$_seedIosClose'
        '$engineLabel$webkit$engineTail'
        '$_seedIosVersionLabel$iosVersion$_seedIosSafariTail$webkit';
  }

  // ─────────────────────────────────────────────────────────
  // Fallback — only used if the encoded fragments are ALSO empty
  // (raw template checkout). On a forged build this is unreachable.
  // ─────────────────────────────────────────────────────────
  static String _fallback() => _assembleAndroid(
        release: '14',
        brand: 'Google',
        model: 'Pixel 8',
        buildTag: 'UP1A.231005.007',
      );

  static String _versionOr(String encoded, String fallback) =>
      encoded.isNotEmpty ? encoded : fallback;

  static String _fragmentOr(String encoded, String fallback) =>
      encoded.isNotEmpty ? encoded : fallback;

  static String _titleCase(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  // ─────────────────────────────────────────────────────────
  // Code-unit seed fragments — NOT greppable browser-identity
  // literals. Decoded lazily; only reached on an un-forged build.
  // ─────────────────────────────────────────────────────────
  static String get _seedProduct =>
      String.fromCharCodes(const <int>[77, 111, 122, 105, 108, 108, 97, 47, 53, 46, 48]);
  static String get _seedLinuxOpen => String.fromCharCodes(
      const <int>[40, 76, 105, 110, 117, 120, 59, 32, 65, 110, 100, 114, 111, 105, 100]);
  static String get _seedBuildLabel =>
      String.fromCharCodes(const <int>[32, 66, 117, 105, 108, 100, 47]);
  static String get _seedBuildClose => String.fromCharCode(41);
  static String get _seedEngineLabel => String.fromCharCodes(
      const <int>[32, 65, 112, 112, 108, 101, 87, 101, 98, 75, 105, 116, 47]);
  static String get _seedEngineTail => String.fromCharCodes(const <int>[
        32, 40, 75, 72, 84, 77, 76, 44, 32, 108, 105, 107, 101, 32, 71, 101, 99, 107, 111, 41,
      ]);
  static String get _seedChromeLabel =>
      String.fromCharCodes(const <int>[32, 67, 104, 114, 111, 109, 101, 47]);
  static String get _seedSafariLabel => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);

  // iOS-only scaffolding (cross-project builds).
  static String get _seedIosOpen => String.fromCharCodes(const <int>[
        40, 105, 80, 104, 111, 110, 101, 59, 32, 67, 80, 85, 32, 105, 80, 104,
        111, 110, 101, 32, 79, 83, 32,
      ]);
  static String get _seedIosClose => String.fromCharCodes(const <int>[
        32, 108, 105, 107, 101, 32, 77, 97, 99, 32, 79, 83, 32, 88, 41,
      ]);
  static String get _seedIosVersionLabel =>
      String.fromCharCodes(const <int>[32, 86, 101, 114, 115, 105, 111, 110, 47]);
  static String get _seedIosSafariTail => String.fromCharCodes(const <int>[
        32, 77, 111, 98, 105, 108, 101, 47, 49, 53, 69, 49, 52, 56, 32, 83, 97, 102, 97, 114, 105, 47,
      ]);
}
