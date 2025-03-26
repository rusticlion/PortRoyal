Description:

Develop an inventory screen to display the player’s resources, setting up 
a 10-slot structure for future item management.

Tasks:

Add an inventory table to GameState with 10 slots: GameState.inventory = { 
slots = {} }.
Create an inventory screen showing:
10 empty slots (for future cargo/items).
A separate section displaying current resources from GameState.resources 
(e.g., "Gold: 50, Rum: 0").
Add a button to return to the main Port Royal screen.
(Optional) Include debug functionality to add resources (e.g., 10 rum) for 
testing.
Acceptance Criteria:

The inventory screen shows 10 empty slots and lists current resources.
Players can close the screen and return to the main Port Royal hub.
Notes:

Slots will hold cargo or unique items in future sprints (e.g., Sprint 4 
for trading).
For now, display GameState.resources separately; slots remain empty until 
trading is implemented.
Keep the UI clean and legible within the retro style.
