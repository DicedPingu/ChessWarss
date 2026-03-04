import 'package:chesswarss/src/domain/ai.dart';
import 'package:chesswarss/src/domain/army.dart';
import 'package:chesswarss/src/domain/battle_state.dart';
import 'package:chesswarss/src/domain/board_position.dart';
import 'package:chesswarss/src/domain/piece.dart';
import 'package:chesswarss/src/domain/world.dart';
import 'package:chesswarss/src/domain/world_generator.dart';
import 'package:flutter_test/flutter_test.dart';

int _threatenedGeneralCount(BattleState state, int playerId) {
  final enemyId = playerId == state.southPlayerId
      ? state.northPlayerId
      : state.southPlayerId;
  final threatenedSquares = <BoardPosition>{};
  for (final enemy in state.piecesForPlayer(enemyId)) {
    threatenedSquares.addAll(
      state.legalMovesForPiece(
        enemy.id,
        asPlayerId: enemyId,
        ignoreOpeningCaptureBlock: true,
      ),
    );
  }
  return state
      .generalsForSide(playerId)
      .where((general) => threatenedSquares.contains(general.position))
      .length;
}

int _attackerCount(
  BattleState state,
  int playerId,
  BoardPosition target, {
  String? excludingPieceId,
}) {
  var count = 0;
  for (final piece in state.piecesForPlayer(playerId)) {
    if (piece.id == excludingPieceId) {
      continue;
    }
    final moves = state.legalMovesForPiece(
      piece.id,
      asPlayerId: playerId,
      ignoreOpeningCaptureBlock: true,
    );
    if (moves.contains(target)) {
      count++;
    }
  }
  return count;
}

