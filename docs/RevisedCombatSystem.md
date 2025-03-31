# Pirate's Wager: Blood for Gold - Combat Rules (Revised)

## 1. Overview

This document outlines the rules for the tactical naval combat system in Pirate's Wager: Blood for Gold. Combat takes place on a 10x10 hex grid and emphasizes simultaneous maneuver planning, prediction, resource management (Sail Points & Crew Points), and risk/reward dice mechanics inspired by Forged in the Dark (FitD).

## 2. Key Concepts

*   **Hex Grid:** A 10x10 grid using pointy-top hexes and axial coordinates (q, r).
*   **Simultaneous Maneuvering:** Player and AI plan their movement and rotation secretly, and these maneuvers are resolved simultaneously.
*   **Sail Points (SP):** A per-turn resource representing a ship's agility, used to plan movement (moving hexes) and rotation (changing facing). SP varies by ship class.
*   **Crew Points (CP):** A per-turn resource representing the crew's capacity for action, used to execute combat actions like firing cannons, evading, or repairing. CP varies by ship class and current crew count (for the player).
*   **Orientation & Firing Arcs:** Ships have a specific facing (orientation). Weapons can only target hexes within defined firing arcs relative to the ship's current orientation.
*   **FitD Dice Mechanics:** Actions are resolved by rolling a pool of d6s. The highest die determines the outcome: Critical (multiple 6s), Success (highest is 6), Partial Success (highest is 4-5), or Failure (highest is 1-3).

## 3. Battlefield & Ships

*   **Grid:** 10x10 hexes.
*   **Ship Representation:**
    *   Ships occupy 1-4 hexes based on class.
    *   Each ship has a central anchor hex (`position {q, r}`) and an `orientation` (0-5, representing 60° increments, 0=North).
    *   Ship shapes rotate based on orientation.
*   **Ship Classes & Base Stats:**

    | Class      | Hex Size/Shape | Max HP | Base Max SP | Base Max CP | Base Speed (Moves/Turn) | Base Firepower (Dice) | Firing Arcs          |
    | :--------- | :------------- | :----- | :---------- | :---------- | :---------------------- | :-------------------- | :------------------- |
    | Sloop      | 1 hex          | 10     | 5           | 2 (*Note 1*) | 3                       | 1                     | Forward Only         |
    | Brigantine | 2 hexes (line) | 20     | 4           | 4 (*Note 1*) | 2                       | 3                     | Broadsides (Sides)   |
    | Galleon    | 4 hexes (kite) | 40     | 3           | 6 (*Note 1*) | 1                       | 6                     | Broadsides (Sides)   |

    *Note 1: Player ship's Max CP is based on `#gameState.crew.members`, capped by ship capacity. Enemy Max CP uses these base values.*

## 4. Combat Turn Structure

Each combat turn follows this sequence:

1.  **Start of Turn:**
    *   Replenish `currentSP` to `maxSP` for both ships.
    *   Replenish `currentCP` to `maxCP` for both ships.
    *   Clear any temporary turn-based effects or states (e.g., evade scores from previous turns if applicable, planned moves/rotations).
    *   Advance turn counter (`gameState.combat.turnCount`).

2.  **Enemy Planning Phase (Internal):**
    *   AI determines its intended maneuver (`plannedMove` hex and `plannedRotation` orientation).
    *   AI calculates SP cost and ensures the plan is affordable. Revises if necessary.
    *   AI determines its intended action(s) for the Action Phase (based on anticipated post-maneuver state).
    *   *Plans are stored internally, not revealed to the player.*

3.  **Player Planning Phase (Movement & Rotation):** (`gameState.combat.phase = "playerMovePlanning"`)
    *   Player sees current board state, their available SP.
    *   Player selects a target **orientation** using UI controls.
    *   Player selects a target **destination hex** from valid moves.
    *   UI displays SP cost for the planned move path + planned rotation change.
    *   Player cannot confirm a plan costing more than `currentSP`.
    *   Player **commits** the maneuver plan (stores destination in `playerShip.plannedMove`, final orientation in `playerShip.plannedRotation`).

4.  **Resolution Phase (Maneuver):** (`gameState.combat.phase = "maneuverResolution"`)
    *   **Rotation Update:** Internal `ship.orientation` state is instantly updated for *both* ships based on their `plannedRotation`.
    *   **Collision Check:** Check if `plannedMove` destinations conflict. Adjust `plannedMove` destinations for involved ships according to collision rules (e.g., stop 1 hex short).
    *   **Movement Execution & SP Deduction:**
        *   Animate both ships rotating towards their new orientation *while* moving towards their (potentially adjusted) destination hexes.
        *   Calculate the *actual* SP cost incurred for the maneuver performed (actual hexes moved + rotation steps).
        *   Deduct SP: `ship.currentSP -= actualCost`.
        *   Update internal `ship.position` state upon animation completion.
    *   Clear `plannedMove` and `plannedRotation` for both ships.

