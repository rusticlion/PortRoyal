# GameState Module Documentation

## Overview

The GameState module serves as the central repository for all game data, providing a single source of truth for the game's state. This architectural approach improves maintainability, simplifies data access across modules, and provides a clear structure for future extensions.

## Core Data Structure

The GameState object contains several key sections:

```lua
GameState = {
    -- Ship information
    ship = {
        name = "The Swift Sting",    -- Ship name
        type = "Sloop",             -- Ship class
        currentZone = nil,          -- Current zone index
        x = 0,                      -- X position on map
        y = 0,                      -- Y position on map
        isMoving = false,           -- Movement state
        speed = 3,                  -- Movement stats
        firepower = 2,              -- Combat stats
        durability = 10,            -- Health stats
        crewCapacity = 4            -- Maximum crew size
    },
    
    -- Time tracking
    time = {
        currentWeek = 1,           -- Current game week
        totalWeeks = 72,            -- Campaign length
        earthquakeWeek = nil,       -- When earthquake occurs
        isGameOver = false          -- Game over state
    },
    
    -- Player resources
    resources = {
        gold = 50,                  -- Starting gold
        rum = 0,                    -- Various resources
        timber = 0,
        gunpowder = 0
    },
    
    -- Crew management
    crew = {
        members = {},               -- Crew member objects
        morale = 5                  -- Overall crew morale
    },
    
    -- Faction relationships (-3 to +3)
    factions = { ... },
    
    -- Player's investments
    investments = { ... },
    
    -- Game settings
    settings = {
        debug = false,              -- Debug mode
        isPaused = false            -- Pause state
    }
}
```

## Key Methods

### Initialization and Reset

- `GameState:init()`: Sets up initial game state, including random earthquake timing, starting crew, etc.
- `GameState:reset()`: Resets all state to initial values, used for restarts

### Time Management

- `GameState:advanceTime(weeks)`: Advances game time by specified weeks, checks for game end conditions, and triggers time-based events

### Ship Operations

- `GameState:updateShipPosition(zoneIndex, x, y)`: Updates ship's position on the map
- `GameState:setShipMoving(isMoving)`: Sets the ship's movement state

### Resource Management

- `GameState:addResources(type, amount)`: Adds resources of specified type
- `GameState:canAfford(type, amount)`: Checks if player has enough resources
- `GameState:spendResources(type, amount)`: Deducts resources if available

### Crew Management

- `GameState:addCrewMember(member)`: Adds a new crew member if capacity allows

### Faction Relations

- `GameState:changeFactionRep(faction, amount)`: Updates reputation with a faction

### Game Settings

- `GameState:toggleDebug()`: Toggles debug mode

## Usage in Other Modules

All other modules receive the GameState as a parameter and interact with it:

```lua
-- Example from Ship Module
function Ship:update(dt, gameState, gameMap)
    if gameState.ship.isMoving then
        -- Animation logic...
        gameState.ship.x = newX  -- Update position in GameState
        gameState.ship.y = newY
    end
end

-- Example from Map Module
function Map:mousepressed(x, y, button, gameState)
    -- Handle mouse click...
    if someCondition then
        Ship:moveToZone(targetZone, gameState, self)
    end
end
```

## Benefits

### Single Source of Truth

All game data is stored in one place, eliminating inconsistencies across modules.

### Clear Data Access

Modules don't need to maintain their own state or communicate with each other directly.

### Save/Load Ready

The structure is designed to support serialization for save/load functionality.

### Debuggability

Debugging is simplified by having all state in one place.

## Extending GameState

To add new features to the game:

1. Add appropriate data structures to GameState
2. Add helper methods for common operations on that data
3. Update relevant modules to use the new data

```lua
-- Example: Adding weather system
GameState.weather = {
    currentCondition = "clear",
    stormTimer = 0,
    affectedZones = {}
}

function GameState:updateWeather(dt)
    -- Weather update logic
end
```

## Best Practices

- Modify GameState only through its methods when possible
- Keep GameState focused on data, not logic
- Don't store temporary/rendering state in GameState
- Document any new fields added to GameState
- Use descriptive names for state properties