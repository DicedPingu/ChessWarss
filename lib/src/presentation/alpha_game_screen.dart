import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/ai.dart';
import '../domain/army.dart';
import '../domain/battle_session.dart';
import '../domain/battle_state.dart';
import '../domain/board_position.dart';
import '../domain/piece.dart';
import '../domain/world.dart';
import '../domain/world_generator.dart';
import 'player_colors.dart';
import 'widgets/battle_board_widget.dart';

enum _GamePhase { setup, world, battle, gameOver }

class AlphaGameScreen extends StatefulWidget {
  const AlphaGameScreen({super.key});

  @override
  State<AlphaGameScreen> createState() => _AlphaGameScreenState();
}

class _AlphaGameScreenState extends State<AlphaGameScreen> {
  static const Duration _aiWorldThinkDelay = Duration(milliseconds: 900);
  static const Duration _aiWorldActionDelay = Duration(milliseconds: 750);
  static const Duration _aiBattleThinkDelay = Duration(milliseconds: 750);
  static const Duration _aiBattleActionDelay = Duration(milliseconds: 650);

  final WorldGenerator _worldGenerator = const WorldGenerator();
  final StrategicAi _strategicAi = const StrategicAi();
  final BattleAi _battleAi = const BattleAi();
  final TextEditingController _seedController = TextEditingController();

  _GamePhase _phase = _GamePhase.setup;

  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  int _playerCount = 2;
  MapPreset _mapPreset = MapPreset.greatField;
  final List<PlayerType> _playerTypes = [
    PlayerType.human,
    PlayerType.ai,
    PlayerType.ai,
    PlayerType.ai,
  ];

  WorldState? _world;
  BattleSession? _battle;

  String _status = 'Configure and start a match.';

  String? _selectedStackId;
  Set<BoardPosition> _worldLegalMoves = const <BoardPosition>{};

  String? _selectedBattlePieceId;
  Set<BoardPosition> _battleLegalMoves = const <BoardPosition>{};

