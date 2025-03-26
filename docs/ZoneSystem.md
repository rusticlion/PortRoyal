# Zone System Documentation

## Overview

The zone system manages the geography of the Caribbean map, including zone definitions, movement between zones, and adjacency relationships. It's designed to provide the foundation for ship travel and exploration.

## Key Components

### Map Module (`/src/map.lua`)

The Map module is the main controller for the zone system, containing:

- Zone definitions with properties like name, description, color, shape, and adjacency lists
- Mouse interaction logic for hovering and selecting zones
- Visualization of zones on the world map
- Adjacency tracking and validation for movement

### Data Structure

Each zone is represented as a Lua table with the following properties:

```lua
zone = {
    name = "Zone Name",                -- String: Zone name (e.g., "Port Royal")
    description = "Description",      -- String: Zone description
    color = {r, g, b, a},            -- Table: RGBA color values (0-1)
    hoverColor = {r, g, b, a},       -- Table: RGBA color when hovered
    points = {x1, y1, x2, y2, ...},  -- Table: Polygon points defining shape
    adjacent = {"Zone1", "Zone2"},   -- Table: Names of adjacent zones
    isHovered = false,               -- Boolean: Currently being hovered?
    isSelected = false,              -- Boolean: Currently selected?
    travelCost = 1                   -- Number: Weeks to travel here
}
```

## Zone Adjacency System

The adjacency system uses named relationships, which has these advantages:

- Zone connections are defined by names rather than indices, making the code more readable
- Changes to the zone list order don't break connections
- Easy to audit and maintain relationships

Example of adjacency definition:

```lua
-- Port Royal is adjacent to Calm Waters, Merchants' Route, and Nassau
adjacent = {"Calm Waters", "Merchants' Route", "Nassau"}
```

## Point-in-Polygon Algorithm

The map uses a ray-casting point-in-polygon algorithm to detect when the mouse is hovering over an irregular zone shape. This allows for artistic freedom in zone design while maintaining accurate hit detection.

## Integration with Ship Movement

The zone system validates movement by checking:
1. If the target zone exists
2. If the target zone is adjacent to the current zone
3. If the player has the resources to make the journey (time)

If these conditions are met, the ship can move to the new zone.

## Extending the System

### Adding New Zones

To add a new zone:

1. Add a new entry to the `zoneDefinitions` table in `map.lua`
2. Define its properties (name, description, color, etc.)
3. Define its polygon shape (points array)
4. List all adjacent zones by name
5. Update existing zones' adjacency lists if they connect to the new zone

### Adding Zone Properties

To add new properties to zones (e.g., danger level, resources):

1. Add the property to the zone definition in `zoneDefinitions`
2. Update the zone creation code in `Map:load()` to include the new property
3. Add any related logic to handle the new property

## Future Improvements

- Load zone definitions from external data files for easier editing
- Add variable travel costs based on distance or conditions
- Implement zone-specific events and encounters
- Add within-zone hex grid for tactical movement in later sprints
