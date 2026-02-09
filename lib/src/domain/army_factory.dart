import 'dart:math';

import 'army.dart';
import 'piece.dart';

class ArmyFactory {
  const ArmyFactory({this.secondGeneralChance = 0.02});

  final double secondGeneralChance;

  PlayerArmySet createArmySet({required int playerId, required Random random}) {
    final armies = <ArmyDefinition>[
      _towerLineArmy(),
      _mobileVanguardArmy(),
      _balancedWildcardArmy(random),
    ];

    final withRareSecondGeneral = _rollSecondGeneral(armies, random);

    return PlayerArmySet(playerId: playerId, armies: withRareSecondGeneral);
  }

  List<ArmyDefinition> _rollSecondGeneral(
    List<ArmyDefinition> armies,
    Random random,
  ) {
    if (random.nextDouble() > secondGeneralChance) {
      return armies;
    }

    final chosenIndex = random.nextInt(armies.length);
    final chosenArmy = armies[chosenIndex];
    final updatedUnits = List<ArmyUnit>.from(chosenArmy.units)
      ..add(
        const ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.fieldCommander,
          title: 'Deputy General',
        ),
      );

    final copy = List<ArmyDefinition>.from(armies);
    copy[chosenIndex] = chosenArmy.copyWith(units: updatedUnits);
    return copy;
  }

  ArmyDefinition _towerLineArmy() {
    return const ArmyDefinition(
      id: 'tower_line',
      label: 'Tower Line',
      units: [
        ArmyUnit(type: PieceType.rook),
        ArmyUnit(type: PieceType.rook),
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.fieldCommander,
          title: 'Line Captain',
        ),
      ],
    );
  }

  ArmyDefinition _mobileVanguardArmy() {
    return const ArmyDefinition(
      id: 'mobile_vanguard',
      label: 'Mobile Vanguard',
      units: [
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.bishop),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.veteranCommander,
          title: 'Veteran Commander',
        ),
      ],
    );
  }

  ArmyDefinition _balancedWildcardArmy(Random random) {
    final minorPair = random.nextBool()
        ? const [PieceType.knight, PieceType.knight]
        : const [PieceType.bishop, PieceType.bishop];

    return ArmyDefinition(
      id: 'balanced_wildcard',
      label: 'Balanced Wildcard',
      units: [
        const ArmyUnit(type: PieceType.rook),
        ArmyUnit(type: minorPair[0]),
        ArmyUnit(type: minorPair[1]),
        const ArmyUnit(type: PieceType.pawn),
        const ArmyUnit(type: PieceType.pawn),
        const ArmyUnit(type: PieceType.pawn),
        const ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.fieldCommander,
          title: 'Rising Commander',
        ),
      ],
    );
  }
}
