# PortRoyal Codebase Dump
Generated: Wed Mar 26 23:42:26 CDT 2025

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
    
    -- Inventory system (10 slots for cargo and special items)
    inventory = {
        slots = {}          -- Will contain inventory slot objects
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = 5,         -- Scale 1-10
        
        -- Global crew pool - tracks all possible crew members in the game
        -- Each crew member has a unique ID
        pool = {},
        
        -- Tracks which crew are available at each location
        -- Key is location name, value is table of crew IDs
        availableByLocation = {}
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
        debug = false,  -- Set to false for normal gameplay, true for debugging
        portMode = false,  -- When true, display port/location interface instead of map
        currentPortScreen = "main",  -- Which port screen to display: main, tavern, shipyard, crew, inventory
        
        -- Ship state flags
        moored = false  -- When true, ship is docked at a location rather than at sea
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
    
    -- Initialize the crew pool
    self:initializeCrewPool()
    
    -- Distribute crew members to locations
    self:distributeCrewToLocations()
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        id = "captain",
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

-- Initialize the pool of potential crew members
function GameState:initializeCrewPool()
    self.crew.pool = {
        {
            id = "js001",
            name = "Jack Sparrow",
            role = "Navigator",
            skill = 3,
            loyalty = 4,
            health = 8,
            cost = 25
        },
        {
            id = "ab002",
            name = "Anne Bonny",
            role = "Gunner",
            skill = 2,
            loyalty = 3,
            health = 7,
            cost = 20
        },
        {
            id = "dh003",
            name = "Doc Holliday",
            role = "Surgeon",
            skill = 2,
            loyalty = 5,
            health = 6,
            cost = 15
        },
        {
            id = "bb004",
            name = "Blackbeard",
            role = "Gunner",
            skill = 3,
            loyalty = 2,
            health = 9,
            cost = 30
        },
        {
            id = "hm005",
            name = "Henry Morgan",
            role = "Navigator",
            skill = 2,
            loyalty = 4,
            health = 7,
            cost = 22
        },
        {
            id = "sp006",
            name = "Samuel Porter",
            role = "Surgeon",
            skill = 3,
            loyalty = 3,
            health = 5,
            cost = 18
        },
        {
            id = "wb007",
            name = "William Bones",
            role = "Gunner",
            skill = 2,
            loyalty = 5,
            health = 6,
            cost = 20
        },
        {
            id = "gr008",
            name = "Grace O'Malley",
            role = "Navigator",
            skill = 3,
            loyalty = 3,
            health = 7,
            cost = 24
        },
        {
            id = "jf009",
            name = "James Fletcher",
            role = "Surgeon",
            skill = 1,
            loyalty = 4,
            health = 8,
            cost = 12
        }
    }
end

-- Distribute crew members to different ports
function GameState:distributeCrewToLocations()
    -- Initialize location tables
    self.crew.availableByLocation = {
        ["Port Royal"] = {},
        ["Nassau"] = {},
        ["Havana"] = {},
        ["Crown Colony"] = {}
    }
    
    -- Helper function to check if a crew member is already in a location
    local function isInAnyLocation(crewId)
        for _, locationCrew in pairs(self.crew.availableByLocation) do
            for _, id in ipairs(locationCrew) do
                if id == crewId then
                    return true
                end
            end
        end
        return false
    end
    
    -- Helper function to get a crew member by role from pool
    local function getCrewByRole(role)
        local candidates = {}
        for _, crew in ipairs(self.crew.pool) do
            if crew.role == role and not isInAnyLocation(crew.id) then
                table.insert(candidates, crew)
            end
        end
        
        if #candidates > 0 then
            local selected = candidates[math.random(#candidates)]
            return selected.id
        end
        return nil
    end
    
    -- Assign crew by role patterns to each location
    -- Port Royal: 1 of each role (Navigator, Gunner, Surgeon)
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Surgeon"))
    
    -- Nassau: 2 Gunners, 1 Navigator
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Navigator"))
    
    -- Havana: 2 Navigators, 1 Surgeon
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Surgeon"))
    
    -- Crown Colony: 1 Surgeon, 1 Gunner, 1 Navigator
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Surgeon"))
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Navigator"))
    
    -- Remove nil entries (if we ran out of crew)
    for location, crewList in pairs(self.crew.availableByLocation) do
        for i = #crewList, 1, -1 do
            if not crewList[i] then
                table.remove(crewList, i)
            end
        end
    end
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
    
    -- Reset interface modes
    self.settings.portMode = false
    self.settings.currentPortScreen = "main"
    self.settings.moored = false
    
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
    
    -- Reset inventory
    self.inventory.slots = {}
    for i = 1, 10 do
        self.inventory.slots[i] = {
            item = nil,
            quantity = 0
        }
    end
    
    -- Reset crew
    self.crew.members = {}
    self.crew.morale = 5
    
    -- Reinitialize the crew pool and distribution
    self:initializeCrewPool()
    self:distributeCrewToLocations()
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        id = "captain",
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

-- Calculate travel time between zones based on wind and crew
function GameState:calculateTravelTime(fromZoneIdx, toZoneIdx, map)
    -- Base travel time is always 1 week
    local baseTravelTime = 1
    
    -- If either zone is invalid, just return base time
    if not fromZoneIdx or not toZoneIdx or 
       fromZoneIdx > #map.zones or toZoneIdx > #map.zones then
        return baseTravelTime, "normal"
    end
    
    -- Debug info for travel calculation
    if self.settings.debug then
        print("Calculating travel time from zone " .. fromZoneIdx .. " to zone " .. toZoneIdx)
        print("Current wind direction: " .. self.environment.wind.currentDirection)
    end
    
    -- Check for Navigator in crew (Ticket 2-6)
    local hasNavigator = false
    for _, crewMember in ipairs(self.crew.members) do
        if crewMember.role == "Navigator" then
            hasNavigator = true
            if self.settings.debug then
                print("Navigator found in crew: " .. crewMember.name)
            end
            break
        end
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
    
    -- Apply the wind modifier 
    local travelTime = baseTravelTime + windModifier
    
    -- Apply navigator modifier if present
    local navigatorEffect = ""
    if hasNavigator then
        travelTime = travelTime - 0.5
        navigatorEffect = " with Navigator"
        if self.settings.debug then
            print("Navigator reducing travel time by 0.5 weeks")
        end
    end
    
    -- Ensure minimum 0.5 week travel time
    travelTime = math.max(0.5, travelTime)
    
    -- Create wind effect description
    local windEffect = ""
    if windModifier > 0 then
        windEffect = "against wind"
    elseif windModifier < 0 then
        windEffect = "with wind"
    else
        windEffect = "crosswind"
    end
    
    -- Combine wind and navigator effects
    local totalEffect = windEffect
    if hasNavigator then
        totalEffect = totalEffect .. navigatorEffect
    end
    
    if self.settings.debug then
        print("Wind direction: " .. windDirection)
        print("Wind modifier: " .. windModifier)
        print("Navigator effect: " .. (hasNavigator and "-0.5 weeks" or "none"))
        print("Final travel time: " .. travelTime .. " weeks")
        print("Total effect: " .. totalEffect)
    end
    
    return travelTime, totalEffect
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

-- Get crew member from ID
function GameState:getCrewMemberById(id)
    for _, member in ipairs(self.crew.pool) do
        if member.id == id then
            return member
        end
    end
    return nil
end

-- Get available crew at a location
function GameState:getAvailableCrewAtLocation(locationName)
    local result = {}
    
    -- Check if we have crew listed for this location
    if not self.crew.availableByLocation[locationName] then
        return result
    end
    
    -- Get crew IDs at this location
    local crewIds = self.crew.availableByLocation[locationName]
    
    -- Convert IDs to full crew member data
    for _, id in ipairs(crewIds) do
        local member = self:getCrewMemberById(id)
        if member then
            table.insert(result, member)
        end
    end
    
    return result
end

-- Remove a crew member from a location (e.g., when hired)
function GameState:removeCrewFromLocation(crewId, locationName)
    if not self.crew.availableByLocation[locationName] then
        return false
    end
    
    for i, id in ipairs(self.crew.availableByLocation[locationName]) do
        if id == crewId then
            table.remove(self.crew.availableByLocation[locationName], i)
            return true
        end
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
local portRoyal = require('portRoyal')

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
    portRoyal:load(gameState)   -- Initialize Port Royal interface
    
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
    if gameState.settings.portMode then
        -- Update port interface
        portRoyal:update(dt, gameState)
    else
        -- Update map and ship
        gameMap:update(dt, gameState)
        playerShip:update(dt, gameState, gameMap)
    end
    
    -- Always update time system
    timeSystem:update(dt, gameState)
    
    -- Handle game restart
    if gameState.time.isGameOver and love.keyboard.isDown('r') then
        gameState:reset()  -- Reset all game state
        timeSystem:load(gameState)  -- Reinitialize systems
        gameMap:load(gameState)
        playerShip:load(gameState, gameMap)
        portRoyal:load(gameState)
    end
end

function love.draw()
    -- Render game based on current mode
    if gameState.settings.portMode then
        -- Draw port interface
        portRoyal:draw(gameState)
    else
        -- Draw map and ship
        gameMap:draw(gameState)
        playerShip:draw(gameState)
    end
    
    -- Always draw time system
    timeSystem:draw(gameState)
    
    -- Display fps in debug mode
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end
end

function love.mousemoved(x, y)
    if gameState.settings.portMode then
        portRoyal:mousemoved(x, y, gameState)
    else
        gameMap:mousemoved(x, y, gameState)
    end
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    
    if gameState.settings.portMode then
        portRoyal:mousepressed(x, y, button, gameState)
    else
        gameMap:mousepressed(x, y, button, gameState)
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- If in port mode, return to map
        if gameState.settings.portMode then
            gameState.settings.portMode = false
            gameState.settings.currentPortScreen = "main"
        else
            love.event.quit()
        end
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

return Map```

## src/portRoyal.lua
```lua
-- Port Interface Module
-- Currently focused on Port Royal but can be extended to all locations

local PortRoyal = {
    -- UI constants
    width = 800,
    height = 600,
    
    -- UI elements
    buttons = {},
    
    -- Placeholder art
    backgrounds = {
        main = nil,
        tavern = nil,
        shipyard = nil
    },
    
    -- Currently displayed crew (loaded dynamically based on location)
    availableCrew = {},
    
    -- Tavern status indicators
    tavernMessage = nil,
    tavernMessageTimer = 0,
}

-- Initialize Port interface
function PortRoyal:load(gameState)
    -- Main screen buttons will be generated dynamically based on location
    self.buttons.main = {}
    
    -- Initialize buttons for tavern screen (just the back button initially)
    self.buttons.tavern = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() 
                gameState.settings.currentPortScreen = "main" 
                -- Clear crew list when leaving tavern
                self.availableCrew = {}
            end
        }
    }
    
    -- Initialize buttons for shipyard screen
    self.buttons.shipyard = {
        {
            text = "Repair Ship",
            x = 325,
            y = 300,
            width = 150,
            height = 50,
            action = function() 
                -- For now, just display a message that repairs aren't available yet
                print("Ship repairs not yet implemented")
                self.shipyardMessage = "Ship repairs will be available in a future update."
                self.shipyardMessageTimer = 3  -- Show message for 3 seconds
            end
        },
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Variables for shipyard message display
    self.shipyardMessage = nil
    self.shipyardMessageTimer = 0
    
    -- Initialize buttons for crew screen
    self.buttons.crew = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Initialize buttons for inventory screen
    self.buttons.inventory = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Load placeholder background images if available
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port_royal_main.png")
    end)
    if success then
        self.backgrounds.main = result
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-tavern.png")
    end)
    if success then
        self.backgrounds.tavern = result
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-shipyard.png")
    end)
    if success then
        self.backgrounds.shipyard = result
        print("Port Royal shipyard background loaded")
    end
