Implement Maneuver Planning Logic (AI)

Description: Update the enemy AI logic to plan both a destination hex (plannedMove) and a final orientation (plannedRotation) during its planning phase, ensuring the combined maneuver is affordable within its SP budget.

Tasks:

Modify AI functions (processEnemyTurn, potentially creating a new planEnemyManeuver function):

AI logic should determine both a target hex (targetQ, targetR) and a target orientation (targetOrientation). (Initial AI can be simple: move towards player, orient towards player).

Call Combat:calculateManeuverCost using the AI ship's current state and its targets.

Check if calculatedCost <= gameState.combat.enemyShip.currentSP.

If affordable, store the targets in enemyShip.plannedMove and enemyShip.plannedRotation.

If unaffordable, AI must revise its plan (e.g., shorter move, less rotation, or do nothing). Implement a simple fallback (e.g., stay put, no rotation).

Ensure AI planning happens before the Player Planning phase, storing the plan internally without revealing it.

Acceptance Criteria:

Enemy AI calculates the SP cost for its intended move and rotation.

AI successfully plans an affordable maneuver (move + rotation) and stores it in enemyShip.plannedMove and enemyShip.plannedRotation.

AI has a fallback behavior if its desired maneuver is too expensive.

Notes: AI complexity can be increased later. The core requirement is planning both aspects within the SP budget. Depends on Ticket 3.X.1 and the calculateManeuverCost function from 3.X.2.