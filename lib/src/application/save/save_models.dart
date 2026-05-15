import '../../domain/ai.dart';
import '../../domain/army.dart';
import '../../domain/battle_session.dart';
import '../../domain/battle_state.dart';
import '../../domain/board_position.dart';
import '../../domain/piece.dart';
import '../../domain/world.dart';
import '../settings/settings_models.dart';

const int gameSaveSchemaVersion = 1;

enum SavedGamePhase { setup, world, battle, gameOver }

class SaveSlots {
  static const String slot1 = 'slot_1';
  static const String slot2 = 'slot_2';
  static const String slot3 = 'slot_3';
  static const String autosave = 'autosave';

  static const List<String> manual = <String>[slot1, slot2, slot3];
  static const List<String> all = <String>[slot1, slot2, slot3, autosave];
}

class GameSaveV1 {
  const GameSaveV1({
    required this.schemaVersion,
    required this.savedAtUtc,
    required this.gameModeKey,
    required this.phase,
    required this.seed,
    required this.playerCount,
    required this.mapSize,
    required this.armiesPerPlayer,
    required this.mapPreset,
    required this.aiDifficulty,
    required this.playerTypes,
    required this.worldState,
    required this.battleSession,
    required this.statusLine,
    required this.selectedStackId,
    required this.forcedMarchMode,
    required this.selectedBattlePieceId,
    required this.campaignOnboardingSeen,
    required this.stackSupplyById,
    required this.stackStarvationById,
    required this.stackWaterById,
    required this.stackThirstById,
    required this.capturePolicyByPlayer,
    required this.foodTileOwnerByPosition,
    required this.pillagedTileUntilRound,
    required this.settings,
  });