void main() {
  group('World generation', () {
    test('creates 7x7 map with 3 stacks per player and passable spawns', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 4,
        playerTypes: const [
          PlayerType.human,
          PlayerType.ai,
          PlayerType.ai,
          PlayerType.ai,
        ],
        preset: MapPreset.tightRavine,
        seed: 42,
      );

      expect(world.size, 7);
      expect(world.stacks.length, 12);

      for (final stack in world.stacks) {
        expect(world.isPassable(stack.position), isTrue);
      }
    });

    test('battlefield notation and dimensions vary by tile', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 7,
      );

      final tileA = world.tileAt(const BoardPosition(0, 0));
      final tileB = world.tileAt(const BoardPosition(0, 1));

      final dimsA = '${tileA.battlefield.rows}x${tileA.battlefield.cols}';
      final dimsB = '${tileB.battlefield.rows}x${tileB.battlefield.cols}';

      expect(['6x6', '6x8', '8x6', '8x8'], contains(dimsA));
      expect(['6x6', '6x8', '8x6', '8x8'], contains(dimsB));
      expect(tileA.battlefield.notation, contains('x'));
    });

    test('generates settlements with economy state and treasury tracks', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 5,
      );

      expect(world.settlements, isNotEmpty);
      expect(world.treasuryByPlayer[0], 0);
      expect(world.treasuryByPlayer[1], 0);

      final capitalForP1 = world.settlements.where(
        (settlement) => settlement.ownerId == 0,
      );
      expect(capitalForP1, isNotEmpty);
      expect(
        world.settlements.every((settlement) => settlement.taxYield > 0),
        isTrue,
      );
    });

    test('supports 4v4 stack option in 1v1 world setup', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 33,
        boardSizeOverride: 6,
        armiesPerPlayerOverride: 4,
      );

      expect(world.stacks.length, 8);
      expect(world.stacks.where((stack) => stack.ownerId == 0).length, 4);
      expect(world.stacks.where((stack) => stack.ownerId == 1).length, 4);
      expect(
        world.stacks.map((stack) => stack.position).toSet().length,
        world.stacks.length,
      );
      for (final stack in world.stacks) {
        expect(world.isPassable(stack.position), isTrue);
      }
    });

    test('supports compact 4x4 world size', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 73,
        boardSizeOverride: 4,
      );

      expect(world.size, 4);
      expect(world.stacks.length, 6);
      for (final stack in world.stacks) {
        expect(world.isPassable(stack.position), isTrue);
      }
    });

    test('supports 3x3 arena size for 1v1 with up to 3 armies', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 71,
        boardSizeOverride: 3,
        armiesPerPlayerOverride: 3,
      );

      expect(world.size, 3);
      expect(world.stacks.length, 6);
      expect(
        world.stacks.map((stack) => stack.position).toSet().length,
        world.stacks.length,
      );
      for (final stack in world.stacks) {
        expect(world.isPassable(stack.position), isTrue);
      }
    });
  });

  group('AI move validity', () {
    test('strategic AI returns legal move for active player', () {
      const generator = WorldGenerator();
      const ai = StrategicAi();

      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.ai, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 99,
      );

      for (final difficulty in AiDifficulty.values) {
        final move = ai.chooseMove(
          world,
          world.activePlayerId,
          world.seed,
          difficulty: difficulty,
        );
        expect(move, isNotNull);

        final legal = world.legalMovesForStack(move!.stackId);
        expect(legal.contains(move.to), isTrue);
      }
    });

    test('battle AI returns legal action from generated battle', () {
      const generator = WorldGenerator();
      const battleAi = BattleAi();

      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.ai, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 120,
      );

      final attacker = world.stacks.firstWhere((stack) => stack.ownerId == 0);
      final defender = world.stacks.firstWhere((stack) => stack.ownerId == 1);
      final tile = world.tileAt(defender.position);

      final battleState = BattleState.fromArmies(
        southArmy: attacker.army,
        northArmy: defender.army,
        southOwnerId: attacker.ownerId,
        northOwnerId: defender.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
      );

      for (final difficulty in AiDifficulty.values) {
        final action = battleAi.chooseMove(
          battleState,
          world.seed,
          difficulty: difficulty,
        );
        expect(action, isNotNull);

        final legalMoves = battleState.legalMovesForPiece(action!.pieceId);
        expect(legalMoves.contains(action.to), isTrue);
      }
    });

    test(
      'different unlocked formations produce different starting layouts',
      () {
        const generator = WorldGenerator();

        final world = generator.create(
          playerCount: 2,
          playerTypes: const [PlayerType.ai, PlayerType.ai],
          preset: MapPreset.greatField,
          seed: 120,
        );

        final attacker = world.stacks.firstWhere((stack) => stack.ownerId == 0);
        final defender = world.stacks.firstWhere((stack) => stack.ownerId == 1);
        final tile = world.tileAt(defender.position);

        final plans = BattleState.generateDeploymentPlans(
          southArmy: attacker.army,
          northArmy: defender.army,
          southOwnerId: attacker.ownerId,
          northOwnerId: defender.ownerId,
          rows: tile.battlefield.rows,
          cols: tile.battlefield.cols,
          blockedCells: tile.battlefield.blocked,
        );
        expect(plans, isNotEmpty);

        final byFormation = <BattleFormation, BattleDeploymentPlan>{};
        for (final plan in plans) {
          byFormation.putIfAbsent(plan.formation, () => plan);
        }

        if (byFormation.length < 2) {
          expect(byFormation, isNotEmpty);
          return;
        }

        final first = byFormation.values.elementAt(0);
        final second = byFormation.values.elementAt(1);
        final firstLayout = first.pieces
            .where((piece) => piece.ownerId == attacker.ownerId)
            .map(
              (piece) =>
                  '${piece.type}:${piece.position.row},${piece.position.col}',
            )
            .toSet();
        final secondLayout = second.pieces
            .where((piece) => piece.ownerId == attacker.ownerId)
            .map(
              (piece) =>
                  '${piece.type}:${piece.position.row},${piece.position.col}',
            )
            .toSet();

        expect(secondLayout, isNot(equals(firstLayout)));
      },
    );

    test('non-active side legal move checks are valid', () {
      const generator = WorldGenerator();

      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.ai, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 120,
      );

      final attacker = world.stacks.firstWhere((stack) => stack.ownerId == 0);
      final defender = world.stacks.firstWhere((stack) => stack.ownerId == 1);
      final tile = world.tileAt(defender.position);

      final battleState = BattleState.fromArmies(
        southArmy: attacker.army,
        northArmy: defender.army,
        southOwnerId: attacker.ownerId,
        northOwnerId: defender.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
      );

      expect(battleState.hasAnyLegalMove(defender.ownerId), isTrue);
    });

    test('battle AI avoids isolated center general moves', () {
      const battleAi = BattleAi();
      final battleState = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: const [
          BattlePiece(
            id: 'g0',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(7, 3),
            generalSkill: GeneralSkill.fieldCommander,
          ),
          BattlePiece(
            id: 'p0',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(7, 2),
          ),
          BattlePiece(
            id: 'e0',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(0, 0),
          ),
        ],
        blockedCells: {const BoardPosition(6, 2), const BoardPosition(7, 1)},
        moveLog: const [],
      );

      final action = battleAi.chooseMove(battleState, 11);
      expect(action, isNotNull);
      expect(action!.pieceId, 'g0');

      final destination = action.to;
      final hasAdjacentAlly = battleState.pieces.any((piece) {
        if (piece.ownerId != 0 || piece.id == 'g0') {
          return false;
        }
        final rowDelta = (piece.position.row - destination.row).abs();
        final colDelta = (piece.position.col - destination.col).abs();
        return rowDelta <= 1 &&
            colDelta <= 1 &&
            !(rowDelta == 0 && colDelta == 0);
      });
      expect(hasAdjacentAlly, isTrue);
    });

    test('battle AI avoids exposing command lane when safer move exists', () {
      const battleAi = BattleAi();
      final battleState = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: const [
          BattlePiece(
            id: 'g0',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(7, 3),
            generalSkill: GeneralSkill.fieldCommander,
          ),
          BattlePiece(
            id: 'b0',
            ownerId: 0,
            type: PieceType.bishop,
            position: BoardPosition(6, 3),
          ),
          BattlePiece(
            id: 'p0',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 0),
          ),
          BattlePiece(
            id: 'er0',
            ownerId: 1,
            type: PieceType.rook,
            position: BoardPosition(3, 3),
          ),
          BattlePiece(
            id: 'ep0',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(5, 4),
          ),
        ],
        moveLog: const [],
      );

      final beforeThreatened = _threatenedGeneralCount(battleState, 0);
      final hasRiskyAction = battleState.legalActionsForActivePlayer().any((
        action,
      ) {
        final simulated = battleState.movePiece(
          pieceId: action.pieceId,
          to: action.to,
        );
        return _threatenedGeneralCount(simulated, 0) > beforeThreatened;
      });
      expect(hasRiskyAction, isTrue);

      final action = battleAi.chooseMove(
        battleState,
        13,
        difficulty: AiDifficulty.hard,
      );
      expect(action, isNotNull);

      final after = battleState.movePiece(
        pieceId: action!.pieceId,
        to: action.to,
      );
      expect(
        _threatenedGeneralCount(after, 0),
        lessThanOrEqualTo(beforeThreatened),
      );
    });

    test('battle AI avoids rout collapse when stable option exists', () {
      const battleAi = BattleAi();
      final battleState = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: const [
          BattlePiece(
            id: 'g0',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(7, 3),
            generalSkill: GeneralSkill.fragileMarshal,
          ),
          BattlePiece(
            id: 'b0',
            ownerId: 0,
            type: PieceType.bishop,
            position: BoardPosition(6, 3),
          ),
          BattlePiece(
            id: 'p0',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 0),
          ),
          BattlePiece(
            id: 'er0',
            ownerId: 1,
            type: PieceType.rook,
            position: BoardPosition(3, 3),
          ),
          BattlePiece(
            id: 'ep0',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(5, 4),
          ),
        ],
        moveLog: const [],
        moraleByPlayer: const {0: 2, 1: 6},
      );

      final hasCollapsingAction = battleState.legalActionsForActivePlayer().any(
        (action) {
          final simulated = battleState.movePiece(
            pieceId: action.pieceId,
            to: action.to,
          );
          return simulated.moraleStateForPlayer(0) == MoraleState.collapsed;
        },
      );
      expect(hasCollapsingAction, isTrue);

      final action = battleAi.chooseMove(
        battleState,
        29,
        difficulty: AiDifficulty.hard,
      );
      expect(action, isNotNull);

      final after = battleState.movePiece(
        pieceId: action!.pieceId,
        to: action.to,
      );
      expect(after.moraleStateForPlayer(0), isNot(MoraleState.collapsed));
    });

    test(
      'battle AI avoids hanging high-value capture when safer move exists',
      () {
        const battleAi = BattleAi();
        final battleState = BattleState(
          rows: 8,
          cols: 8,
          activePlayer: 0,
          pieces: const [
            BattlePiece(
              id: 'g0',
              ownerId: 0,
              type: PieceType.general,
              position: BoardPosition(7, 0),
              generalSkill: GeneralSkill.fieldCommander,
            ),
            BattlePiece(
              id: 'r0',
              ownerId: 0,
              type: PieceType.rook,
              position: BoardPosition(6, 4),
            ),
            BattlePiece(
              id: 'eg0',
              ownerId: 1,
              type: PieceType.general,
              position: BoardPosition(0, 7),
              generalSkill: GeneralSkill.fieldCommander,
            ),
            BattlePiece(
              id: 'eb0',
              ownerId: 1,
              type: PieceType.bishop,
              position: BoardPosition(2, 2),
            ),
            BattlePiece(
              id: 'ep0',
              ownerId: 1,
              type: PieceType.pawn,
              position: BoardPosition(6, 6),
            ),
          ],
          blockedCells: {
            BoardPosition(6, 0),
            BoardPosition(6, 1),
            BoardPosition(7, 1),
          },
          moveLog: const [],
        );

        final captureAction = battleState
            .legalActionsForActivePlayer()
            .firstWhere(
              (action) =>
                  action.pieceId == 'r0' &&
                  action.to == const BoardPosition(6, 6),
            );
        final afterCapture = battleState.movePiece(
          pieceId: captureAction.pieceId,
          to: captureAction.to,
        );
        final enemyAttackers = _attackerCount(
          afterCapture,
          1,
          const BoardPosition(6, 6),
        );
        final alliedDefenders = _attackerCount(
          afterCapture,
          0,
          const BoardPosition(6, 6),
          excludingPieceId: 'r0',
        );
        expect(enemyAttackers, greaterThan(alliedDefenders));

        final action = battleAi.chooseMove(
          battleState,
          37,
          difficulty: AiDifficulty.hard,
        );
        expect(action, isNotNull);
        expect(action!.to, isNot(const BoardPosition(6, 6)));
      },
    );
  });

  group('Doctrine availability', () {
    test('fragile command cannot unlock spearhead doctrine', () {
      const fragileArmy = ArmyDefinition(
        id: 'fragile_line',
        label: 'Fragile Line',
        units: [
          ArmyUnit(type: PieceType.rook),
          ArmyUnit(type: PieceType.rook),
          ArmyUnit(type: PieceType.knight),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(
            type: PieceType.general,
            generalSkill: GeneralSkill.fragileMarshal,
          ),
        ],
      );

      final plans = BattleState.generateDeploymentPlans(
        southArmy: fragileArmy,
        northArmy: fragileArmy,
        southOwnerId: 0,
        northOwnerId: 1,
        rows: 8,
        cols: 8,
      );

      expect(
        plans.any((plan) => plan.formation == BattleFormation.spearhead),
        isFalse,
      );
      expect(
        plans.any((plan) => plan.formation == BattleFormation.flankGuard),
        isTrue,
      );
    });

    test('veteran command with shock units unlocks spearhead doctrine', () {
      const veteranShockArmy = ArmyDefinition(
        id: 'veteran_shock',
        label: 'Veteran Shock',
        units: [
          ArmyUnit(type: PieceType.knight),
          ArmyUnit(type: PieceType.knight),
          ArmyUnit(type: PieceType.bishop),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(
            type: PieceType.general,
            generalSkill: GeneralSkill.veteranCommander,
          ),
        ],
      );

      final plans = BattleState.generateDeploymentPlans(
        southArmy: veteranShockArmy,
        northArmy: veteranShockArmy,
        southOwnerId: 0,
        northOwnerId: 1,
        rows: 8,
        cols: 8,
      );

      expect(
        plans.any((plan) => plan.formation == BattleFormation.spearhead),
        isTrue,
      );
    });

    test('peasant wall doctrine allows pawn double-stack depth', () {
      const peasantHost = ArmyDefinition(
        id: 'peasant_host',
        label: 'Peasant Host',
        units: [
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.rook),
          ArmyUnit(type: PieceType.knight),
          ArmyUnit(
            type: PieceType.general,
            generalSkill: GeneralSkill.fieldCommander,
          ),
        ],
      );

      final sidePlans = BattleState.generateSideDeploymentPlans(
        army: peasantHost,
        ownerId: 0,
        sideIsNorth: false,
        rows: 6,
        cols: 6,
      );

      final stackedPlan = sidePlans.firstWhere(
        (plan) => plan.label.contains('Peasant Wall'),
      );

      final pawnPositions = stackedPlan.pieces
          .where((piece) => piece.type == PieceType.pawn)
          .map((piece) => piece.position)
          .toList();

      expect(pawnPositions.any((pos) => pos.row == 4), isTrue);
      expect(pawnPositions.any((pos) => pos.row == 3), isTrue);

      final byColumn = <int, int>{};
      for (final pos in pawnPositions) {
        byColumn[pos.col] = (byColumn[pos.col] ?? 0) + 1;
      }
      expect(byColumn.values.any((count) => count >= 2), isTrue);
    });

    test('generated side formations keep generals escorted', () {
      const escortArmy = ArmyDefinition(
        id: 'escort_test',
        label: 'Escort Test',
        units: [
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.pawn),
          ArmyUnit(type: PieceType.rook),
          ArmyUnit(type: PieceType.knight),
          ArmyUnit(
            type: PieceType.general,
            generalSkill: GeneralSkill.fieldCommander,
          ),
        ],
      );

      final plans = BattleState.generateSideDeploymentPlans(
        army: escortArmy,
        ownerId: 0,
        sideIsNorth: false,
        rows: 8,
        cols: 8,
      );
      expect(plans, isNotEmpty);

      for (final plan in plans) {
        final general = plan.pieces.firstWhere(
          (piece) => piece.type == PieceType.general,
        );
        final supports = plan.pieces.where((piece) {
          if (piece.ownerId != general.ownerId ||
              piece.type == PieceType.general) {
            return false;
          }
          final rowDelta = (piece.position.row - general.position.row).abs();
          final colDelta = (piece.position.col - general.position.col).abs();
          return rowDelta <= 1 &&
              colDelta <= 1 &&
              !(rowDelta == 0 && colDelta == 0);
        }).toList();

        expect(
          supports,
          isNotEmpty,
          reason: '${plan.id} left the general without close support.',
        );
        final centerColumns = {(8 - 1) ~/ 2, 8 ~/ 2};
        if (centerColumns.contains(general.position.col)) {
          expect(
            supports.length,
            greaterThanOrEqualTo(2),
            reason:
                '${plan.id} placed the general on center file without full escort.',
          );
        }
      }
    });
  });

  group('Battle deployment regression', () {
    test('battle deployment does not overlap units on compact board', () {
      const generator = WorldGenerator();

      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.ai, PlayerType.human],
        preset: MapPreset.greatField,
        seed: 1,
      );

      final attacker = world.stacks.firstWhere((stack) => stack.ownerId == 0);
      final defender = world.stacks.firstWhere((stack) => stack.ownerId == 1);
      final tile = world.tileAt(defender.position);
      expect(tile.battlefield.rows, 6);
      expect(tile.battlefield.cols, 6);

      final battleState = BattleState.fromArmies(
        southArmy: attacker.army,
        northArmy: defender.army,
        southOwnerId: attacker.ownerId,
        northOwnerId: defender.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
      );

      final occupied = <BoardPosition>{};
      for (final piece in battleState.pieces) {
        expect(occupied.add(piece.position), isTrue);
      }
    });

    test('opening position has no immediate capture moves', () {
      const generator = WorldGenerator();
      for (final preset in MapPreset.values) {
        for (var seed = 1; seed <= 40; seed++) {
          final world = generator.create(
            playerCount: 2,
            playerTypes: const [PlayerType.ai, PlayerType.human],
            preset: preset,
            seed: seed,
          );

          final attacker = world.stacks.firstWhere(
            (stack) => stack.ownerId == 0,
          );
          final defender = world.stacks.firstWhere(
            (stack) => stack.ownerId == 1,
          );
          final tile = world.tileAt(defender.position);

          final battleState = BattleState.fromArmies(
            southArmy: attacker.army,
            northArmy: defender.army,
            southOwnerId: attacker.ownerId,
            northOwnerId: defender.ownerId,
            rows: tile.battlefield.rows,
            cols: tile.battlefield.cols,
            blockedCells: tile.battlefield.blocked,
          );

          final hasOpeningCapture = battleState
              .legalActionsForActivePlayer()
              .any((action) => action.capturedPieceId != null);
          expect(hasOpeningCapture, isFalse);
        }
      }
    });
  });

  group('World movement extensions', () {
    test(
      'two-step legal moves are available when forced march range is used',
      () {
        final tiles = <MapTile>[
          for (var row = 0; row < 5; row++)
            for (var col = 0; col < 5; col++)
              MapTile(
                position: BoardPosition(row, col),
                terrain: TerrainType.passable,
                battlefield: const BattlefieldSpec(
                  rows: 6,
                  cols: 6,
                  blocked: <BoardPosition>{},
                  notation: '6x6:0:test',
                ),
              ),
        ];
        const scoutArmy = ArmyDefinition(
          id: 'scout',
          label: 'Scout',
          units: [
            ArmyUnit(
              type: PieceType.general,
              generalSkill: GeneralSkill.fieldCommander,
            ),
          ],
        );
        final world = WorldState(
          size: 5,
          tiles: tiles,
          players: const [
            PlayerSlot(id: 0, type: PlayerType.human, name: 'P1'),
          ],
          activePlayerIndex: 0,
          round: 1,
          stacks: const [
            ArmyStack(
              id: 'P1-A1',
              ownerId: 0,
              army: scoutArmy,
              position: BoardPosition(2, 2),
              label: 'A1',
            ),
          ],
          preset: MapPreset.greatField,
          seed: 1,
          log: const [],
        );

        final oneStep = world.legalMovesForStack('P1-A1');
        final twoStep = world.legalMovesForStack('P1-A1', maxSteps: 2);

        expect(oneStep, contains(const BoardPosition(1, 2)));
        expect(twoStep, contains(const BoardPosition(0, 2)));
        expect(twoStep, contains(const BoardPosition(2, 0)));
        expect(twoStep, contains(const BoardPosition(4, 2)));
        expect(twoStep, contains(const BoardPosition(2, 4)));
      },
    );

    test(
      'army stack copyWith can explicitly clear temporary campaign flags',
      () {
        const stack = ArmyStack(
          id: 'P1-A1',
          ownerId: 0,
          army: ArmyDefinition(
            id: 'army',
            label: 'Army',
            units: [
              ArmyUnit(
                type: PieceType.general,
                generalSkill: GeneralSkill.fieldCommander,
              ),
            ],
          ),
          position: BoardPosition(3, 3),
          label: 'A1',
          entrenchedUntilRound: 5,
          forcedMarchRound: 4,
          fatigue: 2,
        );

        final cleared = stack.copyWith(
          entrenchedUntilRound: null,
          forcedMarchRound: null,
        );

        expect(cleared.entrenchedUntilRound, isNull);
        expect(cleared.forcedMarchRound, isNull);
        expect(cleared.fatigue, 2);
      },
    );
  });

  group('Camp and settlement identity', () {
    test('world generation includes village, town, and castle tiers', () {
      const generator = WorldGenerator();
      final world = generator.create(
        playerCount: 2,
        playerTypes: const [PlayerType.human, PlayerType.ai],
        preset: MapPreset.greatField,
        seed: 88,
      );

      expect(
        world.settlements.any(
          (settlement) => settlement.tier == SettlementTier.village,
        ),
        isTrue,
      );
      expect(
        world.settlements.any(
          (settlement) => settlement.tier == SettlementTier.town,
        ),
        isTrue,
      );
      expect(
        world.settlements.any(
          (settlement) => settlement.tier == SettlementTier.castle,
        ),
        isTrue,
      );
    });

    test('world exposes camp lookup helpers', () {
      final tiles = <MapTile>[
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 3; col++)
            MapTile(
              position: BoardPosition(row, col),
              terrain: TerrainType.passable,
              battlefield: const BattlefieldSpec(
                rows: 6,
                cols: 6,
                blocked: <BoardPosition>{},
                notation: '6x6:0:test',
              ),
            ),
      ];
      final world = WorldState(
        size: 3,
        tiles: tiles,
        camps: const [
          CampState(
            id: 'camp_p1',
            ownerId: 0,
            position: BoardPosition(1, 1),
            createdRound: 1,
            expiresRound: 3,
            posture: CampPosture.fortified,
            supplyStock: 2,
            fatigueRecovery: 1,
            trapPrepared: true,
          ),
        ],
        players: const [
          PlayerSlot(id: 0, type: PlayerType.human, name: 'P1'),
          PlayerSlot(id: 1, type: PlayerType.ai, name: 'P2'),
        ],
        activePlayerIndex: 0,
        round: 2,
        stacks: const [],
        preset: MapPreset.greatField,
        seed: 5,
        log: const [],
      );

      expect(world.campAt(const BoardPosition(1, 1))?.id, 'camp_p1');
      expect(world.campsForPlayer(0).length, 1);
      expect(world.campsForPlayer(1), isEmpty);
    });

    test('camp state supports outpost flag and copyWith upgrades', () {
      const camp = CampState(
        id: 'camp_p1',
        ownerId: 0,
        position: BoardPosition(2, 2),
        createdRound: 1,
        expiresRound: 3,
        posture: CampPosture.fortified,
        supplyStock: 2,
        fatigueRecovery: 1,
        trapPrepared: true,
      );

      expect(camp.isOutpost, isFalse);

      final upgraded = camp.copyWith(
        isOutpost: true,
        expiresRound: 8,
        supplyStock: 3,
      );

      expect(upgraded.isOutpost, isTrue);
      expect(upgraded.expiresRound, 8);
      expect(upgraded.supplyStock, 3);
    });

    test(
      'strategic AI can select a stack to establish camp under pressure',
      () {
        const ai = StrategicAi();
        const scoutArmy = ArmyDefinition(
          id: 'scout',
          label: 'Scout',
          units: [
            ArmyUnit(
              type: PieceType.general,
              generalSkill: GeneralSkill.fieldCommander,
            ),
          ],
        );
        final tiles = <MapTile>[
          for (var row = 0; row < 5; row++)
            for (var col = 0; col < 5; col++)
              MapTile(
                position: BoardPosition(row, col),
                terrain: TerrainType.passable,
                battlefield: const BattlefieldSpec(
                  rows: 6,
                  cols: 6,
                  blocked: <BoardPosition>{},
                  notation: '6x6:0:test',
                ),
              ),
        ];

        final world = WorldState(
          size: 5,
          tiles: tiles,
          players: const [
            PlayerSlot(id: 0, type: PlayerType.ai, name: 'P1'),
            PlayerSlot(id: 1, type: PlayerType.ai, name: 'P2'),
          ],
          activePlayerIndex: 0,
          round: 2,
          stacks: const [
            ArmyStack(
              id: 'P1-A1',
              ownerId: 0,
              army: scoutArmy,
              position: BoardPosition(2, 2),
              label: 'A1',
            ),
            ArmyStack(
              id: 'P2-A1',
              ownerId: 1,
              army: scoutArmy,
              position: BoardPosition(2, 4),
              label: 'A1',
            ),
          ],
          commandPointMax: 3,
          commandPointsByPlayer: {0: 3, 1: 3},
          foodByPlayer: {0: 1, 1: 6},
          treasuryByPlayer: {0: 0, 1: 0},
          preset: MapPreset.greatField,
          seed: 9,
          log: const [],
        );

        final stackId = ai.chooseCampStack(world, 0, 99);
        expect(stackId, 'P1-A1');
      },
    );
  });
}
