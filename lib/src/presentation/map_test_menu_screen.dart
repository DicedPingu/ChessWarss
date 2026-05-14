import 'package:flutter/material.dart';

import 'logistics_siege_prototype_screen.dart';
import 'map_test_screen.dart';

class MapTestMenuScreen extends StatelessWidget {
  const MapTestMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tabulae Probationis')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Experimental test grounds. These are not promises; they show what works, what is not proven, and which direction each prototype supports.',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _MapTestOption(
            title: 'Logistics & Siege Simulation',
            subtitle:
                'Interactive pressure test for starvation, pillaging, and fortified camps.',
            worksNow:
                'Move one hex, forage, pillage, starve when supply hits zero, and assault a fortified/trapped enemy camp.',
            notProven:
                'Balance, AI behavior, campaign persistence, and final battle-engine integration are not proven here.',
            direction:
                'Use this to judge whether logistics, pillage, and defender advantage are simple, interesting, and readable.',
            icon: Icons.shield_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LogisticsSiegeTestScreen(),
                ),
              );
            },
          ),
          _MapTestOption(
            title: 'Standard Grid (Square)',
            subtitle: 'Classic chess board reference.',
            worksNow:
                'Shows an 8x8 coordinate grid that preserves the plain chess baseline.',
            notProven:
                'No logistics, fortifications, terrain pressure, or battle actions are simulated in this card.',
            direction:
                'Keep this as the control test: new mechanics should still feel chess-styled beside it.',
            icon: Icons.grid_3x3_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MapTestScreen(type: MapTestType.square),
                ),
              );
            },
          ),
          _MapTestOption(
            title: 'Hexagonal (6-Edged)',
            subtitle: 'Total War-style movement sketch.',
            worksNow:
                'Draws a readable hex field for testing six-edged movement space.',
            notProven:
                'No units, supply, combat, ownership, or AI decisions are active yet.',
            direction:
                'Use this to decide whether hex maps help campaign movement without losing chess clarity.',
            icon: Icons.hexagon_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const MapTestScreen(type: MapTestType.hexagonal),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapTestOption extends StatelessWidget {
  const _MapTestOption({
    required this.title,
    required this.subtitle,
    required this.worksNow,
    required this.notProven,
    required this.direction,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String worksNow;
  final String notProven;
  final String direction;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    _TestDirectionLine(
                      label: 'Works now',
                      text: worksNow,
                      color: const Color(0xFF2E6B4E),
                    ),
                    _TestDirectionLine(
                      label: 'Not proven',
                      text: notProven,
                      color: const Color(0xFF9A5D18),
                    ),
                    _TestDirectionLine(
                      label: 'Direction',
                      text: direction,
                      color: const Color(0xFF315F7D),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestDirectionLine extends StatelessWidget {
  const _TestDirectionLine({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $text',
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
