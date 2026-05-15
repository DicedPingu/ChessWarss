import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorldMapLabScreen extends StatelessWidget {
  const WorldMapLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Vision')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E2BF), Color(0xFFE1C48B), Color(0xFFBE8A53)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 920;
                    final preview = Card(
                      color: Colors.white.withValues(alpha: 0.94),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Operational Read',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A single theatre direction: staggered hex sectors, visible marches, clearer front lines, and room for river crossings to matter.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5E4D33),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E0BB),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF8B6335,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: CustomPaint(
                                    painter: const _VisionPainter(),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final notes = Card(
                      color: Colors.white.withValues(alpha: 0.94),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direction',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'The old prototype browser was useful for exploration, but it pulled the project sideways. This screen now shows one campaign direction instead of six competing map gimmicks.',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 14),
                            const _VisionNote(
                              icon: Icons.hexagon_outlined,
                              title: 'Hex Fronts',
                              body:
                                  'Movement should feel like advancing through sectors, not hopping through spreadsheet cells.',
                            ),
                            const SizedBox(height: 12),
                            const _VisionNote(
                              icon: Icons.route_rounded,
                              title: 'Marching Columns',
                              body:
                                  'Armies need visible direction and momentum so the war map feels alive before the chess battle starts.',
                            ),
                            const SizedBox(height: 12),
                            const _VisionNote(
                              icon: Icons.shield_rounded,
                              title: 'Decisive Terrain',
                              body:
                                  'Rivers, crossings, capitals, and frontier provinces should matter more than menu-heavy side systems.',
                            ),
                            const SizedBox(height: 12),
                            const _VisionNote(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Stronger Mood',
                              body:
                                  'The campaign should read like a war chronicle, not a sandbox full of debug-era leftovers.',
                            ),
                          ],
                        ),
                      ),
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: math.min(460, constraints.maxHeight * 0.5),
                            child: preview,
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: notes),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: preview),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: notes),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisionNote extends StatelessWidget {
  const _VisionNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6A4A22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisionPainter extends CustomPainter {
  const _VisionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEAD8AA), Color(0xFFD1B17B)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final radius = math.min(size.width / 10.5, size.height / 8.8);
    final tileWidth = math.sqrt(3) * radius;
    final stepY = radius * 1.5;
    final offsetX = (size.width - ((tileWidth * 5) + (tileWidth / 2))) / 2;
    final offsetY = (size.height - ((stepY * 4) + (radius * 2))) / 2;

    final fills = <Color>[
      const Color(0xFFC69A63),
      const Color(0xFFBF8A5F),
      const Color(0xFFB57B52),
      const Color(0xFFB99663),
    ];
    final frontierPaint = Paint()
      ..color = const Color(0xFF7A261A).withValues(alpha: 0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        final center = Offset(
          offsetX +
              (tileWidth / 2) +
              (col * tileWidth) +
              (row.isOdd ? tileWidth / 2 : 0),
          offsetY + radius + (row * stepY),
        );
        final rect = Rect.fromCenter(
          center: center,
          width: tileWidth,
          height: radius * 2,
        );
        final path = _hexPath(rect);
        final fill = Paint()
          ..color = fills[(row + col) % fills.length]
          ..style = PaintingStyle.fill;
        final border = Paint()
          ..color = const Color(0xFF6E4A28).withValues(alpha: 0.55)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, fill);
        canvas.drawPath(path, border);
      }
    }

    final river = Paint()
      ..color = const Color(0xFF37648B)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final riverGlow = Paint()
      ..color = const Color(0xFF9DC4E2).withValues(alpha: 0.35)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final riverPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.34,
        size.width * 0.36,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.33,
        size.height * 0.78,
        size.width * 0.58,
        size.height * 0.88,
      );
    canvas.drawPath(riverPath, riverGlow);
    canvas.drawPath(riverPath, river);

    final movePath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.58,
        size.width * 0.68,
        size.height * 0.42,
      );
    final movePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9D7A2A), Color(0xFF8C2D1F)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(movePath, movePaint);
    final arrow = Path()
      ..moveTo(size.width * 0.68, size.height * 0.42)
      ..lineTo(size.width * 0.64, size.height * 0.405)
      ..lineTo(size.width * 0.645, size.height * 0.445)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF8C2D1F));

    final armyPaint = Paint()..color = const Color(0xFF3A2A1D);
    for (final center in [
      Offset(size.width * 0.23, size.height * 0.72),
      Offset(size.width * 0.68, size.height * 0.42),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 54, height: 16),
          const Radius.circular(8),
        ),
        armyPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(18, 0),
            width: 28,
            height: 10,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFE7D7AA),
      );
    }

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.84),
      frontierPaint,
    );
  }

  Path _hexPath(Rect rect) {
    final center = rect.center;
    return Path()
      ..moveTo(center.dx, rect.top)
      ..lineTo(rect.right, rect.top + (rect.height * 0.25))
      ..lineTo(rect.right, rect.bottom - (rect.height * 0.25))
      ..lineTo(center.dx, rect.bottom)
      ..lineTo(rect.left, rect.bottom - (rect.height * 0.25))
      ..lineTo(rect.left, rect.top + (rect.height * 0.25))
      ..close();
  }

  @override
  bool shouldRepaint(covariant _VisionPainter oldDelegate) => false;
}
