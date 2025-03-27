Description:

Implement logic to resolve battles, distribute loot, and return to 
exploration mode.

Tasks:

Define outcomes in combat.lua:
Win: Enemy HP ≤ 0.
Loss: Player HP ≤ 0 (game over for now).
Escape: Player moves off grid (dice roll TBD in Sprint 6).
Award loot (e.g., 10 gold) on win via GameState:addResources.
Update GameState.combat and transition back to GameState.settings.portMode 
= false.
Acceptance Criteria:

Game returns to exploration mode after a battle ends.
Loot (e.g., 10 gold) is added to GameState.resources.gold on victory.
Ship damage persists (e.g., HP carries over) until repaired.
Notes:

Keep outcomes simple (e.g., fixed loot); expand in Sprint 4.
Loss condition can trigger a game over screen; refine later.
