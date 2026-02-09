import 'package:flutter/material.dart';

import '../../domain/battle_state.dart';
import '../../domain/board_position.dart';
import '../../domain/piece.dart';

class BattleBoardWidget extends StatelessWidget {
  const BattleBoardWidget({
    super.key,
    required this.state,
    required this.selectedPieceId,
    required this.legalMoves,
    required this.onTapSquare,
  });

  final BattleState state;
  final String? selectedPieceId;
  final Set<BoardPosition> legalMoves;
  final ValueChanged<BoardPosition> onTapSquare;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: state.cols / state.rows,
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
          final piece = state.pieceAt(position);
          final isBlocked = state.isBlocked(position);

          final isDarkSquare = (row + col).isOdd;
          final isLegalMove = legalMoves.contains(position);
          final isSelected = piece != null && piece.id == selectedPieceId;

          Color baseColor = isDarkSquare
              ? const Color(0xFF6A7C6A)
              : const Color(0xFFDCE5D0);

          if (isLegalMove) {
            baseColor = const Color(0xFF9CC26B);
          }
          if (isSelected) {
            baseColor = const Color(0xFFFFCC66);
          }
          if (isBlocked) {
            baseColor = const Color(0xFF2B2E34);
          }

          return InkWell(
            onTap: isBlocked ? null : () => onTapSquare(position),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: baseColor,
                border: Border.all(color: Colors.black26),
              ),
              child: piece == null
                  ? const SizedBox.shrink()
                  : Text(
                      _pieceText(piece),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: piece.ownerId == 0
                            ? const Color(0xFF0E2D56)
                            : const Color(0xFF6C1A1A),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  String _pieceText(BattlePiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return 'P';
      case PieceType.rook:
        return 'R';
      case PieceType.knight:
        return 'N';
      case PieceType.bishop:
        return 'B';
      case PieceType.general:
        return piece.generalSkill == GeneralSkill.veteranCommander
            ? 'G2'
            : 'G1';
    }
  }
}
