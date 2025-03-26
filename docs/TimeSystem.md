# Time System Documentation

## Overview

The time system manages the progression of the 72-week campaign, tracking current game time, handling the earthquake event, and providing time-related game mechanics.

## Key Components

### TimeSystem Module (`/src/time.lua`)

The TimeSystem module is responsible for:

- Tracking the current game week
- Advancing time when actions are taken
- Managing the earthquake event
- Providing game over conditions
- Displaying time information to the player

### Core Data Structure

```lua
TimeSystem = {
    currentWeek = 1,                 -- Current week number
    totalWeeks = 72,                 -- Total campaign length
    earthquakeMinWeek = 60,          -- Earliest possible earthquake
    earthquakeMaxWeek = 72,          -- Latest possible earthquake
    earthquakeWeek = nil,            -- Actual earthquake week (randomly determined)
    isGameOver = false               -- Game over state
}
```

## Time Progression

Time advances based on player actions:

- Traveling between zones costs 1 week
- Later features will add additional time costs (e.g., repairs, investments, etc.)

The `advanceTime(weeks)` function is used to progress time, checking for game end conditions and returning whether the game is still active.

## Earthquake Mechanics

A key feature of the game is the impending earthquake that will destroy Port Royal:

- The earthquake will occur randomly between weeks 60-72
- The exact week is determined at game start and hidden from the player
- As the player approaches the earthquake, warning signs appear
- When the currentWeek reaches earthquakeWeek, the game ends

## Game Over Conditions

The game can end in two ways:

1. The earthquake occurs (currentWeek >= earthquakeWeek)
2. The maximum campaign length is reached (currentWeek >= totalWeeks)

In both cases, the `isGameOver` flag is set to true, and a game over screen is displayed.

## Warning System

To create tension, the time system includes a warning mechanism:

- After week 50, players may receive subtle hints about the approaching disaster
- Within 10 weeks of the earthquake, sailors report strange tides
- Within 5 weeks of the earthquake, players feel tremors in Port Royal

## Integrating with Other Systems

The time system integrates with:

- **Ship Movement**: Each zone transition advances time by 1 week
- **Map System**: Zones can reference the time system to show travel costs
- **Main Game Loop**: Checks for game over conditions

## Extending the System

### Adding Time-Based Events

To add events that trigger at specific times:

1. Add event conditions to the `advanceTime()` function
2. Check for specific weeks or ranges of weeks
3. Trigger the appropriate event or notification

### Adding Variable Time Costs

To implement variable time costs for different actions:

1. Determine what factors affect the time cost (e.g., ship type, weather)
2. Calculate the modified time cost
3. Pass the calculated value to `advanceTime()`

## Future Improvements

- Seasons and weather systems affecting travel time
- Time-dependent events and missions
- Enhanced warning system with visual effects
- Game calendar with notable dates
- Variable travel costs based on distance or conditions
