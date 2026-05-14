import 'package:flutter/material.dart';

import 'map_test_screen.dart';

class MapTestMenuScreen extends StatefulWidget {
  const MapTestMenuScreen({super.key});

  @override
  State<MapTestMenuScreen> createState() => _MapTestMenuScreenState();
}

class _MapTestMenuScreenState extends State<MapTestMenuScreen> {
  int _selectedIndex = 0;

  late final List<_TestEntry> _entries = [
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
        backgroundColor: const Color(0xFF3D1D13),
        foregroundColor: Colors.white,
        title: const Text('War Table Trials'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final columns = isWide ? 5 : 3;
            return Padding(
              padding: EdgeInsets.all(isWide ? 20 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WarTableHeader(),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: isWide ? 6 : 6,
                    child: _FeaturedTrialPanel(entry: selected),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: isWide ? 3 : 5,
                    child: _FixedTestGrid(
                      entries: _entries,
                      selectedIndex: _selectedIndex,
                      columns: columns,
                      onSelected: (index) {
                        setState(() => _selectedIndex = index);
                      },
                    ),
                  ),
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

class _WarTableHeader extends StatelessWidget {
  const _WarTableHeader();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF3D1D13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7C25E), width: 2),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.flare_rounded, color: Color(0xFFE7C25E), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'CHESSWARSS  |  WAR TABLE TRIALS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Select -> TEST',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedTrialPanel extends StatelessWidget {
  const _FeaturedTrialPanel({required this.entry});

  final _TestEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = _iconColorFor(entry.title);
    final soft = _softColorFor(entry.title);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3D1D13), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x443D1D13),
            blurRadius: 0,
            offset: Offset(5, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TrialPanelPainter(color: accent)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF3D1D13),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(entry.icon, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TEST',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF7B2D26),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3D1D13),
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TrialCallout(label: 'FEEL', text: entry.subtitle),
                _TrialCallout(label: 'OK', text: entry.worksNow),
                _TrialCallout(label: 'CUT?', text: entry.notProven),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.direction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4C3525),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      key: const ValueKey('war-table-open-test'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF3D1D13),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: entry.open,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'TEST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialCallout extends StatelessWidget {
  const _TrialCallout({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x668D6B48)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B2D26),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3D1D13),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
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

class _TrialPanelPainter extends CustomPainter {
  const _TrialPanelPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.22), 74, paint);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.92),
      108,
      paint,
    );

    final routePaint = Paint()
      ..color = const Color(0x663D1D13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.60,
        size.width * 0.56,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.88,
        size.width * 0.94,
        size.height * 0.58,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _TrialPanelPainter oldDelegate) {
    return oldDelegate.color != color;
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
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      padding: const EdgeInsets.all(5),
                      child: Icon(entry.icon, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.cardTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3D1D13),
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      height: 1,
                    ),
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

Color _iconColorFor(String title) {
  return switch (title) {
    'Road Tempo' => const Color(0xFFB88A42),
    'Twin Crossing' => const Color(0xFF287B9A),
    'Crown Hill' => const Color(0xFF8A6A3E),
    'Valley Gate' => const Color(0xFF725E45),
    'Coastal Landing' => const Color(0xFF1F6F83),
    'Forest Screen' => const Color(0xFF265F38),
    'Supply Spine' => const Color(0xFF7A8B35),
    'Siege Ring' => const Color(0xFF6A576E),
    'Three Approaches' => const Color(0xFF315F7D),
    _ => const Color(0xFF7B2D26),
  };
}

Color _softColorFor(String title) {
  return switch (title) {
    'Road Tempo' => const Color(0xFFFFF0B7),
    'Twin Crossing' => const Color(0xFFCDE8FF),
    'Crown Hill' => const Color(0xFFFFE0A3),
    'Valley Gate' => const Color(0xFFE7D8C8),
    'Coastal Landing' => const Color(0xFFC8F2F5),
    'Forest Screen' => const Color(0xFFCBEAC8),
    'Supply Spine' => const Color(0xFFE2F4C8),
    'Siege Ring' => const Color(0xFFE7D8FF),
    'Three Approaches' => const Color(0xFFD9E8FF),
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
