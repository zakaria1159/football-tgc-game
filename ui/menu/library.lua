-- Card library: pill tabs per card type, a scrollable grid of hand-size cards drawn with
-- the real card renderer, and the card zoom on hover (ui/match/zoom.lua). Layout,
-- filtering and scrolling are pure (unit-tested); update/draw use LÖVE.
-- Opened full-screen from the home menu and from the pause menu.
-- keypressed / mousepressed return "close" when the library should close.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Hover    = require("ui.match.hover")
local Zoom     = require("ui.match.zoom")
local Backdrop = require("ui.menu.backdrop")

local Library = {}

Library.TABS = {
    { key = "all",        label = "ALL"         },
    { key = "striker",    label = "STRIKERS"    },
    { key = "midfielder", label = "MIDFIELDERS" },
    { key = "defender",   label = "DEFENDERS"   },
    { key = "keeper",     label = "KEEPERS"     },
    { key = "trap",       label = "TRAPS"       },
    { key = "strategy",   label = "STRATEGIES"  },
}
Library.TAB_X, Library.TAB_Y, Library.TAB_H, Library.TAB_GAP = 40, 92, 40, 10
Library.COLS, Library.CARD_W, Library.CARD_H = 7, 120, 165
Library.COL_W, Library.ROW_H, Library.GRID_X = 160, 212, 100
Library.VIEW        = { x = 0, y = 150, w = 1280, h = 650 }
Library.TOP_PAD     = 16          -- room for the type tag above the first row
Library.CLOSE       = { x = 1196, y = 24, w = 52, h = 52 }
Library.SCROLL_STEP = 60

-- ── Pure layout ───────────────────────────────────────────────────────────────

function Library.tabRects()
    local out, x = {}, Library.TAB_X
    for i, t in ipairs(Library.TABS) do
        local w = 28 + 12 * #t.label
        out[i] = { x = x, y = Library.TAB_Y, w = w, h = Library.TAB_H, key = t.key, label = t.label }
        x = x + w + Library.TAB_GAP
    end
    return out
end

function Library.tabAt(x, y)
    for _, r in ipairs(Library.tabRects()) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return r.key end
    end
    return nil
end

-- Screen rect of card i (1-based) at the given scroll offset.
function Library.cellRect(i, scroll)
    local col = (i - 1) % Library.COLS
    local row = math.floor((i - 1) / Library.COLS)
    return {
        x = Library.GRID_X + col * Library.COL_W,
        y = Library.VIEW.y + Library.TOP_PAD + row * Library.ROW_H - (scroll or 0),
        w = Library.CARD_W, h = Library.CARD_H,
    }
end

function Library.maxScroll(n)
    local rows = math.ceil(n / Library.COLS)
    return math.max(0, Library.TOP_PAD + rows * Library.ROW_H - Library.VIEW.h)
end

function Library.clampScroll(s, n)
    return math.max(0, math.min(Library.maxScroll(n), s))
end

-- Index of the card under (x, y); only inside the grid viewport.
function Library.cardAt(x, y, n, scroll)
    local V = Library.VIEW
    if y < V.y or y > V.y + V.h then return nil end
    for i = 1, n do
        local r = Library.cellRect(i, scroll)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

