# ChessWarss

ChessWarss is a Flutter alpha for a strategy game that combines a small Risk-style world map with chess-style tactical battles.

## Alpha Status

Current build is playable and focused on proving the core loop:

1. Setup match (2-4 players, Human/AI mix, map preset)
2. Move separate army stacks on a 5x5 world map
3. Trigger a chess-like battle when enemy stacks collide
4. Resolve battle and return survivors to the world map
5. Continue until one player remains

## Implemented Features

- 5x5 strategic map with multiple terrain presets
- Impassable tiles on strategic and tactical boards
- Three separate starting armies per player (non-mergeable)
- Simple General system:
  - `G1` moves orthogonally by 1 tile
  - `G2` (veteran) moves orthogonally by up to 2 tiles
  - Generals gain experience from captures
  - Rare second-general spawn support
- Basic AI for world movement and battle moves
- Deterministic seed-based map and army generation
- Unit tests for General rules, world generation, and AI legality
- Widget tests for setup and game start flow

## Tech Stack

- Flutter
- Dart
- Material UI

## Project Layout

- `lib/src/presentation/`: screens and widgets
- `lib/src/domain/`: game rules, map generation, battle logic, AI
- `test/domain/`: rules/engine tests
- `docs/`: implementation notes

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK installed (bundled with Flutter)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

### Run the Linux app (safe mode for unstable GPU drivers)

```bash
./tool/dev_linux_safe.sh
```

Force software rendering if your desktop compositor becomes unstable:

```bash
RENDERER=software ./tool/dev_linux_safe.sh
```

### Run Android on Linux (low-freeze dev mode)

```bash
./tool/dev_android_safe.sh
```

This helper uses lower emulator/Gradle resource settings and a stable Android Studio JDK to keep the desktop responsive during development.

### Quality checks

```bash
flutter analyze
flutter test
```

## Roadmap

See `TODO.md` for prioritized next steps.

## Current Limitations

- Battle rules are intentionally simplified for alpha scope
- AI is heuristic-based, not engine-strength
- No persistence, networking, or cloud saves yet
- No full economy/recruitment system in this phase
