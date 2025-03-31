 Task: Develop Pre-Action Confirmation Window (Dice Stakes)

Goal: Show the player the exact dice roll setup before they commit an action, clearly displaying stakes.

Implementation:

Introduce a new combat state, e.g., gameState.combat.phase = "confirmingAction", storing which action is being confirmed.

When an action (Fire, Evade, Repair) is selected from the menu (Task 3), enter this state.

Create Combat:drawConfirmationWindow(actionData):

Draws a pop-up window.

Displays: Action Name ("Fire Cannons"), Target (if applicable, e.g., "Enemy Sloop"), Base Dice, List of Modifiers (e.g., "+1 Point Blank", "-1 Target Evading"), Final Dice Pool (e.g., "Rolling 3d6").

Briefly indicate potential outcomes (e.g., "6=Success, 4-5=Partial").

Show the CP Cost.

Provide clear "Confirm" and "Cancel" buttons within this window.

Modify Combat:mousepressed to handle clicks on "Confirm" or "Cancel". Cancel returns to the Action Phase/Menu. Confirm proceeds to execute the action (Task 5).

Acceptance Criteria:

Selecting an action from the menu displays a confirmation window.

The window clearly shows the number of dice to be rolled, accounting for all modifiers.

The player must explicitly Confirm or Cancel the action.

CP cost is visible.