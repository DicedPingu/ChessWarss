# ChessWarss

ChessWarss is a Flutter strategy prototype where the campaign layer is Total War-lite and battles resolve on a chess-based tactical board.

## Core Vision

- TOTAL WAR; YET THE ARMIES AND WARS ARE "CHESS".
- Campaign: logistics, pressure, occupation, and territorial control.
- `Eterna Mode`: singleplayer adventure baseline (one human faction against multiple AI factions).
- Battles: chess-like movement and positional combat as the main resolver.
- Historical tone: strongly Roman-inspired, but not strict historical reenactment, take inspiration from Total War, also Kings and Generals and the Invicta series on YouTube.
- It should be simple and keep the style of chess, yet have possibilities for interesting playability and fun.
- Inside the folder .inspiration are some screenshots of how it should look like, and some scetches as to how the generals might look like.

## Non-Negotiable Direction

- Armies are constrained by logistics first. Caesar said an army marches on its stomach.
- Starvation in enemy territory is possible, not bothersome.
- Supply comes from forage, plunder, and supply trains/deposits/etc.
- Settlements are population and resource centers, not generic gold unit factories.
- Capture outcomes are explicit: spare or destroy.
- Sieges should feel time-based and costly while still using chess-based battle resolution.
- Temporary camps should create defender advantages on the battle board (traps first).
- Pawn units do not auto-promote into queens.

## Current Build Snapshot

The current build already includes:

- Shit.

## Current Scope (After Phase 1)

Implemented:

- Per-army supply (not only global player food).
- Supplytrains.
- Starve and your army dies-
- Starvation ladder with escalating penaltie, shown clearly and understandable.
- Starvation in enemy territory is possible, not bothersome.
- Settlements are population and resource centers, not generic gold unit factories.
- Rework settlement captures.
- Conquered-food scaling tied to occupation age and distance/connectivity.
- Levy reinforcement from settlements and spared captures.

## Scope Guardrails

- Not a full Total War simulator.
- Keep systems readable and testable.
- Simple, optimized, interesting, and chess-styled is the design rule.

## Product References

- Execution plan: `TODO.md`

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK (bundled with Flutter)

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Quality checks

```bash
flutter analyze
flutter test
dart run tool/check_dependencies.dart
```

## Current Limitations

- Logistics-first warfare model is in migration and not complete yet.
- Siege timing, long sieges, and camp-to-city conversion are not finalized.
- Commander threat penalties for cowardly/green leadership still need expansion.
- AI is heuristic-based and still tuned for current rule sets.
- Casus Belli remains slot-editable (AI or human per slot), while Eterna defaults to singleplayer adventure pacing.
