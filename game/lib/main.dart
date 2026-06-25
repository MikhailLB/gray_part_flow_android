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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land; failures here
  // must not block startup.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  // Loading + WebView need every orientation; the game re-locks to portrait.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

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
