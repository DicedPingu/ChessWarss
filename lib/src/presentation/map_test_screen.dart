import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MapTestType {
  roadTempo,
  twinCrossing,
  crownHill,
  valleyGate,
  coastalLanding,
  forestScreen,
  supplySpine,
  siegeRing,
  threeApproaches,
  commandPiece,
  generalCohort,
  marchColumn,
}

extension MapTestTypeCopy on MapTestType {
  String get cardTitle => switch (this) {
    MapTestType.roadTempo => 'Road Tempo',
    MapTestType.twinCrossing => 'Twin Crossing',
    MapTestType.crownHill => 'Crown Hill',
    MapTestType.valleyGate => 'Valley Gate',
    MapTestType.coastalLanding => 'Coastal Landing',
    MapTestType.forestScreen => 'Forest Screen',
    MapTestType.supplySpine => 'Supply Spine',
    MapTestType.siegeRing => 'Siege Ring',
    MapTestType.threeApproaches => 'Three Approaches',
    MapTestType.commandPiece => 'Command Piece',
    MapTestType.generalCohort => 'General + Cohort',
    MapTestType.marchColumn => 'March Column',
  };

  String get title => cardTitle;

  String get subtitle => switch (this) {
    MapTestType.roadTempo => 'Fast road',
    MapTestType.twinCrossing => 'Two bridges',
    MapTestType.crownHill => 'High ground',
    MapTestType.valleyGate => 'Gate + flank',
    MapTestType.coastalLanding => 'Ports',
    MapTestType.forestScreen => 'Hidden flank',
    MapTestType.supplySpine => 'Supply line',
    MapTestType.siegeRing => 'Encircle',
    MapTestType.threeApproaches => '3 routes',
    MapTestType.commandPiece => 'One commander',
    MapTestType.generalCohort => 'Full stack',
    MapTestType.marchColumn => 'Moving column',
  };

  String get worksNow => switch (this) {
    MapTestType.roadTempo => 'Road tiles can chain one extra road step.',
    MapTestType.twinCrossing => 'River blocks; bridges open clear fights.',
    MapTestType.crownHill => 'Center hill pulls both armies into contact.',
    MapTestType.valleyGate => 'Short gate or long flank is readable.',
    MapTestType.coastalLanding => 'Ports act like connected landing points.',
    MapTestType.forestScreen => 'Forest cover creates a visible side screen.',
    MapTestType.supplySpine => 'Depots make the safe line obvious.',
    MapTestType.siegeRing => 'Ring roads show how to encircle a fort.',
    MapTestType.threeApproaches => 'Left, center, right routes are distinct.',
    MapTestType.commandPiece => 'Army is one readable general on a raised hex.',
    MapTestType.generalCohort => 'General fronts K/Q/R/B/N/P on the same hex.',
    MapTestType.marchColumn =>
      'General leads, pieces trail behind as a moving group.',
  };

  String get notProven => switch (this) {
    MapTestType.roadTempo => 'May be too fast.',
    MapTestType.twinCrossing => 'May become bridge camping.',
    MapTestType.crownHill => 'May overvalue center.',
    MapTestType.valleyGate => 'May still feel solved.',
    MapTestType.coastalLanding => 'May need naval rules later.',
    MapTestType.forestScreen => 'May hide too much.',
    MapTestType.supplySpine => 'May become escort busywork.',
    MapTestType.siegeRing => 'May need defender tools.',
    MapTestType.threeApproaches => 'May be too abstract.',
    MapTestType.commandPiece => 'May hide army composition.',
    MapTestType.generalCohort => 'May become crowded on phones.',
    MapTestType.marchColumn => 'May imply separate units too strongly.',
  };

  String get direction => switch (this) {
    MapTestType.roadTempo => 'Baseline movement feel.',
    MapTestType.twinCrossing => 'Crossing pressure.',
    MapTestType.crownHill => 'Center objective.',
    MapTestType.valleyGate => 'Choke vs flank.',
    MapTestType.coastalLanding => 'Operational landing.',
    MapTestType.forestScreen => 'Ambush readability.',
    MapTestType.supplySpine => 'Line protection.',
    MapTestType.siegeRing => 'Fort pressure.',
    MapTestType.threeApproaches => 'Route comparison.',
    MapTestType.commandPiece => 'General-only army read.',
    MapTestType.generalCohort => 'General plus full chess army.',
    MapTestType.marchColumn => 'Formation and movement read.',
  };

