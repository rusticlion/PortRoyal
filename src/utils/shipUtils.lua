-- Ship Stats Utility Module
-- Centralizes all ship stat lookups and calculations

local ShipUtils = {}

-- Base stats for each ship class
local SHIP_BASE_STATS = {
    sloop = {
        speed = 3,
        firepowerDice = 1,
        durability = 10,
        crewCapacity = 4,
        baseCP = 2
    },
    brigantine = {
        speed = 2,
        firepowerDice = 3,
        durability = 20,
        crewCapacity = 8,
        baseCP = 4
    },
    galleon = {
        speed = 1,
        firepowerDice = 6,
        durability = 40,
        crewCapacity = 12,
        baseCP = 6
    }
}

-- Returns the complete set of base stats for a ship class
function ShipUtils.getShipBaseStats(shipClass)
    return SHIP_BASE_STATS[shipClass] or SHIP_BASE_STATS["sloop"]
end

-- Returns maximum durability (HP) for a ship class
function ShipUtils.getMaxHP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.durability or 10
end

-- Returns base firepower dice for a ship class
function ShipUtils.getBaseFirepowerDice(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.firepowerDice or 1
end

-- Returns base movement speed for a ship class
function ShipUtils.getBaseSpeed(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.speed or 3
end

-- Returns base crew points (CP) for a ship class
function ShipUtils.getBaseCP(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.baseCP or 2
end

-- Returns crew capacity for a ship class
function ShipUtils.getCrewCapacity(shipClass)
    local stats = SHIP_BASE_STATS[shipClass]
    return stats and stats.crewCapacity or 4
end

return ShipUtils