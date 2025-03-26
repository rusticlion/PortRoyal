# PortRoyal Codebase Dump
Generated: Wed Mar 26 17:12:08 CDT 2025

# Source Code

## src/conf.lua
```lua
-- LÖVE Configuration
function love.conf(t)
    t.title = "Pirate's Wager: Blood for Gold"  -- The title of the window
    t.version = "11.4"                -- The LÖVE version this game was made for
    t.window.width = 800              -- Game window width
    t.window.height = 600             -- Game window height
    t.window.resizable = false        -- Let the window be user-resizable
    t.console = true                  -- Enable console for debug output
    
    -- For development
    t.window.vsync = 1                -- Vertical sync mode
    
    -- Disable modules we won't be using
    t.modules.joystick = false        -- No need for joystick module
    t.modules.physics = false         -- No need for physics module for map navigation
end```

## src/gameState.lua
```lua
-- Game State Module
-- Central repository for game state that needs to be accessed across modules

local GameState = {
    -- Player ship information
    ship = {
        name = "The Swift Sting",
        class = "sloop",     -- Ship class (sloop, brigantine, galleon)
        currentZone = nil,  -- Set during initialization
        x = 0,
        y = 0,
        isMoving = false,
        -- Ship stats
        speed = 3,          -- Hexes per turn in combat (future feature)
        firepower = 2,      -- Number of cannons
        durability = 10,    -- Hull hit points
        crewCapacity = 4    -- Maximum crew size
    },
    
    -- Time tracking
    time = {
        currentWeek = 1,
        totalWeeks = 72,
        earthquakeWeek = nil,  -- Set during initialization
        isGameOver = false
    },
    
    -- Player resources
    resources = {
        gold = 50,          -- Starting gold
        rum = 0,
        timber = 0,
        gunpowder = 0
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = 5          -- Scale 1-10
    },
    
    -- Faction relationships (-3 to +3)
    factions = {
        pirates = 0,
        merchants = 0,
        navy = 0,
        locals = 0
    },
    
    -- Player's investments/claims
    investments = {
        -- Will contain investment objects
    },
    
    -- Environmental conditions
    environment = {
        -- Wind system
        wind = {
            directions = {"North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"},
            currentDirection = nil,  -- Set during initialization
            changeTimer = 0,         -- Timer for wind changes (future feature)
            changeInterval = 4       -- How often wind might change (in weeks)
        }
    },
    
    -- Game settings and flags
    settings = {
        debug = false  -- Set to false for normal gameplay, true for debugging
    }
}

-- Initialize game state
function GameState:init()
    -- Seed random number generator
    math.randomseed(os.time())
    
    -- Set earthquake week (random between weeks 60-72)
    self.time.earthquakeWeek = math.random(60, 72)
    
    -- Initialize wind direction (random)
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        name = "Captain",
        role = "Navigator",
        skill = 2,
        loyalty = 8,
        health = 10
    })
    
    print("Game state initialized!")
    print("Earthquake will occur on week: " .. self.time.earthquakeWeek)
    print("Initial wind direction: " .. self.environment.wind.currentDirection)
end

-- Reset game state (for new game or restart)
function GameState:reset()
    -- Reset ship
    self.ship.name = "The Swift Sting"
    self.ship.class = "sloop"
    self.ship.currentZone = nil
    self.ship.x = 0
    self.ship.y = 0
    self.ship.isMoving = false
    
    -- Reset time
    self.time.currentWeek = 1
    self.time.earthquakeWeek = math.random(60, 72)
    self.time.isGameOver = false
    
    -- Reset wind
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    self.environment.wind.changeTimer = 0
    
    -- Reset resources
    self.resources.gold = 50
    self.resources.rum = 0
    self.resources.timber = 0
    self.resources.gunpowder = 0
    
    -- Reset crew
    self.crew.members = {}
    self.crew.morale = 5
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        name = "Captain",
        role = "Navigator",
        skill = 2,
        loyalty = 8,
        health = 10
    })
    
    -- Reset factions
    self.factions.pirates = 0
    self.factions.merchants = 0
    self.factions.navy = 0
    self.factions.locals = 0
    
    -- Reset investments
    self.investments = {}
    
    print("Game state reset!")
    print("Earthquake will occur on week: " .. self.time.earthquakeWeek)
    print("Wind direction reset to: " .. self.environment.wind.currentDirection)
end

-- Advance time by specified number of weeks
function GameState:advanceTime(weeks)
    -- For display purposes, we want to show 0.5 for half a week
    -- but internally, we'll track weeks with 1 decimal place
    local roundedWeeks = math.floor(weeks * 10 + 0.5) / 10
    self.time.currentWeek = self.time.currentWeek + roundedWeeks
    
    -- Check for game end conditions
    if self.time.currentWeek >= self.time.earthquakeWeek then
        -- Earthquake occurs
        print("EARTHQUAKE! Port Royal is devastated!")
        self.time.isGameOver = true
    elseif self.time.currentWeek >= self.time.totalWeeks then
        -- Campaign ends regardless
        print("End of campaign reached!")
        self.time.isGameOver = true
    end
    
    -- Report time advancement
    print("Advanced " .. weeks .. " week(s) - Now on week " .. self.time.currentWeek .. " of " .. self.time.totalWeeks)
    
    -- Update wind direction occasionally (each changeInterval weeks)
    self.environment.wind.changeTimer = self.environment.wind.changeTimer + weeks
    if self.environment.wind.changeTimer >= self.environment.wind.changeInterval then
        self.environment.wind.changeTimer = 0
        local oldDirection = self.environment.wind.currentDirection
        
        -- Choose a new direction (potentially same as before)
        self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
        
        if oldDirection ~= self.environment.wind.currentDirection then
            print("Wind direction changed from " .. oldDirection .. " to " .. self.environment.wind.currentDirection)
        end
    end
    
    -- As player approaches earthquake, add warning signs
    if self.time.currentWeek >= 50 and not self.time.isGameOver then
        local weeksToQuake = self.time.earthquakeWeek - self.time.currentWeek
        if weeksToQuake <= 5 then
            print("Warning: Strong tremors felt in Port Royal!")
        elseif weeksToQuake <= 10 then
            print("Warning: Sailors report strange tides and underwater rumbling.")
        end
    end
    
    return not self.time.isGameOver  -- Return false if game is over
end

-- Calculate travel time between zones based on wind
function GameState:calculateTravelTime(fromZoneIdx, toZoneIdx, map)
    -- Base travel time is always 1 week
    local baseTravelTime = 1
    
    -- If either zone is invalid, just return base time
    if not fromZoneIdx or not toZoneIdx or 
       fromZoneIdx > #map.zones or toZoneIdx > #map.zones then
        return baseTravelTime, "normal"
    end
    
    -- Debug info for wind calculation
    if self.settings.debug then
        print("Calculating travel time from zone " .. fromZoneIdx .. " to zone " .. toZoneIdx)
        print("Current wind direction: " .. self.environment.wind.currentDirection)
    end
    
    -- For Sprint 1, we apply a simple wind modifier:
    -- Assign each zone a "direction" based on its position relative to the map center
    local fromZone = map.zones[fromZoneIdx]
    local toZone = map.zones[toZoneIdx]
    
    -- Calculate center points
    local fromCenterX, fromCenterY = 0, 0
    for j = 1, #fromZone.points, 2 do
        fromCenterX = fromCenterX + fromZone.points[j]
        fromCenterY = fromCenterY + fromZone.points[j+1]
    end
    fromCenterX = fromCenterX / (#fromZone.points / 2)
    fromCenterY = fromCenterY / (#fromZone.points / 2)
    
    local toCenterX, toCenterY = 0, 0
    for j = 1, #toZone.points, 2 do
        toCenterX = toCenterX + toZone.points[j]
        toCenterY = toCenterY + toZone.points[j+1]
    end
    toCenterX = toCenterX / (#toZone.points / 2)
    toCenterY = toCenterY / (#toZone.points / 2)
    
    -- Calculate travel direction (from -> to)
    local dx = toCenterX - fromCenterX
    local dy = toCenterY - fromCenterY
    local travelAngle = math.atan2(dy, dx) * 180 / math.pi
    
    if self.settings.debug then
        print("Travel vector: dx=" .. dx .. ", dy=" .. dy)
        print("Travel angle: " .. travelAngle .. " degrees")
    end
    
    -- Convert angle to compass direction (0 = East, 90 = South, etc.)
    local travelDirection = ""
    if travelAngle >= -22.5 and travelAngle < 22.5 then
        travelDirection = "East"
    elseif travelAngle >= 22.5 and travelAngle < 67.5 then
        travelDirection = "Southeast"
    elseif travelAngle >= 67.5 and travelAngle < 112.5 then
        travelDirection = "South"
    elseif travelAngle >= 112.5 and travelAngle < 157.5 then
        travelDirection = "Southwest"
    elseif travelAngle >= 157.5 or travelAngle < -157.5 then
        travelDirection = "West"
    elseif travelAngle >= -157.5 and travelAngle < -112.5 then
        travelDirection = "Northwest"
    elseif travelAngle >= -112.5 and travelAngle < -67.5 then
        travelDirection = "North"
    elseif travelAngle >= -67.5 and travelAngle < -22.5 then
        travelDirection = "Northeast"
    end
    
    if self.settings.debug then
        print("Travel direction: " .. travelDirection)
    end
    
    -- Compare travel direction with wind direction
    local windDirection = self.environment.wind.currentDirection
    local windModifier = 0
    
    -- Define opposite directions for "with wind" calculation
    local oppositeOf = {
        ["North"] = "South",
        ["South"] = "North",
        ["East"] = "West",
        ["West"] = "East",
        ["Northeast"] = "Southwest",
        ["Southwest"] = "Northeast",
        ["Northwest"] = "Southeast",
        ["Southeast"] = "Northwest"
    }
    
    -- Wind modifiers:
    -- Traveling WITH the wind (in the same direction as the wind blows): -0.5 weeks
    -- Traveling AGAINST the wind (opposite to wind direction): +1 week
    -- Traveling in any other direction (perpendicular/angled): no modifier
    
    -- With the wind (same direction): reduce travel time
    if travelDirection == windDirection then
        windModifier = -0.5  -- Half a week faster with the wind
    -- Against the wind (sailing into the wind): +1 week
    elseif travelDirection == oppositeOf[windDirection] then
        windModifier = 1
    -- Perpendicular to wind: no modifier
    else
        windModifier = 0
    end
    
    -- Apply the wind modifier (ensure minimum 0.5 week)
    local travelTime = math.max(0.5, baseTravelTime + windModifier)
    
    -- Return both the travel time and the wind effect description
    local windEffect = ""
    if windModifier > 0 then
        windEffect = "against wind"
    elseif windModifier < 0 then
        windEffect = "with wind"
    else
        windEffect = "crosswind"
    end
    
    if self.settings.debug then
        print("Wind direction: " .. windDirection)
        print("Wind modifier: " .. windModifier)
        print("Final travel time: " .. travelTime .. " weeks")
        print("Wind effect: " .. windEffect)
    end
    
    return travelTime, windEffect
end

-- Update ship position
function GameState:updateShipPosition(zoneIndex, x, y)
    self.ship.currentZone = zoneIndex
    self.ship.x = x
    self.ship.y = y
end

-- Set ship movement state
function GameState:setShipMoving(isMoving)
    self.ship.isMoving = isMoving
end

-- Add resources
function GameState:addResources(type, amount)
    if self.resources[type] then
        self.resources[type] = self.resources[type] + amount
        return true
    end
    return false
end

-- Check if player can afford a cost
function GameState:canAfford(type, amount)
    if self.resources[type] and self.resources[type] >= amount then
        return true
    end
    return false
end

-- Spend resources
function GameState:spendResources(type, amount)
    if self:canAfford(type, amount) then
        self.resources[type] = self.resources[type] - amount
        return true
    end
    return false
end

-- Add a crew member
function GameState:addCrewMember(member)
    if #self.crew.members < self.ship.crewCapacity then
        table.insert(self.crew.members, member)
        return true
    end
    return false
end

-- Change faction reputation
function GameState:changeFactionRep(faction, amount)
    if self.factions[faction] then
        self.factions[faction] = math.max(-3, math.min(3, self.factions[faction] + amount))
        return true
    end
    return false
end

-- Add an investment
function GameState:addInvestment(investment)
    table.insert(self.investments, investment)
end

-- Toggle debug mode
function GameState:toggleDebug()
    self.settings.debug = not self.settings.debug
    return self.settings.debug
end

return GameState```

