Description:

Modify the map and ship modules to trigger battles when encountering enemy 
ships.

Tasks:

Add a GameState.enemyShips table to track enemy ship locations (e.g., { 
zone = 2, class = "Sloop" }).
Update ship.lua to detect enemy ships in the same zone during movement 
(check GameState.ship.currentZone).
Transition to combat mode by setting a GameState.settings.combatMode flag 
and initializing GameState.combat.
Acceptance Criteria:

Battles start automatically when the player moves to a zone with an enemy 
ship.
Game transitions smoothly from exploration to combat mode (UI switches to 
combat screen).
Notes:

Spawn one test enemy in a fixed zone (e.g., "Nassau") for now.
Depends on Ticket 3.1 for combat setup.
