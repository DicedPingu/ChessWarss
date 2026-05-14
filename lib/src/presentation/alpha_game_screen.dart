import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../application/save/local_json_save_repository.dart';
import '../application/save/save_models.dart';
import '../application/save/save_repository.dart';
import '../application/settings/settings_models.dart';
import '../domain/ai.dart';
import '../domain/army.dart';
import '../domain/battle_session.dart';
import '../domain/battle_state.dart';
import '../domain/board_position.dart';
import '../domain/piece.dart';
import '../domain/world.dart';
import '../domain/world_generator.dart';
import 'game_mode.dart';
import 'general_sandbox_screen.dart';
import 'player_colors.dart';
import 'widgets/battle_board_widget.dart';

part 'alpha_game_support_models.dart';

enum _GamePhase { setup, world, battle, gameOver }

class AlphaGameScreen extends StatefulWidget {
  const AlphaGameScreen({
    super.key,
    this.gameMode = GameMode.casusBelli,
    SaveRepository? saveRepository,
    this.initialLoadSlotId,
  }) : saveRepository = saveRepository ?? const LocalJsonSaveRepository();

  final GameMode gameMode;
  final SaveRepository saveRepository;
  final String? initialLoadSlotId;

  @override
  State<AlphaGameScreen> createState() => _AlphaGameScreenState();
}

class _AlphaGameScreenState extends State<AlphaGameScreen> {
  final WorldGenerator _worldGenerator = const WorldGenerator();
  final StrategicAi _strategicAi = const StrategicAi();
  final BattleAi _battleAi = const BattleAi();

  _GamePhase _phase = _GamePhase.setup;

  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  int _playerCount = 2;
  int _mapSize = 5;
  int _armiesPerPlayer = 3;
  bool _mapSizeManuallySet = false;
  MapPreset _mapPreset = MapPreset.greatField;
  AiDifficulty _aiDifficulty = AiDifficulty.normal;
  final List<PlayerType> _playerTypes = [
    PlayerType.human,
    PlayerType.ai,
    PlayerType.ai,
    PlayerType.ai,
  ];

  WorldState? _world;
  BattleSession? _battle;

  String _status = 'Ready. Set up your campaign and begin.';

  String? _selectedStackId;
  String? _selectedSettlementId;
  Set<BoardPosition> _worldLegalMoves = const <BoardPosition>{};
  bool _forcedMarchMode = false;

  String? _selectedBattlePieceId;
  Set<BoardPosition> _battleLegalMoves = const <BoardPosition>{};

  bool _aiBusy = false;
  BattleTurnOverlay? _battleTurnOverlay;
  Timer? _battleOverlayTimer;
  Map<int, _PlayerBattleLedger> _battleLedgerByPlayer =
      const <int, _PlayerBattleLedger>{};
  _MatchOverSummary? _matchOverSummary;
  bool _matchOverBannerVisible = false;
  bool _matchOverPopupShown = false;
  int _matchOverSequence = 0;
  double _animationSpeed = GameSettingsSnapshot.defaults.animationSpeed;
  int _aiDelayMs = GameSettingsSnapshot.defaults.aiDelayMs;
  bool _reduceEffectsOverride = defaultTargetPlatform == TargetPlatform.linux;
  bool _loadingSave = false;
  bool _campaignOnboardingSeen = false;
  bool get _reduceEffects => _reduceEffectsOverride;
  Map<int, int> _strategicActionsByPlayer = const <int, int>{};
  _WorldMoveMarker? _lastEnemyWorldMove;
  bool _backConfirmOpen = false;
  Map<String, int> _stackSupplyById = const <String, int>{};
  Map<String, int> _stackStarvationById = const <String, int>{};
  Map<String, int> _stackWaterById = const <String, int>{};
  Map<String, int> _stackThirstById = const <String, int>{};
  Map<int, _CapturePolicy> _capturePolicyByPlayer =
      const <int, _CapturePolicy>{};
  Map<BoardPosition, int> _foodTileOwnerByPosition = <BoardPosition, int>{};
  Map<BoardPosition, int> _pillagedTileUntilRound = <BoardPosition, int>{};
  bool _skipAiBattles = true;
  static const int _maxArmyUnitsPerStack = 18;
  static const int _battleTurnLimit = 140;
  static const double _aiMoveTimeScale = 2 / 3;

  double _riverAnimValue = 0.0;
  Timer? _riverTimer;

  Duration _scaledDelay(int baseMs) {
    final speed = _animationSpeed <= 0 ? 1.0 : _animationSpeed;
    final ms = (baseMs / speed).round().clamp(120, 4500);
    return Duration(milliseconds: ms);
  }

  Duration get _aiWorldThinkDelay =>
      _scaledDelay(((_aiDelayMs + 150) * _aiMoveTimeScale).round());
  Duration get _aiWorldActionDelay =>
      _scaledDelay((_aiDelayMs * _aiMoveTimeScale).round());
  Duration get _aiBattleThinkDelay =>
      _scaledDelay((_aiDelayMs * _aiMoveTimeScale).round());
  Duration get _aiBattleActionDelay =>
      _scaledDelay(((_aiDelayMs - 80) * _aiMoveTimeScale).round());

