import 'package:flutter/material.dart';

import '../../app/relay_buttons.dart';
import '../../app_assets.dart';
import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import 'portal_stage.dart';

/// One-shot push opt-in promo shown before the portal (only when
/// `keystore.shouldInvitePermission` is true — first time, or after
/// the snooze window expired).
class PermissionStage extends StatefulWidget {
  const PermissionStage({
    super.key,
    required this.keystore,
    required this.alerts,
    required this.destinationUrl,
  });

  final BeaconKeystore keystore;
  final AlertChannel alerts;
  final String destinationUrl;

  @override
  State<PermissionStage> createState() => _PermissionStageState();
}

class _PermissionStageState extends State<PermissionStage> {
  Future<void> _accept() async {
    final bool granted = await widget.alerts.askPermission();
    if (!granted) {
      await widget.keystore
          .writePermissionSnoozeUntil(_snoozeTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    if (mounted) _forward();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      RelayConfig.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PortalStage(
          url: widget.destinationUrl,
          keystore: widget.keystore,
          alerts: widget.alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalNotifications
        : AppAssets.verticalNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFF0E2238),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg,
              fit: BoxFit.cover, width: size.width, height: size.height),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          Positioned(
            left: size.width * 0.08,
            right: size.width * 0.08,
            bottom: size.height * (landscape ? 0.06 : 0.08),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RelayPillButton(
                  label: 'Accept',
                  compact: landscape,
                  width: landscape ? size.width * 0.34 : size.width * 0.7,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 8 : 16),
                RelayTextButton(
                  label: 'Skip',
                  compact: landscape,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
