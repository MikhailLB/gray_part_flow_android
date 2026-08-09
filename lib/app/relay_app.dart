import 'package:flutter/material.dart';

import '../boot/boot_screen.dart';
import '../relay/config/relay_config.dart';
import '../relay/relay_coordinator.dart';
import '../relay/wire/alert_channel.dart';
import '../relay/wire/beacon_keystore.dart';
import 'relay_theme.dart';

/// Root widget. Owns the long-lived infrastructure (keystore,
/// alerts, coordinator) and hands them to the boot screen.
class RelayApp extends StatelessWidget {
  const RelayApp({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final RelayCoordinator coordinator;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: RelayConfig.displayName,
      debugShowCheckedModeBanner: false,
      theme: RelayTheme.build(),
      home: BootScreen(
        coordinator: coordinator,
        keystore: keystore,
        alerts: alerts,
      ),
    );
  }
}