  bool _aiBusy = false;
  bool get _reduceEffects => defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    _seedController.text = '$_seed';
  }

  int _effectiveSeed([int? forcedSeed]) {
    if (forcedSeed != null) {
      return forcedSeed & 0x7fffffff;
    }
    final parsed = int.tryParse(_seedController.text.trim());
    if (parsed != null) {
      return parsed & 0x7fffffff;
    }
    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  }

  void _startMatch({int? forcedSeed}) {
    final seed = _effectiveSeed(forcedSeed);
    final playerTypes = _playerTypes.take(_playerCount).toList();

    final world = _worldGenerator.create(
      playerCount: _playerCount,
      playerTypes: playerTypes,
      preset: _mapPreset,
      seed: seed,
    );

    setState(() {
      _phase = _GamePhase.world;
      _seed = seed;
      _world = world;
      _battle = null;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _aiBusy = false;
      _status =
          'Round ${world.round}: ${world.players[world.activePlayerIndex].name} turn.';
    });
    _seedController.text = '$seed';

    _triggerAiTurnIfNeeded();
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  void _backToSetup() {
    setState(() {
      _phase = _GamePhase.setup;
      _world = null;
      _battle = null;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _aiBusy = false;
      _status = 'Configure and start a match.';
    });
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
      final activeId = _world!.activePlayerId;
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
    final move = _strategicAi.chooseMove(world, world.activePlayerId, _seed);

    if (move == null) {
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
        _status = 'AI triggered a command skill.';
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

    final action = _battleAi.chooseMove(session.battleState, _seed);

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
      _status = 'AI is considering ${action.pieceId}...';
    });

    await Future<void>.delayed(_aiBattleActionDelay);

    if (!mounted || _phase != _GamePhase.battle || _battle == null) {
      _aiBusy = false;
      return;
    }

    _aiBusy = false;
    _executeBattleMove(action, fromAi: true);
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

    if (_selectedStackId != null && _worldLegalMoves.contains(position)) {
      unawaited(
        _executeWorldMove(WorldMove(stackId: _selectedStackId!, to: position)),
      );
      return;
    }

    if (tappedStack != null && tappedStack.ownerId == activePlayer) {
      setState(() {
        _selectedStackId = tappedStack.id;
        _worldLegalMoves = world.legalMovesForStack(tappedStack.id).toSet();
        _status =
            '${tappedStack.id} selected. ${_armyPlainSummary(tappedStack.army)}';
      });
      return;
    }

    setState(() {
      _selectedStackId = null;
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

    _advanceWorldTurn('Player ${activeId + 1} passed.');
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

    final legal = world.legalMovesForStack(stack.id);
    if (!legal.contains(move.to)) {
      if (fromAi) {
        _triggerAiTurnIfNeeded();
      }
      return;
    }

    final occupant = world.stackAt(move.to);
    if (occupant != null && occupant.ownerId != stack.ownerId) {
      final activePlayerType = _playerTypeById(world.activePlayerId);
      final recommendedFormation = _recommendedFormationForBattle(
        attacker: stack.army,
        defender: occupant.army,
      );
      final tile = world.tileAt(move.to);
      final deploymentOptions = BattleState.generateDeploymentPlans(
        southArmy: stack.army,
        northArmy: occupant.army,
        southOwnerId: stack.ownerId,
        northOwnerId: occupant.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
        preferredFormation: recommendedFormation,
      );
      setState(() {
        _aiBusy = true;
        _status = activePlayerType == PlayerType.human
            ? 'Engagement detected. Choose deployment doctrine.'
            : 'AI is choosing deployment doctrine...';
      });

      final selectedPlan = await _selectDeploymentPlan(
        attacker: stack,
        defender: occupant,
        activePlayerType: activePlayerType,
        battlePosition: move.to,
        options: deploymentOptions,
        recommendedFormation: recommendedFormation,
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

      if (selectedPlan == null) {
        setState(() {
          _aiBusy = false;
          _status = 'Battle setup canceled.';
        });
        return;
      }

      final battleState = BattleState.fromDeploymentPlan(
        plan: selectedPlan,
        southOwnerId: stack.ownerId,
        northOwnerId: occupant.ownerId,
        rows: tile.battlefield.rows,
        cols: tile.battlefield.cols,
        blockedCells: tile.battlefield.blocked,
      );

      setState(() {
        _phase = _GamePhase.battle;
        _battle = BattleSession(
          attackerStack: stack,
          defenderStack: occupant,
          battleState: battleState,
          battlefield: tile.battlefield,
        );
        _selectedStackId = null;
        _worldLegalMoves = const <BoardPosition>{};
        _selectedBattlePieceId = null;
        _battleLegalMoves = const <BoardPosition>{};
        _aiBusy = false;
        _status =
            'Battle started at (${move.to.row},${move.to.col}) on ${tile.battlefield.notation} (${selectedPlan.label}).';
      });

      _triggerAiTurnIfNeeded();
      return;
    }

    final updatedStacks = world.stacks
        .map(
          (item) =>
              item.id == stack.id ? item.copyWith(position: move.to) : item,
        )
        .toList();

    final actor = fromAi ? 'AI' : 'Player ${stack.ownerId + 1}';
    final updatedWorld = world.copyWith(
      stacks: updatedStacks,
      log: [
        ...world.log,
        '$actor moved ${stack.id} to (${move.to.row},${move.to.col}).',
      ],
    );

    setState(() {
      _world = updatedWorld;
      _selectedStackId = null;
      _worldLegalMoves = const <BoardPosition>{};
    });

    _advanceWorldTurn();
  }

  void _advanceWorldTurn([String? additionalLog]) {
    final world = _world;
    if (world == null) {
      return;
    }

    var updatedWorld = world;
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
      setState(() {
        _world = updatedWorld;
        _phase = _GamePhase.gameOver;
        _status = winner == null
            ? 'Draw: all armies eliminated.'
            : 'Player ${winner + 1} wins the match.';
      });
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
      updatedWorld = _applyRoundLevy(updatedWorld);
    }

    setState(() {
      _world = updatedWorld;
      _status =
          'Round ${updatedWorld.round}: ${updatedWorld.players[nextIndex].name} turn.';
    });

    _triggerAiTurnIfNeeded();
  }

  WorldState _applyRoundLevy(WorldState world) {
    if (world.round.isOdd) {
      return world;
    }

    final stacks = List<ArmyStack>.from(world.stacks);
    final log = List<String>.from(world.log);

    for (final player in world.players) {
      final owned = <ArmyStack>[];
      for (final stack in stacks) {
        if (stack.ownerId == player.id) {
          owned.add(stack);
        }
      }
      if (owned.isEmpty) {
        continue;
      }

      ArmyStack target = owned.first;
      for (final candidate in owned) {
        final targetHome = _isHomeTerritory(
          playerId: player.id,
          position: target.position,
          size: world.size,
        );
        final candidateHome = _isHomeTerritory(
          playerId: player.id,
          position: candidate.position,
          size: world.size,
        );
        if (!targetHome && candidateHome) {
          target = candidate;
        }
      }

      final pawnCount = target.army.countType(PieceType.pawn);
      if (pawnCount >= 8) {
        continue;
      }

      final index = stacks.indexWhere((stack) => stack.id == target.id);
      if (index < 0) {
        continue;
      }

      final updatedArmy = target.army.copyWith(
        units: [
          ...target.army.units,
          const ArmyUnit(type: PieceType.pawn, title: 'Levy Infantry'),
        ],
      );
      stacks[index] = target.copyWith(army: updatedArmy);
      log.add(
        'Round ${world.round}: ${player.name} levied 1 pawn into ${target.id} from home territory.',
      );
    }

    return world.copyWith(stacks: stacks, log: log);
  }

  bool _isHomeTerritory({
    required int playerId,
    required BoardPosition position,
    required int size,
  }) {
    switch (playerId) {
      case 0:
        return position.row >= size - 2;
      case 1:
        return position.row <= 1;
      case 2:
        return position.col <= 1;
      case 3:
        return position.col >= size - 2;
      default:
        return false;
    }
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
      _status = fromAi
          ? 'AI played ${action.pieceId}.'
          : 'Move executed on battle board.';
    });

    _resolveBattleProgress();
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
      _status = fromAi
          ? 'AI advanced the frontline.'
          : 'Frontline advance executed.';
    });

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
      _status = fromAi
          ? 'AI used a general command skill.'
          : 'General command skill activated.';
    });

    _resolveBattleProgress();
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
      _finishBattle(
        winner,
        'Commander eliminated, morale collapsed, or no legal moves.',
      );
      return;
    }

    setState(() {
      _status =
          'Battle turn: Player ${session.battleState.activePlayer + 1} to move.';
    });

    _triggerAiTurnIfNeeded();
  }

  void _finishBattle(int winnerPlayerId, String reason) {
    final world = _world;
    final session = _battle;
    if (world == null || session == null) {
      return;
    }

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

    if (winnerPlayerId == session.attackerStack.ownerId) {
      stacks.add(
        session.attackerStack.copyWith(
          army: survivorArmy,
          position: session.defenderStack.position,
        ),
      );
    } else {
      stacks.add(
        session.defenderStack.copyWith(
          army: survivorArmy,
          position: session.defenderStack.position,
        ),
      );
    }

    final updatedWorld = world.copyWith(
      stacks: stacks,
      log: [
        ...world.log,
        'Battle resolved: Player ${winnerPlayerId + 1} won (${reason.toLowerCase()}).',
      ],
    );

    setState(() {
      _phase = _GamePhase.world;
      _world = updatedWorld;
      _battle = null;
      _selectedBattlePieceId = null;
      _battleLegalMoves = const <BoardPosition>{};
      _status = 'Battle ended. Returning to world map.';
    });

    _advanceWorldTurn();
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
      duration: _reduceEffects
          ? Duration.zero
          : const Duration(milliseconds: 380),
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
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3A5C51).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
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

  BattleDeploymentPlan _recommendedPlan(
    List<BattleDeploymentPlan> options,
    BattleFormation recommendedFormation,
  ) {
    for (final option in options) {
      if (option.formation == recommendedFormation) {
        return option;
      }
    }
    return options.first;
  }

  Future<BattleDeploymentPlan?> _selectDeploymentPlan({
    required ArmyStack attacker,
    required ArmyStack defender,
    required PlayerType activePlayerType,
    required BoardPosition battlePosition,
    required List<BattleDeploymentPlan> options,
    required BattleFormation recommendedFormation,
  }) async {
    final recommended = _recommendedPlan(options, recommendedFormation);

    if (activePlayerType == PlayerType.ai) {
      return recommended;
    }

    return showDialog<BattleDeploymentPlan>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Choose Deployment Doctrine'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battle at ${battlePosition.row},${battlePosition.col} '
                  'against ${defender.label}.',
                  style: theme.textTheme.bodySmall,
                ),
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
                                  Text(
                                    option.label,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(width: 8),
                                  if (option.id == recommended.id)
                                    const Chip(
                                      label: Text('Recommended'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(option.summary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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

  Widget _buildSetupScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ChessWarss Alpha Setup')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: FilledButton.icon(
            onPressed: _startMatch,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Deploy Alpha Match'),
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
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'War Council',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set commanders and terrain before deploying. Doctrine is chosen right before each battle.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              Chip(label: Text('5x5 World')),
                              Chip(label: Text('3 Armies / Player')),
                              Chip(label: Text('Collision => Tactical Battle')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: _playerCount,
                            decoration: const InputDecoration(
                              labelText: 'Players',
                            ),
                            items: const [
                              DropdownMenuItem(value: 2, child: Text('2')),
                              DropdownMenuItem(value: 3, child: Text('3')),
                              DropdownMenuItem(value: 4, child: Text('4')),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _playerCount = value;
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
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _seedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Seed (optional)',
                              hintText: 'Leave empty for random',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 14),
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'Deployment phase:\n'
                                '- Each engagement generates 1-3 legal deployment doctrines.\n'
                                '- AI commanders auto-pick the recommended doctrine.\n'
                                '- Opening captures are blocked on first move.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'Levy phase:\n'
                                '- Every 2 rounds, each commander may raise 1 pawn.\n'
                                '- Levies prefer stacks stationed in home territory.\n'
                                '- This models periodic reinforcements, not instant spawning mid-battle.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Player Control',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
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
    );
  }

  Widget _buildWorldScreen(BuildContext context) {
    final world = _world!;
    final activePlayer = world.players[world.activePlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessWarss Alpha - World Map'),
        actions: [
          TextButton.icon(
            onPressed: _backToSetup,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
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
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildWorldBoard(world)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildWorldSidebar(world, activePlayer),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(flex: 5, child: _buildWorldBoard(world)),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 4,
                      child: _buildWorldSidebar(world, activePlayer),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorldBoard(WorldState world) {
    final stackByPosition = <BoardPosition, ArmyStack>{
      for (final stack in world.stacks) stack.position: stack,
    };
    final selectedStackId = _selectedStackId;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round ${world.round} | Active: ${world.players[world.activePlayerIndex].name}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Preset: ${_presetLabel(world.preset)}')),
                const Chip(label: Text('Doctrine: Chosen on Engagement')),
                Chip(label: Text('Seed ${world.seed}')),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8A7652)),
                    boxShadow: _reduceEffects
                        ? const []
                        : const [
                            BoxShadow(
                              blurRadius: 12,
                              offset: Offset(0, 4),
                              color: Color(0x22000000),
                            ),
                          ],
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF7EEDB), Color(0xFFE4D3B1)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: world.size * world.size,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: world.size,
                              ),
                          itemBuilder: (context, index) {
                            final row = index ~/ world.size;
                            final col = index % world.size;
                            final position = BoardPosition(row, col);
                            final tile = world.tiles[index];
                            final stack = stackByPosition[position];

                            final isBlocked =
                                tile.terrain == TerrainType.blocked;
                            final isSelected =
                                stack != null && stack.id == selectedStackId;
                            final isLegalMove = _worldLegalMoves.contains(
                              position,
                            );
                            final color = _worldTileColor(
                              row: row,
                              col: col,
                              isBlocked: isBlocked,
                              isSelected: isSelected,
                              isLegalMove: isLegalMove,
                            );

                            return InkWell(
                              onTap: isBlocked
                                  ? null
                                  : () => _onWorldTileTap(position),
                              child: AnimatedContainer(
                                duration: _reduceEffects
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: stack == null
                                    ? (isLegalMove
                                          ? Center(
                                              child: Container(
                                                width: 15,
                                                height: 15,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2F5D4E,
                                                  ).withValues(alpha: 0.42),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink())
                                    : Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: const EdgeInsets.all(3),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'P${stack.ownerId + 1} ${stack.label}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: playerColor(
                                                      stack.ownerId,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _armyTileSummary(stack.army),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    height: 1.08,
                                                    color: playerColor(
                                                      stack.ownerId,
                                                    ).withValues(alpha: 0.95),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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
              ),
            ),
            const SizedBox(height: 8),
            _statusChip(_status),
          ],
        ),
      ),
    );
  }

  Color _worldTileColor({
    required int row,
    required int col,
    required bool isBlocked,
    required bool isSelected,
    required bool isLegalMove,
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
    return (row + col).isEven
        ? const Color(0xFFE8D7B8)
        : const Color(0xFFD8BD90);
  }

  Widget _buildWorldSidebar(WorldState world, PlayerSlot activePlayer) {
    final activeIsAi = activePlayer.type == PlayerType.ai;
    final selectedStack = _selectedStack(world);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: activeIsAi || _aiBusy ? null : _passWorldTurn,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Pass Turn'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _backToSetup,
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    label: const Text('Back to Setup'),
                  ),
                ],
              ),
            ),
          ),
          if (selectedStack != null) ...[
            const SizedBox(height: 12),
            _selectedStackCard(selectedStack),
          ],
          const SizedBox(height: 12),
          Text('Commanders', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final player in world.players)
            _playerSummaryCard(
              player: player,
              stacks: world.stacksForPlayer(player.id),
              isActive: player.id == world.activePlayerId,
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent World Log', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 140,
                    child: ListView(
                      children: world.log.reversed
                          .take(10)
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text(entry),
                            ),
                          )
                          .toList(),
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

  Widget _playerSummaryCard({
    required PlayerSlot player,
    required List<ArmyStack> stacks,
    required bool isActive,
  }) {
    final accent = playerColor(player.id);
    return Card(
      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.name} (${player.type.name.toUpperCase()})${isActive ? ' • ACTIVE' : ''}',
              style: TextStyle(fontWeight: FontWeight.bold, color: accent),
            ),
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
                  '${stack.id}: (${stack.position.row},${stack.position.col}) '
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessWarss Alpha - Battle'),
        actions: [
          TextButton.icon(
            onPressed: _backToSetup,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
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
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildBattleBoardCard(session)),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildBattleSidebar(session)),
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
          _playerTypeById(battle.activePlayer) == PlayerType.ai
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final action = _battleAi.chooseMove(battle, _seed);
                if (action != null) {
                  _executeBattleMove(action);
                }
              },
              icon: const Icon(Icons.tips_and_updates_outlined),
              label: const Text('Hint Move'),
            ),
    );
  }

  Widget _buildBattleBoardCard(BattleSession session) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battlefield ${session.battlefield.notation}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RepaintBoundary(
                child: BattleBoardWidget(
                  state: session.battleState,
                  selectedPieceId: _selectedBattlePieceId,
                  legalMoves: _battleLegalMoves,
                  onTapSquare: _onBattleTileTap,
                  reduceEffects: _reduceEffects,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _statusChip(_status),
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Active side: Player ${battle.activePlayer + 1} (${activeType.name.toUpperCase()})',
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
                    morale: battle.moraleForPlayer(
                      session.attackerStack.ownerId,
                    ),
                    maxMorale: battle.maxMorale,
                    color: playerColor(session.attackerStack.ownerId),
                  ),
                  const SizedBox(height: 4),
                  _moraleLine(
                    label: 'Player ${session.defenderStack.ownerId + 1}',
                    morale: battle.moraleForPlayer(
                      session.defenderStack.ownerId,
                    ),
                    maxMorale: battle.maxMorale,
                    color: playerColor(session.defenderStack.ownerId),
                  ),
                ],
              ),
            ),
          ),
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
                      onPressed: battle.canAdvanceFrontline()
                          ? () => _advanceFrontline()
                          : null,
                      icon: const Icon(Icons.trending_up_rounded),
                      label: const Text('Advance Line'),
                    ),
                    FilledButton.icon(
                      onPressed: battle.canUseGeneralAdvanceSkill()
                          ? () => _useGeneralAdvanceSkill()
                          : null,
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('General Skill'),
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
                  Text('Battle Replay', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 170,
                    child: ListView(
                      children: battle.eventLog.reversed
                          .take(10)
                          .map(
                            (event) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text(
                                '[T${event.turn}] ${event.description}',
                              ),
                            ),
                          )
                          .toList(),
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
              child: Text(
                'Battle Rules:\n'
                '- Pawns move forward 1; from starting row they may move 2 if clear.\n'
                '- Generals are king-like (1-step in all directions).\n'
                '- Morale drops with losses; 0 morale means collapse.\n'
                '- Fragile generals may trigger panic retreat when threatened.\n'
                '- Veteran/War Drummer generals can trigger stronger advance skills.\n'
                '- Lose all generals or morale => lose battle.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moraleLine({
    required String label,
    required int morale,
    required int maxMorale,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        for (var i = 0; i < maxMorale; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              i < morale
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 15,
              color: i < morale ? color : color.withValues(alpha: 0.35),
            ),
          ),
      ],
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
      lines.add('${skill.publicLabel}: ${skill.perkDescription}');
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

  Widget _selectedStackCard(ArmyStack stack) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: ${stack.id}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: playerColor(stack.ownerId),
              ),
            ),
            const SizedBox(height: 4),
            Text('Army: ${stack.army.label}'),
            const SizedBox(height: 4),
            Text(_armyTileSummary(stack.army)),
            const SizedBox(height: 6),
            Text(
              _armyPlainSummary(stack.army),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(_armyRoleSummary(stack.army)),
          ],
        ),
      ),
    );
  }

  String _armyTileSummary(ArmyDefinition army) {
    final comp = army.composition;
    final pawns = comp.pawns;
    final rooks = comp.rooks;
    final knights = comp.knights;
    final bishops = comp.bishops;
    final generals = comp.generals;
    return '♟$pawns ♜$rooks\n♞$knights ♝$bishops ♚$generals';
  }

  String _armyPlainSummary(ArmyDefinition army) {
    final comp = army.composition;
    final pawns = comp.pawns;
    final rooks = comp.rooks;
    final knights = comp.knights;
    final bishops = comp.bishops;
    final generals = comp.generals;
    return 'Units: $pawns pawns, $rooks rooks, $knights knights, '
        '$bishops bishops, $generals generals.';
  }

  String _armyRoleSummary(ArmyDefinition army) {
    final comp = army.composition;
    final veteranGenerals = comp.veteranGenerals;
    final rookieGenerals = comp.rookieGenerals;
    return 'Role guide: pawns hold the front; rooks control lines; knights jump; '
        'bishops control diagonals; generals command '
        '($rookieGenerals rookie, $veteranGenerals veteran).';
  }

  Widget _buildGameOverScreen(BuildContext context) {
    final world = _world;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ChessWarss Alpha - Finished')),
      body: _screenBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_status, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      if (world != null)
                        Text(
                          'Rounds played: ${world.round}\n'
                          'Preset: ${_presetLabel(world.preset)}\n'
                          'Seed: ${world.seed}',
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _startMatch(forcedSeed: _seed),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Rematch (Same Seed)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _startMatch(),
                            icon: const Icon(Icons.casino_rounded),
                            label: const Text('Random Seed'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _backToSetup,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to Setup'),
                          ),
                        ],
                      ),
                    ],
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
    }
  }
}
