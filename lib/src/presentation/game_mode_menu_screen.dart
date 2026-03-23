import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../application/save/save_repository.dart';
import 'alpha_game_screen.dart';
import 'game_mode.dart';

class GameModeMenuScreen extends StatelessWidget {
  const GameModeMenuScreen({super.key, required this.saveRepository});

  final SaveRepository saveRepository;

  Future<void> _loadCampaignFromSlots(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    List<SaveSlotSummary> slots;
    try {
      slots = await saveRepository.listSlots();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read local save slots.')),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (slots.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No local campaign saves found yet.')),
      );
      return;
    }

    final selected = await showDialog<SaveSlotSummary>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Load Campaign'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: slots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (itemContext, index) {
                final slot = slots[index];
                final mode = gameModeFromStorageKey(slot.gameModeKey);
                final phaseLabel = slot.phase.name.toUpperCase();
                final roundLine = slot.round == null
                    ? ''
                    : ' • Round ${slot.round}';
                return ListTile(
                  tileColor: Colors.white.withValues(alpha: 0.78),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    '${slot.isAutosave ? 'Autosave' : slot.slotId} • ${mode.label}',
                  ),
                  subtitle: Text(
                    '$phaseLabel$roundLine • ${slot.savedAtUtc.toLocal()}',
                  ),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => Navigator.of(dialogContext).pop(slot),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || selected == null) {
      return;
    }
    final mode = gameModeFromStorageKey(selected.gameModeKey);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlphaGameScreen(
          gameMode: mode,
          saveRepository: saveRepository,
          initialLoadSlotId: selected.slotId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessWarss'),
        actions: [
          Tooltip(
            message: 'Load a previously saved campaign',
            child: TextButton.icon(
              onPressed: () => _loadCampaignFromSlots(context),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Load Campaign'),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4E6C4), Color(0xFFE0C089), Color(0xFFC6945B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 760;
                    final useRow = constraints.maxWidth >= 920 && !compact;
                    final hero = Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EED7).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF8A6336).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Campaign',
                            style: theme.textTheme.headlineMedium,
                          ).animate().fadeIn(duration: 360.ms),
                          const SizedBox(height: 8),
                          Text(
                            'The first track is single-player conquest. Casus Belli is the local multiplayer proving ground. Both now lean harder into crossings, supply lines, raiding, and treasure brought back to strengthen the realm.',
                            style: theme.textTheme.bodyLarge,
                          ).animate().fadeIn(delay: 80.ms, duration: 360.ms),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              Chip(
                                avatar: Icon(
                                  Icons.account_balance_rounded,
                                  size: 18,
                                ),
                                label: Text('Single-Player First'),
                              ),
                              Chip(
                                avatar: Icon(Icons.groups_rounded, size: 18),
                                label: Text('Local Multiplayer'),
                              ),
                              Chip(
                                avatar: Icon(Icons.map_rounded, size: 18),
                                label: Text('Fast Map Testing'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    if (!useRow) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            hero,
                            const SizedBox(height: 14),
                            _GameModeCard(
                                  mode: GameMode.eterna,
                                  saveRepository: saveRepository,
                                )
                                .animate()
                                .fadeIn(delay: 180.ms, duration: 380.ms)
                                .slideY(begin: 0.06),
                            const SizedBox(height: 12),
                            _GameModeCard(
                                  mode: GameMode.casusBelli,
                                  saveRepository: saveRepository,
                                )
                                .animate()
                                .fadeIn(delay: 260.ms, duration: 380.ms)
                                .slideY(begin: 0.06),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        hero,
                        const SizedBox(height: 14),
                        Expanded(
                          child: useRow
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child:
                                          _GameModeCard(
                                                mode: GameMode.eterna,
                                                saveRepository: saveRepository,
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 180.ms,
                                                duration: 380.ms,
                                              )
                                              .slideX(begin: -0.06),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child:
                                          _GameModeCard(
                                                mode: GameMode.casusBelli,
                                                saveRepository: saveRepository,
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 260.ms,
                                                duration: 380.ms,
                                              )
                                              .slideX(begin: 0.06),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child:
                                          _GameModeCard(
                                                mode: GameMode.eterna,
                                                saveRepository: saveRepository,
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 180.ms,
                                                duration: 380.ms,
                                              )
                                              .slideY(begin: 0.06),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child:
                                          _GameModeCard(
                                                mode: GameMode.casusBelli,
                                                saveRepository: saveRepository,
                                              )
                                              .animate()
                                              .fadeIn(
                                                delay: 260.ms,
                                                duration: 380.ms,
                                              )
                                              .slideY(begin: 0.06),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  const _GameModeCard({required this.mode, required this.saveRepository});

  final GameMode mode;
  final SaveRepository saveRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSolo = mode == GameMode.eterna;
    final accent = isSolo ? const Color(0xFF8A2E22) : const Color(0xFF2F5B52);
    final panel = isSolo
        ? const [Color(0xFFF5E6D6), Color(0xFFE9C89A)]
        : const [Color(0xFFE4EEE8), Color(0xFFC7D9CE)];

    return Card(
      color: Colors.white.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: panel),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.label,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: accent,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          isSolo ? 'Single Player' : 'Local Multiplayer',
                        ),
                        avatar: Icon(
                          isSolo
                              ? Icons.account_balance_rounded
                              : Icons.groups_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSolo
                        ? 'Build a war machine, cross rivers, seize rich settlements, and return spoils to your heartland before your rivals can choke the campaign.'
                        : 'Settle grudges on the same machine with compact campaigns tuned for repeated redeploys, local rivalry, and quick map comparisons.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(mode.menuSummary),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Map ${mode.minMapSize}x${mode.minMapSize}-${mode.maxMapSize}x${mode.maxMapSize}',
                  ),
                ),
                Chip(
                  label: Text(
                    'Players ${mode.minPlayerCount}-${mode.maxPlayerCount}',
                  ),
                ),
                Chip(
                  label: Text(
                    mode.playerControlEditable
                        ? 'Hotseat-ready'
                        : 'Campaign AI',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isSolo
                  ? 'Best if you want Caesar-in-Gaul pressure: frontier expansion, supply discipline, and long-form conquest.'
                  : 'Best if you want to test theaters, openings, and line behavior quickly with another person in the room.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5E503E),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AlphaGameScreen(
                      gameMode: mode,
                      saveRepository: saveRepository,
                    ),
                  ),
                );
              },
              icon: Icon(
                isSolo
                    ? Icons.auto_stories_rounded
                    : Icons.sports_martial_arts_rounded,
              ),
              label: Text('Enter ${mode.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
