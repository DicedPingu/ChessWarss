import 'dart:math';

import 'battle_state.dart';
import 'board_position.dart';
import 'piece.dart';
import 'world.dart';

class StrategicAi {
  const StrategicAi();

  WorldMove? chooseMove(WorldState world, int playerId, int seed) {
    final random = Random(seed + world.round + playerId * 13);
    final candidates = <_ScoredWorldMove>[];

    for (final stack in world.stacksForPlayer(playerId)) {
      final legalMoves = world.legalMovesForStack(stack.id);
      for (final move in legalMoves) {
        final occupant = world.stackAt(move);
        var score = 0.0;
        if (occupant != null && occupant.ownerId != playerId) {
          score += 100;
        }

        final nearestEnemyDistance = _nearestEnemyDistance(world, move, playerId);
        score += (10 - nearestEnemyDistance).clamp(0, 10).toDouble();

        score += random.nextDouble();
        candidates.add(
          _ScoredWorldMove(WorldMove(stackId: stack.id, to: move), score),
        );
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.move;
  }

  int _nearestEnemyDistance(WorldState world, BoardPosition from, int ownerId) {
    var best = 99;
    for (final stack in world.stacks) {
      if (stack.ownerId == ownerId) {
        continue;
      }
      final distance = (stack.position.row - from.row).abs() +
          (stack.position.col - from.col).abs();
      if (distance < best) {
        best = distance;
      }
    }
    return best;
  }
}

class BattleAi {
  const BattleAi();

  BattleAction? chooseMove(BattleState state, int seed) {
    final random = Random(seed + state.moveLog.length * 17 + state.activePlayer);
    final actions = <_ScoredBattleAction>[];

    for (final piece in state.piecesForPlayer(state.activePlayer)) {
      final legalMoves = state.legalMovesForPiece(piece.id);
      for (final to in legalMoves) {
        final target = state.pieceAt(to);
        var score = random.nextDouble();

        if (target != null && target.ownerId != piece.ownerId) {
          score += _pieceValue(target.type) * 12;
        }

        if (piece.type == PieceType.general && target == null) {
          score -= 1.0;
        }

        final centerBias =
            -((to.row - (state.rows / 2)).abs() + (to.col - (state.cols / 2)).abs());
        score += centerBias * 0.08;

        actions.add(
          _ScoredBattleAction(
            BattleAction(pieceId: piece.id, to: to, capturedPieceId: target?.id),
            score,
          ),
        );
      }
    }

    if (actions.isEmpty) {
      return null;
    }

    actions.sort((a, b) => b.score.compareTo(a.score));
    return actions.first.action;
  }

  int _pieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 1;
      case PieceType.knight:
        return 3;
      case PieceType.bishop:
        return 3;
      case PieceType.rook:
        return 5;
      case PieceType.general:
        return 9;
    }
  }
}

class _ScoredWorldMove {
  const _ScoredWorldMove(this.move, this.score);

  final WorldMove move;
  final double score;
}

class _ScoredBattleAction {
  const _ScoredBattleAction(this.action, this.score);

  final BattleAction action;
  final double score;
}
