-- Deck select (after PLAY): three deck tiles, each with a fanned showcase of three real
-- cards peeking over its top; the selected tile lifts and scales with a yellow ring.
-- BACK bottom-left, KICK OFF bottom-right. Layout, hit-testing and the showcase pick are
-- pure (unit-tested); update/draw use LÖVE.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Backdrop = require("ui.menu.backdrop")

local DeckSelect = {}

DeckSelect.DECKS = {
    { key = "tikitaka",   label = "THE BEAUTIFUL GAME", sub = "TIKI-TAKA",  desc = "Possession & draw power" },
    { key = "longball",   label = "DIRECT FOOTBALL",    sub = "LONG BALL",  desc = "Raw striker power" },
    { key = "catenaccio", label = "THE WALL",           sub = "CATENACCIO", desc = "Defensive fortress" },
}
DeckSelect.TILE_W, DeckSelect.TILE_H, DeckSelect.GAP, DeckSelect.TILE_Y = 320, 300, 40, 250
DeckSelect.LIFT    = 18                                 -- selected tile rises (px)
DeckSelect.FAN     = { bottom = 56, w = 108, h = 148 }  -- showcase cards; bottom = px below the tile top
DeckSelect.TITLE   = { y = 44, h = 64 }
DeckSelect.BACK    = { x = 40,   y = 704, w = 210, h = 64 }
DeckSelect.KICKOFF = { x = 1010, y = 704, w = 230, h = 64 }

function DeckSelect.tileRect(i)
    local n = #DeckSelect.DECKS
    local total = n * DeckSelect.TILE_W + (n - 1) * DeckSelect.GAP
    local x0 = (1280 - total) / 2
    return { x = x0 + (i - 1) * (DeckSelect.TILE_W + DeckSelect.GAP), y = DeckSelect.TILE_Y,
             w = DeckSelect.TILE_W, h = DeckSelect.TILE_H }
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- "back" | "kickoff" | tile index | nil for a click at (x, y).
function DeckSelect.hitAt(x, y)
    if inRect(x, y, DeckSelect.BACK) then return "back" end
    if inRect(x, y, DeckSelect.KICKOFF) then return "kickoff" end
    for i = 1, #DeckSelect.DECKS do
        if inRect(x, y, DeckSelect.tileRect(i)) then return i end
    end
    return nil
end

local RANK  = { legendary = 4, rare = 3, uncommon = 2, common = 1 }
local FIELD = { striker = true, midfielder = true, defender = true, keeper = true }