  factory GameSaveV1.fromJson(Map<String, dynamic> json) {
    final settingsRaw = _map(json['settings']);
    final worldRaw = _mapOrNull(json['worldState']);
    final battleRaw = _mapOrNull(json['battleSession']);
    final playerTypesRaw =
        (json['playerTypes'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList();

    return GameSaveV1(
      schemaVersion: _asInt(json['schemaVersion'], gameSaveSchemaVersion),
      savedAtUtc:
          DateTime.tryParse(_asString(json['savedAtUtc'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      gameModeKey: _asString(json['gameModeKey'], 'casusBelli'),
      phase: _enumByName(
        SavedGamePhase.values,
        _asString(json['phase']),
        SavedGamePhase.setup,
      ),
      seed: _asInt(json['seed']),
      playerCount: _asInt(json['playerCount'], 2),
      mapSize: _asInt(json['mapSize'], 5),
      armiesPerPlayer: _asInt(json['armiesPerPlayer'], 3),
      mapPreset: _enumByName(
        MapPreset.values,
        _asString(json['mapPreset']),
        MapPreset.greatField,
      ),
      aiDifficulty: _enumByName(
        AiDifficulty.values,
        _asString(json['aiDifficulty']),
        AiDifficulty.normal,
      ),
      playerTypes: playerTypesRaw.isEmpty
          ? const <PlayerType>[PlayerType.human, PlayerType.ai]
          : playerTypesRaw
                .map(
                  (value) =>
                      _enumByName(PlayerType.values, value, PlayerType.ai),
                )
                .toList(),
      worldState: worldRaw == null ? null : _worldStateFromJson(worldRaw),
      battleSession: battleRaw == null
          ? null
          : _battleSessionFromJson(battleRaw),
      statusLine: _asString(json['statusLine']),
      selectedStackId: _nullableString(json['selectedStackId']),
      forcedMarchMode: _asBool(json['forcedMarchMode']),
      selectedBattlePieceId: _nullableString(json['selectedBattlePieceId']),
      campaignOnboardingSeen: _asBool(json['campaignOnboardingSeen']),
      stackSupplyById: _stringIntMapFromJson(json['stackSupplyById']),
      stackStarvationById: _stringIntMapFromJson(json['stackStarvationById']),
      stackWaterById: _stringIntMapFromJson(json['stackWaterById']),
      stackThirstById: _stringIntMapFromJson(json['stackThirstById']),
      capturePolicyByPlayer: _intStringMapFromJson(
        json['capturePolicyByPlayer'],
      ),
      foodTileOwnerByPosition: _stringIntMapFromJson(
        json['foodTileOwnerByPosition'],
      ),
      pillagedTileUntilRound: _stringIntMapFromJson(
        json['pillagedTileUntilRound'],
      ),
      settings: settingsRaw == null
          ? GameSettingsSnapshot.defaults
          : GameSettingsSnapshot.fromJson(settingsRaw),
    );
  }

  final int schemaVersion;
  final DateTime savedAtUtc;
  final String gameModeKey;
  final SavedGamePhase phase;
  final int seed;
  final int playerCount;
  final int mapSize;
  final int armiesPerPlayer;
  final MapPreset mapPreset;
  final AiDifficulty aiDifficulty;
  final List<PlayerType> playerTypes;
  final WorldState? worldState;
  final BattleSession? battleSession;
  final String statusLine;
  final String? selectedStackId;
  final bool forcedMarchMode;
  final String? selectedBattlePieceId;
  final bool campaignOnboardingSeen;
  final Map<String, int> stackSupplyById;
  final Map<String, int> stackStarvationById;
  final Map<String, int> stackWaterById;
  final Map<String, int> stackThirstById;
  final Map<int, String> capturePolicyByPlayer;
  final Map<String, int> foodTileOwnerByPosition;
  final Map<String, int> pillagedTileUntilRound;
  final GameSettingsSnapshot settings;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'savedAtUtc': savedAtUtc.toUtc().toIso8601String(),
      'gameModeKey': gameModeKey,
      'phase': phase.name,
      'seed': seed,
      'playerCount': playerCount,
      'mapSize': mapSize,
      'armiesPerPlayer': armiesPerPlayer,
      'mapPreset': mapPreset.name,
      'aiDifficulty': aiDifficulty.name,
      'playerTypes': playerTypes.map((value) => value.name).toList(),
      'worldState': worldState == null ? null : _worldStateToJson(worldState!),
      'battleSession': battleSession == null
          ? null
          : _battleSessionToJson(battleSession!),
      'statusLine': statusLine,
      'selectedStackId': selectedStackId,
      'forcedMarchMode': forcedMarchMode,
      'selectedBattlePieceId': selectedBattlePieceId,
      'campaignOnboardingSeen': campaignOnboardingSeen,
      'stackSupplyById': _stringIntMapToJson(stackSupplyById),
      'stackStarvationById': _stringIntMapToJson(stackStarvationById),
      'stackWaterById': _stringIntMapToJson(stackWaterById),
      'stackThirstById': _stringIntMapToJson(stackThirstById),
      'capturePolicyByPlayer': _intStringMapToJson(capturePolicyByPlayer),
      'foodTileOwnerByPosition': _stringIntMapToJson(foodTileOwnerByPosition),
      'pillagedTileUntilRound': _stringIntMapToJson(pillagedTileUntilRound),
      'settings': settings.toJson(),
    };
  }
}

Map<String, dynamic> _worldStateToJson(WorldState world) {
  return <String, dynamic>{
    'size': world.size,
    'tiles': world.tiles.map(_mapTileToJson).toList(),
    'riverEdges': world.riverEdges.map(_riverEdgeToJson).toList(),
    'settlements': world.settlements.map(_settlementToJson).toList(),
    'camps': world.camps.map(_campToJson).toList(),
    'players': world.players.map(_playerSlotToJson).toList(),
    'activePlayerIndex': world.activePlayerIndex,
    'round': world.round,
    'stacks': world.stacks.map(_stackToJson).toList(),
    'commandPointMax': world.commandPointMax,
    'commandPointsByPlayer': _intIntMapToJson(world.commandPointsByPlayer),
    'foodByPlayer': _intIntMapToJson(world.foodByPlayer),
    'treasuryByPlayer': _intIntMapToJson(world.treasuryByPlayer),
    'preset': world.preset.name,
    'seed': world.seed,
    'log': world.log,
  };
}

WorldState _worldStateFromJson(Map<String, dynamic> json) {
  return WorldState(
    size: _asInt(json['size'], 5),
    tiles: _listOfMaps(json['tiles']).map(_mapTileFromJson).toList(),
    riverEdges: _listOfMaps(
      json['riverEdges'],
    ).map(_riverEdgeFromJson).toList(),
    settlements: _listOfMaps(
      json['settlements'],
    ).map(_settlementFromJson).toList(),
    camps: _listOfMaps(json['camps']).map(_campFromJson).toList(),
    players: _listOfMaps(json['players']).map(_playerSlotFromJson).toList(),
    activePlayerIndex: _asInt(json['activePlayerIndex']),
    round: _asInt(json['round'], 1),
    stacks: _listOfMaps(json['stacks']).map(_stackFromJson).toList(),
    commandPointMax: _asInt(json['commandPointMax'], 3),
    commandPointsByPlayer: _intIntMapFromJson(json['commandPointsByPlayer']),
    foodByPlayer: _intIntMapFromJson(json['foodByPlayer']),
    treasuryByPlayer: _intIntMapFromJson(json['treasuryByPlayer']),
    preset: _enumByName(
      MapPreset.values,
      _asString(json['preset']),
      MapPreset.greatField,
    ),
    seed: _asInt(json['seed']),
    log: _stringList(json['log']),
  );
}

Map<String, dynamic> _battleSessionToJson(BattleSession session) {
  return <String, dynamic>{
    'attackerStack': _stackToJson(session.attackerStack),
    'defenderStack': _stackToJson(session.defenderStack),
    'battleState': _battleStateToJson(session.battleState),
    'battlefield': _battlefieldToJson(session.battlefield),
  };
}

BattleSession _battleSessionFromJson(Map<String, dynamic> json) {
  return BattleSession(
    attackerStack: _stackFromJson(_map(json['attackerStack'])!),
    defenderStack: _stackFromJson(_map(json['defenderStack'])!),
    battleState: _battleStateFromJson(_map(json['battleState'])!),
    battlefield: _battlefieldFromJson(_map(json['battlefield'])!),
  );
}

Map<String, dynamic> _battleStateToJson(BattleState state) {
  return <String, dynamic>{
    'rows': state.rows,
    'cols': state.cols,
    'activePlayer': state.activePlayer,
    'southPlayerId': state.southPlayerId,
    'northPlayerId': state.northPlayerId,
    'pieces': state.pieces.map(_battlePieceToJson).toList(),
    'moveLog': state.moveLog,
    'eventLog': state.eventLog.map(_battleEventToJson).toList(),
    'blockedCells': _positionsToJson(state.blockedCells),
    'disableOpeningCaptures': state.disableOpeningCaptures,
    'moraleByPlayer': _intIntMapToJson(state.moraleByPlayer),
    'maxMorale': state.maxMorale,
    'generalSkillUsedByPlayer': _intBoolMapToJson(
      state.generalSkillUsedByPlayer,
    ),
    'trapArmedByPlayer': _intBoolMapToJson(state.trapArmedByPlayer),
    'trapColumnByPlayer': _intIntMapToJson(state.trapColumnByPlayer),
  };
}

BattleState _battleStateFromJson(Map<String, dynamic> json) {
  return BattleState(
    rows: _asInt(json['rows'], 8),
    cols: _asInt(json['cols'], 8),
    activePlayer: _asInt(json['activePlayer']),
    southPlayerId: _asInt(json['southPlayerId']),
    northPlayerId: _asInt(json['northPlayerId'], 1),
    pieces: _listOfMaps(json['pieces']).map(_battlePieceFromJson).toList(),
    moveLog: _stringList(json['moveLog']),
    eventLog: _listOfMaps(json['eventLog']).map(_battleEventFromJson).toList(),
    blockedCells: _positionsFromJson(json['blockedCells']),
    disableOpeningCaptures: _asBool(json['disableOpeningCaptures']),
    moraleByPlayer: _intIntMapFromJson(json['moraleByPlayer']),
    maxMorale: _asInt(json['maxMorale'], 6),
    generalSkillUsedByPlayer: _intBoolMapFromJson(
      json['generalSkillUsedByPlayer'],
    ),
    trapArmedByPlayer: _intBoolMapFromJson(json['trapArmedByPlayer']),
    trapColumnByPlayer: _intIntMapFromJson(json['trapColumnByPlayer']),
  );
}

Map<String, dynamic> _battleEventToJson(BattleEvent event) {
  return <String, dynamic>{
    'turn': event.turn,
    'type': event.type.name,
    'description': event.description,
    'actorPlayerId': event.actorPlayerId,
    'targetPlayerId': event.targetPlayerId,
    'pieceId': event.pieceId,
    'fromPosition': event.fromPosition == null
        ? null
        : _positionToJson(event.fromPosition!),
    'position': event.position == null
        ? null
        : _positionToJson(event.position!),
    'delta': event.delta,
  };
}

BattleEvent _battleEventFromJson(Map<String, dynamic> json) {
  return BattleEvent(
    turn: _asInt(json['turn']),
    type: _enumByName(
      BattleEventType.values,
      _asString(json['type']),
      BattleEventType.move,
    ),
    description: _asString(json['description']),
    actorPlayerId: _asNullableInt(json['actorPlayerId']),
    targetPlayerId: _asNullableInt(json['targetPlayerId']),
    pieceId: _nullableString(json['pieceId']),
    fromPosition: _positionOrNull(json['fromPosition']),
    position: _positionOrNull(json['position']),
    delta: _asNullableInt(json['delta']),
  );
}

Map<String, dynamic> _battlePieceToJson(BattlePiece piece) {
  return <String, dynamic>{
    'id': piece.id,
    'ownerId': piece.ownerId,
    'type': piece.type.name,
    'position': _positionToJson(piece.position),
    'generalSkill': piece.generalSkill?.name,
    'generalRank': piece.generalRank?.name,
    'generalExperience': piece.generalExperience,
  };
}

BattlePiece _battlePieceFromJson(Map<String, dynamic> json) {
  final type = _enumByName(
    PieceType.values,
    _asString(json['type']),
    PieceType.pawn,
  );
  final isGeneral = type == PieceType.general;
  return BattlePiece(
    id: _asString(json['id']),
    ownerId: _asInt(json['ownerId']),
    type: type,
    position: _positionFromJson(_map(json['position'])!),
    generalSkill: isGeneral
        ? _enumByName(
            GeneralSkill.values,
            _asString(json['generalSkill']),
            GeneralSkill.fieldCommander,
          )
        : null,
    generalRank: isGeneral
        ? _enumByName(
            GeneralRank.values,
            _asString(json['generalRank']),
            GeneralRank.highKing,
          )
        : null,
    generalExperience: _asInt(json['generalExperience']),
  );
}

Map<String, dynamic> _stackToJson(ArmyStack stack) {
  return <String, dynamic>{
    'id': stack.id,
    'ownerId': stack.ownerId,
    'army': _armyDefinitionToJson(stack.army),
    'position': _positionToJson(stack.position),
    'label': stack.label,
    'entrenchedUntilRound': stack.entrenchedUntilRound,
    'forcedMarchRound': stack.forcedMarchRound,
    'fatigue': stack.fatigue,
  };
}

ArmyStack _stackFromJson(Map<String, dynamic> json) {
  return ArmyStack(
    id: _asString(json['id']),
    ownerId: _asInt(json['ownerId']),
    army: _armyDefinitionFromJson(_map(json['army'])!),
    position: _positionFromJson(_map(json['position'])!),
    label: _asString(json['label']),
    entrenchedUntilRound: _asNullableInt(json['entrenchedUntilRound']),
    forcedMarchRound: _asNullableInt(json['forcedMarchRound']),
    fatigue: _asInt(json['fatigue']),
  );
}

Map<String, dynamic> _armyDefinitionToJson(ArmyDefinition army) {
  return <String, dynamic>{
    'id': army.id,
    'label': army.label,
    'units': army.units.map(_armyUnitToJson).toList(),
  };
}

ArmyDefinition _armyDefinitionFromJson(Map<String, dynamic> json) {
  return ArmyDefinition(
    id: _asString(json['id']),
    label: _asString(json['label']),
    units: _listOfMaps(json['units']).map(_armyUnitFromJson).toList(),
  );
}

Map<String, dynamic> _armyUnitToJson(ArmyUnit unit) {
  return <String, dynamic>{
    'type': unit.type.name,
    'generalSkill': unit.generalSkill?.name,
    'generalRank': unit.generalRank?.name,
    'title': unit.title,
  };
}

ArmyUnit _armyUnitFromJson(Map<String, dynamic> json) {
  final type = _enumByName(
    PieceType.values,
    _asString(json['type']),
    PieceType.pawn,
  );
  return ArmyUnit(
    type: type,
    generalSkill: type == PieceType.general
        ? _enumByName(
            GeneralSkill.values,
            _asString(json['generalSkill']),
            GeneralSkill.fieldCommander,
          )
        : null,
    generalRank: type == PieceType.general
        ? _enumByName(
            GeneralRank.values,
            _asString(json['generalRank']),
            GeneralRank.highKing,
          )
        : null,
    title: _nullableString(json['title']),
  );
}

Map<String, dynamic> _playerSlotToJson(PlayerSlot slot) {
  return <String, dynamic>{
    'id': slot.id,
    'type': slot.type.name,
    'name': slot.name,
  };
}

PlayerSlot _playerSlotFromJson(Map<String, dynamic> json) {
  return PlayerSlot(
    id: _asInt(json['id']),
    type: _enumByName(
      PlayerType.values,
      _asString(json['type']),
      PlayerType.ai,
    ),
    name: _asString(json['name'], 'Player'),
  );
}

Map<String, dynamic> _mapTileToJson(MapTile tile) {
  return <String, dynamic>{
    'position': _positionToJson(tile.position),
    'terrain': tile.terrain.name,
    'battlefield': _battlefieldToJson(tile.battlefield),
  };
}

MapTile _mapTileFromJson(Map<String, dynamic> json) {
  return MapTile(
    position: _positionFromJson(_map(json['position'])!),
    terrain: _enumByName(
      TerrainType.values,
      _asString(json['terrain']),
      TerrainType.passable,
    ),
    battlefield: _battlefieldFromJson(_map(json['battlefield'])!),
  );
}

Map<String, dynamic> _riverEdgeToJson(RiverEdge edge) {
  return <String, dynamic>{
    'a': _positionToJson(edge.a),
    'b': _positionToJson(edge.b),
    'type': edge.type.name,
  };
}

RiverEdge _riverEdgeFromJson(Map<String, dynamic> json) {
  return RiverEdge(
    a: _positionFromJson(_map(json['a'])!),
    b: _positionFromJson(_map(json['b'])!),
    type: _enumByName(
      RiverEdgeType.values,
      _asString(json['type']),
      RiverEdgeType.river,
    ),
  );
}

Map<String, dynamic> _battlefieldToJson(BattlefieldSpec spec) {
  return <String, dynamic>{
    'rows': spec.rows,
    'cols': spec.cols,
    'blocked': _positionsToJson(spec.blocked),
    'notation': spec.notation,
  };
}

BattlefieldSpec _battlefieldFromJson(Map<String, dynamic> json) {
  return BattlefieldSpec(
    rows: _asInt(json['rows'], 8),
    cols: _asInt(json['cols'], 8),
    blocked: _positionsFromJson(json['blocked']),
    notation: _asString(json['notation']),
  );
}

Map<String, dynamic> _settlementToJson(SettlementState settlement) {
  return <String, dynamic>{
    'id': settlement.id,
    'name': settlement.name,
    'position': _positionToJson(settlement.position),
    'ownerId': settlement.ownerId,
    'tier': settlement.tier.name,
    'cultureRating': settlement.cultureRating,
    'taxYield': settlement.taxYield,
    'supplyStock': settlement.supplyStock,
    'garrisonCapacity': settlement.garrisonCapacity,
    'garrisonedUnits': settlement.garrisonedUnits,
    'unrest': settlement.unrest,
    'levyCooldown': settlement.levyCooldown,
    'trapType': settlement.trapType.name,
    'trapArmed': settlement.trapArmed,
    'lastCapturedRound': settlement.lastCapturedRound,
  };
}

SettlementState _settlementFromJson(Map<String, dynamic> json) {
  return SettlementState(
    id: _asString(json['id']),
    name: _asString(json['name']),
    position: _positionFromJson(_map(json['position'])!),
    ownerId: _asInt(json['ownerId']),
    tier: _enumByName(
      SettlementTier.values,
      _asString(json['tier']),
      SettlementTier.village,
    ),
    cultureRating: _asInt(json['cultureRating']),
    taxYield: _asInt(json['taxYield']),
    supplyStock: _asInt(json['supplyStock']),
    garrisonCapacity: _asInt(json['garrisonCapacity']),
    garrisonedUnits: _asInt(json['garrisonedUnits']),
    unrest: _asInt(json['unrest']),
    levyCooldown: _asInt(json['levyCooldown']),
    trapType: _enumByName(
      SettlementTrapType.values,
      _asString(json['trapType']),
      SettlementTrapType.none,
    ),
    trapArmed: _asBool(json['trapArmed']),
    lastCapturedRound: _asNullableInt(json['lastCapturedRound']),
  );
}

Map<String, dynamic> _campToJson(CampState camp) {
  return <String, dynamic>{
    'id': camp.id,
    'ownerId': camp.ownerId,
    'position': _positionToJson(camp.position),
    'createdRound': camp.createdRound,
    'expiresRound': camp.expiresRound,
    'posture': camp.posture.name,
    'supplyStock': camp.supplyStock,
    'fatigueRecovery': camp.fatigueRecovery,
    'trapPrepared': camp.trapPrepared,
    'isOutpost': camp.isOutpost,
  };
}

CampState _campFromJson(Map<String, dynamic> json) {
  return CampState(
    id: _asString(json['id']),
    ownerId: _asInt(json['ownerId']),
    position: _positionFromJson(_map(json['position'])!),
    createdRound: _asInt(json['createdRound']),
    expiresRound: _asInt(json['expiresRound']),
    posture: _enumByName(
      CampPosture.values,
      _asString(json['posture']),
      CampPosture.supply,
    ),
    supplyStock: _asInt(json['supplyStock']),
    fatigueRecovery: _asInt(json['fatigueRecovery']),
    trapPrepared: _asBool(json['trapPrepared']),
    isOutpost: _asBool(json['isOutpost']),
  );
}

List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
  final list = raw as List<dynamic>? ?? const <dynamic>[];
  return list.whereType<Map>().map((value) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }).toList();
}

Map<String, dynamic>? _map(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

Map<String, dynamic>? _mapOrNull(dynamic raw) => _map(raw);

String _asString(dynamic value, [String fallback = '']) {
  if (value is String) {
    return value;
  }
  return fallback;
}

String? _nullableString(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

List<String> _stringList(dynamic value) {
  final list = value as List<dynamic>? ?? const <dynamic>[];
  return list.map((entry) => entry.toString()).toList();
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null || name.isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

Map<String, dynamic> _positionToJson(BoardPosition position) {
  return <String, dynamic>{'row': position.row, 'col': position.col};
}

BoardPosition _positionFromJson(Map<String, dynamic> json) {
  return BoardPosition(_asInt(json['row']), _asInt(json['col']));
}

BoardPosition? _positionOrNull(dynamic raw) {
  final value = _map(raw);
  if (value == null) {
    return null;
  }
  return _positionFromJson(value);
}

List<Map<String, dynamic>> _positionsToJson(Iterable<BoardPosition> values) {
  return values.map(_positionToJson).toList();
}

Set<BoardPosition> _positionsFromJson(dynamic raw) {
  final list = raw as List<dynamic>? ?? const <dynamic>[];
  final values = <BoardPosition>{};
  for (final entry in list) {
    final json = _map(entry);
    if (json == null) {
      continue;
    }
    values.add(_positionFromJson(json));
  }
  return values;
}

Map<String, dynamic> _intIntMapToJson(Map<int, int> source) {
  return source.map((key, value) => MapEntry('$key', value));
}

Map<String, dynamic> _stringIntMapToJson(Map<String, int> source) {
  return source.map((key, value) => MapEntry(key, value));
}

Map<int, int> _intIntMapFromJson(dynamic raw) {
  final value = _map(raw);
  if (value == null) {
    return const <int, int>{};
  }
  final result = <int, int>{};
  for (final entry in value.entries) {
    final key = int.tryParse(entry.key);
    if (key == null) {
      continue;
    }
    result[key] = _asInt(entry.value);
  }
  return result;
}

Map<String, int> _stringIntMapFromJson(dynamic raw) {
  final value = _map(raw);
  if (value == null) {
    return const <String, int>{};
  }
  final result = <String, int>{};
  for (final entry in value.entries) {
    result[entry.key] = _asInt(entry.value);
  }
  return result;
}

Map<String, dynamic> _intStringMapToJson(Map<int, String> source) {
  return source.map((key, value) => MapEntry('$key', value));
}

Map<int, String> _intStringMapFromJson(dynamic raw) {
  final value = _map(raw);
  if (value == null) {
    return const <int, String>{};
  }
  final result = <int, String>{};
  for (final entry in value.entries) {
    final key = int.tryParse(entry.key);
    if (key == null) {
      continue;
    }
    result[key] = _asString(entry.value);
  }
  return result;
}

Map<String, dynamic> _intBoolMapToJson(Map<int, bool> source) {
  return source.map((key, value) => MapEntry('$key', value));
}

Map<int, bool> _intBoolMapFromJson(dynamic raw) {
  final value = _map(raw);
  if (value == null) {
    return const <int, bool>{};
  }
  final result = <int, bool>{};
  for (final entry in value.entries) {
    final key = int.tryParse(entry.key);
    if (key == null) {
      continue;
    }
    result[key] = _asBool(entry.value);
  }
  return result;
}
