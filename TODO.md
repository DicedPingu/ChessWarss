# TODO - ChessWarss

## Doctrine (Approved)

- Campaign should feel like Total War-lite; battles remain chess-based.
- Logistics are army-first, not abstract treasury-first recruitment.
- Starvation in enemy territory is required.
- Supply sources must include forage, plunder, and local requisition.
- Settlement capture outcomes must include `Spare` and `Destroy` with different consequences.
- Temporary camps should favor defenders on the battle board (traps first).

## Phase 1 - Logistics Core (Completed)

### Logistics and Starvation
- [x] Add per-army supply tracking.
- [x] Add starvation ladder: low supply -> fatigue -> morale pressure -> desertion risk.
- [x] Show selected-army supply state in HUD.

### Supply Sources
- [x] Add local requisition from controlled settlements into nearby/occupying armies.
- [x] Add forage income in the field.
- [x] Add plunder gains from destructive capture outcomes.
- [x] Add square-level food tile control (secure fields for ongoing yield).
- [x] Add square-level pillage action (instant army supply, temporary tile exhaustion).

### Capture Outcomes
- [x] Add capture policy per active player: `Spare` or `Destroy`.
- [x] `Spare`: lower immediate gain, better long-term recovery.
- [x] `Destroy`: higher immediate gain, stronger long-term settlement damage.

### Conquered Food Scaling
- [x] Add occupation-age effect (older occupation -> higher stability/yield).
- [x] Add distance/connectivity effect (closer/connected territory feeds better).

## Phase 2 - Levy and Siege Pressure (In Progress)

### Levy Warfare (Experimental)
- [x] Add settlement manpower/levy pools.
- [x] Replace generic recruitment with levy-based reinforcement logic.
- [x] Add settlement `Levy` action on owned settlements.
- [x] Add forced levy intake on `Spare` captures.
- [ ] Tune levy composition and recovery rates from playtests.

### Siege-Style Pressure (Chess-Compatible)
- [ ] Add time-based siege pressure states tied to settlement control and battle triggers.
- [ ] Keep resolution chess-based while making sieges costly over turns.

## Later - Phase 3

### Territorial Development
- [ ] Evaluate camp-to-city progression with simple, readable rules.
- [ ] Make long-held conquered areas evolve into stronger food contributors.

### AI and UX
- [ ] Teach AI to choose `Spare` vs `Destroy` based on supply pressure.
- [x] Improve logistics explainability in HUD and logs.
- [x] Replace long-scroll world sidebar with compact no-scroll contextual HUD flow.
- [x] Make settlement/town selection useful even without active army selection.
- [x] Add optional AI-vs-AI battle skip with instant auto-resolve.
- [x] Add battle anti-stall turn-limit safeguard to prevent endless AI loops.
- [ ] Expand cowardly/green-general threatened behavior (panic, hesitation, command loss).
- [ ] Experiment with non-standard pawn/levy movement variants without breaking AI reliability.

## Open Decisions (User-Guided)

- [ ] Camp -> city conversion rule and timing.
- [ ] Final siege win condition model.
- [ ] Final levy composition and replenishment pacing.
- [ ] Eterna adventure campaign progression layer (quests/events/victory arcs beyond total elimination).

## Baseline Already In Place

- [x] Campaign map + tactical battle loop.
- [x] Settlement and camp entities with defensive context.
- [x] Morale and command systems in battle.
- [x] Save/load, onboarding, and settings.
- [x] Turn/ownership clarity pass on board visuals.
