-- Match top bar (y 0–80): avatars, draining LP bars, halves pips, opponent deck count,
-- phase pill, turn chip and the pause / music / log icon buttons.
-- Clicks are mapped by Layout.buttonAt; this module only draws and animates.
local Theme     = require("ui.theme")
local Fonts     = require("ui.fonts")
local Draw      = require("ui.kit.draw")
local Icons     = require("ui.kit.icons")
local Button    = require("ui.kit.button")
local Layout    = require("ui.match.layout")
local LPBar     = require("ui.match.lpbar")
local Character = require("ui.character")
local Audio     = require("ui.audio")
local C         = require("engine.constants")

local TopBar = {}

local bars, buttons = nil, nil
local ICON_IDS = { "pause", "music", "log" }

local PHASE_COLOR = {
    draw    = Theme.grad.def[2],
    summon  = Theme.grad.bonus[2],
    attack  = Theme.grad.atk[2],
    ["end"] = Theme.typeGrad.trap[2],
}
local OPP_CHIP = { Theme.hex("d7dcea"), Theme.hex("a3abc4") }

function TopBar.reset(match)
    local max = C.MATCH.STARTING_LP
    bars = {
        player   = LPBar.new(match.players.player.lp, max),
        opponent = LPBar.new(match.players.opponent.lp, max),
    }
    buttons = {}
    for _, id in ipairs(ICON_IDS) do
        local r = Layout.top[id]
        buttons[id] = Button.new({ id = id, variant = "icon", x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

function TopBar.update(dt, match, mx, my)
    if not bars then TopBar.reset(match) end
    bars.player:set(match.players.player.lp)
    bars.opponent:set(match.players.opponent.lp)
    bars.player:update(dt)
    bars.opponent:update(dt)
    local down = love.mouse.isDown(1)
    for _, id in ipairs(ICON_IDS) do buttons[id]:update(dt, mx or -1, my or -1, down) end
end

local function avatarFrame(a, fill)
    Draw.setColor(Theme.ink);   love.graphics.circle("fill", a.cx, a.cy + 4, a.r + 3, 40)
    Draw.setColor(Theme.white); love.graphics.circle("fill", a.cx, a.cy, a.r + 3, 40)
    Draw.setColor(fill);        love.graphics.circle("fill", a.cx, a.cy, a.r, 40)
end

-- Halves-won pips (⚽ when won). rightAligned: p.x is the right edge.
local function pips(p, won, rightAligned)
    local n = math.max(2, won)
    for i = 1, n do
        local off = (i - 1) * (p.size + p.gap) + p.size / 2
        local cx = rightAligned and (p.x - off) or (p.x + off)
        local cy = p.y + p.size / 2
        if i <= won then
            Draw.setColor(Theme.ink);   love.graphics.circle("fill", cx, cy + 2, p.size / 2 + 1, 24)
            Draw.setColor(Theme.white); love.graphics.circle("fill", cx, cy, p.size / 2 + 1, 24)
            Icons.draw("soccer-ball", cx, cy, p.size - 2, Theme.inkText, 0)
        else
            love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35)
            love.graphics.circle("fill", cx, cy, p.size / 2, 24)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, p.size / 2, 24)
            love.graphics.setLineWidth(1)
        end
    end
end

local function phasePill(match)
    local r = Layout.top.phasePill
    Draw.sticker(r.x, r.y, r.w, r.h, { r = r.h / 2, fill = Theme.white, border = 3, shadow = 4 })
    local half   = match.half == "extra" and "EXTRA TIME" or ("HALF " .. tostring(match.half))
    local prefix = half .. " · TURN " .. tostring(match.turn) .. " · "
    local word   = string.upper(match.phase or "")
    local font   = Fonts.get(18)
    local total  = font:getWidth(prefix) + font:getWidth(word)
    local x = math.floor(r.x + (r.w - total) / 2)
    local y = math.floor(r.y + (r.h - font:getHeight()) / 2)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    Draw.setColor(Theme.inkText)
    love.graphics.print(prefix, x, y)
    Draw.setColor(PHASE_COLOR[match.phase] or Theme.inkText)
    love.graphics.print(word, x + font:getWidth(prefix), y)
    love.graphics.setFont(prev)
end

local function turnChip(match)
    local c = Layout.top.turnChip
    if match.activePlayer == "player" then
        Draw.pill(c.x, c.y, c.w, c.h, "YOUR TURN", {
            fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 15 })
    else
        Draw.pill(c.x, c.y, c.w, c.h, "OPP TURN", { fill = OPP_CHIP, textColor = Theme.inkText, size = 15 })
    end
end

-- White glyphs drawn on top of the icon buttons (follow the button's lift).
local function glyph(id, b)
    local cx, cy = b.x + b.w / 2, b.y + b.lift + b.h / 2
    love.graphics.setColor(1, 1, 1, 1)
    if id == "pause" then
        love.graphics.rectangle("fill", cx - 8, cy - 9, 6, 18, 2, 2)
        love.graphics.rectangle("fill", cx + 2, cy - 9, 6, 18, 2, 2)
    elseif id == "music" then
        love.graphics.circle("fill", cx - 4, cy + 6, 5, 16)
        love.graphics.rectangle("fill", cx - 2, cy - 10, 3, 16)
        love.graphics.polygon("fill", cx + 1, cy - 10, cx + 8, cy - 6, cx + 1, cy - 3)
        if Audio.isMuted() then
            Draw.setColor(Theme.grad.atk[2])
            love.graphics.setLineWidth(4)
            love.graphics.line(b.x + 7, b.y + b.lift + 7, b.x + b.w - 7, b.y + b.lift + b.h - 7)
            love.graphics.setLineWidth(1)
        end
    else
        for i = -1, 1 do
            love.graphics.rectangle("fill", cx - 9, cy + i * 7 - 1.5, 18, 3, 1, 1)
        end
    end
end

function TopBar.draw(match)
    if not bars then TopBar.reset(match) end
    local T = Layout.top
    local p, o = match.players.player, match.players.opponent

    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.25)
    love.graphics.rectangle("fill", T.bar.x, T.bar.y, T.bar.w, T.bar.h)

    avatarFrame(T.youAvatar, Theme.bg.top)
    Character.drawAvatar(T.youAvatar.cx, T.youAvatar.cy, T.youAvatar.r)
    avatarFrame(T.oppAvatar, Theme.grad.lpOpp[2])
    Icons.draw("soccer-kick", T.oppAvatar.cx, T.oppAvatar.cy, T.oppAvatar.r * 1.3, Theme.white)

    LPBar.draw(bars.player,   T.youBar, Theme.grad.lpYou, "YOU · " .. math.max(0, bars.player.shown), false)
    LPBar.draw(bars.opponent, T.oppBar, Theme.grad.lpOpp, "OPP · " .. math.max(0, bars.opponent.shown), true)
    pips(T.youPips, p.halvesWon or 0, false)
    pips(T.oppPips, o.halvesWon or 0, true)
    Draw.pill(T.oppDeck.x, T.oppDeck.y, T.oppDeck.w, T.oppDeck.h, "DECK " .. #o.deck, {
        fill = Theme.white, textColor = Theme.inkText, size = 13, shadow = 2 })

    phasePill(match)
    turnChip(match)
    for _, id in ipairs(ICON_IDS) do
        buttons[id]:draw()
        glyph(id, buttons[id])
    end
end

return TopBar
