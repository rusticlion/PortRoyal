-- LÖVE Configuration
function love.conf(t)
    t.title = "Pirate's Wager: Blood for Gold"  -- The title of the window
    t.version = "11.4"                -- The LÖVE version this game was made for
    t.window.width = 800              -- Game window width
    t.window.height = 600             -- Game window height
    t.window.resizable = true         -- Allow window to be resized with letterboxing/pillarboxing
    t.console = true                  -- Enable console for debug output
    
    -- For development
    t.window.vsync = 1                -- Vertical sync mode
    
    -- Disable modules we won't be using
    t.modules.joystick = false        -- No need for joystick module
    t.modules.physics = false         -- No need for physics module for map navigation
end