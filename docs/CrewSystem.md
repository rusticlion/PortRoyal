# Crew System Documentation

## Overview

The crew management system tracks individual crew members, their distribution across different locations, and their effects on gameplay. It serves as the foundation for the staffing and personnel aspects of the game, encompassing recruitment, character progression, and gameplay effects like the Navigator's travel time reduction.

## Architecture

### Core Components

The crew system is built around several key components:

1. **Global Crew Pool**: A master list of all potential crew members in the game
2. **Location-Based Availability**: Tracking which crew members are available at which port locations
3. **Player's Crew Roster**: The collection of crew members currently serving on the player's ship
4. **Role-Based Effects**: Gameplay modifications based on crew roles (e.g., Navigators reducing travel time)

### Data Structures

#### Crew Member Object

Each crew member is a uniquely identifiable entity with a set of properties:

```lua
crewMember = {
    id = "js001",             -- Unique identifier
    name = "Jack Sparrow",    -- Display name
    role = "Navigator",       -- Role (Navigator, Gunner, Surgeon)
    skill = 3,                -- Skill level (1-5)
    loyalty = 4,              -- Loyalty to player (1-10)
    health = 8,               -- Health status (1-10)
    cost = 25                 -- Recruitment cost in gold
}
```

#### GameState Crew Data

The crew data is stored within the central GameState:

```lua
GameState.crew = {
    members = {},             -- Player's current crew (array of crew members)
    morale = 5,               -- Overall crew morale (1-10)
    
    pool = {},                -- Global pool of all potential crew members
    availableByLocation = {}  -- Mapping of locations to available crew member IDs
}
```

## Functionality

### Crew Distribution and Recruitment

1. **Initialization**: During game start, the system:
   - Populates the global crew pool with predefined crew members
   - Distributes crew members to different locations based on location-specific criteria

2. **Availability**: Each location has a different set of available crew members:
   - Port Royal: Balanced mix of all roles
   - Nassau: Focus on Gunners and combat specialists
   - Havana: Focus on Navigators and exploration specialists
   - Crown Colony: Mix with a focus on higher quality crew

3. **Recruitment**: When a player hires a crew member:
   - Gold is deducted based on the crew member's cost
   - The crew member is added to the player's roster
   - The crew member is removed from the location's available pool

### Role Effects

Each crew role provides specific benefits to gameplay:

1. **Navigator**: Reduces travel time between zones by 0.5 weeks
   - Implementation: When calculating travel time, checks if a Navigator is present in the crew
   - The reduction is applied after wind effects
   - Multiple Navigators currently don't stack (planned for future implementation)

2. **Gunner**: (Currently visual only, to be implemented in future sprints)
   - Will improve combat effectiveness in ship battles

3. **Surgeon**: (Currently visual only, to be implemented in future sprints)
   - Will provide healing and recovery benefits for crew

## Implementation Details

### Adding a New Crew Member to Pool

To add a new crew member to the global pool:

```lua
table.insert(GameState.crew.pool, {
    id = "unique_id",
    name = "Crew Name",
    role = "Role",
    skill = skillValue,
    loyalty = loyaltyValue,
    health = healthValue,
    cost = goldCost
})
```

### Crew Distribution Logic

Crew are distributed based on role patterns for each location:

```lua
-- Example distribution pattern
-- Port Royal: 1 of each role (Navigator, Gunner, Surgeon)
table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Navigator"))
table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Gunner"))
table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Surgeon"))
```

### Hiring Implementation

The full hiring process:

1. Check if the player can afford the crew member
2. Check if there is space in the crew roster (based on ship capacity)
3. Deduct gold from player resources
4. Add crew member to player's roster
5. Remove crew member from location availability
6. Update the tavern interface to reflect changes

### Accessing Crew Role Effects

To check if a player has a crew member with a specific role:

```lua
local hasRole = false
for _, crewMember in ipairs(gameState.crew.members) do
    if crewMember.role == "RoleName" then
        hasRole = true
        break
    end
end
```

## Extension Points

The crew system is designed for future extension in several ways:

1. **Rotation and Refresh**: Implementing periodic crew rotation at ports
2. **Character Progression**: Adding experience and leveling for crew members
3. **Role Stacking**: Implementing cumulative effects for multiple crew with the same role
4. **Advanced Effects**: Adding more complex role effects and combinations
5. **Events and Interactions**: Creating crew-specific events and storylines