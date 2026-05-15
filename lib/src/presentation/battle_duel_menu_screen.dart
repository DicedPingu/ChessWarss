import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/ai.dart';
import '../domain/army.dart';
import '../domain/army_factory.dart';
import '../domain/battle_state.dart';
import '../domain/board_position.dart';
import '../domain/piece.dart';
import 'widgets/battle_board_widget.dart';

class BattleDuelMenuScreen extends StatefulWidget {
  const BattleDuelMenuScreen({super.key});

  @override
  State<BattleDuelMenuScreen> createState() => _BattleDuelMenuScreenState();
}

class _BattleDuelMenuScreenState extends State<BattleDuelMenuScreen> {
  final ArmyFactory _armyFactory = const ArmyFactory();
  late final ArmyDefinition _previewSouthArmy;
  late final ArmyDefinition _previewNorthArmy;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final random = Random(90421);
    _previewSouthArmy = _armyFactory
        .createArmySet(playerId: 0, random: random)
        .armies
        .first;
    _previewNorthArmy = _armyFactory
        .createArmySet(playerId: 1, random: random)
        .armies[1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _duelFormats[_selectedIndex];
    final previewState = selected.previewState(
      southArmy: _previewSouthArmy,
      northArmy: _previewNorthArmy,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Board Duels')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F1E8), Color(0xFFD7E6DF), Color(0xFFE8D3B3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1020;
                final previewPanel = Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selected.tagline,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF604A2A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PreviewChip(
                              label: '${selected.rows}x${selected.cols}',
                            ),
                            _PreviewChip(label: selected.shapeLabel),
                            _PreviewChip(label: selected.styleLabel),
                            _PreviewChip(
                              label: 'Score ${selected.targetWarScore}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          flex: 6,
                          child: IgnorePointer(
                            child: BattleBoardWidget(
                              state: previewState,
                              selectedPieceId: null,
                              legalMoves: const <BoardPosition>{},
                              onTapSquare: (_) {},
                              reduceEffects: true,
                              showOverlayArrows: false,
                              visualStyle: selected.visualStyle,
                              objectiveCells: selected.objectiveCells,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selected.summary),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              _BattleDuelMatchScreen(
                                                format: selected,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.sports_martial_arts_rounded,
                                    ),
                                    label: const Text('Start Duel'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final chooserPanel = Card(
                  color: Colors.white.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Format',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fast war-chess scenarios: classic movement, visible command banners, and short battles with enough campaign pressure to matter.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _duelFormats.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final format = _duelFormats[index];
                              final selectedCard = index == _selectedIndex;
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selectedCard
                                        ? const Color(0xFFF6E7C6)
                                        : const Color(0xFFF9F2E3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selectedCard
                                          ? const Color(0xFF8A6336)
                                          : const Color(0xFFD2B78C),
                                      width: selectedCard ? 1.6 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8A6336),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              format.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              format.tagline,
                                              style: const TextStyle(
                                                color: Color(0xFF5C482B),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${format.shapeLabel} • ${format.rows}x${format.cols}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF7A5A2F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: previewPanel),
                      const SizedBox(height: 12),
                      Expanded(flex: 5, child: chooserPanel),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: previewPanel),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: chooserPanel),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BattleDuelMatchScreen extends StatefulWidget {
  const _BattleDuelMatchScreen({required this.format});

  final _DuelFormat format;

  @override
  State<_BattleDuelMatchScreen> createState() => _BattleDuelMatchScreenState();
}

class _BattleDuelMatchScreenState extends State<_BattleDuelMatchScreen> {
  final ArmyFactory _armyFactory = const ArmyFactory();
  final BattleAi _battleAi = const BattleAi();

  late int _seed;
  late ArmyDefinition _southArmy;
  late ArmyDefinition _northArmy;
  late BattleState _battleState;

  String? _selectedPieceId;
  Set<BoardPosition> _legalMoves = const <BoardPosition>{};
  String _statusLine = 'Select a piece and start the duel.';
  bool _aiBusy = false;
  int? _winnerPlayerId;
  bool _draw = false;
  Map<int, int> _warScoreByPlayer = const <int, int>{};
  String? _lastPressureLine;
  int _matchVersion = 0;

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _startMatch();
  }

  void _startMatch() {
    _matchVersion++;
    final random = Random(_seed);
    final southSet = _armyFactory.createArmySet(playerId: 0, random: random);
    final northSet = _armyFactory.createArmySet(playerId: 1, random: random);
    _southArmy = southSet.armies[_seed % southSet.armies.length];
    _northArmy = northSet.armies[(_seed ~/ 3) % northSet.armies.length];
    _battleState = widget.format.previewState(
      southArmy: _southArmy,
      northArmy: _northArmy,
    );
    _selectedPieceId = null;
    _legalMoves = const <BoardPosition>{};
    _winnerPlayerId = null;
    _draw = false;
    _aiBusy = false;
    _warScoreByPlayer = <int, int>{
      _battleState.southPlayerId: 0,
      _battleState.northPlayerId: 0,
    };
    _lastPressureLine = null;
    _statusLine = 'Player 1 opens on ${widget.format.title}.';
    if (mounted) {
      setState(() {});
    }
  }

  void _reroll() {
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _startMatch();
  }

  void _onTapSquare(BoardPosition position) {
    if (_aiBusy || _winnerPlayerId != null || _draw) {
      return;
    }
    if (_battleState.activePlayer != _battleState.southPlayerId) {
      return;
    }

    final selectedPieceId = _selectedPieceId;
    if (selectedPieceId != null && _legalMoves.contains(position)) {
      final movedState = _battleState.movePiece(
        pieceId: selectedPieceId,
        to: position,
      );
      _finishBattleAction(
        actorPlayerId: _battleState.southPlayerId,
        nextState: movedState,
      );
      return;
    }

    final tappedPiece = _battleState.pieceAt(position);
    if (tappedPiece != null &&
        tappedPiece.ownerId == _battleState.activePlayer) {
      final legalMoves = _battleState
          .legalMovesForPiece(tappedPiece.id)
          .toSet();
      setState(() {
        _selectedPieceId = tappedPiece.id;
        _legalMoves = legalMoves;
        _statusLine =
            '${tappedPiece.type.name.toUpperCase()} selected: ${legalMoves.length} legal move(s).';
      });
      return;
    }

    setState(() {
      _selectedPieceId = null;
      _legalMoves = const <BoardPosition>{};
    });
  }

  void _resolveAfterAction({required int actorPlayerId}) {
    final winner = _winnerForState(_battleState);
    if (winner != null) {
      setState(() {
        _winnerPlayerId = winner;
        _draw = false;
        _aiBusy = false;
        _statusLine = winner == _battleState.southPlayerId
            ? 'Player 1 wins ${widget.format.title}.'
            : 'The AI wins ${widget.format.title}.';
      });
      return;
    }
    if (_isDrawState(_battleState)) {
      setState(() {
        _draw = true;
        _aiBusy = false;
        _statusLine = 'The duel stalled into a draw.';
      });
      return;
    }

    final nextPlayer = _battleState.activePlayer;
    final pressureLine = _lastPressureLine;
    final nextLine = nextPlayer == _battleState.southPlayerId
        ? 'Your move.'
        : 'AI is reading the board...';
    setState(() {
      _statusLine = pressureLine == null
          ? nextLine
          : '$pressureLine. $nextLine';
    });
    if (nextPlayer == _battleState.northPlayerId) {
      unawaited(_runAiTurn());
    }
  }

  Future<void> _runAiTurn() async {
    final matchVersion = _matchVersion;
    setState(() {
      _aiBusy = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted ||
        _matchVersion != matchVersion ||
        _winnerPlayerId != null ||
        _draw) {
      return;
    }
    final action = _battleAi.chooseMove(_battleState, _seed);
    if (action == null) {
      setState(() {
        _aiBusy = false;
        _winnerPlayerId = _battleState.southPlayerId;
        _statusLine = 'The AI has no legal move. Player 1 wins.';
      });
      return;
    }
    setState(() {
      _aiBusy = false;
    });
    _finishBattleAction(
      actorPlayerId: _battleState.northPlayerId,
      nextState: _battleState.movePiece(pieceId: action.pieceId, to: action.to),
    );
  }

  void _finishBattleAction({
    required int actorPlayerId,
    required BattleState nextState,
  }) {
    final pressure = _applyWarPressure(
      state: nextState,
      actorPlayerId: actorPlayerId,
    );
    setState(() {
      _battleState = pressure.state;
      _warScoreByPlayer = pressure.warScoreByPlayer;
      _lastPressureLine = pressure.statusLine;
      _selectedPieceId = null;
      _legalMoves = const <BoardPosition>{};
    });
    _resolveAfterAction(actorPlayerId: actorPlayerId);
  }

  _WarPressureResult _applyWarPressure({
    required BattleState state,
    required int actorPlayerId,
  }) {
    final objectives = widget.format.objectiveCells;
    var updatedState = state;
    final scores = <int, int>{
      state.southPlayerId: _warScoreByPlayer[state.southPlayerId] ?? 0,
      state.northPlayerId: _warScoreByPlayer[state.northPlayerId] ?? 0,
    };
    final notes = <String>[];

    final southControl = _objectiveControlCount(state, state.southPlayerId);
    final northControl = _objectiveControlCount(state, state.northPlayerId);
    if (objectives.isNotEmpty && southControl != northControl) {
      final controller = southControl > northControl
          ? state.southPlayerId
          : state.northPlayerId;
      final defender = controller == state.southPlayerId
          ? state.northPlayerId
          : state.southPlayerId;
      final controlLead = (southControl - northControl).abs();
      final gain = controlLead >= 2 ? 2 : 1;
      final beforeScore = scores[controller] ?? 0;
      final afterScore = (beforeScore + gain).clamp(
        0,
        widget.format.targetWarScore,
      );
      scores[controller] = afterScore;
      notes.add(
        '${_sideLabel(controller)} banners $southControl-$northControl (+$gain)',
      );

      if ((beforeScore ~/ 3) < (afterScore ~/ 3)) {
        updatedState = _applyMoralePressure(
          state: updatedState,
          targetPlayerId: defender,
          actorPlayerId: controller,
          reason: 'banner pressure',
        );
      }
    }

    if (_hasBreakthrough(state, actorPlayerId)) {
      final beforeScore = scores[actorPlayerId] ?? 0;
      final afterScore = (beforeScore + 1).clamp(
        0,
        widget.format.targetWarScore,
      );
      scores[actorPlayerId] = afterScore;
      if (afterScore != beforeScore) {
        notes.add('${_sideLabel(actorPlayerId)} breakthrough (+1)');
      }
    }

    return _WarPressureResult(
      state: updatedState,
      warScoreByPlayer: scores,
      statusLine: notes.isEmpty ? null : notes.join(' • '),
    );
  }

  BattleState _applyMoralePressure({
    required BattleState state,
    required int targetPlayerId,
    required int actorPlayerId,
    required String reason,
  }) {
    final beforeMorale = state.moraleForPlayer(targetPlayerId);
    final afterMorale = (beforeMorale - 1).clamp(0, state.maxMorale).toInt();
    if (afterMorale == beforeMorale) {
      return state;
    }
    final turn = state.moveLog.length;
    return state.copyWith(
      moraleByPlayer: <int, int>{
        ...state.moraleByPlayer,
        targetPlayerId: afterMorale,
      },
      eventLog: <BattleEvent>[
        ...state.eventLog,
        BattleEvent(
          turn: turn,
          type: BattleEventType.moraleShift,
          actorPlayerId: actorPlayerId,
          targetPlayerId: targetPlayerId,
          delta: afterMorale - beforeMorale,
          description:
              '${_sideLabel(targetPlayerId)} morale $beforeMorale->$afterMorale from $reason.',
        ),
      ],
    );
  }

  int _objectiveControlCount(BattleState state, int playerId) {
    var count = 0;
    for (final objective in widget.format.objectiveCells) {
      final occupant = state.pieceAt(objective);
      if (occupant != null && occupant.ownerId == playerId) {
        count++;
      }
    }
    return count;
  }

  bool _hasBreakthrough(BattleState state, int playerId) {
    final breakthroughRow = playerId == state.southPlayerId
        ? 0
        : state.rows - 1;
    for (final piece in state.piecesForPlayer(playerId)) {
      if (piece.type == PieceType.general) {
        continue;
      }
      if (piece.position.row == breakthroughRow) {
        return true;
      }
    }
    return false;
  }

  String _sideLabel(int playerId) {
    return playerId == _battleState.southPlayerId ? 'P1' : 'AI';
  }

  int? _winnerForState(BattleState state) {
    final southScore = _warScoreByPlayer[state.southPlayerId] ?? 0;
    final northScore = _warScoreByPlayer[state.northPlayerId] ?? 0;
    if (southScore >= widget.format.targetWarScore) {
      return state.southPlayerId;
    }
    if (northScore >= widget.format.targetWarScore) {
      return state.northPlayerId;
    }

    final southDefeated =
        !state.commanderAlive(state.southPlayerId) ||
        state.moraleBroken(state.southPlayerId) ||
        !state.hasAnyLegalMove(state.southPlayerId);
    final northDefeated =
        !state.commanderAlive(state.northPlayerId) ||
        state.moraleBroken(state.northPlayerId) ||
        !state.hasAnyLegalMove(state.northPlayerId);
    if (southDefeated && northDefeated) {
      return null;
    }
    if (southDefeated) {
      return state.northPlayerId;
    }
    if (northDefeated) {
      return state.southPlayerId;
    }
    return null;
  }

  bool _isDrawState(BattleState state) {
    return !state.hasAnyLegalMove(state.southPlayerId) &&
        !state.hasAnyLegalMove(state.northPlayerId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = _battleState.latestTurnOverlay();
    final wide = MediaQuery.of(context).size.width >= 1040;

    return Scaffold(
      appBar: AppBar(title: Text('Board Duel - ${widget.format.title}')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F1E8), Color(0xFFD7E6DF), Color(0xFFE8D3B3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: wide
                ? Row(
                    children: [
                      Expanded(flex: 3, child: _buildBoardPane()),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildInfoPane(theme, overlay)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 3, child: _buildBoardPane()),
                      const SizedBox(height: 12),
                      Expanded(flex: 2, child: _buildInfoPane(theme, overlay)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardPane() {
    final overlay = _battleState.latestTurnOverlay();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreviewChip(label: widget.format.shapeLabel),
                _PreviewChip(
                  label: '${widget.format.rows}x${widget.format.cols}',
                ),
                _PreviewChip(
                  label: _winnerPlayerId != null
                      ? (_winnerPlayerId == _battleState.southPlayerId
                            ? 'Player 1 Won'
                            : 'AI Won')
                      : (_draw ? 'Draw' : 'Live Duel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BattleBoardWidget(
                state: _battleState,
                selectedPieceId: _selectedPieceId,
                legalMoves: _legalMoves,
                onTapSquare: _onTapSquare,
                turnOverlay: overlay,
                showOverlayArrows: !_isHexStyle(widget.format.visualStyle),
                reduceEffects: false,
                visualStyle: widget.format.visualStyle,
                objectiveCells: widget.format.objectiveCells,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPane(ThemeData theme, BattleTurnOverlay? overlay) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.format.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(widget.format.summary),
              const SizedBox(height: 10),
              Text(
                _statusLine,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _warScorePanel(theme),
              const SizedBox(height: 10),
              _battleCommandBar(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _startMatch,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Rematch'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _reroll,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('New Seed'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _armySummaryCard('Player 1', _southArmy),
              const SizedBox(height: 10),
              _armySummaryCard('AI', _northArmy),
              const SizedBox(height: 10),
              Text('Latest Moves', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Container(
                height: 118,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F3E7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD7C79E)),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: _battleState.moveLog.reversed
                      .take(10)
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(entry),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (overlay != null) ...[
                const SizedBox(height: 8),
                Text('Last turn overlay: turn ${overlay.turn}.'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _warScorePanel(ThemeData theme) {
    final target = widget.format.targetWarScore;
    final p1Score = _warScoreByPlayer[_battleState.southPlayerId] ?? 0;
    final aiScore = _warScoreByPlayer[_battleState.northPlayerId] ?? 0;
    final p1Control = _objectiveControlCount(
      _battleState,
      _battleState.southPlayerId,
    );
    final aiControl = _objectiveControlCount(
      _battleState,
      _battleState.northPlayerId,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7B681)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text('War Score', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                'Banners $p1Control-$aiControl',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _scoreLine(
            label: 'P1',
            score: p1Score,
            target: target,
            color: const Color(0xFF1D5A70),
          ),
          const SizedBox(height: 6),
          _scoreLine(
            label: 'AI',
            score: aiScore,
            target: target,
            color: const Color(0xFFB44734),
          ),
        ],
      ),
    );
  }

  Widget _scoreLine({
    required String label,
    required int score,
    required int target,
    required Color color,
  }) {
    final progress = target <= 0
        ? 0.0
        : (score / target).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: color,
              backgroundColor: color.withValues(alpha: 0.16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$score/$target',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _battleCommandBar() {
    final humanTurn =
        !_aiBusy &&
        !_draw &&
        _winnerPlayerId == null &&
        _battleState.activePlayer == _battleState.southPlayerId;
    final canAdvance = humanTurn && _battleState.canAdvanceFrontline();
    final canGeneralOrder =
        humanTurn && _battleState.canUseGeneralAdvanceSkill();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: canAdvance
              ? () {
                  _finishBattleAction(
                    actorPlayerId: _battleState.southPlayerId,
                    nextState: _battleState.advanceFrontline(maxUnits: 3),
                  );
                }
              : null,
          icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
          label: const Text('Push Line'),
        ),
        FilledButton.tonalIcon(
          onPressed: canGeneralOrder
              ? () {
                  _finishBattleAction(
                    actorPlayerId: _battleState.southPlayerId,
                    nextState: _battleState.useGeneralAdvanceSkill(),
                  );
                }
              : null,
          icon: const Icon(Icons.military_tech_rounded),
          label: const Text('General Order'),
        ),
      ],
    );
  }

  Widget _armySummaryCard(String label, ArmyDefinition army) {
    final comp = army.composition;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0DE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5BB8F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label • ${army.label}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Pawns ${comp.pawns} • Rooks ${comp.rooks} • Knights ${comp.knights} • Bishops ${comp.bishops} • Generals ${comp.generals}',
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6CC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD3BA8F)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5C4527),
        ),
      ),
    );
  }
}

class _DuelFormat {
  const _DuelFormat({
    required this.title,
    required this.tagline,
    required this.summary,
    required this.rows,
    required this.cols,
    required this.visualStyle,
    required this.blockedCells,
    required this.objectiveCells,
    required this.targetWarScore,
    required this.shapeLabel,
    required this.styleLabel,
  });

  final String title;
  final String tagline;
  final String summary;
  final int rows;
  final int cols;
  final BattleBoardVisualStyle visualStyle;
  final Set<BoardPosition> blockedCells;
  final Set<BoardPosition> objectiveCells;
  final int targetWarScore;
  final String shapeLabel;
  final String styleLabel;

  BattleState previewState({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
  }) {
    return BattleState.fromArmies(
      southArmy: southArmy,
      northArmy: northArmy,
      southOwnerId: 0,
      northOwnerId: 1,
      rows: rows,
      cols: cols,
      blockedCells: blockedCells,
    );
  }
}

class _WarPressureResult {
  const _WarPressureResult({
    required this.state,
    required this.warScoreByPlayer,
    required this.statusLine,
  });

  final BattleState state;
  final Map<int, int> warScoreByPlayer;
  final String? statusLine;
}

bool _isHexStyle(BattleBoardVisualStyle style) {
  return switch (style) {
    BattleBoardVisualStyle.flatHexFront ||
    BattleBoardVisualStyle.fordHex ||
    BattleBoardVisualStyle.pointedHex ||
    BattleBoardVisualStyle.longHex => true,
    _ => false,
  };
}

Set<BoardPosition> _centerKeep() {
  return <BoardPosition>{
    BoardPosition(3, 3),
    BoardPosition(3, 4),
    BoardPosition(4, 3),
    BoardPosition(4, 4),
  };
}

Set<BoardPosition> _centerObjectives(int rows, int cols) {
  final top = (rows - 1) ~/ 2;
  final bottom = rows ~/ 2;
  final left = (cols - 1) ~/ 2;
  final right = cols ~/ 2;
  return <BoardPosition>{
    BoardPosition(top, left),
    BoardPosition(top, right),
    BoardPosition(bottom, left),
    BoardPosition(bottom, right),
  };
}

Set<BoardPosition> _citadelObjectives() {
  return <BoardPosition>{
    const BoardPosition(2, 3),
    const BoardPosition(2, 4),
    const BoardPosition(5, 3),
    const BoardPosition(5, 4),
  };
}

Set<BoardPosition> _fordObjectives() {
  return <BoardPosition>{
    const BoardPosition(3, 4),
    const BoardPosition(4, 3),
    const BoardPosition(4, 5),
    const BoardPosition(5, 4),
  };
}

Set<BoardPosition> _diamondMask(int rows, int cols) {
  final blocked = <BoardPosition>{};
  final centerRow = rows ~/ 2;
  final centerCol = cols ~/ 2;
  final radius = centerRow < centerCol ? centerRow : centerCol;
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final distance = (row - centerRow).abs() + (col - centerCol).abs();
      if (distance > radius) {
        blocked.add(BoardPosition(row, col));
      }
    }
  }
  return blocked;
}

Set<BoardPosition> _cornerCuts(int rows, int cols, {required int depth}) {
  final blocked = <BoardPosition>{};
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final topLeft = row + col < depth;
      final topRight = row + (cols - 1 - col) < depth;
      final bottomLeft = (rows - 1 - row) + col < depth;
      final bottomRight = (rows - 1 - row) + (cols - 1 - col) < depth;
      if (topLeft || topRight || bottomLeft || bottomRight) {
        blocked.add(BoardPosition(row, col));
      }
    }
  }
  return blocked;
}

Set<BoardPosition> _fordHexMask() {
  return <BoardPosition>{
    ..._cornerCuts(9, 9, depth: 2),
    const BoardPosition(4, 4),
  };
}

final List<_DuelFormat> _duelFormats = <_DuelFormat>[
  _DuelFormat(
    title: 'Royal Boxes',
    tagline: 'The clean, classical board for direct chess pressure.',
    summary:
        'Pure 8x8 boxes. Best when you want the most readable duel and the least friction between campaign flavor and core chess instincts.',
    rows: 8,
    cols: 8,
    visualStyle: BattleBoardVisualStyle.royalBoxes,
    blockedCells: const <BoardPosition>{},
    objectiveCells: _centerObjectives(8, 8),
    targetWarScore: 8,
    shapeLabel: 'Boxes',
    styleLabel: 'War Chess',
  ),
  _DuelFormat(
    title: 'Citadel Boxes',
    tagline: 'A ruined keep in the center forces the lines to bend.',
    summary:
        'Still square and chess-readable, but the central keep breaks automatic mirror play and rewards lateral planning.',
    rows: 8,
    cols: 8,
    visualStyle: BattleBoardVisualStyle.citadelBoxes,
    blockedCells: _centerKeep(),
    objectiveCells: _citadelObjectives(),
    targetWarScore: 8,
    shapeLabel: 'Boxes',
    styleLabel: 'Fortified',
  ),
  _DuelFormat(
    title: 'Diamond Court',
    tagline: 'A court cut into a diamond to focus battle toward the middle.',
    summary:
        'The corners vanish and the center matters more. It still feels like chess, but with the dead air removed.',
    rows: 9,
    cols: 9,
    visualStyle: BattleBoardVisualStyle.diamondBoxes,
    blockedCells: _diamondMask(9, 9),
    objectiveCells: _centerObjectives(9, 9),
    targetWarScore: 9,
    shapeLabel: 'Boxes',
    styleLabel: 'Diamond',
  ),
  _DuelFormat(
    title: 'March Rectangle',
    tagline: 'A wider field that gives rooks and flanks more air.',
    summary:
        'A long battlefield inspired by operational frontage rather than a perfect square, while still keeping straight files legible.',
    rows: 8,
    cols: 10,
    visualStyle: BattleBoardVisualStyle.marchBoxes,
    blockedCells: const <BoardPosition>{},
    objectiveCells: _centerObjectives(8, 10),
    targetWarScore: 10,
    shapeLabel: 'Boxes',
    styleLabel: 'Wide Front',
  ),
  _DuelFormat(
    title: 'Flat Hex Front',
    tagline: 'Hex sectors soften rigid lanes without losing the duel feel.',
    summary:
        'This is the most direct hex conversion: broader frontage, smoother flanks, still close enough to the discipline of chess.',
    rows: 9,
    cols: 9,
    visualStyle: BattleBoardVisualStyle.flatHexFront,
    blockedCells: _cornerCuts(9, 9, depth: 2),
    objectiveCells: _centerObjectives(9, 9),
    targetWarScore: 9,
    shapeLabel: 'Hexes',
    styleLabel: 'Flat Top',
  ),
  _DuelFormat(
    title: 'Ford Hex',
    tagline: 'A broken center that feels like fighting over a crossing.',
    summary:
        'Inspired by battle maps where a single breach line matters. The center is awkward and every push needs preparation.',
    rows: 9,
    cols: 9,
    visualStyle: BattleBoardVisualStyle.fordHex,
    blockedCells: _fordHexMask(),
    objectiveCells: _fordObjectives(),
    targetWarScore: 9,
    shapeLabel: 'Hexes',
    styleLabel: 'Broken Front',
  ),
  _DuelFormat(
    title: 'Pointed Crown',
    tagline: 'Sharper hex geometry with a more spearhead-like reading.',
    summary:
        'This one leans into directional thrusts. The board looks more martial and less like a perfect table of squares.',
    rows: 8,
    cols: 9,
    visualStyle: BattleBoardVisualStyle.pointedHex,
    blockedCells: _cornerCuts(8, 9, depth: 2),
    objectiveCells: _centerObjectives(8, 9),
    targetWarScore: 9,
    shapeLabel: 'Hexes',
    styleLabel: 'Pointed',
  ),
  _DuelFormat(
    title: 'Long Hex March',
    tagline: 'A stretched hex theatre for sweeping wing play.',
    summary:
        'The broadest duel board here. It rewards rooks, cavalry arcs, and the feeling of armies meeting across a real front.',
    rows: 8,
    cols: 10,
    visualStyle: BattleBoardVisualStyle.longHex,
    blockedCells: _cornerCuts(8, 10, depth: 2),
    objectiveCells: _centerObjectives(8, 10),
    targetWarScore: 10,
    shapeLabel: 'Hexes',
    styleLabel: 'Long Front',
  ),
];
