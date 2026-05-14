import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MapTestType { square, hexagonal, provinces, lanes, islands }

extension MapTestTypeCopy on MapTestType {
  String get cardTitle => switch (this) {
    MapTestType.square => 'Square Warboard',
    MapTestType.hexagonal => 'Hex Campaign',
    MapTestType.provinces => 'Province Web',
    MapTestType.lanes => 'Three Fronts',
    MapTestType.islands => 'Island Crossings',
  };

  String get title => switch (this) {
    MapTestType.square => 'Square Warboard',
    MapTestType.hexagonal => 'Hex Campaign',
    MapTestType.provinces => 'Province Web',
    MapTestType.lanes => 'Three Fronts',
    MapTestType.islands => 'Island Crossings',
  };

  String get subtitle => switch (this) {
    MapTestType.square => 'Chess-like control grid',
    MapTestType.hexagonal => 'Six-neighbor campaign movement',
    MapTestType.provinces => 'Named regions and chokepoints',
    MapTestType.lanes => 'North, center, and south pressure lanes',
    MapTestType.islands => 'Ports, crossings, and naval bottlenecks',
  };

  String get worksNow => switch (this) {
    MapTestType.square =>
      'Move a marker through an 8x8 board and compare it to chess clarity.',
    MapTestType.hexagonal =>
      'Move across six-neighbor cells and test whether turns feel more campaign-like.',
    MapTestType.provinces =>
      'Move between connected named regions with obvious chokepoints.',
    MapTestType.lanes =>
      'Test three-route pressure, flanks, and center breakthrough pacing.',
    MapTestType.islands =>
      'Test port-to-port movement and map control with fewer land routes.',
  };

  String get notProven => switch (this) {
    MapTestType.square =>
      'Terrain, supply, army stacking, and AI are not final here.',
    MapTestType.hexagonal =>
      'Balance, combat value, and readability under many armies are not proven.',
    MapTestType.provinces =>
      'Province economy, ownership, and siege rules are not proven.',
    MapTestType.lanes =>
      'Whether lanes get repetitive after many turns is not proven.',
    MapTestType.islands =>
      'Naval movement, transport rules, and blockade rules are not proven.',
  };

  String get direction => switch (this) {
    MapTestType.square =>
      'Use as the control: if a new map is worse than this, cut it.',
    MapTestType.hexagonal =>
      'Use if campaign motion needs smoother borders without losing tactics.',
    MapTestType.provinces =>
      'Use if the campaign should feel like territories, roads, and sieges.',
    MapTestType.lanes =>
      'Use if battles should build readable front lines quickly.',
    MapTestType.islands =>
      'Use if crossings and ports make wars more interesting.',
  };

  IconData get icon => switch (this) {
    MapTestType.square => Icons.grid_4x4_rounded,
    MapTestType.hexagonal => Icons.hexagon_rounded,
    MapTestType.provinces => Icons.map_rounded,
    MapTestType.lanes => Icons.alt_route_rounded,
    MapTestType.islands => Icons.water_rounded,
  };
}

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({super.key, required this.type});

  final MapTestType type;

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  late _MapSpec _spec;
  late String _playerTileId;
  late String _selectedTileId;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _loadSpec();
  }

  @override
  void didUpdateWidget(covariant MapTestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _loadSpec();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _spec.tile(_selectedTileId);
    final canMove = _canMoveTo(_selectedTileId);

    return Scaffold(
      backgroundColor: const Color(0xFFFAE8BC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B2D26),
        foregroundColor: Colors.white,
        title: Text('${widget.type.title} Test'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return Padding(
              padding: EdgeInsets.all(isWide ? 20 : 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(flex: 7, child: _buildBoard()),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 4,
                              child: _MapInfoPanel(
                                spec: _spec,
                                selected: selected,
                                playerTile: _spec.tile(_playerTileId),
                                moves: _moves,
                                canMove: canMove,
                                onMove: _moveToSelected,
                                onReset: _reset,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: _buildBoard()),
                            const SizedBox(height: 10),
                            _MapInfoPanel(
                              spec: _spec,
                              selected: selected,
                              playerTile: _spec.tile(_playerTileId),
                              moves: _moves,
                              canMove: canMove,
                              onMove: _moveToSelected,
                              onReset: _reset,
                              compact: true,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3D1D13), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x333D1D13),
              blurRadius: 0,
              offset: Offset(5, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: RepaintBoundary(
            child: _PlayableMapBoard(
              spec: _spec,
              playerTileId: _playerTileId,
              selectedTileId: _selectedTileId,
              reachableIds: _reachableIds(),
              onSelected: (id) => setState(() => _selectedTileId = id),
            ),
          ),
        ),
      ),
    );
  }

  void _loadSpec() {
    _spec = _specFor(widget.type);
    _playerTileId = _spec.startTileId;
    _selectedTileId = _spec.startTileId;
    _moves = 0;
  }

  bool _canMoveTo(String tileId) {
    return tileId != _playerTileId && _spec.areConnected(_playerTileId, tileId);
  }

  Set<String> _reachableIds() {
    return _spec.connectionsFor(_playerTileId);
  }

  void _moveToSelected() {
    if (!_canMoveTo(_selectedTileId)) return;
    setState(() {
      _playerTileId = _selectedTileId;
      _moves += 1;
    });
  }

  void _reset() {
    setState(_loadSpec);
  }
}

