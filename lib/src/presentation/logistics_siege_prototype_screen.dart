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
    return Scaffold(
      backgroundColor: const Color(0xFFFAE8BC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F6F83),
        foregroundColor: Colors.white,
        title: const Text('Logistics & Siege Prototype'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 900 && constraints.maxHeight >= 640;
            final map = _LogisticsMapPanel(
              grid: _grid.values.toList(),
              playerTile: _playerTile,
              enemyTile: _enemyTile,
              baseQ: _baseQ,
              baseR: _baseR,
              onTapHex: _handleTap,
            );
            final command = _CommandPostPanel(
              playerHealth: _playerHealth,
              playerSupply: _playerSupply,
              enemyHealth: _enemyHealth,
              enemyFortified: _enemyTile?.hasFortification ?? false,
              enemyAlive: _enemyTile != null,
              log: _log,
              onPillage: _pillage,
              compact: !wide,
            );

            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: map),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: command),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Expanded(flex: 4, child: map),
                  const SizedBox(height: 10),
                  Expanded(flex: 5, child: command),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogisticsMapPanel extends StatelessWidget {
  const _LogisticsMapPanel({
    required this.grid,
    required this.playerTile,
    required this.enemyTile,
    required this.baseQ,
    required this.baseR,
    required this.onTapHex,
  });

  final List<HexTile> grid;
  final HexTile? playerTile;
  final HexTile? enemyTile;
  final int baseQ;
  final int baseR;
  final void Function(Offset pos, Size size) onTapHex;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onTapUp: (details) => onTapHex(details.localPosition, size),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  isComplex: true,
                  willChange: false,
                  painter: _InteractiveHexPainter(
                    grid: grid,
                    playerTile: playerTile,
                    enemyTile: enemyTile,
                    baseQ: baseQ,
                    baseR: baseR,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CommandPostPanel extends StatelessWidget {
  const _CommandPostPanel({
    required this.playerHealth,
    required this.playerSupply,
    required this.enemyHealth,
    required this.enemyFortified,
    required this.enemyAlive,
    required this.log,
    required this.onPillage,
    required this.compact,
  });

  final int playerHealth;
  final int playerSupply;
  final int enemyHealth;
  final bool enemyFortified;
  final bool enemyAlive;
  final String log;
  final VoidCallback onPillage;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Color(0xFF7B2D26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Command Post',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF3D1D13),
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              const Text(
                'Tap a neighboring hex. Blue is your base, red is your army, purple is the fortified enemy camp.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF4C3525),
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 8),
            ],
            _PrototypeStatusCard(compact: compact),
            const SizedBox(height: 6),
            _StatBar(
              'Health',
              playerHealth,
              const Color(0xFFD93030),
              compact: compact,
            ),
            const SizedBox(height: 4),
            _StatBar(
              'Supply',
              playerSupply,
              const Color(0xFFEB8A23),
              compact: compact,
            ),
            if (enemyAlive) ...[
              const SizedBox(height: 4),
              _StatBar(
                'Enemy',
                enemyHealth,
                const Color(0xFF7B2CBF),
                compact: compact,
              ),
              if (enemyFortified && !compact)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF5E5A67),
                        size: 17,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Fortified: defender takes half damage.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF4C3525),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: onPillage,
              icon: const Icon(Icons.local_fire_department),
              label: const Text('Pillage Local Tile'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB83A2B),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3D1D13), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8D6B48)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      log,
                      maxLines: compact ? 3 : 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3D1D13),
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RuleChip(text: 'Near base: -5 supply'),
                  _RuleChip(text: 'Far: -15 supply'),
                  _RuleChip(text: 'Brown: pillaged'),
                  _RuleChip(text: 'Trap: first assault hurts'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFD1F2C9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D1D13)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF3D1D13),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PrototypeStatusCard extends StatelessWidget {
  const _PrototypeStatusCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7D8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3D1D13), width: 2),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prototype Status',
            style: TextStyle(
              color: Color(0xFF3D1D13),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Works: one-hex movement, forage, pillage, starvation damage, fortified/trapped assault.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF4C3525),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Not proven: balance, AI, saves, campaign economy, and final battle integration.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF4C3525),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Direction: keep logistics simple, readable, interesting, and chess-styled.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF4C3525),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
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
  final bool compact;

  const _StatBar(this.label, this.value, this.color, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3D1D13),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: math.max(0, value) / 100.0,
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              minHeight: 7,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${math.max(0, value)}',
            style: const TextStyle(
              color: Color(0xFF3D1D13),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${math.max(0, value)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF3D1D13),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
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
    final hexRadius = math.max(27.0, math.min(size.width, size.height) / 11.2);

    final backgroundPaint = Paint()..color = const Color(0xFFBFE7B8);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final strokePaint = Paint()
      ..color = const Color(0x773D1D13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var tile in grid) {
      double x =
          hexRadius * math.sqrt(3) * (tile.q + tile.r / 2) + size.width / 2;
      double y = hexRadius * 3 / 2 * tile.r + size.height / 2;

      final inSupplyRange = _distance(tile.q, tile.r, baseQ, baseR) <= 2;
      Color tileColor = inSupplyRange
          ? const Color(0xFFA8DFA2)
          : const Color(0xFFD9C879);
      if (tile.isPillaged) {
        tileColor = const Color(0xFF9A6B3D);
      }

      final fillPaint = Paint()
        ..color = tileColor
        ..style = PaintingStyle.fill;

      _drawHex(canvas, Offset(x, y), hexRadius, strokePaint, fillPaint);

      if (tile.q == baseQ && tile.r == baseR) {
        canvas.drawCircle(
          Offset(x, y),
          hexRadius * 0.34,
          Paint()..color = const Color(0xFF1F6F83),
        ); // Base
        _drawCenteredText(canvas, 'BASE', Offset(x, y), 9, Colors.white);
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
        hexRadius * 0.36,
        Paint()..color = const Color(0xFF7B2CBF),
      );
      _drawCenteredText(canvas, 'CAMP', Offset(ex, ey), 8, Colors.white);

      if (enemyTile!.hasFortification) {
        canvas.drawCircle(
          Offset(ex, ey),
          hexRadius * 0.54,
          Paint()
            ..color = const Color(0xFF3D1D13)
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
        hexRadius * 0.36,
        Paint()..color = const Color(0xFFD93030),
      );
      _drawCenteredText(canvas, 'ARMY', Offset(px, py), 8, Colors.white);
    }
  }

  int _distance(int q1, int r1, int q2, int r2) {
    return ((q1 - q2).abs() + (q1 + r1 - q2 - r2).abs() + (r1 - r2).abs()) ~/ 2;
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

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _InteractiveHexPainter oldDelegate) => true;
}
