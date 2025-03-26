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

return TimeSystem