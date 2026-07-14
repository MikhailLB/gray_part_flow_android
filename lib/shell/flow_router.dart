import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_assets.dart';
import '../bridge/attribution_bridge.dart';
import '../bridge/insight.dart';
import '../bridge/link_watch.dart';
import '../bridge/net_gate.dart';
import '../bridge/push_hub.dart';
import '../bridge/vault.dart';
import '../domain/gate_reply.dart';
import '../domain/shell_mode.dart';
import '../screens/menu_screen.dart';
import '../state/progress_store.dart';
import '../theme/app_theme.dart';
import '../veil/offline_stage.dart';
import '../veil/push_invite_stage.dart';
import '../veil/web_stage.dart';

// ============================================================
// FLOW ROUTER — loading screen + gray/native decision engine
// ============================================================
// The single startup screen. Shows the loading artwork with a progress
// bar and animated "Loading..." caption while it resolves attribution and
// queries the gate, then routes to either the WebView (gray) or the
// native placeholder game (white).
//
// This is the direct implementation of the state machine documented in
// .cursor/rules/android_gray_guide.md §"Gray Flow State Machine".
// Read that section before altering ANY branch of _drive() / _firstRun()
// / _resumeWeb() — the tree is intentionally strict.
//
// [FIRST-LAUNCH UX INVARIANT — do not weaken]
// If the device is offline on the FIRST launch (OneLink install with
// Wi-Fi disabled), _firstRun() short-circuits into _toOffline() BEFORE
// AppsFlyer.ignite() is awaited. The user sees the No-Wi-Fi screen on
// frame 1, and Retry restarts the full pipeline from FlowRouter.initState.
// This is required by TZ + .cursor/rules/android_gray_guide.md
// §"First-Launch UX Contract".
// ============================================================

class FlowRouter extends StatefulWidget {
  const FlowRouter({
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
  State<FlowRouter> createState() => _FlowRouterState();
}

class _FlowRouterState extends State<FlowRouter>
    with SingleTickerProviderStateMixin {
  double _progress = 0.05;
  bool _routed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.pushHub.onTokenRotated = _repostToken;
    Insight.screen('loading');
    _drive();
  }

  @override
  void dispose() {
    widget.pushHub.onTokenRotated = null;
    _dots.dispose();
    super.dispose();
  }

  void _lift(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _drive() async {
    await widget.pushHub.boot();
    _lift(0.2);

    switch (widget.vault.readMode()) {
      case ShellMode.native:
        await _goNative(initialLift: 0.4);
        break;
      case ShellMode.web:
        await _resumeWeb();
        break;
      case ShellMode.unset:
        await _firstRun();
        break;
    }
  }

  Future<void> _firstRun() async {
    if (!await widget.linkWatch.isReachable()) {
      _toOffline();
      return;
    }
    _lift(0.4);

    await widget.attribution.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstallData(),
      widget.attribution.awaitDeepLink(),
    ]);
    _lift(0.7);

    final GateReply reply = await _ask();
    if (reply.allowed && reply.hasLink) {
      await widget.vault.writeMode(ShellMode.web);
      _lift(1.0);
      await _settle();
      _toWeb(reply.link!);
    } else {
      await widget.vault.writeMode(ShellMode.native);
      await _goNative(initialLift: 0.85);
    }
  }

  Future<void> _resumeWeb() async {
    if (!await widget.linkWatch.isReachable()) {
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.4);

    // A pending push link wins over everything.
    final String? pending = await widget.vault.takePendingLink();
    if (pending != null) {
      Insight.event('route_push_link');
      _lift(1.0);
      await _settle();
      _toWeb(pending);
      return;
    }

    final String? cached = await widget.vault.readCachedLink();

    await widget.attribution.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attribution.awaitInstallData(seconds: 10),
      widget.attribution.awaitDeepLink(),
    ]);
    _lift(0.7);

    final GateReply reply = await _ask();
    _lift(1.0);
    await _settle();

    if (reply.allowed && reply.hasLink) {
      _toWeb(reply.link!);
    } else if (cached != null) {
      Insight.event('route_cached_link');
      _toWeb(cached);
    } else {
      _toOffline();
    }
  }

  Future<GateReply> _ask() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.attribution.assembleGateBody(
      locale: locale,
      pushToken: widget.pushHub.token,
    );
    // Identify the session as soon as af_id is known. Attribution tags are
    // attached so the Clarity dashboard can be sliced per acquired user.
    Insight.identify(
      body['af_id']?.toString(),
      tags: <String, String>{
        'af_status': body['af_status']?.toString() ?? '',
        'media_source': body['media_source']?.toString() ?? '',
        'campaign': body['campaign']?.toString() ?? '',
        'os': body['os']?.toString() ?? '',
        'locale': body['locale']?.toString() ?? '',
      },
    );
    return widget.netGate.query(body);
  }

  void _repostToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.attribution.assembleGateBody(
      locale: locale,
      pushToken: token,
    );
    widget.netGate.query(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  // ── Routing ──

  Future<void> _goNative({required double initialLift}) async {
    Insight.tag('run_mode', 'native');
    Insight.event('route_native');
    _lift(initialLift);
    // The game is portrait-only.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final ProgressStore store = await ProgressStore.create();
    await _warmGameArt();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MenuScreen(store: store)),
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

  void _toWeb(String link) {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.tag('run_mode', 'web');
    Insight.event('route_web');
    if (widget.vault.shouldOfferPushInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PushInviteStage(
            vault: widget.vault,
            pushHub: widget.pushHub,
            linkWatch: widget.linkWatch,
            contentLink: link,
          ),
        ),
      );
    } else {
      // Returning users skip the invite screen — classify their notif state
      // so the `notif_permission` tag is never blank in the dashboard.
      Insight.tag(
        'notif_permission',
        widget.vault.isPushAllowed()
            ? 'granted'
            : widget.vault.isPushBlockedByOs()
                ? 'os_denied'
                : 'snoozed',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WebStage(
            link: link,
            vault: widget.vault,
            pushHub: widget.pushHub,
            linkWatch: widget.linkWatch,
          ),
        ),
      );
    }
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.event('route_offline');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => FlowRouter(
            vault: widget.vault,
            linkWatch: widget.linkWatch,
            attribution: widget.attribution,
            netGate: widget.netGate,
            pushHub: widget.pushHub,
          ),
        ),
      ),
    );
  }

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
                        style: AppTheme.titleStyle(size: 24),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
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
