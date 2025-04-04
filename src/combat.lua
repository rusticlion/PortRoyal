-- Combat module for naval combat
local Combat = {
    -- Configuration values
    GRID_SIZE = 12,       -- Size of the hex grid (12x12)
    HEX_RADIUS = 30,      -- Size of hexes in pixels
    GRID_CENTER_X = 400,  -- Default center X of the grid (will be calculated in load)
    GRID_CENTER_Y = 300,  -- Default center Y of the grid (will be calculated in load)
    
    -- State tracking
    selectedHex = nil,    -- Currently selected hex coordinates {q, r}
    hoveredHex = nil,     -- Hex currently being hovered {q, r}
    validMoves = {},      -- List of valid moves from selected hex
    
    -- Maneuver planning state
    plannedMoveHex = nil, -- Planned destination hex {q, r}
    plannedRotation = nil, -- Planned final orientation (0-5)
    rotationButtons = nil, -- UI button regions for rotation
    confirmManeuverButton = nil, -- UI button region for confirm
    
    -- Ship definitions
    shipDefinitions = {
        sloop = {
            name = "Sloop",
            hexSize = 1,       -- Number of hexes the ship occupies
            shape = {{0, 0}},  -- Offsets from the position hex (q, r)
            maxHP = 6,
            speed = 3,
            cannon = 2
        },
        brigantine = {
            name = "Brigantine",
            hexSize = 2,
            shape = {{0, 0}, {1, 0}},  -- Two hexes in a row (will be rotated based on orientation)
            maxHP = 10,
            speed = 2,
            cannon = 4
        }
    }
}

-- Draw the maneuver planning controls
function Combat:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
    local buttonSpacing = 20
    local buttonWidth = 120
    local buttonHeight = 30
    
    -- First draw instructions
    love.graphics.setColor(1, 1, 1, 0.8)
    
    -- Different instructions based on current planning state
    if self.plannedMoveHex and self.plannedRotation then
        -- If both destination and rotation are selected
        love.graphics.printf("CONFIRM MANEUVER", 0, buttonsY + 5, screenWidth, "center")
    elseif self.plannedMoveHex then
        -- If destination selected, prompt for rotation
        love.graphics.printf("CHOOSE FINAL ORIENTATION", 0, buttonsY + 5, screenWidth, "center")
    elseif self.plannedRotation then
        -- If only rotation is planned, show that
        love.graphics.printf("ROTATE IN PLACE OR SELECT DESTINATION", 0, buttonsY + 5, screenWidth, "center")
    else
        -- If nothing planned yet
        love.graphics.printf("SELECT DESTINATION OR ROTATE IN PLACE", 0, buttonsY + 5, screenWidth, "center")
    end
    
    -- Always draw rotation controls
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
    
    -- Show confirm button if we have a planned rotation (with or without movement)
    if self.plannedRotation ~= nil then
        -- Calculate total cost
        local targetQ, targetR = nil, nil
        if self.plannedMoveHex then
            targetQ, targetR = self.plannedMoveHex[1], self.plannedMoveHex[2]
        end
        
        local cost = self:calculateSPCost(battle.playerShip, targetQ, targetR, self.plannedRotation)
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
        
        -- Button text for confirm
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Indicate what kind of maneuver this is
        local buttonText = ""
        if self.plannedMoveHex then
            buttonText = "MOVE + ROTATE"
        else
            buttonText = "ROTATE ONLY"
        end
        
        love.graphics.printf(buttonText .. " (" .. cost .. " SP)", self.confirmManeuverButton.x, 
                          self.confirmManeuverButton.y + 8, buttonWidth, "center")
    end
end

