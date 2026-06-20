/// A single building token on the board.
///
/// Positions are stored as grid coordinates (row/col). The UI layer converts
/// them to pixels. [previousRow]/[previousCol] keep the pre-move position so the
/// view can animate the slide. Flags drive spawn/merge animations.
class Tile {
  Tile({
    required this.id,
    required this.level,
    required this.row,
    required this.col,
    this.isNew = false,
  })  : previousRow = row,
        previousCol = col;

  final int id;
  int level;
  int row;
  int col;

  int previousRow;
  int previousCol;

  /// True for the cycle in which this tile spawned (plays a scale-in).
  bool isNew;

  /// True for the cycle in which this tile was the result of a merge (plays a
  /// pop). Set by the board after a move.
  bool justMerged = false;

  void moveTo(int newRow, int newCol) {
    row = newRow;
    col = newCol;
  }

  void rememberPosition() {
    previousRow = row;
    previousCol = col;
  }
}
