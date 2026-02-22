import 'dart:math';

import 'package:chesswarss/src/domain/army_factory.dart';
import 'package:chesswarss/src/domain/battle_state.dart';
import 'package:chesswarss/src/domain/board_position.dart';
import 'package:chesswarss/src/domain/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pawn movement', () {
    test('south pawn can move one or two squares from starting row', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'p',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 4),
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('p');
      expect(
        moves,
        unorderedEquals(const [BoardPosition(5, 4), BoardPosition(4, 4)]),
      );
    });

    test('north pawn can move one or two squares from starting row', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 1,
        pieces: [
          BattlePiece(
            id: 'p',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(1, 3),
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('p');
      expect(
        moves,
        unorderedEquals(const [BoardPosition(2, 3), BoardPosition(3, 3)]),
      );
    });

    test('pawn cannot move two squares when path is blocked', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'p',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 4),
          ),
          BattlePiece(
            id: 'block',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(5, 4),
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('p');
      expect(moves, isEmpty);
    });

    test('pawn cannot move two squares after leaving starting row', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'p',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(5, 4),
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('p');
      expect(moves, unorderedEquals(const [BoardPosition(4, 4)]));
    });
  });

  group('General movement and growth', () {
    test('rookie general moves one square in all directions', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'g',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(4, 4),
            generalSkill: GeneralSkill.fieldCommander,
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('g');
      expect(
        moves,
        unorderedEquals(const [
          BoardPosition(3, 4),
          BoardPosition(5, 4),
          BoardPosition(4, 3),
          BoardPosition(4, 5),
          BoardPosition(3, 3),
          BoardPosition(3, 5),
          BoardPosition(5, 3),
          BoardPosition(5, 5),
        ]),
      );
    });

    test('veteran general is still king-like and cannot move onto ally', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'g',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(4, 4),
            generalSkill: GeneralSkill.veteranCommander,
          ),
          BattlePiece(
            id: 'block',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(4, 5),
          ),
          BattlePiece(
            id: 'enemy',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(2, 4),
          ),
        ],
        moveLog: [],
      );

      final moves = state.legalMovesForPiece('g');

      expect(moves.contains(const BoardPosition(4, 6)), isFalse);
      expect(moves.contains(const BoardPosition(2, 4)), isFalse);
      expect(moves.contains(const BoardPosition(3, 4)), isTrue);
      expect(moves.contains(const BoardPosition(4, 5)), isFalse);
    });

    test('general promotes to veteran after two captures', () {
      const opening = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'g',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(4, 4),
            generalSkill: GeneralSkill.fieldCommander,
          ),
          BattlePiece(
            id: 'enemyA',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(4, 5),
          ),
          BattlePiece(
            id: 'enemyB',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(4, 6),
          ),
        ],
        moveLog: [],
      );

      final afterFirstCapture = opening.movePiece(
        pieceId: 'g',
        to: const BoardPosition(4, 5),
      );

      final generalAfterOne = afterFirstCapture.pieceById('g');
      expect(generalAfterOne?.generalSkill, GeneralSkill.fieldCommander);
      expect(generalAfterOne?.generalExperience, 1);

      final forcedTurn = BattleState(
        rows: afterFirstCapture.rows,
        cols: afterFirstCapture.cols,
        activePlayer: 0,
        pieces: afterFirstCapture.pieces,
        moveLog: afterFirstCapture.moveLog,
      );

      final afterSecondCapture = forcedTurn.movePiece(
        pieceId: 'g',
        to: const BoardPosition(4, 6),
      );

      final promotedGeneral = afterSecondCapture.pieceById('g');
      expect(promotedGeneral?.generalSkill, GeneralSkill.veteranCommander);
      expect(promotedGeneral?.generalExperience, 2);
    });

    test('veteran general command skill can advance multiple units once', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'g0',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(7, 4),
            generalSkill: GeneralSkill.veteranCommander,
          ),
          BattlePiece(
            id: 'p0',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 1),
          ),
          BattlePiece(
            id: 'p1',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 3),
          ),
          BattlePiece(
            id: 'p2',
            ownerId: 0,
            type: PieceType.pawn,
            position: BoardPosition(6, 5),
          ),
          BattlePiece(
            id: 'g1',
            ownerId: 1,
            type: PieceType.general,
            position: BoardPosition(0, 4),
            generalSkill: GeneralSkill.fieldCommander,
          ),
        ],
        moveLog: [],
        moraleByPlayer: {0: 4, 1: 4},
      );

      expect(state.canUseGeneralAdvanceSkill(), isTrue);
      final advanced = state.useGeneralAdvanceSkill();
      expect(advanced.activePlayer, 1);
      expect(advanced.pieceById('p0')?.position, const BoardPosition(5, 1));
      expect(advanced.pieceById('p1')?.position, const BoardPosition(5, 3));
      expect(advanced.pieceById('p2')?.position, const BoardPosition(5, 5));
      expect(advanced.generalSkillUsedByPlayer[0], isTrue);
    });

    test('fragile general causes panic retreat when threatened', () {
      const state = BattleState(
        rows: 8,
        cols: 8,
        activePlayer: 0,
        pieces: [
          BattlePiece(
            id: 'r0',
            ownerId: 0,
            type: PieceType.rook,
            position: BoardPosition(4, 0),
          ),
          BattlePiece(
            id: 'g0',
            ownerId: 0,
            type: PieceType.general,
            position: BoardPosition(7, 4),
            generalSkill: GeneralSkill.fieldCommander,
          ),
          BattlePiece(
            id: 'g1',
            ownerId: 1,
            type: PieceType.general,
            position: BoardPosition(4, 4),
            generalSkill: GeneralSkill.fragileMarshal,
          ),
          BattlePiece(
            id: 'p1',
            ownerId: 1,
            type: PieceType.pawn,
            position: BoardPosition(3, 2),
          ),
        ],
        moveLog: [],
        moraleByPlayer: {0: 5, 1: 5},
      );

      final moved = state.movePiece(
        pieceId: 'r0',
        to: const BoardPosition(4, 3),
      );

      expect(moved.pieceById('p1')?.position, const BoardPosition(2, 2));
      expect(moved.moraleForPlayer(1), 4);
      expect(moved.moveLog.last, contains('panic retreat'));
    });
  });

  group('Army factory', () {
    test('can roll a rare second general', () {
      final factory = const ArmyFactory(secondGeneralChance: 1.0);
      final set = factory.createArmySet(playerId: 0, random: Random(9));

      final hasDoubleGeneral = set.armies.any(
        (army) => army.countType(PieceType.general) >= 2,
      );

      expect(hasDoubleGeneral, isTrue);
    });

    test('always includes at least one veteran commander army', () {
      final factory = const ArmyFactory(secondGeneralChance: 0.0);
      final set = factory.createArmySet(playerId: 0, random: Random(9));

      final hasVeteran = set.armies.any(
        (army) => army.units.any(
          (unit) =>
              unit.type == PieceType.general &&
              unit.generalSkill == GeneralSkill.veteranCommander,
        ),
      );

      expect(hasVeteran, isTrue);
    });
  });
}
