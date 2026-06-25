import 'dart:convert';

import '../domain/gate_reply.dart';
import '../env/facade.dart';
import 'ua_forge.dart';
import 'vault.dart';

// ============================================================
// NET GATE — posts the attribution body, reads the verdict
// ============================================================
// Sends the merged body to the gate endpoint. On an allowed reply the
// content link + ttl are cached so returning launches can fall back to
// it if the network later fails. A missing endpoint or any error yields
// a failure reply, which routes the user to the native game.
// ============================================================

class NetGate {
  NetGate(this._vault);

  final Vault _vault;

  Future<GateReply> query(Map<String, dynamic> body) async {
    final String endpoint = TowerFacade.gateEndpoint;
    if (endpoint.isEmpty) {
      return GateReply.failure('no-endpoint');
    }

    try {
      final dynamic response = await towerHttp
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return GateReply.failure('http-${response.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      final GateReply reply = GateReply.fromMap(map);

      if (reply.allowed && reply.hasLink) {
        await _vault.writeCachedLink(reply.link!);
        if (reply.ttl != null) {
          await _vault.writeLinkTtl(reply.ttl!);
        }
      }
      return reply;
    } catch (e) {
      return GateReply.failure(e.toString());
    }
  }

  Future<String?> cachedLink() => _vault.readCachedLink();
}
