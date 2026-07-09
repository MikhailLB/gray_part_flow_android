import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../bridge/link_watch.dart';
import '../bridge/push_hub.dart';
import '../bridge/vault.dart';
import '../env/facade.dart';
import 'glass_button.dart';
import 'web_stage.dart';

/// Push opt-in promo shown once before the WebView (gray mode). Uses the
/// project's notification artwork (orientation-aware). Accept triggers the
/// OS permission dialog; Skip arms a cooldown. Either way the user then
/// continues to the content.
class PushInviteStage extends StatelessWidget {
  const PushInviteStage({
    super.key,
    required this.vault,
    required this.pushHub,
    required this.linkWatch,
    required this.contentLink,
  });

  final Vault vault;
  final PushHub pushHub;
  final LinkWatch linkWatch;
  final String contentLink;

  Future<void> _accept(BuildContext context) async {
    final bool granted = await pushHub.askPermission();
    if (!granted) {
      await vault.writeInviteCooldown(_cooldownTarget());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    await vault.writeInviteCooldown(_cooldownTarget());
    if (context.mounted) _forward(context);
  }

  int _cooldownTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      TowerFacade.pushInviteCooldown;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebStage(
          link: contentLink,
          vault: vault,
          pushHub: pushHub,
          linkWatch: linkWatch,
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

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SkyPillButton(
          label: 'Accept',
          compact: landscape,
          width: landscape ? size.width * 0.34 : size.width * 0.7,
          onTap: () => _accept(context),
        ),
        SizedBox(height: landscape ? 8 : 16),
        SkyTextButton(
          label: 'Skip',
          compact: landscape,
          onTap: () => _skip(context),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0E2238),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover, width: size.width, height: size.height),
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
            child: actions,
          ),
        ],
      ),
    );
  }
}
