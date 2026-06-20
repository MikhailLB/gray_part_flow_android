import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyward_towers/game/logic/board.dart';
import 'package:skyward_towers/game/models/tile.dart';

void main() {
  group('Board merge logic', () {
    test('two equal tiles merge into one of the next level', () {
      final Board board = Board(size: 4, random: Random(1));
      board.addTile(1, 0, 0);
      board.addTile(1, 0, 1);

      final MoveResult result = board.move(SwipeDirection.left);

      expect(result.moved, isTrue);
      expect(board.tiles.length, 1);
      expect(board.tiles.first.level, 2);
      expect(board.tiles.first.col, 0);
      expect(result.absorbed.length, 1);
      expect(result.scoreGained, 1 << 2);
    });

    test('three equal tiles merge only the outer pair (no chain)', () {
      final Board board = Board(size: 4, random: Random(1));
      board.addTile(1, 0, 0);
      board.addTile(1, 0, 1);
      board.addTile(1, 0, 2);

      board.move(SwipeDirection.left);

      // Expect a level-2 tile and a leftover level-1 tile.
      final List<int> levels =
          board.tiles.map((Tile t) => t.level).toList()..sort();
      expect(levels, <int>[1, 2]);
      expect(board.tiles.length, 2);
    });

    test('different levels do not merge', () {
      final Board board = Board(size: 4, random: Random(1));
      board.addTile(1, 0, 0);
      board.addTile(2, 0, 1);

      final MoveResult result = board.move(SwipeDirection.left);

      expect(board.tiles.length, 2);
      expect(result.scoreGained, 0);
    });

    test('move with no change reports moved=false', () {
      final Board board = Board(size: 4, random: Random(1));
      board.addTile(1, 0, 0);

      final MoveResult result = board.move(SwipeDirection.left);
      expect(result.moved, isFalse);
    });

    test('tiles slide to the far edge on right swipe', () {
      final Board board = Board(size: 4, random: Random(1));
      board.addTile(3, 0, 0);

      final MoveResult result = board.move(SwipeDirection.right);

      expect(result.moved, isTrue);
      expect(board.tiles.first.col, 3);
    });

    test('canMove is false on a full unmergeable board', () {
      final Board board = Board(size: 2, random: Random(1));
      board.addTile(1, 0, 0);
      board.addTile(2, 0, 1);
      board.addTile(2, 1, 0);
      board.addTile(1, 1, 1);

      expect(board.canMove(), isFalse);
    });

    test('spawnRandom fills empty cells until full', () {
      final Board board = Board(size: 2, random: Random(1));
      expect(board.spawnRandom(), isNotNull);
      expect(board.spawnRandom(), isNotNull);
      expect(board.spawnRandom(), isNotNull);
      expect(board.spawnRandom(), isNotNull);
      expect(board.spawnRandom(), isNull); // board full
    });
  });
}
