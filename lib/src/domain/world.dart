import 'army.dart';
import 'board_position.dart';

enum PlayerType { human, ai }

enum TerrainType { passable, blocked }

enum MapPreset { greatField, tightRavine, brokenGround }

enum SettlementAction { tax, forage, garrison, study, levy }

enum SettlementTier { village, town, castle }

enum SettlementTrapType { none, defensiveDitch }

enum CampPosture { supply, fortified, raiding }

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

class SettlementState {
  const SettlementState({
    required this.id,
    required this.name,
    required this.position,
    required this.ownerId,
    required this.tier,
    required this.cultureRating,
    required this.taxYield,
    required this.supplyStock,
    required this.garrisonCapacity,
    required this.garrisonedUnits,
    required this.unrest,
    required this.levyCooldown,
    this.trapType = SettlementTrapType.none,
    this.trapArmed = false,
    this.lastCapturedRound,
    this.occupationAge = 0,
    this.devastation = 0,
  });

  final String id;
  final String name;
  final BoardPosition position;
  final int ownerId;
  final SettlementTier tier;
  final int cultureRating;
  final int taxYield;
  final int supplyStock;
  final int garrisonCapacity;
  final int garrisonedUnits;
  final int unrest;
  final int levyCooldown;
  final SettlementTrapType trapType;
  final bool trapArmed;
  final int? lastCapturedRound;
  final int occupationAge;
  final int devastation;

  int get laneConstraint {
    switch (tier) {
      case SettlementTier.village:
        return 0;
      case SettlementTier.town:
        return 1;
      case SettlementTier.castle:
        return 2;
    }
  }

  int get moraleShield {
    switch (tier) {
      case SettlementTier.village:
        return 0;
      case SettlementTier.town:
        return 1;
      case SettlementTier.castle:
        return 1;
    }
  }

  SettlementState copyWith({
    String? id,
    String? name,
    BoardPosition? position,
    int? ownerId,
    SettlementTier? tier,
    int? cultureRating,
    int? taxYield,
    int? supplyStock,
    int? garrisonCapacity,
    int? garrisonedUnits,
    int? unrest,
    int? levyCooldown,
    SettlementTrapType? trapType,
    bool? trapArmed,
    int? lastCapturedRound,
    int? occupationAge,
    int? devastation,
  }) {
    return SettlementState(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      ownerId: ownerId ?? this.ownerId,
      tier: tier ?? this.tier,
      cultureRating: cultureRating ?? this.cultureRating,
      taxYield: taxYield ?? this.taxYield,
      supplyStock: supplyStock ?? this.supplyStock,
      garrisonCapacity: garrisonCapacity ?? this.garrisonCapacity,
      garrisonedUnits: garrisonedUnits ?? this.garrisonedUnits,
      unrest: unrest ?? this.unrest,
      levyCooldown: levyCooldown ?? this.levyCooldown,
      trapType: trapType ?? this.trapType,
      trapArmed: trapArmed ?? this.trapArmed,
      lastCapturedRound: lastCapturedRound ?? this.lastCapturedRound,
      occupationAge: occupationAge ?? this.occupationAge,
      devastation: devastation ?? this.devastation,
    );
  }
}

class CampState {
  const CampState({
    required this.id,
    required this.ownerId,
    required this.position,
    required this.createdRound,
    required this.expiresRound,
    required this.posture,
    required this.supplyStock,
    required this.fatigueRecovery,
    required this.trapPrepared,
    this.isOutpost = false,
  });

  final String id;
  final int ownerId;
  final BoardPosition position;
  final int createdRound;
  final int expiresRound;
  final CampPosture posture;
  final int supplyStock;
  final int fatigueRecovery;
  final bool trapPrepared;
  final bool isOutpost;

  bool activeAtRound(int round) => round <= expiresRound;

  CampState copyWith({
    String? id,
    int? ownerId,
    BoardPosition? position,
    int? createdRound,
    int? expiresRound,
    CampPosture? posture,
    int? supplyStock,
    int? fatigueRecovery,
    bool? trapPrepared,
    bool? isOutpost,
  }) {
    return CampState(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      position: position ?? this.position,
      createdRound: createdRound ?? this.createdRound,
      expiresRound: expiresRound ?? this.expiresRound,
      posture: posture ?? this.posture,
      supplyStock: supplyStock ?? this.supplyStock,
      fatigueRecovery: fatigueRecovery ?? this.fatigueRecovery,
      trapPrepared: trapPrepared ?? this.trapPrepared,
      isOutpost: isOutpost ?? this.isOutpost,
    );
  }
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
  static const Object _unset = Object();

  const ArmyStack({
    required this.id,
    required this.ownerId,
    required this.army,
    required this.position,
    required this.label,
    this.entrenchedUntilRound,
    this.forcedMarchRound,
    this.fatigue = 0,
  });

  final String id;
  final int ownerId;
  final ArmyDefinition army;
  final BoardPosition position;
  final String label;
  final int? entrenchedUntilRound;
  final int? forcedMarchRound;
  final int fatigue;

