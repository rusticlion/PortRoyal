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
        combatMode = false,  -- When true, display naval combat interface
        currentPortScreen = "main",  -- Which port screen to display: main, tavern, shipyard, crew, inventory
        
        -- Ship state flags
        moored = false  -- When true, ship is docked at a location rather than at sea
    },
    
    -- Combat state will be populated when a battle starts
    -- Structure shown in combat.lua
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

return GameState