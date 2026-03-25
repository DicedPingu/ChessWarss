import 'dart:math' as math;

import 'package:flutter/material.dart';

class WorldMapLabScreen extends StatefulWidget {
  const WorldMapLabScreen({super.key});

  @override
  State<WorldMapLabScreen> createState() => _WorldMapLabScreenState();
}

class _WorldMapLabScreenState extends State<WorldMapLabScreen> {
  _WorldMapPrototype _selected = _WorldMapPrototype.provinceMosaic;

  void _cyclePrototype(int delta) {
    final values = _WorldMapPrototype.values;
    final currentIndex = values.indexOf(_selected);
    final nextIndex = (currentIndex + delta + values.length) % values.length;
    setState(() {
      _selected = values[nextIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = _MapLabSpec.forPrototype(_selected);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('World Map Lab')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E2BF), Color(0xFFE1C48B), Color(0xFFBE8A53)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final denseScreen = constraints.maxHeight < 760;
                final wide =
                    constraints.maxWidth >= 980 && constraints.maxHeight >= 760;
                final selectorCard = Card(
                  color: Colors.white.withValues(alpha: 0.92),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _cyclePrototype(-1),
                              child: const Icon(Icons.chevron_left_rounded),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    spec.title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    spec.tagline,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF5E4D33),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.tonal(
                              onPressed: () => _cyclePrototype(1),
                              child: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final prototype in _WorldMapPrototype.values)
                              ChoiceChip(
                                label: Text(
                                  _MapLabSpec.forPrototype(prototype).chipLabel,
                                ),
                                selected: prototype == _selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selected = prototype;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                final previewCard = Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!denseScreen) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.account_balance_rounded,
                                  size: 18,
                                ),
                                label: Text(spec.commandFeel),
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.route_rounded,
                                  size: 18,
                                ),
                                label: Text(spec.routeFeel),
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.water_rounded,
                                  size: 18,
                                ),
                                label: Text(spec.waterFeel),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
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
                                painter: _WorldMapLabPainter(
                                  prototype: _selected,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final notesCard = Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Why Try It', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(spec.summary),
                        const SizedBox(height: 12),
                        _LabNote(
                          icon: Icons.military_tech_rounded,
                          title: 'Strength',
                          body: spec.strength,
                        ),
                        const SizedBox(height: 10),
                        _LabNote(
                          icon: Icons.warning_amber_rounded,
                          title: 'Risk',
                          body: spec.risk,
                        ),
                        const SizedBox(height: 10),
                        _LabNote(
                          icon: Icons.travel_explore_rounded,
                          title: 'Best Use',
                          body: spec.bestUse,
                        ),
                        const Spacer(),
                        Text(
                          'Six prototypes are live here now: square legions, flat hex, pointy hex, road nodes, province mosaic, and river corridor.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5E4D33),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final compactNotesCard = Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prototype Read',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          spec.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.military_tech_rounded,
                                size: 18,
                              ),
                              label: Text(spec.commandFeel),
                            ),
                            Chip(
                              avatar: const Icon(Icons.route_rounded, size: 18),
                              label: Text(spec.routeFeel),
                            ),
                            Chip(
                              avatar: const Icon(Icons.water_rounded, size: 18),
                              label: Text(spec.waterFeel),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );

                if (wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selectorCard,
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: previewCard),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: notesCard),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                if (denseScreen) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selectorCard,
                      const SizedBox(height: 12),
                      Expanded(child: previewCard),
                      const SizedBox(height: 12),
                      compactNotesCard,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    selectorCard,
                    const SizedBox(height: 12),
                    Expanded(flex: 5, child: previewCard),
                    const SizedBox(height: 12),
                    Expanded(flex: 3, child: notesCard),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum _WorldMapPrototype {
  squareLegionGrid,
  flatHexMarches,
  pointyHexFrontier,
  roadNodeAtlas,
  provinceMosaic,
  riverCorridor,
}

