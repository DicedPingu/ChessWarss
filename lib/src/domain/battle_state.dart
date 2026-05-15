import 'army.dart';
import 'board_position.dart';
import 'piece.dart';

enum BattleFormation { balanced, flankGuard, spearhead }

enum BattleEventType {
  deployment,
  move,
  capture,
  moraleShift,
  advance,
  rout,
  generalProgress,
  generalSkill,
  charge,
  defend,
}

enum MoraleState { steady, wavering, routing, collapsed }

class BattleEvent {
  const BattleEvent({
    required this.turn,
    required this.type,
    required this.description,
    this.actorPlayerId,
    this.targetPlayerId,
    this.pieceId,
    this.fromPosition,
    this.position,
    this.delta,
  });

  final int turn;
  final BattleEventType type;
  final String description;
  final int? actorPlayerId;
  final int? targetPlayerId;
  final String? pieceId;
  final BoardPosition? fromPosition;
  final BoardPosition? position;
  final int? delta;
}

class BattleDeploymentPlan {
  const BattleDeploymentPlan({
    required this.id,
    required this.formation,
    required this.label,
    required this.summary,
    required this.pieces,
  });

  final String id;
  final BattleFormation formation;
  final String label;
  final String summary;
  final List<BattlePiece> pieces;
}

class BattleSideDeploymentPlan {
  const BattleSideDeploymentPlan({
    required this.id,
    required this.formation,
    required this.label,
    required this.summary,
    required this.pieces,
  });

  final String id;
  final BattleFormation formation;
  final String label;
  final String summary;
  final List<BattlePiece> pieces;
}

class BattleState {
  const BattleState({
    required this.rows,
    required this.cols,
    required this.activePlayer,
    this.southPlayerId = 0,
    this.northPlayerId = 1,
    required this.pieces,
    required this.moveLog,
    this.eventLog = const <BattleEvent>[],
    this.blockedCells = const <BoardPosition>{},
    this.disableOpeningCaptures = false,
    this.moraleByPlayer = const <int, int>{},
    this.maxMorale = 6,
    this.generalSkillUsedByPlayer = const <int, bool>{},
    this.trapArmedByPlayer = const <int, bool>{},
    this.trapColumnByPlayer = const <int, int>{},
    this.chargeByPlayer = const <int, bool>{},
    this.defendByPlayer = const <int, bool>{},
  });

  final int rows;
  final int cols;
  final int activePlayer;
  final int southPlayerId;
  final int northPlayerId;
  final List<BattlePiece> pieces;
  final List<String> moveLog;
  final List<BattleEvent> eventLog;
  final Set<BoardPosition> blockedCells;
  final bool disableOpeningCaptures;
  final Map<int, int> moraleByPlayer;
  final int maxMorale;
  final Map<int, bool> generalSkillUsedByPlayer;
  final Map<int, bool> trapArmedByPlayer;
  final Map<int, int> trapColumnByPlayer;
  final Map<int, bool> chargeByPlayer;
  final Map<int, bool> defendByPlayer;

  BattleState copyWith({
    int? rows,
    int? cols,
    int? activePlayer,
    int? southPlayerId,
    int? northPlayerId,
    List<BattlePiece>? pieces,
    List<String>? moveLog,
    List<BattleEvent>? eventLog,
    Set<BoardPosition>? blockedCells,
    bool? disableOpeningCaptures,
    Map<int, int>? moraleByPlayer,
    int? maxMorale,
    Map<int, bool>? generalSkillUsedByPlayer,
    Map<int, bool>? trapArmedByPlayer,
    Map<int, int>? trapColumnByPlayer,
    Map<int, bool>? chargeByPlayer,
    Map<int, bool>? defendByPlayer,
  }) {
    return BattleState(
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      activePlayer: activePlayer ?? this.activePlayer,
      southPlayerId: southPlayerId ?? this.southPlayerId,
      northPlayerId: northPlayerId ?? this.northPlayerId,
      pieces: pieces ?? this.pieces,
      moveLog: moveLog ?? this.moveLog,
      eventLog: eventLog ?? this.eventLog,
      blockedCells: blockedCells ?? this.blockedCells,
      disableOpeningCaptures:
          disableOpeningCaptures ?? this.disableOpeningCaptures,
      moraleByPlayer: moraleByPlayer ?? this.moraleByPlayer,
      maxMorale: maxMorale ?? this.maxMorale,
      generalSkillUsedByPlayer:
          generalSkillUsedByPlayer ?? this.generalSkillUsedByPlayer,
      trapArmedByPlayer: trapArmedByPlayer ?? this.trapArmedByPlayer,
      trapColumnByPlayer: trapColumnByPlayer ?? this.trapColumnByPlayer,
      chargeByPlayer: chargeByPlayer ?? this.chargeByPlayer,
      defendByPlayer: defendByPlayer ?? this.defendByPlayer,
    );
  }

  factory BattleState.fromArmies({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
    required int southOwnerId,
    required int northOwnerId,
    int rows = 8,
    int cols = 8,
    Set<BoardPosition> blockedCells = const <BoardPosition>{},
    BattleFormation formation = BattleFormation.balanced,
  }) {
    final options = BattleState.generateDeploymentPlans(
      southArmy: southArmy,
      northArmy: northArmy,
      southOwnerId: southOwnerId,
      northOwnerId: northOwnerId,
      rows: rows,
      cols: cols,
      blockedCells: blockedCells,
      preferredFormation: formation,
    );

    BattleDeploymentPlan selectedPlan = options.first;
    for (final option in options) {
      if (option.formation == formation) {
        selectedPlan = option;
        break;
      }
    }

    return BattleState.fromDeploymentPlan(
      plan: selectedPlan,
      southOwnerId: southOwnerId,
      northOwnerId: northOwnerId,
      rows: rows,
      cols: cols,
      blockedCells: blockedCells,
    );
  }

