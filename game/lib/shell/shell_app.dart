import 'package:flutter/material.dart';

import '../bridge/attribution_bridge.dart';
import '../bridge/link_watch.dart';
import '../bridge/net_gate.dart';
import '../bridge/push_hub.dart';
import '../bridge/vault.dart';
import '../env/facade.dart';
import '../theme/app_theme.dart';
import 'flow_router.dart';

/// Root widget. Owns the long-lived bridges and hands them to the router.
///
/// The MaterialApp title is intentionally sourced from `TowerFacade.displayName`
/// so it stays in sync with the store listing (and with the Android
/// `android:label`). Do not hard-code a title here — every new project only
/// changes `facade.dart` and this widget picks it up automatically.
class ShellApp extends StatelessWidget {
  const ShellApp({
    super.key,
    required this.vault,
    required this.linkWatch,
    required this.attribution,
    required this.netGate,
    required this.pushHub,
  });

  final Vault vault;
  final LinkWatch linkWatch;
  final AttributionBridge attribution;
  final NetGate netGate;
  final PushHub pushHub;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: TowerFacade.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: FlowRouter(
        vault: vault,
        linkWatch: linkWatch,
        attribution: attribution,
        netGate: netGate,
        pushHub: pushHub,
      ),
    );
  }
}
