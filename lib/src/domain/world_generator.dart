import 'dart:math';

import 'army_factory.dart';
import 'board_position.dart';
import 'world.dart';

class WorldGenerator {
  const WorldGenerator({
    this.boardSize = 5,
    this.armyFactory = const ArmyFactory(),
  });

  final int boardSize;
  final ArmyFactory armyFactory;

  WorldState create({
    required int playerCount,
    required List<PlayerType> playerTypes,
    required MapPreset preset,
    required int seed,
  }) {
    final random = Random(seed);
    final players = List<PlayerSlot>.generate(playerCount, (index) {
      return PlayerSlot(
        id: index,
        type: playerTypes[index],
        name: 'P${index + 1}',
      );
    });

    final protectedTiles = _spawnTilesByPlayer(playerCount)
        .expand((positions) => positions)
        .toSet();

    final blockedStrategic = _blockedStrategicTiles(
      boardSize: boardSize,
      seed: seed,
      preset: preset,
      protectedTiles: protectedTiles,
    );

    final tiles = <MapTile>[];
    for (var row = 0; row < boardSize; row++) {
      for (var col = 0; col < boardSize; col++) {
        final position = BoardPosition(row, col);
        final terrain = blockedStrategic.contains(position)
            ? TerrainType.blocked
            : TerrainType.passable;
        tiles.add(
          MapTile(
            position: position,
            terrain: terrain,
            battlefield: _battlefieldForTile(
              tile: position,
              preset: preset,
              seed: seed,
            ),
          ),
        );
      }
    }

    final stacks = <ArmyStack>[];
    for (var playerId = 0; playerId < playerCount; playerId++) {
      final armySet = armyFactory.createArmySet(playerId: playerId, random: random);
      final spawns = _spawnTilesByPlayer(playerCount)[playerId];
      for (var i = 0; i < armySet.armies.length; i++) {
        stacks.add(
          ArmyStack(
            id: 'P${playerId + 1}-A${i + 1}',
            ownerId: playerId,
            army: armySet.armies[i],
            position: spawns[i],
            label: 'A${i + 1}',
          ),
        );
      }
    }

    return WorldState(
      size: boardSize,
      tiles: tiles,
      players: players,
      activePlayerIndex: 0,
      round: 1,
      stacks: stacks,
      preset: preset,
      seed: seed,
      log: [
        'Match started: ${preset.name} on ${boardSize}x$boardSize.',
      ],
    );
  }

  List<List<BoardPosition>> _spawnTilesByPlayer(int playerCount) {
    final layout = <List<BoardPosition>>[
      const [BoardPosition(4, 0), BoardPosition(4, 1), BoardPosition(3, 0)],
      const [BoardPosition(0, 4), BoardPosition(0, 3), BoardPosition(1, 4)],
      const [BoardPosition(0, 0), BoardPosition(0, 1), BoardPosition(1, 0)],
      const [BoardPosition(4, 4), BoardPosition(4, 3), BoardPosition(3, 4)],
    ];
    return layout.take(playerCount).toList();
  }

  Set<BoardPosition> _blockedStrategicTiles({
    required int boardSize,
    required int seed,
    required MapPreset preset,
    required Set<BoardPosition> protectedTiles,
  }) {
    final blocked = <BoardPosition>{};

    switch (preset) {
      case MapPreset.greatField:
        for (final pos in const [BoardPosition(2, 2)]) {
          if (!protectedTiles.contains(pos)) {
            blocked.add(pos);
          }
        }
      case MapPreset.tightRavine:
        for (final pos in const [
          BoardPosition(1, 2),
          BoardPosition(2, 1),
          BoardPosition(2, 3),
          BoardPosition(3, 2),
        ]) {
          if (!protectedTiles.contains(pos)) {
            blocked.add(pos);
          }
        }
      case MapPreset.brokenGround:
        for (var row = 0; row < boardSize; row++) {
          for (var col = 0; col < boardSize; col++) {
            final pos = BoardPosition(row, col);
            if (protectedTiles.contains(pos)) {
              continue;
            }
            final hash = (row * 13 + col * 7 + seed) % 17;
            if (hash == 0 || hash == 6) {
              blocked.add(pos);
            }
          }
        }
    }

    return blocked;
  }

  BattlefieldSpec _battlefieldForTile({
    required BoardPosition tile,
    required MapPreset preset,
    required int seed,
  }) {
    final rows = ((tile.row + seed) % 2 == 0) ? 8 : 4;
    final cols = ((tile.col + seed) % 2 == 0) ? 8 : 4;
    final blocked = <BoardPosition>{};

    if (preset == MapPreset.tightRavine) {
      final midCol = cols ~/ 2;
      for (var row = 1; row < rows - 1; row++) {
        if ((row + tile.row + tile.col) % 2 == 0) {
          blocked.add(BoardPosition(row, midCol));
        }
      }
    }

    if (preset == MapPreset.brokenGround) {
      for (var row = 1; row < rows - 1; row++) {
        for (var col = 1; col < cols - 1; col++) {
          final hash = (row * 5 + col * 11 + tile.row * 3 + tile.col + seed) % 23;
          if (hash == 2) {
            blocked.add(BoardPosition(row, col));
          }
        }
      }
    }

    final notation = '${rows}x$cols:${blocked.length}:${preset.name}';
    return BattlefieldSpec(rows: rows, cols: cols, blocked: blocked, notation: notation);
  }
}
