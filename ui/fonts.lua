-- Shared pixel font loader — m6x11 primary, SF Pro / built-in fallback.
local Fonts = {}
local _cache = {}

local function tryLoad(path, size)
    local ok, f = pcall(love.graphics.newFont, path, size)
    return ok and f or nil
end

function Fonts.get(size)
    if _cache[size] then return _cache[size] end
    local f = tryLoad("assets/fonts/m6x11.ttf", size)
    if not f then
        for _, p in ipairs({
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/SFNSText.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        }) do
            f = tryLoad(p, size)
            if f then break end
        end
    end
    f = f or love.graphics.newFont(size)
    _cache[size] = f
    return f
end

-- Convenience wrapper: set font, call fn, restore previous font.
function Fonts.with(size, fn)
    local prev = love.graphics.getFont()
    love.graphics.setFont(Fonts.get(size))
    fn()
    love.graphics.setFont(prev)
end

return Fonts
