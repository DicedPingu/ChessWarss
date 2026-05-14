import 'package:flutter/material.dart';
import 'dart:math' as math;

class HexTile {
  final int q;
  final int r;
  bool isPillaged = false;
  int supplyValue = 20;
  bool hasFortification = false;
  bool hasTraps = false;

  HexTile(this.q, this.r);
}

class LogisticsSiegeTestScreen extends StatefulWidget {
  const LogisticsSiegeTestScreen({super.key});

  @override
  State<LogisticsSiegeTestScreen> createState() =>
      _LogisticsSiegeTestScreenState();
}

class _LogisticsSiegeTestScreenState extends State<LogisticsSiegeTestScreen> {
  final Map<String, HexTile> _grid = {};
  HexTile? _playerTile;
  HexTile? _enemyTile;

  int _playerSupply = 100;
  int _playerHealth = 100;
  int _enemyHealth = 100;

  final int _baseQ = 0;
  final int _baseR = 0;

  String _log = "Campaign started. Move towards the enemy camp.";

  @override
  void initState() {
    super.initState();
    _generateGrid(4);
    _playerTile = _getTile(0, 0);
    _enemyTile = _getTile(3, -1);

    _enemyTile?.hasFortification = true;
    _enemyTile?.hasTraps = true;
  }

  void _generateGrid(int radius) {
    for (int q = -radius; q <= radius; q++) {
      int r1 = math.max(-radius, -q - radius);
      int r2 = math.min(radius, -q + radius);
      for (int r = r1; r <= r2; r++) {
        _grid['$q,$r'] = HexTile(q, r);
      }
    }
  }

  HexTile? _getTile(int q, int r) => _grid['$q,$r'];

  int _distance(int q1, int r1, int q2, int r2) {
    return ((q1 - q2).abs() + (q1 + r1 - q2 - r2).abs() + (r1 - r2).abs()) ~/ 2;
  }

  void _logMsg(String msg) {
    setState(() {
      _log = msg;
    });
  }

  void _moveTo(HexTile target) {
    if (_playerTile == null || _playerHealth <= 0) return;

    int dist = _distance(_playerTile!.q, _playerTile!.r, target.q, target.r);
    if (dist > 1) {
      _logMsg("Cannot move there (too far).");
      return;
    }

    setState(() {
      if (target == _enemyTile) {
        _attackEnemy();
        return;
      }

      _playerTile = target;

      int distFromBase = _distance(target.q, target.r, _baseQ, _baseR);
      bool inSupplyRange = distFromBase <= 2;

      int baseCost = inSupplyRange ? 5 : 15;
      String turnLog = "Moved to (${target.q}, ${target.r}). ";
      if (!inSupplyRange) turnLog += "[Out of Range] ";

      if (target.isPillaged) {
        baseCost += 10;
        turnLog += "[Desolate] ";
      } else {
        int forage = math.min(10, target.supplyValue);
        target.supplyValue -= forage;
        _playerSupply += forage;
        if (forage > 0) turnLog += "Foraged +$forage. ";
      }

      _playerSupply -= baseCost;
      turnLog += "Cost -$baseCost supply. ";

      if (_playerSupply <= 0) {
        _playerSupply = 0;
        _playerHealth -= 15;
        turnLog += "[STARVING: -15 Health] ";
      }

      _logMsg(turnLog);
    });
  }

  void _pillage() {
    if (_playerTile == null || _playerTile!.isPillaged || _playerHealth <= 0) {
      return;
    }
    setState(() {
      int gain = _playerTile!.supplyValue + 20;
      _playerSupply += gain;
      _playerTile!.supplyValue = 0;
      _playerTile!.isPillaged = true;
      _logMsg(
        "Pillaged local area! Gained +$gain supply. Tile is now desolate.",
      );
    });
  }

  void _attackEnemy() {
    setState(() {
      int damageToEnemy = 30;
      int damageToPlayer = 10;
      String combatLog = "Attacked! ";

      if (_enemyTile!.hasFortification) {
        damageToEnemy ~/= 2; // 50% reduction
        combatLog += "[Enemy Fortified: Dmg Halved] ";
      }
      if (_enemyTile!.hasTraps) {
        damageToPlayer += 25;
        _enemyTile!.hasTraps = false;
        combatLog += "[Traps Triggered: -25 Health] ";
      }

      if (_playerSupply <= 0) {
        damageToEnemy ~/= 2;
        damageToPlayer += 10;
        combatLog += "[Starving: Poor Combat] ";
      }

      _enemyHealth -= damageToEnemy;
      _playerHealth -= damageToPlayer;

      if (_enemyHealth <= 0) {
        _enemyTile = null;
        combatLog += "Enemy Defeated!";
      } else if (_playerHealth <= 0) {
        combatLog += "Your army was wiped out.";
      }

      _logMsg(combatLog);
    });
  }

