-- Pause menu: navy dim, a white sticker panel that pops in with a bounce, a PAUSED ribbon,
-- and RESUME / CARD LIBRARY / QUIT TO MENU. Layout, focus and input mapping are pure
-- (unit-tested); update/draw use LÖVE. Actions: "resume" | "library" | "home".
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Button = require("ui.kit.button")
local Tween  = require("ui.kit.tween")
local Nav    = require("ui.menu.nav")

local Pause = {}

Pause.ITEMS = {
    { action = "resume",  label = "RESUME",       variant = "go"     },
    { action = "library", label = "CARD LIBRARY", variant = "blue"   },
    { action = "home",    label = "QUIT TO MENU", variant = "danger" },
}
Pause.PANEL = { x = 440, y = 232, w = 400, h = 336 }
Pause.BTN_W, Pause.BTN_H, Pause.BTN_GAP, Pause.BTN_TOP = 300, 64, 20, 64

function Pause.buttonRect(i)
    local P = Pause.PANEL
    return { x = P.x + (P.w - Pause.BTN_W) / 2, y = P.y + Pause.BTN_TOP + (i - 1) * (Pause.BTN_H + Pause.BTN_GAP),
             w = Pause.BTN_W, h = Pause.BTN_H }
end

function Pause.indexAt(x, y)
    for i = 1, #Pause.ITEMS do
        local r = Pause.buttonRect(i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

function Pause.actionAt(x, y)
    local i = Pause.indexAt(x, y)
    return i and Pause.ITEMS[i].action or nil
end

local nav       = Nav.new(#Pause.ITEMS, { wrap = true })
local pop       = { scale = 1 }
local buttons   = nil
local lastHover = nil

-- Call whenever the menu opens: resets focus and replays the pop-in.
function Pause.open()
    nav = Nav.new(#Pause.ITEMS, { wrap = true })
    lastHover = nil
    Tween.popIn(pop, 0.35)
end

function Pause.focus() return nav.index end

function Pause.keypressed(key)
    if key == "escape" then return "resume" end
    if key == "up" then
        nav:move(-1)
    elseif key == "down" then
        nav:move(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        return Pause.ITEMS[nav.index].action
    end
    return nil
end

function Pause.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    return Pause.actionAt(x, y)
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local function ensure()
    if buttons then return end
    buttons = {}
    for i, it in ipairs(Pause.ITEMS) do
        local r = Pause.buttonRect(i)
        buttons[i] = Button.new({ id = it.action, label = it.label, variant = it.variant, fontSize = 28,
            x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

function Pause.update(dt, mx, my)
    ensure()
    local hovered = Pause.indexAt(mx or -1, my or -1)
    if hovered ~= lastHover then
        lastHover = hovered
        if hovered then nav:set(hovered) end
    end
    local down = love.mouse.isDown(1)
    for i, b in ipairs(buttons) do
        b.focused = (i == nav.index)
        b:update(dt, mx or -1, my or -1, down)
    end
end

function Pause.draw()
    ensure()
    local P = Pause.PANEL
    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, 1280, 800)
    local cx, cy = P.x + P.w / 2, P.y + P.h / 2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(pop.scale, pop.scale)
    love.graphics.translate(-cx, -cy)
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 26, fill = Theme.white, border = 0, shadow = 8 })
    Draw.ribbon(cx, P.y - 30, 280, 60, "PAUSED", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 38,
    })
    for _, b in ipairs(buttons) do b:draw() end
    love.graphics.pop()
    Draw.text("ESC TO RESUME", 0, P.y + P.h + 22, 1280, "center", {
        size = 14, body = true, color = Theme.white, shadowY = 1,
    })
end

return Pause
