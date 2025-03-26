Description:

Create the main interface for Port Royal, serving as the central hub for 
port-based activities. This screen allows players to access locations 
(tavern, shipyard) and management screens (crew, inventory), with a clear 
entry/exit point to the global map.

Tasks:

Design a main Port Royal screen with buttons: "Tavern," "Shipyard," 
"Crew," "Inventory," and "Set Sail."
Implement navigation logic: clicking a button opens the corresponding 
screen (e.g., tavern or shipyard).
Display the player’s current gold from GameState.resources.gold on the 
main screen.
Create placeholder side-view pixel art screens for the tavern and shipyard 
(to be refined later).
Ensure the "Set Sail" button returns the player to the global map by 
updating GameState.ship.isMoving and triggering the map view.
Acceptance Criteria:

The main Port Royal screen displays current gold (e.g., "Gold: 50").
Buttons for "Tavern," "Shipyard," "Crew," "Inventory," and "Set Sail" are 
present and functional.
Clicking "Tavern" or "Shipyard" opens a placeholder screen with basic 
pixel art.
Clicking "Set Sail" exits Port Royal and returns to the global map view.
The hub is accessible only when the ship is in the Port Royal zone (check 
GameState.ship.currentZone).
Notes:

Use side-view pixel art consistent with the retro style (e.g., 800x600 
resolution).
For now, focus on structure; detailed art and animations (e.g., flickering 
lanterns) can be added in Sprint 10.
Integrate with map.lua to detect when the ship is in Port Royal for hub 
access.