  IconData get icon => switch (this) {
    MapTestType.roadTempo => Icons.alt_route_rounded,
    MapTestType.twinCrossing => Icons.water_rounded,
    MapTestType.crownHill => Icons.landscape_rounded,
    MapTestType.valleyGate => Icons.terrain_rounded,
    MapTestType.coastalLanding => Icons.anchor_rounded,
    MapTestType.forestScreen => Icons.forest_rounded,
    MapTestType.supplySpine => Icons.grass_rounded,
    MapTestType.siegeRing => Icons.fort_rounded,
    MapTestType.threeApproaches => Icons.call_split_rounded,
    MapTestType.commandPiece => Icons.military_tech_rounded,
    MapTestType.generalCohort => Icons.groups_3_rounded,
    MapTestType.marchColumn => Icons.double_arrow_rounded,
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
    return _spec.reachableFrom(fromId);
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
        color: spec.background,
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
                      formationStyle: spec.formationStyle,
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
    required this.formationStyle,
    required this.onTap,
  });

  final _HexTile tile;
  final _TrialArmy? army;
  final _ArmySide activeSide;
  final _ArmySide? selectedSide;
  final bool reachable;
  final _FormationStyle formationStyle;
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(tile.kind), color: Colors.white, size: 15),
                      Text(
                        tile.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
                    formationStyle: formationStyle,
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
  const _ArmyMarker({
    super.key,
    required this.army,
    required this.active,
    required this.formationStyle,
  });

  final _TrialArmy army;
  final bool active;
  final _FormationStyle formationStyle;

  @override
  Widget build(BuildContext context) {
    return switch (formationStyle) {
      _FormationStyle.badge => _BadgeArmyMarker(army: army, active: active),
      _FormationStyle.generalOnly => _GeneralOnlyMarker(
        army: army,
        active: active,
      ),
      _FormationStyle.generalStack => _GeneralStackMarker(
        army: army,
        active: active,
      ),
      _FormationStyle.marchColumn => _MarchColumnMarker(
        army: army,
        active: active,
      ),
    };
  }
}

class _BadgeArmyMarker extends StatelessWidget {
  const _BadgeArmyMarker({required this.army, required this.active});

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

class _GeneralOnlyMarker extends StatelessWidget {
  const _GeneralOnlyMarker({required this.army, required this.active});

  final _TrialArmy army;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 3,
            child: _GeneralToken(army: army, active: active, size: 36),
          ),
          Positioned(
            bottom: 0,
            child: _NamePlate(text: army.shortName, color: army.color),
          ),
        ],
      ),
    );
  }
}

class _GeneralStackMarker extends StatelessWidget {
  const _GeneralStackMarker({required this.army, required this.active});

  final _TrialArmy army;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < army.pieces.length; index++)
            Positioned(
              left: 2 + (index % 3) * 15,
              bottom: index < 3 ? 3 : 17,
              child: _ChessPieceChip(
                key: ValueKey(
                  'stack-piece-${army.side.name}-${army.pieces[index]}',
                ),
                text: army.pieces[index],
                color: army.color,
              ),
            ),
          Positioned(
            top: -1,
            child: _GeneralToken(army: army, active: active, size: 32),
          ),
        ],
      ),
    );
  }
}

class _MarchColumnMarker extends StatelessWidget {
  const _MarchColumnMarker({required this.army, required this.active});

  final _TrialArmy army;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < 4; index++)
            Positioned(
              left: 5 + index * 7,
              bottom: 3 + index * 4,
              child: _ChessPieceChip(
                key: ValueKey(
                  'trail-piece-${army.side.name}-${army.pieces[index]}',
                ),
                text: army.pieces[index],
                color: army.color,
              ),
            ),
          Positioned(
            right: 2,
            top: 1,
            child: _GeneralToken(army: army, active: active, size: 34),
          ),
        ],
      ),
    );
  }
}

class _GeneralToken extends StatelessWidget {
  const _GeneralToken({
    required this.army,
    required this.active,
    required this.size,
  });

