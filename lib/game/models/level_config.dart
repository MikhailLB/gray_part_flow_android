/// Definition of a single puzzle level.
///
/// The player wins by merging buildings up to [targetLevel]. Stars are awarded
/// based on how few moves it takes: finishing in [movesForThreeStars] (or fewer)
/// earns 3 stars, within [movesForTwoStars] earns 2, otherwise 1.
class LevelConfig {
  const LevelConfig({
    required this.index,
    required this.gridSize,
    required this.targetLevel,
    required this.movesForThreeStars,
    required this.movesForTwoStars,
  });

  /// 1-based level number.
  final int index;
  final int gridSize;
  final int targetLevel;
  final int movesForThreeStars;
  final int movesForTwoStars;

  String get title => 'Level $index';

  int starsForMoves(int moves) {
    if (moves <= movesForThreeStars) return 3;
    if (moves <= movesForTwoStars) return 2;
    return 1;
  }
}

/// The full 50-level campaign, generated with a smooth difficulty curve.
///
/// Difficulty ramps three ways: the board grows (4x4 -> 5x5 -> 6x6), the target
/// building level rises, and the star move-budgets tighten across each group of
/// levels that share a target. Winning always grants at least 1 star, so the
/// next level always unlocks.
class Levels {
  Levels._();

  static const int totalLevels = 50;

  static final List<LevelConfig> all = _generate();

  static List<LevelConfig> _generate() {
    final List<LevelConfig> list = <LevelConfig>[];
    for (int i = 1; i <= totalLevels; i++) {
      final int gridSize = i <= 4 ? 4 : (i <= 24 ? 5 : 6);

      // Target rises every ~8 levels, capped at 8 to keep runs reasonable.
      final int target = (3 + (i - 1) ~/ 8).clamp(3, 8);

      // Approx number of base tiles needed to reach the target building.
      final int need = 1 << (target - 1);

      // Tighten thresholds for later levels within the same target group.
      final int withinGroup = (i - 1) % 8; // 0..7
      final double tighten = 1.0 - withinGroup * 0.03;

      final int three = (need * 1.8 * tighten).round() + gridSize;
      final int two = (need * 2.6 * tighten).round() + gridSize;

      list.add(LevelConfig(
        index: i,
        gridSize: gridSize,
        targetLevel: target,
        movesForThreeStars: three,
        movesForTwoStars: two,
      ));
    }
    return list;
  }

  static int get count => all.length;

  static LevelConfig byIndex(int index) =>
      all.firstWhere((LevelConfig l) => l.index == index);
}
