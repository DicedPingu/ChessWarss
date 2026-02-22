import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/battle_state.dart';
import '../../domain/board_position.dart';
import '../../domain/piece.dart';
import '../player_colors.dart';

class BattleBoardWidget extends StatelessWidget {
  const BattleBoardWidget({
    super.key,
    required this.state,
    required this.selectedPieceId,
    required this.legalMoves,
    required this.onTapSquare,
    this.reduceEffects = false,
  });

  final BattleState state;
  final String? selectedPieceId;
  final Set<BoardPosition> legalMoves;
  final ValueChanged<BoardPosition> onTapSquare;
  final bool reduceEffects;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pieceByPosition = <BoardPosition, BattlePiece>{
      for (final piece in state.pieces) piece.position: piece,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: reduceEffects
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2E7CE), Color(0xFFE5D5B7)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7EEDB), Color(0xFFE5D5B7)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8A7652)),
        boxShadow: reduceEffects
            ? const []
            : const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 6),
                  color: Color(0x33000000),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AspectRatio(
          aspectRatio: state.cols / state.rows,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.rows * state.cols,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: state.cols,
              ),
              itemBuilder: (context, index) {
                final row = index ~/ state.cols;
                final col = index % state.cols;
                final position = BoardPosition(row, col);
                final piece = pieceByPosition[position];
                final isBlocked = state.isBlocked(position);

                final isDarkSquare = (row + col).isOdd;
                final isLegalMove = legalMoves.contains(position);
                final isSelected = piece != null && piece.id == selectedPieceId;
                final baseColor = _squareColor(
                  isDarkSquare: isDarkSquare,
                  isBlocked: isBlocked,
                  isLegalMove: isLegalMove,
                  isSelected: isSelected,
                );

                return InkWell(
                  onTap: isBlocked ? null : () => onTapSquare(position),
                  child: AnimatedContainer(
                    duration: reduceEffects
                        ? Duration.zero
                        : const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: baseColor,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isLegalMove && piece == null)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: scheme.secondary.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (piece != null) _pieceGlyph(piece),
                        if (isBlocked)
                          Icon(
                            Icons.block_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        if (isSelected)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFFCF2DB),
                                    width: 2.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _squareColor({
    required bool isDarkSquare,
    required bool isBlocked,
    required bool isLegalMove,
    required bool isSelected,
  }) {
    if (isBlocked) {
      return const Color(0xFF4B545C);
    }
    if (isSelected) {
      return const Color(0xFFF6B663);
    }
    if (isLegalMove) {
      return const Color(0xFFAED184);
    }
    return isDarkSquare ? const Color(0xFFC89660) : const Color(0xFFEED9B8);
  }

  Widget _pieceGlyph(BattlePiece piece) {
    final asset = _pieceAsset(piece);
    final color = playerColor(piece.ownerId);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          children: [
            Positioned(
              left: 1.3,
              top: 1.3,
              child: SvgPicture.asset(
                asset,
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  Color(0x55000000),
                  BlendMode.srcIn,
                ),
              ),
            ),
            SvgPicture.asset(
              asset,
              width: 32,
              height: 32,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            if (piece.type == PieceType.general) _generalSkillBadge(piece),
          ],
        ),
      ),
    );
  }

  Widget _generalSkillBadge(BattlePiece piece) {
    final skill = piece.generalSkill;
    if (skill == null) {
      return const SizedBox.shrink();
    }

    final icon = switch (skill) {
      GeneralSkill.fragileMarshal => Icons.warning_amber_rounded,
      GeneralSkill.fieldCommander => Icons.shield_moon_outlined,
      GeneralSkill.veteranCommander => Icons.military_tech_rounded,
      GeneralSkill.warDrummer => Icons.bolt_rounded,
    };

    final color = switch (skill) {
      GeneralSkill.fragileMarshal => const Color(0xFFC03A2B),
      GeneralSkill.fieldCommander => const Color(0xFF355C4B),
      GeneralSkill.veteranCommander => const Color(0xFFD19A1D),
      GeneralSkill.warDrummer => const Color(0xFF8E3FA0),
    };

    return Positioned(
      right: -1,
      bottom: -1,
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.86), width: 1),
        ),
        child: Icon(icon, size: 9, color: color),
      ),
    );
  }

  String _pieceAsset(BattlePiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return 'assets/pieces/pawn.svg';
      case PieceType.rook:
        return 'assets/pieces/rook.svg';
      case PieceType.knight:
        return 'assets/pieces/knight.svg';
      case PieceType.bishop:
        return 'assets/pieces/bishop.svg';
      case PieceType.general:
        return piece.generalSkill == GeneralSkill.veteranCommander ||
                piece.generalSkill == GeneralSkill.warDrummer
            ? 'assets/pieces/queen.svg'
            : 'assets/pieces/king.svg';
    }
  }
}