## src/main.lua
```lua
-- Pirate's Wager: Blood for Gold - Main Game File

local gameState = require('gameState')
local gameMap = require('map')
local playerShip = require('ship')
local timeSystem = require('time')

function love.load()
    -- Load game assets and initialize states
    love.graphics.setDefaultFilter("nearest", "nearest") -- For pixel art
    
    -- Create assets directory if it doesn't exist
    love.filesystem.createDirectory("assets")
    
    -- Initialize game state - central repository for all game data
    gameState:init()
    
    -- Initialize game systems with reference to gameState
    timeSystem:load(gameState)  -- Initialize time tracking
    gameMap:load(gameState)     -- Initialize map 
    playerShip:load(gameState, gameMap)  -- Initialize ship
    
    -- Set window properties
    love.window.setTitle("Pirate's Wager: Blood for Gold")
    love.window.setMode(800, 600, {
        vsync = true,
        resizable = false
    })
end

function love.update(dt)
    -- Early return if game is paused
    if gameState.settings.isPaused then return end
    
    -- Update game state
    gameMap:update(dt, gameState)
    playerShip:update(dt, gameState, gameMap)
    timeSystem:update(dt, gameState)
    
    -- Handle game restart
    if gameState.time.isGameOver and love.keyboard.isDown('r') then
        gameState:reset()  -- Reset all game state
        timeSystem:load(gameState)  -- Reinitialize systems
        gameMap:load(gameState)
        playerShip:load(gameState, gameMap)
    end
end

function love.draw()
    -- Render game
    gameMap:draw(gameState)
    playerShip:draw(gameState)
    timeSystem:draw(gameState)
    
    -- Display fps in debug mode
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end
end

function love.mousemoved(x, y)
    gameMap:mousemoved(x, y, gameState)
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    gameMap:mousepressed(x, y, button, gameState)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "f1" then
        gameState.settings.debug = not gameState.settings.debug
    elseif key == "p" then
        gameState.settings.isPaused = not gameState.settings.isPaused
    end
end```

## src/map.lua
```lua
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
            tooltipText = zone.name .. "\n" .. zone.description .. "\nCurrent location"
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
    end
    
    -- Display instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Hover over zones to see information\nClick adjacent zones to sail there", 10, self.height - 50, 300, "left")
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

return Map```

## src/ship.lua
```lua
-- Ship Module

local Ship = {
    -- Visual properties (display-only, gameplay state is in gameState)
    color = {0.9, 0.9, 0.9, 1},  -- White ship (fallback)
    size = 10,  -- Basic size for representation (fallback)
    
    -- Ship sprite
    sprites = {},
    
    -- Internal animation variables (not part of game state)
    sourceX = 0,
    sourceY = 0,
    targetX = 0,
    targetY = 0,
    moveProgress = 0,
    moveSpeed = 2  -- Units per second
}

-- Initialize ship
function Ship:load(gameState, gameMap)
    -- Load ship sprites
    self.sprites = {
        sloop = love.graphics.newImage("assets/sloop.png")
        -- Will add brigantine.png and galleon.png when available
    }
    -- Find Port Royal and set it as starting location
    for i, zone in ipairs(gameMap.zones) do
        if zone.name == "Port Royal" then
            -- Calculate center of zone for ship position
            local centerX, centerY = 0, 0
            for j = 1, #zone.points, 2 do
                centerX = centerX + zone.points[j]
                centerY = centerY + zone.points[j+1]
            end
            centerX = centerX / (#zone.points / 2)
            centerY = centerY / (#zone.points / 2)
            
            -- Update ship position in game state
            gameState:updateShipPosition(i, centerX, centerY)
            break
        end
    end
    
    print("Ship \"" .. gameState.ship.name .. "\" positioned at zone: " .. 
          gameMap.zones[gameState.ship.currentZone].name)
end

-- Update ship state
function Ship:update(dt, gameState, gameMap)
    -- Handle ship movement animation
    if gameState.ship.isMoving then
        self.moveProgress = self.moveProgress + (dt * self.moveSpeed)
        
        -- Lerp between source and target positions
        if self.moveProgress < 1 then
            -- Calculate interpolated position
            local x = self.sourceX + (self.targetX - self.sourceX) * self.moveProgress
            local y = self.sourceY + (self.targetY - self.sourceY) * self.moveProgress
            
            -- Update position in game state
            gameState.ship.x = x
            gameState.ship.y = y
        else
            -- Movement complete
            gameState.ship.x = self.targetX
            gameState.ship.y = self.targetY
            gameState:setShipMoving(false)
            print("Ship arrived at " .. gameMap.zones[gameState.ship.currentZone].name)
        end
    end
end

-- Draw the ship
function Ship:draw(gameState)
    -- Get the ship's current class (defaulting to sloop for now)
    local shipClass = gameState.ship.class or "sloop"
    local sprite = self.sprites[shipClass]
    
    -- If sprite exists, draw it centered on the ship's position
    if sprite then
        love.graphics.setColor(1, 1, 1, 1)  -- Full white, no tint
        love.graphics.draw(sprite, gameState.ship.x, gameState.ship.y, 0, 1, 1, 
                           sprite:getWidth()/2, sprite:getHeight()/2)
    else
        -- Fallback to triangular shape if sprite not found
        love.graphics.setColor(unpack(self.color))
        
        -- Draw a triangular ship shape
        love.graphics.polygon("fill", 
            gameState.ship.x, gameState.ship.y - self.size,  -- Top point
            gameState.ship.x - self.size/1.5, gameState.ship.y + self.size/1.5,  -- Bottom left
            gameState.ship.x + self.size/1.5, gameState.ship.y + self.size/1.5   -- Bottom right
        )
        
        -- Draw outline
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.polygon("line", 
            gameState.ship.x, gameState.ship.y - self.size,
            gameState.ship.x - self.size/1.5, gameState.ship.y + self.size/1.5,
            gameState.ship.x + self.size/1.5, gameState.ship.y + self.size/1.5
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Move ship to a new zone
function Ship:moveToZone(targetZoneIndex, gameState, gameMap)
    if not gameState.ship.isMoving then
        local targetZone = gameMap.zones[targetZoneIndex]
        local currentZone = gameMap.zones[gameState.ship.currentZone]
        
        -- Check if target zone is adjacent to current zone
        local isAdjacent = false
        for _, adjacentName in ipairs(currentZone.adjacent) do
            if adjacentName == targetZone.name then
                isAdjacent = true
                break
            end
        end
        
        if isAdjacent then
            -- Calculate travel time based on wind BEFORE updating position
            local currentZoneIndex = gameState.ship.currentZone
            
            print("Moving from zone " .. currentZoneIndex .. " (" .. currentZone.name .. ") to zone " .. 
                  targetZoneIndex .. " (" .. targetZone.name .. ")")
                  
            local travelTime, windEffect = gameState:calculateTravelTime(currentZoneIndex, targetZoneIndex, gameMap)
            
            -- Start movement animation
            gameState:setShipMoving(true)
            self.moveProgress = 0
            
            -- Set source position (current position)
            self.sourceX = gameState.ship.x
            self.sourceY = gameState.ship.y
            
            -- Calculate target position (center of target zone)
            local centerX, centerY = 0, 0
            for j = 1, #targetZone.points, 2 do
                centerX = centerX + targetZone.points[j]
                centerY = centerY + targetZone.points[j+1]
            end
            centerX = centerX / (#targetZone.points / 2)
            centerY = centerY / (#targetZone.points / 2)
            
            self.targetX = centerX
            self.targetY = centerY
            
            -- Update ship's current zone in game state
            gameState.ship.currentZone = targetZoneIndex
            
            -- Advance time by calculated weeks for zone transition
            local weekWord = travelTime == 1 and "week" or "weeks"
            if travelTime == 0.5 then
                print("Sailing with " .. windEffect .. " conditions, travel time: half a week")
            else
                print("Sailing with " .. windEffect .. " conditions, travel time: " .. travelTime .. " " .. weekWord)
            end
            
            -- Actually advance the game time
            gameState:advanceTime(travelTime)
            return true
        else
            print("Cannot move to " .. targetZone.name .. " - not adjacent to current zone")
            return false
        end
    else
        print("Ship is already in motion")
        return false
    end
end

return Ship```

## src/time.lua
```lua
-- Time System Module

local TimeSystem = {
    -- Display properties and rendering logic only
    -- All state is now in gameState.time
}

-- Initialize time system
function TimeSystem:load(gameState)
    -- The time properties are now handled by gameState
    -- This function is kept for compatibility
    print("Time system initialized")
end

-- Update time system
function TimeSystem:update(dt, gameState)
    -- Any time-specific update logic would go here
    -- For now, this is just a placeholder for future functionality
end

-- Get a string representation of current time
function TimeSystem:getTimeString(gameState)
    -- Format current week nicely (handle fractional weeks)
    local currentWeek = gameState.time.currentWeek
    local currentWeekDisplay
    
    -- Check if we have a fractional week
    if currentWeek == math.floor(currentWeek) then
        -- Whole number of weeks
        currentWeekDisplay = math.floor(currentWeek)
    elseif math.abs(currentWeek - math.floor(currentWeek) - 0.5) < 0.05 then
        -- About half a week
        currentWeekDisplay = math.floor(currentWeek) .. ".5"
    else
        -- Other fraction (show 1 decimal place)
        currentWeekDisplay = string.format("%.1f", currentWeek)
    end
    
    -- Calculate weeks remaining
    local weeksLeft = gameState.time.totalWeeks - gameState.time.currentWeek
    local weeksLeftDisplay
    
    -- Format weeks left the same way
    if weeksLeft == math.floor(weeksLeft) then
        weeksLeftDisplay = math.floor(weeksLeft)
    elseif math.abs(weeksLeft - math.floor(weeksLeft) - 0.5) < 0.05 then
        weeksLeftDisplay = math.floor(weeksLeft) .. ".5"
    else
        weeksLeftDisplay = string.format("%.1f", weeksLeft)
    end
    
    return "Week " .. currentWeekDisplay .. " (" .. weeksLeftDisplay .. " remaining)"
end

-- Draw time information
function TimeSystem:draw(gameState)
    -- Time information in top-right corner
    love.graphics.setColor(1, 1, 1, 0.8)
    local timeString = self:getTimeString(gameState)
    local textWidth = love.graphics.getFont():getWidth(timeString)
    love.graphics.print(timeString, 800 - textWidth - 10, 10)
    
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
    
    -- Draw the arrow based on wind direction
    love.graphics.setColor(0.9, 0.9, 1, 0.8)
    
    -- Calculate arrow endpoint based on direction
    local endX, endY = arrowX, arrowY
    
    if windDir == "North" then
        endX, endY = arrowX, arrowY - arrowLength
    elseif windDir == "South" then
        endX, endY = arrowX, arrowY + arrowLength
    elseif windDir == "East" then
        endX, endY = arrowX + arrowLength, arrowY
    elseif windDir == "West" then
        endX, endY = arrowX - arrowLength, arrowY
    elseif windDir == "Northeast" then
        endX, endY = arrowX + arrowLength*0.7, arrowY - arrowLength*0.7
    elseif windDir == "Northwest" then
        endX, endY = arrowX - arrowLength*0.7, arrowY - arrowLength*0.7
    elseif windDir == "Southeast" then
        endX, endY = arrowX + arrowLength*0.7, arrowY + arrowLength*0.7
    elseif windDir == "Southwest" then
        endX, endY = arrowX - arrowLength*0.7, arrowY + arrowLength*0.7
    end
    
    -- Line
    love.graphics.setLineWidth(2)
    love.graphics.line(arrowX, arrowY, endX, endY)
    
    -- Arrowhead
    local headSize = 5
    local angle = math.atan2(endY - arrowY, endX - arrowX)
    local leftX = endX - headSize * math.cos(angle - math.pi/6)
    local leftY = endY - headSize * math.sin(angle - math.pi/6)
    local rightX = endX - headSize * math.cos(angle + math.pi/6)
    local rightY = endY - headSize * math.sin(angle + math.pi/6)
    
    love.graphics.polygon("fill", endX, endY, leftX, leftY, rightX, rightY)
    love.graphics.setLineWidth(1)
    
    -- If game is over, show end screen
    if gameState.time.isGameOver then
        -- Semi-transparent overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        
        -- Game over message
        love.graphics.setColor(1, 0.3, 0.3, 1)
        local message = "Game Over - The Earthquake has struck Port Royal!"
        local msgWidth = love.graphics.getFont():getWidth(message)
        love.graphics.print(message, 400 - msgWidth/2, 280)
        
        -- Instructions to restart
        love.graphics.setColor(1, 1, 1, 0.8)
        local restartMsg = "Press 'R' to restart the game"
        local restartWidth = love.graphics.getFont():getWidth(restartMsg)
        love.graphics.print(restartMsg, 400 - restartWidth/2, 320)
    end
end

return TimeSystem```