class _PlayableMapBoard extends StatelessWidget {
  const _PlayableMapBoard({
    required this.spec,
    required this.playerTileId,
    required this.selectedTileId,
    required this.reachableIds,
    required this.onSelected,
  });

  final _MapSpec spec;
  final String playerTileId;
  final String selectedTileId;
  final Set<String> reachableIds;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D1D13), width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          final tileSize = spec.tileSizeFor(size);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ConnectionPainter(spec: spec),
                isComplex: true,
                willChange: false,
              ),
              for (final tile in spec.tiles)
                Positioned(
                  left: tile.x * size - tileSize / 2,
                  top: tile.y * size - tileSize / 2,
                  width: tileSize,
                  height: tileSize,
                  child: _MapTileButton(
                    tile: tile,
                    style: spec.tileStyle,
                    isPlayer: tile.id == playerTileId,
                    isSelected: tile.id == selectedTileId,
                    isReachable: reachableIds.contains(tile.id),
                    onTap: () => onSelected(tile.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MapTileButton extends StatelessWidget {
  const _MapTileButton({
    required this.tile,
    required this.style,
    required this.isPlayer,
    required this.isSelected,
    required this.isReachable,
    required this.onTap,
  });

  final _MapTile tile;
  final _TileStyle style;
  final bool isPlayer;
  final bool isSelected;
  final bool isReachable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Colors.white
        : isReachable
        ? const Color(0xFFFFD166)
        : const Color(0xFF3D1D13);
    return Tooltip(
      message: '${tile.label}: ${tile.terrain}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: style.border,
          child: Ink(
            decoration: ShapeDecoration(
              color: tile.color,
              shape: style.shape(borderColor, isSelected ? 3 : 1.3),
              shadows: [
                if (isPlayer || isSelected)
                  const BoxShadow(
                    color: Color(0x553D1D13),
                    blurRadius: 0,
                    offset: Offset(3, 4),
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: tile.textColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (isPlayer)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                if (tile.marker != null && !isPlayer)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(tile.marker, size: 14, color: tile.textColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapInfoPanel extends StatelessWidget {
  const _MapInfoPanel({
    required this.spec,
    required this.selected,
    required this.playerTile,
    required this.moves,
    required this.canMove,
    required this.onMove,
    required this.onReset,
    this.compact = false,
  });

  final _MapSpec spec;
  final _MapTile selected;
  final _MapTile playerTile;
  final int moves;
  final bool canMove;
  final VoidCallback onMove;
  final VoidCallback onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D1D13), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x333D1D13),
            blurRadius: 0,
            offset: Offset(4, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spec.name,
              style: TextStyle(
                color: const Color(0xFF3D1D13),
                fontWeight: FontWeight.w900,
                fontSize: compact ? 16 : 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              spec.feel,
              maxLines: compact ? 2 : 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4C3525),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: 16),
            const _RtsLegend(),
            const SizedBox(height: 6),
            const _InfoLine(
              label: 'Order',
              text: 'Tap a space, then use Move Here if the route is lit.',
            ),
            _InfoLine(label: 'Army', text: playerTile.label),
            _InfoLine(label: 'Moves', text: '$moves'),
            _InfoLine(label: 'Selected', text: selected.label),
            _InfoLine(label: 'Terrain', text: selected.terrain),
            _InfoLine(label: 'Effect', text: selected.note),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2D26),
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF3D1D13),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: canMove ? onMove : null,
                    icon: const Icon(Icons.open_with_rounded),
                    label: const Text('Move Here'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Reset map test',
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ),
            if (!compact) ...[
              const Divider(height: 18),
              _InfoLine(label: 'Works', text: spec.worksNow),
              _InfoLine(label: 'Not proven', text: spec.notProven),
              _InfoLine(label: 'Direction', text: spec.direction),
            ],
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

class _RtsLegend extends StatelessWidget {
  const _RtsLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _LegendChip(color: Color(0xFFFFD166), label: 'Can move'),
        _LegendChip(color: Colors.white, label: 'Selected'),
        _LegendChip(color: Color(0xFF7B2D26), label: 'Army flag'),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0B7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8D6B48)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3D1D13)),
              ),
              child: const SizedBox.square(dimension: 10),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3D1D13),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({required this.spec});

  final _MapSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = spec.connectionColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

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
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.spec != spec;
  }
}

class _MapSpec {
  _MapSpec({
    required this.name,
    required this.feel,
    required this.worksNow,
    required this.notProven,
    required this.direction,
    required this.background,
    required this.connectionColor,
    required this.tileStyle,
    required this.tiles,
    required this.edges,
    required this.startTileId,
  }) : tileById = Map.unmodifiable({for (final tile in tiles) tile.id: tile});

  final String name;
  final String feel;
  final String worksNow;
  final String notProven;
  final String direction;
  final Color background;
  final Color connectionColor;
  final _TileStyle tileStyle;
  final List<_MapTile> tiles;
  final Map<String, _MapTile> tileById;
  final List<_MapEdge> edges;
  final String startTileId;

  _MapTile tile(String id) => tileById[id]!;

  bool areConnected(String a, String b) {
    return edges.any((edge) => edge.matches(a, b));
  }

  Set<String> connectionsFor(String id) {
    return {
      for (final edge in edges)
        if (edge.a == id) edge.b else if (edge.b == id) edge.a,
    };
  }

  double tileSizeFor(double boardSize) {
    return switch (tileStyle) {
      _TileStyle.square => (boardSize / 8.8).clamp(28, 54).toDouble(),
      _TileStyle.hex => (boardSize / 7.4).clamp(34, 64).toDouble(),
      _TileStyle.node => (boardSize / 7).clamp(38, 72).toDouble(),
    };
  }
}

class _MapTile {
  const _MapTile({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.terrain,
    required this.note,
    required this.color,
    this.textColor = Colors.white,
    this.marker,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final String terrain;
  final String note;
  final Color color;
  final Color textColor;
  final IconData? marker;
}

class _MapEdge {
  const _MapEdge(this.a, this.b);

  final String a;
  final String b;

  bool matches(String first, String second) {
    return (a == first && b == second) || (a == second && b == first);
  }
}

enum _TileStyle { square, hex, node }

extension _TileStyleShape on _TileStyle {
  ShapeBorder get border => switch (this) {
    _TileStyle.square => const RoundedRectangleBorder(),
    _TileStyle.hex => const _HexagonBorder(),
    _TileStyle.node => const StadiumBorder(),
  };

  ShapeBorder shape(Color color, double width) {
    return switch (this) {
      _TileStyle.square => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: color, width: width),
      ),
      _TileStyle.hex => _HexagonBorder(
        side: BorderSide(color: color, width: width),
      ),
      _TileStyle.node => StadiumBorder(
        side: BorderSide(color: color, width: width),
      ),
    };
  }
}

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

_MapSpec _specFor(MapTestType type) {
  return switch (type) {
    MapTestType.square => _squareSpec(),
    MapTestType.hexagonal => _hexSpec(),
    MapTestType.provinces => _provinceSpec(),
    MapTestType.lanes => _laneSpec(),
    MapTestType.islands => _islandSpec(),
  };
}

_MapSpec _squareSpec() {
  final tiles = <_MapTile>[];
  final edges = <_MapEdge>[];
  const files = 'ABCDEFGH';
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final id = '${files[col]}${8 - row}';
      final dark = (row + col).isOdd;
      final home = row == 7 && col == 4;
      final enemy = row == 0 && col == 3;
      tiles.add(
        _MapTile(
          id: id,
          label: id,
          x: 0.08 + col * 0.12,
          y: 0.08 + row * 0.12,
          terrain: dark ? 'Dark square' : 'Light square',
          note: dark
              ? 'Fast to read, but it can feel board-game strict.'
              : 'Good chess clarity, weaker campaign geography.',
          color: dark ? const Color(0xFF6E4E37) : const Color(0xFFCBAE7A),
          textColor: dark ? Colors.white : const Color(0xFF2E2118),
          marker: enemy
              ? Icons.flag_circle_rounded
              : home
              ? Icons.home_rounded
              : null,
        ),
      );
      if (col > 0) edges.add(_MapEdge(id, '${files[col - 1]}${8 - row}'));
      if (row > 0) edges.add(_MapEdge(id, '${files[col]}${9 - row}'));
    }
  }
  return _MapSpec(
    name: MapTestType.square.title,
    feel: 'Control test: clean chess readability, least campaign personality.',
    worksNow: MapTestType.square.worksNow,
    notProven: MapTestType.square.notProven,
    direction: MapTestType.square.direction,
    background: const Color(0xFF2B2219),
    connectionColor: Colors.transparent,
    tileStyle: _TileStyle.square,
    tiles: tiles,
    edges: edges,
    startTileId: 'E1',
  );
}

