import 'package:flutter/material.dart';

import '../application/save/save_repository.dart';
import 'alpha_game_screen.dart';
import 'game_mode.dart';
import 'map_test_menu_screen.dart';

class GameModeMenuScreen extends StatefulWidget {
  const GameModeMenuScreen({super.key, required this.saveRepository});

  final SaveRepository saveRepository;

  @override
  State<GameModeMenuScreen> createState() => _GameModeMenuScreenState();
}

class _GameModeMenuScreenState extends State<GameModeMenuScreen> {
  int _selectedIndex = 0;

  late final List<_ModeChoice> _choices = [
    _ModeChoice(
      latinTitle: 'ROMA AETERNA',
      englishTitle: 'Eternal Rome',
      shortLabel: 'Solo campaign',
      description:
          'Rome-first adventure pacing: one human faction against AI pressure, built for fast campaign turns and decisive battles.',
      tryFirst: 'Pick this when you want the normal solo campaign path.',
      icon: Icons.account_balance_rounded,
      colors: const [Color(0xFF7B2D26), Color(0xFFC9A227)],
      launch: () => _launchMode(GameMode.eterna),
    ),
    _ModeChoice(
      latinTitle: 'CASUS BELLI',
      englishTitle: 'Cause for War',
      shortLabel: 'Local war setup',
      description:
          'Hotseat-friendly war setup with editable faction slots, quick map pressure, and repeatable fights.',
      tryFirst: 'Pick this when you want to configure both sides before war.',
      icon: Icons.sports_martial_arts_rounded,
      colors: const [Color(0xFF285C4D), Color(0xFF9BB35D)],
      launch: () => _launchMode(GameMode.casusBelli),
    ),
    _ModeChoice(
      latinTitle: 'TABULAE PROBATIONIS',
      englishTitle: 'Proving Tables',
      shortLabel: 'Test mechanics',
      description:
          'Playable test grounds for map shapes, logistics, siege pressure, and menu ideas before any of it becomes final.',
      tryFirst: 'Pick this when you want to compare prototype maps and rules.',
      icon: Icons.science_rounded,
      colors: const [Color(0xFF315F7D), Color(0xFFB97532)],
      launch: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MapTestMenuScreen()),
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _choices[_selectedIndex];

    return Scaffold(
      body: CustomPaint(
        painter: const _CartoonMenuBackdrop(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              return Padding(
                padding: EdgeInsets.all(isWide ? 28 : 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CHESSWARSS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: const Color(0xFF3D1D13),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: const [
                              Shadow(
                                color: Color(0xFFFFF0B7),
                                blurRadius: 0,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose a mode. Tap once for details, then start.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF513223),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: isWide ? 24 : 14),
                        if (isWide)
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _ModeGrid(
                                    choices: _choices,
                                    selectedIndex: _selectedIndex,
                                    onSelected: _selectMode,
                                    columns: 1,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 5,
                                  child: _ModeDetailsPanel(
                                    choice: selected,
                                    onStart: selected.launch,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Expanded(
                            child: _ModeGrid(
                              choices: _choices,
                              selectedIndex: _selectedIndex,
                              onSelected: _selectMode,
                              columns: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ModeDetailsPanel(
                            choice: selected,
                            onStart: selected.launch,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectMode(int index) {
    setState(() => _selectedIndex = index);
  }

  void _launchMode(GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlphaGameScreen(
          gameMode: mode,
          saveRepository: widget.saveRepository,
        ),
      ),
    );
  }
}

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({
    required this.choices,
    required this.selectedIndex,
    required this.onSelected,
    required this.columns,
  });

  final List<_ModeChoice> choices;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: [
          for (var index = 0; index < choices.length; index++) ...[
            Expanded(
              child: _ModeTile(
                choice: choices[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
            if (index != choices.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var start = 0; start < choices.length; start += columns) {
      final end = (start + columns).clamp(0, choices.length);
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (var index = start; index < end; index++) ...[
                Expanded(
                  child: _ModeTile(
                    choice: choices[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
                if (index != end - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      );
      if (end != choices.length) rows.add(const SizedBox(height: 12));
    }

    return Column(children: rows);
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _ModeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: choice.englishTitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFFF0B7)
                  : const Color(0xFFFFFBEC),
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
                        color: Color(0x553D1D13),
                        blurRadius: 0,
                        offset: Offset(4, 5),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: choice.colors.first,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3D1D13),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(choice.icon, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            choice.latinTitle,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF3D1D13),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${choice.englishTitle} / ${choice.shortLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF644329),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? choice.colors.first
                        : const Color(0xFF8D6B48),
                    size: 20,
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

class _ModeDetailsPanel extends StatelessWidget {
  const _ModeDetailsPanel({
    required this.choice,
    required this.onStart,
    this.compact = false,
  });

  final _ModeChoice choice;
  final VoidCallback onStart;
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
            color: Color(0x443D1D13),
            blurRadius: 0,
            offset: Offset(5, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              choice.englishTitle,
              style: TextStyle(
                color: const Color(0xFF3D1D13),
                fontSize: compact ? 20 : 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              choice.latinTitle,
              style: const TextStyle(
                color: Color(0xFF8D3E2E),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: compact ? 8 : 16),
            _MenuInfoLine(label: 'What it is', text: choice.description),
            const SizedBox(height: 6),
            _MenuInfoLine(label: 'Try first', text: choice.tryFirst),
            if (!compact) ...[
              const SizedBox(height: 10),
              _MenuInfoLine(
                label: 'New player read',
                text:
                    '${choice.latinTitle} is the Latin button; ${choice.englishTitle} is the English name.',
              ),
            ],
            SizedBox(height: compact ? 12 : 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: choice.colors.first,
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3D1D13), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start ${choice.englishTitle}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChoice {
  const _ModeChoice({
    required this.latinTitle,
    required this.englishTitle,
    required this.shortLabel,
    required this.description,
    required this.tryFirst,
    required this.icon,
    required this.colors,
    required this.launch,
  });

  final String latinTitle;
  final String englishTitle;
  final String shortLabel;
  final String description;
  final String tryFirst;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback launch;
}

class _MenuInfoLine extends StatelessWidget {
  const _MenuInfoLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF4C3525),
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xFF8D3E2E),
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _CartoonMenuBackdrop extends CustomPainter {
  const _CartoonMenuBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = const Color(0xFF9ED8F2);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.16), 46, sun);

    final farHill = Paint()..color = const Color(0xFF6DBA75);
    final farPath = Path()
      ..moveTo(0, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.55,
        size.width * 0.52,
        size.height * 0.70,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.84,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(farPath, farHill);

    final nearHill = Paint()..color = const Color(0xFF3D8D5A);
    final nearPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.68,
        size.width * 0.56,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.92,
        size.width,
        size.height * 0.78,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearPath, nearHill);

    final road = Paint()..color = const Color(0xFFC99155);
    final roadPath = Path()
      ..moveTo(size.width * 0.44, size.height)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.77,
        size.width * 0.47,
        size.height * 0.58,
      )
      ..lineTo(size.width * 0.55, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.61,
        size.height * 0.78,
        size.width * 0.70,
        size.height,
      )
      ..close();
    canvas.drawPath(roadPath, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
