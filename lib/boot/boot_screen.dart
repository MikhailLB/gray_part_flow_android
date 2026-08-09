import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/relay_theme.dart';
import '../app_assets.dart';
import '../relay/core/landing.dart';
import '../relay/relay_coordinator.dart';
import '../relay/stage/offline_stage.dart';
import '../relay/stage/permission_stage.dart';
import '../relay/stage/portal_stage.dart';
import '../relay/wire/alert_channel.dart';
import '../relay/wire/beacon_keystore.dart';
import '../screens/menu_screen.dart';
import '../state/progress_store.dart';

// ============================================================
// BOOT SCREEN — the ONLY startup surface
// ============================================================
// One responsibility: show the loading art + progress bar while
// [RelayCoordinator.decide] resolves, then destructure the sealed
// `Landing` type and push exactly one route. This file contains
// zero routing logic beyond `switch (landing)`; everything else
// lives in `relay/`.
// ============================================================

class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final RelayCoordinator coordinator;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _dotsPeriod = Duration(milliseconds: 1200);

  double _progress = 0.04;
  bool _landed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: _dotsPeriod)..repeat();
    _drive();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  Future<void> _drive() async {
    final Landing outcome =
        await widget.coordinator.decide(onProgress: _liftProgress);
    if (!mounted || _landed) return;
    _landed = true;
    await _settle();
    if (!mounted) return;

    final Widget next = switch (outcome) {
      GameLanding() => await _buildGameLanding(),
      PortalLanding(url: final String url) =>
        _buildPortalLanding(url: url),
      OfflineLanding() => _buildOfflineLanding(),
    };
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  Future<Widget> _buildGameLanding() async {
    // The game is portrait-only.
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final ProgressStore store = await ProgressStore.create();
    await _warmGameArt();
    return MenuScreen(store: store);
  }

  Widget _buildPortalLanding({required String url}) {
    if (widget.keystore.shouldInvitePermission) {
      return PermissionStage(
        keystore: widget.keystore,
        alerts: widget.alerts,
        destinationUrl: url,
      );
    }
    return PortalStage(
      url: url,
      keystore: widget.keystore,
      alerts: widget.alerts,
    );
  }

  Widget _buildOfflineLanding() {
    return OfflineStage(
      onRetryBuild: (_) => BootScreen(
        coordinator: widget.coordinator,
        keystore: widget.keystore,
        alerts: widget.alerts,
      ),
    );
  }

  Future<void> _warmGameArt() async {
    for (final String path in AppAssets.all) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _liftProgress(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? AppAssets.horizontalLoading
        : AppAssets.verticalLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0E2238),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 34, 46),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (BuildContext context, _) {
                      final int n = (_dots.value * 4).floor() % 4;
                      return Text(
                        'Loading${'.' * n}',
                        style: RelayTheme.titleStyle(size: 24),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ProgressTrack(value: _progress),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF63BEF8), Color(0xFF2E78C9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}
