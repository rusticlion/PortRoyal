-- Port Interface Module
-- Currently focused on Port Royal but can be extended to all locations

local AssetUtils = require('utils.assetUtils')
local fonts = nil

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
    
    -- Currently displayed crew (loaded dynamically based on location)
    availableCrew = {},
    
    -- Tavern status indicators
    tavernMessage = nil,
    tavernMessageTimer = 0,
}

-- Initialize Port interface
function PortRoyal:load(gameState)
    -- Store reference to fonts
    fonts = gameState.fonts
    
    -- Main screen buttons will be generated dynamically based on location
    self.buttons.main = {}
    
    -- Initialize buttons for tavern screen (just the back button initially)
    self.buttons.tavern = {
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() 
                gameState.settings.currentPortScreen = "main" 
                -- Clear crew list when leaving tavern
                self.availableCrew = {}
            end
        }
    }
    
    -- Initialize buttons for shipyard screen
    self.buttons.shipyard = {
        {
            text = "Repair Ship",
            x = 325,
            y = 300,
            width = 150,
            height = 50,
            action = function() 
                -- For now, just display a message that repairs aren't available yet
                print("Ship repairs not yet implemented")
                self.shipyardMessage = "Ship repairs will be available in a future update."
                self.shipyardMessageTimer = 3  -- Show message for 3 seconds
            end
        },
        {
            text = "Back to Port",
            x = 325,
            y = 500,
            width = 150,
            height = 50,
            action = function() gameState.settings.currentPortScreen = "main" end
        }
    }
    
    -- Variables for shipyard message display
    self.shipyardMessage = nil
    self.shipyardMessageTimer = 0
    
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
    
    -- Validate required parameters
    assert(gameState, "gameState is required for PortRoyal:load")
    
    -- Load placeholder background images using AssetUtils
    self.backgrounds.main = AssetUtils.loadImage("assets/port_royal_main.png", "ui")
    if self.backgrounds.main then
        print("Port Royal main background loaded")
    end
    
    -- Load tavern background
    self.backgrounds.tavern = AssetUtils.loadImage("assets/port-royal-tavern.png", "ui")
    if self.backgrounds.tavern then
        print("Port Royal tavern background loaded")
    end
    
    -- Load shipyard background
    self.backgrounds.shipyard = AssetUtils.loadImage("assets/port-royal-shipyard.png", "ui")
    if self.backgrounds.shipyard then
        print("Port Royal shipyard background loaded")
    end
end

-- Update Port interface
function PortRoyal:update(dt, gameState)
    -- Generate location-specific buttons if needed
    self:generateLocationButtons(gameState)
    
    -- Load crew members for the current location if entering tavern
    local currentScreen = gameState.settings.currentPortScreen
    if currentScreen == "tavern" and #self.availableCrew == 0 then
        self:loadAvailableCrewForLocation(gameState)
    end
    
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
    
    -- Update shipyard message timer
    if self.shipyardMessage and self.shipyardMessageTimer > 0 then
        self.shipyardMessageTimer = self.shipyardMessageTimer - dt
        if self.shipyardMessageTimer <= 0 then
            self.shipyardMessage = nil
        end
    end
    
    -- Update tavern message timer
    if self.tavernMessage and self.tavernMessageTimer > 0 then
        self.tavernMessageTimer = self.tavernMessageTimer - dt
        if self.tavernMessageTimer <= 0 then
            self.tavernMessage = nil
        end
    end
end

-- Load crew members available at the current location
function PortRoyal:loadAvailableCrewForLocation(gameState)
    -- Clear current list
    self.availableCrew = {}
    
    -- Get current location
    local currentZoneIndex = gameState.ship.currentZone
    local currentZoneName = "Unknown Location"
    
    -- Look up location info
    if currentZoneIndex and currentZoneIndex > 0 then
        local Map = require('map')
        local zone = Map:getZone(currentZoneIndex)
        if zone then
            currentZoneName = zone.name
            
            -- Get available crew at this location
            self.availableCrew = gameState:getAvailableCrewAtLocation(currentZoneName)
            
            -- Update the tavern buttons for these crew members
            self:updateTavernButtons(gameState, currentZoneName)
        end
    end
