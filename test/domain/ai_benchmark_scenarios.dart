import 'package:chesswarss/src/domain/ai.dart';
import 'package:chesswarss/src/domain/battle_state.dart';
import 'package:chesswarss/src/domain/board_position.dart';
import 'package:chesswarss/src/domain/piece.dart';

enum AiScenarioFamily {
  commandPreservation,
  routStability,
  exposureDiscipline,
  decisiveConversion,
}

class AiBenchmarkScenario {
  const AiBenchmarkScenario({
    required this.id,
    required this.family,
    required this.seed,
    required this.difficulty,
    required this.battleState,
    required this.expectation,
    required this.failureMessage,
  });

  final String id;
  final AiScenarioFamily family;
  final int seed;
  final AiDifficulty difficulty;
  final BattleState battleState;
  final bool Function(
    BattleState before,
    BattleAction action,
    BattleState after,
  )
  expectation;
  final String Function(
    BattleState before,
    BattleAction action,
    BattleState after,
  )
  failureMessage;
}

List<AiBenchmarkScenario> buildAiBenchmarkScenarios() {
  return <AiBenchmarkScenario>[
    for (final seed in const <int>[11, 111, 211, 311])
      AiBenchmarkScenario(
        id: 'command_isolation_seed_$seed',
        family: AiScenarioFamily.commandPreservation,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _isolatedGeneralState(),
        expectation: _keepsGeneralAdjacentToSupport,
        failureMessage: _isolationFailureMessage,
      ),
    for (final seed in const <int>[13, 113, 213, 313])
      AiBenchmarkScenario(
        id: 'command_lane_seed_$seed',
        family: AiScenarioFamily.commandPreservation,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _commandLaneExposureState(),
        expectation: _doesNotIncreaseThreatenedGenerals,
        failureMessage: _commandLaneFailureMessage,
      ),
    for (final seed in const <int>[29, 129, 229, 329])
      AiBenchmarkScenario(
        id: 'rout_collapse_seed_$seed',
        family: AiScenarioFamily.routStability,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _routCollapsePressureState(),
        expectation: _avoidsImmediateMoraleCollapse,
        failureMessage: _routFailureMessage,
      ),
    for (final seed in const <int>[37, 137, 237, 337])
      AiBenchmarkScenario(
        id: 'hanging_capture_seed_$seed',
        family: AiScenarioFamily.exposureDiscipline,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _hangingCaptureState(),
        expectation: _avoidsHangingRookCapture,
        failureMessage: _hangingCaptureFailureMessage,
      ),
    for (final seed in const <int>[43, 143, 243, 343])
      AiBenchmarkScenario(
        id: 'general_exposure_bait_seed_$seed',
        family: AiScenarioFamily.exposureDiscipline,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _generalExposureBaitState(),
        expectation: _avoidsGeneralExposureBait,
        failureMessage: _generalExposureBaitFailureMessage,
      ),
    for (final seed in const <int>[41, 141, 241, 341])
      AiBenchmarkScenario(
        id: 'decisive_conversion_seed_$seed',
        family: AiScenarioFamily.decisiveConversion,
        seed: seed,
        difficulty: AiDifficulty.hard,
        battleState: _decisiveConversionState(),
        expectation: _convertsImmediateDecisiveChance,
        failureMessage: _decisiveConversionFailureMessage,
      ),
  ];
}

BattleState _isolatedGeneralState() {
  return BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: const [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 3),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'p0',
        ownerId: 0,
        type: PieceType.pawn,
        position: BoardPosition(7, 2),
      ),
      BattlePiece(
        id: 'e0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(0, 0),
      ),
    ],
    blockedCells: {const BoardPosition(6, 2), const BoardPosition(7, 1)},
    moveLog: [],
  );
}

BattleState _commandLaneExposureState() {
  return const BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 3),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'b0',
        ownerId: 0,
        type: PieceType.bishop,
        position: BoardPosition(6, 3),
      ),
      BattlePiece(
        id: 'p0',
        ownerId: 0,
        type: PieceType.pawn,
        position: BoardPosition(6, 0),
      ),
      BattlePiece(
        id: 'er0',
        ownerId: 1,
        type: PieceType.rook,
        position: BoardPosition(3, 3),
      ),
      BattlePiece(
        id: 'ep0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(5, 4),
      ),
    ],
    moveLog: [],
  );
}

BattleState _routCollapsePressureState() {
  return const BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 3),
        generalSkill: GeneralSkill.fragileMarshal,
      ),
      BattlePiece(
        id: 'b0',
        ownerId: 0,
        type: PieceType.bishop,
        position: BoardPosition(6, 3),
      ),
      BattlePiece(
        id: 'p0',
        ownerId: 0,
        type: PieceType.pawn,
        position: BoardPosition(6, 0),
      ),
      BattlePiece(
        id: 'er0',
        ownerId: 1,
        type: PieceType.rook,
        position: BoardPosition(3, 3),
      ),
      BattlePiece(
        id: 'ep0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(5, 4),
      ),
    ],
    moveLog: [],
    moraleByPlayer: {0: 2, 1: 6},
  );
}

BattleState _hangingCaptureState() {
  return BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: const [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 0),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'r0',
        ownerId: 0,
        type: PieceType.rook,
        position: BoardPosition(6, 4),
      ),
      BattlePiece(
        id: 'eg0',
        ownerId: 1,
        type: PieceType.general,
        position: BoardPosition(0, 7),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'eb0',
        ownerId: 1,
        type: PieceType.bishop,
        position: BoardPosition(2, 2),
      ),
      BattlePiece(
        id: 'ep0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(6, 6),
      ),
    ],
    blockedCells: {
      const BoardPosition(6, 0),
      const BoardPosition(6, 1),
      const BoardPosition(7, 1),
    },
    moveLog: [],
  );
}

