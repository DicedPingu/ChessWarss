import 'package:flutter/material.dart';

import 'logistics_siege_prototype_screen.dart';
import 'map_test_screen.dart';

class MapTestMenuScreen extends StatefulWidget {
  const MapTestMenuScreen({super.key});

  @override
  State<MapTestMenuScreen> createState() => _MapTestMenuScreenState();
}

class _MapTestMenuScreenState extends State<MapTestMenuScreen> {
  int _selectedIndex = 0;

  late final List<_TestEntry> _entries = [
    _TestEntry(
      title: 'Logistics & Siege',
      cardTitle: 'Logistics',
      subtitle: 'Supply, pillage, fortified camp',
      worksNow: 'Move one hex, forage, pillage, starve, and assault a camp.',
      notProven: 'Balance, AI, persistence, and final battle integration.',
      direction: 'Judge whether logistics are readable and worth keeping.',
      icon: Icons.shield_rounded,
      open: () => _push(const LogisticsSiegeTestScreen()),
    ),
    for (final type in MapTestType.values)
      _TestEntry(
        title: type.title,
        cardTitle: type.cardTitle,
        subtitle: type.subtitle,
        worksNow: type.worksNow,
        notProven: type.notProven,
        direction: type.direction,
        icon: type.icon,
        open: () => _push(MapTestScreen(type: type)),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _entries[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFFAE8BC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B2D26),
        foregroundColor: Colors.white,
        title: const Text('Tabulae Probationis / Proving Tables'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final columns = isWide ? 3 : 2;
            return Padding(
              padding: EdgeInsets.all(isWide ? 20 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3D1D13),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Playable test grounds. Pick a card for details, then open it to feel the mechanic.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF3D1D13),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _FixedTestGrid(
                      entries: _entries,
                      selectedIndex: _selectedIndex,
                      columns: columns,
                      onSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SelectedTestPanel(entry: selected),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _FixedTestGrid extends StatelessWidget {
  const _FixedTestGrid({
    required this.entries,
    required this.selectedIndex,
    required this.columns,
    required this.onSelected,
  });

  final List<_TestEntry> entries;
  final int selectedIndex;
  final int columns;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += columns) {
      final end = (start + columns).clamp(0, entries.length);
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (var index = start; index < end; index++) ...[
                Expanded(
                  child: _TestCard(
                    entry: entries[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
                if (index != end - 1) const SizedBox(width: 10),
              ],
              for (var index = end; index < start + columns; index++) ...[
                const Expanded(child: SizedBox.shrink()),
                if (index != start + columns - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      );
      if (end != entries.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _TestEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: entry.subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? _softColorFor(entry.title)
                  : Color.lerp(_softColorFor(entry.title), Colors.white, 0.62),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF3D1D13)
                    : const Color(0xFF8D6B48),
                width: selected ? 3 : 2,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x333D1D13),
                        blurRadius: 0,
                        offset: Offset(3, 4),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _iconColorFor(entry.title),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3D1D13),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(entry.icon, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3D1D13),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            height: 1.02,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF644329),
                            fontSize: 11.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected
                        ? const Color(0xFF7B2D26)
                        : const Color(0xFF8D6B48),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTestPanel extends StatelessWidget {
  const _SelectedTestPanel({required this.entry});

  final _TestEntry entry;

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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: const TextStyle(
                color: Color(0xFF3D1D13),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            _StatusLine(label: 'What this is', text: entry.subtitle),
            _StatusLine(label: 'Works', text: entry.worksNow),
            _StatusLine(label: 'Not proven', text: entry.notProven),
            _StatusLine(label: 'Direction', text: entry.direction),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2D26),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3D1D13), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: entry.open,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Open Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
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

Color _iconColorFor(String title) {
  return switch (title) {
    'Logistics & Siege' => const Color(0xFF5E5A67),
    'Square Warboard' => const Color(0xFF8A6A3E),
    'Hex Campaign' => const Color(0xFF3D7A4F),
    'Province Web' => const Color(0xFF7B2D26),
    'Three Fronts' => const Color(0xFF315F7D),
    'Island Crossings' => const Color(0xFF2E6F87),
    _ => const Color(0xFF7B2D26),
  };
}

Color _softColorFor(String title) {
  return switch (title) {
    'Logistics & Siege' => const Color(0xFFE7D8FF),
    'Square Warboard' => const Color(0xFFFFE0A3),
    'Hex Campaign' => const Color(0xFFD1F2C9),
    'Province Web' => const Color(0xFFFFC4B8),
    'Three Fronts' => const Color(0xFFCDE8FF),
    'Island Crossings' => const Color(0xFFC8F2F5),
    _ => const Color(0xFFFFF0B7),
  };
}

class _TestEntry {
  const _TestEntry({
    required this.title,
    required this.cardTitle,
    required this.subtitle,
    required this.worksNow,
    required this.notProven,
    required this.direction,
    required this.icon,
    required this.open,
  });

  final String title;
  final String cardTitle;
  final String subtitle;
  final String worksNow;
  final String notProven;
  final String direction;
  final IconData icon;
  final VoidCallback open;
}