end

-- Update the tavern buttons for the available crew members
function PortRoyal:updateTavernButtons(gameState, locationName)
    -- Keep the back button (it should be the last button)
    local backButton = self.buttons.tavern[#self.buttons.tavern]
    
    -- Clear all other buttons
    self.buttons.tavern = {}
    
    -- Add hire buttons for each available crew member
    for i, crew in ipairs(self.availableCrew) do
        table.insert(self.buttons.tavern, {
            text = "Hire for " .. crew.cost .. " gold",
            x = 500,
            y = 190 + (i-1) * 100 + 20,
            width = 200,
            height = 40,
            crewId = crew.id,  -- Store crew ID for hiring
            action = function()
                -- Check if can afford the crew member
                if not gameState:canAfford("gold", crew.cost) then
                    self.tavernMessage = "Not enough gold to hire " .. crew.name
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Check if crew is full
                if #gameState.crew.members >= gameState.ship.crewCapacity then
                    self.tavernMessage = "Ship crew capacity reached"
                    self.tavernMessageTimer = 3
                    return
                end
                
                -- Hire the crew member
                gameState:spendResources("gold", crew.cost)
                
                -- Create a copy of the crew member to add to the player's crew
                local newCrewMember = {
                    id = crew.id,
                    name = crew.name,
                    role = crew.role,
                    skill = crew.skill,
                    loyalty = crew.loyalty,
                    health = crew.health
                }
                
                -- Add to player's crew
                gameState:addCrewMember(newCrewMember)
                
                -- Remove from location
                gameState:removeCrewFromLocation(crew.id, locationName)
                
                -- Success message
                self.tavernMessage = crew.name .. " hired successfully!"
                self.tavernMessageTimer = 3
                
                -- Update available crew and buttons
                self.availableCrew = gameState:getAvailableCrewAtLocation(locationName)
                self:updateTavernButtons(gameState, locationName)
            end
        })
    end
    
    -- Add back button
    table.insert(self.buttons.tavern, backButton)
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
        love.graphics.setFont(fonts.title)
        love.graphics.printf(currentZoneName .. " Harbor", 0, 100, self.width, "center")
        love.graphics.setFont(fonts.default)
        
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
        love.graphics.setFont(fonts.title)
        love.graphics.printf(tavernName, 0, 50, self.width, "center")
        love.graphics.setFont(fonts.default)
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.tavern then
            love.graphics.printf(tavernDescription, 0, 120, self.width, "center")
        end
        
        -- Draw available crew for hire
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Available Crew for Hire:", 0, 160, self.width, "center")
        
        -- Draw table header
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print("Name", 100, 190)
        love.graphics.print("Role", 250, 190)
        love.graphics.print("Stats", 350, 190)
        
        -- Draw available crew members
        for i, crew in ipairs(self.availableCrew) do
            local yPos = 190 + (i-1) * 100  -- Increased vertical spacing
            
            -- Background panel for each crew member (including hire button area)
            love.graphics.setColor(0.2, 0.2, 0.3, 0.6)
            love.graphics.rectangle("fill", 90, yPos, 620, 80)
            love.graphics.setColor(0.4, 0.4, 0.5, 0.8)
            love.graphics.rectangle("line", 90, yPos, 620, 80)
            
            -- Display crew info
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(crew.name, 100, yPos + 10)
            
            -- Color code the role to match the crew management screen
            if crew.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            elseif crew.role == "Gunner" then
                love.graphics.setColor(1, 0.7, 0.7, 1)  -- Red for gunners
            elseif crew.role == "Surgeon" then
                love.graphics.setColor(0.7, 0.7, 1, 1)  -- Blue for surgeons
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(crew.role, 250, yPos + 10)
            
            -- Display crew stats
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print("Skill: " .. crew.skill, 350, yPos + 10)
            love.graphics.print("Loyalty: " .. crew.loyalty, 350, yPos + 30)
            love.graphics.print("Health: " .. crew.health, 350, yPos + 50)
            
            -- Display hire cost
            love.graphics.setColor(1, 0.9, 0.2, 1)
            love.graphics.print("Cost: " .. crew.cost .. " gold", 100, yPos + 50)
            
            -- Draw integrated hire button (right side of panel)
            love.graphics.setColor(0.3, 0.5, 0.7, 0.9)
            love.graphics.rectangle("fill", 500, yPos + 20, 200, 40)
            love.graphics.setColor(0.5, 0.7, 0.9, 1)
            love.graphics.rectangle("line", 500, yPos + 20, 200, 40)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Hire for " .. crew.cost .. " gold", 500, yPos + 33, 200, "center")
        end
        
        -- Show player's current gold
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.printf("Your gold: " .. gameState.resources.gold, 0, 440, self.width, "center")
        
        -- Display crew capacity
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Ship Crew: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 470, self.width, "center")
        
        -- Display tavern message if active
        if self.tavernMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.tavernMessage, 150, 390, 500, "center")
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
        love.graphics.setFont(fonts.title)
        love.graphics.printf(shipyardName, 0, 50, self.width, "center")
        love.graphics.setFont(fonts.default)
        
        -- If the background image doesn't include text, draw it manually
        if not self.backgrounds.shipyard then
            love.graphics.printf(shipyardDescription, 0, 150, self.width, "center")
        end
        
        -- Draw current ship status
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.printf("Current Ship: " .. gameState.ship.name .. " (" .. gameState.ship.class .. ")", 0, 220, self.width, "center")
        love.graphics.printf("Hull Durability: " .. gameState.ship.durability .. "/10", 0, 250, self.width, "center")
        
        -- Draw shipyard message if active
        if self.shipyardMessage then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 150, 380, 500, 40)
            love.graphics.setColor(1, 1, 0, 1)
            love.graphics.printf(self.shipyardMessage, 150, 390, 500, "center")
        end
        
        -- Draw buttons for shipyard screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "crew" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.title)
        love.graphics.printf("Crew Management", 0, 70, self.width, "center")
        love.graphics.setFont(fonts.default)
        
        -- Draw crew info
        love.graphics.setColor(0.7, 0.85, 1, 1)
        love.graphics.printf("Crew Size: " .. #gameState.crew.members .. "/" .. gameState.ship.crewCapacity, 0, 110, self.width, "center")
        love.graphics.printf("Crew Morale: " .. gameState.crew.morale .. "/10", 0, 140, self.width, "center")
        
        -- Draw crew table headers
        love.graphics.setColor(1, 0.9, 0.7, 1)
        love.graphics.print("Name", 130, 180)
        love.graphics.print("Role", 300, 180)
        love.graphics.print("Skill", 450, 180)
        love.graphics.print("Loyalty", 520, 180)
        love.graphics.print("Health", 600, 180)
        
        -- Draw table separator
        love.graphics.setColor(0.6, 0.6, 0.7, 1)
        love.graphics.line(120, 200, 680, 200)
        
        -- List crew members with stats in a table format
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        local yPos = 210
        for i, member in ipairs(gameState.crew.members) do
            -- Highlight navigator role for ticket 2-6 visibility
            if member.role == "Navigator" then
                love.graphics.setColor(0.7, 1, 0.7, 1)  -- Green for navigators
            else
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            end
            
            love.graphics.print(member.name, 130, yPos)
            love.graphics.print(member.role, 300, yPos)
            love.graphics.print(member.skill or 1, 450, yPos)
            love.graphics.print(member.loyalty or 5, 520, yPos)
            love.graphics.print(member.health or 10, 600, yPos)
            
            -- Draw separator between crew members
            love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            
            yPos = yPos + 40
        end
        
        -- Draw empty slots if not at capacity
        for i = #gameState.crew.members + 1, gameState.ship.crewCapacity do
            love.graphics.setColor(0.4, 0.4, 0.5, 0.5)
            love.graphics.print("Empty slot", 130, yPos)
            love.graphics.line(120, yPos + 25, 680, yPos + 25)
            yPos = yPos + 40
        end
        
        -- Draw role effects information
        love.graphics.setColor(0.9, 0.8, 0.6, 1)
        love.graphics.printf("Crew Role Effects:", 150, 400, 500, "center")
        
        love.graphics.setColor(0.7, 1, 0.7, 1)
        love.graphics.printf("Navigator: Reduces travel time between zones by 0.5 weeks", 150, 430, 500, "center")
        
        -- Draw buttons for crew screen
        self:drawButtons(currentScreen)
    
    elseif currentScreen == "inventory" then
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(fonts.title)
        love.graphics.printf("Inventory", 0, 70, self.width, "center")
        love.graphics.setFont(fonts.default)
        
        -- Draw resources section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Resources:", 100, 120, 200, "left")
        
        -- Draw resources
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.print("Gold: " .. gameState.resources.gold, 120, 150)
        love.graphics.print("Rum: " .. gameState.resources.rum, 120, 180)
        love.graphics.print("Timber: " .. gameState.resources.timber, 120, 210)
        love.graphics.print("Gunpowder: " .. gameState.resources.gunpowder, 120, 240)
        
        -- Draw cargo slots section
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Cargo Slots:", 400, 120, 200, "left")
        
        -- Draw cargo slots (10 slots)
        local slotSize = 50
        local startX = 400
        local startY = 150
        local cols = 5
        
        for i = 1, 10 do
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            local x = startX + col * (slotSize + 10)
            local y = startY + row * (slotSize + 10)
            
            -- Draw slot background
            love.graphics.setColor(0.2, 0.2, 0.3, 1)
            love.graphics.rectangle("fill", x, y, slotSize, slotSize)
            
            -- Draw slot border
            love.graphics.setColor(0.4, 0.4, 0.5, 1)
            love.graphics.rectangle("line", x, y, slotSize, slotSize)
            
            -- Draw slot content if any
            local slot = gameState.inventory.slots[i]
            if slot and slot.item then
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
                love.graphics.printf(slot.item, x, y + 10, slotSize, "center")
                love.graphics.printf(slot.quantity, x, y + 30, slotSize, "center")
            else
                -- Draw empty slot number
                love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
                love.graphics.printf(i, x + 15, y + 15, 20, "center")
            end
        end
        
        -- Debug button for adding resources (if debug mode enabled)
        if gameState.settings.debug then
            love.graphics.setColor(0.3, 0.6, 0.3, 1)
            love.graphics.rectangle("fill", 120, 270, 150, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("+ 10 of each resource", 120, 275, 150, "center")
        end
        
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
        -- Use AssetUtils to load the location-specific background
        locationBackground = AssetUtils.loadImage("assets/" .. locationKey .. "_main.png", "ui")
    end
    
    -- Check if we have a background image for this screen
    if locationBackground then
        -- We have a location-specific background
        AssetUtils.drawImage(locationBackground, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "main" and self.backgrounds.main then
        -- Fall back to generic port background
        AssetUtils.drawImage(self.backgrounds.main, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "tavern" and self.backgrounds.tavern then
        AssetUtils.drawImage(self.backgrounds.tavern, 0, 0, 0, 1, 1, self.width, self.height, "ui")
    elseif screen == "shipyard" and self.backgrounds.shipyard then
        AssetUtils.drawImage(self.backgrounds.shipyard, 0, 0, 0, 1, 1, self.width, self.height, "ui")
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
        love.graphics.setFont(fonts.default)
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
    
    -- Special handling for inventory debug button
    if currentScreen == "inventory" and gameState.settings.debug then
        if x >= 120 and x <= 270 and y >= 270 and y <= 300 then
            -- Debug button for adding resources
            gameState.resources.gold = gameState.resources.gold + 10
            gameState.resources.rum = gameState.resources.rum + 10
            gameState.resources.timber = gameState.resources.timber + 10
            gameState.resources.gunpowder = gameState.resources.gunpowder + 10
            print("DEBUG: Added 10 of each resource")
            return
        end
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