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
            maxCrewPoints = gameState.crew.members and #gameState.crew.members or 1  -- Maximum crew points per turn
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
            maxCrewPoints = shipUtils.getBaseCP(enemyShipClass or "sloop")
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
    local angle = orientation * math.pi / 3
    
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
    local angle = orientation * math.pi / 3
    
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
        local angle = orientation * math.pi / 3
        
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
        local angle = orientation * math.pi / 3
        
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
    
    -- Draw moves or crew points based on phase
    if battle.phase == "movement" then
        self:drawMovementInfo(battle.playerShip, gridTop, sidebarWidth)
    else
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

-- Draw movement info for a ship
function Combat:drawMovementInfo(ship, gridTop, sidebarWidth)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("MOVEMENT:", 15, gridTop + 165)
    local baseSpeed = shipUtils.getBaseSpeed(ship.class)
    local movePercent = ship.movesRemaining / baseSpeed
    self:drawProgressBar(15, gridTop + 185, sidebarWidth - 30, 16, movePercent, Constants.COLORS.BUTTON_EVADE, Constants.COLORS.UI_BORDER)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(ship.movesRemaining .. "/" .. baseSpeed, 50, gridTop + 187)
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
    
    -- Draw enemy ship additional info
    if battle.enemyShip.evadeScore > 0 then
        love.graphics.setColor(0.9, 0.7, 0.3, 1)
        love.graphics.print("EVADE SCORE: " .. battle.enemyShip.evadeScore, screenWidth - sidebarWidth + 15, gridTop + 165)
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
        if battle.phase == "action" then
            self:drawActionButtons(battle, buttonsY, screenWidth, layout.sidebarWidth)
        else
            self:drawMovementControls(battle, buttonsY, screenWidth)
        end
    else
        -- Enemy turn - show a "Waiting..." animation or indicator
        love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
        love.graphics.printf("ENEMY TAKING ACTION...", 0, buttonsY + 15, screenWidth, "center")
    end
end

-- Draw the action buttons
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
        if battle.phase == "movement" then
            instructions = "MOVEMENT PHASE: Click your ship, then click a blue hex to move"
        elseif battle.phase == "action" then
            instructions = "ACTION PHASE: Click a button to perform an action"
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
    self.hoveredHex = self:getHexFromScreen(x, y)
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
    -- (but only if click is inside the grid area)
    if self:isPointInGridArea(x, y, layout) then
        if battle.turn == "player" and battle.phase == "movement" then
            self:handleHexClick(x, y, battle, gameState)
        end
    end
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

return Combat