-- Handle clicks during maneuver planning phase
function Combat:handleManeuverPlanningClick(x, y, battle)
    print("Handling maneuver planning click at " .. x .. "," .. y)
    
    -- Check for rotation button clicks (available regardless of whether a move is planned)
    if self.rotationButtons then
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
    
    -- Check if Confirm button is clicked (available if rotation is planned, with or without movement)
    if self.plannedRotation ~= nil and self.confirmManeuverButton then
        if self:isPointInRect(x, y, self.confirmManeuverButton) then
            print("Confirm button clicked")
            
            -- Calculate total cost
            local targetQ, targetR = nil, nil
            if self.plannedMoveHex then
                targetQ, targetR = self.plannedMoveHex[1], self.plannedMoveHex[2]
            end
            
            local cost = self:calculateSPCost(battle.playerShip, targetQ, targetR, self.plannedRotation)
            
            -- Check if player has enough SP
            if cost <= battle.playerShip.currentSP then
                print("Confirming maneuver - cost: " .. cost .. " SP")
                
                -- Store planned move and rotation in ship data
                if self.plannedMoveHex then
                    battle.playerShip.plannedMove = {self.plannedMoveHex[1], self.plannedMoveHex[2]}
                else
                    -- For rotation-only maneuvers, stay in place
                    battle.playerShip.plannedMove = {battle.playerShip.position[1], battle.playerShip.position[2]}
                end
                
                battle.playerShip.plannedRotation = self.plannedRotation
                
                -- Now auto-plan enemy maneuver (this would normally be handled by AI)
                self:planEnemyManeuver(battle)
                
                -- Advance to next phase (maneuver resolution)
                self:advanceToNextPhase(battle)
                
                -- Reset planning variables
                self.plannedMoveHex = nil
                self.plannedRotation = nil
                self.hoveredMoveHex = nil
                self.rotationButtons = nil
                self.confirmManeuverButton = nil
                
                return true
            else
                print("Not enough SP for maneuver")
                -- Could add visual feedback here
                return true
            end
        end
    end
    
    -- Check if a valid move destination is clicked
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
            self.validMoves = self:calculateValidMoves_SP(battle, battle.playerShip)
            print("Ship selected: calculated " .. #self.validMoves .. " valid moves")
            
            return true
        else
            print("Hex is not a valid move or player ship")
            return false
        end
    end
    
    print("No hex found at click position")
    return false
end

-- Handle mouse press events in combat mode
function Combat:mousepressed(x, y, button, gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Only handle left clicks
    if button ~= 1 then return end
    
    -- Handle based on current phase
    if battle.phase == "playerMovePlanning" then
        -- Handle the new maneuver planning phase
        local handled = self:handleManeuverPlanningClick(x, y, battle)
        print("Maneuver planning click handled: " .. tostring(handled))
        
        -- Debug: if clicks aren't working, force calculate valid moves
        if not handled then
            print("Click not handled - recalculating valid moves using SP system")
            self.validMoves = {}
            self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
            self.validMoves = self:calculateValidMoves_SP(battle, battle.playerShip)
            print("Fallback recalculation found " .. #self.validMoves .. " valid moves")
        end
    elseif battle.phase == "playerActionPlanning" then
        -- Action planning phase - to be implemented
        print("Action planning not yet implemented")
    elseif battle.phase == "displayingResult" then
        -- Dismiss results and proceed to next phase
        self:advanceToNextPhase(battle)
    end
end

-- Plan a maneuver for the enemy ship
function Combat:planEnemyManeuver(battle)
    print("Planning enemy maneuver")
    
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Simple AI: if player ship is nearby, try to stay at a distance and rotate to face them
    -- If player ship is farther away, move toward them
    
    -- Calculate distance to player ship
    local distanceToPlayer = self:hexDistance(
        enemyShip.position[1], enemyShip.position[2],
        playerShip.position[1], playerShip.position[2]
    )
    
    -- Calculate valid moves for the enemy
    local validMoves = self:calculateValidMoves_SP(battle, enemyShip)
    print("Enemy has " .. #validMoves .. " possible moves")
    
    -- Default: Stay in place
    local chosenMove = {enemyShip.position[1], enemyShip.position[2]}
    
    -- If we have valid moves, choose a good one
    if #validMoves > 0 then
        -- Simple strategy: if too close, move away; if far, move closer
        if distanceToPlayer <= 2 then
            -- Try to keep distance - find move that maximizes distance
            local maxDistance = distanceToPlayer
            for _, move in ipairs(validMoves) do
                local moveDistance = self:hexDistance(move[1], move[2], playerShip.position[1], playerShip.position[2])
                if moveDistance > maxDistance then
                    maxDistance = moveDistance
                    chosenMove = move
                end
            end
        else 
            -- Move toward player - find move that minimizes distance
            local minDistance = distanceToPlayer
            for _, move in ipairs(validMoves) do
                local moveDistance = self:hexDistance(move[1], move[2], playerShip.position[1], playerShip.position[2])
                if moveDistance < minDistance then
                    minDistance = moveDistance
                    chosenMove = move
                end
            end
        end
    end
    
    -- Determine best orientation (face toward player)
    local targetOrientation = self:calculateOrientationToward(
        chosenMove[1], chosenMove[2],
        playerShip.position[1], playerShip.position[2]
    )
    
    -- Set enemy's planned move and rotation
    enemyShip.plannedMove = chosenMove
    enemyShip.plannedRotation = targetOrientation
    
    print("Enemy will move to " .. chosenMove[1] .. "," .. chosenMove[2] .. 
          " with orientation " .. targetOrientation)
          
    return true
end

-- Move to the next phase of combat
function Combat:advanceToNextPhase(battle)
    -- Combat phases:
    -- 1. Planning Phase (Player) - "playerMovePlanning"
    -- 2. Resolution Phase (Movement) - "maneuverResolution"
    -- 3. Planning Phase (Action) - "playerActionPlanning"
    -- 4. Resolution Phase (Action) - "actionResolution" 
    -- 5. End of Turn -> back to 1
    
    -- Current phase determines the next phase
    print("Advancing from phase: " .. battle.phase)
    
    if battle.phase == "playerMovePlanning" then
        -- After player commits a movement plan, advance to maneuver resolution
        battle.phase = "maneuverResolution"
        
        -- Immediately process the maneuver resolution (with animation in the draw function)
        self:processManeuverResolution(battle)
        
    elseif battle.phase == "maneuverResolution" then
        -- After maneuvers resolve, advance to player action planning
        battle.phase = "playerActionPlanning"
        
    elseif battle.phase == "playerActionPlanning" then
        -- After player plans actions, advance to action resolution
        battle.phase = "actionResolution"
        
    elseif battle.phase == "actionResolution" then
        -- After action resolution, show results
        battle.phase = "displayingResult"
        
    elseif battle.phase == "displayingResult" then
        -- After player dismisses results, start a new turn
        self:startNewTurn(battle)
        
        -- Process enemy planning for the new turn
        self:processEnemyPlanning(battle)
    end
    
    print("Combat phase advanced to: " .. battle.phase)
end

-- Calculate the best orientation to face from one hex toward another
function Combat:calculateOrientationToward(fromQ, fromR, toQ, toR)
    -- Convert to cube coordinates
    local fromCube = {self:offsetToCube(fromQ, fromR)}
    local toCube = {self:offsetToCube(toQ, toR)}
    
    -- Calculate direction vector
    local dirX = toCube[1] - fromCube[1]
    local dirY = toCube[2] - fromCube[2]
    local dirZ = toCube[3] - fromCube[3]
    
    -- Find the direction with the largest component
    local absX, absY, absZ = math.abs(dirX), math.abs(dirY), math.abs(dirZ)
    
    -- Determine the orientation based on the most significant direction
    if absX >= absY and absX >= absZ then
        -- X-dominant
        return (dirX > 0) and 0 or 3  -- East or West
    elseif absY >= absX and absY >= absZ then
        -- Y-dominant
        return (dirY > 0) and 1 or 4  -- Northeast or Southwest
    else
        -- Z-dominant
        return (dirZ > 0) and 2 or 5  -- Southeast or Northwest
    end
end

-- Calculate a path between two hexes for visualization
function Combat:calculatePath(startQ, startR, endQ, endR)
    local path = {}
    
    -- If start and end are the same, return just the start point
    if startQ == endQ and startR == endR then
        return {{startQ, startR}}
    end
    
    -- Calculate the approximate line between points
    local distance = self:hexDistance(startQ, startR, endQ, endR)
    
    -- Add the start point
    table.insert(path, {startQ, startR})
    
    -- For simple straight paths, just interpolate
    if distance > 1 then
        for i = 1, distance - 1 do
            -- Interpolate between start and end
            local t = i / distance
            
            -- Use cube coordinates for interpolation (more precise for hexes)
            local startCube = {self:offsetToCube(startQ, startR)}
            local endCube = {self:offsetToCube(endQ, endR)}
            
            -- Linear interpolation in cube space
            local interpCube = {
                math.round(startCube[1] + (endCube[1] - startCube[1]) * t),
                math.round(startCube[2] + (endCube[2] - startCube[2]) * t),
                math.round(startCube[3] + (endCube[3] - startCube[3]) * t)
            }
            
            -- Convert back to offset coordinates
            local q, r = self:cubeToOffset(interpCube[1], interpCube[2], interpCube[3])
            
            -- Avoid duplicates
            local isDuplicate = false
            for _, point in ipairs(path) do
                if point[1] == q and point[2] == r then
                    isDuplicate = true
                    break
                end
            end
            
            -- Add if not a duplicate
            if not isDuplicate then
                table.insert(path, {q, r})
            end
        end
    end
    
    -- Add the end point if not already added
    local lastPoint = path[#path]
    if lastPoint[1] ~= endQ or lastPoint[2] ~= endR then
        table.insert(path, {endQ, endR})
    end
    
    return path
end

-- Draw grid hexes
function Combat:drawHexes(battle, showDebug)
    -- First, calculate the path if we have a planned move
    local path = nil
    if self.plannedMoveHex and battle.playerShip then
        local startQ, startR = battle.playerShip.position[1], battle.playerShip.position[2]
        local endQ, endR = self.plannedMoveHex[1], self.plannedMoveHex[2]
        path = self:calculatePath(startQ, startR, endQ, endR)
    end

    -- Draw all hexes with an extra cell on even rows for symmetry
    for r = 0, self.GRID_SIZE - 1 do
        -- Determine row width - add one extra cell for even rows
        local rowWidth = self.GRID_SIZE
        if r % 2 == 0 then 
            rowWidth = rowWidth + 1
        end
        
        -- Calculate starting q to center the row
        local startQ = 0
        
        for q = startQ, startQ + rowWidth - 1 do
            local x, y = self:hexToScreen(q, r)
            
            -- Determine if this hex is part of the planned path
            local isPathHex = false
            local pathIndex = 0
            if path then
                for i, point in ipairs(path) do
                    if point[1] == q and point[2] == r and 
                       not (i == 1 and battle.grid[q][r].isPlayerShip) then -- Skip the starting hex
                        isPathHex = true
                        pathIndex = i
                        break
                    end
                end
            end
            
            -- Determine hex color based on content
            if battle.grid[q][r].isPlayerShip then
                -- Green outline for player ship hex, but transparent fill
                love.graphics.setColor(self.COLORS.PLAYER_SHIP[1], self.COLORS.PLAYER_SHIP[2], 
                                      self.COLORS.PLAYER_SHIP[3], 0.2)
            elseif battle.grid[q][r].isEnemyShip then
                -- Red outline for enemy ship hex, but transparent fill
                love.graphics.setColor(self.COLORS.ENEMY_SHIP[1], self.COLORS.ENEMY_SHIP[2], 
                                      self.COLORS.ENEMY_SHIP[3], 0.2)
            elseif self.plannedMoveHex and self.plannedMoveHex[1] == q and self.plannedMoveHex[2] == r then
                -- Green/yellow pulsing for planned destination
                local pulse = math.abs(math.sin(love.timer.getTime() * 2))
                love.graphics.setColor(0.3 + pulse * 0.6, 0.7 + pulse * 0.3, 0.2, 0.6 + pulse * 0.4)
            elseif isPathHex then
                -- Path visualization (gradient from pale green to planned destination)
                if path and #path > 0 then
                    local progress = pathIndex / #path
                    love.graphics.setColor(0.2 + progress * 0.3, 0.6 + progress * 0.2, 0.2 + progress * 0.2, 0.6)
                else
                    love.graphics.setColor(0.2, 0.6, 0.2, 0.6)
                end
            elseif self.hoveredHex and self.hoveredHex[1] == q and self.hoveredHex[2] == r then
                love.graphics.setColor(self.COLORS.HOVER) -- Yellow for hover
            elseif self.selectedHex and self.selectedHex[1] == q and self.selectedHex[2] == r then
                love.graphics.setColor(self.COLORS.SELECTED) -- Cyan for selected
            elseif self:isValidMove(q, r) then
                love.graphics.setColor(self.COLORS.VALID_MOVE) -- Light blue for valid moves
            else
                love.graphics.setColor(self.COLORS.EMPTY_WATER) -- Blue for empty water
            end
            
            -- Determine if this is a ship hex and which team
            local isShipHex = battle.grid[q][r].isPlayerShip or battle.grid[q][r].isEnemyShip
            local shipTeam = nil
            if battle.grid[q][r].isPlayerShip then
                shipTeam = "player"
            elseif battle.grid[q][r].isEnemyShip then
                shipTeam = "enemy"
            end
            
            -- Draw hex with appropriate styling
            self:drawHex(x, y, isShipHex, shipTeam)
            
            -- Draw grid coordinates for debugging
            if showDebug then
                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.print(q .. "," .. r, x - 10, y)
            end
        end
    end
    
    -- Draw path directional indicators
    if path and #path > 1 then
        for i = 1, #path - 1 do
            local q1, r1 = path[i][1], path[i][2]
            local q2, r2 = path[i + 1][1], path[i + 1][2]
            
            -- Skip the start hex
            if not (i == 1 and battle.grid[q1][r1].isPlayerShip) then
                local x1, y1 = self:hexToScreen(q1, r1)
                local x2, y2 = self:hexToScreen(q2, r2)
                
                -- Calculate direction
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                
                -- Skip very short segments
                if len > 10 then
                    dx, dy = dx / len, dy / len
                    
                    -- Draw a direction arrow
                    love.graphics.setColor(1, 1, 1, 0.8)
                    
                    -- Calculate midpoint and slightly offset
                    local midX, midY = (x1 + x2) / 2, (y1 + y2) / 2
                    
                    -- Draw direction indicator
                    local arrowLen = 10
                    local arrowWidth = 6
                    
                    -- Line
                    love.graphics.setLineWidth(2)
                    love.graphics.line(midX - dx * arrowLen, midY - dy * arrowLen,
                                     midX + dx * arrowLen, midY + dy * arrowLen)
                    
                    -- Arrowhead
                    local perpX, perpY = -dy, dx -- perpendicular vector
                    love.graphics.polygon("fill",
                        midX + dx * arrowLen, midY + dy * arrowLen,
                        midX - dx * arrowLen/2 + perpX * arrowWidth/2, midY - dy * arrowLen/2 + perpY * arrowWidth/2,
                        midX - dx * arrowLen/2 - perpX * arrowWidth/2, midY - dy * arrowLen/2 - perpY * arrowWidth/2
                    )
                    
                    -- Reset line width
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end
end

-- Draw a single hexagon at position x,y
function Combat:drawHex(x, y, isShipHex, shipTeam)
    local vertices = {}
    
    -- For pointy-top hexes, start at the top (rotated 30 degrees from flat-top)
    local startAngle = math.pi / 6  -- 30 degrees
    
    for i = 0, 5 do
        local angle = startAngle + (i * math.pi / 3)
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Draw the fill
    love.graphics.polygon("fill", vertices)
    
    -- Draw outline with proper color and thickness
    local currentColor = {love.graphics.getColor()}
    
    if isShipHex then
        -- Draw a thicker, more visible outline for ship hexes
        if shipTeam == "player" then
            love.graphics.setColor(self.COLORS.PLAYER_SHIP[1], self.COLORS.PLAYER_SHIP[2], 
                                 self.COLORS.PLAYER_SHIP[3], 0.8)
        elseif shipTeam == "enemy" then
            love.graphics.setColor(self.COLORS.ENEMY_SHIP[1], self.COLORS.ENEMY_SHIP[2], 
                                 self.COLORS.ENEMY_SHIP[3], 0.8)
        end
        
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", vertices)
        love.graphics.setLineWidth(1)
    else
        -- Normal outline
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.polygon("line", vertices)
    end
    
    -- Restore the original color
    love.graphics.setColor(currentColor)
end

-- Calculate valid moves for SP-based movement
function Combat:calculateValidMoves_SP(battle, ship)
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
                if battle.grid[newQ] and battle.grid[newQ][newR] and not (battle.grid[newQ][newR].isPlayerShip or battle.grid[newQ][newR].isEnemyShip) then
                    table.insert(self.validMoves, {newQ, newR})
                    print("FORCED valid move: " .. newQ .. "," .. newR)
                end
            end
        end
    end
    
    -- Print debug summary
    print("Calculated " .. #self.validMoves .. " valid moves for ship with " .. availableSP .. " SP")
    return self.validMoves
end

-- Wrapper function to ensure SP-based movement is used
function Combat:calculateValidMoves(battle, ship)
    print("USING SP-BASED VALID MOVES CALCULATION")
    return self:calculateValidMoves_SP(battle, ship)
end

-- Calculate valid moves for a ship from its current position (OLD LEGACY METHOD - NO LONGER USED)
function Combat:calculateValidMoves_Legacy(battle, ship)
    local q, r = ship.position[1], ship.position[2]
    local movesRemaining = ship.movesRemaining or 3 -- Fallback value
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
                    if battle.grid[nq] and battle.grid[nq][nr] and battle.grid[nq][nr].content ~= "ship" then
                        visited[key] = true
                        table.insert(queue, {nq, nr, distance + 1})
                    end
                end
            end
        end
    end
    
    print("WARNING: Legacy movement calculation used - this should not happen!")
    return validMoves
end

-- Get the maximum SP for a ship class
function Combat:getMaxSP(shipClass)
    -- Default values based on ship class
    local defaultValues = {
        sloop = 3,
        brigantine = 2
    }
    
    return defaultValues[shipClass] or 2  -- Default fallback
end

-- Calculate the SP cost of a planned maneuver
function Combat:calculateSPCost(ship, targetQ, targetR, targetOrientation)
    local spCost = 0
    
    -- Movement cost: SP_COST_MOVE_HEX per hex moved
    if targetQ and targetR then
        local distance = self:hexDistance(ship.position[1], ship.position[2], targetQ, targetR)
        spCost = spCost + (distance * self.Constants.COMBAT.SP_COST_MOVE_HEX)
    end
    
    -- Rotation cost: SP_COST_ROTATE_60 per 60° orientation change
    if targetOrientation ~= nil then
        -- Calculate the shortest rotation distance
        local currentOrientation = ship.orientation
        local rotationDistance = math.min(
            math.abs(targetOrientation - currentOrientation),
            6 - math.abs(targetOrientation - currentOrientation)
        )
        spCost = spCost + (rotationDistance * self.Constants.COMBAT.SP_COST_ROTATE_60)
    end
    
    return spCost
end

-- Check if a given hex coordinate is a valid move
function Combat:isValidMove(q, r)
    -- Check if we have valid moves calculated
    if not self.validMoves or #self.validMoves == 0 then
        return false
    end
    
    -- Check if the given coordinate is in our valid moves list
    for _, move in ipairs(self.validMoves) do
        if move[1] == q and move[2] == r then
            return true
        end
    end
    
    return false
end

-- Helper function to check if a point is inside a rectangle
function Combat:isPointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width and
           y >= rect.y and y <= rect.y + rect.height
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
    
    -- Filter out neighbors that are out of bounds
    local validNeighbors = {}
    for _, neighbor in ipairs(neighbors) do
        local nq, nr = neighbor[1], neighbor[2]
        if nq >= 0 and nq < self.GRID_SIZE and nr >= 0 and nr < self.GRID_SIZE then
            table.insert(validNeighbors, neighbor)
        end
    end
    
    return validNeighbors
end

-- Clear a ship from the grid (used during maneuver resolution)
function Combat:clearShipFromGrid(grid, ship)
    print("Clearing ship " .. ship.class .. " from grid at position " .. ship.position[1] .. "," .. ship.position[2])
    
    -- Method 1: If ship definition and shape transformation are available
    if ship.class and self.shipDefinitions and self.shipDefinitions[ship.class] and self.shipDefinitions[ship.class].shape then
        local q, r = ship.position[1], ship.position[2]
        local shape = self.shipDefinitions[ship.class].shape
        
        -- Transform shape based on orientation
        local transformedShape = self:transformShapeByOrientation(shape, ship.orientation)
        
        -- Clear the ship from each occupied hex
        for _, offset in ipairs(transformedShape) do
            local hexQ = q + offset[1]
            local hexR = r + offset[2]
            
            -- Check if within grid bounds
            if hexQ >= 0 and hexQ < self.GRID_SIZE and hexR >= 0 and hexR < self.GRID_SIZE then
                grid[hexQ][hexR].ship = nil
                grid[hexQ][hexR].content = "empty"
                grid[hexQ][hexR].isPlayerShip = false
                grid[hexQ][hexR].isEnemyShip = false
                print("Cleared hex " .. hexQ .. "," .. hexR)
            end
        end
    else
        -- Method 2: Fallback to scanning the entire grid (less efficient but safer)
        print("Using fallback grid scan to clear ship")
        for q = 0, self.GRID_SIZE - 1 do
            for r = 0, self.GRID_SIZE - 1 do
                if grid[q] and grid[q][r] and grid[q][r].ship == ship then
                    grid[q][r].ship = nil
                    grid[q][r].content = "empty"
                    grid[q][r].isPlayerShip = false
                    grid[q][r].isEnemyShip = false
                    print("Cleared hex " .. q .. "," .. r .. " (fallback method)")
                end
            end
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

-- Convert from offset to cube coordinates for hex calculations
function Combat:offsetToCube(q, r)
    -- For an odd-r offset system
    local x = q - (r - (r % 2)) / 2
    local z = r
    local y = -x - z
    return x, y, z
end

-- Convert from cube to offset coordinates
function Combat:cubeToOffset(x, y, z)
    -- For an odd-r offset system
    local q = x + (z - (z % 2)) / 2
    local r = z
    return q, r
end

-- Calculate distance between two hexes using cube coordinates
function Combat:hexDistance(q1, r1, q2, r2)
    -- Convert to cube coordinates
    local x1, y1, z1 = self:offsetToCube(q1, r1)
    local x2, y2, z2 = self:offsetToCube(q2, r2)
    
    -- Manhattan distance in cube coordinates
    return (math.abs(x1 - x2) + math.abs(y1 - y2) + math.abs(z1 - z2)) / 2
end

-- Convert screen coordinates to hex grid coordinates
function Combat:getHexFromScreen(x, y)
    -- Calculate the same grid parameters as in hexToScreen
    local size = self.HEX_RADIUS
    local hexWidth = size * math.sqrt(3)
    
    -- Calculate grid dimensions in hexes and pixels
    local gridCols = self.GRID_SIZE + 0.5  -- Add 0.5 to account for odd row extensions
    local gridRows = self.GRID_SIZE
    
    -- Calculate the total width and height of the hex grid
    local totalGridWidthPixels = gridCols * hexWidth
    local totalGridHeightPixels = gridRows * size * 1.5 + size * 0.5
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate the top-left corner of the grid (same as in hexToScreen)
    local gridStartX = (screenWidth - totalGridWidthPixels) / 2
    local gridStartY = (screenHeight - totalGridHeightPixels) / 2 - 30
    
    -- Adjust input coordinates relative to the grid origin
    local relX = x - gridStartX
    local relY = y - gridStartY
    
    -- Get the row first (easier in pointy-top orientation)
    local approxRow = relY / (size * 1.5)
    local approxRowInt = math.floor(approxRow)
    local isOddRow = approxRowInt % 2 == 1
    
    -- Adjust x for odd row offset
    if isOddRow then
        relX = relX - (hexWidth / 2)
    end
    
    -- Calculate approximate axial coordinates
    local q = relX / hexWidth
    local r = relY / (size * 1.5)
    
    -- Convert to cube for proper rounding
    local cx, cy, cz = self:axialToCube(q, r)
    local rx, ry, rz = self:roundCube(cx, cy, cz)
    local roundedQ, roundedR = self:cubeToAxial(rx, ry, rz)
    
    -- Check if the resulting hex is within the grid bounds, accounting for even rows having an extra cell
    if roundedQ >= 0 and roundedR >= 0 and roundedR < self.GRID_SIZE then
        -- Check horizontal bounds based on row
        local maxQ = self.GRID_SIZE
        if roundedR % 2 == 0 then
            maxQ = self.GRID_SIZE + 1 -- Extra cell on even rows
        end
        
        if roundedQ < maxQ then
            return {roundedQ, roundedR}
        end
    end
    return nil
end

-- Helper function for hex coordinate conversion - converts axial (q,r) to cube (x,y,z)
function Combat:axialToCube(q, r)
    local x = q
    local z = r
    local y = -x - z  -- In cube coordinates: x + y + z = 0
    return x, y, z
end

-- Helper function for hex coordinate conversion - converts cube (x,y,z) to axial (q,r)
function Combat:cubeToAxial(x, y, z)
    local q = x
    local r = z
    return q, r
end

-- Helper function for rounding hex coordinates
function Combat:roundCube(x, y, z)
    local rx = math.round(x)
    local ry = math.round(y)
    local rz = math.round(z)
    
    local xDiff = math.abs(rx - x)
    local yDiff = math.abs(ry - y)
    local zDiff = math.abs(rz - z)
    
    if xDiff > yDiff and xDiff > zDiff then
        rx = -ry - rz
    elseif yDiff > zDiff then
        ry = -rx - rz
    else
        rz = -rx - ry
    end
    
    return rx, ry, rz
end

-- Helper function for rounding
function math.round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
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

-- Calculate direction vector between two hexes (for collision handling)
function Combat:calculateDirectionVector(startQ, startR, endQ, endR)
    -- Convert to cube coordinates
    local startX, startY, startZ = self:offsetToCube(startQ, startR)
    local endX, endY, endZ = self:offsetToCube(endQ, endR)
    
    -- Calculate vector
    local distance = self:hexDistance(startQ, startR, endQ, endR)
    if distance == 0 then
        return {q = 0, r = 0}
    end
    
    -- Normalized direction vector
    local dirQ = (endQ - startQ) / distance
    local dirR = (endR - startR) / distance
    
    return {q = dirQ, r = dirR}
end

-- Replenish a ship's resources (SP and CP) at the start of a turn
function Combat:replenishResources(ship)
    -- Replenish Sail Points to maximum
    ship.currentSP = ship.maxSP
    
    -- Replenish Crew Points to maximum if applicable
    if ship.currentCP then
        ship.currentCP = ship.maxCP
    end
    
    print("Replenished resources for " .. ship.class .. " ship")
end

-- Start a new turn
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
    
    -- Calculate valid moves for player's ship for the new turn
    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
    self.validMoves = self:calculateValidMoves_SP(battle, battle.playerShip)
    print("Starting new turn " .. battle.turnCount .. " with " .. #self.validMoves .. " valid moves")
end

-- Initialize a new combat battle
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
    
    -- Create battle state
    local battle = {
        grid = grid,
        playerShip = {
            class = playerShipClass,
            size = self.shipDefinitions[playerShipClass].hexSize,
            position = {2, 8}, -- Bottom-left area
            orientation = 0,   -- North-facing to start
            currentSP = self:getMaxSP(playerShipClass),
            maxSP = self:getMaxSP(playerShipClass),
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        enemyShip = {
            class = enemyShipClass or "sloop", -- Default to sloop if not specified
            size = self.shipDefinitions[enemyShipClass or "sloop"].hexSize,
            position = {9, 3}, -- Top-right area
            orientation = 3,   -- South-facing to start
            currentSP = self:getMaxSP(enemyShipClass or "sloop"),
            maxSP = self:getMaxSP(enemyShipClass or "sloop"),
            plannedMove = nil,
            plannedRotation = nil
        },
        phase = "playerMovePlanning", -- Updated to new phase system
        actionResult = nil,    -- Stores result of the last action
        turnCount = 1          -- Track number of turns
    }
    
    -- Place ships on the grid
    self:placeShipOnGrid(battle.grid, battle.playerShip, battle)
    self:placeShipOnGrid(battle.grid, battle.enemyShip, battle)
    
    -- Note: gameState.combat reference should be set by the caller (startBattle)
    -- We don't set gameState.combat here to avoid duplication
    
    -- Process initial enemy planning for first turn
    self:processEnemyPlanning(battle)
    
    -- Always set up initial valid moves for player (regardless of phase)
    print("Calculating initial valid moves for player ship using SP system")
    self.validMoves = {}
    self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
    self.validMoves = self:calculateValidMoves_SP(battle, battle.playerShip)
    print("Initial calculation found " .. #self.validMoves .. " valid moves")
    
    print("New naval battle initialized: " .. playerShipClass .. " vs " .. (enemyShipClass or "sloop"))
    return battle
end

-- Create an empty hex grid with extra cells on odd rows for symmetry
function Combat:createEmptyGrid()
    local grid = {}
    
    -- Initialize grid with an extra cell on odd rows
    for q = 0, self.GRID_SIZE + 1 do -- +1 to ensure we have space for the extra cells
        grid[q] = {}
        for r = 0, self.GRID_SIZE - 1 do
            -- Determine if this cell exists in our odd-row-extended grid
            local validCell = true
            
            -- Skip cells that are beyond the row width
            if (r % 2 == 1 and q >= self.GRID_SIZE) or 
               (r % 2 == 0 and q >= self.GRID_SIZE + 1) then
                validCell = false
            end
            
            if validCell then
                grid[q][r] = {
                    content = "empty",
                    isPlayerShip = false,
                    isEnemyShip = false,
                    ship = nil
                }
            end
        end
    end
    return grid
end

-- Process enemy AI planning
function Combat:processEnemyPlanning(battle)
    print("Processing enemy planning")
    -- Simple implementation - plan a move and rotation
    self:planEnemyManeuver(battle)
    return true
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

-- Draw a ship sprite on the grid
function Combat:drawShip(battle, ship)
    local q, r = ship.position[1], ship.position[2]
    local x, y = self:hexToScreen(q, r)
    
    -- Determine which ship sprite to use
    local spritePath = nil
    if ship.class == "sloop" then
        spritePath = "assets/sloop-top-down.png"
    elseif ship.class == "brigantine" then
        spritePath = "assets/brigantine-top-down.png"
    else
        -- Fallback to default sprite
        spritePath = "assets/sloop-top-down.png"
    end
    
    -- Calculate rotation angle - 60 degrees per orientation unit
    -- Adding pi/6 (30 degrees) to make ships face flat sides instead of points
    local angle = ship.orientation * math.pi / 3 + math.pi / 6
    
    -- No color tint - preserve original sprite appearance
    love.graphics.setColor(1, 1, 1, 1) -- Full white (no tint)
    
    -- Load and draw ship sprite
    local sprite = self.assetUtils.loadImage(spritePath, "ship")
    if sprite then
        -- Display at full size
        local scale = 1.0
        
        love.graphics.draw(
            sprite,
            x, y,   -- Position
            angle,  -- Rotation
            scale, scale, -- Scale at 1.0 (full size)
            sprite:getWidth() / 2, sprite:getHeight() / 2 -- Origin at center
        )
    else
        -- Fallback if sprite not loaded - draw a simple shape
        love.graphics.circle("fill", x, y, self.HEX_RADIUS * 0.7) -- Increased size
        
        -- Draw a line indicating orientation
        local lineLength = self.HEX_RADIUS * 0.8
        love.graphics.setLineWidth(3) -- Thicker line for better visibility
        love.graphics.line(
            x, y,
            x + math.cos(angle) * lineLength,
            y + math.sin(angle) * lineLength
        )
        love.graphics.setLineWidth(1)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw ship name and health with improved visibility
    -- Draw shadow for better readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf(ship.class:upper(), x - 41, y + self.HEX_RADIUS + 6, 80, "center")
    
    -- Draw ship name
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf(ship.class:upper(), x - 40, y + self.HEX_RADIUS + 5, 80, "center")
    
    -- Draw shadow for SP indicator
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.printf("SP: " .. ship.currentSP .. "/" .. ship.maxSP, 
                      x - 41, y + self.HEX_RADIUS + 21, 80, "center")
    
    -- Draw SP indicator
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("SP: " .. ship.currentSP .. "/" .. ship.maxSP, 
                      x - 40, y + self.HEX_RADIUS + 20, 80, "center")
end

-- Convert hex coordinates to screen coordinates
function Combat:hexToScreen(q, r)
    -- For pointy-top hexagons (axial coordinate system)
    local size = self.HEX_RADIUS
    local hexWidth = size * math.sqrt(3)
    
    -- Calculate grid dimensions in hexes and pixels
    local gridCols = self.GRID_SIZE + 0.5  -- Add 0.5 to account for odd row extensions
    local gridRows = self.GRID_SIZE
    
    -- Calculate the total width and height of the hex grid
    local totalGridWidthPixels = gridCols * hexWidth  -- Just the hexes
    local totalGridHeightPixels = gridRows * size * 1.5 + size * 0.5  -- Height with padding
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate the top-left corner of the grid to center it in the screen
    local gridStartX = (screenWidth - totalGridWidthPixels) / 2
    local gridStartY = (screenHeight - totalGridHeightPixels) / 2 - 30  -- Same offset as background
    
    -- Calculate hex center position with odd-row offset
    local x = gridStartX + (q * hexWidth) + ((r % 2) * hexWidth / 2)
    local y = gridStartY + (r * size * 1.5)
    
    return x, y
end

-- Draw the rectangular area containing the hex grid
function Combat:drawGridArea()
    -- For pointy-top hexagons (axial coordinate system)
    local size = self.HEX_RADIUS
    local hexWidth = size * math.sqrt(3)
    
    -- Calculate grid dimensions in hexes and pixels
    local gridCols = self.GRID_SIZE + 0.5  -- Add 0.5 to account for odd row extensions
    local gridRows = self.GRID_SIZE
    
    -- Calculate the total width and height of the hex grid
    local totalGridWidthPixels = gridCols * hexWidth  -- Just the hexes
    local totalGridHeightPixels = gridRows * size * 1.5 + size * 0.5  -- Height with padding
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Add padding around the grid
    local padding = size * 1.5
    local gridWidthInPixels = totalGridWidthPixels + padding * 2
    local gridHeightInPixels = totalGridHeightPixels + padding * 2
    
    -- Calculate the top-left corner of the grid with padding
    local gridX = (screenWidth - totalGridWidthPixels) / 2 - padding
    local gridY = (screenHeight - totalGridHeightPixels) / 2 - 30 - padding  -- Same offset as hexes
    
    -- Draw a background rectangle for the grid area
    love.graphics.setColor(0.1, 0.1, 0.3, 0.5) -- Dark blue background
    
    -- Store the grid area for collision detection
    self.gridArea = {
        x = gridX,
        y = gridY,
        width = gridWidthInPixels,
        height = gridHeightInPixels
    }
    
    -- Draw the rectangle
    love.graphics.rectangle(
        "fill", 
        gridX, 
        gridY, 
        gridWidthInPixels, 
        gridHeightInPixels,
        8, 8 -- Slightly larger rounded corners
    )
end

-- Check if cursor is within the grid area
function Combat:isPointInGridArea(x, y)
    return self.gridArea and self:isPointInRect(x, y, self.gridArea)
end

-- Draw the combat user interface
function Combat:draw(gameState)
    if not gameState.combat then return end
    
    local battle = gameState.combat
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate control panel position at bottom
    local panelHeight = 100
    local buttonsY = screenHeight - panelHeight
    
    -- Draw the grid area background
    self:drawGridArea()
    
    -- Draw grid hexes
    self:drawHexes(battle, gameState.settings.debug)
    
    -- Draw ships
    self:drawShip(battle, battle.playerShip)
    self:drawShip(battle, battle.enemyShip)
    
    -- Draw UI based on current phase
    if battle.phase == "playerMovePlanning" then
        -- Draw maneuver planning UI
        self:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
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
        self.validMoves = self:calculateValidMoves_SP(gameState.combat, gameState.combat.playerShip)
        print("Auto-selected player ship in mousemoved, found " .. #self.validMoves .. " valid moves")
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

-- Start a new battle with specified enemy ship
function Combat:startBattle(gameState, enemyShipClass)
    print("Starting new battle against " .. (enemyShipClass or "sloop"))
    
    -- Enter combat mode
    gameState.settings.combatMode = true
    
    -- Initialize battle state
    local battle = self:initBattle(gameState, enemyShipClass)
    
    -- Store battle in gameState
    gameState.combat = battle
    
    -- Additional setup if needed
    -- You might want to add music/sound effects here
    
    print("Battle started: " .. gameState.ship.class .. " vs " .. (enemyShipClass or "sloop"))
    return battle
end

-- End the current battle and return to the world map
function Combat:endBattle(gameState)
    print("Ending combat battle")
    gameState.settings.combatMode = false
    gameState.combat = nil
    
    -- Reset combat state
    self.selectedHex = nil
    self.hoveredHex = nil
    self.validMoves = {}
    self.plannedMoveHex = nil
    self.plannedRotation = nil
    self.rotationButtons = nil
    self.confirmManeuverButton = nil
    
    print("Combat ended, returning to world map")
end

-- Load function to initialize the combat system
function Combat:load(gameState)
    print("Initializing combat system")
    
    -- Load other modules
    self.Constants = require('constants')
    self.assetUtils = require('utils.assetUtils')
    self.shipUtils = require('utils.shipUtils')
    
    -- Set up color references for easier access
    self.COLORS = {
        PLAYER_SHIP = self.Constants.COLORS.PLAYER_SHIP,
        ENEMY_SHIP = self.Constants.COLORS.ENEMY_SHIP,
        HOVER = self.Constants.COLORS.HOVER,
        SELECTED = self.Constants.COLORS.SELECTED,
        VALID_MOVE = {0.2, 0.6, 0.8, 0.4}, -- Light blue for valid moves
        EMPTY_WATER = {0.2, 0.3, 0.8, 0.3} -- Blue for empty water
    }
    
    -- Set up combat constants
    self.COMBAT = self.Constants.COMBAT
    
    -- Use hex radius from constants if available
    if self.Constants.UI and self.Constants.UI.COMBAT and self.Constants.UI.COMBAT.HEX_RADIUS then
        self.HEX_RADIUS = self.Constants.UI.COMBAT.HEX_RADIUS
        print("Using hex radius from constants: " .. self.HEX_RADIUS)
    end
    
    -- Use grid size from constants if available
    if self.Constants.COMBAT and self.Constants.COMBAT.GRID_SIZE then
        self.GRID_SIZE = self.Constants.COMBAT.GRID_SIZE
        print("Using grid size from constants: " .. self.GRID_SIZE)
    end
    
    -- Calculate the grid center position based on screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Set the grid center to the center of the screen, adjusted for controls
    self.GRID_CENTER_X = screenWidth / 2
    self.GRID_CENTER_Y = (screenHeight / 2) - 30  -- Move up slightly to make room for controls
    
    print("Setting grid center to: " .. self.GRID_CENTER_X .. ", " .. self.GRID_CENTER_Y)
    
    -- Initialize internal state
    self.selectedHex = nil
    self.hoveredHex = nil
    self.validMoves = {}
    self.plannedMoveHex = nil
    self.plannedRotation = nil
    self.rotationButtons = nil
    self.confirmManeuverButton = nil
    
    print("Combat system initialized")
end

-- Update function for combat system
function Combat:update(dt, gameState)
    if not gameState.combat then return end
    
    -- Update any animations or time-based effects
    
    -- Handle any AI decisions for enemy ships
    
    -- Update any visual effects
    
    -- Debug: Auto-select player ship if not already selected
    if gameState.combat.phase == "playerMovePlanning" and not self.selectedHex and gameState.combat.playerShip then
        self.selectedHex = {gameState.combat.playerShip.position[1], gameState.combat.playerShip.position[2]}
        if #self.validMoves == 0 then
            self.validMoves = self:calculateValidMoves_SP(gameState.combat, gameState.combat.playerShip)
        end
    end
end

-- Return the module
return Combat