-- Combat module for naval combat
local Constants = require("constants")

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
            cannon = 2,
            firingArcs = {     -- Define which arcs can be targeted
                forward = true,  -- Can fire forward (orientation 0)
                sides = false,   -- Cannot fire to sides (orientations 1,2,4,5)
                rear = false     -- Cannot fire to rear (orientation 3)
            },
            firingRange = 4    -- Maximum firing range in hexes
        },
        brigantine = {
            name = "Brigantine",
            hexSize = 2,
            shape = {{0, 0}, {1, 0}},  -- Two hexes in a row (will be rotated based on orientation)
            maxHP = 10,
            speed = 2,
            cannon = 4,
            firingArcs = {
                forward = false,  -- Cannot fire forward
                sides = true,     -- Can fire to sides (broadsides)
                rear = false      -- Cannot fire to rear
            },
            firingRange = 4    -- Maximum firing range in hexes
        },
        galleon = {
            name = "Galleon", 
            hexSize = 4,
            shape = {{0, 0}, {1, 0}, {0, 1}, {1, 1}},  -- Kite shape (2x2)
            maxHP = 40,
            speed = 1,
            cannon = 6,
            firingArcs = {
                forward = false,  -- Cannot fire forward 
                sides = true,     -- Can fire to sides (broadsides)
                rear = false      -- Cannot fire to rear
            },
            firingRange = 5    -- Maximum firing range in hexes
        }
    }
}

-- Draw the maneuver planning controls
function Combat:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
    local buttonSpacing = 20
    local buttonWidth = 120
    local buttonHeight = 30
    
    -- Draw planned maneuver visualization if applicable
    if self.plannedMoveHex then
        -- Draw a path from current position to planned position
        local startQ, startR = battle.playerShip.position[1], battle.playerShip.position[2]
        local endQ, endR = self.plannedMoveHex[1], self.plannedMoveHex[2]
        
        -- Skip if start and end are the same (rotating in place)
        if not (startQ == endQ and startR == endR) then
            -- Calculate and draw the path
            local path = self:calculatePath(startQ, startR, endQ, endR)
            
            -- Draw path with dotted/dashed appearance for planning
            for i = 1, #path - 1 do
                local q1, r1 = path[i][1], path[i][2]
                local q2, r2 = path[i+1][1], path[i+1][2]
                
                local x1, y1 = self:hexToScreen(q1, r1)
                local x2, y2 = self:hexToScreen(q2, r2)
                
                -- Use a cyan color for planned movement path
                love.graphics.setColor(0.2, 0.8, 0.8, 0.8)
                
                -- Draw dashed line (alternate segments)
                local dashLength = 5
                local gapLength = 3
                local dx, dy = x2 - x1, y2 - y1
                local length = math.sqrt(dx * dx + dy * dy)
                local unitX, unitY = dx / length, dy / length
                
                -- Set line width for better visibility
                love.graphics.setLineWidth(2)
                
                -- Draw dashed segments
                local pos = 0
                while pos < length do
                    local segmentEnd = math.min(pos + dashLength, length)
                    local startX = x1 + unitX * pos
                    local startY = y1 + unitY * pos
                    local endX = x1 + unitX * segmentEnd
                    local endY = y1 + unitY * segmentEnd
                    
                    love.graphics.line(startX, startY, endX, endY)
                    
                    pos = pos + dashLength + gapLength
                end
                
                -- Reset line width
                love.graphics.setLineWidth(1)
            end
        end
    end
    
    -- Show planned final orientation if set
    if self.plannedMoveHex and self.plannedRotation ~= nil then
        -- Draw a ghost ship at the planned position and orientation
        local x, y = self:hexToScreen(self.plannedMoveHex[1], self.plannedMoveHex[2])
        
        -- Draw an orientation indicator (arrow)
        -- In the hex grid, orientations are:
        -- 0 = North (pointing to the top of the screen)
        -- 1 = Northeast
        -- 2 = Southeast
        -- 3 = South
        -- 4 = Southwest
        -- 5 = Northwest
        
        -- For proper arrow alignment, we convert to radians
        -- where 0 = East and increases counterclockwise
        
        -- Convert hex orientation directly to radians
        -- Starting with North (0 in hex = π/2 in radians)
        -- and moving clockwise in 60° (π/3) increments
        -- Subtract a half-unit (30°) rotation to point at sides instead of vertices
        local angle = math.pi/2 - (self.plannedRotation * math.pi/3) - math.pi/6
        
        -- Making sure angle is in [0, 2π)
        angle = angle % (2 * math.pi)
        
        -- Make arrow more prominent
        local arrowLength = self.HEX_RADIUS * 0.9
        local arrowWidth = self.HEX_RADIUS * 0.4
        
        -- Add visual pulsing effect
        local time = love.timer.getTime()
        local pulse = math.abs(math.sin(time * 2)) * 0.3 + 0.7 -- 0.7 to 1.0 pulsing
        
        -- Calculate arrow points
        local tipX = x + math.cos(angle) * arrowLength * pulse
        local tipY = y - math.sin(angle) * arrowLength * pulse
        
        -- Calculate perpendicular direction for arrow head
        local perpX = math.cos(angle + math.pi/2)
        local perpY = -math.sin(angle + math.pi/2)
        
        -- Calculate arrow head points
        local headLeftX = tipX - math.cos(angle) * arrowWidth + perpX * arrowWidth
        local headLeftY = tipY + math.sin(angle) * arrowWidth + perpY * arrowWidth
        local headRightX = tipX - math.cos(angle) * arrowWidth - perpX * arrowWidth
        local headRightY = tipY + math.sin(angle) * arrowWidth - perpY * arrowWidth
        
        -- Draw filled arrow for better visibility
        love.graphics.setColor(0.2, 0.9, 0.2, 0.6) -- Semi-transparent green
        
        -- Draw arrow as a filled triangle
        love.graphics.polygon("fill", 
            x, y, -- Base center
            headLeftX, headLeftY, -- Left point
            tipX, tipY, -- Tip
            headRightX, headRightY -- Right point
        )
        
        -- Draw outline
        love.graphics.setColor(0.2, 1.0, 0.2, 0.8) -- Brighter green
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", 
            x, y, -- Base center
            headLeftX, headLeftY, -- Left point
            tipX, tipY, -- Tip
            headRightX, headRightY -- Right point
        )
        
        -- Reset line width
        love.graphics.setLineWidth(1)
    end
    
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
                
                -- Plan enemy maneuver BEFORE advancing to resolution phase
                print("Planning enemy maneuver before resolution")
                self:planEnemyManeuver(battle)
                
                if not battle.enemyShip.plannedMove or not battle.enemyShip.plannedRotation then
                    print("ERROR: Enemy maneuver planning failed!")
                else
                    print("Enemy maneuver planned: move to " .. 
                          battle.enemyShip.plannedMove[1] .. "," .. battle.enemyShip.plannedMove[2] .. 
                          " and rotate to " .. battle.enemyShip.plannedRotation)
                end
                
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
        -- Action planning phase
        print("Processing action planning click at " .. x .. "," .. y)
        
        -- Check if we're clicking action menu buttons
        if self.actionMenuButtons then
            for actionName, button in pairs(self.actionMenuButtons) do
                if self:isPointInRect(x, y, button) then
                    -- Check if this action requires a target (like firing cannons)
                    if actionName == "fireCannons" then
                        -- Start aiming mode - will need to select a target hex
                        battle.actionInProgress = "fireCannons"
                        print("Starting aim mode for fire cannons")
                        return true
                    elseif actionName == "evade" then
                        -- Evade doesn't need a target, can go straight to confirmation
                        battle.confirmingAction = "evade"
                        print("Confirming evade action")
                        return true
                    elseif actionName == "repair" then
                        -- Repair doesn't need a target, can go straight to confirmation
                        battle.confirmingAction = "repair"
                        print("Confirming repair action")
                        return true
                    elseif actionName == "endTurn" then
                        -- End turn immediately advances to the next phase
                        self:advanceToNextPhase(battle)
                        print("Ending turn")
                        return true
                    end
                end
            end
        end
        
        -- Check if we're in the targeting mode for an action that requires aiming
        if battle.actionInProgress == "fireCannons" then
            -- Get the hex that was clicked
            local clickedHex = self:getHexFromScreen(x, y)
            if clickedHex then
                local q, r = clickedHex[1], clickedHex[2]
                print("Clicked hex while aiming: " .. q .. "," .. r)
                
                -- Check if this hex is within firing arc
                if self:isInFiringArc(battle, battle.playerShip, q, r) then
                    -- Valid target - store it and move to confirmation
                    battle.actionInProgress = nil
                    battle.confirmingAction = "fireCannons"
                    battle.targetHex = {q, r}
                    print("Target in arc, proceeding to confirmation")
                    return true
                else
                    -- Not in firing arc - show feedback
                    print("Target not in firing arc")
                    battle.actionFeedback = "Target not in firing arc"
                    return true
                end
            end
        end
        
        -- Check if we're clicking confirmation window buttons
        if battle.confirmingAction and self.confirmationButtons then
            for buttonName, button in pairs(self.confirmationButtons) do
                if self:isPointInRect(x, y, button) then
                    if buttonName == "confirm" then
                        -- Execute the confirmed action
                        if battle.confirmingAction == "fireCannons" then
                            if battle.targetHex then
                                -- Execute fire cannons action with stored target
                                self:fireCannons(battle, battle.playerShip, battle.targetHex[1], battle.targetHex[2])
                                battle.confirmingAction = nil
                                battle.targetHex = nil
                                -- After action completes, advance to next phase
                                self:advanceToNextPhase(battle)
                                return true
                            end
                        elseif battle.confirmingAction == "evade" then
                            -- Execute evade action
                            self:performEvade(battle, battle.playerShip)
                            battle.confirmingAction = nil
                            -- After action completes, advance to next phase
                            self:advanceToNextPhase(battle)
                            return true
                        elseif battle.confirmingAction == "repair" then
                            -- Execute repair action
                            self:performRepair(battle, battle.playerShip)
                            battle.confirmingAction = nil
                            -- After action completes, advance to next phase
                            self:advanceToNextPhase(battle)
                            return true
                        end
                    elseif buttonName == "cancel" then
                        -- Cancel the current action
                        battle.confirmingAction = nil
                        battle.targetHex = nil
                        battle.actionInProgress = nil
                        return true
                    end
                end
            end
        end
    elseif battle.phase == "displayingResult" then
        -- Dismiss results and proceed to next phase
        self:advanceToNextPhase(battle)
    end
