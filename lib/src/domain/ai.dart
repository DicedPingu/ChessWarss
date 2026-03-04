import 'dart:math';

import 'battle_state.dart';
import 'board_position.dart';
import 'piece.dart';
import 'world.dart';

enum AiDifficulty { easy, normal, hard }

extension AiDifficultyProfile on AiDifficulty {
  String get label {
    switch (this) {
      case AiDifficulty.easy:
        return 'Easy';
      case AiDifficulty.normal:
        return 'Normal';
      case AiDifficulty.hard:
        return 'Hard';
    }
  }

  double get strategicNoiseWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 1.8;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 0.45;
    }
  }

  double get strategicPlanningWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 0.8;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 1.2;
    }
  }

  double get campDecisionThreshold {
    switch (this) {
      case AiDifficulty.easy:
        return 3.1;
      case AiDifficulty.normal:
        return 2.4;
      case AiDifficulty.hard:
        return 1.9;
    }
  }

  double get battleNoiseWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 2.0;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 0.35;
    }
  }

  double get battleCaptureWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 9.0;
      case AiDifficulty.normal:
        return 12.0;
      case AiDifficulty.hard:
        return 14.0;
    }
  }

  double get battleIsolationPenaltyWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 0.65;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 1.25;
    }
  }

  double get battleRoutRiskWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 0.65;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 1.45;
    }
  }

  double get battleCommandPreservationWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 0.85;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 1.35;
    }
  }

  double get battleExposurePenaltyWeight {
    switch (this) {
      case AiDifficulty.easy:
        return 0.75;
      case AiDifficulty.normal:
        return 1.0;
      case AiDifficulty.hard:
        return 1.55;
    }
  }
}

class StrategicAi {
  const StrategicAi();

  WorldMove? chooseMove(
    WorldState world,
    int playerId,
    int seed, {
    AiDifficulty difficulty = AiDifficulty.normal,
  }) {
    final cp = world.commandPointsByPlayer[playerId] ?? world.commandPointMax;
    final random = Random(
      seed + world.round * 31 + playerId * 13 + world.log.length * 17 + cp * 7,
    );
    WorldMove? bestMove;
    var bestScore = double.negativeInfinity;

    for (final stack in world.stacksForPlayer(playerId)) {
      final legalMoves = world.legalMovesForStack(stack.id);
      for (final move in legalMoves) {
        final occupant = world.stackAt(move);
        var score = 0.0;
        if (occupant != null && occupant.ownerId != playerId) {
          score += 100 * difficulty.strategicPlanningWeight;
        }

        final nearestEnemyDistance = _nearestEnemyDistance(
          world,
          move,
          playerId,
        );
        score +=
            (10 - nearestEnemyDistance).clamp(0, 10).toDouble() *
            difficulty.strategicPlanningWeight;
        score +=
            _settlementScore(world, move, playerId) *
            difficulty.strategicPlanningWeight;
        score +=
            _campScore(world, move, playerId) *
            difficulty.strategicPlanningWeight;
        score +=
            _frontlinePressureScore(world, move, playerId) *
            difficulty.strategicPlanningWeight;

        final simulated = _simulatedWorldAfterMove(
          world: world,
          stackId: stack.id,
          to: move,
          playerId: playerId,
        );
        final recapturePenalty = _counterCapturePenalty(
          simulated,
          movingStackId: stack.id,
          playerId: playerId,
        );
        score -= recapturePenalty * difficulty.strategicPlanningWeight;
        score -=
            _recentDestinationPenalty(
              world: world,
              stackId: stack.id,
              destination: move,
            ) *
            difficulty.strategicPlanningWeight;

        score += random.nextDouble() * difficulty.strategicNoiseWeight;
        if (score > bestScore) {
          bestScore = score;
          bestMove = WorldMove(stackId: stack.id, to: move);
        }
      }
    }

    return bestMove;
  }

