# Wind System Documentation

## Overview

The Wind System adds environmental effects to sea travel, making navigation more strategic by influencing the time it takes to travel between zones. Wind direction changes periodically, challenging players to adapt their travel plans accordingly.

## Core Mechanics

### Wind Direction

- Wind can blow in 8 cardinal directions (N, NE, E, SE, S, SW, W, NW)
- Direction is randomly determined at game start
- Changes every few in-game weeks (configurable)
- Persists across game sessions (part of game state)

### Wind Effects on Travel

Wind affects travel time between zones based on the relative direction:

| Travel Direction | Effect | Travel Time |
|------------------|--------|-------------|
| With the wind    | -0.5 weeks | 0.5 weeks |
| Crosswind (perpendicular) | No effect | 1 week |
| Against the wind | +1 week | 2 weeks |

### How Wind Direction Is Determined

For each journey between zones:

1. The travel direction is calculated based on the geometric angle between the source and destination zones
2. This direction is compared to the current wind direction
3. The system classifies the journey as "with wind," "against wind," or "crosswind"
4. A time modifier is applied based on this classification

## Implementation Details

### Data Structure

The wind system resides in the `environment` section of the game state:

```lua
gameState.environment.wind = {
    directions = {"North", "Northeast", "East", "Southeast", 
                 "South", "Southwest", "West", "Northwest"},
    currentDirection = nil,  -- Set during initialization
    changeTimer = 0,         -- Timer for wind changes
    changeInterval = 4       -- How often wind might change (in weeks)
}
```

### Travel Time Calculation

The `calculateTravelTime` function in `gameState.lua` determines travel time:

```lua
-- Calculate travel time between zones based on wind conditions
function GameState:calculateTravelTime(fromZoneIdx, toZoneIdx, map)
    -- Base travel time is always 1 week
    local baseTravelTime = 1
    
    -- Calculate travel direction based on zone positions
    local travelDirection = calculateTravelDirection(fromZone, toZone)
    
    -- Apply wind modifier based on relative direction
    local windModifier = 0
    if travelDirection == windDirection then
        windModifier = -0.5  -- Half a week faster with the wind
    elseif travelDirection == oppositeOf[windDirection] then
        windModifier = 1     -- Extra week against the wind
    else
        windModifier = 0     -- No modifier for crosswind
    end
    
    -- Ensure minimum 0.5 week travel time
    local travelTime = math.max(0.5, baseTravelTime + windModifier)
    
    return travelTime, windEffect
end
```

### Wind Change Mechanism

Wind direction changes periodically as time advances:

```lua
-- In the advanceTime function
self.environment.wind.changeTimer = self.environment.wind.changeTimer + weeks
if self.environment.wind.changeTimer >= self.environment.wind.changeInterval then
    self.environment.wind.changeTimer = 0
    -- Choose a new wind direction
    local oldDirection = self.environment.wind.currentDirection
    self.environment.wind.currentDirection = self.environment.wind.directions[
        math.random(#self.environment.wind.directions)]
    
    if oldDirection ~= self.environment.wind.currentDirection then
        print("Wind direction changed from " .. oldDirection .. 
              " to " .. self.environment.wind.currentDirection)
    end
end
```

## User Interface

### Visual Indicators

1. **Wind Label**: The word "Wind" is displayed in the top-left corner of the screen
2. **Wind Direction Arrow**: A graphical arrow below the label showing the current wind direction
3. **Travel Time in Tooltips**: Shows travel time with wind effect when hovering over adjacent zones
   - Example: "Travel time: 0.5 weeks (with wind)"

### Wind Display Implementation

The Time module's `draw` function visualizes wind direction:

```lua
-- Wind information in top-left corner
local windText = "Wind"
love.graphics.print(windText, 10, 10)

-- Calculate text width to center arrow below it
local windTextWidth = love.graphics.getFont():getWidth(windText)
local textCenterX = 10 + windTextWidth/2

-- Draw a small arrow indicating wind direction below the text
local windDir = gameState.environment.wind.currentDirection
local arrowX, arrowY = textCenterX, 40  -- Position arrow perfectly centered and further down
local arrowLength = 15

-- Calculate arrow endpoint based on direction
local endX, endY = calculateArrowEndpoint(windDir, arrowX, arrowY, arrowLength)

-- Draw the arrow
love.graphics.setLineWidth(2)
love.graphics.line(arrowX, arrowY, endX, endY)
love.graphics.polygon("fill", endX, endY, leftX, leftY, rightX, rightY)
```

## Travel Flow

1. Player hovers over an adjacent zone
2. System calculates travel time based on current wind
3. Tooltip displays time and wind effect
4. If player clicks to move:
   - Ship animation begins
   - Game time advances by the calculated amount
   - Wind may change if enough time passes

## Debugging

The wind system includes extensive debugging output that can be enabled by setting `gameState.settings.debug = true`. This outputs details of:

- Current wind direction
- Travel vector and angle
- Calculated travel direction 
- Applied wind modifier
- Final travel time

## Future Enhancements

Potential improvements for later sprints:

1. **Wind Visualization**: Add visual wind effects on the map (wave patterns, cloud movement)
2. **Hex-Level Wind**: Apply wind effects to movement within zones once hex grids are implemented
3. **Strategic Wind Changes**: Make wind more predictable in certain areas or seasons
4. **Advanced Weather**: Expand to include storms or calm seas that further affect travel
5. **Ship Type Effects**: Different ship classes could have varied responses to wind conditions