end

-- Update Port interface
function PortRoyal:update(dt, gameState)
    -- Generate location-specific buttons if needed
    self:generateLocationButtons(gameState)
    
    -- Load crew members for the current location if entering tavern
    local currentScreen = gameState.settings.currentPortScreen
    if currentScreen == "tavern" and #self.availableCrew == 0 then
        self:loadAvailableCrewForLocation(gameState)
    end
    
    -- Check if we need to reload any assets
    if not self.backgrounds.tavern then
        -- Try to load tavern background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-tavern.png")
        end)
        if success then
            self.backgrounds.tavern = result
            print("Port Royal tavern background loaded during update")
        end
    end
    
    if not self.backgrounds.shipyard then
        -- Try to load shipyard background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-shipyard.png")
        end)
        if success then
            self.backgrounds.shipyard = result
            print("Port Royal shipyard background loaded during update")
        end
    end
    
    -- Update shipyard message timer
    if self.shipyardMessage and self.shipyardMessageTimer > 0 then
        self.shipyardMessageTimer = self.shipyardMessageTimer - dt
        if self.shipyardMessageTimer <= 0 then
            self.shipyardMessage = nil
        end
    end
    
    -- Update tavern message timer
    if self.tavernMessage and self.tavernMessageTimer > 0 then
        self.tavernMessageTimer = self.tavernMessageTimer - dt
        if self.tavernMessageTimer <= 0 then
            self.tavernMessage = nil
        end
    end
end

-- Load crew members available at the current location
function PortRoyal:loadAvailableCrewForLocation(gameState)
    -- Clear current list
    self.availableCrew = {}
    
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
            
            -- Get available crew at this location
            self.availableCrew = gameState:getAvailableCrewAtLocation(currentZoneName)
            
            -- Update the tavern buttons for these crew members
            self:updateTavernButtons(gameState, currentZoneName)
        end
    end
end

