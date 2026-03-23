part of 'alpha_game_screen.dart';

enum _CapturePolicy { spare, destroy }

@immutable
class _PlayerBattleLedger {
  const _PlayerBattleLedger({
    this.captures = 0,
    this.routPressureInflicted = 0,
    this.battlesWon = 0,
    this.commandSkillsUsed = 0,
    this.commandersEliminated = 0,
    this.moraleCollapseVictories = 0,
  });

  final int captures;
  final int routPressureInflicted;
  final int battlesWon;
  final int commandSkillsUsed;
  final int commandersEliminated;
  final int moraleCollapseVictories;

  _PlayerBattleLedger copyWith({
    int? captures,
    int? routPressureInflicted,
    int? battlesWon,
    int? commandSkillsUsed,
    int? commandersEliminated,
    int? moraleCollapseVictories,
  }) {
    return _PlayerBattleLedger(
      captures: captures ?? this.captures,
      routPressureInflicted:
          routPressureInflicted ?? this.routPressureInflicted,
      battlesWon: battlesWon ?? this.battlesWon,
      commandSkillsUsed: commandSkillsUsed ?? this.commandSkillsUsed,
      commandersEliminated: commandersEliminated ?? this.commandersEliminated,
      moraleCollapseVictories:
          moraleCollapseVictories ?? this.moraleCollapseVictories,
    );
  }
}

@immutable
class _MatchOverSummary {
  const _MatchOverSummary({
    required this.winnerPlayerId,
    required this.rounds,
    required this.seed,
    required this.preset,
    required this.decisiveLine,
    required this.settlementsHeld,
    required this.captures,
    required this.routPressureInflicted,
    required this.battlesWon,
    required this.commandSkillsUsed,
    required this.commandersEliminated,
    required this.moraleCollapseVictories,
    required this.decisiveEvents,
    required this.timeline,
  });

  final int? winnerPlayerId;
  final int rounds;
  final int seed;
  final MapPreset preset;
  final String decisiveLine;
  final int settlementsHeld;
  final int captures;
  final int routPressureInflicted;
  final int battlesWon;
  final int commandSkillsUsed;
  final int commandersEliminated;
  final int moraleCollapseVictories;
  final List<String> decisiveEvents;
  final List<String> timeline;
}

class _BattlefieldModifiers {
  const _BattlefieldModifiers({
    required this.blockedCells,
    required this.maxMorale,
    required this.attackerMorale,
    required this.defenderMorale,
    required this.defenderTrapArmed,
    required this.defenderTrapColumn,
    required this.attackerHint,
    required this.laneConstraint,
    required this.defenderShield,
  });

  final Set<BoardPosition> blockedCells;
  final int maxMorale;
  final int attackerMorale;
  final int defenderMorale;
  final bool defenderTrapArmed;
  final int defenderTrapColumn;
  final String? attackerHint;
  final int laneConstraint;
  final int defenderShield;

  Map<int, int> initialMoraleByPlayer({
    required int attackerId,
    required int defenderId,
  }) {
    return <int, int>{attackerId: attackerMorale, defenderId: defenderMorale};
  }

  Map<int, bool> trapArmedByPlayer({required int defenderId}) {
    if (!defenderTrapArmed) {
      return const <int, bool>{};
    }
    return <int, bool>{defenderId: true};
  }

  Map<int, int> trapColumnByPlayer({required int defenderId}) {
    if (!defenderTrapArmed) {
      return const <int, int>{};
    }
    return <int, int>{defenderId: defenderTrapColumn};
  }

  List<BattleEvent> deploymentEvents({
    required int attackerId,
    required int defenderId,
  }) {
    final events = <BattleEvent>[];
    if (laneConstraint > 0) {
      events.add(
        BattleEvent(
          turn: 0,
          type: BattleEventType.deployment,
          actorPlayerId: defenderId,
          targetPlayerId: attackerId,
          description:
              'Defender narrowed the approach: $laneConstraint lane(s) constrained.',
        ),
      );
    }
    if (defenderShield > 0) {
      events.add(
        BattleEvent(
          turn: 0,
          type: BattleEventType.deployment,
          actorPlayerId: defenderId,
          description:
              'Defender morale shield +$defenderShield from settlement/camp support.',
        ),
      );
    }
    if (defenderTrapArmed) {
      events.add(
        BattleEvent(
          turn: 0,
          type: BattleEventType.deployment,
          actorPlayerId: defenderId,
          description:
              'Defensive ditch prepared on file $defenderTrapColumn for first contact advance.',
        ),
      );
    }
    return events;
  }
}

@immutable
class _FieldManualSection {
  const _FieldManualSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<String> points;
}

@immutable
class _FoodProjection {
  const _FoodProjection({
    required this.reserve,
    required this.settlementIncome,
    required this.campIncome,
    required this.fieldIncome,
    required this.upkeep,
    required this.projectedReserve,
    required this.shortageStacks,
  });

  final int reserve;
  final int settlementIncome;
  final int campIncome;
  final int fieldIncome;
  final int upkeep;
  final int projectedReserve;
  final int shortageStacks;
}

@immutable
class _WorldMoveMarker {
  const _WorldMoveMarker({
    required this.playerId,
    required this.stackId,
    required this.from,
    required this.to,
    required this.round,
  });

  final int playerId;
  final String stackId;
  final BoardPosition from;
  final BoardPosition to;
  final int round;
}

@immutable
class _ArmyLogisticsRoundResult {
  const _ArmyLogisticsRoundResult({
    required this.world,
    required this.supplyByStackId,
    required this.starvationByStackId,
    required this.waterByStackId,
    required this.thirstByStackId,
  });

  final WorldState world;
  final Map<String, int> supplyByStackId;
  final Map<String, int> starvationByStackId;
  final Map<String, int> waterByStackId;
  final Map<String, int> thirstByStackId;
}

enum _SupplyAnchorType { capital, settlement, camp, outpost }

enum _SupplyLineState { secure, stretched, isolated }

@immutable
class _SupplyAnchor {
  const _SupplyAnchor({
    required this.position,
    required this.type,
    required this.label,
  });

  final BoardPosition position;
  final _SupplyAnchorType type;
  final String label;
}

@immutable
class _SupplyLineReport {
  const _SupplyLineReport({
    required this.state,
    required this.path,
    required this.distance,
    required this.dangerSteps,
    required this.anchor,
  });

  final _SupplyLineState state;
  final List<BoardPosition> path;
  final int distance;
  final int dangerSteps;
  final _SupplyAnchor? anchor;

  bool get hasLine => anchor != null && path.isNotEmpty;

  String get stateLabel {
    return switch (state) {
      _SupplyLineState.secure => 'Secure line',
      _SupplyLineState.stretched => 'Stretched line',
      _SupplyLineState.isolated => 'Isolated',
    };
  }
}

@immutable
class _TerritoryTileStatus {
  const _TerritoryTileStatus({
    required this.ownerId,
    required this.depth,
    required this.contested,
    required this.frontline,
  });

  final int? ownerId;
  final int depth;
  final bool contested;
  final bool frontline;
}
