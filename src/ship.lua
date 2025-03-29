-- Ship Module
local AssetUtils = require('utils.assetUtils')

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
    -- Validate required parameters
    assert(gameState, "gameState is required for Ship:load")
    assert(gameMap, "gameMap is required for Ship:load")
    
    -- Load ship sprites using AssetUtils
    self.sprites = {
        sloop = AssetUtils.loadImage("assets/sloop.png", "ship"),
        brigantine = AssetUtils.loadImage("assets/brigantine-top-down.png", "ship"),
        galleon = nil -- Not yet available
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
    -- Validate required parameters
    if not gameState then
        print("ERROR: gameState is required for Ship:draw")
        return
    end
    
    -- Get the ship's current class (defaulting to sloop for now)
    local shipClass = gameState.ship.class or "sloop"
    local sprite = self.sprites[shipClass]
    
    -- Use AssetUtils to safely draw the ship sprite
    if sprite then
        love.graphics.setColor(1, 1, 1, 1)  -- Full white, no tint
        love.graphics.draw(sprite, gameState.ship.x, gameState.ship.y, 0, 1, 1, 
                         sprite:getWidth()/2, sprite:getHeight()/2)
    else
        -- Draw a placeholder with the appropriate ship size
        local width = self.size * 3
        local height = self.size * 2
        AssetUtils.drawPlaceholder(
            gameState.ship.x - width/2, 
            gameState.ship.y - height/2, 
            width, height, "ship"
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Move ship to a new zone
function Ship:moveToZone(targetZoneIndex, gameState, gameMap)
    -- Validate required parameters
    assert(targetZoneIndex and type(targetZoneIndex) == "number", "targetZoneIndex must be a number")
    assert(gameState, "gameState is required for Ship:moveToZone")
    assert(gameMap, "gameMap is required for Ship:moveToZone")
    assert(targetZoneIndex <= #gameMap.zones, "targetZoneIndex out of bounds")
    
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
            
            -- Check if we should trigger a random encounter (20% chance)
            if targetZone.name ~= "Port Royal" and math.random() < 0.2 then
                self:initiateEncounter(gameState)
            end
            
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

-- Initiate an encounter with an enemy ship
function Ship:initiateEncounter(gameState)
    -- In a complete implementation, this would have different encounter types
    -- and could include narrative events, but for now, we'll focus on combat
    
    -- Check if combat system is loaded
    local combatSystem = require('combat')
    if not combatSystem then
        print("Error: Combat system not loaded")
        return false
    end
    
    -- Determine what type of ship the player encounters
    local encounterRoll = math.random()
    local enemyShipClass
    
    -- Higher level zones would affect encounter difficulty, but for now:
    if encounterRoll < 0.6 then
        enemyShipClass = "sloop"      -- 60% chance of encountering a sloop
    elseif encounterRoll < 0.9 then
        enemyShipClass = "brigantine" -- 30% chance of encountering a brigantine
    else
        enemyShipClass = "galleon"    -- 10% chance of encountering a galleon
    end
    
    -- Start naval combat
    print("Encountered an enemy " .. enemyShipClass .. "! Prepare for battle!")
    combatSystem:startBattle(gameState, enemyShipClass)
    
    return true
end

return Ship