class _MapLabSpec {
  const _MapLabSpec({
    required this.chipLabel,
    required this.title,
    required this.tagline,
    required this.summary,
    required this.strength,
    required this.risk,
    required this.bestUse,
    required this.commandFeel,
    required this.routeFeel,
    required this.waterFeel,
  });

  final String chipLabel;
  final String title;
  final String tagline;
  final String summary;
  final String strength;
  final String risk;
  final String bestUse;
  final String commandFeel;
  final String routeFeel;
  final String waterFeel;

  static _MapLabSpec forPrototype(_WorldMapPrototype prototype) {
    return switch (prototype) {
      _WorldMapPrototype.squareLegionGrid => const _MapLabSpec(
        chipLabel: 'Square',
        title: 'Square Legion Grid',
        tagline:
            'The current campaign map, but shown as a harder front system.',
        summary:
            'Best for clear front lines, tight river crossings, and straightforward supply pressure without hiding maneuver options.',
        strength:
            'Easy to read. Strong for border wars, settlement sieges, and line-of-march planning.',
        risk:
            'Can feel chessy if the painter and frontage rules do not sell roads, rivers, and territorial depth.',
        bestUse:
            'Baseline campaign map when clarity matters more than romantic geography.',
        commandFeel: 'Front lines',
        routeFeel: 'Road columns',
        waterFeel: 'River chokepoints',
      ),
      _WorldMapPrototype.flatHexMarches => const _MapLabSpec(
        chipLabel: 'Flat Hex',
        title: 'Flat-Top Hex Marches',
        tagline:
            'A classic campaign hex view for slow encirclement and frontier drift.',
        summary:
            'Hexes soften the rigid north-south march pattern and create cleaner flank movement for operational play.',
        strength:
            'Excellent for broad maneuver, screening, and long encirclement games.',
        risk:
            'Supply and settlement control need stronger overlays or the map can become visually noisy.',
        bestUse:
            'Large campaigns where moving around a river line matters as much as smashing through it.',
        commandFeel: 'Wide marches',
        routeFeel: 'Six-way approach',
        waterFeel: 'Banks matter',
      ),
      _WorldMapPrototype.pointyHexFrontier => const _MapLabSpec(
        chipLabel: 'Pointy Hex',
        title: 'Pointy Hex Frontier',
        tagline:
            'A sharper hex presentation that feels more like frontier wedges and invasion corridors.',
        summary:
            'Pointy hexes emphasize diagonals and create a more spearhead-like reading for offensives.',
        strength:
            'Strong visual language for thrusts, raids, and converging columns.',
        risk:
            'Can distort settlement spacing if roads and province edges are not explicit.',
        bestUse:
            'Aggressive campaigns where invasion axes should feel directional and dangerous.',
        commandFeel: 'Spearheads',
        routeFeel: 'Diagonal thrusts',
        waterFeel: 'Crossings exposed',
      ),
      _WorldMapPrototype.roadNodeAtlas => const _MapLabSpec(
        chipLabel: 'Nodes',
        title: 'Road Node Atlas',
        tagline:
            'A civilis-style road and depot map where junctions decide the campaign.',
        summary:
            'Armies move between road hubs instead of tiles, making baggage routes and crossroads the heart of strategy.',
        strength:
            'Perfect for supply logic, depots, escorts, and ambushes on strategic roads.',
        risk:
            'Less terrain-granular. Needs strong battle site generation around nodes and links.',
        bestUse:
            'Campaigns where you want Caesar guarding his roads and barbarians striking the baggage train.',
        commandFeel: 'Road control',
        routeFeel: 'Junction warfare',
        waterFeel: 'Bridge nodes',
      ),
      _WorldMapPrototype.provinceMosaic => const _MapLabSpec(
        chipLabel: 'Provinces',
        title: 'Province Mosaic',
        tagline:
            'Large territorial blocks that read like tribute lands, tribes, and Roman districts.',
        summary:
            'Instead of marching tile by tile, you contest provinces, forts, and river basins as larger political spaces.',
        strength:
            'Excellent for feeling like a conqueror collecting tribute, pacifying regions, and staging deeper offensives.',
        risk:
            'Less tactically precise. Needs good local battle-site selection to keep army movement grounded.',
        bestUse:
            'Grand campaigns focused on occupation, raiding, and treasure extraction.',
        commandFeel: 'Regional rule',
        routeFeel: 'Province pressure',
        waterFeel: 'Basin control',
      ),
      _WorldMapPrototype.riverCorridor => const _MapLabSpec(
        chipLabel: 'Corridor',
        title: 'River Corridor Theatre',
        tagline:
            'A long river campaign where bridges, fords, and grain belts define survival.',
        summary:
            'This style turns the map into a living campaign artery, with cities and depots strung along a dangerous waterway.',
        strength:
            'Makes logistics, bridgeheads, and spoils of rich river provinces immediately legible.',
        risk:
            'Can over-focus the campaign on one axis unless lateral raiding lanes exist.',
        bestUse:
            'Gaul-style campaigns where control of the river valley means control of the war.',
        commandFeel: 'Bridgeheads',
        routeFeel: 'Depot chain',
        waterFeel: 'River lifeline',
      ),
    };
  }
}

