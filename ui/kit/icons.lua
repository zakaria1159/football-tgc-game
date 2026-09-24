-- Icons from game-icons.net (CC BY 3.0), white-on-transparent PNGs in assets/icons/.
local Theme = require("ui.theme")

local Icons = {}

local BY_TYPE = {
    striker    = "soccer-kick",
    defender   = "checked-shield",
    midfielder = "on-target",
    keeper     = "goal-keeper",
    trap       = "wolf-trap",
    strategy   = "whistle",
    formation  = "soccer-field",
}
local FALLBACK = "soccer-ball"

function Icons.forType(cardType)
    return BY_TYPE[cardType] or FALLBACK
end

local _cache = {}
function Icons.get(name)
    if _cache[name] ~= nil then return _cache[name] or nil end
    local ok, img = pcall(love.graphics.newImage, "assets/icons/" .. name .. ".png", { mipmaps = true })
    if ok then
        img:setFilter("linear", "linear")
        img:setMipmapFilter("linear")
        _cache[name] = img
        return img
    end
    _cache[name] = false
    return nil
end

-- Draw icon centered at cx,cy scaled to `size` px, tinted `color`, with a hard ink shadow.
function Icons.draw(name, cx, cy, size, color, shadowY, alpha)
    local img = Icons.get(name)
    if not img then return end
    alpha = alpha or 1
    local iw = img:getWidth()
    local s  = size / iw
    local ox = iw / 2
    shadowY = shadowY or math.max(1, math.floor(size * 0.05))
    if shadowY > 0 then
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35 * alpha)
        love.graphics.draw(img, cx, cy + shadowY, 0, s, s, ox, ox)
    end
    local c = color or Theme.white
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
    love.graphics.draw(img, cx, cy, 0, s, s, ox, ox)
end

return Icons
