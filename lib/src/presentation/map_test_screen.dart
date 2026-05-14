import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MapTestType { hexOpen, hexChoke, commanderClash }

extension MapTestTypeCopy on MapTestType {
  String get cardTitle => switch (this) {
    MapTestType.hexOpen => 'Open Hex March',
    MapTestType.hexChoke => 'Hex Chokepoints',
    MapTestType.commanderClash => 'Commander Clash',
  };

  String get title => cardTitle;

  String get subtitle => switch (this) {
    MapTestType.hexOpen => 'Fluid six-way movement and attack preview',
    MapTestType.hexChoke => 'Rivers, hills, crossings, and tactical lanes',
    MapTestType.commanderClash =>
      'Generals, threat range, and command identity',
  };

  String get worksNow => switch (this) {
    MapTestType.hexOpen =>
      'Select the active army, tap a lit hex, and the turn ends automatically.',
    MapTestType.hexChoke =>
      'Test whether terrain blockers and crossings make movement readable.',
    MapTestType.commanderClash =>
      'Test whether commanders are obvious, threatening, and worth protecting.',
  };

  String get notProven => switch (this) {
    MapTestType.hexOpen =>
      'Final combat odds, AI, and multi-army traffic are not proven here.',
    MapTestType.hexChoke =>
      'Whether chokepoints stay fun over a full campaign is not proven.',
    MapTestType.commanderClash =>
      'Final general progression and morale tuning are not proven here.',
  };

  String get direction => switch (this) {
    MapTestType.hexOpen =>
      'Use this as the baseline for campaign movement feel.',
    MapTestType.hexChoke =>
      'Use this if the map needs geography that creates decisions fast.',
    MapTestType.commanderClash =>
      'Use this to make generals visible to both players before battle.',
  };

  IconData get icon => switch (this) {
    MapTestType.hexOpen => Icons.hexagon_rounded,
    MapTestType.hexChoke => Icons.alt_route_rounded,
    MapTestType.commanderClash => Icons.military_tech_rounded,
  };
}

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({super.key, required this.type});

  final MapTestType type;

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  late _HexTrialSpec _spec;
  late Map<_ArmySide, String> _armyTileBySide;
  _ArmySide _activeSide = _ArmySide.rome;
  _ArmySide? _selectedSide;
  int _turn = 1;
  String _log = 'Select the glowing army, then tap a lit hex.';

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant MapTestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeArmy = _spec.army(_activeSide);
    final activeTile = _spec.tile(_armyTileBySide[_activeSide]!);

    return Scaffold(
      backgroundColor: const Color(0xFF101923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101923),
        foregroundColor: Colors.white,
        title: Text('${widget.type.title} Test'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 700 && constraints.maxHeight >= 500;
            final board = _HexTrialBoard(
              spec: _spec,
              activeSide: _activeSide,
              selectedSide: _selectedSide,
              armyTileBySide: _armyTileBySide,
              reachableIds: _reachableIds(),
              onTileTap: _onTileTap,
            );
            final panel = _HexCommandPanel(
              spec: _spec,
              activeArmy: activeArmy,
              activeTile: activeTile,
              selectedSide: _selectedSide,
              turn: _turn,
              log: _log,
              onReset: () => setState(_reset),
            );

            return Padding(
              padding: EdgeInsets.all(wide ? 18 : 10),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 7, child: board),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: panel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 6, child: board),
                        const SizedBox(height: 10),
                        Expanded(flex: 4, child: panel),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  void _reset() {
    _spec = _specFor(widget.type);
    _armyTileBySide = {
      _ArmySide.rome: _spec.army(_ArmySide.rome).startTileId,
      _ArmySide.enemy: _spec.army(_ArmySide.enemy).startTileId,
    };
    _activeSide = _ArmySide.rome;
    _selectedSide = null;
    _turn = 1;
    _log = 'Select the glowing army, then tap a lit hex.';
  }

  Set<String> _reachableIds() {
    if (_selectedSide != _activeSide) return const {};
    final fromId = _armyTileBySide[_activeSide]!;
    return _spec.connectionsFor(fromId).where((id) {
      final tile = _spec.tile(id);
      return !tile.blocked;
    }).toSet();
  }

  void _onTileTap(String tileId) {
    final armyOnTile = _sideAt(tileId);
    if (armyOnTile == _activeSide) {
      setState(() {
        _selectedSide = _activeSide;
        final army = _spec.army(_activeSide);
        _log =
            '${army.name} selected. Lit hexes are valid orders; enemy marker means attack.';
      });
      return;
    }

    if (_selectedSide != _activeSide) {
      setState(() {
        _selectedSide = null;
        _log = 'No army selected. Tap the glowing active army first.';
      });
      return;
    }

    final reachable = _reachableIds();
    if (!reachable.contains(tileId)) {
      setState(() {
        _selectedSide = null;
        _log = 'Selection cleared. Tap your army again to issue an order.';
      });
      return;
    }

    setState(() {
      final attacker = _spec.army(_activeSide);
      final defenderSide = _sideAt(tileId);
      _selectedSide = null;
      if (defenderSide != null && defenderSide != _activeSide) {
        final defender = _spec.army(defenderSide);
        _log =
            '${attacker.name} attacks ${defender.name}. Turn auto-ended so the other side can answer.';
      } else {
        final tile = _spec.tile(tileId);
        _armyTileBySide[_activeSide] = tileId;
        _log =
            '${attacker.name} moved to ${tile.label}. Turn auto-ended. Select the next army.';
      }
      _activeSide = _activeSide == _ArmySide.rome
          ? _ArmySide.enemy
          : _ArmySide.rome;
      _turn += 1;
    });
  }

  _ArmySide? _sideAt(String tileId) {
    for (final entry in _armyTileBySide.entries) {
      if (entry.value == tileId) return entry.key;
    }
    return null;
  }
}

