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

return GameState