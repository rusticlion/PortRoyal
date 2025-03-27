-- Combat System Module for Naval Battles
-- Implements a hex grid battlefield and ship combat mechanics

-- Import dice system
local diceSystem = require('dice')

local Combat = {
    -- Constants for the hex grid
    GRID_SIZE = 10,  -- 10x10 grid as per requirements
    HEX_RADIUS = 25, -- Visual size of hexagons
    HEX_HEIGHT = nil, -- Will be calculated based on radius
    HEX_WIDTH = nil,  -- Will be calculated based on radius
    
    -- Grid display properties
    gridOffsetX = 200,  -- Position of grid on screen
    gridOffsetY = 120,
    
    -- State variables for the battle
    hoveredHex = nil,   -- Currently hovered hex coordinates {q, r}
    selectedHex = nil,  -- Currently selected hex coordinates
    validMoves = {},    -- Valid move targets for selected ship
    
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
    
    -- Ship definitions for the hex grid (size, shape, movement patterns)
    shipDefinitions = {
        sloop = {
            hexSize = 1,    -- Occupies 1 hex
            speed = 3,      -- 3 hexes per turn
            shape = {{0, 0}} -- Relative {q, r} coordinates for each hex
        },
        brigantine = {
            hexSize = 2,    -- Occupies 2 hexes
            speed = 2,      -- 2 hexes per turn
            -- Represents a ship that occupies 2 hexes in a line
            shape = {{0, 0}, {1, 0}} -- Relative coordinates from anchor point
        },
        galleon = {
            hexSize = 4,    -- Occupies 4 hexes
            speed = 1,      -- 1 hex per turn
            -- Kite shape with 1 hex bow, 2 hex midship, 1 hex stern
            shape = {{0, 0}, {0, 1}, {1, 0}, {-1, 0}} -- Relative coordinates from anchor point
        }
    }
}

-- Initialize the combat system
function Combat:load(gameState)
    -- Calculate hex dimensions for drawing
    self.HEX_WIDTH = self.HEX_RADIUS * 2
    self.HEX_HEIGHT = math.sqrt(3) * self.HEX_RADIUS
    
    -- Create combat state in gameState if it doesn't exist
    if not gameState.combat then
        gameState.combat = {}
    end
    
    -- Initialize the dice system
    self:initDiceSystem()
    
    print("Combat system initialized")
end

-- Initialize a new battle
function Combat:initBattle(gameState, enemyShipClass)
    -- Create a new grid
    local grid = self:createEmptyGrid()
    
    -- Configure player ship based on gameState
    local playerShipClass = gameState.ship.class
    local playerShipSpeed = self.shipDefinitions[playerShipClass].speed
    
    -- Create battle state
    local battle = {
        grid = grid,
        playerShip = {
            class = playerShipClass,
            size = self.shipDefinitions[playerShipClass].hexSize,
            position = {2, 8}, -- Bottom-left area
            orientation = 0,   -- North-facing to start
            movesRemaining = playerShipSpeed,
            evading = 0,       -- Evasion success level
            hasActed = false   -- Whether ship has performed an action this turn
        },
        enemyShip = {
            class = enemyShipClass or "sloop", -- Default to sloop if not specified
            size = self.shipDefinitions[enemyShipClass or "sloop"].hexSize,
            position = {7, 1}, -- Top-right area
            orientation = 3,   -- South-facing to start
            movesRemaining = self.shipDefinitions[enemyShipClass or "sloop"].speed,
            durability = enemyShipClass == "galleon" and 40 or 
                        enemyShipClass == "brigantine" and 20 or 10, -- Set HP based on ship class
            evading = 0,       -- Evasion success level
            hasActed = false   -- Whether ship has performed an action this turn
        },
        turn = "player",
        phase = "movement",
        actionResult = nil,    -- Stores result of the last action
        turnCount = 1          -- Track number of turns
    }
    
    -- Place ships on the grid
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- Store battle in gameState
    gameState.combat = battle
    
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
    -- Adjust for grid offset
    local localX = x - self.gridOffsetX
    local localY = y - self.gridOffsetY
    
    -- Approach: Find the closest hex center for maximum precision
    local closestHex = nil
    local minDistance = math.huge
    
    -- Try all grid hexes (brute force approach to guarantee accuracy)
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            -- Get hex center in pixel coordinates
            local hexX, hexY = self:hexToScreen(q, r)
            hexX = hexX - self.gridOffsetX
            hexY = hexY - self.gridOffsetY
            
            -- Calculate distance from mouse to hex center
            local dx = localX - hexX
            local dy = localY - hexY
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Check if this is in the hex (hexagons have radius = self.HEX_RADIUS)
            if dist <= self.HEX_RADIUS then
                -- Inside this hex - return immediately
                return {q, r}
            end
            
            -- Otherwise track the closest hex
            if dist < minDistance then
                minDistance = dist
                closestHex = {q, r}
            end
        end
    end
    
    -- If mouse is close enough to the grid, return the closest hex
    if minDistance < self.HEX_RADIUS * 2 then
        return closestHex
    end
    
    -- Mouse is too far from any hex
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