-- Three distinct field cards to fan over a deck tile: rarest first (deck order breaks
-- ties), returned as { left, centre, right } with the rarest in the centre.
function DeckSelect.showcase(cards)
    local seen, pool = {}, {}
    for i, c in ipairs(cards) do
        if FIELD[c.type] and not seen[c.id] then
            seen[c.id] = true
            pool[#pool + 1] = { card = c, rank = RANK[c.rarity] or 0, order = i }
        end
    end
    table.sort(pool, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.order < b.order
    end)
    local out = {}
    if pool[2] then out[#out + 1] = pool[2].card end
    if pool[1] then out[#out + 1] = pool[1].card end
    if pool[3] then out[#out + 1] = pool[3].card end
    return out
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local buttons, showcases, counts = nil, nil, nil
local lifts, time = { 0, 0, 0 }, 0

local function ensure()
    if buttons then return end
    local B, K = DeckSelect.BACK, DeckSelect.KICKOFF
    buttons = {
        back    = Button.new({ id = "back", label = "BACK", variant = "neutral", fontSize = 26,
                               x = B.x, y = B.y, w = B.w, h = B.h }),
        kickoff = Button.new({ id = "kickoff", label = "KICK OFF", variant = "go", fontSize = 30,
                               x = K.x, y = K.y, w = K.w, h = K.h }),
    }
    local Decks = require("data.presetDecks")
    showcases, counts = {}, {}
    for i, d in ipairs(DeckSelect.DECKS) do
        showcases[i] = DeckSelect.showcase(Decks[d.key].cards)
        counts[i] = #Decks[d.key].cards
    end
end

function DeckSelect.update(dt, mx, my, selected)
    ensure()
    time = time + dt
    local down = love.mouse.isDown(1)
    buttons.back:update(dt, mx or -1, my or -1, down)
    buttons.kickoff:update(dt, mx or -1, my or -1, down)
    for i = 1, #DeckSelect.DECKS do
        local target = (i == selected) and 1 or 0
        lifts[i] = lifts[i] + (target - lifts[i]) * math.min(1, dt * 12)
    end
end

-- Three cards fanned around cx, bottoms at bottomY (sides first, centre on top).
local function drawFan(cards, cx, bottomY)
    local F = DeckSelect.FAN
    local angle = { -0.20, 0, 0.20 }
    local dx    = { -58, 0, 58 }
    for _, k in ipairs({ 1, 3, 2 }) do
        local c = cards[k]
        if c then
            love.graphics.push()
            love.graphics.translate(cx + dx[k], bottomY + (k == 2 and -10 or 0))
            love.graphics.rotate(angle[k])
            Card.drawFace(c, -F.w / 2, -F.h, F.w, F.h, {})
            love.graphics.pop()
        end
    end
end

local function drawTile(i, sel)
    local deck, lift = DeckSelect.DECKS[i], lifts[i]
    local r = DeckSelect.tileRect(i)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local s = 1 + 0.05 * lift
    love.graphics.push()
    love.graphics.translate(cx, cy - DeckSelect.LIFT * lift)
    love.graphics.scale(s, s)
    love.graphics.translate(-cx, -cy)
    if sel then
        Draw.glow(r.x, r.y, r.w, r.h, 24, Theme.highlight.selected, 1.2)
        Draw.ring(r.x - 6, r.y - 6, r.w + 12, r.h + 12, 30, Theme.highlight.selected, 6)
    end
    drawFan(showcases[i], cx, r.y + DeckSelect.FAN.bottom)     -- behind the tile: only the tops peek out
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 24, fill = Theme.deckFill[deck.key], dir = "d", border = 5, shadow = 7 })
    Draw.text(deck.label, r.x + 16, r.y + 84, r.w - 32, "center", {
        size = 32, color = Theme.white, shadowY = 3, fit = true, minSize = 18,
    })
    Draw.pill(r.x + r.w / 2 - 80, r.y + 134, 160, 30, deck.sub, {
        fill = Theme.ink, textColor = Theme.white, size = 16, border = 2, shadow = 0,
    })
    Draw.text(deck.desc, r.x + 24, r.y + 184, r.w - 48, "center", {
        size = 18, body = true, color = Theme.white, shadowY = 2,
    })
    Draw.pill(r.x + r.w / 2 - 60, r.y + r.h - 50, 120, 30, counts[i] .. " CARDS", {
        fill = Theme.white, textColor = Theme.inkText, size = 16,
    })
    love.graphics.pop()
end

local function arrowOn(b, dir)
    local style = Theme.button[b.variant]
    local ax = dir < 0 and (b.x + 30) or (b.x + b.w - 30)
    Draw.arrow(ax, b.y + b.lift + b.h / 2, 22, dir, style.text)
end

function DeckSelect.draw(selected)
    ensure()
    local W, H = 1280, 800
    local T = DeckSelect.TITLE
    Backdrop.draw(time, W, H, false)
    Draw.ribbon(W / 2, T.y, 460, T.h, "CHOOSE YOUR DECK", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 36,
    })
    -- unselected tiles first so the lifted tile overlaps its neighbours
    for i = 1, #DeckSelect.DECKS do
        if i ~= selected then drawTile(i, false) end
    end
    drawTile(selected, true)
    buttons.back:draw();    arrowOn(buttons.back, -1)
    buttons.kickoff:draw(); arrowOn(buttons.kickoff, 1)
    Draw.text("LEFT / RIGHT TO CHOOSE  ·  ENTER TO KICK OFF  ·  ESC TO GO BACK", 0, 604, W, "center", {
        size = 15, body = true, color = { 1, 1, 1, 0.85 }, shadowY = 1,
    })
end

return DeckSelect
