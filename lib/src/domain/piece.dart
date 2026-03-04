import 'board_position.dart';

enum PieceType { pawn, rook, knight, bishop, general }

enum GeneralRank { highKing, officer }

enum GeneralSkill {
  fragileMarshal,
  fieldCommander,
  veteranCommander,
  warDrummer,
}

enum GeneralTraitFamily { stability, aggression, momentum, volatility }

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
        return 'Volatile: Morale swings are amplified (+/-). Panic risk if threatened.';
      case GeneralSkill.fieldCommander:
        return 'Stability: Mitigates local morale shocks. No special active skill.';
      case GeneralSkill.veteranCommander:
        return 'Aggression: Stronger contact impact (+1 swing). One group advance.';
      case GeneralSkill.warDrummer:
        return 'Momentum: Faster morale gain from movement. One mass advance.';
    }
  }

  GeneralTraitFamily get traitFamily {
    switch (this) {
      case GeneralSkill.fragileMarshal:
        return GeneralTraitFamily.volatility;
      case GeneralSkill.fieldCommander:
        return GeneralTraitFamily.stability;
      case GeneralSkill.veteranCommander:
        return GeneralTraitFamily.aggression;
      case GeneralSkill.warDrummer:
        return GeneralTraitFamily.momentum;
    }
  }

  String get traitFamilyLabel {
    switch (traitFamily) {
      case GeneralTraitFamily.stability:
        return 'Stability';
      case GeneralTraitFamily.aggression:
        return 'Aggression';
      case GeneralTraitFamily.momentum:
        return 'Momentum';
      case GeneralTraitFamily.volatility:
        return 'Volatility';
    }
  }
}

extension GeneralRankProfile on GeneralRank {
  String get publicLabel {
    switch (this) {
      case GeneralRank.highKing:
        return 'High King';
      case GeneralRank.officer:
        return 'Officer';
    }
  }
}

class CommandProfile {
  const CommandProfile({
    required this.rank,
    required this.skill,
    required this.passive,
    required this.active,
  });

  final GeneralRank rank;
  final GeneralSkill skill;
  final String passive;
  final String active;

  String get label => '${rank.publicLabel}: ${skill.publicLabel}';
}

class BattlePiece {
  const BattlePiece({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.position,
    this.generalSkill,
    this.generalRank,
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
  final GeneralRank? generalRank;
  final int generalExperience;

  bool get isGeneral => type == PieceType.general;

  GeneralRank get resolvedGeneralRank {
    if (!isGeneral) {
      return GeneralRank.officer;
    }
    return generalRank ?? GeneralRank.highKing;
  }

  int get commandWeight {
    if (!isGeneral) {
      return 0;
    }
    final base = switch (generalSkill) {
      GeneralSkill.fragileMarshal => 0,
      GeneralSkill.fieldCommander => 1,
      GeneralSkill.veteranCommander => 2,
      GeneralSkill.warDrummer => 3,
      null => 1,
    };
    return resolvedGeneralRank == GeneralRank.highKing ? base + 1 : base;
  }

  CommandProfile get commandProfile {
    final skill = generalSkill ?? GeneralSkill.fieldCommander;
    final rank = resolvedGeneralRank;
    final passive = switch (skill) {
      GeneralSkill.fragileMarshal =>
        rank == GeneralRank.highKing
            ? 'Court volatility: Amplified morale swings. Troops lose nerve when threatened.'
            : 'Nervous command: Amplified morale swings. Troops may retreat under pressure.',
      GeneralSkill.fieldCommander =>
        rank == GeneralRank.highKing
            ? 'Royal stability: Stronger mitigation of morale shocks and rout checks.'
            : 'Steady command: Mitigates local morale shocks.',
      GeneralSkill.veteranCommander =>
        rank == GeneralRank.highKing
            ? 'Crown aggression: Max contact impact bonus. Stronger rally.'
            : 'Seasoned aggression: Contact impact bonus. Improved rally.',
      GeneralSkill.warDrummer =>
        rank == GeneralRank.highKing
            ? 'Royal momentum: Fast morale gain. Highest rally pressure.'
            : 'Drum momentum: Fast morale gain. Major advance pressure.',
    };
    final active = switch (skill) {
      GeneralSkill.fragileMarshal => 'No active command. Panic can trigger.',
      GeneralSkill.fieldCommander => 'No active command. Maintain line.',
      GeneralSkill.veteranCommander =>
        'One stronger contact advance per battle.',
      GeneralSkill.warDrummer => 'One mass contact advance per battle.',
    };
    return CommandProfile(
      rank: rank,
      skill: skill,
      passive: passive,
      active: active,
    );
  }

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
    GeneralRank? generalRank,
    int? generalExperience,
  }) {
    return BattlePiece(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      position: position ?? this.position,
      generalSkill: isGeneral ? (generalSkill ?? this.generalSkill) : null,
      generalRank: isGeneral ? (generalRank ?? this.generalRank) : null,
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