-- Get neighbors of a hex
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

-- Convert hex coordinates to screen coordinates
function Combat:hexToScreen(q, r)
    -- Offset-coordinate system for flat-topped hex grid with alternating rows
    -- This creates a more square-shaped grid rather than a diamond
    local x = self.gridOffsetX + self.HEX_RADIUS * math.sqrt(3) * q
    local y = self.gridOffsetY + self.HEX_RADIUS * 3/2 * r
    
    -- Apply offset for odd rows (makes a brick pattern rather than diamond)
    if r % 2 == 1 then
        x = x + self.HEX_RADIUS * math.sqrt(3) / 2
    end
    
    return x, y
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
    
    -- Draw grid background
    love.graphics.setColor(0.1, 0.2, 0.4, 1) -- Dark blue water
    love.graphics.rectangle("fill", 
        self.gridOffsetX - 50, 
        self.gridOffsetY - 50, 
        self.GRID_SIZE * self.HEX_WIDTH + 100, 
        self.GRID_SIZE * self.HEX_HEIGHT + 100
    )
    
    -- Draw grid hexes
    for q = 0, self.GRID_SIZE - 1 do
        for r = 0, self.GRID_SIZE - 1 do
            local x, y = self:hexToScreen(q, r)
            
            -- Determine hex color based on content
            if battle.grid[q][r].isPlayerShip then
                love.graphics.setColor(0.2, 0.7, 0.2, 0.8) -- Green for player
            elseif battle.grid[q][r].isEnemyShip then
                love.graphics.setColor(0.7, 0.2, 0.2, 0.8) -- Red for enemy
            elseif self.hoveredHex and self.hoveredHex[1] == q and self.hoveredHex[2] == r then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.6) -- Yellow for hover
            elseif self.selectedHex and self.selectedHex[1] == q and self.selectedHex[2] == r then
                love.graphics.setColor(0.2, 0.8, 0.8, 0.6) -- Cyan for selected
            elseif self:isValidMove(q, r) then
                love.graphics.setColor(0.5, 0.7, 0.9, 0.6) -- Light blue for valid moves
            else
                love.graphics.setColor(0.3, 0.5, 0.7, 0.6) -- Blue for empty water
            end
            
            -- Draw hex
            self:drawHex(x, y)
            
            -- Draw grid coordinates for debugging
            if gameState.settings.debug then
                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.print(q .. "," .. r, x - 10, y)
            end
        end
    end
    
    -- Draw ships on top of hexes for better visibility
    self:drawShips(battle)
    
    -- Draw UI elements
    self:drawUI(gameState)
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
    for _, move in ipairs(self.validMoves) do
        if move[1] == q and move[2] == r then
            return true
        end
    end
    return false
end

-- Draw ships with proper shapes and orientations
function Combat:drawShips(battle)
    -- Draw player ship
    local pq, pr = battle.playerShip.position[1], battle.playerShip.position[2]
    local px, py = self:hexToScreen(pq, pr)
    
    love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Bright green for player ship
    love.graphics.circle("fill", px, py, self.HEX_RADIUS * 0.7)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("line", px, py, self.HEX_RADIUS * 0.7)
    
    -- Draw enemy ship
    local eq, er = battle.enemyShip.position[1], battle.enemyShip.position[2]
    local ex, ey = self:hexToScreen(eq, er)
    
    love.graphics.setColor(0.8, 0.2, 0.2, 1) -- Bright red for enemy ship
    love.graphics.circle("fill", ex, ey, self.HEX_RADIUS * 0.7)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("line", ex, ey, self.HEX_RADIUS * 0.7)
    
    -- Later implementation will draw proper ship shapes based on class and orientation
