 UI - Visualize Firing Arcs & Planned Maneuvers

Description: Implement visual feedback for firing arcs during action planning and potentially visualize the planned maneuver during the maneuver planning phase.

Tasks:

Firing Arc Visualization:

Create Combat:drawFiringArcs(ship) function.

When the player selects "Fire Cannons" during the Action Planning phase, call this function.

It should visually highlight the hexes within the ship's firing arc (using getFiringArcHexes from 3.X.5). Use a distinct color or overlay.

(Optional but Recommended) Planned Maneuver Visualization:

During the Player Maneuver Planning phase (Ticket 3.X.2), draw a visual representation of the planned move:

A line or series of dots from the current position to the selected destination hex.

An indicator (e.g., a ghosted ship sprite or an arrow) showing the planned final orientation at the destination hex.

This visualization should update dynamically as the player adjusts their planned move/rotation.

Acceptance Criteria:

When planning to fire cannons, the valid firing arc hexes are clearly highlighted on the grid.

(If implemented) During maneuver planning, the player sees a clear preview of their intended path and final orientation.

Visualizations are clear and readable within the low-res style.

Notes: Arc visualization is crucial for usability. Planned maneuver visualization helps players understand their choices before committing SP. Depends on 3.X.2 and 3.X.5. Requires careful attention to visual clarity (Known Weakness!).