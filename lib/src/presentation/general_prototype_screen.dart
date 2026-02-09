import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/army.dart';
import '../domain/army_factory.dart';
import '../domain/battle_state.dart';
import '../domain/board_position.dart';
import '../domain/piece.dart';
import 'widgets/battle_board_widget.dart';

class GeneralPrototypeScreen extends StatefulWidget {
  const GeneralPrototypeScreen({super.key});

  @override
  State<GeneralPrototypeScreen> createState() => _GeneralPrototypeScreenState();
}

class _GeneralPrototypeScreenState extends State<GeneralPrototypeScreen> {
  final ArmyFactory _armyFactory = const ArmyFactory();

  late int _seed;
  late PlayerArmySet _southArmySet;
  late PlayerArmySet _northArmySet;
  late BattleState _battleState;

  int _southArmyIndex = 0;
  int _northArmyIndex = 0;

  String? _selectedPieceId;
  Set<BoardPosition> _legalMoves = {};
  String _statusLine =
      'Select a piece and move. Generals move orthogonally only.';

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _generateNewArmySets();
  }

  void _generateNewArmySets() {
    final random = Random(_seed);
    _southArmySet = _armyFactory.createArmySet(playerId: 0, random: random);
    _northArmySet = _armyFactory.createArmySet(playerId: 1, random: random);

    _southArmyIndex = _southArmyIndex.clamp(0, _southArmySet.armies.length - 1);
    _northArmyIndex = _northArmyIndex.clamp(0, _northArmySet.armies.length - 1);

    _deploySelectedArmies();
  }

  void _deploySelectedArmies() {
    _battleState = BattleState.fromArmies(
      southArmy: _southArmySet.armies[_southArmyIndex],
      northArmy: _northArmySet.armies[_northArmyIndex],
      southOwnerId: 0,
      northOwnerId: 1,
      rows: 8,
      cols: 8,
    );

    _selectedPieceId = null;
    _legalMoves = {};

    _statusLine =
        'Battle reset. P1 goes first. G1=rookie commander, G2=veteran commander (2-step).';

    setState(() {});
  }

  void _resetWithFreshSeed() {
    _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    _generateNewArmySets();
  }

  void _onTapSquare(BoardPosition position) {
    final selectedPieceId = _selectedPieceId;
    if (selectedPieceId != null && _legalMoves.contains(position)) {
      final movedState = _battleState.movePiece(
        pieceId: selectedPieceId,
        to: position,
      );
      setState(() {
        _battleState = movedState;
        _selectedPieceId = null;
        _legalMoves = {};
      });
      _updateStatusAfterMove();
      return;
    }

    final tappedPiece = _battleState.pieceAt(position);
    if (tappedPiece != null &&
        tappedPiece.ownerId == _battleState.activePlayer) {
      final legal = _battleState.legalMovesForPiece(tappedPiece.id);
      setState(() {
        _selectedPieceId = tappedPiece.id;
        _legalMoves = legal.toSet();
        _statusLine = _pieceStatus(tappedPiece, legal.length);
      });
      return;
    }

    setState(() {
      _selectedPieceId = null;
      _legalMoves = {};
    });
  }

  void _updateStatusAfterMove() {
    final southAlive = _battleState.commanderAlive(0);
    final northAlive = _battleState.commanderAlive(1);

    setState(() {
      if (!southAlive || !northAlive) {
        final winner = southAlive ? 'Player 1' : 'Player 2';
        _statusLine = '$winner wins: enemy commanders eliminated.';
      } else {
        _statusLine =
            'Player ${_battleState.activePlayer + 1} turn. ${_battleState.generalsForPlayer(0)} vs ${_battleState.generalsForPlayer(1)} generals alive.';
      }
    });
  }

  String _pieceStatus(BattlePiece piece, int legalMoveCount) {
    if (piece.type == PieceType.general) {
      final skill = piece.generalSkill == GeneralSkill.veteranCommander
          ? 'Veteran'
          : 'Rookie';
      return 'Selected $skill General: $legalMoveCount legal orthogonal moves.';
    }
    return 'Selected ${piece.type.name}: $legalMoveCount legal moves.';
  }

  @override
  Widget build(BuildContext context) {
    final southArmy = _southArmySet.armies[_southArmyIndex];
    final northArmy = _northArmySet.armies[_northArmyIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('ChessWarss - General Prototype')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useWideLayout = constraints.maxWidth >= 980;
              if (useWideLayout) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildBoardSection()),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildInfoSection(
                        southArmy: southArmy,
                        northArmy: northArmy,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(child: _buildBoardSection()),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 280,
                    child: _buildInfoSection(
                      southArmy: southArmy,
                      northArmy: northArmy,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBoardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seed: $_seed',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: BattleBoardWidget(
                state: _battleState,
                selectedPieceId: _selectedPieceId,
                legalMoves: _legalMoves,
                onTapSquare: _onTapSquare,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(_statusLine),
      ],
    );
  }

  Widget _buildInfoSection({
    required ArmyDefinition southArmy,
    required ArmyDefinition northArmy,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _resetWithFreshSeed,
                child: const Text('Regenerate Armies'),
              ),
              OutlinedButton(
                onPressed: _deploySelectedArmies,
                child: const Text('Redeploy Selected'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _armyPicker(
            title: 'Player 1 Army',
            value: _southArmyIndex,
            armies: _southArmySet.armies,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _southArmyIndex = value;
              });
            },
          ),
          const SizedBox(height: 8),
          _armySummaryCard('Player 1', southArmy),
          const SizedBox(height: 12),
          _armyPicker(
            title: 'Player 2 Army',
            value: _northArmyIndex,
            armies: _northArmySet.armies,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _northArmyIndex = value;
              });
            },
          ),
          const SizedBox(height: 8),
          _armySummaryCard('Player 2', northArmy),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'General rules now:\n'
                '- G1 (rookie): orthogonal 1 square.\n'
                '- G2 (veteran): orthogonal up to 2 squares, cannot jump pieces.\n'
                '- Generals can level up by combat captures.\n'
                '- Rarely, an army spawns with a second general.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Latest moves',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Card(
            child: SizedBox(
              height: 120,
              child: ListView(
                children: _battleState.moveLog.reversed
                    .take(8)
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

  Widget _armyPicker({
    required String title,
    required int value,
    required List<ArmyDefinition> armies,
    required ValueChanged<int?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(title)),
        Expanded(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            items: [
              for (var i = 0; i < armies.length; i++)
                DropdownMenuItem<int>(value: i, child: Text(armies[i].label)),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _armySummaryCard(String title, ArmyDefinition army) {
    final generals = army.countType(PieceType.general);
    final hasVeteran = army.units.any(
      (unit) =>
          unit.type == PieceType.general &&
          unit.generalSkill == GeneralSkill.veteranCommander,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: ${army.label}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'R:${army.countType(PieceType.rook)} '
              'N:${army.countType(PieceType.knight)} '
              'B:${army.countType(PieceType.bishop)} '
              'P:${army.countType(PieceType.pawn)} '
              'G:$generals',
            ),
            if (hasVeteran) const Text('Includes veteran commander (G2).'),
            if (generals >= 2)
              const Text('Rare double-general army is active in this seed.'),
          ],
        ),
      ),
    );
  }
}
