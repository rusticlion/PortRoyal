Adapt Action Planning & Resolution for Arcs

Description: Modify the existing Action Planning and Resolution phases to incorporate firing arc checks after the Maneuver Resolution phase.

Tasks:

Modify the Player Action Planning phase logic:

When the player selects the "Fire Cannons" action from the contextual menu (Ticket AdHoc/UI_Task_3), before showing the Confirmation Window (Ticket AdHoc/UI_Task_4):

The UI should now require selecting a target hex (likely the enemy ship's hex).

Check if the target hex is within the player ship's firing arc using Combat:isInFiringArc based on the ship's orientation after the maneuver resolution.

If not in arc, disallow targeting or show feedback ("Target not in arc").

If in arc, proceed to the Confirmation Window.

Modify Combat:fireCannons: This function now implicitly assumes the target is valid (checked during planning). No changes needed here unless damage/effects depend on which arc was used (future enhancement).

Modify Enemy AI Action Planning (chooseEnemyAction or similar):

When planning "Fire Cannons", the AI must check if the player ship is within its firing arc based on its orientation after its planned maneuver.

If the player is not in arc, the AI should choose a different action (e.g., Evade, Repair, or potentially prioritize rotation next turn).

Acceptance Criteria:

Player can only target enemy ships within their firing arc during the Action Planning phase.

The Confirmation Window for "Fire Cannons" only appears if a valid target in arc is selected.

Enemy AI only attempts to fire if the player is within its firing arc after its maneuver.

Notes: This integrates the new positioning mechanics directly into action constraints. Depends on 3.X.4 (Maneuver Resolution) and 3.X.5 (Firing Arc Logic).