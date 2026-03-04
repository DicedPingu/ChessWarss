# ChessWarss Game Vision

## Game Promise
ChessWarss should feel like a believable ancient-war campaign where command, logistics, and morale matter, but still stay playable and exciting in short sessions. It is not a pure simulator and not a pure chess clone. It is a campaign-to-battle loop where strategic pressure and tactical execution are tightly connected.

## Design Priorities
1. Realism and believable campaign logic.
2. Playability, readability, and winnable momentum.
3. Tactical depth and balance expression.

## Non-Negotiables
- Enemy doctrine selection remains hidden during setup.
- The player cannot configure the opponent army setup directly.
- Sane formations should not leave a general isolated in exposed center positions.
- Morale state changes must be visually obvious in battle UI.
- Compact early-game map sizes must be supported (including 4x4 option).
- UI should stay minimal and descriptive; no duplicate controls or noisy filler.
- The game should keep a light parody flavor of old-school ancient warfare without breaking clarity.

## Campaign Layer Intent (Villages, Towns, Camps)
- Villages, towns, and camps must have distinct campaign roles.
- The economy loop should not be arcade-style "build town, spawn units".
- Settlements should drive logistics, control pressure, unrest, and defense posture.
- Camps should represent temporary military projection and supply posture, not permanent city infrastructure.
- Settlement control should influence movement pressure, morale pressure, and battle context.

## General System Intent
- Generals are command identity, not just stronger chess pieces.
- General traits should affect doctrine access, morale behavior, and risk profile.
- General presence should matter in both campaign decisions and tactical outcomes.
- Losing or exposing generals should create meaningful strategic consequences.

## Battle Feel Intent
- Players should clearly understand what happened each turn.
- Last-turn movement and impact feedback should remain visible long enough to parse.
- Match/battle ending should provide readable closure (summary popup, replay context, decisive event).
- Battles should feel tense but not random or unreadable.

## UX Principles
- Minimal interface, high information value.
- Plain-language labels for key systems (morale, command, settlement effects).
- Strong information hierarchy over visual noise.
- Quick setup, clear objective, clear consequences.

## Out of Scope for Now
- Features that add complexity before villages/towns/camps and generals are coherent.
- Heavy simulation subsystems that do not improve immediate campaign-to-battle clarity.
- Broad content expansion before pacing and readability stabilize.

## Definition of Presentable
The game is presentable when:
1. A new player can understand objective, choices, and consequences in about 2 minutes.
2. UI labels and controls are consistent and non-contradictory.
3. The core loop is easy to explain to a non-gamer in plain language.
4. Match outcomes feel earned through command and campaign choices.

## Validation Mapping (Last Verified: 2026-02-24)

| Non-negotiable | Enforced in | Status |
| --- | --- | --- |
| Enemy doctrine selection remains hidden during setup. | `lib/src/presentation/alpha_game_screen.dart` doctrine selection prompts and setup flow text. | enforced |
| The player cannot configure the opponent army setup directly. | Setup flow in `lib/src/presentation/alpha_game_screen.dart` (no dedicated opponent-army editor exposed). | partial |
| Sane formations should not leave a general isolated in exposed center positions. | `lib/src/domain/ai.dart` general-isolation and command-preservation penalties; formation generation in `lib/src/domain/battle_state.dart`. | partial |
| Morale state changes must be visually obvious in battle UI. | Morale status lines and icons in `lib/src/presentation/alpha_game_screen.dart`; turn overlays in `lib/src/presentation/widgets/battle_board_widget.dart`. | enforced |
| Compact early-game map sizes must be supported (including 4x4 option). | `lib/src/presentation/game_mode.dart` map constraints and setup clamping in `lib/src/presentation/alpha_game_screen.dart`. | enforced |
| UI should stay minimal and descriptive; no duplicate controls or noisy filler. | Ongoing UI cleanup in `lib/src/presentation/alpha_game_screen.dart`, tracked in `TODO.md`. | partial |
| The game should keep a light parody flavor of old-school ancient warfare without breaking clarity. | Menu/manual tone in `lib/src/presentation/game_mode_menu_screen.dart` and setup/world field-manual copy in `lib/src/presentation/alpha_game_screen.dart`. | partial |
