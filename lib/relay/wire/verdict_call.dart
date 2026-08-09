import 'dart:convert';

import '../config/relay_config.dart';
import '../core/landing.dart';
import 'beacon_keystore.dart';
import 'relay_agent.dart';

// ============================================================
// VERDICT CALL — POST the assembled body, cache the answer
// ============================================================
// The backend is the single source of truth for the routing
// decision. On an approved response we cache both the URL AND
// its expiry so returning launches can skip the network call
// when the URL is still fresh. On any failure — HTTP error,
// timeout, malformed JSON — we return a rejected verdict; the
// coordinator turns that into a game landing (or an offline
// landing if the network is down).
// ============================================================

class VerdictCall {
  VerdictCall(this._keystore);

  final BeaconKeystore _keystore;

  Future<Verdict> ask(Map<String, dynamic> body) async {
    final String endpoint = RelayConfig.endpointUrl;
    if (endpoint.isEmpty) {
      return Verdict.rejected('endpoint_missing');
    }

    try {
      final dynamic response = await relayAgent
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: RelayConfig.verdictTimeoutSeconds));

      if (response.statusCode != 200) {
        return Verdict.rejected('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return Verdict.rejected('malformed');
      final Verdict verdict = Verdict.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (verdict.hasDestination) {
        await _keystore.cacheDestination(verdict.url!, verdict.expiresAt);
      }
      return verdict;
    } catch (e) {
      return Verdict.rejected('network:$e');
    }
  }
}
