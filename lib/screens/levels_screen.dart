import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../game/models/level_config.dart';
import '../state/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/star_row.dart';
import 'game_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  Future<void> _openLevel(LevelConfig config) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GameScreen(config: config, store: widget.store),
    ));
    if (mounted) setState(() {}); // refresh stars/unlocks after playing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.bgCity, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x99000000)),
          SafeArea(
            child: Column(
              children: <Widget>[
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: Levels.count,
                    itemBuilder: (BuildContext context, int i) {
                      final LevelConfig config = Levels.all[i];
                      final bool unlocked =
                          widget.store.isUnlocked(config.index);
                      final int stars = widget.store.starsFor(config.index);
                      return _LevelCard(
                        config: config,
                        unlocked: unlocked,
                        stars: stars,
                        onTap: unlocked ? () => _openLevel(config) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 30),
          ),
          Expanded(
            child: Text(
              'Select Level',
              textAlign: TextAlign.center,
              style: AppTheme.titleStyle(size: 26),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.config,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final LevelConfig config;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? AppColors.panel : const Color(0xFF6F6256),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? AppColors.panelBorder : const Color(0xFF4A4138),
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (unlocked) ...<Widget>[
              Text(
                '${config.index}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.woodDark,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Reach Lv ${config.targetLevel}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.woodDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              StarRow(earned: stars, size: 18),
            ] else
              const Icon(Icons.lock_rounded,
                  color: Color(0xFFCDC3B5), size: 40),
          ],
        ),
      ),
    );
  }
}
