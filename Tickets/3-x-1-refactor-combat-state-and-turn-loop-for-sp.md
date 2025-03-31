Refactor Combat State & Turn Loop for SP/Planning

Description: Modify the combat state (gameState.combat) and the main combat loop in combat.lua to accommodate the new Sail Point (SP) resource, planned maneuvers (move + rotation), and the revised turn structure (Planning -> Resolution phases).

Tasks:

Modify gameState.combat ship objects (playerShip, enemyShip) to include:

currentSP: Current sail points for the turn.

maxSP: Maximum sail points (based on ship class: Sloop=5, Brigantine=4, Galleon=3). Initialize this in Combat:initBattle.

plannedMove: Table {q, r} storing the intended destination hex (or nil).

plannedRotation: Number 0-5 storing the intended final orientation (or nil).

Refactor the main combat turn progression logic in combat.lua (likely affecting endPlayerTurn, processEnemyTurn, finalizeEnemyTurn, and potentially needing new phase-handling functions) to follow the new structure:

Start of Turn: Replenish CP and SP. Clear plannedMove, plannedRotation for both ships.

Enemy Planning Phase (internal logic placeholder).

Player Planning Phase (Movement & Rotation).

Resolution Phase (Maneuver).

Player Planning Phase (Action).

Resolution Phase (Action).

End of Turn.

Ensure SP is replenished correctly at the start of each ship's turn segment or the overall turn start.

Acceptance Criteria:

gameState.combat correctly stores currentSP, maxSP, plannedMove, and plannedRotation for both ships.

maxSP is correctly initialized based on ship class in initBattle.

SP is replenished at the start of the turn.

The main combat loop structure in combat.lua reflects the new phases in the correct order (even if some phases are currently empty placeholders).

Game transitions between these new phases correctly.

Notes: This is a foundational structural change. Subsequent tickets depend heavily on this. Focus on the state and loop structure first; detailed logic for each phase comes next.