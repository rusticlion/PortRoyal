Implement Maneuver Planning UI & Logic (Player)

Description: Develop the UI and input handling for the Player Planning (Movement & Rotation) phase, allowing the player to select a destination hex and final orientation, constrained by available Sail Points (SP).

Tasks:

Define SP costs in constants.lua or combat.lua: SP_COST_MOVE_HEX = 1, SP_COST_ROTATE_60 = 1.

Create helper function Combat:calculateManeuverCost(startHex, endHex, startOrientation, endOrientation) that returns the total SP cost for a potential maneuver (path distance + rotation steps). Use hexDistance for path distance. Calculate rotation steps efficiently (e.g., min(abs(end - start), 6 - abs(end - start))).

Modify Combat:drawUI or a related drawing function:

Display currentSP / maxSP in the minimal player HUD.

Modify Combat:draw (or a planning-phase specific draw function):

When the player ship is selected during the playerMovePlanning phase:

Show valid move hexes (potentially color-coded by SP cost).

Display UI elements for selecting target orientation (e.g., "Rotate Left"/"Rotate Right" buttons near the ship or in a fixed UI panel). Update a temporary variable holding the player's intended rotation.

Display the calculated SP cost breakdown for the hovered/selected move and the intended rotation change (e.g., "Move: 2 SP | Rotate: 1 SP | Total: 3 SP / 5 SP").

Modify Combat:mousepressed for the playerMovePlanning phase:

Handle clicks on rotation controls to update the temporary intended rotation.

Handle clicks on valid move hexes.

Implement a "Confirm Maneuver" button or mechanism.

When confirming: Check if totalCalculatedSPCost <= gameState.combat.playerShip.currentSP.

If affordable, store the selected destination hex in playerShip.plannedMove and the final orientation in playerShip.plannedRotation.

Transition gameState.combat.phase to the next phase (Maneuver Resolution).

If unaffordable, provide visual/audio feedback and do not commit/transition.

Acceptance Criteria:

Player UI clearly displays current/max SP.

Player can select a destination hex and a target orientation using UI controls.

The UI dynamically shows the SP cost for the planned move and rotation.

The player is prevented from confirming a maneuver that costs more SP than they have.

Confirming an affordable maneuver stores plannedMove and plannedRotation in gameState.combat.playerShip and advances the combat phase.

Notes: UI clarity is paramount here (Known Weakness!). Use clear visual cues for costs and affordability. Rotation controls need careful design for the low-res environment (maybe simple arrows?). Depends on Ticket 3.X.1.