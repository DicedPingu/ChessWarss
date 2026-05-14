import 'package:flutter/material.dart';
import 'dart:math' as math;

enum MapTestType { square, hexagonal }

class MapTestScreen extends StatelessWidget {
  const MapTestScreen({super.key, required this.type});

  final MapTestType type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_nameFor(type)} Map Test')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MapPrototypeStatus(type: type),
                const SizedBox(height: 16),
                Expanded(child: _buildBoard(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nameFor(MapTestType type) {
    switch (type) {
      case MapTestType.square:
        return 'Square Grid';
      case MapTestType.hexagonal:
        return 'Hexagonal Grid';
    }
  }

  Widget _buildBoard(BuildContext context) {
    switch (type) {
      case MapTestType.square:
        return const _SquareBoard();
      case MapTestType.hexagonal:
        return const _HexagonalBoard();
    }
  }
}

class _MapPrototypeStatus extends StatelessWidget {
  const _MapPrototypeStatus({required this.type});

  final MapTestType type;

  @override
  Widget build(BuildContext context) {
    final (works, notProven, direction) = switch (type) {
      MapTestType.square => (
        'Works: classic 8x8 coordinate board.',
        'Not proven: no logistics, terrain, fortification, or AI behavior.',
        'Direction: use as the chess baseline for every experimental rule.',
      ),
      MapTestType.hexagonal => (
        'Works: readable six-edged map field.',
        'Not proven: no unit rules, ownership, supply, combat, or AI behavior.',
        'Direction: test whether hex movement helps campaign play without losing chess clarity.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EEDB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x338A6A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prototype Status',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(works, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(notProven, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(direction, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SquareBoard extends StatelessWidget {
  const _SquareBoard();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final row = index ~/ 8;
        final col = index % 8;
        final isDark = (row + col) % 2 == 1;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.brown.shade400 : Colors.brown.shade200,
            border: Border.all(color: Colors.brown.shade800, width: 0.5),
          ),
          child: Center(
            child: Text(
              '$col,$row',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HexagonalBoard extends StatelessWidget {
  const _HexagonalBoard();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HexGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.green.shade200
      ..style = PaintingStyle.fill;

    // Use a fixed hex radius for rendering
    const hexRadius = 40.0;
    final hexWidth = math.sqrt(3) * hexRadius;
    final hexHeight = 2 * hexRadius;
    final vertDist = hexHeight * 0.75; // Distance between rows
    final horizDist = hexWidth; // Distance between columns

    final cols = (size.width / horizDist).ceil();
    final rows = (size.height / vertDist).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // Offset odd rows by half width
        final offsetX = col * horizDist + (row % 2 == 1 ? horizDist / 2 : 0);
        final offsetY = row * vertDist;

        if (offsetX > size.width || offsetY > size.height) continue;

        _drawHex(
          canvas,
          Offset(offsetX + horizDist / 2, offsetY + hexHeight / 2),
          hexRadius,
          strokePaint,
          fillPaint,
        );
      }
    }
  }

  void _drawHex(
    Canvas canvas,
    Offset center,
    double radius,
    Paint stroke,
    Paint fill,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Pointy top hex: start at -30 deg
      final angle = math.pi / 180 * (60 * i - 30);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