# Documentation

## docs/GameState.md
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

## docs/Implementation.md
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

## docs/MapZones.md
# Map Zones of Port Royal

## Zone Overview

The Caribbean map in Port Royal is divided into 12 distinct zones, each with its own characteristics and strategic importance. The zones represent different maritime regions in the 17th-century Caribbean, ranging from established colonies to dangerous, mysterious waters.

## Zone Descriptions

### Port Royal
**Description:** The pirate haven and central hub of operations.
**Strategic Value:** As your home port, this is where most business, recruitment, and trading activities take place. The campaign will culminate here with the 1692 earthquake.
**Adjacent Zones:** Calm Waters, Merchants' Route, Nassau

### Calm Waters
**Description:** Peaceful seas with light winds, ideal for new captains.
**Strategic Value:** Safe passage for inexperienced crews, with occasional merchant vessels and minimal threats.
**Adjacent Zones:** Port Royal, Merchants' Route, Stormy Pass

### Merchants' Route
**Description:** Busy trade routes frequent with merchant vessels.
**Strategic Value:** Rich hunting grounds for pirates seeking merchant ships laden with goods, but with increased naval presence.
**Adjacent Zones:** Port Royal, Calm Waters, Navy Waters, Havana

### Nassau
**Description:** A lawless pirate stronghold.
**Strategic Value:** Secondary hub for pirates with access to black market goods and potential crew members with questionable backgrounds.
**Adjacent Zones:** Port Royal, Shark Bay, Cursed Waters

### Stormy Pass
**Description:** Treacherous waters known for sudden storms.
**Strategic Value:** Difficult sailing conditions but a shortcut to northern territories; experienced navigators can pass through more quickly.
**Adjacent Zones:** Calm Waters, Kraken's Reach

### Navy Waters
**Description:** Heavily patrolled by the Royal Navy.
**Strategic Value:** Dangerous for pirates but lucrative for those brave enough to challenge naval vessels with valuable cargo.
**Adjacent Zones:** Merchants' Route, Crown Colony

### Shark Bay
**Description:** Shallow waters home to many sharks.
**Strategic Value:** Rich fishing grounds but risky for swimming and recovery operations; contains hidden reefs with potential for shipwrecks.
**Adjacent Zones:** Nassau, Sunken Graveyard

### Cursed Waters
**Description:** Legends speak of ghost ships here.
**Strategic Value:** Supernatural encounters and rare treasures for those who survive the mysterious dangers.
**Adjacent Zones:** Nassau, Kraken's Reach, Lost Island

### Havana
**Description:** A prosperous Spanish colony.
**Strategic Value:** Wealthy target for raids but heavily defended; offers unique Spanish goods for trading.
**Adjacent Zones:** Merchants' Route, Crown Colony

### Kraken's Reach
**Description:** Deep waters where monsters are said to lurk.
**Strategic Value:** Few dare to sail here, but rumors tell of ancient treasures and artifacts from civilizations long past.
**Adjacent Zones:** Stormy Pass, Cursed Waters

### Crown Colony
**Description:** A well-defended British settlement.
**Strategic Value:** Center of British colonial power with military supplies and potential government contracts for privateers.
**Adjacent Zones:** Navy Waters, Havana

### Sunken Graveyard
**Description:** The final resting place of countless ships.
**Strategic Value:** Rich in salvage opportunities from wrecked ships, but dangerous underwater currents and structures.
**Adjacent Zones:** Shark Bay

### Lost Island
**Description:** A mysterious island appearing on few maps.
**Strategic Value:** Uncharted territory with potential for discovering unique resources, ancient artifacts, or hidden pirate caches.
**Adjacent Zones:** Cursed Waters

## Travel and Wind Effects

Movement between zones is affected by the prevailing wind direction. Sailing with the wind can reduce travel time, while sailing against it increases the journey duration. The strategic captain will plan routes that take advantage of favorable winds to maximize efficiency.

## Zone Development

As the game progresses through development, these zones will gain additional properties including:
- Zone-specific random events
- Special encounters and characters
- Resource gathering opportunities
- Tactical combat scenarios

Each zone will develop a distinct personality that affects gameplay and provides unique strategic opportunities for the aspiring pirate captain.

## docs/TimeSystem.md
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

## docs/WindSystem.md
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

## docs/ZoneSystem.md
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

## ./ComprehensiveDesignDocument.md
Pirate’s Wager: Blood for Gold – Comprehensive Design Document
1. Game Concept Overview
Setting: A pixel-art pirate adventure set in the 17th-century Caribbean, 
centered on Port Royal, culminating in the historical 1692 earthquake as a 
dramatic endgame event.
Core Gameplay: Players captain a pirate ship, juggling tactical naval 
combat and exploration at sea with crew management, investments, and 
faction relationships in Port Royal.
Unique Selling Points:
Dual gameplay loops: tactical combat/exploration at sea and strategic 
management in port.
Dice-based mechanics inspired by Forged in the Dark, emphasizing risk and 
reward.
Hex-grid naval battles for tactical depth.
A 72-week campaign with the earthquake striking randomly between weeks 
60-72, blending urgency with replayability.
A secret ending where players can break a curse and prevent the 
earthquake.
2. Visual Style
Art Direction: Retro pixel art with a limited tile set, layers, and color 
palettes.
Resolution: 800x600 or smaller for a classic aesthetic.
Sea Tiles: Hex-based grid with animated waves indicating wind direction.
Port Phase: Side-view screens for locations (e.g., tavern, shipyard) with 
detailed pixel art and subtle animations (e.g., flickering lanterns, 
swaying palms).
Aesthetic Goals: A gritty yet charming pirate-era Caribbean, balancing 
immersion with clarity in low resolution.
3. Core Gameplay Loops
3.1 At Sea
Exploration:
The Caribbean is split into 10-15 zones (e.g., calm waters, pirate 
territory, naval routes), each with distinct risks and rewards.
Moving between zones or taking major actions (e.g., combat, exploration) 
costs 1 week; movement within a zone (hex-to-hex) is free.
Combat:
Tactical hex-grid battles on a 10x10 hex grid, with ships sized 1-4 hexes 
based on class.
Wind influences movement and combat, varying by sea region (e.g., calm, 
stormy, trade winds).
Actions: Two per turn—one for movement, one for combat/utility:
Fire Cannons: Attack enemies.
Evade: Dodge incoming fire.
Repair: Mend hull damage.
Ram: Deal high-risk hull damage to foes.
Board: Initiate boarding (shifts to side-view combat).
Dice Mechanics: Roll 1-5 d6s based on crew skills, ship stats, and 
context:
6: Success.
4-5: Partial success (e.g., hit with a drawback).
1-3: Failure (e.g., miss or mishap).
Chase Mechanics: If a ship exits the grid, a dice roll decides escape or 
pursuit.
3.2 In Port Royal
Investments (Claims):
Stake resources (gold, items, crew) and time (1-3 weeks) to claim/upgrade 
properties (e.g., taverns, shipyards).
Dice Rolls: Determine outcomes:
Success: Full benefits (e.g., income, perks).
Partial Success: Benefits with complications (e.g., rival attention).
Failure: Lose some resources, gain a minor perk.
Crew Management: Recruit, train, and manage crew with unique roles and 
stats.
Faction Relationships: Build or strain ties with factions (e.g., pirates, 
navy) via actions.
Earthquake Prep Options:
Fortify Investments: Quake-proof properties.
Stockpile Supplies: Hoard resources for recovery.
Evacuation Plans: Prepare to flee with loot and crew.
4. Ship Classes
Players can command three distinct ship classes, each with unique 
characteristics that influence exploration and combat. These classes are 
defined by their size and shape on the hex grid, affecting their speed, 
firepower, durability, and crew capacity.

4.1 Sloop (1-Hex Ship) – "The Swift Sting"
Description: A small, agile vessel favored by daring pirates and 
smugglers. Ideal for hit-and-run tactics and quick escapes.
Hex Size and Shape: 1 hex, compact and highly maneuverable.
Stats:
Speed: 3 hexes per turn (4 with favorable wind)
Firepower: 2 cannons (1 die per attack)
Durability: 10 HP
Crew Capacity: 4 members
Tactical Role: Excels at evasion and precision strikes. Best for players 
who prefer speed and cunning over brute force.
Flavor: A sleek, low-profile ship with patched sails, built for stealth 
and speed.
Customization: Options include adding a harpoon for boarding or extra 
sails for increased speed.
4.2 Brigantine (2-Hex Ship) – "The Rogue’s Balance"
Description: A versatile, mid-sized ship that balances speed and strength. 
Suitable for a wide range of pirate activities.
Hex Size and Shape: 2 hexes in a straight line, sleek and narrow.
Stats:
Speed: 2 hexes per turn (3 with favorable wind)
Firepower: 6 cannons (3 dice per attack)
Durability: 20 HP
Crew Capacity: 8 members
Tactical Role: A jack-of-all-trades ship, capable of raiding, boarding, or 
engaging in sustained combat.
Flavor: A weathered vessel with a history of battles, its deck adorned 
with trophies from past raids.
Customization: Can be outfitted with additional cannons or a reinforced 
hull for durability.
4.3 Galleon (4-Hex Ship – Kite Shape) – "The Crimson Titan"
Description: A massive, heavily armed ship designed for dominance. Its 
kite shape provides a broad profile for devastating broadsides.
Hex Size and Shape: 4 hexes in a kite arrangement (1 hex bow, 2 hexes 
midship, 1 hex stern), wide and imposing.
Stats:
Speed: 1 hex per turn (2 with favorable wind)
Firepower: 12 cannons (6 dice per attack)
Durability: 40 HP
Crew Capacity: 12 members
Tactical Role: A slow but powerful ship that excels in head-on combat and 
intimidation. Requires careful positioning due to its size.
Flavor: An ornate, battle-scarred behemoth, its deck laden with gold and 
gunpowder.
Customization: Options include reinforced plating for extra durability or 
enhanced rigging to improve maneuverability.
4.4 Ship Classes and the Hex Grid
Sloop (1-hex): Highly agile, able to dart through tight spaces and evade 
larger ships. Its small size makes it a difficult target.
Brigantine (2-hex): Balanced maneuverability, able to pivot and reposition 
effectively while maintaining a clear broadside arc.
Galleon (4-hex, kite shape): Slow to turn, requiring strategic use of wind 
and positioning. Its wide midsection allows for powerful broadsides from 
multiple angles but makes navigation in confined areas challenging.
4.5 Progression and Balance
Sloop: High-risk, high-reward gameplay focused on speed and precision.
Brigantine: Versatile and adaptable, suitable for a range of strategies.
Galleon: Emphasizes raw power and resilience, ideal for players who prefer 
overwhelming force.
Upgrades: Players can enhance speed, firepower, or durability within each 
class to suit their playstyle.
5. Mechanics Deep Dive
5.1 Crew System
Crew Roles: Navigator, Gunner, Surgeon, etc., boosting specific actions.
Character Sheet:
Role: Defines specialty.
Skill Level: 1-5, adding dice/bonuses to rolls.
Loyalty: 1-10 (low risks mutiny, high enhances performance).
Influences: Victories (+1), rum (+2), long voyages (-1/week).
Health: Hit points; injuries occur in combat.
Boon/Bane: One positive trait (e.g., “Sharp-Eyed”) and one negative (e.g., 
“Cursed”).
Recruitment: Found in taverns or via quests; elite crew require high 
reputation.
5.2 Item System
Types:
Resources: Bulk goods (e.g., rum, timber) tracked numerically.
Treasures: Unique items (e.g., maps, jewels) taking inventory slots.
Equipment: Gear for crew/ship (e.g., cannons, sails).
Inventory: Ship hold has 10 slots, expandable in port.
Staking: Items/crew committed to actions; failure risks partial loss.
5.3 Reputation System
Factions: Pirates, Merchants, Navy, Locals.
Scale: -3 to +3 per faction.
-3: Hated (e.g., barred from ports).
0: Neutral.
+3: Revered (e.g., exclusive deals).
Shifts: Actions (e.g., raiding) adjust rep by 1-2 points.
Impact: Affects opportunities, crew recruitment, and events.
5.4 Passage of Time
Timeline: 72 weeks, with the earthquake striking randomly between weeks 
60-72.
At Sea: Zone movement or major actions cost 1 week.
In Port: Actions take 1-3 weeks (e.g., 1 for repairs, 2 for investments).
Hints: NPC rumors and tremors escalate as the quake approaches.
5.5 Economic Systems
Trade Routes: Buy low, sell high across ports with dynamic pricing.
Missions: Faction quests (e.g., smuggling for merchants).
Passive Income: Investments yield steady cash or perks.
High-Risk Options: Raiding navy convoys offers rare loot (e.g., unique 
ship parts).
6. Port Phase Details
Presentation: One screen per location (e.g., tavern, shipyard) with 
side-view pixel art and light animations.
Interactions: Click to access functions; occasional mini-events (e.g., bar 
fights, rumors).
Purpose: A streamlined hub for management and prep with flavorful 
immersion.
7. Combat System
Hex Grid: 10x10 hexes; ships sized 1-4 hexes based on class.
Movement: Varies by ship class (see "Ship Classes").
Actions: Two per turn (movement + combat/utility).
Dice Pools: 1-5 d6s for attacks, evasion, etc.
Boarding Actions: Side-view crew combat.
8. Modular Systems
Ship Customization: Hulls, sails, cannons with unique stats (e.g., speed, 
firepower). Each ship class has specific upgrade paths (e.g., sloops can 
add speed, galleons can add durability).
Crew Roles and Traits: Combinatorial depth for management.
Investments: Properties offer stacking perks and interactions.
9. Narrative and Supernatural Elements
Cursed Prophecy: A map reveals the earthquake’s curse, tied to a vengeful 
captain.
Secret Ending: A challenging path to break the curse and stop the quake.
Low Fantasy: Rare supernatural elements (e.g., curses, ghost ships) in 
specific quests/zones.
10. Difficulty and Progression
Scaling Enemies: Navy patrols grow stronger with your reputation.
Event Escalation: Storms and pirate hunters intensify over time.
Win/Loss Conditions:
Win: Survive the quake with a thriving empire or legendary status.
Loss: Lose your ship, crew, or fail to prepare.
11. Strategic Paths
Merchant Focus: Wealth via trade and investments, fortifying the port.
Combat Focus: Raiding and crew dominance to rule the seas.
Balanced Approach: Mix raiding and investing for flexibility.
12. Project Name
Working Title: Pirate’s Wager: Blood for Gold
13. Next Steps
Mock up a Caribbean zone map to test voyage lengths.
Define specific random events and triggers.
Playtest combat for balance and engagement.
Expand crew boon/bane traits for variety.

