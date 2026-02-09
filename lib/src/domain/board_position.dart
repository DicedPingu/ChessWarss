class BoardPosition {
  const BoardPosition(this.row, this.col);

  final int row;
  final int col;

  bool inBounds(int rows, int cols) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }

  BoardPosition offset(int rowDelta, int colDelta) {
    return BoardPosition(row + rowDelta, col + colDelta);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BoardPosition && other.row == row && other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}
