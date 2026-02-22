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
  generalProgress,
  generalSkill,
}

class BattleEvent {
  const BattleEvent({
    required this.turn,
    required this.type,
    required this.description,
    this.actorPlayerId,
    this.targetPlayerId,
    this.pieceId,
    this.position,
    this.delta,
  });

  final int turn;
  final BattleEventType type;
  final String description;
  final int? actorPlayerId;
  final int? targetPlayerId;
  final String? pieceId;
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
  }) {
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
      ],
      blockedCells: blockedCells,
      disableOpeningCaptures: true,
      moraleByPlayer: <int, int>{southOwnerId: 6, northOwnerId: 6},
      maxMorale: 6,
      generalSkillUsedByPlayer: <int, bool>{
        southOwnerId: false,
        northOwnerId: false,
      },
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
    final formationOrder = _formationOrder(preferredFormation);
    final maxPlans = rows * cols <= 36 ? 2 : 3;
    final styles = <_DeploymentStyle>[
      const _DeploymentStyle(
        suffix: 'Central Anchor',
        columnRotation: 0,
        mirrorColumns: false,
        reservePawns: false,
      ),
      const _DeploymentStyle(
        suffix: 'Offset Lanes',
        columnRotation: 1,
        mirrorColumns: false,
        reservePawns: false,
      ),
      const _DeploymentStyle(
        suffix: 'Mirrored Pressure',
        columnRotation: 0,
        mirrorColumns: true,
        reservePawns: true,
      ),
    ];

    final plans = <BattleDeploymentPlan>[];
    final signatures = <String>{};

    for (final formation in formationOrder) {
      for (final style in styles) {
        if (plans.length >= maxPlans) {
          break;
        }

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

  static List<BattleFormation> _formationOrder(BattleFormation preferred) {
    final order = <BattleFormation>[preferred];
    for (final formation in BattleFormation.values) {
      if (formation != preferred) {
        order.add(formation);
      }
    }
    return order;
  }

  static String _formationLabel(BattleFormation formation) {
    switch (formation) {
      case BattleFormation.balanced:
        return 'Balanced';
      case BattleFormation.flankGuard:
        return 'Flank Guard';
      case BattleFormation.spearhead:
        return 'Spearhead';
    }
  }

  static String _deploymentSummary({
    required BattleFormation formation,
    required _DeploymentStyle style,
    required int rows,
    required int cols,
  }) {
    final base = switch (formation) {
      BattleFormation.balanced => 'Symmetric center control',
      BattleFormation.flankGuard => 'Wide flank cover',
      BattleFormation.spearhead => 'Aggressive center pressure',
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

  bool moraleBroken(int playerId) {
    return moraleForPlayer(playerId) <= 0;
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
      if (_isOpenSquare(forward)) {
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

  BattleState advanceFrontline({int maxUnits = 3}) {
    return _advanceUnits(
      maxUnits: maxUnits,
      fromGeneralSkill: false,
      skillLabel: null,
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
      if (_isOpenSquare(forward)) {
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
    final destinationById = <String, BoardPosition>{
      for (final piece in selected) piece.id: _forwardSquare(piece),
    };

    final updatedPieces = pieces.map((piece) {
      final destination = destinationById[piece.id];
      if (destination == null) {
        return piece;
      }
      return piece.copyWith(position: destination);
    }).toList();

    final updatedMorale = <int, int>{...moraleByPlayer};
    final updatedSkillUse = <int, bool>{...generalSkillUsedByPlayer};

    final currentMorale = moraleForPlayer(activePlayer);
    final moraleBoost = selected.length >= 2 || fromGeneralSkill ? 1 : 0;
    var boostedMorale = currentMorale;
    if (moraleBoost > 0 && currentMorale < maxMorale) {
      boostedMorale = _clampMorale(currentMorale + moraleBoost);
      updatedMorale[activePlayer] = boostedMorale;
    }

    if (fromGeneralSkill) {
      updatedSkillUse[activePlayer] = true;
    }

    final turn = moveLog.length + 1;
    final logEntry = fromGeneralSkill
        ? 'Skill ${skillLabel ?? 'General'}: P${activePlayer + 1} advanced ${selected.length} units.'
        : 'Advance P${activePlayer + 1}: ${selected.length} pawns pushed forward.';

    final events = <BattleEvent>[
      BattleEvent(
        turn: turn,
        type: fromGeneralSkill
            ? BattleEventType.generalSkill
            : BattleEventType.advance,
        actorPlayerId: activePlayer,
        description: logEntry,
      ),
    ];

    if (boostedMorale != currentMorale) {
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

    final retreat = _resolveFragileRetreat(
      boardPieces: updatedPieces,
      moraleByPlayer: updatedMorale,
      turn: turn,
    );

    final finalEvents = [...events, ...retreat.events];
    final finalLog = retreat.logSuffix == null
        ? logEntry
        : '$logEntry | ${retreat.logSuffix}';

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: retreat.pieces,
      moveLog: [...moveLog, finalLog],
      eventLog: [...eventLog, ...finalEvents],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: updatedMorale,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: updatedSkillUse,
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
          position: to,
          description:
              'P${movingPiece.ownerId + 1} captured '
              '${target.type.name} from P${target.ownerId + 1}.',
        ),
      );

      final moraleLoss = _moraleLossForCapture(target.type);
      final defenderMorale = moraleForPlayer(target.ownerId);
      final reducedMorale = _clampMorale(defenderMorale - moraleLoss);
      if (reducedMorale != defenderMorale) {
        updatedMorale[target.ownerId] = reducedMorale;
        events.add(
          BattleEvent(
            turn: turn,
            type: BattleEventType.moraleShift,
            actorPlayerId: movingPiece.ownerId,
            targetPlayerId: target.ownerId,
            delta: -moraleLoss,
            description:
                'P${target.ownerId + 1} morale '
                '$defenderMorale->$reducedMorale.',
          ),
        );
      }

      if (target.type == PieceType.general) {
        final attackerMorale = moraleForPlayer(movingPiece.ownerId);
        final boostedMorale = _clampMorale(attackerMorale + 1);
        if (boostedMorale != attackerMorale) {
          updatedMorale[movingPiece.ownerId] = boostedMorale;
          events.add(
            BattleEvent(
              turn: turn,
              type: BattleEventType.moraleShift,
              actorPlayerId: movingPiece.ownerId,
              delta: 1,
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

    if (retreat.logSuffix != null) {
      logEntry = '$logEntry | ${retreat.logSuffix}';
    }

    return BattleState(
      rows: rows,
      cols: cols,
      activePlayer: otherPlayer,
      southPlayerId: southPlayerId,
      northPlayerId: northPlayerId,
      pieces: retreat.pieces,
      moveLog: [...moveLog, logEntry],
      eventLog: [...eventLog, ...events, ...retreat.events],
      blockedCells: blockedCells,
      disableOpeningCaptures: disableOpeningCaptures,
      moraleByPlayer: updatedMorale,
      maxMorale: maxMorale,
      generalSkillUsedByPlayer: generalSkillUsedByPlayer,
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

    List<int> columnsFor(ArmyUnit unit) {
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
      final preferredRows = rowsFor(unit);
      final preferredColumns = columnsFor(unit);
      final rowOrder = <int>[...preferredRows, ...homeRows];
      final colOrder = <int>[
        ...preferredColumns,
        ...centerColumns,
        ...edgeColumns,
      ];
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
          used.add(pos);
          pieces.add(
            BattlePiece(
              id: '$idPrefix-${nextIndex++}',
              ownerId: ownerId,
              type: unit.type,
              position: pos,
              generalSkill: unit.generalSkill,
            ),
          );
          return;
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
  });

  final String suffix;
  final int columnRotation;
  final bool mirrorColumns;
  final bool reservePawns;
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
