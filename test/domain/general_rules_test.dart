import 'dart:math';

import 'package:chesswarss/src/domain/army_factory.dart';
import 'package:chesswarss/src/domain/battle_state.dart';
import 'package:chesswarss/src/domain/board_position.dart';
import 'package:chesswarss/src/domain/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('General movement and growth', () {
    test('rookie general moves only one square orthogonally', () {
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
        ]),
      );
    });

    test('veteran general can move up to two squares without jumping', () {
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
      expect(moves.contains(const BoardPosition(2, 4)), isTrue);
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
