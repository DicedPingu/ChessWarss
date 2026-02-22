import 'board_position.dart';

enum PieceType { pawn, rook, knight, bishop, general }

enum GeneralSkill {
  fragileMarshal,
  fieldCommander,
  veteranCommander,
  warDrummer,
}

extension GeneralSkillProfile on GeneralSkill {
  bool get isNegative {
    return this == GeneralSkill.fragileMarshal;
  }

  bool get grantsMassAdvance {
    return this == GeneralSkill.veteranCommander ||
        this == GeneralSkill.warDrummer;
  }

  bool get visibleToEnemy {
    return this != GeneralSkill.fieldCommander;
  }

  String get publicLabel {
    switch (this) {
      case GeneralSkill.fragileMarshal:
        return 'Fragile Marshal';
      case GeneralSkill.fieldCommander:
        return 'Field Commander';
      case GeneralSkill.veteranCommander:
        return 'Veteran Commander';
      case GeneralSkill.warDrummer:
        return 'War Drummer';
    }
  }

  String get perkDescription {
    switch (this) {
      case GeneralSkill.fragileMarshal:
        return 'If threatened, nearby troops may retreat and lose morale.';
      case GeneralSkill.fieldCommander:
        return 'Stable command presence with no special active skill.';
      case GeneralSkill.veteranCommander:
        return 'Can trigger a stronger group advance once per battle.';
      case GeneralSkill.warDrummer:
        return 'Can trigger a mass advance once per battle.';
    }
  }
}

class BattlePiece {
  const BattlePiece({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.position,
    this.generalSkill,
    this.generalExperience = 0,
  }) : assert(
         type != PieceType.general || generalSkill != null,
         'General pieces must have a GeneralSkill.',
       );

  final String id;
  final int ownerId;
  final PieceType type;
  final BoardPosition position;
  final GeneralSkill? generalSkill;
  final int generalExperience;

  bool get isGeneral => type == PieceType.general;

  int get generalStride {
    if (!isGeneral) {
      return 0;
    }
    // Alpha balance: generals are king-like commanders for all tiers.
    return 1;
  }

  BattlePiece copyWith({
    String? id,
    int? ownerId,
    PieceType? type,
    BoardPosition? position,
    GeneralSkill? generalSkill,
    int? generalExperience,
  }) {
    return BattlePiece(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      position: position ?? this.position,
      generalSkill: isGeneral ? (generalSkill ?? this.generalSkill) : null,
      generalExperience: generalExperience ?? this.generalExperience,
    );
  }

  BattlePiece gainGeneralExperience([int amount = 1]) {
    if (!isGeneral) {
      return this;
    }

    final updatedExperience = generalExperience + amount;
    final currentSkill = generalSkill ?? GeneralSkill.fieldCommander;
    GeneralSkill updatedSkill = currentSkill;

    if (currentSkill == GeneralSkill.fragileMarshal && updatedExperience >= 2) {
      updatedSkill = GeneralSkill.fieldCommander;
    }

    if (updatedExperience >= 3) {
      updatedSkill = GeneralSkill.warDrummer;
    } else if (updatedExperience >= 2 &&
        currentSkill != GeneralSkill.fragileMarshal) {
      updatedSkill = GeneralSkill.veteranCommander;
    }

    return copyWith(
      generalExperience: updatedExperience,
      generalSkill: updatedSkill,
    );
  }
}
