# Implementation Plan

## Current Architecture

Our game uses a state-centric architecture with the following components:

### Core Components

- **GameState** (`gameState.lua`): Central state repository containing all game data
- **Map** (`map.lua`): Manages the Caribbean map zones, adjacencies, and display
- **Ship** (`ship.lua`): Handles ship visualization and movement logic
- **Time** (`time.lua`): Handles time display and temporal effects

### Data Flow Architecture

The architecture follows a clear separation between:
- **State** (data) - stored in GameState
- **Logic** (behavior) - implemented in module functions
- **Rendering** (display) - handled by module draw methods

### Main Game Loop

The main game loop in `main.lua` coordinates these components with the following flow:
1. Initialize GameState and all modules
2. Update modules, passing the GameState reference
3. Render modules, using data from GameState
4. Handle input by passing events to appropriate modules with GameState

## Module Responsibilities

### GameState Module

Central data store containing:
- `ship`: Current position, movement state, stats
- `time`: Week tracking, earthquake timing
- `resources`: Gold, materials
- `crew`: Members, stats, morale
- `factions`: Reputation with different groups
- `investments`: Player's properties and claims
- `settings`: Game settings (debug, pause)

Provides methods for common operations:
- `init()`: Initialize game state
- `reset()`: Reset all state data
- `advanceTime()`: Manage time progression
- `updateShipPosition()`: Set ship location
- Resource management functions

### Map Module

- Maintains zone definitions and relationships
- Renders map and zones
- Handles mouse interaction with zones
- Provides utility functions for zone operations
- No state storage except temporary UI state (hover)

### Ship Module

- Handles ship movement animation
- Renders ship based on GameState position
- Calculates paths between zones
- Validates zone transitions
- No state storage except animation variables

### Time Module

- Renders time information
- Displays game over conditions
- Handles time-based effects
- No state storage, reads from GameState

## Roadmap for Sprint 2

### Port Phase

1. Create Port Royal interface (tavern, shipyard, etc.)
2. Implement crew recruitment system
3. Add basic investment mechanics

### Combat System

1. Build hex-grid battle system
2. Implement ship combat actions
3. Add dice-based resolution mechanics

### Economic System

1. Develop dynamic pricing for trade goods
2. Create trade routes between zones
3. Implement passive income from investments

## Implementation Guidelines

### Extending GameState

When adding new features:
1. Define data structure in GameState first
2. Add helper methods to GameState for common operations
3. Create modules focused on logic and rendering
4. Keep modules stateless where possible

### Maintaining Separation of Concerns

- **GameState**: What is happening (pure data)
- **Modules**: How it happens (logic) and how it looks (rendering)
- **Main**: When it happens (coordination)

### Performance Considerations

- Pass GameState by reference to avoid copying
- Minimize redundant calculations by centralizing logic
- Cache frequently accessed values within function scope
- Only update changed values in GameState

### Debugging

- Use GameState.settings.debug for debug features
- Add debugging UI elements that read from GameState
- Consider adding a history of state changes for debugging

### Save/Load Considerations

- GameState is designed to be serializable
- Animation state is kept separate to avoid serialization issues
- Split modules into data (for saving) and temporary state