_MapSpec _hexSpec() {
  final tiles = <_MapTile>[];
  final edges = <_MapEdge>[];
  const rows = 5;
  const cols = 5;
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final id = 'H$row$col';
      tiles.add(
        _MapTile(
          id: id,
          label: '${row + 1}.${col + 1}',
          x: 0.12 + col * 0.18 + (row.isOdd ? 0.09 : 0),
          y: 0.13 + row * 0.18,
          terrain: row == 2 && col == 2 ? 'Hill center' : 'Open hex',
          note: row == 2 && col == 2
              ? 'Center pulls armies into a six-way fight.'
              : 'More natural movement than squares, but less chess-native.',
          color: row == 2 && col == 2
              ? const Color(0xFF8A7A3C)
              : const Color(0xFF3D7A4F),
          marker: row == 0 && col == 4 ? Icons.outlined_flag_rounded : null,
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
        if (!edges.any((edge) => edge.matches(id, nextId))) {
          edges.add(_MapEdge(id, nextId));
        }
      }
    }
  }
  return _MapSpec(
    name: MapTestType.hexagonal.title,
    feel: 'Campaign test: smoother borders and more routes around blockers.',
    worksNow: MapTestType.hexagonal.worksNow,
    notProven: MapTestType.hexagonal.notProven,
    direction: MapTestType.hexagonal.direction,
    background: const Color(0xFF203A2B),
    connectionColor: const Color(0x558FD19E),
    tileStyle: _TileStyle.hex,
    tiles: tiles,
    edges: edges,
    startTileId: 'H40',
  );
}

