import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/relay_app.dart';
import 'relay/relay_coordinator.dart';
import 'relay/wire/alert_channel.dart';
import 'relay/wire/attribution_pulse.dart';
import 'relay/wire/beacon_keystore.dart';
import 'relay/wire/device_signature.dart';
import 'relay/wire/pulse_probe.dart';
import 'relay/wire/verdict_call.dart';

// ============================================================
// main.dart — bootstrap wiring
// ============================================================
// Order of operations (do NOT reorder without reading the docs):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck   — wrapped in try/catch. The template
//      compiles + runs without google-services.json; failures
//      here must NEVER block startup (the coordinator will fall
//      back to the native game path).
//   3. Orientations + status-bar chrome — set once here so the
//      boot screen renders edge-to-edge on frame one.
//   4. DeviceSignature.prime — builds the forged User-Agent used
//      by both the HTTP client (RelayAgent) and the WebView.
//      MUST run before any bridge or the WebView is constructed.
//   5. BeaconKeystore.prime  — reads SharedPreferences into memory
//      so the coordinator's route decision is synchronous.
//   6. Assemble the pipeline and mount RelayApp.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await DeviceSignature.prime();

  final BeaconKeystore keystore = BeaconKeystore();
  await keystore.prime();

  final PulseProbe probe = PulseProbe();
  final AttributionPulse pulse = AttributionPulse();
  final VerdictCall verdict = VerdictCall(keystore);
  final AlertChannel alerts = AlertChannel(keystore);

  final RelayCoordinator coordinator = RelayCoordinator(
    keystore: keystore,
    probe: probe,
    pulse: pulse,
    verdict: verdict,
    alerts: alerts,
  );

  runApp(RelayApp(
    coordinator: coordinator,
    keystore: keystore,
    alerts: alerts,
  ));
}
