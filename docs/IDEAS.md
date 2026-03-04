# ChessWarss Ideas Board

This file tracks candidate ideas that are not yet committed to the main roadmap.
Ideas in this file should map back to priorities in `docs/GAME_VISION.md`.

## Required Idea Metadata

Before promoting any idea from this file to `TODO.md`, capture:

- **Impact window**: does the player feel value within 2 minutes?
- **Deterministic testability**: can we define deterministic pass/fail checks?
- **Scope risk**: low / medium / high expansion risk before core pacing stabilizes.

Template:

```md
- Idea: <short title>
  - Impact window: <statement>
  - Deterministic testability: <statement>
  - Scope risk: <low|medium|high>
```

## Presentation Ideas

- Add short pre-battle flavor lines based on settlement/tile type.
- Add a simple post-battle medal panel (`Bravest Unit`, `Turning Point`).
- Add optional "family mode" tooltips with plain-language rule summaries.
- Add a compact "what just happened" strip after each turn.

## Gameplay Ideas

- Add commander bodyguard behavior as an explicit mechanic (not only AI preference).
- Add battle stances (hold, probe, commit) that influence morale risk.
- Add weather modifiers for selected map presets.
- Add neutral militia events around central settlements.

## Campaign Ideas

- Add named capitals and regional identity for each faction.
- Add roads/supply lanes that improve movement and logistics.
- Add unrest-driven rebellion chance for over-taxed settlements.
- Add seasonal economy cycles (harvest vs winter pressure).

## AI Ideas

- Add tactical retreat logic when commander risk is high.
- Add objective-driven world AI (raid, hold, consolidate, siege).
- Add personality presets (`Cautious`, `Balanced`, `Aggressive`).
- Add explainable AI snippets in the log (one-line reason for a move).

## UX/Quality Ideas

- Add one-tap screenshot/export for battle and campaign summaries.
- Add accessibility presets for text size and color contrast.
- Add replay scrubber for the last 10 battle turns.

## Decision Filter

Before promoting an idea to `TODO.md`, check:

1. Does it improve playability in under 2 minutes of user interaction?
2. Can it be tested with deterministic rules and clear pass/fail?
3. Does it avoid ballooning scope before core pacing is stable?