function Library.filter(cards, key)
    if key == "all" then return cards end
    local out = {}
    for _, c in ipairs(cards) do
        if c.type == key then out[#out + 1] = c end
    end
    return out
end

-- ── State ─────────────────────────────────────────────────────────────────────

local SOURCES = { "strikers", "midfielders", "defenders", "keepers", "traps", "strategies" }
local allDefs, filter, scroll = nil, "all", 0
local hover    = Hover.new()
local closeBtn = nil

local function allCards()
    if allDefs then return allDefs end
    allDefs = {}
    for _, f in ipairs(SOURCES) do
        for _, c in ipairs(require("engine.cards.definitions." .. f)) do allDefs[#allDefs + 1] = c end
    end
    return allDefs
end

local function visible() return Library.filter(allCards(), filter) end

local function setFilter(key)
    filter, scroll = key, 0
    hover:reset()
end

function Library.open() setFilter("all") end

-- Current tab key and scroll offset (tests, snapshot scenarios).
function Library.state() return filter, scroll end

-- ── Input ─────────────────────────────────────────────────────────────────────

function Library.keypressed(key)
    if key == "escape" then return "close" end
    local n = #visible()
    if key == "down" then
        scroll = Library.clampScroll(scroll + Library.SCROLL_STEP, n)
    elseif key == "up" then
        scroll = Library.clampScroll(scroll - Library.SCROLL_STEP, n)
    elseif key == "left" or key == "right" then
        local idx = 1
        for i, t in ipairs(Library.TABS) do
            if t.key == filter then idx = i end
        end
        idx = (idx - 1 + (key == "right" and 1 or -1)) % #Library.TABS + 1
        setFilter(Library.TABS[idx].key)
    end
    return nil
end

function Library.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    local C = Library.CLOSE
    if x >= C.x and x <= C.x + C.w and y >= C.y and y <= C.y + C.h then return "close" end
    local key = Library.tabAt(x, y)
    if key then setFilter(key) end
    return nil
end

function Library.wheelmoved(_, dy)
    scroll = Library.clampScroll(scroll - dy * Library.SCROLL_STEP, #visible())
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

function Library.update(dt, mx, my)
    if not closeBtn then
        local C = Library.CLOSE
        closeBtn = Button.new({ id = "close", label = "", variant = "danger", x = C.x, y = C.y, w = C.w, h = C.h })
    end
    mx, my = mx or -1, my or -1
    closeBtn:update(dt, mx, my, love.mouse.isDown(1))
    local cards = visible()
    local i = Library.cardAt(mx, my, #cards, scroll)
    if i then
        hover:update(dt, filter .. ":" .. i, { cardDef = cards[i], src = Library.cellRect(i, scroll) })
    else
        hover:update(dt, nil, nil)
    end
end

local function drawScrollbar(n)
    local maxS = Library.maxScroll(n)
    if maxS <= 0 then return end
    local V = Library.VIEW
    local trackX, trackY, trackH = 1262, V.y + 8, V.h - 16
    local thumbH = math.max(40, trackH * V.h / (V.h + maxS))
    local thumbY = trackY + (scroll / maxS) * (trackH - thumbH)
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35)
    love.graphics.rectangle("fill", trackX, trackY, 8, trackH, 4, 4)
    Draw.setColor(Theme.white)
    love.graphics.rectangle("fill", trackX, thumbY, 8, thumbH, 4, 4)
end

function Library.draw()
    local W, H = 1280, 800
    local cards = visible()
    Backdrop.draw(love.timer.getTime(), W, H, false)

    -- Header
    Draw.text("CARD LIBRARY", 40, 16, 700, "left", {
        size = 40, color = Theme.white, outline = 3, outlineColor = Theme.ink, shadowY = 4,
    })
    Draw.text("ESC TO CLOSE  ·  MOUSE WHEEL OR UP / DOWN TO SCROLL  ·  LEFT / RIGHT TO SWITCH TABS",
        40, 66, 900, "left", { size = 12, body = true, color = { 1, 1, 1, 0.85 } })
    Draw.pill(1040, 33, 140, 34, #cards .. " CARDS", { fill = Theme.white, textColor = Theme.inkText, size = 18 })

    -- Tabs (active one filled yellow)
    for _, r in ipairs(Library.tabRects()) do
        local active = r.key == filter
        Draw.pill(r.x, r.y, r.w, r.h, r.label, {
            fill = active and Theme.button.primary.fill or { 1, 1, 1, 0.18 },
            textColor = active and Theme.button.primary.text or Theme.white,
            size = 18, border = 3, shadow = active and 4 or 3,
        })
    end

    -- Grid (clipped to the viewport)
    local V = Library.VIEW
    local shownKey = hover:shown() and hover.key or nil
    love.graphics.setScissor(V.x, V.y, V.w, V.h)
    for i, c in ipairs(cards) do
        local r = Library.cellRect(i, scroll)
        if r.y + r.h + 30 > V.y and r.y - 30 < V.y + V.h then
            Card.drawFace(c, r.x, r.y, r.w, r.h, { selected = shownKey == (filter .. ":" .. i) })
        end
    end
    love.graphics.setScissor()
    if #cards == 0 then
        Draw.text("No cards in this category.", 0, 440, W, "center", { size = 24, shadowY = 2 })
    end
    drawScrollbar(#cards)

    -- Close button with a drawn ✕
    if closeBtn then
        closeBtn:draw()
        Draw.cross(closeBtn.x + closeBtn.w / 2, closeBtn.y + closeBtn.lift + closeBtn.h / 2, 20, Theme.white, 5)
    end

    -- Hover zoom
    if hover:shown() and hover.payload then
        Zoom.draw({ cardDef = hover.payload.cardDef, src = hover.payload.src, scale = 1 })
    end
end

return Library