## ./SprintPlan.md
Total Sprints: 10 (initial plan; adjustable based on progress or 
feedback).
Approach: Agile-inspired, focusing on iterative development, testing, and 
refinement.
Sprint Goals
Deliver functional components incrementally.
Prioritize core gameplay (sea exploration, combat, port management) for 
early playtesting.
Build towards a cohesive pirate adventure with tactical depth and 
strategic management.
Sprint 1: Foundation - Game World and Basic Ship Mechanics
Objective: Establish the game world and basic exploration mechanics.

Tasks:

Create a Caribbean map with 10-15 zones (e.g., calm waters, pirate 
territory) using a hex grid.
Implement basic ship movement:
Moving between zones costs 1 week.
Within-zone hex-to-hex movement is free.
Develop the time management system (72-week campaign).
Add wind direction mechanics affecting movement (e.g., +1 hex with 
favorable wind).
Create placeholder pixel art for sea tiles and ships (Sloop, Brigantine, 
Galleon).
Deliverables:
A navigable Caribbean map with zones and hex grid.
Basic ship movement and time tracking.
Sprint 2: Port Royal and Crew Management
Objective: Build Port Royal as the management hub and introduce crew 
mechanics.

Tasks:

Design Port Royal with key locations (tavern, shipyard) in side-view pixel 
art.
Implement crew recruitment in taverns (basic roles: Navigator, Gunner, 
etc.).
Develop crew management UI (view stats, roles, loyalty).
Set up an inventory system (10 slots for resources/items).
Add basic crew stat impacts (e.g., Navigator adds 1 die to movement 
rolls).
Deliverables:
Functional Port Royal hub with interactive locations.
Basic crew recruitment and management system.
Sprint 3: Combat System - Phase 1
Objective: Introduce core naval combat mechanics.

Tasks:

Create a 10x10 hex-grid battle system.
Implement basic combat actions:
Fire Cannons (attack).
Evade (dodge).
Repair (heal hull).
Develop dice mechanics:
Roll 1-5 d6s based on crew/ship stats.
6 = Success, 4-5 = Partial Success, 1-3 = Failure.
Add simple enemy AI (e.g., moves and fires cannons).
Design combat UI (ship stats, dice results).
Deliverables:
Playable sea combat with dice-based actions.
Basic enemy AI for testing.
Sprint 4: Economic Systems and Investments
Objective: Add trade and investment mechanics for resource management.

Tasks:

Implement trade routes with dynamic pricing across zones.
Develop the investment system:
Stake resources to claim properties (e.g., taverns).
Dice rolls determine outcomes (success = income, failure = loss).
Introduce passive income from investments.
Balance economy for steady progression (e.g., 10-20 gold/week from 
properties).
Add economic UI (track gold, investments).
Deliverables:
Functional trade and investment systems.
Basic economic balance.
Sprint 5: Reputation and Faction System
Objective: Introduce factions and reputation mechanics.

Tasks:

Create four factions (Pirates, Merchants, Navy, Locals) with a -3 to +3 
reputation scale.
Implement reputation shifts based on actions (e.g., raiding lowers Navy 
rep).
Add faction-specific quests (e.g., smuggling for Merchants).
Integrate reputation effects (e.g., +3 Pirates = exclusive crew recruits).
Design faction UI to track relationships.
Deliverables:
Working reputation system with faction interactions.
Initial faction quests.
Sprint 6: Combat System - Phase 2
Objective: Expand combat with boarding and advanced mechanics.

Tasks:

Add advanced actions:
Ram (high-risk hull damage).
Board (triggers side-view crew combat).
Implement crew combat (e.g., dice rolls for melee).
Enhance enemy AI (uses ram/board, adapts to player tactics).
Polish combat UI (animations, sound cues).
Balance combat across ship classes (Sloop = evasion, Galleon = firepower).
Deliverables:
Full combat system with boarding and crew combat.
Improved AI and balance.
Sprint 7: Ship Customization and Upgrades
Objective: Enable ship customization for strategic depth.

Tasks:

Develop customization options:
Sloop: Extra sails (+speed).
Brigantine: More cannons (+firepower).
Galleon: Reinforced hull (+durability).
Implement upgrade system in the shipyard.
Balance upgrades (e.g., speed vs. firepower trade-offs).
Add ship customization UI.
Test ship class distinctions (1-hex Sloop, 4-hex Galleon).
Deliverables:
Functional ship customization system.
Balanced upgrade options.
Sprint 8: Narrative and Quests
Objective: Integrate the main storyline and side quests.

Tasks:

Write and implement the cursed prophecy narrative.
Develop side quests for factions (e.g., retrieve a lost map).
Create NPC dialogue system for quest delivery.
Plan the secret ending (break the curse requirements).
Add narrative triggers (e.g., prophecy hints after week 30).
Deliverables:
Cohesive narrative with main and side quests.
Functional dialogue system.
Sprint 9: Time Management and Events
Objective: Refine time mechanics and add dynamic events.

Tasks:

Finalize the 72-week timeline with earthquake (randomly weeks 60-72).
Implement random events (e.g., storms reduce speed, pirate hunters 
attack).
Add earthquake hints (NPC rumors, tremors from week 50).
Develop prep options: fortify investments, stockpile, evacuate.
Balance event frequency (1-2 per 10 weeks).
Deliverables:
Full time and event systems.
Balanced earthquake mechanics.
Sprint 10: Polish and Optimization
Objective: Refine visuals, performance, and player experience.

Tasks:

Polish pixel art (sea waves, port animations).
Optimize for 800x600 resolution.
Enhance UI/UX (intuitive menus, feedback).
Create a tutorial (cover movement, combat, port actions).
Conduct playtesting and bug fixing.
Deliverables:
Polished, optimized build.
Complete tutorial for new players.
Key Considerations
Dependencies: Sprints build on prior work (e.g., combat expansions need 
Sprint 3). Adjust if blockers arise.
MVP Focus: Sprints 1-3 deliver the core loops (exploration, combat, port 
management) for early testing.
Playtesting: Test after each sprint to validate mechanics and gather 
feedback. Focus on fun and balance.
Flexibility: If time is tight, delay advanced features (e.g., crew traits, 
supernatural elements) for post-Sprint 10 iterations.
Next Steps Beyond Sprint 10
Crew Depth: Add boons/banes (e.g., “Sharp-Eyed” vs. “Cursed”) and loyalty 
mechanics.
Economic Risks: Introduce high-stakes options like raiding navy convoys.
Supernatural: Add low-fantasy quests (e.g., ghost ships).
Endgame: Polish the earthquake and secret ending for replayability.

## ./TicketStrategy.md
To complete Tickets for this project, work together with me to follow 
these steps:

1. Open the relevant `0x-0x-description.md` file.

2. Carefully read the Description at the top of the file to understand 
the goal for the task.

3. Complete each component Task that follows the description in 
order. If the task is ambiguous, you may wish to create a plan and submit 
it to me for approval or workshopping first.

4. Ensure that each of the Acceptance Criteria is fulfilled. If it is 
difficult to tell whether a criterion has been met successfully, check 
with me.

5. Append a newline with a cat emoji followed by a zzz "snoozing" emoji 
to the end of the file.

Strategy Notes:

* Consider me your partner in completing each Task. Solve issues 
independently when you can do so confidently, but please avail yourself 
of my input as often as you like - I have a very clear product vision in 
terms of final UX, and a solid understanding of the technical side, with 
a background as an IC backend software developer for nearly a decade.

* I am taking full advantage of your superpowers: your strong coding 
and organizational ability, tirelessness, and general cross-domain 
capability. Take advantage of my superpowers too: often-complimented 
taste, clearly defined product vision, and strong ability to understand 
the user-side of experiences at both a high level and a very granular 
level - I used to work quite successfully on designing puzzles in escape 
rooms. The boundary will be extremely permeable, but I'm closest to a 
project manager here, where you are closest to a lead programmer. I am 
counting on you to ask me lots of questions and rely on my feedback to 
bring my vision to life. Don't let that stop you from making creative 
suggestions when they spark for you, though, I love to hear ideas :)

* This document includes a list of Known Weaknesses below, these are areas 
of development where either you or I have struggled in the past. When 
these elements are in play, bias towards working more closely with me so 
we can check each others' logic and validate each others' 
implementations.

Known Weaknesses:

* It is difficult for you to "see" visuals in our game's style - the 
low-res retro imagery seems to be difficult for you to parse. Rely on me 
to check whether everything looks the way it should.

* In prototyping, the clarity of the combat UI was the biggest pain point 
for testers. Our low-res style demands special attention to readability, 
which we should consider when designing display elements. Refer back to 
the canon of games for the Game Boy and Game Boy Advance, such as 
Pokemon, Fire Emblem, and Golden Sun for inspiration on how to work around low-resolution in our layouts. 

## ./codebase_dump.md
# PortRoyal Codebase Dump
Generated: Wed Mar 26 17:12:08 CDT 2025

# Source Code

## src/conf.lua
```lua
-- LÖVE Configuration
function love.conf(t)
    t.title = "Pirate's Wager: Blood for Gold"  -- The title of the window
    t.version = "11.4"                -- The LÖVE version this game was made for
    t.window.width = 800              -- Game window width
    t.window.height = 600             -- Game window height
    t.window.resizable = false        -- Let the window be user-resizable
    t.console = true                  -- Enable console for debug output
    
    -- For development
    t.window.vsync = 1                -- Vertical sync mode
    
    -- Disable modules we won't be using
    t.modules.joystick = false        -- No need for joystick module
    t.modules.physics = false         -- No need for physics module for map navigation
end```

