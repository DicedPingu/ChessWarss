import 'piece.dart';

class ArmyUnit {
  const ArmyUnit({required this.type, this.generalSkill, this.title})
    : assert(
        type != PieceType.general || generalSkill != null,
        'General units must define a skill.',
      );

  final PieceType type;
  final GeneralSkill? generalSkill;
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
