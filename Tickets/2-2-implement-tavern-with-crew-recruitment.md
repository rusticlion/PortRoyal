Description:

Develop the tavern location within Port Royal, where players can recruit 
crew members with basic roles (e.g., Navigator, Gunner, Surgeon), costing 
gold and respecting crew capacity.

Tasks:

Design side-view pixel art for the tavern interior (placeholder for now).
Create a recruitment interface displaying at least three available crew 
members, each with:
Name (e.g., "Jim Hawkins")
Role (e.g., "Navigator")
Hiring cost (e.g., 10 gold)
Implement a "Hire" button that:
Checks if GameState.resources.gold >= cost using GameState:canAfford.
Checks if #GameState.crew.members < GameState.ship.crewCapacity.
Deducts gold via GameState:spendResources and adds the crew member to 
GameState.crew.members if conditions are met.
Display error messages (e.g., "Not enough gold" or "Crew is full") if 
hiring fails.
Add a button to return to the main Port Royal screen.
Acceptance Criteria:

The tavern screen displays with basic pixel art.
At least three crew members with different roles are available to hire.
Hiring deducts gold and adds the crew member if capacity allows (e.g., max 
4 for Sloop).
Error messages appear when gold or crew space is insufficient.
Players can return to the main Port Royal screen.
Notes:

Assume a fixed crew capacity of 4 for the starting Sloop 
(GameState.ship.class = "sloop").
Crew stats can be placeholders (e.g., skill = 1, loyalty = 5, health = 
10); expand in later sprints.
Store crew data in GameState.crew.members as per the existing structure.
