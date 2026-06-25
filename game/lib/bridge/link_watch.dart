import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin connectivity helper. [isReachable] does a real DNS probe (not just
/// the adapter state) so captive/limited networks are treated as offline.
class LinkWatch {
  LinkWatch({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isReachable() async {
    final List<ConnectivityResult> states =
        await _connectivity.checkConnectivity();
    final bool anyAdapter =
        states.any((ConnectivityResult s) => s != ConnectivityResult.none);
    if (!anyAdapter) return false;

    try {
      final List<InternetAddress> probe = await InternetAddress.lookup(
        'cloudflare.com',
      ).timeout(const Duration(seconds: 3));
      return probe.isNotEmpty && probe.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
