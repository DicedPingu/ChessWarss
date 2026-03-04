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
    this.turnOverlay,
    this.showOverlayArrows = true,
    this.bottomOwnerId,
    this.reduceEffects = false,
  });

  final BattleState state;
  final String? selectedPieceId;
  final Set<BoardPosition> legalMoves;
  final ValueChanged<BoardPosition> onTapSquare;
  final BattleTurnOverlay? turnOverlay;
  final bool showOverlayArrows;
  final int? bottomOwnerId;
  final bool reduceEffects;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pieceByPosition = <BoardPosition, BattlePiece>{
      for (final piece in state.pieces) piece.position: piece,
    };
    final overlayMarks =
        turnOverlay?.marksByPosition ??
        const <BoardPosition, BattleOverlayMark>{};
    final overlayArrows = showOverlayArrows
        ? turnOverlay?.arrows.map(_projectOverlayArrow).toList() ??
              const <BattleOverlayArrow>[]
        : const <BattleOverlayArrow>[];

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
            child: Stack(
              children: [
                GridView.builder(
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: state.rows * state.cols,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: state.cols,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ state.cols;
                    final col = index % state.cols;
                    final position = _displayToBoardPosition(
                      BoardPosition(row, col),
                    );
                    final piece = pieceByPosition[position];
                    final isBlocked = state.isBlocked(position);

                    final isDarkSquare = (row + col).isOdd;
                    final isLegalMove = legalMoves.contains(position);
                    final isSelected =
                        piece != null && piece.id == selectedPieceId;
                    final isActiveTurnPiece =
                        piece != null && piece.ownerId == state.activePlayer;
                    final overlayMark = overlayMarks[position];
                    final baseColor = _squareColor(
                      isDarkSquare: isDarkSquare,
                      isBlocked: isBlocked,
                      isLegalMove: isLegalMove,
                      isSelected: isSelected,
                    );
                    final occupiedColor =
                        piece == null || isBlocked || isSelected
                        ? baseColor
                        : Color.alphaBlend(
                            playerColor(piece.ownerId).withValues(
                              alpha: isActiveTurnPiece ? 0.34 : 0.22,
                            ),
                            baseColor,
                          );
                    final activePieceAccent = piece == null
                        ? null
                        : playerColor(piece.ownerId);

                    return InkWell(
                      onTap: isBlocked ? null : () => onTapSquare(position),
                      child: AnimatedContainer(
                        duration: reduceEffects
                            ? Duration.zero
                            : const Duration(milliseconds: 190),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: occupiedColor,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                          boxShadow: reduceEffects || !isActiveTurnPiece
                              ? const <BoxShadow>[]
                              : [
                                  BoxShadow(
                                    color: activePieceAccent!.withValues(
                                      alpha: 0.46,
                                    ),
                                    blurRadius: 9,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isActiveTurnPiece)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: activePieceAccent!.withValues(
                                          alpha: 0.84,
                                        ),
                                        width: reduceEffects ? 1.2 : 1.9,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (overlayMark != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: _overlayColor(
                                        overlayMark,
                                      ).withValues(alpha: 0.2),
                                      border: Border.all(
                                        color: _overlayColor(overlayMark),
                                        width: reduceEffects ? 1.6 : 2.4,
                                      ),
                                      boxShadow: reduceEffects
                                          ? const []
                                          : [
                                              BoxShadow(
                                                color: _overlayColor(
                                                  overlayMark,
                                                ).withValues(alpha: 0.55),
                                                blurRadius: 8,
                                                spreadRadius: 0.5,
                                              ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                            if (isLegalMove && piece == null)
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: scheme.secondary.withValues(
                                    alpha: 0.42,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (piece != null) _pieceGlyph(piece),
                            if (isActiveTurnPiece)
                              Positioned(
                                top: 1,
                                right: 1,
                                child: Icon(
                                  Icons.flash_on_rounded,
                                  size: 10,
                                  color: activePieceAccent!.withValues(
                                    alpha: 0.96,
                                  ),
                                ),
                              ),
                            if (overlayMark != null && piece == null)
                              Icon(
                                overlayMark == BattleOverlayMark.loss
                                    ? Icons.close_rounded
                                    : Icons.circle,
                                size: overlayMark == BattleOverlayMark.loss
                                    ? 14
                                    : 8,
                                color: _overlayColor(
                                  overlayMark,
                                ).withValues(alpha: 0.92),
                              ),
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
                if (overlayArrows.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _OverlayArrowPainter(
                          arrows: overlayArrows,
                          rows: state.rows,
                          cols: state.cols,
                          soften: reduceEffects,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _flipBoard {
    final bottom = bottomOwnerId;
    if (bottom == null) {
      return false;
    }
    return bottom == state.northPlayerId;
  }

  BoardPosition _displayToBoardPosition(BoardPosition display) {
    if (!_flipBoard) {
      return display;
    }
    return BoardPosition(
      state.rows - 1 - display.row,
      state.cols - 1 - display.col,
    );
  }

  BoardPosition _boardToDisplayPosition(BoardPosition board) {
    if (!_flipBoard) {
      return board;
    }
    return BoardPosition(
      state.rows - 1 - board.row,
      state.cols - 1 - board.col,
    );
  }

  BattleOverlayArrow _projectOverlayArrow(BattleOverlayArrow arrow) {
    if (!_flipBoard) {
      return arrow;
    }
    return BattleOverlayArrow(
      from: _boardToDisplayPosition(arrow.from),
      to: _boardToDisplayPosition(arrow.to),
      mark: arrow.mark,
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

  Color _overlayColor(BattleOverlayMark mark) {
    return _overlayColorForMark(mark);
  }

  Widget _pieceGlyph(BattlePiece piece) {
    final asset = _pieceAsset(piece);
    final color = playerColor(piece.ownerId);
    final onColor = playerOnColor(piece.ownerId);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.62),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 1.3,
              top: 1.3,
              child: SvgPicture.asset(
                asset,
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Color(0x55000000),
                  BlendMode.srcIn,
                ),
              ),
            ),
            SvgPicture.asset(
              asset,
              width: 30,
              height: 30,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            Positioned(
              left: -1,
              top: -1,
              child: Container(
                width: 13,
                height: 13,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.92),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  '${piece.ownerId + 1}',
                  style: TextStyle(
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: onColor,
                  ),
                ),
              ),
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
        return 'assets/pieces/king.svg';
    }
  }
}

Color _overlayColorForMark(BattleOverlayMark mark) {
  return switch (mark) {
    BattleOverlayMark.move => const Color(0xFF2F77D1),
    BattleOverlayMark.capture => const Color(0xFFE1872B),
    BattleOverlayMark.loss => const Color(0xFFC0392B),
    BattleOverlayMark.hazard => const Color(0xFF7B3FB5),
  };
}

class _OverlayArrowPainter extends CustomPainter {
  const _OverlayArrowPainter({
    required this.arrows,
    required this.rows,
    required this.cols,
    required this.soften,
  });

  final List<BattleOverlayArrow> arrows;
  final int rows;
  final int cols;
  final bool soften;

  @override
  void paint(Canvas canvas, Size size) {
    if (arrows.isEmpty || rows <= 0 || cols <= 0) {
      return;
    }
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final strokeWidth = soften ? 1.8 : 2.8;

    for (final arrow in arrows) {
      final color = _overlayColorForMark(arrow.mark);
      final from = Offset(
        (arrow.from.col + 0.5) * cellWidth,
        (arrow.from.row + 0.5) * cellHeight,
      );
      final to = Offset(
        (arrow.to.col + 0.5) * cellWidth,
        (arrow.to.row + 0.5) * cellHeight,
      );

      final delta = to - from;
      final distance = delta.distance;
      if (distance < 2) {
        continue;
      }

      final direction = Offset(delta.dx / distance, delta.dy / distance);
      final normal = Offset(-direction.dy, direction.dx);
      final headLen =
          (cellWidth < cellHeight ? cellWidth : cellHeight) *
          (soften ? 0.18 : 0.24);
      final headWidth = headLen * 0.72;
      final tip = to - direction * 1.5;
      final shaftEnd = tip - direction * headLen * 0.6;

      if (!soften) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth + 2.2;
        canvas.drawLine(from, shaftEnd, glowPaint);
      }

      final shaftPaint = Paint()
        ..color = color.withValues(alpha: soften ? 0.78 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawLine(from, shaftEnd, shaftPaint);

      final headPaint = Paint()
        ..color = color.withValues(alpha: soften ? 0.82 : 0.95)
        ..style = PaintingStyle.fill;
      final headPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - direction.dx * headLen + normal.dx * headWidth,
          tip.dy - direction.dy * headLen + normal.dy * headWidth,
        )
        ..lineTo(
          tip.dx - direction.dx * headLen - normal.dx * headWidth,
          tip.dy - direction.dy * headLen - normal.dy * headWidth,
        )
        ..close();
      canvas.drawPath(headPath, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayArrowPainter oldDelegate) {
    if (oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.soften != soften ||
        oldDelegate.arrows.length != arrows.length) {
      return true;
    }
    for (var i = 0; i < arrows.length; i++) {
      final before = oldDelegate.arrows[i];
      final after = arrows[i];
      if (before.from != after.from ||
          before.to != after.to ||
          before.mark != after.mark) {
        return true;
      }
    }
    return false;
  }
}
