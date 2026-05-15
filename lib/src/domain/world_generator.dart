import 'dart:math';

import 'army_factory.dart';
import 'board_position.dart';
import 'world.dart';

class WorldGenerator {
  const WorldGenerator({
    this.boardSize = 7,
    this.armyFactory = const ArmyFactory(),
  }) : assert(boardSize >= 3, 'boardSize must be at least 3.');

  final int boardSize;
  final ArmyFactory armyFactory;

  WorldState create({
    required int playerCount,
    required List<PlayerType> playerTypes,
    required MapPreset preset,
    required int seed,
    int? boardSizeOverride,
    int? armiesPerPlayerOverride,
  }) {
    final effectiveBoardSize = (boardSizeOverride ?? boardSize)
        .clamp(3, 10)
        .toInt();
    final maxArmiesByBoard = effectiveBoardSize <= 3 ? 3 : 4;
    final effectiveArmiesPerPlayer = (armiesPerPlayerOverride ?? 3)
        .clamp(2, maxArmiesByBoard)
        .toInt();
    final random = Random(seed);
    final players = List<PlayerSlot>.generate(playerCount, (index) {
      return PlayerSlot(
        id: index,
        type: playerTypes[index],
        name: 'P${index + 1}',
      );
    });

    final spawnTilesByPlayer = _spawnTilesByPlayer(
      playerCount,
      boardSize: effectiveBoardSize,
      armiesPerPlayer: effectiveArmiesPerPlayer,
    );
    final protectedTiles = spawnTilesByPlayer
        .expand((positions) => positions)
        .toSet();

    final blockedStrategic = _blockedStrategicTiles(
      boardSize: effectiveBoardSize,
      seed: seed,
      preset: preset,
      protectedTiles: protectedTiles,
    );
    final riverEdges = _riverEdgesForPreset(
      boardSize: effectiveBoardSize,
      seed: seed,
      preset: preset,
    );

    final tiles = <MapTile>[];
    for (var row = 0; row < effectiveBoardSize; row++) {
      for (var col = 0; col < effectiveBoardSize; col++) {
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
      final armySet = armyFactory.createArmySet(
        playerId: playerId,
        random: random,
        armiesPerPlayer: effectiveArmiesPerPlayer,
      );
      final spawns = spawnTilesByPlayer[playerId];
      for (var i = 0; i < armySet.armies.length; i++) {
        stacks.add(
          ArmyStack(
            id: 'P${playerId + 1}-A${i + 1}',
            ownerId: playerId,
            army: armySet.armies[i],
            position: spawns[i],
            label: 'A${i + 1}',
            entrenchedUntilRound: null,
            forcedMarchRound: null,
            fatigue: 0,
          ),
        );
      }
    }

    final settlements = _generateSettlements(
      boardSize: effectiveBoardSize,
      playerCount: playerCount,
      blockedStrategic: blockedStrategic,
      spawnTilesByPlayer: spawnTilesByPlayer,
    );
    final treasuryByPlayer = <int, int>{
      for (final player in players) player.id: 0,
    };
    final commandPointsByPlayer = <int, int>{
      for (final player in players) player.id: 3,
    };
    final foodByPlayer = <int, int>{for (final player in players) player.id: 8};

    return WorldState(
      size: effectiveBoardSize,
      tiles: tiles,
      riverEdges: riverEdges,
      settlements: settlements,
      camps: const <CampState>[],
      players: players,
      activePlayerIndex: 0,
      round: 1,
      stacks: stacks,
      commandPointMax: 3,
      commandPointsByPlayer: commandPointsByPlayer,
      foodByPlayer: foodByPlayer,
      treasuryByPlayer: treasuryByPlayer,
      preset: preset,
      seed: seed,
      log: [
        'Match started: ${preset.name} on $effectiveBoardSize'
            'x$effectiveBoardSize with $effectiveArmiesPerPlayer armies per side.',
      ],
    );
  }

  List<SettlementState> _generateSettlements({
    required int boardSize,
    required int playerCount,
    required Set<BoardPosition> blockedStrategic,
    required List<List<BoardPosition>> spawnTilesByPlayer,
  }) {
    final settlements = <SettlementState>[];
    final occupied = <BoardPosition>{};

    for (var playerId = 0; playerId < playerCount; playerId++) {
      final capitalPos = spawnTilesByPlayer[playerId].first;
      occupied.add(capitalPos);
      settlements.add(
        SettlementState(
          id: 'capital_p${playerId + 1}',
          name: 'Capital ${playerId + 1}',
          position: capitalPos,
          ownerId: playerId,
          tier: SettlementTier.castle,
          cultureRating: 3,
          taxYield: 3,
          supplyStock: 2,
          garrisonCapacity: 5,
          garrisonedUnits: 0,
          unrest: 0,
          levyCooldown: 0,
          trapType: SettlementTrapType.defensiveDitch,
          trapArmed: false,
        ),
      );

      final villagePos = _firstOpenSettlementTile(
        candidates: spawnTilesByPlayer[playerId].skip(1),
        occupied: occupied,
        blockedStrategic: blockedStrategic,
        boardSize: boardSize,
      );
      if (villagePos != null) {
        occupied.add(villagePos);
        settlements.add(
          SettlementState(
            id: 'village_p${playerId + 1}',
            name: 'Village ${playerId + 1}',
            position: villagePos,
            ownerId: playerId,
            tier: SettlementTier.village,
            cultureRating: 1,
            taxYield: 1,
            supplyStock: 3,
            garrisonCapacity: 2,
            garrisonedUnits: 0,
            unrest: 0,
            levyCooldown: 0,
            trapType: SettlementTrapType.none,
            trapArmed: false,
          ),
        );
      }
    }

    final center = BoardPosition(boardSize ~/ 2, boardSize ~/ 2);
    final townPosition = _firstOpenSettlementTile(
      candidates: [
        center,
        center.offset(-1, 0),
        center.offset(1, 0),
        center.offset(0, -1),
        center.offset(0, 1),
      ],
      occupied: occupied,
      blockedStrategic: blockedStrategic,
      boardSize: boardSize,
    );
    if (townPosition != null) {
      occupied.add(townPosition);
      settlements.add(
        SettlementState(
          id: 'market_central',
          name: 'Central Market',
          position: townPosition,
          ownerId: -1,
          tier: SettlementTier.town,
          cultureRating: 2,
          taxYield: 2,
          supplyStock: 2,
          garrisonCapacity: 3,
          garrisonedUnits: 0,
          unrest: 1,
          levyCooldown: 1,
          trapType: SettlementTrapType.none,
          trapArmed: false,
        ),
      );
    }

    final neutralVillageCandidates = <BoardPosition>[
      BoardPosition(boardSize ~/ 2, (boardSize ~/ 2) - 2),
      BoardPosition(boardSize ~/ 2, (boardSize ~/ 2) + 2),
      BoardPosition((boardSize ~/ 2) - 2, boardSize ~/ 2),
      BoardPosition((boardSize ~/ 2) + 2, boardSize ~/ 2),
    ];
    var neutralVillageIndex = 1;
    for (final candidate in neutralVillageCandidates) {
      if (!candidate.inBounds(boardSize, boardSize)) {
        continue;
      }
      if (blockedStrategic.contains(candidate) ||
          occupied.contains(candidate)) {
        continue;
      }
      settlements.add(
        SettlementState(
          id: 'neutral_village_$neutralVillageIndex',
          name: 'Hamlet $neutralVillageIndex',
          position: candidate,
          ownerId: -1,
          tier: SettlementTier.village,
          cultureRating: 1,
          taxYield: 1,
          supplyStock: 2,
          garrisonCapacity: 2,
          garrisonedUnits: 0,
          unrest: 1,
          levyCooldown: 1,
          trapType: SettlementTrapType.none,
          trapArmed: false,
        ),
      );
      occupied.add(candidate);
      neutralVillageIndex++;
      if (neutralVillageIndex > 2) {
        break;
      }
    }

    return settlements;
  }

  BoardPosition? _firstOpenSettlementTile({
    required Iterable<BoardPosition> candidates,
    required Set<BoardPosition> occupied,
    required Set<BoardPosition> blockedStrategic,
    required int boardSize,
  }) {
    for (final candidate in candidates) {
      if (!candidate.inBounds(boardSize, boardSize)) {
        continue;
      }
      if (blockedStrategic.contains(candidate)) {
        continue;
      }
      if (occupied.contains(candidate)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  List<List<BoardPosition>> _spawnTilesByPlayer(
    int playerCount, {
    required int boardSize,
    required int armiesPerPlayer,
  }) {
    final southRow = boardSize - 1;
    final northRow = 0;
    final westCol = 0;
    final eastCol = boardSize - 1;
    final innerSouthRow = boardSize - 2;
    final innerNorthRow = 1;
    final innerWestCol = 1;
    final innerEastCol = boardSize - 2;

    final layout = <List<BoardPosition>>[
      [
        BoardPosition(southRow, westCol),
        BoardPosition(southRow, innerWestCol),
        BoardPosition(innerSouthRow, westCol),
        BoardPosition(innerSouthRow, innerWestCol),
      ],
      [
        BoardPosition(northRow, eastCol),
        BoardPosition(northRow, innerEastCol),
        BoardPosition(innerNorthRow, eastCol),
        BoardPosition(innerNorthRow, innerEastCol),
      ],
      [
        BoardPosition(northRow, westCol),
        BoardPosition(northRow, innerWestCol),
        BoardPosition(innerNorthRow, westCol),
        BoardPosition(innerNorthRow, innerWestCol),
      ],
      [
        BoardPosition(southRow, eastCol),
        BoardPosition(southRow, innerEastCol),
        BoardPosition(innerSouthRow, eastCol),
        BoardPosition(innerSouthRow, innerEastCol),
      ],
    ];
    return layout
        .take(playerCount)
        .map((positions) => positions.take(armiesPerPlayer).toList())
        .toList();
  }

  Set<BoardPosition> _blockedStrategicTiles({
    required int boardSize,
    required int seed,
    required MapPreset preset,
    required Set<BoardPosition> protectedTiles,
  }) {
    final blocked = <BoardPosition>{};
    final random = Random(seed + preset.index);
    final center = boardSize ~/ 2;

    switch (preset) {
      case MapPreset.greatField:
        for (final pos in [BoardPosition(center, center)]) {
          if (pos.inBounds(boardSize, boardSize) &&
              !protectedTiles.contains(pos)) {
            blocked.add(pos);
          }
        }
      case MapPreset.tightRavine:
        for (final pos in [
          BoardPosition(center - 1, center),
          BoardPosition(center, center - 1),
          BoardPosition(center, center + 1),
          BoardPosition(center + 1, center),
        ]) {
          if (pos.inBounds(boardSize, boardSize) &&
              !protectedTiles.contains(pos)) {
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
      case MapPreset.riverlands:
        break;
      case MapPreset.mountainPass:
        for (var r = 0; r < boardSize; r++) {
          for (var c = 0; c < boardSize; c++) {
            if (r == c || r == c + 1 || r == c - 1) continue;
            if (random.nextDouble() < 0.7 &&
                !protectedTiles.contains(BoardPosition(r, c))) {
              blocked.add(BoardPosition(r, c));
            }
          }
        }
        break;
      case MapPreset.coastalCliffs:
        for (var r = 0; r < boardSize; r++) {
          blocked.add(BoardPosition(r, boardSize - 1));
          if (random.nextBool()) blocked.add(BoardPosition(r, boardSize - 2));
        }
        break;
      case MapPreset.ancientRuins:
        for (var r = 1; r < boardSize - 1; r += 2) {
          for (var c = 1; c < boardSize - 1; c += 2) {
            if (!protectedTiles.contains(BoardPosition(r, c))) {
              blocked.add(BoardPosition(r, c));
            }
          }
        }
        break;
      case MapPreset.desertOasis:
        for (var r = center - 2; r <= center + 2; r++) {
          for (var c = center - 2; c <= center + 2; c++) {
            if ((r == center - 2 ||
                    r == center + 2 ||
                    c == center - 2 ||
                    c == center + 2) &&
                !protectedTiles.contains(BoardPosition(r, c))) {
              blocked.add(BoardPosition(r, c));
            }
          }
        }
        break;
    }

    return blocked;
  }

  List<RiverEdge> _riverEdgesForPreset({
    required int boardSize,
    required int seed,
    required MapPreset preset,
  }) {
    if (boardSize < 4) {
      return const <RiverEdge>[];
    }

    var splitCol = (boardSize ~/ 2) - 1;
    splitCol = splitCol.clamp(0, boardSize - 2);
    final crossingByRow = <int, RiverEdgeType>{
      for (final entry in _crossingRowsForPreset(boardSize, preset).entries)
        entry.key.clamp(0, boardSize - 1): entry.value,
    };
    final edges = <RiverEdge>[];

    for (var row = 0; row < boardSize; row++) {
      edges.add(
        RiverEdge(
          a: BoardPosition(row, splitCol),
          b: BoardPosition(row, splitCol + 1),
          type: crossingByRow[row] ?? RiverEdgeType.river,
        ),
      );

      if (row == boardSize - 1) {
        break;
      }

      final drift = ((seed + row * 17 + preset.index * 11) % 3) - 1;
      final canDriftLeft = splitCol > 0;
      final canDriftRight = splitCol < boardSize - 2;
      if (drift < 0 && canDriftLeft) {
        splitCol--;
      } else if (drift > 0 && canDriftRight) {
        splitCol++;
      }
    }

    return edges;
  }

  Map<int, RiverEdgeType> _crossingRowsForPreset(
    int boardSize,
    MapPreset preset,
  ) {
    final center = boardSize ~/ 2;
    return switch (preset) {
      MapPreset.greatField => <int, RiverEdgeType>{
        center: RiverEdgeType.bridge,
        if (boardSize >= 6) center - 2: RiverEdgeType.ford,
      },
      MapPreset.tightRavine => <int, RiverEdgeType>{
        center: RiverEdgeType.bridge,
      },
      MapPreset.brokenGround => <int, RiverEdgeType>{
        center: RiverEdgeType.ford,
        if (boardSize >= 5) center - 1: RiverEdgeType.bridge,
        if (boardSize >= 7) center + 2: RiverEdgeType.ford,
      },
      MapPreset.riverlands => <int, RiverEdgeType>{
        center: RiverEdgeType.bridge,
        center - 1: RiverEdgeType.ford,
        center + 1: RiverEdgeType.ford,
      },
      MapPreset.ancientRuins => <int, RiverEdgeType>{
        center: RiverEdgeType.bridge,
        if (boardSize >= 6) center - 2: RiverEdgeType.bridge,
      },
      _ => <int, RiverEdgeType>{},
    };
  }

  BattlefieldSpec _battlefieldForTile({
    required BoardPosition tile,
    required MapPreset preset,
    required int seed,
  }) {
    final rows = ((tile.row + seed) % 2 == 0) ? 8 : 6;
    final cols = ((tile.col + seed) % 2 == 0) ? 8 : 6;
    final blocked = <BoardPosition>{};
    final allowBlockedCells = rows * cols > 24;

    if (allowBlockedCells && preset == MapPreset.tightRavine) {
      final midCol = cols ~/ 2;
      for (var row = 1; row < rows - 1; row++) {
        if ((row + tile.row + tile.col) % 2 == 0) {
          blocked.add(BoardPosition(row, midCol));
        }
      }
    }

    if (allowBlockedCells && preset == MapPreset.brokenGround) {
      for (var row = 1; row < rows - 1; row++) {
        for (var col = 1; col < cols - 1; col++) {
          final hash =
              (row * 5 + col * 11 + tile.row * 3 + tile.col + seed) % 23;
          if (hash == 2) {
            blocked.add(BoardPosition(row, col));
          }
        }
      }
    }

    final notation = '${rows}x$cols:${blocked.length}:${preset.name}';
    return BattlefieldSpec(
      rows: rows,
      cols: cols,
      blocked: blocked,
      notation: notation,
    );
  }
}
