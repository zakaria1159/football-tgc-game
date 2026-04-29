local Fonts = {}
local _cache = {}

local function tryLoad(path, size)
    local ok, f = pcall(love.graphics.newFont, path, size)
    return ok and f or nil
end

function Fonts.get(size)
    if _cache[size] then return _cache[size] end
    -- Bebas Neue for display sizes; m6x11 pixel font for small labels
    local f
    if size >= 11 then
        f = tryLoad("assets/fonts/Anton-Regular.ttf", size)
    end
    if not f then
        f = tryLoad("assets/fonts/m6x11.ttf", size)
    end
    if not f then
        f = love.graphics.newFont(size)
    end
    _cache[size] = f
    return f
end

function Fonts.with(size, fn)
    local prev = love.graphics.getFont()
    love.graphics.setFont(Fonts.get(size))
    fn()
    love.graphics.setFont(prev)
end

return Fonts