end

-- Draw UI elements for the battle
function Combat:drawUI(gameState)
    local battle = gameState.combat
    
    -- Draw turn and phase information
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Naval Battle - Turn " .. battle.turnCount, 20, 20)
    love.graphics.print("Active: " .. (battle.turn == "player" and "Your Turn" or "Enemy Turn"), 20, 40)
    love.graphics.print("Phase: " .. battle.phase, 20, 60)
    
    -- Draw player ship info
    local playerShip = battle.playerShip
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.print("Your Ship: " .. playerShip.class, 600, 20)
    love.graphics.print("HP: " .. gameState.ship.durability .. "/" .. 
                      (playerShip.class == "sloop" and 10 or 
                       playerShip.class == "brigantine" and 20 or 40), 600, 40)
    
    if battle.phase == "movement" then
        love.graphics.print("Moves: " .. playerShip.movesRemaining .. "/" .. 
                         self.shipDefinitions[playerShip.class].speed, 600, 60)
    end
    
    if playerShip.evading > 0 then
        love.graphics.print("Evading: " .. playerShip.evading, 600, 80)
    end
    
    -- Draw enemy ship info
    local enemyShip = battle.enemyShip
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.print("Enemy Ship: " .. enemyShip.class, 600, 120)
    love.graphics.print("HP: " .. enemyShip.durability .. "/" .. 
                      (enemyShip.class == "sloop" and 10 or 
                       enemyShip.class == "brigantine" and 20 or 40), 600, 140)
    
    if enemyShip.evading > 0 then
        love.graphics.print("Evading: " .. enemyShip.evading, 600, 160)
    end
    
    -- Draw action buttons if it's player's turn and in action phase
    if battle.turn == "player" and battle.phase == "action" then
        -- Fire Cannons button
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", 50, 500, 160, 40)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Fire Cannons", 80, 510)
        
        -- Evade button
        love.graphics.setColor(0.3, 0.3, 0.8, 0.8)
        love.graphics.rectangle("fill", 250, 500, 160, 40)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Evade", 300, 510)
        
        -- Repair button
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8)
        love.graphics.rectangle("fill", 450, 500, 160, 40)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Repair", 500, 510)
        
        -- End Turn button
        love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
        love.graphics.rectangle("fill", 650, 500, 100, 40)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print("End Turn", 665, 510)
    end
    
    -- Draw phase transition button
    if battle.turn == "player" and battle.phase == "movement" and playerShip.movesRemaining <= 0 then
        love.graphics.setColor(0.7, 0.7, 0.2, 0.8)
        love.graphics.rectangle("fill", 650, 500, 100, 40)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print("End Move", 665, 510)
    elseif battle.turn == "player" and battle.phase == "movement" then
        love.graphics.setColor(0.7, 0.7, 0.2, 0.8)
        love.graphics.rectangle("fill", 650, 500, 100, 40)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.print("To Action", 665, 510)
    end
    
    -- Display last action result if any
    if battle.actionResult then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 50, 400, 700, 80)
        
        -- Action title
        love.graphics.setColor(1, 1, 0, 1)
        local title
        if battle.actionResult.action == "fire" then
            title = (battle.actionResult.attacker == "player" and "You fired cannons" or "Enemy fired cannons")
            title = title .. " - Damage: " .. battle.actionResult.damage
        elseif battle.actionResult.action == "evade" then
            title = (battle.actionResult.ship == "player" and "You evaded" or "Enemy evaded")
            title = title .. " - Evasion: " .. battle.actionResult.evasion
        elseif battle.actionResult.action == "repair" then
            title = (battle.actionResult.ship == "player" and "You repaired" or "Enemy repaired")
            title = title .. " - HP Restored: " .. battle.actionResult.repairAmount
        end
        
        -- Display title
        love.graphics.print(title, 70, 410)
        
        -- Display dice rolled with visuals
        love.graphics.setColor(1, 1, 1, 1)
        local diceX = 70
        local diceY = 440
        diceSystem:draw(battle.actionResult.dice, diceX, diceY, 1.5)
        
        -- Display result text with appropriate color
        love.graphics.setColor(diceSystem:getResultColor(battle.actionResult.outcome))
        local resultText = diceSystem:getResultText(battle.actionResult.outcome)
        love.graphics.print(resultText, 250, 445)
        
        -- Display detailed counts underneath in white
        love.graphics.setColor(1, 1, 1, 1)
        local statsText = "Successes: " .. battle.actionResult.outcome.successes .. 
                       " | Partials: " .. battle.actionResult.outcome.partials .. 
                       " | Failures: " .. battle.actionResult.outcome.failures
        love.graphics.print(statsText, 70, 480)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.8)
    if battle.turn == "player" then
        if battle.phase == "movement" then
            love.graphics.print("Movement Phase: Click your ship, then click a blue hex to move", 200, 570)
        elseif battle.phase == "action" then
            love.graphics.print("Action Phase: Click a button to perform an action", 250, 570)
        end
    else
        love.graphics.print("Enemy Turn: Please wait...", 300, 570)
    end