  void _handleTap(Offset pos, Size size) {
    double hexRadius = 40.0;
    double ptX = pos.dx - size.width / 2;
    double ptY = pos.dy - size.height / 2;

    double qFrac = (math.sqrt(3) / 3 * ptX - 1.0 / 3 * ptY) / hexRadius;
    double rFrac = (2.0 / 3 * ptY) / hexRadius;
    double sFrac = -qFrac - rFrac;

    int q = qFrac.round();
    int r = rFrac.round();
    int s = sFrac.round();

    double qDiff = (q - qFrac).abs();
    double rDiff = (r - rFrac).abs();
    double sDiff = (s - sFrac).abs();

    if (qDiff > rDiff && qDiff > sDiff) {
      q = -r - s;
    } else if (rDiff > sDiff) {
      r = -q - s;
    }

    HexTile? tile = _getTile(q, r);
    if (tile != null) {
      _moveTo(tile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Logistics & Siege Prototype')),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFFEFEBE4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    onTapUp: (details) =>
                        _handleTap(details.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _InteractiveHexPainter(
                        grid: _grid.values.toList(),
                        playerTile: _playerTile,
                        enemyTile: _enemyTile,
                        baseQ: _baseQ,
                        baseR: _baseR,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Command Post', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const _PrototypeStatusCard(),
                  const SizedBox(height: 20),
                  _StatBar('Player Health', _playerHealth, Colors.red),
                  const SizedBox(height: 10),
                  _StatBar('Player Supply', _playerSupply, Colors.orange),
                  const SizedBox(height: 30),

                  if (_enemyTile != null) ...[
                    _StatBar('Enemy Health', _enemyHealth, Colors.purple),
                    const SizedBox(height: 10),
                    if (_enemyTile!.hasFortification)
                      const Row(
                        children: [
                          Icon(Icons.shield, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(child: Text('Fortified Camp')),
                        ],
                      ),
                    const SizedBox(height: 30),
                  ],

                  FilledButton.icon(
                    onPressed: _pillage,
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text('Pillage Local Tile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Rules of War:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Supply Range: ≤ 2 hexes from base costs 5 supply. Beyond costs 15.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Scorched Earth: Pillaged (brown) land costs +10 supply and yields no forage.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Fortifications: Defenders halve incoming damage.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Traps: First assault takes heavy bonus damage.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _log,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeStatusCard extends StatelessWidget {
  const _PrototypeStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1C46A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prototype Status',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Works: one-hex movement, forage, pillage, starvation damage, fortified/trapped assault.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Not proven: balance, AI, saves, campaign economy, and final battle integration.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Direction: keep logistics simple, readable, interesting, and chess-styled.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBar(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${math.max(0, value)}'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: math.max(0, value) / 100.0,
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
          minHeight: 8,
        ),
      ],
    );
  }
}

class _InteractiveHexPainter extends CustomPainter {
  final List<HexTile> grid;
  final HexTile? playerTile;
  final HexTile? enemyTile;
  final int baseQ;
  final int baseR;

  _InteractiveHexPainter({
    required this.grid,
    required this.playerTile,
    required this.enemyTile,
    required this.baseQ,
    required this.baseR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const hexRadius = 40.0;

    final strokePaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var tile in grid) {
      double x =
          hexRadius * math.sqrt(3) * (tile.q + tile.r / 2) + size.width / 2;
      double y = hexRadius * 3 / 2 * tile.r + size.height / 2;

      Color tileColor = Colors.green.shade200;
      if (tile.isPillaged) {
        tileColor = Colors.brown.shade300; // Desolate
      }

      final fillPaint = Paint()
        ..color = tileColor
        ..style = PaintingStyle.fill;

      _drawHex(canvas, Offset(x, y), hexRadius, strokePaint, fillPaint);

      if (tile.q == baseQ && tile.r == baseR) {
        canvas.drawCircle(
          Offset(x, y),
          10,
          Paint()..color = Colors.blue.shade800,
        ); // Base
      }
    }

    // Draw Enemy
    if (enemyTile != null) {
      double ex =
          hexRadius * math.sqrt(3) * (enemyTile!.q + enemyTile!.r / 2) +
          size.width / 2;
      double ey = hexRadius * 3 / 2 * enemyTile!.r + size.height / 2;
      canvas.drawCircle(
        Offset(ex, ey),
        15,
        Paint()..color = Colors.purple.shade800,
      );

      if (enemyTile!.hasFortification) {
        canvas.drawCircle(
          Offset(ex, ey),
          22,
          Paint()
            ..color = Colors.purple.shade900
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    // Draw Player
    if (playerTile != null) {
      double px =
          hexRadius * math.sqrt(3) * (playerTile!.q + playerTile!.r / 2) +
          size.width / 2;
      double py = hexRadius * 3 / 2 * playerTile!.r + size.height / 2;
      canvas.drawCircle(
        Offset(px, py),
        15,
        Paint()..color = Colors.red.shade700,
      );
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
  bool shouldRepaint(covariant _InteractiveHexPainter oldDelegate) => true;
}
