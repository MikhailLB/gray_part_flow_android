import 'dart:math';

import '../models/tile.dart';

enum SwipeDirection { up, down, left, right }

/// Result of a single move attempt.
class MoveResult {
  MoveResult({
    required this.moved,
    required this.scoreGained,
    required this.absorbed,
    required this.highestLevel,
  });

  /// Whether anything actually changed (slid or merged).
  final bool moved;

  /// Score earned this move (sum of resulting merge values).
  final int scoreGained;

  /// Tiles that were merged away. They already have their final position set
  /// (on top of the surviving tile) so the view can animate them, then drop.
  final List<Tile> absorbed;

  /// Highest building level present after the move.
  final int highestLevel;
}

/// Pure, deterministic 2048-style merge engine. No Flutter imports so it can be
/// unit-tested. Randomness is injected for predictability in tests.
class Board {
  Board({required this.size, Random? random}) : _random = random ?? Random();

  final int size;
  final Random _random;

  final List<Tile> tiles = <Tile>[];
  int _nextId = 0;

  int get highestLevel =>
      tiles.isEmpty ? 0 : tiles.map((Tile t) => t.level).reduce(max);

  /// Number of distinct cells currently occupied.
  int get occupied => tiles.length;

  bool get isFull => occupied >= size * size;

  void reset() {
    tiles.clear();
    _nextId = 0;
  }

  List<List<Tile?>> _toGrid() {
    final List<List<Tile?>> grid = List<List<Tile?>>.generate(
      size,
      (_) => List<Tile?>.filled(size, null),
    );
    for (final Tile t in tiles) {
      grid[t.row][t.col] = t;
    }
    return grid;
  }

  /// Spawns a new tile in a random empty cell. Returns it, or null if full.
  /// 90% chance of level 1, 10% chance of level 2.
  Tile? spawnRandom() {
    final List<Point<int>> empty = <Point<int>>[];
    final List<List<Tile?>> grid = _toGrid();
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == null) empty.add(Point<int>(r, c));
      }
    }
    if (empty.isEmpty) return null;
    final Point<int> cell = empty[_random.nextInt(empty.length)];
    final int level = _random.nextDouble() < 0.1 ? 2 : 1;
    final Tile tile = Tile(
      id: _nextId++,
      level: level,
      row: cell.x,
      col: cell.y,
      isNew: true,
    );
    tiles.add(tile);
    return tile;
  }

  /// Adds a tile at an explicit position (used for fixed level setups/tests).
  Tile addTile(int level, int row, int col) {
    final Tile tile = Tile(id: _nextId++, level: level, row: row, col: col);
    tiles.add(tile);
    return tile;
  }

  bool canMove() {
    if (!isFull) return true;
    final List<List<Tile?>> grid = _toGrid();
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final Tile? t = grid[r][c];
        if (t == null) return true;
        if (c + 1 < size && grid[r][c + 1]?.level == t.level) return true;
        if (r + 1 < size && grid[r + 1][c]?.level == t.level) return true;
      }
    }
    return false;
  }

  MoveResult move(SwipeDirection dir) {
    final bool vertical =
        dir == SwipeDirection.up || dir == SwipeDirection.down;
    final bool forward =
        dir == SwipeDirection.down || dir == SwipeDirection.right;

    for (final Tile t in tiles) {
      t.rememberPosition();
      t.justMerged = false;
      t.isNew = false;
    }

    final List<List<Tile?>> grid = _toGrid();
    final List<Tile> absorbed = <Tile>[];
    bool moved = false;
    int gained = 0;

    for (int line = 0; line < size; line++) {
      // Collect tiles in this line, ordered from the edge they move toward.
      final List<Tile> lineTiles = <Tile>[];
      for (int i = 0; i < size; i++) {
        final int idx = forward ? size - 1 - i : i;
        final int r = vertical ? idx : line;
        final int c = vertical ? line : idx;
        final Tile? t = grid[r][c];
        if (t != null) lineTiles.add(t);
      }

      int target = forward ? size - 1 : 0;
      final int step = forward ? -1 : 1;
      Tile? last;

      for (final Tile t in lineTiles) {
        if (last != null && !last.justMerged && last.level == t.level) {
          // Merge t into last.
          last.level += 1;
          last.justMerged = true;
          gained += 1 << last.level;
          t.moveTo(last.row, last.col);
          absorbed.add(t);
          moved = true;
          last = null; // prevent chained merges in one move
        } else {
          final int nr = vertical ? target : line;
          final int nc = vertical ? line : target;
          if (t.row != nr || t.col != nc) moved = true;
          t.moveTo(nr, nc);
          target += step;
          last = t;
        }
      }
    }

    if (moved) {
      tiles.removeWhere((Tile t) => absorbed.contains(t));
    }

    return MoveResult(
      moved: moved,
      scoreGained: gained,
      absorbed: absorbed,
      highestLevel: highestLevel,
    );
  }
}