_MapSpec _provinceSpec() {
  final tiles = [
    _node(
      'roma',
      'Roma',
      0.20,
      0.58,
      'Capital',
      'Safe start; every route leaving Rome matters.',
      const Color(0xFF8B2F2F),
      Icons.account_balance_rounded,
    ),
    _node(
      'port',
      'Port',
      0.16,
      0.28,
      'Port',
      'Fast flank route, weak if cut off.',
      const Color(0xFF2E6F87),
      Icons.anchor_rounded,
    ),
    _node(
      'farm',
      'Farm',
      0.42,
      0.72,
      'Farmland',
      'Supply-rich province, exposed from two sides.',
      const Color(0xFF6E8B3D),
      Icons.grass_rounded,
    ),
    _node(
      'pass',
      'Pass',
      0.48,
      0.42,
      'Mountain pass',
      'Natural choke; good for forts and ambushes.',
      const Color(0xFF77706A),
      Icons.terrain_rounded,
    ),
    _node(
      'hill',
      'Hill',
      0.66,
      0.62,
      'Hill town',
      'Good staging point before a siege.',
      const Color(0xFF9A7B3F),
      Icons.landscape_rounded,
    ),
    _node(
      'fort',
      'Fort',
      0.78,
      0.34,
      'Fortress',
      'Defender advantage should feel obvious here.',
      const Color(0xFF5E5A67),
      Icons.fort_rounded,
    ),
    _node(
      'capua',
      'Capua',
      0.84,
      0.76,
      'Enemy city',
      'Objective province; test final approach pressure.',
      const Color(0xFF743E62),
      Icons.flag_circle_rounded,
    ),
  ];
  return _MapSpec(
    name: MapTestType.provinces.title,
    feel: 'Territory test: fewer spaces, stronger geography, clearer politics.',
    worksNow: MapTestType.provinces.worksNow,
    notProven: MapTestType.provinces.notProven,
    direction: MapTestType.provinces.direction,
    background: const Color(0xFF2E3328),
    connectionColor: const Color(0xAAE4C988),
    tileStyle: _TileStyle.node,
    tiles: tiles,
    edges: const [
      _MapEdge('roma', 'port'),
      _MapEdge('roma', 'farm'),
      _MapEdge('roma', 'pass'),
      _MapEdge('port', 'pass'),
      _MapEdge('farm', 'hill'),
      _MapEdge('pass', 'hill'),
      _MapEdge('pass', 'fort'),
      _MapEdge('hill', 'fort'),
      _MapEdge('hill', 'capua'),
      _MapEdge('fort', 'capua'),
    ],
    startTileId: 'roma',
  );
}

