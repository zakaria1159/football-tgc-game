-- Half-time screen (spec 2026-09-24 §2): opens after the half-time ribbon while the match is
-- in a half-time break. Score, stats of the half just played (YOU vs OPP), the new hand
-- (click / 1-5 to pick up to 3 cards to send back), SWAP and KICK OFF.
-- Layout, selection, labels and input mapping are pure (unit-tested); draw uses LÖVE.
-- Actions: "toggle", i | "swap" | "kickoff" | "pause". scenes/match.lua calls the store
-- (Store:mulligan / Store:kickOff) and plays the SECOND HALF / EXTRA TIME banner.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Button = require("ui.kit.button")
local C      = require("engine.constants")
local Fx     = require("ui.overlay.combatfx")   -- progress / backout

local HT = {}

HT.MAX      = C.MATCH.MULLIGAN_MAX
HT.CARD_W   = 146
HT.CARD_H   = 200
HT.CARD_GAP = 22
HT.CARD_Y   = 400
HT.LIFT     = 26
HT.POP      = 0.35   -- pop-in of freshly drawn cards after a swap
HT.TITLE    = { cx = 640, y = 30, w = 640, h = 84 }
HT.SCORE    = { x = 490, y = 130, w = 300, h = 44 }
HT.STATS    = { x = 240, y = 192, w = 800, h = 150 }
HT.SWAP_BTN = { x = 278, y = 662, w = 280, h = 68 }
HT.KICK_BTN = { x = 582, y = 662, w = 420, h = 68 }
HT.KICKOFF  = { x = 420, y = 614, w = 440, h = 36 }   -- who kicks off, between hand and buttons

-- ── Text ──────────────────────────────────────────────────────────────────────

-- half = match.half of the half about to start (2 | "extra"); starter = its
-- match.halfStarter ("player" | "opponent", optional). kickoff: the line naming who kicks
-- off (the Extra Time one is a coin toss); the banner names them too.
function HT.labels(half, starter)
    local l
    if half == "extra" then
        l = { title = "FULL TIME — EXTRA TIME", kick = "KICK OFF — EXTRA TIME", banner = "EXTRA TIME" }
    else
        l = { title = "HALF TIME", kick = "KICK OFF — 2ND HALF", banner = "SECOND HALF" }
    end
    if starter then
        local who = starter == "player" and "YOU KICK OFF" or "OPPONENT KICKS OFF"
        l.kickoff = (half == "extra" and "COIN TOSS: " or "") .. who
        l.banner  = l.banner .. " · " .. who
    end
    return l
end

function HT.score(match)
    local p, o = match.players.player, match.players.opponent
    return "YOU " .. (p.halvesWon or 0) .. " – " .. (o.halvesWon or 0) .. " OPP"
end

-- stats = match.lastHalfStats (may be nil).
function HT.rows(stats)
    local p = stats and stats.player or {}
    local o = stats and stats.opponent or {}
    return {
        { label = "LP LEFT",    you = math.max(0, p.lp or 0), opp = math.max(0, o.lp or 0) },
        { label = "DAMAGE",     you = p.damage or 0,          opp = o.damage or 0 },
        { label = "GOALS",      you = p.goals or 0,           opp = o.goals or 0 },
        { label = "CARDS LOST", you = p.lost or 0,            opp = o.lost or 0 },
    }
end

-- ── State ─────────────────────────────────────────────────────────────────────

-- selected[i] = true for hand index i; swapped after the one swap; t = seconds open.
function HT.new()
    return { selected = {}, swapped = false, t = 0, newFrom = nil, swapT = 0 }
end

function HT.count(s)
    local n = 0
    for _ in pairs(s.selected) do n = n + 1 end
    return n
end

function HT.canSwap(s) return not s.swapped and HT.count(s) > 0 end

-- Toggle hand card i of n. Returns true when the selection changed.
function HT.toggle(s, i, n)
    if s.swapped or not i or i < 1 or i > n then return false end
    if s.selected[i] then
        s.selected[i] = nil
        return true
    end
    if HT.count(s) >= HT.MAX then return false end
    s.selected[i] = true
    return true
end

