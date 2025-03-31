 Task: Create Contextual Ship Info Display

Goal: Allow players to view detailed ship stats on demand, replacing static sidebars.

Implementation:

Modify Combat:mousemoved to detect hovering over a hex containing any part of a ship (player or enemy).

Create a new function Combat:drawShipInfoWindow(shipData) that draws a temporary, clean pop-up window (similar to unit stat screens in Fire Emblem).

This window should display: Ship Name, Class, Current/Max HP, Current/Max CP (if player), Speed, Firepower Dice, Evade Score (if > 0), any active Modifiers affecting the ship.

In Combat:draw, call drawShipInfoWindow for the hovered ship. The window should appear near the hovered ship but avoid obscuring critical areas.

Acceptance Criteria:

Hovering over any ship (player or enemy) displays a detailed info window for that ship.

The info window disappears when the mouse moves off the ship.

The main combat HUD remains minimal.