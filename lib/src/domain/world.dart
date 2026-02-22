import 'army.dart';
import 'board_position.dart';

enum PlayerType { human, ai }

enum TerrainType { passable, blocked }

enum MapPreset { greatField, tightRavine, brokenGround }

class PlayerSlot {
  const PlayerSlot({required this.id, required this.type, required this.name});

  final int id;
  final PlayerType type;
  final String name;

  PlayerSlot copyWith({int? id, PlayerType? type, String? name}) {
    return PlayerSlot(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
    );
  }
}

class BattlefieldSpec {
  const BattlefieldSpec({
    required this.rows,
    required this.cols,
    required this.blocked,
    required this.notation,
  });

  final int rows;
  final int cols;
  final Set<BoardPosition> blocked;
  final String notation;
}

class MapTile {
  const MapTile({
    required this.position,
    required this.terrain,
    required this.battlefield,
  });

  final BoardPosition position;
  final TerrainType terrain;
  final BattlefieldSpec battlefield;
}

class ArmyStack {
  const ArmyStack({
    required this.id,
    required this.ownerId,
    required this.army,
    required this.position,
    required this.label,
  });

  final String id;
  final int ownerId;
  final ArmyDefinition army;
  final BoardPosition position;
  final String label;

  ArmyStack copyWith({
    String? id,
    int? ownerId,
    ArmyDefinition? army,
    BoardPosition? position,
    String? label,
  }) {
    return ArmyStack(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      army: army ?? this.army,
      position: position ?? this.position,
      label: label ?? this.label,
    );
  }
}

class WorldState {
  const WorldState({
    required this.size,
    required this.tiles,
    required this.players,
    required this.activePlayerIndex,
    required this.round,
    required this.stacks,
    required this.preset,
    required this.seed,
    required this.log,
  });

  final int size;
  final List<MapTile> tiles;
  final List<PlayerSlot> players;
  final int activePlayerIndex;
  final int round;
  final List<ArmyStack> stacks;
  final MapPreset preset;
  final int seed;
  final List<String> log;

  int get activePlayerId => players[activePlayerIndex].id;

  MapTile tileAt(BoardPosition position) {
    return tiles.firstWhere((tile) => tile.position == position);
  }

  ArmyStack? stackAt(BoardPosition position) {
    for (final stack in stacks) {
      if (stack.position == position) {
        return stack;
      }
    }
    return null;
  }

  ArmyStack? stackById(String stackId) {
    for (final stack in stacks) {
      if (stack.id == stackId) {
        return stack;
      }
    }
    return null;
  }

  List<ArmyStack> stacksForPlayer(int playerId) {
    return stacks.where((stack) => stack.ownerId == playerId).toList();
  }

  bool isInside(BoardPosition position) {
    return position.inBounds(size, size);
  }

  bool isPassable(BoardPosition position) {
    return tileAt(position).terrain == TerrainType.passable;
  }

  List<BoardPosition> legalMovesForStack(String stackId) {
    final stack = stackById(stackId);
    if (stack == null) {
      return const [];
    }
    final moves = <BoardPosition>[];
    for (final delta in const [
      BoardPosition(-1, 0),
      BoardPosition(1, 0),
      BoardPosition(0, -1),
      BoardPosition(0, 1),
    ]) {
      final next = stack.position.offset(delta.row, delta.col);
      if (!isInside(next)) {
        continue;
      }
      if (!isPassable(next)) {
        continue;
      }
      final occupant = stackAt(next);
      if (occupant != null && occupant.ownerId == stack.ownerId) {
        continue;
      }
      moves.add(next);
    }
    return moves;
  }

  WorldState copyWith({
    int? size,
    List<MapTile>? tiles,
    List<PlayerSlot>? players,
    int? activePlayerIndex,
    int? round,
    List<ArmyStack>? stacks,
    MapPreset? preset,
    int? seed,
    List<String>? log,
  }) {
    return WorldState(
      size: size ?? this.size,
      tiles: tiles ?? this.tiles,
      players: players ?? this.players,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      round: round ?? this.round,
      stacks: stacks ?? this.stacks,
      preset: preset ?? this.preset,
      seed: seed ?? this.seed,
      log: log ?? this.log,
    );
  }
}

class WorldMove {
  const WorldMove({required this.stackId, required this.to});

  final String stackId;
  final BoardPosition to;
}
