Description:

Add core combat actions (Fire Cannons, Evade, Repair) integrated with the 
dice mechanics.

Tasks:

Define action functions in combat.lua:
fireCannons: Deals damage based on firepower (e.g., Sloop = 2).
evade: Attempts to dodge incoming attacks.
repair: Restores hull HP (e.g., 5 HP per success).
Integrate dice rolls (from Ticket 3.3) into each action, using ship/crew 
stats.
Apply outcomes (e.g., damage dealt, evasion success) to ship stats in 
GameState.combat.
Acceptance Criteria:

Players can select and perform Fire Cannons, Evade, or Repair during their 
turn.
Each action triggers a dice roll with appropriate outcomes (e.g., Fire 
Cannons deals damage on success).
Ship stats (e.g., durability) update correctly based on action results.
Notes:

Use placeholder stats for now (e.g., 1 die per action); refine with crew 
skills in later sprints.
Depends on Ticket 3.3 for dice mechanics.
