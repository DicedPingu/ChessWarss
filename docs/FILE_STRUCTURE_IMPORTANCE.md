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
- `docs/`
  - Human documentation and design rationale.
- `test/domain/`
  - Unit tests for game rules (especially general behavior).

## Rule of thumb

If a file needs Flutter widgets, it belongs in `presentation`.
If a file should run in tests without Flutter UI, it belongs in `domain`.

This split keeps prototype code clean now and prevents rewrite pain later.
