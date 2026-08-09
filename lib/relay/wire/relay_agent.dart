import 'package:http/http.dart' as http;

import 'device_signature.dart';

// ============================================================
// RELAY AGENT — http.Client that always carries the forged UA
// ============================================================
// Every outbound HTTP call in the relay pipeline (verdict POST,
// GCD rescue, push image fetch) goes through this client. The
// User-Agent header is written unconditionally so no request
// escapes with the default Dart `dart-io/x.y` UA — that literal
// is a well-known Flutter-shell fingerprint.
// ============================================================

class RelayAgent extends http.BaseClient {
  RelayAgent();

  final http.Client _transport = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = DeviceSignature.userAgent;
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}

/// Shared client instance — one per app, primed after
/// `DeviceSignature.prime()` completes in `main()`.
final RelayAgent relayAgent = RelayAgent();
