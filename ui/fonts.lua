-- Font cache. Display = Lilita One (headings, numbers, buttons, card names).
-- Body = Nunito Black (ability text, toasts, hints).
local Fonts = {}

local DISPLAY = "assets/fonts/LilitaOne-Regular.ttf"
local BODY    = "assets/fonts/Nunito-Black.ttf"

local _display, _body = {}, {}

local function load(cache, path, size)
    size = math.max(6, math.floor(size + 0.5))
    if cache[size] then return cache[size] end
    local ok, f = pcall(love.graphics.newFont, path, size)
    if not ok then f = love.graphics.newFont(size) end
    f:setFilter("linear", "linear")
    cache[size] = f
    return f
end

function Fonts.get(size)  return load(_display, DISPLAY, size) end
function Fonts.body(size) return load(_body, BODY, size) end

local function with(font, fn)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    fn()
    love.graphics.setFont(prev)
end

function Fonts.with(size, fn)     with(Fonts.get(size), fn) end
function Fonts.withBody(size, fn) with(Fonts.body(size), fn) end

return Fonts