  final _TrialArmy army;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${army.generalName}, ${army.commandTrait}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF191B1E),
          border: Border.all(
            color: active ? const Color(0xFFFFD166) : const Color(0xFFE6B65E),
            width: active ? 2.4 : 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: army.color.withValues(alpha: active ? 0.62 : 0.34),
              blurRadius: active ? 13 : 6,
              spreadRadius: active ? 2 : 0,
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.military_tech_rounded, color: army.color, size: 20),
              Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  army.generalInitial,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChessPieceChip extends StatelessWidget {
  const _ChessPieceChip({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.4),
      ),
      child: SizedBox.square(
        dimension: 14,
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            height: 1,
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
    this.movement = _MovementRule.adjacent,
    this.formationStyle = _FormationStyle.badge,
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
  final _MovementRule movement;
  final _FormationStyle formationStyle;
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

  Set<String> reachableFrom(String id) {
    final direct = connectionsFor(
      id,
    ).where((next) => !tile(next).blocked).toSet();
    if (movement == _MovementRule.roadTempo && tile(id).kind == _HexKind.road) {
      for (final middle in List<String>.from(direct)) {
        if (tile(middle).kind != _HexKind.road) continue;
        for (final next in connectionsFor(middle)) {
          if (next != id &&
              tile(next).kind == _HexKind.road &&
              !tile(next).blocked) {
            direct.add(next);
          }
        }
      }
    }
    if (movement == _MovementRule.portHop && tile(id).kind == _HexKind.port) {
      direct.addAll(
        tiles
            .where((tile) => tile.kind == _HexKind.port && tile.id != id)
            .map((tile) => tile.id),
      );
    }
    return direct;
  }

  double tileSizeFor(double boardSize) {
    return (boardSize / 7.3).clamp(38, 68).toDouble();
  }
}

enum _MovementRule { adjacent, roadTempo, portHop }

enum _FormationStyle { badge, generalOnly, generalStack, marchColumn }

class _HexTile {
  const _HexTile({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.terrain,
    required this.color,
    this.kind = _HexKind.field,
    this.blocked = false,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final String terrain;
  final Color color;
  final _HexKind kind;
  final bool blocked;
}

enum _HexKind {
  field,
  road,
  bridge,
  river,
  ridge,
  forest,
  port,
  hill,
  fort,
  supply,
}

IconData _iconFor(_HexKind kind) {
  return switch (kind) {
    _HexKind.field => Icons.hexagon_rounded,
    _HexKind.road => Icons.alt_route_rounded,
    _HexKind.bridge => Icons.water_rounded,
    _HexKind.river => Icons.waves_rounded,
    _HexKind.ridge => Icons.terrain_rounded,
    _HexKind.forest => Icons.forest_rounded,
    _HexKind.port => Icons.anchor_rounded,
    _HexKind.hill => Icons.landscape_rounded,
    _HexKind.fort => Icons.fort_rounded,
    _HexKind.supply => Icons.grass_rounded,
  };
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
  List<String> get pieces => const ['K', 'Q', 'R', 'B', 'N', 'P'];

  String get generalInitial => generalName.substring(0, 1).toUpperCase();
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
    MapTestType.roadTempo => _roadTempoSpec(),
    MapTestType.twinCrossing => _twinCrossingSpec(),
    MapTestType.crownHill => _crownHillSpec(),
    MapTestType.valleyGate => _valleyGateSpec(),
    MapTestType.coastalLanding => _coastalLandingSpec(),
    MapTestType.forestScreen => _forestScreenSpec(),
    MapTestType.supplySpine => _supplySpineSpec(),
    MapTestType.siegeRing => _siegeRingSpec(),
    MapTestType.threeApproaches => _threeApproachesSpec(),
    MapTestType.commandPiece => _commandPieceSpec(),
    MapTestType.generalCohort => _generalCohortSpec(),
    MapTestType.marchColumn => _marchColumnSpec(),
  };
}

_HexTrialSpec _roadTempoSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    road: {'H41', 'H30', 'H21', 'H12', 'H02'},
    supply: {'H31', 'H13'},
  );
  return _HexTrialSpec(
    name: MapTestType.roadTempo.title,
    feel: 'Fast readable road, slower open flanks.',
    worksNow: MapTestType.roadTempo.worksNow,
    notProven: MapTestType.roadTempo.notProven,
    background: const Color(0xFF1E3C2B),
    routeColor: const Color(0x99FFD166),
    tiles: tiles,
    edges: edges,
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _twinCrossingSpec() {
  final blocked = {'H20', 'H22', 'H24'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    river: {'H10', 'H11', 'H12', 'H13', 'H30', 'H31', 'H32', 'H33'},
    bridge: {'H12', 'H32'},
    blocked: blocked,
  );
  return _HexTrialSpec(
    name: MapTestType.twinCrossing.title,
    feel: 'Two bridges, one fake center wall, clear crossing fights.',
    worksNow: MapTestType.twinCrossing.worksNow,
    notProven: MapTestType.twinCrossing.notProven,
    background: const Color(0xFF153345),
    routeColor: const Color(0x99CDE8FF),
    tiles: tiles,
    edges: _withoutBlocked(edges, blocked),
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _crownHillSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    hill: {'H21', 'H22', 'H23', 'H12', 'H32'},
    road: {'H41', 'H30', 'H21', 'H12', 'H02'},
  );
  return _HexTrialSpec(
    name: MapTestType.crownHill.title,
    feel: 'Crown hill is obvious, but roads and sides contest it.',
    worksNow: MapTestType.crownHill.worksNow,
    notProven: MapTestType.crownHill.notProven,
    background: const Color(0xFF2D2A20),
    routeColor: const Color(0x99E4C988),
    tiles: tiles,
    edges: edges,
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _valleyGateSpec() {
  final blocked = {'H11', 'H12', 'H13', 'H31', 'H32', 'H33'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    blocked: blocked,
    bridge: {'H22'},
    road: {'H41', 'H30', 'H22', 'H13', 'H02', 'H42', 'H43', 'H33'},
  );
  return _HexTrialSpec(
    name: MapTestType.valleyGate.title,
    feel: 'Short gate through the valley, long flank around it.',
    worksNow: MapTestType.valleyGate.worksNow,
    notProven: MapTestType.valleyGate.notProven,
    background: const Color(0xFF302B24),
    routeColor: const Color(0x99E4C988),
    tiles: tiles,
    edges: _withoutBlocked(edges, blocked),
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _coastalLandingSpec() {
  final blocked = {'H11', 'H22', 'H33'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    port: {'H41', 'H24', 'H02'},
    coast: {'H30', 'H31', 'H20', 'H21', 'H12', 'H13', 'H23', 'H33'},
    blocked: blocked,
  );
  return _HexTrialSpec(
    name: MapTestType.coastalLanding.title,
    feel: 'Ports connect as landings; coast shows stepping stones.',
    worksNow: MapTestType.coastalLanding.worksNow,
    notProven: MapTestType.coastalLanding.notProven,
    background: const Color(0xFF13364A),
    routeColor: const Color(0x99E9F4FF),
    tiles: tiles,
    edges: _withoutBlocked(edges, blocked),
    movement: _MovementRule.portHop,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _forestScreenSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    forest: {'H10', 'H20', 'H21', 'H30', 'H32', 'H33', 'H24', 'H13'},
    road: {'H41', 'H31', 'H22', 'H13', 'H02'},
    supply: {'H21', 'H33'},
  );
  return _HexTrialSpec(
    name: MapTestType.forestScreen.title,
    feel: 'Forest screen masks the flank without hiding the map.',
    worksNow: MapTestType.forestScreen.worksNow,
    notProven: MapTestType.forestScreen.notProven,
    background: const Color(0xFF173023),
    routeColor: const Color(0x778FD19E),
    tiles: tiles,
    edges: edges,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _supplySpineSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    road: {'H41', 'H30', 'H20', 'H21', 'H22', 'H23', 'H13', 'H02'},
    supply: {'H30', 'H21', 'H23'},
    forest: {'H11', 'H31', 'H33'},
  );
  return _HexTrialSpec(
    name: MapTestType.supplySpine.title,
    feel: 'Depots create a line worth protecting.',
    worksNow: MapTestType.supplySpine.worksNow,
    notProven: MapTestType.supplySpine.notProven,
    background: const Color(0xFF243420),
    routeColor: const Color(0x99D1F2C9),
    tiles: tiles,
    edges: edges,
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _siegeRingSpec() {
  final fort = {'H22'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    fort: fort,
    road: {'H21', 'H12', 'H23', 'H32', 'H31'},
    hill: {'H11', 'H13', 'H31', 'H33'},
  );
  return _HexTrialSpec(
    name: MapTestType.siegeRing.title,
    feel: 'Center fort blocks movement; ring roads invite encirclement.',
    worksNow: MapTestType.siegeRing.worksNow,
    notProven: MapTestType.siegeRing.notProven,
    background: const Color(0xFF302826),
    routeColor: const Color(0x99FFD166),
    tiles: tiles,
    edges: _withoutBlocked(edges, fort),
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _threeApproachesSpec() {
  final blocked = {'H22'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    blocked: blocked,
    road: {
      'H41',
      'H30',
      'H20',
      'H10',
      'H01',
      'H32',
      'H23',
      'H13',
      'H42',
      'H33',
      'H24',
    },
    bridge: {'H20', 'H23', 'H33'},
    hill: {'H12', 'H32'},
  );
  return _HexTrialSpec(
    name: MapTestType.threeApproaches.title,
    feel: 'Three obvious routes: left road, center risk, right flank.',
    worksNow: MapTestType.threeApproaches.worksNow,
    notProven: MapTestType.threeApproaches.notProven,
    background: const Color(0xFF26313A),
    routeColor: const Color(0x99CDE8FF),
    tiles: tiles,
    edges: _withoutBlocked(edges, blocked),
    movement: _MovementRule.roadTempo,
    armies: _armies(romeStart: 'H41', enemyStart: 'H02'),
  );
}

_HexTrialSpec _commandPieceSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    road: {'H41', 'H30', 'H21', 'H12', 'H02'},
    hill: {'H21', 'H22', 'H12'},
    forest: {'H10', 'H31', 'H33'},
    fort: {'H03'},
  );
  return _HexTrialSpec(
    name: MapTestType.commandPiece.title,
    feel: 'Raised hexes, clean command token, no crowded army blob.',
    worksNow: MapTestType.commandPiece.worksNow,
    notProven: MapTestType.commandPiece.notProven,
    background: const Color(0xFF142232),
    routeColor: const Color(0x99EAD7A0),
    tiles: tiles,
    edges: edges,
    movement: _MovementRule.roadTempo,
    formationStyle: _FormationStyle.generalOnly,
    armies: _armies(
      romeStart: 'H41',
      enemyStart: 'H02',
      romeGeneralName: 'Livia Varro',
      enemyGeneralName: 'Brennos',
    ),
  );
}

_HexTrialSpec _generalCohortSpec() {
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    road: {'H41', 'H31', 'H22', 'H13', 'H02'},
    supply: {'H31', 'H13'},
    hill: {'H22'},
    forest: {'H10', 'H20', 'H33'},
  );
  return _HexTrialSpec(
    name: MapTestType.generalCohort.title,
    feel: 'General in front, full chess army packed behind on one hex.',
    worksNow: MapTestType.generalCohort.worksNow,
    notProven: MapTestType.generalCohort.notProven,
    background: const Color(0xFF223421),
    routeColor: const Color(0xAAFFD166),
    tiles: tiles,
    edges: edges,
    formationStyle: _FormationStyle.generalStack,
    armies: _armies(
      romeStart: 'H41',
      enemyStart: 'H02',
      romeGeneralName: 'Livia Varro',
      enemyGeneralName: 'Mara of the Hill',
    ),
  );
}

_HexTrialSpec _marchColumnSpec() {
  final blocked = {'H22'};
  final (tiles, edges) = _hexGrid(
    rows: 5,
    cols: 5,
    blocked: blocked,
    road: {'H41', 'H30', 'H20', 'H11', 'H02', 'H31', 'H23', 'H13'},
    bridge: {'H20', 'H23'},
    forest: {'H10', 'H32', 'H33'},
    hill: {'H12'},
  );
  return _HexTrialSpec(
    name: MapTestType.marchColumn.title,
    feel: 'Pieces trail the commander so movement reads like a column.',
    worksNow: MapTestType.marchColumn.worksNow,
    notProven: MapTestType.marchColumn.notProven,
    background: const Color(0xFF272B2F),
    routeColor: const Color(0xAACDE8FF),
    tiles: tiles,
    edges: _withoutBlocked(edges, blocked),
    movement: _MovementRule.roadTempo,
    formationStyle: _FormationStyle.marchColumn,
    armies: _armies(
      romeStart: 'H41',
      enemyStart: 'H02',
      romeGeneralName: 'Aulus Varro',
      enemyGeneralName: 'Mara of the Hill',
    ),
  );
}

List<_HexEdge> _withoutBlocked(List<_HexEdge> edges, Set<String> blocked) {
  return edges
      .where((edge) => !blocked.contains(edge.a) && !blocked.contains(edge.b))
      .toList(growable: false);
}

List<_TrialArmy> _armies({
  required String romeStart,
  required String enemyStart,
  String romeGeneralName = 'Aulus Varro',
  String enemyGeneralName = 'Brennos',
}) {
  return [
    _TrialArmy(
      side: _ArmySide.rome,
      name: 'Roman Vanguard',
      shortName: 'ROM',
      generalName: romeGeneralName,
      commandTrait: 'Veteran',
      commandHint: 'Fast baseline commander.',
      startTileId: romeStart,
      color: const Color(0xFFB83A2B),
      icon: Icons.flag_rounded,
    ),
    _TrialArmy(
      side: _ArmySide.enemy,
      name: 'Hill Host',
      shortName: 'HST',
      generalName: enemyGeneralName,
      commandTrait: 'Drummer',
      commandHint: 'Simple enemy pressure.',
      startTileId: enemyStart,
      color: const Color(0xFF2E6F87),
      icon: Icons.shield_rounded,
    ),
  ];
}

(List<_HexTile>, List<_HexEdge>) _hexGrid({
  required int rows,
  required int cols,
  Set<String>? mask,
  Set<String> blocked = const {},
  Set<String> river = const {},
  Set<String> bridge = const {},
  Set<String> forest = const {},
  Set<String> coast = const {},
  Set<String> port = const {},
  Set<String> road = const {},
  Set<String> hill = const {},
  Set<String> fort = const {},
  Set<String> supply = const {},
  bool centerHill = false,
}) {
  final activeMask =
      mask ??
      (rows == 5 && cols == 5
          ? const {
              'H01',
              'H02',
              'H03',
              'H10',
              'H11',
              'H12',
              'H13',
              'H20',
              'H21',
              'H22',
              'H23',
              'H24',
              'H30',
              'H31',
              'H32',
              'H33',
              'H41',
              'H42',
              'H43',
            }
          : null);
  final tiles = <_HexTile>[];
  final edges = <_HexEdge>[];
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final id = 'H$row$col';
      if (activeMask != null && !activeMask.contains(id)) continue;
      final isBlocked = blocked.contains(id);
      final isFort = fort.contains(id);
      final isPort = port.contains(id);
      final isBridge = bridge.contains(id);
      final isSupply = supply.contains(id);
      final isRiver = river.contains(id);
      final isForest = forest.contains(id);
      final isCoast = coast.contains(id);
      final isRoad = road.contains(id);
      final isHill =
          hill.contains(id) ||
          (centerHill && row == rows ~/ 2 && col == cols ~/ 2);
      tiles.add(
        _HexTile(
          id: id,
          label: '${row + 1}.${col + 1}',
          x: 0.12 + col * (0.76 / (cols - 1)) + (row.isOdd ? 0.06 : 0),
          y: 0.14 + row * (0.72 / (rows - 1)),
          terrain: isFort
              ? 'Fort'
              : isBlocked
              ? 'Blocked ridge'
              : isBridge
              ? 'Bridge'
              : isPort
              ? 'Port'
              : isSupply
              ? 'Supply depot'
              : isRiver
              ? 'River crossing'
              : isCoast
              ? 'Coast hop'
              : isForest
              ? 'Forest'
              : isRoad
              ? 'Relay road'
              : isHill
              ? 'Command hill'
              : 'Open field',
          color: isFort
              ? const Color(0xFF6A576E)
              : isBlocked
              ? const Color(0xFF555C65)
              : isBridge
              ? const Color(0xFFB88A42)
              : isPort
              ? const Color(0xFF1F6F83)
              : isSupply
              ? const Color(0xFF7A8B35)
              : isRiver
              ? const Color(0xFF2E6F87)
              : isCoast
              ? const Color(0xFF287B9A)
              : isForest
              ? const Color(0xFF265F38)
              : isRoad
              ? const Color(0xFFB88A42)
              : isHill
              ? const Color(0xFF8A6A3E)
              : const Color(0xFF3D7A4F),
          kind: isFort
              ? _HexKind.fort
              : isBlocked
              ? _HexKind.ridge
              : isBridge
              ? _HexKind.bridge
              : isPort
              ? _HexKind.port
              : isSupply
              ? _HexKind.supply
              : isRiver
              ? _HexKind.river
              : isCoast
              ? _HexKind.port
              : isForest
              ? _HexKind.forest
              : isRoad
              ? _HexKind.road
              : isHill
              ? _HexKind.hill
              : _HexKind.field,
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
      if (activeMask != null && !activeMask.contains(id)) continue;
      final neighbors = row.isOdd ? oddNeighbors : evenNeighbors;
      for (final offset in neighbors) {
        final nextRow = row + offset[0];
        final nextCol = col + offset[1];
        if (nextRow < 0 || nextRow >= rows || nextCol < 0 || nextCol >= cols) {
          continue;
        }
        final nextId = 'H$nextRow$nextCol';
        if (activeMask != null && !activeMask.contains(nextId)) continue;
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