## src/gameState.lua
```lua
-- Game State Module
-- Central repository for game state that needs to be accessed across modules

local GameState = {
    -- Player ship information
    ship = {
        name = "The Swift Sting",
        class = "sloop",     -- Ship class (sloop, brigantine, galleon)
        currentZone = nil,  -- Set during initialization
        x = 0,
        y = 0,
        isMoving = false,
        -- Ship stats
        speed = 3,          -- Hexes per turn in combat (future feature)
        firepower = 2,      -- Number of cannons
        durability = 10,    -- Hull hit points
        crewCapacity = 4    -- Maximum crew size
    },
    
    -- Time tracking
    time = {
        currentWeek = 1,
        totalWeeks = 72,
        earthquakeWeek = nil,  -- Set during initialization
        isGameOver = false
    },
    
    -- Player resources
    resources = {
        gold = 50,          -- Starting gold
        rum = 0,
        timber = 0,
        gunpowder = 0
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = 5          -- Scale 1-10
    },
    
    -- Faction relationships (-3 to +3)
    factions = {
        pirates = 0,
        merchants = 0,
        navy = 0,
        locals = 0
    },
    
    -- Player's investments/claims
    investments = {
        -- Will contain investment objects
    },
    
    -- Environmental conditions
    environment = {
        -- Wind system
        wind = {
            directions = {"North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"},
            currentDirection = nil,  -- Set during initialization
            changeTimer = 0,         -- Timer for wind changes (future feature)
            changeInterval = 4       -- How often wind might change (in weeks)
        }
    },
    
    -- Game settings and flags
    settings = {
        debug = false  -- Set to false for normal gameplay, true for debugging
    }
}

-- Initialize game state
function GameState:init()
    -- Seed random number generator
    math.randomseed(os.time())
    
    -- Set earthquake week (random between weeks 60-72)
    self.time.earthquakeWeek = math.random(60, 72)
    
    -- Initialize wind direction (random)
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        name = "Captain",
        role = "Navigator",
        skill = 2,
        loyalty = 8,
        health = 10
    })
    
    print("Game state initialized!")
    print("Earthquake will occur on week: " .. self.time.earthquakeWeek)
    print("Initial wind direction: " .. self.environment.wind.currentDirection)
end

-- Reset game state (for new game or restart)
function GameState:reset()
    -- Reset ship
    self.ship.name = "The Swift Sting"
    self.ship.class = "sloop"
    self.ship.currentZone = nil
    self.ship.x = 0
    self.ship.y = 0
    self.ship.isMoving = false
    
    -- Reset time
    self.time.currentWeek = 1
    self.time.earthquakeWeek = math.random(60, 72)
    self.time.isGameOver = false
    
    -- Reset wind
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    self.environment.wind.changeTimer = 0
    
    -- Reset resources
    self.resources.gold = 50
    self.resources.rum = 0
    self.resources.timber = 0
    self.resources.gunpowder = 0
    
    -- Reset crew
    self.crew.members = {}
    self.crew.morale = 5
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        name = "Captain",
        role = "Navigator",
        skill = 2,
        loyalty = 8,
        health = 10
    })
    
    -- Reset factions
    self.factions.pirates = 0
    self.factions.merchants = 0
    self.factions.navy = 0
    self.factions.locals = 0
    
    -- Reset investments
    self.investments = {}
    
    print("Game state reset!")
    print("Earthquake will occur on week: " .. self.time.earthquakeWeek)
    print("Wind direction reset to: " .. self.environment.wind.currentDirection)
end

-- Advance time by specified number of weeks
function GameState:advanceTime(weeks)
    -- For display purposes, we want to show 0.5 for half a week
    -- but internally, we'll track weeks with 1 decimal place
    local roundedWeeks = math.floor(weeks * 10 + 0.5) / 10
    self.time.currentWeek = self.time.currentWeek + roundedWeeks
    
    -- Check for game end conditions
    if self.time.currentWeek >= self.time.earthquakeWeek then
        -- Earthquake occurs
        print("EARTHQUAKE! Port Royal is devastated!")
        self.time.isGameOver = true
    elseif self.time.currentWeek >= self.time.totalWeeks then
        -- Campaign ends regardless
        print("End of campaign reached!")
        self.time.isGameOver = true
    end
    
    -- Report time advancement
    print("Advanced " .. weeks .. " week(s) - Now on week " .. self.time.currentWeek .. " of " .. self.time.totalWeeks)
    
    -- Update wind direction occasionally (each changeInterval weeks)
    self.environment.wind.changeTimer = self.environment.wind.changeTimer + weeks
    if self.environment.wind.changeTimer >= self.environment.wind.changeInterval then
        self.environment.wind.changeTimer = 0
        local oldDirection = self.environment.wind.currentDirection
        
        -- Choose a new direction (potentially same as before)
        self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
        
        if oldDirection ~= self.environment.wind.currentDirection then
            print("Wind direction changed from " .. oldDirection .. " to " .. self.environment.wind.currentDirection)
        end
    end
    
    -- As player approaches earthquake, add warning signs
    if self.time.currentWeek >= 50 and not self.time.isGameOver then
        local weeksToQuake = self.time.earthquakeWeek - self.time.currentWeek
        if weeksToQuake <= 5 then
            print("Warning: Strong tremors felt in Port Royal!")
        elseif weeksToQuake <= 10 then
            print("Warning: Sailors report strange tides and underwater rumbling.")
        end
    end
    
    return not self.time.isGameOver  -- Return false if game is over
end

-- Calculate travel time between zones based on wind
function GameState:calculateTravelTime(fromZoneIdx, toZoneIdx, map)
    -- Base travel time is always 1 week
    local baseTravelTime = 1
    
    -- If either zone is invalid, just return base time
    if not fromZoneIdx or not toZoneIdx or 
       fromZoneIdx > #map.zones or toZoneIdx > #map.zones then
        return baseTravelTime, "normal"
    end
    
    -- Debug info for wind calculation
    if self.settings.debug then
        print("Calculating travel time from zone " .. fromZoneIdx .. " to zone " .. toZoneIdx)
        print("Current wind direction: " .. self.environment.wind.currentDirection)
    end
    
    -- For Sprint 1, we apply a simple wind modifier:
    -- Assign each zone a "direction" based on its position relative to the map center
    local fromZone = map.zones[fromZoneIdx]
    local toZone = map.zones[toZoneIdx]
    
    -- Calculate center points
    local fromCenterX, fromCenterY = 0, 0
    for j = 1, #fromZone.points, 2 do
        fromCenterX = fromCenterX + fromZone.points[j]
        fromCenterY = fromCenterY + fromZone.points[j+1]
    end
    fromCenterX = fromCenterX / (#fromZone.points / 2)
    fromCenterY = fromCenterY / (#fromZone.points / 2)
    
    local toCenterX, toCenterY = 0, 0
    for j = 1, #toZone.points, 2 do
        toCenterX = toCenterX + toZone.points[j]
        toCenterY = toCenterY + toZone.points[j+1]
    end
    toCenterX = toCenterX / (#toZone.points / 2)
    toCenterY = toCenterY / (#toZone.points / 2)
    
    -- Calculate travel direction (from -> to)
    local dx = toCenterX - fromCenterX
    local dy = toCenterY - fromCenterY
    local travelAngle = math.atan2(dy, dx) * 180 / math.pi
    
    if self.settings.debug then
        print("Travel vector: dx=" .. dx .. ", dy=" .. dy)
        print("Travel angle: " .. travelAngle .. " degrees")
    end
    
    -- Convert angle to compass direction (0 = East, 90 = South, etc.)
    local travelDirection = ""
    if travelAngle >= -22.5 and travelAngle < 22.5 then
        travelDirection = "East"
    elseif travelAngle >= 22.5 and travelAngle < 67.5 then
        travelDirection = "Southeast"
    elseif travelAngle >= 67.5 and travelAngle < 112.5 then
        travelDirection = "South"
    elseif travelAngle >= 112.5 and travelAngle < 157.5 then
        travelDirection = "Southwest"
    elseif travelAngle >= 157.5 or travelAngle < -157.5 then
        travelDirection = "West"
    elseif travelAngle >= -157.5 and travelAngle < -112.5 then
        travelDirection = "Northwest"
    elseif travelAngle >= -112.5 and travelAngle < -67.5 then
        travelDirection = "North"
    elseif travelAngle >= -67.5 and travelAngle < -22.5 then
        travelDirection = "Northeast"
    end
    
    if self.settings.debug then
        print("Travel direction: " .. travelDirection)
    end
    
    -- Compare travel direction with wind direction
    local windDirection = self.environment.wind.currentDirection
    local windModifier = 0
    
    -- Define opposite directions for "with wind" calculation
    local oppositeOf = {
        ["North"] = "South",
        ["South"] = "North",
        ["East"] = "West",
        ["West"] = "East",
        ["Northeast"] = "Southwest",
        ["Southwest"] = "Northeast",
        ["Northwest"] = "Southeast",
        ["Southeast"] = "Northwest"
    }
    
    -- Wind modifiers:
    -- Traveling WITH the wind (in the same direction as the wind blows): -0.5 weeks
    -- Traveling AGAINST the wind (opposite to wind direction): +1 week
    -- Traveling in any other direction (perpendicular/angled): no modifier
    
    -- With the wind (same direction): reduce travel time
    if travelDirection == windDirection then
        windModifier = -0.5  -- Half a week faster with the wind
    -- Against the wind (sailing into the wind): +1 week
    elseif travelDirection == oppositeOf[windDirection] then
        windModifier = 1
    -- Perpendicular to wind: no modifier
    else
        windModifier = 0
    end
    
    -- Apply the wind modifier (ensure minimum 0.5 week)
    local travelTime = math.max(0.5, baseTravelTime + windModifier)
    
    -- Return both the travel time and the wind effect description
    local windEffect = ""
    if windModifier > 0 then
        windEffect = "against wind"
    elseif windModifier < 0 then
        windEffect = "with wind"
    else
        windEffect = "crosswind"
    end
    
    if self.settings.debug then
        print("Wind direction: " .. windDirection)
        print("Wind modifier: " .. windModifier)
        print("Final travel time: " .. travelTime .. " weeks")
        print("Wind effect: " .. windEffect)
    end
    
    return travelTime, windEffect
end

-- Update ship position
function GameState:updateShipPosition(zoneIndex, x, y)
    self.ship.currentZone = zoneIndex
    self.ship.x = x
    self.ship.y = y
end

-- Set ship movement state
function GameState:setShipMoving(isMoving)
    self.ship.isMoving = isMoving
end

-- Add resources
function GameState:addResources(type, amount)
    if self.resources[type] then
        self.resources[type] = self.resources[type] + amount
        return true
    end
    return false
end

-- Check if player can afford a cost
function GameState:canAfford(type, amount)
    if self.resources[type] and self.resources[type] >= amount then
        return true
    end
    return false
end

-- Spend resources
function GameState:spendResources(type, amount)
    if self:canAfford(type, amount) then
        self.resources[type] = self.resources[type] - amount
        return true
    end
    return false
end

-- Add a crew member
function GameState:addCrewMember(member)
    if #self.crew.members < self.ship.crewCapacity then
        table.insert(self.crew.members, member)
        return true
    end
    return false
end

-- Change faction reputation
function GameState:changeFactionRep(faction, amount)
    if self.factions[faction] then
        self.factions[faction] = math.max(-3, math.min(3, self.factions[faction] + amount))
        return true
    end
    return false
end

-- Add an investment
function GameState:addInvestment(investment)
    table.insert(self.investments, investment)
end

-- Toggle debug mode
function GameState:toggleDebug()
    self.settings.debug = not self.settings.debug
    return self.settings.debug
end

return GameState```

## src/main.lua
```lua
-- Pirate's Wager: Blood for Gold - Main Game File

local gameState = require('gameState')
local gameMap = require('map')
local playerShip = require('ship')
local timeSystem = require('time')

function love.load()
    -- Load game assets and initialize states
    love.graphics.setDefaultFilter("nearest", "nearest") -- For pixel art
    
    -- Create assets directory if it doesn't exist
    love.filesystem.createDirectory("assets")
    
    -- Initialize game state - central repository for all game data
    gameState:init()
    
    -- Initialize game systems with reference to gameState
    timeSystem:load(gameState)  -- Initialize time tracking
    gameMap:load(gameState)     -- Initialize map 
    playerShip:load(gameState, gameMap)  -- Initialize ship
    
    -- Set window properties
    love.window.setTitle("Pirate's Wager: Blood for Gold")
    love.window.setMode(800, 600, {
        vsync = true,
        resizable = false
    })
end

function love.update(dt)
    -- Early return if game is paused
    if gameState.settings.isPaused then return end
    
    -- Update game state
    gameMap:update(dt, gameState)
    playerShip:update(dt, gameState, gameMap)
    timeSystem:update(dt, gameState)
    
    -- Handle game restart
    if gameState.time.isGameOver and love.keyboard.isDown('r') then
        gameState:reset()  -- Reset all game state
        timeSystem:load(gameState)  -- Reinitialize systems
        gameMap:load(gameState)
        playerShip:load(gameState, gameMap)
    end
end

function love.draw()
    -- Render game
    gameMap:draw(gameState)
    playerShip:draw(gameState)
    timeSystem:draw(gameState)
    
    -- Display fps in debug mode
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end
end

function love.mousemoved(x, y)
    gameMap:mousemoved(x, y, gameState)
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    gameMap:mousepressed(x, y, button, gameState)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "f1" then
        gameState.settings.debug = not gameState.settings.debug
    elseif key == "p" then
        gameState.settings.isPaused = not gameState.settings.isPaused
    end
end```

