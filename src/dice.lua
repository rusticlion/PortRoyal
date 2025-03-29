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
}