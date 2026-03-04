import 'package:chesswarss/src/domain/ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_benchmark_scenarios.dart';

void main() {
  group('AI behavior benchmark', () {
    test('hard AI meets per-family reliability gates', () {
      const battleAi = BattleAi();
      final scenarios = buildAiBenchmarkScenarios();
      final outcomesByFamily = <AiScenarioFamily, List<_ScenarioOutcome>>{
        for (final family in AiScenarioFamily.values)
          family: <_ScenarioOutcome>[],
      };

      for (final scenario in scenarios) {
        final action = battleAi.chooseMove(
          scenario.battleState,
          scenario.seed,
          difficulty: scenario.difficulty,
        );
        if (action == null) {
          outcomesByFamily[scenario.family]!.add(
            _ScenarioOutcome(
              id: scenario.id,
              passed: false,
              detail: 'No legal action returned by AI.',
            ),
          );
          continue;
        }

        final after = scenario.battleState.movePiece(
          pieceId: action.pieceId,
          to: action.to,
        );
        final passed = scenario.expectation(
          scenario.battleState,
          action,
          after,
        );
        outcomesByFamily[scenario.family]!.add(
          _ScenarioOutcome(
            id: scenario.id,
            passed: passed,
            detail: passed
                ? 'ok'
                : scenario.failureMessage(scenario.battleState, action, after),
          ),
        );
      }

      for (final family in AiScenarioFamily.values) {
        final outcomes = outcomesByFamily[family]!;
        final total = outcomes.length;
        final passed = outcomes.where((result) => result.passed).length;
        final required = (total * 0.75).ceil();
        final failures = outcomes.where((result) => !result.passed).toList();
        final passPercent = total == 0 ? 0 : ((passed * 100) ~/ total);
        expect(
          passed,
          greaterThanOrEqualTo(required),
          reason:
              '${family.name}: $passed/$total ($passPercent%) passed, '
              'required $required.\n'
              '${failures.map((result) => '- ${result.id}: ${result.detail}').join('\n')}',
        );
      }
    });
  });
}

class _ScenarioOutcome {
  const _ScenarioOutcome({
    required this.id,
    required this.passed,
    required this.detail,
  });

  final String id;
  final bool passed;
  final String detail;
}