end

-- Handle mouse movement
function Combat:mousemoved(x, y, gameState)
    if not gameState.combat then return end
    
    -- Update hovered hex
    self.hoveredHex = self:getHexFromScreen(x, y)
end

-- Handle mouse clicks
function Combat:mousepressed(x, y, button, gameState)
    if not gameState.combat then return end
    
    -- Only handle left clicks
    if button ~= 1 then return end
    
    local battle = gameState.combat
    
    -- Check if clicking on UI buttons
    if battle.turn == "player" then
        -- Phase transition button (movement -> action)
        if x >= 650 and x <= 750 and y >= 500 and y <= 540 and battle.phase == "movement" then
            -- End movement phase and start action phase
            battle.phase = "action"
            return
        end
        
        -- Action buttons (only in action phase)
        if battle.phase == "action" then
            -- Fire Cannons button
            if x >= 50 and x <= 210 and y >= 500 and y <= 540 then
                battle.actionResult = self:fireCannons(gameState)
                battle.playerShip.hasActed = true
                return
            end
            
            -- Evade button
            if x >= 250 and x <= 410 and y >= 500 and y <= 540 then
                battle.actionResult = self:evade(gameState)
                battle.playerShip.hasActed = true
                return
            end
            
            -- Repair button
            if x >= 450 and x <= 610 and y >= 500 and y <= 540 then
                battle.actionResult = self:repair(gameState)
                battle.playerShip.hasActed = true
                return
            end
            
            -- End Turn button
            if x >= 650 and x <= 750 and y >= 500 and y <= 540 then
                self:endPlayerTurn(gameState)
                return
            end
        end
    end
    
    -- If not clicking buttons, check for hex grid interactions (only in movement phase)
    if battle.turn == "player" and battle.phase == "movement" then
        local clickedHex = self:getHexFromScreen(x, y)
        if not clickedHex then return end
        
        local q, r = clickedHex[1], clickedHex[2]
        
        -- If the player's ship is clicked, select it
        if battle.grid[q][r].isPlayerShip then
            self.selectedHex = clickedHex
            -- Calculate valid moves from this position
            self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
            
            -- Debug
            if gameState.settings.debug then
                print("Selected player ship at " .. q .. "," .. r .. 
                      " with " .. battle.playerShip.movesRemaining .. " moves remaining")
            end
        
        -- If a valid move hex is clicked, move the ship there
        elseif self.selectedHex and self:isValidMove(q, r) then
            -- Move the ship to the new position
            self:moveShip(battle, battle.playerShip, q, r)
            
            -- Recalculate valid moves or clear them if no moves left
            if battle.playerShip.movesRemaining > 0 then
                self.validMoves = self:calculateValidMoves(battle, battle.playerShip)
            else
                self.validMoves = {}
                self.selectedHex = nil
                
                -- If out of moves, auto-transition to action phase
                if battle.playerShip.movesRemaining <= 0 then
                    battle.phase = "action"
                end
            end
            
            -- Debug
            if gameState.settings.debug then
                print("Moved player ship to " .. q .. "," .. r .. 
                      " with " .. battle.playerShip.movesRemaining .. " moves remaining")
            end
        end
    end
end

