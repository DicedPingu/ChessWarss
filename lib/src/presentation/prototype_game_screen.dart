import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/ai.dart';
import '../domain/army.dart';
import '../domain/battle_session.dart';
import '../domain/battle_state.dart';
import '../domain/board_position.dart';
import '../domain/piece.dart';
import '../domain/world.dart';
import '../domain/world_generator.dart';
import 'widgets/battle_board_widget.dart';

enum _GamePhase { setup, world, battle, gameOver }

class PrototypeGameScreen extends StatefulWidget {
  const PrototypeGameScreen({super.key});

  @override
  State<PrototypeGameScreen> createState() => _PrototypeGameScreenState();
}

class _PrototypeGameScreenState extends State<PrototypeGameScreen> {
  final WorldGenerator _worldGenerator = const WorldGenerator();
  final StrategicAi _strategicAi = const StrategicAi();
  final BattleAi _battleAi = const BattleAi();

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

  void _startMatch() {
    final seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
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

    _triggerAiTurnIfNeeded();
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
    return world.players.firstWhere((player) => player.id == playerId).type;
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
          Future<void>.delayed(
            const Duration(milliseconds: 350),
            _runStrategicAiTurn,
          ),
        );
      }
      return;
    }

    if (_phase == _GamePhase.battle && _battle != null) {
      final activeId = _battle!.battleState.activePlayer;
      if (_playerTypeById(activeId) == PlayerType.ai) {
        _aiBusy = true;
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 300),
            _runBattleAiTurn,
          ),
        );
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
    _aiBusy = false;

    if (move == null) {
      _advanceWorldTurn(
        'Player ${world.activePlayerId + 1} had no legal moves.',
      );
      return;
    }

    _executeWorldMove(move, fromAi: true);
  }

  Future<void> _runBattleAiTurn() async {
    if (!mounted || _phase != _GamePhase.battle || _battle == null) {
      _aiBusy = false;
      return;
    }

    final session = _battle!;
    final action = _battleAi.chooseMove(session.battleState, _seed);
    _aiBusy = false;

    if (action == null) {
      _finishBattle(session.battleState.otherPlayer, 'No legal battle moves.');
      return;
    }

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
      _executeWorldMove(WorldMove(stackId: _selectedStackId!, to: position));
      return;
    }

    if (tappedStack != null && tappedStack.ownerId == activePlayer) {
      setState(() {
        _selectedStackId = tappedStack.id;
        _worldLegalMoves = world.legalMovesForStack(tappedStack.id).toSet();
        _status = '${tappedStack.id} selected. Choose destination.';
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

  void _executeWorldMove(WorldMove move, {bool fromAi = false}) {
    final world = _world;
    if (world == null) {
      return;
    }

    final stack = world.stacks.firstWhere(
      (candidate) => candidate.id == move.stackId,
    );
    if (stack.ownerId != world.activePlayerId) {
      return;
    }

    final legal = world.legalMovesForStack(stack.id);
    if (!legal.contains(move.to)) {
      return;
    }

    final occupant = world.stackAt(move.to);
    if (occupant != null && occupant.ownerId != stack.ownerId) {
      final tile = world.tileAt(move.to);
      final battleState = BattleState.fromArmies(
        southArmy: stack.army,
        northArmy: occupant.army,
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
        _status =
            'Battle started at (${move.to.row},${move.to.col}) on ${tile.battlefield.notation}.';
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

    setState(() {
      _world = updatedWorld;
      _status =
          'Round ${updatedWorld.round}: ${updatedWorld.players[nextIndex].name} turn.';
    });

    _triggerAiTurnIfNeeded();
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
      _finishBattle(winner, 'Commander eliminated or no legal moves.');
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
    switch (_phase) {
      case _GamePhase.setup:
        return _buildSetupScreen(context);
      case _GamePhase.world:
        return _buildWorldScreen(context);
      case _GamePhase.battle:
        return _buildBattleScreen(context);
      case _GamePhase.gameOver:
        return _buildGameOverScreen(context);
    }
  }

  Widget _buildSetupScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChessWarss Prototype Setup')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Prototype Config',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '5x5 map, 3 armies per player, collision starts chess-style battle.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(width: 120, child: Text('Players')),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _playerCount,
                            isExpanded: true,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 120, child: Text('Map preset')),
                        Expanded(
                          child: DropdownButton<MapPreset>(
                            value: _mapPreset,
                            isExpanded: true,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Player control',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _playerCount; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text('Player ${i + 1}'),
                            ),
                            Expanded(
                              child: DropdownButton<PlayerType>(
                                value: _playerTypes[i],
                                isExpanded: true,
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _startMatch,
                        child: const Text('Start Prototype Match'),
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

  Widget _buildWorldScreen(BuildContext context) {
    final world = _world!;
    final activePlayer = world.players[world.activePlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessWarss Prototype - World Map'),
        actions: [
          TextButton(
            onPressed: _backToSetup,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
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
                  Expanded(child: _buildWorldBoard(world)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 290,
                    child: _buildWorldSidebar(world, activePlayer),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWorldBoard(WorldState world) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round ${world.round} | Active: ${world.players[world.activePlayerIndex].name}',
            ),
            const SizedBox(height: 4),
            Text('Preset: ${_presetLabel(world.preset)} | Seed: ${world.seed}'),
            const SizedBox(height: 8),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: world.size * world.size,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: world.size,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ world.size;
                    final col = index % world.size;
                    final position = BoardPosition(row, col);
                    final tile = world.tileAt(position);
                    final stack = world.stackAt(position);

                    final isBlocked = tile.terrain == TerrainType.blocked;
                    final isSelected =
                        stack != null && stack.id == _selectedStackId;
                    final isLegalMove = _worldLegalMoves.contains(position);

                    Color color = (row + col).isEven
                        ? const Color(0xFFE6E5D8)
                        : const Color(0xFFD5D3C5);
                    if (isBlocked) {
                      color = const Color(0xFF4A4D54);
                    }
                    if (isLegalMove) {
                      color = const Color(0xFF9AB86A);
                    }
                    if (isSelected) {
                      color = const Color(0xFFFFC56B);
                    }

                    return InkWell(
                      onTap: isBlocked ? null : () => _onWorldTileTap(position),
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(color: Colors.black26),
                        ),
                        child: stack == null
                            ? const SizedBox.shrink()
                            : Center(
                                child: Text(
                                  'P${stack.ownerId + 1}\n${stack.label}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: stack.ownerId.isEven
                                        ? const Color(0xFF0D2B53)
                                        : const Color(0xFF5B1420),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_status),
          ],
        ),
      ),
    );
  }

  Widget _buildWorldSidebar(WorldState world, PlayerSlot activePlayer) {
    final activeIsAi = activePlayer.type == PlayerType.ai;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: activeIsAi || _aiBusy ? null : _passWorldTurn,
                child: const Text('Pass Turn'),
              ),
              OutlinedButton(
                onPressed: _backToSetup,
                child: const Text('Back to Setup'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final player in world.players)
            _playerSummaryCard(
              player: player,
              stacks: world.stacksForPlayer(player.id),
              isActive: player.id == world.activePlayerId,
            ),
          const SizedBox(height: 8),
          const Text(
            'Recent world log',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Card(
            child: SizedBox(
              height: 140,
              child: ListView(
                children: world.log.reversed
                    .take(10)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(entry),
                      ),
                    )
                    .toList(),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.name} (${player.type.name.toUpperCase()})${isActive ? ' *' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (stacks.isEmpty)
              const Text('Eliminated')
            else
              for (final stack in stacks)
                Text(
                  '${stack.id}: (${stack.position.row},${stack.position.col}) '
                  'G:${stack.army.countType(PieceType.general)} '
                  'P:${stack.army.countType(PieceType.pawn)} '
                  'R:${stack.army.countType(PieceType.rook)} '
                  'N:${stack.army.countType(PieceType.knight)} '
                  'B:${stack.army.countType(PieceType.bishop)}',
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleScreen(BuildContext context) {
    final world = _world!;
    final session = _battle!;
    final battle = session.battleState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessWarss Prototype - Battle'),
        actions: [
          TextButton(
            onPressed: _backToSetup,
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
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
                    Expanded(
                      flex: 2,
                      child: _buildBattleSidebar(world, session),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: _buildBattleBoardCard(session)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: _buildBattleSidebar(world, session),
                  ),
                ],
              );
            },
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
              label: const Text('Hint Move'),
            ),
    );
  }

  Widget _buildBattleBoardCard(BattleSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battlefield ${session.battlefield.notation} '
              '| P${session.attackerStack.ownerId + 1} vs P${session.defenderStack.ownerId + 1}',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BattleBoardWidget(
                state: session.battleState,
                selectedPieceId: _selectedBattlePieceId,
                legalMoves: _battleLegalMoves,
                onTapSquare: _onBattleTileTap,
              ),
            ),
            const SizedBox(height: 8),
            Text(_status),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleSidebar(WorldState world, BattleSession session) {
    final activeType = _playerTypeById(session.battleState.activePlayer);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active side: Player ${session.battleState.activePlayer + 1} (${activeType.name})',
          ),
          const SizedBox(height: 8),
          _battleArmyCard('Attacker', session.attackerStack.army),
          _battleArmyCard('Defender', session.defenderStack.army),
          const SizedBox(height: 8),
          const Text(
            'Recent battle log',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Card(
            child: SizedBox(
              height: 140,
              child: ListView(
                children: session.battleState.moveLog.reversed
                    .take(10)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(entry),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'General rules:\n'
                '- G1 moves orthogonally 1 square.\n'
                '- G2 moves orthogonally up to 2 squares.\n'
                '- Generals level up through captures.\n'
                '- Lose all generals => lose battle.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _battleArmyCard(String label, ArmyDefinition army) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '${army.label} | '
              'G:${army.countType(PieceType.general)} '
              'P:${army.countType(PieceType.pawn)} '
              'R:${army.countType(PieceType.rook)} '
              'N:${army.countType(PieceType.knight)} '
              'B:${army.countType(PieceType.bishop)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen(BuildContext context) {
    final world = _world;
    return Scaffold(
      appBar: AppBar(title: const Text('ChessWarss Prototype - Finished')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (world != null)
                      Text(
                        'Rounds played: ${world.round}\n'
                        'Preset: ${_presetLabel(world.preset)}\n'
                        'Seed: ${world.seed}',
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _startMatch,
                          child: const Text('Rematch'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _backToSetup,
                          child: const Text('Back to Setup'),
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
