 Task: Streamline Enemy Turn Visuals

Goal: Make enemy turns resolve quickly and clearly without overwhelming the player with unnecessary AI decision detail.

Implementation:

In Combat:processEnemyTurn: Keep the AI logic, but modify the display.

When the enemy acts, don't show a confirmation window for them.

Directly trigger the Combat:drawActionResultOverlay (Task 5) showing the result of the enemy action (e.g., "Enemy Fires Cannons!", dice roll, "Success!", "-10 HP!").

Maybe add a very brief preceding indicator like a small "!" icon over the acting enemy ship.

Ensure enemy turn actions resolve visually without requiring player clicks to advance unless absolutely necessary (e.g., end of their entire turn).

Acceptance Criteria:

Enemy turns are visually less intrusive than player turns.

The results of enemy actions are clearly communicated via the feedback overlay.

The game flow during the enemy turn feels reasonably quick.

General Guidelines for the Team:

Iteration: This UI overhaul may require iteration. Encourage the team to build simple versions first and then refine based on usability testing (even just internal team testing).

Visual Consistency: Ensure new UI elements (windows, menus, overlays) match the established retro pixel art style. Placeholder art is acceptable initially, but the layout and flow are key. New art assets might be required.

Testing Resolution: Test constantly at the target 800x600 resolution to ensure readability. What looks fine on a large monitor might be unreadable when scaled down. Use pixel-perfect fonts.

Input Handling: Pay close attention to mouse clicks. Ensure clicks are only registered by the topmost relevant UI element (e.g., clicking "Confirm" shouldn't also register as clicking on the hex grid underneath). Manage game states (gameState.combat.phase) carefully to control input.

Code Structure: Keep the new drawing functions (drawShipInfoWindow, drawActionMenu, etc.) organised within combat.lua or potentially a new src/ui/combatUI.lua module if combat.lua becomes too large.