-- Port Interface Module
-- Currently focused on Port Royal but can be extended to all locations

local PortRoyal = {
    -- UI constants
    width = 800,
    height = 600,
    
    -- UI elements
    buttons = {},
    
    -- Placeholder art
    backgrounds = {
        main = nil,
        tavern = nil,
        shipyard = nil
    },
}

-- Initialize Port interface
function PortRoyal:load(gameState)
    -- Main screen buttons will be generated dynamically based on location
    self.buttons.main = {}
    
    -- Initialize buttons for tavern screen
    self.buttons.tavern = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Initialize buttons for shipyard screen
    self.buttons.shipyard = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Initialize buttons for crew screen
    self.buttons.crew = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Initialize buttons for inventory screen
    self.buttons.inventory = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Load placeholder background images if available
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port_royal_main.png")
    end)
    if success then
        self.backgrounds.main = result
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-tavern.png")
    end)
    if success then
        self.backgrounds.tavern = result
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    local success, result = pcall(function()
        return love.graphics.newImage("assets/port-royal-shipyard.png")
    end)
    if success then
        self.backgrounds.shipyard = result
        print("Port Royal shipyard background loaded")
    end
end

-- Update Port interface
function PortRoyal:update(dt, gameState)
    -- Generate location-specific buttons if needed
    self:generateLocationButtons(gameState)
    
    -- Check if we need to reload any assets
    if not self.backgrounds.tavern then
        -- Try to load tavern background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-tavern.png")
        end)
        if success then
            self.backgrounds.tavern = result
            print("Port Royal tavern background loaded during update")
        end
    end
    
    if not self.backgrounds.shipyard then
        -- Try to load shipyard background
        local success, result = pcall(function()
            return love.graphics.newImage("assets/port-royal-shipyard.png")
        end)
        if success then
            self.backgrounds.shipyard = result
            print("Port Royal shipyard background loaded during update")
        end
    end
end