  factory BattleState.fromDeploymentPlan({
    required BattleDeploymentPlan plan,
    required int southOwnerId,
    required int northOwnerId,
    required int rows,
    required int cols,
    Set<BoardPosition> blockedCells = const <BoardPosition>{},
    Map<int, int>? initialMoraleByPlayer,
    int maxMorale = 6,
    Map<int, bool> trapArmedByPlayer = const <int, bool>{},
    Map<int, int> trapColumnByPlayer = const <int, int>{},
    List<BattleEvent> extraEvents = const <BattleEvent>[],
  }) {
    final morale =
        initialMoraleByPlayer ??
        <int, int>{southOwnerId: maxMorale, northOwnerId: maxMorale};
    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: southOwnerId,
      southPlayerId: southOwnerId,
      northPlayerId: northOwnerId,
      pieces: List<BattlePiece>.from(plan.pieces),
      moveLog: const <String>[],
      eventLog: [
        BattleEvent(
          turn: 0,
          type: BattleEventType.deployment,
          actorPlayerId: southOwnerId,
          description:
              'Deployment locked: ${plan.label}. Opening captures disabled on first move.',
        ),
        ...extraEvents,
      ],
      blockedCells: blockedCells,
      disableOpeningCaptures: true,
      moraleByPlayer: morale,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: <int, bool>{
        southOwnerId: false,
        northOwnerId: false,
      },
      trapArmedByPlayer: trapArmedByPlayer,
      trapColumnByPlayer: trapColumnByPlayer,
      chargeByPlayer: <int, bool>{southOwnerId: false, northOwnerId: false},
      defendByPlayer: <int, bool>{southOwnerId: false, northOwnerId: false},
    );
  }

  static List<BattleDeploymentPlan> generateDeploymentPlans({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
    required int southOwnerId,
    required int northOwnerId,
    int rows = 8,
    int cols = 8,
    Set<BoardPosition> blockedCells = const <BoardPosition>{},
    BattleFormation preferredFormation = BattleFormation.balanced,
  }) {
    final eligibleFormations = _eligibleFormationsForBattle(
      southArmy: southArmy,
      northArmy: northArmy,
    );
    final formationOrder = _formationOrder(
      preferredFormation,
    ).where(eligibleFormations.contains).toList();
    if (formationOrder.isEmpty) {
      formationOrder.add(BattleFormation.balanced);
    }
    final strongestSkill = _betterGeneralSkill(
      _strongestGeneralSkillInArmy(southArmy),
      _strongestGeneralSkillInArmy(northArmy),
    );
    final styles = _deploymentStylesForSkill(strongestSkill);

    final plans = <BattleDeploymentPlan>[];
    final signatures = <String>{};

    for (final formation in formationOrder) {
      for (final style in styles) {
        try {
          final occupiedCells = <BoardPosition>{};
          final southPieces = _deployArmy(
            army: southArmy,
            ownerId: southOwnerId,
            sideIsNorth: false,
            rows: rows,
            cols: cols,
            idPrefix: 'S$southOwnerId',
            blockedCells: blockedCells,
            occupiedCells: occupiedCells,
            formation: formation,
            columnRotation: style.columnRotation,
            mirrorColumns: style.mirrorColumns,
            reservePawns: style.reservePawns,
            pawnFileLimit: style.pawnFileLimit,
          );

          occupiedCells.addAll(southPieces.map((piece) => piece.position));

          final northPieces = _deployArmy(
            army: northArmy,
            ownerId: northOwnerId,
            sideIsNorth: true,
            rows: rows,
            cols: cols,
            idPrefix: 'N$northOwnerId',
            blockedCells: blockedCells,
            occupiedCells: occupiedCells,
            formation: formation,
            columnRotation: style.columnRotation,
            mirrorColumns: style.mirrorColumns,
            reservePawns: style.reservePawns,
            pawnFileLimit: style.pawnFileLimit,
          );

          final allPieces = [...southPieces, ...northPieces];
          final signature = _deploymentSignature(allPieces);
          if (!signatures.add(signature)) {
            continue;
          }

          final probeState = BattleState(
            rows: rows,
            cols: cols,
            activePlayer: southOwnerId,
            southPlayerId: southOwnerId,
            northPlayerId: northOwnerId,
            pieces: allPieces,
            moveLog: const <String>[],
            blockedCells: blockedCells,
            disableOpeningCaptures: false,
            moraleByPlayer: <int, int>{southOwnerId: 6, northOwnerId: 6},
            generalSkillUsedByPlayer: const <int, bool>{},
            chargeByPlayer: const <int, bool>{},
            defendByPlayer: const <int, bool>{},
          );

          final southOpeningCapture = probeState
              .legalActionsForPlayer(
                southOwnerId,
                ignoreOpeningCaptureBlock: true,
              )
              .any((action) => action.capturedPieceId != null);
          final northOpeningCapture = probeState
              .legalActionsForPlayer(
                northOwnerId,
                ignoreOpeningCaptureBlock: true,
              )
              .any((action) => action.capturedPieceId != null);

          if (southOpeningCapture || northOpeningCapture) {
            continue;
          }

          plans.add(
            BattleDeploymentPlan(
              id: '${formation.name}_${style.suffix.replaceAll(' ', '_')}',
              formation: formation,
              label: '${_formationLabel(formation)} • ${style.suffix}',
              summary: _deploymentSummary(
                formation: formation,
                style: style,
                rows: rows,
                cols: cols,
              ),
              pieces: allPieces,
            ),
          );
        } on StateError {
          continue;
        }
      }
    }

    if (plans.isEmpty) {
      final occupiedCells = <BoardPosition>{};
      final southPieces = _deployArmy(
        army: southArmy,
        ownerId: southOwnerId,
        sideIsNorth: false,
        rows: rows,
        cols: cols,
        idPrefix: 'S$southOwnerId',
        blockedCells: blockedCells,
        occupiedCells: occupiedCells,
        formation: preferredFormation,
      );
      occupiedCells.addAll(southPieces.map((piece) => piece.position));
      final northPieces = _deployArmy(
        army: northArmy,
        ownerId: northOwnerId,
        sideIsNorth: true,
        rows: rows,
        cols: cols,
        idPrefix: 'N$northOwnerId',
        blockedCells: blockedCells,
        occupiedCells: occupiedCells,
        formation: preferredFormation,
      );

      plans.add(
        BattleDeploymentPlan(
          id: '${preferredFormation.name}_fallback',
          formation: preferredFormation,
          label: '${_formationLabel(preferredFormation)} • Fallback',
          summary: 'Fallback deployment on constrained battlefield.',
          pieces: [...southPieces, ...northPieces],
        ),
      );
    }

    return plans;
  }

  static List<BattleSideDeploymentPlan> generateSideDeploymentPlans({
    required ArmyDefinition army,
    required int ownerId,
    required bool sideIsNorth,
    int rows = 8,
    int cols = 8,
    Set<BoardPosition> blockedCells = const <BoardPosition>{},
    BattleFormation preferredFormation = BattleFormation.balanced,
  }) {
    final eligibleFormations = _eligibleFormationsForArmy(army);
    final formationOrder = _formationOrder(
      preferredFormation,
    ).where(eligibleFormations.contains).toList();
    if (formationOrder.isEmpty) {
      formationOrder.add(BattleFormation.balanced);
    }
    final styles = _deploymentStylesForSkill(
      _strongestGeneralSkillInArmy(army),
    );

    final plans = <BattleSideDeploymentPlan>[];
    final signatures = <String>{};

    for (final formation in formationOrder) {
      for (final style in styles) {
        try {
          final pieces = _deployArmy(
            army: army,
            ownerId: ownerId,
            sideIsNorth: sideIsNorth,
            rows: rows,
            cols: cols,
            idPrefix: '${sideIsNorth ? 'N' : 'S'}$ownerId',
            blockedCells: blockedCells,
            occupiedCells: <BoardPosition>{},
            formation: formation,
            columnRotation: style.columnRotation,
            mirrorColumns: style.mirrorColumns,
            reservePawns: style.reservePawns,
            pawnFileLimit: style.pawnFileLimit,
          );
          final signature = _deploymentSignature(pieces);
          if (!signatures.add(signature)) {
            continue;
          }

          plans.add(
            BattleSideDeploymentPlan(
              id: '${sideIsNorth ? 'north' : 'south'}_${formation.name}_${style.suffix.replaceAll(' ', '_')}',
              formation: formation,
              label: '${_formationLabel(formation)} • ${style.suffix}',
              summary: _deploymentSummary(
                formation: formation,
                style: style,
                rows: rows,
                cols: cols,
              ),
              pieces: pieces,
            ),
          );
        } on StateError {
          continue;
        }
      }
    }

    if (plans.isEmpty) {
      final fallback = _deployArmy(
        army: army,
        ownerId: ownerId,
        sideIsNorth: sideIsNorth,
        rows: rows,
        cols: cols,
        idPrefix: '${sideIsNorth ? 'N' : 'S'}$ownerId',
        blockedCells: blockedCells,
        occupiedCells: <BoardPosition>{},
        formation: preferredFormation,
      );
      plans.add(
        BattleSideDeploymentPlan(
          id: '${sideIsNorth ? 'north' : 'south'}_${preferredFormation.name}_fallback',
          formation: preferredFormation,
          label: '${_formationLabel(preferredFormation)} • Fallback',
          summary: 'Fallback deployment on constrained battlefield.',
          pieces: fallback,
        ),
      );
    }

    return plans;
  }

  static List<BattleFormation> _formationOrder(BattleFormation preferred) {
    final order = <BattleFormation>[preferred];
    for (final formation in BattleFormation.values) {
      if (formation != preferred) {
        order.add(formation);
      }
    }
    return order;
  }

  static Set<BattleFormation> _eligibleFormationsForBattle({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
  }) {
    final south = _eligibleFormationsForArmy(southArmy);
    final north = _eligibleFormationsForArmy(northArmy);
    final shared = south.intersection(north);
    if (shared.isNotEmpty) {
      return shared;
    }
    return <BattleFormation>{BattleFormation.balanced};
  }

  static Set<BattleFormation> _eligibleFormationsForArmy(ArmyDefinition army) {
    final composition = army.composition;
    final strongestSkill = _strongestGeneralSkillInArmy(army);
    final isFragile = strongestSkill == GeneralSkill.fragileMarshal;
    final veteranCommand =
        strongestSkill == GeneralSkill.veteranCommander ||
        strongestSkill == GeneralSkill.warDrummer;
    final flankAssets = composition.rooks + composition.bishops;
    final mobileAssets = composition.knights;
    final frontPressure = composition.pawns + composition.knights;

    final allowed = <BattleFormation>{BattleFormation.balanced};

    if (flankAssets >= 1 || mobileAssets >= 2 || veteranCommand) {
      allowed.add(BattleFormation.flankGuard);
    }

    if (!isFragile && (frontPressure >= 5 || veteranCommand)) {
      allowed.add(BattleFormation.spearhead);
    }

    if (strongestSkill == GeneralSkill.warDrummer) {
      allowed
        ..add(BattleFormation.flankGuard)
        ..add(BattleFormation.spearhead);
    }

    return allowed;
  }

  static GeneralSkill _strongestGeneralSkillInArmy(ArmyDefinition army) {
    GeneralSkill strongest = GeneralSkill.fieldCommander;
    var foundGeneral = false;

    for (final unit in army.units) {
      if (unit.type != PieceType.general || unit.generalSkill == null) {
        continue;
      }
      final skill = unit.generalSkill!;
      if (!foundGeneral ||
          _generalSkillRank(skill) > _generalSkillRank(strongest)) {
        strongest = skill;
      }
      foundGeneral = true;
    }

    return strongest;
  }

  static GeneralSkill _betterGeneralSkill(
    GeneralSkill first,
    GeneralSkill second,
  ) {
    return _generalSkillRank(first) >= _generalSkillRank(second)
        ? first
        : second;
  }

  static List<_DeploymentStyle> _deploymentStylesForSkill(
    GeneralSkill strongestSkill,
  ) {
    final styles = <_DeploymentStyle>[
      const _DeploymentStyle(
        suffix: 'Standard Bearer',
        columnRotation: 0,
        mirrorColumns: false,
        reservePawns: false,
      ),
      const _DeploymentStyle(
        suffix: 'Skirmisher Lanes',
        columnRotation: 1,
        mirrorColumns: false,
        reservePawns: false,
      ),
      const _DeploymentStyle(
        suffix: 'Hammer & Anvil',
        columnRotation: 0,
        mirrorColumns: true,
        reservePawns: true,
      ),
      const _DeploymentStyle(
        suffix: 'Peasant Wall',
        columnRotation: 0,
        mirrorColumns: false,
        reservePawns: true,
        pawnFileLimit: 2,
      ),
    ];

    if (_generalSkillRank(strongestSkill) >=
        _generalSkillRank(GeneralSkill.veteranCommander)) {
      styles.add(
        const _DeploymentStyle(
          suffix: 'Staggered Phalanx',
          columnRotation: 2,
          mirrorColumns: false,
          reservePawns: true,
        ),
      );
    }

    if (strongestSkill == GeneralSkill.warDrummer) {
      styles.add(
        const _DeploymentStyle(
          suffix: 'Drumline Surge',
          columnRotation: 1,
          mirrorColumns: true,
          reservePawns: true,
          pawnFileLimit: 3,
        ),
      );
    }

    return styles;
  }

  static String _formationLabel(BattleFormation formation) {
    switch (formation) {
      case BattleFormation.balanced:
        return 'Shieldwall';
      case BattleFormation.flankGuard:
        return 'Wing Guard';
      case BattleFormation.spearhead:
        return 'Spear Wedge';
    }
  }

  static String _deploymentSummary({
    required BattleFormation formation,
    required _DeploymentStyle style,
    required int rows,
    required int cols,
  }) {
    final base = switch (formation) {
      BattleFormation.balanced => 'Disciplined shieldwall hold',
      BattleFormation.flankGuard => 'Guarded wings and archer lanes',
      BattleFormation.spearhead => 'Aggressive wedge toward center',
    };
    final board = rows * cols <= 36 ? 'compact board' : 'open board';
    return '$base using ${style.suffix.toLowerCase()} on $board.';
  }

  static String _deploymentSignature(List<BattlePiece> pieces) {
    final tokens =
        pieces
            .map(
              (piece) =>
                  '${piece.ownerId}:${piece.type.name}:${piece.position.row},${piece.position.col}',
            )
            .toList()
          ..sort();
    return tokens.join('|');
  }

  BattlePiece? pieceAt(BoardPosition position) {
    for (final piece in pieces) {
      if (piece.position == position) {
        return piece;
      }
    }
    return null;
  }

  BattlePiece? pieceById(String id) {
    for (final piece in pieces) {
      if (piece.id == id) {
        return piece;
      }
    }
    return null;
  }

  bool isBlocked(BoardPosition position) => blockedCells.contains(position);

  int get otherPlayer =>
      activePlayer == southPlayerId ? northPlayerId : southPlayerId;

  List<BattlePiece> piecesForPlayer(int playerId) {
    return pieces.where((piece) => piece.ownerId == playerId).toList();
  }

  int generalsForPlayer(int playerId) {
    return piecesForPlayer(
      playerId,
    ).where((piece) => piece.type == PieceType.general).length;
  }

  bool commanderAlive(int playerId) {
    return generalsForPlayer(playerId) > 0;
  }

  int moraleForPlayer(int playerId) {
    return moraleByPlayer[playerId] ?? maxMorale;
  }

  MoraleState moraleStateForPlayer(int playerId) {
    final morale = moraleForPlayer(playerId);
    if (morale <= 0) {
      return MoraleState.collapsed;
    }
    return _moraleStateFromMoraleAndCommand(
      morale,
      _commandStrengthForPlayer(playerId),
    );
  }

  bool moraleBroken(int playerId) {
    return moraleStateForPlayer(playerId) == MoraleState.collapsed;
  }

  int _commandStrengthForPlayer(int playerId) {
    var score = 0;
    for (final general in generalsForSide(playerId)) {
      score += general.commandWeight;
    }
    return score;
  }

  MoraleState _moraleStateFromMoraleAndCommand(
    int morale,
    int commandStrength,
  ) {
    final routingThreshold = (2 - commandStrength).clamp(1, 3);
    final waveringThreshold = (4 - (commandStrength ~/ 2)).clamp(2, 4);

    if (morale <= routingThreshold) {
      return MoraleState.routing;
    }
    if (morale <= waveringThreshold) {
      return MoraleState.wavering;
    }
    return MoraleState.steady;
  }

  bool hasAnyLegalMove(int playerId) {
    for (final piece in piecesForPlayer(playerId)) {
      if (legalMovesForPiece(piece.id, asPlayerId: playerId).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<BattlePiece> generalsForSide(int playerId) {
    return piecesForPlayer(
      playerId,
    ).where((piece) => piece.type == PieceType.general).toList();
  }

  List<BattleAction> legalActionsForActivePlayer() {
    return legalActionsForPlayer(activePlayer);
  }

  List<BattleAction> legalActionsForPlayer(
    int playerId, {
    bool ignoreOpeningCaptureBlock = false,
  }) {
    final actions = <BattleAction>[];
    for (final piece in piecesForPlayer(playerId)) {
      for (final move in legalMovesForPiece(
        piece.id,
        asPlayerId: playerId,
        ignoreOpeningCaptureBlock: ignoreOpeningCaptureBlock,
      )) {
        actions.add(
          BattleAction(
            pieceId: piece.id,
            to: move,
            capturedPieceId: pieceAt(move)?.id,
          ),
        );
      }
    }
    return actions;
  }

  List<BoardPosition> legalMovesForPiece(
    String pieceId, {
    int? asPlayerId,
    bool ignoreOpeningCaptureBlock = false,
  }) {
    final piece = pieceById(pieceId);
    final playerId = asPlayerId ?? activePlayer;
    if (piece == null || piece.ownerId != playerId) {
      return const [];
    }

    final moves = switch (piece.type) {
      PieceType.pawn => _pawnMoves(piece),
      PieceType.rook => _sliderMoves(piece, const [
        _Vector(1, 0),
        _Vector(-1, 0),
        _Vector(0, 1),
        _Vector(0, -1),
      ]),
      PieceType.bishop => _sliderMoves(piece, const [
        _Vector(1, 1),
        _Vector(1, -1),
        _Vector(-1, 1),
        _Vector(-1, -1),
      ]),
      PieceType.knight => _knightMoves(piece),
      PieceType.general => _generalMoves(piece),
    };

    // If defending, pieces cannot move, but they are harder to capture (implemented in contact resolution).
    if (defendByPlayer[playerId] == true) {
      return const [];
    }

    // If charging, pawns and knights get extra reach but must move forward or capture.
    if (chargeByPlayer[playerId] == true &&
        (piece.type == PieceType.pawn || piece.type == PieceType.knight)) {
      // Basic charge: keep existing moves but emphasize forward momentum.
      // (In a more complex sim, we'd add extra range here).
    }

    if (!ignoreOpeningCaptureBlock &&
        _capturesBlockedForOpening(piece.ownerId)) {
      return moves.where((position) {
        final occupant = pieceAt(position);
        return occupant == null || occupant.ownerId == piece.ownerId;
      }).toList();
    }

    return moves;
  }

  bool _capturesBlockedForOpening(int pieceOwnerId) {
    return disableOpeningCaptures &&
        moveLog.isEmpty &&
        pieceOwnerId == activePlayer;
  }

  bool canAdvanceFrontline({int? asPlayerId}) {
    final playerId = asPlayerId ?? activePlayer;
    if (playerId != activePlayer) {
      return false;
    }
    for (final piece in piecesForPlayer(playerId)) {
      if (piece.type != PieceType.pawn) {
        continue;
      }
      final forward = _forwardSquare(piece);
      if (!forward.inBounds(rows, cols) || isBlocked(forward)) {
        continue;
      }
      final occupant = pieceAt(forward);
      if (occupant == null || occupant.ownerId != piece.ownerId) {
        return true;
      }
    }
    return false;
  }

  GeneralSkill? strongestGeneralSkill(int playerId) {
    final generals = generalsForSide(playerId);
    if (generals.isEmpty) {
      return null;
    }

    GeneralSkill? best;
    for (final general in generals) {
      final skill = general.generalSkill;
      if (skill == null) {
        continue;
      }
      if (best == null) {
        best = skill;
        continue;
      }
      if (_generalSkillRank(skill) > _generalSkillRank(best)) {
        best = skill;
      }
    }

    return best;
  }

  bool canUseGeneralAdvanceSkill({int? asPlayerId}) {
    final playerId = asPlayerId ?? activePlayer;
    if (playerId != activePlayer) {
      return false;
    }
    if (!canAdvanceFrontline(asPlayerId: playerId)) {
      return false;
    }
    if (generalSkillUsedByPlayer[playerId] == true) {
      return false;
    }
    final skill = strongestGeneralSkill(playerId);
    return skill?.grantsMassAdvance == true;
  }

  BattleTurnOverlay? latestTurnOverlay() {
    if (eventLog.isEmpty) {
      return null;
    }
    var latestTurn = 0;
    for (final event in eventLog) {
      if (event.turn > latestTurn) {
        latestTurn = event.turn;
      }
    }
    if (latestTurn <= 0) {
      return null;
    }

    final turnEvents = eventLog
        .where((event) => event.turn == latestTurn)
        .toList();
    if (turnEvents.isEmpty) {
      return null;
    }

    final marksByPosition = <BoardPosition, BattleOverlayMark>{};
    final arrows = <BattleOverlayArrow>[];

    void mark(BoardPosition position, BattleOverlayMark markType) {
      final existing = marksByPosition[position];
      if (existing == null ||
          _overlayMarkPriority(markType) > _overlayMarkPriority(existing)) {
        marksByPosition[position] = markType;
      }
    }

    bool capturesOn(BoardPosition position) {
      return turnEvents.any(
        (event) =>
            event.type == BattleEventType.capture && event.position == position,
      );
    }

    for (final event in turnEvents) {
      final to = event.position;
      final from = event.fromPosition;
      switch (event.type) {
        case BattleEventType.move:
          if (to != null) {
            mark(
              to,
              capturesOn(to)
                  ? BattleOverlayMark.capture
                  : BattleOverlayMark.move,
            );
          }
          if (from != null) {
            mark(from, BattleOverlayMark.move);
          }
          if (from != null && to != null) {
            arrows.add(
              BattleOverlayArrow(
                from: from,
                to: to,
                mark: capturesOn(to)
                    ? BattleOverlayMark.capture
                    : BattleOverlayMark.move,
              ),
            );
          }
        case BattleEventType.capture:
          if (to != null) {
            mark(to, BattleOverlayMark.loss);
          }
        case BattleEventType.advance:
          final lower = event.description.toLowerCase();
          final isTrap = lower.contains('trap');
          final isLoss = lower.contains('repulsed') || lower.contains('fell');
          if (to != null) {
            mark(
              to,
              isTrap
                  ? BattleOverlayMark.hazard
                  : isLoss
                  ? BattleOverlayMark.loss
                  : BattleOverlayMark.move,
            );
          }
          if (from != null) {
            mark(from, BattleOverlayMark.move);
          }
          if (from != null && to != null) {
            arrows.add(
              BattleOverlayArrow(
                from: from,
                to: to,
                mark: isTrap
                    ? BattleOverlayMark.hazard
                    : isLoss
                    ? BattleOverlayMark.loss
                    : BattleOverlayMark.move,
              ),
            );
          }
        case BattleEventType.rout:
          if (to != null) {
            mark(to, BattleOverlayMark.loss);
          }
        case BattleEventType.deployment:
        case BattleEventType.moraleShift:
        case BattleEventType.generalProgress:
        case BattleEventType.generalSkill:
        case BattleEventType.charge:
        case BattleEventType.defend:
          continue;
      }
    }

    if (marksByPosition.isEmpty && arrows.isEmpty) {
      return null;
    }
    arrows.sort(
      (a, b) =>
          _overlayMarkPriority(b.mark).compareTo(_overlayMarkPriority(a.mark)),
    );
    return BattleTurnOverlay(
      turn: latestTurn,
      marksByPosition: marksByPosition,
      arrows: arrows.take(3).toList(),
    );
  }

  BattleState advanceFrontline({int maxUnits = 3}) {
    return _advanceUnits(
      maxUnits: maxUnits,
      fromGeneralSkill: false,
      skillLabel: null,
    );
  }

  bool canCharge() {
    if (chargeByPlayer[activePlayer] == true ||
        defendByPlayer[activePlayer] == true) {
      return false;
    }
    // Need at least 2 pawns/knights to charge.
    final mobileUnits = piecesForPlayer(activePlayer)
        .where((p) => p.type == PieceType.pawn || p.type == PieceType.knight)
        .length;
    return mobileUnits >= 2;
  }

  bool canDefend() {
    if (chargeByPlayer[activePlayer] == true ||
        defendByPlayer[activePlayer] == true) {
      return false;
    }
    return piecesForPlayer(activePlayer).length >= 3;
  }

  BattleState useCharge() {
    if (!canCharge()) {
      return this;
    }
    final turn = moveLog.length + 1;
    final updatedCharge = <int, bool>{...chargeByPlayer, activePlayer: true};
    final event = BattleEvent(
      turn: turn,
      type: BattleEventType.charge,
      actorPlayerId: activePlayer,
      description: 'P${activePlayer + 1} ordered a charge! Momentum increased.',
    );
    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: pieces,
      moveLog: [...moveLog, 'P${activePlayer + 1} Charge'],
      eventLog: [...eventLog, event],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: moraleByPlayer,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: generalSkillUsedByPlayer,
      trapArmedByPlayer: trapArmedByPlayer,
      trapColumnByPlayer: trapColumnByPlayer,
      chargeByPlayer: updatedCharge,
      defendByPlayer: defendByPlayer,
    );
  }

  BattleState useDefend() {
    if (!canDefend()) {
      return this;
    }
    final turn = moveLog.length + 1;
    final updatedDefend = <int, bool>{...defendByPlayer, activePlayer: true};
    final event = BattleEvent(
      turn: turn,
      type: BattleEventType.defend,
      actorPlayerId: activePlayer,
      description: 'P${activePlayer + 1} stands firm! Defense reinforced.',
    );
    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: pieces,
      moveLog: [...moveLog, 'P${activePlayer + 1} Defend'],
      eventLog: [...eventLog, event],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: moraleByPlayer,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: generalSkillUsedByPlayer,
      trapArmedByPlayer: trapArmedByPlayer,
      trapColumnByPlayer: trapColumnByPlayer,
      chargeByPlayer: chargeByPlayer,
      defendByPlayer: updatedDefend,
    );
  }

  BattleState useGeneralAdvanceSkill() {
    if (!canUseGeneralAdvanceSkill()) {
      return this;
    }

    final skill = strongestGeneralSkill(activePlayer);
    if (skill == null) {
      return this;
    }

    final maxUnits = switch (skill) {
      GeneralSkill.warDrummer => 99,
      GeneralSkill.veteranCommander => 5,
      _ => 4,
    };

    return _advanceUnits(
      maxUnits: maxUnits,
      fromGeneralSkill: true,
      skillLabel: skill.publicLabel,
    );
  }

  BattleState _advanceUnits({
    required int maxUnits,
    required bool fromGeneralSkill,
    required String? skillLabel,
  }) {
    if (!canAdvanceFrontline()) {
      return this;
    }

    final candidates = <BattlePiece>[];
    for (final piece in piecesForPlayer(activePlayer)) {
      if (piece.type != PieceType.pawn) {
        continue;
      }
      final forward = _forwardSquare(piece);
      if (!forward.inBounds(rows, cols) || isBlocked(forward)) {
        continue;
      }
      final occupant = pieceAt(forward);
      if (occupant == null || occupant.ownerId != piece.ownerId) {
        candidates.add(piece);
      }
    }

    if (candidates.isEmpty) {
      return this;
    }

    final direction = activePlayer == southPlayerId ? -1 : 1;
    candidates.sort((a, b) {
      if (direction == -1) {
        return a.position.row.compareTo(b.position.row);
      }
      return b.position.row.compareTo(a.position.row);
    });

    final selected = candidates.take(maxUnits).toList();
    final updatedPieces = List<BattlePiece>.from(pieces);
    final updatedMorale = <int, int>{...moraleByPlayer};
    final updatedSkillUse = <int, bool>{...generalSkillUsedByPlayer};
    final updatedTraps = <int, bool>{...trapArmedByPlayer};
    final turn = moveLog.length + 1;
    final events = <BattleEvent>[];
    var movedCount = 0;
    var contactCount = 0;
    var captureCount = 0;
    var clashCount = 0;
    var repulsedCount = 0;

    void pushMoraleDelta({
      required int playerId,
      required int delta,
      required String reason,
      BoardPosition? focalPosition,
    }) {
      final adjustedDelta = focalPosition == null
          ? delta
          : _applyLocalMoralePressure(
              affectedPlayerId: playerId,
              baseDelta: delta,
              focalPosition: focalPosition,
              boardPieces: updatedPieces,
            );
      final before = updatedMorale[playerId] ?? maxMorale;
      final after = _clampMorale(before + adjustedDelta);
      if (before == after) {
        return;
      }
      updatedMorale[playerId] = after;
      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.moraleShift,
          actorPlayerId: playerId,
          delta: after - before,
          position: focalPosition,
          description:
              'P${playerId + 1} morale $before->$after ($reason, local ${adjustedDelta >= 0 ? '+' : ''}$adjustedDelta).',
        ),
      );
    }

    BattlePiece? pieceAtInList(BoardPosition position) {
      for (final piece in updatedPieces) {
        if (piece.position == position) {
          return piece;
        }
      }
      return null;
    }

    for (final selectedPawn in selected) {
      final attackerIndex = updatedPieces.indexWhere(
        (piece) => piece.id == selectedPawn.id,
      );
      if (attackerIndex < 0) {
        continue;
      }

      final attacker = updatedPieces[attackerIndex];
      final forward = _forwardSquare(attacker);
      if (!forward.inBounds(rows, cols) || isBlocked(forward)) {
        continue;
      }

      final target = pieceAtInList(forward);
      if (target == null) {
        final trapOwner = otherPlayer;
        final trapCol = trapColumnByPlayer[trapOwner];
        if (updatedTraps[trapOwner] == true &&
            trapCol != null &&
            trapCol == forward.col) {
          updatedPieces.removeWhere((piece) => piece.id == attacker.id);
          repulsedCount++;
          updatedTraps[trapOwner] = false;
          pushMoraleDelta(
            playerId: attacker.ownerId,
            delta: -1,
            reason: 'defensive ditch trap',
            focalPosition: forward,
          );
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.advance,
              actorPlayerId: trapOwner,
              targetPlayerId: attacker.ownerId,
              pieceId: attacker.id,
              fromPosition: attacker.position,
              position: forward,
              description:
                  'P${trapOwner + 1} ditch trap disrupted advancing militia on file $trapCol.',
            ),
          );
          continue;
        }

        updatedPieces[attackerIndex] = attacker.copyWith(position: forward);
        movedCount++;
        events.add(
          BattleEvent(
            turn: turn,
            type: BattleEventType.move,
            actorPlayerId: attacker.ownerId,
            pieceId: attacker.id,
            fromPosition: attacker.position,
            position: forward,
            description:
                'P${attacker.ownerId + 1} advanced ${attacker.type.name} to (${forward.row},${forward.col}).',
          ),
        );
        continue;
      }
      if (target.ownerId == attacker.ownerId) {
        continue;
      }

      contactCount++;
      final outcome = _resolveAdvanceContact(
        attacker: attacker,
        defender: target,
        fromGeneralSkill: fromGeneralSkill,
        attackerPressure: _commandStrengthForPlayerFromPieces(
          attacker.ownerId,
          updatedPieces,
        ),
        defenderPressure: _commandStrengthForPlayerFromPieces(
          target.ownerId,
          updatedPieces,
        ),
      );

      switch (outcome) {
        case _AdvanceContactOutcome.capture:
          final defenderIndex = updatedPieces.indexWhere(
            (piece) => piece.id == target.id,
          );
          if (defenderIndex >= 0) {
            updatedPieces.removeAt(defenderIndex);
          }
          final shiftedIndex = updatedPieces.indexWhere(
            (piece) => piece.id == attacker.id,
          );
          if (shiftedIndex >= 0) {
            updatedPieces[shiftedIndex] = updatedPieces[shiftedIndex].copyWith(
              position: forward,
            );
          }
          captureCount++;
          movedCount++;
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.capture,
              actorPlayerId: attacker.ownerId,
              targetPlayerId: target.ownerId,
              pieceId: target.id,
              fromPosition: attacker.position,
              position: forward,
              description:
                  'P${attacker.ownerId + 1} broke contact and captured ${target.type.name} at (${forward.row},${forward.col}).',
            ),
          );
          pushMoraleDelta(
            playerId: target.ownerId,
            delta: -_moraleLossForCapture(target.type),
            reason: 'advance contact loss',
            focalPosition: forward,
          );
          if (target.type == PieceType.general) {
            pushMoraleDelta(
              playerId: attacker.ownerId,
              delta: 1,
              reason: 'enemy commander broken in contact',
              focalPosition: forward,
            );
          }
        case _AdvanceContactOutcome.clash:
          updatedPieces.removeWhere(
            (piece) => piece.id == attacker.id || piece.id == target.id,
          );
          clashCount++;
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.advance,
              actorPlayerId: attacker.ownerId,
              targetPlayerId: target.ownerId,
              pieceId: attacker.id,
              fromPosition: attacker.position,
              position: forward,
              description:
                  'P${attacker.ownerId + 1} and P${target.ownerId + 1} clashed and both units fell at (${forward.row},${forward.col}).',
            ),
          );
          pushMoraleDelta(
            playerId: attacker.ownerId,
            delta: -1,
            reason: 'contact clash losses',
            focalPosition: forward,
          );
          pushMoraleDelta(
            playerId: target.ownerId,
            delta: -1,
            reason: 'contact clash losses',
            focalPosition: forward,
          );
        case _AdvanceContactOutcome.repulsed:
          updatedPieces.removeWhere((piece) => piece.id == attacker.id);
          repulsedCount++;
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.advance,
              actorPlayerId: target.ownerId,
              targetPlayerId: attacker.ownerId,
              pieceId: attacker.id,
              fromPosition: attacker.position,
              position: forward,
              description:
                  'P${target.ownerId + 1} repulsed contact from P${attacker.ownerId + 1} at (${forward.row},${forward.col}).',
            ),
          );
          pushMoraleDelta(
            playerId: attacker.ownerId,
            delta: -1,
            reason: 'repulsed during contact advance',
            focalPosition: forward,
          );
      }
    }

    if (movedCount == 0 &&
        captureCount == 0 &&
        clashCount == 0 &&
        repulsedCount == 0) {
      return this;
    }

    final activeSkill = strongestGeneralSkill(activePlayer);
    final activeTrait = activeSkill?.traitFamily;

    final currentMorale = moraleForPlayer(activePlayer);
    // Momentum trait allows morale boost from less momentum (1 move/capture vs 2).
    final momentumThreshold = activeTrait == GeneralTraitFamily.momentum
        ? 1
        : 2;
    final moraleBoost =
        (movedCount + captureCount) >= momentumThreshold || fromGeneralSkill
        ? 1
        : 0;
    var boostedMorale = currentMorale;
    if (moraleBoost > 0 && currentMorale < maxMorale) {
      boostedMorale = _clampMorale(currentMorale + moraleBoost);
      updatedMorale[activePlayer] = boostedMorale;
      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.moraleShift,
          actorPlayerId: activePlayer,
          delta: boostedMorale - currentMorale,
          description:
              'Player ${activePlayer + 1} morale $currentMorale->$boostedMorale.',
        ),
      );
    }

    if (fromGeneralSkill) {
      updatedSkillUse[activePlayer] = true;
    }

    final logEntry = fromGeneralSkill
        ? 'Skill ${skillLabel ?? 'General'}: P${activePlayer + 1} advanced $movedCount, contacts $contactCount.'
        : 'Advance P${activePlayer + 1}: moved $movedCount, contacts $contactCount.';

    events.insert(
      0,
      BattleEvent(
        turn: turn,
        type: fromGeneralSkill
            ? BattleEventType.generalSkill
            : BattleEventType.advance,
        actorPlayerId: activePlayer,
        description:
            '$logEntry Captures: $captureCount, clashes: $clashCount, repulsed: $repulsedCount.',
      ),
    );

    final retreat = _resolveFragileRetreat(
      boardPieces: updatedPieces,
      moraleByPlayer: updatedMorale,
      turn: turn,
    );

    final rout = _resolveRoutPressure(
      boardPieces: retreat.pieces,
      moraleByPlayer: updatedMorale,
      turn: turn,
    );
    final finalEvents = [...events, ...retreat.events, ...rout.events];
    final finalLog = retreat.logSuffix == null
        ? logEntry
        : '$logEntry | ${retreat.logSuffix}';
    final routLog = rout.logSuffix == null
        ? finalLog
        : '$finalLog | ${rout.logSuffix}';

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: rout.pieces,
      moveLog: [...moveLog, routLog],
      eventLog: [...eventLog, ...finalEvents],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: updatedMorale,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: updatedSkillUse,
      trapArmedByPlayer: updatedTraps,
      trapColumnByPlayer: trapColumnByPlayer,
      chargeByPlayer: chargeByPlayer,
      defendByPlayer: defendByPlayer,
    );
  }

  BattleState movePiece({required String pieceId, required BoardPosition to}) {
    final movingPiece = pieceById(pieceId);
    if (movingPiece == null) {
      return this;
    }

    final legalMoves = legalMovesForPiece(pieceId);
    if (!legalMoves.contains(to)) {
      return this;
    }

    final target = pieceAt(to);

    final updatedPieces = <BattlePiece>[];
    BattlePiece? movedPiece;

    for (final piece in pieces) {
      if (piece.id == pieceId) {
        var moved = piece.copyWith(position: to);
        if (target != null && piece.type == PieceType.general) {
          moved = moved.gainGeneralExperience();
        }
        movedPiece = moved;
        updatedPieces.add(moved);
        continue;
      }

      if (target != null && piece.id == target.id) {
        continue;
      }

      updatedPieces.add(piece);
    }

    final moverLabel = '${_pieceCode(movingPiece)}${movingPiece.ownerId + 1}';
    final captureLabel = target == null
        ? ''
        : ' x${_pieceCode(target)}${target.ownerId + 1}';
    var logEntry = '$moverLabel -> (${to.row},${to.col})$captureLabel';

    final turn = moveLog.length + 1;
    final events = <BattleEvent>[
      BattleEvent(
        turn: turn,
        type: BattleEventType.move,
        actorPlayerId: movingPiece.ownerId,
        pieceId: movingPiece.id,
        fromPosition: movingPiece.position,
        position: to,
        description:
            'P${movingPiece.ownerId + 1} moved '
            '${movingPiece.type.name} to (${to.row},${to.col}).',
      ),
    ];

    final updatedMorale = <int, int>{...moraleByPlayer};

    if (target != null) {
      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.capture,
          actorPlayerId: movingPiece.ownerId,
          targetPlayerId: target.ownerId,
          pieceId: target.id,
          fromPosition: movingPiece.position,
          position: to,
          description:
              'P${movingPiece.ownerId + 1} captured '
              '${target.type.name} from P${target.ownerId + 1}.',
        ),
      );

      final moraleLoss = _moraleLossForCapture(target.type);
      final defenderMorale = moraleForPlayer(target.ownerId);
      final localizedLoss = _applyLocalMoralePressure(
        affectedPlayerId: target.ownerId,
        baseDelta: -moraleLoss,
        focalPosition: to,
        boardPieces: updatedPieces,
      );
      final reducedMorale = _clampMorale(defenderMorale + localizedLoss);
      if (reducedMorale != defenderMorale) {
        updatedMorale[target.ownerId] = reducedMorale;
        events.add(
          BattleEvent(
            turn: turn,
            type: BattleEventType.moraleShift,
            actorPlayerId: movingPiece.ownerId,
            targetPlayerId: target.ownerId,
            delta: reducedMorale - defenderMorale,
            position: to,
            description:
                'P${target.ownerId + 1} morale '
                '$defenderMorale->$reducedMorale.',
          ),
        );
      }

      if (target.type == PieceType.general) {
        final attackerMorale = moraleForPlayer(movingPiece.ownerId);
        final localizedBoost = _applyLocalMoralePressure(
          affectedPlayerId: movingPiece.ownerId,
          baseDelta: 1,
          focalPosition: to,
          boardPieces: updatedPieces,
        );
        final boostedMorale = _clampMorale(attackerMorale + localizedBoost);
        if (boostedMorale != attackerMorale) {
          updatedMorale[movingPiece.ownerId] = boostedMorale;
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.moraleShift,
              actorPlayerId: movingPiece.ownerId,
              delta: boostedMorale - attackerMorale,
              position: to,
              description:
                  'P${movingPiece.ownerId + 1} morale '
                  '$attackerMorale->$boostedMorale after commander takedown.',
            ),
          );
        }
      }

      final upgradedGeneral = movedPiece;
      if (movingPiece.type == PieceType.general && upgradedGeneral != null) {
        if (upgradedGeneral.generalExperience !=
            movingPiece.generalExperience) {
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.generalProgress,
              actorPlayerId: movingPiece.ownerId,
              pieceId: movingPiece.id,
              description:
                  'General gained XP '
                  '${movingPiece.generalExperience}->${upgradedGeneral.generalExperience}.',
            ),
          );
        }
        if (upgradedGeneral.generalSkill != movingPiece.generalSkill) {
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.generalProgress,
              actorPlayerId: movingPiece.ownerId,
              pieceId: movingPiece.id,
              description:
                  'General adapted to ${upgradedGeneral.generalSkill?.publicLabel}.',
            ),
          );
        }
      }
    }

    final retreat = _resolveFragileRetreat(
      boardPieces: updatedPieces,
      moraleByPlayer: updatedMorale,
      turn: turn,
    );
    final rout = _resolveRoutPressure(
      boardPieces: retreat.pieces,
      moraleByPlayer: updatedMorale,
      turn: turn,
    );

    if (retreat.logSuffix != null) {
      logEntry = '$logEntry | ${retreat.logSuffix}';
    }
    if (rout.logSuffix != null) {
      logEntry = '$logEntry | ${rout.logSuffix}';
    }

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: rout.pieces,
      moveLog: [...moveLog, logEntry],
      eventLog: [...eventLog, ...events, ...retreat.events, ...rout.events],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: updatedMorale,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: generalSkillUsedByPlayer,
      trapArmedByPlayer: trapArmedByPlayer,
      trapColumnByPlayer: trapColumnByPlayer,
      chargeByPlayer: chargeByPlayer,
      defendByPlayer: defendByPlayer,
    );
  }

  _RetreatResolution _resolveFragileRetreat({
    required List<BattlePiece> boardPieces,
    required Map<int, int> moraleByPlayer,
    required int turn,
  }) {
    var currentPieces = boardPieces;
    final events = <BattleEvent>[];
    final notes = <String>[];

    for (final playerId in [southPlayerId, northPlayerId]) {
      if (!_hasFragileGeneral(playerId, currentPieces)) {
        continue;
      }
      if (!_isFragileGeneralThreatened(playerId, currentPieces)) {
        continue;
      }

      final retreatOutcome = _retreatUnits(
        pieces: currentPieces,
        playerId: playerId,
        maxUnits: 3,
      );
      if (retreatOutcome.movedCount == 0) {
        continue;
      }

      currentPieces = retreatOutcome.pieces;
      final beforeMorale = moraleByPlayer[playerId] ?? maxMorale;
      final afterMorale = _clampMorale(beforeMorale - 1);
      moraleByPlayer[playerId] = afterMorale;

      notes.add('P${playerId + 1} panic retreat');
      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.generalSkill,
          actorPlayerId: playerId,
          delta: -1,
          description:
              'P${playerId + 1} fragile marshal panicked: '
              '${retreatOutcome.movedCount} units retreated.',
        ),
      );
      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.moraleShift,
          actorPlayerId: playerId,
          delta: -1,
          description: 'P${playerId + 1} morale $beforeMorale->$afterMorale.',
        ),
      );
    }

    return _RetreatResolution(
      pieces: currentPieces,
      events: events,
      logSuffix: notes.isEmpty ? null : notes.join(', '),
    );
  }

  _AdvanceContactOutcome _resolveAdvanceContact({
    required BattlePiece attacker,
    required BattlePiece defender,
    required bool fromGeneralSkill,
    required int attackerPressure,
    required int defenderPressure,
  }) {
    // Aggression trait increases contact impact (+1 swing).
    final attackerTrait = strongestGeneralSkill(attacker.ownerId)?.traitFamily;
    final aggressionBonus = attackerTrait == GeneralTraitFamily.aggression
        ? 1
        : 0;

    final attackerCharging = chargeByPlayer[attacker.ownerId] == true;
    final defenderDefending = defendByPlayer[defender.ownerId] == true;

    final swing =
        (fromGeneralSkill ? 1 : 0) +
        (attackerCharging ? 1 : 0) -
        (defenderDefending ? 1 : 0) +
        aggressionBonus +
        attackerPressure -
        defenderPressure +
        (_pieceImpact(defender.type) >= _pieceImpact(attacker.type) ? 1 : 0);

    if (swing >= 2) {
      return _AdvanceContactOutcome.capture;
    }
    if (swing >= 0) {
      return _AdvanceContactOutcome.clash;
    }
    return _AdvanceContactOutcome.repulsed;
  }

  _RoutResolution _resolveRoutPressure({
    required List<BattlePiece> boardPieces,
    required Map<int, int> moraleByPlayer,
    required int turn,
  }) {
    var currentPieces = boardPieces;
    final events = <BattleEvent>[];
    final notes = <String>[];

    for (final playerId in [southPlayerId, northPlayerId]) {
      final morale = moraleByPlayer[playerId] ?? maxMorale;
      final command = _commandStrengthForPlayerFromPieces(
        playerId,
        currentPieces,
      );
      final state = morale <= 0
          ? MoraleState.collapsed
          : _moraleStateFromMoraleAndCommand(morale, command);
      if (state != MoraleState.routing) {
        continue;
      }

      final rallyScore = morale + command;
      if (rallyScore >= 4) {
        final after = _clampMorale(morale + 1);
        moraleByPlayer[playerId] = after;
        events.add(
          BattleEvent(
            turn: turn,
            type: BattleEventType.rout,
            actorPlayerId: playerId,
            delta: after - morale,
            description:
                'P${playerId + 1} rallied from routing pressure ($morale->$after).',
          ),
        );
        notes.add('P${playerId + 1} rallied');
        continue;
      }

      final retreat = _retreatUnits(
        pieces: currentPieces,
        playerId: playerId,
        maxUnits: command <= 1 ? 3 : 2,
      );
      currentPieces = retreat.pieces;
      var deserted = 0;
      if (retreat.movedCount == 0) {
        final desertResult = _desertUnits(
          pieces: currentPieces,
          playerId: playerId,
          maxUnits: command <= 1 ? 2 : 1,
        );
        currentPieces = desertResult.pieces;
        deserted = desertResult.movedCount;
      } else if (command == 0) {
        final desertResult = _desertUnits(
          pieces: currentPieces,
          playerId: playerId,
          maxUnits: 1,
        );
        currentPieces = desertResult.pieces;
        deserted = desertResult.movedCount;
      }

      final afterMorale = _clampMorale(morale - 1);
      moraleByPlayer[playerId] = afterMorale;

      events.add(
        BattleEvent(
          turn: turn,
          type: BattleEventType.rout,
          actorPlayerId: playerId,
          delta: afterMorale - morale,
          description:
              'P${playerId + 1} routing: ${retreat.movedCount} withdrew, $deserted deserted, morale $morale->$afterMorale.',
        ),
      );
      notes.add(
        'P${playerId + 1} routing (${retreat.movedCount} withdrew, $deserted deserted)',
      );
    }

    return _RoutResolution(
      pieces: currentPieces,
      events: events,
      logSuffix: notes.isEmpty ? null : notes.join(', '),
    );
  }

  int _commandStrengthForPlayerFromPieces(
    int playerId,
    List<BattlePiece> boardPieces,
  ) {
    var score = 0;
    for (final piece in boardPieces) {
      if (piece.ownerId != playerId || piece.type != PieceType.general) {
        continue;
      }
      score += piece.commandWeight;
    }
    return score;
  }

  _RetreatOutcome _desertUnits({
    required List<BattlePiece> pieces,
    required int playerId,
    required int maxUnits,
  }) {
    final mutable = List<BattlePiece>.from(pieces);
    final casualties = mutable
        .where(
          (piece) =>
              piece.ownerId == playerId && piece.type != PieceType.general,
        )
        .toList();

    casualties.sort((a, b) {
      final frontA = playerId == southPlayerId
          ? -a.position.row
          : a.position.row;
      final frontB = playerId == southPlayerId
          ? -b.position.row
          : b.position.row;
      return frontB.compareTo(frontA);
    });

    final doomed = casualties.take(maxUnits).map((piece) => piece.id).toSet();
    mutable.removeWhere((piece) => doomed.contains(piece.id));
    return _RetreatOutcome(pieces: mutable, movedCount: doomed.length);
  }

  bool _hasFragileGeneral(int playerId, List<BattlePiece> boardPieces) {
    for (final piece in boardPieces) {
      if (piece.ownerId != playerId || piece.type != PieceType.general) {
        continue;
      }
      if (piece.generalSkill == GeneralSkill.fragileMarshal) {
        return true;
      }
    }
    return false;
  }

  bool _isFragileGeneralThreatened(
    int playerId,
    List<BattlePiece> boardPieces,
  ) {
    final fragileGenerals = boardPieces
        .where(
          (piece) =>
              piece.ownerId == playerId &&
              piece.type == PieceType.general &&
              piece.generalSkill == GeneralSkill.fragileMarshal,
        )
        .toList();
    if (fragileGenerals.isEmpty) {
      return false;
    }

    final probeState = BattleState(
      rows: rows,
      cols: cols,
      activePlayer: playerId,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: boardPieces,
      moveLog: const <String>[],
      blockedCells: blockedCells,
      disableOpeningCaptures: false,
      moraleByPlayer: moraleByPlayer,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: generalSkillUsedByPlayer,
    );

    final threatenedSquares = fragileGenerals
        .map((general) => general.position)
        .toSet();

    for (final piece in boardPieces) {
      if (piece.ownerId == playerId) {
        continue;
      }
      final moves = probeState.legalMovesForPiece(
        piece.id,
        asPlayerId: piece.ownerId,
        ignoreOpeningCaptureBlock: true,
      );
      for (final move in moves) {
        if (threatenedSquares.contains(move)) {
          return true;
        }
      }
    }

    return false;
  }

  _RetreatOutcome _retreatUnits({
    required List<BattlePiece> pieces,
    required int playerId,
    required int maxUnits,
  }) {
    final retreatDirection = playerId == southPlayerId ? 1 : -1;
    final movable = pieces
        .where(
          (piece) =>
              piece.ownerId == playerId && piece.type != PieceType.general,
        )
        .toList();

    movable.sort((a, b) {
      if (playerId == southPlayerId) {
        return a.position.row.compareTo(b.position.row);
      }
      return b.position.row.compareTo(a.position.row);
    });

    final mutable = List<BattlePiece>.from(pieces);
    final occupied = <BoardPosition, String>{
      for (final piece in mutable) piece.position: piece.id,
    };

    var moved = 0;
    for (final unit in movable) {
      if (moved >= maxUnits) {
        break;
      }
      final retreatTo = unit.position.offset(retreatDirection, 0);
      if (!retreatTo.inBounds(rows, cols)) {
        continue;
      }
      if (isBlocked(retreatTo)) {
        continue;
      }
      if (occupied.containsKey(retreatTo)) {
        continue;
      }

      final index = mutable.indexWhere((piece) => piece.id == unit.id);
      if (index < 0) {
        continue;
      }
      occupied.remove(unit.position);
      occupied[retreatTo] = unit.id;
      mutable[index] = mutable[index].copyWith(position: retreatTo);
      moved++;
    }

    return _RetreatOutcome(pieces: mutable, movedCount: moved);
  }

  int _applyLocalMoralePressure({
    required int affectedPlayerId,
    required int baseDelta,
    required BoardPosition focalPosition,
    required List<BattlePiece> boardPieces,
  }) {
    var adjusted = baseDelta;
    final friendlyGeneralsNearby = _countNearbyPieces(
      playerId: affectedPlayerId,
      focalPosition: focalPosition,
      boardPieces: boardPieces,
      generalsOnly: true,
      maxDistance: 2,
    );
    final enemyGeneralsNearby = _countNearbyPieces(
      playerId: affectedPlayerId == southPlayerId
          ? northPlayerId
          : southPlayerId,
      focalPosition: focalPosition,
      boardPieces: boardPieces,
      generalsOnly: true,
      maxDistance: 2,
    );

    final activeTrait = strongestGeneralSkill(affectedPlayerId)?.traitFamily;

    if (baseDelta < 0) {
      if (friendlyGeneralsNearby > 0) {
        adjusted += 1;
      }
      // Stability mitigates morale loss.
      if (activeTrait == GeneralTraitFamily.stability) {
        adjusted += 1;
      }
      // Volatility amplifies morale loss.
      if (activeTrait == GeneralTraitFamily.volatility) {
        adjusted -= 1;
      }
      if (_hasFriendlyCohesionNear(
        playerId: affectedPlayerId,
        focalPosition: focalPosition,
        boardPieces: boardPieces,
      )) {
        adjusted += 1;
      }
      final nearbyAllies = _countNearbyPieces(
        playerId: affectedPlayerId,
        focalPosition: focalPosition,
        boardPieces: boardPieces,
        generalsOnly: false,
        maxDistance: 2,
      );
      if (nearbyAllies <= 1) {
        adjusted -= 1;
      }
      if (enemyGeneralsNearby > 0) {
        adjusted -= 1;
      }
    } else if (baseDelta > 0) {
      if (friendlyGeneralsNearby > 0) {
        adjusted += 1;
      }
      // Volatility amplifies morale gain.
      if (activeTrait == GeneralTraitFamily.volatility) {
        adjusted += 1;
      }
      if (enemyGeneralsNearby > 0) {
        adjusted += 1;
      }
    }

    adjusted = adjusted.clamp(baseDelta - 2, baseDelta + 2).toInt();
    if (baseDelta < 0 && adjusted >= 0) {
      return -1;
    }
    if (baseDelta > 0 && adjusted <= 0) {
      return 1;
    }
    return adjusted;
  }

  int _countNearbyPieces({
    required int playerId,
    required BoardPosition focalPosition,
    required List<BattlePiece> boardPieces,
    required bool generalsOnly,
    required int maxDistance,
  }) {
    var count = 0;
    for (final piece in boardPieces) {
      if (piece.ownerId != playerId) {
        continue;
      }
      if (generalsOnly && piece.type != PieceType.general) {
        continue;
      }
      final distance =
          (piece.position.row - focalPosition.row).abs() +
          (piece.position.col - focalPosition.col).abs();
      if (distance <= maxDistance) {
        count++;
      }
    }
    return count;
  }

  bool _hasFriendlyCohesionNear({
    required int playerId,
    required BoardPosition focalPosition,
    required List<BattlePiece> boardPieces,
  }) {
    var adjacentAllies = 0;
    for (final piece in boardPieces) {
      if (piece.ownerId != playerId || piece.type == PieceType.general) {
        continue;
      }
      final distance =
          (piece.position.row - focalPosition.row).abs() +
          (piece.position.col - focalPosition.col).abs();
      if (distance == 1) {
        adjacentAllies++;
      }
      if (adjacentAllies >= 2) {
        return true;
      }
    }
    return false;
  }

  int _clampMorale(int value) {
    return value.clamp(0, maxMorale).toInt();
  }

  static int _generalSkillRank(GeneralSkill skill) {
    switch (skill) {
      case GeneralSkill.fragileMarshal:
        return 0;
      case GeneralSkill.fieldCommander:
        return 1;
      case GeneralSkill.veteranCommander:
        return 2;
      case GeneralSkill.warDrummer:
        return 3;
    }
  }

  static int _moraleLossForCapture(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 1;
      case PieceType.knight:
      case PieceType.bishop:
        return 2;
      case PieceType.rook:
        return 2;
      case PieceType.general:
        return 3;
    }
  }

  static int _pieceImpact(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 1;
      case PieceType.knight:
      case PieceType.bishop:
        return 2;
      case PieceType.rook:
        return 3;
      case PieceType.general:
        return 4;
    }
  }

  static int _overlayMarkPriority(BattleOverlayMark mark) {
    switch (mark) {
      case BattleOverlayMark.loss:
        return 4;
      case BattleOverlayMark.capture:
        return 3;
      case BattleOverlayMark.hazard:
        return 2;
      case BattleOverlayMark.move:
        return 1;
    }
  }

  static String _pieceCode(BattlePiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return '♟';
      case PieceType.rook:
        return '♜';
      case PieceType.knight:
        return '♞';
      case PieceType.bishop:
        return '♝';
      case PieceType.general:
        switch (piece.generalSkill) {
          case GeneralSkill.fragileMarshal:
            return '♔';
          case GeneralSkill.warDrummer:
            return '♕';
          case GeneralSkill.veteranCommander:
            return '♛';
          case GeneralSkill.fieldCommander:
          case null:
            return '♚';
        }
    }
  }

  BoardPosition _forwardSquare(BattlePiece piece) {
    final direction = piece.ownerId == southPlayerId ? -1 : 1;
    return piece.position.offset(direction, 0);
  }

  List<BoardPosition> _pawnMoves(BattlePiece piece) {
    final direction = piece.ownerId == southPlayerId ? -1 : 1;
    final startingRow = piece.ownerId == southPlayerId ? rows - 2 : 1;
    final oneStepForward = piece.position.offset(direction, 0);
    final moves = <BoardPosition>[];

    if (_isOpenSquare(oneStepForward)) {
      moves.add(oneStepForward);

      final atStartingRow = piece.position.row == startingRow;
      if (atStartingRow) {
        final twoStepsForward = piece.position.offset(direction * 2, 0);
        if (_isOpenSquare(twoStepsForward)) {
          moves.add(twoStepsForward);
        }
      }
    }

    final forwardBlocked =
        !oneStepForward.inBounds(rows, cols) ||
        isBlocked(oneStepForward) ||
        pieceAt(oneStepForward) != null;
    if (forwardBlocked) {
      for (final sideDelta in const [-1, 1]) {
        final sideStep = piece.position.offset(0, sideDelta);
        if (_isOpenSquare(sideStep)) {
          moves.add(sideStep);
        }
      }
    }

    for (final colDelta in const [-1, 1]) {
      final captureSquare = piece.position.offset(direction, colDelta);
      if (!captureSquare.inBounds(rows, cols) || isBlocked(captureSquare)) {
        continue;
      }
      final occupant = pieceAt(captureSquare);
      if (occupant != null && occupant.ownerId != piece.ownerId) {
        moves.add(captureSquare);
      }
    }

    return moves;
  }

  List<BoardPosition> _knightMoves(BattlePiece piece) {
    final moves = <BoardPosition>[];
    for (final vector in const [
      _Vector(2, 1),
      _Vector(2, -1),
      _Vector(-2, 1),
      _Vector(-2, -1),
      _Vector(1, 2),
      _Vector(1, -2),
      _Vector(-1, 2),
      _Vector(-1, -2),
    ]) {
      final next = piece.position.offset(vector.rowDelta, vector.colDelta);
      if (!next.inBounds(rows, cols) || isBlocked(next)) {
        continue;
      }
      final occupant = pieceAt(next);
      if (occupant == null || occupant.ownerId != piece.ownerId) {
        moves.add(next);
      }
    }
    return moves;
  }

  List<BoardPosition> _generalMoves(BattlePiece piece) {
    final moves = <BoardPosition>[];

    for (final vector in const [
      _Vector(1, 0),
      _Vector(-1, 0),
      _Vector(0, 1),
      _Vector(0, -1),
      _Vector(1, 1),
      _Vector(1, -1),
      _Vector(-1, 1),
      _Vector(-1, -1),
    ]) {
      final next = piece.position.offset(vector.rowDelta, vector.colDelta);
      if (!next.inBounds(rows, cols) || isBlocked(next)) {
        continue;
      }

      final occupant = pieceAt(next);
      if (occupant == null || occupant.ownerId != piece.ownerId) {
        moves.add(next);
      }
    }

    return moves;
  }

  List<BoardPosition> _sliderMoves(
    BattlePiece piece,
    List<_Vector> directions,
  ) {
    final moves = <BoardPosition>[];
    for (final direction in directions) {
      var next = piece.position.offset(direction.rowDelta, direction.colDelta);
      while (next.inBounds(rows, cols) && !isBlocked(next)) {
        final occupant = pieceAt(next);
        if (occupant == null) {
          moves.add(next);
          next = next.offset(direction.rowDelta, direction.colDelta);
          continue;
        }

        if (occupant.ownerId != piece.ownerId) {
          moves.add(next);
        }
        break;
      }
    }
    return moves;
  }

  bool _isOpenSquare(BoardPosition position) {
    return position.inBounds(rows, cols) &&
        !isBlocked(position) &&
        pieceAt(position) == null;
  }

  static List<BattlePiece> _deployArmy({
    required ArmyDefinition army,
    required int ownerId,
    required bool sideIsNorth,
    required int rows,
    required int cols,
    required String idPrefix,
    required Set<BoardPosition> blockedCells,
    required Set<BoardPosition> occupiedCells,
    required BattleFormation formation,
    int columnRotation = 0,
    bool mirrorColumns = false,
    bool reservePawns = false,
    int? pawnFileLimit,
  }) {
    final used = <BoardPosition>{...occupiedCells};
    final pieces = <BattlePiece>[];
    final rowsFromBackToFront = sideIsNorth
        ? List<int>.generate(rows, (index) => index)
        : List<int>.generate(rows, (index) => rows - 1 - index);
    final homeRows = rowsFromBackToFront.take((rows / 2).ceil()).toList();
    final backRow = homeRows.first;
    final frontRow = homeRows.length > 1 ? homeRows[1] : backRow;
    final reserveRows = homeRows
        .where((row) => row != backRow && row != frontRow)
        .toList();

    final centerColumns = _applyColumnVariant(
      _centerOutColumns(cols),
      cols: cols,
      rotation: columnRotation,
      mirrored: mirrorColumns,
    );
    final edgeColumns = _applyColumnVariant(
      _edgeInColumns(cols),
      cols: cols,
      rotation: columnRotation,
      mirrored: mirrorColumns,
    );
    final knightColumns = _columnsFromIndex(edgeColumns, 2);
    final bishopColumns = _columnsFromIndex(edgeColumns, 4);
    final spearColumns = _mergeColumnOrders(
      centerColumns,
      _columnsFromIndex(centerColumns, 2),
    );

    var nextIndex = 0;
    var hasHighKingAssigned = false;

    List<int> columnsFor(ArmyUnit unit) {
      if (unit.type == PieceType.pawn && pawnFileLimit != null) {
        return _pawnStackColumns(
          centerColumns,
          cols,
          preferredFiles: pawnFileLimit,
        );
      }
      switch (formation) {
        case BattleFormation.balanced:
          switch (unit.type) {
            case PieceType.pawn:
              return centerColumns;
            case PieceType.general:
              return centerColumns;
            case PieceType.rook:
              return edgeColumns;
            case PieceType.knight:
              return _mergeColumnOrders(knightColumns, centerColumns);
            case PieceType.bishop:
              return _mergeColumnOrders(bishopColumns, centerColumns);
          }
        case BattleFormation.flankGuard:
          switch (unit.type) {
            case PieceType.pawn:
              return edgeColumns;
            case PieceType.general:
              return centerColumns;
            case PieceType.rook:
              return edgeColumns;
            case PieceType.knight:
              return _mergeColumnOrders(edgeColumns, centerColumns);
            case PieceType.bishop:
              return _mergeColumnOrders(edgeColumns, bishopColumns);
          }
        case BattleFormation.spearhead:
          switch (unit.type) {
            case PieceType.pawn:
              return spearColumns;
            case PieceType.general:
              return spearColumns;
            case PieceType.rook:
              return _mergeColumnOrders(centerColumns, edgeColumns);
            case PieceType.knight:
              return _mergeColumnOrders(spearColumns, knightColumns);
            case PieceType.bishop:
              return _mergeColumnOrders(spearColumns, bishopColumns);
          }
      }
    }

    List<int> rowsFor(ArmyUnit unit) {
      if (unit.type == PieceType.pawn) {
        if (reservePawns && reserveRows.isNotEmpty) {
          return [
            frontRow,
            reserveRows.last,
            ...reserveRows.take(reserveRows.length - 1),
            backRow,
          ];
        }
        return [frontRow, ...reserveRows, backRow];
      }
      return [backRow, ...reserveRows, frontRow];
    }

    List<ArmyUnit> sortedUnits() {
      final pawns = army.units.where((unit) => unit.type == PieceType.pawn);
      final generals = army.units.where(
        (unit) => unit.type == PieceType.general,
      );
      final rooks = army.units.where((unit) => unit.type == PieceType.rook);
      final knights = army.units.where((unit) => unit.type == PieceType.knight);
      final bishops = army.units.where((unit) => unit.type == PieceType.bishop);
      return [...pawns, ...generals, ...rooks, ...knights, ...bishops];
    }

    void placeUnit(ArmyUnit unit) {
      GeneralRank? generalRank;
      if (unit.type == PieceType.general) {
        final declaredRank = unit.generalRank;
        if (declaredRank == GeneralRank.highKing) {
          generalRank = hasHighKingAssigned
              ? GeneralRank.officer
              : GeneralRank.highKing;
        } else if (declaredRank == GeneralRank.officer) {
          generalRank = GeneralRank.officer;
        } else {
          generalRank = hasHighKingAssigned
              ? GeneralRank.officer
              : GeneralRank.highKing;
        }
        if (generalRank == GeneralRank.highKing) {
          hasHighKingAssigned = true;
        }
      }

      final preferredRows = rowsFor(unit);
      final preferredColumns = columnsFor(unit);
      final strictPawnFiles =
          pawnFileLimit != null && unit.type == PieceType.pawn;
      final rowOrder = <int>[...preferredRows, ...homeRows];
      final colOrder = strictPawnFiles
          ? preferredColumns
          : <int>[...preferredColumns, ...centerColumns, ...edgeColumns];
      final supportPasses = unit.type == PieceType.general
          ? const <bool>[true, false]
          : const <bool>[false];

      for (final enforceEscort in supportPasses) {
        final visitedRows = <int>{};
        final visitedCols = <int>{};
        for (final row in rowOrder) {
          if (!visitedRows.add(row)) {
            continue;
          }
          visitedCols.clear();
          for (final col in colOrder) {
            if (!visitedCols.add(col)) {
              continue;
            }
            final pos = BoardPosition(row, col);
            if (used.contains(pos) || blockedCells.contains(pos)) {
              continue;
            }
            if (enforceEscort) {
              final supportCount = _adjacentFriendlySupportCount(
                at: pos,
                ownerId: ownerId,
                pieces: pieces,
              );
              if (supportCount == 0) {
                continue;
              }
              if (_isCenterColumn(col, cols) && supportCount < 2) {
                continue;
              }
            }
            used.add(pos);
            pieces.add(
              BattlePiece(
                id: '$idPrefix-${nextIndex++}',
                ownerId: ownerId,
                type: unit.type,
                position: pos,
                generalSkill: unit.generalSkill,
                generalRank: generalRank,
              ),
            );
            return;
          }
        }
      }
      throw StateError(
        'Could not place unit ${unit.type} for army ${army.label}.',
      );
    }

    for (final unit in sortedUnits()) {
      placeUnit(unit);
    }

    return pieces;
  }

  static int _adjacentFriendlySupportCount({
    required BoardPosition at,
    required int ownerId,
    required List<BattlePiece> pieces,
  }) {
    var count = 0;
    for (final piece in pieces) {
      if (piece.ownerId != ownerId || piece.type == PieceType.general) {
        continue;
      }
      final rowDelta = (piece.position.row - at.row).abs();
      final colDelta = (piece.position.col - at.col).abs();
      final adjacent =
          rowDelta <= 1 && colDelta <= 1 && !(rowDelta == 0 && colDelta == 0);
      if (adjacent) {
        count++;
      }
    }
    return count;
  }

  static bool _isCenterColumn(int col, int cols) {
    final leftCenter = (cols - 1) ~/ 2;
    final rightCenter = cols ~/ 2;
    return col == leftCenter || col == rightCenter;
  }

  static List<int> _applyColumnVariant(
    List<int> source, {
    required int cols,
    required int rotation,
    required bool mirrored,
  }) {
    if (source.isEmpty) {
      return const <int>[];
    }
    final safeRotation = rotation % source.length;
    final rotated = [
      ...source.skip(safeRotation),
      ...source.take(safeRotation),
    ];
    if (!mirrored) {
      return rotated;
    }
    return rotated.map((col) => cols - 1 - col).toList();
  }

  static List<int> _centerOutColumns(int cols) {
    final order = <int>[];
    final leftCenter = (cols - 1) ~/ 2;
    final rightCenter = cols ~/ 2;

    if (leftCenter == rightCenter) {
      order.add(leftCenter);
    } else {
      order.add(rightCenter);
      order.add(leftCenter);
    }

    for (var offset = 1; order.length < cols; offset++) {
      final right = rightCenter + offset;
      final left = leftCenter - offset;
      if (right >= 0 && right < cols) {
        order.add(right);
      }
      if (left >= 0 && left < cols) {
        order.add(left);
      }
    }

    return order;
  }

  static List<int> _edgeInColumns(int cols) {
    final order = <int>[];
    var left = 0;
    var right = cols - 1;
    while (left <= right) {
      if (left == right) {
        order.add(left);
      } else {
        order.add(left);
        order.add(right);
      }
      left++;
      right--;
    }
    return order;
  }

  static List<int> _columnsFromIndex(List<int> source, int start) {
    if (source.isEmpty) {
      return const <int>[];
    }
    final safeStart = start.clamp(0, source.length - 1);
    return [...source.skip(safeStart), ...source.take(safeStart)];
  }

  static List<int> _mergeColumnOrders(List<int> primary, List<int> secondary) {
    final merged = <int>[];
    final seen = <int>{};
    for (final col in [...primary, ...secondary]) {
      if (seen.add(col)) {
        merged.add(col);
      }
    }
    return merged;
  }

  static List<int> _pawnStackColumns(
    List<int> centerColumns,
    int cols, {
    required int preferredFiles,
  }) {
    if (centerColumns.isEmpty) {
      return const <int>[];
    }
    final files = preferredFiles.clamp(
      1,
      cols >= 8
          ? 4
          : cols >= 6
          ? 3
          : 2,
    );
    return centerColumns.take(files).toList();
  }
}