## src/map.lua
```lua
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
            tooltipText = zone.name .. "\n" .. zone.description .. "\nCurrent location"
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
    end
    
    -- Display instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Hover over zones to see information\nClick adjacent zones to sail there", 10, self.height - 50, 300, "left")
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

return Map```

## src/ship.lua
```lua
-- Ship Module

local Ship = {
    -- Visual properties (display-only, gameplay state is in gameState)
    color = {0.9, 0.9, 0.9, 1},  -- White ship (fallback)
    size = 10,  -- Basic size for representation (fallback)
    
    -- Ship sprite
    sprites = {},
    
    -- Internal animation variables (not part of game state)
    sourceX = 0,
    sourceY = 0,
    targetX = 0,
    targetY = 0,
    moveProgress = 0,
    moveSpeed = 2  -- Units per second
}

-- Initialize ship
function Ship:load(gameState, gameMap)
    -- Load ship sprites
    self.sprites = {
        sloop = love.graphics.newImage("assets/sloop.png")
        -- Will add brigantine.png and galleon.png when available
    }
    -- Find Port Royal and set it as starting location
    for i, zone in ipairs(gameMap.zones) do
        if zone.name == "Port Royal" then
            -- Calculate center of zone for ship position
            local centerX, centerY = 0, 0
            for j = 1, #zone.points, 2 do
                centerX = centerX + zone.points[j]
                centerY = centerY + zone.points[j+1]
            end
            centerX = centerX / (#zone.points / 2)
            centerY = centerY / (#zone.points / 2)
            
            -- Update ship position in game state
            gameState:updateShipPosition(i, centerX, centerY)
            break
        end
    end
    
    print("Ship \"" .. gameState.ship.name .. "\" positioned at zone: " .. 
          gameMap.zones[gameState.ship.currentZone].name)
end

-- Update ship state
function Ship:update(dt, gameState, gameMap)
    -- Handle ship movement animation
    if gameState.ship.isMoving then
        self.moveProgress = self.moveProgress + (dt * self.moveSpeed)
        
        -- Lerp between source and target positions
        if self.moveProgress < 1 then
            -- Calculate interpolated position
            local x = self.sourceX + (self.targetX - self.sourceX) * self.moveProgress
            local y = self.sourceY + (self.targetY - self.sourceY) * self.moveProgress
            
            -- Update position in game state
            gameState.ship.x = x
            gameState.ship.y = y
        else
            -- Movement complete
            gameState.ship.x = self.targetX
            gameState.ship.y = self.targetY
            gameState:setShipMoving(false)
            print("Ship arrived at " .. gameMap.zones[gameState.ship.currentZone].name)
        end
    end
end

-- Draw the ship
function Ship:draw(gameState)
    -- Get the ship's current class (defaulting to sloop for now)
    local shipClass = gameState.ship.class or "sloop"
    local sprite = self.sprites[shipClass]
    
    -- If sprite exists, draw it centered on the ship's position
    if sprite then
        love.graphics.setColor(1, 1, 1, 1)  -- Full white, no tint
        love.graphics.draw(sprite, gameState.ship.x, gameState.ship.y, 0, 1, 1, 
                           sprite:getWidth()/2, sprite:getHeight()/2)
    else
        -- Fallback to triangular shape if sprite not found
        love.graphics.setColor(unpack(self.color))
        
        -- Draw a triangular ship shape
        love.graphics.polygon("fill", 
            gameState.ship.x, gameState.ship.y - self.size,  -- Top point
            gameState.ship.x - self.size/1.5, gameState.ship.y + self.size/1.5,  -- Bottom left
            gameState.ship.x + self.size/1.5, gameState.ship.y + self.size/1.5   -- Bottom right
        )
        
        -- Draw outline
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.polygon("line", 
            gameState.ship.x, gameState.ship.y - self.size,
            gameState.ship.x - self.size/1.5, gameState.ship.y + self.size/1.5,
            gameState.ship.x + self.size/1.5, gameState.ship.y + self.size/1.5
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Move ship to a new zone
function Ship:moveToZone(targetZoneIndex, gameState, gameMap)
    if not gameState.ship.isMoving then
        local targetZone = gameMap.zones[targetZoneIndex]
        local currentZone = gameMap.zones[gameState.ship.currentZone]
        
        -- Check if target zone is adjacent to current zone
        local isAdjacent = false
        for _, adjacentName in ipairs(currentZone.adjacent) do
            if adjacentName == targetZone.name then
                isAdjacent = true
                break
            end
        end
        
        if isAdjacent then
            -- Calculate travel time based on wind BEFORE updating position
            local currentZoneIndex = gameState.ship.currentZone
            
            print("Moving from zone " .. currentZoneIndex .. " (" .. currentZone.name .. ") to zone " .. 
                  targetZoneIndex .. " (" .. targetZone.name .. ")")
                  
            local travelTime, windEffect = gameState:calculateTravelTime(currentZoneIndex, targetZoneIndex, gameMap)
            
            -- Start movement animation
            gameState:setShipMoving(true)
            self.moveProgress = 0
            
            -- Set source position (current position)
            self.sourceX = gameState.ship.x
            self.sourceY = gameState.ship.y
            
            -- Calculate target position (center of target zone)
            local centerX, centerY = 0, 0
            for j = 1, #targetZone.points, 2 do
                centerX = centerX + targetZone.points[j]
                centerY = centerY + targetZone.points[j+1]
            end
            centerX = centerX / (#targetZone.points / 2)
            centerY = centerY / (#targetZone.points / 2)
            
            self.targetX = centerX
            self.targetY = centerY
            
            -- Update ship's current zone in game state
            gameState.ship.currentZone = targetZoneIndex
            
            -- Advance time by calculated weeks for zone transition
            local weekWord = travelTime == 1 and "week" or "weeks"
            if travelTime == 0.5 then
                print("Sailing with " .. windEffect .. " conditions, travel time: half a week")
            else
                print("Sailing with " .. windEffect .. " conditions, travel time: " .. travelTime .. " " .. weekWord)
            end
            
            -- Actually advance the game time
            gameState:advanceTime(travelTime)
            return true
        else
            print("Cannot move to " .. targetZone.name .. " - not adjacent to current zone")
            return false
        end
    else
        print("Ship is already in motion")
        return false
    end
end

return Ship```

## src/time.lua
```lua
-- Time System Module

local TimeSystem = {
    -- Display properties and rendering logic only
    -- All state is now in gameState.time
}

-- Initialize time system
function TimeSystem:load(gameState)
    -- The time properties are now handled by gameState
    -- This function is kept for compatibility
    print("Time system initialized")
end

-- Update time system
function TimeSystem:update(dt, gameState)
    -- Any time-specific update logic would go here
    -- For now, this is just a placeholder for future functionality
end

-- Get a string representation of current time
function TimeSystem:getTimeString(gameState)
    -- Format current week nicely (handle fractional weeks)
    local currentWeek = gameState.time.currentWeek
    local currentWeekDisplay
    
    -- Check if we have a fractional week
    if currentWeek == math.floor(currentWeek) then
        -- Whole number of weeks
        currentWeekDisplay = math.floor(currentWeek)
    elseif math.abs(currentWeek - math.floor(currentWeek) - 0.5) < 0.05 then
        -- About half a week
        currentWeekDisplay = math.floor(currentWeek) .. ".5"
    else
        -- Other fraction (show 1 decimal place)
        currentWeekDisplay = string.format("%.1f", currentWeek)
    end
    
    -- Calculate weeks remaining
    local weeksLeft = gameState.time.totalWeeks - gameState.time.currentWeek
    local weeksLeftDisplay
    
    -- Format weeks left the same way
    if weeksLeft == math.floor(weeksLeft) then
        weeksLeftDisplay = math.floor(weeksLeft)
    elseif math.abs(weeksLeft - math.floor(weeksLeft) - 0.5) < 0.05 then
        weeksLeftDisplay = math.floor(weeksLeft) .. ".5"
    else
        weeksLeftDisplay = string.format("%.1f", weeksLeft)
    end
    
    return "Week " .. currentWeekDisplay .. " (" .. weeksLeftDisplay .. " remaining)"
end

-- Draw time information
function TimeSystem:draw(gameState)
    -- Time information in top-right corner
    love.graphics.setColor(1, 1, 1, 0.8)
    local timeString = self:getTimeString(gameState)
    local textWidth = love.graphics.getFont():getWidth(timeString)
    love.graphics.print(timeString, 800 - textWidth - 10, 10)
    
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
    
    -- Draw the arrow based on wind direction
    love.graphics.setColor(0.9, 0.9, 1, 0.8)
    
    -- Calculate arrow endpoint based on direction
    local endX, endY = arrowX, arrowY
    
    if windDir == "North" then
        endX, endY = arrowX, arrowY - arrowLength
    elseif windDir == "South" then
        endX, endY = arrowX, arrowY + arrowLength
    elseif windDir == "East" then
        endX, endY = arrowX + arrowLength, arrowY
    elseif windDir == "West" then
        endX, endY = arrowX - arrowLength, arrowY
    elseif windDir == "Northeast" then
        endX, endY = arrowX + arrowLength*0.7, arrowY - arrowLength*0.7
    elseif windDir == "Northwest" then
        endX, endY = arrowX - arrowLength*0.7, arrowY - arrowLength*0.7
    elseif windDir == "Southeast" then
        endX, endY = arrowX + arrowLength*0.7, arrowY + arrowLength*0.7
    elseif windDir == "Southwest" then
        endX, endY = arrowX - arrowLength*0.7, arrowY + arrowLength*0.7
    end
    
    -- Line
    love.graphics.setLineWidth(2)
    love.graphics.line(arrowX, arrowY, endX, endY)
    
    -- Arrowhead
    local headSize = 5
    local angle = math.atan2(endY - arrowY, endX - arrowX)
    local leftX = endX - headSize * math.cos(angle - math.pi/6)
    local leftY = endY - headSize * math.sin(angle - math.pi/6)
    local rightX = endX - headSize * math.cos(angle + math.pi/6)
    local rightY = endY - headSize * math.sin(angle + math.pi/6)
    
    love.graphics.polygon("fill", endX, endY, leftX, leftY, rightX, rightY)
    love.graphics.setLineWidth(1)
    
    -- If game is over, show end screen
    if gameState.time.isGameOver then
        -- Semi-transparent overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 800, 600)
        
        -- Game over message
        love.graphics.setColor(1, 0.3, 0.3, 1)
        local message = "Game Over - The Earthquake has struck Port Royal!"
        local msgWidth = love.graphics.getFont():getWidth(message)
        love.graphics.print(message, 400 - msgWidth/2, 280)
        
        -- Instructions to restart
        love.graphics.setColor(1, 1, 1, 0.8)
        local restartMsg = "Press 'R' to restart the game"
        local restartWidth = love.graphics.getFont():getWidth(restartMsg)
        love.graphics.print(restartMsg, 400 - restartWidth/2, 320)
    end
end

return TimeSystem```

# Documentation

## docs/GameState.md
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

## docs/Implementation.md
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

## docs/MapZones.md
# Map Zones of Port Royal

## Zone Overview

The Caribbean map in Port Royal is divided into 12 distinct zones, each with its own characteristics and strategic importance. The zones represent different maritime regions in the 17th-century Caribbean, ranging from established colonies to dangerous, mysterious waters.

## Zone Descriptions

### Port Royal
**Description:** The pirate haven and central hub of operations.
**Strategic Value:** As your home port, this is where most business, recruitment, and trading activities take place. The campaign will culminate here with the 1692 earthquake.
**Adjacent Zones:** Calm Waters, Merchants' Route, Nassau

### Calm Waters
**Description:** Peaceful seas with light winds, ideal for new captains.
**Strategic Value:** Safe passage for inexperienced crews, with occasional merchant vessels and minimal threats.
**Adjacent Zones:** Port Royal, Merchants' Route, Stormy Pass

### Merchants' Route
**Description:** Busy trade routes frequent with merchant vessels.
**Strategic Value:** Rich hunting grounds for pirates seeking merchant ships laden with goods, but with increased naval presence.
**Adjacent Zones:** Port Royal, Calm Waters, Navy Waters, Havana

### Nassau
**Description:** A lawless pirate stronghold.
**Strategic Value:** Secondary hub for pirates with access to black market goods and potential crew members with questionable backgrounds.
**Adjacent Zones:** Port Royal, Shark Bay, Cursed Waters

