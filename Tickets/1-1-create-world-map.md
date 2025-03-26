Ticket 1: Create Caribbean Map with Zones
Description: Develop a Caribbean map divided into 10-15 distinct, 
irregular zones (e.g., "Calm Waters," "Pirate Territory"). Each zone is a 
clickable area on a non-hex-based global map.
Tasks:
Design a visual layout of the Caribbean with 10-15 zones, ensuring each 
has a unique shape and name.
Implement interactive zone areas that highlight on mouse-over and respond 
to clicks.
Create a tooltip system displaying zone name, basic info, and time cost to 
sail there (e.g., "Calm Waters - 1 week").
Define zone adjacencies in a data structure (e.g., a graph) for movement 
logic.
Acceptance Criteria:
The map shows 10-15 zones with distinct boundaries and names.
Mouseing over a zone highlights it and displays a tooltip with name and 
time cost.
Clicking an adjacent zone triggers movement (handled in Ticket 2).
Notes:
Zones should be large enough for easy clicking.
For Sprint 1, assume a uniform 1-week cost per transition; variable costs 
(e.g., based on distance) can be added later.
No hex grid on the global map; keep it abstract.

🐱💤