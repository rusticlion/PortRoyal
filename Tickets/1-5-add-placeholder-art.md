Ticket 5: Integrate Pixel Art Assets into Existing Systems
Description:

Incorporate the provided pixel art assets—a hand-drawn background map and 
ship sprites—into the game. Replace placeholder graphics (e.g., the ocean 
rectangle and ship triangle) with these assets, ensuring compatibility 
with the zone-based map and ship movement mechanics built in Tickets 1-4.

Tasks:

Load and Display the Background Map Image
In Map:load, load the hand-drawn map image (assets/caribbean_map.png) as 
self.background.
In Map:draw, replace the placeholder ocean rectangle with the background 
image using:
lua

Collapse

Wrap

Copy
love.graphics.setColor(1, 1, 1, 1) -- White, fully opaque
love.graphics.draw(self.background, 0, 0)
Ensure the background renders as the base layer beneath all other 
elements.
Update Zone Definitions with New Polygon Points
Update the zoneDefinitions table in map.lua with new points provided by 
the asset creator, aligning the invisible polygons with the hand-drawn 
zones on the map.
Optional Enhancement: Add labelX and labelY fields to each zone definition 
for precise placement of zone names. Modify Map:draw to use these 
coordinates if provided, falling back to the polygon center otherwise:
lua

Collapse

Wrap

Copy
local x = zone.labelX or (calculateCenterX(zone.points))
local y = zone.labelY or (calculateCenterY(zone.points))
love.graphics.print(zone.name, x, y)
Load Ship Sprites for Each Class
In ship.lua (or the appropriate module), load pixel art sprites for each 
ship class:
sloop.png
brigantine.png
galleon.png
Store them in a table for easy access, e.g.:
lua

Collapse

Wrap

Copy
local Ship = {
    sprites = {
        sloop = love.graphics.newImage("assets/sloop.png"),
        brigantine = love.graphics.newImage("assets/brigantine.png"),
        galleon = love.graphics.newImage("assets/galleon.png")
    }
}
Update Ship Rendering
In the ship’s drawing function (likely in ship.lua or main.lua), replace 
the placeholder triangle with the appropriate sprite based on the ship’s 
class:
lua

Collapse

Wrap

Copy
function Ship:draw()
    local sprite = self.sprites[self.class]
    love.graphics.draw(sprite, self.x, self.y, 0, 1, 1, 
sprite:getWidth()/2, sprite:getHeight()/2)
end
Ensure the sprite is centered on the ship’s current position (self.x, 
self.y), which is managed by the existing smooth movement system.
(Optional) Adjust Zone Highlights
Retain the existing semi-transparent polygon highlights for hovered or 
selected zones (if already implemented in Map:draw).
Adjust transparency or color if needed for readability over the hand-drawn 
map.
Note: Image-based highlights are a potential future enhancement but not 
required for Sprint 1.
Acceptance Criteria:

The hand-drawn caribbean_map.png displays correctly as the game’s 
background, replacing the placeholder ocean rectangle.
Zone interactions (hovering and clicking) function accurately using the 
updated polygon points aligned with the hand-drawn zones.
The ship renders with the correct sprite (e.g., sloop.png for a 
Sloop-class ship) instead of a triangle, centered on its current position.
The ship moves smoothly between zones, consistent with the existing 
animation system.
(If implemented) Zone highlights appear as semi-transparent polygons when 
hovered or selected, remaining visible over the background.
All assets render without graphical glitches, misalignments, or layering 
issues.
Notes:

Assets: The asset creator will provide caribbean_map.png and ship sprites 
(sloop.png, brigantine.png, galleon.png) as PNG files exported from 
Aseprite.
Polygon Points: The asset creator will supply updated points for 
zoneDefinitions to match the hand-drawn map. Coordinate to ensure 
accuracy.
Label Positioning: If labelX and labelY are provided, use them for zone 
names; otherwise, rely on the existing center calculation.
Scope for Sprint 1: Prioritize integrating the background map and one ship 
sprite (e.g., Sloop). Add support for multiple ship classes if time 
permits.