5.  **Player Planning Phase (Action):** (`gameState.combat.phase = "playerActionPlanning"`)
    *   Player sees the board state *after* maneuvers have resolved.
    *   Player selects actions (Fire, Evade, Repair, etc.) using available **CP**.
    *   Targeting for actions like "Fire Cannons" is constrained by the ship's current orientation and **firing arcs**.
    *   Selecting an action leads to the Confirmation Window (showing dice/modifiers/cost).
    *   Player Confirms or Cancels the action.

6.  **Resolution Phase (Action):** (`gameState.combat.phase = "actionResolution" or "displayingResult"`)
    *   If player confirmed action: Deduct CP, roll dice, determine outcome, apply effects (damage, repair, evade score).
    *   Display action results dynamically (dice roll visualization, outcome text, effect summary).
    *   AI executes its planned action(s) sequentially, using its remaining CP. AI targeting also respects firing arcs. Results are displayed dynamically.

7.  **End of Turn:**
    *   Perform any end-of-turn cleanup (e.g., expire temporary effects).
    *   Check win/loss conditions.
    *   Loop back to Start of Turn for the next turn number.

## 5. Core Mechanics Deep Dive

### 5.1. Sail Points (SP)

*   **Purpose:** Governs maneuverability (movement and rotation).
*   **Replenishment:** Fully restored to `maxSP` at the start of each turn.
*   **Costs (Planned - Subject to Tuning):**
    *   Move 1 Hex: 1 SP
    *   Rotate 60° (1 facing change): 1 SP
*   **Planning:** SP cost is calculated based on the planned path distance + the number of 60° steps needed to reach the planned orientation. The maneuver cannot be committed if `Total Cost > currentSP`.
*   **Deduction:** SP is deducted during the Maneuver Resolution phase based on the *actual* movement and rotation performed (after collision checks).

### 5.2. Crew Points (CP)

*   **Purpose:** Governs the crew's ability to perform actions (combat, repair, etc.).
*   **Replenishment:** Fully restored to `maxCP` at the start of each turn.
*   **Source:**
    *   Player: Number of crew members currently on ship (`#gameState.crew.members`), capped by ship's `crewCapacity`.
    *   Enemy: Based on ship class (`shipUtils.getBaseCP`).
*   **Costs:** Defined per action (see Actions List).
*   **Usage:** Spent during the Action Planning/Resolution phases to execute actions. Multiple actions can be performed if enough CP is available.

### 5.3. Movement & Rotation

*   **Planning:** Player/AI select both a target hex and a target orientation during their respective planning phases, constrained by SP.
*   **Resolution:** Planned rotations and moves resolve simultaneously during the Maneuver Resolution phase. Ship orientations update instantly internally, while visual rotation tweens alongside movement animation. SP is deducted based on the resolved maneuver.

### 5.4. Firing Arcs

*   **Definition:** Each ship class has defined arcs relative to its forward direction (Orientation 0).
    *   **Forward:** Directly ahead.
    *   **Sides (Broadsides):** To the left and right flanks.
    *   **Rear:** Directly behind.
*   **Constraint:** The "Fire Cannons" action can only target hexes that fall within an active firing arc based on the ship's *current* orientation (after maneuvering).
*   **Implementation:** `Combat:isInFiringArc(ship, targetQ, targetR)` checks validity. `Combat:getFiringArcHexes(ship)` calculates all valid target hexes within range.

### 5.5. Dice Rolls & Outcomes (FitD)

*   **Rolling:** Actions trigger a roll of 1-5 d6s. The pool size = Base Dice (from ship/action) + Modifiers (from crew, situation, evade scores). Max 5 dice.
*   **Zero Dice:** If modifiers reduce the pool to 0 or less, roll 2d6 and take the *lowest* result.
*   **Interpretation:** Determined by the *single highest die* rolled:
    *   **Critical Success:** Multiple 6s rolled. (Outcome Level 3)
    *   **Success:** Highest die is a 6. (Outcome Level 2)
    *   **Partial Success:** Highest die is 4 or 5. (Outcome Level 1)
    *   **Failure:** Highest die is 1, 2, or 3. (Outcome Level 0)
