import 'package:chesswarss/src/domain/ai.dart';
import 'package:chesswarss/src/domain/battle_state.dart';
import 'package:chesswarss/src/domain/board_position.dart';
import 'package:chesswarss/src/domain/world.dart';
import 'package:chesswarss/src/domain/world_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('World generation', () {
    test('creates 5x5 map with 3 stacks per player and passable spawns', () {
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

      expect(world.size, 5);
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

      final move = ai.chooseMove(world, world.activePlayerId, world.seed);
      expect(move, isNotNull);

      final legal = world.legalMovesForStack(move!.stackId);
      expect(legal.contains(move.to), isTrue);
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

      final action = battleAi.chooseMove(battleState, world.seed);
      expect(action, isNotNull);

      final legalMoves = battleState.legalMovesForPiece(action!.pieceId);
      expect(legalMoves.contains(action.to), isTrue);
    });

    test('battle formations produce different starting layouts', () {
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

      final balanced = BattleState.fromArmies(
        southArmy: attacker.army,
        northArmy: defender.army,
        southOwnerId: attacker.ownerId,
        northOwnerId: defender.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
        formation: BattleFormation.balanced,
      );

      final spearhead = BattleState.fromArmies(
        southArmy: attacker.army,
        northArmy: defender.army,
        southOwnerId: attacker.ownerId,
        northOwnerId: defender.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
        formation: BattleFormation.spearhead,
      );

      final balancedLayout = balanced
          .piecesForPlayer(attacker.ownerId)
          .map(
            (piece) =>
                '${piece.type}:${piece.position.row},${piece.position.col}',
          )
          .toSet();
      final spearheadLayout = spearhead
          .piecesForPlayer(attacker.ownerId)
          .map(
            (piece) =>
                '${piece.type}:${piece.position.row},${piece.position.col}',
          )
          .toSet();

      expect(spearheadLayout, isNot(equals(balancedLayout)));
    });

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
}