  String? chooseCampStack(
    WorldState world,
    int playerId,
    int seed, {
    AiDifficulty difficulty = AiDifficulty.normal,
  }) {
    final cp = world.commandPointsByPlayer[playerId] ?? world.commandPointMax;
    final random = Random(
      seed + world.round * 29 + playerId * 101 + world.log.length * 11 + cp * 5,
    );
    String? bestStackId;
    var bestScore = double.negativeInfinity;
    final food = world.foodByPlayer[playerId] ?? 0;

    for (final stack in world.stacksForPlayer(playerId)) {
      if (stack.forcedMarchRound == world.round) {
        continue;
      }
      if (world.campAt(stack.position) != null) {
        continue;
      }

      var score = 0.0;
      final nearestEnemy = _nearestEnemyDistance(
        world,
        stack.position,
        playerId,
      );
      if (nearestEnemy <= 2) {
        score += 4.5;
      } else if (nearestEnemy <= 4) {
        score += 2.0;
      }

      if (food <= 2) {
        score += 3.0;
      }

      final settlement = world.settlementAt(stack.position);
      if (settlement != null && settlement.ownerId == playerId) {
        score += 2.5;
        score += switch (settlement.tier) {
          SettlementTier.village => 0.8,
          SettlementTier.town => 1.3,
          SettlementTier.castle => 1.8,
        };
      }

      final pressure = _enemyAdjacentCount(world, stack.position, playerId);
      score += pressure * 0.9 * difficulty.strategicPlanningWeight;
      score += random.nextDouble() * 0.6 * difficulty.strategicNoiseWeight;

      if (score > bestScore) {
        bestScore = score;
        bestStackId = stack.id;
      }
    }

    if (bestScore < difficulty.campDecisionThreshold) {
      return null;
    }
    return bestStackId;
  }

  int _nearestEnemyDistance(WorldState world, BoardPosition from, int ownerId) {
    var best = 99;
    for (final stack in world.stacks) {
      if (stack.ownerId == ownerId) {
        continue;
      }
      final distance =
          (stack.position.row - from.row).abs() +
          (stack.position.col - from.col).abs();
      if (distance < best) {
        best = distance;
      }
    }
    return best;
  }

  double _settlementScore(WorldState world, BoardPosition move, int playerId) {
    final settlement = world.settlementAt(move);
    if (settlement == null) {
      return 0;
    }

    final tierValue = switch (settlement.tier) {
      SettlementTier.village => 3.0,
      SettlementTier.town => 5.0,
      SettlementTier.castle => 6.5,
    };
    final unrestPenalty = settlement.unrest * 0.35;

    if (settlement.ownerId == playerId) {
      return 1.4 + (tierValue * 0.2) - (unrestPenalty * 0.1);
    }
    if (settlement.ownerId < 0) {
      return 4.0 + tierValue - unrestPenalty;
    }
    return 8.0 + tierValue - unrestPenalty;
  }

  double _campScore(WorldState world, BoardPosition move, int playerId) {
    final camp = world.campAt(move);
    if (camp == null) {
      return 0;
    }

    if (camp.ownerId == playerId) {
      return switch (camp.posture) {
        CampPosture.supply => 2.5,
        CampPosture.fortified => 2.0,
        CampPosture.raiding => 1.3,
      };
    }
    return 6.0;
  }

  double _frontlinePressureScore(
    WorldState world,
    BoardPosition move,
    int playerId,
  ) {
    final adjacentEnemies = _enemyAdjacentCount(world, move, playerId);
    if (adjacentEnemies <= 0) {
      return 0.4;
    }
    if (adjacentEnemies == 1) {
      return 2.0;
    }
    return 3.6;
  }

  int _enemyAdjacentCount(WorldState world, BoardPosition from, int ownerId) {
    var count = 0;
    for (final delta in const [
      BoardPosition(-1, 0),
      BoardPosition(1, 0),
      BoardPosition(0, -1),
      BoardPosition(0, 1),
    ]) {
      final next = from.offset(delta.row, delta.col);
      if (!world.isInside(next)) {
        continue;
      }
      final occupant = world.stackAt(next);
      if (occupant != null && occupant.ownerId != ownerId) {
        count++;
      }
    }
    return count;
  }

  WorldState _simulatedWorldAfterMove({
    required WorldState world,
    required String stackId,
    required BoardPosition to,
    required int playerId,
  }) {
    final moving = world.stackById(stackId);
    if (moving == null) {
      return world;
    }
    final target = world.stackAt(to);
    final moved = moving.copyWith(position: to);

    final stacks = <ArmyStack>[];
    for (final stack in world.stacks) {
      if (stack.id == stackId) {
        continue;
      }
      if (target != null &&
          target.ownerId != playerId &&
          stack.id == target.id) {
        continue;
      }
      stacks.add(stack);
    }
    stacks.add(moved);
    return world.copyWith(stacks: stacks);
  }