-- Generate buttons based on the current location
function PortRoyal:generateLocationButtons(gameState)
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Clear existing buttons
    self.buttons.main = {}
    
    -- Generate basic "Set Sail" button for all locations
    table.insert(self.buttons.main, {
        text = "Set Sail",
        x = 325,
        y = 400,
        width = 150,
        height = 50,
        action = function() 
            gameState.settings.portMode = false 
            gameState.settings.moored = false
            print("Setting sail from " .. currentZoneName)
        end
    })
    
    -- Add location-specific buttons
    if currentZoneName == "Port Royal" then
        -- Port Royal has the full set of options
        table.insert(self.buttons.main, {
            text = "Tavern",
            x = 200,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 200,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 450,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 450,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    elseif currentZoneName == "Nassau" then
        -- Nassau has a tavern and crew management
        table.insert(self.buttons.main, {
            text = "Pirate Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Crew",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "crew" end
        })
    elseif currentZoneName == "Havana" then
        -- Havana has a tavern and shipyard
        table.insert(self.buttons.main, {
            text = "Spanish Tavern",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "tavern" end
        })
        
        table.insert(self.buttons.main, {
            text = "Shipyard",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
    elseif currentZoneName == "Crown Colony" then
        -- Crown Colony has a shipyard and inventory
        table.insert(self.buttons.main, {
            text = "Royal Shipyard",
            x = 325,
            y = 200,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "shipyard" end
        })
        
        table.insert(self.buttons.main, {
            text = "Inventory",
            x = 325,
            y = 270,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "inventory" end
        })
    end
    
    -- For all locations, ensure "Set Sail" is at the bottom
    if #self.buttons.main > 0 then
        for i, button in ipairs(self.buttons.main) do
            if button.text == "Set Sail" then
                button.y = 400  -- Position at bottom
            end
        end
    end
end

-- Draw Port interface
function PortRoyal:draw(gameState)
    -- Get current screen and location
    local currentScreen = gameState.settings.currentPortScreen
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up the current zone name
    if currentZoneIndex and currentZoneIndex > 0 then
        -- Get the Map module to look up zone name
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Draw background based on current screen
    self:drawBackground(currentScreen)
    
    -- Draw gold amount
    love.graphics.setColor(1, 0.9, 0.2, 1)  -- Gold color
    love.graphics.print("Gold: " .. gameState.resources.gold, 10, 10)
    
    -- Draw screen-specific content
    if currentScreen == "main" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(currentZoneName .. " Harbor", 0, 100, self.width, "center")
        
        -- Draw ship name and class
        love.graphics.printf("Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 130, self.width, "center")
        
        -- Draw location-specific welcome message
        local welcomeMessage = "Welcome to port. What would you like to do?"
        
        if currentZoneName == "Port Royal" then
            welcomeMessage = "Welcome to Port Royal, the pirate haven of the Caribbean."
        elseif currentZoneName == "Nassau" then
            welcomeMessage = "Welcome to Nassau, the lawless pirate stronghold."
        elseif currentZoneName == "Havana" then
            welcomeMessage = "Welcome to Havana, the jewel of Spanish colonies."
        elseif currentZoneName == "Crown Colony" then
            welcomeMessage = "Welcome to the Crown Colony, an outpost of British influence."
        elseif currentZoneName:find("Waters") then
            welcomeMessage = "Your ship is anchored in open waters. Not much to do here."
        elseif currentZoneName:find("Bay") or currentZoneName:find("Reach") then
            welcomeMessage = "You've moored at a secluded spot with no settlements."
        end
        
        love.graphics.setColor(1, 0.95, 0.8, 1)  -- Light cream color
        love.graphics.printf(welcomeMessage, 50, 160, self.width - 100, "center")
        
        -- Draw buttons for main screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "tavern" then
        -- Get current location for tavern name
        local currentZoneIndex = gameState.ship.currentZone
        local tavernName = "The Rusty Anchor Tavern"
        local tavernDescription = "The tavern is filled with sailors, merchants, and pirates.\nHere you can recruit crew members and hear rumors."
        
        -- Set location-specific tavern names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Nassau" then
                    tavernName = "The Black Flag Tavern"
                    tavernDescription = "A rowdy establishment frequented by pirates.\nRecruit dangerous but skilled crew members here."
                elseif zone.name == "Havana" then
                    tavernName = "La Cantina del Rey"
                    tavernDescription = "An elegant Spanish tavern with fine wines.\nHear rumors about Spanish treasure fleets here."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tavernName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.tavern then
            love.graphics.printf(tavernDescription, 0, 150, self.width, "center")
        end
        
        -- Draw buttons for tavern screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "shipyard" then
        -- Get current location for shipyard name
        local currentZoneIndex = gameState.ship.currentZone
        local shipyardName = "Port Royal Shipyard"
        local shipyardDescription = "The shipyard is busy with workers repairing vessels.\nHere you can upgrade your ship or purchase a new one."
        
        -- Set location-specific shipyard names
        if currentZoneIndex and currentZoneIndex > 0 then
            local Map = require('map')
            local zone = Map:getZone(currentZoneIndex)
            if zone then
                if zone.name == "Havana" then
                    shipyardName = "Havana Naval Yards"
                    shipyardDescription = "A Spanish shipyard specializing in galleons.\nSpanish vessels are sturdy but more expensive."
                elseif zone.name == "Crown Colony" then
                    shipyardName = "Royal Navy Dockyard"
                    shipyardDescription = "A military shipyard with British vessels.\nStrict regulations, but high-quality ships available."
                end
            end
        end
        
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(shipyardName, 0, 50, self.width, "center")
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.shipyard then
            love.graphics.printf(shipyardDescription, 0, 150, self.width, "center")
        end
        
        -- Draw buttons for shipyard screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "crew" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Crew Management", 0, 100, self.width, "center")
        
        -- Draw crew info
        love.graphics.printf("Crew Size: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 150, self.width, "center")
        love.graphics.printf("Crew Morale: " .. gameState.crew.morale .. "/10", 0, 180, self.width, "center")
        
        -- List crew members
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        local yPos = 220
        for i, member in ipairs(gameState.crew.members) do
            love.graphics.print(i .. ". " .. member.name .. " - " .. member.role, 300, yPos)
            yPos = yPos + 30
        end
        
        -- Draw buttons for crew screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "inventory" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Inventory", 0, 100, self.width, "center")
        
        -- Draw inventory info
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print("Gold: " .. gameState.resources.gold, 300, 150)
        love.graphics.print("Rum: " .. gameState.resources.rum, 300, 180)
        love.graphics.print("Timber: " .. gameState.resources.timber, 300, 210)
        love.graphics.print("Gunpowder: " .. gameState.resources.gunpowder, 300, 240)
        
        -- Draw buttons for inventory screen
        self:drawButtons(currentScreen)
    end
end

-- Helper function to draw background
function PortRoyal:drawBackground(screen)
    -- Set color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Get current location
    local currentZoneIndex = nil
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if _G.gameState and _G.gameState.ship then
        currentZoneIndex = _G.gameState.ship.currentZone
    end
    
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
        end
    end
    
    -- Try to load location-specific background if available
    local locationKey = currentZoneName:lower():gsub("%s+", "_")
    local locationBackground = nil
    
    if screen == "main" then
        local success, result = pcall(function()
            return love.graphics.newImage("assets/" .. locationKey .. "_main.png")
        end)
        if success then
            locationBackground = result
        end
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        love.graphics.draw(locationBackground, 0, 0)
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        love.graphics.draw(self.backgrounds.main, 0, 0)
    elseif screen == "tavern" and self.backgrounds.tavern then
        love.graphics.draw(self.backgrounds.tavern, 0, 0)
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        love.graphics.draw(self.backgrounds.shipyard, 0, 0)
    else
        -- Draw a fallback colored background
        if screen == "main" then
            -- Based on zone type (could become more sophisticated)
            if currentZoneName == "Port Royal" then
                love.graphics.setColor(0.2, 0.3, 0.5, 1)  -- Deep blue for Port Royal
            elseif currentZoneName:find("Waters") then
                love.graphics.setColor(0.2, 0.4, 0.5, 1)  -- Different blue for waters
            elseif currentZoneName == "Nassau" or currentZoneName == "Havana" then
                love.graphics.setColor(0.5, 0.3, 0.2, 1)  -- Brown for settlements
            else
                love.graphics.setColor(0.3, 0.3, 0.4, 1)  -- Default color
            end
        elseif screen == "tavern" then
            love.graphics.setColor(0.3, 0.2, 0.1, 1)  -- Brown for tavern
        elseif screen == "shipyard" then
            love.graphics.setColor(0.4, 0.4, 0.5, 1)  -- Grey for shipyard
        elseif screen == "crew" then
            love.graphics.setColor(0.2, 0.3, 0.4, 1)  -- Navy for crew
        elseif screen == "inventory" then
            love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Grey for inventory
        end
        
        -- Fill background
        love.graphics.rectangle("fill", 0, 0, self.width, self.height)
    end
end

-- Helper function to draw buttons
function PortRoyal:drawButtons(screen)
    -- Only draw buttons for the current screen
    if not self.buttons[screen] then
        return
    end
    
    -- Position the "Back to Port" button at the bottom for non-main screens
    if screen ~= "main" and #self.buttons[screen] == 1 and 
       self.buttons[screen][1].text == "Back to Port" then
        self.buttons[screen][1].y = 520
    end
    
    for _, button in ipairs(self.buttons[screen]) do
        -- Draw button background
        love.graphics.setColor(0.4, 0.4, 0.6, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button border
        love.graphics.setColor(0.6, 0.6, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(button.text)
        local textHeight = font:getHeight()
        love.graphics.print(
            button.text,
            button.x + (button.width/2) - (textWidth/2),
            button.y + (button.height/2) - (textHeight/2)
        )
    end
end

-- Handle mouse movement
function PortRoyal:mousemoved(x, y, gameState)
    -- Could implement hover effects for buttons here
end

-- Handle mouse clicks
function PortRoyal:mousepressed(x, y, button, gameState)
    if button ~= 1 then  -- Only process left clicks
        return
    end
    
    local currentScreen = gameState.settings.currentPortScreen
    
    -- Print debug info
    if gameState.settings.debug then
        print("Port Royal screen click at: " .. x .. ", " .. y .. " on screen: " .. currentScreen)
    end
    
    -- Check if any button was clicked
    if self.buttons[currentScreen] then
        for i, btn in ipairs(self.buttons[currentScreen]) do
            if x >= btn.x and x <= btn.x + btn.width and
               y >= btn.y and y <= btn.y + btn.height then
                -- Button was clicked, execute its action
                if btn.action then
                    if gameState.settings.debug then
                        print("Button clicked: " .. btn.text)
                    end
                    btn.action()
                end
                return
            end
        end
    end
end

return PortRoyal