class _LabNote extends StatelessWidget {
  const _LabNote({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7B5126)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorldMapLabPainter extends CustomPainter {
  const _WorldMapLabPainter({required this.prototype});

  final _WorldMapPrototype prototype;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    final field = frame.deflate(16);
    _paintBackdrop(canvas, frame);
    _paintPaperNoise(canvas, field);

    switch (prototype) {
      case _WorldMapPrototype.squareLegionGrid:
        _paintSquareGrid(canvas, field);
      case _WorldMapPrototype.flatHexMarches:
        _paintFlatHexMap(canvas, field);
      case _WorldMapPrototype.pointyHexFrontier:
        _paintPointyHexMap(canvas, field);
      case _WorldMapPrototype.roadNodeAtlas:
        _paintRoadNodeAtlas(canvas, field);
      case _WorldMapPrototype.provinceMosaic:
        _paintProvinceMosaic(canvas, field);
      case _WorldMapPrototype.riverCorridor:
        _paintRiverCorridor(canvas, field);
    }
  }

  void _paintBackdrop(Canvas canvas, Rect frame) {
    canvas.drawRect(frame, Paint()..color = const Color(0xFFF0E3BE));
    canvas.drawRect(
      frame.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF89653A).withValues(alpha: 0.45),
    );
  }

  void _paintPaperNoise(Canvas canvas, Rect field) {
    final dust = Paint()
      ..color = const Color(0xFF8D6A3F).withValues(alpha: 0.06);
    for (var i = 0; i < 44; i++) {
      final dx = field.left + (field.width * ((i * 37) % 100) / 100);
      final dy = field.top + (field.height * ((i * 19) % 100) / 100);
      canvas.drawCircle(Offset(dx, dy), 1.2 + (i % 3), dust);
    }
  }