  double _counterCapturePenalty(
    WorldState world, {
    required String movingStackId,
    required int playerId,
  }) {
    final movedStack = world.stackById(movingStackId);
    if (movedStack == null) {
      return 0;
    }

    for (final enemy in world.stacks) {
      if (enemy.ownerId == playerId) {
        continue;
      }
      final enemyMoves = world.legalMovesForStack(enemy.id);
      if (!enemyMoves.contains(movedStack.position)) {
        continue;
      }
      var penalty = 7.0;
      final defenseSettlement = world.settlementAt(movedStack.position);
      if (defenseSettlement != null && defenseSettlement.ownerId == playerId) {
        penalty -= 1.2;
      }
      final defenseCamp = world.campAt(movedStack.position);
      if (defenseCamp != null &&
          defenseCamp.ownerId == playerId &&
          defenseCamp.posture == CampPosture.fortified) {
        penalty -= 1.8;
      }
      return penalty.clamp(2.0, 8.0);
    }
    return 0;
  }

  double _recentDestinationPenalty({
    required WorldState world,
    required String stackId,
    required BoardPosition destination,
  }) {
    var hits = 0;
    var scanned = 0;
    final destinationToken = 'to (${destination.row},${destination.col})';
    for (final entry in world.log.reversed) {
      if (!entry.contains(stackId)) {
        continue;
      }
      scanned++;
      if (entry.contains(destinationToken)) {
        hits++;
      }
      if (scanned >= 4) {
        break;
      }
    }
    if (hits <= 0) {
      return 0;
    }
    return hits * 1.8;
  }
}

class BattleAi {
  const BattleAi();

