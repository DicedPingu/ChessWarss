import 'piece.dart';

class ArmyUnit {
  const ArmyUnit({
    required this.type,
    this.generalSkill,
    this.generalRank,
    this.title,
  }) : assert(
         type != PieceType.general || generalSkill != null,
         'General units must define a skill.',
       );

  final PieceType type;
  final GeneralSkill? generalSkill;
  final GeneralRank? generalRank;
  final String? title;
}

class ArmyDefinition {
  const ArmyDefinition({
    required this.id,
    required this.label,
    required this.units,
  });

  final String id;
  final String label;
  final List<ArmyUnit> units;

  ArmyComposition get composition => ArmyComposition.fromUnits(units);

  int countType(PieceType type) {
    return units.where((unit) => unit.type == type).length;
  }

  ArmyDefinition copyWith({String? id, String? label, List<ArmyUnit>? units}) {
    return ArmyDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      units: units ?? this.units,
    );
  }
}

class PlayerArmySet {
  const PlayerArmySet({required this.playerId, required this.armies});

  final int playerId;
  final List<ArmyDefinition> armies;
}

class ArmyComposition {
  const ArmyComposition({
    required this.pawns,
    required this.rooks,
    required this.knights,
    required this.bishops,
    required this.generals,
    required this.veteranGenerals,
    required this.highKings,
  });

  final int pawns;
  final int rooks;
  final int knights;
  final int bishops;
  final int generals;
  final int veteranGenerals;
  final int highKings;

  int get rookieGenerals => generals - veteranGenerals;

  factory ArmyComposition.fromUnits(List<ArmyUnit> units) {
    var pawns = 0;
    var rooks = 0;
    var knights = 0;
    var bishops = 0;
    var generals = 0;
    var veteranGenerals = 0;
    var highKings = 0;

    for (final unit in units) {
      switch (unit.type) {
        case PieceType.pawn:
          pawns++;
        case PieceType.rook:
          rooks++;
        case PieceType.knight:
          knights++;
        case PieceType.bishop:
          bishops++;
        case PieceType.general:
          generals++;
          if (unit.generalSkill == GeneralSkill.veteranCommander) {
            veteranGenerals++;
          }
          if ((unit.generalRank ?? GeneralRank.highKing) ==
              GeneralRank.highKing) {
            highKings++;
          }
      }
    }

    return ArmyComposition(
      pawns: pawns,
      rooks: rooks,
      knights: knights,
      bishops: bishops,
      generals: generals,
      veteranGenerals: veteranGenerals,
      highKings: highKings,
    );
  }
}
