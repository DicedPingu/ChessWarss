# Why File Structure Matters in ChessWarss

A good file structure keeps the game easy to change as rules grow.

## Core reasons

- Faster feature work: when rules are in one place, new mechanics (morale, skills, maps) are added without hunting through UI code.
- Fewer bugs: UI mistakes do not break core battle logic when domain logic is isolated.
- Easier balancing: army templates and skill values are visible and editable in focused files.
- Better testing: movement and combat rules can be tested without rendering widgets.
- Safer scaling: adding AI, multiplayer, and more maps is simpler when responsibilities are separated.

## Structure used in this prototype

- `lib/src/domain/`
  - Pure game logic and data models.
  - Contains piece definitions, general skills, armies, and battle move rules.
- `lib/src/presentation/`
  - Flutter UI screens and widgets only.
  - Reads domain state and sends user actions back to domain logic.
- `lib/src/presentation/alpha_game_support_models.dart`
  - Support data classes for the main alpha screen.
  - Keeps `alpha_game_screen.dart` focused on flow/UI methods.
- `docs/`
  - Human documentation and design rationale.
  - `GAME_VISION.md`: intended game direction and priorities.
  - `GAME_WIKI.md`: quick reference for gameplay systems.
  - Includes `IDEAS.md` for exploratory concepts before roadmap commitment.
- `test/domain/`
  - Unit tests for game rules (especially general behavior).

## Rule of thumb

If a file needs Flutter widgets, it belongs in `presentation`.
If a file should run in tests without Flutter UI, it belongs in `domain`.
If a new gameplay rule is introduced, implement it in `domain` first, then wire UI behavior in `presentation`.

This split keeps prototype code clean now and prevents rewrite pain later.

## Current hot spots and cleanup policy

- `alpha_game_screen.dart` still carries broad UI orchestration and should continue to be split by focused UI sections and support models.
- `battle_state.dart` remains a dense rules surface and should continue extracting pure helpers where behavior boundaries are stable.
- Prefer extracting:
  - data holders and pure helpers first,
  - then AI scoring utilities,
  - then optional UI sections (dialogs/cards) when stable.
- Every extraction should keep behavior unchanged and be followed by:
  - `flutter analyze`,
  - `flutter test`,
  - `dart run tool/check_dependencies.dart`.