_MapSpec _laneSpec() {
  final tiles = [
    _node(
      'homeN',
      'N-Home',
      0.12,
      0.22,
      'Northern muster',
      'Safe lane start.',
      const Color(0xFF476D48),
      Icons.home_rounded,
    ),
    _node(
      'homeC',
      'C-Home',
      0.12,
      0.50,
      'Central muster',
      'Fastest route, easiest to block.',
      const Color(0xFF476D48),
      Icons.home_rounded,
    ),
    _node(
      'homeS',
      'S-Home',
      0.12,
      0.78,
      'Southern muster',
      'Longer but safer flank.',
      const Color(0xFF476D48),
      Icons.home_rounded,
    ),
    _node(
      'fordN',
      'Ford',
      0.36,
      0.22,
      'River ford',
      'Small choke on the north lane.',
      const Color(0xFF387487),
      Icons.water_rounded,
    ),
    _node(
      'bridge',
      'Bridge',
      0.40,
      0.50,
      'Central bridge',
      'The obvious fight point.',
      const Color(0xFF8A6A3E),
      Icons.account_tree_rounded,
    ),
    _node(
      'woods',
      'Woods',
      0.36,
      0.78,
      'Southern woods',
      'Flank route with slower pressure.',
      const Color(0xFF315C36),
      Icons.forest_rounded,
    ),
    _node(
      'campN',
      'N-Camp',
      0.64,
      0.22,
      'Enemy camp',
      'North pressure objective.',
      const Color(0xFF854545),
      Icons.outlined_flag_rounded,
    ),
    _node(
      'keep',
      'Keep',
      0.68,
      0.50,
      'Central keep',
      'Center decides tempo.',
      const Color(0xFF6A576E),
      Icons.fort_rounded,
    ),
    _node(
      'campS',
      'S-Camp',
      0.64,
      0.78,
      'Enemy camp',
      'South pressure objective.',
      const Color(0xFF854545),
      Icons.outlined_flag_rounded,
    ),
    _node(
      'throne',
      'Throne',
      0.88,
      0.50,
      'Final objective',
      'All lanes collapse here.',
      const Color(0xFF9B7A2D),
      Icons.flag_circle_rounded,
    ),
  ];
  return _MapSpec(
    name: MapTestType.lanes.title,
    feel: 'Front-line test: quick readable war, but may become too solved.',
    worksNow: MapTestType.lanes.worksNow,
    notProven: MapTestType.lanes.notProven,
    direction: MapTestType.lanes.direction,
    background: const Color(0xFF282C31),
    connectionColor: const Color(0xAAAFB6C2),
    tileStyle: _TileStyle.node,
    tiles: tiles,
    edges: const [
      _MapEdge('homeN', 'fordN'),
      _MapEdge('homeC', 'bridge'),
      _MapEdge('homeS', 'woods'),
      _MapEdge('fordN', 'campN'),
      _MapEdge('bridge', 'keep'),
      _MapEdge('woods', 'campS'),
      _MapEdge('fordN', 'bridge'),
      _MapEdge('bridge', 'woods'),
      _MapEdge('campN', 'keep'),
      _MapEdge('keep', 'campS'),
      _MapEdge('campN', 'throne'),
      _MapEdge('keep', 'throne'),
      _MapEdge('campS', 'throne'),
    ],
    startTileId: 'homeC',
  );
}

