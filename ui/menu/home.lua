-- Home screen: bobbing FOOTBALL TCG logo with a football badge, and PLAY / CARD LIBRARY /
-- QUIT buttons. Layout is pure (unit-tested); update/draw use LÖVE.
-- Keyboard focus comes from ui/menu/flow.lua (passed into update).
local Theme    = require("ui.theme")
local Fonts    = require("ui.fonts")
local Draw     = require("ui.kit.draw")
local Icons    = require("ui.kit.icons")
local Button   = require("ui.kit.button")
local Backdrop = require("ui.menu.backdrop")

local HomeMenu = {}

HomeMenu.W, HomeMenu.H = 1280, 800
HomeMenu.BTN_W, HomeMenu.BTN_H, HomeMenu.BTN_GAP, HomeMenu.BTN_Y = 320, 72, 22, 352
HomeMenu.LOGO_Y, HomeMenu.LOGO_SIZE = 130, 92
HomeMenu.ITEMS = {
    { id = "play",    label = "PLAY",         variant = "primary", fontSize = 38 },
    { id = "library", label = "CARD LIBRARY", variant = "blue",    fontSize = 28 },
    { id = "quit",    label = "QUIT",         variant = "danger",  fontSize = 28 },
}

function HomeMenu.buttonRect(i)
    return {
        x = (HomeMenu.W - HomeMenu.BTN_W) / 2,
        y = HomeMenu.BTN_Y + (i - 1) * (HomeMenu.BTN_H + HomeMenu.BTN_GAP),
        w = HomeMenu.BTN_W, h = HomeMenu.BTN_H,
    }
end

-- Index of the button under (x, y), or nil.
function HomeMenu.buttonAt(x, y)
    for i = 1, #HomeMenu.ITEMS do
        local r = HomeMenu.buttonRect(i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

-- Logo vertical bob (px) at time t.
function HomeMenu.bob(t) return math.sin(t * 2.2) * 6 end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local buttons, time = nil, 0

local function ensure()
    if buttons then return end
    buttons = {}
    for i, it in ipairs(HomeMenu.ITEMS) do
        local r = HomeMenu.buttonRect(i)
        buttons[i] = Button.new({ id = it.id, label = it.label, variant = it.variant, fontSize = it.fontSize,
            x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

-- focus: index of the keyboard-focused button (pulsing glow).
function HomeMenu.update(dt, mx, my, focus)
    ensure()
    time = time + dt
    local down = love.mouse.isDown(1)
    for i, b in ipairs(buttons) do
        b.focused = (i == focus)
        b:update(dt, mx or -1, my or -1, down)
    end
end

-- Word shifted right so the football badge + word are centred as a group.
local function drawLogo(t)
    local W, size = HomeMenu.W, HomeMenu.LOGO_SIZE
    local y = HomeMenu.LOGO_Y + HomeMenu.bob(t)
    local text = "FOOTBALL TCG"
    local tw = Fonts.get(size):getWidth(text)
    local shift = 46
    -- navy drop shadow of the outlined word, then the yellow word with a white outline
    Draw.text(text, shift, y + 8, W, "center", { size = size, color = Theme.ink, outline = 5, outlineColor = Theme.ink })
    Draw.text(text, shift, y, W, "center", {
        size = size, color = Theme.highlight.selected, outline = 5, outlineColor = Theme.white,
    })
    local bx, by = W / 2 - tw / 2 - 8, y + size * 0.52
    Draw.setColor(Theme.ink);   love.graphics.circle("fill", bx, by + 6, 38, 40)
    Draw.setColor(Theme.white); love.graphics.circle("fill", bx, by, 38, 40)
    Icons.draw("soccer-ball", bx, by, 62, Theme.inkText, 0)
end

function HomeMenu.draw()
    ensure()
    local W, H = HomeMenu.W, HomeMenu.H
    Backdrop.draw(time, W, H)
    drawLogo(time)
    for _, b in ipairs(buttons) do b:draw() end
    Draw.text("ARROW KEYS + ENTER  ·  CLICK  ·  ESC TO QUIT", 0, H - 44, W, "center", {
        size = 14, body = true, color = { 1, 1, 1, 0.85 }, shadowY = 1,
    })
end

return HomeMenu
