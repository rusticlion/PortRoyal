-- Asset Utilities Module
-- Centralizes asset loading with better error handling

local AssetUtils = {}

-- Asset types
AssetUtils.ASSET_TYPE = {
    SHIP = "ship",
    MAP = "map",
    UI = "ui",
    DICE = "dice",
    FONT = "font"
}

-- Default placeholder images for different asset types
local DEFAULT_PLACEHOLDERS = {
    ship = {r = 0.2, g = 0.5, b = 0.8}, -- Blue rectangle for ships
    map = {r = 0.1, g = 0.3, b = 0.2},  -- Green rectangle for map elements
    ui = {r = 0.4, g = 0.4, b = 0.4},   -- Gray rectangle for UI elements
    dice = {r = 0.7, g = 0.7, b = 0.2}, -- Yellow rectangle for dice
    font = {r = 0.5, g = 0.3, b = 0.6}  -- Purple for fonts
}

-- Tables to store loaded assets for reference
AssetUtils.loadedAssets = {}
AssetUtils.loadedFonts = {}

-- Load an image with error handling
-- @param filePath - The path to the image file
-- @param assetType - Type of asset (ship, map, ui, dice) for fallback coloring
-- @return The loaded image or nil if loading failed
function AssetUtils.loadImage(filePath, assetType)
    -- Validate inputs
    if not filePath then
        print("ERROR: No file path provided to AssetUtils.loadImage")
        return nil
    end
    
    -- Normalize asset type
    assetType = assetType or "ui"
    
    -- Check if we've already loaded this asset
    if AssetUtils.loadedAssets[filePath] then
        return AssetUtils.loadedAssets[filePath]
    end
    
    -- Try to load the image
    local success, result = pcall(function() 
        return love.graphics.newImage(filePath)
    end)
    
    -- Handle the result
    if success then
        -- Store the loaded image for future reference
        AssetUtils.loadedAssets[filePath] = result
        return result
    else
        -- Print detailed error message
        print("ERROR: Failed to load asset: " .. filePath)
        print("Reason: " .. tostring(result))
        return nil
    end
end

-- Load a font with error handling
-- @param filePath - The path to the font file
-- @param size - The font size (default: 16)
-- @return The loaded font or nil if loading failed
function AssetUtils.loadFont(filePath, size)
    -- Validate inputs
    if not filePath then
        print("ERROR: No file path provided to AssetUtils.loadFont")
        return nil
    end
    
    size = size or 16
    
    -- Create cache key (filepath + size)
    local cacheKey = filePath .. "_" .. size
    
    -- Check if we've already loaded this font at this size
    if AssetUtils.loadedFonts[cacheKey] then
        return AssetUtils.loadedFonts[cacheKey]
    end
    
    -- Try to load the font
    local success, result = pcall(function() 
        return love.graphics.newFont(filePath, size)
    end)
    
    -- Handle the result
    if success then
        -- Store the loaded font for future reference
        AssetUtils.loadedFonts[cacheKey] = result
        print("Successfully loaded font: " .. filePath .. " at size " .. size)
        return result
    else
        -- Print detailed error message
        print("ERROR: Failed to load font: " .. filePath)
        print("Reason: " .. tostring(result))
        return nil
    end
end

-- Draw a placeholder rectangle for a missing asset
-- @param x, y - Position to draw at
-- @param width, height - Dimensions of the placeholder
-- @param assetType - Type of asset (ship, map, ui, dice) for coloring
function AssetUtils.drawPlaceholder(x, y, width, height, assetType)
    -- Get placeholder color based on asset type
    local colorDef = DEFAULT_PLACEHOLDERS[assetType] or DEFAULT_PLACEHOLDERS.ui
    
    -- Save current color
    local r, g, b, a = love.graphics.getColor()
    
    -- Draw the placeholder
    love.graphics.setColor(colorDef.r, colorDef.g, colorDef.b, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw a border
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw a missing texture pattern
    love.graphics.setColor(1, 0, 1, 0.5) -- Magenta
    love.graphics.line(x, y, x + width, y + height)
    love.graphics.line(x + width, y, x, y + height)
    
    -- Restore original color
    love.graphics.setColor(r, g, b, a)
end

-- Safely draw an image, with fallback to placeholder if image is nil
-- @param image - The image to draw
-- @param x, y - Position to draw at
-- @param angle, sx, sy - Rotation and scale (optional)
-- @param width, height - Dimensions for placeholder if image is nil
-- @param assetType - Type of asset for placeholder coloring
function AssetUtils.drawImage(image, x, y, angle, sx, sy, width, height, assetType)
    if image then
        love.graphics.draw(image, x, y, angle or 0, sx or 1, sy or 1)
    else
        -- Draw placeholder if image is nil
        AssetUtils.drawPlaceholder(x, y, width or 32, height or 32, assetType)
    end
end

return AssetUtils