_MapSpec _islandSpec() {
  final tiles = [
    _node(
      'romePort',
      'Rome Port',
      0.16,
      0.62,
      'Home port',
      'Safe harbor and launch point.',
      const Color(0xFF8B2F2F),
      Icons.anchor_rounded,
    ),
    _node(
      'northSea',
      'N-Sea',
      0.34,
      0.32,
      'Sea lane',
      'Fast crossing, exposed to blockade rules later.',
      const Color(0xFF2E6F87),
      Icons.sailing_rounded,
    ),
    _node(
      'southSea',
      'S-Sea',
      0.34,
      0.78,
      'Sea lane',
      'Safer route but longer.',
      const Color(0xFF2E6F87),
      Icons.sailing_rounded,
    ),
    _node(
      'sardinia',
      'Sardinia',
      0.50,
      0.52,
      'Island',
      'Central island controls both crossings.',
      const Color(0xFF6E8B3D),
      Icons.park_rounded,
    ),
    _node(
      'corsica',
      'Corsica',
      0.55,
      0.22,
      'Island fort',
      'Northern stepping stone.',
      const Color(0xFF77706A),
      Icons.fort_rounded,
    ),
    _node(
      'sicily',
      'Sicily',
      0.64,
      0.82,
      'Grain island',
      'Supply objective.',
      const Color(0xFF9A7B3F),
      Icons.grass_rounded,
    ),
    _node(
      'carthage',
      'Carthage',
      0.84,
      0.54,
      'Enemy port',
      'Final port objective.',
      const Color(0xFF743E62),
      Icons.flag_circle_rounded,
    ),
  ];
  return _MapSpec(
    name: MapTestType.islands.title,
    feel:
        'Crossing test: fewer moves, bigger decisions around ports and routes.',
    worksNow: MapTestType.islands.worksNow,
    notProven: MapTestType.islands.notProven,
    direction: MapTestType.islands.direction,
    background: const Color(0xFF183D55),
    connectionColor: const Color(0xAAE9F4FF),
    tileStyle: _TileStyle.node,
    tiles: tiles,
    edges: const [
      _MapEdge('romePort', 'northSea'),
      _MapEdge('romePort', 'southSea'),
      _MapEdge('northSea', 'corsica'),
      _MapEdge('northSea', 'sardinia'),
      _MapEdge('southSea', 'sardinia'),
      _MapEdge('southSea', 'sicily'),
      _MapEdge('corsica', 'carthage'),
      _MapEdge('sardinia', 'carthage'),
      _MapEdge('sicily', 'carthage'),
      _MapEdge('sardinia', 'sicily'),
    ],
    startTileId: 'romePort',
  );
}

_MapTile _node(
  String id,
  String label,
  double x,
  double y,
  String terrain,
  String note,
  Color color,
  IconData marker,
) {
  return _MapTile(
    id: id,
    label: label,
    x: x,
    y: y,
    terrain: terrain,
    note: note,
    color: color,
    marker: marker,
  );
}
