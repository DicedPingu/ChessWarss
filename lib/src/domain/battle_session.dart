import 'army.dart';
import 'battle_state.dart';
import 'piece.dart';
import 'world.dart';

class BattleSession {
  const BattleSession({
    required this.attackerStack,
    required this.defenderStack,
    required this.battleState,
    required this.battlefield,
  });

  final ArmyStack attackerStack;
  final ArmyStack defenderStack;
  final BattleState battleState;
  final BattlefieldSpec battlefield;

  BattleSession copyWith({
    ArmyStack? attackerStack,
    ArmyStack? defenderStack,
    BattleState? battleState,
    BattlefieldSpec? battlefield,
  }) {
    return BattleSession(
      attackerStack: attackerStack ?? this.attackerStack,
      defenderStack: defenderStack ?? this.defenderStack,
      battleState: battleState ?? this.battleState,
      battlefield: battlefield ?? this.battlefield,
    );
  }

  int? winnerPlayerId() {
    final attackerAlive = battleState.commanderAlive(attackerStack.ownerId);
    final defenderAlive = battleState.commanderAlive(defenderStack.ownerId);
    final attackerMoraleBroken = battleState.moraleBroken(
      attackerStack.ownerId,
    );
    final defenderMoraleBroken = battleState.moraleBroken(
      defenderStack.ownerId,
    );

    if (attackerMoraleBroken && defenderMoraleBroken) {
      return null;
    }
    if (attackerMoraleBroken) {
      return defenderStack.ownerId;
    }
    if (defenderMoraleBroken) {
      return attackerStack.ownerId;
    }

    if (attackerAlive && defenderAlive) {
      return null;
    }
    return attackerAlive ? attackerStack.ownerId : defenderStack.ownerId;
  }

  ArmyDefinition armyFromRemainingPieces(int playerId, String fallbackLabel) {
    final remaining = battleState.piecesForPlayer(playerId);
    final units = remaining
        .map(
          (piece) => ArmyUnit(
            type: piece.type,
            generalSkill: piece.type == PieceType.general
                ? piece.generalSkill
                : null,
            generalRank: piece.type == PieceType.general
                ? piece.resolvedGeneralRank
                : null,
            title: piece.type == PieceType.general ? 'General' : null,
          ),
        )
        .toList();

    return ArmyDefinition(
      id: 'battle_$playerId',
      label: fallbackLabel,
      units: units,
    );
  }
}