-- End player turn and start enemy turn
function Combat:endPlayerTurn(gameState)
    local battle = gameState.combat
    
    -- Reset player ship for next turn
    battle.playerShip.hasActed = false
    battle.playerShip.movesRemaining = self.shipDefinitions[battle.playerShip.class].speed
    
    -- Switch to enemy turn
    battle.turn = "enemy"
    battle.phase = "movement"
    
    -- Process enemy turn (simple AI)
    self:processEnemyTurn(gameState)
end

-- Process enemy turn with simple AI
function Combat:processEnemyTurn(gameState)
    local battle = gameState.combat
    
    -- In this simple implementation, enemy will:
    -- 1. Move toward player if too far, or away if too damaged
    -- 2. Fire cannons if in good health, evade if damaged, repair if critical
    
    -- Movement phase
    self:processEnemyMovement(gameState)
    
    -- Action phase
    battle.phase = "action"
    self:processEnemyAction(gameState)
    
    -- End enemy turn, back to player
    battle.enemyShip.hasActed = false
    battle.enemyShip.movesRemaining = self.shipDefinitions[battle.enemyShip.class].speed
    
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
    
    -- Calculate distance to player
    local eq, er = enemyShip.position[1], enemyShip.position[2]
    local pq, pr = playerShip.position[1], playerShip.position[2]
    local distance = self:hexDistance(eq, er, pq, pr)
    
    -- Basic AI: move toward player if healthy, away if damaged
    local movesRemaining = enemyShip.movesRemaining
    
    -- Calculate health percentage
    local maxHealth = enemyShip.class == "sloop" and 10 or 
                    enemyShip.class == "brigantine" and 20 or 40
    local healthPercent = enemyShip.durability / maxHealth
    
    while movesRemaining > 0 do
        -- Get all possible moves
        local validMoves = self:calculateValidMoves(battle, enemyShip)
        if #validMoves == 0 then break end
        
        -- Choose best move based on strategy
        local bestMove = nil
        local bestScore = -1000
        
        for _, move in ipairs(validMoves) do
            local moveQ, moveR = move[1], move[2]
            local newDist = self:hexDistance(moveQ, moveR, pq, pr)
            local score = 0
            
            -- If health > 70%, get closer to attack
            if healthPercent > 0.7 then
                score = -newDist  -- Negative distance = prefer closer
            -- If health 30-70%, maintain medium distance
            elseif healthPercent > 0.3 then
                score = -(math.abs(newDist - 3))  -- Prefer distance of about 3
            -- If health < 30%, run away
            else
                score = newDist  -- Prefer farther
            end
            
            -- Slightly randomize to avoid predictable behavior
            score = score + math.random() * 0.5
            
            if score > bestScore then
                bestScore = score
                bestMove = move
            end
        end
        
        -- Execute best move
        if bestMove then
            self:moveShip(battle, enemyShip, bestMove[1], bestMove[2])
            movesRemaining = enemyShip.movesRemaining
        else
            break
        end
    end
end

-- Process enemy action
function Combat:processEnemyAction(gameState)
    local battle = gameState.combat
    local enemyShip = battle.enemyShip
    
    -- Calculate health percentage
    local maxHealth = enemyShip.class == "sloop" and 10 or 
                    enemyShip.class == "brigantine" and 20 or 40
    local healthPercent = enemyShip.durability / maxHealth
    
    -- Choose action based on health:
    -- - If health > 70%, fire cannons
    -- - If health 30-70%, evade
    -- - If health < 30%, repair
    
    if healthPercent < 0.3 then
        -- Critically damaged - try to repair
        battle.actionResult = self:repair(gameState)
    elseif healthPercent < 0.7 then
        -- Moderately damaged - try to evade
        battle.actionResult = self:evade(gameState)
    else
        -- Healthy - attack!
        battle.actionResult = self:fireCannons(gameState)
    end
    
    -- Short delay to show the action result (would be implemented better with a timer)
    love.timer.sleep(0.5)
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
    local battle = gameState.combat
    local attacker = battle.turn == "player" and battle.playerShip or battle.enemyShip
    local defender = battle.turn == "player" and battle.enemyShip or battle.playerShip
    
    -- Calculate number of dice based on firepower (cannons)
    local numDice
    if battle.turn == "player" then
        -- Player uses their ship's firepower from gameState
        numDice = gameState.ship.firepower
    else
        -- Enemy uses firepower based on ship class
        if defender.class == "sloop" then
            numDice = 2  -- Sloop has 2 cannons
        elseif defender.class == "brigantine" then
            numDice = 6  -- Brigantine has 6 cannons
        elseif defender.class == "galleon" then
            numDice = 12  -- Galleon has 12 cannons
        else
            numDice = 2  -- Default
        end
    end
    
    -- Roll dice for attack
    local diceResults = self:rollDice(numDice)
    local outcome = self:interpretDiceResults(diceResults)
    
    -- Calculate damage based on outcome level
    local damage = 0
    if outcome.result == "critical" then
        damage = 3  -- Critical hit deals 3 damage
    elseif outcome.result == "success" then
        damage = 2  -- Success deals 2 damage
    elseif outcome.result == "partial" then
        damage = 1  -- Partial success deals 1 damage
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
    
    -- Return result for UI display
    return {
        action = "fire",
        dice = diceResults,
        outcome = outcome,
        damage = damage,
        attacker = battle.turn,
        targetDurability = battle.turn == "player" and battle.enemyShip.durability or gameState.ship.durability
    }
