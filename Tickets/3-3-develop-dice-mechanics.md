Description:

Create a system to roll dice based on crew and ship stats, interpreting 
results per the design doc.

Tasks:

Implement a rollDice(numDice) function in combat.lua that rolls 1-5 d6s 
and returns results.
Define success criteria: 6 = Success, 4-5 = Partial Success, 1-3 = 
Failure.
Calculate outcomes (e.g., count successes) and return them for use in 
actions.
Acceptance Criteria:

Dice rolls generate correct results (e.g., rolling 3d6 might yield [6, 4, 
2]).
Results are interpreted accurately (e.g., 6 = 1 success, 4 = 0.5 success).
The system integrates with combat actions (e.g., Fire Cannons uses roll 
results).
Notes:

For Sprint 3, use a fixed number of dice (e.g., 1 per cannon for Fire 
Cannons) or basic crew stats from GameState.crew.members.
Expand with crew skills (e.g., Gunner adds dice) in Sprint 6.