-- Update the tavern buttons for the available crew members
function PortRoyal:updateTavernButtons(gameState, locationName)
    -- Keep the back button (it should be the last button)
    local backButton = self.buttons.tavern[#self.buttons.tavern]
    
    -- Clear all other buttons
    self.buttons.tavern = {}
    
    -- Add hire buttons for each available crew member
    for i, crew in ipairs(self.availableCrew) do
        table.insert(self.buttons.tavern, {
            text = "Hire for " .. crew.cost .. " gold",
            x = 500,
            y = 190 + (i-1) * 100 + 20,
            width = 200,
            height = 40,
            crewId = crew.id,  -- Store crew ID for hiring
            action = function()
                -- Check if can afford the crew member
                if not gameState:canAfford("gold", crew.cost) then
                    self.tavernMessage = "Not enough gold to hire " .. crew.name
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Check if crew is full
                if #gameState.crew.members >= gameState.ship.crewCapacity then
                    self.tavernMessage = "Ship crew capacity reached"
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Hire the crew member
                gameState:spendResources("gold", crew.cost)
                
                -- Create a copy of the crew member to add to the player's crew
                local newCrewMember = {
                    id = crew.id,
                    name = crew.name,
                    role = crew.role,
                    skill = crew.skill,
                    loyalty = crew.loyalty,
                    health = crew.health
                }
                
                -- Add to player's crew
                gameState:addCrewMember(newCrewMember)
                
                -- Remove from location
                gameState:removeCrewFromLocation(crew.id, locationName)
                
                -- Success message
                self.tavernMessage = crew.name .. " hired successfully!"
                self.tavernMessageTimer = 3
                
                -- Update available crew and buttons
                self.availableCrew = gameState:getAvailableCrewAtLocation(locationName)
                self:updateTavernButtons(gameState, locationName)
            end
        })
    end
    
    -- Add back button
    table.insert(self.buttons.tavern, backButton)
end

-- Generate buttons based on the current location
function PortRoyal:generateLocationButtons(gameState)
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Clear existing buttons
    self.buttons.main = {}
    
    -- Generate basic "Set Sail" button for all locations
    table.insert(self.buttons.main, {
        text = "Set Sail",
        x = 325,
        y = 400,
        width = 150,
        height = 50,
        action = function() 
            gameState.settings.portMode = false 
            gameState.settings.moored = false
            print("Setting sail from " .. currentZoneName)
        end
    })
    
    -- Add location-specific buttons
    if currentZoneName == "Port Royal" then
        -- Port Royal has the full set of options
        table.insert(self.buttons.main, {
            text = "Tavern",
            x = 200,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 200,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 450,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 450,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    elseif currentZoneName == "Nassau" then
        -- Nassau has a tavern and crew management
        table.insert(self.buttons.main, {
            text = "Pirate Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
    elseif currentZoneName == "Havana" then
        -- Havana has a tavern and shipyard
        table.insert(self.buttons.main, {
            text = "Spanish Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
    elseif currentZoneName == "Crown Colony" then
        -- Crown Colony has a shipyard and inventory
        table.insert(self.buttons.main, {
            text = "Royal Shipyard",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    end
    
    -- For all locations, ensure "Set Sail" is at the bottom
    if #self.buttons.main > 0 then
        for i, button in ipairs(self.buttons.main) do
            if button.text == "Set Sail" then
                button.y = 400  -- Position at bottom
            end
        end
    end
end

-- Draw Port interface
function PortRoyal:draw(gameState)
    -- Get current screen and location
    local currentScreen = gameState.settings.currentPortScreen
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up the current zone name
    if currentZoneIndex and currentZoneIndex > 0 then
        -- Get the Map module to look up zone name
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Draw background based on current screen
    self:drawBackground(currentScreen)
    
    -- Draw gold amount
    love.graphics.setColor(1, 0.9, 0.2, 1)  -- Gold color
    love.graphics.print("Gold: " .. gameState.resources.gold, 10, 10)
    
    -- Draw screen-specific content
    if currentScreen == "main" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(currentZoneName .. " Harbor", 0, 100, self.width, "center")
        
        -- Draw ship name and class
        love.graphics.printf("Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 130, self.width, "center")
        
        -- Draw location-specific welcome message
        local welcomeMessage = "Welcome to port. What would you like to do?"
        
        if currentZoneName == "Port Royal" then
            welcomeMessage = "Welcome to Port Royal, the pirate haven of the Caribbean."
        elseif currentZoneName == "Nassau" then
            welcomeMessage = "Welcome to Nassau, the lawless pirate stronghold."
        elseif currentZoneName == "Havana" then
            welcomeMessage = "Welcome to Havana, the jewel of Spanish colonies."
        elseif currentZoneName == "Crown Colony" then
            welcomeMessage = "Welcome to the Crown Colony, an outpost of British influence."
        elseif currentZoneName:find("Waters") then
            welcomeMessage = "Your ship is anchored in open waters. Not much to do here."
        elseif currentZoneName:find("Bay") or currentZoneName:find("Reach") then
            welcomeMessage = "You've moored at a secluded spot with no settlements."
        end
        
        love.graphics.setColor(1, 0.95, 0.8, 1)  -- Light cream color
        love.graphics.printf(welcomeMessage, 50, 160, self.width - 100, "center")
        
        -- Draw buttons for main screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "tavern" then
        -- Get current location for tavern name
        local currentZoneIndex = gameState.ship.currentZone
        local tavernName = "The Rusty Anchor Tavern"
        local tavernDescription = "The tavern is filled with sailors, merchants, and pirates.\nHere you can recruit crew members and hear rumors."
        
        -- Set location-specific tavern names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Nassau" then
                    tavernName = "The Black Flag Tavern"
                    tavernDescription = "A rowdy establishment frequented by pirates.\nRecruit dangerous but skilled crew members here."
                elseif zone.name == "Havana" then
                    tavernName = "La Cantina del Rey"
                    tavernDescription = "An elegant Spanish tavern with fine wines.\nHear rumors about Spanish treasure fleets here."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tavernName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.tavern then
            love.graphics.printf(tavernDescription, 0, 120, self.width, "center")
        end
        
        -- Draw available crew for hire
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Available Crew for Hire:", 0, 160, self.width, "center")
        
        -- Draw table header
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print("Name", 100, 190)
        love.graphics.print("Role", 250, 190)
        love.graphics.print("Stats", 350, 190)
        
        -- Draw available crew members
        for i, crew in ipairs(self.availableCrew) do
            local yPos = 190 + (i-1) * 100  -- Increased vertical spacing
            
            -- Background panel for each crew member (including hire button area)
            love.graphics.setColor(0.2, 0.2, 0.3, 0.6)
            love.graphics.rectangle("fill", 90, yPos, 620, 80)
            love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
            love.graphics.rectangle("line", 90, yPos, 620, 80)
            
            -- Display crew info
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(crew.name, 100, yPos + 10)
            
            -- Color code the role to match the crew management screen
            if crew.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            elseif crew.role == "Gunner" then
                love.graphics.setColor(1, 0.7, 0.7, 1)  -- Red for gunners
            elseif crew.role == "Surgeon" then
                love.graphics.setColor(0.7, 0.7, 1, 1)  -- Blue for surgeons
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(crew.role, 250, yPos + 10)
            
            -- Display crew stats
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print("Skill: " .. crew.skill, 350, yPos + 10)
            love.graphics.print("Loyalty: " .. crew.loyalty, 350, yPos + 30)
            love.graphics.print("Health: " .. crew.health, 350, yPos + 50)
            
            -- Display hire cost
            love.graphics.setColor(1, 0.9, 0.2, 1)
            love.graphics.print("Cost: " .. crew.cost .. " gold", 100, yPos + 50)
            
            -- Draw integrated hire button (right side of panel)
            love.graphics.setColor(0.3, 0.5, 0.7, 0.9)
            love.graphics.rectangle("fill", 500, yPos + 20, 200, 40)
            love.graphics.setColor(0.5, 0.7, 0.9, 1)
            love.graphics.rectangle("line", 500, yPos + 20, 200, 40)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Hire for " .. crew.cost .. " gold", 500, yPos + 33, 200, "center")
        end
        
        -- Show player's current gold
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.printf("Your gold: " .. gameState.resources.gold, 0, 440, self.width, "center")
        
        -- Display crew capacity
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Ship Crew: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 470, self.width, "center")
        
        -- Display tavern message if active
        if self.tavernMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.tavernMessage, 150, 390, 500, "center")
        end
        
        -- Draw buttons for tavern screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "shipyard" then
        -- Get current location for shipyard name
        local currentZoneIndex = gameState.ship.currentZone
        local shipyardName = "Port Royal Shipyard"
        local shipyardDescription = "The shipyard is busy with workers repairing vessels.\nHere you can upgrade your ship or purchase a new one."
        
        -- Set location-specific shipyard names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Havana" then
                    shipyardName = "Havana Naval Yards"
                    shipyardDescription = "A Spanish shipyard specializing in galleons.\nSpanish vessels are sturdy but more expensive."
                elseif zone.name == "Crown Colony" then
                    shipyardName = "Royal Navy Dockyard"
                    shipyardDescription = "A military shipyard with British vessels.\nStrict regulations, but high-quality ships available."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(shipyardName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.shipyard then
            love.graphics.printf(shipyardDescription, 0, 150, self.width, "center")
        end
        
        -- Draw current ship status
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.printf("Current Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 220, self.width, "center")
        love.graphics.printf("Hull Durability: " .. gameState.ship.durability .. "/10", 0, 250, self.width, "center")
        
        -- Draw shipyard message if active
        if self.shipyardMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.shipyardMessage, 150, 390, 500, "center")
        end
        
        -- Draw buttons for shipyard screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "crew" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Crew Management", 0, 70, self.width, "center")
        
        -- Draw crew info
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Crew Size: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 110, self.width, "center")
        love.graphics.printf("Crew Morale: " .. gameState.crew.morale .. "/10", 0, 140, self.width, "center")
        
        -- Draw crew table headers
        love.graphics.setColor(1, 0.9, 0.7, 1)
        love.graphics.print("Name", 130, 180)
        love.graphics.print("Role", 300, 180)
        love.graphics.print("Skill", 450, 180)
        love.graphics.print("Loyalty", 520, 180)
        love.graphics.print("Health", 600, 180)
        
        -- Draw table separator
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.line(120, 200, 680, 200)
        
        -- List crew members with stats in a table format
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        local yPos = 210
        for i, member in ipairs(gameState.crew.members) do
            -- Highlight navigator role for ticket 2-6 visibility
            if member.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(member.name, 130, yPos)
            love.graphics.print(member.role, 300, yPos)
            love.graphics.print(member.skill or 1, 450, yPos)
            love.graphics.print(member.loyalty or 5, 520, yPos)
            love.graphics.print(member.health or 10, 600, yPos)
            
            -- Draw separator between crew members
            love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            
            yPos = yPos + 40
        end
        
        -- Draw empty slots if not at capacity
        for i = #gameState.crew.members + 1, gameState.ship.crewCapacity do
            love.graphics.setColor(0.4, 0.4, 0.5, 0.5)
            love.graphics.print("Empty slot", 130, yPos)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            yPos = yPos + 40
        end
        
        -- Draw role effects information
        love.graphics.setColor(0.9, 0.8, 0.6, 1)
        love.graphics.printf("Crew Role Effects:", 150, 400, 500, "center")
        
        love.graphics.setColor(0.7, 1, 0.7, 1)
        love.graphics.printf("Navigator: Reduces travel time between zones by 0.5 weeks", 150, 430, 500, "center")
        
        -- Draw buttons for crew screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "inventory" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Inventory", 0, 70, self.width, "center")
        
        -- Draw resources section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Resources:", 100, 120, 200, "left")
        
        -- Draw resources
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print("Gold: " .. gameState.resources.gold, 120, 150)
        love.graphics.print("Rum: " .. gameState.resources.rum, 120, 180)
        love.graphics.print("Timber: " .. gameState.resources.timber, 120, 210)
        love.graphics.print("Gunpowder: " .. gameState.resources.gunpowder, 120, 240)
        
        -- Draw cargo slots section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Cargo Slots:", 400, 120, 200, "left")
        
        -- Draw cargo slots (10 slots)
        local slotSize = 50
        local startX = 400
        local startY = 150
        local cols = 5
        
        for i = 1, 10 do
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            local x = startX + col * (slotSize + 10)
            local y = startY + row * (slotSize + 10)
            
            -- Draw slot background
            love.graphics.setColor(0.2, 0.2, 0.3, 1)
            love.graphics.rectangle("fill", x, y, slotSize, slotSize)
            
            -- Draw slot border
            love.graphics.setColor(0.4, 0.4, 0.5, 1)
            love.graphics.rectangle("line", x, y, slotSize, slotSize)
            
            -- Draw slot content if any
            local slot = gameState.inventory.slots[i]
            if slot and slot.item then
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
                love.graphics.printf(slot.item, x, y + 10, slotSize, "center")
                love.graphics.printf(slot.quantity, x, y + 30, slotSize, "center")
            else
                -- Draw empty slot number
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                love.graphics.printf(i, x + 15, y + 15, 20, "center")
            end
        end
        
        -- Debug button for adding resources (if debug mode enabled)
        if gameState.settings.debug then
            love.graphics.setColor(0.3, 0.6, 0.3, 1)
            love.graphics.rectangle("fill", 120, 270, 150, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("+ 10 of each resource", 120, 275, 150, "center")
        end
        
        -- Draw buttons for inventory screen
        self:drawButtons(currentScreen)
    end
end

-- Helper function to draw background
function PortRoyal:drawBackground(screen)
    -- Set color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Get current location
    local currentZoneIndex = nil
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if _G.gameState and _G.gameState.ship then
        currentZoneIndex = _G.gameState.ship.currentZone
    end
    
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Try to load location-specific background if available
    local locationKey = currentZoneName:lower():gsub("%s+", "_")
    local locationBackground = nil
    
    if screen == "main" then
        local success, result = pcall(function()
            return love.graphics.newImage("assets/" .. locationKey .. "_main.png")
        end)
        if success then
            locationBackground = result
        end
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        love.graphics.draw(locationBackground, 0, 0)
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        love.graphics.draw(self.backgrounds.main, 0, 0)
    elseif screen == "tavern" and self.backgrounds.tavern then
        love.graphics.draw(self.backgrounds.tavern, 0, 0)
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        love.graphics.draw(self.backgrounds.shipyard, 0, 0)
    else
        -- Draw a fallback colored background
        if screen == "main" then
            -- Based on zone type (could become more sophisticated)
            if currentZoneName == "Port Royal" then
                love.graphics.setColor(0.2, 0.3, 0.5, 1)  -- Deep blue for Port Royal
            elseif currentZoneName:find("Waters") then
                love.graphics.setColor(0.2, 0.4, 0.5, 1)  -- Different blue for waters
            elseif currentZoneName == "Nassau" or currentZoneName == "Havana" then
                love.graphics.setColor(0.5, 0.3, 0.2, 1)  -- Brown for settlements
            else
                love.graphics.setColor(0.3, 0.3, 0.4, 1)  -- Default color
            end
        elseif screen == "tavern" then
            love.graphics.setColor(0.3, 0.2, 0.1, 1)  -- Brown for tavern
        elseif screen == "shipyard" then
            love.graphics.setColor(0.4, 0.4, 0.5, 1)  -- Grey for shipyard
        elseif screen == "crew" then
            love.graphics.setColor(0.2, 0.3, 0.4, 1)  -- Navy for crew
        elseif screen == "inventory" then
            love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Grey for inventory
        end
        
        -- Fill background
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
end

-- Helper function to draw buttons
function PortRoyal:drawButtons(screen)
    -- Only draw buttons for the current screen
    if not self.buttons[screen] then
        return
    end
    
    -- Position the "Back to Port" button at the bottom for non-main screens
    if screen ~= "main" and #self.buttons[screen] == 1 and 
       self.buttons[screen][1].text == "Back to Port" then
        self.buttons[screen][1].y = 520
    end
    
    for _, button in ipairs(self.buttons[screen]) do
        -- Draw button background
        love.graphics.setColor(0.4, 0.4, 0.6, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button border
        love.graphics.setColor(0.6, 0.6, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(button.text)
        local textHeight = font:getHeight()
        love.graphics.print(
            button.text,
            button.x + (button.width/2) - (textWidth/2),
            button.y + (button.height/2) - (textHeight/2)
        )
    end
end

-- Handle mouse movement
function PortRoyal:mousemoved(x, y, gameState)
    -- Could implement hover effects for buttons here
end

-- Handle mouse clicks
function PortRoyal:mousepressed(x, y, button, gameState)
    if button ~= 1 then  -- Only process left clicks
        return
    end
    
    local currentScreen = gameState.settings.currentPortScreen
    
    -- Print debug info
    if gameState.settings.debug then
        print("Port Royal screen click at: " .. x .. ", " .. y .. " on screen: " .. currentScreen)
    end
    
    -- Special handling for inventory debug button
    if currentScreen == "inventory" and gameState.settings.debug then
        if x >= 120 and x <= 270 and y >= 270 and y <= 300 then
            -- Debug button for adding resources
            gameState.resources.gold = gameState.resources.gold + 10
            gameState.resources.rum = gameState.resources.rum + 10
            gameState.resources.timber = gameState.resources.timber + 10
            gameState.resources.gunpowder = gameState.resources.gunpowder + 10
            print("DEBUG: Added 10 of each resource")
            return
        end
    end
    
    -- Check if any button was clicked
    if self.buttons[currentScreen] then
        for i, btn in ipairs(self.buttons[currentScreen]) do
            if x >= btn.x and x <= btn.x + btn.width and
               y >= btn.y and y <= btn.y + btn.height then
                -- Button was clicked, execute its action
                if btn.action then
                    if gameState.settings.debug then
                        print("Button clicked: " .. btn.text)
                    end
                    btn.action()
                end
                return
            end
        end
    end
end

return PortRoyal```

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
            
            -- We're now at the destination, but not yet moored
            gameState.settings.moored = false
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
            
            -- We no longer automatically enter Port Royal
            -- This will be handled by the mooring system instead
            
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

## docs/CrewSystem.md
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
Generated: Wed Mar 26 23:42:26 CDT 2025

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
    
    -- Inventory system (10 slots for cargo and special items)
    inventory = {
        slots = {}          -- Will contain inventory slot objects
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = 5,         -- Scale 1-10
        
        -- Global crew pool - tracks all possible crew members in the game
        -- Each crew member has a unique ID
        pool = {},
        
        -- Tracks which crew are available at each location
        -- Key is location name, value is table of crew IDs
        availableByLocation = {}
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
        debug = false,  -- Set to false for normal gameplay, true for debugging
        portMode = false,  -- When true, display port/location interface instead of map
        currentPortScreen = "main",  -- Which port screen to display: main, tavern, shipyard, crew, inventory
        
        -- Ship state flags
        moored = false  -- When true, ship is docked at a location rather than at sea
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
    
    -- Initialize the crew pool
    self:initializeCrewPool()
    
    -- Distribute crew members to locations
    self:distributeCrewToLocations()
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        id = "captain",
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

-- Initialize the pool of potential crew members
function GameState:initializeCrewPool()
    self.crew.pool = {
        {
            id = "js001",
            name = "Jack Sparrow",
            role = "Navigator",
            skill = 3,
            loyalty = 4,
            health = 8,
            cost = 25
        },
        {
            id = "ab002",
            name = "Anne Bonny",
            role = "Gunner",
            skill = 2,
            loyalty = 3,
            health = 7,
            cost = 20
        },
        {
            id = "dh003",
            name = "Doc Holliday",
            role = "Surgeon",
            skill = 2,
            loyalty = 5,
            health = 6,
            cost = 15
        },
        {
            id = "bb004",
            name = "Blackbeard",
            role = "Gunner",
            skill = 3,
            loyalty = 2,
            health = 9,
            cost = 30
        },
        {
            id = "hm005",
            name = "Henry Morgan",
            role = "Navigator",
            skill = 2,
            loyalty = 4,
            health = 7,
            cost = 22
        },
        {
            id = "sp006",
            name = "Samuel Porter",
            role = "Surgeon",
            skill = 3,
            loyalty = 3,
            health = 5,
            cost = 18
        },
        {
            id = "wb007",
            name = "William Bones",
            role = "Gunner",
            skill = 2,
            loyalty = 5,
            health = 6,
            cost = 20
        },
        {
            id = "gr008",
            name = "Grace O'Malley",
            role = "Navigator",
            skill = 3,
            loyalty = 3,
            health = 7,
            cost = 24
        },
        {
            id = "jf009",
            name = "James Fletcher",
            role = "Surgeon",
            skill = 1,
            loyalty = 4,
            health = 8,
            cost = 12
        }
    }
end

-- Distribute crew members to different ports
function GameState:distributeCrewToLocations()
    -- Initialize location tables
    self.crew.availableByLocation = {
        ["Port Royal"] = {},
        ["Nassau"] = {},
        ["Havana"] = {},
        ["Crown Colony"] = {}
    }
    
    -- Helper function to check if a crew member is already in a location
    local function isInAnyLocation(crewId)
        for _, locationCrew in pairs(self.crew.availableByLocation) do
            for _, id in ipairs(locationCrew) do
                if id == crewId then
                    return true
                end
            end
        end
        return false
    end
    
    -- Helper function to get a crew member by role from pool
    local function getCrewByRole(role)
        local candidates = {}
        for _, crew in ipairs(self.crew.pool) do
            if crew.role == role and not isInAnyLocation(crew.id) then
                table.insert(candidates, crew)
            end
        end
        
        if #candidates > 0 then
            local selected = candidates[math.random(#candidates)]
            return selected.id
        end
        return nil
    end
    
    -- Assign crew by role patterns to each location
    -- Port Royal: 1 of each role (Navigator, Gunner, Surgeon)
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Port Royal"], getCrewByRole("Surgeon"))
    
    -- Nassau: 2 Gunners, 1 Navigator
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Nassau"], getCrewByRole("Navigator"))
    
    -- Havana: 2 Navigators, 1 Surgeon
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Navigator"))
    table.insert(self.crew.availableByLocation["Havana"], getCrewByRole("Surgeon"))
    
    -- Crown Colony: 1 Surgeon, 1 Gunner, 1 Navigator
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Surgeon"))
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Gunner"))
    table.insert(self.crew.availableByLocation["Crown Colony"], getCrewByRole("Navigator"))
    
    -- Remove nil entries (if we ran out of crew)
    for location, crewList in pairs(self.crew.availableByLocation) do
        for i = #crewList, 1, -1 do
            if not crewList[i] then
                table.remove(crewList, i)
            end
        end
    end
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
    
    -- Reset interface modes
    self.settings.portMode = false
    self.settings.currentPortScreen = "main"
    self.settings.moored = false
    
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
    
    -- Reset inventory
    self.inventory.slots = {}
    for i = 1, 10 do
        self.inventory.slots[i] = {
            item = nil,
            quantity = 0
        }
    end
    
    -- Reset crew
    self.crew.members = {}
    self.crew.morale = 5
    
    -- Reinitialize the crew pool and distribution
    self:initializeCrewPool()
    self:distributeCrewToLocations()
    
    -- Add default crew member (captain)
    table.insert(self.crew.members, {
        id = "captain",
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

-- Calculate travel time between zones based on wind and crew
function GameState:calculateTravelTime(fromZoneIdx, toZoneIdx, map)
    -- Base travel time is always 1 week
    local baseTravelTime = 1
    
    -- If either zone is invalid, just return base time
    if not fromZoneIdx or not toZoneIdx or 
       fromZoneIdx > #map.zones or toZoneIdx > #map.zones then
        return baseTravelTime, "normal"
    end
    
    -- Debug info for travel calculation
    if self.settings.debug then
        print("Calculating travel time from zone " .. fromZoneIdx .. " to zone " .. toZoneIdx)
        print("Current wind direction: " .. self.environment.wind.currentDirection)
    end
    
    -- Check for Navigator in crew (Ticket 2-6)
    local hasNavigator = false
    for _, crewMember in ipairs(self.crew.members) do
        if crewMember.role == "Navigator" then
            hasNavigator = true
            if self.settings.debug then
                print("Navigator found in crew: " .. crewMember.name)
            end
            break
        end
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
    
    -- Apply the wind modifier 
    local travelTime = baseTravelTime + windModifier
    
    -- Apply navigator modifier if present
    local navigatorEffect = ""
    if hasNavigator then
        travelTime = travelTime - 0.5
        navigatorEffect = " with Navigator"
        if self.settings.debug then
            print("Navigator reducing travel time by 0.5 weeks")
        end
    end
    
    -- Ensure minimum 0.5 week travel time
    travelTime = math.max(0.5, travelTime)
    
    -- Create wind effect description
    local windEffect = ""
    if windModifier > 0 then
        windEffect = "against wind"
    elseif windModifier < 0 then
        windEffect = "with wind"
    else
        windEffect = "crosswind"
    end
    
    -- Combine wind and navigator effects
    local totalEffect = windEffect
    if hasNavigator then
        totalEffect = totalEffect .. navigatorEffect
    end
    
    if self.settings.debug then
        print("Wind direction: " .. windDirection)
        print("Wind modifier: " .. windModifier)
        print("Navigator effect: " .. (hasNavigator and "-0.5 weeks" or "none"))
        print("Final travel time: " .. travelTime .. " weeks")
        print("Total effect: " .. totalEffect)
    end
    
    return travelTime, totalEffect
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

-- Get crew member from ID
function GameState:getCrewMemberById(id)
    for _, member in ipairs(self.crew.pool) do
        if member.id == id then
            return member
        end
    end
    return nil
end

-- Get available crew at a location
function GameState:getAvailableCrewAtLocation(locationName)
    local result = {}
    
    -- Check if we have crew listed for this location
    if not self.crew.availableByLocation[locationName] then
        return result
    end
    
    -- Get crew IDs at this location
    local crewIds = self.crew.availableByLocation[locationName]
    
    -- Convert IDs to full crew member data
    for _, id in ipairs(crewIds) do
        local member = self:getCrewMemberById(id)
        if member then
            table.insert(result, member)
        end
    end
    
    return result
end

-- Remove a crew member from a location (e.g., when hired)
function GameState:removeCrewFromLocation(crewId, locationName)
    if not self.crew.availableByLocation[locationName] then
        return false
    end
    
    for i, id in ipairs(self.crew.availableByLocation[locationName]) do
        if id == crewId then
            table.remove(self.crew.availableByLocation[locationName], i)
            return true
        end
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
local portRoyal = require('portRoyal')

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
    portRoyal:load(gameState)   -- Initialize Port Royal interface
    
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
    if gameState.settings.portMode then
        -- Update port interface
        portRoyal:update(dt, gameState)
    else
        -- Update map and ship
        gameMap:update(dt, gameState)
        playerShip:update(dt, gameState, gameMap)
    end
    
    -- Always update time system
    timeSystem:update(dt, gameState)
    
    -- Handle game restart
    if gameState.time.isGameOver and love.keyboard.isDown('r') then
        gameState:reset()  -- Reset all game state
        timeSystem:load(gameState)  -- Reinitialize systems
        gameMap:load(gameState)
        playerShip:load(gameState, gameMap)
        portRoyal:load(gameState)
    end
end

function love.draw()
    -- Render game based on current mode
    if gameState.settings.portMode then
        -- Draw port interface
        portRoyal:draw(gameState)
    else
        -- Draw map and ship
        gameMap:draw(gameState)
        playerShip:draw(gameState)
    end
    
    -- Always draw time system
    timeSystem:draw(gameState)
    
    -- Display fps in debug mode
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end
end

function love.mousemoved(x, y)
    if gameState.settings.portMode then
        portRoyal:mousemoved(x, y, gameState)
    else
        gameMap:mousemoved(x, y, gameState)
    end
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    
    if gameState.settings.portMode then
        portRoyal:mousepressed(x, y, button, gameState)
    else
        gameMap:mousepressed(x, y, button, gameState)
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- If in port mode, return to map
        if gameState.settings.portMode then
            gameState.settings.portMode = false
            gameState.settings.currentPortScreen = "main"
        else
            love.event.quit()
        end
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

return Map```

## src/portRoyal.lua
```lua
-- Port Interface Module
-- Currently focused on Port Royal but can be extended to all locations

local PortRoyal = {
    -- UI constants
    width = 800,
    height = 600,
    
    -- UI elements
    buttons = {},
    
    -- Placeholder art
    backgrounds = {
        main = nil,
        tavern = nil,
        shipyard = nil
    },
    
    -- Currently displayed crew (loaded dynamically based on location)
    availableCrew = {},
    
    -- Tavern status indicators
    tavernMessage = nil,
    tavernMessageTimer = 0,
}

-- Initialize Port interface
function PortRoyal:load(gameState)
    -- Main screen buttons will be generated dynamically based on location
    self.buttons.main = {}
    
    -- Initialize buttons for tavern screen (just the back button initially)
    self.buttons.tavern = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() 
                gameState.settings.currentPortScreen = "main" 
                -- Clear crew list when leaving tavern
                self.availableCrew = {}
            end
        }
    }
    
    -- Initialize buttons for shipyard screen
    self.buttons.shipyard = {
        {
            text = "Repair Ship",
            x = 325,
            y = 300,
            width = 150,
            height = 50,
            action = function() 
                -- For now, just display a message that repairs aren't available yet
                print("Ship repairs not yet implemented")
                self.shipyardMessage = "Ship repairs will be available in a future update."
                self.shipyardMessageTimer = 3  -- Show message for 3 seconds
            end
        },
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Variables for shipyard message display
    self.shipyardMessage = nil
    self.shipyardMessageTimer = 0
    
    -- Initialize buttons for crew screen
    self.buttons.crew = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Initialize buttons for inventory screen
    self.buttons.inventory = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Load placeholder background images if available
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port_royal_main.png")
    end)
    if success then
        self.backgrounds.main = result
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-tavern.png")
    end)
    if success then
        self.backgrounds.tavern = result
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-shipyard.png")
    end)
    if success then
        self.backgrounds.shipyard = result
        print("Port Royal shipyard background loaded")
    end
end

-- Update Port interface
function PortRoyal:update(dt, gameState)
    -- Generate location-specific buttons if needed
    self:generateLocationButtons(gameState)
    
    -- Load crew members for the current location if entering tavern
    local currentScreen = gameState.settings.currentPortScreen
    if currentScreen == "tavern" and #self.availableCrew == 0 then
        self:loadAvailableCrewForLocation(gameState)
    end
    
    -- Check if we need to reload any assets
    if not self.backgrounds.tavern then
        -- Try to load tavern background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-tavern.png")
        end)
        if success then
            self.backgrounds.tavern = result
            print("Port Royal tavern background loaded during update")
        end
    end
    
    if not self.backgrounds.shipyard then
        -- Try to load shipyard background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-shipyard.png")
        end)
        if success then
            self.backgrounds.shipyard = result
            print("Port Royal shipyard background loaded during update")
        end
    end
    
    -- Update shipyard message timer
    if self.shipyardMessage and self.shipyardMessageTimer > 0 then
        self.shipyardMessageTimer = self.shipyardMessageTimer - dt
        if self.shipyardMessageTimer <= 0 then
            self.shipyardMessage = nil
        end
    end
    
    -- Update tavern message timer
    if self.tavernMessage and self.tavernMessageTimer > 0 then
        self.tavernMessageTimer = self.tavernMessageTimer - dt
        if self.tavernMessageTimer <= 0 then
            self.tavernMessage = nil
        end
    end
end

-- Load crew members available at the current location
function PortRoyal:loadAvailableCrewForLocation(gameState)
    -- Clear current list
    self.availableCrew = {}
    
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
            
            -- Get available crew at this location
            self.availableCrew = gameState:getAvailableCrewAtLocation(currentZoneName)
            
            -- Update the tavern buttons for these crew members
            self:updateTavernButtons(gameState, currentZoneName)
        end
    end
end

-- Update the tavern buttons for the available crew members
function PortRoyal:updateTavernButtons(gameState, locationName)
    -- Keep the back button (it should be the last button)
    local backButton = self.buttons.tavern[#self.buttons.tavern]
    
    -- Clear all other buttons
    self.buttons.tavern = {}
    
    -- Add hire buttons for each available crew member
    for i, crew in ipairs(self.availableCrew) do
        table.insert(self.buttons.tavern, {
            text = "Hire for " .. crew.cost .. " gold",
            x = 500,
            y = 190 + (i-1) * 100 + 20,
            width = 200,
            height = 40,
            crewId = crew.id,  -- Store crew ID for hiring
            action = function()
                -- Check if can afford the crew member
                if not gameState:canAfford("gold", crew.cost) then
                    self.tavernMessage = "Not enough gold to hire " .. crew.name
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Check if crew is full
                if #gameState.crew.members >= gameState.ship.crewCapacity then
                    self.tavernMessage = "Ship crew capacity reached"
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Hire the crew member
                gameState:spendResources("gold", crew.cost)
                
                -- Create a copy of the crew member to add to the player's crew
                local newCrewMember = {
                    id = crew.id,
                    name = crew.name,
                    role = crew.role,
                    skill = crew.skill,
                    loyalty = crew.loyalty,
                    health = crew.health
                }
                
                -- Add to player's crew
                gameState:addCrewMember(newCrewMember)
                
                -- Remove from location
                gameState:removeCrewFromLocation(crew.id, locationName)
                
                -- Success message
                self.tavernMessage = crew.name .. " hired successfully!"
                self.tavernMessageTimer = 3
                
                -- Update available crew and buttons
                self.availableCrew = gameState:getAvailableCrewAtLocation(locationName)
                self:updateTavernButtons(gameState, locationName)
            end
        })
    end
    
    -- Add back button
    table.insert(self.buttons.tavern, backButton)
end

-- Generate buttons based on the current location
function PortRoyal:generateLocationButtons(gameState)
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Clear existing buttons
    self.buttons.main = {}
    
    -- Generate basic "Set Sail" button for all locations
    table.insert(self.buttons.main, {
        text = "Set Sail",
        x = 325,
        y = 400,
        width = 150,
        height = 50,
        action = function() 
            gameState.settings.portMode = false 
            gameState.settings.moored = false
            print("Setting sail from " .. currentZoneName)
        end
    })
    
    -- Add location-specific buttons
    if currentZoneName == "Port Royal" then
        -- Port Royal has the full set of options
        table.insert(self.buttons.main, {
            text = "Tavern",
            x = 200,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 200,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 450,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 450,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    elseif currentZoneName == "Nassau" then
        -- Nassau has a tavern and crew management
        table.insert(self.buttons.main, {
            text = "Pirate Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
    elseif currentZoneName == "Havana" then
        -- Havana has a tavern and shipyard
        table.insert(self.buttons.main, {
            text = "Spanish Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
    elseif currentZoneName == "Crown Colony" then
        -- Crown Colony has a shipyard and inventory
        table.insert(self.buttons.main, {
            text = "Royal Shipyard",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    end
    
    -- For all locations, ensure "Set Sail" is at the bottom
    if #self.buttons.main > 0 then
        for i, button in ipairs(self.buttons.main) do
            if button.text == "Set Sail" then
                button.y = 400  -- Position at bottom
            end
        end
    end
end

-- Draw Port interface
function PortRoyal:draw(gameState)
    -- Get current screen and location
    local currentScreen = gameState.settings.currentPortScreen
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up the current zone name
    if currentZoneIndex and currentZoneIndex > 0 then
        -- Get the Map module to look up zone name
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Draw background based on current screen
    self:drawBackground(currentScreen)
    
    -- Draw gold amount
    love.graphics.setColor(1, 0.9, 0.2, 1)  -- Gold color
    love.graphics.print("Gold: " .. gameState.resources.gold, 10, 10)
    
    -- Draw screen-specific content
    if currentScreen == "main" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(currentZoneName .. " Harbor", 0, 100, self.width, "center")
        
        -- Draw ship name and class
        love.graphics.printf("Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 130, self.width, "center")
        
        -- Draw location-specific welcome message
        local welcomeMessage = "Welcome to port. What would you like to do?"
        
        if currentZoneName == "Port Royal" then
            welcomeMessage = "Welcome to Port Royal, the pirate haven of the Caribbean."
        elseif currentZoneName == "Nassau" then
            welcomeMessage = "Welcome to Nassau, the lawless pirate stronghold."
        elseif currentZoneName == "Havana" then
            welcomeMessage = "Welcome to Havana, the jewel of Spanish colonies."
        elseif currentZoneName == "Crown Colony" then
            welcomeMessage = "Welcome to the Crown Colony, an outpost of British influence."
        elseif currentZoneName:find("Waters") then
            welcomeMessage = "Your ship is anchored in open waters. Not much to do here."
        elseif currentZoneName:find("Bay") or currentZoneName:find("Reach") then
            welcomeMessage = "You've moored at a secluded spot with no settlements."
        end
        
        love.graphics.setColor(1, 0.95, 0.8, 1)  -- Light cream color
        love.graphics.printf(welcomeMessage, 50, 160, self.width - 100, "center")
        
        -- Draw buttons for main screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "tavern" then
        -- Get current location for tavern name
        local currentZoneIndex = gameState.ship.currentZone
        local tavernName = "The Rusty Anchor Tavern"
        local tavernDescription = "The tavern is filled with sailors, merchants, and pirates.\nHere you can recruit crew members and hear rumors."
        
        -- Set location-specific tavern names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Nassau" then
                    tavernName = "The Black Flag Tavern"
                    tavernDescription = "A rowdy establishment frequented by pirates.\nRecruit dangerous but skilled crew members here."
                elseif zone.name == "Havana" then
                    tavernName = "La Cantina del Rey"
                    tavernDescription = "An elegant Spanish tavern with fine wines.\nHear rumors about Spanish treasure fleets here."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tavernName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.tavern then
            love.graphics.printf(tavernDescription, 0, 120, self.width, "center")
        end
        
        -- Draw available crew for hire
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Available Crew for Hire:", 0, 160, self.width, "center")
        
        -- Draw table header
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print("Name", 100, 190)
        love.graphics.print("Role", 250, 190)
        love.graphics.print("Stats", 350, 190)
        
        -- Draw available crew members
        for i, crew in ipairs(self.availableCrew) do
            local yPos = 190 + (i-1) * 100  -- Increased vertical spacing
            
            -- Background panel for each crew member (including hire button area)
            love.graphics.setColor(0.2, 0.2, 0.3, 0.6)
            love.graphics.rectangle("fill", 90, yPos, 620, 80)
            love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
            love.graphics.rectangle("line", 90, yPos, 620, 80)
            
            -- Display crew info
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(crew.name, 100, yPos + 10)
            
            -- Color code the role to match the crew management screen
            if crew.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            elseif crew.role == "Gunner" then
                love.graphics.setColor(1, 0.7, 0.7, 1)  -- Red for gunners
            elseif crew.role == "Surgeon" then
                love.graphics.setColor(0.7, 0.7, 1, 1)  -- Blue for surgeons
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(crew.role, 250, yPos + 10)
            
            -- Display crew stats
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print("Skill: " .. crew.skill, 350, yPos + 10)
            love.graphics.print("Loyalty: " .. crew.loyalty, 350, yPos + 30)
            love.graphics.print("Health: " .. crew.health, 350, yPos + 50)
            
            -- Display hire cost
            love.graphics.setColor(1, 0.9, 0.2, 1)
            love.graphics.print("Cost: " .. crew.cost .. " gold", 100, yPos + 50)
            
            -- Draw integrated hire button (right side of panel)
            love.graphics.setColor(0.3, 0.5, 0.7, 0.9)
            love.graphics.rectangle("fill", 500, yPos + 20, 200, 40)
            love.graphics.setColor(0.5, 0.7, 0.9, 1)
            love.graphics.rectangle("line", 500, yPos + 20, 200, 40)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Hire for " .. crew.cost .. " gold", 500, yPos + 33, 200, "center")
        end
        
        -- Show player's current gold
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.printf("Your gold: " .. gameState.resources.gold, 0, 440, self.width, "center")
        
        -- Display crew capacity
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Ship Crew: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 470, self.width, "center")
        
        -- Display tavern message if active
        if self.tavernMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.tavernMessage, 150, 390, 500, "center")
        end
        
        -- Draw buttons for tavern screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "shipyard" then
        -- Get current location for shipyard name
        local currentZoneIndex = gameState.ship.currentZone
        local shipyardName = "Port Royal Shipyard"
        local shipyardDescription = "The shipyard is busy with workers repairing vessels.\nHere you can upgrade your ship or purchase a new one."
        
        -- Set location-specific shipyard names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Havana" then
                    shipyardName = "Havana Naval Yards"
                    shipyardDescription = "A Spanish shipyard specializing in galleons.\nSpanish vessels are sturdy but more expensive."
                elseif zone.name == "Crown Colony" then
                    shipyardName = "Royal Navy Dockyard"
                    shipyardDescription = "A military shipyard with British vessels.\nStrict regulations, but high-quality ships available."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(shipyardName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.shipyard then
            love.graphics.printf(shipyardDescription, 0, 150, self.width, "center")
        end
        
        -- Draw current ship status
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.printf("Current Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 220, self.width, "center")
        love.graphics.printf("Hull Durability: " .. gameState.ship.durability .. "/10", 0, 250, self.width, "center")
        
        -- Draw shipyard message if active
        if self.shipyardMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.shipyardMessage, 150, 390, 500, "center")
        end
        
        -- Draw buttons for shipyard screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "crew" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Crew Management", 0, 70, self.width, "center")
        
        -- Draw crew info
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Crew Size: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 110, self.width, "center")
        love.graphics.printf("Crew Morale: " .. gameState.crew.morale .. "/10", 0, 140, self.width, "center")
        
        -- Draw crew table headers
        love.graphics.setColor(1, 0.9, 0.7, 1)
        love.graphics.print("Name", 130, 180)
        love.graphics.print("Role", 300, 180)
        love.graphics.print("Skill", 450, 180)
        love.graphics.print("Loyalty", 520, 180)
        love.graphics.print("Health", 600, 180)
        
        -- Draw table separator
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.line(120, 200, 680, 200)
        
        -- List crew members with stats in a table format
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        local yPos = 210
        for i, member in ipairs(gameState.crew.members) do
            -- Highlight navigator role for ticket 2-6 visibility
            if member.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(member.name, 130, yPos)
            love.graphics.print(member.role, 300, yPos)
            love.graphics.print(member.skill or 1, 450, yPos)
            love.graphics.print(member.loyalty or 5, 520, yPos)
            love.graphics.print(member.health or 10, 600, yPos)
            
            -- Draw separator between crew members
            love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            
            yPos = yPos + 40
        end
        
        -- Draw empty slots if not at capacity
        for i = #gameState.crew.members + 1, gameState.ship.crewCapacity do
            love.graphics.setColor(0.4, 0.4, 0.5, 0.5)
            love.graphics.print("Empty slot", 130, yPos)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            yPos = yPos + 40
        end
        
        -- Draw role effects information
        love.graphics.setColor(0.9, 0.8, 0.6, 1)
        love.graphics.printf("Crew Role Effects:", 150, 400, 500, "center")
        
        love.graphics.setColor(0.7, 1, 0.7, 1)
        love.graphics.printf("Navigator: Reduces travel time between zones by 0.5 weeks", 150, 430, 500, "center")
        
        -- Draw buttons for crew screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "inventory" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Inventory", 0, 70, self.width, "center")
        
        -- Draw resources section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Resources:", 100, 120, 200, "left")
        
        -- Draw resources
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print("Gold: " .. gameState.resources.gold, 120, 150)
        love.graphics.print("Rum: " .. gameState.resources.rum, 120, 180)
        love.graphics.print("Timber: " .. gameState.resources.timber, 120, 210)
        love.graphics.print("Gunpowder: " .. gameState.resources.gunpowder, 120, 240)
        
        -- Draw cargo slots section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Cargo Slots:", 400, 120, 200, "left")
        
        -- Draw cargo slots (10 slots)
        local slotSize = 50
        local startX = 400
        local startY = 150
        local cols = 5
        
        for i = 1, 10 do
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            local x = startX + col * (slotSize + 10)
            local y = startY + row * (slotSize + 10)
            
            -- Draw slot background
            love.graphics.setColor(0.2, 0.2, 0.3, 1)
            love.graphics.rectangle("fill", x, y, slotSize, slotSize)
            
            -- Draw slot border
            love.graphics.setColor(0.4, 0.4, 0.5, 1)
            love.graphics.rectangle("line", x, y, slotSize, slotSize)
            
            -- Draw slot content if any
            local slot = gameState.inventory.slots[i]
            if slot and slot.item then
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
                love.graphics.printf(slot.item, x, y + 10, slotSize, "center")
                love.graphics.printf(slot.quantity, x, y + 30, slotSize, "center")
            else
                -- Draw empty slot number
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                love.graphics.printf(i, x + 15, y + 15, 20, "center")
            end
        end
        
        -- Debug button for adding resources (if debug mode enabled)
        if gameState.settings.debug then
            love.graphics.setColor(0.3, 0.6, 0.3, 1)
            love.graphics.rectangle("fill", 120, 270, 150, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("+ 10 of each resource", 120, 275, 150, "center")
        end
        
        -- Draw buttons for inventory screen
        self:drawButtons(currentScreen)
    end
end

-- Helper function to draw background
function PortRoyal:drawBackground(screen)
    -- Set color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Get current location
    local currentZoneIndex = nil
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if _G.gameState and _G.gameState.ship then
        currentZoneIndex = _G.gameState.ship.currentZone
    end
    
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Try to load location-specific background if available
    local locationKey = currentZoneName:lower():gsub("%s+", "_")
    local locationBackground = nil
    
    if screen == "main" then
        local success, result = pcall(function()
            return love.graphics.newImage("assets/" .. locationKey .. "_main.png")
        end)
        if success then
            locationBackground = result
        end
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        love.graphics.draw(locationBackground, 0, 0)
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        love.graphics.draw(self.backgrounds.main, 0, 0)
    elseif screen == "tavern" and self.backgrounds.tavern then
        love.graphics.draw(self.backgrounds.tavern, 0, 0)
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        love.graphics.draw(self.backgrounds.shipyard, 0, 0)
    else
        -- Draw a fallback colored background
        if screen == "main" then
            -- Based on zone type (could become more sophisticated)
            if currentZoneName == "Port Royal" then
                love.graphics.setColor(0.2, 0.3, 0.5, 1)  -- Deep blue for Port Royal
            elseif currentZoneName:find("Waters") then
                love.graphics.setColor(0.2, 0.4, 0.5, 1)  -- Different blue for waters
            elseif currentZoneName == "Nassau" or currentZoneName == "Havana" then
                love.graphics.setColor(0.5, 0.3, 0.2, 1)  -- Brown for settlements
            else
                love.graphics.setColor(0.3, 0.3, 0.4, 1)  -- Default color
            end
        elseif screen == "tavern" then
            love.graphics.setColor(0.3, 0.2, 0.1, 1)  -- Brown for tavern
        elseif screen == "shipyard" then
            love.graphics.setColor(0.4, 0.4, 0.5, 1)  -- Grey for shipyard
        elseif screen == "crew" then
            love.graphics.setColor(0.2, 0.3, 0.4, 1)  -- Navy for crew
        elseif screen == "inventory" then
            love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Grey for inventory
        end
        
        -- Fill background
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
end

-- Helper function to draw buttons
function PortRoyal:drawButtons(screen)
    -- Only draw buttons for the current screen
    if not self.buttons[screen] then
        return
    end
    
    -- Position the "Back to Port" button at the bottom for non-main screens
    if screen ~= "main" and #self.buttons[screen] == 1 and 
       self.buttons[screen][1].text == "Back to Port" then
        self.buttons[screen][1].y = 520
    end
    
    for _, button in ipairs(self.buttons[screen]) do
        -- Draw button background
        love.graphics.setColor(0.4, 0.4, 0.6, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button border
        love.graphics.setColor(0.6, 0.6, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(button.text)
        local textHeight = font:getHeight()
        love.graphics.print(
            button.text,
            button.x + (button.width/2) - (textWidth/2),
            button.y + (button.height/2) - (textHeight/2)
        )
    end
end

-- Handle mouse movement
function PortRoyal:mousemoved(x, y, gameState)
    -- Could implement hover effects for buttons here
end

-- Handle mouse clicks
function PortRoyal:mousepressed(x, y, button, gameState)
    if button ~= 1 then  -- Only process left clicks
        return
    end
    
    local currentScreen = gameState.settings.currentPortScreen
    
    -- Print debug info
    if gameState.settings.debug then
        print("Port Royal screen click at: " .. x .. ", " .. y .. " on screen: " .. currentScreen)
    end
    
    -- Special handling for inventory debug button
    if currentScreen == "inventory" and gameState.settings.debug then
        if x >= 120 and x <= 270 and y >= 270 and y <= 300 then
            -- Debug button for adding resources
            gameState.resources.gold = gameState.resources.gold + 10
            gameState.resources.rum = gameState.resources.rum + 10
            gameState.resources.timber = gameState.resources.timber + 10
            gameState.resources.gunpowder = gameState.resources.gunpowder + 10
            print("DEBUG: Added 10 of each resource")
            return
        end
    end
    
    -- Check if any button was clicked
    if self.buttons[currentScreen] then
        for i, btn in ipairs(self.buttons[currentScreen]) do
            if x >= btn.x and x <= btn.x + btn.width and
               y >= btn.y and y <= btn.y + btn.height then
                -- Button was clicked, execute its action
                if btn.action then
                    if gameState.settings.debug then
                        print("Button clicked: " .. btn.text)
                    end
                    btn.action()
                end
                return
            end
        end
    end
end

return PortRoyal```

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
            
            -- We're now at the destination, but not yet moored
            gameState.settings.moored = false
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
            
            -- We no longer automatically enter Port Royal
            -- This will be handled by the mooring system instead
            
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

## docs/CrewSystem.md
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

## Tickets/2-1-design-and-implement-port-royal-hub.md
Description:

Create the main interface for Port Royal, serving as the central hub for 
port-based activities. This screen allows players to access locations 
(tavern, shipyard) and management screens (crew, inventory), with a clear 
entry/exit point to the global map.

Tasks:

Design a main Port Royal screen with buttons: "Tavern," "Shipyard," 
"Crew," "Inventory," and "Set Sail."
Implement navigation logic: clicking a button opens the corresponding 
screen (e.g., tavern or shipyard).
Display the player’s current gold from GameState.resources.gold on the 
main screen.
Create placeholder side-view pixel art screens for the tavern and shipyard 
(to be refined later).
Ensure the "Set Sail" button returns the player to the global map by 
updating GameState.ship.isMoving and triggering the map view.
Acceptance Criteria:

The main Port Royal screen displays current gold (e.g., "Gold: 50").
Buttons for "Tavern," "Shipyard," "Crew," "Inventory," and "Set Sail" are 
present and functional.
Clicking "Tavern" or "Shipyard" opens a placeholder screen with basic 
pixel art.
Clicking "Set Sail" exits Port Royal and returns to the global map view.
The hub is accessible only when the ship is in the Port Royal zone (check 
GameState.ship.currentZone).
Notes:

Use side-view pixel art consistent with the retro style (e.g., 800x600 
resolution).
For now, focus on structure; detailed art and animations (e.g., flickering 
lanterns) can be added in Sprint 10.
Integrate with map.lua to detect when the ship is in Port Royal for hub 
access.

## Tickets/2-2-implement-tavern-with-crew-recruitment.md
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

## Tickets/2-3-implement-shipyard-placeholder.md
Description:

Create a placeholder shipyard location in Port Royal to set the stage for 
future repair and upgrade functionality.

Tasks:

Design basic side-view pixel art for the shipyard.
Add a "Repair Ship" button that displays a message (e.g., "Repairs not yet 
available").
Include a button to return to the main Port Royal screen.
Acceptance Criteria:

The shipyard screen displays with basic pixel art.
A "Repair Ship" button is present and shows a placeholder message when 
clicked.
Players can return to the main Port Royal screen.
Notes:

This is a placeholder; full functionality (repairs, upgrades) will come in 
Sprint 7.
Keep the art simple but consistent with the retro style.

## Tickets/2-4-develop-crew-management-ui.md
Description:

Create a user interface to display the player’s current crew members and 
their basic stats, accessible from the Port Royal hub.

Tasks:

Design a UI screen listing all crew members from GameState.crew.members.
Display each crew member’s:
Name
Role (e.g., "Navigator")
Skill level (e.g., 1)
Loyalty (e.g., 5)
Show the current crew count and capacity (e.g., "Crew: 2/4").
Add a button to return to the main Port Royal screen.
Acceptance Criteria:

The crew management screen lists all crew members with their roles and 
stats.
The screen displays the current crew count and capacity.
Players can close the screen and return to the main Port Royal hub.

## Tickets/2-5-implement-basic-inventory-system.md
Description:

Develop an inventory screen to display the player’s resources, setting up 
a 10-slot structure for future item management.

Tasks:

Add an inventory table to GameState with 10 slots: GameState.inventory = { 
slots = {} }.
Create an inventory screen showing:
10 empty slots (for future cargo/items).
A separate section displaying current resources from GameState.resources 
(e.g., "Gold: 50, Rum: 0").
Add a button to return to the main Port Royal screen.
(Optional) Include debug functionality to add resources (e.g., 10 rum) for 
testing.
Acceptance Criteria:

The inventory screen shows 10 empty slots and lists current resources.
Players can close the screen and return to the main Port Royal hub.
Notes:

Slots will hold cargo or unique items in future sprints (e.g., Sprint 4 
for trading).
For now, display GameState.resources separately; slots remain empty until 
trading is implemented.
Keep the UI clean and legible within the retro style.

## Tickets/2-6-implement-navigator-crew-role-effect.md
Description:

Add the Navigator crew role’s effect to reduce travel time between zones, 
integrating port decisions with sea gameplay.

Tasks:

Modify GameState:calculateTravelTime to check for a Navigator in 
GameState.crew.members (e.g., role == "Navigator").
If a Navigator is present, reduce travel time by 0.5 weeks (e.g., base 1 
week becomes 0.5 weeks), with a minimum of 0.5 weeks.
Update the zone tooltip in map.lua to reflect the reduced travel time when 
a Navigator is active (e.g., "Travel time: 0.5 weeks").
Acceptance Criteria:

Travel time between zones is reduced by 0.5 weeks with a Navigator in the 
crew.
The reduced time is shown in the zone tooltip (e.g., "0.5 weeks" instead 
of "1 week").
Travel time never drops below 0.5 weeks.
Notes:

Assume only one Navigator applies the effect; handle multiple Navigators 
in future sprints.
Test with the existing wind mechanics (e.g., Navigator + "with wind" = 0.5 
weeks minimum).
Update GameState:advanceTime calls in ship.lua to reflect the new travel 
time.

