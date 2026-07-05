import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bridge/attribution_bridge.dart';
import 'bridge/link_watch.dart';
import 'bridge/net_gate.dart';
import 'bridge/push_hub.dart';
import 'bridge/ua_forge.dart';
import 'bridge/vault.dart';
import 'shell/shell_app.dart';

// ============================================================
// main.dart — bootstrap
// ============================================================
// Wiring order (must NOT change without reading the guide):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck   — wrapped in try/catch because the
//      template ships without google-services.json (see
//      android/app/google-services.json.example). Failure here must
//      never block startup — gray mode simply falls back to native.
//   3. Orientation whitelist — all four are enabled so the loading
//      and WebView screens rotate freely. The native game re-locks
//      to portrait inside FlowRouter._goNative.
//   4. Status bar transparent + light icons — the loading artwork
//      goes edge-to-edge.
//   5. towerHttp.prime() — builds the forged device User-Agent used
//      by BOTH the config HTTP call and the WebView (see
//      .cursor/rules/gray_user_agent.mdc when the app is themed as
//      Zeus / Magma — else the plain UA is enough).
//   6. Vault.warmUp() — reads SharedPreferences into memory so the
//      first frame of FlowRouter can decide the route synchronously
//      (no async await = no blank splash).
//   7. Bridges are constructed but not `boot()`-ed here; PushHub /
//      AttributionBridge run inside FlowRouter after the UI is up.
//
// [FINGERPRINT] Do NOT rename the top-level `Vault`, `LinkWatch`,
// `AttributionBridge`, `NetGate`, `PushHub` classes here in isolation
// — the whole rename must happen atomically across the bridge folder
// and every screen that uses them (see .cursor/rules/android_gray_guide.md
// §"Code Mixing"). If you rename in bulk, keep the wiring order intact.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land; failures here
  // must not block startup. See android/app/google-services.json.example.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  // Loading + WebView need every orientation; the game re-locks to
  // portrait once FlowRouter routes into native mode.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Forge the User-Agent BEFORE any bridge is created — NetGate uses
  // the primed value on its first HTTP call.
  await towerHttp.prime();

  final Vault vault = Vault();
  await vault.warmUp();

  final LinkWatch linkWatch = LinkWatch();
  final AttributionBridge attribution = AttributionBridge();
  final NetGate netGate = NetGate(vault);
  final PushHub pushHub = PushHub(vault);

  runApp(ShellApp(
    vault: vault,
    linkWatch: linkWatch,
    attribution: attribution,
    netGate: netGate,
    pushHub: pushHub,
  ));
}
