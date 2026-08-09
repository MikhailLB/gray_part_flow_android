// ============================================================
// INLINE BEACON — cold-boot deep-link consumption
// ============================================================
// A cold-boot push tap on Android delivers the URL through the
// launch intent, which Firebase Messaging surfaces via
// `getInitialMessage()`. `AlertChannel` writes it into the
// keystore's pending slot. This class is a thin one-shot reader
// so the coordinator has a single entry point for cold-launch
// URLs, symmetric with the returning-launch code path.
// ============================================================

import 'beacon_keystore.dart';

class InlineBeacon {
  InlineBeacon._();

  /// Reads and clears the pending URL. Returns `null` when there was
  /// no cold-boot push tap.
  static Future<String?> consume(BeaconKeystore keystore) =>
      keystore.consumePendingUrl();
}
