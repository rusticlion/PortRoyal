-- Caribbean Map Module

local Map = {
    zones = {},
    hoveredZone = nil,
    -- Base map dimensions
    width = 800,
    height = 600
}

-- Zone definitions
local zoneDefinitions = {
    {
        name = "Port Royal",
        description = "The pirate haven and central hub of operations.",
        color = {0.8, 0.2, 0.2, 0.6},  -- Light red
        hoverColor = {0.9, 0.3, 0.3, 0.8},
        points = {400, 300, 450, 250, 500, 300, 450, 350},  -- Example polygon points
        adjacent = {"Calm Waters", "Merchants' Route", "Nassau"}
    },
    {
        name = "Calm Waters",
        description = "Peaceful seas with light winds, ideal for new captains.",
        color = {0.2, 0.6, 0.8, 0.6},  -- Light blue
        hoverColor = {0.3, 0.7, 0.9, 0.8},
        points = {300, 200, 350, 150, 400, 200, 350, 250},
        adjacent = {"Port Royal", "Merchants' Route", "Stormy Pass"}
    },
    {
        name = "Merchants' Route",
        description = "Busy trade routes frequent with merchant vessels.",
        color = {0.6, 0.8, 0.2, 0.6},  -- Light green
        hoverColor = {0.7, 0.9, 0.3, 0.8},
        points = {500, 200, 550, 150, 600, 200, 550, 250},
        adjacent = {"Port Royal", "Calm Waters", "Navy Waters", "Havana"}
    },
    {
        name = "Nassau",
        description = "A lawless pirate stronghold.",
        color = {0.8, 0.6, 0.2, 0.6},  -- Light orange
        hoverColor = {0.9, 0.7, 0.3, 0.8},
        points = {300, 400, 350, 350, 400, 400, 350, 450},
        adjacent = {"Port Royal", "Shark Bay", "Cursed Waters"}
    },
    {
        name = "Stormy Pass",
        description = "Treacherous waters known for sudden storms.",
        color = {0.5, 0.5, 0.7, 0.6},  -- Slate
        hoverColor = {0.6, 0.6, 0.8, 0.8},
        points = {200, 150, 250, 100, 300, 150, 250, 200},
        adjacent = {"Calm Waters", "Kraken's Reach"}
    },
    {
        name = "Navy Waters",
        description = "Heavily patrolled by the Royal Navy.",
        color = {0.2, 0.2, 0.8, 0.6},  -- Navy blue
        hoverColor = {0.3, 0.3, 0.9, 0.8},
        points = {600, 150, 650, 100, 700, 150, 650, 200},
        adjacent = {"Merchants' Route", "Crown Colony"}
    },
    {
        name = "Shark Bay",
        description = "Shallow waters home to many sharks.",
        color = {0.6, 0.2, 0.2, 0.6},  -- Darker red
        hoverColor = {0.7, 0.3, 0.3, 0.8},
        points = {200, 350, 250, 300, 300, 350, 250, 400},
        adjacent = {"Nassau", "Sunken Graveyard"}
    },
    {
        name = "Cursed Waters",
        description = "Legends speak of ghost ships here.",
        color = {0.4, 0.1, 0.4, 0.6},  -- Purple
        hoverColor = {0.5, 0.2, 0.5, 0.8},
        points = {350, 500, 400, 450, 450, 500, 400, 550},
        adjacent = {"Nassau", "Kraken's Reach", "Lost Island"}
    },
    {
        name = "Havana",
        description = "A prosperous Spanish colony.",
        color = {0.8, 0.8, 0.2, 0.6},  -- Yellow
        hoverColor = {0.9, 0.9, 0.3, 0.8},
        points = {550, 300, 600, 250, 650, 300, 600, 350},
        adjacent = {"Merchants' Route", "Crown Colony"}
    },
    {
        name = "Kraken's Reach",
        description = "Deep waters where monsters are said to lurk.",
        color = {0.1, 0.3, 0.3, 0.6},  -- Dark teal
        hoverColor = {0.2, 0.4, 0.4, 0.8},
        points = {150, 250, 200, 200, 250, 250, 200, 300},
        adjacent = {"Stormy Pass", "Cursed Waters"}
    },
    {
        name = "Crown Colony",
        description = "A well-defended British settlement.",
        color = {0.7, 0.1, 0.1, 0.6},  -- Deep red
        hoverColor = {0.8, 0.2, 0.2, 0.8},
        points = {650, 250, 700, 200, 750, 250, 700, 300},
        adjacent = {"Navy Waters", "Havana"}
    },
    {
        name = "Sunken Graveyard",
        description = "The final resting place of countless ships.",
        color = {0.3, 0.3, 0.3, 0.6},  -- Gray
        hoverColor = {0.4, 0.4, 0.4, 0.8},
        points = {150, 400, 200, 350, 250, 400, 200, 450},
        adjacent = {"Shark Bay"}
    },
    {
        name = "Lost Island",
        description = "A mysterious island appearing on few maps.",
        color = {0.2, 0.8, 0.2, 0.6},  -- Green
        hoverColor = {0.3, 0.9, 0.3, 0.8},
        points = {400, 600, 450, 550, 500, 600, 450, 650},
        adjacent = {"Cursed Waters"}
    },
}