  BattleAction? chooseMove(
    BattleState state,
    int seed, {
    AiDifficulty difficulty = AiDifficulty.normal,
  }) {
    final random = Random(
      seed + state.moveLog.length * 17 + state.activePlayer,
    );
    BattleAction? bestAction;
    var bestScore = double.negativeInfinity;

    for (final piece in state.piecesForPlayer(state.activePlayer)) {
      final legalMoves = state.legalMovesForPiece(piece.id);
      for (final to in legalMoves) {
        final target = state.pieceAt(to);
        var score = random.nextDouble() * difficulty.battleNoiseWeight;
        final beforeMorale = state.moraleForPlayer(piece.ownerId);
        final beforeMoraleState = state.moraleStateForPlayer(piece.ownerId);
        final beforeEnemyMorale = state.moraleForPlayer(state.otherPlayer);
        final beforeThreatenedGenerals = _threatenedGeneralCount(
          state: state,
          playerId: piece.ownerId,
        );
        final beforeEnemyThreatenedGenerals = _threatenedGeneralCount(
          state: state,
          playerId: state.otherPlayer,
        );

        if (target != null && target.ownerId != piece.ownerId) {
          score += _pieceValue(target.type) * difficulty.battleCaptureWeight;
        }

        if (piece.type == PieceType.general && target == null) {
          score -= 1.0 * difficulty.battleIsolationPenaltyWeight;
        }

        final centerBias =
            -((to.row - (state.rows / 2)).abs() +
                (to.col - (state.cols / 2)).abs());
        final centerWeight = switch (difficulty) {
          AiDifficulty.easy => 0.06,
          AiDifficulty.normal => 0.08,
          AiDifficulty.hard => 0.1,
        };
        score += centerBias * centerWeight;
        score -=
            _generalIsolationPenalty(state: state, movingPiece: piece, to: to) *
            difficulty.battleIsolationPenaltyWeight;

        final simulated = state.movePiece(pieceId: piece.id, to: to);
        final afterMorale = simulated.moraleForPlayer(piece.ownerId);
        final afterMoraleState = simulated.moraleStateForPlayer(piece.ownerId);
        final afterEnemyMorale = simulated.moraleForPlayer(state.otherPlayer);
        final ownCommanderAliveAfter = simulated.commanderAlive(piece.ownerId);
        final enemyCommanderAliveAfter = simulated.commanderAlive(
          state.otherPlayer,
        );
        final ownMoraleBrokenAfter = simulated.moraleBroken(piece.ownerId);
        final enemyMoraleBrokenAfter = simulated.moraleBroken(
          state.otherPlayer,
        );
        final afterThreatenedGenerals = _threatenedGeneralCount(
          state: simulated,
          playerId: piece.ownerId,
        );
        final afterEnemyThreatenedGenerals = _threatenedGeneralCount(
          state: simulated,
          playerId: state.otherPlayer,
        );

        score +=
            _moraleStateScore(
              before: beforeMoraleState,
              after: afterMoraleState,
            ) *
            difficulty.battleRoutRiskWeight;
        score +=
            (afterMorale - beforeMorale) *
            4.2 *
            difficulty.battleRoutRiskWeight;
        score +=
            (beforeEnemyMorale - afterEnemyMorale) *
            1.4 *
            difficulty.battleRoutRiskWeight;
        score +=
            (beforeThreatenedGenerals - afterThreatenedGenerals) *
            5.0 *
            difficulty.battleCommandPreservationWeight;
        score +=
            (afterEnemyThreatenedGenerals - beforeEnemyThreatenedGenerals) *
            3.8 *
            difficulty.battleCommandPreservationWeight;

        if (!enemyCommanderAliveAfter) {
          score += 240.0 * difficulty.battleCommandPreservationWeight;
        }
        if (!ownCommanderAliveAfter) {
          score -= 300.0 * difficulty.battleCommandPreservationWeight;
        }
        if (enemyMoraleBrokenAfter) {
          score += 160.0 * difficulty.battleRoutRiskWeight;
        }
        if (ownMoraleBrokenAfter) {
          score -= 220.0 * difficulty.battleRoutRiskWeight;
        }

        if (afterThreatenedGenerals > beforeThreatenedGenerals) {
          score -=
              (afterThreatenedGenerals - beforeThreatenedGenerals) *
              9.5 *
              difficulty.battleCommandPreservationWeight;
        }

        final movedPiece = simulated.pieceById(piece.id);
        if (movedPiece == null) {
          score -=
              (_pieceValue(piece.type) + 1) *
              9.0 *
              difficulty.battleExposurePenaltyWeight;
        } else {
          final enemyAttackers = _attackerCount(
            state: simulated,
            attackerPlayerId: state.otherPlayer,
            target: movedPiece.position,
          );
          final alliedDefenders = _attackerCount(
            state: simulated,
            attackerPlayerId: piece.ownerId,
            target: movedPiece.position,
            excludingPieceId: piece.id,
          );
          final pressure = enemyAttackers - alliedDefenders;
          if (pressure > 0) {
            score -=
                pressure *
                (_pieceValue(piece.type) + 1) *
                2.8 *
                difficulty.battleExposurePenaltyWeight;
          }
          if (enemyAttackers > 0 && alliedDefenders == 0) {
            score -=
                (_pieceValue(piece.type) + 1) *
                3.6 *
                difficulty.battleExposurePenaltyWeight;
          }
          if (piece.type == PieceType.general && enemyAttackers > 0) {
            final lowMoraleMultiplier = afterMorale <= 2 ? 1.35 : 1.0;
            score -=
                8.0 *
                lowMoraleMultiplier *
                difficulty.battleExposurePenaltyWeight;
          }
        }

        if (piece.type != PieceType.general &&
            _adjacentToFriendlyGeneral(
              state: state,
              playerId: piece.ownerId,
              position: piece.position,
              excludingPieceId: piece.id,
            ) &&
            !_adjacentToFriendlyGeneral(
              state: simulated,
              playerId: piece.ownerId,
              position: to,
              excludingPieceId: piece.id,
            )) {
          score -= 4.5 * difficulty.battleCommandPreservationWeight;
        }
        if (target == null) {
          score -=
              _repeatMovePenalty(state: state, movingPiece: piece, to: to) *
              difficulty.battleCommandPreservationWeight;
        }

        if (score > bestScore) {
          bestScore = score;
          bestAction = BattleAction(
            pieceId: piece.id,
            to: to,
            capturedPieceId: target?.id,
          );
        }
      }
    }

    return bestAction;
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

  double _repeatMovePenalty({
    required BattleState state,
    required BattlePiece movingPiece,
    required BoardPosition to,
  }) {
    BattleEvent? latestOwnMove;
    var sampled = 0;
    var repeatedDestinationHits = 0;
    for (final event in state.eventLog.reversed) {
      if (event.type != BattleEventType.move ||
          event.actorPlayerId != movingPiece.ownerId ||
          event.pieceId != movingPiece.id) {
        continue;
      }
      latestOwnMove ??= event;
      sampled++;
      if (event.position == to) {
        repeatedDestinationHits++;
      }
      if (sampled >= 4) {
        break;
      }
    }
    if (latestOwnMove == null) {
      return 0;
    }
    var penalty = repeatedDestinationHits * 1.3;
    if (latestOwnMove.fromPosition != null &&
        to == latestOwnMove.fromPosition) {
      penalty += 5.5;
    }
    return penalty;
  }

  double _generalIsolationPenalty({
    required BattleState state,
    required BattlePiece movingPiece,
    required BoardPosition to,
  }) {
    if (movingPiece.type != PieceType.general) {
      return 0;
    }

    var adjacentAllies = 0;
    var adjacentNonGenerals = 0;
    var adjacentEnemies = 0;

    for (final piece in state.pieces) {
      if (piece.id == movingPiece.id) {
        continue;
      }
      final rowDelta = (piece.position.row - to.row).abs();
      final colDelta = (piece.position.col - to.col).abs();
      if (rowDelta > 1 || colDelta > 1 || (rowDelta == 0 && colDelta == 0)) {
        continue;
      }

      if (piece.ownerId == movingPiece.ownerId) {
        adjacentAllies++;
        if (piece.type != PieceType.general) {
          adjacentNonGenerals++;
        }
      } else {
        adjacentEnemies++;
      }
    }

    final centerRow = (state.rows - 1) / 2;
    final centerCol = (state.cols - 1) / 2;
    final centerDistance =
        (to.row - centerRow).abs() + (to.col - centerCol).abs();
    final nearCenter = centerDistance <= 2.2;

    var penalty = 0.0;
    if (adjacentAllies == 0) {
      penalty += nearCenter ? 12.0 : 4.0;
    }
    if (adjacentNonGenerals == 0) {
      penalty += nearCenter ? 6.0 : 2.0;
    }
    if (adjacentEnemies > adjacentAllies) {
      penalty += 3.5;
    }
    return penalty;
  }

  int _threatenedGeneralCount({
    required BattleState state,
    required int playerId,
  }) {
    final generals = state.generalsForSide(playerId);
    if (generals.isEmpty) {
      return 99;
    }

    final enemyId = playerId == state.southPlayerId
        ? state.northPlayerId
        : state.southPlayerId;
    final threatenedSquares = <BoardPosition>{};
    for (final enemy in state.piecesForPlayer(enemyId)) {
      final moves = state.legalMovesForPiece(
        enemy.id,
        asPlayerId: enemyId,
        ignoreOpeningCaptureBlock: true,
      );
      threatenedSquares.addAll(moves);
    }

    var count = 0;
    for (final general in generals) {
      if (threatenedSquares.contains(general.position)) {
        count++;
      }
    }
    return count;
  }

  bool _adjacentToFriendlyGeneral({
    required BattleState state,
    required int playerId,
    required BoardPosition position,
    required String excludingPieceId,
  }) {
    for (final friendly in state.piecesForPlayer(playerId)) {
      if (friendly.id == excludingPieceId ||
          friendly.type != PieceType.general) {
        continue;
      }
      final rowDelta = (friendly.position.row - position.row).abs();
      final colDelta = (friendly.position.col - position.col).abs();
      if (rowDelta <= 1 && colDelta <= 1 && !(rowDelta == 0 && colDelta == 0)) {
        return true;
      }
    }
    return false;
  }

  int _attackerCount({
    required BattleState state,
    required int attackerPlayerId,
    required BoardPosition target,
    String? excludingPieceId,
  }) {
    var count = 0;
    for (final piece in state.piecesForPlayer(attackerPlayerId)) {
      if (piece.id == excludingPieceId) {
        continue;
      }
      final moves = state.legalMovesForPiece(
        piece.id,
        asPlayerId: attackerPlayerId,
        ignoreOpeningCaptureBlock: true,
      );
      if (moves.contains(target)) {
        count++;
      }
    }
    return count;
  }

  double _moraleStateScore({
    required MoraleState before,
    required MoraleState after,
  }) {
    final beforeValue = _moraleStateValue(before);
    final afterValue = _moraleStateValue(after);
    return (beforeValue - afterValue) * 14.0;
  }

  int _moraleStateValue(MoraleState state) {
    switch (state) {
      case MoraleState.steady:
        return 0;
      case MoraleState.wavering:
        return 1;
      case MoraleState.routing:
        return 2;
      case MoraleState.collapsed:
        return 4;
    }
  }
}
