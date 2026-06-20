import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-level star ratings and best scores using SharedPreferences.
///
/// A level is "unlocked" when the previous level has at least 1 star. Level 1
/// is always unlocked.
class ProgressStore {
  ProgressStore._(this._prefs);

  static const String _starsKey = 'stars_level_';
  static const String _bestScoreKey = 'best_score_level_';

  final SharedPreferences _prefs;

  static Future<ProgressStore> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return ProgressStore._(prefs);
  }

  int starsFor(int levelIndex) => _prefs.getInt('$_starsKey$levelIndex') ?? 0;

  int bestScoreFor(int levelIndex) =>
      _prefs.getInt('$_bestScoreKey$levelIndex') ?? 0;

  bool isUnlocked(int levelIndex) {
    if (levelIndex <= 1) return true;
    return starsFor(levelIndex - 1) > 0;
  }

  int get totalStars {
    int sum = 0;
    for (int i = 1; i <= 999; i++) {
      final int s = _prefs.getInt('$_starsKey$i') ?? -1;
      if (s < 0 && i > 1) break;
      if (s > 0) sum += s;
    }
    return sum;
  }

  /// Records a completed level. Keeps the best (highest) star count and score.
  Future<void> recordResult({
    required int levelIndex,
    required int stars,
    required int score,
  }) async {
    if (stars > starsFor(levelIndex)) {
      await _prefs.setInt('$_starsKey$levelIndex', stars);
    }
    if (score > bestScoreFor(levelIndex)) {
      await _prefs.setInt('$_bestScoreKey$levelIndex', score);
    }
  }
}