class BattleAction {
  const BattleAction({
    required this.pieceId,
    required this.to,
    this.capturedPieceId,
  });

  final String pieceId;
  final BoardPosition to;
  final String? capturedPieceId;
}

enum BattleOverlayMark { move, capture, loss, hazard }

class BattleOverlayArrow {
  const BattleOverlayArrow({
    required this.from,
    required this.to,
    required this.mark,
  });

  final BoardPosition from;
  final BoardPosition to;
  final BattleOverlayMark mark;
}

class BattleTurnOverlay {
  const BattleTurnOverlay({
    required this.turn,
    required this.marksByPosition,
    required this.arrows,
  });

  final int turn;
  final Map<BoardPosition, BattleOverlayMark> marksByPosition;
  final List<BattleOverlayArrow> arrows;
}

class _Vector {
  const _Vector(this.rowDelta, this.colDelta);

  final int rowDelta;
  final int colDelta;
}

class _DeploymentStyle {
  const _DeploymentStyle({
    required this.suffix,
    required this.columnRotation,
    required this.mirrorColumns,
    required this.reservePawns,
    this.pawnFileLimit,
  });

  final String suffix;
  final int columnRotation;
  final bool mirrorColumns;
  final bool reservePawns;
  final int? pawnFileLimit;
}

class _RetreatOutcome {
  const _RetreatOutcome({required this.pieces, required this.movedCount});

  final List<BattlePiece> pieces;
  final int movedCount;
}

class _RetreatResolution {
  const _RetreatResolution({
    required this.pieces,
    required this.events,
    required this.logSuffix,
  });

  final List<BattlePiece> pieces;
  final List<BattleEvent> events;
  final String? logSuffix;
}

enum _AdvanceContactOutcome { capture, clash, repulsed }

class _RoutResolution {
  const _RoutResolution({
    required this.pieces,
    required this.events,
    required this.logSuffix,
  });

  final List<BattlePiece> pieces;
  final List<BattleEvent> events;
  final String? logSuffix;
}
