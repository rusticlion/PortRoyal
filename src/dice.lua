-- Dice Module
-- Implements a reusable dice system for Forged in the Dark mechanics

local Dice = {
    -- Sprite sheet for dice
    spriteSheet = nil,
    spriteWidth = 32,
    spriteHeight = 32,
    quads = {}
}

-- Initialize dice system
function Dice:init()
    -- Try to load dice sprite sheet
    local success, result = pcall(function()
        return love.graphics.newImage("assets/dice-strip.png")
    end)
    
    if success then
        self.spriteSheet = result
        
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
        print("Dice sprite sheet not found. Will use text representation.")
    end
end

-- Roll dice
function Dice:roll(numDice)
    local results = {}
    
    -- Roll the specified number of dice (1-5)
    numDice = math.min(5, math.max(1, numDice))
    
    for i = 1, numDice do
        -- Each die is a d6 (1-6)
        table.insert(results, math.random(1, 6))
    end
    
    return results
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
        if die == 6 then
            -- Success
            outcome.successes = outcome.successes + 1
        elseif die >= 4 and die <= 5 then
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
        outcome.level = 3
    elseif outcome.successes == 1 then
        -- Full success (1 die showing 6)
        outcome.result = "success"
        outcome.level = 2
    elseif outcome.partials > 0 then
        -- Partial success (highest die is 4-5)
        outcome.result = "partial"
        outcome.level = 1
    else
        -- Failure (no dice showing 4+)
        outcome.result = "failure"
        outcome.level = 0
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
            love.graphics.draw(
                self.spriteSheet,
                self.quads[value],
                dieX,
                y,
                0,  -- rotation
                scale, scale  -- scale x, y
            )
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
        return {0.2, 0.9, 0.2, 1} -- Bright green
    elseif outcome.result == "success" then
        return {0.2, 0.8, 0.2, 1} -- Green
    elseif outcome.result == "partial" then
        return {0.8, 0.8, 0.2, 1} -- Yellow
    else
        return {0.8, 0.2, 0.2, 1} -- Red
    end
end

return Dice