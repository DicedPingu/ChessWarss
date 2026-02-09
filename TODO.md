# TODO - ChessWarss

## P0 - Prototype Hardening

- [ ] Add full battle end-state handling for stalemate and no-legal-move edge cases.
- [ ] Add formation selection screen with up to 3 generated layouts per side.
- [ ] Enforce pawn-front placement constraints in formation generation.
- [ ] Add battle replay log panel (turn-by-turn with captures and General XP events).
- [ ] Add in-app seed input and explicit rematch with same seed.

## P1 - Core Gameplay Expansion

- [ ] Add recruitment/challenge mechanic (tile control + challenge check).
- [ ] Add morale system tied to General presence and material imbalance.
- [ ] Add tactical terrain effects (cover, chokepoints, blocked lanes by preset).
- [ ] Add army inspection panel from world map (piece counts + general skills).
- [ ] Add fog-of-war option for hidden enemy stack composition.

## P1 - AI Quality

- [ ] Improve strategic AI with 1-ply lookahead and risk scoring.
- [ ] Improve battle AI with lightweight minimax and piece-safety heuristics.
- [ ] Add AI difficulty levels (easy/normal/hard) with deterministic behavior per seed.

## P2 - UX and Product

- [ ] Add onboarding screen with concise rule explanation and controls.
- [ ] Add visual indicators for passable/blocked strategic tiles and battle hazards.
- [ ] Add settings screen (animation speed, AI delay, sound on/off).
- [ ] Add pause menu with quick restart and return-to-setup actions.

## P2 - Engineering and Stability

- [ ] Increase domain test coverage for collision and survivor army reconstruction.
- [ ] Add golden tests for world and battle UI states.
- [ ] Split large screen state into controller/services for easier maintenance.
- [ ] Add CI workflow for `flutter analyze` + `flutter test` on push/PR.

## Backlog / Optional

- [ ] Integrate external chess engine mode (Stockfish-based) behind a feature flag.
- [ ] Add campaign mode with scenario progression.
- [ ] Add local hot-seat save/load support.