### Stormy Pass
**Description:** Treacherous waters known for sudden storms.
**Strategic Value:** Difficult sailing conditions but a shortcut to northern territories; experienced navigators can pass through more quickly.
**Adjacent Zones:** Calm Waters, Kraken's Reach

### Navy Waters
**Description:** Heavily patrolled by the Royal Navy.
**Strategic Value:** Dangerous for pirates but lucrative for those brave enough to challenge naval vessels with valuable cargo.
**Adjacent Zones:** Merchants' Route, Crown Colony

### Shark Bay
**Description:** Shallow waters home to many sharks.
**Strategic Value:** Rich fishing grounds but risky for swimming and recovery operations; contains hidden reefs with potential for shipwrecks.
**Adjacent Zones:** Nassau, Sunken Graveyard

### Cursed Waters
**Description:** Legends speak of ghost ships here.
**Strategic Value:** Supernatural encounters and rare treasures for those who survive the mysterious dangers.
**Adjacent Zones:** Nassau, Kraken's Reach, Lost Island

### Havana
**Description:** A prosperous Spanish colony.
**Strategic Value:** Wealthy target for raids but heavily defended; offers unique Spanish goods for trading.
**Adjacent Zones:** Merchants' Route, Crown Colony

### Kraken's Reach
**Description:** Deep waters where monsters are said to lurk.
**Strategic Value:** Few dare to sail here, but rumors tell of ancient treasures and artifacts from civilizations long past.
**Adjacent Zones:** Stormy Pass, Cursed Waters

### Crown Colony
**Description:** A well-defended British settlement.
**Strategic Value:** Center of British colonial power with military supplies and potential government contracts for privateers.
**Adjacent Zones:** Navy Waters, Havana

### Sunken Graveyard
**Description:** The final resting place of countless ships.
**Strategic Value:** Rich in salvage opportunities from wrecked ships, but dangerous underwater currents and structures.
**Adjacent Zones:** Shark Bay

### Lost Island
**Description:** A mysterious island appearing on few maps.
**Strategic Value:** Uncharted territory with potential for discovering unique resources, ancient artifacts, or hidden pirate caches.
**Adjacent Zones:** Cursed Waters

## Travel and Wind Effects

Movement between zones is affected by the prevailing wind direction. Sailing with the wind can reduce travel time, while sailing against it increases the journey duration. The strategic captain will plan routes that take advantage of favorable winds to maximize efficiency.

## Zone Development

As the game progresses through development, these zones will gain additional properties including:
- Zone-specific random events
- Special encounters and characters
- Resource gathering opportunities
- Tactical combat scenarios

Each zone will develop a distinct personality that affects gameplay and provides unique strategic opportunities for the aspiring pirate captain.

## docs/TimeSystem.md
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

## docs/WindSystem.md
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

## docs/ZoneSystem.md
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

## ./ComprehensiveDesignDocument.md
Pirate’s Wager: Blood for Gold – Comprehensive Design Document
1. Game Concept Overview
Setting: A pixel-art pirate adventure set in the 17th-century Caribbean, 
centered on Port Royal, culminating in the historical 1692 earthquake as a 
dramatic endgame event.
Core Gameplay: Players captain a pirate ship, juggling tactical naval 
combat and exploration at sea with crew management, investments, and 
faction relationships in Port Royal.
Unique Selling Points:
Dual gameplay loops: tactical combat/exploration at sea and strategic 
management in port.
Dice-based mechanics inspired by Forged in the Dark, emphasizing risk and 
reward.
Hex-grid naval battles for tactical depth.
A 72-week campaign with the earthquake striking randomly between weeks 
60-72, blending urgency with replayability.
A secret ending where players can break a curse and prevent the 
earthquake.
2. Visual Style
Art Direction: Retro pixel art with a limited tile set, layers, and color 
palettes.
Resolution: 800x600 or smaller for a classic aesthetic.
Sea Tiles: Hex-based grid with animated waves indicating wind direction.
Port Phase: Side-view screens for locations (e.g., tavern, shipyard) with 
detailed pixel art and subtle animations (e.g., flickering lanterns, 
swaying palms).
Aesthetic Goals: A gritty yet charming pirate-era Caribbean, balancing 
immersion with clarity in low resolution.
3. Core Gameplay Loops
3.1 At Sea
Exploration:
The Caribbean is split into 10-15 zones (e.g., calm waters, pirate 
territory, naval routes), each with distinct risks and rewards.
Moving between zones or taking major actions (e.g., combat, exploration) 
costs 1 week; movement within a zone (hex-to-hex) is free.
Combat:
Tactical hex-grid battles on a 10x10 hex grid, with ships sized 1-4 hexes 
based on class.
Wind influences movement and combat, varying by sea region (e.g., calm, 
stormy, trade winds).
Actions: Two per turn—one for movement, one for combat/utility:
Fire Cannons: Attack enemies.
Evade: Dodge incoming fire.
Repair: Mend hull damage.
Ram: Deal high-risk hull damage to foes.
Board: Initiate boarding (shifts to side-view combat).
Dice Mechanics: Roll 1-5 d6s based on crew skills, ship stats, and 
context:
6: Success.
4-5: Partial success (e.g., hit with a drawback).
1-3: Failure (e.g., miss or mishap).
Chase Mechanics: If a ship exits the grid, a dice roll decides escape or 
pursuit.
3.2 In Port Royal
Investments (Claims):
Stake resources (gold, items, crew) and time (1-3 weeks) to claim/upgrade 
properties (e.g., taverns, shipyards).
Dice Rolls: Determine outcomes:
Success: Full benefits (e.g., income, perks).
Partial Success: Benefits with complications (e.g., rival attention).
Failure: Lose some resources, gain a minor perk.
Crew Management: Recruit, train, and manage crew with unique roles and 
stats.
Faction Relationships: Build or strain ties with factions (e.g., pirates, 
navy) via actions.
Earthquake Prep Options:
Fortify Investments: Quake-proof properties.
Stockpile Supplies: Hoard resources for recovery.
Evacuation Plans: Prepare to flee with loot and crew.
4. Ship Classes
Players can command three distinct ship classes, each with unique 
characteristics that influence exploration and combat. These classes are 
defined by their size and shape on the hex grid, affecting their speed, 
firepower, durability, and crew capacity.

4.1 Sloop (1-Hex Ship) – "The Swift Sting"
Description: A small, agile vessel favored by daring pirates and 
smugglers. Ideal for hit-and-run tactics and quick escapes.
Hex Size and Shape: 1 hex, compact and highly maneuverable.
Stats:
Speed: 3 hexes per turn (4 with favorable wind)
Firepower: 2 cannons (1 die per attack)
Durability: 10 HP
Crew Capacity: 4 members
Tactical Role: Excels at evasion and precision strikes. Best for players 
who prefer speed and cunning over brute force.
Flavor: A sleek, low-profile ship with patched sails, built for stealth 
and speed.
Customization: Options include adding a harpoon for boarding or extra 
sails for increased speed.
4.2 Brigantine (2-Hex Ship) – "The Rogue’s Balance"
Description: A versatile, mid-sized ship that balances speed and strength. 
Suitable for a wide range of pirate activities.
Hex Size and Shape: 2 hexes in a straight line, sleek and narrow.
Stats:
Speed: 2 hexes per turn (3 with favorable wind)
Firepower: 6 cannons (3 dice per attack)
Durability: 20 HP
Crew Capacity: 8 members
Tactical Role: A jack-of-all-trades ship, capable of raiding, boarding, or 
engaging in sustained combat.
Flavor: A weathered vessel with a history of battles, its deck adorned 
with trophies from past raids.
Customization: Can be outfitted with additional cannons or a reinforced 
hull for durability.
4.3 Galleon (4-Hex Ship – Kite Shape) – "The Crimson Titan"
Description: A massive, heavily armed ship designed for dominance. Its 
kite shape provides a broad profile for devastating broadsides.
Hex Size and Shape: 4 hexes in a kite arrangement (1 hex bow, 2 hexes 
midship, 1 hex stern), wide and imposing.
Stats:
Speed: 1 hex per turn (2 with favorable wind)
Firepower: 12 cannons (6 dice per attack)
Durability: 40 HP
Crew Capacity: 12 members
Tactical Role: A slow but powerful ship that excels in head-on combat and 
intimidation. Requires careful positioning due to its size.
Flavor: An ornate, battle-scarred behemoth, its deck laden with gold and 
gunpowder.
Customization: Options include reinforced plating for extra durability or 
enhanced rigging to improve maneuverability.
4.4 Ship Classes and the Hex Grid
Sloop (1-hex): Highly agile, able to dart through tight spaces and evade 
larger ships. Its small size makes it a difficult target.
Brigantine (2-hex): Balanced maneuverability, able to pivot and reposition 
effectively while maintaining a clear broadside arc.
Galleon (4-hex, kite shape): Slow to turn, requiring strategic use of wind 
and positioning. Its wide midsection allows for powerful broadsides from 
multiple angles but makes navigation in confined areas challenging.
4.5 Progression and Balance
Sloop: High-risk, high-reward gameplay focused on speed and precision.
Brigantine: Versatile and adaptable, suitable for a range of strategies.
Galleon: Emphasizes raw power and resilience, ideal for players who prefer 
overwhelming force.
Upgrades: Players can enhance speed, firepower, or durability within each 
class to suit their playstyle.
5. Mechanics Deep Dive
5.1 Crew System
Crew Roles: Navigator, Gunner, Surgeon, etc., boosting specific actions.
Character Sheet:
Role: Defines specialty.
Skill Level: 1-5, adding dice/bonuses to rolls.
Loyalty: 1-10 (low risks mutiny, high enhances performance).
Influences: Victories (+1), rum (+2), long voyages (-1/week).
Health: Hit points; injuries occur in combat.
Boon/Bane: One positive trait (e.g., “Sharp-Eyed”) and one negative (e.g., 
“Cursed”).
Recruitment: Found in taverns or via quests; elite crew require high 
reputation.
5.2 Item System
Types:
Resources: Bulk goods (e.g., rum, timber) tracked numerically.
Treasures: Unique items (e.g., maps, jewels) taking inventory slots.
Equipment: Gear for crew/ship (e.g., cannons, sails).
Inventory: Ship hold has 10 slots, expandable in port.
Staking: Items/crew committed to actions; failure risks partial loss.
5.3 Reputation System
Factions: Pirates, Merchants, Navy, Locals.
Scale: -3 to +3 per faction.
-3: Hated (e.g., barred from ports).
0: Neutral.
+3: Revered (e.g., exclusive deals).
Shifts: Actions (e.g., raiding) adjust rep by 1-2 points.
Impact: Affects opportunities, crew recruitment, and events.
5.4 Passage of Time
Timeline: 72 weeks, with the earthquake striking randomly between weeks 
60-72.
At Sea: Zone movement or major actions cost 1 week.
In Port: Actions take 1-3 weeks (e.g., 1 for repairs, 2 for investments).
Hints: NPC rumors and tremors escalate as the quake approaches.
5.5 Economic Systems
Trade Routes: Buy low, sell high across ports with dynamic pricing.
Missions: Faction quests (e.g., smuggling for merchants).
Passive Income: Investments yield steady cash or perks.
High-Risk Options: Raiding navy convoys offers rare loot (e.g., unique 
ship parts).
6. Port Phase Details
Presentation: One screen per location (e.g., tavern, shipyard) with 
side-view pixel art and light animations.
Interactions: Click to access functions; occasional mini-events (e.g., bar 
fights, rumors).
Purpose: A streamlined hub for management and prep with flavorful 
immersion.
7. Combat System
Hex Grid: 10x10 hexes; ships sized 1-4 hexes based on class.
Movement: Varies by ship class (see "Ship Classes").
Actions: Two per turn (movement + combat/utility).
Dice Pools: 1-5 d6s for attacks, evasion, etc.
Boarding Actions: Side-view crew combat.
8. Modular Systems
Ship Customization: Hulls, sails, cannons with unique stats (e.g., speed, 
firepower). Each ship class has specific upgrade paths (e.g., sloops can 
add speed, galleons can add durability).
Crew Roles and Traits: Combinatorial depth for management.
Investments: Properties offer stacking perks and interactions.
9. Narrative and Supernatural Elements
Cursed Prophecy: A map reveals the earthquake’s curse, tied to a vengeful 
captain.
Secret Ending: A challenging path to break the curse and stop the quake.
Low Fantasy: Rare supernatural elements (e.g., curses, ghost ships) in 
specific quests/zones.
10. Difficulty and Progression
Scaling Enemies: Navy patrols grow stronger with your reputation.
Event Escalation: Storms and pirate hunters intensify over time.
Win/Loss Conditions:
Win: Survive the quake with a thriving empire or legendary status.
Loss: Lose your ship, crew, or fail to prepare.
11. Strategic Paths
Merchant Focus: Wealth via trade and investments, fortifying the port.
Combat Focus: Raiding and crew dominance to rule the seas.
Balanced Approach: Mix raiding and investing for flexibility.
12. Project Name
Working Title: Pirate’s Wager: Blood for Gold
13. Next Steps
Mock up a Caribbean zone map to test voyage lengths.
Define specific random events and triggers.
Playtest combat for balance and engagement.
Expand crew boon/bane traits for variety.

