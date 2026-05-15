import 'dart:math';

import 'army.dart';
import 'piece.dart';

class ArmyFactory {
  const ArmyFactory({this.secondGeneralChance = 0.02});

  final double secondGeneralChance;

  PlayerArmySet createArmySet({
    required int playerId,
    required Random random,
    int armiesPerPlayer = 3,
  }) {
    final requestedArmies = armiesPerPlayer.clamp(2, 4).toInt();
    final baseArmies = <ArmyDefinition>[
      _towerLineArmy(),
      _mobileVanguardArmy(),
      _balancedWildcardArmy(random),
      _frontierHostArmy(random),
    ];
    final armies = baseArmies.take(requestedArmies).toList();

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
          generalRank: GeneralRank.officer,
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
        ArmyUnit(type: PieceType.bishop),
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.veteranCommander,
          generalRank: GeneralRank.highKing,
          title: 'Iron Marshal',
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
        ArmyUnit(type: PieceType.bishop),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.warDrummer,
          generalRank: GeneralRank.highKing,
          title: 'Grand Vanguard',
        ),
      ],
    );
  }

  ArmyDefinition _balancedWildcardArmy(Random random) {
    return const ArmyDefinition(
      id: 'royal_expedition',
      label: 'Royal Expedition',
      units: [
        ArmyUnit(type: PieceType.rook),
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.bishop),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.fieldCommander,
          generalRank: GeneralRank.highKing,
          title: 'Royal Heir',
        ),
      ],
    );
  }

  ArmyDefinition _frontierHostArmy(Random random) {
    return const ArmyDefinition(
      id: 'frontier_host',
      label: 'Frontier Host',
      units: [
        ArmyUnit(type: PieceType.rook),
        ArmyUnit(type: PieceType.knight),
        ArmyUnit(type: PieceType.bishop),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(type: PieceType.pawn),
        ArmyUnit(
          type: PieceType.general,
          generalSkill: GeneralSkill.fieldCommander,
          generalRank: GeneralRank.highKing,
          title: 'Border Captain',
        ),
      ],
    );
  }
}
