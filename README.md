# ChessWarss Prototype

Fast prototype of a hybrid strategy + chess-battle game.

## Current playable loop

1. Setup screen:
   - Choose 2-4 players.
   - Set each player to Human or AI.
   - Choose map preset.
2. Strategic layer:
   - 5x5 map.
   - Impassable tiles by preset.
   - Three separate armies per player (cannot combine).
   - Move one tile orthogonally per turn.
3. Collision -> battle:
   - Enter generated battle board (4x4, 4x8, 8x4, or 8x8).
   - Use chess-like movement.
   - General rules:
     - `G1`: orthogonal 1 tile.
     - `G2`: orthogonal up to 2 tiles.
     - General can level up via captures.
     - Rare second general can appear.
   - Lose all generals = lose battle.
4. Return to map and continue until one player remains.

## Run

```bash
flutter pub get
flutter run
```

## Validate

```bash
flutter analyze
flutter test
```

## Core files

- `lib/src/presentation/prototype_game_screen.dart`
- `lib/src/domain/world.dart`
- `lib/src/domain/world_generator.dart`
- `lib/src/domain/battle_state.dart`
- `lib/src/domain/ai.dart`