  bool entrenchedAtRound(int round) {
    final until = entrenchedUntilRound;
    return until != null && round <= until;
  }

  ArmyStack copyWith({
    String? id,
    int? ownerId,
    ArmyDefinition? army,
    BoardPosition? position,
    String? label,
    Object? entrenchedUntilRound = _unset,
    Object? forcedMarchRound = _unset,
    int? fatigue,
  }) {
    return ArmyStack(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      army: army ?? this.army,
      position: position ?? this.position,
      label: label ?? this.label,
      entrenchedUntilRound: identical(entrenchedUntilRound, _unset)
          ? this.entrenchedUntilRound
          : entrenchedUntilRound as int?,
      forcedMarchRound: identical(forcedMarchRound, _unset)
          ? this.forcedMarchRound
          : forcedMarchRound as int?,
      fatigue: fatigue ?? this.fatigue,
    );
  }
}

class WorldState {
  const WorldState({
    required this.size,
    required this.tiles,
    this.settlements = const <SettlementState>[],
    this.camps = const <CampState>[],
    required this.players,
    required this.activePlayerIndex,
    required this.round,
    required this.stacks,
    this.commandPointMax = 3,
    this.commandPointsByPlayer = const <int, int>{},
    this.foodByPlayer = const <int, int>{},
    this.treasuryByPlayer = const <int, int>{},
    required this.preset,
    required this.seed,
    required this.log,
  });

  final int size;
  final List<MapTile> tiles;
  final List<SettlementState> settlements;
  final List<CampState> camps;
  final List<PlayerSlot> players;
  final int activePlayerIndex;
  final int round;
  final List<ArmyStack> stacks;
  final int commandPointMax;
  final Map<int, int> commandPointsByPlayer;
  final Map<int, int> foodByPlayer;
  final Map<int, int> treasuryByPlayer;
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

  SettlementState? settlementAt(BoardPosition position) {
    for (final settlement in settlements) {
      if (settlement.position == position) {
        return settlement;
      }
    }
    return null;
  }

  CampState? campAt(BoardPosition position) {
    for (final camp in camps) {
      if (camp.position == position) {
        return camp;
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

  List<CampState> campsForPlayer(int playerId) {
    return camps.where((camp) => camp.ownerId == playerId).toList();
  }

  bool isInside(BoardPosition position) {
    return position.inBounds(size, size);
  }

  bool isPassable(BoardPosition position) {
    return tileAt(position).terrain == TerrainType.passable;
  }

  List<BoardPosition> legalMovesForStack(String stackId, {int maxSteps = 1}) {
    final stack = stackById(stackId);
    if (stack == null) {
      return const [];
    }
    final steps = maxSteps.clamp(1, 2).toInt();
    if (steps == 1) {
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

    final reachable = <BoardPosition>{};
    final frontier = <BoardPosition>{stack.position};
    final visited = <BoardPosition>{stack.position};

    for (var depth = 0; depth < steps; depth++) {
      final nextFrontier = <BoardPosition>{};
      for (final current in frontier) {
        for (final delta in const [
          BoardPosition(-1, 0),
          BoardPosition(1, 0),
          BoardPosition(0, -1),
          BoardPosition(0, 1),
        ]) {
          final next = current.offset(delta.row, delta.col);
          if (!isInside(next) || !isPassable(next)) {
            continue;
          }
          final occupant = stackAt(next);
          if (occupant != null && occupant.ownerId == stack.ownerId) {
            continue;
          }
          if (depth + 1 < steps && occupant != null) {
            continue;
          }
          reachable.add(next);
          if (visited.add(next) && occupant == null) {
            nextFrontier.add(next);
          }
        }
      }
      frontier
        ..clear()
        ..addAll(nextFrontier);
    }

    reachable.remove(stack.position);
    return reachable.toList();
  }

  WorldState copyWith({
    int? size,
    List<MapTile>? tiles,
    List<SettlementState>? settlements,
    List<CampState>? camps,
    List<PlayerSlot>? players,
    int? activePlayerIndex,
    int? round,
    List<ArmyStack>? stacks,
    int? commandPointMax,
    Map<int, int>? commandPointsByPlayer,
    Map<int, int>? foodByPlayer,
    Map<int, int>? treasuryByPlayer,
    MapPreset? preset,
    int? seed,
    List<String>? log,
  }) {
    return WorldState(
      size: size ?? this.size,
      tiles: tiles ?? this.tiles,
      settlements: settlements ?? this.settlements,
      camps: camps ?? this.camps,
      players: players ?? this.players,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      round: round ?? this.round,
      stacks: stacks ?? this.stacks,
      commandPointMax: commandPointMax ?? this.commandPointMax,
      commandPointsByPlayer:
          commandPointsByPlayer ?? this.commandPointsByPlayer,
      foodByPlayer: foodByPlayer ?? this.foodByPlayer,
      treasuryByPlayer: treasuryByPlayer ?? this.treasuryByPlayer,
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
