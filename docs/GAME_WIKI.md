# ChessWarss Mini Wiki

This wiki is a quick reference for systems that are mostly NOT standard chess.
An in-game "Field Manual" dialog summarizes these same systems during setup, world map, and battle screens.

## 1) Campaign Layer (World Map)

### Goal
Control the campaign by moving army stacks, taking settlements, and winning battles until one side remains.

### Turn Economy
- Each player gets Command Points (CP).
- Most strategic actions cost CP.
- Food is a second resource used by aggressive movement and long-term upkeep.
- AI behavior can be tuned in setup (`Easy`, `Normal`, `Hard`) with deterministic seed-based outcomes.

### Army Stacks
- Armies move as stacks on the world map.
- Stacks can engage enemy stacks to trigger tactical battles.
- Stack state matters between turns (for example fatigue and temporary posture).

### Forced March
- Extends movement range for a turn.
- Costs food.
- Increases fatigue.
- Cannot be used while a stack is in fortified camp posture.

### Camps (Temporary Military Posture)
- Camps are explicit temporary entities on the campaign map.
- Camps are not settlements and expire after a short duration.
- Postures:
  - `Supply`: converts camp stock into food reserve.
  - `Fortified`: improves defensive battle context and local recovery.
  - `Raiding`: pressures nearby enemy settlements and can extract food.

### Camp vs Outpost Lifecycle
- A **camp** is a temporary field entity created by a stack and tied to posture management.
- A **minor outpost** is a consolidated camp state (lasting support footprint), but it is still not a settlement.
- Outposts keep camp identity and benefits; they do not become village/town/castle infrastructure.
- Breaking camp removes the local support node and returns the stack to open-march posture decisions.

### Fatigue
- Represents operational strain.
- Can increase from aggressive movement and poor supply.
- Affects campaign and battle pressure through penalties.

## 2) Settlements (Villages, Towns, Castles)

### Why Settlements Matter
Settlements are the logistics/control system of the campaign. They are not a simple "build town, spawn troops" loop.
Each tier has a different campaign role:
- Villages: stronger local food flow.
- Towns: stronger tax/governance throughput.
- Castles: strongest defensive anchor and command stability.

### Core Settlement Stats
- Owner
- Tier (village, town, castle)
- Tax yield
- Supply stock
- Garrison capacity / current garrison
- Unrest
- Culture rating
- Trap readiness (where applicable)

### Settlement Actions
- Tax: gain coin, usually increases unrest.
- Forage: increase supply stock, can increase unrest.
- Garrison: reinforce local defense, can reduce unrest and arm defenses.
- Study: improve command development at an economic cost.

### Defensive Effects in Battle
Settlements can grant defenders:
- Lane constraints (narrowed attack approach)
- Morale shield bonuses
- Trap effects (defensive ditch behavior)

## 3) Tactical Battle Layer (Not Pure Chess)

### Doctrine / Formation Selection
- Before battle, each side chooses from generated legal doctrine options.
- Legal doctrines depend on unit mix and general quality.
- Enemy doctrine remains hidden during selection.
- Suggestions are curated (fewer, stronger options).

### Contact Advance
- A command action that drives front-line pawn contact.
- Can trigger captures, clashes, repulses, and morale shifts.

### High Command
- One-time battle surge tied to general skill.
- Stronger generals can trigger larger coordinated advances.

### Opening Capture Block
- First-move capture pressure is intentionally limited to improve opening readability.

## 4) Generals and Command (Custom System)

### General Ranks
- High King
- Officer

### General Skills
- Fragile Marshal
- Field Commander
- Veteran Commander
- War Drummer

### General Trait Families
- Volatility (Fragile Marshal)
- Stability (Field Commander)
- Aggression (Veteran Commander)
- Momentum (War Drummer)

### What They Change
- Doctrine access and command profile
- Morale stability and rout pressure behavior
- Access to stronger command surges

### Design Intent
Generals are command anchors, not just stronger piece movers. Exposing them carelessly should be costly.

## 5) Morale and Rout (Custom System)

### Morale States
- Steady
- Wavering
- Routing
- Collapsed

### What Affects Morale
- Captures and losses
- Command quality
- Local battle context (nearby support/pressure)
- Settlement and supply context in campaign-to-battle flow

### Rout Pressure Outcomes
When routing pressure triggers, a side may:
- Rally
- Retreat
- Desert units

### Collapse Condition
If morale collapses, that side can lose the battle even before full piece elimination.

### In-Battle Decisive Signals
- The battle sidebar exposes quick decisive checks per side:
  - commander alive/lost
  - morale state pressure
  - legal-move lock risk
- These indicators are meant to explain why a battle is drifting toward collapse before the final result line appears.

## 6) Visibility Constraints (Non-Negotiables)

- Enemy doctrine stays hidden during doctrine selection.
- Opponent army setup is not directly configured from a single side's setup controls.
- Enemy command detail is intentionally partial in pre-battle intel.
- Match and battle logs summarize recent events for readability without revealing hidden setup choices.

## 7) Victory Flow

- Win tactical battles to remove enemy campaign presence.
- Capture/hold strategic positions and settlements.
- Campaign ends when only one player remains active.

## 8) Prototype Caveats Linked to Roadmap

- Campaign sidebar hierarchy and repeated controls are still being cleaned up.
- Battle AI weights for rout-risk and command preservation are still being tuned.
- Onboarding/settings/session controls are implemented; duplicate control-path cleanup remains.
- Rules explanations across settlement, supply, and battle modifiers are now unified in selected-stack intel and manual text.

All active caveats above are tracked in `TODO.md` (`Now` and `Next` sections).

## 9) Current Gameplay Notes

- This is an active prototype.
- Systems are intentionally being tuned toward:
  1) realism and believable campaign logic,
  2) playable/winnable momentum,
  3) tactical depth.

For direction and non-negotiables, see `docs/GAME_VISION.md`.