end

-- Evade action (Ticket 3-2)
function Combat:evade(gameState)
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Calculate number of dice based on ship class (speed influences evasion)
    local numDice
    if ship.class == "sloop" then
        numDice = 3  -- Sloops are very maneuverable (3 dice)
    elseif ship.class == "brigantine" then
        numDice = 2  -- Brigantines are moderately maneuverable (2 dice)
    else
        numDice = 1  -- Galleons are slow (1 die)
    end
    
    -- Roll dice for evasion
    local diceResults = self:rollDice(numDice)
    local outcome = self:interpretDiceResults(diceResults)
    
    -- Set evasion status based on outcome level
    local evasionLevel = outcome.level  -- 0=failure, 1=partial, 2=success, 3=critical
    
    if battle.turn == "player" then
        -- Player evades
        battle.playerShip.evading = evasionLevel
    else
        -- Enemy evades
        battle.enemyShip.evading = evasionLevel
    end
    
    -- Return result for UI display
    return {
        action = "evade",
        dice = diceResults,
        outcome = outcome,
        evasion = evasionLevel,
        ship = battle.turn
    }
end

-- Repair action (Ticket 3-2)
function Combat:repair(gameState)
    local battle = gameState.combat
    local ship = battle.turn == "player" and battle.playerShip or battle.enemyShip
    
    -- Calculate number of dice - always 1 for base repair
    local numDice = 1
    
    -- Check for surgeon in crew (adds dice)
    if battle.turn == "player" then
        -- Check player's crew for surgeon
        for _, member in ipairs(gameState.crew.members) do
            if member.role == "Surgeon" then
                numDice = numDice + member.skill  -- Add surgeon's skill level
                break
            end
        end
    end
    
    -- Roll dice for repair
    local diceResults = self:rollDice(numDice)
    local outcome = self:interpretDiceResults(diceResults)
    
    -- Calculate repair amount based on outcome level
    local repairAmount = 0
    if outcome.result == "critical" then
        repairAmount = 15  -- Critical repair restores 15 HP
    elseif outcome.result == "success" then
        repairAmount = 10  -- Success restores 10 HP
    elseif outcome.result == "partial" then
        repairAmount = 5   -- Partial success restores 5 HP
    end
    
    -- Apply repairs
    if battle.turn == "player" then
        -- Player repairs their ship
        gameState.ship.durability = math.min(gameState.ship.durability + repairAmount, 
                                           gameState.ship.class == "sloop" and 10 or 
                                           gameState.ship.class == "brigantine" and 20 or 40)
    else
        -- Enemy repairs their ship
        local maxDurability = ship.class == "sloop" and 10 or 
                             ship.class == "brigantine" and 20 or 40
        
        battle.enemyShip.durability = math.min((battle.enemyShip.durability or 10) + repairAmount, 
                                            maxDurability)
    end
    
    -- Return result for UI display
    return {
        action = "repair",
        dice = diceResults,
        outcome = outcome,
        repairAmount = repairAmount,
        ship = battle.turn,
        currentDurability = battle.turn == "player" and gameState.ship.durability or battle.enemyShip.durability
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

return Combat