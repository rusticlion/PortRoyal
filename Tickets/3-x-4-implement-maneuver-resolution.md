 Implement Maneuver Resolution (Simultaneous)

Description: Implement the core logic for the Maneuver Resolution phase where both player and enemy ships simultaneously execute their planned rotations and movements, handling collisions and deducting SP.

Tasks:

Create logic within the maneuverResolution phase handler in combat.lua.

Collision Check: Before movement, check if playerShip.plannedMove and enemyShip.plannedMove result in the same destination hex or if paths cross in a way that implies collision (simplest: check destination hex conflict). Define a collision rule (e.g., both ships stop one hex short of their plannedMove along their path). Update plannedMove for affected ships if a collision occurs.

Rotation Update: Instantly update playerShip.orientation = playerShip.plannedRotation and enemyShip.orientation = enemyShip.plannedRotation.

Movement & SP Deduction:

For both ships, determine the actual path taken (original plannedMove or adjusted plannedMove after collision).

Calculate the actual SP cost incurred using Combat:calculateManeuverCost based on the start position/orientation and the actual end position/orientation.

Deduct cost: ship.currentSP = ship.currentSP - actualCost.

Set up simultaneous animation: Store start/end positions/orientations. The existing Ship:update lerping can be adapted, potentially needing coordination in combat.lua to update both ships based on their individual start/end points and a shared timer. Rotation should visually tween alongside movement.

State Update: After animations complete (or instantly for now, with animation hooks added later):

Update playerShip.position and enemyShip.position to their final resolved hexes.

Clear plannedMove and plannedRotation for both ships.

Transition gameState.combat.phase to Player Action Planning.

Acceptance Criteria:

Ship orientations are updated based on plannedRotation at the start of the phase (internal state).

A basic collision rule prevents ships from occupying the same hex.

Ships move (visually, eventually) towards their resolved destinations simultaneously.

Correct SP cost is deducted based on the actual maneuver performed.

Ship positions are updated correctly in gameState.combat.

plannedMove and plannedRotation are cleared.

Phase transitions correctly to Action Planning.

Notes: Simultaneous animation can be tricky. Initial implementation might just snap positions/orientations after calculating costs, with visual tweening added later. Collision rules can be basic for now. Depends on Tickets 3.X.1, 3.X.2, 3.X.3.