  void _paintSquareGrid(Canvas canvas, Rect field) {
    const rows = 6;
    const cols = 7;
    final tileWidth = field.width / cols;
    final tileHeight = field.height / rows;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF7C5A33).withValues(alpha: 0.36);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final rect = Rect.fromLTWH(
          field.left + col * tileWidth,
          field.top + row * tileHeight,
          tileWidth,
          tileHeight,
        );
        final warm = (row + col).isEven;
        canvas.drawRect(
          rect,
          Paint()
            ..color = warm ? const Color(0xFFE6CB94) : const Color(0xFFD8B57D),
        );
        canvas.drawRect(rect, border);
      }
    }

    final river = Path()
      ..moveTo(field.left + tileWidth * 4.3, field.top)
      ..cubicTo(
        field.left + tileWidth * 4.0,
        field.top + tileHeight * 1.3,
        field.left + tileWidth * 5.2,
        field.top + tileHeight * 3.0,
        field.left + tileWidth * 4.6,
        field.bottom,
      );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tileWidth * 0.38
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF76A7BE).withValues(alpha: 0.92),
    );

    _paintSupplyRoad(canvas, [
      Offset(field.left + tileWidth * 1.2, field.bottom - tileHeight * 0.8),
      Offset(field.left + tileWidth * 2.4, field.bottom - tileHeight * 1.1),
      Offset(field.left + tileWidth * 3.1, field.top + tileHeight * 3.4),
      Offset(field.left + tileWidth * 3.9, field.top + tileHeight * 2.4),
    ]);
    _paintSettlement(
      canvas,
      Offset(field.left + tileWidth * 1.2, field.bottom - tileHeight * 0.8),
      isCapital: true,
    );
    _paintSettlement(
      canvas,
      Offset(field.left + tileWidth * 3.9, field.top + tileHeight * 2.4),
    );
    _paintSettlement(
      canvas,
      Offset(field.left + tileWidth * 5.8, field.top + tileHeight * 1.5),
    );

    _paintArmyBlock(
      canvas,
      Offset(field.left + tileWidth * 2.5, field.top + tileHeight * 4.2),
      const Color(0xFF9F2F25),
      rotation: -0.14,
    );
    _paintArmyBlock(
      canvas,
      Offset(field.left + tileWidth * 5.0, field.top + tileHeight * 1.7),
      const Color(0xFF234C77),
      rotation: 0.12,
    );
  }

  void _paintFlatHexMap(Canvas canvas, Rect field) {
    const rows = 5;
    const cols = 6;
    final radius = math.min(field.width / 8.4, field.height / 7.4);
    final xStep = radius * 1.7;
    final yStep = radius * 1.5;
    final start = Offset(field.left + radius * 1.4, field.top + radius * 1.3);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final center = Offset(
          start.dx + col * xStep + (row.isOdd ? xStep * 0.5 : 0),
          start.dy + row * yStep,
        );
        final path = _flatHex(center, radius);
        canvas.drawPath(
          path,
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFFE1C38E)
                : const Color(0xFFD2AB6E),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF7B5C33).withValues(alpha: 0.34),
        );
      }
    }

    final river = Path()
      ..moveTo(field.left + radius * 1.8, field.top + radius * 0.8)
      ..quadraticBezierTo(
        field.center.dx,
        field.top + field.height * 0.35,
        field.right - radius * 1.4,
        field.bottom - radius * 0.9,
      );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.52
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6F9CB2),
    );

    _paintSupplyRoad(canvas, [
      Offset(field.left + radius * 2.2, field.bottom - radius * 1.2),
      Offset(field.left + radius * 3.8, field.bottom - radius * 2.0),
      Offset(field.center.dx, field.center.dy),
      Offset(field.right - radius * 2.0, field.top + radius * 1.6),
    ]);
    _paintSettlement(
      canvas,
      Offset(field.left + radius * 2.2, field.bottom - radius * 1.2),
      isCapital: true,
    );
    _paintSettlement(canvas, Offset(field.center.dx, field.center.dy));
    _paintArmyBlock(
      canvas,
      Offset(
        field.left + field.width * 0.37,
        field.bottom - field.height * 0.23,
      ),
      const Color(0xFFB33A2B),
      rotation: -0.2,
    );
    _paintArmyBlock(
      canvas,
      Offset(field.right - field.width * 0.22, field.top + field.height * 0.28),
      const Color(0xFF365A8C),
      rotation: 0.22,
    );
  }

  void _paintPointyHexMap(Canvas canvas, Rect field) {
    const cols = 6;
    const rows = 5;
    final radius = math.min(field.width / 9.2, field.height / 7.2);
    final xStep = radius * 1.5;
    final yStep = radius * 1.72;
    final start = Offset(field.left + radius * 1.6, field.top + radius * 1.2);

    for (var col = 0; col < cols; col++) {
      for (var row = 0; row < rows; row++) {
        final center = Offset(
          start.dx + col * xStep,
          start.dy + row * yStep + (col.isOdd ? yStep * 0.5 : 0),
        );
        final path = _pointyHex(center, radius);
        canvas.drawPath(
          path,
          Paint()
            ..color = (row + col).isEven
                ? const Color(0xFFE0C08D)
                : const Color(0xFFCFAB73),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0xFF7A5931).withValues(alpha: 0.34),
        );
      }
    }

    _paintSupplyRoad(canvas, [
      Offset(
        field.left + field.width * 0.15,
        field.bottom - field.height * 0.18,
      ),
      Offset(field.left + field.width * 0.34, field.center.dy),
      Offset(field.center.dx, field.top + field.height * 0.38),
      Offset(field.right - field.width * 0.12, field.top + field.height * 0.16),
    ]);
    _paintRiverArc(canvas, [
      Offset(field.left + field.width * 0.1, field.top + field.height * 0.16),
      Offset(field.left + field.width * 0.28, field.top + field.height * 0.3),
      Offset(field.left + field.width * 0.52, field.top + field.height * 0.56),
      Offset(
        field.right - field.width * 0.12,
        field.bottom - field.height * 0.1,
      ),
    ]);
    _paintSettlement(
      canvas,
      Offset(
        field.left + field.width * 0.15,
        field.bottom - field.height * 0.18,
      ),
      isCapital: true,
    );
    _paintSettlement(
      canvas,
      Offset(field.center.dx, field.top + field.height * 0.38),
    );
    _paintArmyBlock(
      canvas,
      Offset(
        field.left + field.width * 0.24,
        field.bottom - field.height * 0.22,
      ),
      const Color(0xFFA33024),
      rotation: -0.28,
    );
    _paintArmyBlock(
      canvas,
      Offset(field.right - field.width * 0.18, field.top + field.height * 0.2),
      const Color(0xFF2E5687),
      rotation: 0.28,
    );
  }

  void _paintRoadNodeAtlas(Canvas canvas, Rect field) {
    final nodes = <Offset>[
      Offset(
        field.left + field.width * 0.12,
        field.bottom - field.height * 0.14,
      ),
      Offset(field.left + field.width * 0.28, field.top + field.height * 0.58),
      Offset(field.center.dx, field.center.dy),
      Offset(field.right - field.width * 0.18, field.top + field.height * 0.2),
      Offset(
        field.right - field.width * 0.12,
        field.bottom - field.height * 0.22,
      ),
      Offset(field.left + field.width * 0.58, field.top + field.height * 0.18),
    ];

    final provincePaint = Paint()
      ..color = const Color(0xFFDDB57A).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: field.center,
        width: field.width * 0.72,
        height: field.height * 0.56,
      ),
      provincePaint,
    );

    _paintSupplyRoad(canvas, [nodes[0], nodes[1], nodes[2], nodes[3]]);
    _paintSupplyRoad(canvas, [nodes[1], nodes[5], nodes[3], nodes[4]]);
    _paintSupplyRoad(canvas, [nodes[0], nodes[2], nodes[4]]);
    _paintRiverArc(canvas, [
      Offset(field.left + field.width * 0.05, field.top + field.height * 0.15),
      Offset(field.left + field.width * 0.26, field.top + field.height * 0.34),
      Offset(field.right - field.width * 0.22, field.top + field.height * 0.48),
      Offset(
        field.right - field.width * 0.06,
        field.bottom - field.height * 0.08,
      ),
    ]);

    for (var i = 0; i < nodes.length; i++) {
      _paintSettlement(canvas, nodes[i], isCapital: i == 0 || i == 3);
    }

    _paintArmyBlock(canvas, nodes[2], const Color(0xFFAB3528));
    _paintArmyBlock(
      canvas,
      Offset(field.right - field.width * 0.18, field.top + field.height * 0.22),
      const Color(0xFF345D86),
      rotation: 0.12,
    );
  }

  void _paintProvinceMosaic(Canvas canvas, Rect field) {
    final provinces = <Path>[
      Path()
        ..moveTo(field.left, field.top + field.height * 0.18)
        ..lineTo(field.left + field.width * 0.28, field.top)
        ..lineTo(
          field.left + field.width * 0.44,
          field.top + field.height * 0.2,
        )
        ..lineTo(
          field.left + field.width * 0.32,
          field.top + field.height * 0.44,
        )
        ..lineTo(
          field.left + field.width * 0.06,
          field.top + field.height * 0.42,
        )
        ..close(),
      Path()
        ..moveTo(
          field.left + field.width * 0.32,
          field.top + field.height * 0.44,
        )
        ..lineTo(
          field.left + field.width * 0.44,
          field.top + field.height * 0.2,
        )
        ..lineTo(
          field.right - field.width * 0.08,
          field.top + field.height * 0.14,
        )
        ..lineTo(
          field.right - field.width * 0.14,
          field.top + field.height * 0.46,
        )
        ..lineTo(
          field.left + field.width * 0.54,
          field.top + field.height * 0.58,
        )
        ..close(),
      Path()
        ..moveTo(
          field.left + field.width * 0.06,
          field.top + field.height * 0.42,
        )
        ..lineTo(
          field.left + field.width * 0.32,
          field.top + field.height * 0.44,
        )
        ..lineTo(
          field.left + field.width * 0.54,
          field.top + field.height * 0.58,
        )
        ..lineTo(
          field.left + field.width * 0.38,
          field.bottom - field.height * 0.06,
        )
        ..lineTo(
          field.left + field.width * 0.12,
          field.bottom - field.height * 0.1,
        )
        ..close(),
      Path()
        ..moveTo(
          field.left + field.width * 0.54,
          field.top + field.height * 0.58,
        )
        ..lineTo(
          field.right - field.width * 0.14,
          field.top + field.height * 0.46,
        )
        ..lineTo(field.right, field.top + field.height * 0.62)
        ..lineTo(field.right - field.width * 0.18, field.bottom)
        ..lineTo(
          field.left + field.width * 0.38,
          field.bottom - field.height * 0.06,
        )
        ..close(),
    ];
    final fills = [
      const Color(0xFFE2C58F),
      const Color(0xFFD3AE74),
      const Color(0xFFD9B984),
      const Color(0xFFC89D63),
    ];

    for (var i = 0; i < provinces.length; i++) {
      canvas.drawPath(provinces[i], Paint()..color = fills[i]);
      canvas.drawPath(
        provinces[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF7D5D37).withValues(alpha: 0.46),
      );
    }

    _paintRiverArc(canvas, [
      Offset(field.left + field.width * 0.12, field.top + field.height * 0.16),
      Offset(field.left + field.width * 0.36, field.top + field.height * 0.3),
      Offset(field.left + field.width * 0.56, field.top + field.height * 0.62),
      Offset(
        field.right - field.width * 0.08,
        field.bottom - field.height * 0.08,
      ),
    ]);
    _paintSettlement(
      canvas,
      Offset(field.left + field.width * 0.14, field.top + field.height * 0.16),
      isCapital: true,
    );
    _paintSettlement(
      canvas,
      Offset(field.right - field.width * 0.16, field.top + field.height * 0.2),
      isCapital: true,
    );
    _paintSettlement(
      canvas,
      Offset(field.center.dx, field.top + field.height * 0.56),
    );
    _paintArmyBlock(
      canvas,
      Offset(
        field.left + field.width * 0.28,
        field.bottom - field.height * 0.18,
      ),
      const Color(0xFF9F3427),
      rotation: -0.16,
    );
    _paintArmyBlock(
      canvas,
      Offset(field.right - field.width * 0.2, field.top + field.height * 0.28),
      const Color(0xFF2F5C89),
      rotation: 0.18,
    );
  }

  void _paintRiverCorridor(Canvas canvas, Rect field) {
    final fertileBelt = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        field.left + field.width * 0.18,
        field.top + field.height * 0.06,
        field.width * 0.64,
        field.height * 0.88,
      ),
      const Radius.circular(42),
    );
    canvas.drawRRect(fertileBelt, Paint()..color = const Color(0xFFD8BD85));

    final river = Path()
      ..moveTo(field.center.dx, field.top)
      ..cubicTo(
        field.left + field.width * 0.34,
        field.top + field.height * 0.2,
        field.right - field.width * 0.26,
        field.top + field.height * 0.48,
        field.center.dx,
        field.bottom,
      );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = field.width * 0.12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6D9FB8),
    );
    canvas.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = field.width * 0.02
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD3E6EF).withValues(alpha: 0.78),
    );

    _paintSupplyRoad(canvas, [
      Offset(
        field.left + field.width * 0.22,
        field.bottom - field.height * 0.1,
      ),
      Offset(field.left + field.width * 0.26, field.top + field.height * 0.54),
      Offset(field.left + field.width * 0.3, field.top + field.height * 0.18),
    ]);
    _paintSupplyRoad(canvas, [
      Offset(
        field.right - field.width * 0.22,
        field.bottom - field.height * 0.12,
      ),
      Offset(field.right - field.width * 0.26, field.top + field.height * 0.48),
      Offset(field.right - field.width * 0.3, field.top + field.height * 0.16),
    ]);

    _paintSettlement(
      canvas,
      Offset(field.left + field.width * 0.28, field.top + field.height * 0.16),
      isCapital: true,
    );
    _paintSettlement(
      canvas,
      Offset(field.right - field.width * 0.28, field.top + field.height * 0.18),
      isCapital: true,
    );
    _paintSettlement(canvas, Offset(field.center.dx, field.center.dy));

    _paintArmyBlock(
      canvas,
      Offset(
        field.left + field.width * 0.28,
        field.bottom - field.height * 0.18,
      ),
      const Color(0xFFB13629),
      rotation: -0.1,
    );
    _paintArmyBlock(
      canvas,
      Offset(field.right - field.width * 0.27, field.top + field.height * 0.26),
      const Color(0xFF2E5D8D),
      rotation: 0.1,
    );
  }

  void _paintSupplyRoad(Canvas canvas, List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF7A5125).withValues(alpha: 0.75),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF6E4B6).withValues(alpha: 0.75),
    );
  }

  void _paintRiverArc(Canvas canvas, List<Offset> points) {
    if (points.length < 4) {
      return;
    }
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    path.cubicTo(
      points[1].dx,
      points[1].dy,
      points[2].dx,
      points[2].dy,
      points[3].dx,
      points[3].dy,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF75A8BF).withValues(alpha: 0.92),
    );
  }

  void _paintSettlement(
    Canvas canvas,
    Offset center, {
    bool isCapital = false,
  }) {
    final radius = isCapital ? 10.0 : 7.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isCapital ? const Color(0xFF4E3B20) : const Color(0xFF5F4829),
    );
    canvas.drawCircle(
      center,
      radius - 2.6,
      Paint()
        ..color = isCapital ? const Color(0xFFE8D9B0) : const Color(0xFFD7C188),
    );
  }

  void _paintArmyBlock(
    Canvas canvas,
    Offset center,
    Color color, {
    double rotation = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 34, height: 18),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = color);
    canvas.drawRect(
      Rect.fromLTWH(-14, -16, 2.6, 30),
      Paint()..color = const Color(0xFF4F3215),
    );
    final banner = Path()
      ..moveTo(-11, -15)
      ..lineTo(12, -12)
      ..lineTo(-2, -4)
      ..lineTo(-11, -4)
      ..close();
    canvas.drawPath(banner, Paint()..color = color.withValues(alpha: 0.88));
    canvas.drawLine(
      const Offset(17, 0),
      const Offset(34, 0),
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(27, -5),
      const Offset(34, 0),
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(27, 5),
      const Offset(34, 0),
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  Path _flatHex(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _pointyHex(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 6 + math.pi / 3 * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WorldMapLabPainter oldDelegate) {
    return oldDelegate.prototype != prototype;
  }
}
