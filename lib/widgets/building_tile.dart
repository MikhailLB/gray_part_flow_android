import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../game/models/tile.dart';
import '../theme/app_theme.dart';

/// Renders a single building tile with spawn (scale-in) and merge (pop)
/// animations driven by a local controller.
class BuildingTile extends StatefulWidget {
  const BuildingTile({
    super.key,
    required this.tile,
    required this.size,
  });

  final Tile tile;
  final double size;

  @override
  State<BuildingTile> createState() => _BuildingTileState();
}

class _BuildingTileState extends State<BuildingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    if (widget.tile.isNew) {
      _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      );
      _controller.forward();
    } else {
      _scale = const AlwaysStoppedAnimation<double>(1.0);
    }
  }

  @override
  void didUpdateWidget(covariant BuildingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tile.justMerged && !oldWidget.tile.justMerged) {
      _playPop();
    }
  }

  void _playPop() {
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_controller);
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int level = widget.tile.level;
    return ScaleTransition(
      scale: _scale,
      child: Padding(
        padding: EdgeInsets.all(widget.size * 0.06),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Soft rounded plate behind the art so transparent PNGs read well.
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(widget.size * 0.16),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(widget.size * 0.04),
              child: Image.asset(
                AppAssets.blockForLevel(level),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (level > AppAssets.blocks.length) _LevelBadge(level: level),
          ],
        ),
      ),
    );
  }
}

/// Badge shown for buildings taller than the available art set.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 2,
      right: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.sunset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          'Lv$level',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
