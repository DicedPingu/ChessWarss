import 'package:flutter/material.dart';

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
          TextButton.icon(
            onPressed: () => _loadCampaignFromSlots(context),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Load Campaign'),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5EEDC), Color(0xFFE6D3AE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose Campaign',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Two tracks are live right now. Casus Belli is the active balance focus.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          _GameModeCard(
                            mode: GameMode.eterna,
                            saveRepository: saveRepository,
                          ),
                          const SizedBox(height: 12),
                          _GameModeCard(
                            mode: GameMode.casusBelli,
                            saveRepository: saveRepository,
                          ),
                        ],
                      ),
                    ),
                  ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(mode.label, style: theme.textTheme.headlineSmall),
                ),
                if (mode == GameMode.casusBelli)
                  const Chip(
                    label: Text('Main Focus'),
                    avatar: Icon(Icons.priority_high_rounded, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(mode.menuSummary),
            const SizedBox(height: 10),
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
                    mode.playerControlEditable ? 'Local MP + SP' : 'Solo-first',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Enter ${mode.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
