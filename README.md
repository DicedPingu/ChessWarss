# ChessWarss

ChessWarss is a Flutter strategy prototype where the campaign layer is Total War-lite and battles resolve on a chess-based tactical board.

## Core Vision

- Campaign: logistics, pressure, occupation, and territorial control.
- `Eterna Mode`: singleplayer adventure baseline (one human faction against multiple AI factions).
- Battles: chess-like movement and positional combat as the main resolver.
- Historical tone: strongly Roman-inspired, but not strict historical reenactment.

## Non-Negotiable Direction

- Armies are constrained by logistics first.
- Starvation in enemy territory must be possible.
- Supply comes from forage, plunder, and local requisition.
- Settlements are population and resource centers, not generic gold unit factories.
- Capture outcomes are explicit: spare or destroy.
- Sieges should feel time-based and costly while still using chess-based battle resolution.
- Temporary camps should create defender advantages on the battle board (traps first).
- Pawn units do not auto-promote into queens.

## Current Build Snapshot

The current build already includes:

- Campaign map + tactical battle loop.
- Two game modes (`Eterna Mode`, `Casus Belli`).
- Battle doctrines, command traits, morale states, and tactical overlays.
- Settlement and camp entities with defensive context modifiers.
- Per-army supply and starvation tracking with desertion pressure.
- Settlement and battle capture policies (`Spare` / `Destroy`) with occupation/devastation effects.
- Settlement `Levy` action and forced levy intake on spared captures.
- Board/HUD ownership clarity: turn-lit active units, owner badges, selected-army unit list + supply state.
- Compact no-scroll strategic HUD: icon-first controls, contextual selection panels, and modal drill-down instead of always-on long lists.
- Selectable settlements without army selection, with town effects shown directly in HUD context.
- Tile-level field economy: open squares can be secured for recurring food or pillaged for immediate army supply.
- Optional AI-vs-AI battle skip (auto-resolve) to keep campaign flow fast.
- Battle anti-stall safeguard with forced resolution at turn limit.
- Save/load, settings, and onboarding.

This baseline is now being redirected toward the logistics-first war model above.

## Current Scope (After Phase 1)

Implemented:

- Per-army supply (not only global player food).
- Supply actions from campaign movement context: forage, plunder, requisition.
- Open-field food control layer: secure/pillage mechanics tied to specific board squares.
- Starvation ladder with escalating penalties.
- Settlement capture outcomes (`spare` or `destroy`) with immediate and long-term effects.
- Conquered-food scaling tied to occupation age and distance/connectivity.
- Levy reinforcement from settlements and spared captures.

## Scope Guardrails

- Not a full Total War simulator.
- Keep systems readable and testable.
- Prefer fewer, strong mechanics over many weak subsystems.

## Product References

- Execution plan: `TODO.md`
- Design intent and non-negotiables: `docs/GAME_VISION.md`
- System reference: `docs/GAME_WIKI.md`

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
./tool/check_docs_consistency.sh
./tool/check_mcp_stack.sh
```

## Current Limitations

- Logistics-first warfare model is in migration and not complete yet.
- Siege timing, long sieges, and camp-to-city conversion are not finalized.
- Commander threat penalties for cowardly/green leadership still need expansion.
- AI is heuristic-based and still tuned for current rule sets.
- Casus Belli remains slot-editable (AI or human per slot), while Eterna defaults to singleplayer adventure pacing.
