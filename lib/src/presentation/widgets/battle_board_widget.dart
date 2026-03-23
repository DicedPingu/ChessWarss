import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4E4BE), Color(0xFFDDC08A), Color(0xFFC49B63)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7A5934), width: 1.4),
        boxShadow: reduceEffects
            ? const []
            : const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Color(0x2A000000),
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BattlefieldTheatrePainter(
                        rows: state.rows,
                        cols: state.cols,
                        southColor: playerColor(state.southPlayerId),
                        northColor: playerColor(state.northPlayerId),
                        soften: reduceEffects,
                      ),
                    ),
                  ),
                ),
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

                    final isLegalMove = legalMoves.contains(position);
                    final isSelected =
                        piece != null && piece.id == selectedPieceId;
                    final isActiveTurnPiece =
                        piece != null && piece.ownerId == state.activePlayer;
                    final overlayMark = overlayMarks[position];
                    final baseColor = _squareColor(
                      row: row,
                      col: col,
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
                              ).animate().scale(
                                duration: 200.ms,
                                curve: Curves.easeOutBack,
                              ),
                            if (piece != null)
                              Tooltip(
                                message: _pieceDescription(piece),
                                child: _pieceGlyph(piece)
                                    .animate(
                                      key: ValueKey(
                                        '${piece.id}-${piece.position}',
                                      ),
                                    )
                                    .scale(
                                      duration: 300.ms,
                                      curve: Curves.elasticOut,
                                    )
                                    .fadeIn(duration: 200.ms),
                              ),
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
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .fade(duration: 600.ms, begin: 0.5, end: 1.0),
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
                  ).animate().fadeIn(duration: 300.ms),
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
    required int row,
    required int col,
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
    final distanceToCenter = (row - ((state.rows - 1) / 2)).abs();
    final clashBand = distanceToCenter <= 1.0;
    final flankBand = col == 0 || col == state.cols - 1;
    var base = clashBand ? const Color(0xFFD0A06A) : const Color(0xFFE9D5AF);
    if ((row + col).isOdd) {
      base = Color.alphaBlend(const Color(0x11A36E3E), base);
    }
    if (flankBand) {
      base = Color.alphaBlend(const Color(0x114A3A28), base);
    }
    return base;
  }

  Color _overlayColor(BattleOverlayMark mark) {
    return _overlayColorForMark(mark);
  }

  String _pieceDescription(BattlePiece piece) {
    final type = piece.type.name.toUpperCase();
    final behavior = switch (piece.type) {
      PieceType.pawn =>
        'Pawn infantry: Holds the line, advances straight, captures on the forward diagonal.',
      PieceType.knight =>
        'Knight cavalry: Leaps in L-shape to flank or break through.',
      PieceType.bishop =>
        'Bishop skirmishers: Sweep diagonals and pressure open lanes.',
      PieceType.rook =>
        'Rook heavy line: Moves on files and ranks as the hard point of the battle line.',
      PieceType.general =>
        'General command: Leads the army, steadies morale, and anchors the formation.',
    };

    if (piece.type == PieceType.general) {
      final rank = piece.resolvedGeneralRank.name;
      final skill = piece.generalSkill?.publicLabel ?? 'Unskilled';
      return '$type ($rank)\nSkill: $skill\n$behavior';
    }

    return '$type\n$behavior';
  }

  Widget _pieceGlyph(BattlePiece piece) {
    final asset = _pieceAsset(piece);
    final color = playerColor(piece.ownerId);
    final onColor = playerOnColor(piece.ownerId);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PieceStandPainter(piece: piece, color: color),
              ),
            ),
            Positioned(
              left: 6,
              top: 4,
              child: SvgPicture.asset(
                asset,
                width: 28,
                height: 28,
                colorFilter: const ColorFilter.mode(
                  Color(0x55000000),
                  BlendMode.srcIn,
                ),
              ),
            ),
            Positioned(
              left: 4.8,
              top: 2.8,
              child: SvgPicture.asset(
                asset,
                width: 28,
                height: 28,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 15,
                height: 15,
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
            Positioned(
              left: 5,
              right: 5,
              bottom: 1,
              child: Container(
                height: 11,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7E9C5).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: color.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _pieceRoleCode(piece.type),
                  style: TextStyle(
                    fontSize: 7.6,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF352516),
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

  String _pieceRoleCode(PieceType type) {
    return switch (type) {
      PieceType.pawn => 'LINE',
      PieceType.rook => 'ANVIL',
      PieceType.knight => 'WING',
      PieceType.bishop => 'SKIRM',
      PieceType.general => 'CMD',
    };
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

class _BattlefieldTheatrePainter extends CustomPainter {
  const _BattlefieldTheatrePainter({
    required this.rows,
    required this.cols,
    required this.southColor,
    required this.northColor,
    required this.soften,
  });

  final int rows;
  final int cols;
  final Color southColor;
  final Color northColor;
  final bool soften;

  @override
  void paint(Canvas canvas, Size size) {
    if (rows <= 0 || cols <= 0) {
      return;
    }

    final cellWidth = size.width / cols;
    final centerBand = Rect.fromLTWH(
      0,
      size.height * 0.38,
      size.width,
      size.height * 0.24,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            northColor.withValues(alpha: 0.12),
            const Color(0xFFE5C78E).withValues(alpha: 0.35),
            southColor.withValues(alpha: 0.12),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      centerBand,
      Paint()..color = const Color(0xFF8E6231).withValues(alpha: 0.12),
    );

    final lanePaint = Paint()
      ..color = const Color(0xFF5D4528).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var col = 1; col < cols; col++) {
      final x = col * cellWidth;
      canvas.drawLine(
        Offset(x, size.height * 0.12),
        Offset(x, size.height * 0.88),
        lanePaint,
      );
    }

    final frontPaint = Paint()
      ..color = const Color(0xFF5A3217).withValues(alpha: soften ? 0.18 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = soften ? 1.4 : 2.2;
    final upperFront = Path()
      ..moveTo(cellWidth * 0.5, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.36,
        size.width - (cellWidth * 0.5),
        size.height * 0.42,
      );
    final lowerFront = Path()
      ..moveTo(cellWidth * 0.5, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.64,
        size.width - (cellWidth * 0.5),
        size.height * 0.58,
      );
    canvas.drawPath(upperFront, frontPaint);
    canvas.drawPath(lowerFront, frontPaint);

    final wingPaint = Paint()
      ..color = const Color(0xFF8D6A39).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(
      Rect.fromLTWH(
        -cellWidth,
        size.height * 0.18,
        cellWidth * 2.2,
        size.height * 0.46,
      ),
      -0.6,
      1.3,
      false,
      wingPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width - (cellWidth * 1.2),
        size.height * 0.36,
        cellWidth * 2.2,
        size.height * 0.46,
      ),
      2.5,
      1.3,
      false,
      wingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BattlefieldTheatrePainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.soften != soften ||
        oldDelegate.southColor != southColor ||
        oldDelegate.northColor != northColor;
  }
}

class _PieceStandPainter extends CustomPainter {
  const _PieceStandPainter({required this.piece, required this.color});

  final BattlePiece piece;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final plateRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, size.height * 0.42, size.width - 8, size.height * 0.38),
      const Radius.circular(10),
    );
    final platePaint = Paint()
      ..color = const Color(0xFFF7E5C1).withValues(alpha: 0.94);
    canvas.drawRRect(plateRect, platePaint);

    final outline = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(plateRect, outline);

    final accent = Paint()
      ..color = color.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    final ghost = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final centerY = size.height * 0.57;

    switch (piece.type) {
      case PieceType.pawn:
        for (var i = 0; i < 3; i++) {
          final left = 8 + (i * 9.5);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, centerY, 7, 8),
              const Radius.circular(2),
            ),
            i == 1 ? accent : ghost,
          );
        }
      case PieceType.rook:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(8, centerY - 1, size.width - 16, 10),
            const Radius.circular(3),
          ),
          accent,
        );
      case PieceType.knight:
        final path = Path()
          ..moveTo(9, centerY + 8)
          ..lineTo(size.width - 10, centerY + 4)
          ..lineTo(13, centerY - 3)
          ..close();
        canvas.drawPath(path, accent);
      case PieceType.bishop:
        for (var i = 0; i < 3; i++) {
          final offset = 8 + (i * 10.0);
          canvas.drawCircle(Offset(offset + 4, centerY + 5), 3.4, ghost);
          canvas.drawCircle(
            Offset(offset + 7, centerY + 1.2),
            3.0,
            i == 1 ? accent : ghost,
          );
        }
      case PieceType.general:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(9, centerY + 1, size.width - 18, 8),
            const Radius.circular(3),
          ),
          ghost,
        );
        final banner = Path()
          ..moveTo(size.width * 0.28, centerY + 7)
          ..lineTo(size.width * 0.28, centerY - 7)
          ..lineTo(size.width * 0.6, centerY - 5)
          ..lineTo(size.width * 0.5, centerY + 1)
          ..lineTo(size.width * 0.6, centerY + 5)
          ..close();
        canvas.drawPath(banner, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _PieceStandPainter oldDelegate) {
    return oldDelegate.piece != piece || oldDelegate.color != color;
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