-- Point-in-polygon function to detect if mouse is inside a zone
local function pointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon - 1
    
    for i = 1, #polygon, 2 do
        local xi, yi = polygon[i], polygon[i+1]
        local xj, yj = polygon[j], polygon[j+1]
        
        local intersect = ((yi > y) ~= (yj > y)) and
            (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        
        if intersect then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

-- Load map data
function Map:load(gameState)
    -- Clear any existing zones to support restart
    self.zones = {}
    
    -- Create zone objects from definitions
    for i, def in ipairs(zoneDefinitions) do
        local zone = {
            name = def.name,
            description = def.description,
            color = def.color,
            hoverColor = def.hoverColor,
            points = def.points,
            adjacent = def.adjacent,
            -- Initialize zone state
            isHovered = false,
            isSelected = false,
            -- Travel cost is uniformly 1 week in Sprint 1
            travelCost = 1
        }
        table.insert(self.zones, zone)
    end
    
    -- Set Port Royal as initial selected zone
    for i, zone in ipairs(self.zones) do
        if zone.name == "Port Royal" then
            zone.isSelected = true
            break
        end
    end
    
    -- Load background image if available
    local success, result = pcall(function()
        return love.graphics.newImage("assets/caribbean_map.png")
    end)
    
    if success then
        self.background = result
        print("Map background loaded successfully")
    else
        print("Map background image not found. Background will be displayed as blue rectangle.")
    end
    
    -- Font for tooltips
    self.tooltipFont = love.graphics.newFont(14)
 end

-- Update map state
function Map:update(dt, gameState)
    -- Update logic here (animations, etc.)
    
    -- Reset all zone selection states
    for i, zone in ipairs(self.zones) do
        zone.isSelected = false
    end
    
    -- Mark current ship zone as selected
    if gameState.ship.currentZone and gameState.ship.currentZone <= #self.zones then
        self.zones[gameState.ship.currentZone].isSelected = true
    end
end

-- Draw the map
function Map:draw(gameState)
    -- Draw background (either image or fallback color)
    if self.background then
        love.graphics.setColor(1, 1, 1, 1)  -- White, fully opaque
        love.graphics.draw(self.background, 0, 0)
    else
        love.graphics.setColor(0.1, 0.3, 0.5, 1)  -- Deep blue ocean background
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
    
    -- Draw zones
    for i, zone in ipairs(self.zones) do
        -- Draw zone shape
        if zone.isHovered then
            love.graphics.setColor(unpack(zone.hoverColor))
        elseif zone.isSelected then
            love.graphics.setColor(1, 1, 1, 0.8)  -- Selected zone is white
        else
            love.graphics.setColor(unpack(zone.color))
        end
        
        love.graphics.polygon("fill", zone.points)
        
        -- Draw zone outline
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.polygon("line", zone.points)
        
        -- Calculate zone center for name label, or use custom label position if provided
        local x, y
        if zone.labelX and zone.labelY then
            x, y = zone.labelX, zone.labelY
        else
            x, y = 0, 0
            for j = 1, #zone.points, 2 do
                x = x + zone.points[j]
                y = y + zone.points[j+1]
            end
            x = x / (#zone.points / 2)
            y = y / (#zone.points / 2)
        end
        
        -- Draw zone name
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = love.graphics.getFont():getWidth(zone.name)
        love.graphics.print(zone.name, x - textWidth/2, y - 7)
    end
    
    -- Draw tooltip for hovered zone
    if self.hoveredZone then
        local zone = self.zones[self.hoveredZone]
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Enhanced tooltip with travel information
        love.graphics.setColor(0, 0, 0, 0.8)
        
        -- Check if the hovered zone is adjacent to ship's current zone
        local isAdjacent = false
        if gameState.ship.currentZone and gameState.ship.currentZone <= #self.zones then
            local currentZone = self.zones[gameState.ship.currentZone]
            
            for _, adjacentName in ipairs(currentZone.adjacent) do
                if adjacentName == zone.name then
                    isAdjacent = true
                    break
                end
            end
        end
        
        local tooltipText
        if self.hoveredZone == gameState.ship.currentZone then
            if gameState.settings.moored then
                tooltipText = zone.name .. "\n" .. zone.description .. "\nCurrently moored at this location\n(Click to enter " .. zone.name .. " interface)"
            else
                tooltipText = zone.name .. "\n" .. zone.description .. "\nCurrently at sea near this location\n(Click to moor at " .. zone.name .. ")"
            end
        elseif isAdjacent then
            -- Calculate travel time with wind effects
            local travelTime, windEffect = gameState:calculateTravelTime(gameState.ship.currentZone, self.hoveredZone, self)
            
            -- Format travel time nicely
            local timeDisplay
            if travelTime == 0.5 then
                timeDisplay = "half a week"
            elseif travelTime == 1 then
                timeDisplay = "1 week"
            else
                timeDisplay = travelTime .. " weeks"
            end
            
            tooltipText = zone.name .. "\n" .. zone.description .. 
                          "\nTravel time: " .. timeDisplay .. 
                          " (" .. windEffect .. ")" ..
                          "\nWind: " .. gameState.environment.wind.currentDirection .. 
                          "\n(Click to sail here)"
        else
            tooltipText = zone.name .. "\n" .. zone.description .. "\nNot directly accessible from current location"
        end
        
        local tooltipWidth = self.tooltipFont:getWidth(tooltipText) + 20
        local tooltipHeight = 90  -- Increased height for more content
        
        -- Adjust position if tooltip would go off screen
        local tooltipX = mouseX + 15
        local tooltipY = mouseY + 15
        if tooltipX + tooltipWidth > self.width then
            tooltipX = self.width - tooltipWidth - 5
        end
        if tooltipY + tooltipHeight > self.height then
            tooltipY = self.height - tooltipHeight - 5
        end
        
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight, 5, 5)
        
        -- Tooltip text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(self.tooltipFont)
        love.graphics.printf(tooltipText, tooltipX + 10, tooltipY + 10, tooltipWidth - 20, "left")
    end
    
    -- Draw adjacency lines for ship's current zone
    if gameState.ship.currentZone and gameState.ship.currentZone <= #self.zones then
        local currentZone = self.zones[gameState.ship.currentZone]
        
        -- Calculate center of current zone
        local centerX1, centerY1 = 0, 0
        for j = 1, #currentZone.points, 2 do
            centerX1 = centerX1 + currentZone.points[j]
            centerY1 = centerY1 + currentZone.points[j+1]
        end
        centerX1 = centerX1 / (#currentZone.points / 2)
        centerY1 = centerY1 / (#currentZone.points / 2)
        
        -- Draw lines to adjacent zones
        love.graphics.setColor(1, 1, 1, 0.4)  -- Semi-transparent white
        for _, adjacentName in ipairs(currentZone.adjacent) do
            for i, zone in ipairs(self.zones) do
                if zone.name == adjacentName then
                    -- Calculate center of adjacent zone
                    local centerX2, centerY2 = 0, 0
                    for j = 1, #zone.points, 2 do
                        centerX2 = centerX2 + zone.points[j]
                        centerY2 = centerY2 + zone.points[j+1]
                    end
                    centerX2 = centerX2 / (#zone.points / 2)
                    centerY2 = centerY2 / (#zone.points / 2)
                    
                    -- Draw line connecting centers
                    love.graphics.line(centerX1, centerY1, centerX2, centerY2)
                    break
                end
            end
        end
        
        -- Draw mooring indicator if ship is moored
        if gameState.settings.moored then
            love.graphics.setColor(1, 1, 0.3, 0.8)  -- Yellow anchor indicator
            love.graphics.circle("fill", centerX1, centerY1 + 25, 5)
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.circle("line", centerX1, centerY1 + 25, 5)
        end
    end
    
    -- Display instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    
    local instructionText = "Hover over zones to see information\nClick adjacent zones to sail there"
    if gameState.ship.currentZone and not gameState.settings.moored then
        instructionText = instructionText .. "\nClick your current zone to moor your ship"
    elseif gameState.ship.currentZone and gameState.settings.moored then
        instructionText = instructionText .. "\nClick your current zone to enter port interface"
    end
    
    love.graphics.printf(instructionText, 10, self.height - 70, 300, "left")
end

-- Handle mouse movement
function Map:mousemoved(x, y, gameState)
    -- Only allow interaction if the ship is not already moving
    if gameState.ship.isMoving then
        return
    end
    
    local foundHover = false
    
    -- Reset all hover states
    for i, zone in ipairs(self.zones) do
        zone.isHovered = false
    end
    
    -- Check if mouse is over any zone
    for i, zone in ipairs(self.zones) do
        if pointInPolygon(x, y, zone.points) then
            zone.isHovered = true
            self.hoveredZone = i
            foundHover = true
            break
        end
    end
    
    -- Clear hover if not over any zone
    if not foundHover then
        self.hoveredZone = nil
    end
end

-- Handle mouse clicks
function Map:mousepressed(x, y, button, gameState)
    -- Early return if game is over
    if gameState.time.isGameOver then
        return
    end
    
    -- Only allow clicks if the ship is not already moving
    if gameState.ship.isMoving then
        return
    end
    
    if button == 1 and self.hoveredZone then  -- Left click
        local clickedZone = self.hoveredZone
        
        -- If ship exists and the clicked zone is different from current,
        -- attempt to move the ship using the Ship module
        if clickedZone ~= gameState.ship.currentZone then
            -- Get the Ship module and call moveToZone
            local Ship = require('ship')
            Ship:moveToZone(clickedZone, gameState, self)
        else
            -- Clicked on current zone
            local currentZone = self.zones[gameState.ship.currentZone]
            
            -- When clicking on current zone, show mooring options
            if not gameState.settings.moored then
                -- If not moored, offer to moor at this location
                print("Mooring at " .. currentZone.name)
                gameState.settings.moored = true
            else
                -- If already moored, enter the location interface
                print("Entering " .. currentZone.name .. " interface")
                gameState.settings.portMode = true
                gameState.settings.currentPortScreen = "main"
            end
        end
    end
end

-- Get a zone by index
function Map:getZone(index)
    if index and index <= #self.zones then
        return self.zones[index]
    end
    return nil
end

-- Get a zone by name
function Map:getZoneByName(name)
    for i, zone in ipairs(self.zones) do
        if zone.name == name then
            return zone, i
        end
    end
    return nil, nil
end

-- Check if two zones are adjacent
function Map:areZonesAdjacent(zoneIndex1, zoneIndex2)
    if not zoneIndex1 or not zoneIndex2 or
       zoneIndex1 > #self.zones or zoneIndex2 > #self.zones then
        return false
    end
    
    local zone1 = self.zones[zoneIndex1]
    local zone2 = self.zones[zoneIndex2]
    
    for _, adjacentName in ipairs(zone1.adjacent) do
        if adjacentName == zone2.name then
            return true
        end
    end
    
    return false
end

return Map