end

-- Plan a maneuver for the enemy ship
function Combat:planEnemyManeuver(battle)
    print("Planning enemy maneuver with SP budget")
    
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Calculate distance to player ship
    local distanceToPlayer = self:hexDistance(
        enemyShip.position[1], enemyShip.position[2],
        playerShip.position[1], playerShip.position[2]
    )
    
    print("Current distance to player: " .. distanceToPlayer)
    print("Enemy SP available: " .. enemyShip.currentSP)
    
    -- Calculate valid moves for the enemy
    local validMoves = self:calculateValidMoves_SP(battle, enemyShip)
    print("Enemy has " .. #validMoves .. " possible moves")
    
    -- Debug - print all valid moves
    for i, move in ipairs(validMoves) do
        print("Valid move " .. i .. ": " .. move[1] .. "," .. move[2])
    end
    
    -- Default: Stay in place (with rotation potentially)
    local chosenMove = {enemyShip.position[1], enemyShip.position[2]}
    
    -- Create a prioritized list of potential maneuvers (move + rotation)
    local potentialManeuvers = {}
    
    -- For each valid move hex, calculate potential maneuvers
    if #validMoves > 0 then
        -- Force the enemy to prefer movement over staying in place
        -- Only consider staying in place as a last resort
        
        -- Consider all other move options with rotation
        for _, move in ipairs(validMoves) do
            -- Calculate best orientation from this hex toward player
            local targetOrientation = self:calculateOrientationToward(
                move[1], move[2],
                playerShip.position[1], playerShip.position[2]
            )
            
            -- Calculate maneuver cost
            local maneuverCost = self:calculateSPCost(
                enemyShip, 
                move[1], move[2], 
                targetOrientation
            )
            
            -- Skip if not affordable
            if maneuverCost <= enemyShip.currentSP then
                -- Calculate move's distance to player
                local moveDistance = self:hexDistance(move[1], move[2], playerShip.position[1], playerShip.position[2])
                
                -- Set score based on strategy - higher score is better
                local score = 0
                
                if distanceToPlayer <= 2 then
                    -- Kiting strategy: prefer moves farther from player
                    score = (moveDistance * 3) - maneuverCost
                else
                    -- Engagement strategy: prefer moves closer to player
                    score = (-moveDistance * 3) - maneuverCost
                end
                
                -- Add a move preference bonus to prioritize movement over staying in place
                local moveBonus = 0
                if move[1] ~= enemyShip.position[1] or move[2] ~= enemyShip.position[2] then
                    moveBonus = 5 -- Significant bonus for moving vs staying still
                end
                
                score = score + moveBonus
                
                table.insert(potentialManeuvers, {
                    move = move,
                    rotation = targetOrientation,
                    cost = maneuverCost,
                    score = score,
                    distance = moveDistance,
                    isStayingInPlace = (move[1] == enemyShip.position[1] and move[2] == enemyShip.position[2])
                })
            end
        end
        
        -- If no movement maneuvers were affordable, consider staying in place with rotation
        if #potentialManeuvers == 0 then
            local stayInPlaceOrientation = self:calculateOrientationToward(
                enemyShip.position[1], enemyShip.position[2],
                playerShip.position[1], playerShip.position[2]
            )
            
            local stayInPlaceCost = self:calculateSPCost(
                enemyShip, 
                nil, nil, -- No movement
                stayInPlaceOrientation
            )
            
            -- Only add if affordable
            if stayInPlaceCost <= enemyShip.currentSP then
                table.insert(potentialManeuvers, {
                    move = {enemyShip.position[1], enemyShip.position[2]},
                    rotation = stayInPlaceOrientation,
                    cost = stayInPlaceCost,
                    score = -100, -- Very low score, only used as fallback
                    distance = distanceToPlayer,
                    isStayingInPlace = true
                })
            end
        end
    end
    
    -- Sort maneuvers by score (highest first)
    table.sort(potentialManeuvers, function(a, b) return a.score > b.score end)
    
    -- Print maneuver options for debugging
    print("Enemy has " .. #potentialManeuvers .. " potential maneuvers:")
    for i, maneuver in ipairs(potentialManeuvers) do
        local moveDesc = maneuver.isStayingInPlace and "Stay at " or "Move to "
        print(i .. ": " .. moveDesc .. maneuver.move[1] .. "," .. maneuver.move[2] .. 
              " (rot: " .. maneuver.rotation .. ", cost: " .. maneuver.cost .. 
              ", dist: " .. maneuver.distance .. ", score: " .. maneuver.score .. ")")
    end
    
    -- Choose the highest-scoring affordable maneuver
    local chosenManeuver = potentialManeuvers[1]
    
    -- If we have a valid maneuver, use it
    if chosenManeuver then
        chosenMove = chosenManeuver.move
        local targetOrientation = chosenManeuver.rotation
        
        -- Set enemy's planned move and rotation
        enemyShip.plannedMove = chosenMove
        enemyShip.plannedRotation = targetOrientation
        
        local moveType = chosenManeuver.isStayingInPlace and "staying at" or "moving to"
        print("Enemy chose maneuver: " .. moveType .. " " .. chosenMove[1] .. "," .. chosenMove[2] .. 
              " with orientation " .. targetOrientation .. " (Cost: " .. chosenManeuver.cost .. 
              " SP, Score: " .. chosenManeuver.score .. ")")
    else
        -- Extreme fallback: do nothing
        enemyShip.plannedMove = {enemyShip.position[1], enemyShip.position[2]}
        enemyShip.plannedRotation = enemyShip.orientation
        print("Enemy can't afford any maneuvers, staying still with current orientation")
    end
    
    -- Confirm we've set planned values correctly
    print("FINAL PLAN: Enemy will move from " .. enemyShip.position[1] .. "," .. enemyShip.position[2] .. 
          " to " .. enemyShip.plannedMove[1] .. "," .. enemyShip.plannedMove[2] .. 
          " and rotate from " .. enemyShip.orientation .. " to " .. enemyShip.plannedRotation)
    
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
        
        -- Do NOT immediately process the maneuver resolution
        -- The update function will handle it in the next frame
        -- This ensures both ships are properly animated
        print("Transitioning to maneuver resolution phase - animation will be set up in update")
        
    elseif battle.phase == "maneuverResolution" then
        -- Clear any animation-related variables
        battle.maneuverAnimationTimer = nil
        battle.maneuverAnimationComplete = nil
        battle.playerShip.animationStart = nil
        battle.playerShip.animationEnd = nil
        battle.enemyShip.animationStart = nil
        battle.enemyShip.animationEnd = nil
        
        -- After maneuvers resolve, advance to player action planning
        battle.phase = "playerActionPlanning"
        
    elseif battle.phase == "playerActionPlanning" then
        -- After player plans actions, advance to action resolution
        battle.phase = "actionResolution"
        
    elseif battle.phase == "actionResolution" then
        -- After player action resolves, check if enemy has a planned action
        if battle.enemyShip.plannedAction and battle.enemyShip.plannedAction ~= "none" then
            -- Execute enemy's planned action
            print("Executing enemy planned action: " .. battle.enemyShip.plannedAction)
            
            if battle.enemyShip.plannedAction == "fireCannons" then
                -- Check if player is still in enemy firing arc (position may have changed)
                local playerQ, playerR = battle.playerShip.position[1], battle.playerShip.position[2]
                
                -- Check if player is in firing arc
                if self:isInFiringArc(battle, battle.enemyShip, playerQ, playerR) then
                    -- Fire cannons at player ship
                    self:fireCannons(battle, battle.enemyShip, playerQ, playerR)
                else
                    print("Player no longer in enemy firing arc, skipping enemy attack")
                    -- Enemy chose fireCannons but player is no longer in arc - action fails
                    battle.actionResult = {
                        action = "fireCannons",
                        ship = "enemy",
                        failed = true,
                        failReason = "Target not in firing arc"
                    }
                end
            elseif battle.enemyShip.plannedAction == "evade" then
                -- Execute enemy evade action
                self:performEvade(battle, battle.enemyShip)
            elseif battle.enemyShip.plannedAction == "repair" then
                -- Execute enemy repair action
                self:performRepair(battle, battle.enemyShip)
            end
            
            -- Reset enemy's planned action
            battle.enemyShip.plannedAction = nil
        end
        
        -- After action resolution, show results
        battle.phase = "displayingResult"
        
    elseif battle.phase == "displayingResult" then
        -- Clear action feedback
        battle.actionFeedback = nil
        
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
    local validMoves = {} -- Local list for storing moves, not modifying self.validMoves for AI
    
    -- Get the ship's current position and SP
    local shipQ, shipR = ship.position[1], ship.position[2]
    local availableSP = ship.currentSP
    
    print("Calculating valid moves for " .. ship.class .. " ship at " .. 
          shipQ .. "," .. shipR .. " with " .. availableSP .. " SP")
    
    -- Each SP allows moving 1 hex, so the maximum distance we can move is equal to availableSP
    local maxDistance = availableSP
    
    -- Also include the current position as a valid "move" (for rotation-only maneuvers)
    table.insert(validMoves, {shipQ, shipR})
    print("Added current position as valid move (for rotation): " .. shipQ .. "," .. shipR)
    
    -- Loop through all grid cells within maxDistance
    for q = math.max(0, shipQ - maxDistance), math.min(self.GRID_SIZE - 1, shipQ + maxDistance) do
        for r = math.max(0, shipR - maxDistance), math.min(self.GRID_SIZE - 1, shipR + maxDistance) do
            -- Skip the ship's current position (already added above)
            if q ~= shipQ or r ~= shipR then
                -- Calculate distance between ship and this hex
                local distance = self:hexDistance(shipQ, shipR, q, r)
                
                -- Check if within movement range
                if distance <= maxDistance then
                    -- Check if the hex is empty (no ships)
                    if battle.grid[q] and battle.grid[q][r] and 
                       not (battle.grid[q][r].isPlayerShip or battle.grid[q][r].isEnemyShip) then
                        -- This is a valid move destination, add it to valid moves
                        table.insert(validMoves, {q, r})
                        print("Added valid move: " .. q .. "," .. r .. " (distance: " .. distance .. ")")
                    else
                        if battle.grid[q] and battle.grid[q][r] then
                            if battle.grid[q][r].isPlayerShip then
                                print("Hex " .. q .. "," .. r .. " occupied by player ship")
                            elseif battle.grid[q][r].isEnemyShip then
                                print("Hex " .. q .. "," .. r .. " occupied by enemy ship")
                            else
                                print("Hex " .. q .. "," .. r .. " occupied by unknown entity")
                            end
                        else
                            print("Hex " .. q .. "," .. r .. " is out of grid bounds")
                        end
                    end
                else
                    print("Hex " .. q .. "," .. r .. " too far (distance: " .. distance .. ")")
                end
            end
        end
    end
    
    -- If no valid moves beyond the current position, try adjacent hexes
    if #validMoves <= 1 then
        print("Very few valid moves found - checking adjacent directions")
        
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
                if battle.grid[newQ] and battle.grid[newQ][newR] and 
                   not (battle.grid[newQ][newR].isPlayerShip or battle.grid[newQ][newR].isEnemyShip) then
                    -- Check if this move is already in our list
                    local isDuplicate = false
                    for _, move in ipairs(validMoves) do
                        if move[1] == newQ and move[2] == newR then
                            isDuplicate = true
                            break
                        end
                    end
                    
                    if not isDuplicate then
                        table.insert(validMoves, {newQ, newR})
                        print("Added adjacent move: " .. newQ .. "," .. newR)
                    end
                end
            end
        end
    end
    
    -- Print debug summary
    print("Calculated " .. #validMoves .. " valid moves for " .. ship.class .. 
          " ship with " .. availableSP .. " SP")
    
    -- If this is for the player ship, also update self.validMoves
    if ship == battle.playerShip then
        self.validMoves = validMoves
    end
    
    return validMoves
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
    -- Default values based on ship class and RevisedCombatSystem.md
    local defaultValues = {
        sloop = 5,      -- More maneuverable
        brigantine = 4, -- Medium maneuverability
        galleon = 3     -- Least maneuverable
    }
    
    local result = defaultValues[shipClass] or 4  -- Default fallback
    print("Getting maxSP for " .. tostring(shipClass) .. ": " .. result)
    return result
end

-- Get maximum CP for player ship (based on crew count)
function Combat:getMaxCP(shipClass, gameState)
    if not shipClass then
        -- Default to sloop if class is invalid
        shipClass = "sloop"
    end
    
    -- Player's CP is based on crew count, capped by ship capacity
    local baseCP = self:getBaseCP(shipClass)
    
    -- If we have crew data, use actual crew count
    if gameState and gameState.crew and gameState.crew.members then
        return math.min(#gameState.crew.members, baseCP)
    else
        -- Fallback to base values if no crew data
        return baseCP
    end
end

-- Get base CP for a ship class (used for enemy ships or as player cap)
function Combat:getBaseCP(shipClass)
    if not shipClass then
        -- Default to sloop if class is invalid
        shipClass = "sloop"
    end
    
    -- Base CP values by ship class
    local defaultValues = {
        sloop = 2,      -- Sloops have small crews
        brigantine = 4, -- Brigantines have medium crews
        galleon = 6     -- Galleons have large crews
    }
    
    local result = defaultValues[shipClass] or 2  -- Default fallback
    print("Getting baseCP for " .. tostring(shipClass) .. ": " .. result)
    return result
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
    
    -- 1. Update orientations immediately (internal state)
    battle.playerShip.orientation = playerTargetOrientation
    battle.enemyShip.orientation = enemyTargetOrientation
    
    print("Player rotated from " .. playerStartOrientation .. " to " .. playerTargetOrientation)
    print("Enemy rotated from " .. enemyStartOrientation .. " to " .. enemyTargetOrientation)
    
    -- 2. Check for collision at target destination
    local collision = false
    local playerFinalQ, playerFinalR = playerTargetQ, playerTargetR
    local enemyFinalQ, enemyFinalR = enemyTargetQ, enemyTargetR
    
    -- Simple collision detection: check if both ships want to move to the same hex
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
    
    -- Store the original planned destinations for animation
    battle.playerShip.animationStart = {
        q = playerStartQ,
        r = playerStartR,
        orientation = playerStartOrientation
    }
    
    battle.playerShip.animationEnd = {
        q = playerFinalQ,
        r = playerFinalR,
        orientation = playerTargetOrientation
    }
    
    battle.enemyShip.animationStart = {
        q = enemyStartQ,
        r = enemyStartR,
        orientation = enemyStartOrientation
    }
    
    battle.enemyShip.animationEnd = {
        q = enemyFinalQ,
        r = enemyFinalR,
        orientation = enemyTargetOrientation
    }
    
    -- Set up animation timer (shared between both ships)
    battle.maneuverAnimationTimer = 0
    battle.maneuverAnimationDuration = 0.8  -- Animation lasts 0.8 seconds
    battle.maneuverAnimationComplete = false
    
    -- 3. Calculate actual SP costs for the moves performed
    local playerActualCost = self:calculateSPCost(
        {position = {playerStartQ, playerStartR}, orientation = playerStartOrientation},
        playerFinalQ, playerFinalR, playerTargetOrientation
    )
    
    local enemyActualCost = self:calculateSPCost(
        {position = {enemyStartQ, enemyStartR}, orientation = enemyStartOrientation},
        enemyFinalQ, enemyFinalR, enemyTargetOrientation
    )
    
    -- 4. Deduct SP
    battle.playerShip.currentSP = math.max(0, battle.playerShip.currentSP - playerActualCost)
    battle.enemyShip.currentSP = math.max(0, battle.enemyShip.currentSP - enemyActualCost)
    
    print("Player spent " .. playerActualCost .. " SP (remaining: " .. battle.playerShip.currentSP .. ")")
    print("Enemy spent " .. enemyActualCost .. " SP (remaining: " .. battle.enemyShip.currentSP .. ")")
    
    -- 5. Remove ships from their old grid positions
    self:clearShipFromGrid(battle.grid, battle.playerShip)
    self:clearShipFromGrid(battle.grid, battle.enemyShip)
    
    -- 6. Update ship positions (immediately in game state, but visually will be animated)
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
    
    -- We'll advance to the next phase in update() once animation is complete
    
    return true
end

-- Update function for maneuver resolution animation
function Combat:updateManeuverResolution(dt, battle)
    if not battle.maneuverAnimationTimer then 
        -- Initialize animation if not already set up
        if battle.phase == "maneuverResolution" then
            print("Initializing maneuver animation")
            -- Process the resolution now, which will set up animation
            self:processManeuverResolution(battle)
        end
        return 
    end
    
    -- Update animation timer
    battle.maneuverAnimationTimer = battle.maneuverAnimationTimer + dt
    
    -- Calculate animation progress (0 to 1)
    local progress = math.min(1, battle.maneuverAnimationTimer / battle.maneuverAnimationDuration)
    
    -- Debugging
    if battle.maneuverAnimationTimer % 0.5 < 0.02 then -- Log every ~0.5 seconds
        print("Maneuver animation progress: " .. string.format("%.2f", progress * 100) .. "%")
        
        -- Debug enemy ship animation data
        if battle.enemyShip and battle.enemyShip.animationStart and battle.enemyShip.animationEnd then
            print("Enemy animation from: " .. battle.enemyShip.animationStart.q .. "," .. 
                  battle.enemyShip.animationStart.r .. " to " .. 
                  battle.enemyShip.animationEnd.q .. "," .. 
                  battle.enemyShip.animationEnd.r)
        else
            print("WARNING: Enemy animation data not properly set up")
        end
    end
    
    -- If animation just completed
    if progress >= 1 and not battle.maneuverAnimationComplete then
        battle.maneuverAnimationComplete = true
        print("Maneuver animation complete, advancing to next phase")
        
        -- Animation is done, advance to next phase
        self:advanceToNextPhase(battle)
    end
end

-- Draw the ship during maneuver animation
function Combat:drawShipDuringManeuver(battle, ship)
    -- Check if we're animating
    if not battle.maneuverAnimationTimer or not ship.animationStart or not ship.animationEnd then
        -- Just draw normally if not animating
        self:drawShip(battle, ship)
        return
    end
    
    -- Calculate animation progress (0 to 1)
    local progress = math.min(1, battle.maneuverAnimationTimer / battle.maneuverAnimationDuration)
    
    -- Calculate interpolated position
    local startQ, startR = ship.animationStart.q, ship.animationStart.r
    local endQ, endR = ship.animationEnd.q, ship.animationEnd.r
    
    -- Debug to make sure animation values are correct
    if progress < 0.1 then  -- Only log at the beginning of animation
        print("Animating " .. ship.class .. " from " .. startQ .. "," .. startR .. 
              " to " .. endQ .. "," .. endR .. " (progress: " .. progress .. ")")
    end
    
    -- Convert start and end positions to screen coordinates
    local startX, startY = self:hexToScreen(startQ, startR)
    local endX, endY = self:hexToScreen(endQ, endR)
    
    -- Interpolate position
    local x = startX + (endX - startX) * progress
    local y = startY + (endY - startY) * progress
    
    -- Calculate interpolated orientation (need to handle wrap-around from 5 to 0)
    local startOrientation = ship.animationStart.orientation
    local endOrientation = ship.animationEnd.orientation
    
    -- Handle wrap-around for shorter rotation path
    local diff = (endOrientation - startOrientation) % 6
    if diff > 3 then diff = diff - 6 end
    
    -- Interpolate orientation
    local currentOrientation = (startOrientation + diff * progress) % 6
    
    -- Store original orientation
    local originalOrientation = ship.orientation
    
    -- Temporarily set the ship's orientation for drawing
    ship.orientation = currentOrientation
    
    -- Draw the ship at the interpolated position
    local q, r = ship.position[1], ship.position[2]
    local originalX, originalY = self:hexToScreen(q, r)
    
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
    local angle = currentOrientation * math.pi / 3 + math.pi / 6
    
    -- No color tint - preserve original sprite appearance
    love.graphics.setColor(1, 1, 1, 1) -- Full white (no tint)
    
    -- Load and draw ship sprite
    local sprite = self.assetUtils.loadImage(spritePath, "ship")
    if sprite then
        -- Display at full size
        local scale = 1.0
        
        love.graphics.draw(
            sprite,
            x, y,   -- Position (interpolated)
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
    
    -- Restore original orientation
    ship.orientation = originalOrientation
end

-- Draw a trajectory path between start and end positions
function Combat:drawManeuverPath(battle, ship)
    -- Only draw if we're in maneuver animation
    if not battle.maneuverAnimationTimer or not ship.animationStart or not ship.animationEnd then
        return
    end
    
    -- Calculate animation progress
    local progress = math.min(1, battle.maneuverAnimationTimer / battle.maneuverAnimationDuration)
    
    -- Calculate the path
    local startQ, startR = ship.animationStart.q, ship.animationStart.r
    local endQ, endR = ship.animationEnd.q, ship.animationEnd.r
    local path = self:calculatePath(startQ, startR, endQ, endR)
    
    -- Determine how much of the path to show based on animation progress
    local visiblePathLength = math.ceil(#path * progress)
    
    -- Draw the visible path segments
    for i = 1, math.min(visiblePathLength, #path - 1) do
        local q1, r1 = path[i][1], path[i][2]
        local q2, r2 = path[i+1][1], path[i+1][2]
        
        local x1, y1 = self:hexToScreen(q1, r1)
        local x2, y2 = self:hexToScreen(q2, r2)
        
        -- Draw path line with appropriate color based on ship type
        if ship == battle.playerShip then
            love.graphics.setColor(0.2, 0.8, 0.2, 0.7) -- Green for player
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 0.7) -- Red for enemy
        end
        
        -- Draw slightly thicker line for visibility
        love.graphics.setLineWidth(2)
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.setLineWidth(1)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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

-- Get all hex coordinates that fall within a ship's firing arc
function Combat:getFiringArcHexes(battle, ship)
    -- Get ship class definition to determine firing arcs and range
    local shipClass = ship.class
    local shipDef = self.shipDefinitions[shipClass]
    
    if not shipDef or not shipDef.firingArcs then
        print("ERROR: Ship class " .. tostring(shipClass) .. " not properly defined or missing firing arcs")
        return {}
    end
    
    -- Get ship position and orientation
    local shipQ, shipR = ship.position[1], ship.position[2]
    local orientation = ship.orientation
    local firingRange = shipDef.firingRange or 4  -- Default range if not specified
    
    print("Calculating firing arcs for " .. shipClass .. " at " .. 
          shipQ .. "," .. shipR .. " with orientation " .. orientation)
    
    -- Create a set of valid arc hexes
    local validHexes = {}
    
    -- Helper function to add a hex to our results if it's in bounds
    local function addIfValid(q, r)
        -- Check grid bounds
        if q < 0 or q >= self.GRID_SIZE or r < 0 or r >= self.GRID_SIZE then
            return false
        end
        
        -- Check if it's already in our results
        for _, hex in ipairs(validHexes) do
            if hex[1] == q and hex[2] == r then
                return false
            end
        end
        
        -- Check it's not occupied by a ship (we can't fire through other ships)
        -- Simplification: we're not doing complex line-of-sight, just checking the target hex
        if battle.grid[q] and battle.grid[q][r] then
            if battle.grid[q][r].isPlayerShip or battle.grid[q][r].isEnemyShip then
                -- If it's an enemy or player ship, we can target it (but not pass through it)
                -- Check if it's a valid target (enemy for player, player for enemy)
                local isValidTarget = false
                if ship == battle.playerShip and battle.grid[q][r].isEnemyShip then
                    isValidTarget = true
                elseif ship == battle.enemyShip and battle.grid[q][r].isPlayerShip then
                    isValidTarget = true
                end
                
                if isValidTarget then
                    table.insert(validHexes, {q, r})
                end
                return false  -- Don't continue past this hex
            end
        end
        
        -- If we get here, it's a valid target hex
        table.insert(validHexes, {q, r})
        return true
    end
    
    -- Define the arc sectors relative to orientation
    -- For a ship with orientation 0 (facing North):
    -- - Forward arc: Hexes in directions 0 (and adjacent)
    -- - Side arcs: Hexes in directions 1,2 (right) and 4,5 (left)
    -- - Rear arc: Hexes in direction 3 (and adjacent)
    
    -- We need to translate these arcs based on the ship's current orientation
    
    -- Calculate all hexes within range
    for q = math.max(0, shipQ - firingRange), math.min(self.GRID_SIZE - 1, shipQ + firingRange) do
        for r = math.max(0, shipR - firingRange), math.min(self.GRID_SIZE - 1, shipR + firingRange) do
            -- Skip the ship's own position
            if not (q == shipQ and r == shipR) then
                -- Calculate distance
                local distance = self:hexDistance(shipQ, shipR, q, r)
                
                -- If within range, check if in firing arc
                if distance <= firingRange then
                    -- Determine which arc sector this hex falls into
                    local arcDirection = self:getArcDirection(shipQ, shipR, q, r, orientation)
                    
                    -- Check if this direction is in the ship's firing arc
                    if self:isDirectionInFiringArc(arcDirection, shipDef.firingArcs) then
                        addIfValid(q, r)
                    end
                end
            end
        end
    end
    
    return validHexes
end

-- Get the arc direction (forward, sides, rear) of a target hex relative to a ship
function Combat:getArcDirection(shipQ, shipR, targetQ, targetR, shipOrientation)
    -- Convert both positions to cube coordinates
    local shipX, shipY, shipZ = self:offsetToCube(shipQ, shipR)
    local targetX, targetY, targetZ = self:offsetToCube(targetQ, targetR)
    
    -- Calculate the direction vector from ship to target
    local dirX = targetX - shipX
    local dirY = targetY - shipY
    local dirZ = targetZ - shipZ
    
    -- The orientation is 0-5 (60° increments)
    -- 0 = North, 1 = Northeast, 2 = Southeast, 3 = South, 4 = Southwest, 5 = Northwest
    
    -- Convert orientation to radians for easy comparison
    local orientationRads = shipOrientation * math.pi / 3
    
    -- Calculate the angle of the target relative to east (0 radians)
    local targetAngle = 0
    if dirX == 0 and dirY == 0 and dirZ == 0 then
        -- Edge case: same hex
        return "same"
    else
        -- Use atan2 to get the angle
        -- For cube coordinates, we need to convert to our coordinate system
        -- This formula gives us an angle where 0 is east
        targetAngle = math.atan2(dirZ, dirX)
    end
    
    -- Adjust the angle to be relative to the ship's orientation
    -- This makes 0 degrees the ship's forward direction
    local relativeAngle = targetAngle - orientationRads
    
    -- Normalize to [-π, π]
    while relativeAngle > math.pi do relativeAngle = relativeAngle - 2 * math.pi end
    while relativeAngle <= -math.pi do relativeAngle = relativeAngle + 2 * math.pi end
    
    -- Determine which arc sector this falls into
    -- Forward: -π/6 to π/6 (60° arc centered on forward)
    -- Right side: π/6 to 5π/6 (120° arc on right)
    -- Left side: -5π/6 to -π/6 (120° arc on left)
    -- Rear: 5π/6 to -5π/6 (60° arc centered on rear)
    
    if relativeAngle >= -math.pi/6 and relativeAngle < math.pi/6 then
        return "forward"
    elseif relativeAngle >= math.pi/6 and relativeAngle < 5*math.pi/6 then
        return "right"  -- Right side
    elseif relativeAngle >= -5*math.pi/6 and relativeAngle < -math.pi/6 then
        return "left"   -- Left side
    else
        return "rear"
    end
end

-- Check if a direction is in a ship's firing arc
function Combat:isDirectionInFiringArc(direction, firingArcs)
    if direction == "forward" then
        return firingArcs.forward
    elseif direction == "right" or direction == "left" then
        return firingArcs.sides
    elseif direction == "rear" then
        return firingArcs.rear
    else
        return false
    end
end

-- Check if a specific hex is within a ship's firing arc
function Combat:isInFiringArc(battle, ship, targetQ, targetR)
    -- Quick distance check
    local shipQ, shipR = ship.position[1], ship.position[2]
    local distance = self:hexDistance(shipQ, shipR, targetQ, targetR)
    
    -- Get ship data
    local shipDef = self.shipDefinitions[ship.class]
    if not shipDef or not shipDef.firingArcs then return false end
    
    -- Check if target is beyond firing range
    local firingRange = shipDef.firingRange or 4
    if distance > firingRange then return false end
    
    -- Check if target is the ship itself
    if shipQ == targetQ and shipR == targetR then return false end
    
    -- Determine which arc sector this hex falls into
    local arcDirection = self:getArcDirection(shipQ, shipR, targetQ, targetR, ship.orientation)
    
    -- Check if this direction is in the ship's firing arc
    return self:isDirectionInFiringArc(arcDirection, shipDef.firingArcs)
end

-- Replenish a ship's resources (SP and CP) at the start of a turn
function Combat:replenishResources(ship)
    -- Replenish Sail Points to maximum
    ship.currentSP = ship.maxSP
    
    -- Replenish Crew Points to maximum
    ship.currentCP = ship.maxCP or 2 -- Default to 2 if not set
    
    print("Replenished resources for " .. ship.class .. " ship: " .. 
          ship.currentSP .. " SP, " .. ship.currentCP .. " CP")
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
    self.actionMenuButtons = nil
    self.confirmationButtons = nil
    
    -- Clear any action-related state
    battle.actionInProgress = nil
    battle.confirmingAction = nil
    battle.targetHex = nil
    battle.actionResult = nil
    battle.actionFeedback = nil
    battle.enemyShip.plannedAction = nil
    
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
    
    -- Get SP (Sail Points) for ships based on class
    local playerMaxSP = self:getMaxSP(playerShipClass)
    local enemyMaxSP = self:getMaxSP(enemyShipClass or "sloop")
    
    -- Ensure valid SP values - important for ship movement
    if not playerMaxSP or playerMaxSP < 1 then playerMaxSP = 3 end
    if not enemyMaxSP or enemyMaxSP < 1 then enemyMaxSP = 3 end
    
    -- Get CP (Crew Points) for ships based on class 
    local playerMaxCP = self:getMaxCP(playerShipClass, gameState)
    local enemyMaxCP = self:getBaseCP(enemyShipClass or "sloop")
    
    print("Setting up ships - Player: " .. playerShipClass .. " with " .. playerMaxSP .. " SP, " ..
          playerMaxCP .. " CP, Enemy: " .. (enemyShipClass or "sloop") .. " with " .. 
          enemyMaxSP .. " SP, " .. enemyMaxCP .. " CP")
    
    -- Create battle state
    local battle = {
        grid = grid,
        playerShip = {
            class = playerShipClass,
            size = self.shipDefinitions[playerShipClass].hexSize,
            position = {2, 8}, -- Bottom-left area
            orientation = 0,   -- North-facing to start
            currentSP = playerMaxSP,
            maxSP = playerMaxSP,
            currentCP = playerMaxCP,
            maxCP = playerMaxCP,
            evadeScore = 0,    -- Initial evade score
            durability = self.shipDefinitions[playerShipClass].maxHP, -- Ship health
            plannedMove = nil, -- Will store destination hex {q, r}
            plannedRotation = nil -- Will store target orientation (0-5)
        },
        enemyShip = {
            class = enemyShipClass or "sloop", -- Default to sloop if not specified
            size = self.shipDefinitions[enemyShipClass or "sloop"].hexSize,
            position = {9, 3}, -- Top-right area
            orientation = 3,   -- South-facing to start
            currentSP = enemyMaxSP,
            maxSP = enemyMaxSP,
            currentCP = enemyMaxCP,
            maxCP = enemyMaxCP,
            evadeScore = 0,    -- Initial evade score
            durability = self.shipDefinitions[enemyShipClass or "sloop"].maxHP, -- Ship health
            plannedMove = nil,
            plannedRotation = nil,
            plannedAction = nil -- Will store planned action for later execution
        },
        phase = "playerMovePlanning", -- Updated to new phase system
        actionResult = nil,    -- Stores result of the last action
        actionInProgress = nil, -- Tracks if we're in the middle of an action
        confirmingAction = nil, -- Tracks if we're confirming an action
        targetHex = nil,       -- Stores target hex for actions
        actionFeedback = nil,  -- Stores feedback messages for player
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
    
    -- Now also plan the enemy's actions based on firing arcs
    self:chooseEnemyAction(battle)
    
    -- Test firing arc calculation - print available targets in arc
    self:testFiringArcs(battle)
    
    return true
end

-- Choose an action for the enemy to take based on situation
function Combat:chooseEnemyAction(battle)
    local enemyShip = battle.enemyShip
    local playerShip = battle.playerShip
    
    -- Default action is to hold (do nothing)
    enemyShip.plannedAction = "none"
    
    -- Simple HP-based decision tree with arc check
    local enemyHP = enemyShip.health or enemyShip.durability or 10
    local maxEnemyHP = self.shipDefinitions[enemyShip.class].maxHP or 10
    local hpRatio = enemyHP / maxEnemyHP
    
    -- Will player be in firing arc after movement?
    -- Note: We need to check based on the planned position and orientation after maneuver
    local playerQ, playerR = playerShip.position[1], playerShip.position[2]
    
    -- We need to check if the player will be in firing arc after the enemy's planned maneuver
    -- This is predicting the future state after maneuver resolution
    local willBeInArc = self:isInFiringArc(battle, {
        position = enemyShip.plannedMove,
        orientation = enemyShip.plannedRotation,
        class = enemyShip.class
    }, playerQ, playerR)
    
    print("Enemy checking if player will be in firing arc: " .. (willBeInArc and "YES" or "NO"))
    
    -- Decide action based on HP and arc
    if hpRatio < 0.3 then
        -- Low HP - prioritize repair
        enemyShip.plannedAction = "repair"
    elseif hpRatio < 0.7 then
        -- Medium HP - evade if can't fire, otherwise fire
        if willBeInArc then
            enemyShip.plannedAction = "fireCannons"
            enemyShip.targetHex = {playerQ, playerR} -- Store target hex
        else
            enemyShip.plannedAction = "evade"
        end
    else
        -- High HP - fire if possible, otherwise evade
        if willBeInArc then
            enemyShip.plannedAction = "fireCannons"
            enemyShip.targetHex = {playerQ, playerR} -- Store target hex
        else
            enemyShip.plannedAction = "evade"
        end
    end
    
    print("Enemy planned action: " .. enemyShip.plannedAction)
    return true
end

-- Draw action menu for player during action planning phase
function Combat:drawActionMenu(battle, buttonsY, screenWidth)
    local buttonWidth = 120
    local buttonHeight = 30
    local buttonSpacing = 20
    
    -- Calculate button positions
    local totalWidth = (4 * buttonWidth) + (3 * buttonSpacing)
    local startX = (screenWidth - totalWidth) / 2
    
    -- Define buttons and store them for interaction
    self.actionMenuButtons = {
        fireCannons = {
            x = startX,
            y = buttonsY + 50,
            width = buttonWidth,
            height = buttonHeight
        },
        evade = {
            x = startX + buttonWidth + buttonSpacing,
            y = buttonsY + 50,
            width = buttonWidth,
            height = buttonHeight
        },
        repair = {
            x = startX + (buttonWidth + buttonSpacing) * 2,
            y = buttonsY + 50,
            width = buttonWidth,
            height = buttonHeight
        },
        endTurn = {
            x = startX + (buttonWidth + buttonSpacing) * 3,
            y = buttonsY + 50,
            width = buttonWidth,
            height = buttonHeight
        }
    }
    
    -- Define costs and check affordability
    local cpCosts = {
        fireCannons = Constants.COMBAT.CP_COST_FIRE,
        evade = Constants.COMBAT.CP_COST_EVADE,
        repair = Constants.COMBAT.CP_COST_REPAIR,
        endTurn = 0
    }
    
    -- Actions may have additional requirements (like target in arc)
    local availableActions = {
        fireCannons = self:hasValidTargetsInFiringArc(battle, battle.playerShip),
        evade = true, -- Always available if affordable
        repair = true, -- Always available if affordable
        endTurn = true -- Always available
    }
    
    -- Draw buttons
    for actionName, button in pairs(self.actionMenuButtons) do
        -- Check if player can afford this action
        local canAfford = (battle.playerShip.currentCP or 0) >= (cpCosts[actionName] or 0)
        local isAvailable = availableActions[actionName]
        
        -- Set button color based on action type and availability
        if not canAfford or not isAvailable then
            -- Grey out if not affordable or unavailable
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        elseif actionName == "fireCannons" then
            love.graphics.setColor(Constants.COLORS.BUTTON_FIRE)
        elseif actionName == "evade" then
            love.graphics.setColor(Constants.COLORS.BUTTON_EVADE)
        elseif actionName == "repair" then
            love.graphics.setColor(Constants.COLORS.BUTTON_REPAIR)
        else
            love.graphics.setColor(Constants.COLORS.BUTTON_NEUTRAL)
        end
        
        -- Draw button rectangle
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Draw button border
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, 1)
        local displayText = actionName
        if actionName ~= "endTurn" then
            displayText = displayText .. " (" .. cpCosts[actionName] .. " CP)"
        end
        love.graphics.printf(displayText, button.x, button.y + 8, button.width, "center")
    end
    
    -- Show available CP
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Available CP: " .. (battle.playerShip.currentCP or 0), 
                      0, buttonsY + 10, screenWidth, "center")
end

-- Draw confirmation window for actions
function Combat:drawConfirmationWindow(battle, buttonsY, screenWidth)
    local windowWidth = 300
    local windowHeight = 200
    local windowX = (screenWidth - windowWidth) / 2
    local windowY = buttonsY - windowHeight - 20
    
    -- Draw window background
    love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight, 10, 10)
    
    -- Draw window border
    love.graphics.setColor(0.5, 0.5, 0.6, 0.8)
    love.graphics.rectangle("line", windowX, windowY, windowWidth, windowHeight, 10, 10)
    
    -- Draw window title
    love.graphics.setColor(1, 1, 1, 0.9)
    
    local actionTitle = "Confirm Action"
    if battle.confirmingAction == "fireCannons" then
        actionTitle = "Fire Cannons"
    elseif battle.confirmingAction == "evade" then
        actionTitle = "Evade"
    elseif battle.confirmingAction == "repair" then
        actionTitle = "Repair"
    end
    
    -- Draw title
    love.graphics.printf(actionTitle, windowX, windowY + 15, windowWidth, "center")
    
    -- Draw dice pool and modifiers
    local baseY = windowY + 50
    love.graphics.setColor(1, 1, 1, 0.8)
    
    -- Set up action-specific data
    local baseDice = 0
    local modifiers = {}
    local cpCost = 0
    
    if battle.confirmingAction == "fireCannons" then
        -- Get ship's base firepower
        baseDice = self.shipDefinitions[battle.playerShip.class].cannon or 2
        cpCost = Constants.COMBAT.CP_COST_FIRE
        
        -- Calculate point-blank bonus
        if battle.targetHex then
            local distance = self:hexDistance(
                battle.playerShip.position[1], battle.playerShip.position[2],
                battle.targetHex[1], battle.targetHex[2]
            )
            
            if distance <= 1 then
                table.insert(modifiers, {text = "Point Blank", value = 1})
            end
        end
        
        -- Check enemy evade score
        if battle.enemyShip.evadeScore and battle.enemyShip.evadeScore > 0 then
            table.insert(modifiers, {text = "Target Evading", value = -battle.enemyShip.evadeScore})
        end
        
        -- TODO: Add gunner skill bonus once crew implementation is finalized
    
    elseif battle.confirmingAction == "evade" then
        -- Get ship's base speed for evade
        baseDice = self.shipDefinitions[battle.playerShip.class].speed or 1
        cpCost = Constants.COMBAT.CP_COST_EVADE
        
    elseif battle.confirmingAction == "repair" then
        -- Base repair is 1 die
        baseDice = 1
        cpCost = Constants.COMBAT.CP_COST_REPAIR
        
        -- TODO: Add surgeon skill bonus once crew implementation is finalized
    end
    
    -- Draw base dice info
    love.graphics.printf("Base Dice: " .. baseDice, windowX + 20, baseY, windowWidth - 40, "left")
    baseY = baseY + 20
    
    -- Draw modifiers
    if #modifiers > 0 then
        for _, mod in ipairs(modifiers) do
            local modText = mod.text .. ": " .. (mod.value > 0 and "+" or "") .. mod.value
            love.graphics.printf(modText, windowX + 20, baseY, windowWidth - 40, "left")
            baseY = baseY + 20
        end
    end
    
    -- Calculate total dice
    local totalDice = baseDice
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
    end
    
    -- Clamp to valid range (min 0)
    totalDice = math.max(0, totalDice)
    
    -- Draw total dice pool
    love.graphics.setColor(1, 0.8, 0.2, 0.9) -- Gold for total
    love.graphics.printf("Total Dice Pool: " .. totalDice .. " d6", windowX + 20, baseY + 10, windowWidth - 40, "left")
    
    -- Draw CP cost
    love.graphics.setColor(0.2, 0.8, 0.8, 0.9) -- Cyan for CP
    love.graphics.printf("CP Cost: " .. cpCost, windowX + 20, baseY + 40, windowWidth - 40, "left")
    
    -- Draw confirm/cancel buttons
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonY = windowY + windowHeight - 50
    
    -- Set up button hitboxes
    self.confirmationButtons = {
        confirm = {
            x = windowX + 40,
            y = buttonY,
            width = buttonWidth,
            height = buttonHeight
        },
        cancel = {
            x = windowX + windowWidth - buttonWidth - 40,
            y = buttonY,
            width = buttonWidth,
            height = buttonHeight
        }
    }
    
    -- Draw confirm button
    love.graphics.setColor(0.2, 0.7, 0.3, 0.9) -- Green for confirm
    love.graphics.rectangle("fill", self.confirmationButtons.confirm.x, self.confirmationButtons.confirm.y, 
                       self.confirmationButtons.confirm.width, self.confirmationButtons.confirm.height)
    
    -- Draw cancel button
    love.graphics.setColor(0.7, 0.3, 0.2, 0.9) -- Red for cancel
    love.graphics.rectangle("fill", self.confirmationButtons.cancel.x, self.confirmationButtons.cancel.y, 
                       self.confirmationButtons.cancel.width, self.confirmationButtons.cancel.height)
    
    -- Draw button text
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Confirm", self.confirmationButtons.confirm.x, self.confirmationButtons.confirm.y + 8, 
                     self.confirmationButtons.confirm.width, "center")
    love.graphics.printf("Cancel", self.confirmationButtons.cancel.x, self.confirmationButtons.cancel.y + 8, 
                     self.confirmationButtons.cancel.width, "center")
end

-- Check if a ship has any valid targets within its firing arc
function Combat:hasValidTargetsInFiringArc(battle, ship)
    -- Get all hexes in firing arc
    local arcHexes = self:getFiringArcHexes(battle, ship)
    
    -- Check if any of these hexes contain a valid target
    for _, hex in ipairs(arcHexes) do
        local q, r = hex[1], hex[2]
        
        if ship == battle.playerShip and battle.grid[q] and battle.grid[q][r] and battle.grid[q][r].isEnemyShip then
            return true
        elseif ship == battle.enemyShip and battle.grid[q] and battle.grid[q][r] and battle.grid[q][r].isPlayerShip then
            return true
        end
    end
    
    return false
end

-- Roll dice for an action
function Combat:rollActionDice(dicePool)
    -- Ensure dicePool is at least 0
    dicePool = math.max(0, dicePool or 0)
    
    local diceResults = {}
    local highest = 0
    local countSixes = 0
    
    -- Special case: Zero or negative dice pool
    if dicePool <= 0 then
        -- Roll 2d6 and take lowest
        local roll1 = math.random(1, 6)
        local roll2 = math.random(1, 6)
        table.insert(diceResults, math.min(roll1, roll2))
        highest = diceResults[1]
    else
        -- Normal case: Roll the dice pool (max 5 dice)
        dicePool = math.min(dicePool, 5)
        
        for i = 1, dicePool do
            local roll = math.random(1, 6)
            table.insert(diceResults, roll)
            
            -- Track highest and count sixes
            if roll > highest then
                highest = roll
            end
            
            if roll == 6 then
                countSixes = countSixes + 1
            end
        end
    end
    
    -- Determine outcome level
    local outcomeLevel = Constants.DICE.OUTCOME_FAILURE -- Default to failure
    
    if countSixes > 1 then
        -- Critical success (multiple 6s)
        outcomeLevel = Constants.DICE.OUTCOME_CRITICAL
    elseif highest == 6 then
        -- Success (single 6)
        outcomeLevel = Constants.DICE.OUTCOME_SUCCESS
    elseif highest >= Constants.DICE.PARTIAL_MIN and highest <= Constants.DICE.PARTIAL_MAX then
        -- Partial success (4-5)
        outcomeLevel = Constants.DICE.OUTCOME_PARTIAL
    end
    
    return {
        dice = diceResults,
        highest = highest,
        outcomeLevel = outcomeLevel,
        outcomeName = self:getOutcomeName(outcomeLevel)
    }
end

-- Get the name of an outcome level
function Combat:getOutcomeName(outcomeLevel)
    if outcomeLevel == Constants.DICE.OUTCOME_CRITICAL then
        return "Critical Success"
    elseif outcomeLevel == Constants.DICE.OUTCOME_SUCCESS then
        return "Success"
    elseif outcomeLevel == Constants.DICE.OUTCOME_PARTIAL then
        return "Partial Success"
    else
        return "Failure"
    end
end

-- Fire cannons at a target
function Combat:fireCannons(battle, ship, targetQ, targetR)
    print("Firing cannons from " .. ship.class .. " at " .. targetQ .. "," .. targetR)
    
    -- Deduct CP cost
    if ship.currentCP then
        ship.currentCP = ship.currentCP - Constants.COMBAT.CP_COST_FIRE
    end
    
    -- Calculate base dice pool
    local baseDice = self.shipDefinitions[ship.class].cannon or 2
    local modifiers = {}
    
    -- Calculate distance for point-blank bonus
    local distance = self:hexDistance(ship.position[1], ship.position[2], targetQ, targetR)
    
    -- Apply point-blank bonus
    if distance <= 1 then
        table.insert(modifiers, {text = "Point Blank", value = 1})
    end
    
    -- Apply target's evade score as a negative modifier
    local targetShip = nil
    if ship == battle.playerShip then
        targetShip = battle.enemyShip
    else
        targetShip = battle.playerShip
    end
    
    if targetShip.evadeScore and targetShip.evadeScore > 0 then
        table.insert(modifiers, {text = "Target Evading", value = -targetShip.evadeScore})
    end
    
    -- TODO: Apply gunner skill bonus once crew implementation is done
    
    -- Calculate total dice pool
    local totalDice = baseDice
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
    end
    
    -- Roll the dice
    local rollResult = self:rollActionDice(totalDice)
    
    -- Apply damage based on outcome
    local damage = 0
    if rollResult.outcomeLevel == Constants.DICE.OUTCOME_CRITICAL then
        damage = Constants.COMBAT.DAMAGE_CRITICAL
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_SUCCESS then
        damage = Constants.COMBAT.DAMAGE_SUCCESS
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_PARTIAL then
        damage = Constants.COMBAT.DAMAGE_PARTIAL
    end
    
    -- Apply the damage to the target
    if targetShip.durability then
        targetShip.durability = math.max(0, targetShip.durability - damage)
    elseif targetShip.health then
        targetShip.health = math.max(0, targetShip.health - damage)
    end
    
    -- Reset target's evade score after being attacked
    targetShip.evadeScore = 0
    
    -- Store action result for display
    battle.actionResult = {
        action = "fireCannons",
        ship = ship == battle.playerShip and "player" or "enemy",
        rollResult = rollResult,
        damage = damage,
        target = targetShip == battle.playerShip and "player" or "enemy"
    }
    
    print("Fire cannons result: " .. rollResult.outcomeName .. " with " .. damage .. " damage")
    return true
end

-- Perform evade action
function Combat:performEvade(battle, ship)
    print("Performing evade with " .. ship.class)
    
    -- Deduct CP cost
    if ship.currentCP then
        ship.currentCP = ship.currentCP - Constants.COMBAT.CP_COST_EVADE
    end
    
    -- Calculate base dice pool (based on ship speed)
    local baseDice = self.shipDefinitions[ship.class].speed or 1
    local modifiers = {}
    
    -- No standard modifiers for evade, but could add later
    
    -- Calculate total dice pool
    local totalDice = baseDice
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
    end
    
    -- Roll the dice
    local rollResult = self:rollActionDice(totalDice)
    
    -- Set evade score based on outcome
    local evadeScore = 0
    if rollResult.outcomeLevel == Constants.DICE.OUTCOME_CRITICAL then
        evadeScore = 3
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_SUCCESS then
        evadeScore = 2
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_PARTIAL then
        evadeScore = 1
    end
    
    -- Apply the evade score to the ship
    ship.evadeScore = evadeScore
    
    -- Store action result for display
    battle.actionResult = {
        action = "evade",
        ship = ship == battle.playerShip and "player" or "enemy",
        rollResult = rollResult,
        evadeScore = evadeScore
    }
    
    print("Evade result: " .. rollResult.outcomeName .. " with evade score " .. evadeScore)
    return true
end

-- Perform repair action
function Combat:performRepair(battle, ship)
    print("Performing repair on " .. ship.class)
    
    -- Deduct CP cost
    if ship.currentCP then
        ship.currentCP = ship.currentCP - Constants.COMBAT.CP_COST_REPAIR
    end
    
    -- Calculate base dice pool (base is 1 for repair)
    local baseDice = 1
    local modifiers = {}
    
    -- TODO: Apply surgeon skill bonus once crew implementation is done
    
    -- Calculate total dice pool
    local totalDice = baseDice
    for _, mod in ipairs(modifiers) do
        totalDice = totalDice + mod.value
    end
    
    -- Roll the dice
    local rollResult = self:rollActionDice(totalDice)
    
    -- Calculate repair amount based on outcome
    local repairAmount = 0
    if rollResult.outcomeLevel == Constants.DICE.OUTCOME_CRITICAL then
        repairAmount = Constants.COMBAT.REPAIR_CRITICAL
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_SUCCESS then
        repairAmount = Constants.COMBAT.REPAIR_SUCCESS
    elseif rollResult.outcomeLevel == Constants.DICE.OUTCOME_PARTIAL then
        repairAmount = Constants.COMBAT.REPAIR_PARTIAL
    end
    
    -- Get ship's maximum health
    local maxHealth = self.shipDefinitions[ship.class].maxHP or 10
    
    -- Apply the repair, but don't exceed max health
    if ship.durability then
        ship.durability = math.min(maxHealth, ship.durability + repairAmount)
    elseif ship.health then
        ship.health = math.min(maxHealth, ship.health + repairAmount)
    end
    
    -- Store action result for display
    battle.actionResult = {
        action = "repair",
        ship = ship == battle.playerShip and "player" or "enemy",
        rollResult = rollResult,
        repairAmount = repairAmount
    }
    
    print("Repair result: " .. rollResult.outcomeName .. " with " .. repairAmount .. " HP restored")
    return true
end

-- Test function for firing arcs (debug/development use)
function Combat:testFiringArcs(battle)
    -- Test player ship firing arcs
    local playerArcs = self:getFiringArcHexes(battle, battle.playerShip)
    print("Player ship has " .. #playerArcs .. " hexes in firing arc")
    
    -- Check if enemy ship is in player's firing arc
    local enemyQ, enemyR = battle.enemyShip.position[1], battle.enemyShip.position[2]
    local enemyInArc = self:isInFiringArc(battle, battle.playerShip, enemyQ, enemyR)
    print("Enemy ship is " .. (enemyInArc and "IN" or "NOT IN") .. " player's firing arc")
    
    -- Test enemy ship firing arcs
    local enemyArcs = self:getFiringArcHexes(battle, battle.enemyShip)
    print("Enemy ship has " .. #enemyArcs .. " hexes in firing arc")
    
    -- Check if player ship is in enemy's firing arc
    local playerQ, playerR = battle.playerShip.position[1], battle.playerShip.position[2]
    local playerInArc = self:isInFiringArc(battle, battle.enemyShip, playerQ, playerR)
    print("Player ship is " .. (playerInArc and "IN" or "NOT IN") .. " enemy's firing arc")
    
    -- Get details about ship firing capabilities
    local playerShipDef = self.shipDefinitions[battle.playerShip.class]
    local enemyShipDef = self.shipDefinitions[battle.enemyShip.class]
    
    print("Player ship (" .. battle.playerShip.class .. ") firing arcs:")
    print("  Forward: " .. tostring(playerShipDef.firingArcs.forward))
    print("  Sides: " .. tostring(playerShipDef.firingArcs.sides))
    print("  Rear: " .. tostring(playerShipDef.firingArcs.rear))
    print("  Range: " .. tostring(playerShipDef.firingRange))
    
    print("Enemy ship (" .. battle.enemyShip.class .. ") firing arcs:")
    print("  Forward: " .. tostring(enemyShipDef.firingArcs.forward))
    print("  Sides: " .. tostring(enemyShipDef.firingArcs.sides))
    print("  Rear: " .. tostring(enemyShipDef.firingArcs.rear))
    print("  Range: " .. tostring(enemyShipDef.firingRange))
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
    
    -- Draw phase-specific information at the top of the screen
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.printf("Turn " .. battle.turnCount .. " - " .. self:getPhaseDisplayName(battle.phase), 
                      0, 20, screenWidth, "center")
    
    -- If in action planning phase, show relevant visual feedback
    if battle.phase == "playerActionPlanning" then
        -- Show current action info
        if battle.actionInProgress then
            -- Add an action indicator at the top
            local actionText = ""
            if battle.actionInProgress == "fireCannons" then
                actionText = "TARGETING: Fire Cannons"
                -- Draw player's firing arcs when targeting
                self:drawFiringArcs(battle, battle.playerShip)
            elseif battle.actionInProgress == "evade" then
                actionText = "PLANNING: Evade"
            elseif battle.actionInProgress == "repair" then
                actionText = "PLANNING: Repair"
            end
            
            -- Draw action indicator
            love.graphics.setColor(0.9, 0.9, 0.2, 0.9) -- Yellow action text
            love.graphics.printf(actionText, 0, 50, screenWidth, "center")
        end
    end
    
    -- Phase-specific drawing
    if battle.phase == "maneuverResolution" and battle.maneuverAnimationTimer then
        -- During maneuver resolution animation, draw trajectory paths
        self:drawManeuverPath(battle, battle.playerShip)
        self:drawManeuverPath(battle, battle.enemyShip)
        
        -- Draw the animated ships
        self:drawShipDuringManeuver(battle, battle.playerShip)
        self:drawShipDuringManeuver(battle, battle.enemyShip)
    else
        -- Default ship drawing for other phases
        self:drawShip(battle, battle.playerShip)
        self:drawShip(battle, battle.enemyShip)
    end
    
    -- Draw UI based on current phase
    if battle.phase == "playerMovePlanning" then
        -- Draw maneuver planning UI
        self:drawManeuverPlanningControls(battle, buttonsY, screenWidth)
    elseif battle.phase == "playerActionPlanning" then
        -- Draw action planning UI
        self:drawActionMenu(battle, buttonsY, screenWidth)
        
        -- If an action that requires target selection (like fireCannons) is in progress,
        -- show aiming feedback (highlighted hexes in firing arc etc.)
        if battle.actionInProgress == "fireCannons" then
            -- Draw instructional text
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("Select a target hex within your firing arc", 
                          0, buttonsY + 20, screenWidth, "center")
                          
            -- If we're hovering over a valid target, show indication
            if self.hoveredHex and self:isInFiringArc(battle, battle.playerShip, self.hoveredHex[1], self.hoveredHex[2]) then
                -- Draw the hover highlight in aiming color
                love.graphics.setColor(0.8, 0.6, 0.2, 0.8) -- Gold targeting color
                local screenX, screenY = self:hexToScreen(self.hoveredHex[1], self.hoveredHex[2])
                love.graphics.circle("fill", screenX, screenY, self.HEX_RADIUS * 0.5)
            end
        elseif battle.confirmingAction then
            -- Draw confirmation window if we're confirming an action
            self:drawConfirmationWindow(battle, buttonsY, screenWidth)
        else
            -- If no action is in progress, show normal action menu
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.printf("Select an action from the menu below", 
                          0, buttonsY + 20, screenWidth, "center")
        end
        
        -- Show any action feedback (errors like "Target not in arc")
        if battle.actionFeedback then
            love.graphics.setColor(1, 0.3, 0.3, 0.9) -- Red error text
            love.graphics.printf(battle.actionFeedback, 
                          0, buttonsY - 30, screenWidth, "center")
        end
    end
end

-- Draw the firing arcs for a ship (debug visualization)
function Combat:drawFiringArcs(battle, ship)
    -- Get all hexes in firing arc
    local arcHexes = self:getFiringArcHexes(battle, ship)
    
    -- Early exit if no hexes found
    if #arcHexes == 0 then return end
    
    -- Draw each hex with a colored overlay
    for _, hex in ipairs(arcHexes) do
        local q, r = hex[1], hex[2]
        local x, y = self:hexToScreen(q, r)
        
        -- Draw with a transparent overlay
        if ship == battle.playerShip then
            love.graphics.setColor(0.2, 0.8, 0.2, 0.3) -- Green for player
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 0.3) -- Red for enemy
        end
        
        -- Draw the hex with a semi-transparent fill
        self:drawHexOverlay(x, y)
        
        -- Check if this is a valid target (opponent's ship)
        local isValidTarget = false
        if ship == battle.playerShip and battle.grid[q][r].isEnemyShip then
            isValidTarget = true
        elseif ship == battle.enemyShip and battle.grid[q][r].isPlayerShip then
            isValidTarget = true
        end
        
        -- If it's a valid target, highlight it more brightly
        if isValidTarget then
            if ship == battle.playerShip then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.5) -- Brighter green
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.5) -- Brighter red
            end
            self:drawHexOverlay(x, y)
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a hex overlay for firing arc visualization
function Combat:drawHexOverlay(x, y)
    local vertices = {}
    
    -- For pointy-top hexes, start at the top (rotated 30 degrees from flat-top)
    local startAngle = math.pi / 6  -- 30 degrees
    
    -- Generate vertices for the hex
    for i = 0, 5 do
        local angle = startAngle + (i * math.pi / 3)
        table.insert(vertices, x + self.HEX_RADIUS * math.cos(angle))
        table.insert(vertices, y + self.HEX_RADIUS * math.sin(angle))
    end
    
    -- Draw the fill with current color
    love.graphics.polygon("fill", vertices)
    
    -- Store current color components
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw a target-like pattern for better visibility
    local innerRadius = self.HEX_RADIUS * 0.5
    
    -- Draw crosshair lines (subtly)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(r, g, b, a * 1.5) -- Slightly more opaque
    
    -- Draw diagonals with pulsing effect based on time
    local time = love.timer.getTime()
    local pulse = math.abs(math.sin(time * 2)) * 0.5 + 0.5 -- 0.5 to 1.0 pulse
    
    -- Inner circle
    love.graphics.circle("line", x, y, innerRadius * pulse)
    
    -- Outer hex outline (enhanced)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.polygon("line", vertices)
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end

-- Helper function to get a display name for the current phase
function Combat:getPhaseDisplayName(phase)
    local displayNames = {
        ["playerMovePlanning"] = "Player Maneuver Planning",
        ["maneuverResolution"] = "Maneuver Resolution",
        ["playerActionPlanning"] = "Player Action Planning",
        ["actionResolution"] = "Action Resolution",
        ["displayingResult"] = "Results"
    }
    
    return displayNames[phase] or phase
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
    
    local battle = gameState.combat
    
    -- Update based on the current phase
    if battle.phase == "maneuverResolution" then
        -- Update maneuver resolution animations
        self:updateManeuverResolution(dt, battle)
    end
    
    -- Debug: Auto-select player ship if not already selected in planning phase
    if battle.phase == "playerMovePlanning" and not self.selectedHex and battle.playerShip then
        self.selectedHex = {battle.playerShip.position[1], battle.playerShip.position[2]}
        if #self.validMoves == 0 then
            self.validMoves = self:calculateValidMoves_SP(battle, battle.playerShip)
        end
    end
    
    -- Handle any phase-specific updates (future expansion)
    if battle.phase == "playerActionPlanning" then
        -- Update action planning UI animations, if any
    elseif battle.phase == "actionResolution" then
        -- Update action resolution animations, if any
    elseif battle.phase == "displayingResult" then
        -- Update result display animations, if any
    end
end

-- Return the module
return Combat