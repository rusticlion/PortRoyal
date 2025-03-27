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
}