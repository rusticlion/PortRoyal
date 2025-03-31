# PortRoyal Codebase Dump
Generated: Sun Mar 30 22:14:28 CDT 2025

# Source Code

## src/combat.lua
```lua
-- Combat System Module for Naval Battles
-- Implements a hex grid battlefield and ship combat mechanics

-- Import dice system
local diceModule = require('dice')
local diceSystem = diceModule.dice
local Modifier = diceModule.Modifier

-- Import ship utils
local shipUtils = require('utils.shipUtils')

-- Import constants
local Constants = require('constants')

local Combat = {
    -- Constants for the hex grid
    GRID_SIZE = Constants.COMBAT.GRID_SIZE,
    HEX_RADIUS = Constants.UI.COMBAT.HEX_RADIUS,
    HEX_HEIGHT = nil, -- Will be calculated based on radius
    HEX_WIDTH = nil,  -- Will be calculated based on radius
    
    -- Grid display properties
    gridOffsetX = Constants.UI.SCREEN_WIDTH / 2,  -- Position of grid on screen - will be centered
    gridOffsetY = 235,  -- Will be dynamically adjusted based on UI layout
    
    -- State variables for the battle
    hoveredHex = nil,   -- Currently hovered hex coordinates {q, r}
    selectedHex = nil,  -- Currently selected hex coordinates
    validMoves = {},    -- Valid move targets for selected ship
    
    -- SP planning phase variables
    plannedRotation = nil,  -- Temporary storage for rotation during planning
    hoveredMoveHex = nil,   -- Hex being hovered during movement planning
    plannedMoveHex = nil,   -- Hex selected as destination during planning
    rotationButtons = nil,  -- UI elements for rotation controls
    confirmManeuverButton = nil, -- UI element for confirm button
    
    -- Active battle data (will be stored in gameState.combat)
    -- Included here as reference/documentation
    --[[
    battle = {
        grid = {}, -- 2D array representing the hex grid
        playerShip = {
            class = "sloop",  -- Ship class (sloop, brigantine, galleon)
            size = 1,         -- Number of hexes occupied
            position = {5, 5}, -- {q, r} coordinates on grid
            orientation = 0,   -- Direction ship is facing (0-5, representing 60° increments)
            movesRemaining = 3 -- Based on ship speed
        },
        enemyShip = {
            class = "sloop",
            size = 1,
            position = {2, 2},
            orientation = 3,
            movesRemaining = 3
        },
        turn = "player", -- Who's turn is it (player or enemy)
        phase = "movement", -- Current phase (movement, attack, etc.)
    }
    --]]
    
    -- Action costs in crew points
    actionCosts = {
        fire = Constants.COMBAT.CP_COST_FIRE,     -- Fire Cannons costs
        evade = Constants.COMBAT.CP_COST_EVADE,   -- Evade costs
        repair = Constants.COMBAT.CP_COST_REPAIR  -- Repair costs (more labor intensive)
    },
    
    -- Ship definitions for the hex grid (size, shape, movement patterns)
    shipDefinitions = {
        sloop = {
            hexSize = 1,    -- Occupies 1 hex
            shape = {{0, 0}}, -- Relative {q, r} coordinates for each hex
            anchorOffset = {0, 0} -- Anchor point offset for sprite positioning
        },
        brigantine = {
            hexSize = 2,    -- Occupies 2 hexes
            -- Represents a ship that occupies 2 hexes in a line
            shape = {{0, 0}, {1, 0}}, -- Relative coordinates from anchor point
            anchorOffset = {0.5, 0} -- Anchor point is between the two hexes
        },
        galleon = {
            hexSize = 4,    -- Occupies 4 hexes
            -- Kite shape with 1 hex bow, 2 hex midship, 1 hex stern
            shape = {{0, 0}, {0, 1}, {1, 0}, {-1, 0}}, -- Relative coordinates from anchor point
            anchorOffset = {0, 0.5} -- Anchor point is in the middle of the kite shape
        }
    }
}

-- Initialize the combat system
function Combat:load(gameState)
    -- Calculate hex dimensions for drawing
    -- For pointy-top hexagons
    self.HEX_WIDTH = self.HEX_RADIUS * 2
    self.HEX_HEIGHT = math.sqrt(3) * self.HEX_RADIUS
    
    -- Create combat state in gameState if it doesn't exist
    if not gameState.combat then
        gameState.combat = {}
    end
    
    -- Load ship sprite assets
    local AssetUtils = require('utils.assetUtils')
    self.shipSprites = {
        sloop = AssetUtils.loadImage("assets/sloop-top-down.png", "ship"),
        brigantine = AssetUtils.loadImage("assets/brigantine-top-down.png", "ship"),
        galleon = nil -- Placeholder for future galleon sprite
    }
    
    -- Initialize the dice system
    self:initDiceSystem()
    
    -- Debug feature - enable with F9 key in debug mode
    self.showDebugHitboxes = false
    
    print("Combat system initialized")
    print("Hex dimensions: " .. self.HEX_WIDTH .. "x" .. self.HEX_HEIGHT)
end

-- Initialize a new battle
function Combat:initBattle(gameState, enemyShipClass)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:initBattle")
    assert(gameState.ship, "gameState.ship is required for Combat:initBattle")
    assert(gameState.ship.class, "gameState.ship.class is required for Combat:initBattle")
    
    -- Validate enemyShipClass if provided
    if enemyShipClass and not self.shipDefinitions[enemyShipClass] then
        print("WARNING: Unknown enemy ship class: " .. tostring(enemyShipClass) .. ". Defaulting to sloop.")
        enemyShipClass = "sloop"
    end
    
    -- Create a new grid
    local grid = self:createEmptyGrid()
    
    -- Configure player ship based on gameState
    local playerShipClass = gameState.ship.class
    local playerShipSpeed = shipUtils.getBaseSpeed(playerShipClass)
    
    -- Create battle state
    local battle = {
        grid = grid,
        playerShip = {
            class = playerShipClass,
            size = self.shipDefinitions[playerShipClass].hexSize,
            position = {2, 8}, -- Bottom-left area
            orientation = 0,   -- North-facing to start
            movesRemaining = playerShipSpeed,
            evadeScore = 0,    -- Evade score (reduces attacker's dice)
            hasActed = false,  -- Whether ship has performed an action this turn
            modifiers = {},    -- Active modifiers
            crewPoints = gameState.crew.members and #gameState.crew.members or 1, -- Available crew points for actions
            maxCrewPoints = gameState.crew.members and #gameState.crew.members or 1,  -- Maximum crew points per turn
            -- New SP and maneuver planning fields
            currentSP = self:getMaxSP(playerShipClass),
            maxSP = self:getMaxSP(playerShipClass),
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        enemyShip = {
            class = enemyShipClass or "sloop", -- Default to sloop if not specified
            size = self.shipDefinitions[enemyShipClass or "sloop"].hexSize,
            position = {7, 1}, -- Top-right area
            orientation = 3,   -- South-facing to start
            movesRemaining = shipUtils.getBaseSpeed(enemyShipClass or "sloop"),
            durability = shipUtils.getMaxHP(enemyShipClass or "sloop"), -- Set HP based on ship class
            evadeScore = 0,    -- Evade score (reduces attacker's dice)
            hasActed = false,  -- Whether ship has performed an action this turn
            modifiers = {},    -- Active modifiers
            crewPoints = shipUtils.getBaseCP(enemyShipClass or "sloop"), -- Based on ship class
            maxCrewPoints = shipUtils.getBaseCP(enemyShipClass or "sloop"),
            -- New SP and maneuver planning fields
            currentSP = self:getMaxSP(enemyShipClass or "sloop"),
            maxSP = self:getMaxSP(enemyShipClass or "sloop"),
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        turn = "player",
        phase = "playerMovePlanning", -- Updated to new phase system
        actionResult = nil,    -- Stores result of the last action
        turnCount = 1          -- Track number of turns
    }
    
    -- Place ships on the grid
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- Store battle in gameState
    gameState.combat = battle
    
    -- Process initial enemy planning for first turn
    self:processEnemyPlanning(battle)
    
    -- Always set up initial valid moves for player (regardless of phase)
    print("Calculating initial valid moves for player ship")
    self.validMoves = {}
    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
    self:calculateValidMoves(battle, battle.playerShip)
    print("Initial calculation found " .. #self.validMoves .. " valid moves")
    
    print("New naval battle initialized: " .. playerShipClass .. " vs " .. (enemyShipClass or "sloop"))
    return battle
end

-- Create an empty hex grid
function Combat:createEmptyGrid()
    local grid = {}
    for q = 0, self.GRID_SIZE - 1 do
        grid[q] = {}
        for r = 0, self.GRID_SIZE - 1 do
            grid[q][r] = {
                ship = nil,     -- Reference to ship in this hex
                isPlayerShip = false, -- Flag for player ship
                isEnemyShip = false,  -- Flag for enemy ship
                content = "empty" -- Can be "empty", "ship", or other battlefield elements
            }
        end
    end
    return grid
end

-- Place a ship on the grid
function Combat:placeShipOnGrid(grid, ship, battle)
    local q, r = ship.position[1], ship.position[2]
    local shape = self.shipDefinitions[ship.class].shape
    
    -- Transform shape based on orientation
    local transformedShape = self:transformShapeByOrientation(shape, ship.orientation)
    
    -- Place the ship on each relevant hex
    for _, offset in ipairs(transformedShape) do
        local hexQ = q + offset[1]
        local hexR = r + offset[2]
        
        -- Check if within grid bounds
        if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
            grid[hexQ][hexR].ship = ship
            grid[hexQ][hexR].content = "ship"
            
            -- Mark as player or enemy ship
            if ship == battle.playerShip then
                grid[hexQ][hexR].isPlayerShip = true
            else
                grid[hexQ][hexR].isEnemyShip = true
            end
        else
            print("Warning: Ship placement outside grid bounds: " .. hexQ .. "," .. hexR)
        end
    end
end

-- Transform a ship's shape based on orientation (0-5 for 60° increments)
function Combat:transformShapeByOrientation(shape, orientation)
    local transformed = {}
    
    -- Apply rotation based on orientation
    for _, hex in ipairs(shape) do
        local q, r = hex[1], hex[2]
        local newQ, newR
        
        -- Hex grid rotation formulas
        if orientation == 0 then      -- 0° (North)
            newQ, newR = q, r
        elseif orientation == 1 then  -- 60° (Northeast)
            newQ, newR = q + r, -q
        elseif orientation == 2 then  -- 120° (Southeast)
            newQ, newR = -r, q + r
        elseif orientation == 3 then  -- 180° (South)
            newQ, newR = -q, -r
        elseif orientation == 4 then  -- 240° (Southwest)
            newQ, newR = -q - r, q
        elseif orientation == 5 then  -- 300° (Northwest)
            newQ, newR = r, -q - r
        end
        
        table.insert(transformed, {newQ, newR})
    end
    
    return transformed
end

-- Get the hex at screen coordinates (x,y)
function Combat:getHexFromScreen(x, y)
    -- Approach: Find the closest hex center for maximum precision
    local closestHex = nil
    local minDistance = math.huge
    
    -- Try all grid hexes (brute force approach to guarantee accuracy)
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            -- Get hex center in pixel coordinates
            local hexX, hexY = self:hexToScreen(q, r)
            
            -- Calculate distance from mouse to hex center
            local dx = x - hexX
            local dy = y - hexY
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Check if this is in the hex (hexagons have radius = self.HEX_RADIUS)
            if dist <= self.HEX_RADIUS then
                -- Inside this hex - return immediately
                print("Found exact hex at " .. q .. "," .. r .. " (distance: " .. dist .. ")")
                return {q, r}
            end
            
            -- Otherwise track the closest hex
            if dist < minDistance then
                minDistance = dist
                closestHex = {q, r}
            end
        end
    end
    
    -- For debugging: Always return the closest hex, regardless of distance
    if closestHex then
        print("Returning closest hex " .. closestHex[1] .. "," .. closestHex[2] .. " (distance: " .. minDistance .. ")")
        return closestHex
    end
    
    -- Mouse is too far from any hex
    print("No hex found near " .. x .. "," .. y)
    return nil
end

-- Round floating point hex coordinates to the nearest hex
function Combat:roundHexCoord(q, r)
    local s = -q - r
    local rq = math.round(q)
    local rr = math.round(r)
    local rs = math.round(s)
    
    local qDiff = math.abs(rq - q)
    local rDiff = math.abs(rr - r)
    local sDiff = math.abs(rs - s)
    
    if qDiff > rDiff and qDiff > sDiff then
        rq = -rr - rs
    elseif rDiff > sDiff then
        rr = -rq - rs
    end
    
    return {rq, rr}
end

-- Helper function for Lua that mimics the math.round function from other languages
function math.round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

-- Mouse click handler for the playerMovePlanning phase
function Combat:handleManeuverPlanningClick(x, y, battle)
    -- Debug info
    print("Handling maneuver planning click at " .. x .. "," .. y)
    
    -- If rotation buttons are visible and clicked
    if self.plannedMoveHex and self.rotationButtons then
        -- Check if Rotate Left button is clicked
        if self:isPointInRect(x, y, self.rotationButtons.rotateLeft) then
            print("Rotate left button clicked")
            -- Rotate left (counter-clockwise)
            if self.plannedRotation == nil then
                -- If no rotation is set yet, start from the current ship orientation
                self.plannedRotation = (battle.playerShip.orientation - 1) % 6
            else
                -- Otherwise, just rotate from the current planned orientation
                self.plannedRotation = (self.plannedRotation - 1) % 6
            end
            print("New rotation: " .. self.plannedRotation)
            return true
        end
        
        -- Check if Rotate Right button is clicked
        if self:isPointInRect(x, y, self.rotationButtons.rotateRight) then
            print("Rotate right button clicked")
            -- Rotate right (clockwise)
            if self.plannedRotation == nil then
                -- If no rotation is set yet, start from the current ship orientation
                self.plannedRotation = (battle.playerShip.orientation + 1) % 6
            else
                -- Otherwise, just rotate from the current planned orientation
                self.plannedRotation = (self.plannedRotation + 1) % 6
            end
            print("New rotation: " .. self.plannedRotation)
            return true
        end
    end
    
    -- Check if Confirm button is clicked
    if self.plannedMoveHex and self.plannedRotation and self.confirmManeuverButton then
        if self:isPointInRect(x, y, self.confirmManeuverButton) then
            print("Confirm button clicked")
            -- Calculate SP cost
            local cost = self:calculateSPCost(battle.playerShip, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
            
            -- Check if player has enough SP
            if cost <= battle.playerShip.currentSP then
                print("Confirming maneuver - cost: " .. cost .. " SP")
                -- Store planned move and rotation in ship data
                battle.playerShip.plannedMove = {self.plannedMoveHex[1], self.plannedMoveHex[2]}
                battle.playerShip.plannedRotation = self.plannedRotation
                
                -- Advance to the next phase (maneuver resolution)
                self:advanceToNextPhase(battle)
                return true
            else
                -- Not enough SP - provide feedback
                print("Not enough Sail Points for this maneuver!")
                return true
            end
        end
    end
    
    -- Check if a hex on the grid was clicked
    print("Attempting to get hex from screen coordinates: " .. x .. "," .. y)
    
    -- First check if player ship is already selected
    if not self.selectedHex then
        -- Auto-select player ship to show valid moves
        print("Auto-selecting player ship")
        self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
        self:calculateValidMoves(battle, battle.playerShip)
    end
    
    -- Get clicked hex
    local clickedHex = self:getHexFromScreen(x, y)
    if clickedHex then
        local q, r = clickedHex[1], clickedHex[2]
        print("Clicked hex: " .. q .. "," .. r)
        
        -- Check if clicked hex is a valid move
        if self:isValidMove(q, r) then
            print("Valid move selected at " .. q .. "," .. r)
            -- Store as planned move destination
            self.plannedMoveHex = {q, r}
            
            -- If no rotation planned yet, initialize it to current orientation
            if not self.plannedRotation then
                self.plannedRotation = battle.playerShip.orientation
                print("Set initial rotation to current orientation: " .. self.plannedRotation)
            end
            
            return true
        elseif battle.grid[q] and battle.grid[q][r] and battle.grid[q][r].isPlayerShip then
            print("Player ship selected at " .. q .. "," .. r)
            -- If player clicked their ship, select it to show valid moves
            self.selectedHex = {q, r}
            
            -- Calculate and store valid moves for selected ship
            self:calculateValidMoves(battle, battle.playerShip)
            
            return true
        else
            print("Hex is not a valid move or player ship")
            
            -- Try recalculating valid moves in case they weren't set properly
            if #self.validMoves == 0 and self.selectedHex then
                print("Recalculating valid moves")
                self:calculateValidMoves(battle, battle.playerShip)
            end
        end
    else
        print("No hex found at click position")
    end
    
    return false
end

-- Helper function to check if a point is inside a rectangle
function Combat:isPointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width and
           y >= rect.y and y <= rect.y + rect.height
end

-- Get neighbors of a hex
-- Calculate valid moves for SP-based movement
function Combat:calculateValidMoves(battle, ship)
    self.validMoves = {} -- Clear previous valid moves
    
    -- Get the ship's current position and SP
    local shipQ, shipR = ship.position[1], ship.position[2]
    local availableSP = ship.currentSP
    
    print("Calculating valid moves for ship at " .. shipQ .. "," .. shipR .. " with " .. availableSP .. " SP")
    
    -- Each SP allows moving 1 hex, so the maximum distance we can move is equal to availableSP
    local maxDistance = availableSP
    
    -- Initialize an empty valid moves list
    self.validMoves = {}
    
    -- Loop through all grid cells within maxDistance
    for q = math.max(0, shipQ - maxDistance), math.min(self.GRID_SIZE - 1, shipQ + maxDistance) do
        for r = math.max(0, shipR - maxDistance), math.min(self.GRID_SIZE - 1, shipR + maxDistance) do
            -- Skip the ship's current position
            if q ~= shipQ or r ~= shipR then
                -- Calculate distance between ship and this hex
                local distance = self:hexDistance(shipQ, shipR, q, r)
                
                -- Check if within movement range
                if distance <= maxDistance then
                    -- Check if the hex is empty (no ships)
                    if battle.grid[q] and battle.grid[q][r] and 
                       not (battle.grid[q][r].isPlayerShip or battle.grid[q][r].isEnemyShip) then
                        -- This is a valid move destination, add it to valid moves
                        table.insert(self.validMoves, {q, r})
                        print("Added valid move: " .. q .. "," .. r .. " (distance: " .. distance .. ")")
                    else
                        print("Hex " .. q .. "," .. r .. " occupied or out of bounds")
                    end
                else
                    print("Hex " .. q .. "," .. r .. " too far (distance: " .. distance .. ")")
                end
            end
        end
    end
    
    -- Force some valid moves for debugging!
    if #self.validMoves == 0 then
        print("NO VALID MOVES FOUND - FORCING SOME FOR DEBUGGING")
        
        -- Add some moves adjacent to the ship
        local directions = {
            {1, 0}, {1, -1}, {0, -1}, 
            {-1, 0}, {-1, 1}, {0, 1}
        }
        
        for _, dir in ipairs(directions) do
            local newQ = shipQ + dir[1]
            local newR = shipR + dir[2]
            
            -- Check if within grid bounds
            if newQ >= 0 and newQ < self.GRID_SIZE and newR >= 0 and newR < self.GRID_SIZE then
                -- Check if empty
                if not (battle.grid[newQ][newR].isPlayerShip or battle.grid[newQ][newR].isEnemyShip) then
                    table.insert(self.validMoves, {newQ, newR})
                    print("FORCED valid move: " .. newQ .. "," .. newR)
                end
            end
        end
    end
    
    -- Print debug summary
    print("Calculated " .. #self.validMoves .. " valid moves for ship with " .. availableSP .. " SP")
end

function Combat:getHexNeighbors(q, r)
    local neighbors = {}
    
    -- Define different neighbors for even and odd rows in offset coordinates
    if r % 2 == 0 then
        -- Even row neighbors
        neighbors = {
            {q+1, r}, {q, r-1}, {q-1, r-1},
            {q-1, r}, {q-1, r+1}, {q, r+1}
        }
    else
        -- Odd row neighbors
        neighbors = {
            {q+1, r}, {q+1, r-1}, {q, r-1},
            {q-1, r}, {q, r+1}, {q+1, r+1}
        }
    end
    
    -- Filter neighbors to ensure they're within grid bounds
    local validNeighbors = {}
    for _, neighbor in ipairs(neighbors) do
        local nq, nr = neighbor[1], neighbor[2]
        if nq >= 0 and nq < self.GRID_SIZE and nr >= 0 and nr < self.GRID_SIZE then
            table.insert(validNeighbors, neighbor)
        end
    end
    
    return validNeighbors
end

-- Calculate valid moves for a ship from its current position
function Combat:calculateValidMoves(battle, ship)
    local q, r = ship.position[1], ship.position[2]
    local movesRemaining = ship.movesRemaining
    local validMoves = {}
    
    -- Use a breadth-first search to find all reachable hexes
    local queue = {{q, r, 0}} -- {q, r, distance}
    local visited = {[q .. "," .. r] = true}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local cq, cr, distance = current[1], current[2], current[3]
        
        if distance > 0 and distance <= movesRemaining then
            table.insert(validMoves, {cq, cr})
        end
        
        -- Only explore neighbors if within movement range
        if distance < movesRemaining then
            local neighbors = self:getHexNeighbors(cq, cr)
            for _, neighbor in ipairs(neighbors) do
                local nq, nr = neighbor[1], neighbor[2]
                local key = nq .. "," .. nr
                
                -- Skip if already visited
                if not visited[key] then
                    -- Skip if occupied by a ship
                    if battle.grid[nq][nr].content ~= "ship" then
                        visited[key] = true
                        table.insert(queue, {nq, nr, distance + 1})
                    end
                end
            end
        end
    end
    
    return validMoves
end

-- Move a ship to a new position
function Combat:moveShip(battle, ship, newQ, newR)
    -- Store old position for distance calculation
    local oldQ, oldR = ship.position[1], ship.position[2]
    
    -- Clear ship from old position
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            if battle.grid[q][r].ship == ship then
                battle.grid[q][r].ship = nil
                battle.grid[q][r].content = "empty"
                battle.grid[q][r].isPlayerShip = false
                battle.grid[q][r].isEnemyShip = false
            end
        end
    end
    
    -- Update ship position
    ship.position = {newQ, newR}
    
    -- Place ship at new position
    self:placeShipOnGrid(battle.grid, ship, battle)
    
    -- Update moves remaining
    local distance = self:hexDistance(oldQ, oldR, newQ, newR)
    ship.movesRemaining = ship.movesRemaining - distance
    
    return true
end

-- Calculate distance between two hexes in the offset coordinate system
function Combat:hexDistance(q1, r1, q2, r2)
    -- Convert from offset coordinates to cube coordinates
    local x1, y1, z1 = self:offsetToCube(q1, r1)
    local x2, y2, z2 = self:offsetToCube(q2, r2)
    
    -- Use cube coordinate distance formula
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2), math.abs(z1 - z2))
end

-- Convert offset coordinates to cube coordinates
function Combat:offsetToCube(q, r)
    local parity = r % 2  -- r mod 2, gives 0 for even rows and 1 for odd rows
    local x = q - (r - parity) / 2
    local z = r
    local y = -x - z
    return x, y, z
end

-- Calculate direction vector from one hex to another
function Combat:calculateDirectionVector(fromQ, fromR, toQ, toR)
    -- Normalize the direction
    local dirQ = toQ - fromQ
    local dirR = toR - fromR
    
    -- Simple normalization
    local length = math.sqrt(dirQ*dirQ + dirR*dirR)
    if length > 0 then
        dirQ = dirQ / length
        dirR = dirR / length
    end
    
    return {q = dirQ, r = dirR}
end

-- Get maximum Sail Points for a ship class
function Combat:getMaxSP(shipClass)
    -- Max SP values based on ship class as defined in RevisedCombatSystem.md
    if shipClass == "sloop" then
        return 5
    elseif shipClass == "brigantine" then
        return 4
    elseif shipClass == "galleon" then
        return 3
    else
        return 5 -- Default to sloop if unknown class
    end
end

-- Calculate the SP cost of a planned maneuver
function Combat:calculateSPCost(ship, targetQ, targetR, targetOrientation)
    local spCost = 0
    
    -- Movement cost: SP_COST_MOVE_HEX per hex moved
    if targetQ and targetR then
        local distance = self:hexDistance(ship.position[1], ship.position[2], targetQ, targetR)
        spCost = spCost + (distance * Constants.COMBAT.SP_COST_MOVE_HEX)
    end
    
    -- Rotation cost: SP_COST_ROTATE_60 per 60° orientation change
    if targetOrientation ~= nil then
        -- Calculate the shortest rotation distance between current and target orientation
        local currentOrientation = ship.orientation
        local rotationDistance = math.min(
            math.abs(targetOrientation - currentOrientation),
            6 - math.abs(targetOrientation - currentOrientation)
        )
        spCost = spCost + (rotationDistance * Constants.COMBAT.SP_COST_ROTATE_60)
    end
    
    return spCost
end

-- Convert hex coordinates to screen coordinates
function Combat:hexToScreen(q, r)
    -- For pointy-top hexagons
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid size in pixels
    -- For a pointy-top hex grid with brick layout pattern
    local gridWidthInHexes = self.GRID_SIZE
    local gridHeightInHexes = self.GRID_SIZE
    
    -- Total width = width of a column of hexes * number of columns
    local totalGridWidth = hexWidth * gridWidthInHexes
    -- Total height = height of a hex * number of rows, accounting for overlap
    local totalGridHeight = hexHeight * 0.75 * gridHeightInHexes + hexHeight * 0.25
    
    -- Make sure we have proper grid center coordinates
    -- This should be exactly the center of the available play area
    local centerX = self.gridOffsetX
    local centerY = self.gridOffsetY
    
    -- Calculate grid origin (top-left corner of the hex grid itself)
    -- This centers the actual hex grid within whatever panel is showing it
    local gridOriginX = centerX - (totalGridWidth / 2)
    local gridOriginY = centerY - (totalGridHeight / 2)
    
    -- Calculate the position for this specific hex
    local hexX = gridOriginX + (q * hexWidth)
    local hexY = gridOriginY + (r * hexHeight * 0.75)
    
    -- Apply horizontal offset for odd rows (brick pattern layout)
    if r % 2 == 1 then
        hexX = hexX + (hexWidth / 2)
    end
    
    return hexX, hexY
end

function Combat:startNewTurn(battle)
    -- Increment turn counter
    battle.turnCount = battle.turnCount + 1
    
    -- Replenish Sail Points and Crew Points for both ships
    self:replenishResources(battle.playerShip)
    self:replenishResources(battle.enemyShip)
    
    -- Clear planned moves and rotations
    battle.playerShip.plannedMove = nil
    battle.playerShip.plannedRotation = nil
    battle.enemyShip.plannedMove = nil
    battle.enemyShip.plannedRotation = nil
    
    -- Reset temporary planning variables in the Combat module
    self.plannedRotation = nil
    self.hoveredMoveHex = nil
    self.plannedMoveHex = nil
    self.rotationButtons = nil
    self.confirmManeuverButton = nil
    
    -- Clear any temporary turn-based effects
    battle.playerShip.evadeScore = 0
    battle.enemyShip.evadeScore = 0
    
    -- Set the initial phase for the new turn - enemy planning happens internally
    battle.phase = "playerMovePlanning"
    
    print("Starting new turn " .. battle.turnCount)
end

-- Replenish a ship's resources (SP and CP) at the start of a turn
function Combat:replenishResources(ship)
    -- Replenish Sail Points to maximum
    ship.currentSP = ship.maxSP
    
    -- Replenish Crew Points to maximum
    ship.crewPoints = ship.maxCrewPoints
    
    -- Reset action flags
    ship.hasActed = false
end

-- Process enemy ship's planning phase (internal AI logic)
function Combat:processEnemyPlanning(battle)
    -- Get enemy and player ships
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Get enemy position and orientation
    local enemyQ, enemyR = enemyShip.position[1], enemyShip.position[2]
    local enemyOrientation = enemyShip.orientation
    
    -- Calculate health percentage for strategy selection
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Choose strategy based on health
    local strategy
    if healthPercent < 0.3 then
        strategy = "defensive" -- Run away when critically damaged
    elseif healthPercent < 0.7 then
        strategy = "cautious"  -- Maintain medium distance when moderately damaged
    else
        strategy = "aggressive" -- Get close when healthy
    end
    
    -- Plan target destination and orientation
    local targetQ, targetR, targetOrientation = self:planEnemyManeuver(battle, strategy, enemyShip)
    
    -- Calculate SP cost for the planned maneuver
    local moveCost = self:calculateSPCost(enemyShip, targetQ, targetR, nil)
    local rotateCost = self:calculateSPCost(enemyShip, nil, nil, targetOrientation)
    local totalCost = moveCost + rotateCost
    
    -- Check if the maneuver is affordable
    if totalCost <= enemyShip.currentSP then
        -- Store the planned move and rotation
        enemyShip.plannedMove = {targetQ, targetR}
        enemyShip.plannedRotation = targetOrientation
        print("Enemy planning: Move to " .. targetQ .. "," .. targetR .. ", rotate to " .. targetOrientation .. " (SP cost: " .. totalCost .. ")")
    else
        -- If unaffordable, try simpler fallback options
        print("Enemy's preferred maneuver costs " .. totalCost .. " SP, which exceeds available " .. enemyShip.currentSP .. " SP. Using fallback plan.")
        
        -- Try just rotation, no movement
        if rotateCost <= enemyShip.currentSP then
            enemyShip.plannedMove = {enemyQ, enemyR} -- Stay in place
            enemyShip.plannedRotation = targetOrientation
            print("Enemy fallback plan: Stay in place, rotate to " .. targetOrientation .. " (SP cost: " .. rotateCost .. ")")
        
        -- Try just movement, no rotation
        elseif moveCost <= enemyShip.currentSP then
            enemyShip.plannedMove = {targetQ, targetR}
            enemyShip.plannedRotation = enemyOrientation -- Keep current orientation
            print("Enemy fallback plan: Move to " .. targetQ .. "," .. targetR .. ", keep orientation " .. enemyOrientation .. " (SP cost: " .. moveCost .. ")")
        
        -- If still unaffordable, do nothing
        else
            enemyShip.plannedMove = {enemyQ, enemyR} -- Stay in place
            enemyShip.plannedRotation = enemyOrientation -- Keep current orientation
            print("Enemy fallback plan: Do nothing (insufficient SP for any meaningful maneuver)")
        end
    end
end

-- Plan the enemy's maneuver based on the selected strategy
function Combat:planEnemyManeuver(battle, strategy, enemyShip)
    local playerShip = battle.playerShip
    local enemyQ, enemyR = enemyShip.position[1], enemyShip.position[2]
    local playerQ, playerR = playerShip.position[1], playerShip.position[2]
    
    -- Calculate direction to player
    local directionToPlayer = self:calculateDirectionVector(enemyQ, enemyR, playerQ, playerR)
    
    -- Calculate distance to player
    local distanceToPlayer = self:hexDistance(enemyQ, enemyR, playerQ, playerR)
    
    -- Plan target position
    local targetQ, targetR
    
    if strategy == "defensive" then
        -- Move away from player
        targetQ = enemyQ - directionToPlayer.q
        targetR = enemyR - directionToPlayer.r
        
        -- Clamp to grid bounds
        targetQ = math.max(0, math.min(self.GRID_SIZE - 1, targetQ))
        targetR = math.max(0, math.min(self.GRID_SIZE - 1, targetR))
        
    elseif strategy == "cautious" then
        -- Maintain medium distance (3 hexes) from player
        if distanceToPlayer < 3 then
            -- Too close, move away a bit
            targetQ = enemyQ - directionToPlayer.q
            targetR = enemyR - directionToPlayer.r
        elseif distanceToPlayer > 3 then
            -- Too far, move closer a bit
            targetQ = enemyQ + directionToPlayer.q
            targetR = enemyR + directionToPlayer.r
        else
            -- Just right, strafe around player
            -- Simple strafing: move perpendicular to player direction
            targetQ = enemyQ + directionToPlayer.r
            targetR = enemyR - directionToPlayer.q
        end
        
        -- Clamp to grid bounds
        targetQ = math.max(0, math.min(self.GRID_SIZE - 1, targetQ))
        targetR = math.max(0, math.min(self.GRID_SIZE - 1, targetR))
        
    else -- "aggressive"
        -- Move towards player, but stop 1 hex away (for firing)
        if distanceToPlayer > 2 then
            targetQ = enemyQ + directionToPlayer.q
            targetR = enemyR + directionToPlayer.r
        else
            -- Already close enough, stay in place
            targetQ = enemyQ
            targetR = enemyR
        end
    end
    
    -- Round to nearest integer for hex coordinates
    targetQ = math.floor(targetQ + 0.5)
    targetR = math.floor(targetR + 0.5)
    
    -- Plan target orientation - face towards player
    local targetOrientation = self:calculateOrientationTowards(enemyQ, enemyR, playerQ, playerR)
    
    return targetQ, targetR, targetOrientation
end

-- Calculate the orientation needed to face from one hex towards another
function Combat:calculateOrientationTowards(fromQ, fromR, toQ, toR)
    -- Convert to cube coordinates
    local fromX, fromY, fromZ = self:offsetToCube(fromQ, fromR)
    local toX, toY, toZ = self:offsetToCube(toQ, toR)
    
    -- Calculate direction vector in cube coordinates
    local dirX = toX - fromX
    local dirY = toY - fromY
    local dirZ = toZ - fromZ
    
    -- Normalize to get the primary direction
    local length = math.max(math.abs(dirX), math.abs(dirY), math.abs(dirZ))
    if length > 0 then
        dirX = dirX / length
        dirY = dirY / length
        dirZ = dirZ / length
    end
    
    -- Map the direction to the closest of the 6 orientations
    -- This is a simple mapping based on the angle
    local angle = math.atan2(dirY, dirX)
    local orientation = math.floor((angle + math.pi) / (math.pi/3)) % 6
    
    return orientation
end

-- Move to the next phase of combat
function Combat:advanceToNextPhase(battle)
    -- The phase progression according to RevisedCombatSystem.md:
    -- 1. Start of Turn (replenish resources)
    -- 2. Enemy Planning Phase (internal)
    -- 3. Player Planning Phase (Movement & Rotation) - "playerMovePlanning"
    -- 4. Resolution Phase (Maneuver) - "maneuverResolution"
    -- 5. Player Planning Phase (Action) - "playerActionPlanning"
    -- 6. Resolution Phase (Action) - "actionResolution" or "displayingResult"
    -- 7. End of Turn -> back to 1
    
    -- Current phase determines the next phase
    if battle.phase == "playerMovePlanning" then
        -- After player commits a movement plan, advance to maneuver resolution
        battle.phase = "maneuverResolution"
        
        -- Immediately process the maneuver resolution (with animation in the draw function)
        self:processManeuverResolution(battle)
        
    elseif battle.phase == "maneuverResolution" then
        -- After maneuvers resolve, advance to player action planning
        battle.phase = "playerActionPlanning"
        
    elseif battle.phase == "playerActionPlanning" then
        -- This transition happens when player confirms an action
        battle.phase = "actionResolution"
        
    elseif battle.phase == "actionResolution" then
        -- After action resolution, show results
        battle.phase = "displayingResult"
        
    elseif battle.phase == "displayingResult" then
        -- After player dismisses results, there could be more enemy actions
        -- or we end the turn
        -- For now, just end the turn
        self:startNewTurn(battle)
        
        -- Process enemy planning for the new turn
        self:processEnemyPlanning(battle)
    end
    
    print("Combat phase advanced to: " .. battle.phase)
end

-- Process maneuver resolution phase
function Combat:processManeuverResolution(battle)
    -- Check if both ships have planned moves and rotations
    if not battle.playerShip.plannedMove or not battle.playerShip.plannedRotation or
       not battle.enemyShip.plannedMove or not battle.enemyShip.plannedRotation then
        print("Cannot process maneuver resolution: Missing planned moves or rotations")
        return false
    end
    
    -- Extract planned moves and rotations
    local playerStartQ, playerStartR = battle.playerShip.position[1], battle.playerShip.position[2]
    local playerTargetQ, playerTargetR = battle.playerShip.plannedMove[1], battle.playerShip.plannedMove[2]
    local playerStartOrientation = battle.playerShip.orientation
    local playerTargetOrientation = battle.playerShip.plannedRotation
    
    local enemyStartQ, enemyStartR = battle.enemyShip.position[1], battle.enemyShip.position[2]
    local enemyTargetQ, enemyTargetR = battle.enemyShip.plannedMove[1], battle.enemyShip.plannedMove[2]
    local enemyStartOrientation = battle.enemyShip.orientation
    local enemyTargetOrientation = battle.enemyShip.plannedRotation
    
    -- 1. Update orientations immediately
    battle.playerShip.orientation = playerTargetOrientation
    battle.enemyShip.orientation = enemyTargetOrientation
    
    -- 2. Check for collision at target destination
    local collision = false
    local playerFinalQ, playerFinalR = playerTargetQ, playerTargetR
    local enemyFinalQ, enemyFinalR = enemyTargetQ, enemyTargetR
    
    if playerTargetQ == enemyTargetQ and playerTargetR == enemyTargetR then
        -- Collision detected - both ships trying to move to the same hex
        collision = true
        
        -- Simple collision rule: both ships stop 1 hex short along their path
        -- Calculate player's adjusted position
        local playerDirection = self:calculateDirectionVector(playerStartQ, playerStartR, playerTargetQ, playerTargetR)
        local playerDistance = self:hexDistance(playerStartQ, playerStartR, playerTargetQ, playerTargetR)
        
        if playerDistance > 1 then
            -- If moving more than 1 hex, stop 1 hex short
            playerFinalQ = math.floor(playerTargetQ - playerDirection.q + 0.5)
            playerFinalR = math.floor(playerTargetR - playerDirection.r + 0.5)
        else
            -- If only moving 1 hex, stay in place
            playerFinalQ, playerFinalR = playerStartQ, playerStartR
        end
        
        -- Calculate enemy's adjusted position
        local enemyDirection = self:calculateDirectionVector(enemyStartQ, enemyStartR, enemyTargetQ, enemyTargetR)
        local enemyDistance = self:hexDistance(enemyStartQ, enemyStartR, enemyTargetQ, enemyTargetR)
        
        if enemyDistance > 1 then
            -- If moving more than 1 hex, stop 1 hex short
            enemyFinalQ = math.floor(enemyTargetQ - enemyDirection.q + 0.5)
            enemyFinalR = math.floor(enemyTargetR - enemyDirection.r + 0.5)
        else
            -- If only moving 1 hex, stay in place
            enemyFinalQ, enemyFinalR = enemyStartQ, enemyStartR
        end
        
        print("Collision detected! Ships stopped short of destination.")
    end
    
    -- 3. Calculate actual SP costs for the moves performed
    local playerActualMoveCost = self:calculateSPCost(
        {position = {playerStartQ, playerStartR}, orientation = playerStartOrientation},
        playerFinalQ, playerFinalR, nil
    )
    
    local playerActualRotationCost = self:calculateSPCost(
        {position = {playerStartQ, playerStartR}, orientation = playerStartOrientation},
        nil, nil, playerTargetOrientation
    )
    
    local enemyActualMoveCost = self:calculateSPCost(
        {position = {enemyStartQ, enemyStartR}, orientation = enemyStartOrientation},
        enemyFinalQ, enemyFinalR, nil
    )
    
    local enemyActualRotationCost = self:calculateSPCost(
        {position = {enemyStartQ, enemyStartR}, orientation = enemyStartOrientation},
        nil, nil, enemyTargetOrientation
    )
    
    -- 4. Deduct SP
    battle.playerShip.currentSP = math.max(0, battle.playerShip.currentSP - (playerActualMoveCost + playerActualRotationCost))
    battle.enemyShip.currentSP = math.max(0, battle.enemyShip.currentSP - (enemyActualMoveCost + enemyActualRotationCost))
    
    -- 5. Remove ships from their old grid positions
    self:clearShipFromGrid(battle.grid, battle.playerShip)
    self:clearShipFromGrid(battle.grid, battle.enemyShip)
    
    -- 6. Update ship positions
    battle.playerShip.position = {playerFinalQ, playerFinalR}
    battle.enemyShip.position = {enemyFinalQ, enemyFinalR}
    
    -- 7. Place ships at their new grid positions
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- 8. Clear planned moves and rotations (no longer needed)
    battle.playerShip.plannedMove = nil
    battle.playerShip.plannedRotation = nil
    battle.enemyShip.plannedMove = nil
    battle.enemyShip.plannedRotation = nil
    
    -- 9. Advance to next phase (Action Planning)
    self:advanceToNextPhase(battle)
    
    return true
end

function Combat:hexToScreen(q, r)
    -- For pointy-top hexagons
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid size in pixels
    -- For a pointy-top hex grid with brick layout pattern
    local gridWidthInHexes = self.GRID_SIZE
    local gridHeightInHexes = self.GRID_SIZE
    
    -- Total width = width of a column of hexes * number of columns
    local totalGridWidth = hexWidth * gridWidthInHexes
    -- Total height = height of a hex * number of rows, accounting for overlap
    local totalGridHeight = hexHeight * 0.75 * gridHeightInHexes + hexHeight * 0.25
    
    -- Make sure we have proper grid center coordinates
    -- This should be exactly the center of the available play area
    local centerX = self.gridOffsetX
    local centerY = self.gridOffsetY
    
    -- Calculate grid origin (top-left corner of the hex grid itself)
    -- This centers the actual hex grid within whatever panel is showing it
    local gridOriginX = centerX - (totalGridWidth / 2)
    local gridOriginY = centerY - (totalGridHeight / 2)
    
    -- Calculate the position for this specific hex
    local hexX = gridOriginX + (q * hexWidth)
    local hexY = gridOriginY + (r * hexHeight * 0.75)
    
    -- Apply horizontal offset for odd rows (brick pattern layout)
    if r % 2 == 1 then
        hexX = hexX + (hexWidth / 2)
    end
    
    return hexX, hexY
end

-- Update combat state
function Combat:update(dt, gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Update game logic here
    -- For now, we're just focusing on the movement mechanics
end

-- Draw the hex grid and ships
function Combat:draw(gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Define fixed UI layout constants for our 800x600 reference resolution
    local SCREEN_WIDTH = 800
    local SCREEN_HEIGHT = 600
    local TOP_BAR_HEIGHT = 30     -- Reduced height for top status bar
    local BOTTOM_BAR_HEIGHT = 80  -- Height for action buttons and instructions
    
    -- Calculate available space for the battle grid
    -- Move grid up slightly to make more room for action feedback panel
    local GRID_TOP = TOP_BAR_HEIGHT + 5  -- Reduced top margin
    local GRID_BOTTOM = SCREEN_HEIGHT - BOTTOM_BAR_HEIGHT - 15 -- Added more space at bottom
    local GRID_HEIGHT = GRID_BOTTOM - GRID_TOP
    
    -- Define sidebar width
    local sidebarWidth = 140
    
    -- Calculate true hex dimensions for a pointy-top hex
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid dimensions more accurately
    -- For a pointy-top hex grid with brick layout pattern
    local totalGridWidth = hexWidth * self.GRID_SIZE
    local totalGridHeight = (hexHeight * 0.75 * self.GRID_SIZE) + (hexHeight * 0.25)
    
    -- Store dimensions for other methods
    self.gridScreenHeight = GRID_HEIGHT
    self.gridScreenWidth = totalGridWidth
    
    -- Define available center area (excluding sidebars)
    local availableWidth = SCREEN_WIDTH - (sidebarWidth * 2)
    
    -- Center coordinates of the play area (excluding sidebars)
    local centerX = SCREEN_WIDTH / 2
    local centerY = GRID_TOP + ((GRID_BOTTOM - GRID_TOP) / 2)
    
    -- Store these coordinates for the grid drawing functions
    self.gridOffsetX = centerX
    self.gridOffsetY = centerY
    
    -- Save play area constants for other functions
    self.layoutConstants = {
        topBarHeight = TOP_BAR_HEIGHT,
        gridTop = GRID_TOP,
        gridBottom = GRID_BOTTOM,
        sidebarWidth = sidebarWidth,
        bottomBarHeight = BOTTOM_BAR_HEIGHT,
        screenWidth = SCREEN_WIDTH,
        screenHeight = SCREEN_HEIGHT,
        availableWidth = availableWidth
    }
    
    -- Draw background and grid
    self:drawBackground(centerX, centerY, SCREEN_WIDTH, SCREEN_HEIGHT, gameState.settings.debug)
    self:drawGridBackground(GRID_TOP, GRID_HEIGHT, sidebarWidth, availableWidth)
    self:drawHexes(battle, gameState.settings.debug)
    
    -- Draw ships on top of hexes for better visibility
    self:drawShips(battle)
    
    -- Draw UI elements using the layout constants
    self:drawUI(gameState)
    
    -- Draw debug info if needed
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Grid offset: " .. self.gridOffsetX .. ", " .. self.gridOffsetY, 10, 550)
        love.graphics.print("Grid dims: " .. totalGridWidth .. "x" .. totalGridHeight, 10, 570)
        love.graphics.print("Play area: " .. GRID_TOP .. "-" .. GRID_BOTTOM, 200, 570)
    end
end

-- Draw the battle background
function Combat:drawBackground(centerX, centerY, screenWidth, screenHeight, showDebug)
    -- Draw the entire battle area background first
    love.graphics.setColor(Constants.COLORS.UI_BACKGROUND) -- Very dark blue/black background
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- If debug mode is on, draw a small dot at the exact center for reference
    if showDebug then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", centerX, centerY, 3)
    end
end

-- Draw the grid background (sea area)
function Combat:drawGridBackground(gridTop, gridHeight, sidebarWidth, availableWidth)
    -- Calculate grid background dimensions to fill available space between sidebars
    local gridAreaWidth = availableWidth - 20  -- -20 for small margin on each side
    local gridAreaHeight = gridHeight - 20    -- -20 for small margin on top and bottom
    
    -- Calculate the top-left corner of the grid background
    local gridAreaX = sidebarWidth + 10 -- Left sidebar width + small margin
    local gridAreaY = gridTop + 10     -- Top bar + small margin
    
    -- Draw grid background (sea)
    love.graphics.setColor(Constants.COLORS.SEA) -- Dark blue water
    love.graphics.rectangle("fill", 
        gridAreaX, 
        gridAreaY, 
        gridAreaWidth, 
        gridAreaHeight,
        5, 5 -- Rounded corners
    )
    
    -- Grid border
    love.graphics.setColor(Constants.COLORS.SEA_BORDER) -- Lighter blue border
    love.graphics.rectangle("line", 
        gridAreaX, 
        gridAreaY, 
        gridAreaWidth, 
        gridAreaHeight,
        5, 5 -- Rounded corners
    )
end

-- Draw grid hexes
function Combat:drawHexes(battle, showDebug)
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            local x, y = self:hexToScreen(q, r)
            
            -- Determine hex color based on content
            if battle.grid[q][r].isPlayerShip then
                -- Green for player ship (more transparent)
                love.graphics.setColor(Constants.COLORS.PLAYER_SHIP[1], Constants.COLORS.PLAYER_SHIP[2], 
                                      Constants.COLORS.PLAYER_SHIP[3], 0.5)
            elseif battle.grid[q][r].isEnemyShip then
                -- Red for enemy ship (more transparent)
                love.graphics.setColor(Constants.COLORS.ENEMY_SHIP[1], Constants.COLORS.ENEMY_SHIP[2], 
                                      Constants.COLORS.ENEMY_SHIP[3], 0.5)
            elseif self.plannedMoveHex and self.plannedMoveHex[1] == q and self.plannedMoveHex[2] == r then
                -- Green/yellow pulsing for planned destination
                local pulse = math.abs(math.sin(love.timer.getTime() * 2))
                love.graphics.setColor(0.3 + pulse * 0.6, 0.7 + pulse * 0.3, 0.2, 0.6 + pulse * 0.4)
            elseif self.hoveredHex and self.hoveredHex[1] == q and self.hoveredHex[2] == r then
                love.graphics.setColor(Constants.COLORS.HOVER) -- Yellow for hover
            elseif self.selectedHex and self.selectedHex[1] == q and self.selectedHex[2] == r then
                love.graphics.setColor(Constants.COLORS.SELECTED) -- Cyan for selected
            elseif self:isValidMove(q, r) then
                love.graphics.setColor(Constants.COLORS.VALID_MOVE) -- Light blue for valid moves
            else
                love.graphics.setColor(Constants.COLORS.EMPTY_WATER) -- Blue for empty water
            end
            
            -- Draw hex
            self:drawHex(x, y)
            
            -- Draw grid coordinates for debugging
            if showDebug then
                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.print(q .. "," .. r, x - 10, y)
            end
        end
    end
end

-- Draw a single hexagon at position x,y
function Combat:drawHex(x, y)
    local vertices = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i + math.pi / 6 -- Pointy-top orientation
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Fill hex
    love.graphics.polygon("fill", vertices)
    
    -- Draw hex outline
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.polygon("line", vertices)
end

-- Check if hex coordinates are in the valid moves list
function Combat:isValidMove(q, r)
    -- Debug logging
    print("Checking if " .. q .. "," .. r .. " is a valid move. Current valid moves: " .. #self.validMoves)
    
    if not self.validMoves or #self.validMoves == 0 then
        print("No valid moves available")
        return false
    end
    
    for i, move in ipairs(self.validMoves) do
        if move[1] == q and move[2] == r then
            print("Valid move found: " .. q .. "," .. r .. " (index " .. i .. ")")
            return true
        end
    end
    
    print("Not a valid move: " .. q .. "," .. r)
    return false
end

-- Draw ships with proper shapes and orientations
function Combat:drawShips(battle)
    -- Draw player ship
    local playerShip = battle.playerShip
    local pq, pr = playerShip.position[1], playerShip.position[2]
    
    -- Check if player ship is selected for movement
    local isSelected = false
    if self.selectedHex and 
       self.selectedHex[1] == pq and 
       self.selectedHex[2] == pr then
        isSelected = true
    end
    
    -- Draw player ship based on class using the multi-hex approach
    self:drawShipByClass(playerShip, true, isSelected, battle)
    
    -- Draw enemy ship
    local enemyShip = battle.enemyShip
    
    -- Draw enemy ship based on class using the multi-hex approach
    self:drawShipByClass(enemyShip, false, false, battle)
end

-- Draw a ship with appropriate shape based on class and orientation
-- This is the main function for drawing ships on the combat grid
function Combat:drawShipByClass(ship, isPlayer, isSelected, battle)
    local shipClass = ship.class
    local orientation = ship.orientation
    local anchorQ, anchorR = ship.position[1], ship.position[2]
    local scale = 1.0
    
    -- Set base color based on player/enemy
    local baseColor = isPlayer and Constants.COLORS.PLAYER_SHIP or Constants.COLORS.ENEMY_SHIP
    local outlineColor = {1, 1, 1, 0.8}
    
    -- Get the ship's shape and transform it based on orientation
    local shape = self.shipDefinitions[shipClass].shape
    local transformedShape = self:transformShapeByOrientation(shape, orientation)
    
    -- Draw each hex that the ship occupies
    for _, offset in ipairs(transformedShape) do
        local hexQ = anchorQ + offset[1]
        local hexR = anchorR + offset[2]
        
        -- Check if within grid bounds
        if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
            -- Draw hex outline to indicate ship occupation
            local hexX, hexY = self:hexToScreen(hexQ, hexR)
            
            -- Draw colored hex background for occupied hexes
            local hexColor = isPlayer and {0.2, 0.8, 0.2, 0.3} or {0.8, 0.2, 0.2, 0.3}
            love.graphics.setColor(hexColor)
            self:drawHex(hexX, hexY)
            
            -- Draw hex border with ship color
            love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.7)
            self:drawHexOutline(hexX, hexY)
        end
    end
    
    -- Calculate the ship's center position 
    local anchorOffset = self.shipDefinitions[shipClass].anchorOffset or {0, 0}
    local centerHexQ = anchorQ + anchorOffset[1]
    local centerHexR = anchorR + anchorOffset[2]
    local centerX, centerY = self:hexToScreen(centerHexQ, centerHexR)
    
    -- Draw the ship sprite at the center position
    local sprite = self.shipSprites[shipClass]
    
    -- Angle based on orientation (60 degrees per orientation step)
    -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
    local angle = orientation * math.pi / 3 + math.pi / 6
    
    if sprite then
        -- Draw the sprite with proper orientation and scale
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Scale the sprite to fit within the hex
        local spriteWidth = sprite:getWidth()
        local spriteHeight = sprite:getHeight()
        local maxDimension = self.HEX_RADIUS * 1.5
        
        -- Calculate scale based on sprite size and hex size
        local scaleX = maxDimension / spriteWidth
        local scaleY = maxDimension / spriteHeight
        local spriteScale = math.min(scaleX, scaleY) * scale
        
        -- Draw rotated sprite centered on the ship's position
        love.graphics.draw(
            sprite, 
            centerX, centerY, 
            angle, 
            spriteScale, spriteScale, 
            spriteWidth / 2, spriteHeight / 2
        )
    else
        -- Use the fallback geometric shape rendering if sprite is missing
        self:drawShipFallbackShape(centerX, centerY, shipClass, orientation, baseColor, outlineColor, scale)
    end
    
    -- Ship sprite is already rotated to show orientation - no need for extra indicators
    
    -- Draw a selection indicator if the ship is selected
    if isSelected then
        -- Draw a highlight around the entire ship
        for _, offset in ipairs(transformedShape) do
            local hexQ = anchorQ + offset[1]
            local hexR = anchorR + offset[2]
            
            if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
                local x, y = self:hexToScreen(hexQ, hexR)
                love.graphics.setColor(1, 1, 0, 0.5) -- Yellow highlight
                self:drawHexOutline(x, y)
            end
        end
        
        -- Draw a pulsing highlight effect on the anchor hex
        local anchorX, anchorY = self:hexToScreen(anchorQ, anchorR)
        local pulseScale = 1.0 + math.sin(love.timer.getTime() * 4) * 0.1
        love.graphics.setColor(1, 1, 0, 0.7) -- Yellow highlight
        love.graphics.circle("line", anchorX, anchorY, self.HEX_RADIUS * 0.5 * pulseScale)
    end
end

-- Draw a hex outline without fill
function Combat:drawHexOutline(x, y)
    local vertices = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i + math.pi / 6 -- Pointy-top orientation
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Draw hex outline
    love.graphics.polygon("line", vertices)
end

-- Draw a ship icon for UI elements like sidebars
function Combat:drawShipIconForUI(x, y, shipClass, orientation, isPlayer, isSelected, scale)
    -- Set default scale if not provided
    scale = scale or 1.0
    
    -- Set base color based on player/enemy
    local baseColor = isPlayer and Constants.COLORS.PLAYER_SHIP or Constants.COLORS.ENEMY_SHIP
    local outlineColor = {1, 1, 1, 0.8}
    
    -- Draw the ship sprite at the center position if available
    local sprite = self.shipSprites[shipClass]
    
    -- Angle based on orientation (60 degrees per orientation step)
    -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
    local angle = orientation * math.pi / 3 + math.pi / 6
    
    if sprite then
        -- Draw the sprite with proper orientation and scale
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Scale the sprite to fit within the icon area
        local spriteWidth = sprite:getWidth()
        local spriteHeight = sprite:getHeight()
        local maxDimension = self.HEX_RADIUS * 1.5 * scale
        
        -- Calculate scale based on sprite size and desired icon size
        local scaleX = maxDimension / spriteWidth
        local scaleY = maxDimension / spriteHeight
        local spriteScale = math.min(scaleX, scaleY)
        
        -- Draw rotated sprite
        love.graphics.draw(
            sprite, 
            x, y, 
            angle, 
            spriteScale, spriteScale, 
            spriteWidth / 2, spriteHeight / 2
        )
    else
        -- Use fallback geometric shape if sprite is missing
        self:drawShipFallbackShape(x, y, shipClass, orientation, baseColor, outlineColor, scale)
    end
    
    -- Ship sprite is already rotated to show orientation
    -- No need for additional direction indicators as the sprite rotation is sufficient
    
    -- Draw selection indicator if needed
    if isSelected then
        love.graphics.setColor(1, 1, 0, 0.7) -- Yellow highlight
        love.graphics.circle("line", x, y, self.HEX_RADIUS * 0.8 * scale)
    end
end

-- Fallback shape rendering for ships without sprites
function Combat:drawShipFallbackShape(x, y, shipClass, orientation, baseColor, outlineColor, scale)
    -- Set default scale if not provided
    scale = scale or 1.0
    
    -- Calculate ship points based on orientation
    local points = {}
    
    if shipClass == "sloop" then
        -- Simple triangular shape for sloop
        local size = self.HEX_RADIUS * 0.7 * scale
        
        -- Define the triangle points based on orientation
        if orientation == 0 then -- North
            points = {
                x, y - size,          -- Bow
                x - size * 0.7, y + size * 0.5,  -- Port (left) corner
                x + size * 0.7, y + size * 0.5   -- Starboard (right) corner
            }
        elseif orientation == 1 then -- Northeast
            points = {
                x + size * 0.87, y - size * 0.5,  -- Bow
                x - size * 0.5, y - size * 0.87,  -- Port corner
                x + size * 0.5, y + size * 0.87   -- Starboard corner
            }
        elseif orientation == 2 then -- Southeast
            points = {
                x + size * 0.87, y + size * 0.5,  -- Bow
                x + size * 0.5, y - size * 0.87,  -- Port corner
                x - size * 0.5, y + size * 0.87   -- Starboard corner
            }
        elseif orientation == 3 then -- South
            points = {
                x, y + size,          -- Bow
                x + size * 0.7, y - size * 0.5,  -- Port corner
                x - size * 0.7, y - size * 0.5   -- Starboard corner
            }
        elseif orientation == 4 then -- Southwest
            points = {
                x - size * 0.87, y + size * 0.5,  -- Bow
                x + size * 0.5, y + size * 0.87,  -- Port corner
                x - size * 0.5, y - size * 0.87   -- Starboard corner
            }
        elseif orientation == 5 then -- Northwest
            points = {
                x - size * 0.87, y - size * 0.5,  -- Bow
                x - size * 0.5, y + size * 0.87,  -- Port corner
                x + size * 0.5, y - size * 0.87   -- Starboard corner
            }
        end
        
        -- Draw the ship
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", points)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", points)
        
    elseif shipClass == "brigantine" then
        -- More complex rectangular shape for brigantine
        local sizeX = self.HEX_RADIUS * 0.85 * scale
        local sizeY = self.HEX_RADIUS * 0.5 * scale
        
        -- Create a rectangle and rotate it based on orientation
        local points = {
            -sizeX, -sizeY,   -- Top-left
            sizeX, -sizeY,    -- Top-right
            sizeX, sizeY,     -- Bottom-right
            -sizeX, sizeY     -- Bottom-left
        }
        
        -- Adjust rotation based on orientation
        -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
        local angle = orientation * math.pi / 3 + math.pi / 6
        
        -- Rotate and translate points
        local rotatedPoints = {}
        for i = 1, #points, 2 do
            local px, py = points[i], points[i+1]
            
            -- Rotate
            local rx = px * math.cos(angle) - py * math.sin(angle)
            local ry = px * math.sin(angle) + py * math.cos(angle)
            
            -- Translate
            rotatedPoints[i] = x + rx
            rotatedPoints[i+1] = y + ry
        end
        
        -- Draw the ship
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", rotatedPoints)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", rotatedPoints)
        
    elseif shipClass == "galleon" then
        -- Big ship with kite shape for galleon
        local size = self.HEX_RADIUS * 0.9 * scale
        
        -- Kite shape points
        local points = {
            0, -size,        -- Top (bow)
            size/2, 0,       -- Right (midship)
            0, size,         -- Bottom (stern)
            -size/2, 0       -- Left (midship)
        }
        
        -- Adjust rotation based on orientation
        -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
        local angle = orientation * math.pi / 3 + math.pi / 6
        
        -- Rotate and translate points
        local rotatedPoints = {}
        for i = 1, #points, 2 do
            local px, py = points[i], points[i+1]
            
            -- Rotate
            local rx = px * math.cos(angle) - py * math.sin(angle)
            local ry = px * math.sin(angle) + py * math.cos(angle)
            
            -- Translate
            rotatedPoints[i] = x + rx
            rotatedPoints[i+1] = y + ry
        end
        
        -- Draw the galleon body
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", rotatedPoints)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", rotatedPoints)
    else
        -- Fallback to simple circle for unknown ship types
        love.graphics.setColor(baseColor)
        love.graphics.circle("fill", x, y, self.HEX_RADIUS * 0.7 * scale)
        love.graphics.setColor(outlineColor)
        love.graphics.circle("line", x, y, self.HEX_RADIUS * 0.7 * scale)
    end
end

-- Draw UI elements for the battle
function Combat:drawUI(gameState)
    local battle = gameState.combat
    
    -- Use layout constants from draw function
    local layout = self.layoutConstants
    if not layout then return end
    
    -- Calculate player/enemy stats
    local playerMaxHP = shipUtils.getMaxHP(battle.playerShip.class)
    local playerHP = gameState.ship.durability
    local playerHP_Percent = playerHP / playerMaxHP
    
    local enemyMaxHP = shipUtils.getMaxHP(battle.enemyShip.class)
    local enemyHP = battle.enemyShip.durability
    local enemyHP_Percent = enemyHP / enemyMaxHP
    
    -- Draw top status bar
    self:drawTopBar(battle, layout.screenWidth)
    
    -- Draw player and enemy sidebars
    self:drawPlayerSidebar(battle, gameState, playerHP, playerMaxHP, playerHP_Percent, layout)
    self:drawEnemySidebar(battle, enemyHP, enemyMaxHP, enemyHP_Percent, layout)
    
    -- Draw action feedback panel if we have a result
    local buttonsY = self:drawFeedbackPanel(battle, layout)
    
    -- Draw action buttons panel based on the game phase
    self:drawActionPanel(battle, buttonsY, layout)
    
    -- Draw instructions panel
    self:drawInstructionsPanel(battle, buttonsY, layout)
end

-- Draw the top status bar
function Combat:drawTopBar(battle, screenWidth)
    local topBarHeight = self.layoutConstants.topBarHeight
    
    -- Draw the panel background
    self:drawUIPanel(0, 0, screenWidth, topBarHeight)
    
    -- Battle status indicator (left)
    local statusColor = Constants.COLORS.PLAYER_SHIP -- Green for player turn
    local statusText = "YOUR TURN"
    if battle.turn ~= "player" then
        statusColor = Constants.COLORS.ENEMY_SHIP -- Red for enemy turn
        statusText = "ENEMY TURN"
    end
    
    love.graphics.setColor(statusColor)
    love.graphics.print(statusText, 20, 8)
    
    -- Phase indicator (center)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("PHASE: " .. battle.phase:upper(), 0, 8, screenWidth, "center")
    
    -- Turn counter (right)
    love.graphics.setColor(1, 0.9, 0.3, 0.9) -- Yellow-gold for turn counter
    love.graphics.print("TURN: " .. battle.turnCount, screenWidth - 80, 8)
end

-- Draw the player's sidebar
function Combat:drawPlayerSidebar(battle, gameState, playerHP, playerMaxHP, playerHP_Percent, layout)
    local gridTop = layout.gridTop
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    
    -- Draw the sidebar panel
    self:drawUIPanel(5, gridTop, sidebarWidth - 10, gridBottom - gridTop)
    
    -- Player ship title with class icon
    love.graphics.setColor(0.2, 0.7, 0.9, 1) -- Blue for player
    love.graphics.print("YOUR SHIP", 15, gridTop + 10)
    love.graphics.print(string.upper(battle.playerShip.class), 15, gridTop + 30)
    
    -- Ship type icon or simple ship silhouette
    self:drawShipIconForUI(75, gridTop + 65, battle.playerShip.class, 0, true, false, 0.8)
    
    -- Draw player ship HP bar
    love.graphics.setColor(Constants.COLORS.UI_TEXT)
    love.graphics.print("DURABILITY:", 15, gridTop + 120)
    self:drawProgressBar(15, gridTop + 140, sidebarWidth - 30, 16, playerHP_Percent, Constants.COLORS.HEALTH, Constants.COLORS.DAMAGE)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(playerHP .. "/" .. playerMaxHP, 50, gridTop + 142)
    
    -- Draw SP and CP based on phase
    if battle.phase == "playerMovePlanning" or battle.phase == "maneuverResolution" then
        -- Show SP for movement planning phases
        self:drawSailPointsInfo(battle.playerShip, gridTop, sidebarWidth)
    else
        -- Show CP for action phases
        self:drawCrewPointsInfo(battle.playerShip, gridTop, sidebarWidth)
    end
    
    -- Draw evade score if active
    if battle.playerShip.evadeScore > 0 then
        love.graphics.setColor(0.3, 0.8, 0.9, 1)
        love.graphics.print("EVADE SCORE: " .. battle.playerShip.evadeScore, 15, gridTop + 210)
    end
    
    -- Draw week counter at bottom of player panel
    love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
    love.graphics.print("WEEK: " .. gameState.time.currentWeek, 15, gridBottom - 30)
end

-- Draw Sail Points (SP) info for a ship
function Combat:drawSailPointsInfo(ship, gridTop, sidebarWidth)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("SAIL POINTS:", 15, gridTop + 165)
    local spPercent = ship.currentSP / ship.maxSP
    self:drawProgressBar(15, gridTop + 185, sidebarWidth - 30, 16, spPercent, Constants.COLORS.BUTTON_EVADE, Constants.COLORS.UI_BORDER)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(ship.currentSP .. "/" .. ship.maxSP, 50, gridTop + 187)
    
    -- Display any planned move SP cost
    if self.plannedMoveHex and self.plannedRotation then
        local cost = self:calculateSPCost(ship, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
        if cost > 0 then
            love.graphics.setColor(1, 0.8, 0.2, 1) -- Gold/yellow for costs
            love.graphics.print("PLANNED COST: " .. cost .. " SP", 15, gridTop + 210)
        end
    end
end

-- Draw movement info for a ship (legacy function, kept for compatibility)
function Combat:drawMovementInfo(ship, gridTop, sidebarWidth)
    self:drawSailPointsInfo(ship, gridTop, sidebarWidth)
end

-- Draw crew points info for a ship
function Combat:drawCrewPointsInfo(ship, gridTop, sidebarWidth)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("CREW POINTS:", 15, gridTop + 165)
    local cpPercent = ship.crewPoints / ship.maxCrewPoints
    self:drawProgressBar(15, gridTop + 185, sidebarWidth - 30, 16, cpPercent, Constants.COLORS.GOLD, {0.5, 0.4, 0.1, 1})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(ship.crewPoints .. "/" .. ship.maxCrewPoints, 50, gridTop + 187)
end

-- Draw the enemy sidebar
function Combat:drawEnemySidebar(battle, enemyHP, enemyMaxHP, enemyHP_Percent, layout)
    local gridTop = layout.gridTop
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    local screenWidth = layout.screenWidth
    
    -- Draw the sidebar panel
    self:drawUIPanel(screenWidth - sidebarWidth + 5, gridTop, sidebarWidth - 10, gridBottom - gridTop)
    
    -- Enemy ship title
    love.graphics.setColor(0.9, 0.3, 0.3, 1) -- Red for enemy
    love.graphics.print("ENEMY SHIP", screenWidth - sidebarWidth + 15, gridTop + 10)
    love.graphics.print(string.upper(battle.enemyShip.class), screenWidth - sidebarWidth + 15, gridTop + 30)
    
    -- Draw a simple ship outline based on class
    self:drawShipIconForUI(screenWidth - sidebarWidth + 75, gridTop + 65, battle.enemyShip.class, 3, false, false, 0.8)
    
    -- Draw enemy ship HP bar
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("DURABILITY:", screenWidth - sidebarWidth + 15, gridTop + 120)
    self:drawProgressBar(screenWidth - sidebarWidth + 15, gridTop + 140, sidebarWidth - 30, 16, 
                        enemyHP_Percent, {0.2, 0.8, 0.2, 1}, {0.8, 0.2, 0.2, 1})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(enemyHP .. "/" .. enemyMaxHP, screenWidth - sidebarWidth + 50, gridTop + 142)
    
    -- Draw enemy ship additional info: SP and Evade Score
    local yPos = gridTop + 165
    
    -- Show SP in movement planning phases
    if battle.phase == "playerMovePlanning" or battle.phase == "maneuverResolution" then
        love.graphics.setColor(0.4, 0.6, 0.9, 1) -- Blue for SP
        love.graphics.print("SAIL POINTS: " .. battle.enemyShip.currentSP .. "/" .. battle.enemyShip.maxSP, 
                           screenWidth - sidebarWidth + 15, yPos)
        yPos = yPos + 25
    end
    
    -- Show evade score if it exists
    if battle.enemyShip.evadeScore > 0 then
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.print("EVADE SCORE: " .. battle.enemyShip.evadeScore, 
                           screenWidth - sidebarWidth + 15, yPos)
    end
end

-- Draw the action feedback panel
function Combat:drawFeedbackPanel(battle, layout)
    local screenWidth = layout.screenWidth
    local screenHeight = layout.screenHeight
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    local FEEDBACK_HEIGHT = Constants.UI.COMBAT.FEEDBACK_HEIGHT
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    local INSTRUCTIONS_HEIGHT = Constants.UI.COMBAT.INSTRUCTIONS_HEIGHT
    
    -- Will be set based on whether feedback is shown
    local buttonsY = 0
    
    if battle.actionResult then
        -- Position the feedback panel below the grid but keep room for buttons
        local feedbackY = gridBottom + 5
        
        -- Make sure there's room for the feedback panel and buttons
        local totalNeededHeight = FEEDBACK_HEIGHT + CONTROLS_HEIGHT + INSTRUCTIONS_HEIGHT + 10
        local availableHeight = screenHeight - gridBottom - 5
        
        if totalNeededHeight > availableHeight then
            -- Not enough space - make room by moving up
            local extraNeeded = totalNeededHeight - availableHeight
            feedbackY = feedbackY - extraNeeded
        end
        
        -- Action result panel with translucent dark background
        self:drawUIPanel(sidebarWidth + 5, feedbackY, screenWidth - (sidebarWidth * 2) - 10, FEEDBACK_HEIGHT)
        
        -- Draw the action result content
        self:drawActionResultContent(battle.actionResult, feedbackY, sidebarWidth, screenWidth)
        
        buttonsY = feedbackY + FEEDBACK_HEIGHT + 5  -- Position buttons below feedback panel
    else
        -- If no feedback, buttons go at the bottom of the grid area
        buttonsY = gridBottom + 5  -- Small gap between grid and buttons
    end
    
    return buttonsY
end

-- Draw the content of the action result panel
function Combat:drawActionResultContent(actionResult, feedbackY, sidebarWidth, screenWidth)
    -- Action title
    local title
    -- Check if action was successful or failed due to lack of crew points
    if actionResult.success == false then
        -- Failed action due to insufficient crew points
        title = actionResult.message
        love.graphics.setColor(1, 0.3, 0.3, 1)  -- Red for error message
    else
        -- Successful action
        if actionResult.action == "fire" then
            love.graphics.setColor(0.9, 0.3, 0.3, 1) -- Red for attack
            title = (actionResult.attacker == "player" and "YOU FIRED CANNONS" or "ENEMY FIRED CANNONS")
            title = title .. " - DAMAGE: " .. actionResult.damage
        elseif actionResult.action == "evade" then
            love.graphics.setColor(0.3, 0.6, 0.9, 1) -- Blue for evade
            title = (actionResult.ship == "player" and "YOU EVADED" or "ENEMY EVADED")
            title = title .. " - EVADE SCORE: " .. actionResult.evadeScore
        elseif actionResult.action == "repair" then
            love.graphics.setColor(0.3, 0.9, 0.3, 1) -- Green for repair
            title = (actionResult.ship == "player" and "YOU REPAIRED" or "ENEMY REPAIRED")
            title = title .. " - HP RESTORED: " .. actionResult.repairAmount
        end
    end
    
    -- Display title centered at top of feedback panel
    love.graphics.printf(title, sidebarWidth + 15, feedbackY + 10, screenWidth - (sidebarWidth * 2) - 30, "center")
    
    -- Skip dice display for failed actions
    if actionResult.success == false then
        -- No further content if it's just an error message
        return
    end
    
    -- Display dice rolled with visual highlights - dice that "count" will be raised
    love.graphics.setColor(1, 1, 1, 1)
    local diceX = sidebarWidth + 20
    local diceY = feedbackY + 35  -- Centered vertically in the shorter panel
    
    -- Use the new highlighted dice display that shows which dice count
    diceSystem:drawWithHighlight(actionResult.dice, diceX, diceY, 1.5)
    
    -- Display subtle outcome indicator text centered below dice
    local panelWidth = screenWidth - (sidebarWidth * 2) - 20
    local resultText = diceSystem:getResultText(actionResult.outcome)
    love.graphics.setColor(diceSystem:getResultColor(actionResult.outcome))
    love.graphics.setColor(1, 1, 1, 0.7)  -- More subtle text
    love.graphics.printf(resultText, sidebarWidth + 10, diceY + 45, panelWidth - 10, "center")
    
    -- Draw modifiers if present
    self:drawActionModifiers(actionResult.modifiers, screenWidth, sidebarWidth, diceY)
end

-- Draw the action modifiers
function Combat:drawActionModifiers(modifiers, screenWidth, sidebarWidth, diceY)
    -- If we have modifiers, display them on the right side
    if modifiers and #modifiers > 0 then
        local modX = screenWidth - sidebarWidth - 150
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("MODIFIERS:", modX, diceY + 5)
        
        for i, mod in ipairs(modifiers) do
            -- Choose color based on modifier value
            if mod.value > 0 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for positive
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for negative
            end
            
            local sign = mod.value > 0 and "+" or ""
            love.graphics.print(mod.description .. " " .. sign .. mod.value, modX, diceY + 5 + (i * 20))
        end
    end
end

-- Draw the action panel (buttons or movement controls)
function Combat:drawActionPanel(battle, buttonsY, layout)
    local screenWidth = layout.screenWidth
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    
    -- Common panel for action buttons or movement controls
    self:drawUIPanel(0, buttonsY, screenWidth, CONTROLS_HEIGHT)
    
    -- Different controls based on phase
    if battle.turn == "player" then
        if battle.phase == "playerActionPlanning" or battle.phase == "actionResolution" then
            -- Action phase - show action buttons
            self:drawActionButtons(battle, buttonsY, screenWidth, layout.sidebarWidth)
        elseif battle.phase == "playerMovePlanning" then
            -- Movement planning phase - show maneuver planning controls
            self:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
        elseif battle.phase == "maneuverResolution" then
            -- Maneuver resolution phase - show resolving message
            love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
            love.graphics.printf("RESOLVING MANEUVERS...", 0, buttonsY + 15, screenWidth, "center")
        else
            -- Legacy fallback
            self:drawMovementControls(battle, buttonsY, screenWidth)
        end
    else
        -- Enemy turn - show a "Waiting..." animation or indicator
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.printf("ENEMY TAKING ACTION...", 0, buttonsY + 15, screenWidth, "center")
    end
end

-- Draw the maneuver planning controls
function Combat:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
    local buttonSpacing = 20
    local buttonWidth = 120
    local buttonHeight = 30
    
    -- First draw instructions
    love.graphics.setColor(1, 1, 1, 0.8)
    
    -- Different instructions based on whether destination is selected
    if self.plannedMoveHex then
        -- If destination selected, prompt for rotation
        love.graphics.printf("CHOOSE FINAL ORIENTATION", 0, buttonsY + 5, screenWidth, "center")
    else
        -- If no destination, prompt to select one
        love.graphics.printf("SELECT DESTINATION HEX", 0, buttonsY + 5, screenWidth, "center")
    end
    
    -- Draw rotation controls if we have a planned move
    if self.plannedMoveHex then
        -- Rotation controls - Calculate button positions
        local totalWidth = (2 * buttonWidth) + buttonSpacing
        local startX = (screenWidth - totalWidth) / 2
        
        -- Store button hitboxes for interaction
        self.rotationButtons = {
            rotateLeft = {
                x = startX,
                y = buttonsY + 25,
                width = buttonWidth,
                height = buttonHeight
            },
            rotateRight = {
                x = startX + buttonWidth + buttonSpacing,
                y = buttonsY + 25,
                width = buttonWidth,
                height = buttonHeight
            }
        }
        
        -- Draw the rotation buttons
        love.graphics.setColor(0.4, 0.7, 0.9, 0.9) -- Blue for rotation
        love.graphics.rectangle("fill", self.rotationButtons.rotateLeft.x, self.rotationButtons.rotateLeft.y, 
                              self.rotationButtons.rotateLeft.width, self.rotationButtons.rotateLeft.height)
        love.graphics.rectangle("fill", self.rotationButtons.rotateRight.x, self.rotationButtons.rotateRight.y, 
                              self.rotationButtons.rotateRight.width, self.rotationButtons.rotateRight.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ROTATE LEFT", self.rotationButtons.rotateLeft.x, self.rotationButtons.rotateLeft.y + 8, buttonWidth, "center")
        love.graphics.printf("ROTATE RIGHT", self.rotationButtons.rotateRight.x, self.rotationButtons.rotateRight.y + 8, buttonWidth, "center")
        
        -- If both move and rotation are planned, show confirm button
        if self.plannedRotation ~= nil then
            -- Calculate total cost
            local cost = self:calculateSPCost(battle.playerShip, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
            local affordable = cost <= battle.playerShip.currentSP
            
            -- Confirm button
            self.confirmManeuverButton = {
                x = (screenWidth - buttonWidth) / 2,
                y = buttonsY + 60,
                width = buttonWidth,
                height = buttonHeight
            }
            
            -- Draw confirm button with color based on affordability
            local buttonColor = affordable and {0.2, 0.8, 0.2, 0.9} or {0.8, 0.2, 0.2, 0.9}
            love.graphics.setColor(buttonColor)
            love.graphics.rectangle("fill", self.confirmManeuverButton.x, self.confirmManeuverButton.y,
                                 self.confirmManeuverButton.width, self.confirmManeuverButton.height)
            
            -- Confirm button text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("CONFIRM (" .. cost .. " SP)", self.confirmManeuverButton.x, 
                              self.confirmManeuverButton.y + 8, buttonWidth, "center")
        end
    end
end

function Combat:drawActionButtons(battle, buttonsY, screenWidth, sidebarWidth)
    -- Center buttons in the available space
    local buttonSpacing = 20
    local buttonWidth = 160
    local buttonHeight = 40
    local buttonY = buttonsY + 5  -- Standard button Y position
    local totalButtonsWidth = (3 * buttonWidth) + (2 * buttonSpacing) + 125 + buttonSpacing
    local startX = (screenWidth - totalButtonsWidth) / 2
    
    -- Store button positions for consistent hitbox testing
    self.actionButtons = {
        fire = { x = startX, y = buttonY, width = buttonWidth, height = buttonHeight },
        evade = { x = startX + buttonWidth + buttonSpacing, y = buttonY, width = buttonWidth, height = buttonHeight },
        repair = { x = startX + (buttonWidth + buttonSpacing) * 2, y = buttonY, width = buttonWidth, height = buttonHeight },
        endTurn = { x = startX + (buttonWidth + buttonSpacing) * 3, y = buttonY, width = 125, height = buttonHeight }
    }
    
    -- Fire Cannons button
    self:drawButton(
        self.actionButtons.fire.x, 
        self.actionButtons.fire.y, 
        self.actionButtons.fire.width, 
        self.actionButtons.fire.height, 
        {0.8, 0.3, 0.3, 0.9}, "FIRE CANNONS", 
        battle.playerShip.crewPoints >= self.actionCosts.fire
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.fire.x, 
        self.actionButtons.fire.y, 
        self.actionButtons.fire.width, 
        self.actionButtons.fire.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.fire .. " CP)", self.actionButtons.fire.x + 20, self.actionButtons.fire.y + 25, 0, 0.8, 0.8)
    
    -- Evade button
    self:drawButton(
        self.actionButtons.evade.x, 
        self.actionButtons.evade.y, 
        self.actionButtons.evade.width, 
        self.actionButtons.evade.height,
        {0.3, 0.3, 0.8, 0.9}, "EVADE", 
        battle.playerShip.crewPoints >= self.actionCosts.evade
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.evade.x, 
        self.actionButtons.evade.y, 
        self.actionButtons.evade.width, 
        self.actionButtons.evade.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.evade .. " CP)", self.actionButtons.evade.x + 20, self.actionButtons.evade.y + 25, 0, 0.8, 0.8)
    
    -- Repair button
    self:drawButton(
        self.actionButtons.repair.x, 
        self.actionButtons.repair.y, 
        self.actionButtons.repair.width, 
        self.actionButtons.repair.height,
        {0.3, 0.8, 0.3, 0.9}, "REPAIR", 
        battle.playerShip.crewPoints >= self.actionCosts.repair
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.repair.x, 
        self.actionButtons.repair.y, 
        self.actionButtons.repair.width, 
        self.actionButtons.repair.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.repair .. " CP)", self.actionButtons.repair.x + 20, self.actionButtons.repair.y + 25, 0, 0.8, 0.8)
    
    -- End Turn button
    self:drawButton(
        self.actionButtons.endTurn.x, 
        self.actionButtons.endTurn.y, 
        self.actionButtons.endTurn.width, 
        self.actionButtons.endTurn.height,
        {0.7, 0.7, 0.7, 0.9}, "END TURN", true
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.endTurn.x, 
        self.actionButtons.endTurn.y, 
        self.actionButtons.endTurn.width, 
        self.actionButtons.endTurn.height
    )
end

-- Draw the movement controls
function Combat:drawMovementControls(battle, buttonsY, screenWidth)
    -- Position info in left side
    love.graphics.setColor(1, 1, 1, 0.8)
    local posText = "POSITION: [" .. battle.playerShip.position[1] .. "," .. battle.playerShip.position[2] .. "]"
    love.graphics.print(posText, 50, buttonsY + 15)
    
    -- Direction hint if ship is selected
    if self.selectedHex then
        love.graphics.setColor(0.3, 0.8, 0.9, 0.9)
        local dirText = "SELECT A BLUE HEX TO MOVE"
        love.graphics.print(dirText, 300, buttonsY + 15)
    end
    
    -- End Move/To Action button (right side)
    local moveButtonX = screenWidth - 175
    local moveButtonY = buttonsY + 5
    local moveButtonWidth = 125
    local moveButtonHeight = 40
    
    -- Store button position for consistent hitbox testing
    self.moveActionButton = {
        x = moveButtonX,
        y = moveButtonY,
        width = moveButtonWidth,
        height = moveButtonHeight
    }
    
    if battle.playerShip.movesRemaining <= 0 then
        self:drawButton(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight, 
                        {0.8, 0.7, 0.2, 0.9}, "END MOVE", true)
    else
        self:drawButton(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight, 
                        {0.7, 0.7, 0.2, 0.9}, "TO ACTION", true)
    end
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight)
end

-- Draw the instructions panel
function Combat:drawInstructionsPanel(battle, buttonsY, layout)
    local screenWidth = layout.screenWidth
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    local INSTRUCTIONS_HEIGHT = Constants.UI.COMBAT.INSTRUCTIONS_HEIGHT
    
    -- Position it below the action buttons panel
    self:drawUIPanel(0, buttonsY + CONTROLS_HEIGHT, screenWidth, INSTRUCTIONS_HEIGHT)
    
    -- Draw instructions text
    love.graphics.setColor(1, 1, 1, 0.9)
    local instructions = ""
    if battle.turn == "player" then
        if battle.phase == "playerMovePlanning" then
            instructions = "PLANNING PHASE: Select destination hex and rotation (SP: " .. battle.playerShip.currentSP .. "/" .. battle.playerShip.maxSP .. ")"
        elseif battle.phase == "maneuverResolution" then
            instructions = "RESOLVING MANEUVERS: Please wait..."
        elseif battle.phase == "playerActionPlanning" then
            instructions = "ACTION PHASE: Select action to perform"
        elseif battle.phase == "movement" then
            instructions = "MOVEMENT PHASE: Click your ship, then click a blue hex to move"
        elseif battle.phase == "action" then
            instructions = "ACTION PHASE: Click a button to perform an action"
        else
            instructions = "PHASE: " .. battle.phase
        end
    else
        instructions = "ENEMY TURN: Please wait..."
    end
    love.graphics.printf(instructions, 20, buttonsY + CONTROLS_HEIGHT + 8, screenWidth - 40, "center")
end

-- Helper function to draw a UI panel with background
function Combat:drawUIPanel(x, y, width, height, r, g, b, a)
    local color
    -- Use provided color values or constants if color arguments are nil
    if r == nil then
        color = Constants.COLORS.UI_PANEL
    else
        color = {r, g, b, a}
    end
    
    -- Draw panel background
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    
    -- Draw panel border
    love.graphics.setColor(Constants.COLORS.UI_BORDER)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
end

-- Helper function to draw a progress bar
function Combat:drawProgressBar(x, y, width, height, fillPercent, fillColor, emptyColor)
    -- Clamp fill percent between 0 and 1
    fillPercent = math.max(0, math.min(1, fillPercent))
    
    -- Draw background (empty part)
    love.graphics.setColor(emptyColor[1], emptyColor[2], emptyColor[3], emptyColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)
    
    -- Draw filled part
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width * fillPercent, height, 3, 3)
    
    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height, 3, 3)
    
    -- Draw notches for visual scale reference (every 25%)
    love.graphics.setColor(1, 1, 1, 0.3)
    for i = 1, 3 do
        local notchX = x + (width * (i / 4))
        love.graphics.line(notchX, y, notchX, y + height)
    end
    
    -- Add color indicator based on value (red for low, yellow for medium, green for good)
    if fillPercent < 0.25 then
        -- Draw critical indicator for low health
        if fillPercent < 0.3 and emptyColor[1] > 0.5 then -- Only for health bars
            love.graphics.setColor(1, 0, 0, math.abs(math.sin(love.timer.getTime() * 4)) * 0.8)
            love.graphics.rectangle("fill", x, y, width * fillPercent, height, 3, 3)
        end
    end
end

-- Helper function to draw a button
function Combat:drawButton(x, y, width, height, color, text, enabled)
    -- Darken the button if disabled
    local buttonColor = {color[1], color[2], color[3], color[4] or 1}
    if not enabled then
        buttonColor[1] = buttonColor[1] * 0.4
        buttonColor[2] = buttonColor[2] * 0.4
        buttonColor[3] = buttonColor[3] * 0.4
    end
    
    -- Draw button shadow for depth
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x + 2, y + 2, width, height, 5, 5)
    
    -- Draw button background with gradient effect
    local gradientTop = {
        buttonColor[1] * 1.2,
        buttonColor[2] * 1.2,
        buttonColor[3] * 1.2,
        buttonColor[4]
    }
    
    -- Top half with lighter color
    love.graphics.setColor(gradientTop)
    love.graphics.rectangle("fill", x, y, width, height/2, 5, 5)
    
    -- Bottom half with original color
    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", x, y + height/2, width, height/2, 5, 5)
    
    -- Draw button border
    if enabled then
        love.graphics.setColor(1, 1, 1, 0.8)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    
    -- Draw button text with slight shadow for better readability
    if enabled then
        -- Text shadow
        love.graphics.setColor(0, 0, 0, 0.5)
        local textX = x + (width / 2) - (love.graphics.getFont():getWidth(text) / 2) + 1
        local textY = y + (height / 2) - (love.graphics.getFont():getHeight() / 2) + 1
        love.graphics.print(text, textX, textY)
        
        -- Actual text
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
    end
    
    -- Center text on button
    local textX = x + (width / 2) - (love.graphics.getFont():getWidth(text) / 2)
    local textY = y + (height / 2) - (love.graphics.getFont():getHeight() / 2)
    love.graphics.print(text, textX, textY)
    
    -- Add subtle highlight effect on the top edge for 3D effect
    if enabled then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.line(x + 2, y + 2, x + width - 2, y + 2)
    end
end

-- Handle mouse movement
function Combat:mousemoved(x, y, gameState)
    if not gameState.combat then return end
    
    -- Update hovered hex
    local oldHoveredHex = self.hoveredHex
    self.hoveredHex = self:getHexFromScreen(x, y)
    
    -- Auto-select player ship if not already selected
    if gameState.combat.phase == "playerMovePlanning" and not self.selectedHex and gameState.combat.playerShip then
        self.selectedHex = {gameState.combat.playerShip.position[1], gameState.combat.playerShip.position[2]}
        self:calculateValidMoves(gameState.combat, gameState.combat.playerShip)
        print("Auto-selected player ship in mousemoved")
    end
    
    -- Debug output when hovering changes
    if self.hoveredHex and (not oldHoveredHex or 
                          oldHoveredHex[1] ~= self.hoveredHex[1] or 
                          oldHoveredHex[2] ~= self.hoveredHex[2]) then
        if self.hoveredHex then
            local q, r = self.hoveredHex[1], self.hoveredHex[2]
            local isValid = self:isValidMove(q, r)
            print("Now hovering over hex " .. q .. "," .. r .. " - " .. (isValid and "VALID move" or "NOT a valid move"))
        end
    end
end

-- Helper function to check if a point is inside a button
function Combat:isPointInButton(x, y, buttonX, buttonY, buttonWidth, buttonHeight)
    -- Simple rectangular hitbox check
    return x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight
end

-- Debug function to draw hitboxes (only used in debug mode)
function Combat:drawButtonHitbox(buttonX, buttonY, buttonWidth, buttonHeight)
    if self.showDebugHitboxes then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
        -- Draw a small dot at the button center for reference
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", buttonX + buttonWidth/2, buttonY + buttonHeight/2, 2)
    end
end

-- Check if a point is within the hex grid area
function Combat:isPointInGridArea(x, y, layout)
    -- Print debug tracking to help debug the issue
    print("Checking if point " .. x .. "," .. y .. " is in grid area")
    
    -- Use layout constants to determine grid boundaries
    local gridTop = layout.gridTop or 0
    local gridBottom = layout.gridBottom or love.graphics.getHeight()
    local sidebarWidth = layout.sidebarWidth or 100
    local screenWidth = layout.screenWidth or love.graphics.getWidth()
    
    -- Calculate grid area boundaries
    local gridLeft = sidebarWidth
    local gridRight = screenWidth - sidebarWidth
    
    -- Debug output
    print("Grid area: " .. gridLeft .. "," .. gridTop .. " to " .. gridRight .. "," .. gridBottom)
    
    -- Check if point is within the grid area
    local inGrid = (x >= gridLeft and x <= gridRight and y >= gridTop and y <= gridBottom)
    print("Point is " .. (inGrid and "INSIDE" or "OUTSIDE") .. " grid area")
    
    -- Always return true for now to debug hex selection
    return true
end

-- Handle mouse clicks
function Combat:mousepressed(x, y, button, gameState)
    if not gameState.combat then return end
    
    -- Only handle left clicks
    if button ~= 1 then return end
    
    local battle = gameState.combat
    
    -- Use layout constants from draw function
    local layout = self.layoutConstants
    if not layout then return end
    
    -- Calculate the y-position of the buttons panel
    local buttonsY = self:calculateButtonsY(battle, layout)
    
    -- First check if clicking on UI buttons
    if battle.turn == "player" then
        -- Try to handle button clicks based on the phase
        if self:handleButtonClick(x, y, battle, buttonsY, gameState) then
            return -- Button was clicked and handled
        end
    end
    
    -- If not clicking buttons, check for hex grid interactions
    -- Skip the grid area check to help debug problems
    --if self:isPointInGridArea(x, y, layout) then
        print("Checking for hex interactions")
        if battle.turn == "player" then
            if battle.phase == "playerMovePlanning" then
                -- Handle the new maneuver planning phase
                local handled = self:handleManeuverPlanningClick(x, y, battle)
                print("Maneuver planning click handled: " .. tostring(handled))
                
                -- Debug: if clicks aren't working, force calculate valid moves
                if not handled then
                    print("Click not handled - recalculating valid moves")
                    self.validMoves = {}
                    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
                    self:calculateValidMoves(battle, battle.playerShip)
                end
            elseif battle.phase == "movement" then
                -- Legacy movement handling
                self:handleHexClick(x, y, battle, gameState)
            end
        end
    --end
end

-- Calculate the Y position for the buttons panel
function Combat:calculateButtonsY(battle, layout)
    local buttonsY = 0
    
    if battle.actionResult then
        -- Below the feedback panel
        buttonsY = layout.gridBottom + Constants.UI.COMBAT.FEEDBACK_HEIGHT + 10
    else
        -- At the bottom of the grid area
        buttonsY = layout.gridBottom + 5
    end
    
    return buttonsY
end

-- Handle button clicks in the UI
function Combat:handleButtonClick(x, y, battle, buttonsY, gameState)
    -- Phase transition button (movement -> action) during movement phase
    if battle.phase == "movement" then
        if self:handleMovementPhaseButton(x, y, battle) then
            return true
        end
    elseif battle.phase == "action" then
        if self:handleActionPhaseButtons(x, y, battle, gameState) then
            return true
        end
    end
    
    return false -- No button was clicked
end

-- Handle movement phase button clicks
function Combat:handleMovementPhaseButton(x, y, battle)
    if self.moveActionButton and 
       self:isPointInButton(x, y, self.moveActionButton.x, self.moveActionButton.y, 
                         self.moveActionButton.width, self.moveActionButton.height) then
        -- End movement phase and start action phase
        battle.phase = "action"
        return true
    end
    
    return false
end

-- Handle action phase button clicks
function Combat:handleActionPhaseButtons(x, y, battle, gameState)
    -- Check for button clicks using stored button positions
    if not self.actionButtons then return false end
    
    -- Fire Cannons button
    if self:isPointInButton(x, y, self.actionButtons.fire.x, self.actionButtons.fire.y, 
                          self.actionButtons.fire.width, self.actionButtons.fire.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.fire then
        battle.actionResult = self:fireCannons(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- Evade button
    if self:isPointInButton(x, y, self.actionButtons.evade.x, self.actionButtons.evade.y, 
                          self.actionButtons.evade.width, self.actionButtons.evade.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.evade then
        battle.actionResult = self:evade(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- Repair button
    if self:isPointInButton(x, y, self.actionButtons.repair.x, self.actionButtons.repair.y, 
                          self.actionButtons.repair.width, self.actionButtons.repair.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.repair then
        battle.actionResult = self:repair(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- End Turn button
    if self:isPointInButton(x, y, self.actionButtons.endTurn.x, self.actionButtons.endTurn.y, 
                          self.actionButtons.endTurn.width, self.actionButtons.endTurn.height) then
        self:endPlayerTurn(gameState)
        return true
    end
    
    return false
end

-- Check if a point is within the grid area
function Combat:isPointInGridArea(x, y, layout)
    local centerAreaLeft = layout.sidebarWidth
    local centerAreaRight = layout.screenWidth - layout.sidebarWidth
    
    -- Return true if point is inside the grid area
    return x >= centerAreaLeft and x <= centerAreaRight and y >= layout.gridTop and y <= layout.gridBottom
end

-- Handle hex grid clicks during the movement phase
function Combat:handleHexClick(x, y, battle, gameState)
    local clickedHex = self:getHexFromScreen(x, y)
    if not clickedHex then return end
    
    local q, r = clickedHex[1], clickedHex[2]
    
    -- Check bounds to make sure we're not out of the grid
    if q < 0 or q >= self.GRID_SIZE or r < 0 or r >= self.GRID_SIZE then
        return
    end
    
    -- If the player's ship is clicked, select it
    if battle.grid[q][r].isPlayerShip then
        self:selectPlayerShip(clickedHex, battle, gameState)
    -- If a valid move hex is clicked, move the ship there
    elseif self.selectedHex and self:isValidMove(q, r) then
        self:movePlayerShip(q, r, battle, gameState)
    end
end

-- Select the player's ship for movement
function Combat:selectPlayerShip(clickedHex, battle, gameState)
    self.selectedHex = clickedHex
    -- Calculate valid moves from this position
    self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
    
    -- Debug
    if gameState.settings.debug then
        local q, r = clickedHex[1], clickedHex[2]
        print("Selected player ship at " .. q .. "," .. r .. 
              " with " .. battle.playerShip.movesRemaining .. " moves remaining")
    end
end

-- Move the player's ship to a new position
function Combat:movePlayerShip(q, r, battle, gameState)
    -- Move the ship to the new position
    self:moveShip(battle, battle.playerShip, q, r)
    
    -- Recalculate valid moves or clear them if no moves left
    if battle.playerShip.movesRemaining > 0 then
        self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
    else
        self.validMoves = {}
        self.selectedHex = nil
        
        -- If out of moves, auto-transition to action phase
        battle.phase = "action"
    end
    
    -- Debug
    if gameState.settings.debug then
        print("Moved player ship to " .. q .. "," .. r .. 
              " with " .. battle.playerShip.movesRemaining .. " moves remaining")
    end
end

-- End player turn and start enemy turn
function Combat:endPlayerTurn(gameState)
    local battle = gameState.combat
    
    -- Reset player ship for next turn
    battle.playerShip.hasActed = false
    battle.playerShip.movesRemaining = shipUtils.getBaseSpeed(battle.playerShip.class)
    battle.playerShip.crewPoints = battle.playerShip.maxCrewPoints
    
    -- Switch to enemy turn
    battle.turn = "enemy"
    battle.phase = "movement"
    
    -- Process enemy turn (simple AI)
    self:processEnemyTurn(gameState)
end

-- Process enemy turn with simple AI
function Combat:processEnemyTurn(gameState)
    local battle = gameState.combat
    
    -- Movement phase - enemy moves based on tactical situation
    self:processEnemyMovement(gameState)
    
    -- Action phase - enemy chooses an action based on health
    battle.phase = "action"
    self:processEnemyAction(gameState)
    
    -- End the enemy turn and prepare for player turn
    self:finalizeEnemyTurn(battle)
end

-- Finalize the enemy turn and prepare for player turn
function Combat:finalizeEnemyTurn(battle)
    -- Reset enemy ship for next turn
    battle.enemyShip.hasActed = false
    battle.enemyShip.movesRemaining = shipUtils.getBaseSpeed(battle.enemyShip.class)
    battle.enemyShip.crewPoints = battle.enemyShip.maxCrewPoints
    
    -- Increment turn counter
    battle.turnCount = battle.turnCount + 1
    
    -- Reset for player turn
    battle.turn = "player"
    battle.phase = "movement"
end

-- Process enemy movement
function Combat:processEnemyMovement(gameState)
    local battle = gameState.combat
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Calculate initial state
    local eq, er = enemyShip.position[1], enemyShip.position[2]
    local pq, pr = playerShip.position[1], playerShip.position[2]
    local distance = self:hexDistance(eq, er, pq, pr)
    local movesRemaining = enemyShip.movesRemaining
    
    -- Calculate health percentage (affects tactical decisions)
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Keep moving until we run out of moves or valid moves
    while movesRemaining > 0 do
        -- Get all possible moves
        local validMoves = self:calculateValidMoves(battle, enemyShip)
        if #validMoves == 0 then break end
        
        -- Find the best move
        local bestMove = self:findBestEnemyMove(validMoves, healthPercent, playerShip)
        
        -- Execute the chosen move
        if bestMove then
            self:moveShip(battle, enemyShip, bestMove[1], bestMove[2])
            movesRemaining = enemyShip.movesRemaining
        else
            break
        end
    end
end

-- Find the best move for the enemy ship based on tactical situation
function Combat:findBestEnemyMove(validMoves, healthPercent, playerShip)
    local bestMove = nil
    local bestScore = -1000
    local pq, pr = playerShip.position[1], playerShip.position[2]
    
    for _, move in ipairs(validMoves) do
        local moveQ, moveR = move[1], move[2]
        local newDist = self:hexDistance(moveQ, moveR, pq, pr)
        
        -- Calculate score based on enemy's health and strategy
        local score = self:calculateMoveScore(newDist, healthPercent)
        
        -- Take the highest-scoring move
        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end
    
    return bestMove
end

-- Calculate a score for a potential move based on tactical situation
function Combat:calculateMoveScore(distance, healthPercent)
    local score = 0
    
    -- Different strategies based on health
    if healthPercent > 0.7 then
        -- Aggressive when healthy - get closer to attack
        score = -distance  -- Negative distance = prefer closer
    elseif healthPercent > 0.3 then
        -- Cautious when moderately damaged - maintain medium distance
        score = -(math.abs(distance - 3))  -- Prefer distance of about 3 hexes
    else
        -- Defensive when critically damaged - flee
        score = distance  -- Prefer farther
    end
    
    -- Add slight randomization to avoid predictable behavior
    score = score + math.random() * 0.5
    
    return score
end

-- Process enemy action based on health
function Combat:processEnemyAction(gameState)
    local battle = gameState.combat
    local enemyShip = battle.enemyShip
    
    -- Calculate health percentage
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Choose and execute an action based on health level
    battle.actionResult = self:chooseEnemyAction(gameState, healthPercent)
    
    -- Short delay to show the action result (would be implemented better with a timer)
    love.timer.sleep(0.5)
end

-- Choose an appropriate action for the enemy based on health
function Combat:chooseEnemyAction(gameState, healthPercent)
    -- Different actions based on health threshold:
    if healthPercent < 0.3 then
        -- Critically damaged - try to repair
        return self:repair(gameState)
    elseif healthPercent < 0.7 then
        -- Moderately damaged - try to evade
        return self:evade(gameState)
    else
        -- Healthy - attack!
        return self:fireCannons(gameState)
    end
end

-- Start a naval battle
function Combat:startBattle(gameState, enemyShipClass)
    -- Initialize a new battle
    self:initBattle(gameState, enemyShipClass)
    
    -- Set game state to combat mode
    gameState.settings.combatMode = true
    
    return true
end

-- Fire cannons action (Ticket 3-2)
function Combat:fireCannons(gameState, target)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:fireCannons")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local attacker = battle.turn == "player" and battle.playerShip or battle.enemyShip
    local defender = battle.turn == "player" and battle.enemyShip or battle.playerShip
    
    -- Validate battle state
    assert(attacker, "No attacker ship found in battle")
    assert(defender, "No defender ship found in battle")
    
    -- Check if enough crew points are available
    if attacker.crewPoints < self.actionCosts.fire then
        return {
            action = "fire",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.fire .. ")"
        }
    end
    
    -- Deduct crew points
    attacker.crewPoints = attacker.crewPoints - self.actionCosts.fire
    
    -- Calculate base dice based on firepower (cannons)
    local baseDice = shipUtils.getBaseFirepowerDice(attacker.class)
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Check for point blank range (adjacent hex)
    local aq, ar = attacker.position[1], attacker.position[2]
    local dq, dr = defender.position[1], defender.position[2]
    local dist = self:hexDistance(aq, ar, dq, dr)
    
    if dist == 1 then
        -- Point blank range gives +1 die
        table.insert(modifiers, diceSystem:createModifier("Point Blank Range", 1, true))
    end
    
    -- Check for Gunner in crew (adds skill as bonus dice)
    if battle.turn == "player" then
        -- Check player's crew for Gunner
        for _, member in ipairs(gameState.crew.members) do
            if member.role == "Gunner" then
                -- Add Gunner's skill level as a modifier
                local gunnerBonus = member.skill * Constants.GAME.GUNNER_SKILL_MULTIPLIER
                table.insert(modifiers, diceSystem:createModifier("Gunner: " .. member.name, gunnerBonus, true))
                
                if gameState.settings.debug then
                    print("Gunner modifier: +" .. gunnerBonus .. " dice from " .. member.name)
                end
                
                break  -- Only apply the first Gunner's bonus for now
            end
        end
    end
    
    -- Apply defender's evade score as a negative modifier
    if defender.evadeScore > 0 then
        table.insert(modifiers, diceSystem:createModifier("Target Evading", -defender.evadeScore, true))
        -- Reset defender's evade score after this attack
        defender.evadeScore = 0
    end
    
    -- Add any persistent modifiers from attacker
    for _, mod in ipairs(attacker.modifiers) do
        if mod.category == "attack" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for attack with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Calculate damage based on outcome level
    local damage = 0
    if outcome.result == "critical" then
        damage = Constants.COMBAT.DAMAGE_CRITICAL  -- Critical hit damage
    elseif outcome.result == "success" then
        damage = Constants.COMBAT.DAMAGE_SUCCESS  -- Success damage
    elseif outcome.result == "partial" then
        damage = Constants.COMBAT.DAMAGE_PARTIAL  -- Partial success damage
    end
    
    -- Apply damage to target
    if battle.turn == "player" then
        -- Player attacks enemy
        battle.enemyShip.durability = math.max(0, (battle.enemyShip.durability or 10) - damage)
        
        -- Check if enemy is destroyed
        if battle.enemyShip.durability <= 0 then
            -- Enemy ship is sunk - player wins
            self:endBattle(gameState, "victory")
            return true
        end
    else
        -- Enemy attacks player
        gameState.ship.durability = math.max(0, gameState.ship.durability - damage)
        
        -- Check if player is destroyed
        if gameState.ship.durability <= 0 then
            -- Player ship is sunk - player loses
            self:endBattle(gameState, "defeat")
            return true
        end
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(attacker)
    
    -- Return result for UI display
    return {
        action = "fire",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        damage = damage,
        attacker = battle.turn,
        targetDurability = battle.turn == "player" and battle.enemyShip.durability or gameState.ship.durability,
        modifiers = modifiers
    }
end

-- Clean up temporary modifiers
function Combat:cleanupTemporaryModifiers(ship)
    -- Filter out temporary modifiers
    local persistentModifiers = {}
    for _, mod in ipairs(ship.modifiers) do
        if not mod.temporary then
            table.insert(persistentModifiers, mod)
        end
    end
    
    -- Replace with only persistent modifiers
    ship.modifiers = persistentModifiers
end

-- Evade action (Ticket 3-2)
function Combat:evade(gameState)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:evade")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Validate battle state
    assert(ship, "No ship found for current turn")
    
    -- Check if enough crew points are available
    if ship.crewPoints < self.actionCosts.evade then
        return {
            action = "evade",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.evade .. ")"
        }
    end
    
    -- Deduct crew points
    ship.crewPoints = ship.crewPoints - self.actionCosts.evade
    
    -- Calculate base dice based on ship class (speed influences evasion)
    local baseDice = shipUtils.getBaseSpeed(ship.class)
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Add any persistent modifiers from ship
    for _, mod in ipairs(ship.modifiers) do
        if mod.category == "evade" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for evasion with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Set evade score based on outcome level
    local evadeScore = outcome.level  -- 0=failure, 1=partial, 2=success, 3=critical
    
    if battle.turn == "player" then
        -- Player evades
        battle.playerShip.evadeScore = evadeScore
    else
        -- Enemy evades
        battle.enemyShip.evadeScore = evadeScore
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(ship)
    
    -- Return result for UI display
    return {
        action = "evade",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        evadeScore = evadeScore,
        ship = battle.turn,
        modifiers = modifiers
    }
end

-- Repair action (Ticket 3-2)
function Combat:repair(gameState)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:repair")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Validate battle state
    assert(ship, "No ship found for current turn")
    
    -- Check if enough crew points are available
    if ship.crewPoints < self.actionCosts.repair then
        return {
            action = "repair",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.repair .. ")"
        }
    end
    
    -- Deduct crew points
    ship.crewPoints = ship.crewPoints - self.actionCosts.repair
    
    -- Calculate base dice - always 1 for base repair
    local baseDice = 1
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Check for surgeon in crew (adds dice)
    if battle.turn == "player" then
        -- Check player's crew for surgeon
        for _, member in ipairs(gameState.crew.members) do
            if member.role == "Surgeon" then
                -- Add surgeon's skill level as a modifier
                table.insert(modifiers, diceSystem:createModifier("Surgeon: " .. member.name, member.skill, true))
                break
            end
        end
    end
    
    -- Add any persistent modifiers from ship
    for _, mod in ipairs(ship.modifiers) do
        if mod.category == "repair" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for repair with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Calculate repair amount based on outcome level
    local repairAmount = 0
    if outcome.result == "critical" then
        repairAmount = Constants.COMBAT.REPAIR_CRITICAL  -- Critical repair
    elseif outcome.result == "success" then
        repairAmount = Constants.COMBAT.REPAIR_SUCCESS  -- Success repair
    elseif outcome.result == "partial" then
        repairAmount = Constants.COMBAT.REPAIR_PARTIAL  -- Partial success repair
    end
    
    -- Apply repairs
    if battle.turn == "player" then
        -- Player repairs their ship
        local maxDurability = shipUtils.getMaxHP(gameState.ship.class)
        gameState.ship.durability = math.min(gameState.ship.durability + repairAmount, maxDurability)
    else
        -- Enemy repairs their ship
        local maxDurability = shipUtils.getMaxHP(ship.class)
        battle.enemyShip.durability = math.min((battle.enemyShip.durability or 10) + repairAmount, maxDurability)
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(ship)
    
    -- Return result for UI display
    return {
        action = "repair",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        repairAmount = repairAmount,
        ship = battle.turn,
        currentDurability = battle.turn == "player" and gameState.ship.durability or battle.enemyShip.durability,
        modifiers = modifiers
    }
end

-- Dice mechanics integration methods

-- Initialize the dice system
function Combat:initDiceSystem()
    diceSystem:init()
end

-- Roll dice for combat actions (using the dice module)
function Combat:rollDice(numDice)
    return diceSystem:roll(numDice)
end

-- Interpret dice results (using the dice module)
function Combat:interpretDiceResults(diceResults)
    return diceSystem:interpret(diceResults)
end

-- End a naval battle
function Combat:endBattle(gameState, result)
    -- Process battle results
    if result then
        if result == "victory" then
            -- Player won the battle
            print("Victory! Enemy ship destroyed.")
            -- Would add rewards here in later sprints
        elseif result == "defeat" then
            -- Player lost the battle
            print("Defeat! Your ship was destroyed.")
            -- Would add consequences here in later sprints
        elseif result == "retreat" then
            -- Player retreated from battle
            print("You retreat from the battle.")
        end
    end
    
    -- Clean up combat state
    gameState.combat = nil
    
    -- Exit combat mode
    gameState.settings.combatMode = false
    
    return true
end

return Combat```

## src/conf.lua
```lua
-- LÖVE Configuration
function love.conf(t)
    t.title = "Pirate's Wager: Blood for Gold"  -- The title of the window
    t.version = "11.4"                -- The LÖVE version this game was made for
    t.window.width = 800              -- Game window width
    t.window.height = 600             -- Game window height
    t.window.resizable = true         -- Allow window to be resized with letterboxing/pillarboxing
    t.console = true                  -- Enable console for debug output
    
    -- For development
    t.window.vsync = 1                -- Vertical sync mode
    
    -- Disable modules we won't be using
    t.modules.joystick = false        -- No need for joystick module
    t.modules.physics = false         -- No need for physics module for map navigation
end```

## src/constants.lua
```lua
-- Game Constants
-- Centralized definitions of commonly used values

local Constants = {
    -- ============ UI LAYOUT CONSTANTS ============
    UI = {
        -- General Screen
        SCREEN_WIDTH = 800,
        SCREEN_HEIGHT = 600,
        
        -- Combat Layout
        COMBAT = {
            TOP_BAR_HEIGHT = 30,
            BOTTOM_BAR_HEIGHT = 80,
            SIDEBAR_WIDTH = 140,
            FEEDBACK_HEIGHT = 70,
            CONTROLS_HEIGHT = 50,
            INSTRUCTIONS_HEIGHT = 30,
            BUTTON_WIDTH = 160,
            BUTTON_HEIGHT = 40,
            BUTTON_SPACING = 20,
            HEX_RADIUS = 25
        }
    },
    
    -- ============ COLORS ============
    COLORS = {
        -- General UI Colors
        UI_BACKGROUND = {0.08, 0.1, 0.15, 1},  -- Very dark blue/black
        UI_PANEL = {0.15, 0.15, 0.25, 0.9},    -- Translucent dark blue
        UI_BORDER = {0.3, 0.3, 0.5, 0.8},      -- Light border
        UI_TEXT = {1, 1, 1, 0.8},              -- Soft white text
        
        -- Ship and Entity Colors
        PLAYER_SHIP = {0.2, 0.8, 0.2, 1},      -- Green for player
        ENEMY_SHIP = {0.8, 0.2, 0.2, 1},       -- Red for enemy
        HOVER = {0.8, 0.8, 0.2, 0.6},          -- Yellow for hover
        SELECTED = {0.2, 0.8, 0.8, 0.6},       -- Cyan for selected
        
        -- Action Button Colors
        BUTTON_FIRE = {0.8, 0.3, 0.3, 0.9},    -- Red for fire actions
        BUTTON_EVADE = {0.3, 0.3, 0.8, 0.9},   -- Blue for evade actions
        BUTTON_REPAIR = {0.3, 0.8, 0.3, 0.9},  -- Green for repair actions
        BUTTON_NEUTRAL = {0.7, 0.7, 0.7, 0.9}, -- Gray for neutral actions
        
        -- Resource Colors
        GOLD = {0.9, 0.8, 0.2, 1},             -- Gold color
        HEALTH = {0.2, 0.8, 0.2, 1},           -- Health green
        DAMAGE = {0.8, 0.2, 0.2, 1},           -- Damage red
        
        -- Sea and Map
        SEA = {0.1, 0.2, 0.4, 1},              -- Dark blue water
        SEA_BORDER = {0.2, 0.4, 0.6, 0.8},     -- Lighter blue border
        VALID_MOVE = {0.5, 0.7, 0.9, 0.6},     -- Light blue for valid moves
        EMPTY_WATER = {0.3, 0.5, 0.7, 0.4}     -- Blue for empty water
    },
    
    -- ============ COMBAT CONSTANTS ============
    COMBAT = {
        -- Grid Configuration
        GRID_SIZE = 10,                         -- 10x10 grid
        
        -- Action Costs
        CP_COST_FIRE = 1,                       -- Fire cannons cost 1 CP
        CP_COST_EVADE = 1,                      -- Evade costs 1 CP
        CP_COST_REPAIR = 2,                     -- Repair costs 2 CP
        
        -- Sail Point (SP) Costs
        SP_COST_MOVE_HEX = 1,                   -- Cost to move one hex
        SP_COST_ROTATE_60 = 1,                  -- Cost to rotate 60 degrees
        
        -- Damage Values
        DAMAGE_CRITICAL = 3,                    -- Critical hit damage
        DAMAGE_SUCCESS = 2,                     -- Success damage
        DAMAGE_PARTIAL = 1,                     -- Partial success damage
        
        -- Repair Values
        REPAIR_CRITICAL = 15,                   -- Critical repair amount
        REPAIR_SUCCESS = 10,                    -- Success repair amount
        REPAIR_PARTIAL = 5                      -- Partial success repair amount
    },
    
    -- ============ DICE CONSTANTS ============
    DICE = {
        SUCCESS = 6,                            -- Success on 6
        PARTIAL_MIN = 4,                        -- Partial success on 4-5
        PARTIAL_MAX = 5,                        -- Partial success on 4-5
        FAILURE_MAX = 3,                        -- Failure on 1-3
        
        -- Outcome Levels
        OUTCOME_CRITICAL = 3,                   -- Level for critical success
        OUTCOME_SUCCESS = 2,                    -- Level for success
        OUTCOME_PARTIAL = 1,                    -- Level for partial success
        OUTCOME_FAILURE = 0                     -- Level for failure
    },
    
    -- ============ CREW ROLES ============
    ROLES = {
        NAVIGATOR = "Navigator",
        GUNNER = "Gunner",
        SURGEON = "Surgeon"
    },
    
    -- ============ GAME SETTINGS ============
    GAME = {
        -- Default Resources
        DEFAULT_GOLD = 50,
        DEFAULT_RUM = 0,
        DEFAULT_TIMBER = 0,
        DEFAULT_GUNPOWDER = 0,
        
        -- Default Crew Values
        DEFAULT_MORALE = 5,                     -- Default crew morale (1-10)
        
        -- Time/Game Progress
        TOTAL_WEEKS = 72,                       -- Total game duration
        EARTHQUAKE_MIN_WEEK = 60,               -- Earliest earthquake week
        EARTHQUAKE_MAX_WEEK = 72,               -- Latest earthquake week
        
        -- Default Travel Time
        BASE_TRAVEL_TIME = 1,                   -- Base travel time (in weeks)
        MIN_TRAVEL_TIME = 0.5,                  -- Minimum travel time
        
        -- Wind Effects
        WIND_WITH = -0.5,                       -- Traveling with wind (weeks modifier)
        WIND_AGAINST = 1,                       -- Traveling against wind (weeks modifier)
        WIND_CHANGE_INTERVAL = 4,               -- How often wind might change (weeks)
        
        -- Inventory
        DEFAULT_INVENTORY_SLOTS = 10,           -- Default inventory capacity
        
        -- Crew Effects
        NAVIGATOR_TRAVEL_BONUS = -0.5,          -- Time reduction with Navigator (weeks)
        GUNNER_SKILL_MULTIPLIER = 1,            -- Multiplier for Gunner's skill level (for future balancing)
        VICTORY_LOYALTY_BONUS = 1,              -- Loyalty boost after victory
        RUM_LOYALTY_BONUS = 2,                  -- Loyalty boost from rum
        VOYAGE_LOYALTY_PENALTY = -1             -- Loyalty reduction per week at sea
    }
}

return Constants```

## src/dice.lua
```lua
-- Dice Module
-- Implements a reusable dice system for Forged in the Dark mechanics

-- Import constants
local Constants = require('constants')
local AssetUtils = require('utils.assetUtils')

local Dice = {
    -- Sprite sheet for dice
    spriteSheet = nil,
    spriteWidth = 32,
    spriteHeight = 32,
    quads = {}
}

-- Initialize dice system
function Dice:init()
    -- Load dice sprite sheet using AssetUtils
    self.spriteSheet = AssetUtils.loadImage("assets/dice-strip.png", "dice")
    
    if self.spriteSheet then
        -- Create quads for each die face
        for i = 0, 5 do
            self.quads[i+1] = love.graphics.newQuad(
                i * self.spriteWidth, 0,
                self.spriteWidth, self.spriteHeight,
                self.spriteSheet:getDimensions()
            )
        end
        
        print("Dice sprite sheet loaded successfully")
    else
        print("Will use text representation for dice")
    end
end

-- Modifier class for dice rolls
local Modifier = {
    description = "",  -- Description of the modifier
    value = 0,         -- The dice modifier value (positive or negative)
    temporary = false  -- Whether modifier is temporary (removed after roll)
}

-- Create a new modifier
function Modifier:new(description, value, temporary)
    local mod = {
        description = description or "",
        value = value or 0,
        temporary = temporary or false
    }
    setmetatable(mod, self)
    self.__index = self
    return mod
end

-- Roll dice with modifiers
function Dice:roll(baseDice, modifiers)
    local modifiers = modifiers or {}
    local results = {}
    local rollInfo = {
        baseDice = baseDice,
        modifiers = {},       -- Copy of applied modifiers
        totalDiceCount = 0,   -- Final dice count after modifiers
        zeroOrNegative = false, -- Flag if we had 0 or negative dice
        results = {},         -- The actual dice values rolled
        rolls = {}            -- All roll operations (for debugging)
    }
    
    -- Calculate total dice count from modifiers
    local totalDice = baseDice
    local modReport = {}
    
    -- Apply all modifiers
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
        table.insert(modReport, {
            description = mod.description, 
            value = mod.value
        })
        table.insert(rollInfo.rolls, "Applied " .. mod.description .. ": " .. (mod.value >= 0 and "+" or "") .. mod.value .. " dice")
    end
    
    -- Store the full list of applied modifiers
    rollInfo.modifiers = modReport
    
    -- Handle zero or negative dice count (roll 2 dice and take worst)
    if totalDice <= 0 then
        rollInfo.zeroOrNegative = true
        rollInfo.totalDiceCount = 2
        table.insert(rollInfo.rolls, "Reduced to " .. totalDice .. " dice - rolling 2 and taking worst")
        
        -- Roll 2 dice
        for i = 1, 2 do
            local dieValue = math.random(1, 6)
            table.insert(results, dieValue)
            table.insert(rollInfo.rolls, "Rolled " .. dieValue)
        end
        
        -- Take the worst (lowest) value
        table.sort(results)
        rollInfo.results = {results[1]}  -- Keep only the lowest value
        table.insert(rollInfo.rolls, "Taking worst value: " .. results[1])
    else
        -- Normal dice pool - roll adjusted number of dice (max 5)
        totalDice = math.min(5, totalDice)
        rollInfo.totalDiceCount = totalDice
        
        for i = 1, totalDice do
            local dieValue = math.random(1, 6)
            table.insert(results, dieValue)
            table.insert(rollInfo.rolls, "Rolled " .. dieValue)
        end
        
        rollInfo.results = results
    end
    
    -- Return both the roll results and the detailed roll info
    return results, rollInfo
end

-- Interpret dice results according to Forged in the Dark rules
function Dice:interpret(diceResults)
    local outcome = {
        successes = 0,      -- Full successes (die = 6)
        partials = 0,       -- Partial successes (die = 4-5)
        failures = 0,       -- Failures (die = 1-3)
        highestValue = 0,   -- The highest die value rolled
        result = "failure", -- Overall result: "failure", "partial", "success", or "critical"
        level = 0,          -- Numeric result level: 0=failure, 1=partial, 2=success, 3=critical
        results = diceResults -- The original dice values
    }
    
    -- No dice rolled
    if #diceResults == 0 then
        return outcome
    end
    
    -- Process each die result
    for _, die in ipairs(diceResults) do
        -- Track highest value
        outcome.highestValue = math.max(outcome.highestValue, die)
        
        -- Categorize results
        if die == Constants.DICE.SUCCESS then
            -- Success
            outcome.successes = outcome.successes + 1
        elseif die >= Constants.DICE.PARTIAL_MIN and die <= Constants.DICE.PARTIAL_MAX then
            -- Partial success
            outcome.partials = outcome.partials + 1
        else
            -- Failure
            outcome.failures = outcome.failures + 1
        end
    end
    
    -- Determine overall result based on Forged in the Dark rules
    -- Rule 1: Use highest die result (not the sum)
    -- Rule 2: 2+ successes (6s) is a critical success
    if outcome.successes >= 2 then
        -- Critical success (2+ dice showing 6)
        outcome.result = "critical"
        outcome.level = Constants.DICE.OUTCOME_CRITICAL
    elseif outcome.successes == 1 then
        -- Full success (1 die showing 6)
        outcome.result = "success"
        outcome.level = Constants.DICE.OUTCOME_SUCCESS
    elseif outcome.partials > 0 then
        -- Partial success (highest die is 4-5)
        outcome.result = "partial"
        outcome.level = Constants.DICE.OUTCOME_PARTIAL
    else
        -- Failure (no dice showing 4+)
        outcome.result = "failure"
        outcome.level = Constants.DICE.OUTCOME_FAILURE
    end
    
    return outcome
end

-- Draw dice results
function Dice:draw(diceResults, x, y, scale)
    local scale = scale or 1
    local padding = 2 * scale
    local width = self.spriteWidth * scale
    
    -- If no sprite sheet, use text representation
    if not self.spriteSheet then
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (20 * scale + padding)
            
            -- Draw die background based on value
            if value == 6 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for success
            elseif value >= 4 then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.8) -- Yellow for partial
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for failure
            end
            
            love.graphics.rectangle("fill", dieX, y, 20 * scale, 20 * scale, 3, 3)
            
            -- Draw die value
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(value, dieX + 7 * scale, y + 4 * scale)
        end
    else
        -- Use sprite sheet
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (width + padding)
            if self.spriteSheet and self.quads[value] then
                love.graphics.draw(
                    self.spriteSheet,
                    self.quads[value],
                    dieX,
                    y,
                    0,  -- rotation
                    scale, scale  -- scale x, y
                )
            else
                -- Draw placeholder if sprite sheet or quad is missing
                AssetUtils.drawPlaceholder(dieX, y, self.spriteWidth * scale, self.spriteHeight * scale, "dice")
            end
        end
    end
    
    -- Return the total width used by the dice
    return #diceResults * (self.spriteWidth * scale + padding)
end

-- Draw dice results with highlighting for dice that "count"
function Dice:drawWithHighlight(diceResults, x, y, scale)
    local scale = scale or 1
    local padding = 4 * scale
    local width = self.spriteWidth * scale
    local outcome = self:interpret(diceResults)
    
    -- If no sprite sheet, use text representation
    if not self.spriteSheet then
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (20 * scale + padding)
            local dieY = y
            
            -- Apply bump to dice that count
            if (value == 6 and outcome.successes > 0) or 
               (value >= 4 and value <= 5 and outcome.successes == 0 and outcome.partials > 0) or
               (value <= 3 and outcome.successes == 0 and outcome.partials == 0) then
                -- This die "counts" - bump it up
                dieY = y - 5 * scale
                
                -- Add glow/shadow for highlighted dice
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", dieX - 2, dieY - 2, 24 * scale, 24 * scale, 5, 5)
            end
            
            -- Draw die background based on value
            if value == 6 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for success
            elseif value >= 4 then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.8) -- Yellow for partial
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for failure
            end
            
            love.graphics.rectangle("fill", dieX, dieY, 20 * scale, 20 * scale, 3, 3)
            
            -- Draw die value
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(value, dieX + 7 * scale, dieY + 4 * scale)
        end
    else
        -- Use sprite sheet
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (width + padding)
            local dieY = y
            
            -- Determine if this die should be highlighted (counts toward the outcome)
            local shouldHighlight = false
            
            -- Critical success - all 6s count
            if outcome.result == "critical" and value == Constants.DICE.SUCCESS then
                shouldHighlight = true
            -- Regular success - only one 6 counts (use the first one found)
            elseif outcome.result == "success" and value == Constants.DICE.SUCCESS then
                -- If we haven't yet highlighted a success die
                if not outcome.hasHighlightedSuccess then
                    shouldHighlight = true
                    outcome.hasHighlightedSuccess = true
                end
            -- Partial success - only 4-5s count if there are no 6s
            -- Always highlight the highest value die (4 or 5)
            elseif outcome.result == "partial" then
                -- Find the highest partial success die (4-5)
                if not outcome.highestPartialValue then
                    outcome.highestPartialValue = 0
                    for _, v in ipairs(diceResults) do
                        if v >= Constants.DICE.PARTIAL_MIN and v <= Constants.DICE.PARTIAL_MAX and v > outcome.highestPartialValue then
                            outcome.highestPartialValue = v
                        end
                    end
                end
                
                -- Highlight only the highest partial success die
                if value == outcome.highestPartialValue and not outcome.hasHighlightedPartial then
                    shouldHighlight = true
                    outcome.hasHighlightedPartial = true
                end
            -- Failure - highlight the highest die (still a failure, but clearer)
            elseif outcome.result == "failure" then
                -- Find the highest die (which is still ≤ 3 for a failure)
                if not outcome.highestFailureValue then
                    outcome.highestFailureValue = 0
                    for _, v in ipairs(diceResults) do
                        if v <= Constants.DICE.FAILURE_MAX and v > outcome.highestFailureValue then
                            outcome.highestFailureValue = v
                        end
                    end
                end
                
                -- Highlight only the highest failure die
                if value == outcome.highestFailureValue and not outcome.hasHighlightedFailure then
                    shouldHighlight = true
                    outcome.hasHighlightedFailure = true
                end
            end
            
            -- Apply bump to dice that count
            if shouldHighlight then
                -- This die "counts" - bump it up
                dieY = y - 8 * scale
            end
            
            -- Check if we can draw the die using the spritesheet
            if self.spriteSheet and self.quads[value] then
                -- Draw the die with appropriate highlight
                love.graphics.setColor(1, 1, 1, 1)
                if shouldHighlight then
                    -- Add shadow for 3D effect
                    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX + 2,
                        dieY + 2,
                        0,  -- rotation
                        scale, scale  -- scale x, y
                    )
                    
                    -- Draw highlighted die slightly larger
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX,
                        dieY,
                        0,  -- rotation
                        scale * 1.1, scale * 1.1  -- slightly larger scale
                    )
                else
                    -- Draw regular die
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX,
                        dieY,
                        0,  -- rotation
                        scale, scale  -- scale x, y
                    )
                end
            else
                -- Draw placeholder if sprite sheet or quad is missing
                local placeholderHeight = self.spriteHeight * (shouldHighlight and scale * 1.1 or scale)
                local placeholderWidth = self.spriteWidth * (shouldHighlight and scale * 1.1 or scale)
                
                AssetUtils.drawPlaceholder(dieX, dieY, placeholderWidth, placeholderHeight, "dice")
                
                -- Draw the die value as text in the center of the placeholder
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(value, dieX + placeholderWidth/2 - 5, dieY + placeholderHeight/2 - 8)
            end
        end
    end
    
    -- Return the total width used by the dice
    return #diceResults * (self.spriteWidth * scale + padding)
end

-- Get result text description
function Dice:getResultText(outcome)
    if outcome.result == "critical" then
        return "Critical Success!"
    elseif outcome.result == "success" then
        return "Success"
    elseif outcome.result == "partial" then
        return "Partial Success"
    else
        return "Failure"
    end
end

-- Get result color
function Dice:getResultColor(outcome)
    if outcome.result == "critical" then
        return Constants.COLORS.HEALTH -- Bright green
    elseif outcome.result == "success" then
        return Constants.COLORS.PLAYER_SHIP -- Green
    elseif outcome.result == "partial" then
        return Constants.COLORS.GOLD -- Yellow
    else
        return Constants.COLORS.DAMAGE -- Red
    end
end

-- Create a helper function to easily create modifiers
function Dice:createModifier(description, value, temporary)
    return Modifier:new(description, value, temporary)
end

-- Draw modifiers list
function Dice:drawModifiers(modifiers, x, y, scale)
    love.graphics.setColor(1, 1, 1, 1)
    local yPos = y
    local scale = scale or 1
    local lineHeight = 20 * scale
    
    for i, mod in ipairs(modifiers) do
        -- Choose color based on modifier value
        if mod.value > 0 then
            love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Green for positive
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 1) -- Red for negative
        end
        
        local sign = mod.value > 0 and "+" or ""
        love.graphics.print(mod.description .. ": " .. sign .. mod.value .. " dice", x, yPos)
        yPos = yPos + lineHeight
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    return yPos - y  -- Return total height used
end

-- Export the module and the Modifier class
return {
    dice = Dice,
    Modifier = Modifier
}```

## src/gameState.lua
```lua
-- Game State Module
-- Central repository for game state that needs to be accessed across modules

-- Import ship utils
local shipUtils = require('utils.shipUtils')

-- Import constants
local Constants = require('constants')

local GameState = {
    -- Player ship information
    ship = {
        name = "The Swift Sting",
        class = "sloop",     -- Ship class (sloop, brigantine, galleon)
        currentZone = nil,  -- Set during initialization
        x = 0,
        y = 0,
        isMoving = false,
        -- Ship stats will be initialized based on class in init()
        speed = nil,
        firepower = nil,
        durability = nil,
        crewCapacity = nil
    },
    
    -- Time tracking
    time = {
        currentWeek = 1,
        totalWeeks = Constants.GAME.TOTAL_WEEKS,
        earthquakeWeek = nil,  -- Set during initialization
        isGameOver = false
    },
    
    -- Player resources
    resources = {
        gold = Constants.GAME.DEFAULT_GOLD,          -- Starting gold
        rum = Constants.GAME.DEFAULT_RUM,
        timber = Constants.GAME.DEFAULT_TIMBER,
        gunpowder = Constants.GAME.DEFAULT_GUNPOWDER
    },
    
    -- Inventory system for cargo and special items
    inventory = {
        slots = {},         -- Will contain inventory slot objects
        capacity = Constants.GAME.DEFAULT_INVENTORY_SLOTS
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = Constants.GAME.DEFAULT_MORALE,  -- Scale 1-10
        
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
    
    -- Set earthquake week (random between the configured weeks)
    self.time.earthquakeWeek = math.random(Constants.GAME.EARTHQUAKE_MIN_WEEK, 
                                         Constants.GAME.EARTHQUAKE_MAX_WEEK)
    
    -- Initialize wind direction (random)
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    
    -- Initialize ship stats based on class
    local stats = shipUtils.getShipBaseStats(self.ship.class)
    self.ship.speed = stats.speed
    self.ship.firepower = stats.firepowerDice
    self.ship.durability = stats.durability
    self.ship.crewCapacity = stats.crewCapacity
    
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
    
    -- Reset ship stats based on class
    local stats = shipUtils.getShipBaseStats(self.ship.class)
    self.ship.speed = stats.speed
    self.ship.firepower = stats.firepowerDice
    self.ship.durability = stats.durability
    self.ship.crewCapacity = stats.crewCapacity
    
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
        windModifier = Constants.GAME.WIND_WITH  -- Faster with the wind
    -- Against the wind (sailing into the wind): +1 week
    elseif travelDirection == oppositeOf[windDirection] then
        windModifier = Constants.GAME.WIND_AGAINST
    -- Perpendicular to wind: no modifier
    else
        windModifier = 0
    end
    
    -- Apply the wind modifier 
    local travelTime = baseTravelTime + windModifier
    
    -- Apply navigator modifier if present
    local navigatorEffect = ""
    if hasNavigator then
        travelTime = travelTime + Constants.GAME.NAVIGATOR_TRAVEL_BONUS
        navigatorEffect = " with Navigator"
        if self.settings.debug then
            print("Navigator reducing travel time by " .. math.abs(Constants.GAME.NAVIGATOR_TRAVEL_BONUS) .. " weeks")
        end
    end
    
    -- Ensure minimum travel time
    travelTime = math.max(Constants.GAME.MIN_TRAVEL_TIME, travelTime)
    
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
local combatSystem = require('combat')
local AssetUtils = require('utils.assetUtils')

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
    combatSystem:load(gameState)  -- Initialize combat system
    
    -- Store base dimensions for scaling calculations
    gameState.settings.baseWidth = 800
    gameState.settings.baseHeight = 600
    gameState.settings.scale = 1
    gameState.settings.offsetX = 0
    gameState.settings.offsetY = 0
    
    -- Set window properties
    love.window.setTitle("Pirate's Wager: Blood for Gold")
    love.window.setMode(800, 600, {
        vsync = true,
        resizable = true,  -- Allow window resizing with letterboxing/pillarboxing
        minwidth = 400,    -- Minimum window width
        minheight = 300    -- Minimum window height
    })
end

function love.update(dt)
    -- Early return if game is paused
    if gameState.settings.isPaused then return end
    
    -- Update game state based on current mode
    if gameState.settings.combatMode then
        -- Update naval combat
        combatSystem:update(dt, gameState)
    elseif gameState.settings.portMode then
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
        combatSystem:load(gameState)
    end
end

-- Handle window resize events
function love.resize(w, h)
    -- Calculate new scale factor to maintain exact 4:3 aspect ratio (800x600)
    local scaleX = w / gameState.settings.baseWidth
    local scaleY = h / gameState.settings.baseHeight
    
    -- Use the smaller scale to ensure everything fits
    gameState.settings.scale = math.min(scaleX, scaleY)
    
    -- Calculate letterbox or pillarbox dimensions for centering
    gameState.settings.offsetX = math.floor((w - gameState.settings.baseWidth * gameState.settings.scale) / 2)
    gameState.settings.offsetY = math.floor((h - gameState.settings.baseHeight * gameState.settings.scale) / 2)
    
    -- Print debug info
    if gameState.settings.debug then
        print("Window resized to " .. w .. "x" .. h)
        print("Scale factor: " .. gameState.settings.scale)
        print("Offset: " .. gameState.settings.offsetX .. ", " .. gameState.settings.offsetY)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    -- Draw black background for the entire window (for letterboxing/pillarboxing)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Set up the scaling transformation
    love.graphics.push()
    
    -- Apply offset for letterboxing/pillarboxing
    love.graphics.translate(gameState.settings.offsetX or 0, gameState.settings.offsetY or 0)
    
    -- Apply scaling
    love.graphics.scale(gameState.settings.scale or 1)
    
    -- Set scissor to ensure nothing renders outside our 800x600 game area
    love.graphics.setScissor(
        gameState.settings.offsetX,
        gameState.settings.offsetY,
        gameState.settings.baseWidth * gameState.settings.scale,
        gameState.settings.baseHeight * gameState.settings.scale
    )
    
    -- Render game based on current mode
    if gameState.settings.combatMode then
        -- Draw naval combat
        combatSystem:draw(gameState)
    elseif gameState.settings.portMode then
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
        love.graphics.print("Scale: " .. string.format("%.2f", gameState.settings.scale), 10, 30)
        love.graphics.print("Window: " .. w .. "x" .. h, 10, 50)
    end
    
    -- Clear scissor and end the transformation
    love.graphics.setScissor()
    love.graphics.pop()
    
    -- Draw letterbox/pillarbox borders if needed
    if gameState.settings.scale < 1 or w ~= gameState.settings.baseWidth or h ~= gameState.settings.baseHeight then
        love.graphics.setColor(0.1, 0.1, 0.1, 1) -- Dark gray borders
        
        -- Draw edge lines to make the borders more visible
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        -- Top border edge
        if gameState.settings.offsetY > 0 then
            love.graphics.rectangle("fill", 0, gameState.settings.offsetY - 1, w, 1)
        end
        -- Bottom border edge
        if gameState.settings.offsetY > 0 then
            love.graphics.rectangle("fill", 0, gameState.settings.offsetY + (gameState.settings.baseHeight * gameState.settings.scale), w, 1)
        end
        -- Left border edge
        if gameState.settings.offsetX > 0 then
            love.graphics.rectangle("fill", gameState.settings.offsetX - 1, 0, 1, h)
        end
        -- Right border edge
        if gameState.settings.offsetX > 0 then
            love.graphics.rectangle("fill", gameState.settings.offsetX + (gameState.settings.baseWidth * gameState.settings.scale), 0, 1, h)
        end
    end
end

-- Helper function to convert screen coordinates to game coordinates
function convertMousePosition(x, y)
    -- Adjust for the offset and scaling
    local gameX = (x - (gameState.settings.offsetX or 0)) / (gameState.settings.scale or 1)
    local gameY = (y - (gameState.settings.offsetY or 0)) / (gameState.settings.scale or 1)
    
    return gameX, gameY
end

function love.mousemoved(x, y)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = convertMousePosition(x, y)
    
    if gameState.settings.combatMode then
        combatSystem:mousemoved(gameX, gameY, gameState)
    elseif gameState.settings.portMode then
        portRoyal:mousemoved(gameX, gameY, gameState)
    else
        gameMap:mousemoved(gameX, gameY, gameState)
    end
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = convertMousePosition(x, y)
    
    if gameState.settings.combatMode then
        combatSystem:mousepressed(gameX, gameY, button, gameState)
    elseif gameState.settings.portMode then
        portRoyal:mousepressed(gameX, gameY, button, gameState)
    else
        gameMap:mousepressed(gameX, gameY, button, gameState)
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- If in combat mode, end the battle
        if gameState.settings.combatMode then
            combatSystem:endBattle(gameState)
        -- If in port mode, return to map
        elseif gameState.settings.portMode then
            gameState.settings.portMode = false
            gameState.settings.currentPortScreen = "main"
        else
            love.event.quit()
        end
    elseif key == "f1" then
        gameState.settings.debug = not gameState.settings.debug
    elseif key == "f9" and gameState.settings.debug then
        -- Toggle button hitbox visualization in debug mode
        if gameState.settings.combatMode then
            combatSystem.showDebugHitboxes = not combatSystem.showDebugHitboxes
            print("Button hitboxes: " .. (combatSystem.showDebugHitboxes and "ON" or "OFF"))
        end
    elseif key == "p" then
        gameState.settings.isPaused = not gameState.settings.isPaused
    elseif key == "c" and not gameState.settings.combatMode then
        -- Debug key to start a test battle
        combatSystem:startBattle(gameState, "sloop")
    end
end```

## src/map.lua
```lua
-- Caribbean Map Module
local AssetUtils = require('utils.assetUtils')

local Map = {
    zones = {},
    hoveredZone = nil,
    -- Base map dimensions
    width = 800,
    height = 600,
    background = nil
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
    
    -- Load background image using AssetUtils
    self.background = AssetUtils.loadImage("assets/caribbean_map.png", "map")
    
    if self.background then
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
        -- Use deep blue ocean as fallback background
        love.graphics.setColor(0.1, 0.3, 0.5, 1)
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

local AssetUtils = require('utils.assetUtils')

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
    
    -- Validate required parameters
    assert(gameState, "gameState is required for PortRoyal:load")
    
    -- Load placeholder background images using AssetUtils
    self.backgrounds.main = AssetUtils.loadImage("assets/port_royal_main.png", "ui")
    if self.backgrounds.main then
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    self.backgrounds.tavern = AssetUtils.loadImage("assets/port-royal-tavern.png", "ui")
    if self.backgrounds.tavern then
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    self.backgrounds.shipyard = AssetUtils.loadImage("assets/port-royal-shipyard.png", "ui")
    if self.backgrounds.shipyard then
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
        -- Use AssetUtils to load the location-specific background
        locationBackground = AssetUtils.loadImage("assets/" .. locationKey .. "_main.png", "ui")
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        AssetUtils.drawImage(locationBackground, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        AssetUtils.drawImage(self.backgrounds.main, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "tavern" and self.backgrounds.tavern then
        AssetUtils.drawImage(self.backgrounds.tavern, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        AssetUtils.drawImage(self.backgrounds.shipyard, 0, 0, 0, 1, 1, self.width, self.height, "ui")
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

## src/utils/assetUtils.lua
```lua
-- Asset Utilities Module
-- Centralizes asset loading with better error handling

local AssetUtils = {}

-- Default placeholder images for different asset types
local DEFAULT_PLACEHOLDERS = {
    ship = {r = 0.2, g = 0.5, b = 0.8}, -- Blue rectangle for ships
    map = {r = 0.1, g = 0.3, b = 0.2},  -- Green rectangle for map elements
    ui = {r = 0.4, g = 0.4, b = 0.4},   -- Gray rectangle for UI elements
    dice = {r = 0.7, g = 0.7, b = 0.2}  -- Yellow rectangle for dice
}

-- Table to store loaded assets for reference
AssetUtils.loadedAssets = {}

-- Load an image with error handling
-- @param filePath - The path to the image file
-- @param assetType - Type of asset (ship, map, ui, dice) for fallback coloring
-- @return The loaded image or nil if loading failed
function AssetUtils.loadImage(filePath, assetType)
    -- Validate inputs
    if not filePath then
        print("ERROR: No file path provided to AssetUtils.loadImage")
        return nil
    end
    
    -- Normalize asset type
    assetType = assetType or "ui"
    
    -- Check if we've already loaded this asset
    if AssetUtils.loadedAssets[filePath] then
        return AssetUtils.loadedAssets[filePath]
    end
    
    -- Try to load the image
    local success, result = pcall(function() 
        return love.graphics.newImage(filePath)
    end)
    
    -- Handle the result
    if success then
        -- Store the loaded image for future reference
        AssetUtils.loadedAssets[filePath] = result
        return result
    else
        -- Print detailed error message
        print("ERROR: Failed to load asset: " .. filePath)
        print("Reason: " .. tostring(result))
        return nil
    end
end

-- Draw a placeholder rectangle for a missing asset
-- @param x, y - Position to draw at
-- @param width, height - Dimensions of the placeholder
-- @param assetType - Type of asset (ship, map, ui, dice) for coloring
function AssetUtils.drawPlaceholder(x, y, width, height, assetType)
    -- Get placeholder color based on asset type
    local colorDef = DEFAULT_PLACEHOLDERS[assetType] or DEFAULT_PLACEHOLDERS.ui
    
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw the placeholder
    love.graphics.setColor(colorDef.r, colorDef.g, colorDef.b, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw a border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw a missing texture pattern
    love.graphics.setColor(1, 0, 1, 0.5) -- Magenta
    love.graphics.line(x, y, x + width, y + height)
    love.graphics.line(x + width, y, x, y + height)
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

-- Safely draw an image, with fallback to placeholder if image is nil
-- @param image - The image to draw
-- @param x, y - Position to draw at
-- @param angle, sx, sy - Rotation and scale (optional)
-- @param width, height - Dimensions for placeholder if image is nil
-- @param assetType - Type of asset for placeholder coloring
function AssetUtils.drawImage(image, x, y, angle, sx, sy, width, height, assetType)
    if image then
        love.graphics.draw(image, x, y, angle or 0, sx or 1, sy or 1)
    else
        -- Draw placeholder if image is nil
        AssetUtils.drawPlaceholder(x, y, width or 32, height or 32, assetType)
    end
end

return AssetUtils```

## src/utils/shipUtils.lua
```lua
-- Ship Stats Utility Module
-- Centralizes all ship stat lookups and calculations

local ShipUtils = {}

-- Base stats for each ship class
local SHIP_BASE_STATS = {
    sloop = {
        speed = 3,
        firepowerDice = 1,
        durability = 10,
        crewCapacity = 4,
        baseCP = 2
    },
    brigantine = {
        speed = 2,
        firepowerDice = 3,
        durability = 20,
        crewCapacity = 8,
        baseCP = 4
    },
    galleon = {
        speed = 1,
        firepowerDice = 6,
        durability = 40,
        crewCapacity = 12,
        baseCP = 6
    }
}

-- Returns the complete set of base stats for a ship class
function ShipUtils.getShipBaseStats(shipClass)
    return SHIP_BASE_STATS[shipClass] or SHIP_BASE_STATS["sloop"]
end

-- Returns maximum durability (HP) for a ship class
function ShipUtils.getMaxHP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.durability or 10
end

-- Returns base firepower dice for a ship class
function ShipUtils.getBaseFirepowerDice(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.firepowerDice or 1
end

-- Returns base movement speed for a ship class
function ShipUtils.getBaseSpeed(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.speed or 3
end

-- Returns base crew points (CP) for a ship class
function ShipUtils.getBaseCP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.baseCP or 2
end

-- Returns crew capacity for a ship class
function ShipUtils.getCrewCapacity(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.crewCapacity or 4
end

return ShipUtils```

# Documentation

## docs/CombatSystem.md
# Combat System Documentation

## Overview

The combat system implements naval battles on a 10x10 hex grid. Ships of different classes occupy different numbers of hexes and have different movement speeds. The system includes movement mechanics, combat actions, and dice roll mechanics based on the Forged in the Dark system.

## Hex Grid System

The combat grid uses a "pointy-top" hex coordinate system with the following properties:

- Grid size: 10x10 hexes
- Coordinate system: uses axial coordinates (q,r) where:
  - q increases from west to east
  - r increases from northwest to southeast
  - (0,0) is the top-left hex

## Ship Classes on the Hex Grid

Ship classes have different sizes and shapes on the hex grid:

1. **Sloop (1-Hex Ship)**
   - Occupies 1 hex
   - Speed: 3 hexes per turn
   - Shape: Single hex

2. **Brigantine (2-Hex Ship)**
   - Occupies 2 hexes in a line
   - Speed: 2 hexes per turn
   - Shape: 2 hexes in a row

3. **Galleon (4-Hex Ship)**
   - Occupies 4 hexes in a kite shape
   - Speed: 1 hex per turn
   - Shape: 1 hex bow, 2 hex midship, 1 hex stern

## Combat Flow

1. **Battle Initialization**
   - Player and enemy ships are placed on opposite sides of the hex grid
   - Turn order is established (player first)

2. **Movement Phase**
   - The player can move their ship up to its maximum speed
   - Movement is done one hex at a time to adjacent hexes
   - Ships cannot move through occupied hexes

3. **Attack Phase** (not yet implemented)
   - After movement, ships can attack if in range
   - Attack success is based on dice rolls from the Forged in the Dark system

4. **End of Turn**
   - Turn passes to the enemy
   - The process repeats until one ship is defeated or retreats

## Game State Integration

Combat state is stored in the gameState object under the combat property with the following structure:

```lua
gameState.combat = {
    grid = {},  -- 2D array representing the hex grid
    playerShip = {
        class = "sloop",  -- Ship class (sloop, brigantine, galleon)
        size = 1,         -- Number of hexes occupied
        position = {5, 5}, -- {q, r} coordinates on grid
        orientation = 0,   -- Direction ship is facing (0-5, for 60° increments)
        movesRemaining = 3 -- Based on ship speed
    },
    enemyShip = {
        class = "sloop",
        size = 1,
        position = {2, 2},
        orientation = 3,
        movesRemaining = 3
    },
    turn = "player", -- Whose turn is it (player or enemy)
    phase = "movement", -- Current phase (movement, attack, etc.)
}
```

## Controls

- **Mouse Hover**: Highlights hexes on the grid
- **Click on Player Ship**: Selects the ship and shows valid movement hexes
- **Click on Valid Movement Hex**: Moves the ship to that hex
- **ESC Key**: Exits combat mode
- **C Key**: Debug key to start a test battle

## Triggering Combat

Naval battles can be triggered in two ways:

1. **Random Encounters**: When sailing between zones, there's a 20% chance of encountering an enemy ship
2. **Debug Mode**: Press 'C' key to start a test battle

## Combat Actions

The combat system includes three core actions:

1. **Fire Cannons**: Attack enemy ships
   - Uses the ship's firepower attribute to determine number of dice
   - Each success deals 1 point of damage
   - Damage is applied to the enemy ship's durability

2. **Evade**: Attempt to dodge enemy attacks
   - Uses the ship's class to determine number of dice (sloops get more dice)
   - Each success adds to the ship's evasion rating
   - Evasion rating reduces damage from attacks

3. **Repair**: Fix damage to the ship
   - Base 1 die for repairs
   - Surgeon crew role adds additional dice
   - Each success restores 5 HP to the ship
   - Cannot exceed ship's maximum durability

## Dice Mechanics

The combat system uses a dice pool mechanic based on Forged in the Dark:

- Actions roll a number of six-sided dice (d6) based on ship stats, crew, and modifiers
- Results are categorized:
  - 6: Full success
  - 4-5: Partial success
  - 1-3: Failure
- Outcome is determined by the highest die result, not the sum:
  - If any die shows 6, it's a success
  - If multiple dice show 6, it's a critical success
  - If the highest die is 4-5, it's a partial success
  - If no die shows 4+, it's a failure
- Each outcome level has different effects:
  - Critical Success: Maximum effect (e.g., 3 damage, 15 HP repair)
  - Success: Strong effect (e.g., 2 damage, 10 HP repair)
  - Partial Success: Minimal effect (e.g., 1 damage, 5 HP repair)
  - Failure: No effect

### Modifiers

The system supports modifiers that add or remove dice from action rolls:

- Positive modifiers add dice to the roll (e.g., "+1 die from Point Blank Range")
- Negative modifiers remove dice (e.g., "-2 dice from Target Evading")
- If the total dice count is reduced to 0 or negative, you roll 2 dice and take the worst (lowest) result
- Modifiers can be temporary (one-time use) or persistent (lasting until cleared)

### Action Types with Modifiers

1. **Fire Cannons**:
   - Base dice from ship's firepower attribute
   - +1 die for Point Blank Range (adjacent hex)
   - Negative dice equal to target's evade score

2. **Evade**:
   - Base dice from ship's class (sloop=3, brigantine=2, galleon=1)
   - Result sets ship's evade score until next turn
   - Evade score reduces attacker's dice when ship is targeted

3. **Repair**:
   - Base 1 die
   - Surgeon crew member adds dice equal to their skill level

## Game Flow

1. **Combat Initialization**:
   - Player and enemy ships are placed on the grid
   - Ships are given initial stats based on their class
   - Crew points are allocated based on crew size for the player and ship class for enemies

2. **Turn Structure**:
   - Each turn consists of a movement phase and an action phase
   - During movement phase, players can move their ship based on speed
   - During action phase, players can perform multiple actions based on crew points

3. **Movement Phase**:
   - Player selects their ship and can move to valid hexes
   - Movement is limited by the ship's speed stat
   - Cannot move through occupied hexes

4. **Action Phase**:
   - Player spends crew points to perform actions
   - Actions have different costs:
     - Fire Cannons: 1 CP
     - Evade: 1 CP
     - Repair: 2 CP
   - Multiple actions can be performed as long as crew points are available
   - Action results are calculated using dice rolls
   - Enemy AI takes its turn after the player

5. **End of Turn**:
   - Crew points are replenished for the next turn
   - Movement points are reset

6. **Combat Resolution**:
   - Combat ends when one ship is destroyed (0 durability)
   - Player can also retreat from battle

## Crew Point System

The crew point system connects ship crew size to combat actions:

- Each ship has a maximum number of crew points equal to its crew size
- The player's ship CP is based on the number of crew members
- Enemy ships' CP is based on their class (sloop=2, brigantine=4, galleon=6)
- Crew points are spent to perform actions during the action phase
- This creates an action economy where players must decide which actions are most important
- Larger ships with more crew can perform more actions each turn
- Creates a strategic layer where ship size and crew complement affect combat capability

## Future Enhancements

1. **Ship Orientation**: Implement proper ship orientation and rotation
2. **Wind Effects**: Integrate with the wind system for movement modifiers
3. **Boarding**: Add boarding mechanics for crew-vs-crew combat
4. **Visual Improvements**: Add proper ship sprites and battle animations
5. **Advanced Actions**: Ram, board, special abilities
6. **Crew Integration**: Deeper crew role impacts on combat

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

## docs/RevisedCombatSystem.md
# Pirate's Wager: Blood for Gold - Combat Rules (Revised)

## 1. Overview

This document outlines the rules for the tactical naval combat system in Pirate's Wager: Blood for Gold. Combat takes place on a 10x10 hex grid and emphasizes simultaneous maneuver planning, prediction, resource management (Sail Points & Crew Points), and risk/reward dice mechanics inspired by Forged in the Dark (FitD).

## 2. Key Concepts

*   **Hex Grid:** A 10x10 grid using pointy-top hexes and axial coordinates (q, r).
*   **Simultaneous Maneuvering:** Player and AI plan their movement and rotation secretly, and these maneuvers are resolved simultaneously.
*   **Sail Points (SP):** A per-turn resource representing a ship's agility, used to plan movement (moving hexes) and rotation (changing facing). SP varies by ship class.
*   **Crew Points (CP):** A per-turn resource representing the crew's capacity for action, used to execute combat actions like firing cannons, evading, or repairing. CP varies by ship class and current crew count (for the player).
*   **Orientation & Firing Arcs:** Ships have a specific facing (orientation). Weapons can only target hexes within defined firing arcs relative to the ship's current orientation.
*   **FitD Dice Mechanics:** Actions are resolved by rolling a pool of d6s. The highest die determines the outcome: Critical (multiple 6s), Success (highest is 6), Partial Success (highest is 4-5), or Failure (highest is 1-3).

## 3. Battlefield & Ships

*   **Grid:** 10x10 hexes.
*   **Ship Representation:**
    *   Ships occupy 1-4 hexes based on class.
    *   Each ship has a central anchor hex (`position {q, r}`) and an `orientation` (0-5, representing 60° increments, 0=North).
    *   Ship shapes rotate based on orientation.
*   **Ship Classes & Base Stats:**

    | Class      | Hex Size/Shape | Max HP | Base Max SP | Base Max CP | Base Speed (Moves/Turn) | Base Firepower (Dice) | Firing Arcs          |
    | :--------- | :------------- | :----- | :---------- | :---------- | :---------------------- | :-------------------- | :------------------- |
    | Sloop      | 1 hex          | 10     | 5           | 2 (*Note 1*) | 3                       | 1                     | Forward Only         |
    | Brigantine | 2 hexes (line) | 20     | 4           | 4 (*Note 1*) | 2                       | 3                     | Broadsides (Sides)   |
    | Galleon    | 4 hexes (kite) | 40     | 3           | 6 (*Note 1*) | 1                       | 6                     | Broadsides (Sides)   |

    *Note 1: Player ship's Max CP is based on `#gameState.crew.members`, capped by ship capacity. Enemy Max CP uses these base values.*

## 4. Combat Turn Structure

Each combat turn follows this sequence:

1.  **Start of Turn:**
    *   Replenish `currentSP` to `maxSP` for both ships.
    *   Replenish `currentCP` to `maxCP` for both ships.
    *   Clear any temporary turn-based effects or states (e.g., evade scores from previous turns if applicable, planned moves/rotations).
    *   Advance turn counter (`gameState.combat.turnCount`).

2.  **Enemy Planning Phase (Internal):**
    *   AI determines its intended maneuver (`plannedMove` hex and `plannedRotation` orientation).
    *   AI calculates SP cost and ensures the plan is affordable. Revises if necessary.
    *   AI determines its intended action(s) for the Action Phase (based on anticipated post-maneuver state).
    *   *Plans are stored internally, not revealed to the player.*

3.  **Player Planning Phase (Movement & Rotation):** (`gameState.combat.phase = "playerMovePlanning"`)
    *   Player sees current board state, their available SP.
    *   Player selects a target **orientation** using UI controls.
    *   Player selects a target **destination hex** from valid moves.
    *   UI displays SP cost for the planned move path + planned rotation change.
    *   Player cannot confirm a plan costing more than `currentSP`.
    *   Player **commits** the maneuver plan (stores destination in `playerShip.plannedMove`, final orientation in `playerShip.plannedRotation`).

4.  **Resolution Phase (Maneuver):** (`gameState.combat.phase = "maneuverResolution"`)
    *   **Rotation Update:** Internal `ship.orientation` state is instantly updated for *both* ships based on their `plannedRotation`.
    *   **Collision Check:** Check if `plannedMove` destinations conflict. Adjust `plannedMove` destinations for involved ships according to collision rules (e.g., stop 1 hex short).
    *   **Movement Execution & SP Deduction:**
        *   Animate both ships rotating towards their new orientation *while* moving towards their (potentially adjusted) destination hexes.
        *   Calculate the *actual* SP cost incurred for the maneuver performed (actual hexes moved + rotation steps).
        *   Deduct SP: `ship.currentSP -= actualCost`.
        *   Update internal `ship.position` state upon animation completion.
    *   Clear `plannedMove` and `plannedRotation` for both ships.

5.  **Player Planning Phase (Action):** (`gameState.combat.phase = "playerActionPlanning"`)
    *   Player sees the board state *after* maneuvers have resolved.
    *   Player selects actions (Fire, Evade, Repair, etc.) using available **CP**.
    *   Targeting for actions like "Fire Cannons" is constrained by the ship's current orientation and **firing arcs**.
    *   Selecting an action leads to the Confirmation Window (showing dice/modifiers/cost).
    *   Player Confirms or Cancels the action.

6.  **Resolution Phase (Action):** (`gameState.combat.phase = "actionResolution" or "displayingResult"`)
    *   If player confirmed action: Deduct CP, roll dice, determine outcome, apply effects (damage, repair, evade score).
    *   Display action results dynamically (dice roll visualization, outcome text, effect summary).
    *   AI executes its planned action(s) sequentially, using its remaining CP. AI targeting also respects firing arcs. Results are displayed dynamically.

7.  **End of Turn:**
    *   Perform any end-of-turn cleanup (e.g., expire temporary effects).
    *   Check win/loss conditions.
    *   Loop back to Start of Turn for the next turn number.

## 5. Core Mechanics Deep Dive

### 5.1. Sail Points (SP)

*   **Purpose:** Governs maneuverability (movement and rotation).
*   **Replenishment:** Fully restored to `maxSP` at the start of each turn.
*   **Costs (Planned - Subject to Tuning):**
    *   Move 1 Hex: 1 SP
    *   Rotate 60° (1 facing change): 1 SP
*   **Planning:** SP cost is calculated based on the planned path distance + the number of 60° steps needed to reach the planned orientation. The maneuver cannot be committed if `Total Cost > currentSP`.
*   **Deduction:** SP is deducted during the Maneuver Resolution phase based on the *actual* movement and rotation performed (after collision checks).

### 5.2. Crew Points (CP)

*   **Purpose:** Governs the crew's ability to perform actions (combat, repair, etc.).
*   **Replenishment:** Fully restored to `maxCP` at the start of each turn.
*   **Source:**
    *   Player: Number of crew members currently on ship (`#gameState.crew.members`), capped by ship's `crewCapacity`.
    *   Enemy: Based on ship class (`shipUtils.getBaseCP`).
*   **Costs:** Defined per action (see Actions List).
*   **Usage:** Spent during the Action Planning/Resolution phases to execute actions. Multiple actions can be performed if enough CP is available.

### 5.3. Movement & Rotation

*   **Planning:** Player/AI select both a target hex and a target orientation during their respective planning phases, constrained by SP.
*   **Resolution:** Planned rotations and moves resolve simultaneously during the Maneuver Resolution phase. Ship orientations update instantly internally, while visual rotation tweens alongside movement animation. SP is deducted based on the resolved maneuver.

### 5.4. Firing Arcs

*   **Definition:** Each ship class has defined arcs relative to its forward direction (Orientation 0).
    *   **Forward:** Directly ahead.
    *   **Sides (Broadsides):** To the left and right flanks.
    *   **Rear:** Directly behind.
*   **Constraint:** The "Fire Cannons" action can only target hexes that fall within an active firing arc based on the ship's *current* orientation (after maneuvering).
*   **Implementation:** `Combat:isInFiringArc(ship, targetQ, targetR)` checks validity. `Combat:getFiringArcHexes(ship)` calculates all valid target hexes within range.

### 5.5. Dice Rolls & Outcomes (FitD)

*   **Rolling:** Actions trigger a roll of 1-5 d6s. The pool size = Base Dice (from ship/action) + Modifiers (from crew, situation, evade scores). Max 5 dice.
*   **Zero Dice:** If modifiers reduce the pool to 0 or less, roll 2d6 and take the *lowest* result.
*   **Interpretation:** Determined by the *single highest die* rolled:
    *   **Critical Success:** Multiple 6s rolled. (Outcome Level 3)
    *   **Success:** Highest die is a 6. (Outcome Level 2)
    *   **Partial Success:** Highest die is 4 or 5. (Outcome Level 1)
    *   **Failure:** Highest die is 1, 2, or 3. (Outcome Level 0)
*   **Effects:** Actions have different effects based on the Outcome Level achieved (see Actions List).

### 5.6. Collisions

*   **Detection:** Checked during Maneuver Resolution based on `plannedMove` destinations.
*   **Rule (Basic):** If two ships plan to move to the same hex, both stop 1 hex short along their planned path. Their orientation changes still resolve as planned. SP cost is adjusted based on actual distance moved. *(More complex rules can be added later)*.

## 6. Actions List

Actions are performed during the Action Phase using CP. Player actions require confirmation via the Confirmation Window.

*   **Fire Cannons**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_FIRE` (1 CP)
    *   **Targeting:** Requires selecting an enemy ship hex within a valid firing arc and range.
    *   **Dice Pool:** `shipUtils.getBaseFirepowerDice(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   `+1` Point Blank (adjacent hex)
        *   `-X` Target Evading (where X is target's `evadeScore`)
        *   `+Y` Gunner Skill (Player only: `member.skill * Constants.GAME.GUNNER_SKILL_MULTIPLIER`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:**
        *   Critical (Lvl 3): `Constants.COMBAT.DAMAGE_CRITICAL` (3 HP) damage.
        *   Success (Lvl 2): `Constants.COMBAT.DAMAGE_SUCCESS` (2 HP) damage.
        *   Partial (Lvl 1): `Constants.COMBAT.DAMAGE_PARTIAL` (1 HP) damage.
        *   Failure (Lvl 0): No damage.
    *   **Note:** Target's `evadeScore` is reset to 0 *after* being applied to the incoming attack roll.

*   **Evade**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_EVADE` (1 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** `shipUtils.getBaseSpeed(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Sets the ship's `evadeScore` for the *next* turn (or until used).
        *   Critical (Lvl 3): `evadeScore = 3`
        *   Success (Lvl 2): `evadeScore = 2`
        *   Partial (Lvl 1): `evadeScore = 1`
        *   Failure (Lvl 0): `evadeScore = 0`
    *   **Note:** `evadeScore` reduces the number of dice rolled by enemies attacking this ship.

*   **Repair**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_REPAIR` (2 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** 1 (Base) + Modifiers.
    *   **Modifiers:**
        *   `+Y` Surgeon Skill (Player only: `member.skill`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Restores ship durability (HP).
        *   Critical (Lvl 3): `+Constants.COMBAT.REPAIR_CRITICAL` (15 HP) restored.
        *   Success (Lvl 2): `+Constants.COMBAT.REPAIR_SUCCESS` (10 HP) restored.
        *   Partial (Lvl 1): `+Constants.COMBAT.REPAIR_PARTIAL` (5 HP) restored.
        *   Failure (Lvl 0): No HP restored.
    *   **Note:** Cannot repair above the ship's maximum durability.

*   **End Turn** (Player Only Action Menu Option)
    *   **CP Cost:** 0 CP
    *   **Effect:** Immediately ends the player's action planning phase and proceeds to the enemy's action resolution (if applicable) or the start of the next turn.

## 7. AI Behavior

*   Enemy AI plans its maneuver (move + rotation) within its SP budget during the Enemy Planning Phase.
*   Enemy AI plans its action(s) based on its anticipated post-maneuver state (e.g., choosing Fire Cannons only if the player is expected to be in arc).
*   During the Action Resolution Phase, the AI executes its planned actions sequentially using its available CP, respecting firing arcs based on its *actual* post-maneuver position/orientation.
*   Current AI prioritizes: Repair (if low HP), Evade (if moderate HP), Fire Cannons (if high HP and target in arc), Move closer/into arc.

## 8. Winning & Losing

*   **Victory:** Enemy ship durability reaches 0 HP. Player may receive loot. Combat ends, return to Exploration mode.
*   **Defeat:** Player ship durability reaches 0 HP. Results in Game Over (current implementation).
*   **Retreat:** (Future Feature) Player or enemy moves off the battle grid. May involve a dice roll to determine success.

## 9. UI Summary

*   **Minimal HUD:** Displays Turn/Phase, Player HP/CP/SP, Enemy HP.
*   **Ship Info Window:** On-demand details via hover.
*   **Action Menu:** Contextual list of actions available during player action planning.
*   **Confirmation Window:** Displays dice pool breakdown, modifiers, and costs before committing an action.
*   **Result Overlay:** Temporarily displays dice results and effects after an action resolves.
*   **Maneuver Planning:** Visual feedback for planned path, orientation, and SP cost.
*   **Firing Arc Highlight:** Visual indication of valid target hexes when planning "Fire Cannons".

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
Speed: 2 hexes per turn (Movement Phase)
Firepower Dice: 3 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 6)
Durability: 20 HP
Crew Capacity: 8 members (Max 8 CP per turn) (Added CP link)
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
Speed: 1 hex per turn (Movement Phase)
Firepower Dice: 6 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 12)
Durability: 40 HP
Crew Capacity: 12 members (Max 12 CP per turn) (Added CP link)
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
Crew Roles: Navigator, Gunner, Surgeon, etc., boosting specific actions (e.g., Navigator reduces travel time, Surgeon adds dice to Repair, Gunner adds dice to Fire Cannons). (Added Gunner effect intent)
Character Sheet:
Role: Defines specialty.
Skill Level: 1-5, adding dice/bonuses to rolls.
Loyalty: 1-10 (low risks mutiny, high enhances performance).
Influences: Victories (+1), rum (+2), long voyages (-1/week).
Health: Hit points; injuries occur in combat.
Boon/Bane: One positive trait (e.g., “Sharp-Eyed”) and one negative (e.g., 
“Cursed”).
Recruitment: Found in taverns or via quests; elite crew require high 
reputation. Hiring costs gold. (Clarified hiring cost)
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
At Sea: Zone movement costs time (base 1 week, modified by wind/crew). Major actions like specific exploration events might cost time. Combat itself does not advance the week counter, but initiating it might if tied to an action. (Clarified time costs)
In Port: Actions take 1-3 weeks (e.g., 1 for basic repairs, 2 for investments, 1 for recruiting). (Confirmed port time costs)
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
Turn Structure: Movement Phase (spend move points based on Speed) followed by Action Phase (spend Crew Points). (Aligned with Section 3.1)
Actions: Core actions (Fire, Evade, Repair) cost CP (1/1/2 respectively). Others TBD. (Aligned with Section 3.1)
Dice Pools: 1-5 d6s for attacks, evasion, etc., based on ship, crew (e.g., Gunner skill for Fire, Surgeon for Repair), and context. (Added crew skill links)
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
Generated: Sun Mar 30 22:14:28 CDT 2025

# Source Code

## src/combat.lua
```lua
-- Combat System Module for Naval Battles
-- Implements a hex grid battlefield and ship combat mechanics

-- Import dice system
local diceModule = require('dice')
local diceSystem = diceModule.dice
local Modifier = diceModule.Modifier

-- Import ship utils
local shipUtils = require('utils.shipUtils')

-- Import constants
local Constants = require('constants')

local Combat = {
    -- Constants for the hex grid
    GRID_SIZE = Constants.COMBAT.GRID_SIZE,
    HEX_RADIUS = Constants.UI.COMBAT.HEX_RADIUS,
    HEX_HEIGHT = nil, -- Will be calculated based on radius
    HEX_WIDTH = nil,  -- Will be calculated based on radius
    
    -- Grid display properties
    gridOffsetX = Constants.UI.SCREEN_WIDTH / 2,  -- Position of grid on screen - will be centered
    gridOffsetY = 235,  -- Will be dynamically adjusted based on UI layout
    
    -- State variables for the battle
    hoveredHex = nil,   -- Currently hovered hex coordinates {q, r}
    selectedHex = nil,  -- Currently selected hex coordinates
    validMoves = {},    -- Valid move targets for selected ship
    
    -- SP planning phase variables
    plannedRotation = nil,  -- Temporary storage for rotation during planning
    hoveredMoveHex = nil,   -- Hex being hovered during movement planning
    plannedMoveHex = nil,   -- Hex selected as destination during planning
    rotationButtons = nil,  -- UI elements for rotation controls
    confirmManeuverButton = nil, -- UI element for confirm button
    
    -- Active battle data (will be stored in gameState.combat)
    -- Included here as reference/documentation
    --[[
    battle = {
        grid = {}, -- 2D array representing the hex grid
        playerShip = {
            class = "sloop",  -- Ship class (sloop, brigantine, galleon)
            size = 1,         -- Number of hexes occupied
            position = {5, 5}, -- {q, r} coordinates on grid
            orientation = 0,   -- Direction ship is facing (0-5, representing 60° increments)
            movesRemaining = 3 -- Based on ship speed
        },
        enemyShip = {
            class = "sloop",
            size = 1,
            position = {2, 2},
            orientation = 3,
            movesRemaining = 3
        },
        turn = "player", -- Who's turn is it (player or enemy)
        phase = "movement", -- Current phase (movement, attack, etc.)
    }
    --]]
    
    -- Action costs in crew points
    actionCosts = {
        fire = Constants.COMBAT.CP_COST_FIRE,     -- Fire Cannons costs
        evade = Constants.COMBAT.CP_COST_EVADE,   -- Evade costs
        repair = Constants.COMBAT.CP_COST_REPAIR  -- Repair costs (more labor intensive)
    },
    
    -- Ship definitions for the hex grid (size, shape, movement patterns)
    shipDefinitions = {
        sloop = {
            hexSize = 1,    -- Occupies 1 hex
            shape = {{0, 0}}, -- Relative {q, r} coordinates for each hex
            anchorOffset = {0, 0} -- Anchor point offset for sprite positioning
        },
        brigantine = {
            hexSize = 2,    -- Occupies 2 hexes
            -- Represents a ship that occupies 2 hexes in a line
            shape = {{0, 0}, {1, 0}}, -- Relative coordinates from anchor point
            anchorOffset = {0.5, 0} -- Anchor point is between the two hexes
        },
        galleon = {
            hexSize = 4,    -- Occupies 4 hexes
            -- Kite shape with 1 hex bow, 2 hex midship, 1 hex stern
            shape = {{0, 0}, {0, 1}, {1, 0}, {-1, 0}}, -- Relative coordinates from anchor point
            anchorOffset = {0, 0.5} -- Anchor point is in the middle of the kite shape
        }
    }
}

-- Initialize the combat system
function Combat:load(gameState)
    -- Calculate hex dimensions for drawing
    -- For pointy-top hexagons
    self.HEX_WIDTH = self.HEX_RADIUS * 2
    self.HEX_HEIGHT = math.sqrt(3) * self.HEX_RADIUS
    
    -- Create combat state in gameState if it doesn't exist
    if not gameState.combat then
        gameState.combat = {}
    end
    
    -- Load ship sprite assets
    local AssetUtils = require('utils.assetUtils')
    self.shipSprites = {
        sloop = AssetUtils.loadImage("assets/sloop-top-down.png", "ship"),
        brigantine = AssetUtils.loadImage("assets/brigantine-top-down.png", "ship"),
        galleon = nil -- Placeholder for future galleon sprite
    }
    
    -- Initialize the dice system
    self:initDiceSystem()
    
    -- Debug feature - enable with F9 key in debug mode
    self.showDebugHitboxes = false
    
    print("Combat system initialized")
    print("Hex dimensions: " .. self.HEX_WIDTH .. "x" .. self.HEX_HEIGHT)
end

-- Initialize a new battle
function Combat:initBattle(gameState, enemyShipClass)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:initBattle")
    assert(gameState.ship, "gameState.ship is required for Combat:initBattle")
    assert(gameState.ship.class, "gameState.ship.class is required for Combat:initBattle")
    
    -- Validate enemyShipClass if provided
    if enemyShipClass and not self.shipDefinitions[enemyShipClass] then
        print("WARNING: Unknown enemy ship class: " .. tostring(enemyShipClass) .. ". Defaulting to sloop.")
        enemyShipClass = "sloop"
    end
    
    -- Create a new grid
    local grid = self:createEmptyGrid()
    
    -- Configure player ship based on gameState
    local playerShipClass = gameState.ship.class
    local playerShipSpeed = shipUtils.getBaseSpeed(playerShipClass)
    
    -- Create battle state
    local battle = {
        grid = grid,
        playerShip = {
            class = playerShipClass,
            size = self.shipDefinitions[playerShipClass].hexSize,
            position = {2, 8}, -- Bottom-left area
            orientation = 0,   -- North-facing to start
            movesRemaining = playerShipSpeed,
            evadeScore = 0,    -- Evade score (reduces attacker's dice)
            hasActed = false,  -- Whether ship has performed an action this turn
            modifiers = {},    -- Active modifiers
            crewPoints = gameState.crew.members and #gameState.crew.members or 1, -- Available crew points for actions
            maxCrewPoints = gameState.crew.members and #gameState.crew.members or 1,  -- Maximum crew points per turn
            -- New SP and maneuver planning fields
            currentSP = self:getMaxSP(playerShipClass),
            maxSP = self:getMaxSP(playerShipClass),
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        enemyShip = {
            class = enemyShipClass or "sloop", -- Default to sloop if not specified
            size = self.shipDefinitions[enemyShipClass or "sloop"].hexSize,
            position = {7, 1}, -- Top-right area
            orientation = 3,   -- South-facing to start
            movesRemaining = shipUtils.getBaseSpeed(enemyShipClass or "sloop"),
            durability = shipUtils.getMaxHP(enemyShipClass or "sloop"), -- Set HP based on ship class
            evadeScore = 0,    -- Evade score (reduces attacker's dice)
            hasActed = false,  -- Whether ship has performed an action this turn
            modifiers = {},    -- Active modifiers
            crewPoints = shipUtils.getBaseCP(enemyShipClass or "sloop"), -- Based on ship class
            maxCrewPoints = shipUtils.getBaseCP(enemyShipClass or "sloop"),
            -- New SP and maneuver planning fields
            currentSP = self:getMaxSP(enemyShipClass or "sloop"),
            maxSP = self:getMaxSP(enemyShipClass or "sloop"),
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        turn = "player",
        phase = "playerMovePlanning", -- Updated to new phase system
        actionResult = nil,    -- Stores result of the last action
        turnCount = 1          -- Track number of turns
    }
    
    -- Place ships on the grid
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- Store battle in gameState
    gameState.combat = battle
    
    -- Process initial enemy planning for first turn
    self:processEnemyPlanning(battle)
    
    -- Always set up initial valid moves for player (regardless of phase)
    print("Calculating initial valid moves for player ship")
    self.validMoves = {}
    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
    self:calculateValidMoves(battle, battle.playerShip)
    print("Initial calculation found " .. #self.validMoves .. " valid moves")
    
    print("New naval battle initialized: " .. playerShipClass .. " vs " .. (enemyShipClass or "sloop"))
    return battle
end

-- Create an empty hex grid
function Combat:createEmptyGrid()
    local grid = {}
    for q = 0, self.GRID_SIZE - 1 do
        grid[q] = {}
        for r = 0, self.GRID_SIZE - 1 do
            grid[q][r] = {
                ship = nil,     -- Reference to ship in this hex
                isPlayerShip = false, -- Flag for player ship
                isEnemyShip = false,  -- Flag for enemy ship
                content = "empty" -- Can be "empty", "ship", or other battlefield elements
            }
        end
    end
    return grid
end

-- Place a ship on the grid
function Combat:placeShipOnGrid(grid, ship, battle)
    local q, r = ship.position[1], ship.position[2]
    local shape = self.shipDefinitions[ship.class].shape
    
    -- Transform shape based on orientation
    local transformedShape = self:transformShapeByOrientation(shape, ship.orientation)
    
    -- Place the ship on each relevant hex
    for _, offset in ipairs(transformedShape) do
        local hexQ = q + offset[1]
        local hexR = r + offset[2]
        
        -- Check if within grid bounds
        if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
            grid[hexQ][hexR].ship = ship
            grid[hexQ][hexR].content = "ship"
            
            -- Mark as player or enemy ship
            if ship == battle.playerShip then
                grid[hexQ][hexR].isPlayerShip = true
            else
                grid[hexQ][hexR].isEnemyShip = true
            end
        else
            print("Warning: Ship placement outside grid bounds: " .. hexQ .. "," .. hexR)
        end
    end
end

-- Transform a ship's shape based on orientation (0-5 for 60° increments)
function Combat:transformShapeByOrientation(shape, orientation)
    local transformed = {}
    
    -- Apply rotation based on orientation
    for _, hex in ipairs(shape) do
        local q, r = hex[1], hex[2]
        local newQ, newR
        
        -- Hex grid rotation formulas
        if orientation == 0 then      -- 0° (North)
            newQ, newR = q, r
        elseif orientation == 1 then  -- 60° (Northeast)
            newQ, newR = q + r, -q
        elseif orientation == 2 then  -- 120° (Southeast)
            newQ, newR = -r, q + r
        elseif orientation == 3 then  -- 180° (South)
            newQ, newR = -q, -r
        elseif orientation == 4 then  -- 240° (Southwest)
            newQ, newR = -q - r, q
        elseif orientation == 5 then  -- 300° (Northwest)
            newQ, newR = r, -q - r
        end
        
        table.insert(transformed, {newQ, newR})
    end
    
    return transformed
end

-- Get the hex at screen coordinates (x,y)
function Combat:getHexFromScreen(x, y)
    -- Approach: Find the closest hex center for maximum precision
    local closestHex = nil
    local minDistance = math.huge
    
    -- Try all grid hexes (brute force approach to guarantee accuracy)
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            -- Get hex center in pixel coordinates
            local hexX, hexY = self:hexToScreen(q, r)
            
            -- Calculate distance from mouse to hex center
            local dx = x - hexX
            local dy = y - hexY
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Check if this is in the hex (hexagons have radius = self.HEX_RADIUS)
            if dist <= self.HEX_RADIUS then
                -- Inside this hex - return immediately
                print("Found exact hex at " .. q .. "," .. r .. " (distance: " .. dist .. ")")
                return {q, r}
            end
            
            -- Otherwise track the closest hex
            if dist < minDistance then
                minDistance = dist
                closestHex = {q, r}
            end
        end
    end
    
    -- For debugging: Always return the closest hex, regardless of distance
    if closestHex then
        print("Returning closest hex " .. closestHex[1] .. "," .. closestHex[2] .. " (distance: " .. minDistance .. ")")
        return closestHex
    end
    
    -- Mouse is too far from any hex
    print("No hex found near " .. x .. "," .. y)
    return nil
end

-- Round floating point hex coordinates to the nearest hex
function Combat:roundHexCoord(q, r)
    local s = -q - r
    local rq = math.round(q)
    local rr = math.round(r)
    local rs = math.round(s)
    
    local qDiff = math.abs(rq - q)
    local rDiff = math.abs(rr - r)
    local sDiff = math.abs(rs - s)
    
    if qDiff > rDiff and qDiff > sDiff then
        rq = -rr - rs
    elseif rDiff > sDiff then
        rr = -rq - rs
    end
    
    return {rq, rr}
end

-- Helper function for Lua that mimics the math.round function from other languages
function math.round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

-- Mouse click handler for the playerMovePlanning phase
function Combat:handleManeuverPlanningClick(x, y, battle)
    -- Debug info
    print("Handling maneuver planning click at " .. x .. "," .. y)
    
    -- If rotation buttons are visible and clicked
    if self.plannedMoveHex and self.rotationButtons then
        -- Check if Rotate Left button is clicked
        if self:isPointInRect(x, y, self.rotationButtons.rotateLeft) then
            print("Rotate left button clicked")
            -- Rotate left (counter-clockwise)
            if self.plannedRotation == nil then
                -- If no rotation is set yet, start from the current ship orientation
                self.plannedRotation = (battle.playerShip.orientation - 1) % 6
            else
                -- Otherwise, just rotate from the current planned orientation
                self.plannedRotation = (self.plannedRotation - 1) % 6
            end
            print("New rotation: " .. self.plannedRotation)
            return true
        end
        
        -- Check if Rotate Right button is clicked
        if self:isPointInRect(x, y, self.rotationButtons.rotateRight) then
            print("Rotate right button clicked")
            -- Rotate right (clockwise)
            if self.plannedRotation == nil then
                -- If no rotation is set yet, start from the current ship orientation
                self.plannedRotation = (battle.playerShip.orientation + 1) % 6
            else
                -- Otherwise, just rotate from the current planned orientation
                self.plannedRotation = (self.plannedRotation + 1) % 6
            end
            print("New rotation: " .. self.plannedRotation)
            return true
        end
    end
    
    -- Check if Confirm button is clicked
    if self.plannedMoveHex and self.plannedRotation and self.confirmManeuverButton then
        if self:isPointInRect(x, y, self.confirmManeuverButton) then
            print("Confirm button clicked")
            -- Calculate SP cost
            local cost = self:calculateSPCost(battle.playerShip, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
            
            -- Check if player has enough SP
            if cost <= battle.playerShip.currentSP then
                print("Confirming maneuver - cost: " .. cost .. " SP")
                -- Store planned move and rotation in ship data
                battle.playerShip.plannedMove = {self.plannedMoveHex[1], self.plannedMoveHex[2]}
                battle.playerShip.plannedRotation = self.plannedRotation
                
                -- Advance to the next phase (maneuver resolution)
                self:advanceToNextPhase(battle)
                return true
            else
                -- Not enough SP - provide feedback
                print("Not enough Sail Points for this maneuver!")
                return true
            end
        end
    end
    
    -- Check if a hex on the grid was clicked
    print("Attempting to get hex from screen coordinates: " .. x .. "," .. y)
    
    -- First check if player ship is already selected
    if not self.selectedHex then
        -- Auto-select player ship to show valid moves
        print("Auto-selecting player ship")
        self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
        self:calculateValidMoves(battle, battle.playerShip)
    end
    
    -- Get clicked hex
    local clickedHex = self:getHexFromScreen(x, y)
    if clickedHex then
        local q, r = clickedHex[1], clickedHex[2]
        print("Clicked hex: " .. q .. "," .. r)
        
        -- Check if clicked hex is a valid move
        if self:isValidMove(q, r) then
            print("Valid move selected at " .. q .. "," .. r)
            -- Store as planned move destination
            self.plannedMoveHex = {q, r}
            
            -- If no rotation planned yet, initialize it to current orientation
            if not self.plannedRotation then
                self.plannedRotation = battle.playerShip.orientation
                print("Set initial rotation to current orientation: " .. self.plannedRotation)
            end
            
            return true
        elseif battle.grid[q] and battle.grid[q][r] and battle.grid[q][r].isPlayerShip then
            print("Player ship selected at " .. q .. "," .. r)
            -- If player clicked their ship, select it to show valid moves
            self.selectedHex = {q, r}
            
            -- Calculate and store valid moves for selected ship
            self:calculateValidMoves(battle, battle.playerShip)
            
            return true
        else
            print("Hex is not a valid move or player ship")
            
            -- Try recalculating valid moves in case they weren't set properly
            if #self.validMoves == 0 and self.selectedHex then
                print("Recalculating valid moves")
                self:calculateValidMoves(battle, battle.playerShip)
            end
        end
    else
        print("No hex found at click position")
    end
    
    return false
end

-- Helper function to check if a point is inside a rectangle
function Combat:isPointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width and
           y >= rect.y and y <= rect.y + rect.height
end

-- Get neighbors of a hex
-- Calculate valid moves for SP-based movement
function Combat:calculateValidMoves(battle, ship)
    self.validMoves = {} -- Clear previous valid moves
    
    -- Get the ship's current position and SP
    local shipQ, shipR = ship.position[1], ship.position[2]
    local availableSP = ship.currentSP
    
    print("Calculating valid moves for ship at " .. shipQ .. "," .. shipR .. " with " .. availableSP .. " SP")
    
    -- Each SP allows moving 1 hex, so the maximum distance we can move is equal to availableSP
    local maxDistance = availableSP
    
    -- Initialize an empty valid moves list
    self.validMoves = {}
    
    -- Loop through all grid cells within maxDistance
    for q = math.max(0, shipQ - maxDistance), math.min(self.GRID_SIZE - 1, shipQ + maxDistance) do
        for r = math.max(0, shipR - maxDistance), math.min(self.GRID_SIZE - 1, shipR + maxDistance) do
            -- Skip the ship's current position
            if q ~= shipQ or r ~= shipR then
                -- Calculate distance between ship and this hex
                local distance = self:hexDistance(shipQ, shipR, q, r)
                
                -- Check if within movement range
                if distance <= maxDistance then
                    -- Check if the hex is empty (no ships)
                    if battle.grid[q] and battle.grid[q][r] and 
                       not (battle.grid[q][r].isPlayerShip or battle.grid[q][r].isEnemyShip) then
                        -- This is a valid move destination, add it to valid moves
                        table.insert(self.validMoves, {q, r})
                        print("Added valid move: " .. q .. "," .. r .. " (distance: " .. distance .. ")")
                    else
                        print("Hex " .. q .. "," .. r .. " occupied or out of bounds")
                    end
                else
                    print("Hex " .. q .. "," .. r .. " too far (distance: " .. distance .. ")")
                end
            end
        end
    end
    
    -- Force some valid moves for debugging!
    if #self.validMoves == 0 then
        print("NO VALID MOVES FOUND - FORCING SOME FOR DEBUGGING")
        
        -- Add some moves adjacent to the ship
        local directions = {
            {1, 0}, {1, -1}, {0, -1}, 
            {-1, 0}, {-1, 1}, {0, 1}
        }
        
        for _, dir in ipairs(directions) do
            local newQ = shipQ + dir[1]
            local newR = shipR + dir[2]
            
            -- Check if within grid bounds
            if newQ >= 0 and newQ < self.GRID_SIZE and newR >= 0 and newR < self.GRID_SIZE then
                -- Check if empty
                if not (battle.grid[newQ][newR].isPlayerShip or battle.grid[newQ][newR].isEnemyShip) then
                    table.insert(self.validMoves, {newQ, newR})
                    print("FORCED valid move: " .. newQ .. "," .. newR)
                end
            end
        end
    end
    
    -- Print debug summary
    print("Calculated " .. #self.validMoves .. " valid moves for ship with " .. availableSP .. " SP")
end

function Combat:getHexNeighbors(q, r)
    local neighbors = {}
    
    -- Define different neighbors for even and odd rows in offset coordinates
    if r % 2 == 0 then
        -- Even row neighbors
        neighbors = {
            {q+1, r}, {q, r-1}, {q-1, r-1},
            {q-1, r}, {q-1, r+1}, {q, r+1}
        }
    else
        -- Odd row neighbors
        neighbors = {
            {q+1, r}, {q+1, r-1}, {q, r-1},
            {q-1, r}, {q, r+1}, {q+1, r+1}
        }
    end
    
    -- Filter neighbors to ensure they're within grid bounds
    local validNeighbors = {}
    for _, neighbor in ipairs(neighbors) do
        local nq, nr = neighbor[1], neighbor[2]
        if nq >= 0 and nq < self.GRID_SIZE and nr >= 0 and nr < self.GRID_SIZE then
            table.insert(validNeighbors, neighbor)
        end
    end
    
    return validNeighbors
end

-- Calculate valid moves for a ship from its current position
function Combat:calculateValidMoves(battle, ship)
    local q, r = ship.position[1], ship.position[2]
    local movesRemaining = ship.movesRemaining
    local validMoves = {}
    
    -- Use a breadth-first search to find all reachable hexes
    local queue = {{q, r, 0}} -- {q, r, distance}
    local visited = {[q .. "," .. r] = true}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local cq, cr, distance = current[1], current[2], current[3]
        
        if distance > 0 and distance <= movesRemaining then
            table.insert(validMoves, {cq, cr})
        end
        
        -- Only explore neighbors if within movement range
        if distance < movesRemaining then
            local neighbors = self:getHexNeighbors(cq, cr)
            for _, neighbor in ipairs(neighbors) do
                local nq, nr = neighbor[1], neighbor[2]
                local key = nq .. "," .. nr
                
                -- Skip if already visited
                if not visited[key] then
                    -- Skip if occupied by a ship
                    if battle.grid[nq][nr].content ~= "ship" then
                        visited[key] = true
                        table.insert(queue, {nq, nr, distance + 1})
                    end
                end
            end
        end
    end
    
    return validMoves
end

-- Move a ship to a new position
function Combat:moveShip(battle, ship, newQ, newR)
    -- Store old position for distance calculation
    local oldQ, oldR = ship.position[1], ship.position[2]
    
    -- Clear ship from old position
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            if battle.grid[q][r].ship == ship then
                battle.grid[q][r].ship = nil
                battle.grid[q][r].content = "empty"
                battle.grid[q][r].isPlayerShip = false
                battle.grid[q][r].isEnemyShip = false
            end
        end
    end
    
    -- Update ship position
    ship.position = {newQ, newR}
    
    -- Place ship at new position
    self:placeShipOnGrid(battle.grid, ship, battle)
    
    -- Update moves remaining
    local distance = self:hexDistance(oldQ, oldR, newQ, newR)
    ship.movesRemaining = ship.movesRemaining - distance
    
    return true
end

-- Calculate distance between two hexes in the offset coordinate system
function Combat:hexDistance(q1, r1, q2, r2)
    -- Convert from offset coordinates to cube coordinates
    local x1, y1, z1 = self:offsetToCube(q1, r1)
    local x2, y2, z2 = self:offsetToCube(q2, r2)
    
    -- Use cube coordinate distance formula
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2), math.abs(z1 - z2))
end

-- Convert offset coordinates to cube coordinates
function Combat:offsetToCube(q, r)
    local parity = r % 2  -- r mod 2, gives 0 for even rows and 1 for odd rows
    local x = q - (r - parity) / 2
    local z = r
    local y = -x - z
    return x, y, z
end

-- Calculate direction vector from one hex to another
function Combat:calculateDirectionVector(fromQ, fromR, toQ, toR)
    -- Normalize the direction
    local dirQ = toQ - fromQ
    local dirR = toR - fromR
    
    -- Simple normalization
    local length = math.sqrt(dirQ*dirQ + dirR*dirR)
    if length > 0 then
        dirQ = dirQ / length
        dirR = dirR / length
    end
    
    return {q = dirQ, r = dirR}
end

-- Get maximum Sail Points for a ship class
function Combat:getMaxSP(shipClass)
    -- Max SP values based on ship class as defined in RevisedCombatSystem.md
    if shipClass == "sloop" then
        return 5
    elseif shipClass == "brigantine" then
        return 4
    elseif shipClass == "galleon" then
        return 3
    else
        return 5 -- Default to sloop if unknown class
    end
end

-- Calculate the SP cost of a planned maneuver
function Combat:calculateSPCost(ship, targetQ, targetR, targetOrientation)
    local spCost = 0
    
    -- Movement cost: SP_COST_MOVE_HEX per hex moved
    if targetQ and targetR then
        local distance = self:hexDistance(ship.position[1], ship.position[2], targetQ, targetR)
        spCost = spCost + (distance * Constants.COMBAT.SP_COST_MOVE_HEX)
    end
    
    -- Rotation cost: SP_COST_ROTATE_60 per 60° orientation change
    if targetOrientation ~= nil then
        -- Calculate the shortest rotation distance between current and target orientation
        local currentOrientation = ship.orientation
        local rotationDistance = math.min(
            math.abs(targetOrientation - currentOrientation),
            6 - math.abs(targetOrientation - currentOrientation)
        )
        spCost = spCost + (rotationDistance * Constants.COMBAT.SP_COST_ROTATE_60)
    end
    
    return spCost
end

-- Convert hex coordinates to screen coordinates
function Combat:hexToScreen(q, r)
    -- For pointy-top hexagons
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid size in pixels
    -- For a pointy-top hex grid with brick layout pattern
    local gridWidthInHexes = self.GRID_SIZE
    local gridHeightInHexes = self.GRID_SIZE
    
    -- Total width = width of a column of hexes * number of columns
    local totalGridWidth = hexWidth * gridWidthInHexes
    -- Total height = height of a hex * number of rows, accounting for overlap
    local totalGridHeight = hexHeight * 0.75 * gridHeightInHexes + hexHeight * 0.25
    
    -- Make sure we have proper grid center coordinates
    -- This should be exactly the center of the available play area
    local centerX = self.gridOffsetX
    local centerY = self.gridOffsetY
    
    -- Calculate grid origin (top-left corner of the hex grid itself)
    -- This centers the actual hex grid within whatever panel is showing it
    local gridOriginX = centerX - (totalGridWidth / 2)
    local gridOriginY = centerY - (totalGridHeight / 2)
    
    -- Calculate the position for this specific hex
    local hexX = gridOriginX + (q * hexWidth)
    local hexY = gridOriginY + (r * hexHeight * 0.75)
    
    -- Apply horizontal offset for odd rows (brick pattern layout)
    if r % 2 == 1 then
        hexX = hexX + (hexWidth / 2)
    end
    
    return hexX, hexY
end

function Combat:startNewTurn(battle)
    -- Increment turn counter
    battle.turnCount = battle.turnCount + 1
    
    -- Replenish Sail Points and Crew Points for both ships
    self:replenishResources(battle.playerShip)
    self:replenishResources(battle.enemyShip)
    
    -- Clear planned moves and rotations
    battle.playerShip.plannedMove = nil
    battle.playerShip.plannedRotation = nil
    battle.enemyShip.plannedMove = nil
    battle.enemyShip.plannedRotation = nil
    
    -- Reset temporary planning variables in the Combat module
    self.plannedRotation = nil
    self.hoveredMoveHex = nil
    self.plannedMoveHex = nil
    self.rotationButtons = nil
    self.confirmManeuverButton = nil
    
    -- Clear any temporary turn-based effects
    battle.playerShip.evadeScore = 0
    battle.enemyShip.evadeScore = 0
    
    -- Set the initial phase for the new turn - enemy planning happens internally
    battle.phase = "playerMovePlanning"
    
    print("Starting new turn " .. battle.turnCount)
end

-- Replenish a ship's resources (SP and CP) at the start of a turn
function Combat:replenishResources(ship)
    -- Replenish Sail Points to maximum
    ship.currentSP = ship.maxSP
    
    -- Replenish Crew Points to maximum
    ship.crewPoints = ship.maxCrewPoints
    
    -- Reset action flags
    ship.hasActed = false
end

-- Process enemy ship's planning phase (internal AI logic)
function Combat:processEnemyPlanning(battle)
    -- Get enemy and player ships
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Get enemy position and orientation
    local enemyQ, enemyR = enemyShip.position[1], enemyShip.position[2]
    local enemyOrientation = enemyShip.orientation
    
    -- Calculate health percentage for strategy selection
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Choose strategy based on health
    local strategy
    if healthPercent < 0.3 then
        strategy = "defensive" -- Run away when critically damaged
    elseif healthPercent < 0.7 then
        strategy = "cautious"  -- Maintain medium distance when moderately damaged
    else
        strategy = "aggressive" -- Get close when healthy
    end
    
    -- Plan target destination and orientation
    local targetQ, targetR, targetOrientation = self:planEnemyManeuver(battle, strategy, enemyShip)
    
    -- Calculate SP cost for the planned maneuver
    local moveCost = self:calculateSPCost(enemyShip, targetQ, targetR, nil)
    local rotateCost = self:calculateSPCost(enemyShip, nil, nil, targetOrientation)
    local totalCost = moveCost + rotateCost
    
    -- Check if the maneuver is affordable
    if totalCost <= enemyShip.currentSP then
        -- Store the planned move and rotation
        enemyShip.plannedMove = {targetQ, targetR}
        enemyShip.plannedRotation = targetOrientation
        print("Enemy planning: Move to " .. targetQ .. "," .. targetR .. ", rotate to " .. targetOrientation .. " (SP cost: " .. totalCost .. ")")
    else
        -- If unaffordable, try simpler fallback options
        print("Enemy's preferred maneuver costs " .. totalCost .. " SP, which exceeds available " .. enemyShip.currentSP .. " SP. Using fallback plan.")
        
        -- Try just rotation, no movement
        if rotateCost <= enemyShip.currentSP then
            enemyShip.plannedMove = {enemyQ, enemyR} -- Stay in place
            enemyShip.plannedRotation = targetOrientation
            print("Enemy fallback plan: Stay in place, rotate to " .. targetOrientation .. " (SP cost: " .. rotateCost .. ")")
        
        -- Try just movement, no rotation
        elseif moveCost <= enemyShip.currentSP then
            enemyShip.plannedMove = {targetQ, targetR}
            enemyShip.plannedRotation = enemyOrientation -- Keep current orientation
            print("Enemy fallback plan: Move to " .. targetQ .. "," .. targetR .. ", keep orientation " .. enemyOrientation .. " (SP cost: " .. moveCost .. ")")
        
        -- If still unaffordable, do nothing
        else
            enemyShip.plannedMove = {enemyQ, enemyR} -- Stay in place
            enemyShip.plannedRotation = enemyOrientation -- Keep current orientation
            print("Enemy fallback plan: Do nothing (insufficient SP for any meaningful maneuver)")
        end
    end
end

-- Plan the enemy's maneuver based on the selected strategy
function Combat:planEnemyManeuver(battle, strategy, enemyShip)
    local playerShip = battle.playerShip
    local enemyQ, enemyR = enemyShip.position[1], enemyShip.position[2]
    local playerQ, playerR = playerShip.position[1], playerShip.position[2]
    
    -- Calculate direction to player
    local directionToPlayer = self:calculateDirectionVector(enemyQ, enemyR, playerQ, playerR)
    
    -- Calculate distance to player
    local distanceToPlayer = self:hexDistance(enemyQ, enemyR, playerQ, playerR)
    
    -- Plan target position
    local targetQ, targetR
    
    if strategy == "defensive" then
        -- Move away from player
        targetQ = enemyQ - directionToPlayer.q
        targetR = enemyR - directionToPlayer.r
        
        -- Clamp to grid bounds
        targetQ = math.max(0, math.min(self.GRID_SIZE - 1, targetQ))
        targetR = math.max(0, math.min(self.GRID_SIZE - 1, targetR))
        
    elseif strategy == "cautious" then
        -- Maintain medium distance (3 hexes) from player
        if distanceToPlayer < 3 then
            -- Too close, move away a bit
            targetQ = enemyQ - directionToPlayer.q
            targetR = enemyR - directionToPlayer.r
        elseif distanceToPlayer > 3 then
            -- Too far, move closer a bit
            targetQ = enemyQ + directionToPlayer.q
            targetR = enemyR + directionToPlayer.r
        else
            -- Just right, strafe around player
            -- Simple strafing: move perpendicular to player direction
            targetQ = enemyQ + directionToPlayer.r
            targetR = enemyR - directionToPlayer.q
        end
        
        -- Clamp to grid bounds
        targetQ = math.max(0, math.min(self.GRID_SIZE - 1, targetQ))
        targetR = math.max(0, math.min(self.GRID_SIZE - 1, targetR))
        
    else -- "aggressive"
        -- Move towards player, but stop 1 hex away (for firing)
        if distanceToPlayer > 2 then
            targetQ = enemyQ + directionToPlayer.q
            targetR = enemyR + directionToPlayer.r
        else
            -- Already close enough, stay in place
            targetQ = enemyQ
            targetR = enemyR
        end
    end
    
    -- Round to nearest integer for hex coordinates
    targetQ = math.floor(targetQ + 0.5)
    targetR = math.floor(targetR + 0.5)
    
    -- Plan target orientation - face towards player
    local targetOrientation = self:calculateOrientationTowards(enemyQ, enemyR, playerQ, playerR)
    
    return targetQ, targetR, targetOrientation
end

-- Calculate the orientation needed to face from one hex towards another
function Combat:calculateOrientationTowards(fromQ, fromR, toQ, toR)
    -- Convert to cube coordinates
    local fromX, fromY, fromZ = self:offsetToCube(fromQ, fromR)
    local toX, toY, toZ = self:offsetToCube(toQ, toR)
    
    -- Calculate direction vector in cube coordinates
    local dirX = toX - fromX
    local dirY = toY - fromY
    local dirZ = toZ - fromZ
    
    -- Normalize to get the primary direction
    local length = math.max(math.abs(dirX), math.abs(dirY), math.abs(dirZ))
    if length > 0 then
        dirX = dirX / length
        dirY = dirY / length
        dirZ = dirZ / length
    end
    
    -- Map the direction to the closest of the 6 orientations
    -- This is a simple mapping based on the angle
    local angle = math.atan2(dirY, dirX)
    local orientation = math.floor((angle + math.pi) / (math.pi/3)) % 6
    
    return orientation
end

-- Move to the next phase of combat
function Combat:advanceToNextPhase(battle)
    -- The phase progression according to RevisedCombatSystem.md:
    -- 1. Start of Turn (replenish resources)
    -- 2. Enemy Planning Phase (internal)
    -- 3. Player Planning Phase (Movement & Rotation) - "playerMovePlanning"
    -- 4. Resolution Phase (Maneuver) - "maneuverResolution"
    -- 5. Player Planning Phase (Action) - "playerActionPlanning"
    -- 6. Resolution Phase (Action) - "actionResolution" or "displayingResult"
    -- 7. End of Turn -> back to 1
    
    -- Current phase determines the next phase
    if battle.phase == "playerMovePlanning" then
        -- After player commits a movement plan, advance to maneuver resolution
        battle.phase = "maneuverResolution"
        
        -- Immediately process the maneuver resolution (with animation in the draw function)
        self:processManeuverResolution(battle)
        
    elseif battle.phase == "maneuverResolution" then
        -- After maneuvers resolve, advance to player action planning
        battle.phase = "playerActionPlanning"
        
    elseif battle.phase == "playerActionPlanning" then
        -- This transition happens when player confirms an action
        battle.phase = "actionResolution"
        
    elseif battle.phase == "actionResolution" then
        -- After action resolution, show results
        battle.phase = "displayingResult"
        
    elseif battle.phase == "displayingResult" then
        -- After player dismisses results, there could be more enemy actions
        -- or we end the turn
        -- For now, just end the turn
        self:startNewTurn(battle)
        
        -- Process enemy planning for the new turn
        self:processEnemyPlanning(battle)
    end
    
    print("Combat phase advanced to: " .. battle.phase)
end

-- Process maneuver resolution phase
function Combat:processManeuverResolution(battle)
    -- Check if both ships have planned moves and rotations
    if not battle.playerShip.plannedMove or not battle.playerShip.plannedRotation or
       not battle.enemyShip.plannedMove or not battle.enemyShip.plannedRotation then
        print("Cannot process maneuver resolution: Missing planned moves or rotations")
        return false
    end
    
    -- Extract planned moves and rotations
    local playerStartQ, playerStartR = battle.playerShip.position[1], battle.playerShip.position[2]
    local playerTargetQ, playerTargetR = battle.playerShip.plannedMove[1], battle.playerShip.plannedMove[2]
    local playerStartOrientation = battle.playerShip.orientation
    local playerTargetOrientation = battle.playerShip.plannedRotation
    
    local enemyStartQ, enemyStartR = battle.enemyShip.position[1], battle.enemyShip.position[2]
    local enemyTargetQ, enemyTargetR = battle.enemyShip.plannedMove[1], battle.enemyShip.plannedMove[2]
    local enemyStartOrientation = battle.enemyShip.orientation
    local enemyTargetOrientation = battle.enemyShip.plannedRotation
    
    -- 1. Update orientations immediately
    battle.playerShip.orientation = playerTargetOrientation
    battle.enemyShip.orientation = enemyTargetOrientation
    
    -- 2. Check for collision at target destination
    local collision = false
    local playerFinalQ, playerFinalR = playerTargetQ, playerTargetR
    local enemyFinalQ, enemyFinalR = enemyTargetQ, enemyTargetR
    
    if playerTargetQ == enemyTargetQ and playerTargetR == enemyTargetR then
        -- Collision detected - both ships trying to move to the same hex
        collision = true
        
        -- Simple collision rule: both ships stop 1 hex short along their path
        -- Calculate player's adjusted position
        local playerDirection = self:calculateDirectionVector(playerStartQ, playerStartR, playerTargetQ, playerTargetR)
        local playerDistance = self:hexDistance(playerStartQ, playerStartR, playerTargetQ, playerTargetR)
        
        if playerDistance > 1 then
            -- If moving more than 1 hex, stop 1 hex short
            playerFinalQ = math.floor(playerTargetQ - playerDirection.q + 0.5)
            playerFinalR = math.floor(playerTargetR - playerDirection.r + 0.5)
        else
            -- If only moving 1 hex, stay in place
            playerFinalQ, playerFinalR = playerStartQ, playerStartR
        end
        
        -- Calculate enemy's adjusted position
        local enemyDirection = self:calculateDirectionVector(enemyStartQ, enemyStartR, enemyTargetQ, enemyTargetR)
        local enemyDistance = self:hexDistance(enemyStartQ, enemyStartR, enemyTargetQ, enemyTargetR)
        
        if enemyDistance > 1 then
            -- If moving more than 1 hex, stop 1 hex short
            enemyFinalQ = math.floor(enemyTargetQ - enemyDirection.q + 0.5)
            enemyFinalR = math.floor(enemyTargetR - enemyDirection.r + 0.5)
        else
            -- If only moving 1 hex, stay in place
            enemyFinalQ, enemyFinalR = enemyStartQ, enemyStartR
        end
        
        print("Collision detected! Ships stopped short of destination.")
    end
    
    -- 3. Calculate actual SP costs for the moves performed
    local playerActualMoveCost = self:calculateSPCost(
        {position = {playerStartQ, playerStartR}, orientation = playerStartOrientation},
        playerFinalQ, playerFinalR, nil
    )
    
    local playerActualRotationCost = self:calculateSPCost(
        {position = {playerStartQ, playerStartR}, orientation = playerStartOrientation},
        nil, nil, playerTargetOrientation
    )
    
    local enemyActualMoveCost = self:calculateSPCost(
        {position = {enemyStartQ, enemyStartR}, orientation = enemyStartOrientation},
        enemyFinalQ, enemyFinalR, nil
    )
    
    local enemyActualRotationCost = self:calculateSPCost(
        {position = {enemyStartQ, enemyStartR}, orientation = enemyStartOrientation},
        nil, nil, enemyTargetOrientation
    )
    
    -- 4. Deduct SP
    battle.playerShip.currentSP = math.max(0, battle.playerShip.currentSP - (playerActualMoveCost + playerActualRotationCost))
    battle.enemyShip.currentSP = math.max(0, battle.enemyShip.currentSP - (enemyActualMoveCost + enemyActualRotationCost))
    
    -- 5. Remove ships from their old grid positions
    self:clearShipFromGrid(battle.grid, battle.playerShip)
    self:clearShipFromGrid(battle.grid, battle.enemyShip)
    
    -- 6. Update ship positions
    battle.playerShip.position = {playerFinalQ, playerFinalR}
    battle.enemyShip.position = {enemyFinalQ, enemyFinalR}
    
    -- 7. Place ships at their new grid positions
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- 8. Clear planned moves and rotations (no longer needed)
    battle.playerShip.plannedMove = nil
    battle.playerShip.plannedRotation = nil
    battle.enemyShip.plannedMove = nil
    battle.enemyShip.plannedRotation = nil
    
    -- 9. Advance to next phase (Action Planning)
    self:advanceToNextPhase(battle)
    
    return true
end

function Combat:hexToScreen(q, r)
    -- For pointy-top hexagons
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid size in pixels
    -- For a pointy-top hex grid with brick layout pattern
    local gridWidthInHexes = self.GRID_SIZE
    local gridHeightInHexes = self.GRID_SIZE
    
    -- Total width = width of a column of hexes * number of columns
    local totalGridWidth = hexWidth * gridWidthInHexes
    -- Total height = height of a hex * number of rows, accounting for overlap
    local totalGridHeight = hexHeight * 0.75 * gridHeightInHexes + hexHeight * 0.25
    
    -- Make sure we have proper grid center coordinates
    -- This should be exactly the center of the available play area
    local centerX = self.gridOffsetX
    local centerY = self.gridOffsetY
    
    -- Calculate grid origin (top-left corner of the hex grid itself)
    -- This centers the actual hex grid within whatever panel is showing it
    local gridOriginX = centerX - (totalGridWidth / 2)
    local gridOriginY = centerY - (totalGridHeight / 2)
    
    -- Calculate the position for this specific hex
    local hexX = gridOriginX + (q * hexWidth)
    local hexY = gridOriginY + (r * hexHeight * 0.75)
    
    -- Apply horizontal offset for odd rows (brick pattern layout)
    if r % 2 == 1 then
        hexX = hexX + (hexWidth / 2)
    end
    
    return hexX, hexY
end

-- Update combat state
function Combat:update(dt, gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Update game logic here
    -- For now, we're just focusing on the movement mechanics
end

-- Draw the hex grid and ships
function Combat:draw(gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Define fixed UI layout constants for our 800x600 reference resolution
    local SCREEN_WIDTH = 800
    local SCREEN_HEIGHT = 600
    local TOP_BAR_HEIGHT = 30     -- Reduced height for top status bar
    local BOTTOM_BAR_HEIGHT = 80  -- Height for action buttons and instructions
    
    -- Calculate available space for the battle grid
    -- Move grid up slightly to make more room for action feedback panel
    local GRID_TOP = TOP_BAR_HEIGHT + 5  -- Reduced top margin
    local GRID_BOTTOM = SCREEN_HEIGHT - BOTTOM_BAR_HEIGHT - 15 -- Added more space at bottom
    local GRID_HEIGHT = GRID_BOTTOM - GRID_TOP
    
    -- Define sidebar width
    local sidebarWidth = 140
    
    -- Calculate true hex dimensions for a pointy-top hex
    local hexWidth = self.HEX_RADIUS * math.sqrt(3)
    local hexHeight = self.HEX_RADIUS * 2
    
    -- Calculate the total grid dimensions more accurately
    -- For a pointy-top hex grid with brick layout pattern
    local totalGridWidth = hexWidth * self.GRID_SIZE
    local totalGridHeight = (hexHeight * 0.75 * self.GRID_SIZE) + (hexHeight * 0.25)
    
    -- Store dimensions for other methods
    self.gridScreenHeight = GRID_HEIGHT
    self.gridScreenWidth = totalGridWidth
    
    -- Define available center area (excluding sidebars)
    local availableWidth = SCREEN_WIDTH - (sidebarWidth * 2)
    
    -- Center coordinates of the play area (excluding sidebars)
    local centerX = SCREEN_WIDTH / 2
    local centerY = GRID_TOP + ((GRID_BOTTOM - GRID_TOP) / 2)
    
    -- Store these coordinates for the grid drawing functions
    self.gridOffsetX = centerX
    self.gridOffsetY = centerY
    
    -- Save play area constants for other functions
    self.layoutConstants = {
        topBarHeight = TOP_BAR_HEIGHT,
        gridTop = GRID_TOP,
        gridBottom = GRID_BOTTOM,
        sidebarWidth = sidebarWidth,
        bottomBarHeight = BOTTOM_BAR_HEIGHT,
        screenWidth = SCREEN_WIDTH,
        screenHeight = SCREEN_HEIGHT,
        availableWidth = availableWidth
    }
    
    -- Draw background and grid
    self:drawBackground(centerX, centerY, SCREEN_WIDTH, SCREEN_HEIGHT, gameState.settings.debug)
    self:drawGridBackground(GRID_TOP, GRID_HEIGHT, sidebarWidth, availableWidth)
    self:drawHexes(battle, gameState.settings.debug)
    
    -- Draw ships on top of hexes for better visibility
    self:drawShips(battle)
    
    -- Draw UI elements using the layout constants
    self:drawUI(gameState)
    
    -- Draw debug info if needed
    if gameState.settings.debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Grid offset: " .. self.gridOffsetX .. ", " .. self.gridOffsetY, 10, 550)
        love.graphics.print("Grid dims: " .. totalGridWidth .. "x" .. totalGridHeight, 10, 570)
        love.graphics.print("Play area: " .. GRID_TOP .. "-" .. GRID_BOTTOM, 200, 570)
    end
end

-- Draw the battle background
function Combat:drawBackground(centerX, centerY, screenWidth, screenHeight, showDebug)
    -- Draw the entire battle area background first
    love.graphics.setColor(Constants.COLORS.UI_BACKGROUND) -- Very dark blue/black background
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- If debug mode is on, draw a small dot at the exact center for reference
    if showDebug then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", centerX, centerY, 3)
    end
end

-- Draw the grid background (sea area)
function Combat:drawGridBackground(gridTop, gridHeight, sidebarWidth, availableWidth)
    -- Calculate grid background dimensions to fill available space between sidebars
    local gridAreaWidth = availableWidth - 20  -- -20 for small margin on each side
    local gridAreaHeight = gridHeight - 20    -- -20 for small margin on top and bottom
    
    -- Calculate the top-left corner of the grid background
    local gridAreaX = sidebarWidth + 10 -- Left sidebar width + small margin
    local gridAreaY = gridTop + 10     -- Top bar + small margin
    
    -- Draw grid background (sea)
    love.graphics.setColor(Constants.COLORS.SEA) -- Dark blue water
    love.graphics.rectangle("fill", 
        gridAreaX, 
        gridAreaY, 
        gridAreaWidth, 
        gridAreaHeight,
        5, 5 -- Rounded corners
    )
    
    -- Grid border
    love.graphics.setColor(Constants.COLORS.SEA_BORDER) -- Lighter blue border
    love.graphics.rectangle("line", 
        gridAreaX, 
        gridAreaY, 
        gridAreaWidth, 
        gridAreaHeight,
        5, 5 -- Rounded corners
    )
end

-- Draw grid hexes
function Combat:drawHexes(battle, showDebug)
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            local x, y = self:hexToScreen(q, r)
            
            -- Determine hex color based on content
            if battle.grid[q][r].isPlayerShip then
                -- Green for player ship (more transparent)
                love.graphics.setColor(Constants.COLORS.PLAYER_SHIP[1], Constants.COLORS.PLAYER_SHIP[2], 
                                      Constants.COLORS.PLAYER_SHIP[3], 0.5)
            elseif battle.grid[q][r].isEnemyShip then
                -- Red for enemy ship (more transparent)
                love.graphics.setColor(Constants.COLORS.ENEMY_SHIP[1], Constants.COLORS.ENEMY_SHIP[2], 
                                      Constants.COLORS.ENEMY_SHIP[3], 0.5)
            elseif self.plannedMoveHex and self.plannedMoveHex[1] == q and self.plannedMoveHex[2] == r then
                -- Green/yellow pulsing for planned destination
                local pulse = math.abs(math.sin(love.timer.getTime() * 2))
                love.graphics.setColor(0.3 + pulse * 0.6, 0.7 + pulse * 0.3, 0.2, 0.6 + pulse * 0.4)
            elseif self.hoveredHex and self.hoveredHex[1] == q and self.hoveredHex[2] == r then
                love.graphics.setColor(Constants.COLORS.HOVER) -- Yellow for hover
            elseif self.selectedHex and self.selectedHex[1] == q and self.selectedHex[2] == r then
                love.graphics.setColor(Constants.COLORS.SELECTED) -- Cyan for selected
            elseif self:isValidMove(q, r) then
                love.graphics.setColor(Constants.COLORS.VALID_MOVE) -- Light blue for valid moves
            else
                love.graphics.setColor(Constants.COLORS.EMPTY_WATER) -- Blue for empty water
            end
            
            -- Draw hex
            self:drawHex(x, y)
            
            -- Draw grid coordinates for debugging
            if showDebug then
                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.print(q .. "," .. r, x - 10, y)
            end
        end
    end
end

-- Draw a single hexagon at position x,y
function Combat:drawHex(x, y)
    local vertices = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i + math.pi / 6 -- Pointy-top orientation
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Fill hex
    love.graphics.polygon("fill", vertices)
    
    -- Draw hex outline
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.polygon("line", vertices)
end

-- Check if hex coordinates are in the valid moves list
function Combat:isValidMove(q, r)
    -- Debug logging
    print("Checking if " .. q .. "," .. r .. " is a valid move. Current valid moves: " .. #self.validMoves)
    
    if not self.validMoves or #self.validMoves == 0 then
        print("No valid moves available")
        return false
    end
    
    for i, move in ipairs(self.validMoves) do
        if move[1] == q and move[2] == r then
            print("Valid move found: " .. q .. "," .. r .. " (index " .. i .. ")")
            return true
        end
    end
    
    print("Not a valid move: " .. q .. "," .. r)
    return false
end

-- Draw ships with proper shapes and orientations
function Combat:drawShips(battle)
    -- Draw player ship
    local playerShip = battle.playerShip
    local pq, pr = playerShip.position[1], playerShip.position[2]
    
    -- Check if player ship is selected for movement
    local isSelected = false
    if self.selectedHex and 
       self.selectedHex[1] == pq and 
       self.selectedHex[2] == pr then
        isSelected = true
    end
    
    -- Draw player ship based on class using the multi-hex approach
    self:drawShipByClass(playerShip, true, isSelected, battle)
    
    -- Draw enemy ship
    local enemyShip = battle.enemyShip
    
    -- Draw enemy ship based on class using the multi-hex approach
    self:drawShipByClass(enemyShip, false, false, battle)
end

-- Draw a ship with appropriate shape based on class and orientation
-- This is the main function for drawing ships on the combat grid
function Combat:drawShipByClass(ship, isPlayer, isSelected, battle)
    local shipClass = ship.class
    local orientation = ship.orientation
    local anchorQ, anchorR = ship.position[1], ship.position[2]
    local scale = 1.0
    
    -- Set base color based on player/enemy
    local baseColor = isPlayer and Constants.COLORS.PLAYER_SHIP or Constants.COLORS.ENEMY_SHIP
    local outlineColor = {1, 1, 1, 0.8}
    
    -- Get the ship's shape and transform it based on orientation
    local shape = self.shipDefinitions[shipClass].shape
    local transformedShape = self:transformShapeByOrientation(shape, orientation)
    
    -- Draw each hex that the ship occupies
    for _, offset in ipairs(transformedShape) do
        local hexQ = anchorQ + offset[1]
        local hexR = anchorR + offset[2]
        
        -- Check if within grid bounds
        if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
            -- Draw hex outline to indicate ship occupation
            local hexX, hexY = self:hexToScreen(hexQ, hexR)
            
            -- Draw colored hex background for occupied hexes
            local hexColor = isPlayer and {0.2, 0.8, 0.2, 0.3} or {0.8, 0.2, 0.2, 0.3}
            love.graphics.setColor(hexColor)
            self:drawHex(hexX, hexY)
            
            -- Draw hex border with ship color
            love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.7)
            self:drawHexOutline(hexX, hexY)
        end
    end
    
    -- Calculate the ship's center position 
    local anchorOffset = self.shipDefinitions[shipClass].anchorOffset or {0, 0}
    local centerHexQ = anchorQ + anchorOffset[1]
    local centerHexR = anchorR + anchorOffset[2]
    local centerX, centerY = self:hexToScreen(centerHexQ, centerHexR)
    
    -- Draw the ship sprite at the center position
    local sprite = self.shipSprites[shipClass]
    
    -- Angle based on orientation (60 degrees per orientation step)
    -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
    local angle = orientation * math.pi / 3 + math.pi / 6
    
    if sprite then
        -- Draw the sprite with proper orientation and scale
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Scale the sprite to fit within the hex
        local spriteWidth = sprite:getWidth()
        local spriteHeight = sprite:getHeight()
        local maxDimension = self.HEX_RADIUS * 1.5
        
        -- Calculate scale based on sprite size and hex size
        local scaleX = maxDimension / spriteWidth
        local scaleY = maxDimension / spriteHeight
        local spriteScale = math.min(scaleX, scaleY) * scale
        
        -- Draw rotated sprite centered on the ship's position
        love.graphics.draw(
            sprite, 
            centerX, centerY, 
            angle, 
            spriteScale, spriteScale, 
            spriteWidth / 2, spriteHeight / 2
        )
    else
        -- Use the fallback geometric shape rendering if sprite is missing
        self:drawShipFallbackShape(centerX, centerY, shipClass, orientation, baseColor, outlineColor, scale)
    end
    
    -- Ship sprite is already rotated to show orientation - no need for extra indicators
    
    -- Draw a selection indicator if the ship is selected
    if isSelected then
        -- Draw a highlight around the entire ship
        for _, offset in ipairs(transformedShape) do
            local hexQ = anchorQ + offset[1]
            local hexR = anchorR + offset[2]
            
            if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
                local x, y = self:hexToScreen(hexQ, hexR)
                love.graphics.setColor(1, 1, 0, 0.5) -- Yellow highlight
                self:drawHexOutline(x, y)
            end
        end
        
        -- Draw a pulsing highlight effect on the anchor hex
        local anchorX, anchorY = self:hexToScreen(anchorQ, anchorR)
        local pulseScale = 1.0 + math.sin(love.timer.getTime() * 4) * 0.1
        love.graphics.setColor(1, 1, 0, 0.7) -- Yellow highlight
        love.graphics.circle("line", anchorX, anchorY, self.HEX_RADIUS * 0.5 * pulseScale)
    end
end

-- Draw a hex outline without fill
function Combat:drawHexOutline(x, y)
    local vertices = {}
    for i = 0, 5 do
        local angle = math.pi / 3 * i + math.pi / 6 -- Pointy-top orientation
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Draw hex outline
    love.graphics.polygon("line", vertices)
end

-- Draw a ship icon for UI elements like sidebars
function Combat:drawShipIconForUI(x, y, shipClass, orientation, isPlayer, isSelected, scale)
    -- Set default scale if not provided
    scale = scale or 1.0
    
    -- Set base color based on player/enemy
    local baseColor = isPlayer and Constants.COLORS.PLAYER_SHIP or Constants.COLORS.ENEMY_SHIP
    local outlineColor = {1, 1, 1, 0.8}
    
    -- Draw the ship sprite at the center position if available
    local sprite = self.shipSprites[shipClass]
    
    -- Angle based on orientation (60 degrees per orientation step)
    -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
    local angle = orientation * math.pi / 3 + math.pi / 6
    
    if sprite then
        -- Draw the sprite with proper orientation and scale
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Scale the sprite to fit within the icon area
        local spriteWidth = sprite:getWidth()
        local spriteHeight = sprite:getHeight()
        local maxDimension = self.HEX_RADIUS * 1.5 * scale
        
        -- Calculate scale based on sprite size and desired icon size
        local scaleX = maxDimension / spriteWidth
        local scaleY = maxDimension / spriteHeight
        local spriteScale = math.min(scaleX, scaleY)
        
        -- Draw rotated sprite
        love.graphics.draw(
            sprite, 
            x, y, 
            angle, 
            spriteScale, spriteScale, 
            spriteWidth / 2, spriteHeight / 2
        )
    else
        -- Use fallback geometric shape if sprite is missing
        self:drawShipFallbackShape(x, y, shipClass, orientation, baseColor, outlineColor, scale)
    end
    
    -- Ship sprite is already rotated to show orientation
    -- No need for additional direction indicators as the sprite rotation is sufficient
    
    -- Draw selection indicator if needed
    if isSelected then
        love.graphics.setColor(1, 1, 0, 0.7) -- Yellow highlight
        love.graphics.circle("line", x, y, self.HEX_RADIUS * 0.8 * scale)
    end
end

-- Fallback shape rendering for ships without sprites
function Combat:drawShipFallbackShape(x, y, shipClass, orientation, baseColor, outlineColor, scale)
    -- Set default scale if not provided
    scale = scale or 1.0
    
    -- Calculate ship points based on orientation
    local points = {}
    
    if shipClass == "sloop" then
        -- Simple triangular shape for sloop
        local size = self.HEX_RADIUS * 0.7 * scale
        
        -- Define the triangle points based on orientation
        if orientation == 0 then -- North
            points = {
                x, y - size,          -- Bow
                x - size * 0.7, y + size * 0.5,  -- Port (left) corner
                x + size * 0.7, y + size * 0.5   -- Starboard (right) corner
            }
        elseif orientation == 1 then -- Northeast
            points = {
                x + size * 0.87, y - size * 0.5,  -- Bow
                x - size * 0.5, y - size * 0.87,  -- Port corner
                x + size * 0.5, y + size * 0.87   -- Starboard corner
            }
        elseif orientation == 2 then -- Southeast
            points = {
                x + size * 0.87, y + size * 0.5,  -- Bow
                x + size * 0.5, y - size * 0.87,  -- Port corner
                x - size * 0.5, y + size * 0.87   -- Starboard corner
            }
        elseif orientation == 3 then -- South
            points = {
                x, y + size,          -- Bow
                x + size * 0.7, y - size * 0.5,  -- Port corner
                x - size * 0.7, y - size * 0.5   -- Starboard corner
            }
        elseif orientation == 4 then -- Southwest
            points = {
                x - size * 0.87, y + size * 0.5,  -- Bow
                x + size * 0.5, y + size * 0.87,  -- Port corner
                x - size * 0.5, y - size * 0.87   -- Starboard corner
            }
        elseif orientation == 5 then -- Northwest
            points = {
                x - size * 0.87, y - size * 0.5,  -- Bow
                x - size * 0.5, y + size * 0.87,  -- Port corner
                x + size * 0.5, y - size * 0.87   -- Starboard corner
            }
        end
        
        -- Draw the ship
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", points)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", points)
        
    elseif shipClass == "brigantine" then
        -- More complex rectangular shape for brigantine
        local sizeX = self.HEX_RADIUS * 0.85 * scale
        local sizeY = self.HEX_RADIUS * 0.5 * scale
        
        -- Create a rectangle and rotate it based on orientation
        local points = {
            -sizeX, -sizeY,   -- Top-left
            sizeX, -sizeY,    -- Top-right
            sizeX, sizeY,     -- Bottom-right
            -sizeX, sizeY     -- Bottom-left
        }
        
        -- Adjust rotation based on orientation
        -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
        local angle = orientation * math.pi / 3 + math.pi / 6
        
        -- Rotate and translate points
        local rotatedPoints = {}
        for i = 1, #points, 2 do
            local px, py = points[i], points[i+1]
            
            -- Rotate
            local rx = px * math.cos(angle) - py * math.sin(angle)
            local ry = px * math.sin(angle) + py * math.cos(angle)
            
            -- Translate
            rotatedPoints[i] = x + rx
            rotatedPoints[i+1] = y + ry
        end
        
        -- Draw the ship
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", rotatedPoints)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", rotatedPoints)
        
    elseif shipClass == "galleon" then
        -- Big ship with kite shape for galleon
        local size = self.HEX_RADIUS * 0.9 * scale
        
        -- Kite shape points
        local points = {
            0, -size,        -- Top (bow)
            size/2, 0,       -- Right (midship)
            0, size,         -- Bottom (stern)
            -size/2, 0       -- Left (midship)
        }
        
        -- Adjust rotation based on orientation
        -- Add pi/6 (30 degrees) to make ships face flat sides instead of points
        local angle = orientation * math.pi / 3 + math.pi / 6
        
        -- Rotate and translate points
        local rotatedPoints = {}
        for i = 1, #points, 2 do
            local px, py = points[i], points[i+1]
            
            -- Rotate
            local rx = px * math.cos(angle) - py * math.sin(angle)
            local ry = px * math.sin(angle) + py * math.cos(angle)
            
            -- Translate
            rotatedPoints[i] = x + rx
            rotatedPoints[i+1] = y + ry
        end
        
        -- Draw the galleon body
        love.graphics.setColor(baseColor)
        love.graphics.polygon("fill", rotatedPoints)
        love.graphics.setColor(outlineColor)
        love.graphics.polygon("line", rotatedPoints)
    else
        -- Fallback to simple circle for unknown ship types
        love.graphics.setColor(baseColor)
        love.graphics.circle("fill", x, y, self.HEX_RADIUS * 0.7 * scale)
        love.graphics.setColor(outlineColor)
        love.graphics.circle("line", x, y, self.HEX_RADIUS * 0.7 * scale)
    end
end

-- Draw UI elements for the battle
function Combat:drawUI(gameState)
    local battle = gameState.combat
    
    -- Use layout constants from draw function
    local layout = self.layoutConstants
    if not layout then return end
    
    -- Calculate player/enemy stats
    local playerMaxHP = shipUtils.getMaxHP(battle.playerShip.class)
    local playerHP = gameState.ship.durability
    local playerHP_Percent = playerHP / playerMaxHP
    
    local enemyMaxHP = shipUtils.getMaxHP(battle.enemyShip.class)
    local enemyHP = battle.enemyShip.durability
    local enemyHP_Percent = enemyHP / enemyMaxHP
    
    -- Draw top status bar
    self:drawTopBar(battle, layout.screenWidth)
    
    -- Draw player and enemy sidebars
    self:drawPlayerSidebar(battle, gameState, playerHP, playerMaxHP, playerHP_Percent, layout)
    self:drawEnemySidebar(battle, enemyHP, enemyMaxHP, enemyHP_Percent, layout)
    
    -- Draw action feedback panel if we have a result
    local buttonsY = self:drawFeedbackPanel(battle, layout)
    
    -- Draw action buttons panel based on the game phase
    self:drawActionPanel(battle, buttonsY, layout)
    
    -- Draw instructions panel
    self:drawInstructionsPanel(battle, buttonsY, layout)
end

-- Draw the top status bar
function Combat:drawTopBar(battle, screenWidth)
    local topBarHeight = self.layoutConstants.topBarHeight
    
    -- Draw the panel background
    self:drawUIPanel(0, 0, screenWidth, topBarHeight)
    
    -- Battle status indicator (left)
    local statusColor = Constants.COLORS.PLAYER_SHIP -- Green for player turn
    local statusText = "YOUR TURN"
    if battle.turn ~= "player" then
        statusColor = Constants.COLORS.ENEMY_SHIP -- Red for enemy turn
        statusText = "ENEMY TURN"
    end
    
    love.graphics.setColor(statusColor)
    love.graphics.print(statusText, 20, 8)
    
    -- Phase indicator (center)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("PHASE: " .. battle.phase:upper(), 0, 8, screenWidth, "center")
    
    -- Turn counter (right)
    love.graphics.setColor(1, 0.9, 0.3, 0.9) -- Yellow-gold for turn counter
    love.graphics.print("TURN: " .. battle.turnCount, screenWidth - 80, 8)
end

-- Draw the player's sidebar
function Combat:drawPlayerSidebar(battle, gameState, playerHP, playerMaxHP, playerHP_Percent, layout)
    local gridTop = layout.gridTop
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    
    -- Draw the sidebar panel
    self:drawUIPanel(5, gridTop, sidebarWidth - 10, gridBottom - gridTop)
    
    -- Player ship title with class icon
    love.graphics.setColor(0.2, 0.7, 0.9, 1) -- Blue for player
    love.graphics.print("YOUR SHIP", 15, gridTop + 10)
    love.graphics.print(string.upper(battle.playerShip.class), 15, gridTop + 30)
    
    -- Ship type icon or simple ship silhouette
    self:drawShipIconForUI(75, gridTop + 65, battle.playerShip.class, 0, true, false, 0.8)
    
    -- Draw player ship HP bar
    love.graphics.setColor(Constants.COLORS.UI_TEXT)
    love.graphics.print("DURABILITY:", 15, gridTop + 120)
    self:drawProgressBar(15, gridTop + 140, sidebarWidth - 30, 16, playerHP_Percent, Constants.COLORS.HEALTH, Constants.COLORS.DAMAGE)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(playerHP .. "/" .. playerMaxHP, 50, gridTop + 142)
    
    -- Draw SP and CP based on phase
    if battle.phase == "playerMovePlanning" or battle.phase == "maneuverResolution" then
        -- Show SP for movement planning phases
        self:drawSailPointsInfo(battle.playerShip, gridTop, sidebarWidth)
    else
        -- Show CP for action phases
        self:drawCrewPointsInfo(battle.playerShip, gridTop, sidebarWidth)
    end
    
    -- Draw evade score if active
    if battle.playerShip.evadeScore > 0 then
        love.graphics.setColor(0.3, 0.8, 0.9, 1)
        love.graphics.print("EVADE SCORE: " .. battle.playerShip.evadeScore, 15, gridTop + 210)
    end
    
    -- Draw week counter at bottom of player panel
    love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
    love.graphics.print("WEEK: " .. gameState.time.currentWeek, 15, gridBottom - 30)
end

-- Draw Sail Points (SP) info for a ship
function Combat:drawSailPointsInfo(ship, gridTop, sidebarWidth)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("SAIL POINTS:", 15, gridTop + 165)
    local spPercent = ship.currentSP / ship.maxSP
    self:drawProgressBar(15, gridTop + 185, sidebarWidth - 30, 16, spPercent, Constants.COLORS.BUTTON_EVADE, Constants.COLORS.UI_BORDER)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(ship.currentSP .. "/" .. ship.maxSP, 50, gridTop + 187)
    
    -- Display any planned move SP cost
    if self.plannedMoveHex and self.plannedRotation then
        local cost = self:calculateSPCost(ship, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
        if cost > 0 then
            love.graphics.setColor(1, 0.8, 0.2, 1) -- Gold/yellow for costs
            love.graphics.print("PLANNED COST: " .. cost .. " SP", 15, gridTop + 210)
        end
    end
end

-- Draw movement info for a ship (legacy function, kept for compatibility)
function Combat:drawMovementInfo(ship, gridTop, sidebarWidth)
    self:drawSailPointsInfo(ship, gridTop, sidebarWidth)
end

-- Draw crew points info for a ship
function Combat:drawCrewPointsInfo(ship, gridTop, sidebarWidth)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("CREW POINTS:", 15, gridTop + 165)
    local cpPercent = ship.crewPoints / ship.maxCrewPoints
    self:drawProgressBar(15, gridTop + 185, sidebarWidth - 30, 16, cpPercent, Constants.COLORS.GOLD, {0.5, 0.4, 0.1, 1})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(ship.crewPoints .. "/" .. ship.maxCrewPoints, 50, gridTop + 187)
end

-- Draw the enemy sidebar
function Combat:drawEnemySidebar(battle, enemyHP, enemyMaxHP, enemyHP_Percent, layout)
    local gridTop = layout.gridTop
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    local screenWidth = layout.screenWidth
    
    -- Draw the sidebar panel
    self:drawUIPanel(screenWidth - sidebarWidth + 5, gridTop, sidebarWidth - 10, gridBottom - gridTop)
    
    -- Enemy ship title
    love.graphics.setColor(0.9, 0.3, 0.3, 1) -- Red for enemy
    love.graphics.print("ENEMY SHIP", screenWidth - sidebarWidth + 15, gridTop + 10)
    love.graphics.print(string.upper(battle.enemyShip.class), screenWidth - sidebarWidth + 15, gridTop + 30)
    
    -- Draw a simple ship outline based on class
    self:drawShipIconForUI(screenWidth - sidebarWidth + 75, gridTop + 65, battle.enemyShip.class, 3, false, false, 0.8)
    
    -- Draw enemy ship HP bar
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("DURABILITY:", screenWidth - sidebarWidth + 15, gridTop + 120)
    self:drawProgressBar(screenWidth - sidebarWidth + 15, gridTop + 140, sidebarWidth - 30, 16, 
                        enemyHP_Percent, {0.2, 0.8, 0.2, 1}, {0.8, 0.2, 0.2, 1})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(enemyHP .. "/" .. enemyMaxHP, screenWidth - sidebarWidth + 50, gridTop + 142)
    
    -- Draw enemy ship additional info: SP and Evade Score
    local yPos = gridTop + 165
    
    -- Show SP in movement planning phases
    if battle.phase == "playerMovePlanning" or battle.phase == "maneuverResolution" then
        love.graphics.setColor(0.4, 0.6, 0.9, 1) -- Blue for SP
        love.graphics.print("SAIL POINTS: " .. battle.enemyShip.currentSP .. "/" .. battle.enemyShip.maxSP, 
                           screenWidth - sidebarWidth + 15, yPos)
        yPos = yPos + 25
    end
    
    -- Show evade score if it exists
    if battle.enemyShip.evadeScore > 0 then
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.print("EVADE SCORE: " .. battle.enemyShip.evadeScore, 
                           screenWidth - sidebarWidth + 15, yPos)
    end
end

-- Draw the action feedback panel
function Combat:drawFeedbackPanel(battle, layout)
    local screenWidth = layout.screenWidth
    local screenHeight = layout.screenHeight
    local gridBottom = layout.gridBottom
    local sidebarWidth = layout.sidebarWidth
    local FEEDBACK_HEIGHT = Constants.UI.COMBAT.FEEDBACK_HEIGHT
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    local INSTRUCTIONS_HEIGHT = Constants.UI.COMBAT.INSTRUCTIONS_HEIGHT
    
    -- Will be set based on whether feedback is shown
    local buttonsY = 0
    
    if battle.actionResult then
        -- Position the feedback panel below the grid but keep room for buttons
        local feedbackY = gridBottom + 5
        
        -- Make sure there's room for the feedback panel and buttons
        local totalNeededHeight = FEEDBACK_HEIGHT + CONTROLS_HEIGHT + INSTRUCTIONS_HEIGHT + 10
        local availableHeight = screenHeight - gridBottom - 5
        
        if totalNeededHeight > availableHeight then
            -- Not enough space - make room by moving up
            local extraNeeded = totalNeededHeight - availableHeight
            feedbackY = feedbackY - extraNeeded
        end
        
        -- Action result panel with translucent dark background
        self:drawUIPanel(sidebarWidth + 5, feedbackY, screenWidth - (sidebarWidth * 2) - 10, FEEDBACK_HEIGHT)
        
        -- Draw the action result content
        self:drawActionResultContent(battle.actionResult, feedbackY, sidebarWidth, screenWidth)
        
        buttonsY = feedbackY + FEEDBACK_HEIGHT + 5  -- Position buttons below feedback panel
    else
        -- If no feedback, buttons go at the bottom of the grid area
        buttonsY = gridBottom + 5  -- Small gap between grid and buttons
    end
    
    return buttonsY
end

-- Draw the content of the action result panel
function Combat:drawActionResultContent(actionResult, feedbackY, sidebarWidth, screenWidth)
    -- Action title
    local title
    -- Check if action was successful or failed due to lack of crew points
    if actionResult.success == false then
        -- Failed action due to insufficient crew points
        title = actionResult.message
        love.graphics.setColor(1, 0.3, 0.3, 1)  -- Red for error message
    else
        -- Successful action
        if actionResult.action == "fire" then
            love.graphics.setColor(0.9, 0.3, 0.3, 1) -- Red for attack
            title = (actionResult.attacker == "player" and "YOU FIRED CANNONS" or "ENEMY FIRED CANNONS")
            title = title .. " - DAMAGE: " .. actionResult.damage
        elseif actionResult.action == "evade" then
            love.graphics.setColor(0.3, 0.6, 0.9, 1) -- Blue for evade
            title = (actionResult.ship == "player" and "YOU EVADED" or "ENEMY EVADED")
            title = title .. " - EVADE SCORE: " .. actionResult.evadeScore
        elseif actionResult.action == "repair" then
            love.graphics.setColor(0.3, 0.9, 0.3, 1) -- Green for repair
            title = (actionResult.ship == "player" and "YOU REPAIRED" or "ENEMY REPAIRED")
            title = title .. " - HP RESTORED: " .. actionResult.repairAmount
        end
    end
    
    -- Display title centered at top of feedback panel
    love.graphics.printf(title, sidebarWidth + 15, feedbackY + 10, screenWidth - (sidebarWidth * 2) - 30, "center")
    
    -- Skip dice display for failed actions
    if actionResult.success == false then
        -- No further content if it's just an error message
        return
    end
    
    -- Display dice rolled with visual highlights - dice that "count" will be raised
    love.graphics.setColor(1, 1, 1, 1)
    local diceX = sidebarWidth + 20
    local diceY = feedbackY + 35  -- Centered vertically in the shorter panel
    
    -- Use the new highlighted dice display that shows which dice count
    diceSystem:drawWithHighlight(actionResult.dice, diceX, diceY, 1.5)
    
    -- Display subtle outcome indicator text centered below dice
    local panelWidth = screenWidth - (sidebarWidth * 2) - 20
    local resultText = diceSystem:getResultText(actionResult.outcome)
    love.graphics.setColor(diceSystem:getResultColor(actionResult.outcome))
    love.graphics.setColor(1, 1, 1, 0.7)  -- More subtle text
    love.graphics.printf(resultText, sidebarWidth + 10, diceY + 45, panelWidth - 10, "center")
    
    -- Draw modifiers if present
    self:drawActionModifiers(actionResult.modifiers, screenWidth, sidebarWidth, diceY)
end

-- Draw the action modifiers
function Combat:drawActionModifiers(modifiers, screenWidth, sidebarWidth, diceY)
    -- If we have modifiers, display them on the right side
    if modifiers and #modifiers > 0 then
        local modX = screenWidth - sidebarWidth - 150
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("MODIFIERS:", modX, diceY + 5)
        
        for i, mod in ipairs(modifiers) do
            -- Choose color based on modifier value
            if mod.value > 0 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for positive
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for negative
            end
            
            local sign = mod.value > 0 and "+" or ""
            love.graphics.print(mod.description .. " " .. sign .. mod.value, modX, diceY + 5 + (i * 20))
        end
    end
end

-- Draw the action panel (buttons or movement controls)
function Combat:drawActionPanel(battle, buttonsY, layout)
    local screenWidth = layout.screenWidth
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    
    -- Common panel for action buttons or movement controls
    self:drawUIPanel(0, buttonsY, screenWidth, CONTROLS_HEIGHT)
    
    -- Different controls based on phase
    if battle.turn == "player" then
        if battle.phase == "playerActionPlanning" or battle.phase == "actionResolution" then
            -- Action phase - show action buttons
            self:drawActionButtons(battle, buttonsY, screenWidth, layout.sidebarWidth)
        elseif battle.phase == "playerMovePlanning" then
            -- Movement planning phase - show maneuver planning controls
            self:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
        elseif battle.phase == "maneuverResolution" then
            -- Maneuver resolution phase - show resolving message
            love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
            love.graphics.printf("RESOLVING MANEUVERS...", 0, buttonsY + 15, screenWidth, "center")
        else
            -- Legacy fallback
            self:drawMovementControls(battle, buttonsY, screenWidth)
        end
    else
        -- Enemy turn - show a "Waiting..." animation or indicator
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.printf("ENEMY TAKING ACTION...", 0, buttonsY + 15, screenWidth, "center")
    end
end

-- Draw the maneuver planning controls
function Combat:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
    local buttonSpacing = 20
    local buttonWidth = 120
    local buttonHeight = 30
    
    -- First draw instructions
    love.graphics.setColor(1, 1, 1, 0.8)
    
    -- Different instructions based on whether destination is selected
    if self.plannedMoveHex then
        -- If destination selected, prompt for rotation
        love.graphics.printf("CHOOSE FINAL ORIENTATION", 0, buttonsY + 5, screenWidth, "center")
    else
        -- If no destination, prompt to select one
        love.graphics.printf("SELECT DESTINATION HEX", 0, buttonsY + 5, screenWidth, "center")
    end
    
    -- Draw rotation controls if we have a planned move
    if self.plannedMoveHex then
        -- Rotation controls - Calculate button positions
        local totalWidth = (2 * buttonWidth) + buttonSpacing
        local startX = (screenWidth - totalWidth) / 2
        
        -- Store button hitboxes for interaction
        self.rotationButtons = {
            rotateLeft = {
                x = startX,
                y = buttonsY + 25,
                width = buttonWidth,
                height = buttonHeight
            },
            rotateRight = {
                x = startX + buttonWidth + buttonSpacing,
                y = buttonsY + 25,
                width = buttonWidth,
                height = buttonHeight
            }
        }
        
        -- Draw the rotation buttons
        love.graphics.setColor(0.4, 0.7, 0.9, 0.9) -- Blue for rotation
        love.graphics.rectangle("fill", self.rotationButtons.rotateLeft.x, self.rotationButtons.rotateLeft.y, 
                              self.rotationButtons.rotateLeft.width, self.rotationButtons.rotateLeft.height)
        love.graphics.rectangle("fill", self.rotationButtons.rotateRight.x, self.rotationButtons.rotateRight.y, 
                              self.rotationButtons.rotateRight.width, self.rotationButtons.rotateRight.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ROTATE LEFT", self.rotationButtons.rotateLeft.x, self.rotationButtons.rotateLeft.y + 8, buttonWidth, "center")
        love.graphics.printf("ROTATE RIGHT", self.rotationButtons.rotateRight.x, self.rotationButtons.rotateRight.y + 8, buttonWidth, "center")
        
        -- If both move and rotation are planned, show confirm button
        if self.plannedRotation ~= nil then
            -- Calculate total cost
            local cost = self:calculateSPCost(battle.playerShip, self.plannedMoveHex[1], self.plannedMoveHex[2], self.plannedRotation)
            local affordable = cost <= battle.playerShip.currentSP
            
            -- Confirm button
            self.confirmManeuverButton = {
                x = (screenWidth - buttonWidth) / 2,
                y = buttonsY + 60,
                width = buttonWidth,
                height = buttonHeight
            }
            
            -- Draw confirm button with color based on affordability
            local buttonColor = affordable and {0.2, 0.8, 0.2, 0.9} or {0.8, 0.2, 0.2, 0.9}
            love.graphics.setColor(buttonColor)
            love.graphics.rectangle("fill", self.confirmManeuverButton.x, self.confirmManeuverButton.y,
                                 self.confirmManeuverButton.width, self.confirmManeuverButton.height)
            
            -- Confirm button text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("CONFIRM (" .. cost .. " SP)", self.confirmManeuverButton.x, 
                              self.confirmManeuverButton.y + 8, buttonWidth, "center")
        end
    end
end

function Combat:drawActionButtons(battle, buttonsY, screenWidth, sidebarWidth)
    -- Center buttons in the available space
    local buttonSpacing = 20
    local buttonWidth = 160
    local buttonHeight = 40
    local buttonY = buttonsY + 5  -- Standard button Y position
    local totalButtonsWidth = (3 * buttonWidth) + (2 * buttonSpacing) + 125 + buttonSpacing
    local startX = (screenWidth - totalButtonsWidth) / 2
    
    -- Store button positions for consistent hitbox testing
    self.actionButtons = {
        fire = { x = startX, y = buttonY, width = buttonWidth, height = buttonHeight },
        evade = { x = startX + buttonWidth + buttonSpacing, y = buttonY, width = buttonWidth, height = buttonHeight },
        repair = { x = startX + (buttonWidth + buttonSpacing) * 2, y = buttonY, width = buttonWidth, height = buttonHeight },
        endTurn = { x = startX + (buttonWidth + buttonSpacing) * 3, y = buttonY, width = 125, height = buttonHeight }
    }
    
    -- Fire Cannons button
    self:drawButton(
        self.actionButtons.fire.x, 
        self.actionButtons.fire.y, 
        self.actionButtons.fire.width, 
        self.actionButtons.fire.height, 
        {0.8, 0.3, 0.3, 0.9}, "FIRE CANNONS", 
        battle.playerShip.crewPoints >= self.actionCosts.fire
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.fire.x, 
        self.actionButtons.fire.y, 
        self.actionButtons.fire.width, 
        self.actionButtons.fire.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.fire .. " CP)", self.actionButtons.fire.x + 20, self.actionButtons.fire.y + 25, 0, 0.8, 0.8)
    
    -- Evade button
    self:drawButton(
        self.actionButtons.evade.x, 
        self.actionButtons.evade.y, 
        self.actionButtons.evade.width, 
        self.actionButtons.evade.height,
        {0.3, 0.3, 0.8, 0.9}, "EVADE", 
        battle.playerShip.crewPoints >= self.actionCosts.evade
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.evade.x, 
        self.actionButtons.evade.y, 
        self.actionButtons.evade.width, 
        self.actionButtons.evade.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.evade .. " CP)", self.actionButtons.evade.x + 20, self.actionButtons.evade.y + 25, 0, 0.8, 0.8)
    
    -- Repair button
    self:drawButton(
        self.actionButtons.repair.x, 
        self.actionButtons.repair.y, 
        self.actionButtons.repair.width, 
        self.actionButtons.repair.height,
        {0.3, 0.8, 0.3, 0.9}, "REPAIR", 
        battle.playerShip.crewPoints >= self.actionCosts.repair
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.repair.x, 
        self.actionButtons.repair.y, 
        self.actionButtons.repair.width, 
        self.actionButtons.repair.height
    )
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("(" .. self.actionCosts.repair .. " CP)", self.actionButtons.repair.x + 20, self.actionButtons.repair.y + 25, 0, 0.8, 0.8)
    
    -- End Turn button
    self:drawButton(
        self.actionButtons.endTurn.x, 
        self.actionButtons.endTurn.y, 
        self.actionButtons.endTurn.width, 
        self.actionButtons.endTurn.height,
        {0.7, 0.7, 0.7, 0.9}, "END TURN", true
    )
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(
        self.actionButtons.endTurn.x, 
        self.actionButtons.endTurn.y, 
        self.actionButtons.endTurn.width, 
        self.actionButtons.endTurn.height
    )
end

-- Draw the movement controls
function Combat:drawMovementControls(battle, buttonsY, screenWidth)
    -- Position info in left side
    love.graphics.setColor(1, 1, 1, 0.8)
    local posText = "POSITION: [" .. battle.playerShip.position[1] .. "," .. battle.playerShip.position[2] .. "]"
    love.graphics.print(posText, 50, buttonsY + 15)
    
    -- Direction hint if ship is selected
    if self.selectedHex then
        love.graphics.setColor(0.3, 0.8, 0.9, 0.9)
        local dirText = "SELECT A BLUE HEX TO MOVE"
        love.graphics.print(dirText, 300, buttonsY + 15)
    end
    
    -- End Move/To Action button (right side)
    local moveButtonX = screenWidth - 175
    local moveButtonY = buttonsY + 5
    local moveButtonWidth = 125
    local moveButtonHeight = 40
    
    -- Store button position for consistent hitbox testing
    self.moveActionButton = {
        x = moveButtonX,
        y = moveButtonY,
        width = moveButtonWidth,
        height = moveButtonHeight
    }
    
    if battle.playerShip.movesRemaining <= 0 then
        self:drawButton(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight, 
                        {0.8, 0.7, 0.2, 0.9}, "END MOVE", true)
    else
        self:drawButton(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight, 
                        {0.7, 0.7, 0.2, 0.9}, "TO ACTION", true)
    end
    
    -- Draw hitbox if debug is on
    self:drawButtonHitbox(moveButtonX, moveButtonY, moveButtonWidth, moveButtonHeight)
end

-- Draw the instructions panel
function Combat:drawInstructionsPanel(battle, buttonsY, layout)
    local screenWidth = layout.screenWidth
    local CONTROLS_HEIGHT = Constants.UI.COMBAT.CONTROLS_HEIGHT
    local INSTRUCTIONS_HEIGHT = Constants.UI.COMBAT.INSTRUCTIONS_HEIGHT
    
    -- Position it below the action buttons panel
    self:drawUIPanel(0, buttonsY + CONTROLS_HEIGHT, screenWidth, INSTRUCTIONS_HEIGHT)
    
    -- Draw instructions text
    love.graphics.setColor(1, 1, 1, 0.9)
    local instructions = ""
    if battle.turn == "player" then
        if battle.phase == "playerMovePlanning" then
            instructions = "PLANNING PHASE: Select destination hex and rotation (SP: " .. battle.playerShip.currentSP .. "/" .. battle.playerShip.maxSP .. ")"
        elseif battle.phase == "maneuverResolution" then
            instructions = "RESOLVING MANEUVERS: Please wait..."
        elseif battle.phase == "playerActionPlanning" then
            instructions = "ACTION PHASE: Select action to perform"
        elseif battle.phase == "movement" then
            instructions = "MOVEMENT PHASE: Click your ship, then click a blue hex to move"
        elseif battle.phase == "action" then
            instructions = "ACTION PHASE: Click a button to perform an action"
        else
            instructions = "PHASE: " .. battle.phase
        end
    else
        instructions = "ENEMY TURN: Please wait..."
    end
    love.graphics.printf(instructions, 20, buttonsY + CONTROLS_HEIGHT + 8, screenWidth - 40, "center")
end

-- Helper function to draw a UI panel with background
function Combat:drawUIPanel(x, y, width, height, r, g, b, a)
    local color
    -- Use provided color values or constants if color arguments are nil
    if r == nil then
        color = Constants.COLORS.UI_PANEL
    else
        color = {r, g, b, a}
    end
    
    -- Draw panel background
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    
    -- Draw panel border
    love.graphics.setColor(Constants.COLORS.UI_BORDER)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
end

-- Helper function to draw a progress bar
function Combat:drawProgressBar(x, y, width, height, fillPercent, fillColor, emptyColor)
    -- Clamp fill percent between 0 and 1
    fillPercent = math.max(0, math.min(1, fillPercent))
    
    -- Draw background (empty part)
    love.graphics.setColor(emptyColor[1], emptyColor[2], emptyColor[3], emptyColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)
    
    -- Draw filled part
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    love.graphics.rectangle("fill", x, y, width * fillPercent, height, 3, 3)
    
    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height, 3, 3)
    
    -- Draw notches for visual scale reference (every 25%)
    love.graphics.setColor(1, 1, 1, 0.3)
    for i = 1, 3 do
        local notchX = x + (width * (i / 4))
        love.graphics.line(notchX, y, notchX, y + height)
    end
    
    -- Add color indicator based on value (red for low, yellow for medium, green for good)
    if fillPercent < 0.25 then
        -- Draw critical indicator for low health
        if fillPercent < 0.3 and emptyColor[1] > 0.5 then -- Only for health bars
            love.graphics.setColor(1, 0, 0, math.abs(math.sin(love.timer.getTime() * 4)) * 0.8)
            love.graphics.rectangle("fill", x, y, width * fillPercent, height, 3, 3)
        end
    end
end

-- Helper function to draw a button
function Combat:drawButton(x, y, width, height, color, text, enabled)
    -- Darken the button if disabled
    local buttonColor = {color[1], color[2], color[3], color[4] or 1}
    if not enabled then
        buttonColor[1] = buttonColor[1] * 0.4
        buttonColor[2] = buttonColor[2] * 0.4
        buttonColor[3] = buttonColor[3] * 0.4
    end
    
    -- Draw button shadow for depth
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x + 2, y + 2, width, height, 5, 5)
    
    -- Draw button background with gradient effect
    local gradientTop = {
        buttonColor[1] * 1.2,
        buttonColor[2] * 1.2,
        buttonColor[3] * 1.2,
        buttonColor[4]
    }
    
    -- Top half with lighter color
    love.graphics.setColor(gradientTop)
    love.graphics.rectangle("fill", x, y, width, height/2, 5, 5)
    
    -- Bottom half with original color
    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", x, y + height/2, width, height/2, 5, 5)
    
    -- Draw button border
    if enabled then
        love.graphics.setColor(1, 1, 1, 0.8)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    
    -- Draw button text with slight shadow for better readability
    if enabled then
        -- Text shadow
        love.graphics.setColor(0, 0, 0, 0.5)
        local textX = x + (width / 2) - (love.graphics.getFont():getWidth(text) / 2) + 1
        local textY = y + (height / 2) - (love.graphics.getFont():getHeight() / 2) + 1
        love.graphics.print(text, textX, textY)
        
        -- Actual text
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
    end
    
    -- Center text on button
    local textX = x + (width / 2) - (love.graphics.getFont():getWidth(text) / 2)
    local textY = y + (height / 2) - (love.graphics.getFont():getHeight() / 2)
    love.graphics.print(text, textX, textY)
    
    -- Add subtle highlight effect on the top edge for 3D effect
    if enabled then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.line(x + 2, y + 2, x + width - 2, y + 2)
    end
end

-- Handle mouse movement
function Combat:mousemoved(x, y, gameState)
    if not gameState.combat then return end
    
    -- Update hovered hex
    local oldHoveredHex = self.hoveredHex
    self.hoveredHex = self:getHexFromScreen(x, y)
    
    -- Auto-select player ship if not already selected
    if gameState.combat.phase == "playerMovePlanning" and not self.selectedHex and gameState.combat.playerShip then
        self.selectedHex = {gameState.combat.playerShip.position[1], gameState.combat.playerShip.position[2]}
        self:calculateValidMoves(gameState.combat, gameState.combat.playerShip)
        print("Auto-selected player ship in mousemoved")
    end
    
    -- Debug output when hovering changes
    if self.hoveredHex and (not oldHoveredHex or 
                          oldHoveredHex[1] ~= self.hoveredHex[1] or 
                          oldHoveredHex[2] ~= self.hoveredHex[2]) then
        if self.hoveredHex then
            local q, r = self.hoveredHex[1], self.hoveredHex[2]
            local isValid = self:isValidMove(q, r)
            print("Now hovering over hex " .. q .. "," .. r .. " - " .. (isValid and "VALID move" or "NOT a valid move"))
        end
    end
end

-- Helper function to check if a point is inside a button
function Combat:isPointInButton(x, y, buttonX, buttonY, buttonWidth, buttonHeight)
    -- Simple rectangular hitbox check
    return x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight
end

-- Debug function to draw hitboxes (only used in debug mode)
function Combat:drawButtonHitbox(buttonX, buttonY, buttonWidth, buttonHeight)
    if self.showDebugHitboxes then
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
        -- Draw a small dot at the button center for reference
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.circle("fill", buttonX + buttonWidth/2, buttonY + buttonHeight/2, 2)
    end
end

-- Check if a point is within the hex grid area
function Combat:isPointInGridArea(x, y, layout)
    -- Print debug tracking to help debug the issue
    print("Checking if point " .. x .. "," .. y .. " is in grid area")
    
    -- Use layout constants to determine grid boundaries
    local gridTop = layout.gridTop or 0
    local gridBottom = layout.gridBottom or love.graphics.getHeight()
    local sidebarWidth = layout.sidebarWidth or 100
    local screenWidth = layout.screenWidth or love.graphics.getWidth()
    
    -- Calculate grid area boundaries
    local gridLeft = sidebarWidth
    local gridRight = screenWidth - sidebarWidth
    
    -- Debug output
    print("Grid area: " .. gridLeft .. "," .. gridTop .. " to " .. gridRight .. "," .. gridBottom)
    
    -- Check if point is within the grid area
    local inGrid = (x >= gridLeft and x <= gridRight and y >= gridTop and y <= gridBottom)
    print("Point is " .. (inGrid and "INSIDE" or "OUTSIDE") .. " grid area")
    
    -- Always return true for now to debug hex selection
    return true
end

-- Handle mouse clicks
function Combat:mousepressed(x, y, button, gameState)
    if not gameState.combat then return end
    
    -- Only handle left clicks
    if button ~= 1 then return end
    
    local battle = gameState.combat
    
    -- Use layout constants from draw function
    local layout = self.layoutConstants
    if not layout then return end
    
    -- Calculate the y-position of the buttons panel
    local buttonsY = self:calculateButtonsY(battle, layout)
    
    -- First check if clicking on UI buttons
    if battle.turn == "player" then
        -- Try to handle button clicks based on the phase
        if self:handleButtonClick(x, y, battle, buttonsY, gameState) then
            return -- Button was clicked and handled
        end
    end
    
    -- If not clicking buttons, check for hex grid interactions
    -- Skip the grid area check to help debug problems
    --if self:isPointInGridArea(x, y, layout) then
        print("Checking for hex interactions")
        if battle.turn == "player" then
            if battle.phase == "playerMovePlanning" then
                -- Handle the new maneuver planning phase
                local handled = self:handleManeuverPlanningClick(x, y, battle)
                print("Maneuver planning click handled: " .. tostring(handled))
                
                -- Debug: if clicks aren't working, force calculate valid moves
                if not handled then
                    print("Click not handled - recalculating valid moves")
                    self.validMoves = {}
                    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
                    self:calculateValidMoves(battle, battle.playerShip)
                end
            elseif battle.phase == "movement" then
                -- Legacy movement handling
                self:handleHexClick(x, y, battle, gameState)
            end
        end
    --end
end

-- Calculate the Y position for the buttons panel
function Combat:calculateButtonsY(battle, layout)
    local buttonsY = 0
    
    if battle.actionResult then
        -- Below the feedback panel
        buttonsY = layout.gridBottom + Constants.UI.COMBAT.FEEDBACK_HEIGHT + 10
    else
        -- At the bottom of the grid area
        buttonsY = layout.gridBottom + 5
    end
    
    return buttonsY
end

-- Handle button clicks in the UI
function Combat:handleButtonClick(x, y, battle, buttonsY, gameState)
    -- Phase transition button (movement -> action) during movement phase
    if battle.phase == "movement" then
        if self:handleMovementPhaseButton(x, y, battle) then
            return true
        end
    elseif battle.phase == "action" then
        if self:handleActionPhaseButtons(x, y, battle, gameState) then
            return true
        end
    end
    
    return false -- No button was clicked
end

-- Handle movement phase button clicks
function Combat:handleMovementPhaseButton(x, y, battle)
    if self.moveActionButton and 
       self:isPointInButton(x, y, self.moveActionButton.x, self.moveActionButton.y, 
                         self.moveActionButton.width, self.moveActionButton.height) then
        -- End movement phase and start action phase
        battle.phase = "action"
        return true
    end
    
    return false
end

-- Handle action phase button clicks
function Combat:handleActionPhaseButtons(x, y, battle, gameState)
    -- Check for button clicks using stored button positions
    if not self.actionButtons then return false end
    
    -- Fire Cannons button
    if self:isPointInButton(x, y, self.actionButtons.fire.x, self.actionButtons.fire.y, 
                          self.actionButtons.fire.width, self.actionButtons.fire.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.fire then
        battle.actionResult = self:fireCannons(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- Evade button
    if self:isPointInButton(x, y, self.actionButtons.evade.x, self.actionButtons.evade.y, 
                          self.actionButtons.evade.width, self.actionButtons.evade.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.evade then
        battle.actionResult = self:evade(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- Repair button
    if self:isPointInButton(x, y, self.actionButtons.repair.x, self.actionButtons.repair.y, 
                          self.actionButtons.repair.width, self.actionButtons.repair.height) and 
       battle.playerShip.crewPoints >= self.actionCosts.repair then
        battle.actionResult = self:repair(gameState)
        battle.playerShip.hasActed = true
        return true
    end
    
    -- End Turn button
    if self:isPointInButton(x, y, self.actionButtons.endTurn.x, self.actionButtons.endTurn.y, 
                          self.actionButtons.endTurn.width, self.actionButtons.endTurn.height) then
        self:endPlayerTurn(gameState)
        return true
    end
    
    return false
end

-- Check if a point is within the grid area
function Combat:isPointInGridArea(x, y, layout)
    local centerAreaLeft = layout.sidebarWidth
    local centerAreaRight = layout.screenWidth - layout.sidebarWidth
    
    -- Return true if point is inside the grid area
    return x >= centerAreaLeft and x <= centerAreaRight and y >= layout.gridTop and y <= layout.gridBottom
end

-- Handle hex grid clicks during the movement phase
function Combat:handleHexClick(x, y, battle, gameState)
    local clickedHex = self:getHexFromScreen(x, y)
    if not clickedHex then return end
    
    local q, r = clickedHex[1], clickedHex[2]
    
    -- Check bounds to make sure we're not out of the grid
    if q < 0 or q >= self.GRID_SIZE or r < 0 or r >= self.GRID_SIZE then
        return
    end
    
    -- If the player's ship is clicked, select it
    if battle.grid[q][r].isPlayerShip then
        self:selectPlayerShip(clickedHex, battle, gameState)
    -- If a valid move hex is clicked, move the ship there
    elseif self.selectedHex and self:isValidMove(q, r) then
        self:movePlayerShip(q, r, battle, gameState)
    end
end

-- Select the player's ship for movement
function Combat:selectPlayerShip(clickedHex, battle, gameState)
    self.selectedHex = clickedHex
    -- Calculate valid moves from this position
    self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
    
    -- Debug
    if gameState.settings.debug then
        local q, r = clickedHex[1], clickedHex[2]
        print("Selected player ship at " .. q .. "," .. r .. 
              " with " .. battle.playerShip.movesRemaining .. " moves remaining")
    end
end

-- Move the player's ship to a new position
function Combat:movePlayerShip(q, r, battle, gameState)
    -- Move the ship to the new position
    self:moveShip(battle, battle.playerShip, q, r)
    
    -- Recalculate valid moves or clear them if no moves left
    if battle.playerShip.movesRemaining > 0 then
        self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
    else
        self.validMoves = {}
        self.selectedHex = nil
        
        -- If out of moves, auto-transition to action phase
        battle.phase = "action"
    end
    
    -- Debug
    if gameState.settings.debug then
        print("Moved player ship to " .. q .. "," .. r .. 
              " with " .. battle.playerShip.movesRemaining .. " moves remaining")
    end
end

-- End player turn and start enemy turn
function Combat:endPlayerTurn(gameState)
    local battle = gameState.combat
    
    -- Reset player ship for next turn
    battle.playerShip.hasActed = false
    battle.playerShip.movesRemaining = shipUtils.getBaseSpeed(battle.playerShip.class)
    battle.playerShip.crewPoints = battle.playerShip.maxCrewPoints
    
    -- Switch to enemy turn
    battle.turn = "enemy"
    battle.phase = "movement"
    
    -- Process enemy turn (simple AI)
    self:processEnemyTurn(gameState)
end

-- Process enemy turn with simple AI
function Combat:processEnemyTurn(gameState)
    local battle = gameState.combat
    
    -- Movement phase - enemy moves based on tactical situation
    self:processEnemyMovement(gameState)
    
    -- Action phase - enemy chooses an action based on health
    battle.phase = "action"
    self:processEnemyAction(gameState)
    
    -- End the enemy turn and prepare for player turn
    self:finalizeEnemyTurn(battle)
end

-- Finalize the enemy turn and prepare for player turn
function Combat:finalizeEnemyTurn(battle)
    -- Reset enemy ship for next turn
    battle.enemyShip.hasActed = false
    battle.enemyShip.movesRemaining = shipUtils.getBaseSpeed(battle.enemyShip.class)
    battle.enemyShip.crewPoints = battle.enemyShip.maxCrewPoints
    
    -- Increment turn counter
    battle.turnCount = battle.turnCount + 1
    
    -- Reset for player turn
    battle.turn = "player"
    battle.phase = "movement"
end

-- Process enemy movement
function Combat:processEnemyMovement(gameState)
    local battle = gameState.combat
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Calculate initial state
    local eq, er = enemyShip.position[1], enemyShip.position[2]
    local pq, pr = playerShip.position[1], playerShip.position[2]
    local distance = self:hexDistance(eq, er, pq, pr)
    local movesRemaining = enemyShip.movesRemaining
    
    -- Calculate health percentage (affects tactical decisions)
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Keep moving until we run out of moves or valid moves
    while movesRemaining > 0 do
        -- Get all possible moves
        local validMoves = self:calculateValidMoves(battle, enemyShip)
        if #validMoves == 0 then break end
        
        -- Find the best move
        local bestMove = self:findBestEnemyMove(validMoves, healthPercent, playerShip)
        
        -- Execute the chosen move
        if bestMove then
            self:moveShip(battle, enemyShip, bestMove[1], bestMove[2])
            movesRemaining = enemyShip.movesRemaining
        else
            break
        end
    end
end

-- Find the best move for the enemy ship based on tactical situation
function Combat:findBestEnemyMove(validMoves, healthPercent, playerShip)
    local bestMove = nil
    local bestScore = -1000
    local pq, pr = playerShip.position[1], playerShip.position[2]
    
    for _, move in ipairs(validMoves) do
        local moveQ, moveR = move[1], move[2]
        local newDist = self:hexDistance(moveQ, moveR, pq, pr)
        
        -- Calculate score based on enemy's health and strategy
        local score = self:calculateMoveScore(newDist, healthPercent)
        
        -- Take the highest-scoring move
        if score > bestScore then
            bestScore = score
            bestMove = move
        end
    end
    
    return bestMove
end

-- Calculate a score for a potential move based on tactical situation
function Combat:calculateMoveScore(distance, healthPercent)
    local score = 0
    
    -- Different strategies based on health
    if healthPercent > 0.7 then
        -- Aggressive when healthy - get closer to attack
        score = -distance  -- Negative distance = prefer closer
    elseif healthPercent > 0.3 then
        -- Cautious when moderately damaged - maintain medium distance
        score = -(math.abs(distance - 3))  -- Prefer distance of about 3 hexes
    else
        -- Defensive when critically damaged - flee
        score = distance  -- Prefer farther
    end
    
    -- Add slight randomization to avoid predictable behavior
    score = score + math.random() * 0.5
    
    return score
end

-- Process enemy action based on health
function Combat:processEnemyAction(gameState)
    local battle = gameState.combat
    local enemyShip = battle.enemyShip
    
    -- Calculate health percentage
    local maxHealth = shipUtils.getMaxHP(enemyShip.class)
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Choose and execute an action based on health level
    battle.actionResult = self:chooseEnemyAction(gameState, healthPercent)
    
    -- Short delay to show the action result (would be implemented better with a timer)
    love.timer.sleep(0.5)
end

-- Choose an appropriate action for the enemy based on health
function Combat:chooseEnemyAction(gameState, healthPercent)
    -- Different actions based on health threshold:
    if healthPercent < 0.3 then
        -- Critically damaged - try to repair
        return self:repair(gameState)
    elseif healthPercent < 0.7 then
        -- Moderately damaged - try to evade
        return self:evade(gameState)
    else
        -- Healthy - attack!
        return self:fireCannons(gameState)
    end
end

-- Start a naval battle
function Combat:startBattle(gameState, enemyShipClass)
    -- Initialize a new battle
    self:initBattle(gameState, enemyShipClass)
    
    -- Set game state to combat mode
    gameState.settings.combatMode = true
    
    return true
end

-- Fire cannons action (Ticket 3-2)
function Combat:fireCannons(gameState, target)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:fireCannons")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local attacker = battle.turn == "player" and battle.playerShip or battle.enemyShip
    local defender = battle.turn == "player" and battle.enemyShip or battle.playerShip
    
    -- Validate battle state
    assert(attacker, "No attacker ship found in battle")
    assert(defender, "No defender ship found in battle")
    
    -- Check if enough crew points are available
    if attacker.crewPoints < self.actionCosts.fire then
        return {
            action = "fire",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.fire .. ")"
        }
    end
    
    -- Deduct crew points
    attacker.crewPoints = attacker.crewPoints - self.actionCosts.fire
    
    -- Calculate base dice based on firepower (cannons)
    local baseDice = shipUtils.getBaseFirepowerDice(attacker.class)
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Check for point blank range (adjacent hex)
    local aq, ar = attacker.position[1], attacker.position[2]
    local dq, dr = defender.position[1], defender.position[2]
    local dist = self:hexDistance(aq, ar, dq, dr)
    
    if dist == 1 then
        -- Point blank range gives +1 die
        table.insert(modifiers, diceSystem:createModifier("Point Blank Range", 1, true))
    end
    
    -- Check for Gunner in crew (adds skill as bonus dice)
    if battle.turn == "player" then
        -- Check player's crew for Gunner
        for _, member in ipairs(gameState.crew.members) do
            if member.role == "Gunner" then
                -- Add Gunner's skill level as a modifier
                local gunnerBonus = member.skill * Constants.GAME.GUNNER_SKILL_MULTIPLIER
                table.insert(modifiers, diceSystem:createModifier("Gunner: " .. member.name, gunnerBonus, true))
                
                if gameState.settings.debug then
                    print("Gunner modifier: +" .. gunnerBonus .. " dice from " .. member.name)
                end
                
                break  -- Only apply the first Gunner's bonus for now
            end
        end
    end
    
    -- Apply defender's evade score as a negative modifier
    if defender.evadeScore > 0 then
        table.insert(modifiers, diceSystem:createModifier("Target Evading", -defender.evadeScore, true))
        -- Reset defender's evade score after this attack
        defender.evadeScore = 0
    end
    
    -- Add any persistent modifiers from attacker
    for _, mod in ipairs(attacker.modifiers) do
        if mod.category == "attack" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for attack with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Calculate damage based on outcome level
    local damage = 0
    if outcome.result == "critical" then
        damage = Constants.COMBAT.DAMAGE_CRITICAL  -- Critical hit damage
    elseif outcome.result == "success" then
        damage = Constants.COMBAT.DAMAGE_SUCCESS  -- Success damage
    elseif outcome.result == "partial" then
        damage = Constants.COMBAT.DAMAGE_PARTIAL  -- Partial success damage
    end
    
    -- Apply damage to target
    if battle.turn == "player" then
        -- Player attacks enemy
        battle.enemyShip.durability = math.max(0, (battle.enemyShip.durability or 10) - damage)
        
        -- Check if enemy is destroyed
        if battle.enemyShip.durability <= 0 then
            -- Enemy ship is sunk - player wins
            self:endBattle(gameState, "victory")
            return true
        end
    else
        -- Enemy attacks player
        gameState.ship.durability = math.max(0, gameState.ship.durability - damage)
        
        -- Check if player is destroyed
        if gameState.ship.durability <= 0 then
            -- Player ship is sunk - player loses
            self:endBattle(gameState, "defeat")
            return true
        end
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(attacker)
    
    -- Return result for UI display
    return {
        action = "fire",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        damage = damage,
        attacker = battle.turn,
        targetDurability = battle.turn == "player" and battle.enemyShip.durability or gameState.ship.durability,
        modifiers = modifiers
    }
end

-- Clean up temporary modifiers
function Combat:cleanupTemporaryModifiers(ship)
    -- Filter out temporary modifiers
    local persistentModifiers = {}
    for _, mod in ipairs(ship.modifiers) do
        if not mod.temporary then
            table.insert(persistentModifiers, mod)
        end
    end
    
    -- Replace with only persistent modifiers
    ship.modifiers = persistentModifiers
end

-- Evade action (Ticket 3-2)
function Combat:evade(gameState)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:evade")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Validate battle state
    assert(ship, "No ship found for current turn")
    
    -- Check if enough crew points are available
    if ship.crewPoints < self.actionCosts.evade then
        return {
            action = "evade",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.evade .. ")"
        }
    end
    
    -- Deduct crew points
    ship.crewPoints = ship.crewPoints - self.actionCosts.evade
    
    -- Calculate base dice based on ship class (speed influences evasion)
    local baseDice = shipUtils.getBaseSpeed(ship.class)
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Add any persistent modifiers from ship
    for _, mod in ipairs(ship.modifiers) do
        if mod.category == "evade" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for evasion with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Set evade score based on outcome level
    local evadeScore = outcome.level  -- 0=failure, 1=partial, 2=success, 3=critical
    
    if battle.turn == "player" then
        -- Player evades
        battle.playerShip.evadeScore = evadeScore
    else
        -- Enemy evades
        battle.enemyShip.evadeScore = evadeScore
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(ship)
    
    -- Return result for UI display
    return {
        action = "evade",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        evadeScore = evadeScore,
        ship = battle.turn,
        modifiers = modifiers
    }
end

-- Repair action (Ticket 3-2)
function Combat:repair(gameState)
    -- Validate required parameters
    assert(gameState, "gameState is required for Combat:repair")
    assert(gameState.combat, "No active battle found in gameState")
    
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Validate battle state
    assert(ship, "No ship found for current turn")
    
    -- Check if enough crew points are available
    if ship.crewPoints < self.actionCosts.repair then
        return {
            action = "repair",
            success = false,
            message = "Not enough crew points! (Need " .. self.actionCosts.repair .. ")"
        }
    end
    
    -- Deduct crew points
    ship.crewPoints = ship.crewPoints - self.actionCosts.repair
    
    -- Calculate base dice - always 1 for base repair
    local baseDice = 1
    
    -- Gather modifiers
    local modifiers = {}
    
    -- Check for surgeon in crew (adds dice)
    if battle.turn == "player" then
        -- Check player's crew for surgeon
        for _, member in ipairs(gameState.crew.members) do
            if member.role == "Surgeon" then
                -- Add surgeon's skill level as a modifier
                table.insert(modifiers, diceSystem:createModifier("Surgeon: " .. member.name, member.skill, true))
                break
            end
        end
    end
    
    -- Add any persistent modifiers from ship
    for _, mod in ipairs(ship.modifiers) do
        if mod.category == "repair" then
            table.insert(modifiers, mod)
        end
    end
    
    -- Roll dice for repair with modifiers
    local diceResults, rollInfo = diceSystem:roll(baseDice, modifiers)
    local outcome = diceSystem:interpret(diceResults)
    
    -- Calculate repair amount based on outcome level
    local repairAmount = 0
    if outcome.result == "critical" then
        repairAmount = Constants.COMBAT.REPAIR_CRITICAL  -- Critical repair
    elseif outcome.result == "success" then
        repairAmount = Constants.COMBAT.REPAIR_SUCCESS  -- Success repair
    elseif outcome.result == "partial" then
        repairAmount = Constants.COMBAT.REPAIR_PARTIAL  -- Partial success repair
    end
    
    -- Apply repairs
    if battle.turn == "player" then
        -- Player repairs their ship
        local maxDurability = shipUtils.getMaxHP(gameState.ship.class)
        gameState.ship.durability = math.min(gameState.ship.durability + repairAmount, maxDurability)
    else
        -- Enemy repairs their ship
        local maxDurability = shipUtils.getMaxHP(ship.class)
        battle.enemyShip.durability = math.min((battle.enemyShip.durability or 10) + repairAmount, maxDurability)
    end
    
    -- Clean up temporary modifiers
    self:cleanupTemporaryModifiers(ship)
    
    -- Return result for UI display
    return {
        action = "repair",
        dice = diceResults,
        outcome = outcome,
        rollInfo = rollInfo,
        repairAmount = repairAmount,
        ship = battle.turn,
        currentDurability = battle.turn == "player" and gameState.ship.durability or battle.enemyShip.durability,
        modifiers = modifiers
    }
end

-- Dice mechanics integration methods

-- Initialize the dice system
function Combat:initDiceSystem()
    diceSystem:init()
end

-- Roll dice for combat actions (using the dice module)
function Combat:rollDice(numDice)
    return diceSystem:roll(numDice)
end

-- Interpret dice results (using the dice module)
function Combat:interpretDiceResults(diceResults)
    return diceSystem:interpret(diceResults)
end

-- End a naval battle
function Combat:endBattle(gameState, result)
    -- Process battle results
    if result then
        if result == "victory" then
            -- Player won the battle
            print("Victory! Enemy ship destroyed.")
            -- Would add rewards here in later sprints
        elseif result == "defeat" then
            -- Player lost the battle
            print("Defeat! Your ship was destroyed.")
            -- Would add consequences here in later sprints
        elseif result == "retreat" then
            -- Player retreated from battle
            print("You retreat from the battle.")
        end
    end
    
    -- Clean up combat state
    gameState.combat = nil
    
    -- Exit combat mode
    gameState.settings.combatMode = false
    
    return true
end

return Combat```

## src/conf.lua
```lua
-- LÖVE Configuration
function love.conf(t)
    t.title = "Pirate's Wager: Blood for Gold"  -- The title of the window
    t.version = "11.4"                -- The LÖVE version this game was made for
    t.window.width = 800              -- Game window width
    t.window.height = 600             -- Game window height
    t.window.resizable = true         -- Allow window to be resized with letterboxing/pillarboxing
    t.console = true                  -- Enable console for debug output
    
    -- For development
    t.window.vsync = 1                -- Vertical sync mode
    
    -- Disable modules we won't be using
    t.modules.joystick = false        -- No need for joystick module
    t.modules.physics = false         -- No need for physics module for map navigation
end```

## src/constants.lua
```lua
-- Game Constants
-- Centralized definitions of commonly used values

local Constants = {
    -- ============ UI LAYOUT CONSTANTS ============
    UI = {
        -- General Screen
        SCREEN_WIDTH = 800,
        SCREEN_HEIGHT = 600,
        
        -- Combat Layout
        COMBAT = {
            TOP_BAR_HEIGHT = 30,
            BOTTOM_BAR_HEIGHT = 80,
            SIDEBAR_WIDTH = 140,
            FEEDBACK_HEIGHT = 70,
            CONTROLS_HEIGHT = 50,
            INSTRUCTIONS_HEIGHT = 30,
            BUTTON_WIDTH = 160,
            BUTTON_HEIGHT = 40,
            BUTTON_SPACING = 20,
            HEX_RADIUS = 25
        }
    },
    
    -- ============ COLORS ============
    COLORS = {
        -- General UI Colors
        UI_BACKGROUND = {0.08, 0.1, 0.15, 1},  -- Very dark blue/black
        UI_PANEL = {0.15, 0.15, 0.25, 0.9},    -- Translucent dark blue
        UI_BORDER = {0.3, 0.3, 0.5, 0.8},      -- Light border
        UI_TEXT = {1, 1, 1, 0.8},              -- Soft white text
        
        -- Ship and Entity Colors
        PLAYER_SHIP = {0.2, 0.8, 0.2, 1},      -- Green for player
        ENEMY_SHIP = {0.8, 0.2, 0.2, 1},       -- Red for enemy
        HOVER = {0.8, 0.8, 0.2, 0.6},          -- Yellow for hover
        SELECTED = {0.2, 0.8, 0.8, 0.6},       -- Cyan for selected
        
        -- Action Button Colors
        BUTTON_FIRE = {0.8, 0.3, 0.3, 0.9},    -- Red for fire actions
        BUTTON_EVADE = {0.3, 0.3, 0.8, 0.9},   -- Blue for evade actions
        BUTTON_REPAIR = {0.3, 0.8, 0.3, 0.9},  -- Green for repair actions
        BUTTON_NEUTRAL = {0.7, 0.7, 0.7, 0.9}, -- Gray for neutral actions
        
        -- Resource Colors
        GOLD = {0.9, 0.8, 0.2, 1},             -- Gold color
        HEALTH = {0.2, 0.8, 0.2, 1},           -- Health green
        DAMAGE = {0.8, 0.2, 0.2, 1},           -- Damage red
        
        -- Sea and Map
        SEA = {0.1, 0.2, 0.4, 1},              -- Dark blue water
        SEA_BORDER = {0.2, 0.4, 0.6, 0.8},     -- Lighter blue border
        VALID_MOVE = {0.5, 0.7, 0.9, 0.6},     -- Light blue for valid moves
        EMPTY_WATER = {0.3, 0.5, 0.7, 0.4}     -- Blue for empty water
    },
    
    -- ============ COMBAT CONSTANTS ============
    COMBAT = {
        -- Grid Configuration
        GRID_SIZE = 10,                         -- 10x10 grid
        
        -- Action Costs
        CP_COST_FIRE = 1,                       -- Fire cannons cost 1 CP
        CP_COST_EVADE = 1,                      -- Evade costs 1 CP
        CP_COST_REPAIR = 2,                     -- Repair costs 2 CP
        
        -- Sail Point (SP) Costs
        SP_COST_MOVE_HEX = 1,                   -- Cost to move one hex
        SP_COST_ROTATE_60 = 1,                  -- Cost to rotate 60 degrees
        
        -- Damage Values
        DAMAGE_CRITICAL = 3,                    -- Critical hit damage
        DAMAGE_SUCCESS = 2,                     -- Success damage
        DAMAGE_PARTIAL = 1,                     -- Partial success damage
        
        -- Repair Values
        REPAIR_CRITICAL = 15,                   -- Critical repair amount
        REPAIR_SUCCESS = 10,                    -- Success repair amount
        REPAIR_PARTIAL = 5                      -- Partial success repair amount
    },
    
    -- ============ DICE CONSTANTS ============
    DICE = {
        SUCCESS = 6,                            -- Success on 6
        PARTIAL_MIN = 4,                        -- Partial success on 4-5
        PARTIAL_MAX = 5,                        -- Partial success on 4-5
        FAILURE_MAX = 3,                        -- Failure on 1-3
        
        -- Outcome Levels
        OUTCOME_CRITICAL = 3,                   -- Level for critical success
        OUTCOME_SUCCESS = 2,                    -- Level for success
        OUTCOME_PARTIAL = 1,                    -- Level for partial success
        OUTCOME_FAILURE = 0                     -- Level for failure
    },
    
    -- ============ CREW ROLES ============
    ROLES = {
        NAVIGATOR = "Navigator",
        GUNNER = "Gunner",
        SURGEON = "Surgeon"
    },
    
    -- ============ GAME SETTINGS ============
    GAME = {
        -- Default Resources
        DEFAULT_GOLD = 50,
        DEFAULT_RUM = 0,
        DEFAULT_TIMBER = 0,
        DEFAULT_GUNPOWDER = 0,
        
        -- Default Crew Values
        DEFAULT_MORALE = 5,                     -- Default crew morale (1-10)
        
        -- Time/Game Progress
        TOTAL_WEEKS = 72,                       -- Total game duration
        EARTHQUAKE_MIN_WEEK = 60,               -- Earliest earthquake week
        EARTHQUAKE_MAX_WEEK = 72,               -- Latest earthquake week
        
        -- Default Travel Time
        BASE_TRAVEL_TIME = 1,                   -- Base travel time (in weeks)
        MIN_TRAVEL_TIME = 0.5,                  -- Minimum travel time
        
        -- Wind Effects
        WIND_WITH = -0.5,                       -- Traveling with wind (weeks modifier)
        WIND_AGAINST = 1,                       -- Traveling against wind (weeks modifier)
        WIND_CHANGE_INTERVAL = 4,               -- How often wind might change (weeks)
        
        -- Inventory
        DEFAULT_INVENTORY_SLOTS = 10,           -- Default inventory capacity
        
        -- Crew Effects
        NAVIGATOR_TRAVEL_BONUS = -0.5,          -- Time reduction with Navigator (weeks)
        GUNNER_SKILL_MULTIPLIER = 1,            -- Multiplier for Gunner's skill level (for future balancing)
        VICTORY_LOYALTY_BONUS = 1,              -- Loyalty boost after victory
        RUM_LOYALTY_BONUS = 2,                  -- Loyalty boost from rum
        VOYAGE_LOYALTY_PENALTY = -1             -- Loyalty reduction per week at sea
    }
}

return Constants```

## src/dice.lua
```lua
-- Dice Module
-- Implements a reusable dice system for Forged in the Dark mechanics

-- Import constants
local Constants = require('constants')
local AssetUtils = require('utils.assetUtils')

local Dice = {
    -- Sprite sheet for dice
    spriteSheet = nil,
    spriteWidth = 32,
    spriteHeight = 32,
    quads = {}
}

-- Initialize dice system
function Dice:init()
    -- Load dice sprite sheet using AssetUtils
    self.spriteSheet = AssetUtils.loadImage("assets/dice-strip.png", "dice")
    
    if self.spriteSheet then
        -- Create quads for each die face
        for i = 0, 5 do
            self.quads[i+1] = love.graphics.newQuad(
                i * self.spriteWidth, 0,
                self.spriteWidth, self.spriteHeight,
                self.spriteSheet:getDimensions()
            )
        end
        
        print("Dice sprite sheet loaded successfully")
    else
        print("Will use text representation for dice")
    end
end

-- Modifier class for dice rolls
local Modifier = {
    description = "",  -- Description of the modifier
    value = 0,         -- The dice modifier value (positive or negative)
    temporary = false  -- Whether modifier is temporary (removed after roll)
}

-- Create a new modifier
function Modifier:new(description, value, temporary)
    local mod = {
        description = description or "",
        value = value or 0,
        temporary = temporary or false
    }
    setmetatable(mod, self)
    self.__index = self
    return mod
end

-- Roll dice with modifiers
function Dice:roll(baseDice, modifiers)
    local modifiers = modifiers or {}
    local results = {}
    local rollInfo = {
        baseDice = baseDice,
        modifiers = {},       -- Copy of applied modifiers
        totalDiceCount = 0,   -- Final dice count after modifiers
        zeroOrNegative = false, -- Flag if we had 0 or negative dice
        results = {},         -- The actual dice values rolled
        rolls = {}            -- All roll operations (for debugging)
    }
    
    -- Calculate total dice count from modifiers
    local totalDice = baseDice
    local modReport = {}
    
    -- Apply all modifiers
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
        table.insert(modReport, {
            description = mod.description, 
            value = mod.value
        })
        table.insert(rollInfo.rolls, "Applied " .. mod.description .. ": " .. (mod.value >= 0 and "+" or "") .. mod.value .. " dice")
    end
    
    -- Store the full list of applied modifiers
    rollInfo.modifiers = modReport
    
    -- Handle zero or negative dice count (roll 2 dice and take worst)
    if totalDice <= 0 then
        rollInfo.zeroOrNegative = true
        rollInfo.totalDiceCount = 2
        table.insert(rollInfo.rolls, "Reduced to " .. totalDice .. " dice - rolling 2 and taking worst")
        
        -- Roll 2 dice
        for i = 1, 2 do
            local dieValue = math.random(1, 6)
            table.insert(results, dieValue)
            table.insert(rollInfo.rolls, "Rolled " .. dieValue)
        end
        
        -- Take the worst (lowest) value
        table.sort(results)
        rollInfo.results = {results[1]}  -- Keep only the lowest value
        table.insert(rollInfo.rolls, "Taking worst value: " .. results[1])
    else
        -- Normal dice pool - roll adjusted number of dice (max 5)
        totalDice = math.min(5, totalDice)
        rollInfo.totalDiceCount = totalDice
        
        for i = 1, totalDice do
            local dieValue = math.random(1, 6)
            table.insert(results, dieValue)
            table.insert(rollInfo.rolls, "Rolled " .. dieValue)
        end
        
        rollInfo.results = results
    end
    
    -- Return both the roll results and the detailed roll info
    return results, rollInfo
end

-- Interpret dice results according to Forged in the Dark rules
function Dice:interpret(diceResults)
    local outcome = {
        successes = 0,      -- Full successes (die = 6)
        partials = 0,       -- Partial successes (die = 4-5)
        failures = 0,       -- Failures (die = 1-3)
        highestValue = 0,   -- The highest die value rolled
        result = "failure", -- Overall result: "failure", "partial", "success", or "critical"
        level = 0,          -- Numeric result level: 0=failure, 1=partial, 2=success, 3=critical
        results = diceResults -- The original dice values
    }
    
    -- No dice rolled
    if #diceResults == 0 then
        return outcome
    end
    
    -- Process each die result
    for _, die in ipairs(diceResults) do
        -- Track highest value
        outcome.highestValue = math.max(outcome.highestValue, die)
        
        -- Categorize results
        if die == Constants.DICE.SUCCESS then
            -- Success
            outcome.successes = outcome.successes + 1
        elseif die >= Constants.DICE.PARTIAL_MIN and die <= Constants.DICE.PARTIAL_MAX then
            -- Partial success
            outcome.partials = outcome.partials + 1
        else
            -- Failure
            outcome.failures = outcome.failures + 1
        end
    end
    
    -- Determine overall result based on Forged in the Dark rules
    -- Rule 1: Use highest die result (not the sum)
    -- Rule 2: 2+ successes (6s) is a critical success
    if outcome.successes >= 2 then
        -- Critical success (2+ dice showing 6)
        outcome.result = "critical"
        outcome.level = Constants.DICE.OUTCOME_CRITICAL
    elseif outcome.successes == 1 then
        -- Full success (1 die showing 6)
        outcome.result = "success"
        outcome.level = Constants.DICE.OUTCOME_SUCCESS
    elseif outcome.partials > 0 then
        -- Partial success (highest die is 4-5)
        outcome.result = "partial"
        outcome.level = Constants.DICE.OUTCOME_PARTIAL
    else
        -- Failure (no dice showing 4+)
        outcome.result = "failure"
        outcome.level = Constants.DICE.OUTCOME_FAILURE
    end
    
    return outcome
end

-- Draw dice results
function Dice:draw(diceResults, x, y, scale)
    local scale = scale or 1
    local padding = 2 * scale
    local width = self.spriteWidth * scale
    
    -- If no sprite sheet, use text representation
    if not self.spriteSheet then
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (20 * scale + padding)
            
            -- Draw die background based on value
            if value == 6 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for success
            elseif value >= 4 then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.8) -- Yellow for partial
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for failure
            end
            
            love.graphics.rectangle("fill", dieX, y, 20 * scale, 20 * scale, 3, 3)
            
            -- Draw die value
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(value, dieX + 7 * scale, y + 4 * scale)
        end
    else
        -- Use sprite sheet
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (width + padding)
            if self.spriteSheet and self.quads[value] then
                love.graphics.draw(
                    self.spriteSheet,
                    self.quads[value],
                    dieX,
                    y,
                    0,  -- rotation
                    scale, scale  -- scale x, y
                )
            else
                -- Draw placeholder if sprite sheet or quad is missing
                AssetUtils.drawPlaceholder(dieX, y, self.spriteWidth * scale, self.spriteHeight * scale, "dice")
            end
        end
    end
    
    -- Return the total width used by the dice
    return #diceResults * (self.spriteWidth * scale + padding)
end

-- Draw dice results with highlighting for dice that "count"
function Dice:drawWithHighlight(diceResults, x, y, scale)
    local scale = scale or 1
    local padding = 4 * scale
    local width = self.spriteWidth * scale
    local outcome = self:interpret(diceResults)
    
    -- If no sprite sheet, use text representation
    if not self.spriteSheet then
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (20 * scale + padding)
            local dieY = y
            
            -- Apply bump to dice that count
            if (value == 6 and outcome.successes > 0) or 
               (value >= 4 and value <= 5 and outcome.successes == 0 and outcome.partials > 0) or
               (value <= 3 and outcome.successes == 0 and outcome.partials == 0) then
                -- This die "counts" - bump it up
                dieY = y - 5 * scale
                
                -- Add glow/shadow for highlighted dice
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", dieX - 2, dieY - 2, 24 * scale, 24 * scale, 5, 5)
            end
            
            -- Draw die background based on value
            if value == 6 then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8) -- Green for success
            elseif value >= 4 then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.8) -- Yellow for partial
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.8) -- Red for failure
            end
            
            love.graphics.rectangle("fill", dieX, dieY, 20 * scale, 20 * scale, 3, 3)
            
            -- Draw die value
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(value, dieX + 7 * scale, dieY + 4 * scale)
        end
    else
        -- Use sprite sheet
        love.graphics.setColor(1, 1, 1, 1)
        for i, value in ipairs(diceResults) do
            local dieX = x + (i-1) * (width + padding)
            local dieY = y
            
            -- Determine if this die should be highlighted (counts toward the outcome)
            local shouldHighlight = false
            
            -- Critical success - all 6s count
            if outcome.result == "critical" and value == Constants.DICE.SUCCESS then
                shouldHighlight = true
            -- Regular success - only one 6 counts (use the first one found)
            elseif outcome.result == "success" and value == Constants.DICE.SUCCESS then
                -- If we haven't yet highlighted a success die
                if not outcome.hasHighlightedSuccess then
                    shouldHighlight = true
                    outcome.hasHighlightedSuccess = true
                end
            -- Partial success - only 4-5s count if there are no 6s
            -- Always highlight the highest value die (4 or 5)
            elseif outcome.result == "partial" then
                -- Find the highest partial success die (4-5)
                if not outcome.highestPartialValue then
                    outcome.highestPartialValue = 0
                    for _, v in ipairs(diceResults) do
                        if v >= Constants.DICE.PARTIAL_MIN and v <= Constants.DICE.PARTIAL_MAX and v > outcome.highestPartialValue then
                            outcome.highestPartialValue = v
                        end
                    end
                end
                
                -- Highlight only the highest partial success die
                if value == outcome.highestPartialValue and not outcome.hasHighlightedPartial then
                    shouldHighlight = true
                    outcome.hasHighlightedPartial = true
                end
            -- Failure - highlight the highest die (still a failure, but clearer)
            elseif outcome.result == "failure" then
                -- Find the highest die (which is still ≤ 3 for a failure)
                if not outcome.highestFailureValue then
                    outcome.highestFailureValue = 0
                    for _, v in ipairs(diceResults) do
                        if v <= Constants.DICE.FAILURE_MAX and v > outcome.highestFailureValue then
                            outcome.highestFailureValue = v
                        end
                    end
                end
                
                -- Highlight only the highest failure die
                if value == outcome.highestFailureValue and not outcome.hasHighlightedFailure then
                    shouldHighlight = true
                    outcome.hasHighlightedFailure = true
                end
            end
            
            -- Apply bump to dice that count
            if shouldHighlight then
                -- This die "counts" - bump it up
                dieY = y - 8 * scale
            end
            
            -- Check if we can draw the die using the spritesheet
            if self.spriteSheet and self.quads[value] then
                -- Draw the die with appropriate highlight
                love.graphics.setColor(1, 1, 1, 1)
                if shouldHighlight then
                    -- Add shadow for 3D effect
                    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX + 2,
                        dieY + 2,
                        0,  -- rotation
                        scale, scale  -- scale x, y
                    )
                    
                    -- Draw highlighted die slightly larger
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX,
                        dieY,
                        0,  -- rotation
                        scale * 1.1, scale * 1.1  -- slightly larger scale
                    )
                else
                    -- Draw regular die
                    love.graphics.draw(
                        self.spriteSheet,
                        self.quads[value],
                        dieX,
                        dieY,
                        0,  -- rotation
                        scale, scale  -- scale x, y
                    )
                end
            else
                -- Draw placeholder if sprite sheet or quad is missing
                local placeholderHeight = self.spriteHeight * (shouldHighlight and scale * 1.1 or scale)
                local placeholderWidth = self.spriteWidth * (shouldHighlight and scale * 1.1 or scale)
                
                AssetUtils.drawPlaceholder(dieX, dieY, placeholderWidth, placeholderHeight, "dice")
                
                -- Draw the die value as text in the center of the placeholder
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(value, dieX + placeholderWidth/2 - 5, dieY + placeholderHeight/2 - 8)
            end
        end
    end
    
    -- Return the total width used by the dice
    return #diceResults * (self.spriteWidth * scale + padding)
end

-- Get result text description
function Dice:getResultText(outcome)
    if outcome.result == "critical" then
        return "Critical Success!"
    elseif outcome.result == "success" then
        return "Success"
    elseif outcome.result == "partial" then
        return "Partial Success"
    else
        return "Failure"
    end
end

-- Get result color
function Dice:getResultColor(outcome)
    if outcome.result == "critical" then
        return Constants.COLORS.HEALTH -- Bright green
    elseif outcome.result == "success" then
        return Constants.COLORS.PLAYER_SHIP -- Green
    elseif outcome.result == "partial" then
        return Constants.COLORS.GOLD -- Yellow
    else
        return Constants.COLORS.DAMAGE -- Red
    end
end

-- Create a helper function to easily create modifiers
function Dice:createModifier(description, value, temporary)
    return Modifier:new(description, value, temporary)
end

-- Draw modifiers list
function Dice:drawModifiers(modifiers, x, y, scale)
    love.graphics.setColor(1, 1, 1, 1)
    local yPos = y
    local scale = scale or 1
    local lineHeight = 20 * scale
    
    for i, mod in ipairs(modifiers) do
        -- Choose color based on modifier value
        if mod.value > 0 then
            love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Green for positive
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 1) -- Red for negative
        end
        
        local sign = mod.value > 0 and "+" or ""
        love.graphics.print(mod.description .. ": " .. sign .. mod.value .. " dice", x, yPos)
        yPos = yPos + lineHeight
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    return yPos - y  -- Return total height used
end

-- Export the module and the Modifier class
return {
    dice = Dice,
    Modifier = Modifier
}```

## src/gameState.lua
```lua
-- Game State Module
-- Central repository for game state that needs to be accessed across modules

-- Import ship utils
local shipUtils = require('utils.shipUtils')

-- Import constants
local Constants = require('constants')

local GameState = {
    -- Player ship information
    ship = {
        name = "The Swift Sting",
        class = "sloop",     -- Ship class (sloop, brigantine, galleon)
        currentZone = nil,  -- Set during initialization
        x = 0,
        y = 0,
        isMoving = false,
        -- Ship stats will be initialized based on class in init()
        speed = nil,
        firepower = nil,
        durability = nil,
        crewCapacity = nil
    },
    
    -- Time tracking
    time = {
        currentWeek = 1,
        totalWeeks = Constants.GAME.TOTAL_WEEKS,
        earthquakeWeek = nil,  -- Set during initialization
        isGameOver = false
    },
    
    -- Player resources
    resources = {
        gold = Constants.GAME.DEFAULT_GOLD,          -- Starting gold
        rum = Constants.GAME.DEFAULT_RUM,
        timber = Constants.GAME.DEFAULT_TIMBER,
        gunpowder = Constants.GAME.DEFAULT_GUNPOWDER
    },
    
    -- Inventory system for cargo and special items
    inventory = {
        slots = {},         -- Will contain inventory slot objects
        capacity = Constants.GAME.DEFAULT_INVENTORY_SLOTS
    },
    
    -- Crew management
    crew = {
        members = {},       -- Will contain crew member objects
        morale = Constants.GAME.DEFAULT_MORALE,  -- Scale 1-10
        
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
    
    -- Set earthquake week (random between the configured weeks)
    self.time.earthquakeWeek = math.random(Constants.GAME.EARTHQUAKE_MIN_WEEK, 
                                         Constants.GAME.EARTHQUAKE_MAX_WEEK)
    
    -- Initialize wind direction (random)
    self.environment.wind.currentDirection = self.environment.wind.directions[math.random(#self.environment.wind.directions)]
    
    -- Initialize ship stats based on class
    local stats = shipUtils.getShipBaseStats(self.ship.class)
    self.ship.speed = stats.speed
    self.ship.firepower = stats.firepowerDice
    self.ship.durability = stats.durability
    self.ship.crewCapacity = stats.crewCapacity
    
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
    
    -- Reset ship stats based on class
    local stats = shipUtils.getShipBaseStats(self.ship.class)
    self.ship.speed = stats.speed
    self.ship.firepower = stats.firepowerDice
    self.ship.durability = stats.durability
    self.ship.crewCapacity = stats.crewCapacity
    
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
        windModifier = Constants.GAME.WIND_WITH  -- Faster with the wind
    -- Against the wind (sailing into the wind): +1 week
    elseif travelDirection == oppositeOf[windDirection] then
        windModifier = Constants.GAME.WIND_AGAINST
    -- Perpendicular to wind: no modifier
    else
        windModifier = 0
    end
    
    -- Apply the wind modifier 
    local travelTime = baseTravelTime + windModifier
    
    -- Apply navigator modifier if present
    local navigatorEffect = ""
    if hasNavigator then
        travelTime = travelTime + Constants.GAME.NAVIGATOR_TRAVEL_BONUS
        navigatorEffect = " with Navigator"
        if self.settings.debug then
            print("Navigator reducing travel time by " .. math.abs(Constants.GAME.NAVIGATOR_TRAVEL_BONUS) .. " weeks")
        end
    end
    
    -- Ensure minimum travel time
    travelTime = math.max(Constants.GAME.MIN_TRAVEL_TIME, travelTime)
    
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
local combatSystem = require('combat')
local AssetUtils = require('utils.assetUtils')

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
    combatSystem:load(gameState)  -- Initialize combat system
    
    -- Store base dimensions for scaling calculations
    gameState.settings.baseWidth = 800
    gameState.settings.baseHeight = 600
    gameState.settings.scale = 1
    gameState.settings.offsetX = 0
    gameState.settings.offsetY = 0
    
    -- Set window properties
    love.window.setTitle("Pirate's Wager: Blood for Gold")
    love.window.setMode(800, 600, {
        vsync = true,
        resizable = true,  -- Allow window resizing with letterboxing/pillarboxing
        minwidth = 400,    -- Minimum window width
        minheight = 300    -- Minimum window height
    })
end

function love.update(dt)
    -- Early return if game is paused
    if gameState.settings.isPaused then return end
    
    -- Update game state based on current mode
    if gameState.settings.combatMode then
        -- Update naval combat
        combatSystem:update(dt, gameState)
    elseif gameState.settings.portMode then
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
        combatSystem:load(gameState)
    end
end

-- Handle window resize events
function love.resize(w, h)
    -- Calculate new scale factor to maintain exact 4:3 aspect ratio (800x600)
    local scaleX = w / gameState.settings.baseWidth
    local scaleY = h / gameState.settings.baseHeight
    
    -- Use the smaller scale to ensure everything fits
    gameState.settings.scale = math.min(scaleX, scaleY)
    
    -- Calculate letterbox or pillarbox dimensions for centering
    gameState.settings.offsetX = math.floor((w - gameState.settings.baseWidth * gameState.settings.scale) / 2)
    gameState.settings.offsetY = math.floor((h - gameState.settings.baseHeight * gameState.settings.scale) / 2)
    
    -- Print debug info
    if gameState.settings.debug then
        print("Window resized to " .. w .. "x" .. h)
        print("Scale factor: " .. gameState.settings.scale)
        print("Offset: " .. gameState.settings.offsetX .. ", " .. gameState.settings.offsetY)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    -- Draw black background for the entire window (for letterboxing/pillarboxing)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Set up the scaling transformation
    love.graphics.push()
    
    -- Apply offset for letterboxing/pillarboxing
    love.graphics.translate(gameState.settings.offsetX or 0, gameState.settings.offsetY or 0)
    
    -- Apply scaling
    love.graphics.scale(gameState.settings.scale or 1)
    
    -- Set scissor to ensure nothing renders outside our 800x600 game area
    love.graphics.setScissor(
        gameState.settings.offsetX,
        gameState.settings.offsetY,
        gameState.settings.baseWidth * gameState.settings.scale,
        gameState.settings.baseHeight * gameState.settings.scale
    )
    
    -- Render game based on current mode
    if gameState.settings.combatMode then
        -- Draw naval combat
        combatSystem:draw(gameState)
    elseif gameState.settings.portMode then
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
        love.graphics.print("Scale: " .. string.format("%.2f", gameState.settings.scale), 10, 30)
        love.graphics.print("Window: " .. w .. "x" .. h, 10, 50)
    end
    
    -- Clear scissor and end the transformation
    love.graphics.setScissor()
    love.graphics.pop()
    
    -- Draw letterbox/pillarbox borders if needed
    if gameState.settings.scale < 1 or w ~= gameState.settings.baseWidth or h ~= gameState.settings.baseHeight then
        love.graphics.setColor(0.1, 0.1, 0.1, 1) -- Dark gray borders
        
        -- Draw edge lines to make the borders more visible
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        -- Top border edge
        if gameState.settings.offsetY > 0 then
            love.graphics.rectangle("fill", 0, gameState.settings.offsetY - 1, w, 1)
        end
        -- Bottom border edge
        if gameState.settings.offsetY > 0 then
            love.graphics.rectangle("fill", 0, gameState.settings.offsetY + (gameState.settings.baseHeight * gameState.settings.scale), w, 1)
        end
        -- Left border edge
        if gameState.settings.offsetX > 0 then
            love.graphics.rectangle("fill", gameState.settings.offsetX - 1, 0, 1, h)
        end
        -- Right border edge
        if gameState.settings.offsetX > 0 then
            love.graphics.rectangle("fill", gameState.settings.offsetX + (gameState.settings.baseWidth * gameState.settings.scale), 0, 1, h)
        end
    end
end

-- Helper function to convert screen coordinates to game coordinates
function convertMousePosition(x, y)
    -- Adjust for the offset and scaling
    local gameX = (x - (gameState.settings.offsetX or 0)) / (gameState.settings.scale or 1)
    local gameY = (y - (gameState.settings.offsetY or 0)) / (gameState.settings.scale or 1)
    
    return gameX, gameY
end

function love.mousemoved(x, y)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = convertMousePosition(x, y)
    
    if gameState.settings.combatMode then
        combatSystem:mousemoved(gameX, gameY, gameState)
    elseif gameState.settings.portMode then
        portRoyal:mousemoved(gameX, gameY, gameState)
    else
        gameMap:mousemoved(gameX, gameY, gameState)
    end
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = convertMousePosition(x, y)
    
    if gameState.settings.combatMode then
        combatSystem:mousepressed(gameX, gameY, button, gameState)
    elseif gameState.settings.portMode then
        portRoyal:mousepressed(gameX, gameY, button, gameState)
    else
        gameMap:mousepressed(gameX, gameY, button, gameState)
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- If in combat mode, end the battle
        if gameState.settings.combatMode then
            combatSystem:endBattle(gameState)
        -- If in port mode, return to map
        elseif gameState.settings.portMode then
            gameState.settings.portMode = false
            gameState.settings.currentPortScreen = "main"
        else
            love.event.quit()
        end
    elseif key == "f1" then
        gameState.settings.debug = not gameState.settings.debug
    elseif key == "f9" and gameState.settings.debug then
        -- Toggle button hitbox visualization in debug mode
        if gameState.settings.combatMode then
            combatSystem.showDebugHitboxes = not combatSystem.showDebugHitboxes
            print("Button hitboxes: " .. (combatSystem.showDebugHitboxes and "ON" or "OFF"))
        end
    elseif key == "p" then
        gameState.settings.isPaused = not gameState.settings.isPaused
    elseif key == "c" and not gameState.settings.combatMode then
        -- Debug key to start a test battle
        combatSystem:startBattle(gameState, "sloop")
    end
end```

## src/map.lua
```lua
-- Caribbean Map Module
local AssetUtils = require('utils.assetUtils')

local Map = {
    zones = {},
    hoveredZone = nil,
    -- Base map dimensions
    width = 800,
    height = 600,
    background = nil
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
    
    -- Load background image using AssetUtils
    self.background = AssetUtils.loadImage("assets/caribbean_map.png", "map")
    
    if self.background then
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
        -- Use deep blue ocean as fallback background
        love.graphics.setColor(0.1, 0.3, 0.5, 1)
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

local AssetUtils = require('utils.assetUtils')

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
    
    -- Validate required parameters
    assert(gameState, "gameState is required for PortRoyal:load")
    
    -- Load placeholder background images using AssetUtils
    self.backgrounds.main = AssetUtils.loadImage("assets/port_royal_main.png", "ui")
    if self.backgrounds.main then
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    self.backgrounds.tavern = AssetUtils.loadImage("assets/port-royal-tavern.png", "ui")
    if self.backgrounds.tavern then
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    self.backgrounds.shipyard = AssetUtils.loadImage("assets/port-royal-shipyard.png", "ui")
    if self.backgrounds.shipyard then
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
        -- Use AssetUtils to load the location-specific background
        locationBackground = AssetUtils.loadImage("assets/" .. locationKey .. "_main.png", "ui")
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        AssetUtils.drawImage(locationBackground, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        AssetUtils.drawImage(self.backgrounds.main, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "tavern" and self.backgrounds.tavern then
        AssetUtils.drawImage(self.backgrounds.tavern, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        AssetUtils.drawImage(self.backgrounds.shipyard, 0, 0, 0, 1, 1, self.width, self.height, "ui")
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

## src/utils/assetUtils.lua
```lua
-- Asset Utilities Module
-- Centralizes asset loading with better error handling

local AssetUtils = {}

-- Default placeholder images for different asset types
local DEFAULT_PLACEHOLDERS = {
    ship = {r = 0.2, g = 0.5, b = 0.8}, -- Blue rectangle for ships
    map = {r = 0.1, g = 0.3, b = 0.2},  -- Green rectangle for map elements
    ui = {r = 0.4, g = 0.4, b = 0.4},   -- Gray rectangle for UI elements
    dice = {r = 0.7, g = 0.7, b = 0.2}  -- Yellow rectangle for dice
}

-- Table to store loaded assets for reference
AssetUtils.loadedAssets = {}

-- Load an image with error handling
-- @param filePath - The path to the image file
-- @param assetType - Type of asset (ship, map, ui, dice) for fallback coloring
-- @return The loaded image or nil if loading failed
function AssetUtils.loadImage(filePath, assetType)
    -- Validate inputs
    if not filePath then
        print("ERROR: No file path provided to AssetUtils.loadImage")
        return nil
    end
    
    -- Normalize asset type
    assetType = assetType or "ui"
    
    -- Check if we've already loaded this asset
    if AssetUtils.loadedAssets[filePath] then
        return AssetUtils.loadedAssets[filePath]
    end
    
    -- Try to load the image
    local success, result = pcall(function() 
        return love.graphics.newImage(filePath)
    end)
    
    -- Handle the result
    if success then
        -- Store the loaded image for future reference
        AssetUtils.loadedAssets[filePath] = result
        return result
    else
        -- Print detailed error message
        print("ERROR: Failed to load asset: " .. filePath)
        print("Reason: " .. tostring(result))
        return nil
    end
end

-- Draw a placeholder rectangle for a missing asset
-- @param x, y - Position to draw at
-- @param width, height - Dimensions of the placeholder
-- @param assetType - Type of asset (ship, map, ui, dice) for coloring
function AssetUtils.drawPlaceholder(x, y, width, height, assetType)
    -- Get placeholder color based on asset type
    local colorDef = DEFAULT_PLACEHOLDERS[assetType] or DEFAULT_PLACEHOLDERS.ui
    
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw the placeholder
    love.graphics.setColor(colorDef.r, colorDef.g, colorDef.b, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw a border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw a missing texture pattern
    love.graphics.setColor(1, 0, 1, 0.5) -- Magenta
    love.graphics.line(x, y, x + width, y + height)
    love.graphics.line(x + width, y, x, y + height)
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

-- Safely draw an image, with fallback to placeholder if image is nil
-- @param image - The image to draw
-- @param x, y - Position to draw at
-- @param angle, sx, sy - Rotation and scale (optional)
-- @param width, height - Dimensions for placeholder if image is nil
-- @param assetType - Type of asset for placeholder coloring
function AssetUtils.drawImage(image, x, y, angle, sx, sy, width, height, assetType)
    if image then
        love.graphics.draw(image, x, y, angle or 0, sx or 1, sy or 1)
    else
        -- Draw placeholder if image is nil
        AssetUtils.drawPlaceholder(x, y, width or 32, height or 32, assetType)
    end
end

return AssetUtils```

## src/utils/shipUtils.lua
```lua
-- Ship Stats Utility Module
-- Centralizes all ship stat lookups and calculations

local ShipUtils = {}

-- Base stats for each ship class
local SHIP_BASE_STATS = {
    sloop = {
        speed = 3,
        firepowerDice = 1,
        durability = 10,
        crewCapacity = 4,
        baseCP = 2
    },
    brigantine = {
        speed = 2,
        firepowerDice = 3,
        durability = 20,
        crewCapacity = 8,
        baseCP = 4
    },
    galleon = {
        speed = 1,
        firepowerDice = 6,
        durability = 40,
        crewCapacity = 12,
        baseCP = 6
    }
}

-- Returns the complete set of base stats for a ship class
function ShipUtils.getShipBaseStats(shipClass)
    return SHIP_BASE_STATS[shipClass] or SHIP_BASE_STATS["sloop"]
end

-- Returns maximum durability (HP) for a ship class
function ShipUtils.getMaxHP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.durability or 10
end

-- Returns base firepower dice for a ship class
function ShipUtils.getBaseFirepowerDice(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.firepowerDice or 1
end

-- Returns base movement speed for a ship class
function ShipUtils.getBaseSpeed(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.speed or 3
end

-- Returns base crew points (CP) for a ship class
function ShipUtils.getBaseCP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.baseCP or 2
end

-- Returns crew capacity for a ship class
function ShipUtils.getCrewCapacity(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.crewCapacity or 4
end

return ShipUtils```

# Documentation

## docs/CombatSystem.md
# Combat System Documentation

## Overview

The combat system implements naval battles on a 10x10 hex grid. Ships of different classes occupy different numbers of hexes and have different movement speeds. The system includes movement mechanics, combat actions, and dice roll mechanics based on the Forged in the Dark system.

## Hex Grid System

The combat grid uses a "pointy-top" hex coordinate system with the following properties:

- Grid size: 10x10 hexes
- Coordinate system: uses axial coordinates (q,r) where:
  - q increases from west to east
  - r increases from northwest to southeast
  - (0,0) is the top-left hex

## Ship Classes on the Hex Grid

Ship classes have different sizes and shapes on the hex grid:

1. **Sloop (1-Hex Ship)**
   - Occupies 1 hex
   - Speed: 3 hexes per turn
   - Shape: Single hex

2. **Brigantine (2-Hex Ship)**
   - Occupies 2 hexes in a line
   - Speed: 2 hexes per turn
   - Shape: 2 hexes in a row

3. **Galleon (4-Hex Ship)**
   - Occupies 4 hexes in a kite shape
   - Speed: 1 hex per turn
   - Shape: 1 hex bow, 2 hex midship, 1 hex stern

## Combat Flow

1. **Battle Initialization**
   - Player and enemy ships are placed on opposite sides of the hex grid
   - Turn order is established (player first)

2. **Movement Phase**
   - The player can move their ship up to its maximum speed
   - Movement is done one hex at a time to adjacent hexes
   - Ships cannot move through occupied hexes

3. **Attack Phase** (not yet implemented)
   - After movement, ships can attack if in range
   - Attack success is based on dice rolls from the Forged in the Dark system

4. **End of Turn**
   - Turn passes to the enemy
   - The process repeats until one ship is defeated or retreats

## Game State Integration

Combat state is stored in the gameState object under the combat property with the following structure:

```lua
gameState.combat = {
    grid = {},  -- 2D array representing the hex grid
    playerShip = {
        class = "sloop",  -- Ship class (sloop, brigantine, galleon)
        size = 1,         -- Number of hexes occupied
        position = {5, 5}, -- {q, r} coordinates on grid
        orientation = 0,   -- Direction ship is facing (0-5, for 60° increments)
        movesRemaining = 3 -- Based on ship speed
    },
    enemyShip = {
        class = "sloop",
        size = 1,
        position = {2, 2},
        orientation = 3,
        movesRemaining = 3
    },
    turn = "player", -- Whose turn is it (player or enemy)
    phase = "movement", -- Current phase (movement, attack, etc.)
}
```

## Controls

- **Mouse Hover**: Highlights hexes on the grid
- **Click on Player Ship**: Selects the ship and shows valid movement hexes
- **Click on Valid Movement Hex**: Moves the ship to that hex
- **ESC Key**: Exits combat mode
- **C Key**: Debug key to start a test battle

## Triggering Combat

Naval battles can be triggered in two ways:

1. **Random Encounters**: When sailing between zones, there's a 20% chance of encountering an enemy ship
2. **Debug Mode**: Press 'C' key to start a test battle

## Combat Actions

The combat system includes three core actions:

1. **Fire Cannons**: Attack enemy ships
   - Uses the ship's firepower attribute to determine number of dice
   - Each success deals 1 point of damage
   - Damage is applied to the enemy ship's durability

2. **Evade**: Attempt to dodge enemy attacks
   - Uses the ship's class to determine number of dice (sloops get more dice)
   - Each success adds to the ship's evasion rating
   - Evasion rating reduces damage from attacks

3. **Repair**: Fix damage to the ship
   - Base 1 die for repairs
   - Surgeon crew role adds additional dice
   - Each success restores 5 HP to the ship
   - Cannot exceed ship's maximum durability

## Dice Mechanics

The combat system uses a dice pool mechanic based on Forged in the Dark:

- Actions roll a number of six-sided dice (d6) based on ship stats, crew, and modifiers
- Results are categorized:
  - 6: Full success
  - 4-5: Partial success
  - 1-3: Failure
- Outcome is determined by the highest die result, not the sum:
  - If any die shows 6, it's a success
  - If multiple dice show 6, it's a critical success
  - If the highest die is 4-5, it's a partial success
  - If no die shows 4+, it's a failure
- Each outcome level has different effects:
  - Critical Success: Maximum effect (e.g., 3 damage, 15 HP repair)
  - Success: Strong effect (e.g., 2 damage, 10 HP repair)
  - Partial Success: Minimal effect (e.g., 1 damage, 5 HP repair)
  - Failure: No effect

### Modifiers

The system supports modifiers that add or remove dice from action rolls:

- Positive modifiers add dice to the roll (e.g., "+1 die from Point Blank Range")
- Negative modifiers remove dice (e.g., "-2 dice from Target Evading")
- If the total dice count is reduced to 0 or negative, you roll 2 dice and take the worst (lowest) result
- Modifiers can be temporary (one-time use) or persistent (lasting until cleared)

### Action Types with Modifiers

1. **Fire Cannons**:
   - Base dice from ship's firepower attribute
   - +1 die for Point Blank Range (adjacent hex)
   - Negative dice equal to target's evade score

2. **Evade**:
   - Base dice from ship's class (sloop=3, brigantine=2, galleon=1)
   - Result sets ship's evade score until next turn
   - Evade score reduces attacker's dice when ship is targeted

3. **Repair**:
   - Base 1 die
   - Surgeon crew member adds dice equal to their skill level

## Game Flow

1. **Combat Initialization**:
   - Player and enemy ships are placed on the grid
   - Ships are given initial stats based on their class
   - Crew points are allocated based on crew size for the player and ship class for enemies

2. **Turn Structure**:
   - Each turn consists of a movement phase and an action phase
   - During movement phase, players can move their ship based on speed
   - During action phase, players can perform multiple actions based on crew points

3. **Movement Phase**:
   - Player selects their ship and can move to valid hexes
   - Movement is limited by the ship's speed stat
   - Cannot move through occupied hexes

4. **Action Phase**:
   - Player spends crew points to perform actions
   - Actions have different costs:
     - Fire Cannons: 1 CP
     - Evade: 1 CP
     - Repair: 2 CP
   - Multiple actions can be performed as long as crew points are available
   - Action results are calculated using dice rolls
   - Enemy AI takes its turn after the player

5. **End of Turn**:
   - Crew points are replenished for the next turn
   - Movement points are reset

6. **Combat Resolution**:
   - Combat ends when one ship is destroyed (0 durability)
   - Player can also retreat from battle

## Crew Point System

The crew point system connects ship crew size to combat actions:

- Each ship has a maximum number of crew points equal to its crew size
- The player's ship CP is based on the number of crew members
- Enemy ships' CP is based on their class (sloop=2, brigantine=4, galleon=6)
- Crew points are spent to perform actions during the action phase
- This creates an action economy where players must decide which actions are most important
- Larger ships with more crew can perform more actions each turn
- Creates a strategic layer where ship size and crew complement affect combat capability

## Future Enhancements

1. **Ship Orientation**: Implement proper ship orientation and rotation
2. **Wind Effects**: Integrate with the wind system for movement modifiers
3. **Boarding**: Add boarding mechanics for crew-vs-crew combat
4. **Visual Improvements**: Add proper ship sprites and battle animations
5. **Advanced Actions**: Ram, board, special abilities
6. **Crew Integration**: Deeper crew role impacts on combat

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

## docs/RevisedCombatSystem.md
# Pirate's Wager: Blood for Gold - Combat Rules (Revised)

## 1. Overview

This document outlines the rules for the tactical naval combat system in Pirate's Wager: Blood for Gold. Combat takes place on a 10x10 hex grid and emphasizes simultaneous maneuver planning, prediction, resource management (Sail Points & Crew Points), and risk/reward dice mechanics inspired by Forged in the Dark (FitD).

## 2. Key Concepts

*   **Hex Grid:** A 10x10 grid using pointy-top hexes and axial coordinates (q, r).
*   **Simultaneous Maneuvering:** Player and AI plan their movement and rotation secretly, and these maneuvers are resolved simultaneously.
*   **Sail Points (SP):** A per-turn resource representing a ship's agility, used to plan movement (moving hexes) and rotation (changing facing). SP varies by ship class.
*   **Crew Points (CP):** A per-turn resource representing the crew's capacity for action, used to execute combat actions like firing cannons, evading, or repairing. CP varies by ship class and current crew count (for the player).
*   **Orientation & Firing Arcs:** Ships have a specific facing (orientation). Weapons can only target hexes within defined firing arcs relative to the ship's current orientation.
*   **FitD Dice Mechanics:** Actions are resolved by rolling a pool of d6s. The highest die determines the outcome: Critical (multiple 6s), Success (highest is 6), Partial Success (highest is 4-5), or Failure (highest is 1-3).

## 3. Battlefield & Ships

*   **Grid:** 10x10 hexes.
*   **Ship Representation:**
    *   Ships occupy 1-4 hexes based on class.
    *   Each ship has a central anchor hex (`position {q, r}`) and an `orientation` (0-5, representing 60° increments, 0=North).
    *   Ship shapes rotate based on orientation.
*   **Ship Classes & Base Stats:**

    | Class      | Hex Size/Shape | Max HP | Base Max SP | Base Max CP | Base Speed (Moves/Turn) | Base Firepower (Dice) | Firing Arcs          |
    | :--------- | :------------- | :----- | :---------- | :---------- | :---------------------- | :-------------------- | :------------------- |
    | Sloop      | 1 hex          | 10     | 5           | 2 (*Note 1*) | 3                       | 1                     | Forward Only         |
    | Brigantine | 2 hexes (line) | 20     | 4           | 4 (*Note 1*) | 2                       | 3                     | Broadsides (Sides)   |
    | Galleon    | 4 hexes (kite) | 40     | 3           | 6 (*Note 1*) | 1                       | 6                     | Broadsides (Sides)   |

    *Note 1: Player ship's Max CP is based on `#gameState.crew.members`, capped by ship capacity. Enemy Max CP uses these base values.*

## 4. Combat Turn Structure

Each combat turn follows this sequence:

1.  **Start of Turn:**
    *   Replenish `currentSP` to `maxSP` for both ships.
    *   Replenish `currentCP` to `maxCP` for both ships.
    *   Clear any temporary turn-based effects or states (e.g., evade scores from previous turns if applicable, planned moves/rotations).
    *   Advance turn counter (`gameState.combat.turnCount`).

2.  **Enemy Planning Phase (Internal):**
    *   AI determines its intended maneuver (`plannedMove` hex and `plannedRotation` orientation).
    *   AI calculates SP cost and ensures the plan is affordable. Revises if necessary.
    *   AI determines its intended action(s) for the Action Phase (based on anticipated post-maneuver state).
    *   *Plans are stored internally, not revealed to the player.*

3.  **Player Planning Phase (Movement & Rotation):** (`gameState.combat.phase = "playerMovePlanning"`)
    *   Player sees current board state, their available SP.
    *   Player selects a target **orientation** using UI controls.
    *   Player selects a target **destination hex** from valid moves.
    *   UI displays SP cost for the planned move path + planned rotation change.
    *   Player cannot confirm a plan costing more than `currentSP`.
    *   Player **commits** the maneuver plan (stores destination in `playerShip.plannedMove`, final orientation in `playerShip.plannedRotation`).

4.  **Resolution Phase (Maneuver):** (`gameState.combat.phase = "maneuverResolution"`)
    *   **Rotation Update:** Internal `ship.orientation` state is instantly updated for *both* ships based on their `plannedRotation`.
    *   **Collision Check:** Check if `plannedMove` destinations conflict. Adjust `plannedMove` destinations for involved ships according to collision rules (e.g., stop 1 hex short).
    *   **Movement Execution & SP Deduction:**
        *   Animate both ships rotating towards their new orientation *while* moving towards their (potentially adjusted) destination hexes.
        *   Calculate the *actual* SP cost incurred for the maneuver performed (actual hexes moved + rotation steps).
        *   Deduct SP: `ship.currentSP -= actualCost`.
        *   Update internal `ship.position` state upon animation completion.
    *   Clear `plannedMove` and `plannedRotation` for both ships.

5.  **Player Planning Phase (Action):** (`gameState.combat.phase = "playerActionPlanning"`)
    *   Player sees the board state *after* maneuvers have resolved.
    *   Player selects actions (Fire, Evade, Repair, etc.) using available **CP**.
    *   Targeting for actions like "Fire Cannons" is constrained by the ship's current orientation and **firing arcs**.
    *   Selecting an action leads to the Confirmation Window (showing dice/modifiers/cost).
    *   Player Confirms or Cancels the action.

6.  **Resolution Phase (Action):** (`gameState.combat.phase = "actionResolution" or "displayingResult"`)
    *   If player confirmed action: Deduct CP, roll dice, determine outcome, apply effects (damage, repair, evade score).
    *   Display action results dynamically (dice roll visualization, outcome text, effect summary).
    *   AI executes its planned action(s) sequentially, using its remaining CP. AI targeting also respects firing arcs. Results are displayed dynamically.

7.  **End of Turn:**
    *   Perform any end-of-turn cleanup (e.g., expire temporary effects).
    *   Check win/loss conditions.
    *   Loop back to Start of Turn for the next turn number.

## 5. Core Mechanics Deep Dive

### 5.1. Sail Points (SP)

*   **Purpose:** Governs maneuverability (movement and rotation).
*   **Replenishment:** Fully restored to `maxSP` at the start of each turn.
*   **Costs (Planned - Subject to Tuning):**
    *   Move 1 Hex: 1 SP
    *   Rotate 60° (1 facing change): 1 SP
*   **Planning:** SP cost is calculated based on the planned path distance + the number of 60° steps needed to reach the planned orientation. The maneuver cannot be committed if `Total Cost > currentSP`.
*   **Deduction:** SP is deducted during the Maneuver Resolution phase based on the *actual* movement and rotation performed (after collision checks).

### 5.2. Crew Points (CP)

*   **Purpose:** Governs the crew's ability to perform actions (combat, repair, etc.).
*   **Replenishment:** Fully restored to `maxCP` at the start of each turn.
*   **Source:**
    *   Player: Number of crew members currently on ship (`#gameState.crew.members`), capped by ship's `crewCapacity`.
    *   Enemy: Based on ship class (`shipUtils.getBaseCP`).
*   **Costs:** Defined per action (see Actions List).
*   **Usage:** Spent during the Action Planning/Resolution phases to execute actions. Multiple actions can be performed if enough CP is available.

### 5.3. Movement & Rotation

*   **Planning:** Player/AI select both a target hex and a target orientation during their respective planning phases, constrained by SP.
*   **Resolution:** Planned rotations and moves resolve simultaneously during the Maneuver Resolution phase. Ship orientations update instantly internally, while visual rotation tweens alongside movement animation. SP is deducted based on the resolved maneuver.

### 5.4. Firing Arcs

*   **Definition:** Each ship class has defined arcs relative to its forward direction (Orientation 0).
    *   **Forward:** Directly ahead.
    *   **Sides (Broadsides):** To the left and right flanks.
    *   **Rear:** Directly behind.
*   **Constraint:** The "Fire Cannons" action can only target hexes that fall within an active firing arc based on the ship's *current* orientation (after maneuvering).
*   **Implementation:** `Combat:isInFiringArc(ship, targetQ, targetR)` checks validity. `Combat:getFiringArcHexes(ship)` calculates all valid target hexes within range.

### 5.5. Dice Rolls & Outcomes (FitD)

*   **Rolling:** Actions trigger a roll of 1-5 d6s. The pool size = Base Dice (from ship/action) + Modifiers (from crew, situation, evade scores). Max 5 dice.
*   **Zero Dice:** If modifiers reduce the pool to 0 or less, roll 2d6 and take the *lowest* result.
*   **Interpretation:** Determined by the *single highest die* rolled:
    *   **Critical Success:** Multiple 6s rolled. (Outcome Level 3)
    *   **Success:** Highest die is a 6. (Outcome Level 2)
    *   **Partial Success:** Highest die is 4 or 5. (Outcome Level 1)
    *   **Failure:** Highest die is 1, 2, or 3. (Outcome Level 0)
*   **Effects:** Actions have different effects based on the Outcome Level achieved (see Actions List).

### 5.6. Collisions

*   **Detection:** Checked during Maneuver Resolution based on `plannedMove` destinations.
*   **Rule (Basic):** If two ships plan to move to the same hex, both stop 1 hex short along their planned path. Their orientation changes still resolve as planned. SP cost is adjusted based on actual distance moved. *(More complex rules can be added later)*.

## 6. Actions List

Actions are performed during the Action Phase using CP. Player actions require confirmation via the Confirmation Window.

*   **Fire Cannons**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_FIRE` (1 CP)
    *   **Targeting:** Requires selecting an enemy ship hex within a valid firing arc and range.
    *   **Dice Pool:** `shipUtils.getBaseFirepowerDice(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   `+1` Point Blank (adjacent hex)
        *   `-X` Target Evading (where X is target's `evadeScore`)
        *   `+Y` Gunner Skill (Player only: `member.skill * Constants.GAME.GUNNER_SKILL_MULTIPLIER`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:**
        *   Critical (Lvl 3): `Constants.COMBAT.DAMAGE_CRITICAL` (3 HP) damage.
        *   Success (Lvl 2): `Constants.COMBAT.DAMAGE_SUCCESS` (2 HP) damage.
        *   Partial (Lvl 1): `Constants.COMBAT.DAMAGE_PARTIAL` (1 HP) damage.
        *   Failure (Lvl 0): No damage.
    *   **Note:** Target's `evadeScore` is reset to 0 *after* being applied to the incoming attack roll.

*   **Evade**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_EVADE` (1 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** `shipUtils.getBaseSpeed(ship.class)` + Modifiers.
    *   **Modifiers:**
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Sets the ship's `evadeScore` for the *next* turn (or until used).
        *   Critical (Lvl 3): `evadeScore = 3`
        *   Success (Lvl 2): `evadeScore = 2`
        *   Partial (Lvl 1): `evadeScore = 1`
        *   Failure (Lvl 0): `evadeScore = 0`
    *   **Note:** `evadeScore` reduces the number of dice rolled by enemies attacking this ship.

*   **Repair**
    *   **CP Cost:** `Constants.COMBAT.CP_COST_REPAIR` (2 CP)
    *   **Targeting:** Self.
    *   **Dice Pool:** 1 (Base) + Modifiers.
    *   **Modifiers:**
        *   `+Y` Surgeon Skill (Player only: `member.skill`)
        *   +/- Other situational/temporary modifiers.
    *   **Effects:** Restores ship durability (HP).
        *   Critical (Lvl 3): `+Constants.COMBAT.REPAIR_CRITICAL` (15 HP) restored.
        *   Success (Lvl 2): `+Constants.COMBAT.REPAIR_SUCCESS` (10 HP) restored.
        *   Partial (Lvl 1): `+Constants.COMBAT.REPAIR_PARTIAL` (5 HP) restored.
        *   Failure (Lvl 0): No HP restored.
    *   **Note:** Cannot repair above the ship's maximum durability.

*   **End Turn** (Player Only Action Menu Option)
    *   **CP Cost:** 0 CP
    *   **Effect:** Immediately ends the player's action planning phase and proceeds to the enemy's action resolution (if applicable) or the start of the next turn.

## 7. AI Behavior

*   Enemy AI plans its maneuver (move + rotation) within its SP budget during the Enemy Planning Phase.
*   Enemy AI plans its action(s) based on its anticipated post-maneuver state (e.g., choosing Fire Cannons only if the player is expected to be in arc).
*   During the Action Resolution Phase, the AI executes its planned actions sequentially using its available CP, respecting firing arcs based on its *actual* post-maneuver position/orientation.
*   Current AI prioritizes: Repair (if low HP), Evade (if moderate HP), Fire Cannons (if high HP and target in arc), Move closer/into arc.

## 8. Winning & Losing

*   **Victory:** Enemy ship durability reaches 0 HP. Player may receive loot. Combat ends, return to Exploration mode.
*   **Defeat:** Player ship durability reaches 0 HP. Results in Game Over (current implementation).
*   **Retreat:** (Future Feature) Player or enemy moves off the battle grid. May involve a dice roll to determine success.

## 9. UI Summary

*   **Minimal HUD:** Displays Turn/Phase, Player HP/CP/SP, Enemy HP.
*   **Ship Info Window:** On-demand details via hover.
*   **Action Menu:** Contextual list of actions available during player action planning.
*   **Confirmation Window:** Displays dice pool breakdown, modifiers, and costs before committing an action.
*   **Result Overlay:** Temporarily displays dice results and effects after an action resolves.
*   **Maneuver Planning:** Visual feedback for planned path, orientation, and SP cost.
*   **Firing Arc Highlight:** Visual indication of valid target hexes when planning "Fire Cannons".

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
Speed: 2 hexes per turn (Movement Phase)
Firepower Dice: 3 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 6)
Durability: 20 HP
Crew Capacity: 8 members (Max 8 CP per turn) (Added CP link)
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
Speed: 1 hex per turn (Movement Phase)
Firepower Dice: 6 dice per 'Fire Cannons' action. (Aligned with Design Doc) (Actual cannons: 12)
Durability: 40 HP
Crew Capacity: 12 members (Max 12 CP per turn) (Added CP link)
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
Crew Roles: Navigator, Gunner, Surgeon, etc., boosting specific actions (e.g., Navigator reduces travel time, Surgeon adds dice to Repair, Gunner adds dice to Fire Cannons). (Added Gunner effect intent)
Character Sheet:
Role: Defines specialty.
Skill Level: 1-5, adding dice/bonuses to rolls.
Loyalty: 1-10 (low risks mutiny, high enhances performance).
Influences: Victories (+1), rum (+2), long voyages (-1/week).
Health: Hit points; injuries occur in combat.
Boon/Bane: One positive trait (e.g., “Sharp-Eyed”) and one negative (e.g., 
“Cursed”).
Recruitment: Found in taverns or via quests; elite crew require high 
reputation. Hiring costs gold. (Clarified hiring cost)
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
At Sea: Zone movement costs time (base 1 week, modified by wind/crew). Major actions like specific exploration events might cost time. Combat itself does not advance the week counter, but initiating it might if tied to an action. (Clarified time costs)
In Port: Actions take 1-3 weeks (e.g., 1 for basic repairs, 2 for investments, 1 for recruiting). (Confirmed port time costs)
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
Turn Structure: Movement Phase (spend move points based on Speed) followed by Action Phase (spend Crew Points). (Aligned with Section 3.1)
Actions: Core actions (Fire, Evade, Repair) cost CP (1/1/2 respectively). Others TBD. (Aligned with Section 3.1)
Dice Pools: 1-5 d6s for attacks, evasion, etc., based on ship, crew (e.g., Gunner skill for Fire, Surgeon for Repair), and context. (Added crew skill links)
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

## Tickets/3-1-implement-hex-grid-battlefield.md
Description:

Develop a 10x10 hex grid for naval battles, including ship placement and 
movement mechanics.

Tasks:

Create a hex grid data structure (e.g., a 10x10 array) to represent the 
battle area in a new combat.lua module.
Implement functions to place ships on the grid, respecting their size (1 
hex for Sloop, 2 for Brigantine, 4 for Galleon, per the design doc).
Develop movement logic allowing ships to move to adjacent hexes based on 
their speed stat (e.g., Sloop = 3 hexes/turn).
Acceptance Criteria:

A 10x10 hex grid is visible during battles (placeholder visuals OK for 
now).
Player and enemy ships can be placed on the grid at the start of combat.
Player ship can move to adjacent hexes during a turn, respecting speed 
limits.
Notes:

Use GameState.ship.class to determine size and speed (e.g., Sloop: 3 
hexes, 1 hex size).
Store combat state in a new GameState.combat table (e.g., { grid, 
playerShip, enemyShip }).
No wind effects yet; add in Sprint 6.

## Tickets/3-2-implement-basic-combat-actions.md
Description:

Add core combat actions (Fire Cannons, Evade, Repair) integrated with the 
dice mechanics.

Tasks:

Define action functions in combat.lua:
fireCannons: Deals damage based on firepower (e.g., Sloop = 2).
evade: Attempts to dodge incoming attacks.
repair: Restores hull HP (e.g., 5 HP per success).
Integrate dice rolls (from Ticket 3.3) into each action, using ship/crew 
stats.
Apply outcomes (e.g., damage dealt, evasion success) to ship stats in 
GameState.combat.
Acceptance Criteria:

Players can select and perform Fire Cannons, Evade, or Repair during their 
turn.
Each action triggers a dice roll with appropriate outcomes (e.g., Fire 
Cannons deals damage on success).
Ship stats (e.g., durability) update correctly based on action results.
Notes:

Use placeholder stats for now (e.g., 1 die per action); refine with crew 
skills in later sprints.
Depends on Ticket 3.3 for dice mechanics.

## Tickets/3-3-develop-dice-mechanics.md
Description:

Create a system to roll dice based on crew and ship stats, interpreting 
results per the design doc.

Tasks:

Implement a rollDice(numDice) function in combat.lua that rolls 1-5 d6s 
and returns results.
Define success criteria: 6 = Success, 4-5 = Partial Success, 1-3 = 
Failure.
Calculate outcomes (e.g., count successes) and return them for use in 
actions.
Acceptance Criteria:

Dice rolls generate correct results (e.g., rolling 3d6 might yield [6, 4, 
2]).
Results are interpreted accurately (e.g., 6 = 1 success, 4 = 0.5 success).
The system integrates with combat actions (e.g., Fire Cannons uses roll 
results).
Notes:

For Sprint 3, use a fixed number of dice (e.g., 1 per cannon for Fire 
Cannons) or basic crew stats from GameState.crew.members.
Expand with crew skills (e.g., Gunner adds dice) in Sprint 6.

## Tickets/3-4-add-simple-enemy-ai.md
Description:

Develop basic AI for enemy ships to move and perform actions during 
battles.

Tasks:

Create an AI function in combat.lua to select actions (e.g., move toward 
player, Fire Cannons if in range).
Implement simple rules (e.g., attack if within 3 hexes, else move closer).
Alternate turns between player and AI in the combat loop.
Acceptance Criteria:

Enemy ships move and act during their turns (e.g., move 1 hex, fire if 
close).
AI behavior is predictable (e.g., always attacks when in range).
Turns alternate smoothly between player and AI.
Notes:

Use a basic enemy ship (e.g., Sloop stats: 1 hex, 2 firepower, 10 HP).
Depends on Tickets 3.1 and 3.2 for grid and actions.

## Tickets/3-5-design-combat-ui.md
Description:

Create a user interface to display ship stats, action options, and dice 
results during battles.

Tasks:

Design UI elements in combat.lua:
Ship stats (e.g., "HP: 10/10").
Action buttons (Fire Cannons, Evade, Repair).
Dice result display (e.g., "Rolled: 6, 4 → Success, Partial Success").
Update UI based on game state changes (e.g., HP decreases after damage).
Ensure readability within the 800x600 retro style.
Acceptance Criteria:

UI shows player and enemy ship stats (HP, position).
Action buttons are clickable and trigger corresponding actions.
Dice results display after each action (e.g., "Rolled: 6 → Success").
Notes:

Use placeholder art; refine in Sprint 10.
Refer to Game Boy Advance games (e.g., Fire Emblem) for low-res UI 
inspiration.
Depends on Tickets 3.2 and 3.3.

## Tickets/3-6-integrate-combat-system-with-exploration.md
Description:

Modify the map and ship modules to trigger battles when encountering enemy 
ships.

Tasks:

Add a GameState.enemyShips table to track enemy ship locations (e.g., { 
zone = 2, class = "Sloop" }).
Update ship.lua to detect enemy ships in the same zone during movement 
(check GameState.ship.currentZone).
Transition to combat mode by setting a GameState.settings.combatMode flag 
and initializing GameState.combat.
Acceptance Criteria:

Battles start automatically when the player moves to a zone with an enemy 
ship.
Game transitions smoothly from exploration to combat mode (UI switches to 
combat screen).
Notes:

Spawn one test enemy in a fixed zone (e.g., "Nassau") for now.
Depends on Ticket 3.1 for combat setup.

## Tickets/3-7-create-pixel-art-assets-for-combat-system.md
Description:

Design and implement pixel art for the hex grid and ship sprites during 
battles.

Tasks:

Create hex tile graphics (e.g., hex_tile.png) for the 10x10 grid.
Design or reuse ship sprites (e.g., sloop.png, brigantine.png) from Sprint 
1, ensuring visibility on the grid.
Integrate assets into combat.lua for rendering.
Acceptance Criteria:

Hex grid is visible and fits the retro aesthetic (e.g., simple outlines).
Ship sprites are clear and distinguishable on the grid (e.g., Sloop vs. 
enemy Sloop).
Notes:

Collaborate with the art team for consistency with Sprint 1 assets.
Use low-res constraints (e.g., 16x16 hex tiles).

## Tickets/3-8-handle-post-battle-outcomes.md
Description:

Implement logic to resolve battles, distribute loot, and return to 
exploration mode.

Tasks:

Define outcomes in combat.lua:
Win: Enemy HP ≤ 0.
Loss: Player HP ≤ 0 (game over for now).
Escape: Player moves off grid (dice roll TBD in Sprint 6).
Award loot (e.g., 10 gold) on win via GameState:addResources.
Update GameState.combat and transition back to GameState.settings.portMode 
= false.
Acceptance Criteria:

Game returns to exploration mode after a battle ends.
Loot (e.g., 10 gold) is added to GameState.resources.gold on victory.
Ship damage persists (e.g., HP carries over) until repaired.
Notes:

Keep outcomes simple (e.g., fixed loot); expand in Sprint 4.
Loss condition can trigger a game over screen; refine later.

## Tickets/3-x-1-refactor-combat-state-and-turn-loop-for-sp.md
Refactor Combat State & Turn Loop for SP/Planning

Description: Modify the combat state (gameState.combat) and the main combat loop in combat.lua to accommodate the new Sail Point (SP) resource, planned maneuvers (move + rotation), and the revised turn structure (Planning -> Resolution phases).

Tasks:

Modify gameState.combat ship objects (playerShip, enemyShip) to include:

currentSP: Current sail points for the turn.

maxSP: Maximum sail points (based on ship class: Sloop=5, Brigantine=4, Galleon=3). Initialize this in Combat:initBattle.

plannedMove: Table {q, r} storing the intended destination hex (or nil).

plannedRotation: Number 0-5 storing the intended final orientation (or nil).

Refactor the main combat turn progression logic in combat.lua (likely affecting endPlayerTurn, processEnemyTurn, finalizeEnemyTurn, and potentially needing new phase-handling functions) to follow the new structure:

Start of Turn: Replenish CP and SP. Clear plannedMove, plannedRotation for both ships.

Enemy Planning Phase (internal logic placeholder).

Player Planning Phase (Movement & Rotation).

Resolution Phase (Maneuver).

Player Planning Phase (Action).

Resolution Phase (Action).

End of Turn.

Ensure SP is replenished correctly at the start of each ship's turn segment or the overall turn start.

Acceptance Criteria:

gameState.combat correctly stores currentSP, maxSP, plannedMove, and plannedRotation for both ships.

maxSP is correctly initialized based on ship class in initBattle.

SP is replenished at the start of the turn.

The main combat loop structure in combat.lua reflects the new phases in the correct order (even if some phases are currently empty placeholders).

Game transitions between these new phases correctly.

Notes: This is a foundational structural change. Subsequent tickets depend heavily on this. Focus on the state and loop structure first; detailed logic for each phase comes next.

## Tickets/3-x-2-implement-maneuver-planning-ui-and-logic-for-player.md
Implement Maneuver Planning UI & Logic (Player)

Description: Develop the UI and input handling for the Player Planning (Movement & Rotation) phase, allowing the player to select a destination hex and final orientation, constrained by available Sail Points (SP).

Tasks:

Define SP costs in constants.lua or combat.lua: SP_COST_MOVE_HEX = 1, SP_COST_ROTATE_60 = 1.

Create helper function Combat:calculateManeuverCost(startHex, endHex, startOrientation, endOrientation) that returns the total SP cost for a potential maneuver (path distance + rotation steps). Use hexDistance for path distance. Calculate rotation steps efficiently (e.g., min(abs(end - start), 6 - abs(end - start))).

Modify Combat:drawUI or a related drawing function:

Display currentSP / maxSP in the minimal player HUD.

Modify Combat:draw (or a planning-phase specific draw function):

When the player ship is selected during the playerMovePlanning phase:

Show valid move hexes (potentially color-coded by SP cost).

Display UI elements for selecting target orientation (e.g., "Rotate Left"/"Rotate Right" buttons near the ship or in a fixed UI panel). Update a temporary variable holding the player's intended rotation.

Display the calculated SP cost breakdown for the hovered/selected move and the intended rotation change (e.g., "Move: 2 SP | Rotate: 1 SP | Total: 3 SP / 5 SP").

Modify Combat:mousepressed for the playerMovePlanning phase:

Handle clicks on rotation controls to update the temporary intended rotation.

Handle clicks on valid move hexes.

Implement a "Confirm Maneuver" button or mechanism.

When confirming: Check if totalCalculatedSPCost <= gameState.combat.playerShip.currentSP.

If affordable, store the selected destination hex in playerShip.plannedMove and the final orientation in playerShip.plannedRotation.

Transition gameState.combat.phase to the next phase (Maneuver Resolution).

If unaffordable, provide visual/audio feedback and do not commit/transition.

Acceptance Criteria:

Player UI clearly displays current/max SP.

Player can select a destination hex and a target orientation using UI controls.

The UI dynamically shows the SP cost for the planned move and rotation.

The player is prevented from confirming a maneuver that costs more SP than they have.

Confirming an affordable maneuver stores plannedMove and plannedRotation in gameState.combat.playerShip and advances the combat phase.

Notes: UI clarity is paramount here (Known Weakness!). Use clear visual cues for costs and affordability. Rotation controls need careful design for the low-res environment (maybe simple arrows?). Depends on Ticket 3.X.1.

## Tickets/3-x-3-implement-maneuver-planning-logic-for-ai.md
Implement Maneuver Planning Logic (AI)

Description: Update the enemy AI logic to plan both a destination hex (plannedMove) and a final orientation (plannedRotation) during its planning phase, ensuring the combined maneuver is affordable within its SP budget.

Tasks:

Modify AI functions (processEnemyTurn, potentially creating a new planEnemyManeuver function):

AI logic should determine both a target hex (targetQ, targetR) and a target orientation (targetOrientation). (Initial AI can be simple: move towards player, orient towards player).

Call Combat:calculateManeuverCost using the AI ship's current state and its targets.

Check if calculatedCost <= gameState.combat.enemyShip.currentSP.

If affordable, store the targets in enemyShip.plannedMove and enemyShip.plannedRotation.

If unaffordable, AI must revise its plan (e.g., shorter move, less rotation, or do nothing). Implement a simple fallback (e.g., stay put, no rotation).

Ensure AI planning happens before the Player Planning phase, storing the plan internally without revealing it.

Acceptance Criteria:

Enemy AI calculates the SP cost for its intended move and rotation.

AI successfully plans an affordable maneuver (move + rotation) and stores it in enemyShip.plannedMove and enemyShip.plannedRotation.

AI has a fallback behavior if its desired maneuver is too expensive.

Notes: AI complexity can be increased later. The core requirement is planning both aspects within the SP budget. Depends on Ticket 3.X.1 and the calculateManeuverCost function from 3.X.2.

## Tickets/3-x-4-implement-maneuver-resolution.md
 Implement Maneuver Resolution (Simultaneous)

Description: Implement the core logic for the Maneuver Resolution phase where both player and enemy ships simultaneously execute their planned rotations and movements, handling collisions and deducting SP.

Tasks:

Create logic within the maneuverResolution phase handler in combat.lua.

Collision Check: Before movement, check if playerShip.plannedMove and enemyShip.plannedMove result in the same destination hex or if paths cross in a way that implies collision (simplest: check destination hex conflict). Define a collision rule (e.g., both ships stop one hex short of their plannedMove along their path). Update plannedMove for affected ships if a collision occurs.

Rotation Update: Instantly update playerShip.orientation = playerShip.plannedRotation and enemyShip.orientation = enemyShip.plannedRotation.

Movement & SP Deduction:

For both ships, determine the actual path taken (original plannedMove or adjusted plannedMove after collision).

Calculate the actual SP cost incurred using Combat:calculateManeuverCost based on the start position/orientation and the actual end position/orientation.

Deduct cost: ship.currentSP = ship.currentSP - actualCost.

Set up simultaneous animation: Store start/end positions/orientations. The existing Ship:update lerping can be adapted, potentially needing coordination in combat.lua to update both ships based on their individual start/end points and a shared timer. Rotation should visually tween alongside movement.

State Update: After animations complete (or instantly for now, with animation hooks added later):

Update playerShip.position and enemyShip.position to their final resolved hexes.

Clear plannedMove and plannedRotation for both ships.

Transition gameState.combat.phase to Player Action Planning.

Acceptance Criteria:

Ship orientations are updated based on plannedRotation at the start of the phase (internal state).

A basic collision rule prevents ships from occupying the same hex.

Ships move (visually, eventually) towards their resolved destinations simultaneously.

Correct SP cost is deducted based on the actual maneuver performed.

Ship positions are updated correctly in gameState.combat.

plannedMove and plannedRotation are cleared.

Phase transitions correctly to Action Planning.

Notes: Simultaneous animation can be tricky. Initial implementation might just snap positions/orientations after calculating costs, with visual tweening added later. Collision rules can be basic for now. Depends on Tickets 3.X.1, 3.X.2, 3.X.3.

## Tickets/3-x-5-implement-firing-arcs-logic.md
 Implement Firing Arcs (Logic & Data)

Description: Define firing arc data for ship classes and implement the logic to check if a target hex is within a ship's firing arc based on its current orientation.

Tasks:

Add firingArcs data to Combat.shipDefinitions. Define arcs relative to the ship's forward direction (orientation 0). Example:

sloop: { forward = true, sides = false, rear = false } (Maybe just forward?)

brigantine: { forward = false, sides = true, rear = false } (Broadsides)

galleon: { forward = true, sides = true, rear = false } (Broadsides + some forward?) - Needs Design Clarification based on kite shape. Let's assume broadsides for now: { forward = false, sides = true, rear = false }.

Implement Combat:getFiringArcHexes(ship): Given a ship object (with position, orientation, class), return a list of absolute hex coordinates {q, r} that fall within its defined firing arc(s) and within a reasonable range (e.g., 5 hexes). This requires mapping relative arc definitions to world space based on orientation.

Implement Combat:isInFiringArc(ship, targetQ, targetR): A simpler check, returns true if the specific targetQ, targetR is within the firing arc calculated by getFiringArcHexes (or a direct geometric calculation).

Acceptance Criteria:

shipDefinitions includes firingArcs for each class.

Combat:getFiringArcHexes correctly calculates the set of hexes within range and arc based on ship orientation.

Combat:isInFiringArc correctly returns true/false for a given target hex.

Notes: This ticket focuses purely on the logic. Visualization comes in 3.X.7. Firing arc definitions might need refinement based on gameplay testing. Needs careful hex math for orientation and relative positions.

## Tickets/3-x-6-adapt-action-planning-and-resolution-for-firing-arcs.md
Adapt Action Planning & Resolution for Arcs

Description: Modify the existing Action Planning and Resolution phases to incorporate firing arc checks after the Maneuver Resolution phase.

Tasks:

Modify the Player Action Planning phase logic:

When the player selects the "Fire Cannons" action from the contextual menu (Ticket AdHoc/UI_Task_3), before showing the Confirmation Window (Ticket AdHoc/UI_Task_4):

The UI should now require selecting a target hex (likely the enemy ship's hex).

Check if the target hex is within the player ship's firing arc using Combat:isInFiringArc based on the ship's orientation after the maneuver resolution.

If not in arc, disallow targeting or show feedback ("Target not in arc").

If in arc, proceed to the Confirmation Window.

Modify Combat:fireCannons: This function now implicitly assumes the target is valid (checked during planning). No changes needed here unless damage/effects depend on which arc was used (future enhancement).

Modify Enemy AI Action Planning (chooseEnemyAction or similar):

When planning "Fire Cannons", the AI must check if the player ship is within its firing arc based on its orientation after its planned maneuver.

If the player is not in arc, the AI should choose a different action (e.g., Evade, Repair, or potentially prioritize rotation next turn).

Acceptance Criteria:

Player can only target enemy ships within their firing arc during the Action Planning phase.

The Confirmation Window for "Fire Cannons" only appears if a valid target in arc is selected.

Enemy AI only attempts to fire if the player is within its firing arc after its maneuver.

Notes: This integrates the new positioning mechanics directly into action constraints. Depends on 3.X.4 (Maneuver Resolution) and 3.X.5 (Firing Arc Logic).

## Tickets/3-x-7-visualize-firing-arcs-and-planned-maneuvers.md
 UI - Visualize Firing Arcs & Planned Maneuvers

Description: Implement visual feedback for firing arcs during action planning and potentially visualize the planned maneuver during the maneuver planning phase.

Tasks:

Firing Arc Visualization:

Create Combat:drawFiringArcs(ship) function.

When the player selects "Fire Cannons" during the Action Planning phase, call this function.

It should visually highlight the hexes within the ship's firing arc (using getFiringArcHexes from 3.X.5). Use a distinct color or overlay.

(Optional but Recommended) Planned Maneuver Visualization:

During the Player Maneuver Planning phase (Ticket 3.X.2), draw a visual representation of the planned move:

A line or series of dots from the current position to the selected destination hex.

An indicator (e.g., a ghosted ship sprite or an arrow) showing the planned final orientation at the destination hex.

This visualization should update dynamically as the player adjusts their planned move/rotation.

Acceptance Criteria:

When planning to fire cannons, the valid firing arc hexes are clearly highlighted on the grid.

(If implemented) During maneuver planning, the player sees a clear preview of their intended path and final orientation.

Visualizations are clear and readable within the low-res style.

Notes: Arc visualization is crucial for usability. Planned maneuver visualization helps players understand their choices before committing SP. Depends on 3.X.2 and 3.X.5. Requires careful attention to visual clarity (Known Weakness!).

## Tickets/3-x-8-adapt-core-ui-and-enemy-turn-visualization.md
Adapt Core UI & Enemy Turn Visualization

Description: Ensure the existing minimal HUD, contextual windows, and result overlays function correctly with the new SP system and turn structure. Streamline enemy turn visuals for the new phases.

Tasks:

Update Combat:drawMinimalPlayerStatus to include the currentSP / maxSP display.

Verify that the Ship Info Window (Task UI_Task_2), Action Menu (UI_Task_3), Confirmation Window (UI_Task_4), and Result Overlay (UI_Task_5) still function correctly within the new phase structure. Adjust triggers if necessary.

Refine Combat:processEnemyTurn visualization:

Do not show AI planning details.

During Maneuver Resolution, show the enemy ship moving/rotating simultaneously with the player.

During Action Resolution, use the Result Overlay (Task UI_Task_5) to show the outcome of the enemy's action immediately.

Acceptance Criteria:

Player HUD correctly displays SP.

Existing contextual UI elements (info window, menus, overlays) work as intended in the new turn structure.

Enemy turns resolve visually showing simultaneous movement and clear action results without unnecessary intermediate steps.

Notes: Primarily integration and refinement. Depends on most other 3.X tickets.

## Tickets/AdHoc/UI_Task_1_MinimalHUD.md
 Core Tasks:

Task: Implement Minimalist Core Combat HUD

Goal: Redesign the always-on-screen UI to show only the absolute essentials, freeing up screen real estate.

Implementation:

Modify Combat:drawUI.

Keep:

Top Bar: Turn Indicator (Player/Enemy), Phase Indicator (Move/Action), Turn Count. (Keep this compact).

Player Ship Status (Minimal): Small corner display (e.g., bottom-left) showing only current HP/Max HP and current CP/Max CP. Use icons if possible.

Enemy Ship Status (Minimal): Small corner display (e.g., top-right or bottom-right) showing only current HP/Max HP.

Remove (from always-on display):

Static sidebars with full ship details.

Static action button bar at the bottom.

Static action feedback panel.

Acceptance Criteria:

The combat screen has significantly more open space.

Only essential turn/phase info and minimal player/enemy HP/CP are constantly visible.

Static sidebars and action/feedback panels are removed.

## Tickets/AdHoc/UI_Task_2_ShipInfoWindow.md
 Task: Create Contextual Ship Info Display

Goal: Allow players to view detailed ship stats on demand, replacing static sidebars.

Implementation:

Modify Combat:mousemoved to detect hovering over a hex containing any part of a ship (player or enemy).

Create a new function Combat:drawShipInfoWindow(shipData) that draws a temporary, clean pop-up window (similar to unit stat screens in Fire Emblem).

This window should display: Ship Name, Class, Current/Max HP, Current/Max CP (if player), Speed, Firepower Dice, Evade Score (if > 0), any active Modifiers affecting the ship.

In Combat:draw, call drawShipInfoWindow for the hovered ship. The window should appear near the hovered ship but avoid obscuring critical areas.

Acceptance Criteria:

Hovering over any ship (player or enemy) displays a detailed info window for that ship.

The info window disappears when the mouse moves off the ship.

The main combat HUD remains minimal.

## Tickets/AdHoc/UI_Task_3_ActionMenu.md
 Task: Implement Contextual Action Selection Menu

Goal: Replace the static action button bar with a dynamic menu that appears when the player intends to act.

Implementation:

Modify Combat:mousepressed for the player's turn:

Clicking the player ship during the Movement Phase still selects it for movement (shows valid move hexes).

Clicking the player ship during the Action Phase (or maybe adding a dedicated "Actions" button to the minimal HUD or Ship Info Window) opens a small, contextual action menu near the player ship.

Create Combat:drawActionMenu(): Renders a simple menu listing available actions (Fire Cannons, Evade, Repair, End Turn).

Grey out actions the player cannot afford (based on CP).

Update Combat:mousepressed to handle clicks within this action menu. Selecting an action transitions to the "Confirmation" step (Task 4).

Acceptance Criteria:

The static action button bar is gone.

Clicking the player ship in the Action Phase brings up a contextual menu of actions.

Unaffordable actions are clearly indicated (greyed out).

Selecting an available action proceeds to the next step.

## Tickets/AdHoc/UI_Task_4_ConfirmationWindow.md
 Task: Develop Pre-Action Confirmation Window (Dice Stakes)

Goal: Show the player the exact dice roll setup before they commit an action, clearly displaying stakes.

Implementation:

Introduce a new combat state, e.g., gameState.combat.phase = "confirmingAction", storing which action is being confirmed.

When an action (Fire, Evade, Repair) is selected from the menu (Task 3), enter this state.

Create Combat:drawConfirmationWindow(actionData):

Draws a pop-up window.

Displays: Action Name ("Fire Cannons"), Target (if applicable, e.g., "Enemy Sloop"), Base Dice, List of Modifiers (e.g., "+1 Point Blank", "-1 Target Evading"), Final Dice Pool (e.g., "Rolling 3d6").

Briefly indicate potential outcomes (e.g., "6=Success, 4-5=Partial").

Show the CP Cost.

Provide clear "Confirm" and "Cancel" buttons within this window.

Modify Combat:mousepressed to handle clicks on "Confirm" or "Cancel". Cancel returns to the Action Phase/Menu. Confirm proceeds to execute the action (Task 5).

Acceptance Criteria:

Selecting an action from the menu displays a confirmation window.

The window clearly shows the number of dice to be rolled, accounting for all modifiers.

The player must explicitly Confirm or Cancel the action.

CP cost is visible.

## Tickets/AdHoc/UI_Task_5_ResultOverlay.md
 Task: Implement Dynamic Action Result Feedback

Goal: Replace the static feedback panel with a clear, temporary overlay showing the results of the confirmed action.

Implementation:

When "Confirm" is clicked (Task 4):

Perform the action logic (deduct CP, roll dice using diceSystem:roll, apply effects). Store the results (dice values, outcome, damage/repair/evade score) potentially in gameState.combat.actionResult as before.

Enter a brief new phase like gameState.combat.phase = "displayingResult".

Create Combat:drawActionResultOverlay():

Draws a prominent, temporary overlay (possibly centered or near the action's target).

Visually displays the dice roll (using diceSystem:drawWithHighlight).

Clearly shows the result text ("Critical Success!", "Partial Success", "Failure").

Shows the concrete effect (e.g., "-10 HP!", "+2 Evade Score!", "Repaired 5 HP!").

This overlay should either fade out after a short duration (e.g., 1.5-2 seconds) or require a click to dismiss, returning to the Action Phase.

Acceptance Criteria:

After confirming an action, the dice roll and results are shown clearly and dynamically.

The feedback is temporary and doesn't permanently clutter the screen.

The player understands the outcome of their action.

The game returns to the appropriate state (Action Phase or End Turn if CP is depleted/player chooses).

## Tickets/AdHoc/UI_Task_6_EnemyTurnVis.md
 Task: Streamline Enemy Turn Visuals

Goal: Make enemy turns resolve quickly and clearly without overwhelming the player with unnecessary AI decision detail.

Implementation:

In Combat:processEnemyTurn: Keep the AI logic, but modify the display.

When the enemy acts, don't show a confirmation window for them.

Directly trigger the Combat:drawActionResultOverlay (Task 5) showing the result of the enemy action (e.g., "Enemy Fires Cannons!", dice roll, "Success!", "-10 HP!").

Maybe add a very brief preceding indicator like a small "!" icon over the acting enemy ship.

Ensure enemy turn actions resolve visually without requiring player clicks to advance unless absolutely necessary (e.g., end of their entire turn).

Acceptance Criteria:

Enemy turns are visually less intrusive than player turns.

The results of enemy actions are clearly communicated via the feedback overlay.

The game flow during the enemy turn feels reasonably quick.

General Guidelines for the Team:

Iteration: This UI overhaul may require iteration. Encourage the team to build simple versions first and then refine based on usability testing (even just internal team testing).

Visual Consistency: Ensure new UI elements (windows, menus, overlays) match the established retro pixel art style. Placeholder art is acceptable initially, but the layout and flow are key. New art assets might be required.

Testing Resolution: Test constantly at the target 800x600 resolution to ensure readability. What looks fine on a large monitor might be unreadable when scaled down. Use pixel-perfect fonts.

Input Handling: Pay close attention to mouse clicks. Ensure clicks are only registered by the topmost relevant UI element (e.g., clicking "Confirm" shouldn't also register as clicking on the hex grid underneath). Manage game states (gameState.combat.phase) carefully to control input.

Code Structure: Keep the new drawing functions (drawShipInfoWindow, drawActionMenu, etc.) organised within combat.lua or potentially a new src/ui/combatUI.lua module if combat.lua becomes too large.

