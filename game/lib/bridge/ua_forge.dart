import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../env/secure_strings.dart';

// ============================================================
// UA FORGE — http client wearing a real device user-agent
// ============================================================
// Outgoing requests (gate POST, GCD retry, push image fetch) and the
// WebView all share one user-agent string that mimics the real device's
// Chrome/Safari. A default Dart UA would be an obvious fingerprint.
//
// The Chrome/WebKit version fragments are decoded from secure_strings.
// ============================================================

class ForgedHttpClient extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _ua = 'Mozilla/5.0';

  String get userAgent => _ua;

  /// Reads device info and assembles the user-agent. Call once in main().
  Future<void> prime() async {
    final String chrome = _orFallback(unlockChromeVersion(), '149.0.0.0');
    final String webkit = _orFallback(unlockWebkitVersion(), '537.36');

    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await plugin.androidInfo;
        final String tag = a.display.isNotEmpty ? a.display : a.id;
        _ua = 'Mozilla/5.0 (Linux; Android ${a.version.release}; '
            '${a.brand} ${a.model} Build/$tag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo i = await plugin.iosInfo;
        final String os = i.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 13; Pixel 7 Build/TQ3A) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _orFallback(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client used by every networking bridge.
final ForgedHttpClient towerHttp = ForgedHttpClient();