BattleState _decisiveConversionState() {
  return const BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 0),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'r0',
        ownerId: 0,
        type: PieceType.rook,
        position: BoardPosition(6, 4),
      ),
      BattlePiece(
        id: 'eg0',
        ownerId: 1,
        type: PieceType.general,
        position: BoardPosition(6, 6),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'ep0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(5, 7),
      ),
    ],
    moveLog: [],
    moraleByPlayer: {0: 4, 1: 2},
  );
}

BattleState _generalExposureBaitState() {
  return const BattleState(
    rows: 8,
    cols: 8,
    activePlayer: 0,
    pieces: [
      BattlePiece(
        id: 'g0',
        ownerId: 0,
        type: PieceType.general,
        position: BoardPosition(7, 4),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'p0',
        ownerId: 0,
        type: PieceType.pawn,
        position: BoardPosition(6, 3),
      ),
      BattlePiece(
        id: 'eg0',
        ownerId: 1,
        type: PieceType.general,
        position: BoardPosition(0, 7),
        generalSkill: GeneralSkill.fieldCommander,
      ),
      BattlePiece(
        id: 'er0',
        ownerId: 1,
        type: PieceType.rook,
        position: BoardPosition(0, 4),
      ),
      BattlePiece(
        id: 'ep0',
        ownerId: 1,
        type: PieceType.pawn,
        position: BoardPosition(6, 4),
      ),
    ],
    moveLog: [],
    moraleByPlayer: {0: 2, 1: 6},
  );
}

bool _keepsGeneralAdjacentToSupport(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  if (action.pieceId != 'g0') {
    return false;
  }
  final moved = after.pieceById('g0');
  if (moved == null) {
    return false;
  }
  for (final piece in after.piecesForPlayer(0)) {
    if (piece.id == 'g0') {
      continue;
    }
    final rowDelta = (piece.position.row - moved.position.row).abs();
    final colDelta = (piece.position.col - moved.position.col).abs();
    if (rowDelta <= 1 && colDelta <= 1 && !(rowDelta == 0 && colDelta == 0)) {
      return true;
    }
  }
  return false;
}

String _isolationFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return 'General moved to ${action.to} without adjacent ally support.';
}

bool _doesNotIncreaseThreatenedGenerals(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  final beforeThreatened = _threatenedGeneralCount(before, 0);
  final afterThreatened = _threatenedGeneralCount(after, 0);
  return afterThreatened <= beforeThreatened;
}

String _commandLaneFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  final beforeThreatened = _threatenedGeneralCount(before, 0);
  final afterThreatened = _threatenedGeneralCount(after, 0);
  return 'Threatened generals increased: $beforeThreatened -> $afterThreatened.';
}

bool _avoidsImmediateMoraleCollapse(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return after.moraleStateForPlayer(0) != MoraleState.collapsed;
}

String _routFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return 'Action ${action.pieceId} -> ${action.to} caused morale collapse.';
}

bool _avoidsHangingRookCapture(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return !(action.pieceId == 'r0' && action.to == const BoardPosition(6, 6));
}

String _hangingCaptureFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  final enemyAttackers = _attackerCount(after, 1, const BoardPosition(6, 6));
  final alliedDefenders = _attackerCount(
    after,
    0,
    const BoardPosition(6, 6),
    excludingPieceId: 'r0',
  );
  return 'AI took hanging rook capture; enemyAttackers=$enemyAttackers '
      'alliedDefenders=$alliedDefenders.';
}

bool _avoidsGeneralExposureBait(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return !(action.pieceId == 'g0' && action.to == const BoardPosition(6, 4));
}

String _generalExposureBaitFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return 'AI exposed the general with ${action.pieceId} -> ${action.to}.';
}

bool _convertsImmediateDecisiveChance(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return !after.commanderAlive(1) || after.moraleBroken(1);
}

String _decisiveConversionFailureMessage(
  BattleState before,
  BattleAction action,
  BattleState after,
) {
  return 'AI missed decisive finish with ${action.pieceId} -> ${action.to}. '
      'enemyCommanderAlive=${after.commanderAlive(1)} '
      'enemyMorale=${after.moraleForPlayer(1)}.';
}

int _threatenedGeneralCount(BattleState state, int playerId) {
  final enemyId = playerId == state.southPlayerId
      ? state.northPlayerId
      : state.southPlayerId;
  final threatenedSquares = <BoardPosition>{};
  for (final enemy in state.piecesForPlayer(enemyId)) {
    threatenedSquares.addAll(
      state.legalMovesForPiece(
        enemy.id,
        asPlayerId: enemyId,
        ignoreOpeningCaptureBlock: true,
      ),
    );
  }
  return state
      .generalsForSide(playerId)
      .where((general) => threatenedSquares.contains(general.position))
      .length;
}

int _attackerCount(
  BattleState state,
  int playerId,
  BoardPosition target, {
  String? excludingPieceId,
}) {
  var count = 0;
  for (final piece in state.piecesForPlayer(playerId)) {
    if (piece.id == excludingPieceId) {
      continue;
    }
    final moves = state.legalMovesForPiece(
      piece.id,
      asPlayerId: playerId,
      ignoreOpeningCaptureBlock: true,
    );
    if (moves.contains(target)) {
      count++;
    }
  }
  return count;
}
