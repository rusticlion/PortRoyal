-- Pirate's Wager: Blood for Gold - Main Game File

local gameState = require('gameState')
local gameMap = require('map')
local playerShip = require('ship')
local timeSystem = require('time')
local portRoyal = require('portRoyal')

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
    
    -- Set window properties
    love.window.setTitle("Pirate's Wager: Blood for Gold")
    love.window.setMode(800, 600, {
        vsync = true,
        resizable = false
    })
end

function love.update(dt)
    -- Early return if game is paused
    if gameState.settings.isPaused then return end
    
    -- Update game state
    if gameState.settings.portMode then
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
    end
end

function love.draw()
    -- Render game based on current mode
    if gameState.settings.portMode then
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
    end
end

function love.mousemoved(x, y)
    if gameState.settings.portMode then
        portRoyal:mousemoved(x, y, gameState)
    else
        gameMap:mousemoved(x, y, gameState)
    end
end

function love.mousepressed(x, y, button)
    if gameState.time.isGameOver then return end
    
    if gameState.settings.portMode then
        portRoyal:mousepressed(x, y, button, gameState)
    else
        gameMap:mousepressed(x, y, button, gameState)
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- If in port mode, return to map
        if gameState.settings.portMode then
            gameState.settings.portMode = false
            gameState.settings.currentPortScreen = "main"
        else
            love.event.quit()
        end
    elseif key == "f1" then
        gameState.settings.debug = not gameState.settings.debug
    elseif key == "p" then
        gameState.settings.isPaused = not gameState.settings.isPaused
    end
end