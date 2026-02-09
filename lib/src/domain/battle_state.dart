import 'army.dart';
import 'board_position.dart';
import 'piece.dart';

class BattleState {
  const BattleState({
    required this.rows,
    required this.cols,
    required this.activePlayer,
    this.southPlayerId = 0,
    this.northPlayerId = 1,
    required this.pieces,
    required this.moveLog,
    this.blockedCells = const <BoardPosition>{},
  });

  final int rows;
  final int cols;
  final int activePlayer;
  final int southPlayerId;
  final int northPlayerId;
  final List<BattlePiece> pieces;
  final List<String> moveLog;
  final Set<BoardPosition> blockedCells;

  factory BattleState.fromArmies({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
    required int southOwnerId,
    required int northOwnerId,
    int rows = 8,
    int cols = 8,
    Set<BoardPosition> blockedCells = const <BoardPosition>{},
  }) {
    final southPieces = _deployArmy(
      army: southArmy,
      ownerId: southOwnerId,
      sideIsNorth: false,
      rows: rows,
      cols: cols,
      idPrefix: 'S$southOwnerId',
      blockedCells: blockedCells,
    );

    final northPieces = _deployArmy(
      army: northArmy,
      ownerId: northOwnerId,
      sideIsNorth: true,
      rows: rows,
      cols: cols,
      idPrefix: 'N$northOwnerId',
      blockedCells: blockedCells,
    );

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: southOwnerId,
      southPlayerId: southOwnerId,
      northPlayerId: northOwnerId,
      pieces: [...southPieces, ...northPieces],
      moveLog: const [],
      blockedCells: blockedCells,
    );
  }

  BattlePiece? pieceAt(BoardPosition position) {
    for (final piece in pieces) {
      if (piece.position == position) {
        return piece;
      }
    }
    return null;
  }

  BattlePiece? pieceById(String id) {
    for (final piece in pieces) {
      if (piece.id == id) {
        return piece;
      }
    }
    return null;
  }

  bool isBlocked(BoardPosition position) => blockedCells.contains(position);

  int get otherPlayer => activePlayer == southPlayerId ? northPlayerId : southPlayerId;

  List<BattlePiece> piecesForPlayer(int playerId) {
    return pieces.where((piece) => piece.ownerId == playerId).toList();
  }

  int generalsForPlayer(int playerId) {
    return piecesForPlayer(
      playerId,
    ).where((piece) => piece.type == PieceType.general).length;
  }

  bool commanderAlive(int playerId) {
    return generalsForPlayer(playerId) > 0;
  }

  bool hasAnyLegalMove(int playerId) {
    for (final piece in piecesForPlayer(playerId)) {
      if (legalMovesForPiece(piece.id).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<BattleAction> legalActionsForActivePlayer() {
    final actions = <BattleAction>[];
    for (final piece in piecesForPlayer(activePlayer)) {
      for (final move in legalMovesForPiece(piece.id)) {
        actions.add(
          BattleAction(
            pieceId: piece.id,
            to: move,
            capturedPieceId: pieceAt(move)?.id,
          ),
        );
      }
    }
    return actions;
  }

  List<BoardPosition> legalMovesForPiece(String pieceId) {
    final piece = pieceById(pieceId);
    if (piece == null || piece.ownerId != activePlayer) {
      return const [];
    }

    switch (piece.type) {
      case PieceType.pawn:
        return _pawnMoves(piece);
      case PieceType.rook:
        return _sliderMoves(piece, const [
          _Vector(1, 0),
          _Vector(-1, 0),
          _Vector(0, 1),
          _Vector(0, -1),
        ]);
      case PieceType.bishop:
        return _sliderMoves(piece, const [
          _Vector(1, 1),
          _Vector(1, -1),
          _Vector(-1, 1),
          _Vector(-1, -1),
        ]);
      case PieceType.knight:
        return _knightMoves(piece);
      case PieceType.general:
        return _generalMoves(piece);
    }
  }

  BattleState movePiece({required String pieceId, required BoardPosition to}) {
    final movingPiece = pieceById(pieceId);
    if (movingPiece == null) {
      return this;
    }

    final legalMoves = legalMovesForPiece(pieceId);
    if (!legalMoves.contains(to)) {
      return this;
    }

    final target = pieceAt(to);

    final updatedPieces = <BattlePiece>[];
    for (final piece in pieces) {
      if (piece.id == pieceId) {
        var moved = piece.copyWith(position: to);
        if (target != null && piece.type == PieceType.general) {
          moved = moved.gainGeneralExperience();
        }
        updatedPieces.add(moved);
        continue;
      }

      if (target != null && piece.id == target.id) {
        continue;
      }

      updatedPieces.add(piece);
    }

    final moverLabel = '${_pieceCode(movingPiece)}${movingPiece.ownerId + 1}';
    final captureLabel = target == null
        ? ''
        : ' x${_pieceCode(target)}${target.ownerId + 1}';
    final logEntry = '$moverLabel -> (${to.row},${to.col})$captureLabel';

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: updatedPieces,
      moveLog: [...moveLog, logEntry],
      blockedCells: blockedCells,
    );
  }

  static String _pieceCode(BattlePiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return 'P';
      case PieceType.rook:
        return 'R';
      case PieceType.knight:
        return 'N';
      case PieceType.bishop:
        return 'B';
      case PieceType.general:
        return piece.generalSkill == GeneralSkill.veteranCommander ? 'GV' : 'G';
    }
  }

  List<BoardPosition> _pawnMoves(BattlePiece piece) {
    final direction = piece.ownerId == southPlayerId ? -1 : 1;
    final oneStepForward = piece.position.offset(direction, 0);
    final moves = <BoardPosition>[];

    if (_isOpenSquare(oneStepForward)) {
      moves.add(oneStepForward);
    }

    for (final colDelta in const [-1, 1]) {
      final captureSquare = piece.position.offset(direction, colDelta);
      if (!captureSquare.inBounds(rows, cols) || isBlocked(captureSquare)) {
        continue;
      }
      final occupant = pieceAt(captureSquare);
      if (occupant != null && occupant.ownerId != piece.ownerId) {
        moves.add(captureSquare);
      }
    }

    return moves;
  }

  List<BoardPosition> _knightMoves(BattlePiece piece) {
    final moves = <BoardPosition>[];
    for (final vector in const [
      _Vector(2, 1),
      _Vector(2, -1),
      _Vector(-2, 1),
      _Vector(-2, -1),
      _Vector(1, 2),
      _Vector(1, -2),
      _Vector(-1, 2),
      _Vector(-1, -2),
    ]) {
      final next = piece.position.offset(vector.rowDelta, vector.colDelta);
      if (!next.inBounds(rows, cols) || isBlocked(next)) {
        continue;
      }
      final occupant = pieceAt(next);
      if (occupant == null || occupant.ownerId != piece.ownerId) {
        moves.add(next);
      }
    }
    return moves;
  }

  List<BoardPosition> _generalMoves(BattlePiece piece) {
    final stride = piece.generalStride;
    final moves = <BoardPosition>[];

    for (final vector in const [
      _Vector(1, 0),
      _Vector(-1, 0),
      _Vector(0, 1),
      _Vector(0, -1),
    ]) {
      for (var step = 1; step <= stride; step++) {
        final next = piece.position.offset(
          vector.rowDelta * step,
          vector.colDelta * step,
        );
        if (!next.inBounds(rows, cols) || isBlocked(next)) {
          break;
        }

        final occupant = pieceAt(next);
        if (occupant == null) {
          moves.add(next);
          continue;
        }

        if (occupant.ownerId != piece.ownerId) {
          moves.add(next);
        }
        break;
      }
    }

    return moves;
  }

  List<BoardPosition> _sliderMoves(
    BattlePiece piece,
    List<_Vector> directions,
  ) {
    final moves = <BoardPosition>[];
    for (final direction in directions) {
      var next = piece.position.offset(direction.rowDelta, direction.colDelta);
      while (next.inBounds(rows, cols) && !isBlocked(next)) {
        final occupant = pieceAt(next);
        if (occupant == null) {
          moves.add(next);
          next = next.offset(direction.rowDelta, direction.colDelta);
          continue;
        }

        if (occupant.ownerId != piece.ownerId) {
          moves.add(next);
        }
        break;
      }
    }
    return moves;
  }

  bool _isOpenSquare(BoardPosition position) {
    return position.inBounds(rows, cols) &&
        !isBlocked(position) &&
        pieceAt(position) == null;
  }

  static List<BattlePiece> _deployArmy({
    required ArmyDefinition army,
    required int ownerId,
    required bool sideIsNorth,
    required int rows,
    required int cols,
    required String idPrefix,
    required Set<BoardPosition> blockedCells,
  }) {
    final used = <BoardPosition>{};
    final pieces = <BattlePiece>[];

    final frontRow = sideIsNorth ? 1 : rows - 2;
    final backRow = sideIsNorth ? 0 : rows - 1;
    final middleRow = sideIsNorth ? 2 : rows - 3;

    final normalizedMiddle = middleRow.clamp(0, rows - 1);

    final columns = _centerOutColumns(cols);

    var nextIndex = 0;

    void placeUnit(ArmyUnit unit, List<int> preferredRows) {
      for (final row in preferredRows) {
        for (final col in columns) {
          final pos = BoardPosition(row, col);
          if (used.contains(pos) || blockedCells.contains(pos)) {
            continue;
          }
          used.add(pos);
          pieces.add(
            BattlePiece(
              id: '$idPrefix-${nextIndex++}',
              ownerId: ownerId,
              type: unit.type,
              position: pos,
              generalSkill: unit.generalSkill,
            ),
          );
          return;
        }
      }
      throw StateError(
        'Could not place unit ${unit.type} for army ${army.label}.',
      );
    }

    final pawns = army.units.where((unit) => unit.type == PieceType.pawn);
    final generals = army.units.where((unit) => unit.type == PieceType.general);
    final others = army.units.where(
      (unit) => unit.type != PieceType.pawn && unit.type != PieceType.general,
    );

    for (final pawn in pawns) {
      placeUnit(pawn, [frontRow, normalizedMiddle, backRow]);
    }
    for (final general in generals) {
      placeUnit(general, [backRow, normalizedMiddle, frontRow]);
    }
    for (final other in others) {
      placeUnit(other, [normalizedMiddle, backRow, frontRow]);
    }

    return pieces;
  }

  static List<int> _centerOutColumns(int cols) {
    final order = <int>[];
    final leftCenter = (cols - 1) ~/ 2;
    final rightCenter = cols ~/ 2;

    if (leftCenter == rightCenter) {
      order.add(leftCenter);
    } else {
      order.add(rightCenter);
      order.add(leftCenter);
    }

    for (var offset = 1; order.length < cols; offset++) {
      final right = rightCenter + offset;
      final left = leftCenter - offset;
      if (right >= 0 && right < cols) {
        order.add(right);
      }
      if (left >= 0 && left < cols) {
        order.add(left);
      }
    }

    return order;
  }
}

class BattleAction {
  const BattleAction({
    required this.pieceId,
    required this.to,
    this.capturedPieceId,
  });

  final String pieceId;
  final BoardPosition to;
  final String? capturedPieceId;
}

class _Vector {
  const _Vector(this.rowDelta, this.colDelta);

  final int rowDelta;
  final int colDelta;
}
