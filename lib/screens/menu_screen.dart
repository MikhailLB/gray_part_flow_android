import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../env/facade.dart';
import '../state/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'levels_screen.dart';
import 'webview_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Sourced from TowerFacade so a single edit in lib/env/legal_links.dart
  // propagates here and into any other UI surface that displays them.
  static final String privacyUrl = TowerFacade.privacyUrl;
  static final String supportUrl = TowerFacade.helpUrl;

  void _openLevels() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          builder: (_) => LevelsScreen(store: widget.store),
        ))
        .then((_) => setState(() {})); // refresh total stars on return
  }

  void _openWeb(String title, String url) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WebViewScreen(title: title, url: url),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.bgCity, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x22000000), Color(0x88000000)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 2),
                  Image.asset(
                    AppAssets.gameName,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  _TotalStarsChip(total: widget.store.totalStars),
                  const Spacer(flex: 2),
                  PrimaryButton(
                    label: 'Play',
                    icon: Icons.play_arrow_rounded,
                    width: 240,
                    labelDx: -5,
                    onPressed: _openLevels,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Privacy Policy',
                    icon: Icons.privacy_tip_rounded,
                    color: AppColors.skyDeep,
                    width: 240,
                    onPressed: () => _openWeb('Privacy Policy', privacyUrl),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Support',
                    icon: Icons.support_agent_rounded,
                    color: AppColors.skyDeep,
                    width: 240,
                    onPressed: () => _openWeb('Support', supportUrl),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalStarsChip extends StatelessWidget {
  const _TotalStarsChip({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: AppColors.star, size: 22),
          const SizedBox(width: 6),
          Text('$total', style: AppTheme.titleStyle(size: 18)),
        ],
      ),
    );
  }
}