## ./SprintPlan.md
Total Sprints: 10 (initial plan; adjustable based on progress or 
feedback).
Approach: Agile-inspired, focusing on iterative development, testing, and 
refinement.
Sprint Goals
Deliver functional components incrementally.
Prioritize core gameplay (sea exploration, combat, port management) for 
early playtesting.
Build towards a cohesive pirate adventure with tactical depth and 
strategic management.
Sprint 1: Foundation - Game World and Basic Ship Mechanics
Objective: Establish the game world and basic exploration mechanics.

Tasks:

Create a Caribbean map with 10-15 zones (e.g., calm waters, pirate 
territory) using a hex grid.
Implement basic ship movement:
Moving between zones costs 1 week.
Within-zone hex-to-hex movement is free.
Develop the time management system (72-week campaign).
Add wind direction mechanics affecting movement (e.g., +1 hex with 
favorable wind).
Create placeholder pixel art for sea tiles and ships (Sloop, Brigantine, 
Galleon).
Deliverables:
A navigable Caribbean map with zones and hex grid.
Basic ship movement and time tracking.
Sprint 2: Port Royal and Crew Management
Objective: Build Port Royal as the management hub and introduce crew 
mechanics.

Tasks:

Design Port Royal with key locations (tavern, shipyard) in side-view pixel 
art.
Implement crew recruitment in taverns (basic roles: Navigator, Gunner, 
etc.).
Develop crew management UI (view stats, roles, loyalty).
Set up an inventory system (10 slots for resources/items).
Add basic crew stat impacts (e.g., Navigator adds 1 die to movement 
rolls).
Deliverables:
Functional Port Royal hub with interactive locations.
Basic crew recruitment and management system.
Sprint 3: Combat System - Phase 1
Objective: Introduce core naval combat mechanics.

Tasks:

Create a 10x10 hex-grid battle system.
Implement basic combat actions:
Fire Cannons (attack).
Evade (dodge).
Repair (heal hull).
Develop dice mechanics:
Roll 1-5 d6s based on crew/ship stats.
6 = Success, 4-5 = Partial Success, 1-3 = Failure.
Add simple enemy AI (e.g., moves and fires cannons).
Design combat UI (ship stats, dice results).
Deliverables:
Playable sea combat with dice-based actions.
Basic enemy AI for testing.
Sprint 4: Economic Systems and Investments
Objective: Add trade and investment mechanics for resource management.

Tasks:

Implement trade routes with dynamic pricing across zones.
Develop the investment system:
Stake resources to claim properties (e.g., taverns).
Dice rolls determine outcomes (success = income, failure = loss).
Introduce passive income from investments.
Balance economy for steady progression (e.g., 10-20 gold/week from 
properties).
Add economic UI (track gold, investments).
Deliverables:
Functional trade and investment systems.
Basic economic balance.
Sprint 5: Reputation and Faction System
Objective: Introduce factions and reputation mechanics.

Tasks:

Create four factions (Pirates, Merchants, Navy, Locals) with a -3 to +3 
reputation scale.
Implement reputation shifts based on actions (e.g., raiding lowers Navy 
rep).
Add faction-specific quests (e.g., smuggling for Merchants).
Integrate reputation effects (e.g., +3 Pirates = exclusive crew recruits).
Design faction UI to track relationships.
Deliverables:
Working reputation system with faction interactions.
Initial faction quests.
Sprint 6: Combat System - Phase 2
Objective: Expand combat with boarding and advanced mechanics.

Tasks:

Add advanced actions:
Ram (high-risk hull damage).
Board (triggers side-view crew combat).
Implement crew combat (e.g., dice rolls for melee).
Enhance enemy AI (uses ram/board, adapts to player tactics).
Polish combat UI (animations, sound cues).
Balance combat across ship classes (Sloop = evasion, Galleon = firepower).
Deliverables:
Full combat system with boarding and crew combat.
Improved AI and balance.
Sprint 7: Ship Customization and Upgrades
Objective: Enable ship customization for strategic depth.

Tasks:

Develop customization options:
Sloop: Extra sails (+speed).
Brigantine: More cannons (+firepower).
Galleon: Reinforced hull (+durability).
Implement upgrade system in the shipyard.
Balance upgrades (e.g., speed vs. firepower trade-offs).
Add ship customization UI.
Test ship class distinctions (1-hex Sloop, 4-hex Galleon).
Deliverables:
Functional ship customization system.
Balanced upgrade options.
Sprint 8: Narrative and Quests
Objective: Integrate the main storyline and side quests.

Tasks:

Write and implement the cursed prophecy narrative.
Develop side quests for factions (e.g., retrieve a lost map).
Create NPC dialogue system for quest delivery.
Plan the secret ending (break the curse requirements).
Add narrative triggers (e.g., prophecy hints after week 30).
Deliverables:
Cohesive narrative with main and side quests.
Functional dialogue system.
Sprint 9: Time Management and Events
Objective: Refine time mechanics and add dynamic events.

Tasks:

Finalize the 72-week timeline with earthquake (randomly weeks 60-72).
Implement random events (e.g., storms reduce speed, pirate hunters 
attack).
Add earthquake hints (NPC rumors, tremors from week 50).
Develop prep options: fortify investments, stockpile, evacuate.
Balance event frequency (1-2 per 10 weeks).
Deliverables:
Full time and event systems.
Balanced earthquake mechanics.
Sprint 10: Polish and Optimization
Objective: Refine visuals, performance, and player experience.

Tasks:

Polish pixel art (sea waves, port animations).
Optimize for 800x600 resolution.
Enhance UI/UX (intuitive menus, feedback).
Create a tutorial (cover movement, combat, port actions).
Conduct playtesting and bug fixing.
Deliverables:
Polished, optimized build.
Complete tutorial for new players.
Key Considerations
Dependencies: Sprints build on prior work (e.g., combat expansions need 
Sprint 3). Adjust if blockers arise.
MVP Focus: Sprints 1-3 deliver the core loops (exploration, combat, port 
management) for early testing.
Playtesting: Test after each sprint to validate mechanics and gather 
feedback. Focus on fun and balance.
Flexibility: If time is tight, delay advanced features (e.g., crew traits, 
supernatural elements) for post-Sprint 10 iterations.
Next Steps Beyond Sprint 10
Crew Depth: Add boons/banes (e.g., “Sharp-Eyed” vs. “Cursed”) and loyalty 
mechanics.
Economic Risks: Introduce high-stakes options like raiding navy convoys.
Supernatural: Add low-fantasy quests (e.g., ghost ships).
Endgame: Polish the earthquake and secret ending for replayability.

## ./TicketStrategy.md
To complete Tickets for this project, work together with me to follow 
these steps:

1. Open the relevant `0x-0x-description.md` file.

2. Carefully read the Description at the top of the file to understand 
the goal for the task.

3. Complete each component Task that follows the description in 
order. If the task is ambiguous, you may wish to create a plan and submit 
it to me for approval or workshopping first.

4. Ensure that each of the Acceptance Criteria is fulfilled. If it is 
difficult to tell whether a criterion has been met successfully, check 
with me.

5. Append a newline with a cat emoji followed by a zzz "snoozing" emoji 
to the end of the file.

Strategy Notes:

* Consider me your partner in completing each Task. Solve issues 
independently when you can do so confidently, but please avail yourself 
of my input as often as you like - I have a very clear product vision in 
terms of final UX, and a solid understanding of the technical side, with 
a background as an IC backend software developer for nearly a decade.

* I am taking full advantage of your superpowers: your strong coding 
and organizational ability, tirelessness, and general cross-domain 
capability. Take advantage of my superpowers too: often-complimented 
taste, clearly defined product vision, and strong ability to understand 
the user-side of experiences at both a high level and a very granular 
level - I used to work quite successfully on designing puzzles in escape 
rooms. The boundary will be extremely permeable, but I'm closest to a 
project manager here, where you are closest to a lead programmer. I am 
counting on you to ask me lots of questions and rely on my feedback to 
bring my vision to life. Don't let that stop you from making creative 
suggestions when they spark for you, though, I love to hear ideas :)

* This document includes a list of Known Weaknesses below, these are areas 
of development where either you or I have struggled in the past. When 
these elements are in play, bias towards working more closely with me so 
we can check each others' logic and validate each others' 
implementations.

Known Weaknesses:

* It is difficult for you to "see" visuals in our game's style - the 
low-res retro imagery seems to be difficult for you to parse. Rely on me 
to check whether everything looks the way it should.

* In prototyping, the clarity of the combat UI was the biggest pain point 
for testers. Our low-res style demands special attention to readability, 
which we should consider when designing display elements. Refer back to 
the canon of games for the Game Boy and Game Boy Advance, such as 
Pokemon, Fire Emblem, and Golden Sun for inspiration on how to work around low-resolution in our layouts. 

## ./codebase_dump.md

## Tickets/1-1-create-world-map.md
Ticket 1: Create Caribbean Map with Zones
Description: Develop a Caribbean map divided into 10-15 distinct, 
irregular zones (e.g., "Calm Waters," "Pirate Territory"). Each zone is a 
clickable area on a non-hex-based global map.
Tasks:
Design a visual layout of the Caribbean with 10-15 zones, ensuring each 
has a unique shape and name.
Implement interactive zone areas that highlight on mouse-over and respond 
to clicks.
Create a tooltip system displaying zone name, basic info, and time cost to 
sail there (e.g., "Calm Waters - 1 week").
Define zone adjacencies in a data structure (e.g., a graph) for movement 
logic.
Acceptance Criteria:
The map shows 10-15 zones with distinct boundaries and names.
Mouseing over a zone highlights it and displays a tooltip with name and 
time cost.
Clicking an adjacent zone triggers movement (handled in Ticket 2).
Notes:
Zones should be large enough for easy clicking.
For Sprint 1, assume a uniform 1-week cost per transition; variable costs 
(e.g., based on distance) can be added later.
No hex grid on the global map; keep it abstract.

🐱💤

## Tickets/1-2-implement-basic-ship-travel.md
Ticket 2: Implement Basic Ship Movement Mechanics
Description: Enable the player's ship to move between adjacent zones on 
the global map, with each transition costing 1 week.
Tasks:
Implement a system to track the ship's current zone.
Allow clicking an adjacent zone to initiate movement, advancing time by 1 
week.
Update the ship's position to the new zone upon transition.
Acceptance Criteria:
The player can click an adjacent zone to move the ship there.
Each move between zones increases the week counter by 1 (ties to Ticket 
3).
The ship's new position is reflected on the global map.
Notes:
For Sprint 1, no within-zone movement or hex grids; the ship is simply 
"in" a zone.
Future sprints could add within-zone hex grids if desired.

🐱💤

## Tickets/1-3-implement-basic-time-management.md
Ticket 3: Develop Time Management System
Description: Create a system to track time across the 72-week campaign, 
tied to zone transitions.
Tasks:
Initialize a week counter at 1.
Increment the counter by 1 per zone transition.
Display the current week in the UI.
Acceptance Criteria:
The week counter updates correctly with each zone move.
The current week is visible in the game interface.
The system supports up to 72 weeks.
Notes:
Keep it extensible for future actions (e.g., exploration, combat) that 
might cost time.

🐱💤

## Tickets/1-4-add-wind-mechanic.md
Ticket 4: Add Wind Direction Mechanics (Simplified for Sprint 1)
Description: Introduce a basic wind direction affecting zone transitions, 
with visual indicators.
Tasks:
Assign a fixed wind direction per zone (e.g., North, South).
Adjust time costs slightly based on wind (e.g., +1 week against wind, -1 
day with wind, minimum 1 week).
Show wind direction in the tooltip or UI.
Acceptance Criteria:
Wind direction influences zone transition time (e.g., "Calm Waters - 2 
weeks against wind").
Players can see the wind effect in the tooltip or UI.
Notes:
Keep it simple for Sprint 1; no hex-level wind effects since the global 
map isn't hex-based.
Refine in later sprints when within-zone mechanics are added.

🐱💤

## Tickets/1-5-add-placeholder-art.md
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