class _HexTrialBoard extends StatelessWidget {
  const _HexTrialBoard({
    required this.spec,
    required this.activeSide,
    required this.selectedSide,
    required this.armyTileBySide,
    required this.reachableIds,
    required this.onTileTap,
  });

  final _HexTrialSpec spec;
  final _ArmySide activeSide;
  final _ArmySide? selectedSide;
  final Map<_ArmySide, String> armyTileBySide;
  final Set<String> reachableIds;
  final ValueChanged<String> onTileTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF172536),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7C25E), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 0,
            offset: Offset(5, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide;
            final tileSize = spec.tileSizeFor(size);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _HexRoutePainter(spec: spec),
                  isComplex: true,
                  willChange: false,
                ),
                for (final tile in spec.tiles)
                  Positioned(
                    left: tile.x * size - tileSize / 2,
                    top: tile.y * size - tileSize / 2,
                    width: tileSize,
                    height: tileSize,
                    child: _HexTrialTile(
                      tile: tile,
                      army: _armyAt(tile.id),
                      activeSide: activeSide,
                      selectedSide: selectedSide,
                      reachable: reachableIds.contains(tile.id),
                      onTap: () => onTileTap(tile.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  _TrialArmy? _armyAt(String tileId) {
    for (final entry in armyTileBySide.entries) {
      if (entry.value == tileId) return spec.army(entry.key);
    }
    return null;
  }
}

class _HexTrialTile extends StatelessWidget {
  const _HexTrialTile({
    required this.tile,
    required this.army,
    required this.activeSide,
    required this.selectedSide,
    required this.reachable,
    required this.onTap,
  });

  final _HexTile tile;
  final _TrialArmy? army;
  final _ArmySide activeSide;
  final _ArmySide? selectedSide;
  final bool reachable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeArmy = army != null && army!.side == activeSide;
    final selectedArmy = army != null && army!.side == selectedSide;
    final borderColor = selectedArmy
        ? Colors.white
        : reachable
        ? const Color(0xFFFFD166)
        : activeArmy
        ? army!.color
        : const Color(0xFF28445A);
    final fillColor = tile.blocked
        ? const Color(0xFF4C5260)
        : reachable
        ? Color.alphaBlend(const Color(0x66FFD166), tile.color)
        : tile.color;

    return Tooltip(
      message: '${tile.label}: ${tile.terrain}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('map-test-tile-${tile.id}'),
          onTap: onTap,
          customBorder: const _HexagonBorder(),
          child: Ink(
            decoration: ShapeDecoration(
              color: fillColor,
              shape: _HexagonBorder(
                side: BorderSide(
                  color: borderColor,
                  width: selectedArmy || activeArmy || reachable ? 3 : 1.2,
                ),
              ),
              shadows: [
                if (activeArmy || reachable)
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.42),
                    blurRadius: 9,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (tile.blocked)
                  const Icon(
                    Icons.block_rounded,
                    color: Colors.white70,
                    size: 20,
                  )
                else
                  Text(
                    tile.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (reachable && army == null)
                  const Positioned(
                    bottom: 4,
                    child: _OrderBadge(text: 'MOVE', icon: Icons.near_me),
                  ),
                if (reachable && army != null && army!.side != activeSide)
                  const Positioned(
                    bottom: 4,
                    child: _OrderBadge(
                      text: 'ATTACK',
                      icon: Icons.sports_martial_arts,
                    ),
                  ),
                if (army != null)
                  _ArmyMarker(
                    key: ValueKey('map-test-army-${army!.side.name}'),
                    army: army!,
                    active: activeArmy,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArmyMarker extends StatelessWidget {
  const _ArmyMarker({super.key, required this.army, required this.active});

  final _TrialArmy army;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: army.color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: active ? 2.4 : 1.2),
        boxShadow: active
            ? [
                BoxShadow(
                  color: army.color.withValues(alpha: 0.55),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(army.icon, size: 13, color: Colors.white),
              const SizedBox(width: 2),
              Text(
                army.shortName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD111B25),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: const Color(0xFFFFD166)),
            const SizedBox(width: 2),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexCommandPanel extends StatelessWidget {
  const _HexCommandPanel({
    required this.spec,
    required this.activeArmy,
    required this.activeTile,
    required this.selectedSide,
    required this.turn,
    required this.log,
    required this.onReset,
  });

  final _HexTrialSpec spec;
  final _TrialArmy activeArmy;
  final _HexTile activeTile;
  final _ArmySide? selectedSide;
  final int turn;
  final String log;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final selected = selectedSide == activeArmy.side;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7C8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3D1D13), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 0,
            offset: Offset(4, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spec.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3D1D13),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.feel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4C3525),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _CommandStrip(
              color: activeArmy.color,
              text:
                  'Turn $turn: ${activeArmy.name} at ${activeTile.label}${selected ? ' - choose target' : ' - select army'}',
            ),
            const SizedBox(height: 8),
            _GeneralCard(army: activeArmy),
            const SizedBox(height: 8),
            _InfoLine(
              label: 'Controls',
              text:
                  'Tap active army -> tap lit hex. Moving or attacking auto-ends the turn. Other taps clear selection.',
            ),
            _InfoLine(label: 'Works', text: spec.worksNow),
            _InfoLine(label: 'Watch', text: spec.notProven),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8D6B48)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      log,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3D1D13),
                        fontWeight: FontWeight.w900,
                        height: 1.14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                tooltip: 'Reset trial',
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandStrip extends StatelessWidget {
  const _CommandStrip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D1D13), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.ads_click_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.army});

  final _TrialArmy army;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x668D6B48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.military_tech_rounded, color: army.color, size: 23),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${army.generalName}: ${army.commandTrait}. ${army.commandHint}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF3D1D13),
                  fontWeight: FontWeight.w800,
                  height: 1.14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        '$label: $text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF4C3525),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HexRoutePainter extends CustomPainter {
  const _HexRoutePainter({required this.spec});

  final _HexTrialSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = spec.routeColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in spec.edges) {
      final a = spec.tile(edge.a);
      final b = spec.tile(edge.b);
      canvas.drawLine(
        Offset(a.x * size.width, a.y * size.height),
        Offset(b.x * size.width, b.y * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HexRoutePainter oldDelegate) {
    return oldDelegate.spec != spec;
  }
}

class _HexTrialSpec {
  _HexTrialSpec({
    required this.name,
    required this.feel,
    required this.worksNow,
    required this.notProven,
    required this.background,
    required this.routeColor,
    required this.tiles,
    required this.edges,
    required this.armies,
  }) : tileById = Map.unmodifiable({for (final tile in tiles) tile.id: tile}),
       armyBySide = Map.unmodifiable({
         for (final army in armies) army.side: army,
       });

  final String name;
  final String feel;
  final String worksNow;
  final String notProven;
  final Color background;
  final Color routeColor;
  final List<_HexTile> tiles;
  final List<_HexEdge> edges;
  final List<_TrialArmy> armies;
  final Map<String, _HexTile> tileById;
  final Map<_ArmySide, _TrialArmy> armyBySide;

  _HexTile tile(String id) => tileById[id]!;

  _TrialArmy army(_ArmySide side) => armyBySide[side]!;

  Set<String> connectionsFor(String id) {
    return {
      for (final edge in edges)
        if (edge.a == id) edge.b else if (edge.b == id) edge.a,
    };
  }

  double tileSizeFor(double boardSize) {
    return (boardSize / 7.3).clamp(38, 68).toDouble();
  }
}

class _HexTile {
  const _HexTile({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.terrain,
    required this.color,
    this.blocked = false,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final String terrain;
  final Color color;
  final bool blocked;
}

class _HexEdge {
  const _HexEdge(this.a, this.b);

  final String a;
  final String b;
}

class _TrialArmy {
  const _TrialArmy({
    required this.side,
    required this.name,
    required this.shortName,
    required this.generalName,
    required this.commandTrait,
    required this.commandHint,
    required this.startTileId,
    required this.color,
    required this.icon,
  });

  final _ArmySide side;
  final String name;
  final String shortName;
  final String generalName;
  final String commandTrait;
  final String commandHint;
  final String startTileId;
  final Color color;
  final IconData icon;
}

enum _ArmySide { rome, enemy }

class _HexagonBorder extends OutlinedBorder {
  const _HexagonBorder({super.side});

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return _HexagonBorder(side: side ?? this.side);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _hexPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _hexPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_hexPath(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) {
    return _HexagonBorder(side: side.scale(t));
  }

  Path _hexPath(Rect rect) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }
}

_HexTrialSpec _specFor(MapTestType type) {
  return switch (type) {
    MapTestType.hexOpen => _hexOpenSpec(),
    MapTestType.hexChoke => _hexChokeSpec(),
    MapTestType.commanderClash => _commanderClashSpec(),
  };
}

_HexTrialSpec _hexOpenSpec() {
  final (tiles, edges) = _hexGrid(rows: 5, cols: 5);
  return _HexTrialSpec(
    name: MapTestType.hexOpen.title,
    feel: 'Open RTS-style movement: fast, readable, and low friction.',
    worksNow: MapTestType.hexOpen.worksNow,
    notProven: MapTestType.hexOpen.notProven,
    background: const Color(0xFF1E3C2B),
    routeColor: const Color(0x778FD19E),
    tiles: tiles,
    edges: edges,
    armies: const [
      _TrialArmy(
        side: _ArmySide.rome,
        name: 'Roman Vanguard',
        shortName: 'ROM',
        generalName: 'Aulus Varro',
        commandTrait: 'Veteran Commander',
        commandHint: 'Strong attack tempo; keep him near the front.',
        startTileId: 'H40',
        color: Color(0xFFB83A2B),
        icon: Icons.flag_rounded,
      ),
      _TrialArmy(
        side: _ArmySide.enemy,
        name: 'Hill Host',
        shortName: 'HST',
        generalName: 'Brennos',
        commandTrait: 'War Drummer',
        commandHint: 'Momentum general; dangerous after movement chains.',
        startTileId: 'H04',
        color: Color(0xFF2E6F87),
        icon: Icons.shield_rounded,
      ),
    ],
  );
}

_HexTrialSpec _hexChokeSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    blocked: {'H12', 'H22', 'H32'},
    river: {'H11', 'H21', 'H31'},
  );
  return _HexTrialSpec(
    name: MapTestType.hexChoke.title,
    feel: 'Terrain test: crossings and blocked hills force clear decisions.',
    worksNow: MapTestType.hexChoke.worksNow,
    notProven: MapTestType.hexChoke.notProven,
    background: const Color(0xFF173247),
    routeColor: const Color(0x99CDE8FF),
    tiles: tiles,
    edges: edges
        .where((edge) {
          return !{'H12', 'H22', 'H32'}.contains(edge.a) &&
              !{'H12', 'H22', 'H32'}.contains(edge.b);
        })
        .toList(growable: false),
    armies: const [
      _TrialArmy(
        side: _ArmySide.rome,
        name: 'Bridge Guard',
        shortName: 'BRG',
        generalName: 'Marcus Flaccus',
        commandTrait: 'Field Commander',
        commandHint: 'Stable commander; best for holding crossings.',
        startTileId: 'H40',
        color: Color(0xFFB83A2B),
        icon: Icons.fort_rounded,
      ),
      _TrialArmy(
        side: _ArmySide.enemy,
        name: 'River Raiders',
        shortName: 'RDR',
        generalName: 'Savaric',
        commandTrait: 'Fragile Marshal',
        commandHint: 'Volatile command; pressure may trigger panic.',
        startTileId: 'H04',
        color: Color(0xFF315F7D),
        icon: Icons.water_rounded,
      ),
    ],
  );
}

_HexTrialSpec _commanderClashSpec() {
  final (tiles, edges) = _hexGrid(rows: 4, cols: 5, centerHill: true);
  return _HexTrialSpec(
    name: MapTestType.commanderClash.title,
    feel: 'General visibility test: commanders should feel like real targets.',
    worksNow: MapTestType.commanderClash.worksNow,
    notProven: MapTestType.commanderClash.notProven,
    background: const Color(0xFF322036),
    routeColor: const Color(0x99E7D8FF),
    tiles: tiles,
    edges: edges,
    armies: const [
      _TrialArmy(
        side: _ArmySide.rome,
        name: 'Consular Guard',
        shortName: 'CMD',
        generalName: 'Lucius Drusus',
        commandTrait: 'High King',
        commandHint: 'Command anchor; losing him should feel catastrophic.',
        startTileId: 'H30',
        color: Color(0xFFC14A2C),
        icon: Icons.military_tech_rounded,
      ),
      _TrialArmy(
        side: _ArmySide.enemy,
        name: 'Oathbreaker Guard',
        shortName: 'FOE',
        generalName: 'Morcant',
        commandTrait: 'Veteran Commander',
        commandHint: 'Known enemy commander; watch his threat range.',
        startTileId: 'H04',
        color: Color(0xFF7B2CBF),
        icon: Icons.visibility_rounded,
      ),
    ],
  );
}

(List<_HexTile>, List<_HexEdge>) _hexGrid({
  required int rows,
  required int cols,
  Set<String> blocked = const {},
  Set<String> river = const {},
  bool centerHill = false,
}) {
  final tiles = <_HexTile>[];
  final edges = <_HexEdge>[];
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final id = 'H$row$col';
      final isBlocked = blocked.contains(id);
      final isRiver = river.contains(id);
      final isHill = centerHill && row == rows ~/ 2 && col == cols ~/ 2;
      tiles.add(
        _HexTile(
          id: id,
          label: '${row + 1}.${col + 1}',
          x: 0.12 + col * (0.76 / (cols - 1)) + (row.isOdd ? 0.06 : 0),
          y: 0.14 + row * (0.72 / (rows - 1)),
          terrain: isBlocked
              ? 'Blocked ridge'
              : isRiver
              ? 'River crossing'
              : isHill
              ? 'Command hill'
              : 'Open field',
          color: isBlocked
              ? const Color(0xFF555C65)
              : isRiver
              ? const Color(0xFF2E6F87)
              : isHill
              ? const Color(0xFF8A6A3E)
              : const Color(0xFF3D7A4F),
          blocked: isBlocked,
        ),
      );
    }
  }

  const evenNeighbors = [
    [0, -1],
    [0, 1],
    [-1, -1],
    [-1, 0],
    [1, -1],
    [1, 0],
  ];
  const oddNeighbors = [
    [0, -1],
    [0, 1],
    [-1, 0],
    [-1, 1],
    [1, 0],
    [1, 1],
  ];
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final id = 'H$row$col';
      final neighbors = row.isOdd ? oddNeighbors : evenNeighbors;
      for (final offset in neighbors) {
        final nextRow = row + offset[0];
        final nextCol = col + offset[1];
        if (nextRow < 0 || nextRow >= rows || nextCol < 0 || nextCol >= cols) {
          continue;
        }
        final nextId = 'H$nextRow$nextCol';
        if (!edges.any(
          (edge) =>
              (edge.a == id && edge.b == nextId) ||
              (edge.a == nextId && edge.b == id),
        )) {
          edges.add(_HexEdge(id, nextId));
        }
      }
    }
  }
  return (tiles, edges);
}
