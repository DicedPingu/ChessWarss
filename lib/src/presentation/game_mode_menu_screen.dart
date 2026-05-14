import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../application/save/save_repository.dart';
import 'alpha_game_screen.dart';
import 'game_mode.dart';
import 'map_test_menu_screen.dart';

class GameModeMenuScreen extends StatelessWidget {
  const GameModeMenuScreen({super.key, required this.saveRepository});

  final SaveRepository saveRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C3E50), Color(0xFF000000), Color(0xFF4CA1AF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CHESSWARSS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        shadows: [
                          const Shadow(
                            color: Colors.black54,
                            blurRadius: 15,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                    const SizedBox(height: 12),

                    Text(
                      'Select Your Campaign',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                    const SizedBox(height: 60),

                    _PremiumModeButton(
                      title: 'ETERNA',
                      translation: 'Eternal',
                      subtitle: 'Single Player Conquest',
                      description:
                          'A solo path with quick strategic turns and decisive chess-board battles.',
                      icon: Icons.auto_stories_rounded,
                      gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      onTap: () => _launchMode(context, GameMode.eterna),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                    const SizedBox(height: 24),

                    _PremiumModeButton(
                      title: 'CASUS BELLI',
                      translation: 'Cause for War',
                      subtitle: 'Local Multiplayer',
                      description:
                          'A hotseat-first clash built around fast map pressure and repeatable fights.',
                      icon: Icons.sports_martial_arts_rounded,
                      gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                      onTap: () => _launchMode(context, GameMode.casusBelli),
                    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),

                    const SizedBox(height: 24),

                    _PremiumModeButton(
                      title: 'TABULAE PROBATIONIS',
                      translation: 'Test Tables',
                      subtitle: 'Experimental Grounds',
                      description:
                          'Test out highly realistic logistics, siege mechanics, and new board prototypes.',
                      icon: Icons.science_rounded,
                      gradient: const [Color(0xFFF2994A), Color(0xFFF2C94C)],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MapTestMenuScreen(),
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _launchMode(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AlphaGameScreen(gameMode: mode, saveRepository: saveRepository),
      ),
    );
  }
}

class _PremiumModeButton extends StatefulWidget {
  const _PremiumModeButton({
    required this.title,
    required this.translation,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String translation;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_PremiumModeButton> createState() => _PremiumModeButtonState();
}

class _PremiumModeButtonState extends State<_PremiumModeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isHovered ? 1.02 : 1.0;
    return Tooltip(
      message: '${widget.title} means "${widget.translation}".',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.diagonal3Values(scale, scale, 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.last.withValues(
                    alpha: _isHovered ? 0.6 : 0.3,
                  ),
                  blurRadius: _isHovered ? 25 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradient,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 48, color: Colors.white),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.translation,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.96),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(
                      alpha: _isHovered ? 1.0 : 0.5,
                    ),
                    size: 28,
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
