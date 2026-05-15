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

@immutable
class _ProvinceInfo {
  const _ProvinceInfo({
    required this.id,
    required this.name,
    required this.tiles,
    required this.gridAnchor,
    required this.ownerId,
    required this.contested,
    required this.frontline,
    required this.grainValue,
    required this.wealthValue,
    required this.crossings,
    required this.settlementCount,
  });

  final String id;
  final String name;
  final List<BoardPosition> tiles;
  final Offset gridAnchor;
  final int? ownerId;
  final bool contested;
  final bool frontline;
  final int grainValue;
  final int wealthValue;
  final int crossings;
  final int settlementCount;
}

@immutable
class _ProvinceMapSummary {
  const _ProvinceMapSummary({
    required this.provinces,
    required this.provinceByPosition,
  });

  final List<_ProvinceInfo> provinces;
  final Map<BoardPosition, _ProvinceInfo> provinceByPosition;
}

@immutable
class _WorldHexMetrics {
  const _WorldHexMetrics({
    required this.radius,
    required this.boardWidth,
    required this.boardHeight,
    required this.offset,
  });

  final double radius;
  final double boardWidth;
  final double boardHeight;
  final Offset offset;

  double get tileWidth => math.sqrt(3) * radius;
  double get tileHeight => radius * 2;
  double get verticalStep => radius * 1.5;

  factory _WorldHexMetrics.fit({
    required Size availableSize,
    required int gridSize,
  }) {
    final widthRadius =
        availableSize.width /
        (math.sqrt(3) * math.max(1, gridSize).toDouble() + (math.sqrt(3) / 2));
    final heightRadius =
        availableSize.height / ((math.max(1, gridSize).toDouble() * 1.5) + 0.5);
    final radius = math.max(18.0, math.min(widthRadius, heightRadius));
    final boardWidth =
        (math.sqrt(3) * radius * gridSize) + ((math.sqrt(3) / 2) * radius);
    final boardHeight = ((gridSize * 1.5) + 0.5) * radius;
    final offset = Offset(
      math.max(0, (availableSize.width - boardWidth) / 2),
      math.max(0, (availableSize.height - boardHeight) / 2),
    );
    return _WorldHexMetrics(
      radius: radius,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      offset: offset,
    );
  }

  Offset centerFor(BoardPosition position) {
    return Offset(
      offset.dx +
          (tileWidth / 2) +
          (position.col * tileWidth) +
          (position.row.isOdd ? tileWidth / 2 : 0),
      offset.dy + radius + (position.row * verticalStep),
    );
  }

  Rect tileRect(BoardPosition position) {
    return Rect.fromCenter(
      center: centerFor(position),
      width: tileWidth,
      height: tileHeight,
    );
  }

  static List<Offset> cornersForRect(Rect rect) {
    final center = rect.center;
    return <Offset>[
      Offset(center.dx, rect.top),
      Offset(rect.right, rect.top + (rect.height * 0.25)),
      Offset(rect.right, rect.bottom - (rect.height * 0.25)),
      Offset(center.dx, rect.bottom),
      Offset(rect.left, rect.bottom - (rect.height * 0.25)),
      Offset(rect.left, rect.top + (rect.height * 0.25)),
    ];
  }

  static Path hexPathForRect(Rect rect) {
    final corners = cornersForRect(rect);
    return Path()
      ..moveTo(corners.first.dx, corners.first.dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..lineTo(corners[4].dx, corners[4].dy)
      ..lineTo(corners[5].dx, corners[5].dy)
      ..close();
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();

  @override
  Path getClip(Size size) {
    return _WorldHexMetrics.hexPathForRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _HexagonClipper oldClipper) => false;
}

class _MarchColumnPainter extends CustomPainter {
  const _MarchColumnPainter({
    required this.ownerColor,
    required this.infantry,
    required this.cavalry,
    required this.support,
    required this.commanders,
  });

  final Color ownerColor;
  final int infantry;
  final int cavalry;
  final int support;
  final int commanders;

  @override
  void paint(Canvas canvas, Size size) {
    final laneHeight = math.max(3.0, size.height / 4.5);
    final infantryWidth =
        size.width * (0.34 + (infantry * 0.03).clamp(0, 0.18));
    final cavalryWidth = size.width * (0.18 + (cavalry * 0.035).clamp(0, 0.14));
    final supportWidth = size.width * (0.14 + (support * 0.03).clamp(0, 0.12));

    final bodyPaint = Paint()
      ..color = ownerColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFF23190F).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final accentPaint = Paint()
      ..color = const Color(0xFFF5E8BC)
      ..style = PaintingStyle.fill;

    final infantryRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, laneHeight * 1.7, infantryWidth, laneHeight),
      const Radius.circular(4),
    );
    final cavalryRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        infantryWidth + 4,
        laneHeight * 0.75,
        cavalryWidth,
        laneHeight,
      ),
      const Radius.circular(4),
    );
    final supportRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        infantryWidth + cavalryWidth + 8,
        laneHeight * 2.45,
        supportWidth,
        laneHeight,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(infantryRect, bodyPaint);
    canvas.drawRRect(cavalryRect, bodyPaint);
    canvas.drawRRect(supportRect, bodyPaint);
    canvas.drawRRect(infantryRect, outlinePaint);
    canvas.drawRRect(cavalryRect, outlinePaint);
    canvas.drawRRect(supportRect, outlinePaint);

    final arrow = Path()
      ..moveTo(size.width - 10, size.height / 2)
      ..lineTo(size.width - 20, size.height / 2 - 6)
      ..lineTo(size.width - 20, size.height / 2 - 2)
      ..lineTo(size.width - 30, size.height / 2 - 2)
      ..lineTo(size.width - 30, size.height / 2 + 2)
      ..lineTo(size.width - 20, size.height / 2 + 2)
      ..lineTo(size.width - 20, size.height / 2 + 6)
      ..close();
    canvas.drawPath(arrow, accentPaint);

    for (var i = 0; i < commanders.clamp(0, 2); i++) {
      canvas.drawCircle(
        Offset(6 + (i * 7), laneHeight * 0.7),
        2.2,
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarchColumnPainter oldDelegate) {
    return oldDelegate.ownerColor != ownerColor ||
        oldDelegate.infantry != infantry ||
        oldDelegate.cavalry != cavalry ||
        oldDelegate.support != support ||
        oldDelegate.commanders != commanders;
  }
}
