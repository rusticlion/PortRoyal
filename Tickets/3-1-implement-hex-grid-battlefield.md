Description:

Develop a 10x10 hex grid for naval battles, including ship placement and 
movement mechanics.

Tasks:

Create a hex grid data structure (e.g., a 10x10 array) to represent the 
battle area in a new combat.lua module.
Implement functions to place ships on the grid, respecting their size (1 
hex for Sloop, 2 for Brigantine, 4 for Galleon, per the design doc).
Develop movement logic allowing ships to move to adjacent hexes based on 
their speed stat (e.g., Sloop = 3 hexes/turn).
Acceptance Criteria:

A 10x10 hex grid is visible during battles (placeholder visuals OK for 
now).
Player and enemy ships can be placed on the grid at the start of combat.
Player ship can move to adjacent hexes during a turn, respecting speed 
limits.
Notes:

Use GameState.ship.class to determine size and speed (e.g., Sloop: 3 
hexes, 1 hex size).
Store combat state in a new GameState.combat table (e.g., { grid, 
playerShip, enemyShip }).
No wind effects yet; add in Sprint 6.