*   **Effects:** Actions have different effects based on the Outcome Level achieved (see Actions List).

### 5.6. Collisions

*   **Detection:** Checked during Maneuver Resolution based on `plannedMove` destinations.
*   **Rule (Basic):** If two ships plan to move to the same hex, both stop 1 hex short along their planned path. Their orientation changes still resolve as planned. SP cost is adjusted based on actual distance moved. *(More complex rules can be added later)*.

## 6. Actions List

Actions are performed during the Action Phase using CP. Player actions require confirmation via the Confirmation Window.

*   **Fire Cannons**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_FIRE` (1 CP)
    *   **Targeting:** Requires selecting an enemy ship hex within a valid firing arc and range.
    *   **Dice Pool:** `shipUtils.getBaseFirepowerDice(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   `+1` Point Blank (adjacent hex)
        *   `-X` Target Evading (where X is target's `evadeScore`)
        *   `+Y` Gunner Skill (Player only: `member.skill * Constants.GAME.GUNNER_SKILL_MULTIPLIER`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:**
        *   Critical (Lvl 3): `Constants.COMBAT.DAMAGE_CRITICAL` (3 HP) damage.
        *   Success (Lvl 2): `Constants.COMBAT.DAMAGE_SUCCESS` (2 HP) damage.
        *   Partial (Lvl 1): `Constants.COMBAT.DAMAGE_PARTIAL` (1 HP) damage.
        *   Failure (Lvl 0): No damage.
    *   **Note:** Target's `evadeScore` is reset to 0 *after* being applied to the incoming attack roll.

*   **Evade**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_EVADE` (1 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** `shipUtils.getBaseSpeed(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Sets the ship's `evadeScore` for the *next* turn (or until used).
        *   Critical (Lvl 3): `evadeScore = 3`
        *   Success (Lvl 2): `evadeScore = 2`
        *   Partial (Lvl 1): `evadeScore = 1`
        *   Failure (Lvl 0): `evadeScore = 0`
    *   **Note:** `evadeScore` reduces the number of dice rolled by enemies attacking this ship.

*   **Repair**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_REPAIR` (2 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** 1 (Base) + Modifiers.
    *   **Modifiers:**
        *   `+Y` Surgeon Skill (Player only: `member.skill`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Restores ship durability (HP).
        *   Critical (Lvl 3): `+Constants.COMBAT.REPAIR_CRITICAL` (15 HP) restored.
        *   Success (Lvl 2): `+Constants.COMBAT.REPAIR_SUCCESS` (10 HP) restored.
        *   Partial (Lvl 1): `+Constants.COMBAT.REPAIR_PARTIAL` (5 HP) restored.
        *   Failure (Lvl 0): No HP restored.
    *   **Note:** Cannot repair above the ship's maximum durability.

*   **End Turn** (Player Only Action Menu Option)
    *   **CP Cost:** 0 CP
    *   **Effect:** Immediately ends the player's action planning phase and proceeds to the enemy's action resolution (if applicable) or the start of the next turn.

## 7. AI Behavior

*   Enemy AI plans its maneuver (move + rotation) within its SP budget during the Enemy Planning Phase.
*   Enemy AI plans its action(s) based on its anticipated post-maneuver state (e.g., choosing Fire Cannons only if the player is expected to be in arc).
*   During the Action Resolution Phase, the AI executes its planned actions sequentially using its available CP, respecting firing arcs based on its *actual* post-maneuver position/orientation.
*   Current AI prioritizes: Repair (if low HP), Evade (if moderate HP), Fire Cannons (if high HP and target in arc), Move closer/into arc.

## 8. Winning & Losing

*   **Victory:** Enemy ship durability reaches 0 HP. Player may receive loot. Combat ends, return to Exploration mode.
*   **Defeat:** Player ship durability reaches 0 HP. Results in Game Over (current implementation).
*   **Retreat:** (Future Feature) Player or enemy moves off the battle grid. May involve a dice roll to determine success.

## 9. UI Summary

*   **Minimal HUD:** Displays Turn/Phase, Player HP/CP/SP, Enemy HP.
*   **Ship Info Window:** On-demand details via hover.
*   **Action Menu:** Contextual list of actions available during player action planning.
*   **Confirmation Window:** Displays dice pool breakdown, modifiers, and costs before committing an action.
*   **Result Overlay:** Temporarily displays dice results and effects after an action resolves.
*   **Maneuver Planning:** Visual feedback for planned path, orientation, and SP cost.
*   **Firing Arc Highlight:** Visual indication of valid target hexes when planning "Fire Cannons".