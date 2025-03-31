 Implement Firing Arcs (Logic & Data)

Description: Define firing arc data for ship classes and implement the logic to check if a target hex is within a ship's firing arc based on its current orientation.

Tasks:

Add firingArcs data to Combat.shipDefinitions. Define arcs relative to the ship's forward direction (orientation 0). Example:

sloop: { forward = true, sides = false, rear = false } (Maybe just forward?)

brigantine: { forward = false, sides = true, rear = false } (Broadsides)

galleon: { forward = true, sides = true, rear = false } (Broadsides + some forward?) - Needs Design Clarification based on kite shape. Let's assume broadsides for now: { forward = false, sides = true, rear = false }.

Implement Combat:getFiringArcHexes(ship): Given a ship object (with position, orientation, class), return a list of absolute hex coordinates {q, r} that fall within its defined firing arc(s) and within a reasonable range (e.g., 5 hexes). This requires mapping relative arc definitions to world space based on orientation.

Implement Combat:isInFiringArc(ship, targetQ, targetR): A simpler check, returns true if the specific targetQ, targetR is within the firing arc calculated by getFiringArcHexes (or a direct geometric calculation).

Acceptance Criteria:

shipDefinitions includes firingArcs for each class.

Combat:getFiringArcHexes correctly calculates the set of hexes within range and arc based on ship orientation.

Combat:isInFiringArc correctly returns true/false for a given target hex.

Notes: This ticket focuses purely on the logic. Visualization comes in 3.X.7. Firing arc definitions might need refinement based on gameplay testing. Needs careful hex math for orientation and relative positions.