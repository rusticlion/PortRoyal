 Task: Implement Dynamic Action Result Feedback

Goal: Replace the static feedback panel with a clear, temporary overlay showing the results of the confirmed action.

Implementation:

When "Confirm" is clicked (Task 4):

Perform the action logic (deduct CP, roll dice using diceSystem:roll, apply effects). Store the results (dice values, outcome, damage/repair/evade score) potentially in gameState.combat.actionResult as before.

Enter a brief new phase like gameState.combat.phase = "displayingResult".

Create Combat:drawActionResultOverlay():

Draws a prominent, temporary overlay (possibly centered or near the action's target).

Visually displays the dice roll (using diceSystem:drawWithHighlight).

Clearly shows the result text ("Critical Success!", "Partial Success", "Failure").

Shows the concrete effect (e.g., "-10 HP!", "+2 Evade Score!", "Repaired 5 HP!").

This overlay should either fade out after a short duration (e.g., 1.5-2 seconds) or require a click to dismiss, returning to the Action Phase.

Acceptance Criteria:

After confirming an action, the dice roll and results are shown clearly and dynamically.

The feedback is temporary and doesn't permanently clutter the screen.

The player understands the outcome of their action.

The game returns to the appropriate state (Action Phase or End Turn if CP is depleted/player chooses).