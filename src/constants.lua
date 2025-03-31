-- Game Constants
-- Centralized definitions of commonly used values

local Constants = {
    -- ============ UI LAYOUT CONSTANTS ============
    UI = {
        -- General Screen
        SCREEN_WIDTH = 800,
        SCREEN_HEIGHT = 600,
        
        -- Combat Layout
        COMBAT = {
            TOP_BAR_HEIGHT = 30,
            BOTTOM_BAR_HEIGHT = 80,
            SIDEBAR_WIDTH = 140,
            FEEDBACK_HEIGHT = 70,
            CONTROLS_HEIGHT = 50,
            INSTRUCTIONS_HEIGHT = 30,
            BUTTON_WIDTH = 160,
            BUTTON_HEIGHT = 40,
            BUTTON_SPACING = 20,
            HEX_RADIUS = 25
        }
    },
    
    -- ============ COLORS ============
    COLORS = {
        -- General UI Colors
        UI_BACKGROUND = {0.08, 0.1, 0.15, 1},  -- Very dark blue/black
        UI_PANEL = {0.15, 0.15, 0.25, 0.9},    -- Translucent dark blue
        UI_BORDER = {0.3, 0.3, 0.5, 0.8},      -- Light border
        UI_TEXT = {1, 1, 1, 0.8},              -- Soft white text
        
        -- Ship and Entity Colors
        PLAYER_SHIP = {0.2, 0.8, 0.2, 1},      -- Green for player
        ENEMY_SHIP = {0.8, 0.2, 0.2, 1},       -- Red for enemy
        HOVER = {0.8, 0.8, 0.2, 0.6},          -- Yellow for hover
        SELECTED = {0.2, 0.8, 0.8, 0.6},       -- Cyan for selected
        
        -- Action Button Colors
        BUTTON_FIRE = {0.8, 0.3, 0.3, 0.9},    -- Red for fire actions
        BUTTON_EVADE = {0.3, 0.3, 0.8, 0.9},   -- Blue for evade actions
        BUTTON_REPAIR = {0.3, 0.8, 0.3, 0.9},  -- Green for repair actions
        BUTTON_NEUTRAL = {0.7, 0.7, 0.7, 0.9}, -- Gray for neutral actions
        
        -- Resource Colors
        GOLD = {0.9, 0.8, 0.2, 1},             -- Gold color
        HEALTH = {0.2, 0.8, 0.2, 1},           -- Health green
        DAMAGE = {0.8, 0.2, 0.2, 1},           -- Damage red
        
        -- Sea and Map
        SEA = {0.1, 0.2, 0.4, 1},              -- Dark blue water
        SEA_BORDER = {0.2, 0.4, 0.6, 0.8},     -- Lighter blue border
        VALID_MOVE = {0.5, 0.7, 0.9, 0.6},     -- Light blue for valid moves
        EMPTY_WATER = {0.3, 0.5, 0.7, 0.4}     -- Blue for empty water
    },
    
    -- ============ COMBAT CONSTANTS ============
    COMBAT = {
        -- Grid Configuration
        GRID_SIZE = 10,                         -- 10x10 grid
        
        -- Action Costs
        CP_COST_FIRE = 1,                       -- Fire cannons cost 1 CP
        CP_COST_EVADE = 1,                      -- Evade costs 1 CP
        CP_COST_REPAIR = 2,                     -- Repair costs 2 CP
        
        -- Sail Point (SP) Costs
        SP_COST_MOVE_HEX = 1,                   -- Cost to move one hex
        SP_COST_ROTATE_60 = 1,                  -- Cost to rotate 60 degrees
        
        -- Damage Values
        DAMAGE_CRITICAL = 3,                    -- Critical hit damage
        DAMAGE_SUCCESS = 2,                     -- Success damage
        DAMAGE_PARTIAL = 1,                     -- Partial success damage
        
        -- Repair Values
        REPAIR_CRITICAL = 15,                   -- Critical repair amount
        REPAIR_SUCCESS = 10,                    -- Success repair amount
        REPAIR_PARTIAL = 5                      -- Partial success repair amount
    },
    
    -- ============ DICE CONSTANTS ============
    DICE = {
        SUCCESS = 6,                            -- Success on 6
        PARTIAL_MIN = 4,                        -- Partial success on 4-5
        PARTIAL_MAX = 5,                        -- Partial success on 4-5
        FAILURE_MAX = 3,                        -- Failure on 1-3
        
        -- Outcome Levels
        OUTCOME_CRITICAL = 3,                   -- Level for critical success
        OUTCOME_SUCCESS = 2,                    -- Level for success
        OUTCOME_PARTIAL = 1,                    -- Level for partial success
        OUTCOME_FAILURE = 0                     -- Level for failure
    },
    
    -- ============ CREW ROLES ============
    ROLES = {
        NAVIGATOR = "Navigator",
        GUNNER = "Gunner",
        SURGEON = "Surgeon"
    },
    
    -- ============ GAME SETTINGS ============
    GAME = {
        -- Default Resources
        DEFAULT_GOLD = 50,
        DEFAULT_RUM = 0,
        DEFAULT_TIMBER = 0,
        DEFAULT_GUNPOWDER = 0,
        
        -- Default Crew Values
        DEFAULT_MORALE = 5,                     -- Default crew morale (1-10)
        
        -- Time/Game Progress
        TOTAL_WEEKS = 72,                       -- Total game duration
        EARTHQUAKE_MIN_WEEK = 60,               -- Earliest earthquake week
        EARTHQUAKE_MAX_WEEK = 72,               -- Latest earthquake week
        
        -- Default Travel Time
        BASE_TRAVEL_TIME = 1,                   -- Base travel time (in weeks)
        MIN_TRAVEL_TIME = 0.5,                  -- Minimum travel time
        
        -- Wind Effects
        WIND_WITH = -0.5,                       -- Traveling with wind (weeks modifier)
        WIND_AGAINST = 1,                       -- Traveling against wind (weeks modifier)
        WIND_CHANGE_INTERVAL = 4,               -- How often wind might change (weeks)
        
        -- Inventory
        DEFAULT_INVENTORY_SLOTS = 10,           -- Default inventory capacity
        
        -- Crew Effects
        NAVIGATOR_TRAVEL_BONUS = -0.5,          -- Time reduction with Navigator (weeks)
        GUNNER_SKILL_MULTIPLIER = 1,            -- Multiplier for Gunner's skill level (for future balancing)
        VICTORY_LOYALTY_BONUS = 1,              -- Loyalty boost after victory
        RUM_LOYALTY_BONUS = 2,                  -- Loyalty boost from rum
        VOYAGE_LOYALTY_PENALTY = -1             -- Loyalty reduction per week at sea
    }
}

return Constants