  static const List<_FieldManualSection> _fieldManualSections = [
    _FieldManualSection(
      icon: Icons.auto_awesome_rounded,
      title: 'First Minute',
      summary:
          'Select an army, move with purpose, then resolve battles on a chess board.',
      points: [
        'Tap one of your armies to see legal march tiles and the actions it can take.',
        'Tap a highlighted tile to march. Moving into an enemy army starts the engage-or-withdraw battle step.',
        'Tap settlements to inspect ownership, supply, unrest, garrison, levy timing, and defense value.',
        'End Turn passes tempo to the next player. Staying active matters because idle turns can cost food.',
      ],
    ),
    _FieldManualSection(
      icon: Icons.route_rounded,
      title: 'Logistics Orders',
      summary:
          'Food, water, CP, and supply lines decide how far armies can push.',
      points: [
        'CP is your action budget. Marching, securing fields, camp work, and settlement actions spend CP.',
        'Forced March lets the selected army move up to 2 tiles for 1 food, but adds fatigue and cannot start from fortified camp posture.',
        'Supply Outlook shows reserve food, settlement income, camp income, field income, upkeep, and projected shortage risk.',
        'Water and supply are separate. Rivers, crossings, settlements, and camps make thirst less dangerous.',
        'Secure claims an open field for steadier food. Pillage burns an open enemy or unsecured field for immediate army supply.',
      ],
    ),
    _FieldManualSection(
      icon: Icons.fort_rounded,
      title: 'Camps and Settlements',
      summary:
          'Camps project temporary military support; settlements feed, fund, defend, and reinforce.',
      points: [
        'Camp creates a temporary support point for the selected army. It costs CP and food, and cannot be made after forced marching that round.',
        'Posture cycles Supply, Fortified, and Raiding. Supply helps logistics, Fortified prepares defense and recovery, Raiding pressures enemy land.',
        'Outpost turns an older camp into longer-lasting support. Break removes your camp and returns the army to open march.',
        'Tax gives coin and raises unrest. Forage adds food and settlement stock, also raising unrest.',
        'Garrison strengthens defense and lowers unrest. Levy adds infantry if cooldown and stack size allow. Study improves command if culture and a general allow it.',
      ],
    ),
    _FieldManualSection(
      icon: Icons.military_tech_rounded,
      title: 'Battle Actions',
      summary:
          'Battles stay chess-styled, but morale and command matter as much as material.',
      points: [
        'Move pieces by selecting one of your units, then tapping a highlighted square. Captures lower enemy morale.',
        'Pawns move forward, can open with a 2-step move if clear, capture diagonally, and sidestep only when blocked ahead.',
        'Generals move one square in any direction. Keep them screened because losing commanders can decide the battle.',
        'Charge is a one-time aggressive stance for armies with enough mobile units. Defend is a one-time holding stance for armies with enough units.',
        'Advance pushes up to 3 front pawns into contact. High Command is a stronger one-time advance unlocked by capable generals.',
      ],
    ),
    _FieldManualSection(
      icon: Icons.flag_rounded,
      title: 'Victory and Policy',
      summary:
          'Win by breaking armies and choosing what conquest does afterward.',
      points: [
        'Morale states explain whether a line is steady, shaken, at retreat risk, or broken.',
        'A side can lose when all commanders fall, morale collapses, or the tactical result removes its army.',
        'Capture policy changes what happens when you take settlements: Spare is gentler, Destroy is harsher.',
        'Simple, optimized, interesting, and chess-styled is the rule: prefer readable choices over hidden simulation noise.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _riverTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _phase == _GamePhase.world) {
        setState(() {
          _riverAnimValue += 0.02;
        });
      }
    });
    _applyModeDefaults();
    _mapSize = _defaultMapSizeForPlayers(_playerCount);
    _armiesPerPlayer = _armiesPerPlayer
        .clamp(2, _maxArmiesForMapSize(_mapSize))
        .toInt();
    final slotId = widget.initialLoadSlotId;
    if (slotId != null && slotId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadFromSlot(slotId, showStatus: true));
      });
    }
  }

  int _defaultMapSizeForPlayers(int players) {
    final suggested = widget.gameMode.defaultMapSizeForPlayers(players);
    return suggested
        .clamp(widget.gameMode.minMapSize, widget.gameMode.maxMapSize)
        .toInt();
  }

  int _maxArmiesForMapSize(int mapSize) {
    return widget.gameMode.maxArmiesForMapSize(mapSize);
  }

  void _applyModeDefaults() {
    _playerCount = widget.gameMode.defaultPlayerCount;
    _armiesPerPlayer = widget.gameMode.defaultArmies;
    if (!widget.gameMode.playerControlEditable) {
      _playerTypes[0] = PlayerType.human;
      _playerTypes[1] = PlayerType.ai;
      _playerTypes[2] = PlayerType.ai;
      _playerTypes[3] = PlayerType.ai;
    }
  }

  int _effectiveSeed([int? forcedSeed]) {
    if (forcedSeed != null) {
      return forcedSeed & 0x7fffffff;
    }
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  }

  SavedGamePhase _toSavedPhase(_GamePhase phase) {
    switch (phase) {
      case _GamePhase.setup:
        return SavedGamePhase.setup;
      case _GamePhase.world:
        return SavedGamePhase.world;
      case _GamePhase.battle:
        return SavedGamePhase.battle;
      case _GamePhase.gameOver:
        return SavedGamePhase.gameOver;
    }
  }

  _GamePhase _fromSavedPhase(SavedGamePhase phase) {
    switch (phase) {
      case SavedGamePhase.setup:
        return _GamePhase.setup;
      case SavedGamePhase.world:
        return _GamePhase.world;
      case SavedGamePhase.battle:
        return _GamePhase.battle;
      case SavedGamePhase.gameOver:
        return _GamePhase.gameOver;
    }
  }

  GameSettingsSnapshot _settingsSnapshot() {
    return GameSettingsSnapshot(
      animationSpeed: _animationSpeed,
      aiDelayMs: _aiDelayMs,
      reducedEffects: _reduceEffectsOverride,
    );
  }

  Map<int, String> _capturePolicyStorageMap() {
    return <int, String>{
      for (final entry in _capturePolicyByPlayer.entries)
        entry.key: entry.value.name,
    };
  }

  Map<int, _CapturePolicy> _capturePolicyMapFromStorage(
    Map<int, String> source,
  ) {
    return <int, _CapturePolicy>{
      for (final entry in source.entries)
        entry.key: switch (entry.value) {
          'destroy' => _CapturePolicy.destroy,
          _ => _CapturePolicy.spare,
        },
    };
  }

  Map<String, int> _positionIntStorageMap(Map<BoardPosition, int> source) {
    return <String, int>{
      for (final entry in source.entries)
        '${entry.key.row},${entry.key.col}': entry.value,
    };
  }

  Map<BoardPosition, int> _storageMapToPositionInt(Map<String, int> source) {
    final result = <BoardPosition, int>{};
    for (final entry in source.entries) {
      final parts = entry.key.split(',');
      if (parts.length != 2) {
        continue;
      }
      final row = int.tryParse(parts[0]);
      final col = int.tryParse(parts[1]);
      if (row == null || col == null) {
        continue;
      }
      result[BoardPosition(row, col)] = entry.value;
    }
    return result;
  }

  GameSaveV1 _buildSaveSnapshot() {
    return GameSaveV1(
      schemaVersion: gameSaveSchemaVersion,
      savedAtUtc: DateTime.now().toUtc(),
      gameModeKey: widget.gameMode.storageKey,
      phase: _toSavedPhase(_phase),
      seed: _seed,
      playerCount: _playerCount,
      mapSize: _mapSize,
      armiesPerPlayer: _armiesPerPlayer,
      mapPreset: _mapPreset,
      aiDifficulty: _aiDifficulty,
      playerTypes: List<PlayerType>.from(_playerTypes),
      worldState: _world,
      battleSession: _battle,
      statusLine: _status,
      selectedStackId: _selectedStackId,
      forcedMarchMode: _forcedMarchMode,
      selectedBattlePieceId: _selectedBattlePieceId,
      campaignOnboardingSeen: _campaignOnboardingSeen,
      stackSupplyById: _stackSupplyById,
      stackStarvationById: _stackStarvationById,
      stackWaterById: _stackWaterById,
      stackThirstById: _stackThirstById,
      capturePolicyByPlayer: _capturePolicyStorageMap(),
      foodTileOwnerByPosition: _positionIntStorageMap(_foodTileOwnerByPosition),
      pillagedTileUntilRound: _positionIntStorageMap(_pillagedTileUntilRound),
      settings: _settingsSnapshot(),
    );
  }

  void _applyLoadedSave(GameSaveV1 save) {
    _battleOverlayTimer?.cancel();
    final phase = _fromSavedPhase(save.phase);
    final world = save.worldState;
    final battle = save.battleSession;
    final nextPhase = switch (phase) {
      _GamePhase.world when world == null => _GamePhase.setup,
      _GamePhase.battle when battle == null =>
        world == null ? _GamePhase.setup : _GamePhase.world,
      _ => phase,
    };

    for (var index = 0; index < _playerTypes.length; index++) {
      _playerTypes[index] = index < save.playerTypes.length
          ? save.playerTypes[index]
          : (index == 0 ? PlayerType.human : PlayerType.ai);
    }

    final settings = save.settings;
    final ledger = <int, _PlayerBattleLedger>{
      for (final player in world?.players ?? const <PlayerSlot>[])
        player.id: const _PlayerBattleLedger(),
    };
    final actionLedger = <int, int>{
      for (final player in world?.players ?? const <PlayerSlot>[]) player.id: 0,
    };
    final reconciledLogistics = world == null
        ? (
            supplyById: const <String, int>{},
            starvationById: const <String, int>{},
            waterById: const <String, int>{},
            thirstById: const <String, int>{},
          )
        : _reconcileStackLogistics(
            world,
            supplySource: save.stackSupplyById,
            starvationSource: save.stackStarvationById,
            waterSource: save.stackWaterById,
            thirstSource: save.stackThirstById,
          );
    final capturePolicies = world == null
        ? const <int, _CapturePolicy>{}
        : _reconcileCapturePolicies(
            world,
            source: _capturePolicyMapFromStorage(save.capturePolicyByPlayer),
          );
    final restoredFoodControl = world == null
        ? const <BoardPosition, int>{}
        : _sanitizeFoodTileControlMap(
            world,
            source: _storageMapToPositionInt(save.foodTileOwnerByPosition),
          );
    final restoredPillaged = world == null
        ? const <BoardPosition, int>{}
        : _sanitizePillagedTileMap(
            world,
            source: _storageMapToPositionInt(save.pillagedTileUntilRound),
          );

    setState(() {
      _phase = nextPhase;
      _seed = save.seed;
      _playerCount = save.playerCount.clamp(
        widget.gameMode.minPlayerCount,
        widget.gameMode.maxPlayerCount,
      );
      _mapSize = save.mapSize.clamp(
        widget.gameMode.minMapSize,
        widget.gameMode.maxMapSize,
      );
      _armiesPerPlayer = save.armiesPerPlayer
          .clamp(2, _maxArmiesForMapSize(_mapSize))
          .toInt();
      _mapPreset = save.mapPreset;
      _aiDifficulty = save.aiDifficulty;
      _world = world;
      _battle = battle;
      _selectedStackId = save.selectedStackId;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = save.forcedMarchMode;
      _selectedBattlePieceId = save.selectedBattlePieceId;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = null;
      _battleLedgerByPlayer = ledger;
      _strategicActionsByPlayer = actionLedger;
      _lastEnemyWorldMove = null;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _foodTileOwnerByPosition = restoredFoodControl;
      _pillagedTileUntilRound = restoredPillaged;
      _matchOverSummary = null;
      _matchOverBannerVisible = false;
      _matchOverPopupShown = false;
      _animationSpeed = settings.animationSpeed;
      _aiDelayMs = settings.aiDelayMs;
      _reduceEffectsOverride = settings.reducedEffects;
      _campaignOnboardingSeen = save.campaignOnboardingSeen;
      _aiBusy = false;
      _status = save.statusLine.isEmpty
          ? 'Campaign loaded from local save.'
          : save.statusLine;
    });

    _scheduleCampaignOnboardingIfNeeded();
    _triggerAiTurnIfNeeded();
  }

  void _scheduleCampaignOnboardingIfNeeded() {
    if (_campaignOnboardingSeen ||
        _phase != _GamePhase.world ||
        _world == null ||
        _loadingSave) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showCampaignOnboarding());
    });
  }

  Future<void> _showCampaignOnboarding({bool markSeen = true}) async {
    if (!mounted || _phase != _GamePhase.world || _world == null) {
      return;
    }
    if (markSeen && _campaignOnboardingSeen) {
      return;
    }
    if (markSeen) {
      setState(() {
        _campaignOnboardingSeen = true;
      });
      _queueAutosave();
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = math.min(
          MediaQuery.of(dialogContext).size.height * 0.72,
          520.0,
        );
        return AlertDialog(
          title: const Text('Campaign Quick Start'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use this as your first-turn checklist. The campaign is easiest to read if you think in three things: crossings, camps, and local logistics.',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1) Command and Food',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Spend command points each round to move, force march, and manage settlements and camps. Food sustains tempo, but water is the urgent short-term limit.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '2) Rivers and Water',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Rivers run between tiles. Bridges and fords are the safe crossings. Armies that camp on a river line or in a settlement keep water steady before battle.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '3) Settlements',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Tax for coin, forage for supply, garrison for defense stability, levy for infantry, study for command growth. Villages feed, towns fund, castles anchor.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '4) Camps and Outposts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Camps are temporary posture tools: Supply, Fortified, Raiding. Riverbank camps make the best pre-battle staging points and outposts hold crossings longer.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '5) Battles and Morale',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Protect generals and watch morale states. Collapse can end battles before full elimination.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                unawaited(_showFieldManualDialog());
              },
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Open Field Manual'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToSlot(String slotId, {bool showStatus = true}) async {
    final snapshot = _buildSaveSnapshot();
    try {
      await widget.saveRepository.saveSlot(slotId, snapshot);
      if (!mounted || !showStatus) {
        return;
      }
      setState(() {
        _status = slotId == SaveSlots.autosave
            ? 'Autosaved campaign state.'
            : 'Saved to ${slotId.replaceAll('_', ' ')}.';
      });
    } catch (_) {
      if (!mounted || !showStatus) {
        return;
      }
      setState(() {
        _status = 'Save failed. Check local storage permissions.';
      });
    }
  }

  Future<void> _loadFromSlot(String slotId, {bool showStatus = false}) async {
    if (_loadingSave) {
      return;
    }
    setState(() {
      _loadingSave = true;
      if (showStatus) {
        _status = 'Loading local save...';
      }
    });

    try {
      final loaded = await widget.saveRepository.loadSlot(slotId);
      if (!mounted) {
        return;
      }
      if (loaded == null) {
        setState(() {
          _status = 'No data found in ${slotId.replaceAll('_', ' ')}.';
        });
        return;
      }
      _applyLoadedSave(loaded);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Loaded ${slotId.replaceAll('_', ' ')} successfully.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Load failed. Save may be invalid or incompatible.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSave = false;
        });
      }
    }
  }

  void _queueAutosave() {
    if (_phase != _GamePhase.world &&
        _phase != _GamePhase.battle &&
        _phase != _GamePhase.gameOver) {
      return;
    }
    unawaited(_saveToSlot(SaveSlots.autosave, showStatus: false));
  }

  Future<void> _showSaveSlotPicker() async {
    if (!mounted) {
      return;
    }
    List<SaveSlotSummary> summaries;
    try {
      summaries = await widget.saveRepository.listSlots();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Could not read local save metadata.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    final summaryById = <String, SaveSlotSummary>{
      for (final summary in summaries) summary.slotId: summary,
    };
    final slotId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save Campaign'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final slot in SaveSlots.manual)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: Colors.white.withValues(alpha: 0.82),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(slot.replaceAll('_', ' ').toUpperCase()),
                      subtitle: Text(
                        summaryById[slot] == null
                            ? 'Empty'
                            : 'Last save: ${summaryById[slot]!.savedAtUtc.toLocal()}',
                      ),
                      trailing: const Icon(Icons.save_rounded),
                      onTap: () => Navigator.of(dialogContext).pop(slot),
                    ),
                  ),
              ],
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
    if (slotId == null) {
      return;
    }
    await _saveToSlot(slotId);
  }

  Future<void> _showLoadSlotPicker() async {
    if (!mounted) {
      return;
    }
    List<SaveSlotSummary> summaries;
    try {
      summaries = await widget.saveRepository.listSlots();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Could not read local save slots.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    final modeFiltered = summaries
        .where(
          (summary) =>
              gameModeFromStorageKey(summary.gameModeKey) == widget.gameMode,
        )
        .toList();
    if (modeFiltered.isEmpty) {
      setState(() {
        _status =
            'No local ${widget.gameMode.label} saves found. Use Save Campaign first.';
      });
      return;
    }

    final slotId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Load Campaign'),
          content: SizedBox(
            width: 540,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: modeFiltered.length,
              itemBuilder: (context, index) {
                final summary = modeFiltered[index];
                final modeLabel = gameModeFromStorageKey(
                  summary.gameModeKey,
                ).label;
                final roundLine = summary.round == null
                    ? ''
                    : ' • Round ${summary.round}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    tileColor: Colors.white.withValues(alpha: 0.82),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(
                      '${summary.isAutosave ? 'Autosave' : summary.slotId} • $modeLabel',
                    ),
                    subtitle: Text(
                      '${summary.phase.name.toUpperCase()}$roundLine • '
                      '${summary.savedAtUtc.toLocal()}',
                    ),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () =>
                        Navigator.of(dialogContext).pop(summary.slotId),
                  ),
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
    if (slotId == null) {
      return;
    }
    await _loadFromSlot(slotId, showStatus: true);
  }

  Future<void> _showSettingsDialog() async {
    if (!mounted) {
      return;
    }
    var animationSpeed = _animationSpeed;
    var aiDelayMs = _aiDelayMs;
    var reducedEffects = _reduceEffectsOverride;

    final updated = await showDialog<GameSettingsSnapshot>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Animation speed: ${animationSpeed.toStringAsFixed(2)}x',
                    ),
                    Slider(
                      value: animationSpeed,
                      min: 0.6,
                      max: 1.4,
                      divisions: 4,
                      label: '${animationSpeed.toStringAsFixed(2)}x',
                      onChanged: (value) {
                        setLocalState(() {
                          animationSpeed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: aiDelayMs,
                      decoration: const InputDecoration(labelText: 'AI Delay'),
                      items: const [
                        DropdownMenuItem(
                          value: 500,
                          child: Text('Fast (500ms)'),
                        ),
                        DropdownMenuItem(
                          value: 750,
                          child: Text('Normal (750ms)'),
                        ),
                        DropdownMenuItem(
                          value: 1000,
                          child: Text('Slow (1000ms)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setLocalState(() {
                          aiDelayMs = value;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      title: const Text('Reduce Effects'),
                      subtitle: const Text(
                        'Lowers motion intensity and shortens overlay persistence.',
                      ),
                      value: reducedEffects,
                      onChanged: (value) {
                        setLocalState(() {
                          reducedEffects = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      GameSettingsSnapshot(
                        animationSpeed: animationSpeed,
                        aiDelayMs: aiDelayMs,
                        reducedEffects: reducedEffects,
                      ),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == null) {
      return;
    }
    setState(() {
      _animationSpeed = updated.animationSpeed;
      _aiDelayMs = updated.aiDelayMs;
      _reduceEffectsOverride = updated.reducedEffects;
      _status = 'Settings updated.';
    });
    _queueAutosave();
  }

  Future<void> _showSessionMenu() async {
    if (!mounted) {
      return;
    }
    final canSave = _phase != _GamePhase.setup;
    final canRestart = _phase != _GamePhase.setup;
    final canShowOnboarding = _phase == _GamePhase.world;
    final summaryLine = _sessionSummaryLine();
    final warningLine = _sessionWarningLine();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = math.min(
          MediaQuery.of(dialogContext).size.height * 0.68,
          420.0,
        );
        return AlertDialog(
          title: const Text('Session'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHeight),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      summaryLine,
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (warningLine != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        warningLine,
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(color: const Color(0xFF8B3A23)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.save_rounded),
                    title: const Text('Save Campaign'),
                    enabled: canSave,
                    onTap: canSave
                        ? () => Navigator.of(dialogContext).pop('save')
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: const Text('Load Campaign'),
                    onTap: () => Navigator.of(dialogContext).pop('load'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded),
                    title: const Text('Settings'),
                    onTap: () => Navigator.of(dialogContext).pop('settings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report_rounded),
                    title: const Text('War Lab / Debug'),
                    onTap: () => Navigator.of(dialogContext).pop('war-lab'),
                  ),
                  if (canShowOnboarding)
                    ListTile(
                      leading: const Icon(Icons.school_rounded),
                      title: const Text('Show Onboarding'),
                      onTap: () =>
                          Navigator.of(dialogContext).pop('onboarding'),
                    ),
                  if (canRestart)
                    ListTile(
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Restart Campaign'),
                      onTap: () => Navigator.of(dialogContext).pop('restart'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: const Text('Main Menu'),
                    onTap: () => Navigator.of(dialogContext).pop('menu'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    switch (action) {
      case 'save':
        await _showSaveSlotPicker();
        break;
      case 'load':
        if (_phase != _GamePhase.setup) {
          final confirm = await _confirmSessionDestructiveAction(
            title: 'Load Saved Campaign?',
            message:
                'Loading a slot replaces the current campaign state in memory.',
            confirmLabel: 'Load',
          );
          if (!confirm) {
            break;
          }
        }
        await _showLoadSlotPicker();
        break;
      case 'settings':
        await _showSettingsDialog();
        break;
      case 'war-lab':
        await _showWarLabSheet();
        break;
      case 'onboarding':
        await _showCampaignOnboarding(markSeen: false);
        break;
      case 'restart':
        final confirm = await _confirmSessionDestructiveAction(
          title: 'Restart Campaign?',
          message:
              'Restarting discards the current run and begins again from round one.',
          confirmLabel: 'Restart',
        );
        if (confirm) {
          _startMatch(forcedSeed: _seed);
        }
        break;
      case 'menu':
        await _confirmReturnToMenuOnBack();
        break;
      default:
        break;
    }
  }

  void _cycleMapPreset(int delta) {
    final presets = MapPreset.values;
    final currentIndex = presets.indexOf(_mapPreset);
    final nextIndex = (currentIndex + delta) % presets.length;
    final resolvedIndex = nextIndex < 0
        ? nextIndex + presets.length
        : nextIndex;
    setState(() {
      _mapPreset = presets[resolvedIndex];
      _status = 'Map preset set to ${_presetLabel(_mapPreset)}.';
    });
  }

  void _grantActivePlayerResources({int food = 0, int treasury = 0}) {
    final world = _world;
    if (world == null) {
      return;
    }
    final foodByPlayer = <int, int>{...world.foodByPlayer};
    final treasuryByPlayer = <int, int>{...world.treasuryByPlayer};
    foodByPlayer[world.activePlayerId] =
        ((foodByPlayer[world.activePlayerId] ?? 0) + food).clamp(0, 99).toInt();
    treasuryByPlayer[world.activePlayerId] =
        ((treasuryByPlayer[world.activePlayerId] ?? 0) + treasury)
            .clamp(0, 999)
            .toInt();
    setState(() {
      _world = world.copyWith(
        foodByPlayer: foodByPlayer,
        treasuryByPlayer: treasuryByPlayer,
      );
      _status =
          'War lab: granted P${world.activePlayerId + 1} +$food food and +$treasury coin.';
    });
  }

  void _refillSelectedArmyLogistics() {
    final world = _world;
    final selectedStackId = _selectedStackId;
    if (world == null || selectedStackId == null) {
      return;
    }
    final stack = world.stackById(selectedStackId);
    if (stack == null) {
      return;
    }
    setState(() {
      _stackSupplyById = <String, int>{..._stackSupplyById, selectedStackId: 8};
      _stackWaterById = <String, int>{..._stackWaterById, selectedStackId: 6};
      _stackStarvationById = <String, int>{
        ..._stackStarvationById,
        selectedStackId: 0,
      };
      _stackThirstById = <String, int>{..._stackThirstById, selectedStackId: 0};
      _status = 'War lab: ${stack.id} refilled to full supply and water.';
    });
  }

  Future<void> _showWarLabSheet() async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final inCampaign = _phase != _GamePhase.setup;
            final selectedStack = _world == null || _selectedStackId == null
                ? null
                : _world!.stackById(_selectedStackId!);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'War Lab / Debug',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Quick map testing and cheat hooks. No scrolling, no hunting.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in MapPreset.values)
                          ChoiceChip(
                            label: Text(_presetLabel(preset)),
                            selected: _mapPreset == preset,
                            onSelected: (_) {
                              setState(() {
                                _mapPreset = preset;
                                _status =
                                    'Map preset set to ${_presetLabel(preset)}.';
                              });
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _presetSummary(_mapPreset),
                      style: const TextStyle(color: Color(0xFF5E503E)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _startMatch();
                          },
                          icon: const Icon(Icons.casino_rounded),
                          label: const Text('Reroll Seed'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            _cycleMapPreset(1);
                            setSheetState(() {});
                            if (inCampaign) {
                              Navigator.of(context).pop();
                              _startMatch();
                            }
                          },
                          icon: const Icon(Icons.map_rounded),
                          label: Text(
                            inCampaign ? 'Next Map + Restart' : 'Next Map',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GeneralSandboxScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.science_rounded),
                          label: const Text('Battle Sandbox'),
                        ),
                      ],
                    ),
                    if (inCampaign) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Live Cheats',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _grantActivePlayerResources(food: 4, treasury: 4);
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.attach_money_rounded),
                            label: const Text('+4 Food / +4 Coin'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: selectedStack == null
                                ? null
                                : () {
                                    _refillSelectedArmyLogistics();
                                    setSheetState(() {});
                                  },
                            icon: const Icon(Icons.local_shipping_rounded),
                            label: Text(
                              selectedStack == null
                                  ? 'Select Army To Refill'
                                  : 'Refill ${selectedStack.label}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _phaseDisplayLabel() {
    switch (_phase) {
      case _GamePhase.setup:
        return 'Setup';
      case _GamePhase.world:
        return 'Campaign Map';
      case _GamePhase.battle:
        return 'Battle';
      case _GamePhase.gameOver:
        return 'Game Over';
    }
  }

  String _sessionSummaryLine() {
    final world = _world;
    final battle = _battle;
    switch (_phase) {
      case _GamePhase.setup:
        return 'Phase: ${_phaseDisplayLabel()}';
      case _GamePhase.world:
        final round = world?.round ?? 0;
        final active = world == null
            ? 'Unknown'
            : 'Player ${world.activePlayerId + 1}';
        return 'Phase: ${_phaseDisplayLabel()} • Round $round • Active $active';
      case _GamePhase.battle:
        final turn = battle?.battleState.moveLog.length ?? 0;
        final active = battle == null
            ? 'Unknown'
            : 'Player ${battle.battleState.activePlayer + 1}';
        return 'Phase: ${_phaseDisplayLabel()} • Battle turn $turn • Active $active';
      case _GamePhase.gameOver:
        final winner = _matchOverSummary?.winnerPlayerId;
        final winnerText = winner == null
            ? 'Draw'
            : 'Winner Player ${winner + 1}';
        return 'Phase: ${_phaseDisplayLabel()} • $winnerText';
    }
  }

  String? _sessionWarningLine() {
    if (_phase == _GamePhase.setup) {
      return null;
    }
    return 'Tip: Save before loading, restarting, or returning to main menu.';
  }

  Future<bool> _confirmSessionDestructiveAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    if (!mounted) {
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _startMatch({int? forcedSeed}) {
    final seed = _effectiveSeed(forcedSeed);
    var startPlayerCount = _playerCount
        .clamp(widget.gameMode.minPlayerCount, widget.gameMode.maxPlayerCount)
        .toInt();
    final startMapSize = _mapSize
        .clamp(widget.gameMode.minMapSize, widget.gameMode.maxMapSize)
        .toInt();
    if (startMapSize == 3 && startPlayerCount > 2) {
      startPlayerCount = 2;
    }
    final startArmiesPerPlayer = _armiesPerPlayer
        .clamp(2, _maxArmiesForMapSize(startMapSize))
        .toInt();
    if (!widget.gameMode.playerControlEditable) {
      _playerTypes[0] = PlayerType.human;
      _playerTypes[1] = PlayerType.ai;
    }
    final playerTypes = _playerTypes.take(startPlayerCount).toList();

    final world = _worldGenerator.create(
      playerCount: startPlayerCount,
      playerTypes: playerTypes,
      preset: _mapPreset,
      seed: seed,
      boardSizeOverride: startMapSize,
      armiesPerPlayerOverride: startArmiesPerPlayer,
    );
    final ledger = <int, _PlayerBattleLedger>{
      for (final player in world.players)
        player.id: const _PlayerBattleLedger(),
    };
    final actionLedger = <int, int>{
      for (final player in world.players) player.id: 0,
    };
    final reconciledLogistics = _reconcileStackLogistics(
      world,
      supplySource: const {},
      starvationSource: const {},
      waterSource: const {},
      thirstSource: const {},
    );
    final capturePolicies = _reconcileCapturePolicies(world, source: const {});
    _battleOverlayTimer?.cancel();

    setState(() {
      _phase = _GamePhase.world;
      _seed = seed;
      _playerCount = startPlayerCount;
      _mapSize = startMapSize;
      _armiesPerPlayer = startArmiesPerPlayer;
      _world = world;
      _battle = null;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = false;
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = null;
      _battleLedgerByPlayer = ledger;
      _strategicActionsByPlayer = actionLedger;
      _lastEnemyWorldMove = null;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _foodTileOwnerByPosition = _initialFoodTileControl(world);
      _pillagedTileUntilRound = const <BoardPosition, int>{};
      _matchOverSummary = null;
      _matchOverBannerVisible = false;
      _matchOverPopupShown = false;
      _campaignOnboardingSeen = false;
      _aiBusy = false;
      _status =
          '${widget.gameMode.label} | Round ${world.round}: '
          '${world.players[world.activePlayerIndex].name} turn. '
          'AI ${_aiDifficulty.label}.';
    });
    _scheduleCampaignOnboardingIfNeeded();
    _queueAutosave();
    _triggerAiTurnIfNeeded();
  }

  @override
  void dispose() {
    _riverTimer?.cancel();
    _battleOverlayTimer?.cancel();
    super.dispose();
  }

  void _backToSetup() {
    _battleOverlayTimer?.cancel();
    _matchOverSequence++;
    setState(() {
      _phase = _GamePhase.setup;
      _world = null;
      _battle = null;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = false;
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = null;
      _battleLedgerByPlayer = const <int, _PlayerBattleLedger>{};
      _strategicActionsByPlayer = const <int, int>{};
      _lastEnemyWorldMove = null;
      _stackSupplyById = const <String, int>{};
      _stackStarvationById = const <String, int>{};
      _stackWaterById = const <String, int>{};
      _stackThirstById = const <String, int>{};
      _capturePolicyByPlayer = const <int, _CapturePolicy>{};
      _foodTileOwnerByPosition = const <BoardPosition, int>{};
      _pillagedTileUntilRound = const <BoardPosition, int>{};
      _matchOverSummary = null;
      _matchOverBannerVisible = false;
      _matchOverPopupShown = false;
      _campaignOnboardingSeen = false;
      _aiBusy = false;
      _status = 'Ready. Configure ${widget.gameMode.label} and deploy.';
    });
  }

  Future<void> _confirmReturnToMenuOnBack() async {
    if (_backConfirmOpen || !mounted) {
      return;
    }
    _backConfirmOpen = true;
    final shouldLeave =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Return To Main Menu?'),
              content: const Text(
                'Current battle/campaign progress will be lost for this session.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Main Menu'),
                ),
              ],
            );
          },
        ) ??
        false;
    _backConfirmOpen = false;
    if (!mounted || !shouldLeave) {
      return;
    }
    _backToSetup();
  }

  PlayerType _playerTypeById(int playerId) {
    final world = _world;
    if (world == null) {
      return PlayerType.human;
    }
    for (final player in world.players) {
      if (player.id == playerId) {
        return player.type;
      }
    }
    return PlayerType.human;
  }

  void _triggerAiTurnIfNeeded() {
    if (!mounted || _aiBusy) {
      return;
    }

    if (_phase == _GamePhase.world && _world != null) {
      final world = _world!;
      final activeId = world.activePlayerId;
      if (_commandPointsForPlayer(world, activeId) <= 0) {
        _advanceWorldTurn('Player ${activeId + 1} exhausted command points.');
        return;
      }
      if (_playerTypeById(activeId) == PlayerType.ai) {
        _aiBusy = true;
        unawaited(
          Future<void>.delayed(_aiWorldThinkDelay, _runStrategicAiTurn),
        );
      }
      return;
    }

    if (_phase == _GamePhase.battle && _battle != null) {
      final activeId = _battle!.battleState.activePlayer;
      if (_playerTypeById(activeId) == PlayerType.ai) {
        _aiBusy = true;
        unawaited(Future<void>.delayed(_aiBattleThinkDelay, _runBattleAiTurn));
      }
    }
  }

  Future<void> _runStrategicAiTurn() async {
    if (!mounted || _phase != _GamePhase.world || _world == null) {
      _aiBusy = false;
      return;
    }

    final world = _world!;
    final activeId = world.activePlayerId;
    if (_commandPointsForPlayer(world, activeId) <= 0) {
      _aiBusy = false;
      _advanceWorldTurn('Player ${activeId + 1} exhausted command points.');
      return;
    }
    final activeCamps = world.camps.where(
      (camp) => camp.ownerId == activeId && camp.activeAtRound(world.round),
    );
    String? outpostStackId;
    for (final camp in activeCamps) {
      if (camp.isOutpost || camp.createdRound >= world.round) {
        continue;
      }
      final guarding = world.stackAt(camp.position);
      if (guarding != null && guarding.ownerId == activeId) {
        outpostStackId = guarding.id;
        break;
      }
    }
    final shouldConsolidateOutpost =
        outpostStackId != null &&
        _commandPointsForPlayer(world, activeId) > 0 &&
        (_foodForPlayer(world, activeId) <= 2 || world.round >= 4);
    if (shouldConsolidateOutpost) {
      setState(() {
        _selectedStackId = outpostStackId;
        _worldLegalMoves = const <BoardPosition>{};
        _status = 'AI is consolidating a minor outpost...';
      });

      await Future<void>.delayed(_aiWorldActionDelay);

      if (!mounted || _phase != _GamePhase.world || _world == null) {
        _aiBusy = false;
        return;
      }
      _aiBusy = false;
      _consolidateCampOutpost(stackId: outpostStackId, fromAi: true);
      return;
    }

    final campStackId = _strategicAi.chooseCampStack(
      world,
      activeId,
      _seed,
      difficulty: _aiDifficulty,
    );
    final shouldEstablishCamp =
        campStackId != null &&
        (activeCamps.isEmpty || _foodForPlayer(world, activeId) <= 2);
    if (shouldEstablishCamp) {
      setState(() {
        _selectedStackId = campStackId;
        _worldLegalMoves = const <BoardPosition>{};
        _status = 'AI is preparing a camp posture...';
      });

      await Future<void>.delayed(_aiWorldActionDelay);

      if (!mounted || _phase != _GamePhase.world || _world == null) {
        _aiBusy = false;
        return;
      }
      _aiBusy = false;
      _establishCamp(stackId: campStackId, fromAi: true);
      return;
    }

    final move = _strategicAi.chooseMove(
      world,
      world.activePlayerId,
      _seed,
      difficulty: _aiDifficulty,
    );

    if (move == null) {
      final fallbackCampStackId = _strategicAi.chooseCampStack(
        world,
        activeId,
        _seed,
        difficulty: _aiDifficulty,
      );
      if (fallbackCampStackId != null) {
        final campStack = world.stackById(fallbackCampStackId);
        if (campStack != null) {
          setState(() {
            _selectedStackId = campStack.id;
            _worldLegalMoves = const <BoardPosition>{};
            _status = 'AI is preparing camp posture for ${campStack.id}...';
          });
          await Future<void>.delayed(_aiWorldActionDelay);
          if (!mounted || _phase != _GamePhase.world || _world == null) {
            _aiBusy = false;
            return;
          }
          _aiBusy = false;
          _establishCamp(stackId: campStack.id, fromAi: true);
          return;
        }
      }
      _aiBusy = false;
      _advanceWorldTurn(
        'Player ${world.activePlayerId + 1} had no legal moves.',
      );
      return;
    }

    if (!mounted || _phase != _GamePhase.world || _world == null) {
      _aiBusy = false;
      return;
    }

    final legalMoves = world.legalMovesForStack(move.stackId).toSet();
    setState(() {
      _selectedStackId = move.stackId;
      _worldLegalMoves = legalMoves;
      _status = 'AI is moving ${move.stackId}...';
    });

    await Future<void>.delayed(_aiWorldActionDelay);

    if (!mounted || _phase != _GamePhase.world || _world == null) {
      _aiBusy = false;
      return;
    }

    _aiBusy = false;
    await _executeWorldMove(move, fromAi: true);
  }

  Future<void> _runBattleAiTurn() async {
    if (!mounted || _phase != _GamePhase.battle || _battle == null) {
      _aiBusy = false;
      return;
    }

    final session = _battle!;
    if (session.battleState.canUseGeneralAdvanceSkill()) {
      setState(() {
        _status = 'AI used High Command.';
      });
      await Future<void>.delayed(_aiBattleActionDelay);
      if (!mounted || _phase != _GamePhase.battle || _battle == null) {
        _aiBusy = false;
        return;
      }
      _aiBusy = false;
      _useGeneralAdvanceSkill(fromAi: true);
      return;
    }

    final action = _battleAi.chooseMove(
      session.battleState,
      _seed,
      difficulty: _aiDifficulty,
    );

    if (action == null) {
      _aiBusy = false;
      _finishBattle(session.battleState.otherPlayer, 'No legal battle moves.');
      return;
    }

    if (!mounted || _phase != _GamePhase.battle || _battle == null) {
      _aiBusy = false;
      return;
    }

    final legalMoves = session.battleState
        .legalMovesForPiece(action.pieceId)
        .toSet();
    setState(() {
      _selectedBattlePieceId = action.pieceId;
      _battleLegalMoves = legalMoves;
      _status = 'AI is planning ${action.pieceId}...';
    });

    await Future<void>.delayed(_aiBattleActionDelay);

    if (!mounted || _phase != _GamePhase.battle || _battle == null) {
      _aiBusy = false;
      return;
    }

    _aiBusy = false;
    _executeBattleMove(action, fromAi: true);
  }

  void _focusWorldStack(ArmyStack stack) {
    final world = _world;
    if (world == null || _phase != _GamePhase.world) {
      return;
    }
    final maxSteps = _forcedMarchMode ? 2 : 1;
    setState(() {
      _selectedStackId = stack.id;
      _selectedSettlementId = world.settlementAt(stack.position)?.id;
      _worldLegalMoves = world
          .legalMovesForStack(stack.id, maxSteps: maxSteps)
          .toSet();
      final supply = _stackSupply(stack.id);
      final starvation = _stackStarvation(stack.id);
      _status =
          'Selected ${stack.id} (Player ${stack.ownerId + 1}). '
          'Army: ${_armyTileSummary(stack.army)}. '
          'Supply $supply (${_supplyStateLabel(supply, starvation)}).';
    });
  }

  List<ArmyStack> _adjacentMergeTargets(WorldState world, ArmyStack stack) {
    final targets = <ArmyStack>[];
    for (final other in world.stacks) {
      if (other.id == stack.id || other.ownerId != stack.ownerId) {
        continue;
      }
      if (_manhattanDistance(stack.position, other.position) != 1) {
        continue;
      }
      if (!world.canTraverseBetween(stack.position, other.position)) {
        continue;
      }
      targets.add(other);
    }
    targets.sort((left, right) {
      final rowOrder = left.position.row.compareTo(right.position.row);
      if (rowOrder != 0) {
        return rowOrder;
      }
      return left.position.col.compareTo(right.position.col);
    });
    return targets;
  }

  Future<ArmyStack?> _showMergeTargetSheet({
    required ArmyStack primary,
    required List<ArmyStack> targets,
  }) async {
    if (targets.length == 1) {
      return targets.first;
    }
    return showModalBottomSheet<ArmyStack>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Columns',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose which adjacent allied column should be folded into ${primary.id}.',
                ),
                const SizedBox(height: 10),
                for (final target in targets)
                  Builder(
                    builder: (tileContext) {
                      final combinedUnits =
                          primary.army.units.length + target.army.units.length;
                      final canMerge = combinedUnits <= _maxArmyUnitsPerStack;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Colors.white.withValues(alpha: 0.76),
                        title: Text(
                          '${target.id} • ${target.army.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Tile (${target.position.row},${target.position.col}) • '
                          '${target.army.units.length} units • '
                          '${canMerge ? 'Result $combinedUnits/$_maxArmyUnitsPerStack units' : 'Too large for one host'}',
                        ),
                        trailing: Icon(
                          canMerge
                              ? Icons.call_merge_rounded
                              : Icons.block_rounded,
                        ),
                        onTap: canMerge
                            ? () => Navigator.of(tileContext).pop(target)
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onWorldTileTap(BoardPosition position) {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }

    final world = _world!;
    final activePlayer = world.activePlayerId;
    if (_playerTypeById(activePlayer) == PlayerType.ai) {
      return;
    }

    final tappedStack = world.stackAt(position);
    final tappedSettlement = world.settlementAt(position);

    if (_selectedStackId != null && _worldLegalMoves.contains(position)) {
      _selectedSettlementId = tappedSettlement?.id;
      unawaited(
        _executeWorldMove(WorldMove(stackId: _selectedStackId!, to: position)),
      );
      return;
    }

    if (tappedStack != null && tappedStack.ownerId == activePlayer) {
      if (_selectedStackId == tappedStack.id) {
        setState(() {
          _selectedStackId = null;
          _selectedSettlementId = tappedSettlement?.id;
          _worldLegalMoves = const <BoardPosition>{};
          _status = tappedSettlement == null
              ? 'Selection cleared.'
              : 'Selection cleared. ${tappedSettlement.name} remains selected.';
        });
        return;
      }
      _focusWorldStack(tappedStack);
      return;
    }

    if (tappedSettlement != null) {
      setState(() {
        _selectedStackId = null;
        _selectedSettlementId = tappedSettlement.id;
        _worldLegalMoves = const <BoardPosition>{};
        _status =
            'Selected ${tappedSettlement.name} (${tappedSettlement.tier.name.toUpperCase()}) • '
            '${tappedSettlement.ownerId < 0 ? 'Neutral' : 'Player ${tappedSettlement.ownerId + 1}'} • '
            'Tax +${_settlementTaxIncome(tappedSettlement, tappedSettlement.unrest)} • '
            'Harvest +${_settlementHarvest(tappedSettlement)} • '
            'Supply ${tappedSettlement.supplyStock}';
      });
      return;
    }

    setState(() {
      _selectedStackId = null;
      _selectedSettlementId = null;
      _worldLegalMoves = const <BoardPosition>{};
    });
  }

  void _passWorldTurn() {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }

    final activeId = _world!.activePlayerId;
    if (_playerTypeById(activeId) == PlayerType.ai) {
      return;
    }

    setState(() {
      _forcedMarchMode = false;
      _selectedStackId = null;
      _selectedSettlementId = null;
      _worldLegalMoves = const <BoardPosition>{};
    });
    _advanceWorldTurn('Player ${activeId + 1} passed.');
  }

  int _commandPointsForPlayer(WorldState world, int playerId) {
    return world.commandPointsByPlayer[playerId] ?? world.commandPointMax;
  }

  int _foodForPlayer(WorldState world, int playerId) {
    return world.foodByPlayer[playerId] ?? 0;
  }

  int _initialSupplyForStack(WorldState world, ArmyStack stack) {
    final settlement = world.settlementAt(stack.position);
    if (settlement != null && settlement.ownerId == stack.ownerId) {
      return 4;
    }
    return 3;
  }

  int _initialWaterForStack(WorldState world, ArmyStack stack) {
    if (_hasReliableWaterSource(world, stack.position)) {
      return 4;
    }
    return 3;
  }

  ({
    Map<String, int> supplyById,
    Map<String, int> starvationById,
    Map<String, int> waterById,
    Map<String, int> thirstById,
  })
  _reconcileStackLogistics(
    WorldState world, {
    Map<String, int>? supplySource,
    Map<String, int>? starvationSource,
    Map<String, int>? waterSource,
    Map<String, int>? thirstSource,
  }) {
    final sourceSupply = supplySource ?? _stackSupplyById;
    final sourceStarvation = starvationSource ?? _stackStarvationById;
    final sourceWater = waterSource ?? _stackWaterById;
    final sourceThirst = thirstSource ?? _stackThirstById;
    final supply = <String, int>{};
    final starvation = <String, int>{};
    final water = <String, int>{};
    final thirst = <String, int>{};
    for (final stack in world.stacks) {
      supply[stack.id] =
          (sourceSupply[stack.id] ?? _initialSupplyForStack(world, stack))
              .clamp(0, 8)
              .toInt();
      starvation[stack.id] = (sourceStarvation[stack.id] ?? 0).clamp(0, 6);
      water[stack.id] =
          (sourceWater[stack.id] ?? _initialWaterForStack(world, stack))
              .clamp(0, 6)
              .toInt();
      thirst[stack.id] = (sourceThirst[stack.id] ?? 0).clamp(0, 6);
    }
    return (
      supplyById: supply,
      starvationById: starvation,
      waterById: water,
      thirstById: thirst,
    );
  }

  int _weightedStackMetric({
    required int firstValue,
    required int secondValue,
    required int firstUnits,
    required int secondUnits,
    required int max,
  }) {
    final totalUnits = firstUnits + secondUnits;
    if (totalUnits <= 0) {
      return 0;
    }
    final weighted =
        ((firstValue * firstUnits) + (secondValue * secondUnits)) / totalUnits;
    return weighted.round().clamp(0, max).toInt();
  }

  Map<int, _CapturePolicy> _reconcileCapturePolicies(
    WorldState world, {
    Map<int, _CapturePolicy>? source,
  }) {
    final current = source ?? _capturePolicyByPlayer;
    return <int, _CapturePolicy>{
      for (final player in world.players)
        player.id: current[player.id] ?? _CapturePolicy.spare,
    };
  }

  Map<BoardPosition, int> _sanitizeFoodTileControlMap(
    WorldState world, {
    required Map<BoardPosition, int> source,
  }) {
    final validOwners = world.players.map((player) => player.id).toSet();
    final sanitized = <BoardPosition, int>{};
    for (final entry in source.entries) {
      final position = entry.key;
      if (position.row < 0 ||
          position.col < 0 ||
          position.row >= world.size ||
          position.col >= world.size) {
        continue;
      }
      if (!validOwners.contains(entry.value)) {
        continue;
      }
      if (world.tileAt(position).terrain != TerrainType.passable) {
        continue;
      }
      if (world.settlementAt(position) != null) {
        continue;
      }
      sanitized[position] = entry.value;
    }
    return sanitized;
  }

  Map<BoardPosition, int> _sanitizePillagedTileMap(
    WorldState world, {
    required Map<BoardPosition, int> source,
  }) {
    final sanitized = <BoardPosition, int>{};
    for (final entry in source.entries) {
      final position = entry.key;
      if (position.row < 0 ||
          position.col < 0 ||
          position.row >= world.size ||
          position.col >= world.size) {
        continue;
      }
      if (world.tileAt(position).terrain != TerrainType.passable) {
        continue;
      }
      if (entry.value < world.round) {
        continue;
      }
      sanitized[position] = entry.value;
    }
    return sanitized;
  }

  Map<BoardPosition, int> _initialFoodTileControl(WorldState world) {
    final control = <BoardPosition, int>{};
    for (final stack in world.stacks) {
      final position = stack.position;
      if (world.tileAt(position).terrain != TerrainType.passable) {
        continue;
      }
      if (world.settlementAt(position) != null) {
        continue;
      }
      control[position] = stack.ownerId;
    }
    return _sanitizeFoodTileControlMap(world, source: control);
  }

  int _stackSupply(String stackId) {
    return _stackSupplyById[stackId] ?? 0;
  }

  int _stackStarvation(String stackId) {
    return _stackStarvationById[stackId] ?? 0;
  }

  int _stackWater(String stackId) {
    return _stackWaterById[stackId] ?? 0;
  }

  int _stackThirst(String stackId) {
    return _stackThirstById[stackId] ?? 0;
  }

  _CapturePolicy _capturePolicyForPlayer(int playerId) {
    return _capturePolicyByPlayer[playerId] ?? _CapturePolicy.spare;
  }

  _CapturePolicy _capturePolicyForMove({
    required WorldState world,
    required ArmyStack stack,
    required bool fromAi,
  }) {
    if (!fromAi) {
      return _capturePolicyForPlayer(stack.ownerId);
    }
    final playerStacks = world.stacksForPlayer(stack.ownerId);
    final pressured = playerStacks.any((item) => _stackSupply(item.id) <= 1);
    return pressured ? _CapturePolicy.destroy : _CapturePolicy.spare;
  }

  String _supplyStateLabel(int supply, int starvation) {
    if (starvation >= 3) {
      return 'Critical';
    }
    if (starvation >= 2 || supply <= 1) {
      return 'Hungry';
    }
    if (supply <= 3) {
      return 'Tight';
    }
    return 'Stable';
  }

  String _waterStateLabel(int water, int thirst) {
    if (thirst >= 3 || water <= 0) {
      return 'Parched';
    }
    if (thirst >= 2 || water <= 1) {
      return 'Dry';
    }
    if (thirst >= 1 || water <= 2) {
      return 'Watch';
    }
    return 'Secure';
  }

  bool _hasReliableWaterSource(WorldState world, BoardPosition position) {
    if (world.tileTouchesRiver(position)) {
      return true;
    }
    if (world.settlementAt(position) != null) {
      return true;
    }
    final camp = world.campAt(position);
    return camp != null && camp.activeAtRound(world.round);
  }

  RiverEdgeType? _bestRiverAccessAt(WorldState world, BoardPosition position) {
    RiverEdgeType? best;
    for (final edge in world.riverEdges) {
      if (!edge.touches(position)) {
        continue;
      }
      if (edge.type == RiverEdgeType.bridge) {
        return RiverEdgeType.bridge;
      }
      best ??= edge.type;
    }
    return best;
  }

  String _waterAccessLabel(WorldState world, BoardPosition position) {
    final riverAccess = _bestRiverAccessAt(world, position);
    if (riverAccess != null) {
      return switch (riverAccess) {
        RiverEdgeType.river => 'Riverbank water access',
        RiverEdgeType.ford => 'Ford crossing and river access',
        RiverEdgeType.bridge => 'Bridge crossing and river access',
      };
    }
    if (world.settlementAt(position) != null) {
      return 'Settlement wells and cisterns';
    }
    final camp = world.campAt(position);
    if (camp != null && camp.activeAtRound(world.round)) {
      return 'Camp stores and animal train';
    }
    return 'No reliable water source';
  }

  WorldState? _consumeStrategicCost({
    required WorldState world,
    required int playerId,
    int cpCost = 1,
    int foodCost = 0,
  }) {
    final cp = _commandPointsForPlayer(world, playerId);
    if (cp < cpCost) {
      setState(() {
        _status = 'Not enough command points.';
      });
      return null;
    }

    final food = _foodForPlayer(world, playerId);
    if (food < foodCost) {
      setState(() {
        _status = 'Not enough food reserves.';
      });
      return null;
    }

    final cpByPlayer = <int, int>{...world.commandPointsByPlayer};
    cpByPlayer[playerId] = cp - cpCost;
    final foodByPlayer = <int, int>{...world.foodByPlayer};
    if (foodCost > 0) {
      foodByPlayer[playerId] = (food - foodCost).clamp(0, 99);
    }
    return world.copyWith(
      commandPointsByPlayer: cpByPlayer,
      foodByPlayer: foodByPlayer,
    );
  }

  void _finalizeStrategicAction({
    required WorldState updatedWorld,
    required bool fromAi,
    required String statusLine,
    _WorldMoveMarker? worldMoveMarker,
    Map<String, int>? stackSupplyById,
    Map<String, int>? stackStarvationById,
    Map<String, int>? stackWaterById,
    Map<String, int>? stackThirstById,
    String? preserveStackId,
    String? preserveSettlementId,
    Map<BoardPosition, int>? foodTileOwnerByPosition,
    Map<BoardPosition, int>? pillagedTileUntilRound,
  }) {
    final activeId = updatedWorld.activePlayerId;
    final updatedActionLedger = <int, int>{..._strategicActionsByPlayer};
    updatedActionLedger[activeId] = (updatedActionLedger[activeId] ?? 0) + 1;
    final reconciledLogistics = _reconcileStackLogistics(
      updatedWorld,
      supplySource: stackSupplyById,
      starvationSource: stackStarvationById,
      waterSource: stackWaterById,
      thirstSource: stackThirstById,
    );
    final capturePolicies = _reconcileCapturePolicies(updatedWorld);
    final remainingCp = _commandPointsForPlayer(updatedWorld, activeId);
    final preferredStackId = preserveStackId ?? _selectedStackId;
    final preferredStack = preferredStackId == null
        ? null
        : updatedWorld.stackById(preferredStackId);
    final retainedStack =
        preferredStack != null && preferredStack.ownerId == activeId
        ? preferredStack
        : null;
    final canRetainStack = retainedStack != null;
    SettlementState? retainedSettlement;
    final preferredSettlementKey =
        preserveSettlementId ?? _selectedSettlementId;
    if (preferredSettlementKey != null) {
      for (final settlement in updatedWorld.settlements) {
        if (settlement.id == preferredSettlementKey) {
          retainedSettlement = settlement;
          break;
        }
      }
    }
    final settlementAtRetainedStack = canRetainStack
        ? updatedWorld.settlementAt(retainedStack.position)
        : null;
    final resolvedFoodTiles = _sanitizeFoodTileControlMap(
      updatedWorld,
      source: foodTileOwnerByPosition ?? _foodTileOwnerByPosition,
    );
    final resolvedPillagedTiles = _sanitizePillagedTileMap(
      updatedWorld,
      source: pillagedTileUntilRound ?? _pillagedTileUntilRound,
    );
    setState(() {
      _world = updatedWorld;
      _strategicActionsByPlayer = updatedActionLedger;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _foodTileOwnerByPosition = resolvedFoodTiles;
      _pillagedTileUntilRound = resolvedPillagedTiles;
      _selectedStackId = canRetainStack ? retainedStack.id : null;
      _selectedSettlementId =
          settlementAtRetainedStack?.id ?? retainedSettlement?.id;
      _worldLegalMoves = canRetainStack
          ? updatedWorld.legalMovesForStack(retainedStack.id).toSet()
          : const <BoardPosition>{};
      _forcedMarchMode = false;
      if (worldMoveMarker != null) {
        _lastEnemyWorldMove = worldMoveMarker;
      }
      _status = '$statusLine ($remainingCp CP left)';
    });
    _queueAutosave();

    if (remainingCp <= 0) {
      _advanceWorldTurn();
      return;
    }

    if (fromAi) {
      _triggerAiTurnIfNeeded();
    }
  }

  (WorldState, String?) _applyCasusTempoResolution({
    required WorldState world,
    required int playerId,
    required int actionCount,
  }) {
    if (!widget.gameMode.usesTempoRules) {
      return (world, null);
    }

    if (actionCount <= 0) {
      final currentFood = _foodForPlayer(world, playerId);
      if (currentFood <= 0) {
        return (world, null);
      }
      final foodByPlayer = <int, int>{...world.foodByPlayer};
      foodByPlayer[playerId] = (currentFood - 1).clamp(0, 99);
      final updatedWorld = world.copyWith(
        foodByPlayer: foodByPlayer,
        log: [
          ...world.log,
          'Player ${playerId + 1} idled: tempo penalty -1 food.',
        ],
      );
      return (
        updatedWorld,
        'Idle penalty: Player ${playerId + 1} lost 1 food.',
      );
    }

    if (actionCount >= 2) {
      final currentFood = _foodForPlayer(world, playerId);
      final foodByPlayer = <int, int>{...world.foodByPlayer};
      foodByPlayer[playerId] = (currentFood + 1).clamp(0, 99);
      final updatedWorld = world.copyWith(
        foodByPlayer: foodByPlayer,
        log: [
          ...world.log,
          'Player ${playerId + 1} stayed active ($actionCount actions): momentum bonus +1 food.',
        ],
      );
      return (
        updatedWorld,
        'Momentum bonus: Player ${playerId + 1} gained +1 food.',
      );
    }

    return (world, null);
  }

  SettlementState? _selectedSettlementForStack(
    WorldState world,
    ArmyStack stack,
  ) {
    return world.settlementAt(stack.position);
  }

  SettlementState? _selectedSettlementById(WorldState world) {
    final settlementId = _selectedSettlementId;
    if (settlementId == null) {
      return null;
    }
    for (final settlement in world.settlements) {
      if (settlement.id == settlementId) {
        return settlement;
      }
    }
    return null;
  }

  CampState? _selectedCampForStack(WorldState world, ArmyStack stack) {
    final camp = world.campAt(stack.position);
    if (camp == null) {
      return null;
    }
    if (!camp.activeAtRound(world.round)) {
      return null;
    }
    return camp;
  }

  bool _stackFortifiedByCamp(WorldState world, ArmyStack stack) {
    final camp = _selectedCampForStack(world, stack);
    if (camp == null || camp.ownerId != stack.ownerId) {
      return false;
    }
    return camp.posture == CampPosture.fortified;
  }

  CampPosture _nextCampPosture(CampPosture posture) {
    switch (posture) {
      case CampPosture.supply:
        return CampPosture.fortified;
      case CampPosture.fortified:
        return CampPosture.raiding;
      case CampPosture.raiding:
        return CampPosture.supply;
    }
  }

  void _secureSelectedSupplyTile() {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }
    final world = _world!;
    final stack = _selectedStack(world);
    if (stack == null || stack.ownerId != world.activePlayerId) {
      return;
    }

    final position = stack.position;
    final tile = world.tileAt(position);
    if (tile.terrain != TerrainType.passable ||
        world.settlementAt(position) != null) {
      setState(() {
        _status = 'This tile cannot be secured for field supply.';
      });
      return;
    }
    if ((_pillagedTileUntilRound[position] ?? 0) >= world.round) {
      setState(() {
        _status = 'This tile is still pillaged and cannot be secured yet.';
      });
      return;
    }
    if (_foodTileOwnerByPosition[position] == stack.ownerId) {
      setState(() {
        _status = 'Tile already secured for Player ${stack.ownerId + 1}.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: stack.ownerId,
      cpCost: 1,
    );
    if (withCost == null) {
      return;
    }

    final updatedFoodTiles = _sanitizeFoodTileControlMap(
      withCost,
      source: <BoardPosition, int>{
        ..._foodTileOwnerByPosition,
        position: stack.ownerId,
      },
    );
    final updatedPillagedTiles = _sanitizePillagedTileMap(
      withCost,
      source: <BoardPosition, int>{..._pillagedTileUntilRound}
        ..remove(position),
    );

    final updatedWorld = withCost.copyWith(
      log: [
        ...withCost.log,
        'P${stack.ownerId + 1} secured fields at (${position.row},${position.col}).',
      ],
    );

    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: false,
      statusLine:
          '${stack.id} secured local fields at (${position.row},${position.col}).',
      preserveStackId: stack.id,
      preserveSettlementId: _selectedSettlementId,
      foodTileOwnerByPosition: updatedFoodTiles,
      pillagedTileUntilRound: updatedPillagedTiles,
    );
  }

  void _pillageSelectedSupplyTile() {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }
    final world = _world!;
    final stack = _selectedStack(world);
    if (stack == null || stack.ownerId != world.activePlayerId) {
      return;
    }

    final position = stack.position;
    final tile = world.tileAt(position);
    if (tile.terrain != TerrainType.passable ||
        world.settlementAt(position) != null) {
      setState(() {
        _status = 'Only open field tiles can be pillaged directly.';
      });
      return;
    }
    if ((_pillagedTileUntilRound[position] ?? 0) >= world.round) {
      setState(() {
        _status = 'Tile already pillaged this season.';
      });
      return;
    }
    if (_foodTileOwnerByPosition[position] == stack.ownerId) {
      setState(() {
        _status = 'Cannot pillage your own secured field tile.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: stack.ownerId,
      cpCost: 1,
    );
    if (withCost == null) {
      return;
    }

    final updatedSupplyById = <String, int>{..._stackSupplyById};
    final updatedStarvationById = <String, int>{..._stackStarvationById};
    final currentSupply =
        updatedSupplyById[stack.id] ?? _initialSupplyForStack(withCost, stack);
    updatedSupplyById[stack.id] = (currentSupply + 2).clamp(0, 8).toInt();
    updatedStarvationById[stack.id] = 0;

    final updatedFoodTiles = _sanitizeFoodTileControlMap(
      withCost,
      source: <BoardPosition, int>{..._foodTileOwnerByPosition}
        ..remove(position),
    );
    final updatedPillagedTiles = _sanitizePillagedTileMap(
      withCost,
      source: <BoardPosition, int>{
        ..._pillagedTileUntilRound,
        position: world.round + 2,
      },
    );

    final updatedWorld = withCost.copyWith(
      log: [
        ...withCost.log,
        'P${stack.ownerId + 1} pillaged fields at (${position.row},${position.col}) for immediate army rations (+2 supply).',
      ],
    );

    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: false,
      statusLine:
          '${stack.id} pillaged (${position.row},${position.col}) for immediate supply.',
      stackSupplyById: updatedSupplyById,
      stackStarvationById: updatedStarvationById,
      preserveStackId: stack.id,
      preserveSettlementId: _selectedSettlementId,
      foodTileOwnerByPosition: updatedFoodTiles,
      pillagedTileUntilRound: updatedPillagedTiles,
    );
  }

  String _hostSuffixForUnits(int totalUnits) {
    return totalUnits >= 15 ? 'Grand Host' : 'Field Host';
  }

  String _mergedHostLabel(String baseLabel, int totalUnits) {
    final suffix = _hostSuffixForUnits(totalUnits);
    if (baseLabel.endsWith(suffix)) {
      return baseLabel;
    }
    if (baseLabel.endsWith('Grand Host') || baseLabel.endsWith('Field Host')) {
      return baseLabel;
    }
    return '$baseLabel $suffix';
  }

  Future<void> _mergeSelectedArmy() async {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }

    final world = _world!;
    final primary = _selectedStack(world);
    if (primary == null || primary.ownerId != world.activePlayerId) {
      return;
    }

    final targets = _adjacentMergeTargets(world, primary);
    if (targets.isEmpty) {
      setState(() {
        _status =
            'No adjacent friendly column can join ${primary.id} right now.';
      });
      return;
    }

    final chosen = await _showMergeTargetSheet(
      primary: primary,
      targets: targets,
    );
    if (!mounted || chosen == null) {
      return;
    }

    final projectedUnits = primary.army.units.length + chosen.army.units.length;
    if (projectedUnits > _maxArmyUnitsPerStack) {
      setState(() {
        _status =
            'Joining ${primary.id} with ${chosen.id} would exceed '
            '$_maxArmyUnitsPerStack units.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: primary.ownerId,
      cpCost: 1,
    );
    if (withCost == null) {
      return;
    }

    final refreshedPrimary = withCost.stackById(primary.id);
    final refreshedSecondary = withCost.stackById(chosen.id);
    if (refreshedPrimary == null || refreshedSecondary == null) {
      return;
    }

    final refreshedUnits =
        refreshedPrimary.army.units.length +
        refreshedSecondary.army.units.length;
    if (refreshedUnits > _maxArmyUnitsPerStack) {
      setState(() {
        _status =
            'The combined host would exceed $_maxArmyUnitsPerStack units.';
      });
      return;
    }

    final mergedArmy = ArmyDefinition(
      id: '${refreshedPrimary.id}_${refreshedSecondary.id}_host',
      label: _mergedHostLabel(refreshedPrimary.army.label, refreshedUnits),
      units: [...refreshedPrimary.army.units, ...refreshedSecondary.army.units],
    );
    final mergedStack = refreshedPrimary.copyWith(
      army: mergedArmy,
      label: _mergedHostLabel(refreshedPrimary.label, refreshedUnits),
      entrenchedUntilRound: null,
      forcedMarchRound: null,
      fatigue: math.max(refreshedPrimary.fatigue, refreshedSecondary.fatigue),
    );

    final updatedStacks = <ArmyStack>[
      for (final stack in withCost.stacks)
        if (stack.id == refreshedPrimary.id)
          mergedStack
        else if (stack.id != refreshedSecondary.id)
          stack,
    ];

    final updatedSupplyById = <String, int>{..._stackSupplyById}
      ..[refreshedPrimary.id] = _weightedStackMetric(
        firstValue: _stackSupply(refreshedPrimary.id),
        secondValue: _stackSupply(refreshedSecondary.id),
        firstUnits: refreshedPrimary.army.units.length,
        secondUnits: refreshedSecondary.army.units.length,
        max: 8,
      )
      ..remove(refreshedSecondary.id);
    final updatedStarvationById = <String, int>{..._stackStarvationById}
      ..[refreshedPrimary.id] = _weightedStackMetric(
        firstValue: _stackStarvation(refreshedPrimary.id),
        secondValue: _stackStarvation(refreshedSecondary.id),
        firstUnits: refreshedPrimary.army.units.length,
        secondUnits: refreshedSecondary.army.units.length,
        max: 6,
      )
      ..remove(refreshedSecondary.id);
    final updatedWaterById = <String, int>{..._stackWaterById}
      ..[refreshedPrimary.id] = _weightedStackMetric(
        firstValue: _stackWater(refreshedPrimary.id),
        secondValue: _stackWater(refreshedSecondary.id),
        firstUnits: refreshedPrimary.army.units.length,
        secondUnits: refreshedSecondary.army.units.length,
        max: 6,
      )
      ..remove(refreshedSecondary.id);
    final updatedThirstById = <String, int>{..._stackThirstById}
      ..[refreshedPrimary.id] = _weightedStackMetric(
        firstValue: _stackThirst(refreshedPrimary.id),
        secondValue: _stackThirst(refreshedSecondary.id),
        firstUnits: refreshedPrimary.army.units.length,
        secondUnits: refreshedSecondary.army.units.length,
        max: 6,
      )
      ..remove(refreshedSecondary.id);

    final updatedWorld = withCost.copyWith(
      stacks: updatedStacks,
      log: [
        ...withCost.log,
        'P${mergedStack.ownerId + 1} joined ${refreshedPrimary.id} with ${refreshedSecondary.id}, forming ${mergedStack.label}.',
      ],
    );

    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: false,
      statusLine:
          '${refreshedPrimary.id} joined columns with ${refreshedSecondary.id}. '
          '${mergedStack.army.label} now fields $refreshedUnits units.',
      preserveStackId: refreshedPrimary.id,
      preserveSettlementId:
          updatedWorld.settlementAt(mergedStack.position)?.id ??
          _selectedSettlementId,
      stackSupplyById: updatedSupplyById,
      stackStarvationById: updatedStarvationById,
      stackWaterById: updatedWaterById,
      stackThirstById: updatedThirstById,
    );
  }

  void _performSettlementAction(SettlementAction action) {
    if (_phase != _GamePhase.world || _world == null || _aiBusy) {
      return;
    }

    final world = _world!;
    final selected = _selectedStack(world);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      return;
    }
    final settlement = _selectedSettlementForStack(world, selected);
    if (settlement == null || settlement.ownerId != selected.ownerId) {
      return;
    }

    final settlements = List<SettlementState>.from(world.settlements);
    final settlementIndex = settlements.indexWhere(
      (s) => s.id == settlement.id,
    );
    if (settlementIndex < 0) {
      return;
    }
    var updated = settlement;
    var updatedSelectedArmy = selected.army;
    late final String actionLabel;
    var cpCost = 1;
    var foodCost = 0;

    if (action == SettlementAction.study) {
      cpCost = 2;
      foodCost = 1;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: selected.ownerId,
      cpCost: cpCost,
      foodCost: foodCost,
    );
    if (withCost == null) {
      return;
    }
    final treasury = <int, int>{...withCost.treasuryByPlayer};
    final food = <int, int>{...withCost.foodByPlayer};
    final log = List<String>.from(withCost.log);

    switch (action) {
      case SettlementAction.tax:
        final before = treasury[selected.ownerId] ?? 0;
        treasury[selected.ownerId] = before + settlement.taxYield;
        updated = settlement.copyWith(
          unrest: (settlement.unrest + 1).clamp(0, 8),
        );
        actionLabel =
            '${settlement.name} taxed for +${settlement.taxYield} coin (unrest +1).';
      case SettlementAction.forage:
        final currentFood = food[selected.ownerId] ?? 0;
        food[selected.ownerId] = (currentFood + 1).clamp(0, 99);
        updated = settlement.copyWith(
          supplyStock: (settlement.supplyStock + 1).clamp(0, 8),
          unrest: (settlement.unrest + 1).clamp(0, 8),
        );
        actionLabel =
            '${settlement.name} foraged supply (+1 stock, unrest +1).';
      case SettlementAction.garrison:
        if (settlement.garrisonedUnits >= settlement.garrisonCapacity) {
          setState(() {
            _status = '${settlement.name} garrison is already full.';
          });
          return;
        }
        updated = settlement.copyWith(
          garrisonedUnits: settlement.garrisonedUnits + 1,
          unrest: (settlement.unrest - 1).clamp(0, 8),
          trapArmed: settlement.trapType == SettlementTrapType.defensiveDitch
              ? true
              : settlement.trapArmed,
        );
        actionLabel =
            '${settlement.name} garrison increased (+1, unrest -1).'
            '${updated.trapArmed ? ' Defensive ditch prepared.' : ''}';
      case SettlementAction.study:
        if (settlement.ownerId != selected.ownerId) {
          setState(() {
            _status = 'General study requires an owned settlement.';
          });
          return;
        }
        if (settlement.cultureRating < 2) {
          setState(() {
            _status = '${settlement.name} lacks enough culture for study.';
          });
          return;
        }
        final studied = _studyGeneralInArmy(selected.army);
        if (studied == null) {
          setState(() {
            _status = '${selected.id} has no general ready for study.';
          });
          return;
        }
        updatedSelectedArmy = studied;
        updated = settlement.copyWith(
          unrest: (settlement.unrest + 1).clamp(0, 8),
        );
        actionLabel =
            '${selected.id} studied command in ${settlement.name} (culture ${settlement.cultureRating}).';
      case SettlementAction.levy:
        if (settlement.levyCooldown > 0) {
          setState(() {
            _status =
                '${settlement.name} cannot raise another levy for ${settlement.levyCooldown} round(s).';
          });
          return;
        }
        final levyTarget = _levyCountFromSettlement(settlement);
        final leviedArmy = _draftLevyIntoArmy(
          selected.army,
          levyCount: levyTarget,
        );
        if (leviedArmy == null) {
          setState(() {
            _status =
                '${selected.id} cannot absorb more levy units right now (stack cap $_maxArmyUnitsPerStack).';
          });
          return;
        }
        final raised = leviedArmy.units.length - selected.army.units.length;
        if (raised <= 0) {
          setState(() {
            _status = '${settlement.name} lacks available levy manpower.';
          });
          return;
        }
        updatedSelectedArmy = leviedArmy;
        updated = settlement.copyWith(
          unrest: (settlement.unrest + 2).clamp(0, 8),
          supplyStock: (settlement.supplyStock - 1).clamp(0, 8),
          levyCooldown: _levyCooldownForSettlement(settlement),
        );
        actionLabel =
            '${settlement.name} raised +$raised levy infantry for ${selected.id} (unrest +2).';
    }

    final stacks = List<ArmyStack>.from(world.stacks);
    final selectedIndex = stacks.indexWhere((stack) => stack.id == selected.id);
    if (selectedIndex >= 0) {
      stacks[selectedIndex] = stacks[selectedIndex].copyWith(
        army: updatedSelectedArmy,
      );
    }
    settlements[settlementIndex] = updated;
    log.add(
      'Round ${world.round}: ${world.players[world.activePlayerIndex].name} $actionLabel',
    );

    final updatedWorld = withCost.copyWith(
      stacks: stacks,
      settlements: settlements,
      treasuryByPlayer: treasury,
      foodByPlayer: food,
      log: log,
    );
    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: false,
      statusLine: actionLabel,
    );
  }

  void _toggleForcedMarchMode() {
    final world = _world;
    if (_phase != _GamePhase.world || world == null || _aiBusy) {
      return;
    }
    final selected = _selectedStack(world);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      return;
    }
    if (_stackFortifiedByCamp(world, selected)) {
      setState(() {
        _status = 'Fortified camp posture blocks forced march this turn.';
      });
      return;
    }
    if (_foodForPlayer(world, selected.ownerId) < 1) {
      setState(() {
        _status = 'Forced march requires at least 1 food.';
      });
      return;
    }
    if (_commandPointsForPlayer(world, selected.ownerId) < 1) {
      setState(() {
        _status = 'No command points left for forced march.';
      });
      return;
    }

    final enabled = !_forcedMarchMode;
    final legal = world.legalMovesForStack(
      selected.id,
      maxSteps: enabled ? 2 : 1,
    );
    setState(() {
      _forcedMarchMode = enabled;
      _worldLegalMoves = legal.toSet();
      _status = enabled
          ? '${selected.id} preparing forced march (2-tile move, 1 food).'
          : '${selected.id} returned to normal march posture.';
    });
  }

  void _establishCamp({String? stackId, bool fromAi = false}) {
    final world = _world;
    if (_phase != _GamePhase.world || world == null || _aiBusy) {
      return;
    }
    final selected = stackId == null
        ? _selectedStack(world)
        : world.stackById(stackId);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }
    if (selected.forcedMarchRound == world.round) {
      setState(() {
        _status = 'Forced-marched armies cannot establish camp this round.';
      });
      return;
    }
    final existingCamp = world.campAt(selected.position);
    if (existingCamp != null && existingCamp.activeAtRound(world.round)) {
      setState(() {
        _status = existingCamp.ownerId == selected.ownerId
            ? '${selected.id} already has an active camp on this tile.'
            : 'Enemy camp blocks local camp setup.';
      });
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: selected.ownerId,
      cpCost: 1,
      foodCost: 1,
    );
    if (withCost == null) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    final riverbankCamp = withCost.tileTouchesRiver(selected.position);
    final defaultPosture =
        riverbankCamp || _foodForPlayer(withCost, selected.ownerId) <= 2
        ? CampPosture.supply
        : CampPosture.fortified;
    final camps = List<CampState>.from(withCost.camps);
    camps.add(
      CampState(
        id: 'camp_p${selected.ownerId + 1}_${selected.id}_${withCost.round}',
        ownerId: selected.ownerId,
        position: selected.position,
        createdRound: withCost.round,
        expiresRound: withCost.round + (riverbankCamp ? 3 : 2),
        posture: defaultPosture,
        supplyStock: riverbankCamp ? 3 : 2,
        fatigueRecovery: defaultPosture == CampPosture.fortified ? 1 : 0,
        trapPrepared: defaultPosture == CampPosture.fortified,
      ),
    );
    final updatedStacks = withCost.stacks
        .map(
          (stack) => stack.id == selected.id
              ? stack.copyWith(
                  entrenchedUntilRound: null,
                  fatigue: (stack.fatigue - 1).clamp(0, 4),
                )
              : stack,
        )
        .toList();
    final postureLabel = _campPostureLabel(defaultPosture);
    final updatedWorld = withCost.copyWith(
      stacks: updatedStacks,
      camps: camps,
      log: [
        ...withCost.log,
        'Round ${withCost.round}: ${selected.id} established a ${riverbankCamp ? 'riverbank ' : ''}$postureLabel camp at (${selected.position.row},${selected.position.col}).',
      ],
    );
    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: fromAi,
      statusLine:
          '${selected.id} established a ${riverbankCamp ? 'riverbank ' : ''}$postureLabel camp.',
    );
  }

  void _shiftCampPosture({bool fromAi = false}) {
    final world = _world;
    if (_phase != _GamePhase.world || world == null || _aiBusy) {
      return;
    }
    final selected = _selectedStack(world);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      return;
    }
    final camp = _selectedCampForStack(world, selected);
    if (camp == null || camp.ownerId != selected.ownerId) {
      setState(() {
        _status = 'No owned active camp on selected tile.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: selected.ownerId,
      cpCost: 1,
    );
    if (withCost == null) {
      return;
    }

    final camps = List<CampState>.from(withCost.camps);
    final campIndex = camps.indexWhere((existing) => existing.id == camp.id);
    if (campIndex < 0) {
      return;
    }

    final nextPosture = _nextCampPosture(camp.posture);
    camps[campIndex] = camp.copyWith(
      posture: nextPosture,
      expiresRound: (camp.expiresRound + 1).clamp(withCost.round, 99),
      fatigueRecovery: nextPosture == CampPosture.fortified ? 1 : 0,
      trapPrepared: nextPosture == CampPosture.fortified,
      supplyStock: nextPosture == CampPosture.supply
          ? camp.supplyStock.clamp(1, 4)
          : camp.supplyStock,
    );

    final postureLabel = _campPostureLabel(nextPosture);
    final updatedWorld = withCost.copyWith(
      camps: camps,
      log: [
        ...withCost.log,
        'Round ${withCost.round}: ${selected.id} shifted camp to $postureLabel posture.',
      ],
    );
    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: fromAi,
      statusLine: '${selected.id} shifted camp posture to $postureLabel.',
    );
  }

  void _consolidateCampOutpost({String? stackId, bool fromAi = false}) {
    final world = _world;
    if (_phase != _GamePhase.world || world == null || _aiBusy) {
      return;
    }
    final selected = stackId == null
        ? _selectedStack(world)
        : world.stackById(stackId);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }
    final camp = _selectedCampForStack(world, selected);
    if (camp == null || camp.ownerId != selected.ownerId) {
      setState(() {
        _status = 'No owned active camp to consolidate.';
      });
      return;
    }
    if (camp.isOutpost) {
      setState(() {
        _status = 'This camp is already consolidated as an outpost.';
      });
      return;
    }
    if (camp.createdRound >= world.round) {
      setState(() {
        _status = 'A new camp needs one round before outpost consolidation.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: selected.ownerId,
      cpCost: 1,
    );
    if (withCost == null) {
      return;
    }

    final camps = List<CampState>.from(withCost.camps);
    final index = camps.indexWhere((existing) => existing.id == camp.id);
    if (index < 0) {
      return;
    }
    final refreshedExpiry = camp.expiresRound < withCost.round + 6
        ? withCost.round + 6
        : camp.expiresRound;
    camps[index] = camp.copyWith(
      isOutpost: true,
      expiresRound: refreshedExpiry,
      supplyStock: (camp.supplyStock + 1).clamp(0, 4),
      trapPrepared: camp.posture == CampPosture.fortified,
    );

    final updatedWorld = withCost.copyWith(
      camps: camps,
      log: [
        ...withCost.log,
        'Round ${withCost.round}: ${selected.id} consolidated camp into a minor outpost at (${camp.position.row},${camp.position.col}).',
      ],
    );
    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: fromAi,
      statusLine:
          '${selected.id} consolidated camp to an outpost (+lasting support).',
    );
  }

  void _breakCamp({bool fromAi = false}) {
    final world = _world;
    if (_phase != _GamePhase.world || world == null || _aiBusy) {
      return;
    }
    final selected = _selectedStack(world);
    if (selected == null || selected.ownerId != world.activePlayerId) {
      return;
    }
    final camp = _selectedCampForStack(world, selected);
    if (camp == null || camp.ownerId != selected.ownerId) {
      setState(() {
        _status = 'No owned active camp to break.';
      });
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: selected.ownerId,
      cpCost: 0,
    );
    if (withCost == null) {
      return;
    }

    final camps = withCost.camps
        .where((existing) => existing.id != camp.id)
        .toList();
    final updatedWorld = withCost.copyWith(
      camps: camps,
      log: [
        ...withCost.log,
        'Round ${withCost.round}: ${selected.id} broke camp at (${camp.position.row},${camp.position.col}).',
      ],
    );
    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: fromAi,
      statusLine: '${selected.id} broke camp and resumed open march.',
    );
  }

  ArmyDefinition? _studyGeneralInArmy(ArmyDefinition army) {
    final units = List<ArmyUnit>.from(army.units);
    final generalIndex = units.indexWhere(
      (unit) => unit.type == PieceType.general,
    );
    if (generalIndex < 0) {
      return null;
    }

    final unit = units[generalIndex];
    final skill = unit.generalSkill;
    if (skill == null) {
      return null;
    }
    final upgraded = _nextSkillForStudy(skill);
    if (upgraded == null) {
      return null;
    }

    units[generalIndex] = ArmyUnit(
      type: PieceType.general,
      generalSkill: upgraded,
      generalRank: unit.generalRank,
      title: unit.title,
    );
    return army.copyWith(units: units);
  }

  int _levyCooldownForSettlement(
    SettlementState settlement, {
    bool forced = false,
  }) {
    final base = switch (settlement.tier) {
      SettlementTier.village => 2,
      SettlementTier.town => 3,
      SettlementTier.castle => 4,
    };
    return (base + (forced ? 1 : 0)).clamp(1, 99).toInt();
  }

  int _levyCountFromSettlement(
    SettlementState settlement, {
    bool forced = false,
  }) {
    var base = switch (settlement.tier) {
      SettlementTier.village => 1,
      SettlementTier.town => 2,
      SettlementTier.castle => 2,
    };
    if (forced && settlement.tier != SettlementTier.village) {
      base += 1;
    }
    final unrestPenalty = settlement.unrest >= 5 ? 1 : 0;
    final devastationPenalty = settlement.devastation ~/ 4;
    final freshOccupationPenalty =
        settlement.ownerId >= 0 && settlement.occupationAge < 2 ? 1 : 0;
    final lowSupplyPenalty = !forced && settlement.supplyStock <= 0 ? 1 : 0;
    final potential =
        base -
        unrestPenalty -
        devastationPenalty -
        freshOccupationPenalty -
        lowSupplyPenalty;
    return potential.clamp(0, forced ? 4 : 3).toInt();
  }

  ArmyDefinition? _draftLevyIntoArmy(
    ArmyDefinition army, {
    required int levyCount,
  }) {
    if (levyCount <= 0) {
      return null;
    }
    final freeSlots = _maxArmyUnitsPerStack - army.units.length;
    if (freeSlots <= 0) {
      return null;
    }
    final raised = math.min(levyCount, freeSlots);
    if (raised <= 0) {
      return null;
    }
    final units = List<ArmyUnit>.from(army.units);
    for (var i = 0; i < raised; i++) {
      units.add(const ArmyUnit(type: PieceType.pawn, title: 'Levy Infantry'));
    }
    return army.copyWith(units: units);
  }

  GeneralSkill? _nextSkillForStudy(GeneralSkill skill) {
    switch (skill) {
      case GeneralSkill.fragileMarshal:
        return GeneralSkill.fieldCommander;
      case GeneralSkill.fieldCommander:
        return GeneralSkill.veteranCommander;
      case GeneralSkill.veteranCommander:
        return GeneralSkill.warDrummer;
      case GeneralSkill.warDrummer:
        return null;
    }
  }

  int _manhattanDistance(BoardPosition a, BoardPosition b) {
    return (a.row - b.row).abs() + (a.col - b.col).abs();
  }

  _WorldMoveMarker? _enemyWorldMoveMarker({
    required ArmyStack mover,
    required BoardPosition from,
    required BoardPosition to,
    required int round,
  }) {
    if (_playerTypeById(mover.ownerId) != PlayerType.ai) {
      return null;
    }
    return _WorldMoveMarker(
      playerId: mover.ownerId,
      stackId: mover.id,
      from: from,
      to: to,
      round: round,
    );
  }

  _BattlefieldModifiers _buildBattlefieldModifiers({
    required WorldState world,
    required BattlefieldSpec battlefield,
    required ArmyStack attacker,
    required ArmyStack defender,
    required SettlementState? settlement,
    required CampState? camp,
  }) {
    var laneConstraint = 0;
    var moraleShield = 0;
    var garrisonSupport = 0;
    var trapArmed = false;
    final riverAnchor = world.tileTouchesRiver(defender.position);

    final defenderOwnsSettlement =
        settlement != null && settlement.ownerId == defender.ownerId;
    if (defenderOwnsSettlement) {
      laneConstraint += settlement.laneConstraint;
      moraleShield += settlement.moraleShield;
      if (settlement.garrisonedUnits > 0) {
        garrisonSupport = 1;
      }
      trapArmed =
          settlement.trapType == SettlementTrapType.defensiveDitch &&
          settlement.trapArmed;
    }

    final defenderOwnsCamp =
        camp != null &&
        camp.ownerId == defender.ownerId &&
        camp.activeAtRound(world.round);
    if (defenderOwnsCamp) {
      switch (camp.posture) {
        case CampPosture.supply:
          moraleShield += 1;
        case CampPosture.fortified:
          laneConstraint += 1;
          moraleShield += 1;
          trapArmed = trapArmed || camp.trapPrepared;
        case CampPosture.raiding:
          laneConstraint += 1;
      }
    }
    if (riverAnchor) {
      laneConstraint += 1;
      if (defenderOwnsCamp || defenderOwnsSettlement) {
        moraleShield += 1;
      }
    }
    laneConstraint = laneConstraint.clamp(0, 2).toInt();

    final extraBlocked = _fortificationBlocks(
      rows: battlefield.rows,
      cols: battlefield.cols,
      laneConstraint: laneConstraint,
      existing: battlefield.blocked,
    );
    final blockedCells = <BoardPosition>{
      ...battlefield.blocked,
      ...extraBlocked,
    };

    final attackerFood = _foodForPlayer(world, attacker.ownerId);
    final defenderFood = _foodForPlayer(world, defender.ownerId);
    final attackerSupplyPenalty = _stackSupply(attacker.id) <= 1 ? 1 : 0;
    final defenderSupplyPenalty = _stackSupply(defender.id) <= 1 ? 1 : 0;
    final attackerWaterPenalty = _stackWater(attacker.id) <= 1 ? 2 : 0;
    final defenderWaterPenalty = _stackWater(defender.id) <= 1 ? 2 : 0;
    final attackerStarvationPenalty = _stackStarvation(attacker.id) >= 2
        ? 1
        : 0;
    final defenderStarvationPenalty = _stackStarvation(defender.id) >= 2
        ? 1
        : 0;
    final attackerThirstPenalty = _stackThirst(attacker.id) >= 1 ? 1 : 0;
    final defenderThirstPenalty = _stackThirst(defender.id) >= 1 ? 1 : 0;
    final attackerPenalty =
        (attackerFood <= 1 ? 1 : 0) +
        attacker.fatigue +
        attackerSupplyPenalty +
        attackerStarvationPenalty +
        attackerWaterPenalty +
        attackerThirstPenalty;
    final defenderPenalty =
        (defenderFood <= 1 ? 1 : 0) +
        defender.fatigue +
        defenderSupplyPenalty +
        defenderStarvationPenalty +
        defenderWaterPenalty +
        defenderThirstPenalty;

    final attackerMorale = (6 - attackerPenalty).clamp(1, 8).toInt();
    final defenderMorale =
        (6 - defenderPenalty + moraleShield + garrisonSupport)
            .clamp(1, 8)
            .toInt();

    final trapColumn = battlefield.cols ~/ 2;
    final notes = <String>[];
    if (laneConstraint > 0) {
      notes.add(
        'Fortifications constrain $laneConstraint attacker approach lane(s).',
      );
    }
    if (moraleShield > 0 || garrisonSupport > 0) {
      notes.add('Defender shield +${moraleShield + garrisonSupport}.');
    }
    if (riverAnchor) {
      notes.add('River line narrows the frontage near the defender.');
    }
    if (defenderOwnsCamp) {
      notes.add('Defender camp posture: ${_campPostureLabel(camp.posture)}.');
    }
    if (trapArmed) {
      notes.add('Scouts report signs of defensive ditches.');
    }
    if (attackerPenalty > 0 || defenderPenalty > 0) {
      notes.add(
        'Supply/water/fatigue pressure: attacker -$attackerPenalty, defender -$defenderPenalty morale.',
      );
    }

    return _BattlefieldModifiers(
      blockedCells: blockedCells,
      maxMorale: 8,
      attackerMorale: attackerMorale,
      defenderMorale: defenderMorale,
      defenderTrapArmed: trapArmed,
      defenderTrapColumn: trapColumn,
      attackerHint: notes.isEmpty ? null : notes.join(' '),
      laneConstraint: laneConstraint,
      defenderShield: moraleShield + garrisonSupport,
    );
  }

  Set<BoardPosition> _fortificationBlocks({
    required int rows,
    required int cols,
    required int laneConstraint,
    required Set<BoardPosition> existing,
  }) {
    if (laneConstraint <= 0) {
      return const <BoardPosition>{};
    }
    final forwardFortRow = (rows - 3).clamp(1, rows - 2).toInt();
    final candidates = <BoardPosition>[
      BoardPosition(forwardFortRow, cols ~/ 2),
      BoardPosition(forwardFortRow, (cols ~/ 2) - 1),
      BoardPosition(forwardFortRow, (cols ~/ 2) + 1),
    ];
    final blocked = <BoardPosition>{};
    for (final candidate in candidates) {
      if (blocked.length >= laneConstraint) {
        break;
      }
      if (!candidate.inBounds(rows, cols)) {
        continue;
      }
      if (existing.contains(candidate)) {
        continue;
      }
      blocked.add(candidate);
    }
    return blocked;
  }

  void _enterBattlePhase({
    required WorldState preparedWorld,
    required BattleSession session,
    required int actingPlayerId,
    required String statusLine,
    _WorldMoveMarker? enemyMoveMarker,
  }) {
    _battleOverlayTimer?.cancel();
    final updatedActionLedger = <int, int>{..._strategicActionsByPlayer};
    updatedActionLedger[actingPlayerId] =
        (updatedActionLedger[actingPlayerId] ?? 0) + 1;
    final reconciledLogistics = _reconcileStackLogistics(
      preparedWorld,
      supplySource: _stackSupplyById,
      starvationSource: _stackStarvationById,
      waterSource: _stackWaterById,
      thirstSource: _stackThirstById,
    );
    final capturePolicies = _reconcileCapturePolicies(preparedWorld);
    setState(() {
      _world = preparedWorld;
      _strategicActionsByPlayer = updatedActionLedger;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _phase = _GamePhase.battle;
      _battle = session;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = false;
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = null;
      if (enemyMoveMarker != null) {
        _lastEnemyWorldMove = enemyMoveMarker;
      }
      _aiBusy = false;
      _status = statusLine;
    });
  }

  Future<void> _executeWorldMove(WorldMove move, {bool fromAi = false}) async {
    final world = _world;
    if (world == null) {
      return;
    }

    final stack = world.stackById(move.stackId);
    if (stack == null) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }
    if (stack.ownerId != world.activePlayerId) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    final forcedMode = _forcedMarchMode && !fromAi;
    final moveRange = forcedMode ? 2 : 1;
    final legal = world.legalMovesForStack(stack.id, maxSteps: moveRange);
    if (!legal.contains(move.to)) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }
    final forcedDistance = _manhattanDistance(stack.position, move.to);
    final usedForcedMarch = forcedMode && forcedDistance > 1;
    if (usedForcedMarch && _stackFortifiedByCamp(world, stack)) {
      setState(() {
        _status = 'Fortified camp posture blocks forced march this turn.';
      });
      return;
    }
    if (usedForcedMarch && _foodForPlayer(world, stack.ownerId) < 1) {
      setState(() {
        _status = 'Forced march requires at least 1 food.';
      });
      return;
    }

    final movedAttackerStack = stack.copyWith(
      entrenchedUntilRound: null,
      forcedMarchRound: usedForcedMarch ? world.round : stack.forcedMarchRound,
      fatigue: usedForcedMarch
          ? (stack.fatigue + 1).clamp(0, 4)
          : stack.fatigue,
    );
    final enemyMoveMarker = _enemyWorldMoveMarker(
      mover: stack,
      from: stack.position,
      to: move.to,
      round: world.round,
    );

    final occupant = world.stackAt(move.to);
    if (occupant != null && occupant.ownerId != stack.ownerId) {
      final tile = world.tileAt(move.to);
      final settlement = world.settlementAt(move.to);
      final camp = world.campAt(move.to);
      final modifiers = _buildBattlefieldModifiers(
        world: world,
        battlefield: tile.battlefield,
        attacker: movedAttackerStack,
        defender: occupant,
        settlement: settlement,
        camp: camp,
      );
      final southPreferredFormation = _recommendedFormationForBattle(
        attacker: movedAttackerStack.army,
        defender: occupant.army,
      );
      final northPreferredFormation = _recommendedFormationForBattle(
        attacker: occupant.army,
        defender: movedAttackerStack.army,
      );
      final southRawOptions = BattleState.generateSideDeploymentPlans(
        army: movedAttackerStack.army,
        ownerId: movedAttackerStack.ownerId,
        sideIsNorth: false,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: modifiers.blockedCells,
        preferredFormation: southPreferredFormation,
      );
      final northRawOptions = BattleState.generateSideDeploymentPlans(
        army: occupant.army,
        ownerId: occupant.ownerId,
        sideIsNorth: true,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: modifiers.blockedCells,
        preferredFormation: northPreferredFormation,
      );
      final southOptions = _curatedDoctrineOptions(
        southRawOptions,
        recommendedFormation: southPreferredFormation,
      );
      final northOptions = _curatedDoctrineOptions(
        northRawOptions,
        recommendedFormation: northPreferredFormation,
      );

      var southPlan = _recommendedSidePlan(
        southOptions,
        southPreferredFormation,
      );
      var northPlan = _recommendedSidePlan(
        northOptions,
        northPreferredFormation,
      );

      setState(() {
        _aiBusy = true;
        _status = 'Enemy host sighted. War councils are assessing the field...';
      });

      bool engage = true;
      if (_playerTypeById(occupant.ownerId) == PlayerType.human) {
        engage = await _showEngagementDecisionDialog(
          ownStack: occupant,
          enemyStack: movedAttackerStack,
          battlePosition: move.to,
        );
      }

      if (!engage) {
        setState(() {
          _aiBusy = false;
          _status =
              'P${occupant.ownerId + 1} refused engagement. Tactical withdrawal.';
        });
        return;
      }

      if (_playerTypeById(stack.ownerId) == PlayerType.human) {
        setState(() {
          _status =
              'Choose doctrine for ${stack.id}. Enemy doctrine is hidden.';
        });
        final selectedSouth = await _selectSideDeploymentPlan(
          ownStack: movedAttackerStack,
          enemyStack: occupant,
          attackerOwnerId: movedAttackerStack.ownerId,
          battlePosition: move.to,
          options: southOptions,
          recommendedFormation: southPreferredFormation,
          rows: tile.battlefield.rows,
          cols: tile.battlefield.cols,
          blockedCells: modifiers.blockedCells,
          battleHint: modifiers.attackerHint,
        );
        if (!mounted) {
          return;
        }
        if (_phase != _GamePhase.world || _world == null) {
          setState(() {
            _aiBusy = false;
          });
          return;
        }
        if (selectedSouth == null) {
          setState(() {
            _aiBusy = false;
            _status = 'Battle setup canceled.';
          });
          return;
        }
        southPlan = selectedSouth;
      }

      if (_playerTypeById(occupant.ownerId) == PlayerType.human) {
        setState(() {
          _status =
              'Choose doctrine for ${occupant.id}. Enemy doctrine is hidden.';
        });
        final selectedNorth = await _selectSideDeploymentPlan(
          ownStack: occupant,
          enemyStack: movedAttackerStack,
          attackerOwnerId: movedAttackerStack.ownerId,
          battlePosition: move.to,
          options: northOptions,
          recommendedFormation: northPreferredFormation,
          rows: tile.battlefield.rows,
          cols: tile.battlefield.cols,
          blockedCells: modifiers.blockedCells,
          battleHint: modifiers.attackerHint,
        );
        if (!mounted) {
          return;
        }
        if (_phase != _GamePhase.world || _world == null) {
          setState(() {
            _aiBusy = false;
          });
          return;
        }
        if (selectedNorth == null) {
          setState(() {
            _aiBusy = false;
            _status = 'Battle setup canceled.';
          });
          return;
        }
        northPlan = selectedNorth;
      }

      final combinedPieces = [...southPlan.pieces, ...northPlan.pieces];
      final occupiedCells = <BoardPosition>{};
      final hasOverlap = combinedPieces.any(
        (piece) => !occupiedCells.add(piece.position),
      );

      final selectedPlan = hasOverlap
          ? BattleState.generateDeploymentPlans(
              southArmy: movedAttackerStack.army,
              northArmy: occupant.army,
              southOwnerId: movedAttackerStack.ownerId,
              northOwnerId: occupant.ownerId,
              rows: tile.battlefield.rows,
              cols: tile.battlefield.cols,
              blockedCells: modifiers.blockedCells,
              preferredFormation: southPreferredFormation,
            ).first
          : BattleDeploymentPlan(
              id: '${southPlan.id}_vs_${northPlan.id}',
              formation: southPlan.formation,
              label: '${southPlan.label} vs ${northPlan.label}',
              summary: '${southPlan.summary} | ${northPlan.summary}',
              pieces: combinedPieces,
            );

      final withCost = _consumeStrategicCost(
        world: world,
        playerId: movedAttackerStack.ownerId,
        cpCost: 1,
        foodCost: usedForcedMarch ? 1 : 0,
      );
      if (withCost == null) {
        setState(() {
          _aiBusy = false;
        });
        return;
      }

      var battleSettlements = List<SettlementState>.from(withCost.settlements);
      if (settlement != null &&
          settlement.ownerId == occupant.ownerId &&
          settlement.trapArmed) {
        final index = battleSettlements.indexWhere(
          (s) => s.id == settlement.id,
        );
        if (index >= 0) {
          battleSettlements[index] = battleSettlements[index].copyWith(
            trapArmed: false,
          );
        }
      }
      var battleCamps = List<CampState>.from(withCost.camps);
      if (camp != null &&
          camp.ownerId == occupant.ownerId &&
          camp.activeAtRound(withCost.round) &&
          camp.trapPrepared) {
        final campIndex = battleCamps.indexWhere(
          (existing) => existing.id == camp.id,
        );
        if (campIndex >= 0) {
          battleCamps[campIndex] = battleCamps[campIndex].copyWith(
            trapPrepared: false,
          );
        }
      }
      final battleStacks = withCost.stacks.map((existing) {
        if (existing.id == movedAttackerStack.id) {
          return movedAttackerStack;
        }
        return existing;
      }).toList();
      final preparedWorld = withCost.copyWith(
        stacks: battleStacks,
        settlements: battleSettlements,
        camps: battleCamps,
        log: [
          ...withCost.log,
          'P${movedAttackerStack.ownerId + 1} engaged ${occupant.id} at (${move.to.row},${move.to.col}).',
        ],
      );

      final battleMorale = modifiers.initialMoraleByPlayer(
        attackerId: movedAttackerStack.ownerId,
        defenderId: occupant.ownerId,
      );
      final battleState = BattleState.fromDeploymentPlan(
        plan: selectedPlan,
        southOwnerId: movedAttackerStack.ownerId,
        northOwnerId: occupant.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: modifiers.blockedCells,
        maxMorale: modifiers.maxMorale,
        initialMoraleByPlayer: battleMorale,
        trapArmedByPlayer: modifiers.trapArmedByPlayer(
          defenderId: occupant.ownerId,
        ),
        trapColumnByPlayer: modifiers.trapColumnByPlayer(
          defenderId: occupant.ownerId,
        ),
        extraEvents: modifiers.deploymentEvents(
          attackerId: movedAttackerStack.ownerId,
          defenderId: occupant.ownerId,
        ),
      );

      final skipAiBattle =
          _skipAiBattles &&
          _playerTypeById(movedAttackerStack.ownerId) == PlayerType.ai &&
          _playerTypeById(occupant.ownerId) == PlayerType.ai;
      if (skipAiBattle) {
        final autoResult = _simulateAiBattleOutcome(
          initialState: battleState,
          attackerPlayerId: movedAttackerStack.ownerId,
          defenderPlayerId: occupant.ownerId,
        );
        _enterBattlePhase(
          preparedWorld: preparedWorld,
          session: BattleSession(
            attackerStack: movedAttackerStack,
            defenderStack: occupant,
            battleState: autoResult.finalState,
            battlefield: tile.battlefield,
          ),
          actingPlayerId: movedAttackerStack.ownerId,
          enemyMoveMarker: enemyMoveMarker,
          statusLine:
              'AI battle auto-resolved at (${move.to.row},${move.to.col}).',
        );
        _finishBattle(autoResult.winnerPlayerId, autoResult.reason);
        return;
      }

      _enterBattlePhase(
        preparedWorld: preparedWorld,
        session: BattleSession(
          attackerStack: movedAttackerStack,
          defenderStack: occupant,
          battleState: battleState,
          battlefield: tile.battlefield,
        ),
        actingPlayerId: movedAttackerStack.ownerId,
        enemyMoveMarker: enemyMoveMarker,
        statusLine:
            'Battle started at (${move.to.row},${move.to.col}) on ${tile.battlefield.notation}.',
      );

      _triggerAiTurnIfNeeded();
      return;
    }

    final withCost = _consumeStrategicCost(
      world: world,
      playerId: stack.ownerId,
      cpCost: 1,
      foodCost: usedForcedMarch ? 1 : 0,
    );
    if (withCost == null) {
      return;
    }

    final updatedStacks = List<ArmyStack>.from(withCost.stacks);
    final movingIndex = updatedStacks.indexWhere((item) => item.id == stack.id);
    if (movingIndex < 0) {
      return;
    }
    updatedStacks[movingIndex] = updatedStacks[movingIndex].copyWith(
      position: move.to,
      entrenchedUntilRound: null,
      forcedMarchRound: usedForcedMarch ? world.round : stack.forcedMarchRound,
      fatigue: usedForcedMarch
          ? (stack.fatigue + 1).clamp(0, 4)
          : stack.fatigue,
    );
    final updatedSupplyById = <String, int>{..._stackSupplyById};
    final updatedStarvationById = <String, int>{..._stackStarvationById};
    final updatedWaterById = <String, int>{..._stackWaterById};
    final updatedThirstById = <String, int>{..._stackThirstById};
    var updatedSettlements = List<SettlementState>.from(world.settlements);
    var updatedCamps = List<CampState>.from(world.camps);
    var updatedFoodTileOwners = <BoardPosition, int>{
      ..._foodTileOwnerByPosition,
    };
    var updatedPillagedTiles = <BoardPosition, int>{..._pillagedTileUntilRound};
    String? settlementCaptureLog;
    String? campCaptureLog;
    var supplyGainFromCapture = 0;
    var forcedLevyCount = 0;
    final settlement = withCost.settlementAt(move.to);
    if (settlement != null && settlement.ownerId != stack.ownerId) {
      final capturePolicy = _capturePolicyForMove(
        world: withCost,
        stack: stack,
        fromAi: fromAi,
      );
      final index = updatedSettlements.indexWhere((s) => s.id == settlement.id);
      if (index >= 0) {
        final devastationGain = capturePolicy == _CapturePolicy.destroy ? 3 : 1;
        final unrestGain = capturePolicy == _CapturePolicy.destroy ? 4 : 2;
        supplyGainFromCapture = capturePolicy == _CapturePolicy.destroy ? 3 : 1;
        if (capturePolicy == _CapturePolicy.spare) {
          final leviedArmy = _draftLevyIntoArmy(
            updatedStacks[movingIndex].army,
            levyCount: _levyCountFromSettlement(settlement, forced: true),
          );
          if (leviedArmy != null) {
            forcedLevyCount =
                leviedArmy.units.length -
                updatedStacks[movingIndex].army.units.length;
            if (forcedLevyCount > 0) {
              updatedStacks[movingIndex] = updatedStacks[movingIndex].copyWith(
                army: leviedArmy,
              );
            }
          }
        }
        updatedSettlements[index] = settlement.copyWith(
          ownerId: stack.ownerId,
          unrest: (settlement.unrest + unrestGain).clamp(0, 8),
          garrisonedUnits: 0,
          levyCooldown: capturePolicy == _CapturePolicy.destroy
              ? 4
              : _levyCooldownForSettlement(settlement, forced: true),
          trapArmed: false,
          lastCapturedRound: world.round,
          occupationAge: 0,
          devastation: (settlement.devastation + devastationGain).clamp(0, 8),
        );
        settlementCaptureLog = capturePolicy == _CapturePolicy.destroy
            ? '${stack.id} destroyed ${settlement.name} during capture (+$supplyGainFromCapture army supply).'
            : '${stack.id} seized ${settlement.name} with population spared (+$supplyGainFromCapture army supply).';
        if (forcedLevyCount > 0) {
          settlementCaptureLog =
              '$settlementCaptureLog Forced levy raised +$forcedLevyCount infantry.';
        }
      }
    }
    final campAtDestination = withCost.campAt(move.to);
    if (campAtDestination != null &&
        campAtDestination.ownerId != stack.ownerId &&
        campAtDestination.activeAtRound(withCost.round)) {
      updatedCamps = updatedCamps
          .where((camp) => camp.id != campAtDestination.id)
          .toList();
      supplyGainFromCapture += 1;
      campCaptureLog =
          '${stack.id} overran an enemy ${_campPostureLabel(campAtDestination.posture).toLowerCase()} camp (+1 army supply).';
    }
    if (withCost.tileAt(move.to).terrain == TerrainType.passable &&
        withCost.settlementAt(move.to) == null &&
        (updatedPillagedTiles[move.to] ?? 0) < withCost.round) {
      updatedFoodTileOwners[move.to] = stack.ownerId;
    }
    if (supplyGainFromCapture > 0) {
      final before =
          updatedSupplyById[stack.id] ?? _initialSupplyForStack(world, stack);
      updatedSupplyById[stack.id] = (before + supplyGainFromCapture)
          .clamp(0, 8)
          .toInt();
      updatedStarvationById[stack.id] = 0;
    }
    if (_hasReliableWaterSource(withCost, move.to)) {
      final before =
          updatedWaterById[stack.id] ?? _initialWaterForStack(withCost, stack);
      updatedWaterById[stack.id] = (before + 1).clamp(0, 6).toInt();
      updatedThirstById[stack.id] = 0;
    }

    final actor = fromAi ? 'AI' : 'Player ${stack.ownerId + 1}';
    final updatedWorld = withCost.copyWith(
      stacks: updatedStacks,
      settlements: updatedSettlements,
      camps: updatedCamps,
      log: [
        ...withCost.log,
        '$actor moved ${stack.id} to (${move.to.row},${move.to.col}).',
        ...settlementCaptureLog == null
            ? const <String>[]
            : <String>[settlementCaptureLog],
        ...campCaptureLog == null ? const <String>[] : <String>[campCaptureLog],
      ],
    );

    _finalizeStrategicAction(
      updatedWorld: updatedWorld,
      fromAi: fromAi,
      statusLine: usedForcedMarch
          ? '${stack.id} forced marched to (${move.to.row},${move.to.col}).'
          : '${stack.id} moved to (${move.to.row},${move.to.col}).',
      worldMoveMarker: enemyMoveMarker,
      stackSupplyById: updatedSupplyById,
      stackStarvationById: updatedStarvationById,
      stackWaterById: updatedWaterById,
      stackThirstById: updatedThirstById,
      preserveStackId: stack.id,
      foodTileOwnerByPosition: updatedFoodTileOwners,
      pillagedTileUntilRound: updatedPillagedTiles,
    );
  }

  void _advanceWorldTurn([String? additionalLog]) {
    final world = _world;
    if (world == null) {
      return;
    }

    var updatedWorld = world;
    var supplyByStackId = Map<String, int>.from(_stackSupplyById);
    var starvationByStackId = Map<String, int>.from(_stackStarvationById);
    var waterByStackId = Map<String, int>.from(_stackWaterById);
    var thirstByStackId = Map<String, int>.from(_stackThirstById);
    var foodTileOwnerByPosition = Map<BoardPosition, int>.from(
      _foodTileOwnerByPosition,
    );
    var pillagedTileUntilRound = Map<BoardPosition, int>.from(
      _pillagedTileUntilRound,
    );
    final finishingPlayerId = updatedWorld.activePlayerId;
    final actionsTaken = _strategicActionsByPlayer[finishingPlayerId] ?? 0;
    final (tempoAdjustedWorld, tempoStatus) = _applyCasusTempoResolution(
      world: updatedWorld,
      playerId: finishingPlayerId,
      actionCount: actionsTaken,
    );
    updatedWorld = tempoAdjustedWorld;
    if (additionalLog != null) {
      updatedWorld = updatedWorld.copyWith(
        log: [...updatedWorld.log, additionalLog],
      );
    }

    final aliveOwners = updatedWorld.stacks
        .map((stack) => stack.ownerId)
        .toSet()
        .toList();

    if (aliveOwners.length <= 1) {
      final winner = aliveOwners.isEmpty ? null : aliveOwners.first;
      final summary = _buildMatchOverSummary(updatedWorld, winner);
      final reconciledLogistics = _reconcileStackLogistics(
        updatedWorld,
        supplySource: supplyByStackId,
        starvationSource: starvationByStackId,
        waterSource: waterByStackId,
        thirstSource: thirstByStackId,
      );
      final capturePolicies = _reconcileCapturePolicies(updatedWorld);
      final sequence = _matchOverSequence + 1;
      setState(() {
        _world = updatedWorld;
        _stackSupplyById = reconciledLogistics.supplyById;
        _stackStarvationById = reconciledLogistics.starvationById;
        _stackWaterById = reconciledLogistics.waterById;
        _stackThirstById = reconciledLogistics.thirstById;
        _capturePolicyByPlayer = capturePolicies;
        _foodTileOwnerByPosition = _sanitizeFoodTileControlMap(
          updatedWorld,
          source: foodTileOwnerByPosition,
        );
        _pillagedTileUntilRound = _sanitizePillagedTileMap(
          updatedWorld,
          source: pillagedTileUntilRound,
        );
        _phase = _GamePhase.gameOver;
        _matchOverSummary = summary;
        _matchOverBannerVisible = false;
        _matchOverPopupShown = false;
        _matchOverSequence = sequence;
        _status = winner == null
            ? 'Draw: all armies eliminated.'
            : 'Player ${winner + 1} wins the match.';
      });
      _startMatchOverSequence(sequence);
      return;
    }

    var nextIndex = updatedWorld.activePlayerIndex;
    var nextRound = updatedWorld.round;
    final currentRound = updatedWorld.round;

    do {
      nextIndex = (nextIndex + 1) % updatedWorld.players.length;
      if (nextIndex == 0) {
        nextRound++;
      }
    } while (updatedWorld
        .stacksForPlayer(updatedWorld.players[nextIndex].id)
        .isEmpty);

    updatedWorld = updatedWorld.copyWith(
      activePlayerIndex: nextIndex,
      round: nextRound,
    );
    if (nextRound > currentRound) {
      updatedWorld = _applySettlementRound(updatedWorld);
      final logistics = _applyArmyLogisticsRound(
        updatedWorld,
        supplySource: supplyByStackId,
        starvationSource: starvationByStackId,
        waterSource: waterByStackId,
        thirstSource: thirstByStackId,
      );
      updatedWorld = logistics.world;
      supplyByStackId = logistics.supplyByStackId;
      starvationByStackId = logistics.starvationByStackId;
      waterByStackId = logistics.waterByStackId;
      thirstByStackId = logistics.thirstByStackId;
      foodTileOwnerByPosition = _sanitizeFoodTileControlMap(
        updatedWorld,
        source: foodTileOwnerByPosition,
      );
      pillagedTileUntilRound = _sanitizePillagedTileMap(
        updatedWorld,
        source: pillagedTileUntilRound,
      );
    }

    final nextPlayerId = updatedWorld.players[nextIndex].id;
    final cpByPlayer = <int, int>{...updatedWorld.commandPointsByPlayer};
    cpByPlayer[nextPlayerId] = updatedWorld.commandPointMax;
    updatedWorld = updatedWorld.copyWith(commandPointsByPlayer: cpByPlayer);
    final activeCp = _commandPointsForPlayer(updatedWorld, nextPlayerId);
    final updatedActionLedger = <int, int>{..._strategicActionsByPlayer};
    updatedActionLedger[finishingPlayerId] = 0;
    final reconciledLogistics = _reconcileStackLogistics(
      updatedWorld,
      supplySource: supplyByStackId,
      starvationSource: starvationByStackId,
      waterSource: waterByStackId,
      thirstSource: thirstByStackId,
    );
    final capturePolicies = _reconcileCapturePolicies(updatedWorld);

    setState(() {
      _world = updatedWorld;
      _strategicActionsByPlayer = updatedActionLedger;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _foodTileOwnerByPosition = foodTileOwnerByPosition;
      _pillagedTileUntilRound = pillagedTileUntilRound;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = false;
      _status =
          '${tempoStatus == null ? '' : '$tempoStatus\n'}'
          'Round ${updatedWorld.round}: ${updatedWorld.players[nextIndex].name} turn ($activeCp CP).';
    });

    _triggerAiTurnIfNeeded();
  }

  WorldState _applySettlementRound(WorldState world) {
    final settlements = <SettlementState>[];
    final treasury = <int, int>{...world.treasuryByPlayer};
    final food = <int, int>{...world.foodByPlayer};
    final log = List<String>.from(world.log);
    final incomeByPlayer = <int, int>{};
    final outpostIncomeByPlayer = <int, int>{};
    final foodByPlayerFromSettlements = <int, int>{};

    for (final settlement in world.settlements) {
      var updatedSupply = settlement.supplyStock;
      var updatedUnrest = settlement.unrest;
      final ownerId = settlement.ownerId;
      var updatedOccupationAge = settlement.occupationAge;
      var updatedDevastation = settlement.devastation;

      if (ownerId >= 0) {
        updatedOccupationAge = (updatedOccupationAge + 1).clamp(0, 99);
        updatedDevastation = (updatedDevastation - 1).clamp(0, 8);
        final harvest = _settlementHarvest(
          settlement,
          occupationAge: updatedOccupationAge,
          devastation: updatedDevastation,
        );
        updatedSupply = (updatedSupply + harvest).clamp(0, 8);
        final unrestRecoveryFromGarrison = settlement.garrisonedUnits > 0
            ? 1
            : 0;
        updatedUnrest = (updatedUnrest - 1 - unrestRecoveryFromGarrison).clamp(
          0,
          8,
        );

        final taxIncome = _settlementTaxIncome(
          settlement,
          updatedUnrest,
          devastation: updatedDevastation,
        );
        if (taxIncome > 0) {
          treasury[ownerId] = (treasury[ownerId] ?? 0) + taxIncome;
          incomeByPlayer[ownerId] = (incomeByPlayer[ownerId] ?? 0) + taxIncome;
        }

        final transferableFood = _settlementFoodTransfer(
          settlement: settlement,
          supplyStock: updatedSupply,
          unrest: updatedUnrest,
          world: world,
          occupationAge: updatedOccupationAge,
          devastation: updatedDevastation,
        );
        if (transferableFood > 0) {
          food[ownerId] = ((food[ownerId] ?? 0) + transferableFood).clamp(
            0,
            99,
          );
          foodByPlayerFromSettlements[ownerId] =
              (foodByPlayerFromSettlements[ownerId] ?? 0) + transferableFood;
          updatedSupply = (updatedSupply - transferableFood).clamp(0, 8);
        }
      } else {
        updatedSupply = (updatedSupply + 1).clamp(0, 8);
        updatedUnrest = (updatedUnrest - 1).clamp(0, 8);
        updatedOccupationAge = 0;
      }

      settlements.add(
        settlement.copyWith(
          supplyStock: updatedSupply,
          unrest: updatedUnrest,
          levyCooldown: (settlement.levyCooldown - 1).clamp(0, 99),
          occupationAge: updatedOccupationAge,
          devastation: updatedDevastation,
        ),
      );
    }

    final camps = <CampState>[];
    final campFoodByPlayer = <int, int>{};
    for (final camp in world.camps) {
      if (!camp.activeAtRound(world.round)) {
        log.add(
          'Round ${world.round}: Player ${camp.ownerId + 1} ${camp.isOutpost ? 'outpost lapsed' : 'camp expired'} at (${camp.position.row},${camp.position.col}).',
        );
        continue;
      }

      var updatedCamp = camp;
      switch (camp.posture) {
        case CampPosture.supply:
          if (camp.supplyStock > 0) {
            final gain = 1;
            food[camp.ownerId] = ((food[camp.ownerId] ?? 0) + gain).clamp(
              0,
              99,
            );
            campFoodByPlayer[camp.ownerId] =
                (campFoodByPlayer[camp.ownerId] ?? 0) + gain;
            updatedCamp = camp.copyWith(
              supplyStock: (camp.supplyStock - gain).clamp(0, 8),
              trapPrepared: false,
              fatigueRecovery: 0,
            );
          } else {
            updatedCamp = camp.copyWith(
              trapPrepared: false,
              fatigueRecovery: 0,
            );
          }
        case CampPosture.fortified:
          final guardingStack = world.stackAt(camp.position);
          final guarded =
              guardingStack != null && guardingStack.ownerId == camp.ownerId;
          updatedCamp = camp.copyWith(
            trapPrepared: guarded,
            fatigueRecovery: 1,
          );
        case CampPosture.raiding:
          var raidedSettlements = 0;
          for (var i = 0; i < settlements.length; i++) {
            final target = settlements[i];
            if (target.ownerId < 0 || target.ownerId == camp.ownerId) {
              continue;
            }
            if (_manhattanDistance(camp.position, target.position) > 1) {
              continue;
            }
            settlements[i] = target.copyWith(
              unrest: (target.unrest + 1).clamp(0, 8),
            );
            raidedSettlements++;
          }
          if (raidedSettlements > 0) {
            final raidFood = raidedSettlements.clamp(0, 2).toInt();
            food[camp.ownerId] = ((food[camp.ownerId] ?? 0) + raidFood).clamp(
              0,
              99,
            );
            campFoodByPlayer[camp.ownerId] =
                (campFoodByPlayer[camp.ownerId] ?? 0) + raidFood;
            log.add(
              'Round ${world.round}: Player ${camp.ownerId + 1} raided from camp at (${camp.position.row},${camp.position.col}), pressuring $raidedSettlements settlement(s).',
            );
          }
          updatedCamp = camp.copyWith(trapPrepared: false, fatigueRecovery: 0);
      }

      if (updatedCamp.isOutpost) {
        treasury[updatedCamp.ownerId] =
            (treasury[updatedCamp.ownerId] ?? 0) + 1;
        outpostIncomeByPlayer[updatedCamp.ownerId] =
            (outpostIncomeByPlayer[updatedCamp.ownerId] ?? 0) + 1;
        final anchoredBySettlement = settlements.any(
          (settlement) =>
              settlement.position == updatedCamp.position &&
              settlement.ownerId == updatedCamp.ownerId,
        );
        final anchoredByStack =
            world.stackAt(updatedCamp.position)?.ownerId == updatedCamp.ownerId;
        final anchored = anchoredBySettlement || anchoredByStack;
        final prolongedExpiry = anchored
            ? (updatedCamp.expiresRound < world.round + 3
                  ? world.round + 3
                  : updatedCamp.expiresRound)
            : updatedCamp.expiresRound;
        updatedCamp = updatedCamp.copyWith(
          expiresRound: prolongedExpiry,
          supplyStock: (updatedCamp.supplyStock + (anchored ? 1 : 0)).clamp(
            0,
            4,
          ),
        );
      }

      camps.add(updatedCamp);
    }

    final fieldFoodByPlayer = <int, int>{};
    final sanitizedFoodTiles = _sanitizeFoodTileControlMap(
      world,
      source: _foodTileOwnerByPosition,
    );
    final sanitizedPillagedTiles = _sanitizePillagedTileMap(
      world,
      source: _pillagedTileUntilRound,
    );
    for (final entry in sanitizedFoodTiles.entries) {
      final position = entry.key;
      final ownerId = entry.value;
      if ((sanitizedPillagedTiles[position] ?? 0) >= world.round) {
        continue;
      }
      final gain = 1;
      food[ownerId] = ((food[ownerId] ?? 0) + gain).clamp(0, 99);
      fieldFoodByPlayer[ownerId] = (fieldFoodByPlayer[ownerId] ?? 0) + gain;
    }

    for (final player in world.players) {
      final playerStacks = world.stacksForPlayer(player.id);
      final stackCount = playerStacks.length;
      if (stackCount <= 0) {
        continue;
      }

      final availableFood = food[player.id] ?? 0;
      final consumedFood = availableFood >= stackCount
          ? stackCount
          : availableFood;
      final shortage = stackCount - consumedFood;
      food[player.id] = (availableFood - consumedFood).clamp(0, 99);

      final taxIncome = incomeByPlayer[player.id] ?? 0;
      final outpostIncome = outpostIncomeByPlayer[player.id] ?? 0;
      final gatheredFood = foodByPlayerFromSettlements[player.id] ?? 0;
      final campFood = campFoodByPlayer[player.id] ?? 0;
      final fieldFood = fieldFoodByPlayer[player.id] ?? 0;
      if (taxIncome > 0 ||
          outpostIncome > 0 ||
          gatheredFood > 0 ||
          campFood > 0 ||
          fieldFood > 0) {
        log.add(
          'Round ${world.round}: ${player.name} collected +$taxIncome coin from settlements, +$outpostIncome coin from outposts, +$gatheredFood food from settlements, +$campFood food from camps, +$fieldFood food from secured fields.',
        );
      }
      if (shortage > 0) {
        log.add(
          'Round ${world.round}: ${player.name} supply shortage ($shortage stack(s) unsupplied).',
        );
      }
    }

    return world.copyWith(
      settlements: settlements,
      camps: camps,
      stacks: world.stacks,
      treasuryByPlayer: treasury,
      foodByPlayer: food,
      log: log,
    );
  }

  _ArmyLogisticsRoundResult _applyArmyLogisticsRound(
    WorldState world, {
    required Map<String, int> supplySource,
    required Map<String, int> starvationSource,
    required Map<String, int> waterSource,
    required Map<String, int> thirstSource,
  }) {
    final settlements = List<SettlementState>.from(world.settlements);
    final settlementByPosition = <BoardPosition, int>{
      for (var i = 0; i < settlements.length; i++) settlements[i].position: i,
    };
    final campsByPosition = <BoardPosition, CampState>{
      for (final camp in world.camps)
        if (camp.activeAtRound(world.round)) camp.position: camp,
    };
    final log = List<String>.from(world.log);
    final updatedStacks = <ArmyStack>[];
    final supplyByStackId = <String, int>{};
    final starvationByStackId = <String, int>{};
    final waterByStackId = <String, int>{};
    final thirstByStackId = <String, int>{};

    for (final stack in world.stacks) {
      final previousSupply =
          (supplySource[stack.id] ?? _initialSupplyForStack(world, stack))
              .clamp(0, 8)
              .toInt();
      final previousWater =
          (waterSource[stack.id] ?? _initialWaterForStack(world, stack))
              .clamp(0, 6)
              .toInt();
      final supplyReport = _supplyLineReport(world, stack);
      var supplyGain = 0;
      var waterGain = 0;
      var dangerousForage = false;
      final enemyPressure = _enemyPressureAt(
        world,
        stack.position,
        stack.ownerId,
      );

      final settlementIndex = settlementByPosition[stack.position];
      if (settlementIndex != null) {
        final settlement = settlements[settlementIndex];
        waterGain += 1;
        if (settlement.ownerId == stack.ownerId) {
          final requisition = switch (supplyReport.state) {
            _SupplyLineState.secure => settlement.supplyStock >= 2 ? 2 : 1,
            _SupplyLineState.stretched => 1,
            _SupplyLineState.isolated => 1,
          };
          final granted = settlement.supplyStock <= 0
              ? 0
              : requisition.clamp(0, settlement.supplyStock);
          if (granted > 0) {
            supplyGain += granted;
            settlements[settlementIndex] = settlement.copyWith(
              supplyStock: (settlement.supplyStock - granted).clamp(0, 8),
              unrest: (settlement.unrest + 1).clamp(0, 8),
            );
          }
        } else if (settlement.ownerId >= 0 &&
            settlement.ownerId != stack.ownerId) {
          supplyGain += 1;
        }
      } else {
        final isPassable =
            world.tileAt(stack.position).terrain == TerrainType.passable;
        final tileOwner = _foodTileOwnerByPosition[stack.position];
        final tilePillaged =
            (_pillagedTileUntilRound[stack.position] ?? 0) >= world.round;
        if (supplyReport.state == _SupplyLineState.secure) {
          supplyGain += 1;
        }
        if (isPassable && !tilePillaged) {
          if (tileOwner == stack.ownerId) {
            supplyGain += supplyReport.state == _SupplyLineState.isolated
                ? 1
                : 2;
            dangerousForage = supplyReport.state != _SupplyLineState.secure;
          } else if (tileOwner == null) {
            supplyGain += 1;
            dangerousForage = true;
          } else if (tileOwner != stack.ownerId) {
            supplyGain += 1;
            dangerousForage = true;
          }
        }
      }

      final camp = campsByPosition[stack.position];
      if (camp != null && camp.ownerId == stack.ownerId) {
        if (camp.posture == CampPosture.supply && camp.supplyStock > 0) {
          supplyGain += 1;
        }
        waterGain += camp.posture == CampPosture.supply ? 2 : 1;
      }
      if (world.tileTouchesRiver(stack.position)) {
        waterGain += 2;
      }
      if (supplyReport.state == _SupplyLineState.stretched &&
          settlementIndex == null &&
          camp == null &&
          supplyGain > 0) {
        supplyGain -= 1;
      }

      final supplyAfterUpkeep = (previousSupply + supplyGain - 1).clamp(0, 8);
      final newSupply = supplyAfterUpkeep.toInt();
      final waterAfterUpkeep = (previousWater + waterGain - 1).clamp(0, 6);
      final newWater = waterAfterUpkeep.toInt();
      var starvation = (starvationSource[stack.id] ?? 0).clamp(0, 6).toInt();
      if (newSupply <= 0) {
        starvation = (starvation + 1).clamp(0, 6).toInt();
      } else if (newSupply >= 2) {
        starvation = (starvation - 1).clamp(0, 6).toInt();
      }
      var thirst = (thirstSource[stack.id] ?? 0).clamp(0, 6).toInt();
      if (newWater <= 0) {
        thirst = (thirst + 2).clamp(0, 6).toInt();
      } else if (newWater <= 1) {
        thirst = (thirst + 1).clamp(0, 6).toInt();
      } else if (newWater >= 3) {
        thirst = (thirst - 1).clamp(0, 6).toInt();
      }
      if (dangerousForage) {
        if (enemyPressure > 0 && !world.tileTouchesRiver(stack.position)) {
          thirst = (thirst + 1).clamp(0, 6).toInt();
        }
      }

      var updatedFatigue = dangerousForage
          ? (stack.fatigue + 1).clamp(0, 4)
          : stack.fatigue;
      if (newSupply <= 0) {
        updatedFatigue = (updatedFatigue + 1).clamp(0, 4);
      } else if (newSupply >= 4) {
        updatedFatigue = (updatedFatigue - 1).clamp(0, 4);
      }
      if (starvation >= 2) {
        updatedFatigue = (updatedFatigue + 1).clamp(0, 4);
      }
      if (newWater <= 1 || thirst >= 1) {
        updatedFatigue = (updatedFatigue + 1).clamp(0, 4);
      }

      var updatedArmy = stack.army;
      if (thirst >= 2) {
        final afterDesertion = _removeDesertingUnit(updatedArmy);
        if (afterDesertion != null) {
          updatedArmy = afterDesertion;
          log.add(
            'Round ${world.round}: ${stack.id} lost a unit to thirst and straggling near ${_waterAccessLabel(world, stack.position).toLowerCase()}.',
          );
        }
      }
      if (starvation >= 3) {
        final afterDesertion = _removeDesertingUnit(updatedArmy);
        if (afterDesertion != null) {
          updatedArmy = afterDesertion;
          log.add(
            'Round ${world.round}: ${stack.id} lost a unit to starvation desertion.',
          );
        }
      }
      if (dangerousForage) {
        final dangerText = enemyPressure > 0
            ? 'foraged under enemy pressure'
            : 'foraged off unsecured ground';
        log.add(
          'Round ${world.round}: ${stack.id} $dangerText because its line to ${supplyReport.anchor?.label ?? 'home territory'} is ${supplyReport.stateLabel.toLowerCase()}.',
        );
      }
      if (supplyReport.state == _SupplyLineState.isolated) {
        log.add(
          'Round ${world.round}: ${stack.id} is isolated from friendly supply territory.',
        );
      }

      if (newSupply <= 1) {
        log.add(
          'Round ${world.round}: ${stack.id} supply is critical (S$newSupply).',
        );
      }
      if (newWater <= 1) {
        log.add(
          'Round ${world.round}: ${stack.id} water is failing (W$newWater).',
        );
      }

      supplyByStackId[stack.id] = newSupply;
      starvationByStackId[stack.id] = starvation;
      waterByStackId[stack.id] = newWater;
      thirstByStackId[stack.id] = thirst;
      updatedStacks.add(
        stack.copyWith(army: updatedArmy, fatigue: updatedFatigue),
      );
    }

    return _ArmyLogisticsRoundResult(
      world: world.copyWith(
        settlements: settlements,
        stacks: updatedStacks,
        log: log,
      ),
      supplyByStackId: supplyByStackId,
      starvationByStackId: starvationByStackId,
      waterByStackId: waterByStackId,
      thirstByStackId: thirstByStackId,
    );
  }

  ArmyDefinition? _removeDesertingUnit(ArmyDefinition army) {
    if (army.units.length <= 1) {
      return null;
    }
    final units = List<ArmyUnit>.from(army.units);
    final idx = units.indexWhere((unit) => unit.type != PieceType.general);
    if (idx < 0) {
      return null;
    }
    units.removeAt(idx);
    return army.copyWith(units: units);
  }

  int _settlementHarvest(
    SettlementState settlement, {
    int? occupationAge,
    int? devastation,
  }) {
    final occAge = occupationAge ?? settlement.occupationAge;
    final damage = devastation ?? settlement.devastation;
    final baseHarvest = switch (settlement.tier) {
      SettlementTier.village => 2,
      SettlementTier.town => 1,
      SettlementTier.castle => 1,
    };
    final cultureBonus = switch (settlement.tier) {
      SettlementTier.village => settlement.cultureRating >= 2 ? 1 : 0,
      SettlementTier.town => settlement.cultureRating >= 3 ? 1 : 0,
      SettlementTier.castle => settlement.cultureRating >= 4 ? 1 : 0,
    };
    final unrestPenalty = settlement.unrest >= 6 ? 1 : 0;
    final devastationPenalty = damage ~/ 3;
    final occupationPenalty = occAge < 2 && settlement.ownerId >= 0 ? 1 : 0;
    return (baseHarvest +
            cultureBonus -
            unrestPenalty -
            devastationPenalty -
            occupationPenalty)
        .clamp(0, 3)
        .toInt();
  }

  int _settlementTaxIncome(
    SettlementState settlement,
    int unrest, {
    int? devastation,
  }) {
    final damage = devastation ?? settlement.devastation;
    final governanceBonus = switch (settlement.tier) {
      SettlementTier.village => 0,
      SettlementTier.town => 1,
      SettlementTier.castle => 1,
    };
    final unrestPenalty = switch (settlement.tier) {
      SettlementTier.village => unrest ~/ 2,
      SettlementTier.town => unrest ~/ 3,
      SettlementTier.castle => unrest ~/ 4,
    };
    final devastationPenalty = damage ~/ 2;
    final maxIncome = settlement.taxYield + governanceBonus;
    return (maxIncome - unrestPenalty - devastationPenalty)
        .clamp(0, maxIncome)
        .toInt();
  }

  int _settlementFoodTransfer({
    required SettlementState settlement,
    required int supplyStock,
    required int unrest,
    required WorldState world,
    int? occupationAge,
    int? devastation,
  }) {
    if (supplyStock <= 0) {
      return 0;
    }
    final occAge = occupationAge ?? settlement.occupationAge;
    final damage = devastation ?? settlement.devastation;
    final baseTransfer = switch (settlement.tier) {
      SettlementTier.village => 2,
      SettlementTier.town => 1,
      SettlementTier.castle => 1,
    };
    final cultureBonus = settlement.cultureRating >= 2
        ? (settlement.tier == SettlementTier.village ? 1 : 0)
        : 0;
    final fortressLogisticsBonus =
        settlement.tier == SettlementTier.castle &&
            settlement.garrisonedUnits > 0
        ? 1
        : 0;
    final unrestPenalty = unrest >= 6 ? 1 : 0;
    final devastationPenalty = damage ~/ 3;
    final occupationBonus = occAge >= 4 ? 1 : 0;
    final logisticPenalty = _logisticDistancePenalty(world, settlement);
    final potential =
        (baseTransfer +
                cultureBonus +
                fortressLogisticsBonus +
                occupationBonus -
                unrestPenalty -
                devastationPenalty -
                logisticPenalty)
            .clamp(0, 3)
            .toInt();
    return potential > supplyStock ? supplyStock : potential;
  }

  int _logisticDistancePenalty(WorldState world, SettlementState settlement) {
    final ownerId = settlement.ownerId;
    if (ownerId < 0) {
      return 0;
    }
    var best = world.size + 2;
    for (final other in world.settlements) {
      if (other.id == settlement.id || other.ownerId != ownerId) {
        continue;
      }
      final distance = _manhattanDistance(settlement.position, other.position);
      if (distance < best) {
        best = distance;
      }
    }
    if (best <= 2) {
      return 0;
    }
    if (best <= 4) {
      return 1;
    }
    return 2;
  }

  _FoodProjection _foodProjectionForPlayer(WorldState world, int playerId) {
    final reserve = _foodForPlayer(world, playerId);
    final upkeep = world.stacksForPlayer(playerId).length;
    var settlementIncome = 0;
    var campIncome = 0;
    var fieldIncome = 0;
    for (final settlement in world.settlements) {
      if (settlement.ownerId != playerId) {
        continue;
      }
      final harvest = _settlementHarvest(settlement);
      final supplyAfterHarvest = (settlement.supplyStock + harvest)
          .clamp(0, 8)
          .toInt();
      final unrestAfterRecovery =
          (settlement.unrest - 1 - (settlement.garrisonedUnits > 0 ? 1 : 0))
              .clamp(0, 8)
              .toInt();
      final transfer = _settlementFoodTransfer(
        settlement: settlement,
        supplyStock: supplyAfterHarvest,
        unrest: unrestAfterRecovery,
        world: world,
      );
      settlementIncome += transfer;
    }
    for (final camp in world.camps) {
      if (camp.ownerId != playerId || !camp.activeAtRound(world.round)) {
        continue;
      }
      if (camp.isOutpost) {
        campIncome += 1;
      }
      switch (camp.posture) {
        case CampPosture.supply:
          if (camp.supplyStock > 0) {
            campIncome += 1;
          }
        case CampPosture.fortified:
          break;
        case CampPosture.raiding:
          final raidingPressure = world.settlements.any(
            (settlement) =>
                settlement.ownerId >= 0 &&
                settlement.ownerId != playerId &&
                _manhattanDistance(settlement.position, camp.position) <= 1,
          );
          if (raidingPressure) {
            campIncome += 1;
          }
      }
    }

    final sanitizedFoodTiles = _sanitizeFoodTileControlMap(
      world,
      source: _foodTileOwnerByPosition,
    );
    final sanitizedPillaged = _sanitizePillagedTileMap(
      world,
      source: _pillagedTileUntilRound,
    );
    for (final entry in sanitizedFoodTiles.entries) {
      if (entry.value != playerId) {
        continue;
      }
      if ((sanitizedPillaged[entry.key] ?? 0) >= world.round) {
        continue;
      }
      fieldIncome += 1;
    }

    final availableAfterIncome =
        reserve + settlementIncome + campIncome + fieldIncome;
    final consumed = availableAfterIncome >= upkeep
        ? upkeep
        : availableAfterIncome;
    final shortageStacks = upkeep - consumed;
    final projectedReserve = (availableAfterIncome - consumed)
        .clamp(0, 99)
        .toInt();
    return _FoodProjection(
      reserve: reserve,
      settlementIncome: settlementIncome,
      campIncome: campIncome,
      fieldIncome: fieldIncome,
      upkeep: upkeep,
      projectedReserve: projectedReserve,
      shortageStacks: shortageStacks,
    );
  }

  _MatchOverSummary _buildMatchOverSummary(
    WorldState world,
    int? winnerPlayerId,
  ) {
    final winnerLedger = winnerPlayerId == null
        ? const _PlayerBattleLedger()
        : (_battleLedgerByPlayer[winnerPlayerId] ??
              const _PlayerBattleLedger());
    final settlementsHeld = winnerPlayerId == null
        ? 0
        : world.settlements
              .where((settlement) => settlement.ownerId == winnerPlayerId)
              .length;
    final timeline = world.log.reversed.take(12).toList();
    final decisiveEvents = world.log.reversed
        .where((entry) => entry.startsWith('Decisive:'))
        .take(4)
        .toList();
    final decisiveLine = timeline.isEmpty ? 'Campaign ended.' : timeline.first;
    return _MatchOverSummary(
      winnerPlayerId: winnerPlayerId,
      rounds: world.round,
      seed: world.seed,
      preset: world.preset,
      decisiveLine: decisiveLine,
      settlementsHeld: settlementsHeld,
      captures: winnerLedger.captures,
      routPressureInflicted: winnerLedger.routPressureInflicted,
      battlesWon: winnerLedger.battlesWon,
      commandSkillsUsed: winnerLedger.commandSkillsUsed,
      commandersEliminated: winnerLedger.commandersEliminated,
      moraleCollapseVictories: winnerLedger.moraleCollapseVictories,
      decisiveEvents: decisiveEvents,
      timeline: timeline,
    );
  }

  void _startMatchOverSequence(int sequence) {
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _phase != _GamePhase.gameOver) {
        return;
      }
      if (sequence != _matchOverSequence) {
        return;
      }
      setState(() {
        _matchOverBannerVisible = true;
      });
    });

    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted || _phase != _GamePhase.gameOver) {
        return;
      }
      if (sequence != _matchOverSequence) {
        return;
      }
      unawaited(_showMatchOverSummaryDialog(sequence));
    });
  }

  Future<void> _showMatchOverSummaryDialog(int sequence) async {
    if (!mounted || _phase != _GamePhase.gameOver) {
      return;
    }
    if (_matchOverPopupShown) {
      return;
    }
    final summary = _matchOverSummary;
    if (summary == null) {
      return;
    }
    setState(() {
      _matchOverPopupShown = true;
    });

    var showTimeline = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text(
                summary.winnerPlayerId == null
                    ? 'Campaign Drawn'
                    : 'Player ${summary.winnerPlayerId! + 1} Triumphant',
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.decisiveLine),
                      const SizedBox(height: 10),
                      Text(
                        'Rounds ${summary.rounds} • ${_presetLabel(summary.preset)}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Captures ${summary.captures} • Rout Pressure ${summary.routPressureInflicted} • '
                        'Battles Won ${summary.battlesWon} • Settlements ${summary.settlementsHeld}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Command swings ${summary.commandSkillsUsed} • '
                        'Commanders eliminated ${summary.commandersEliminated} • '
                        'Morale break victories ${summary.moraleCollapseVictories}',
                      ),
                      if (summary.decisiveEvents.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Decisive Events',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        for (final event in summary.decisiveEvents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(event.replaceFirst('Decisive: ', '')),
                          ),
                      ],
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          setLocalState(() {
                            showTimeline = !showTimeline;
                          });
                        },
                        icon: Icon(
                          showTimeline
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        label: Text(
                          showTimeline ? 'Hide Timeline' : 'View Timeline',
                        ),
                      ),
                      if (showTimeline)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0x33485A63)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: summary.timeline.length,
                            itemBuilder: (context, index) {
                              final entry = summary.timeline[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(entry),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startMatch(forcedSeed: _seed);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Rematch'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startMatch();
                  },
                  icon: const Icon(Icons.casino_rounded),
                  label: const Text('New Campaign'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _backToSetup();
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Main Menu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || sequence != _matchOverSequence) {
      return;
    }
  }

  Future<void> _showFieldManualDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded),
              SizedBox(width: 8),
              Text('Field Manual'),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick reference for what each player action does and why it matters.',
                  ),
                  const SizedBox(height: 10),
                  for (
                    var sectionIndex = 0;
                    sectionIndex < _fieldManualSections.length;
                    sectionIndex++
                  ) ...[
                    _fieldManualSectionTile(
                      _fieldManualSections[sectionIndex],
                      initiallyExpanded: sectionIndex == 0,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _fieldManualSectionTile(
    _FieldManualSection section, {
    required bool initiallyExpanded,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(section.icon),
        title: Text(section.title),
        subtitle: Text(section.summary),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final point in section.points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('- $point'),
              ),
            ),
        ],
      ),
    );
  }

  void _onBattleTileTap(BoardPosition position) {
    if (_phase != _GamePhase.battle || _battle == null || _aiBusy) {
      return;
    }

    final battleState = _battle!.battleState;
    final activePlayer = battleState.activePlayer;
    if (_playerTypeById(activePlayer) == PlayerType.ai) {
      return;
    }

    if (_selectedBattlePieceId != null &&
        _battleLegalMoves.contains(position)) {
      _executeBattleMove(
        BattleAction(pieceId: _selectedBattlePieceId!, to: position),
      );
      return;
    }

    final tappedPiece = battleState.pieceAt(position);
    if (tappedPiece != null && tappedPiece.ownerId == activePlayer) {
      if (_selectedBattlePieceId == tappedPiece.id) {
        setState(() {
          _selectedBattlePieceId = null;
          _battleLegalMoves = const <BoardPosition>{};
          _status = 'Battle selection cleared.';
        });
        return;
      }
      final legalMoves = battleState.legalMovesForPiece(tappedPiece.id);
      setState(() {
        _selectedBattlePieceId = tappedPiece.id;
        _battleLegalMoves = legalMoves.toSet();
        _status =
            'Battle turn: Player ${activePlayer + 1} selected ${tappedPiece.type.name}.';
      });
      return;
    }

    setState(() {
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
    });
  }

  void _executeBattleMove(BattleAction action, {bool fromAi = false}) {
    final session = _battle;
    if (session == null) {
      return;
    }

    final movedState = session.battleState.movePiece(
      pieceId: action.pieceId,
      to: action.to,
    );

    if (identical(movedState, session.battleState)) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    setState(() {
      _battle = session.copyWith(battleState: movedState);
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = movedState.latestTurnOverlay();
      _status = fromAi
          ? 'AI played ${action.pieceId}.'
          : 'Move executed on battle board.';
    });
    _queueAutosave();
    _scheduleBattleOverlayClear(_battleTurnOverlay);

    _resolveBattleProgress();
  }

  void _useCharge() {
    final session = _battle;
    if (session == null || _phase != _GamePhase.battle) {
      return;
    }
    final nextState = session.battleState.useCharge();
    setState(() {
      _battle = session.copyWith(battleState: nextState);
      _status = 'P${session.battleState.activePlayer + 1} ordered a CHARGE!';
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
    });
    _triggerAiTurnIfNeeded();
  }

  void _useDefend() {
    final session = _battle;
    if (session == null || _phase != _GamePhase.battle) {
      return;
    }
    final nextState = session.battleState.useDefend();
    setState(() {
      _battle = session.copyWith(battleState: nextState);
      _status = 'P${session.battleState.activePlayer + 1} is DIGGING IN!';
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
    });
    _triggerAiTurnIfNeeded();
  }

  void _advanceFrontline({bool fromAi = false}) {
    final session = _battle;
    if (session == null) {
      return;
    }
    final before = session.battleState;
    final after = before.advanceFrontline();
    if (identical(before, after)) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    setState(() {
      _battle = session.copyWith(battleState: after);
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = after.latestTurnOverlay();
      _status = fromAi
          ? 'AI executed a contact advance.'
          : 'Contact advance executed.';
    });
    _queueAutosave();
    _scheduleBattleOverlayClear(_battleTurnOverlay);

    _resolveBattleProgress();
  }

  void _useGeneralAdvanceSkill({bool fromAi = false}) {
    final session = _battle;
    if (session == null) {
      return;
    }

    final before = session.battleState;
    final after = before.useGeneralAdvanceSkill();
    if (identical(before, after)) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    setState(() {
      _battle = session.copyWith(battleState: after);
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = after.latestTurnOverlay();
      _status = fromAi
          ? 'AI used a general command skill.'
          : 'General command skill activated.';
    });
    _queueAutosave();
    _scheduleBattleOverlayClear(_battleTurnOverlay);

    _resolveBattleProgress();
  }

  void _scheduleBattleOverlayClear(BattleTurnOverlay? overlay) {
    _battleOverlayTimer?.cancel();
    if (overlay == null) {
      return;
    }
    final baseMs = _reduceEffects ? 900 : 1200;
    final holdMs = (baseMs / (_animationSpeed <= 0 ? 1.0 : _animationSpeed))
        .round()
        .clamp(240, 2200);
    _battleOverlayTimer = Timer(Duration(milliseconds: holdMs), () {
      if (!mounted || _phase != _GamePhase.battle) {
        return;
      }
      if (_battleTurnOverlay?.turn != overlay.turn) {
        return;
      }
      setState(() {
        _battleTurnOverlay = null;
      });
    });
  }

  void _resolveBattleProgress() {
    final session = _battle;
    if (session == null) {
      return;
    }

    var winner = session.winnerPlayerId();
    if (winner == null &&
        !session.battleState.hasAnyLegalMove(
          session.battleState.activePlayer,
        )) {
      winner = session.battleState.otherPlayer;
    }

    if (winner != null) {
      final reason = _battleOutcomeReason(
        session: session,
        winnerPlayerId: winner,
      );
      _finishBattle(winner, reason);
      return;
    }

    if (session.battleState.moveLog.length >= _battleTurnLimit) {
      final forcedWinner = _forcedBattleWinnerForState(
        state: session.battleState,
        attackerPlayerId: session.attackerStack.ownerId,
        defenderPlayerId: session.defenderStack.ownerId,
      );
      _finishBattle(forcedWinner, 'battle reached turn limit');
      return;
    }

    setState(() {
      _status =
          'Battle turn: Player ${session.battleState.activePlayer + 1} to move.';
    });

    _triggerAiTurnIfNeeded();
  }

  int _forcedBattleWinnerForState({
    required BattleState state,
    required int attackerPlayerId,
    required int defenderPlayerId,
  }) {
    final attackerScore = _battleForceScore(state, attackerPlayerId);
    final defenderScore = _battleForceScore(state, defenderPlayerId);
    if (attackerScore > defenderScore) {
      return attackerPlayerId;
    }
    return defenderPlayerId;
  }

  double _battleForceScore(BattleState state, int playerId) {
    var score = state.moraleForPlayer(playerId) * 3.0;
    if (state.commanderAlive(playerId)) {
      score += 8.0;
    }
    for (final piece in state.piecesForPlayer(playerId)) {
      score += switch (piece.type) {
        PieceType.pawn => 1.0,
        PieceType.knight => 3.0,
        PieceType.bishop => 3.0,
        PieceType.rook => 5.0,
        PieceType.general => 8.0,
      };
    }
    return score;
  }

  ({BattleState finalState, int winnerPlayerId, String reason})
  _simulateAiBattleOutcome({
    required BattleState initialState,
    required int attackerPlayerId,
    required int defenderPlayerId,
  }) {
    var state = initialState;
    var stagnantTurns = 0;
    for (var guard = 0; guard < _battleTurnLimit; guard++) {
      final naturalWinner = _winnerForBattleState(
        state: state,
        attackerPlayerId: attackerPlayerId,
        defenderPlayerId: defenderPlayerId,
      );
      if (naturalWinner != null) {
        return (
          finalState: state,
          winnerPlayerId: naturalWinner,
          reason: 'auto-resolved by battle state',
        );
      }

      if (state.canUseGeneralAdvanceSkill()) {
        final afterSkill = state.useGeneralAdvanceSkill();
        if (identical(afterSkill, state)) {
          stagnantTurns++;
        } else {
          state = afterSkill;
          stagnantTurns = 0;
        }
      } else {
        final action = _battleAi.chooseMove(
          state,
          _seed + guard,
          difficulty: _aiDifficulty,
        );
        if (action == null) {
          return (
            finalState: state,
            winnerPlayerId: state.otherPlayer,
            reason: 'no legal battle moves',
          );
        }
        final moved = state.movePiece(pieceId: action.pieceId, to: action.to);
        if (identical(moved, state)) {
          final advanced = state.advanceFrontline();
          if (identical(advanced, state)) {
            stagnantTurns++;
          } else {
            state = advanced;
            stagnantTurns = 0;
          }
        } else {
          state = moved;
          stagnantTurns = 0;
        }
      }

      if (stagnantTurns >= 8) {
        final forced = _forcedBattleWinnerForState(
          state: state,
          attackerPlayerId: attackerPlayerId,
          defenderPlayerId: defenderPlayerId,
        );
        return (
          finalState: state,
          winnerPlayerId: forced,
          reason: 'stalemate auto-resolution',
        );
      }
    }

    final forced = _forcedBattleWinnerForState(
      state: state,
      attackerPlayerId: attackerPlayerId,
      defenderPlayerId: defenderPlayerId,
    );
    return (
      finalState: state,
      winnerPlayerId: forced,
      reason: 'turn-limit auto-resolution',
    );
  }

  int? _winnerForBattleState({
    required BattleState state,
    required int attackerPlayerId,
    required int defenderPlayerId,
  }) {
    final attackerAlive = state.commanderAlive(attackerPlayerId);
    final defenderAlive = state.commanderAlive(defenderPlayerId);
    final attackerMoraleBroken = state.moraleBroken(attackerPlayerId);
    final defenderMoraleBroken = state.moraleBroken(defenderPlayerId);

    if (attackerMoraleBroken && defenderMoraleBroken) {
      return _forcedBattleWinnerForState(
        state: state,
        attackerPlayerId: attackerPlayerId,
        defenderPlayerId: defenderPlayerId,
      );
    }
    if (attackerMoraleBroken) {
      return defenderPlayerId;
    }
    if (defenderMoraleBroken) {
      return attackerPlayerId;
    }
    if (!state.hasAnyLegalMove(state.activePlayer)) {
      return state.otherPlayer;
    }
    if (attackerAlive && defenderAlive) {
      return null;
    }
    return attackerAlive ? attackerPlayerId : defenderPlayerId;
  }

  String _battleOutcomeReason({
    required BattleSession session,
    required int winnerPlayerId,
  }) {
    final loserPlayerId = winnerPlayerId == session.attackerStack.ownerId
        ? session.defenderStack.ownerId
        : session.attackerStack.ownerId;
    final state = session.battleState;
    if (!state.commanderAlive(loserPlayerId)) {
      return 'enemy commander eliminated';
    }
    if (state.moraleBroken(loserPlayerId)) {
      return 'enemy morale collapsed';
    }
    if (!state.hasAnyLegalMove(loserPlayerId)) {
      return 'enemy line had no legal moves';
    }
    return 'battlefield control secured';
  }

  List<String> _battleDecisiveHighlights({
    required BattleSession session,
    required int winnerPlayerId,
    required int loserPlayerId,
    required int commandersEliminated,
    required bool loserMoraleCollapsed,
    required bool loserNoLegalMoves,
  }) {
    final lines = <String>[];
    if (commandersEliminated > 0) {
      lines.add(
        'Command break: $commandersEliminated enemy commander(s) eliminated.',
      );
    }
    if (loserMoraleCollapsed) {
      lines.add('Morale break: Player ${loserPlayerId + 1} collapsed.');
    }
    if (loserNoLegalMoves) {
      lines.add(
        'Positional lock: Player ${loserPlayerId + 1} had no legal moves.',
      );
    }

    final winnerCommandSwings = session.battleState.eventLog
        .where(
          (event) =>
              event.type == BattleEventType.generalSkill &&
              event.actorPlayerId == winnerPlayerId,
        )
        .length;
    if (winnerCommandSwings > 0) {
      lines.add('Winner command swings triggered: $winnerCommandSwings.');
    }
    final loserRoutEvents = session.battleState.eventLog
        .where(
          (event) =>
              event.type == BattleEventType.rout &&
              event.actorPlayerId == loserPlayerId &&
              (event.delta ?? 0) < 0,
        )
        .length;
    if (loserRoutEvents > 0) {
      lines.add(
        'Rout shocks inflicted on Player ${loserPlayerId + 1}: $loserRoutEvents.',
      );
    }
    if (lines.isEmpty) {
      lines.add('Battle was decided by sustained tactical pressure.');
    }
    return lines.take(3).toList(growable: false);
  }

  void _finishBattle(int winnerPlayerId, String reason) {
    final world = _world;
    final session = _battle;
    if (world == null || session == null) {
      return;
    }
    final loserPlayerId = winnerPlayerId == session.attackerStack.ownerId
        ? session.defenderStack.ownerId
        : session.attackerStack.ownerId;
    final loserMoraleCollapsed = session.battleState.moraleBroken(
      loserPlayerId,
    );
    final loserNoLegalMoves = !session.battleState.hasAnyLegalMove(
      loserPlayerId,
    );
    final loserInitialGenerals = loserPlayerId == session.attackerStack.ownerId
        ? session.attackerStack.army.composition.generals
        : session.defenderStack.army.composition.generals;
    final loserRemainingGenerals = session.battleState
        .piecesForPlayer(loserPlayerId)
        .where((piece) => piece.type == PieceType.general)
        .length;
    final commandersEliminated = (loserInitialGenerals - loserRemainingGenerals)
        .clamp(0, 8)
        .toInt();
    final decisiveHighlights = _battleDecisiveHighlights(
      session: session,
      winnerPlayerId: winnerPlayerId,
      loserPlayerId: loserPlayerId,
      commandersEliminated: commandersEliminated,
      loserMoraleCollapsed: loserMoraleCollapsed,
      loserNoLegalMoves: loserNoLegalMoves,
    );

    final survivorArmy = session.armyFromRemainingPieces(
      winnerPlayerId,
      winnerPlayerId == session.attackerStack.ownerId
          ? session.attackerStack.army.label
          : session.defenderStack.army.label,
    );

    final stacks = world.stacks
        .where(
          (stack) =>
              stack.id != session.attackerStack.id &&
              stack.id != session.defenderStack.id,
        )
        .toList();
    final updatedSupplyById = <String, int>{..._stackSupplyById};
    final updatedStarvationById = <String, int>{..._stackStarvationById};
    final updatedWaterById = <String, int>{..._stackWaterById};
    final updatedThirstById = <String, int>{..._stackThirstById};
    String winnerStackId;

    if (winnerPlayerId == session.attackerStack.ownerId) {
      winnerStackId = session.attackerStack.id;
      stacks.add(
        session.attackerStack.copyWith(
          army: survivorArmy,
          position: session.defenderStack.position,
        ),
      );
    } else {
      winnerStackId = session.defenderStack.id;
      stacks.add(
        session.defenderStack.copyWith(
          army: survivorArmy,
          position: session.defenderStack.position,
        ),
      );
    }

    final settlements = List<SettlementState>.from(world.settlements);
    var camps = List<CampState>.from(world.camps);
    final settlementAtBattle = world.settlementAt(
      session.defenderStack.position,
    );
    final campAtBattle = world.campAt(session.defenderStack.position);
    var battleSupplyGain = 0;
    var forcedLevyCount = 0;
    if (settlementAtBattle != null &&
        settlementAtBattle.ownerId != winnerPlayerId) {
      final capturePolicy = _playerTypeById(winnerPlayerId) == PlayerType.ai
          ? _capturePolicyForMove(
              world: world,
              stack: stacks.firstWhere((stack) => stack.id == winnerStackId),
              fromAi: true,
            )
          : _capturePolicyForPlayer(winnerPlayerId);
      final index = settlements.indexWhere(
        (s) => s.id == settlementAtBattle.id,
      );
      if (index >= 0) {
        final devastationGain = capturePolicy == _CapturePolicy.destroy ? 3 : 1;
        final unrestGain = capturePolicy == _CapturePolicy.destroy ? 4 : 2;
        battleSupplyGain += capturePolicy == _CapturePolicy.destroy ? 3 : 2;
        final winnerIndex = stacks.indexWhere(
          (stack) => stack.id == winnerStackId,
        );
        if (capturePolicy == _CapturePolicy.spare && winnerIndex >= 0) {
          final leviedArmy = _draftLevyIntoArmy(
            stacks[winnerIndex].army,
            levyCount: _levyCountFromSettlement(
              settlementAtBattle,
              forced: true,
            ),
          );
          if (leviedArmy != null) {
            forcedLevyCount =
                leviedArmy.units.length - stacks[winnerIndex].army.units.length;
            if (forcedLevyCount > 0) {
              stacks[winnerIndex] = stacks[winnerIndex].copyWith(
                army: leviedArmy,
              );
            }
          }
        }
        settlements[index] = settlementAtBattle.copyWith(
          ownerId: winnerPlayerId,
          unrest: (settlementAtBattle.unrest + unrestGain).clamp(0, 8),
          garrisonedUnits: 0,
          levyCooldown: capturePolicy == _CapturePolicy.destroy
              ? 4
              : _levyCooldownForSettlement(settlementAtBattle, forced: true),
          trapArmed: false,
          occupationAge: 0,
          devastation: (settlementAtBattle.devastation + devastationGain).clamp(
            0,
            8,
          ),
        );
      }
    }
    var campOverrunLine = '';
    if (campAtBattle != null && campAtBattle.ownerId != winnerPlayerId) {
      camps = camps.where((camp) => camp.id != campAtBattle.id).toList();
      battleSupplyGain += 1;
      campOverrunLine =
          'Enemy ${_campPostureLabel(campAtBattle.posture).toLowerCase()} camp was overrun (+1 army supply).';
    }
    if (battleSupplyGain > 0) {
      final supplyBefore = updatedSupplyById[winnerStackId] ?? 3;
      updatedSupplyById[winnerStackId] = (supplyBefore + battleSupplyGain)
          .clamp(0, 8)
          .toInt();
      updatedStarvationById[winnerStackId] = 0;
    }
    if (_hasReliableWaterSource(world, session.defenderStack.position)) {
      final waterBefore = updatedWaterById[winnerStackId] ?? 3;
      updatedWaterById[winnerStackId] = (waterBefore + 1).clamp(0, 6).toInt();
      updatedThirstById[winnerStackId] = 0;
    }

    final updatedWorld = world.copyWith(
      stacks: stacks,
      settlements: settlements,
      camps: camps,
      log: [
        ...world.log,
        'Battle resolved: Player ${winnerPlayerId + 1} won ($reason).',
        if (settlementAtBattle != null)
          '${settlementAtBattle.name} now answers to Player ${winnerPlayerId + 1}.',
        if (forcedLevyCount > 0)
          'Player ${winnerPlayerId + 1} imposed forced levy (+$forcedLevyCount infantry).',
        if (campOverrunLine.isNotEmpty) campOverrunLine,
        ...decisiveHighlights.map((line) => 'Decisive: $line'),
      ],
    );

    final activeId = updatedWorld.activePlayerId;
    final remainingCp = _commandPointsForPlayer(updatedWorld, activeId);
    final actingWasAi = _playerTypeById(activeId) == PlayerType.ai;
    final winnerLabel = 'Player ${winnerPlayerId + 1}';
    final statusLine =
        'Battle ended: $winnerLabel won ($reason). ($remainingCp command left)';
    final currentLedger = <int, _PlayerBattleLedger>{..._battleLedgerByPlayer};
    final captureEvents = session.battleState.eventLog.where(
      (event) =>
          event.type == BattleEventType.capture && event.actorPlayerId != null,
    );
    final routEvents = session.battleState.eventLog.where(
      (event) =>
          event.type == BattleEventType.rout &&
          (event.delta ?? 0) < 0 &&
          event.actorPlayerId != null,
    );
    for (final event in captureEvents) {
      final actor = event.actorPlayerId!;
      currentLedger[actor] =
          (currentLedger[actor] ?? const _PlayerBattleLedger()).copyWith(
            captures: (currentLedger[actor]?.captures ?? 0) + 1,
          );
    }
    for (final event in routEvents) {
      final routed = event.actorPlayerId!;
      final inflictor = routed == session.attackerStack.ownerId
          ? session.defenderStack.ownerId
          : session.attackerStack.ownerId;
      currentLedger[inflictor] =
          (currentLedger[inflictor] ?? const _PlayerBattleLedger()).copyWith(
            routPressureInflicted:
                (currentLedger[inflictor]?.routPressureInflicted ?? 0) + 1,
          );
    }
    final commandSkillEvents = session.battleState.eventLog.where(
      (event) =>
          event.type == BattleEventType.generalSkill &&
          event.actorPlayerId != null,
    );
    for (final event in commandSkillEvents) {
      final actor = event.actorPlayerId!;
      currentLedger[actor] =
          (currentLedger[actor] ?? const _PlayerBattleLedger()).copyWith(
            commandSkillsUsed:
                (currentLedger[actor]?.commandSkillsUsed ?? 0) + 1,
          );
    }
    currentLedger[winnerPlayerId] =
        (currentLedger[winnerPlayerId] ?? const _PlayerBattleLedger()).copyWith(
          battlesWon: (currentLedger[winnerPlayerId]?.battlesWon ?? 0) + 1,
          commandersEliminated:
              (currentLedger[winnerPlayerId]?.commandersEliminated ?? 0) +
              commandersEliminated,
          moraleCollapseVictories:
              (currentLedger[winnerPlayerId]?.moraleCollapseVictories ?? 0) +
              (loserMoraleCollapsed ? 1 : 0),
        );
    _battleOverlayTimer?.cancel();
    final reconciledLogistics = _reconcileStackLogistics(
      updatedWorld,
      supplySource: updatedSupplyById,
      starvationSource: updatedStarvationById,
      waterSource: updatedWaterById,
      thirstSource: updatedThirstById,
    );
    final capturePolicies = _reconcileCapturePolicies(updatedWorld);

    setState(() {
      _phase = _GamePhase.world;
      _world = updatedWorld;
      _stackSupplyById = reconciledLogistics.supplyById;
      _stackStarvationById = reconciledLogistics.starvationById;
      _stackWaterById = reconciledLogistics.waterById;
      _stackThirstById = reconciledLogistics.thirstById;
      _capturePolicyByPlayer = capturePolicies;
      _battle = null;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _forcedMarchMode = false;
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _battleTurnOverlay = null;
      _battleLedgerByPlayer = currentLedger;
      _status = statusLine;
    });
    _queueAutosave();

    if (remainingCp <= 0) {
      _advanceWorldTurn();
      return;
    }
    if (actingWasAi) {
      _triggerAiTurnIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = switch (_phase) {
      _GamePhase.setup => _buildSetupScreen(context),
      _GamePhase.world => _buildWorldScreen(context),
      _GamePhase.battle => _buildBattleScreen(context),
      _GamePhase.gameOver => _buildGameOverScreen(context),
    };

    return AnimatedSwitcher(
      duration: _reduceEffects ? Duration.zero : _scaledDelay(380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<_GamePhase>(_phase), child: screen),
    );
  }

  Widget _screenBackdrop({required Widget child}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6F0E5), Color(0xFFE8DFC8)],
        ),
      ),
      child: Stack(
        children: [
          if (!_reduceEffects)
            Positioned(
              top: -80,
              right: -40,
              child: _glowOrb(
                size: 260,
                colors: const [Color(0x44C4A25F), Color(0x00C4A25F)],
              ),
            ),
          if (!_reduceEffects)
            Positioned(
              bottom: -70,
              left: -30,
              child: _glowOrb(
                size: 220,
                colors: const [Color(0x333D7A63), Color(0x003D7A63)],
              ),
            ),
          child,
        ],
      ),
    );
  }

  Widget _glowOrb({required double size, required List<Color> colors}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }

  Widget _statusChip(String text) {
    return AnimatedSwitcher(
      duration: _reduceEffects
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey<String>(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F4FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF24536A), width: 2),
          boxShadow: _reduceEffects
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x3324536A),
                    blurRadius: 0,
                    offset: Offset(2, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              size: 18,
              color: Color(0xFF24536A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF1F2D36),
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Latest: ',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BattleFormation _recommendedFormationForBattle({
    required ArmyDefinition attacker,
    required ArmyDefinition defender,
  }) {
    final own = attacker.composition;
    final enemy = defender.composition;
    final ownFrontline = own.pawns;
    final ownLanes = own.rooks + own.bishops;
    final enemyFrontline = enemy.pawns;

    if (ownFrontline >= ownLanes + own.knights) {
      return BattleFormation.spearhead;
    }
    if (ownLanes >= ownFrontline || enemyFrontline >= ownFrontline + 2) {
      return BattleFormation.flankGuard;
    }
    return BattleFormation.balanced;
  }

  BattleSideDeploymentPlan _recommendedSidePlan(
    List<BattleSideDeploymentPlan> options,
    BattleFormation recommendedFormation,
  ) {
    for (final option in options) {
      if (option.formation == recommendedFormation) {
        return option;
      }
    }
    return options.first;
  }

  List<BattleSideDeploymentPlan> _curatedDoctrineOptions(
    List<BattleSideDeploymentPlan> options, {
    required BattleFormation recommendedFormation,
    int maxOptions = 3,
  }) {
    if (options.isEmpty) {
      return const <BattleSideDeploymentPlan>[];
    }
    final capped = maxOptions.clamp(1, 5);
    final scored = List<BattleSideDeploymentPlan>.from(options)
      ..sort(
        (a, b) => _doctrineOptionScore(b).compareTo(_doctrineOptionScore(a)),
      );

    final picks = <BattleSideDeploymentPlan>[];
    final pickedIds = <String>{};
    void pick(BattleSideDeploymentPlan option) {
      if (pickedIds.add(option.id)) {
        picks.add(option);
      }
    }

    BattleSideDeploymentPlan recommended = scored.first;
    for (final option in scored) {
      if (option.formation == recommendedFormation) {
        recommended = option;
        break;
      }
    }
    pick(recommended);

    final bestByFormation = <BattleFormation, BattleSideDeploymentPlan>{};
    for (final option in scored) {
      bestByFormation.putIfAbsent(option.formation, () => option);
    }
    final formationAlternates =
        bestByFormation.values
            .where((option) => option.id != recommended.id)
            .toList()
          ..sort(
            (a, b) =>
                _doctrineOptionScore(b).compareTo(_doctrineOptionScore(a)),
          );
    for (final option in formationAlternates) {
      if (picks.length >= capped) {
        break;
      }
      pick(option);
    }

    if (picks.length < capped) {
      for (final option in scored) {
        if (picks.length >= capped) {
          break;
        }
        pick(option);
      }
    }
    return picks;
  }

  double _doctrineOptionScore(BattleSideDeploymentPlan option) {
    if (option.pieces.isEmpty) {
      return -999;
    }
    final ownerId = option.pieces.first.ownerId;
    final generals = option.pieces
        .where(
          (piece) =>
              piece.type == PieceType.general && piece.ownerId == ownerId,
        )
        .toList();
    if (generals.isEmpty) {
      return -300;
    }

    final cols =
        option.pieces
            .map((piece) => piece.position.col)
            .fold<int>(0, (maxCol, col) => col > maxCol ? col : maxCol) +
        1;
    final leftCenter = (cols - 1) ~/ 2;
    final rightCenter = cols ~/ 2;
    double score = 0;

    for (final general in generals) {
      var adjacentSupport = 0;
      for (final piece in option.pieces) {
        if (piece.id == general.id ||
            piece.ownerId != ownerId ||
            piece.type == PieceType.general) {
          continue;
        }
        final rowDelta = (piece.position.row - general.position.row).abs();
        final colDelta = (piece.position.col - general.position.col).abs();
        final adjacent =
            rowDelta <= 1 && colDelta <= 1 && !(rowDelta == 0 && colDelta == 0);
        if (adjacent) {
          adjacentSupport++;
        }
      }
      score += adjacentSupport * 3.2;
      final centerFile =
          general.position.col == leftCenter ||
          general.position.col == rightCenter;
      if (centerFile) {
        score += adjacentSupport >= 2 ? 2.0 : -7.0;
      }
      if (adjacentSupport == 0) {
        score -= 12.0;
      }
    }

    if (option.formation == BattleFormation.balanced) {
      score += 0.45;
    }
    return score;
  }

  Future<bool> _showEngagementDecisionDialog({
    required ArmyStack ownStack,
    required ArmyStack enemyStack,
    required BoardPosition battlePosition,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Engagement!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An enemy host from Player ${enemyStack.ownerId + 1} (${enemyStack.id}) '
                'is moving to engage your stack ${ownStack.id} at (${battlePosition.row},${battlePosition.col}).',
              ),
              const SizedBox(height: 12),
              Text(
                'Your Strength: ${_armyTileSummary(ownStack.army)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Enemy Strength: ${_armyTileSummary(enemyStack.army)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Do you stand your ground and fight?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tactical Withdrawal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Engage'),
            ),
          ],
        );
      },
    );
    return res ?? true;
  }

  Future<BattleSideDeploymentPlan?> _selectSideDeploymentPlan({
    required ArmyStack ownStack,
    required ArmyStack enemyStack,
    required int attackerOwnerId,
    required BoardPosition battlePosition,
    required List<BattleSideDeploymentPlan> options,
    required BattleFormation recommendedFormation,
    required int rows,
    required int cols,
    required Set<BoardPosition> blockedCells,
    String? battleHint,
  }) async {
    final recommended = _recommendedSidePlan(options, recommendedFormation);

    return showDialog<BattleSideDeploymentPlan>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Choose Your Battle Doctrine'),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battle at ${battlePosition.row},${battlePosition.col} '
                      'against ${enemyStack.label}.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are positioning ${ownStack.id}. Enemy doctrine is hidden.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (battleHint != null) ...[
                      const SizedBox(height: 4),
                      Text(battleHint, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 10),
                    for (final option in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(option),
                            child: Ink(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: option.id == recommended.id
                                      ? const Color(0xFF2F6A55)
                                      : const Color(0x332F6A55),
                                ),
                                color: option.id == recommended.id
                                    ? const Color(0x1A2F6A55)
                                    : Colors.white.withValues(alpha: 0.45),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      if (option.id == recommended.id)
                                        const Chip(
                                          label: Text('Recommended'),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(option.summary),
                                  const SizedBox(height: 8),
                                  _formationPreview(
                                    option: option,
                                    attackerOwnerId: attackerOwnerId,
                                    rows: rows,
                                    cols: cols,
                                    blockedCells: blockedCells,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _formationPreview({
    required BattleSideDeploymentPlan option,
    required int attackerOwnerId,
    required int rows,
    required int cols,
    required Set<BoardPosition> blockedCells,
  }) {
    final optionOwnerId = option.pieces.isEmpty
        ? attackerOwnerId
        : option.pieces.first.ownerId;
    final averageRow = option.pieces.isEmpty
        ? (rows - 1) / 2
        : option.pieces
                  .map((piece) => piece.position.row)
                  .reduce((a, b) => a + b) /
              option.pieces.length;
    final currentlyBottom = averageRow > ((rows - 1) / 2);
    final shouldBeBottom = optionOwnerId == attackerOwnerId;
    final flipBoard = currentlyBottom != shouldBeBottom;

    BoardPosition project(BoardPosition source) {
      if (!flipBoard) {
        return source;
      }
      return BoardPosition(rows - 1 - source.row, cols - 1 - source.col);
    }

    final pieceByPosition = <BoardPosition, BattlePiece>{
      for (final piece in option.pieces) project(piece.position): piece,
    };
    final projectedBlocked = <BoardPosition>{
      for (final blocked in blockedCells) project(blocked),
    };
    final markerSize = (20.0 - (rows * 0.7)).clamp(14.0, 18.0).toDouble();
    final markerGlyphSize = (markerSize * 0.58).clamp(8.0, 11.0).toDouble();
    final blockedIconSize = (markerSize * 0.68).clamp(10.0, 13.0).toDouble();

    return SizedBox(
      height: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x554D654D)),
          color: Colors.white.withValues(alpha: 0.58),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AspectRatio(
            aspectRatio: cols / rows,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GridView.builder(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: rows * cols,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                ),
                itemBuilder: (context, index) {
                  final row = index ~/ cols;
                  final col = index % cols;
                  final position = BoardPosition(row, col);
                  final piece = pieceByPosition[position];
                  final isBlocked = projectedBlocked.contains(position);
                  final baseColor = (row + col).isEven
                      ? const Color(0xFFEDE2CA)
                      : const Color(0xDDDDC8A2);

                  if (isBlocked) {
                    return Container(
                      margin: const EdgeInsets.all(0.5),
                      color: const Color(0xFF5E6870),
                      child: Icon(
                        Icons.block_rounded,
                        size: blockedIconSize,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    );
                  }

                  if (piece == null) {
                    return Container(
                      margin: const EdgeInsets.all(0.5),
                      color: baseColor,
                    );
                  }

                  final ownerColor = playerColor(piece.ownerId);
                  final markerAsset = _formationPieceAsset(piece.type);
                  return Container(
                    margin: const EdgeInsets.all(0.5),
                    color: baseColor,
                    child: Center(
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          color: ownerColor.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(markerSize / 2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                          boxShadow: _reduceEffects
                              ? const []
                              : [
                                  BoxShadow(
                                    color: ownerColor.withValues(alpha: 0.46),
                                    blurRadius: 7,
                                    spreadRadius: 0.8,
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: markerSize * 0.06,
                              top: markerSize * 0.06,
                              child: SvgPicture.asset(
                                markerAsset,
                                width: markerGlyphSize,
                                height: markerGlyphSize,
                                colorFilter: const ColorFilter.mode(
                                  Color(0x5A000000),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            SvgPicture.asset(
                              markerAsset,
                              width: markerGlyphSize,
                              height: markerGlyphSize,
                              colorFilter: ColorFilter.mode(
                                playerOnColor(piece.ownerId),
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formationPieceAsset(PieceType type) {
    return switch (type) {
      PieceType.pawn => 'assets/pieces/pawn.svg',
      PieceType.rook => 'assets/pieces/rook.svg',
      PieceType.knight => 'assets/pieces/knight.svg',
      PieceType.bishop => 'assets/pieces/bishop.svg',
      PieceType.general => 'assets/pieces/king.svg',
    };
  }

  Widget _buildSetupScreen(BuildContext context) {
    final theme = Theme.of(context);
    final mode = widget.gameMode;
    final modeMapOptions = [
      for (var size = mode.minMapSize; size <= mode.maxMapSize; size++) size,
    ];
    final maxArmiesForCurrentSize = _maxArmiesForMapSize(_mapSize);
    final armyCountOptions = [
      for (var count = 2; count <= maxArmiesForCurrentSize; count++) count,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('ChessWarss - ${mode.label} Setup'),
        actions: [
          IconButton(
            tooltip: 'Session',
            onPressed: _showSessionMenu,
            icon: const Icon(Icons.shield_rounded),
          ),
          IconButton(
            tooltip: 'War Lab',
            onPressed: _showWarLabSheet,
            icon: const Icon(Icons.bug_report_rounded),
          ),
          IconButton(
            tooltip: 'Field Manual',
            onPressed: _showFieldManualDialog,
            icon: const Icon(Icons.menu_book_rounded),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: FilledButton.icon(
            onPressed: _startMatch,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Start ${mode.label}'),
          ),
        ),
      ),
      body: _screenBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mode.playerControlEditable)
                          DropdownButtonFormField<int>(
                            initialValue: _playerCount,
                            decoration: const InputDecoration(
                              labelText: 'Players',
                            ),
                            items: [
                              for (
                                var count = mode.minPlayerCount;
                                count <= mode.maxPlayerCount;
                                count++
                              )
                                DropdownMenuItem(
                                  value: count,
                                  child: Text('$count'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _playerCount = value;
                                if (_mapSize == 3 && value > 2) {
                                  _mapSize = 4;
                                  _mapSizeManuallySet = true;
                                }
                                if (!_mapSizeManuallySet) {
                                  _mapSize = _defaultMapSizeForPlayers(value);
                                }
                              });
                            },
                          )
                        else
                          const InputDecorator(
                            decoration: InputDecoration(labelText: 'Players'),
                            child: Text('2 (Solo: Human vs AI)'),
                          ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _mapSize,
                          decoration: const InputDecoration(
                            labelText: 'World Size',
                          ),
                          items: modeMapOptions
                              .map(
                                (size) => DropdownMenuItem(
                                  value: size,
                                  child: Text('${size}x$size'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _mapSize = value;
                              if (_mapSize == 3 && _playerCount > 2) {
                                _playerCount = 2;
                              }
                              final maxForSize = _maxArmiesForMapSize(value);
                              if (_armiesPerPlayer > maxForSize) {
                                _armiesPerPlayer = maxForSize;
                              }
                              _mapSizeManuallySet = true;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _armiesPerPlayer,
                          decoration: const InputDecoration(
                            labelText: 'Armies Per Player',
                          ),
                          items: armyCountOptions
                              .map(
                                (count) => DropdownMenuItem(
                                  value: count,
                                  child: Text(
                                    count == 4 ? '4 (4v4 in 1v1)' : '$count',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _armiesPerPlayer = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<MapPreset>(
                          initialValue: _mapPreset,
                          decoration: const InputDecoration(
                            labelText: 'Map Preset',
                          ),
                          items: MapPreset.values
                              .map(
                                (preset) => DropdownMenuItem(
                                  value: preset,
                                  child: Text(_presetLabel(preset)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _mapPreset = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Map Lab',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () {
                                _cycleMapPreset(-1);
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('Prev Preset'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                _cycleMapPreset(1);
                              },
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('Next Preset'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _showWarLabSheet,
                              icon: const Icon(Icons.bug_report_rounded),
                              label: const Text('War Lab'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _presetSummary(_mapPreset),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5E503E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<AiDifficulty>(
                          initialValue: _aiDifficulty,
                          decoration: const InputDecoration(
                            labelText: 'AI Difficulty',
                          ),
                          items: AiDifficulty.values
                              .map(
                                (difficulty) => DropdownMenuItem(
                                  value: difficulty,
                                  child: Text(difficulty.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _aiDifficulty = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Player Control',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (mode.playerControlEditable)
                          for (var i = 0; i < _playerCount; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DropdownButtonFormField<PlayerType>(
                                initialValue: _playerTypes[i],
                                decoration: InputDecoration(
                                  labelText: 'Player ${i + 1}',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: PlayerType.human,
                                    child: Text('Human'),
                                  ),
                                  DropdownMenuItem(
                                    value: PlayerType.ai,
                                    child: Text('AI'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _playerTypes[i] = value;
                                  });
                                },
                              ),
                            )
                        else
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'Eterna is solo-first right now: Player 1 is Human, Player 2 is AI.',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorldScreen(BuildContext context) {
    final world = _world!;
    final activePlayer = world.players[world.activePlayerIndex];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _confirmReturnToMenuOnBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('ChessWarss - ${widget.gameMode.label} Campaign'),
          actions: [
            IconButton(
              tooltip: 'Session',
              onPressed: _showSessionMenu,
              icon: const Icon(Icons.shield_rounded),
            ),
            IconButton(
              tooltip: 'Operations',
              onPressed: _showWarLabSheet,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: 'Field Manual',
              onPressed: _showFieldManualDialog,
              icon: const Icon(Icons.menu_book_rounded),
            ),
          ],
        ),
        body: _screenBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useWideLayout =
                      constraints.maxWidth >= 1080 &&
                      constraints.maxHeight >= 720;
                  final boardPanelHeight = math.min(
                    constraints.maxHeight * 0.64,
                    constraints.maxWidth + 24,
                  );
                  if (useWideLayout) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildWorldBoard(world)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: math.min(388, constraints.maxWidth * 0.34),
                          child: _buildWorldSidebar(world, activePlayer),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: boardPanelHeight,
                        child: _buildWorldBoard(world),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildWorldSidebar(world, activePlayer)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Iterable<BoardPosition> _campaignNeighbors(
    WorldState world,
    BoardPosition origin,
  ) sync* {
    for (final delta in const [
      BoardPosition(-1, 0),
      BoardPosition(1, 0),
      BoardPosition(0, -1),
      BoardPosition(0, 1),
    ]) {
      final next = origin.offset(delta.row, delta.col);
      if (!world.isInside(next)) {
        continue;
      }
      if (!world.isPassable(next)) {
        continue;
      }
      if (!world.canTraverseBetween(origin, next)) {
        continue;
      }
      yield next;
    }
  }

  bool _isEnemyOccupiedTile(
    WorldState world,
    BoardPosition position,
    int playerId,
  ) {
    final stack = world.stackAt(position);
    if (stack != null && stack.ownerId != playerId) {
      return true;
    }
    final settlement = world.settlementAt(position);
    if (settlement != null &&
        settlement.ownerId >= 0 &&
        settlement.ownerId != playerId) {
      return true;
    }
    final camp = world.campAt(position);
    return camp != null &&
        camp.activeAtRound(world.round) &&
        camp.ownerId != playerId;
  }

  bool _isInterdictedTile(
    WorldState world,
    BoardPosition position,
    int playerId,
  ) {
    if (_enemyPressureAt(world, position, playerId) > 0) {
      return true;
    }
    final settlement = world.settlementAt(position);
    if (settlement != null &&
        settlement.ownerId >= 0 &&
        settlement.ownerId != playerId) {
      return true;
    }
    final camp = world.campAt(position);
    return camp != null &&
        camp.activeAtRound(world.round) &&
        camp.ownerId != playerId;
  }

  List<_SupplyAnchor> _supplyAnchorsForPlayer(WorldState world, int playerId) {
    final anchors = <_SupplyAnchor>[];

    for (final settlement in world.settlements) {
      if (settlement.ownerId != playerId) {
        continue;
      }
      final type = settlement.id.startsWith('capital_')
          ? _SupplyAnchorType.capital
          : _SupplyAnchorType.settlement;
      anchors.add(
        _SupplyAnchor(
          position: settlement.position,
          type: type,
          label: settlement.name,
        ),
      );
    }

    for (final camp in world.camps) {
      if (!camp.activeAtRound(world.round) || camp.ownerId != playerId) {
        continue;
      }
      anchors.add(
        _SupplyAnchor(
          position: camp.position,
          type: camp.isOutpost
              ? _SupplyAnchorType.outpost
              : _SupplyAnchorType.camp,
          label: camp.isOutpost ? 'Forward Outpost' : 'Field Camp',
        ),
      );
    }

    anchors.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) {
        return typeCompare;
      }
      final rowCompare = a.position.row.compareTo(b.position.row);
      if (rowCompare != 0) {
        return rowCompare;
      }
      return a.position.col.compareTo(b.position.col);
    });
    return anchors;
  }

  _SupplyLineReport _supplyLineReport(WorldState world, ArmyStack stack) {
    final anchors = _supplyAnchorsForPlayer(world, stack.ownerId);
    if (anchors.isEmpty) {
      return const _SupplyLineReport(
        state: _SupplyLineState.isolated,
        path: <BoardPosition>[],
        distance: 99,
        dangerSteps: 0,
        anchor: null,
      );
    }

    for (final anchor in anchors) {
      if (anchor.position == stack.position) {
        return _SupplyLineReport(
          state: _SupplyLineState.secure,
          path: <BoardPosition>[stack.position],
          distance: 0,
          dangerSteps: 0,
          anchor: anchor,
        );
      }
    }

    final anchorByPosition = <BoardPosition, _SupplyAnchor>{
      for (final anchor in anchors) anchor.position: anchor,
    };
    final frontier = <BoardPosition>[stack.position];
    final previous = <BoardPosition, BoardPosition?>{stack.position: null};
    BoardPosition? foundAnchorPosition;

    while (frontier.isNotEmpty && foundAnchorPosition == null) {
      final current = frontier.removeAt(0);
      for (final next in _campaignNeighbors(world, current)) {
        if (previous.containsKey(next)) {
          continue;
        }
        if (_isEnemyOccupiedTile(world, next, stack.ownerId)) {
          continue;
        }
        previous[next] = current;
        frontier.add(next);
        if (anchorByPosition.containsKey(next)) {
          foundAnchorPosition = next;
          break;
        }
      }
    }

    if (foundAnchorPosition == null) {
      return const _SupplyLineReport(
        state: _SupplyLineState.isolated,
        path: <BoardPosition>[],
        distance: 99,
        dangerSteps: 0,
        anchor: null,
      );
    }

    final path = <BoardPosition>[];
    BoardPosition? cursor = foundAnchorPosition;
    while (cursor != null) {
      path.add(cursor);
      cursor = previous[cursor];
    }
    final line = path.reversed.toList(growable: false);
    final dangerSteps = line
        .skip(1)
        .where((position) => _isInterdictedTile(world, position, stack.ownerId))
        .length;
    final distance = line.length - 1;
    final state = distance <= 3 && dangerSteps == 0
        ? _SupplyLineState.secure
        : (distance <= 6 && dangerSteps <= 2
              ? _SupplyLineState.stretched
              : _SupplyLineState.isolated);
    return _SupplyLineReport(
      state: state,
      path: line,
      distance: distance,
      dangerSteps: dangerSteps,
      anchor: anchorByPosition[foundAnchorPosition],
    );
  }

  Map<int, Map<BoardPosition, int>> _territoryDepthByPlayer(WorldState world) {
    final result = <int, Map<BoardPosition, int>>{};

    for (final player in world.players) {
      final anchors = _supplyAnchorsForPlayer(world, player.id);
      if (anchors.isEmpty) {
        result[player.id] = const <BoardPosition, int>{};
        continue;
      }

      final depths = <BoardPosition, int>{};
      final frontier = <BoardPosition>[];
      for (final anchor in anchors) {
        depths[anchor.position] = 0;
        frontier.add(anchor.position);
      }

      while (frontier.isNotEmpty) {
        final current = frontier.removeAt(0);
        final depth = depths[current] ?? 0;
        if (depth >= 6) {
          continue;
        }
        for (final next in _campaignNeighbors(world, current)) {
          if (_isEnemyOccupiedTile(world, next, player.id)) {
            continue;
          }
          final nextDepth = depth + 1;
          final existing = depths[next];
          if (existing != null && existing <= nextDepth) {
            continue;
          }
          depths[next] = nextDepth;
          frontier.add(next);
        }
      }

      result[player.id] = depths;
    }

    return result;
  }

  Map<BoardPosition, _TerritoryTileStatus> _territoryStatusMap(
    WorldState world,
  ) {
    final depthsByPlayer = _territoryDepthByPlayer(world);
    final statusByPosition = <BoardPosition, _TerritoryTileStatus>{};

    for (final tile in world.tiles) {
      if (tile.terrain != TerrainType.passable) {
        continue;
      }

      int? ownerId;
      var bestDepth = 999;
      var contested = false;

      for (final player in world.players) {
        final depth = depthsByPlayer[player.id]?[tile.position];
        if (depth == null || depth > 6) {
          continue;
        }
        if (depth < bestDepth) {
          ownerId = player.id;
          bestDepth = depth;
          contested = false;
        } else if (depth == bestDepth) {
          contested = true;
        }
      }

      statusByPosition[tile.position] = _TerritoryTileStatus(
        ownerId: ownerId,
        depth: bestDepth == 999 ? 99 : bestDepth,
        contested: contested,
        frontline: false,
      );
    }

    final resolved = <BoardPosition, _TerritoryTileStatus>{};
    for (final entry in statusByPosition.entries) {
      final position = entry.key;
      final status = entry.value;
      var frontline = status.contested;

      for (final neighbor in _campaignNeighbors(world, position)) {
        final neighborStatus = statusByPosition[neighbor];
        if (neighborStatus == null) {
          continue;
        }
        if (status.ownerId != null &&
            neighborStatus.ownerId != null &&
            status.ownerId != neighborStatus.ownerId) {
          frontline = true;
          break;
        }
      }

      if (!frontline &&
          status.ownerId != null &&
          _enemyPressureAt(world, position, status.ownerId!) > 0) {
        frontline = true;
      }

      resolved[position] = _TerritoryTileStatus(
        ownerId: status.ownerId,
        depth: status.depth,
        contested: status.contested,
        frontline: frontline,
      );
    }

    return resolved;
  }

  List<String> _provinceNamesForPreset(MapPreset preset) {
    return switch (preset) {
      MapPreset.greatField => const <String>[
        'Aedui March',
        'Sequani Plain',
        'Arduenna Woods',
        'Central Gaul',
        'Belgae Frontier',
        'Southern Granaries',
      ],
      MapPreset.tightRavine => const <String>[
        'Upper Defile',
        'Stone Gate',
        'West Ridge',
        'Ravine Heart',
        'Eastern Gorge',
        'Low Basin',
      ],
      MapPreset.brokenGround => const <String>[
        'North Scrub',
        'Shattered Fields',
        'West Rise',
        'Broken Uplands',
        'East Verge',
        'South Hollow',
      ],
      MapPreset.riverlands => const <String>[
        'Upper Ford',
        'Middle Channel',
        'West Bank',
        'Island Reach',
        'East Bank',
        'Lower Delta',
      ],
      MapPreset.mountainPass => const <String>[
        'High Spur',
        'Eagle Gate',
        'West Shelf',
        'Pass Heart',
        'East Shelf',
        'Low Vale',
      ],
      MapPreset.coastalCliffs => const <String>[
        'Cliff March',
        'Salt Road',
        'West Moor',
        'Harbor Plain',
        'East Headland',
        'Southern Coast',
      ],
      MapPreset.ancientRuins => const <String>[
        'Old Walls',
        'Temple Reach',
        'West Dust',
        'Forum Basin',
        'East Relics',
        'Southern Necropolis',
      ],
      MapPreset.desertOasis => const <String>[
        'Dune Rim',
        'Palm Route',
        'West Wadi',
        'Oasis Heart',
        'East Caravan',
        'Southern Wells',
      ],
    };
  }

  int _provinceZoneId(WorldState world, BoardPosition position) {
    if (world.size <= 1) {
      return 3;
    }
    final x = position.col / (world.size - 1);
    final y = position.row / (world.size - 1);

    if (y < 0.28) {
      return x < 0.46 ? 0 : 1;
    }
    if (x < 0.28) {
      return 2;
    }
    if (x > 0.72 && y < 0.72) {
      return 4;
    }
    if (y > 0.72) {
      return 5;
    }
    return 3;
  }

  _ProvinceMapSummary _provinceMapSummary(
    WorldState world,
    Map<BoardPosition, _TerritoryTileStatus> territoryByPosition,
  ) {
    final provinceNames = _provinceNamesForPreset(world.preset);
    final tilesByZone = <int, List<BoardPosition>>{};
    for (final tile in world.tiles) {
      final zoneId = _provinceZoneId(world, tile.position);
      tilesByZone
          .putIfAbsent(zoneId, () => <BoardPosition>[])
          .add(tile.position);
    }

    final provinces = <_ProvinceInfo>[];
    final provinceByPosition = <BoardPosition, _ProvinceInfo>{};
    final sortedZones = tilesByZone.keys.toList()..sort();

    for (final zoneId in sortedZones) {
      final tiles = tilesByZone[zoneId];
      if (tiles == null || tiles.isEmpty) {
        continue;
      }
      final tileSet = tiles.toSet();
      final settlements = world.settlements
          .where((settlement) => tileSet.contains(settlement.position))
          .toList(growable: false);
      final ownerWeights = <int, int>{};
      var contested = false;
      var frontline = false;
      var grainValue = 0;

      for (final position in tiles) {
        final tile = world.tileAt(position);
        if (tile.terrain == TerrainType.passable) {
          grainValue++;
        }
        final territory = territoryByPosition[position];
        if (territory == null) {
          continue;
        }
        contested = contested || territory.contested;
        frontline = frontline || territory.frontline;
        final ownerId = territory.ownerId;
        if (ownerId != null && tile.terrain == TerrainType.passable) {
          ownerWeights[ownerId] = (ownerWeights[ownerId] ?? 0) + 1;
        }
      }

      for (final settlement in settlements) {
        if (settlement.ownerId >= 0) {
          ownerWeights[settlement.ownerId] =
              (ownerWeights[settlement.ownerId] ?? 0) + 2;
        }
      }

      int? ownerId;
      var bestWeight = 0;
      var tied = false;
      for (final entry in ownerWeights.entries) {
        if (entry.value > bestWeight) {
          ownerId = entry.key;
          bestWeight = entry.value;
          tied = false;
        } else if (entry.value == bestWeight && entry.value > 0) {
          tied = true;
        }
      }
      if (tied) {
        ownerId = null;
      }

      final wealthValue = settlements.fold<int>(
        0,
        (sum, settlement) =>
            sum + settlement.taxYield + (settlement.cultureRating ~/ 2),
      );
      final crossings = world.riverEdges
          .where(
            (edge) =>
                edge.type != RiverEdgeType.river &&
                (tileSet.contains(edge.a) || tileSet.contains(edge.b)),
          )
          .length;
      final averageRow =
          tiles.fold<double>(0, (sum, position) => sum + position.row) /
          tiles.length;
      final averageCol =
          tiles.fold<double>(0, (sum, position) => sum + position.col) /
          tiles.length;

      final province = _ProvinceInfo(
        id: 'province_$zoneId',
        name: provinceNames[zoneId % provinceNames.length],
        tiles: List<BoardPosition>.unmodifiable(tiles),
        gridAnchor: Offset(averageCol + 0.5, averageRow + 0.5),
        ownerId: ownerId,
        contested: contested || tied,
        frontline: frontline,
        grainValue: grainValue,
        wealthValue: wealthValue,
        crossings: crossings,
        settlementCount: settlements.length,
      );
      provinces.add(province);
      for (final position in tiles) {
        provinceByPosition[position] = province;
      }
    }

    return _ProvinceMapSummary(
      provinces: List<_ProvinceInfo>.unmodifiable(provinces),
      provinceByPosition: provinceByPosition,
    );
  }

  String _provinceControlSummary(_ProvinceInfo province) {
    final ownerText = province.ownerId == null
        ? 'Contested'
        : 'Player ${province.ownerId! + 1}';
    return '$ownerText • Grain ${province.grainValue} • Treasure ${province.wealthValue}';
  }

  String _provincePressureSummary(_ProvinceInfo province) {
    if (province.frontline && province.contested) {
      return 'Province contested under active pressure.';
    }
    if (province.frontline) {
      return 'Frontier province under pressure.';
    }
    if (province.contested) {
      return 'Province disputed by rival supply reach.';
    }
    return 'Interior province with stable command access.';
  }

  Widget _buildWorldBoard(WorldState world) {
    final activePlayer = world.players[world.activePlayerIndex];
    final stackByPosition = <BoardPosition, ArmyStack>{
      for (final stack in world.stacks) stack.position: stack,
    };
    final settlementByPosition = <BoardPosition, SettlementState>{
      for (final settlement in world.settlements)
        settlement.position: settlement,
    };
    final campByPosition = <BoardPosition, CampState>{
      for (final camp in world.camps)
        if (camp.activeAtRound(world.round)) camp.position: camp,
    };
    final selectedStackId = _selectedStackId;
    final selectedStack = selectedStackId == null
        ? null
        : world.stackById(selectedStackId);
    final selectedSettlement = _selectedSettlementById(world);
    final selectedSettlementPosition = selectedSettlement?.position;
    final territoryByPosition = _territoryStatusMap(world);
    final provinceSummary = _provinceMapSummary(world, territoryByPosition);
    final provinceByPosition = provinceSummary.provinceByPosition;
    final supplyReportByStackId = <String, _SupplyLineReport>{
      for (final stack in world.stacks)
        stack.id: _supplyLineReport(world, stack),
    };
    final selectedSupplyReport = selectedStack == null
        ? null
        : supplyReportByStackId[selectedStack.id];
    final focusedProvince =
        provinceByPosition[selectedStack?.position ??
            selectedSettlementPosition];
    final displayedProvince =
        focusedProvince ??
        provinceSummary.provinces.firstWhere(
          (province) => province.frontline || province.contested,
          orElse: () => provinceSummary.provinces.isEmpty
              ? const _ProvinceInfo(
                  id: 'province_none',
                  name: 'No Province',
                  tiles: <BoardPosition>[],
                  gridAnchor: Offset.zero,
                  ownerId: null,
                  contested: false,
                  frontline: false,
                  grainValue: 0,
                  wealthValue: 0,
                  crossings: 0,
                  settlementCount: 0,
                )
              : provinceSummary.provinces.first,
        );
    final activeColor = playerColor(activePlayer.id);
    final activeTextColor = _contrastColor(activeColor);
    final activeOutposts = world.camps.where(
      (camp) =>
          camp.activeAtRound(world.round) &&
          camp.ownerId == world.activePlayerId &&
          camp.isOutpost,
    );
    final lastEnemyMove = _lastEnemyWorldMove;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: activeColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.8),
                      ),
                      boxShadow: _reduceEffects
                          ? const <BoxShadow>[]
                          : [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.26),
                                blurRadius: 9,
                                spreadRadius: 0.4,
                              ),
                            ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            size: 16,
                            color: activeColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'War Map • ${activePlayer.name} (Player ${activePlayer.id + 1})',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: activeTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  triggerMode: TooltipTriggerMode.longPress,
                  waitDuration: const Duration(milliseconds: 350),
                  message: _worldBoardInfoText(
                    world: world,
                    activePlayer: activePlayer,
                    campCount: campByPosition.length,
                    outpostCount: activeOutposts.length,
                    lastEnemyMove: lastEnemyMove,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withValues(alpha: 0.22),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.86),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: activeTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (displayedProvince.tiles.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _worldBoardHeaderChip(
                    icon: Icons.map_rounded,
                    label: displayedProvince.name,
                  ),
                  _worldBoardHeaderChip(
                    icon: Icons.grass_rounded,
                    label: 'Grain ${displayedProvince.grainValue}',
                  ),
                  _worldBoardHeaderChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Treasure ${displayedProvince.wealthValue}',
                  ),
                  _worldBoardHeaderChip(
                    icon: Icons.water_rounded,
                    label: 'Crossings ${displayedProvince.crossings}',
                  ),
                  if (displayedProvince.frontline ||
                      displayedProvince.contested)
                    _worldBoardHeaderChip(
                      icon: Icons.gpp_bad_rounded,
                      label: 'Frontier',
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8A7652),
                      width: 1.3,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE8DAB8), Color(0xFFD8C29A)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableSize = Size(
                            math.max(1.0, constraints.maxWidth),
                            math.max(1.0, constraints.maxHeight),
                          );
                          final hexMetrics = _WorldHexMetrics.fit(
                            availableSize: availableSize,
                            gridSize: world.size,
                          );
                          final tileWidgets = <Widget>[];

                          for (
                            var index = 0;
                            index < world.size * world.size;
                            index++
                          ) {
                            final row = index ~/ world.size;
                            final col = index % world.size;
                            final position = BoardPosition(row, col);
                            final tile = world.tiles[index];
                            final stack = stackByPosition[position];
                            final settlement = settlementByPosition[position];
                            final camp = campByPosition[position];
                            final territoryStatus =
                                territoryByPosition[position];
                            final stackSupplyReport = stack == null
                                ? null
                                : supplyReportByStackId[stack.id];
                            final onSelectedSupplyLine =
                                selectedSupplyReport?.path.contains(position) ??
                                false;
                            final northRiver = row == 0
                                ? null
                                : world
                                      .riverEdgeBetween(
                                        position,
                                        position.offset(-1, 0),
                                      )
                                      ?.type;
                            final southRiver = row == world.size - 1
                                ? null
                                : world
                                      .riverEdgeBetween(
                                        position,
                                        position.offset(1, 0),
                                      )
                                      ?.type;
                            final westRiver = col == 0
                                ? null
                                : world
                                      .riverEdgeBetween(
                                        position,
                                        position.offset(0, -1),
                                      )
                                      ?.type;
                            final eastRiver = col == world.size - 1
                                ? null
                                : world
                                      .riverEdgeBetween(
                                        position,
                                        position.offset(0, 1),
                                      )
                                      ?.type;

                            final isBlocked =
                                tile.terrain == TerrainType.blocked;
                            final isSelected =
                                stack != null && stack.id == selectedStackId;
                            final isSelectedSettlement =
                                selectedSettlementPosition == position &&
                                (selectedStackId == null || !isSelected);
                            final isActiveStack =
                                stack != null &&
                                stack.ownerId == world.activePlayerId;
                            final isLegalMove = _worldLegalMoves.contains(
                              position,
                            );
                            final isLegalAttack =
                                isLegalMove &&
                                selectedStack != null &&
                                stack != null &&
                                stack.ownerId != selectedStack.ownerId;
                            final foodTileOwner =
                                _foodTileOwnerByPosition[position];
                            final tilePillaged =
                                (_pillagedTileUntilRound[position] ?? 0) >=
                                world.round;
                            final color = _worldTileColor(
                              row: row,
                              col: col,
                              isBlocked: isBlocked,
                              isSelected: isSelected || isSelectedSettlement,
                              isLegalMove: isLegalMove,
                              territoryStatus: territoryStatus,
                              activePlayerId: world.activePlayerId,
                              onSelectedSupplyLine: onSelectedSupplyLine,
                            );
                            final occupiedColor = stack == null
                                ? color
                                : Color.alphaBlend(
                                    playerColor(stack.ownerId).withValues(
                                      alpha: isSelected
                                          ? 0.42
                                          : (isActiveStack ? 0.34 : 0.24),
                                    ),
                                    color,
                                  );
                            final settlementUnderSiege =
                                settlement != null &&
                                _isSettlementUnderSiege(world, settlement);
                            final campUnderPressure =
                                camp != null &&
                                _isCampUnderPressure(world, camp);
                            final isLastEnemyFrom =
                                lastEnemyMove != null &&
                                lastEnemyMove.from == position;
                            final isLastEnemyTo =
                                lastEnemyMove != null &&
                                lastEnemyMove.to == position;
                            final ownedFieldByActive =
                                foodTileOwner == world.activePlayerId &&
                                !tilePillaged;
                            final borderColor = isSelected
                                ? playerColor(
                                    stack.ownerId,
                                  ).withValues(alpha: 0.9)
                                : isSelectedSettlement
                                ? const Color(0xFF2F6A55)
                                : isActiveStack
                                ? playerColor(
                                    stack.ownerId,
                                  ).withValues(alpha: 0.85)
                                : isLastEnemyTo
                                ? const Color(0xFFA53224)
                                : isLastEnemyFrom
                                ? const Color(0xFF8C6C1E)
                                : (stack != null
                                      ? playerColor(
                                          stack.ownerId,
                                        ).withValues(alpha: 0.56)
                                      : (settlementUnderSiege ||
                                                campUnderPressure
                                            ? const Color(0xFFB33A2E)
                                            : (territoryStatus?.frontline ??
                                                  false)
                                            ? const Color(0xFF7F4D21)
                                            : (ownedFieldByActive
                                                  ? const Color(
                                                      0xFF2F6A55,
                                                    ).withValues(alpha: 0.6)
                                                  : Colors.black.withValues(
                                                      alpha: 0.18,
                                                    ))));
                            final borderWidth = isSelected
                                ? 2.2
                                : isSelectedSettlement
                                ? 2.0
                                : isActiveStack
                                ? 2.0
                                : onSelectedSupplyLine
                                ? 1.9
                                : (isLastEnemyTo || isLastEnemyFrom)
                                ? 1.8
                                : (settlementUnderSiege ||
                                          campUnderPressure ||
                                          (territoryStatus?.frontline ?? false)
                                      ? 1.6
                                      : 1.0);
                            final tileRect = hexMetrics.tileRect(position);

                            tileWidgets.add(
                              Positioned(
                                left: tileRect.left,
                                top: tileRect.top,
                                width: tileRect.width,
                                height: tileRect.height,
                                child: GestureDetector(
                                  onTap: isBlocked
                                      ? null
                                      : () => _onWorldTileTap(position),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _WorldTilePainter(
                                              northRiver: northRiver,
                                              southRiver: southRiver,
                                              eastRiver: eastRiver,
                                              westRiver: westRiver,
                                              fillColor: occupiedColor,
                                              borderColor: borderColor,
                                              borderWidth: borderWidth,
                                              isBlocked: isBlocked,
                                              glowColor:
                                                  _reduceEffects ||
                                                      !isActiveStack
                                                  ? null
                                                  : playerColor(stack.ownerId),
                                              animValue: _riverAnimValue,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: ClipPath(
                                          clipper: const _HexagonClipper(),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              8,
                                              10,
                                              8,
                                              10,
                                            ),
                                            child: Stack(
                                              children: [
                                                if (territoryStatus
                                                        ?.frontline ??
                                                    false)
                                                  Positioned(
                                                    left: 2,
                                                    top: 4,
                                                    child: Container(
                                                      width: 9,
                                                      height: 9,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            const Color(
                                                              0xFF7A1F14,
                                                            ).withValues(
                                                              alpha: 0.78,
                                                            ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFFFE0AE,
                                                          ),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (onSelectedSupplyLine)
                                                  Positioned(
                                                    left: 8,
                                                    right: 8,
                                                    top: 2,
                                                    child: Container(
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFC89E3C,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              99,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                if (isLegalMove &&
                                                    stack == null)
                                                  Center(
                                                    child:
                                                        _buildWorldMoveTargetMarker(
                                                          attack: false,
                                                        ),
                                                  ),
                                                if (isLegalAttack)
                                                  Positioned(
                                                    right: 1,
                                                    top: 18,
                                                    child:
                                                        _buildWorldMoveTargetMarker(
                                                          attack: true,
                                                        ),
                                                  ),
                                                if (stack != null)
                                                  Center(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: _buildWorldStackTile(
                                                        stack: stack,
                                                        round: world.round,
                                                        isActive:
                                                            stack.ownerId ==
                                                            world
                                                                .activePlayerId,
                                                        supplyReport:
                                                            stackSupplyReport,
                                                      ),
                                                    ),
                                                  ),
                                                if (stack == null &&
                                                    (settlement != null ||
                                                        camp != null))
                                                  Center(
                                                    child:
                                                        _buildWorldTileSiteSummary(
                                                          world: world,
                                                          settlement:
                                                              settlement,
                                                          camp: camp,
                                                        ),
                                                  ),
                                                if (foodTileOwner != null ||
                                                    tilePillaged)
                                                  Positioned(
                                                    left: 0,
                                                    bottom: 0,
                                                    child: _buildFoodTileMarker(
                                                      ownerId: foodTileOwner,
                                                      pillaged: tilePillaged,
                                                    ),
                                                  ),
                                                if (isLastEnemyFrom)
                                                  const Positioned(
                                                    left: 0,
                                                    bottom: 14,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Color(
                                                          0xFF8C6C1E,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.all(
                                                              Radius.circular(
                                                                6,
                                                              ),
                                                            ),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 3,
                                                              vertical: 1,
                                                            ),
                                                        child: Text(
                                                          'FROM',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 7,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (isLastEnemyTo)
                                                  const Positioned(
                                                    right: 0,
                                                    bottom: 14,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: Color(
                                                          0xFFA53224,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.all(
                                                              Radius.circular(
                                                                6,
                                                              ),
                                                            ),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 3,
                                                              vertical: 1,
                                                            ),
                                                        child: Text(
                                                          'TO',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 7,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (settlement != null)
                                                  Positioned(
                                                    top: 0,
                                                    left: 0,
                                                    child:
                                                        _buildSettlementBadge(
                                                          world,
                                                          settlement,
                                                        ),
                                                  ),
                                                if (camp != null)
                                                  Positioned(
                                                    top: 0,
                                                    right: 0,
                                                    child: _buildCampBadge(
                                                      world,
                                                      camp,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: hexMetrics.boardWidth,
                              height: hexMetrics.boardHeight,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _WorldCampaignOverlayPainter(
                                          world: world,
                                          provinces: provinceSummary.provinces,
                                          provinceByPosition:
                                              provinceByPosition,
                                          territoryByPosition:
                                              territoryByPosition,
                                          selectedSupplyLine:
                                              selectedSupplyReport?.path ??
                                              const <BoardPosition>[],
                                          highlightedOwnerId:
                                              selectedStack?.ownerId,
                                          highlightedProvinceId:
                                              focusedProvince?.id,
                                          highlightedMove: lastEnemyMove,
                                          hexMetrics: hexMetrics,
                                          reduceEffects: _reduceEffects,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...tileWidgets,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _worldBoardHeaderChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: const Color(0xFFF1E4C7),
        border: Border.all(
          color: const Color(0xFF876741).withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF664620)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A3518),
            ),
          ),
        ],
      ),
    );
  }

  Color _worldTileColor({
    required int row,
    required int col,
    required bool isBlocked,
    required bool isSelected,
    required bool isLegalMove,
    required _TerritoryTileStatus? territoryStatus,
    required int activePlayerId,
    required bool onSelectedSupplyLine,
  }) {
    if (isBlocked) {
      return const Color(0xFF575E66);
    }
    if (isSelected) {
      return const Color(0xFFF5B865);
    }
    if (isLegalMove) {
      return const Color(0xFFA9CF86);
    }
    final parity = (row + col).isEven;
    var base = parity ? const Color(0xFFE5D1A9) : const Color(0xFFD8BE91);
    final ownerId = territoryStatus?.ownerId;
    if (ownerId != null) {
      final alpha = territoryStatus?.contested ?? false
          ? 0.12
          : (territoryStatus!.depth <= 2 ? 0.22 : 0.16);
      base = Color.alphaBlend(
        playerColor(
          ownerId,
        ).withValues(alpha: ownerId == activePlayerId ? alpha + 0.05 : alpha),
        base,
      );
    }
    if (territoryStatus?.frontline ?? false) {
      base = Color.alphaBlend(const Color(0x22A13924), base);
    }
    if (onSelectedSupplyLine) {
      base = Color.alphaBlend(const Color(0x33D3AE56), base);
    }
    return base;
  }

  Color _settlementOwnerColor(int ownerId) {
    if (ownerId < 0) {
      return const Color(0xFF90A4AE);
    }
    return playerColor(ownerId);
  }

  Color _contrastColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);
  }

  String _settlementTierCode(SettlementTier tier) {
    return switch (tier) {
      SettlementTier.village => 'V',
      SettlementTier.town => 'T',
      SettlementTier.castle => 'C',
    };
  }

  String _campPostureCode(CampPosture posture) {
    return switch (posture) {
      CampPosture.supply => 'S',
      CampPosture.fortified => 'F',
      CampPosture.raiding => 'R',
    };
  }

  int _enemyPressureAt(WorldState world, BoardPosition position, int ownerId) {
    var count = 0;
    for (final stack in world.stacks) {
      if (stack.ownerId == ownerId) {
        continue;
      }
      if (_manhattanDistance(stack.position, position) <= 1) {
        count++;
      }
    }
    return count;
  }

  bool _isSettlementUnderSiege(WorldState world, SettlementState settlement) {
    if (settlement.ownerId < 0) {
      return false;
    }
    return _enemyPressureAt(world, settlement.position, settlement.ownerId) > 0;
  }

  bool _isCampUnderPressure(WorldState world, CampState camp) {
    return _enemyPressureAt(world, camp.position, camp.ownerId) > 0;
  }

  Widget _buildSettlementBadge(WorldState world, SettlementState settlement) {
    final ownerColor = _settlementOwnerColor(settlement.ownerId);
    final ownerTag = settlement.ownerId < 0
        ? 'N'
        : 'P${settlement.ownerId + 1}';
    final siege = _isSettlementUnderSiege(world, settlement);
    final trapReady =
        settlement.trapType == SettlementTrapType.defensiveDitch &&
        settlement.trapArmed;
    final recentlyCaptured =
        settlement.lastCapturedRound != null &&
        (world.round - settlement.lastCapturedRound!) < 3;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ownerColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ownerColor.withValues(alpha: 0.96)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$ownerTag-${_settlementTierCode(settlement.tier)}',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: _contrastColor(ownerColor),
              ),
            ),
            if (recentlyCaptured)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.flag_rounded,
                  size: 10,
                  color: _contrastColor(ownerColor),
                ),
              ),
            if (siege)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.gpp_bad_rounded,
                  size: 10,
                  color: Color(0xFFFFE4A8),
                ),
              ),
            if (trapReady)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 10,
                  color: Color(0xFFFFF3C2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampBadge(WorldState world, CampState camp) {
    final ownerColor = playerColor(camp.ownerId);
    final ownerTag = 'P${camp.ownerId + 1}';
    final pressure = _isCampUnderPressure(world, camp);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ownerColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ownerColor.withValues(alpha: 0.96)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$ownerTag-${camp.isOutpost ? 'OP' : 'C'}-${_campPostureCode(camp.posture)}',
              style: TextStyle(
                fontSize: 7.1,
                fontWeight: FontWeight.w800,
                color: _contrastColor(ownerColor),
              ),
            ),
            if (camp.trapPrepared)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 10,
                  color: Color(0xFFFFF3C2),
                ),
              ),
            if (pressure)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.gpp_bad_rounded,
                  size: 10,
                  color: Color(0xFFFFE4A8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodTileMarker({required int? ownerId, required bool pillaged}) {
    final markerColor = pillaged
        ? const Color(0xFF9D2D2D)
        : (ownerId == null ? const Color(0xFF607D8B) : playerColor(ownerId));
    final markerText = pillaged
        ? 'P'
        : (ownerId == null ? 'F' : 'P${ownerId + 1}');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: markerColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: markerColor.withValues(alpha: 0.96)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pillaged ? Icons.local_fire_department_rounded : Icons.grass,
              size: 9,
              color: _contrastColor(markerColor),
            ),
            const SizedBox(width: 1),
            Text(
              markerText,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: _contrastColor(markerColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldMoveTargetMarker({required bool attack}) {
    final color = attack ? const Color(0xFFB12D25) : const Color(0xFF1F7A4E);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: _reduceEffects
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.34),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attack
                  ? Icons.sports_martial_arts_rounded
                  : Icons.near_me_rounded,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 2),
            Text(
              attack ? 'HIT' : 'GO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldTileSiteSummary({
    required WorldState world,
    required SettlementState? settlement,
    required CampState? camp,
  }) {
    final siteCodes = <String>[
      if (settlement != null)
        '${settlement.ownerId < 0 ? 'N' : 'P${settlement.ownerId + 1}'}-${_settlementTierCode(settlement.tier)}',
      if (camp != null)
        'P${camp.ownerId + 1}-${camp.isOutpost ? 'OP' : 'C'}-${_campPostureCode(camp.posture)}',
    ];
    final hazardIcons = <Widget>[
      if (settlement != null && _isSettlementUnderSiege(world, settlement))
        const Icon(Icons.gpp_bad_rounded, size: 11, color: Color(0xFF9A2E23)),
      if (settlement != null &&
          settlement.trapType == SettlementTrapType.defensiveDitch &&
          settlement.trapArmed)
        const Icon(
          Icons.warning_amber_rounded,
          size: 11,
          color: Color(0xFF8B5B13),
        ),
      if (camp != null && camp.trapPrepared)
        const Icon(
          Icons.warning_amber_rounded,
          size: 11,
          color: Color(0xFF8B5B13),
        ),
      if (camp != null && _isCampUnderPressure(world, camp))
        const Icon(Icons.gpp_bad_rounded, size: 11, color: Color(0xFF9A2E23)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (settlement != null)
          Icon(
            switch (settlement.tier) {
              SettlementTier.village => Icons.holiday_village_rounded,
              SettlementTier.town => Icons.location_city_rounded,
              SettlementTier.castle => Icons.castle_rounded,
            },
            size: 14,
            color: _settlementOwnerColor(settlement.ownerId),
          ),
        if (camp != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              camp.isOutpost ? Icons.home_work_rounded : Icons.fort_rounded,
              size: 13,
              color: playerColor(camp.ownerId),
            ),
          ),
        if (siteCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              siteCodes.join(' • '),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2B312F),
              ),
            ),
          ),
        if (hazardIcons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Wrap(spacing: 1, children: hazardIcons),
          ),
      ],
    );
  }

  Widget _buildWorldStackTile({
    required ArmyStack stack,
    required int round,
    required bool isActive,
    required _SupplyLineReport? supplyReport,
  }) {
    final ownerColor = playerColor(stack.ownerId);
    final ownerText = _contrastColor(ownerColor);
    final comp = stack.army.composition;
    final totalUnits = stack.army.units.length;
    final lineState = supplyReport?.stateLabel ?? 'No line';
    final lineColor = switch (supplyReport?.state ??
        _SupplyLineState.isolated) {
      _SupplyLineState.secure => const Color(0xFF295D46),
      _SupplyLineState.stretched => const Color(0xFF8A6218),
      _SupplyLineState.isolated => const Color(0xFF8E2E22),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: ownerColor.withValues(alpha: isActive ? 0.96 : 0.76),
          width: isActive ? 1.6 : 1.1,
        ),
        boxShadow: _reduceEffects || !isActive
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: ownerColor.withValues(alpha: 0.28),
                  blurRadius: 8,
                  spreadRadius: 0.3,
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ownerColor,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.92),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'P${stack.ownerId + 1} ${stack.label}',
                    style: TextStyle(
                      fontSize: 8.8,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: ownerText,
                    ),
                  ),
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Icon(
                      Icons.flash_on_rounded,
                      size: 10,
                      color: ownerColor.withValues(alpha: 0.95),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 64,
              height: 18,
              child: CustomPaint(
                painter: _MarchColumnPainter(
                  ownerColor: ownerColor,
                  infantry: comp.pawns,
                  cavalry: comp.knights,
                  support: comp.rooks + comp.bishops,
                  commanders: comp.generals,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$totalUnits units',
              style: const TextStyle(
                fontSize: 8.7,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF473826),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: lineColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: lineColor.withValues(alpha: 0.44),
                  width: 0.8,
                ),
              ),
              child: Text(
                lineState,
                style: TextStyle(
                  fontSize: 8.4,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: lineColor,
                ),
              ),
            ),
            if (stack.fatigue > 0 || stack.forcedMarchRound == round)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Wrap(
                  spacing: 2,
                  children: [
                    if (stack.fatigue > 0)
                      const Text(
                        'Fat',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6A2D1C),
                        ),
                      ),
                    if (stack.forcedMarchRound == round)
                      const Icon(
                        Icons.directions_run_rounded,
                        size: 9,
                        color: Color(0xFF7A4A17),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplyLineBanner(_SupplyLineReport report) {
    final (color, icon) = switch (report.state) {
      _SupplyLineState.secure => (const Color(0xFF295D46), Icons.route_rounded),
      _SupplyLineState.stretched => (
        const Color(0xFF8A6218),
        Icons.timeline_rounded,
      ),
      _SupplyLineState.isolated => (
        const Color(0xFF8E2E22),
        Icons.warning_amber_rounded,
      ),
    };
    final detail = report.anchor == null
        ? 'No friendly anchor'
        : '${report.anchor!.label} • ${report.distance} step(s)';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${report.stateLabel} • $detail',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _settlementDefenseSummary(SettlementState settlement) {
    final laneBlock = settlement.laneConstraint;
    final moraleShield =
        settlement.moraleShield + (settlement.garrisonedUnits > 0 ? 1 : 0);
    final trap = switch (settlement.trapType) {
      SettlementTrapType.none => 'No trap',
      SettlementTrapType.defensiveDitch =>
        settlement.trapArmed ? 'Ditch armed' : 'Ditch idle',
    };
    return 'Lanes -$laneBlock • Shield +$moraleShield • $trap';
  }

  String _campPostureLabel(CampPosture posture) {
    return switch (posture) {
      CampPosture.supply => 'Supply',
      CampPosture.fortified => 'Fortified',
      CampPosture.raiding => 'Raiding',
    };
  }

  String _campPostureSummary(CampPosture posture) {
    return switch (posture) {
      CampPosture.supply =>
        'Feeds reserves each upkeep while stock lasts. Lightly defended.',
      CampPosture.fortified =>
        'Strengthens defensive setup and helps nearby stack fatigue recovery.',
      CampPosture.raiding =>
        'Pressures nearby enemy settlements and extracts opportunistic food.',
    };
  }

  String _worldBoardInfoText({
    required WorldState world,
    required PlayerSlot activePlayer,
    required int campCount,
    required int outpostCount,
    _WorldMoveMarker? lastEnemyMove,
  }) {
    final lines = <String>[
      'Round ${world.round}',
      'Turn: ${activePlayer.name} (P${activePlayer.id + 1})',
      'CP ${_commandPointsForPlayer(world, world.activePlayerId)} • Food ${_foodForPlayer(world, world.activePlayerId)}',
      'Settlements ${world.settlements.length} • Camps $campCount • Outposts $outpostCount',
      'Hexes are operational sectors. Bright columns are armies ready to march.',
      'Blue bands mark rivers on hex edges. Only fords and bridges cross them safely.',
      'Red dots mark hot front lines. Gold lines trace the selected supply route.',
      'The curved arrow highlights the latest enemy movement across the theatre.',
      'Armies need water sooner than food. Riverbank camps are strong staging positions.',
      'Field markers: grass = secured food tile, flame = pillaged tile.',
      if (lastEnemyMove != null)
        'Last enemy move: P${lastEnemyMove.playerId + 1} ${lastEnemyMove.stackId} '
            '(${lastEnemyMove.from.row},${lastEnemyMove.from.col}) -> '
            '(${lastEnemyMove.to.row},${lastEnemyMove.to.col})',
    ];
    return lines.join('\n');
  }

  Widget _buildWorldSidebar(WorldState world, PlayerSlot activePlayer) {
    final activeIsAi = activePlayer.type == PlayerType.ai;
    final territoryByPosition = _territoryStatusMap(world);
    final provinceSummary = _provinceMapSummary(world, territoryByPosition);
    final provinceByPosition = provinceSummary.provinceByPosition;
    final activeCp = _commandPointsForPlayer(world, world.activePlayerId);
    final activeFood = _foodForPlayer(world, world.activePlayerId);
    final activeFoodProjection = _foodProjectionForPlayer(
      world,
      world.activePlayerId,
    );
    final activeCapturePolicy = _capturePolicyForPlayer(world.activePlayerId);
    final selectedStack = _selectedStack(world);
    final selectedOwnedStack =
        selectedStack != null && selectedStack.ownerId == world.activePlayerId
        ? selectedStack
        : null;
    final selectedSettlement =
        _selectedSettlementById(world) ??
        (selectedStack == null
            ? null
            : _selectedSettlementForStack(world, selectedStack));
    final selectedCamp = selectedStack == null
        ? null
        : _selectedCampForStack(world, selectedStack);
    final selectedPosition = selectedOwnedStack?.position;
    final selectedTile = selectedPosition == null
        ? null
        : world.tileAt(selectedPosition);
    final selectedTileSettlement = selectedPosition == null
        ? null
        : world.settlementAt(selectedPosition);
    final selectedTileOwner = selectedPosition == null
        ? null
        : _foodTileOwnerByPosition[selectedPosition];
    final selectedTilePillaged =
        selectedPosition != null &&
        (_pillagedTileUntilRound[selectedPosition] ?? 0) >= world.round;
    final selectedProvince =
        provinceByPosition[selectedStack?.position ??
            selectedSettlement?.position];
    final canUseSettlementActions =
        !activeIsAi &&
        !_aiBusy &&
        selectedOwnedStack != null &&
        selectedSettlement != null &&
        selectedOwnedStack.position == selectedSettlement.position &&
        selectedOwnedStack.ownerId == world.activePlayerId &&
        selectedSettlement.ownerId == world.activePlayerId;
    final canUseStackActions =
        !activeIsAi && !_aiBusy && selectedOwnedStack != null && activeCp > 0;
    final canUseForcedMarch =
        canUseStackActions &&
        !_stackFortifiedByCamp(world, selectedOwnedStack) &&
        activeFood > 0;
    final canEstablishCamp =
        canUseStackActions &&
        selectedOwnedStack.forcedMarchRound != world.round &&
        activeFood > 0 &&
        selectedCamp == null;
    final canShiftCampPosture =
        !activeIsAi &&
        !_aiBusy &&
        selectedCamp != null &&
        selectedCamp.ownerId == world.activePlayerId &&
        activeCp > 0;
    final canConsolidateCampOutpost =
        !activeIsAi &&
        !_aiBusy &&
        selectedCamp != null &&
        selectedCamp.ownerId == world.activePlayerId &&
        !selectedCamp.isOutpost &&
        selectedCamp.createdRound < world.round &&
        activeCp > 0;
    final canBreakCamp =
        !activeIsAi &&
        !_aiBusy &&
        selectedCamp != null &&
        selectedCamp.ownerId == world.activePlayerId;
    final canSecureSupplyTile =
        canUseStackActions &&
        selectedPosition != null &&
        selectedTile != null &&
        selectedTile.terrain == TerrainType.passable &&
        selectedTileSettlement == null &&
        !selectedTilePillaged &&
        selectedTileOwner != world.activePlayerId;
    final canPillageSupplyTile =
        canUseStackActions &&
        selectedPosition != null &&
        selectedTile != null &&
        selectedTile.terrain == TerrainType.passable &&
        selectedTileSettlement == null &&
        !selectedTilePillaged &&
        selectedTileOwner != world.activePlayerId;
    final canChangeCapturePolicy = !activeIsAi && !_aiBusy;
    final stackAtSelectedSettlement = selectedSettlement == null
        ? null
        : world.stackAt(selectedSettlement.position);
    final objectiveText = activeIsAi
        ? '${activePlayer.name} is thinking. Watch the highlighted route and latest order.'
        : selectedOwnedStack == null
        ? 'Select one of your armies. Bright stacks can march, camp, secure food, or attack.'
        : 'Selected ${selectedOwnedStack.id}: tap a highlighted sector to march, or use the command bar.';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxHeight < 210;
        final hudCard = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5C3A21), width: 2),
            boxShadow: _reduceEffects
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x333D1D13),
                      blurRadius: 0,
                      offset: Offset(3, 4),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _hudSectionTag(
                  icon: Icons.ads_click_rounded,
                  text: 'COMMAND BAR',
                ),
                _worldHudPill(
                  icon: Icons.bolt_rounded,
                  value: '$activeCp',
                  tooltip:
                      'Command Points. Spend these on movement and strategic actions.',
                ),
                _worldHudPill(
                  icon: Icons.grass_rounded,
                  value: '$activeFood',
                  tooltip:
                      'Reserve food. Armies now also depend on local supply at tile level.',
                ),
                if (selectedOwnedStack != null)
                  _worldHudPill(
                    icon: Icons.water_drop_rounded,
                    value:
                        '${_stackWater(selectedOwnedStack.id)} ${_waterStateLabel(_stackWater(selectedOwnedStack.id), _stackThirst(selectedOwnedStack.id))}',
                    tooltip:
                        'Selected army water state. Thirst rises faster than hunger when you march away from rivers, crossings, settlements, and camps.',
                  ),
                if (selectedProvince != null)
                  _worldHudPill(
                    icon: Icons.map_rounded,
                    value: selectedProvince.name,
                    tooltip:
                        '${_provinceControlSummary(selectedProvince)}. ${_provincePressureSummary(selectedProvince)}',
                  ),
                _worldHudPill(
                  icon: Icons.fort_rounded,
                  value: 'Raise Camp (-1 food)',
                  tooltip:
                      'Create a temporary camp on your selected army tile.',
                  onTap: canEstablishCamp ? _establishCamp : null,
                ),
                _worldHudPill(
                  icon: activeCapturePolicy == _CapturePolicy.spare
                      ? Icons.volunteer_activism_rounded
                      : Icons.warning_amber_rounded,
                  value: activeCapturePolicy == _CapturePolicy.spare
                      ? 'Spare'
                      : 'Destroy',
                  tooltip:
                      'Capture policy. Tap to switch between Spare and Destroy.',
                  onTap: canChangeCapturePolicy
                      ? () {
                          setState(() {
                            final next =
                                activeCapturePolicy == _CapturePolicy.spare
                                ? _CapturePolicy.destroy
                                : _CapturePolicy.spare;
                            _capturePolicyByPlayer = <int, _CapturePolicy>{
                              ..._capturePolicyByPlayer,
                              world.activePlayerId: next,
                            };
                            _status =
                                'Capture policy set to ${next == _CapturePolicy.spare ? 'Spare' : 'Destroy'} for Player ${world.activePlayerId + 1}.';
                          });
                        }
                      : null,
                ),
                _worldHudPill(
                  icon: Icons.insights_rounded,
                  value: 'Outlook',
                  tooltip:
                      'Long-press for details. Tap to open supply projection.',
                  onTap: () => _showSupplyOutlookSheet(
                    world: world,
                    projection: activeFoodProjection,
                  ),
                ),
                _worldHudPill(
                  icon: Icons.skip_next_rounded,
                  value: 'End Turn',
                  tooltip: 'End your turn now.',
                  onTap: activeIsAi || _aiBusy ? null : _passWorldTurn,
                ),
                _worldHudPill(
                  icon: _skipAiBattles
                      ? Icons.fast_forward_rounded
                      : Icons.sports_martial_arts_rounded,
                  value: _skipAiBattles
                      ? 'AI Battles: Skip'
                      : 'AI Battles: Play',
                  tooltip:
                      'Toggle skipping AI-vs-AI tactical battles. When enabled, battles resolve instantly.',
                  onTap: () {
                    setState(() {
                      _skipAiBattles = !_skipAiBattles;
                      _status = _skipAiBattles
                          ? 'AI-vs-AI battles will be skipped and auto-resolved.'
                          : 'AI-vs-AI battles will play on the tactical board.';
                    });
                  },
                ),
              ],
            ),
          ),
        );

        if (compactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _worldObjectiveBanner(
                activePlayer: activePlayer,
                objectiveText: objectiveText,
              ),
              const SizedBox(height: 6),
              _statusChip(_status),
              const SizedBox(height: 6),
              hudCard,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _worldObjectiveBanner(
              activePlayer: activePlayer,
              objectiveText: objectiveText,
            ),
            const SizedBox(height: 6),
            _statusChip(_status),
            const SizedBox(height: 6),
            hudCard,
            if (selectedStack != null) ...[
              const SizedBox(height: 6),
              _selectedArmyHudCard(
                stack: selectedStack,
                activePlayerId: world.activePlayerId,
                province: selectedProvince,
              ),
            ],
            const SizedBox(height: 6),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: AnimatedSwitcher(
                    duration: _reduceEffects
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: selectedStack != null
                        ? _buildSelectedStackContext(
                            world: world,
                            stack: selectedStack,
                            selectedCamp: selectedCamp,
                            selectedSettlement: selectedSettlement,
                            canUseForcedMarch: canUseForcedMarch,
                            canEstablishCamp: canEstablishCamp,
                            canShiftCampPosture: canShiftCampPosture,
                            canConsolidateCampOutpost:
                                canConsolidateCampOutpost,
                            canBreakCamp: canBreakCamp,
                            canUseSettlementActions: canUseSettlementActions,
                            canSecureSupplyTile: canSecureSupplyTile,
                            canPillageSupplyTile: canPillageSupplyTile,
                          )
                        : (selectedSettlement != null
                              ? _buildSelectedSettlementContext(
                                  world: world,
                                  settlement: selectedSettlement,
                                  stackAtSettlement: stackAtSelectedSettlement,
                                )
                              : _buildWorldIdleContext(world)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showWorldFactionsSheet(world),
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Factions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showWorldLogSheet(world),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Chronicle'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _worldObjectiveBanner({
    required PlayerSlot activePlayer,
    required String objectiveText,
  }) {
    final color = playerColor(activePlayer.id);
    final onColor = _contrastColor(color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
        boxShadow: _reduceEffects
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 0,
                  offset: const Offset(3, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  activePlayer.type == PlayerType.ai
                      ? Icons.memory_rounded
                      : Icons.flag_rounded,
                  color: onColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Player ${activePlayer.id + 1} • ${activePlayer.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    objectiveText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2D2117),
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _worldHudPill({
    required IconData icon,
    required String value,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final content = Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: enabled ? const Color(0xFFF3E6C8) : const Color(0xFFE3DDD1),
        border: Border.all(
          color: enabled ? const Color(0xFF8B6E46) : const Color(0xFFB4AA93),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: enabled ? const Color(0xFF674B22) : const Color(0xFF6B6B6B),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                color: enabled
                    ? const Color(0xFF3C2D16)
                    : const Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      waitDuration: const Duration(milliseconds: 280),
      message: tooltip,
      child: enabled
          ? InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }

  Widget _hudSectionTag({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1D13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC9A227), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFF0B7), size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFFFF0B7),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStackContext({
    required WorldState world,
    required ArmyStack stack,
    required CampState? selectedCamp,
    required SettlementState? selectedSettlement,
    required bool canUseForcedMarch,
    required bool canEstablishCamp,
    required bool canShiftCampPosture,
    required bool canConsolidateCampOutpost,
    required bool canBreakCamp,
    required bool canUseSettlementActions,
    required bool canSecureSupplyTile,
    required bool canPillageSupplyTile,
  }) {
    final supply = _stackSupply(stack.id);
    final starvation = _stackStarvation(stack.id);
    final water = _stackWater(stack.id);
    final thirst = _stackThirst(stack.id);
    final supplyReport = _supplyLineReport(world, stack);
    final mergeTargets = _adjacentMergeTargets(world, stack);
    final tileOwner = _foodTileOwnerByPosition[stack.position];
    final tilePillaged =
        (_pillagedTileUntilRound[stack.position] ?? 0) >= world.round;
    final tileFoodLine = tilePillaged
        ? 'Tile status: pillaged and barren this round.'
        : (tileOwner == null
              ? 'Tile status: unsecured forage land.'
              : (tileOwner == stack.ownerId
                    ? 'Tile status: secured food tile for Player ${stack.ownerId + 1}.'
                    : 'Tile status: enemy-controlled food tile (Player ${tileOwner + 1}).'));
    final waterLine = _waterAccessLabel(world, stack.position);
    final supplyLineText = switch (supplyReport.state) {
      _SupplyLineState.secure =>
        'Supply line secure from ${supplyReport.anchor?.label ?? 'friendly territory'} in ${supplyReport.distance} march(es).',
      _SupplyLineState.stretched =>
        'Supply line stretched from ${supplyReport.anchor?.label ?? 'friendly territory'}: ${supplyReport.distance} march(es), ${supplyReport.dangerSteps} exposed segment(s).',
      _SupplyLineState.isolated =>
        'Cut off from friendly magazines. This army is living off the land.',
    };
    final forageLine = switch (supplyReport.state) {
      _SupplyLineState.secure =>
        'Foraging is supplementary. Protect crossings and do not overextend the baggage route.',
      _SupplyLineState.stretched =>
        'Foraging under pressure is risky. Enemy contact along the route can turn hunger into fatigue fast.',
      _SupplyLineState.isolated =>
        'Foraging is now desperate and dangerous. Expect fatigue, thirst, and stragglers if you stay cut off.',
    };
    final concentrationLine = mergeTargets.isEmpty
        ? 'No adjacent allied column ready to join ranks.'
        : '${mergeTargets.length} adjacent allied column(s) can be concentrated into this host.';

    return KeyedSubtree(
      key: ValueKey<String>('stack-${stack.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'March Orders',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: playerColor(stack.ownerId),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tile (${stack.position.row},${stack.position.col}) • '
            'Supply $supply (${_supplyStateLabel(supply, starvation)})',
          ),
          const SizedBox(height: 4),
          _buildSupplyLineBanner(supplyReport),
          const SizedBox(height: 2),
          Text(
            'Water $water (${_waterStateLabel(water, thirst)})',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: thirst >= 2
                  ? const Color(0xFF8C2E1F)
                  : const Color(0xFF225B73),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tileFoodLine,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            supplyLineText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(waterLine, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            forageLine,
            style: const TextStyle(fontSize: 12, color: Color(0xFF604B2A)),
          ),
          const SizedBox(height: 2),
          Text(
            concentrationLine,
            style: const TextStyle(fontSize: 12, color: Color(0xFF604B2A)),
          ),
          if (selectedSettlement != null) ...[
            const SizedBox(height: 2),
            Text(
              'Settlement: ${selectedSettlement.name} (${selectedSettlement.tier.name.toUpperCase()})',
            ),
          ],
          if (selectedCamp != null) ...[
            const SizedBox(height: 2),
            Text(
              'Camp posture: ${_campPostureLabel(selectedCamp.posture)}'
              '${selectedCamp.isOutpost ? ' (Outpost)' : ''}',
            ),
            Text(
              _campPostureSummary(selectedCamp.posture),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: canUseForcedMarch ? _toggleForcedMarchMode : null,
                icon: const Icon(Icons.directions_run_rounded),
                label: Text(_forcedMarchMode ? 'Forced On' : 'Forced'),
              ),
              FilledButton.tonalIcon(
                onPressed: mergeTargets.isNotEmpty ? _mergeSelectedArmy : null,
                icon: const Icon(Icons.call_merge_rounded),
                label: const Text('Join Columns'),
              ),
              if (selectedCamp == null)
                FilledButton.tonalIcon(
                  onPressed: canEstablishCamp ? _establishCamp : null,
                  icon: const Icon(Icons.fort_rounded),
                  label: const Text('Camp'),
                )
              else ...[
                FilledButton.tonalIcon(
                  onPressed: canShiftCampPosture ? _shiftCampPosture : null,
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('Posture'),
                ),
                FilledButton.tonalIcon(
                  onPressed: canConsolidateCampOutpost
                      ? _consolidateCampOutpost
                      : null,
                  icon: const Icon(Icons.home_work_rounded),
                  label: const Text('Outpost'),
                ),
                FilledButton.tonalIcon(
                  onPressed: canBreakCamp ? _breakCamp : null,
                  icon: const Icon(Icons.disabled_by_default_rounded),
                  label: const Text('Break'),
                ),
              ],
              FilledButton.tonalIcon(
                onPressed: canSecureSupplyTile
                    ? _secureSelectedSupplyTile
                    : null,
                icon: const Icon(Icons.grass_rounded),
                label: const Text('Secure'),
              ),
              FilledButton.tonalIcon(
                onPressed: canPillageSupplyTile
                    ? _pillageSelectedSupplyTile
                    : null,
                icon: const Icon(Icons.local_fire_department_rounded),
                label: const Text('Pillage'),
              ),
              FilledButton.tonalIcon(
                onPressed: selectedSettlement != null
                    ? () => _showSettlementActionsSheet(
                        settlement: selectedSettlement,
                      )
                    : null,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Settlement'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _showStackIntelSheet(world: world, stack: stack),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStackActionGuide(selectedCamp: selectedCamp),
          if (!canUseSettlementActions && selectedSettlement != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Settlement actions require your selected army to stand on this owned settlement.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStackActionGuide({required CampState? selectedCamp}) {
    final campLine = selectedCamp == null
        ? 'Camp: spend CP and food to create temporary support on this army tile.'
        : 'Posture: cycle camp role. Outpost: make an older camp last. Break: remove this camp.';
    const lines = <String>[
      'Move: tap a highlighted tile. Moving into an enemy army starts battle setup.',
      'Forced: toggle 2-tile march for food; useful for tempo, risky for fatigue.',
      'Join Columns: merge an adjacent allied army into this host if the stack cap allows it.',
      'Secure: claim open fields for steadier food. Pillage: burn enemy or unsecured fields for immediate supply.',
      'Settlement: open local town actions. Details: inspect supply, water, command, and battle context.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EEDB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x338A6A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Key',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final line in <String>[...lines, campLine])
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 11.6,
                  color: Color(0xFF604B2A),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedSettlementContext({
    required WorldState world,
    required SettlementState settlement,
    required ArmyStack? stackAtSettlement,
  }) {
    final ownerLabel = settlement.ownerId < 0
        ? 'Neutral'
        : 'Player ${settlement.ownerId + 1}';
    final canSelectOwnStack =
        stackAtSettlement != null &&
        stackAtSettlement.ownerId == world.activePlayerId &&
        !_aiBusy &&
        _playerTypeById(world.activePlayerId) == PlayerType.human;
    final harvest = _settlementHarvest(settlement);
    final tax = _settlementTaxIncome(settlement, settlement.unrest);
    final levyText = settlement.levyCooldown == 0
        ? 'Levy ready'
        : 'Levy CD ${settlement.levyCooldown}';

    return KeyedSubtree(
      key: ValueKey<String>('settlement-${settlement.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${settlement.name} (${settlement.tier.name.toUpperCase()})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('Owner: $ownerLabel'),
          const SizedBox(height: 2),
          Text(
            'Tax +$tax • Harvest +$harvest • Supply ${settlement.supplyStock} • $levyText',
          ),
          const SizedBox(height: 2),
          Text(
            'Garrison ${settlement.garrisonedUnits}/${settlement.garrisonCapacity} • '
            'Unrest ${settlement.unrest} • '
            'Dev ${settlement.devastation}',
          ),
          const SizedBox(height: 4),
          Text(
            _settlementDefenseSummary(settlement),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: canSelectOwnStack
                    ? () {
                        _focusWorldStack(stackAtSettlement);
                        _showSettlementActionsSheet(settlement: settlement);
                      }
                    : null,
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Select Army'),
              ),
              FilledButton.tonalIcon(
                onPressed: canSelectOwnStack
                    ? () => _showSettlementActionsSheet(settlement: settlement)
                    : null,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Settlement'),
              ),
            ],
          ),
          if (!canSelectOwnStack) ...[
            const SizedBox(height: 6),
            const Text(
              'To use settlement actions, move and select your army on this tile.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorldIdleContext(WorldState world) {
    return const KeyedSubtree(
      key: ValueKey<String>('world-idle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How To Start', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Tap an army to issue march, camp, merge, and supply orders. Rivers, borders, settlements, grass, and flame mark water, territory, food, and pillage.',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showSupplyOutlookSheet({
    required WorldState world,
    required _FoodProjection projection,
  }) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = math.min(
          MediaQuery.of(context).size.height * 0.74,
          420.0,
        );
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _foodStatusCard(projection),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorldFactionsSheet(WorldState world) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = math.min(
          MediaQuery.of(context).size.height * 0.78,
          520.0,
        );
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                const Text(
                  'Factions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final player in world.players)
                  _playerSummaryCard(
                    player: player,
                    stacks: world.stacksForPlayer(player.id),
                    food: world.foodByPlayer[player.id] ?? 0,
                    treasury: world.treasuryByPlayer[player.id] ?? 0,
                    isActive: player.id == world.activePlayerId,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorldLogSheet(WorldState world) async {
    if (!mounted) {
      return;
    }
    final entries = world.log.reversed.take(10).toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = math.min(
          MediaQuery.of(context).size.height * 0.78,
          520.0,
        );
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Campaign Chronicle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(entries[index - 1]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStackIntelSheet({
    required WorldState world,
    required ArmyStack stack,
  }) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = math.min(
          MediaQuery.of(context).size.height * 0.84,
          680.0,
        );
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _selectedStackCard(world: world, stack: stack),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSettlementActionsSheet({
    required SettlementState settlement,
  }) async {
    final world = _world;
    if (world == null || _phase != _GamePhase.world) {
      return;
    }
    final selected = _selectedStack(world);
    final canAct =
        selected != null &&
        selected.ownerId == world.activePlayerId &&
        selected.position == settlement.position &&
        settlement.ownerId == world.activePlayerId &&
        !_aiBusy &&
        _playerTypeById(world.activePlayerId) == PlayerType.human;

    Future<void> runAction(SettlementAction action) async {
      Navigator.of(context).pop();
      _performSettlementAction(action);
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settlement.name} Actions',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (!canAct)
                  const Text(
                    'Requires your selected army on this owned settlement.',
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Tax: gain coin, unrest +1. Forage: gain food and local supply, unrest +1.',
                ),
                const Text(
                  'Garrison: add defense, lower unrest, and arm ditches where available.',
                ),
                const Text(
                  'Levy: add infantry if cooldown, manpower, and stack cap allow it.',
                ),
                const Text(
                  'Study: spend extra CP and food to improve a general when culture allows it.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: canAct
                          ? () {
                              unawaited(runAction(SettlementAction.tax));
                            }
                          : null,
                      icon: const Icon(Icons.payments_rounded),
                      label: const Text('Tax'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canAct
                          ? () {
                              unawaited(runAction(SettlementAction.forage));
                            }
                          : null,
                      icon: const Icon(Icons.grass_rounded),
                      label: const Text('Forage'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canAct
                          ? () {
                              unawaited(runAction(SettlementAction.garrison));
                            }
                          : null,
                      icon: const Icon(Icons.shield_rounded),
                      label: const Text('Garrison'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canAct
                          ? () {
                              unawaited(runAction(SettlementAction.levy));
                            }
                          : null,
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Levy'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: canAct
                          ? () {
                              unawaited(runAction(SettlementAction.study));
                            }
                          : null,
                      icon: const Icon(Icons.school_rounded),
                      label: const Text('Study'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _foodStatusCard(_FoodProjection projection) {
    final theme = Theme.of(context);
    final atRisk = projection.shortageStacks > 0;
    final veryLowReserve = !atRisk && projection.projectedReserve <= 1;
    final accent = atRisk
        ? const Color(0xFFB33A2E)
        : (veryLowReserve ? const Color(0xFF9A6B14) : const Color(0xFF2F6A55));
    final icon = atRisk
        ? Icons.warning_amber_rounded
        : (veryLowReserve ? Icons.hourglass_bottom_rounded : Icons.eco_rounded);
    final message = atRisk
        ? 'Projected shortage: ${projection.shortageStacks} stack(s) may go unsupplied next upkeep. Unsupplied stacks gain fatigue.'
        : (veryLowReserve
              ? 'Reserve will stay very low after upkeep. Forage or secure settlements before forcing tempo.'
              : 'Supply outlook is stable this round.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Text('Supply Outlook', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Reserve ${projection.reserve}')),
                Chip(
                  label: Text('Settlements +${projection.settlementIncome}'),
                ),
                Chip(label: Text('Camps +${projection.campIncome}')),
                Chip(label: Text('Fields +${projection.fieldIncome}')),
                Chip(label: Text('Upkeep -${projection.upkeep}')),
                Chip(label: Text('Projected ${projection.projectedReserve}')),
              ],
            ),
            const SizedBox(height: 6),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Forced March consumes 1 food on use.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerSummaryCard({
    required PlayerSlot player,
    required List<ArmyStack> stacks,
    required int food,
    required int treasury,
    required bool isActive,
  }) {
    final accent = playerColor(player.id);
    final typeLabel = player.type == PlayerType.human ? 'Human' : 'AI';
    return Card(
      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.name} ($typeLabel)${isActive ? ' • Active Turn' : ''}',
              style: TextStyle(fontWeight: FontWeight.bold, color: accent),
            ),
            const SizedBox(height: 3),
            Text(
              food <= 0
                  ? 'Granaries: $food (Empty)'
                  : (food == 1 ? 'Granaries: $food (Low)' : 'Granaries: $food'),
            ),
            const SizedBox(height: 2),
            Text('War Chest: $treasury'),
            const SizedBox(height: 3),
            Container(
              height: 2,
              width: 56,
              color: accent.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 4),
            if (stacks.isEmpty)
              const Text('Eliminated')
            else
              for (final stack in stacks)
                Text(
                  '${stack.id} at (${stack.position.row},${stack.position.col}) '
                  '${_armyTileSummary(stack.army).replaceFirst('\n', ' | ')}',
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleScreen(BuildContext context) {
    final session = _battle!;
    final battle = session.battleState;
    final mediaSize = MediaQuery.sizeOf(context);
    final useInlineHintButton = mediaSize.width < 720 || mediaSize.height < 900;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _confirmReturnToMenuOnBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('ChessWarss - ${widget.gameMode.label} Battle'),
          actions: [
            IconButton(
              tooltip: 'Session',
              onPressed: _showSessionMenu,
              icon: const Icon(Icons.shield_rounded),
            ),
            IconButton(
              tooltip: 'War Lab',
              onPressed: _showWarLabSheet,
              icon: const Icon(Icons.bug_report_rounded),
            ),
            IconButton(
              tooltip: 'Field Manual',
              onPressed: _showFieldManualDialog,
              icon: const Icon(Icons.menu_book_rounded),
            ),
          ],
        ),
        body: _screenBackdrop(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  final compactBattleHud =
                      !wide &&
                      (constraints.maxWidth < 720 ||
                          constraints.maxHeight < 940);
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildBattleBoardCard(session),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildBattleSidebar(session)),
                      ],
                    );
                  }

                  if (compactBattleHud) {
                    return Column(
                      children: [
                        Expanded(
                          child: _buildBattleBoardCard(session, compact: true),
                        ),
                        const SizedBox(height: 10),
                        _buildCompactBattleHud(
                          session,
                          showHintButton: useInlineHintButton,
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(flex: 5, child: _buildBattleBoardCard(session)),
                      const SizedBox(height: 10),
                      Expanded(flex: 4, child: _buildBattleSidebar(session)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        floatingActionButton:
            _playerTypeById(battle.activePlayer) == PlayerType.ai ||
                useInlineHintButton
            ? null
            : FloatingActionButton.extended(
                onPressed: _requestBattleHint,
                icon: const Icon(Icons.tips_and_updates_outlined),
                label: const Text('Hint Move'),
              ),
      ),
    );
  }

  void _requestBattleHint() {
    final session = _battle;
    if (session == null) {
      return;
    }
    final action = _battleAi.chooseMove(
      session.battleState,
      _seed,
      difficulty: _aiDifficulty,
    );
    if (action != null) {
      _executeBattleMove(action);
      return;
    }
    setState(() {
      _status = 'No clear battle hint is available right now.';
    });
  }

  Widget _buildBattleBoardCard(BattleSession session, {bool compact = false}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battlefield ${session.battlefield.notation}',
              style: compact
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.titleMedium,
            ),
            SizedBox(height: compact ? 6 : 8),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                Chip(
                  label: Text('P${session.attackerStack.ownerId + 1} Attacker'),
                ),
                Chip(
                  label: Text('P${session.defenderStack.ownerId + 1} Defender'),
                ),
                Chip(
                  label: Text(
                    '${session.battleState.rows}x${session.battleState.cols}',
                  ),
                ),
                if (compact)
                  Chip(
                    label: Text(
                      'Turn ${_battleTurnCounter(session.battleState)}',
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Expanded(
              child: RepaintBoundary(
                child: BattleBoardWidget(
                  state: session.battleState,
                  selectedPieceId: _selectedBattlePieceId,
                  legalMoves: _battleLegalMoves,
                  onTapSquare: _onBattleTileTap,
                  turnOverlay: _battleTurnOverlay,
                  showOverlayArrows: true,
                  bottomOwnerId: session.attackerStack.ownerId,
                  reduceEffects: _reduceEffects,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            compact ? _compactBattleStatusStrip(_status) : _statusChip(_status),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleSidebar(BattleSession session) {
    final battle = session.battleState;
    final activeType = _playerTypeById(battle.activePlayer);
    final activeIsHuman = activeType == PlayerType.human;
    final theme = Theme.of(context);
    final attackerMoraleDelta = _latestMoraleDeltaForPlayer(
      battle,
      session.attackerStack.ownerId,
    );
    final defenderMoraleDelta = _latestMoraleDeltaForPlayer(
      battle,
      session.defenderStack.ownerId,
    );
    final recentBattleEvents = battle.eventLog.reversed
        .take(10)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'Active side: Player ${battle.activePlayer + 1} (${activeType == PlayerType.human ? 'Human' : 'AI'})',
              style: theme.textTheme.titleSmall,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Morale', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                _moraleLine(
                  label: 'Player ${session.attackerStack.ownerId + 1}',
                  morale: battle.moraleForPlayer(session.attackerStack.ownerId),
                  moraleState: battle.moraleStateForPlayer(
                    session.attackerStack.ownerId,
                  ),
                  maxMorale: battle.maxMorale,
                  color: playerColor(session.attackerStack.ownerId),
                  trendDelta: attackerMoraleDelta,
                ),
                const SizedBox(height: 4),
                _moraleLine(
                  label: 'Player ${session.defenderStack.ownerId + 1}',
                  morale: battle.moraleForPlayer(session.defenderStack.ownerId),
                  moraleState: battle.moraleStateForPlayer(
                    session.defenderStack.ownerId,
                  ),
                  maxMorale: battle.maxMorale,
                  color: playerColor(session.defenderStack.ownerId),
                  trendDelta: defenderMoraleDelta,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _commandCard(session),
        const SizedBox(height: 8),
        _decisiveSignalsCard(session),
        const SizedBox(height: 8),
        if (activeIsHuman)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: battle.canCharge() ? () => _useCharge() : null,
                    icon: const Icon(Icons.speed_rounded),
                    label: const Text('Charge'),
                  ),
                  FilledButton.icon(
                    onPressed: battle.canDefend() ? () => _useDefend() : null,
                    icon: const Icon(Icons.shield_rounded),
                    label: const Text('Defend'),
                  ),
                  FilledButton.icon(
                    onPressed: battle.canAdvanceFrontline()
                        ? () => _advanceFrontline()
                        : null,
                    icon: const Icon(Icons.trending_up_rounded),
                    label: const Text('Advance'),
                  ),
                  FilledButton.icon(
                    onPressed: battle.canUseGeneralAdvanceSkill()
                        ? () => _useGeneralAdvanceSkill()
                        : null,
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('High Command'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        _battleArmyCard(
          'Attacker',
          session.attackerStack.army,
          session.attackerStack.ownerId,
          battle,
        ),
        _battleArmyCard(
          'Defender',
          session.defenderStack.army,
          session.defenderStack.ownerId,
          battle,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Turns', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                SizedBox(
                  height: 170,
                  child: Scrollbar(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentBattleEvents.length,
                      itemBuilder: (context, index) {
                        final event = recentBattleEvents[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text('[T${event.turn}] ${event.description}'),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Battle Action Guide', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Move: select a unit, then tap a highlighted square. Captures damage morale.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Charge: one-time aggressive stance if you have enough mobile units.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Defend: one-time holding stance if enough units remain.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Advance: pushes front pawns into contact; it can move, capture, clash, or get repulsed.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'High Command: stronger one-time advance from a capable general.',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Watch morale and commanders. Broken morale or lost commanders can end the battle before every unit is gone.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactBattleStatusStrip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF4E7C8),
        border: Border.all(
          color: const Color(0xFF8A6A3E).withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBattleHud(
    BattleSession session, {
    required bool showHintButton,
  }) {
    final battle = session.battleState;
    final activeType = _playerTypeById(battle.activePlayer);
    final activeIsHuman = activeType == PlayerType.human;
    final activeCommandLines = _visibleCommandProfiles(
      battle: battle,
      ownerId: battle.activePlayer,
      viewerId: battle.activePlayer,
    );
    final activeCommandLine = activeCommandLines.isEmpty
        ? 'No commander'
        : activeCommandLines.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _battleInfoChip(
                  icon: Icons.military_tech_rounded,
                  label: 'P${battle.activePlayer + 1} to move',
                ),
                _battleInfoChip(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Turn ${_battleTurnCounter(battle)}',
                ),
                _battleInfoChip(
                  icon: Icons.flag_circle_rounded,
                  label: _decisiveSignalSummary(battle, battle.activePlayer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Command: $activeCommandLine',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.6,
                fontWeight: FontWeight.w600,
                color: Color(0xFF574220),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactBattleMoraleStrip(
                    playerId: session.attackerStack.ownerId,
                    morale: battle.moraleForPlayer(
                      session.attackerStack.ownerId,
                    ),
                    moraleState: battle.moraleStateForPlayer(
                      session.attackerStack.ownerId,
                    ),
                    maxMorale: battle.maxMorale,
                    color: playerColor(session.attackerStack.ownerId),
                    trendDelta: _latestMoraleDeltaForPlayer(
                      battle,
                      session.attackerStack.ownerId,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactBattleMoraleStrip(
                    playerId: session.defenderStack.ownerId,
                    morale: battle.moraleForPlayer(
                      session.defenderStack.ownerId,
                    ),
                    moraleState: battle.moraleStateForPlayer(
                      session.defenderStack.ownerId,
                    ),
                    maxMorale: battle.maxMorale,
                    color: playerColor(session.defenderStack.ownerId),
                    trendDelta: _latestMoraleDeltaForPlayer(
                      battle,
                      session.defenderStack.ownerId,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCompactBattleArmyLines(session),
            const SizedBox(height: 8),
            if (activeIsHuman)
              _buildCompactBattleActionGrid(battle)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEAE2D0),
                ),
                child: Text(
                  'AI command is weighing the line of battle.',
                  style: TextStyle(
                    color: const Color(0xFF5C5446),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showBattleBriefSheet(session),
                  icon: const Icon(Icons.summarize_rounded),
                  label: const Text('Battle Brief'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showFieldManualDialog,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Manual'),
                ),
                if (showHintButton && activeIsHuman)
                  FilledButton.icon(
                    onPressed: _requestBattleHint,
                    icon: const Icon(Icons.tips_and_updates_outlined),
                    label: const Text('Hint Move'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBattleArmyLines(BattleSession session) {
    final battle = session.battleState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _compactBattleArmyLine(
          label: 'Attacker',
          army: session.attackerStack.army,
          ownerId: session.attackerStack.ownerId,
          battle: battle,
        ),
        const SizedBox(height: 4),
        _compactBattleArmyLine(
          label: 'Defender',
          army: session.defenderStack.army,
          ownerId: session.defenderStack.ownerId,
          battle: battle,
        ),
      ],
    );
  }

  Widget _compactBattleArmyLine({
    required String label,
    required ArmyDefinition army,
    required int ownerId,
    required BattleState battle,
  }) {
    final perks = _visibleGeneralPerks(
      battle: battle,
      ownerId: ownerId,
      viewerId: battle.activePlayer,
    );
    final line = perks.isEmpty ? _armyRoleSummary(army) : perks.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: playerColor(ownerId).withValues(alpha: 0.08),
        border: Border.all(color: playerColor(ownerId).withValues(alpha: 0.22)),
      ),
      child: Text(
        '$label • ${army.label} • ${_armyTileSummary(army).replaceFirst('\n', ' | ')} • $line',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.7,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B3A1D),
        ),
      ),
    );
  }

  Widget _battleInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: const Color(0xFFF1E5CB),
        border: Border.all(
          color: const Color(0xFF8A6C42).withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6E4D22)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E391B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBattleMoraleStrip({
    required int playerId,
    required int morale,
    required MoraleState moraleState,
    required int maxMorale,
    required Color color,
    required int trendDelta,
  }) {
    final statusColor = switch (moraleState) {
      MoraleState.steady => const Color(0xFF2F6A55),
      MoraleState.wavering => const Color(0xFF5A6E49),
      MoraleState.routing => const Color(0xFF9D2D2D),
      MoraleState.collapsed => const Color(0xFF6F1A1A),
    };
    final statusLabel = switch (moraleState) {
      MoraleState.steady => 'Steady',
      MoraleState.wavering => 'Shaken',
      MoraleState.routing => 'Rout Risk',
      MoraleState.collapsed => 'Broken',
    };
    final trendLabel = trendDelta > 0
        ? '+$trendDelta'
        : trendDelta < 0
        ? '$trendDelta'
        : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
        color: statusColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'P${playerId + 1} $statusLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              Text(
                trendLabel,
                style: TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                  color: trendDelta < 0
                      ? const Color(0xFFAA2D2D)
                      : const Color(0xFF2F6A55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            runSpacing: 1,
            children: [
              for (var i = 0; i < maxMorale; i++)
                Icon(
                  i < morale ? Icons.shield_rounded : Icons.shield_outlined,
                  size: 14,
                  color: i < morale
                      ? color
                      : const Color(0xFFA44A4A).withValues(alpha: 0.58),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBattleActionGrid(BattleState battle) {
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      visualDensity: VisualDensity.compact,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: actionWidth,
              child: FilledButton.tonalIcon(
                onPressed: battle.canCharge() ? _useCharge : null,
                style: buttonStyle,
                icon: const Icon(Icons.speed_rounded),
                label: const Text('Charge'),
              ),
            ),
            SizedBox(
              width: actionWidth,
              child: FilledButton.tonalIcon(
                onPressed: battle.canDefend() ? _useDefend : null,
                style: buttonStyle,
                icon: const Icon(Icons.shield_rounded),
                label: const Text('Defend'),
              ),
            ),
            SizedBox(
              width: actionWidth,
              child: FilledButton.tonalIcon(
                onPressed: battle.canAdvanceFrontline()
                    ? _advanceFrontline
                    : null,
                style: buttonStyle,
                icon: const Icon(Icons.trending_up_rounded),
                label: const Text('Advance'),
              ),
            ),
            SizedBox(
              width: actionWidth,
              child: FilledButton.tonalIcon(
                onPressed: battle.canUseGeneralAdvanceSkill()
                    ? _useGeneralAdvanceSkill
                    : null,
                style: buttonStyle,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Command'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _decisiveSignalSummary(BattleState battle, int playerId) {
    if (!battle.commanderAlive(playerId)) {
      return 'Commander lost';
    }
    final moraleState = battle.moraleStateForPlayer(playerId);
    if (moraleState == MoraleState.collapsed) {
      return 'Line broken';
    }
    if (moraleState == MoraleState.routing) {
      return 'Retreat risk';
    }
    if (!battle.hasAnyLegalMove(playerId)) {
      return 'Pinned in place';
    }
    return 'Line holding';
  }

  Future<void> _showBattleBriefSheet(BattleSession session) async {
    final battle = session.battleState;
    final recentBattleEvents = battle.eventLog.reversed
        .take(10)
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Battle Brief', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Condensed staff notes for command, morale, army traits, and the latest battlefield turns.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5E4D33),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Action Key', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 6),
                          const Text(
                            'Move pieces by selecting a unit and tapping a highlighted square.',
                          ),
                          const Text(
                            'Charge and Defend are one-time stances. Advance pushes the pawn line. Command is the general-led version.',
                          ),
                          const Text(
                            'Captures, lost commanders, and bad contact shift morale toward retreat or collapse.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _commandCard(session),
                  const SizedBox(height: 8),
                  _decisiveSignalsCard(session),
                  const SizedBox(height: 8),
                  _battleArmyCard(
                    'Attacker',
                    session.attackerStack.army,
                    session.attackerStack.ownerId,
                    battle,
                  ),
                  const SizedBox(height: 8),
                  _battleArmyCard(
                    'Defender',
                    session.defenderStack.army,
                    session.defenderStack.ownerId,
                    battle,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Turns',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          if (recentBattleEvents.isEmpty)
                            const Text('No battle events yet.')
                          else
                            for (final event in recentBattleEvents)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Text(
                                  '[T${event.turn}] ${event.description}',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moraleLine({
    required String label,
    required int morale,
    required MoraleState moraleState,
    required int maxMorale,
    required Color color,
    int trendDelta = 0,
  }) {
    final statusIcon = switch (moraleState) {
      MoraleState.steady => Icons.shield_rounded,
      MoraleState.wavering => Icons.remove_moderator_rounded,
      MoraleState.routing => Icons.logout_rounded,
      MoraleState.collapsed => Icons.warning_rounded,
    };
    final statusColor = switch (moraleState) {
      MoraleState.steady => const Color(0xFF2F6A55),
      MoraleState.wavering => const Color(0xFF5A6E49),
      MoraleState.routing => const Color(0xFF9D2D2D),
      MoraleState.collapsed => const Color(0xFF6F1A1A),
    };
    final statusLabel = switch (moraleState) {
      MoraleState.steady => 'Steady',
      MoraleState.wavering => 'Shaken',
      MoraleState.routing => 'Defection Risk',
      MoraleState.collapsed => 'Broken',
    };
    final trendIcon = switch (trendDelta.sign) {
      1 => Icons.trending_up_rounded,
      -1 => Icons.trending_down_rounded,
      _ => Icons.drag_handle_rounded,
    };
    final trendColor = switch (trendDelta.sign) {
      1 => const Color(0xFF2F6A55),
      -1 => const Color(0xFFAA2D2D),
      _ => const Color(0xFF6A7077),
    };
    final trendLabel = trendDelta > 0
        ? '+$trendDelta'
        : trendDelta < 0
        ? '$trendDelta'
        : '0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.26)),
        color: statusColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 86, child: Text(label)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: statusColor.withValues(alpha: 0.18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 2),
              Text(
                trendLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 2,
            runSpacing: 1,
            children: [
              for (var i = 0; i < maxMorale; i++)
                Icon(
                  i < morale ? Icons.shield_rounded : Icons.shield_outlined,
                  size: 15,
                  color: i < morale
                      ? color
                      : const Color(0xFFA44A4A).withValues(alpha: 0.64),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _latestMoraleDeltaForPlayer(BattleState battle, int playerId) {
    if (battle.eventLog.isEmpty) {
      return 0;
    }
    var latestTurn = 0;
    for (final event in battle.eventLog) {
      if (event.turn > latestTurn) {
        latestTurn = event.turn;
      }
    }
    if (latestTurn <= 0) {
      return 0;
    }

    var delta = 0;
    for (final event in battle.eventLog) {
      if (event.turn != latestTurn ||
          event.type != BattleEventType.moraleShift) {
        continue;
      }
      final eventDelta = event.delta ?? 0;
      if (eventDelta == 0) {
        continue;
      }
      if (event.targetPlayerId == playerId) {
        delta += eventDelta;
        continue;
      }
      if (event.actorPlayerId == playerId && event.targetPlayerId == null) {
        delta += eventDelta;
      }
    }
    return delta;
  }

  int _battleTurnCounter(BattleState battle) {
    var latestTurn = 0;
    for (final event in battle.eventLog) {
      if (event.turn > latestTurn) {
        latestTurn = event.turn;
      }
    }
    return latestTurn;
  }

  Widget _commandCard(BattleSession session) {
    final battle = session.battleState;
    final theme = Theme.of(context);
    final viewer = battle.activePlayer;
    final attackerLines = _visibleCommandProfiles(
      battle: battle,
      ownerId: session.attackerStack.ownerId,
      viewerId: viewer,
    );
    final defenderLines = _visibleCommandProfiles(
      battle: battle,
      ownerId: session.defenderStack.ownerId,
      viewerId: viewer,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Command', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'Player ${session.attackerStack.ownerId + 1}: ${attackerLines.join(' | ')}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Player ${session.defenderStack.ownerId + 1}: ${defenderLines.join(' | ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _decisiveSignalsCard(BattleSession session) {
    final battle = session.battleState;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decisive Signals', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            _decisiveSignalLine(battle, session.attackerStack.ownerId),
            const SizedBox(height: 4),
            _decisiveSignalLine(battle, session.defenderStack.ownerId),
          ],
        ),
      ),
    );
  }

  Widget _decisiveSignalLine(BattleState battle, int playerId) {
    final commanderAlive = battle.commanderAlive(playerId);
    final morale = battle.moraleForPlayer(playerId);
    final moraleState = battle.moraleStateForPlayer(playerId);
    final legalMoves = battle.hasAnyLegalMove(playerId);
    final danger =
        !commanderAlive ||
        moraleState == MoraleState.collapsed ||
        moraleState == MoraleState.routing ||
        !legalMoves;
    final color = danger ? const Color(0xFF9D2D2D) : const Color(0xFF2F6A55);
    final commanderText = commanderAlive ? 'Commander alive' : 'Commander lost';
    final mobilityText = legalMoves
        ? 'Legal moves available'
        : 'No legal moves';
    return Text(
      'Player ${playerId + 1}: $commanderText • Morale $morale (${moraleState.name}) • $mobilityText',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  Widget _battleArmyCard(
    String label,
    ArmyDefinition army,
    int ownerId,
    BattleState battle,
  ) {
    final theme = Theme.of(context);
    final activeViewer = battle.activePlayer;
    final perks = _visibleGeneralPerks(
      battle: battle,
      ownerId: ownerId,
      viewerId: activeViewer,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${army.label} | ${_armyTileSummary(army).replaceFirst('\n', ' | ')}',
            ),
            const SizedBox(height: 4),
            for (final perk in perks)
              Text('- $perk', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  List<String> _visibleGeneralPerks({
    required BattleState battle,
    required int ownerId,
    required int viewerId,
  }) {
    final generals = battle.generalsForSide(ownerId);
    if (generals.isEmpty) {
      return const <String>['No general remaining'];
    }
    final lines = <String>[];
    for (final general in generals) {
      final skill = general.generalSkill;
      if (skill == null) {
        continue;
      }
      final visible = ownerId == viewerId || skill.visibleToEnemy;
      if (!visible) {
        lines.add('General trait hidden');
        continue;
      }
      final profile = general.commandProfile;
      lines.add(
        '${profile.label} (${profile.skill.traitFamilyLabel}): ${profile.passive}',
      );
      if (ownerId == viewerId && profile.active.isNotEmpty) {
        lines.add('Active: ${profile.active}');
      }
    }
    return lines;
  }

  List<String> _visibleCommandProfiles({
    required BattleState battle,
    required int ownerId,
    required int viewerId,
  }) {
    final generals = battle.generalsForSide(ownerId);
    if (generals.isEmpty) {
      return const <String>['No commander'];
    }
    final lines = <String>[];
    for (final general in generals) {
      final skill = general.generalSkill;
      if (skill == null) {
        continue;
      }
      final visible = ownerId == viewerId || skill.visibleToEnemy;
      if (!visible) {
        lines.add('Hidden command profile');
        continue;
      }
      final profile = general.commandProfile;
      lines.add(
        '${profile.rank.publicLabel}/${profile.skill.publicLabel}'
        ' [${profile.skill.traitFamilyLabel}]',
      );
    }
    return lines;
  }

  ArmyStack? _selectedStack(WorldState world) {
    final selectedId = _selectedStackId;
    if (selectedId == null) {
      return null;
    }
    for (final stack in world.stacks) {
      if (stack.id == selectedId) {
        return stack;
      }
    }
    return null;
  }

  Widget _selectedStackCard({
    required WorldState world,
    required ArmyStack stack,
  }) {
    final theme = Theme.of(context);
    final round = world.round;
    final camp = _selectedCampForStack(world, stack);
    final selectedSettlement = _selectedSettlementForStack(world, stack);
    final fortifiedByCamp = _stackFortifiedByCamp(world, stack);
    final ownerFood = _foodForPlayer(world, stack.ownerId);
    final ownerCommand = _commandPointsForPlayer(world, stack.ownerId);
    final ownerProjection = _foodProjectionForPlayer(world, stack.ownerId);
    final stackSupply = _stackSupply(stack.id);
    final stackStarvation = _stackStarvation(stack.id);
    final stackWater = _stackWater(stack.id);
    final stackThirst = _stackThirst(stack.id);
    final enemyPressure = _enemyPressureAt(
      world,
      stack.position,
      stack.ownerId,
    );
    final nearbyAllies = world.stacks.where((candidate) {
      if (candidate.ownerId != stack.ownerId || candidate.id == stack.id) {
        return false;
      }
      return _manhattanDistance(candidate.position, stack.position) <= 1;
    }).length;
    final activePlayerId = world.activePlayerId;
    final tileOwnerLine = switch ((selectedSettlement, camp)) {
      (SettlementState settlement?, _) =>
        settlement.ownerId < 0
            ? 'Tile settlement is neutral.'
            : settlement.ownerId == stack.ownerId
            ? 'Tile settlement is held by this stack owner.'
            : 'Tile settlement is held by Player ${settlement.ownerId + 1}.',
      (_, CampState activeCamp?) =>
        activeCamp.ownerId == stack.ownerId
            ? 'Tile camp is controlled by this stack owner.'
            : 'Tile camp is controlled by Player ${activeCamp.ownerId + 1}.',
      _ => 'No settlement or camp on this tile.',
    };
    final ownershipContext = stack.ownerId == activePlayerId
        ? 'This is the active player stack. $tileOwnerLine'
        : 'This stack belongs to Player ${stack.ownerId + 1}. $tileOwnerLine';
    final pressureScore = _stackPressureScore(
      stack: stack,
      enemyPressure: enemyPressure,
      nearbyAllies: nearbyAllies,
      ownerFood: ownerFood,
      projection: ownerProjection,
      ownsSettlement:
          selectedSettlement != null &&
          selectedSettlement.ownerId == stack.ownerId,
      fortifiedByCamp: fortifiedByCamp,
      camp: camp,
    );
    final pressureLevel = _stackPressureLevel(pressureScore);
    final pressureColor = switch (pressureLevel) {
      'Low' => const Color(0xFF2F6A55),
      'Moderate' => const Color(0xFF8B6A21),
      _ => const Color(0xFF9D2D2D),
    };
    final moralePressure = _stackMoralePressureSummary(
      stack: stack,
      enemyPressure: enemyPressure,
      nearbyAllies: nearbyAllies,
      ownerFood: ownerFood,
      projection: ownerProjection,
      ownsSettlement:
          selectedSettlement != null &&
          selectedSettlement.ownerId == stack.ownerId,
      fortifiedByCamp: fortifiedByCamp,
      camp: camp,
    );
    final immediateEnemy = _adjacentEngagementTarget(world, stack);
    final statuses = <String>[
      if (camp != null) 'Camp ${_campPostureLabel(camp.posture)}',
      if (camp != null && camp.isOutpost) 'Outpost established',
      if (fortifiedByCamp) 'Fortified stance',
      if (stack.fatigue > 0) 'Fatigue ${stack.fatigue}',
      if (stack.forcedMarchRound == round) 'Forced this round',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Stack Intel',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: playerColor(stack.ownerId),
              ),
            ),
            const SizedBox(height: 4),
            Text('${stack.id} • ${stack.army.label}'),
            if (statuses.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Current state: ${statuses.join(' • ')}'),
            ],
            const SizedBox(height: 8),
            Text(
              'Ownership Context',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(ownershipContext),
            const SizedBox(height: 8),
            Text(
              'Supply Context',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Command $ownerCommand • Food $ownerFood • '
              'Projected food ${ownerProjection.projectedReserve} '
              '(income ${ownerProjection.settlementIncome + ownerProjection.campIncome + ownerProjection.fieldIncome}, upkeep ${ownerProjection.upkeep}).',
            ),
            const SizedBox(height: 2),
            Text(
              'Army supply $stackSupply (${_supplyStateLabel(stackSupply, stackStarvation)})'
              '${stackStarvation > 0 ? ' • Starvation $stackStarvation' : ''}.',
            ),
            const SizedBox(height: 2),
            Text(
              'Army water $stackWater (${_waterStateLabel(stackWater, stackThirst)})'
              '${stackThirst > 0 ? ' • Thirst $stackThirst' : ''}. '
              '${_waterAccessLabel(world, stack.position)}.',
            ),
            if (ownerProjection.shortageStacks > 0)
              Text(
                'Shortage warning: ${ownerProjection.shortageStacks} stack(s) may be unsupplied next upkeep.',
              ),
            const SizedBox(height: 8),
            Text(
              'Morale Pressure',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: pressureColor.withValues(alpha: 0.14),
                border: Border.all(
                  color: pressureColor.withValues(alpha: 0.34),
                ),
              ),
              child: Text(
                'Pressure $pressureLevel',
                style: TextStyle(
                  color: pressureColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(moralePressure),
            const SizedBox(height: 2),
            Text(
              immediateEnemy == null
                  ? 'No adjacent enemy engagement right now.'
                  : _immediateBattleContextLine(
                      world: world,
                      attacker: stack,
                      defender: immediateEnemy,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Command Context',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(_stackCommandContextSummary(stack.army)),
            const SizedBox(height: 4),
            Text(_armyRoleSummary(stack.army)),
          ],
        ),
      ),
    );
  }

  Widget _selectedArmyHudCard({
    required ArmyStack stack,
    required int activePlayerId,
    required _ProvinceInfo? province,
  }) {
    final ownerColor = playerColor(stack.ownerId);
    final onOwner = _contrastColor(ownerColor);
    final activeOwner = stack.ownerId == activePlayerId;
    final supply = _stackSupply(stack.id);
    final starvation = _stackStarvation(stack.id);
    final water = _stackWater(stack.id);
    final thirst = _stackThirst(stack.id);
    final supplyState = _supplyStateLabel(supply, starvation);
    final waterState = _waterStateLabel(water, thirst);
    final lineReport = _world == null
        ? const _SupplyLineReport(
            state: _SupplyLineState.isolated,
            path: <BoardPosition>[],
            distance: 99,
            dangerSteps: 0,
            anchor: null,
          )
        : _supplyLineReport(_world!, stack);
    final mergeTargets = _world == null
        ? const <ArmyStack>[]
        : _adjacentMergeTargets(_world!, stack);
    final immediateEnemy = _world == null
        ? null
        : _adjacentEngagementTarget(_world!, stack);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ownerColor,
                border: Border.all(color: ownerColor.withValues(alpha: 0.95)),
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Center(
                  child: Text(
                    '${stack.ownerId + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: onOwner,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected ${stack.id} (${stack.label}) • Player ${stack.ownerId + 1}'
                    '${activeOwner ? ' • Active Turn' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ownerColor.withValues(alpha: 0.96),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Units: ${_armyTileSummary(stack.army)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Supply: $supply ($supplyState)'
                    '${starvation > 0 ? ' • Starvation $starvation' : ''}',
                    style: TextStyle(
                      color: starvation >= 2
                          ? const Color(0xFF8C2E1F)
                          : const Color(0xFF28473E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Water: $water ($waterState)'
                    '${thirst > 0 ? ' • Thirst $thirst' : ''}',
                    style: TextStyle(
                      color: thirst >= 2
                          ? const Color(0xFF8C2E1F)
                          : const Color(0xFF225B73),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Line: ${lineReport.stateLabel}'
                    '${lineReport.anchor == null ? '' : ' via ${lineReport.anchor!.label}'}',
                    style: TextStyle(
                      color: switch (lineReport.state) {
                        _SupplyLineState.secure => const Color(0xFF295D46),
                        _SupplyLineState.stretched => const Color(0xFF8A6218),
                        _SupplyLineState.isolated => const Color(0xFF8E2E22),
                      },
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (province != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Province: ${province.name} • '
                      'Grain ${province.grainValue} • '
                      'Treasure ${province.wealthValue} • '
                      'Crossings ${province.crossings}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _provincePressureSummary(province),
                      style: TextStyle(
                        color: province.frontline || province.contested
                            ? const Color(0xFF8C2E1F)
                            : const Color(0xFF295D46),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'Command: ${mergeTargets.isEmpty ? 'No merge-ready wings' : '${mergeTargets.length} wing(s) ready to join columns'}'
                    '${immediateEnemy == null ? ' • No immediate clash' : ' • ${immediateEnemy.id} in striking distance'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ArmyStack? _adjacentEngagementTarget(WorldState world, ArmyStack stack) {
    final legalMoves = world.legalMovesForStack(stack.id);
    for (final move in legalMoves) {
      final occupant = world.stackAt(move);
      if (occupant != null && occupant.ownerId != stack.ownerId) {
        return occupant;
      }
    }
    return null;
  }

  String _immediateBattleContextLine({
    required WorldState world,
    required ArmyStack attacker,
    required ArmyStack defender,
  }) {
    final battleTile = world.tileAt(defender.position);
    final modifiers = _buildBattlefieldModifiers(
      world: world,
      battlefield: battleTile.battlefield,
      attacker: attacker,
      defender: defender,
      settlement: world.settlementAt(defender.position),
      camp: world.campAt(defender.position),
    );
    final notes = modifiers.attackerHint ?? 'No major fortification modifiers.';
    return 'If this stack attacks now: morale ${modifiers.attackerMorale} vs ${modifiers.defenderMorale}. $notes';
  }

  String _stackMoralePressureSummary({
    required ArmyStack stack,
    required int enemyPressure,
    required int nearbyAllies,
    required int ownerFood,
    required _FoodProjection projection,
    required bool ownsSettlement,
    required bool fortifiedByCamp,
    required CampState? camp,
  }) {
    final score = _stackPressureScore(
      stack: stack,
      enemyPressure: enemyPressure,
      nearbyAllies: nearbyAllies,
      ownerFood: ownerFood,
      projection: projection,
      ownsSettlement: ownsSettlement,
      fortifiedByCamp: fortifiedByCamp,
      camp: camp,
    );
    final drivers = <String>[];

    if (enemyPressure > 0) {
      drivers.add('$enemyPressure nearby enemy stack(s)');
    }
    if (stack.fatigue > 0) {
      drivers.add('fatigue ${stack.fatigue}');
    }
    if (_stackThirst(stack.id) > 0 || _stackWater(stack.id) <= 1) {
      drivers.add('water strain');
    }
    if (ownerFood <= 1) {
      drivers.add('low food reserve');
    }
    if (projection.shortageStacks > 0) {
      drivers.add('upkeep shortage risk');
    }
    if (ownsSettlement) {
      drivers.add('friendly settlement support');
    }
    if (fortifiedByCamp) {
      drivers.add('fortified camp support');
    } else if (camp != null && camp.ownerId == stack.ownerId) {
      drivers.add(
        '${_campPostureLabel(camp.posture).toLowerCase()} camp support',
      );
    }
    if (nearbyAllies > 0) {
      drivers.add('nearby allied support');
    }

    final level = _stackPressureLevel(score);
    final detail = drivers.isEmpty
        ? 'No immediate pressure drivers.'
        : drivers.join(', ');
    return '$level pressure. Drivers: $detail.';
  }

  int _stackPressureScore({
    required ArmyStack stack,
    required int enemyPressure,
    required int nearbyAllies,
    required int ownerFood,
    required _FoodProjection projection,
    required bool ownsSettlement,
    required bool fortifiedByCamp,
    required CampState? camp,
  }) {
    var score = 0;
    if (enemyPressure > 0) {
      score += enemyPressure >= 2 ? 3 : 2;
    }
    if (stack.fatigue > 0) {
      score += stack.fatigue;
    }
    if (_stackThirst(stack.id) > 0 || _stackWater(stack.id) <= 1) {
      score += 2;
    }
    if (ownerFood <= 1) {
      score += 1;
    }
    if (projection.shortageStacks > 0) {
      score += 1;
    }
    if (ownsSettlement) {
      score -= 1;
    }
    if (fortifiedByCamp) {
      score -= 2;
    } else if (camp != null && camp.ownerId == stack.ownerId) {
      score -= 1;
    }
    if (nearbyAllies > 0) {
      score -= 1;
    }
    return score;
  }

  String _stackPressureLevel(int score) {
    switch (score) {
      case <= 1:
        return 'Low';
      case <= 3:
        return 'Moderate';
      default:
        return 'High';
    }
  }

  String _stackCommandContextSummary(ArmyDefinition army) {
    final generals = army.units
        .where((unit) => unit.type == PieceType.general)
        .toList(growable: false);
    if (generals.isEmpty) {
      return 'No generals in this stack. Command resilience and surge options are limited.';
    }
    final traitCounts = <String, int>{};
    var massAdvanceReady = false;
    for (final general in generals) {
      final skill = general.generalSkill ?? GeneralSkill.fieldCommander;
      traitCounts.update(
        skill.traitFamilyLabel,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (skill.grantsMassAdvance) {
        massAdvanceReady = true;
      }
    }
    final traits = traitCounts.entries
        .map((entry) => '${entry.key} x${entry.value}')
        .join(', ');
    final surgeLine = massAdvanceReady
        ? 'At least one commander can trigger a major command surge.'
        : 'No major command surge trait detected.';
    return '${generals.length} general(s): $traits. $surgeLine';
  }

  String _armyTileSummary(ArmyDefinition army) {
    final comp = army.composition;
    final parts = <String>[];
    if (comp.pawns > 0) {
      parts.add('${comp.pawns} P');
    }
    if (comp.rooks > 0) {
      parts.add('${comp.rooks} R');
    }
    if (comp.knights > 0) {
      parts.add('${comp.knights} N');
    }
    if (comp.bishops > 0) {
      parts.add('${comp.bishops} B');
    }
    if (comp.generals > 0) {
      parts.add('${comp.generals} G');
    }
    return parts.isEmpty ? 'No units' : parts.join(', ');
  }

  String _armyRoleSummary(ArmyDefinition army) {
    final comp = army.composition;
    final commandMix = <String>[];
    if (comp.highKings > 0) {
      commandMix.add('${comp.highKings} high king');
    }
    final officers = comp.generals - comp.highKings;
    if (officers > 0) {
      commandMix.add('$officers officers');
    }
    if (comp.veteranGenerals > 0) {
      commandMix.add('${comp.veteranGenerals} veteran');
    }
    if (comp.rookieGenerals > 0) {
      commandMix.add('${comp.rookieGenerals} rookie');
    }
    final commandLine = commandMix.isEmpty
        ? 'no generals'
        : commandMix.join(', ');
    return 'Role guide: pawns hold the front; rooks control lines; knights jump; '
        'bishops control diagonals; generals command '
        '($commandLine).';
  }

  Widget _buildGameOverScreen(BuildContext context) {
    final world = _world;
    final summary = _matchOverSummary;
    final theme = Theme.of(context);
    final winnerId = summary?.winnerPlayerId;
    final winnerText = winnerId == null ? 'DRAW' : 'P${winnerId + 1} TRIUMPH';
    final accent = winnerId == null
        ? const Color(0xFF4C4F55)
        : playerColor(winnerId);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _confirmReturnToMenuOnBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('ChessWarss - ${widget.gameMode.label} End'),
        ),
        body: _screenBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedOpacity(
                    duration: _reduceEffects
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    opacity: _matchOverBannerVisible ? 1 : 0.15,
                    child: AnimatedScale(
                      duration: _reduceEffects
                          ? Duration.zero
                          : const Duration(milliseconds: 560),
                      curve: Curves.easeOutCubic,
                      scale: _matchOverBannerVisible ? 1 : 0.9,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                        winnerId == null
                                            ? Icons.balance_rounded
                                            : Icons.military_tech_rounded,
                                        color: accent,
                                      )
                                      .animate(onPlay: (c) => c.repeat())
                                      .shimmer(
                                        duration: 1200.ms,
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child:
                                        Text(
                                              winnerText,
                                              style: theme
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: accent,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1,
                                                  ),
                                            )
                                            .animate()
                                            .fadeIn(duration: 600.ms)
                                            .slideX(begin: 0.1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_status, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 10),
                              if (summary != null)
                                Text(
                                  'Decisive moment: ${summary.decisiveLine}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              if (summary != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Command swings ${summary.commandSkillsUsed} • '
                                  'Commanders eliminated ${summary.commandersEliminated} • '
                                  'Morale break victories ${summary.moraleCollapseVictories}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (summary.decisiveEvents.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      summary.decisiveEvents.first.replaceFirst(
                                        'Decisive: ',
                                        '',
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 8),
                              if (world != null)
                                Text(
                                  'Rounds played: ${world.round}\n'
                                  'Preset: ${_presetLabel(world.preset)}',
                                ),
                              const SizedBox(height: 14),
                              Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () =>
                                            _startMatch(forcedSeed: _seed),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Rematch'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _startMatch(),
                                        icon: const Icon(Icons.casino_rounded),
                                        label: const Text('New Match'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _backToSetup,
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                        ),
                                        label: const Text('Main Menu'),
                                      ),
                                    ],
                                  )
                                  .animate()
                                  .fadeIn(delay: 400.ms)
                                  .slideY(
                                    begin: 0.2,
                                    curve: Curves.easeOutBack,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _presetLabel(MapPreset preset) {
    switch (preset) {
      case MapPreset.greatField:
        return 'Great Field';
      case MapPreset.tightRavine:
        return 'Tight Ravine';
      case MapPreset.brokenGround:
        return 'Broken Ground';
      case MapPreset.riverlands:
        return 'Riverlands';
      case MapPreset.mountainPass:
        return 'Mountain Pass';
      case MapPreset.coastalCliffs:
        return 'Coastal Cliffs';
      case MapPreset.ancientRuins:
        return 'Ancient Ruins';
      case MapPreset.desertOasis:
        return 'Desert Oasis';
    }
  }

  String _presetSummary(MapPreset preset) {
    switch (preset) {
      case MapPreset.greatField:
        return 'Broad marching room and clean battle lines. Best baseline for reading formations and supply routes.';
      case MapPreset.tightRavine:
        return 'Constricted movement and brutal choke fights. Good for testing how much the square theater can be broken up.';
      case MapPreset.brokenGround:
        return 'Disrupted lanes and jagged approach paths. Useful when judging whether armies still read clearly in messy terrain.';
      case MapPreset.riverlands:
        return 'Closest to a Caesar-in-Gaul campaigning feel: crossings, riverbanks, and supply pressure around the water line.';
      case MapPreset.mountainPass:
        return 'Long, narrow advance with strong defensive leverage. Good for siege-road and baggage-train pressure.';
      case MapPreset.coastalCliffs:
        return 'Hard edges and exposed flanks. Best for testing whether line movement still feels intentional under severe terrain limits.';
      case MapPreset.ancientRuins:
        return 'Fragmented battlefield with anchor points and dead ground. Good for History Civilis-style positional clarity.';
      case MapPreset.desertOasis:
        return 'Water discipline above all. Best for stress-testing thirst, wells, and dangerous local forage.';
    }
  }
}

class _WorldTilePainter extends CustomPainter {
  const _WorldTilePainter({
    required this.northRiver,
    required this.southRiver,
    required this.eastRiver,
    required this.westRiver,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isBlocked,
    required this.glowColor,
    required this.animValue,
  });

  final RiverEdgeType? northRiver;
  final RiverEdgeType? southRiver;
  final RiverEdgeType? eastRiver;
  final RiverEdgeType? westRiver;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool isBlocked;
  final Color? glowColor;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _WorldHexMetrics.hexPathForRect(rect.deflate(1.2));

    if (glowColor != null) {
      canvas.drawShadow(path, glowColor!.withValues(alpha: 0.58), 7, false);
    }

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(const Color(0x18FFFFFF), fillColor),
          fillColor,
          Color.alphaBlend(const Color(0x22000000), fillColor),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (!isBlocked) {
      final washPaint = Paint()
        ..color = const Color(0x14FFF8E5)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, washPaint);

      _paintEdge(canvas, size, northRiver, _TileEdge.north);
      _paintEdge(canvas, size, southRiver, _TileEdge.south);
      _paintEdge(canvas, size, eastRiver, _TileEdge.east);
      _paintEdge(canvas, size, westRiver, _TileEdge.west);
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, borderPaint);
  }

  void _paintEdge(
    Canvas canvas,
    Size size,
    RiverEdgeType? river,
    _TileEdge edge,
  ) {
    if (river == null) {
      return;
    }

    final corners = _WorldHexMetrics.cornersForRect(Offset.zero & size);
    final isHorizontal = edge == _TileEdge.north || edge == _TileEdge.south;
    final stroke = math.max(6.0, size.shortestSide * 0.22);
    final bankStroke = stroke * 1.3;

    final (start, end) = switch (edge) {
      _TileEdge.north => (corners[5], corners[1]),
      _TileEdge.south => (corners[4], corners[2]),
      _TileEdge.east => (corners[1], corners[2]),
      _TileEdge.west => (corners[5], corners[4]),
    };

    // Draw Bank (Mud/Grass edge)
    final bankPaint = Paint()
      ..color = const Color(0xFF3D2B1F).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = bankStroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(start, end, bankPaint);

    // Draw Water with organic curve
    final waterPath = Path();
    waterPath.moveTo(start.dx, start.dy);

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final waveOffset = math.sin(animValue * 4 + (edge.index * 1.5)) * 3.0;

    if (isHorizontal) {
      waterPath.quadraticBezierTo(mid.dx, mid.dy + waveOffset, end.dx, end.dy);
    } else {
      waterPath.quadraticBezierTo(mid.dx + waveOffset, mid.dy, end.dx, end.dy);
    }

    final riverPaint = Paint()
      ..shader = LinearGradient(
        begin: isHorizontal ? Alignment.topCenter : Alignment.centerLeft,
        end: isHorizontal ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [
          const Color(0xFF2E5A88),
          const Color(0xFF4E89AE),
          const Color(0xFF2E5A88),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(waterPath, riverPaint);

    // Highlight/Ripples
    if (river == RiverEdgeType.river) {
      final ripplePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < 3; i++) {
        final phase = (animValue + (i * 0.33)) % 1.0;
        final ripplePos = phase * size.shortestSide;

        if (isHorizontal) {
          canvas.drawLine(
            Offset(ripplePos, start.dy - 2),
            Offset(ripplePos + 12, start.dy - 2),
            ripplePaint,
          );
        } else {
          canvas.drawLine(
            Offset(start.dx - 2, ripplePos),
            Offset(start.dx - 2, ripplePos + 12),
            ripplePaint,
          );
        }
      }
    }

    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke * 0.6;

    switch (river) {
      case RiverEdgeType.river:
        break;
      case RiverEdgeType.ford:
        accentPaint.color = const Color(0xFFC2B280);
        accentPaint.strokeWidth = stroke * 0.8;
        _drawCrossing(canvas, center, isHorizontal, stroke, accentPaint);
      case RiverEdgeType.bridge:
        accentPaint.color = const Color(0xFF4A3728);
        accentPaint.strokeWidth = stroke * 1.1;
        _drawCrossing(
          canvas,
          center,
          isHorizontal,
          stroke,
          accentPaint,
          isBridge: true,
        );
    }
  }

  void _drawCrossing(
    Canvas canvas,
    Offset center,
    bool isHorizontal,
    double stroke,
    Paint paint, {
    bool isBridge = false,
  }) {
    if (isHorizontal) {
      canvas.drawLine(
        Offset(center.dx - stroke, center.dy),
        Offset(center.dx + stroke, center.dy),
        paint,
      );
      if (isBridge) {
        // Railings
        final railPaint = Paint()
          ..color = Colors.black26
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(center.dx - stroke, center.dy - 4),
          Offset(center.dx + stroke, center.dy - 4),
          railPaint,
        );
        canvas.drawLine(
          Offset(center.dx - stroke, center.dy + 4),
          Offset(center.dx + stroke, center.dy + 4),
          railPaint,
        );
      }
    } else {
      canvas.drawLine(
        Offset(center.dx, center.dy - stroke),
        Offset(center.dx, center.dy + stroke),
        paint,
      );
      if (isBridge) {
        final railPaint = Paint()
          ..color = Colors.black26
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(center.dx - 4, center.dy - stroke),
          Offset(center.dx - 4, center.dy + stroke),
          railPaint,
        );
        canvas.drawLine(
          Offset(center.dx + 4, center.dy - stroke),
          Offset(center.dx + 4, center.dy + stroke),
          railPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldTilePainter oldDelegate) {
    return northRiver != oldDelegate.northRiver ||
        southRiver != oldDelegate.southRiver ||
        eastRiver != oldDelegate.eastRiver ||
        westRiver != oldDelegate.westRiver ||
        fillColor != oldDelegate.fillColor ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth ||
        isBlocked != oldDelegate.isBlocked ||
        glowColor != oldDelegate.glowColor ||
        animValue != oldDelegate.animValue;
  }
}

class _WorldCampaignOverlayPainter extends CustomPainter {
  const _WorldCampaignOverlayPainter({
    required this.world,
    required this.provinces,
    required this.provinceByPosition,
    required this.territoryByPosition,
    required this.selectedSupplyLine,
    required this.highlightedOwnerId,
    required this.highlightedProvinceId,
    required this.highlightedMove,
    required this.hexMetrics,
    required this.reduceEffects,
  });

  final WorldState world;
  final List<_ProvinceInfo> provinces;
  final Map<BoardPosition, _ProvinceInfo> provinceByPosition;
  final Map<BoardPosition, _TerritoryTileStatus> territoryByPosition;
  final List<BoardPosition> selectedSupplyLine;
  final int? highlightedOwnerId;
  final String? highlightedProvinceId;
  final _WorldMoveMarker? highlightedMove;
  final _WorldHexMetrics hexMetrics;
  final bool reduceEffects;

  @override
  void paint(Canvas canvas, Size size) {
    if (world.size <= 0) {
      return;
    }

    final parchmentBands = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x0FFAF3E3), Color(0x00F2E2BF), Color(0x12D6B98B)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, parchmentBands);

    final contourPaint = Paint()
      ..color = const Color(0xFF7D6A4C).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var row = 0; row < world.size + 1; row++) {
      final y = ((row + 0.4) / (world.size + 1)) * size.height;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(
          size.width * 0.33,
          y + ((row.isEven ? 1 : -1) * size.height * 0.035),
          size.width,
          y,
        );
      canvas.drawPath(path, contourPaint);
    }

    final provinceGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFC49434).withValues(alpha: 0.12);
    final provinceBorderPaint = Paint()
      ..color = const Color(0xFF5E4121).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final provinceHighlightPaint = Paint()
      ..color = const Color(0xFFC49434).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (final province in provinces) {
      if (province.tiles.isEmpty) {
        continue;
      }
      final isHighlighted = province.id == highlightedProvinceId;
      for (final tile in province.tiles) {
        final path = _WorldHexMetrics.hexPathForRect(
          hexMetrics.tileRect(tile).deflate(3),
        );
        if (isHighlighted) {
          canvas.drawPath(path, provinceGlowPaint);
        }
        canvas.drawPath(
          path,
          isHighlighted ? provinceHighlightPaint : provinceBorderPaint,
        );
      }
    }

    for (final province in provinces) {
      if (province.tiles.isEmpty) {
        continue;
      }
      final centers = province.tiles
          .map(hexMetrics.centerFor)
          .toList(growable: false);
      final anchor = Offset(
        centers.fold<double>(0, (sum, point) => sum + point.dx) /
            centers.length,
        centers.fold<double>(0, (sum, point) => sum + point.dy) /
            centers.length,
      );
      final labelColor = province.frontline || province.contested
          ? const Color(0xFF6E2318)
          : const Color(0xFF5A472E);
      final textPainter = TextPainter(
        text: TextSpan(
          text: province.name.toUpperCase(),
          style: TextStyle(
            color: labelColor.withValues(
              alpha: province.id == highlightedProvinceId ? 0.9 : 0.68,
            ),
            fontSize: math.max(9, hexMetrics.radius * 0.34),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: hexMetrics.tileWidth * 1.8);
      textPainter.paint(
        canvas,
        Offset(
          anchor.dx - textPainter.width / 2,
          anchor.dy - textPainter.height / 2,
        ),
      );
    }

    if (selectedSupplyLine.length >= 2) {
      final routePoints = selectedSupplyLine
          .map(hexMetrics.centerFor)
          .toList(growable: false);
      final routePath = Path()
        ..moveTo(routePoints.first.dx, routePoints.first.dy);
      for (var i = 1; i < routePoints.length; i++) {
        final previous = routePoints[i - 1];
        final current = routePoints[i];
        final mid = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        routePath.quadraticBezierTo(mid.dx, mid.dy, current.dx, current.dy);
      }

      if (!reduceEffects) {
        final glow = Paint()
          ..color = const Color(0xFFB27E22).withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(routePath, glow);
      }

      final routePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF5D488), Color(0xFFB97F24)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = reduceEffects ? 2.3 : 3.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(routePath, routePaint);

      final start = routePoints.first;
      final end = routePoints.last;
      final markerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF8B2420).withValues(alpha: 0.92);
      canvas.drawCircle(start, 4.5, markerPaint);
      canvas.drawCircle(
        end,
        4.5,
        Paint()..color = const Color(0xFF305A44).withValues(alpha: 0.92),
      );
    }

    if (highlightedMove != null) {
      final start = hexMetrics.centerFor(highlightedMove!.from);
      final end = hexMetrics.centerFor(highlightedMove!.to);
      final control = Offset(
        (start.dx + end.dx) / 2,
        math.min(start.dy, end.dy) - (hexMetrics.radius * 0.7),
      );
      final movePath = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      if (!reduceEffects) {
        final shadowPaint = Paint()
          ..color = const Color(0xFF2C1A10).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(movePath, shadowPaint);
      }
      final movePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8C6C1E), Color(0xFFA53224)],
        ).createShader(Rect.fromPoints(start, end))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(movePath, movePaint);
      final arrowPaint = Paint()
        ..color = const Color(0xFFA53224)
        ..style = PaintingStyle.fill;
      final angle = math.atan2(end.dy - control.dy, end.dx - control.dx);
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx - 11 * math.cos(angle - 0.35),
          end.dy - 11 * math.sin(angle - 0.35),
        )
        ..lineTo(
          end.dx - 11 * math.cos(angle + 0.35),
          end.dy - 11 * math.sin(angle + 0.35),
        )
        ..close();
      canvas.drawPath(arrow, arrowPaint);
    }

    if (highlightedOwnerId != null) {
      final crestPaint = Paint()
        ..color = playerColor(highlightedOwnerId!).withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      final crestPath = Path()
        ..moveTo(size.width * 0.06, size.height * 0.12)
        ..lineTo(size.width * 0.2, size.height * 0.08)
        ..lineTo(size.width * 0.26, size.height * 0.22)
        ..lineTo(size.width * 0.12, size.height * 0.26)
        ..close();
      canvas.drawPath(crestPath, crestPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldCampaignOverlayPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.highlightedOwnerId != highlightedOwnerId ||
        oldDelegate.highlightedProvinceId != highlightedProvinceId ||
        oldDelegate.highlightedMove != highlightedMove ||
        oldDelegate.hexMetrics != hexMetrics ||
        oldDelegate.reduceEffects != reduceEffects ||
        oldDelegate.provinces.length != provinces.length ||
        oldDelegate.provinceByPosition.length != provinceByPosition.length ||
        oldDelegate.selectedSupplyLine.length != selectedSupplyLine.length ||
        oldDelegate.territoryByPosition.length != territoryByPosition.length;
  }
}

enum _TileEdge { north, south, east, west }
