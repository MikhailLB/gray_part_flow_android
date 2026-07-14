import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../bridge/insight.dart';
import '../game/logic/board.dart';
import '../game/models/level_config.dart';
import '../game/models/tile.dart';
import '../state/progress_store.dart';
import '../theme/app_theme.dart';
import '../widgets/building_tile.dart';
import '../widgets/primary_button.dart';
import '../widgets/star_row.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.config, required this.store});

  final LevelConfig config;
  final ProgressStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Duration _slideDuration = Duration(milliseconds: 140);

  late Board _board;
  late List<Tile> _renderTiles;
  int _score = 0;
  int _moves = 0;
  bool _busy = false;
  bool _finished = false;

  Offset _dragDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    Insight.screen('game');
    Insight.tag('level', '${widget.config.index}');
    _startNewGame();
  }

  void _startNewGame() {
    _board = Board(size: widget.config.gridSize);
    _board.spawnRandom();
    _board.spawnRandom();
    _score = 0;
    _moves = 0;
    _busy = false;
    _finished = false;
    _renderTiles = List<Tile>.of(_board.tiles);
  }

  Future<void> _handleSwipe(SwipeDirection dir) async {
    if (_busy || _finished) return;

    final MoveResult result = _board.move(dir);
    if (!result.moved) return;

    setState(() {
      _busy = true;
      _moves++;
      _score += result.scoreGained;
      // Include absorbed tiles so they animate into the merge target.
      _renderTiles = <Tile>[..._board.tiles, ...result.absorbed];
    });

    await Future<void>.delayed(_slideDuration);
    if (!mounted) return;

    // Drop absorbed tiles; surviving merged tiles pop via justMerged flag.
    setState(() => _renderTiles = List<Tile>.of(_board.tiles));

    // Win check before spawning a new tile.
    if (_board.highestLevel >= widget.config.targetLevel) {
      await _onWin();
      return;
    }

    _board.spawnRandom();
    if (!mounted) return;
    setState(() => _renderTiles = List<Tile>.of(_board.tiles));

    if (!_board.canMove()) {
      await _onLose();
      return;
    }

    setState(() => _busy = false);
  }

  Future<void> _onWin() async {
    _finished = true;
    final int stars = widget.config.starsForMoves(_moves);
    Insight.event('game_win');
    Insight.tag('last_win_level', '${widget.config.index}');
    Insight.tag('last_win_stars', '$stars');
    await widget.store.recordResult(
      levelIndex: widget.config.index,
      stars: stars,
      score: _score,
    );
    if (!mounted) return;
    await _showResultDialog(won: true, stars: stars);
  }

  Future<void> _onLose() async {
    _finished = true;
    Insight.event('game_lose');
    Insight.tag('last_lose_level', '${widget.config.index}');
    if (!mounted) return;
    await _showResultDialog(won: false, stars: 0);
  }

  void _handleDragEnd() {
    const double threshold = 16;
    final Offset d = _dragDelta;
    _dragDelta = Offset.zero;
    if (d.distance < threshold) return;
    if (d.dx.abs() > d.dy.abs()) {
      _handleSwipe(d.dx > 0 ? SwipeDirection.right : SwipeDirection.left);
    } else {
      _handleSwipe(d.dy > 0 ? SwipeDirection.down : SwipeDirection.up);
    }
  }

  Future<void> _showResultDialog({required bool won, required int stars}) {
    final bool hasNext = widget.config.index < Levels.count;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ResultDialog(
          won: won,
          stars: stars,
          score: _score,
          showNext: won && hasNext,
          onRetry: () {
            Navigator.of(context).pop();
            setState(_startNewGame);
          },
          onNext: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => GameScreen(
                config: Levels.byIndex(widget.config.index + 1),
                store: widget.store,
              ),
            ));
          },
          onMenu: () {
            Navigator.of(context).pop(); // close dialog
            Navigator.of(context).pop(); // back to levels
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(AppAssets.bgCity, fit: BoxFit.cover),
          const ColoredBox(color: Color(0x66000000)),
          SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(),
                _buildStats(),
                const SizedBox(height: 8),
                Expanded(child: Center(child: _buildBoard())),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Swipe to merge buildings',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 30),
          ),
          Expanded(
            child: Text(
              widget.config.title,
              style: AppTheme.titleStyle(size: 24),
            ),
          ),
          IconButton(
            onPressed: () => setState(_startNewGame),
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _StatChip(label: 'SCORE', value: '$_score'),
          _TargetChip(targetLevel: widget.config.targetLevel),
          _StatChip(label: 'MOVES', value: '$_moves'),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side =
            constraints.biggest.shortestSide.clamp(0.0, 460.0);
        final int n = widget.config.gridSize;
        const double pad = 8;
        final double cell = (side - pad * 2) / n;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (_) => _dragDelta = Offset.zero,
          onPanUpdate: (DragUpdateDetails d) => _dragDelta += d.delta,
          onPanEnd: (_) => _handleDragEnd(),
          child: Container(
            width: side,
            height: side,
            padding: const EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: AppColors.boardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.panelBorder, width: 4),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                    color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: Stack(
              children: <Widget>[
                ..._buildEmptyCells(n, cell),
                ..._buildTiles(cell),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEmptyCells(int n, double cell) {
    final List<Widget> cells = <Widget>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        cells.add(Positioned(
          left: c * cell,
          top: r * cell,
          width: cell,
          height: cell,
          child: Padding(
            padding: EdgeInsets.all(cell * 0.06),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.boardCell,
                borderRadius: BorderRadius.circular(cell * 0.16),
              ),
            ),
          ),
        ));
      }
    }
    return cells;
  }

  List<Widget> _buildTiles(double cell) {
    return _renderTiles.map((Tile tile) {
      return AnimatedPositioned(
        key: ValueKey<int>(tile.id),
        duration: _slideDuration,
        curve: Curves.easeInOut,
        left: tile.col * cell,
        top: tile.row * cell,
        width: cell,
        height: cell,
        child: BuildingTile(tile: tile, size: cell),
      );
    }).toList();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.panelBorder, width: 2),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.panelBorder,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.woodDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({required this.targetLevel});

  final int targetLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'GOAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: Image.asset(
              AppAssets.blockForLevel(targetLevel),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.won,
    required this.stars,
    required this.score,
    required this.showNext,
    required this.onRetry,
    required this.onNext,
    required this.onMenu,
  });

  final bool won;
  final int stars;
  final int score;
  final bool showNext;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.panelBorder, width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              won ? 'Level Complete!' : 'Try Again',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: won ? AppColors.brick : AppColors.woodDark,
              ),
            ),
            const SizedBox(height: 16),
            if (won)
              StarRow(earned: stars, size: 44, spacing: 6)
            else
              const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 54, color: AppColors.woodDark),
            const SizedBox(height: 16),
            Text(
              'Score: $score',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.woodDark,
              ),
            ),
            const SizedBox(height: 24),
            if (showNext) ...<Widget>[
              PrimaryButton(label: 'Next Level', width: 220, onPressed: onNext),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: 'Retry',
              width: 220,
              color: AppColors.skyDeep,
              onPressed: onRetry,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Levels',
              width: 220,
              color: AppColors.woodDark,
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}
