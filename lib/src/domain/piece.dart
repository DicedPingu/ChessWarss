import 'board_position.dart';

enum PieceType { pawn, rook, knight, bishop, general }

enum GeneralSkill { fieldCommander, veteranCommander }

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
    return generalSkill == GeneralSkill.veteranCommander ? 2 : 1;
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
    final updatedSkill = updatedExperience >= 2
        ? GeneralSkill.veteranCommander
        : generalSkill;
    return copyWith(
      generalExperience: updatedExperience,
      generalSkill: updatedSkill,
    );
  }
}
