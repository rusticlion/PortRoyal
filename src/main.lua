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
end