-- Ids of the selected cards, in hand order (copies may share an id).
function HT.selectedIds(s, hand)
    local out = {}
    for i, c in ipairs(hand) do
        if s.selected[i] then out[#out + 1] = c.id end
    end
    return out
end

-- After a successful swap of k cards: the hand has n cards, the last k are new draws.
function HT.afterSwap(s, n, k)
    s.swapped, s.selected = true, {}
    s.newFrom, s.swapT = n - k + 1, 0
end

function HT.isNew(s, i) return s.newFrom ~= nil and i >= s.newFrom end

function HT.swapLabel(s)
    if s.swapped then return "SWAPPED" end
    local k = HT.count(s)
    if k == 0 then return "SWAP" end
    return "SWAP " .. k .. (k == 1 and " CARD" or " CARDS")
end

-- ── Layout / input ────────────────────────────────────────────────────────────

-- Rest rects of n hand cards: one centred row.
function HT.cardRects(n)
    local total = n * HT.CARD_W + (n - 1) * HT.CARD_GAP
    local x0 = 640 - total / 2
    local out = {}
    for i = 1, n do
        out[i] = { x = x0 + (i - 1) * (HT.CARD_W + HT.CARD_GAP), y = HT.CARD_Y, w = HT.CARD_W, h = HT.CARD_H }
    end
    return out
end

-- Rect of card i as drawn (selected cards lift).
function HT.cardRect(s, i, n)
    local r = HT.cardRects(n)[i]
    if s.selected[i] then r.y = r.y - HT.LIFT end
    return r
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- n = hand size. → "kickoff" | "swap" | "toggle", i | nil
function HT.actionAt(s, n, x, y)
    if inRect(x, y, HT.KICK_BTN) then return "kickoff" end
    if inRect(x, y, HT.SWAP_BTN) then return HT.canSwap(s) and "swap" or nil end
    for i = n, 1, -1 do
        if inRect(x, y, HT.cardRect(s, i, n)) then return "toggle", i end
    end
    return nil
end

function HT.keyAction(key)
    if key == "return" or key == "kpenter" then return "kickoff" end
    if key == "s" then return "swap" end
    if key == "escape" then return "pause" end
    local d = tonumber(key)
    if d and d >= 1 and d <= 5 and d == math.floor(d) then return "toggle", d end
    return nil
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local buttons = nil

-- Advance the screen's clocks (capped step, like the other overlays).
function HT.update(s, dt)
    local step = math.min(dt, 1 / 30)
    s.t = s.t + step
    if s.newFrom then s.swapT = s.swapT + step end
end

local function drawStats(match)
    local S = HT.STATS
    Draw.sticker(S.x, S.y, S.w, S.h, { r = 24, fill = Theme.white, border = 0, shadow = 7 })
    local colX, colW, step = S.x + 190, 140, 150
    for i, row in ipairs(HT.rows(match.lastHalfStats)) do
        local x = colX + (i - 1) * step
        Draw.text(row.label, x, S.y + 14, colW, "center", { size = 18, color = Theme.inkText, fit = true })
        Draw.pill(x, S.y + 44, colW, 40, tostring(row.you), { fill = Theme.grad.lpYou, textColor = Theme.white, size = 24 })
        Draw.pill(x, S.y + 94, colW, 40, tostring(row.opp), { fill = Theme.grad.lpOpp, textColor = Theme.white, size = 24 })
    end
    Draw.text("THIS HALF", S.x + 24, S.y + 14, 150, "left", { size = 18, color = Theme.inkText, fit = true })
    Draw.text("YOU", S.x + 24, S.y + 50, 150, "left", { size = 26, color = Theme.grad.lpYou[2] })
    Draw.text("OPP", S.x + 24, S.y + 100, 150, "left", { size = 26, color = Theme.grad.lpOpp[2] })
end

local function drawHand(s, hand, mx, my)
    local Card = require("ui.card")
    local n = #hand
    for i, cardDef in ipairs(hand) do
        local r = HT.cardRect(s, i, n)
        local sel = s.selected[i]
        local k = 1
        if HT.isNew(s, i) then k = Fx.backout(Fx.progress(s.swapT, (i - s.newFrom) * 0.08, HT.POP)) end
        if k > 0 then
            love.graphics.push()
            love.graphics.translate(r.x + r.w / 2, r.y + r.h / 2)
            love.graphics.scale(k, k)
            love.graphics.translate(-(r.x + r.w / 2), -(r.y + r.h / 2))
            Card.drawFace(cardDef, r.x, r.y, r.w, r.h, { badges = "left", selected = sel or nil })
            love.graphics.pop()
        end
        if sel then
            Draw.pill(r.x + r.w / 2 - 44, r.y - 16, 88, 32, "SWAP", {
                fill = Theme.outcome.red, textColor = Theme.white, size = 20, border = 3, shadow = 3,
            })
        elseif not s.swapped and inRect(mx or -1, my or -1, r) then
            Draw.ring(r.x - 3, r.y - 3, r.w + 6, r.h + 6, 16, Theme.white, 3, 0.8)
        end
        -- Key hint under each card (1-5)
        if i <= 5 then
            local rest = HT.cardRects(n)[i]
            Draw.pill(rest.x + rest.w / 2 - 15, rest.y + rest.h + 18, 30, 26, tostring(i), {
                fill = Theme.white, textColor = Theme.inkText, size = 16, border = 0, shadow = 2,
            })
        end
    end
end

-- s = HT.new() state; mx, my: match mouse.
function HT.draw(s, match, mx, my)
    if not buttons then
        local S, K = HT.SWAP_BTN, HT.KICK_BTN
        buttons = {
            swap = Button.new({ id = "swap", label = "SWAP", variant = "danger", fontSize = 28,
                                x = S.x, y = S.y, w = S.w, h = S.h }),
            kick = Button.new({ id = "kickoff", label = "KICK OFF", variant = "go", fontSize = 28,
                                x = K.x, y = K.y, w = K.w, h = K.h }),
        }
    end
    local labels = HT.labels(match.half, match.halfStarter)
    local fade = Fx.progress(s.t, 0, 0.25)
    -- Darker than Theme.dim: the pitch and the hand dock must not compete with the screen.
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.9 * fade)
    love.graphics.rectangle("fill", 0, 0, 1280, 800)

    local pop = Fx.backout(Fx.progress(s.t, 0.05, 0.4))
    local T = HT.TITLE
    love.graphics.push()
    love.graphics.translate(T.cx, T.y + T.h / 2)
    love.graphics.scale(pop, pop)
    love.graphics.translate(-T.cx, -(T.y + T.h / 2))
    Draw.ribbon(T.cx, T.y, T.w, T.h, labels.title, {
        fill = Theme.outcome.blue, textColor = Theme.white, size = 54, textShadow = true,
    })
    love.graphics.pop()

    local Sc = HT.SCORE
    Draw.pill(Sc.x, Sc.y, Sc.w, Sc.h, HT.score(match), {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 26, border = 3, shadow = 4,
    })

    drawStats(match)
    drawHand(s, match.players.player.hand, mx, my)

    if labels.kickoff then
        local K = HT.KICKOFF
        local mine = match.halfStarter == "player"
        Draw.pill(K.x, K.y, K.w, K.h, labels.kickoff, {
            fill = mine and Theme.button.go.fill or Theme.button.primary.fill,
            textColor = mine and Theme.white or Theme.button.primary.text, size = 20, border = 3, shadow = 3,
        })
    end

    buttons.swap.label   = HT.swapLabel(s)
    buttons.swap.enabled = HT.canSwap(s)
    buttons.kick.label   = labels.kick
    local dt, down = love.timer.getDelta(), love.mouse.isDown(1)
    for _, b in ipairs({ buttons.swap, buttons.kick }) do
        b:update(dt, mx or -1, my or -1, down)
        b:draw()
    end
    local hint = s.swapped and "ENTER  KICK OFF   ·   ESC  PAUSE"
        or ("CLICK OR 1–5  PICK UP TO " .. HT.MAX .. " CARDS   ·   S  SWAP   ·   ENTER  KICK OFF   ·   ESC  PAUSE")
    Draw.text(hint, 0, 748, 1280, "center", { size = 14, body = true, color = Theme.white, shadowY = 1 })
end

return HT
