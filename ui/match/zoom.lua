-- Card zoom: zoom-size card + info sticker beside the hovered card, clamped on screen.
-- Zoom.place / Zoom.statusLines are pure (unit-tested); Zoom.draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Card   = require("ui.card")
local Layout = require("ui.match.layout")
local Fonts  = require("ui.fonts")
local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")
local Stamina  = require("engine.stamina")

local Zoom = {}
Zoom.W, Zoom.H    = 200, 274   -- Theme.cardSize.zoom
Zoom.INFO_W       = 250
Zoom.GAP          = 14
Zoom.MARGIN       = 8
Zoom.TOP_OVER     = 15         -- type tag sticks out above the card
Zoom.BOTTOM_OVER  = 30         -- ATK/DEF badges stick out below
Zoom.LINE_H       = 18

-- src: rect of the hovered card. Returns { cardX, cardY, infoX, infoY }.
-- Right of the source if it fits ([src][card][info]); else left ([info][card][src]);
-- else clamped to the screen.
function Zoom.place(src, infoH, W, H)
    local m  = Zoom.MARGIN
    local tw = Zoom.W + Zoom.GAP + Zoom.INFO_W
    local cardX, infoX

    local rightX = src.x + src.w + Zoom.GAP
    if rightX + tw <= W - m then
        cardX = rightX
        infoX = rightX + Zoom.W + Zoom.GAP
    else
        local x = src.x - Zoom.GAP - tw
        if x < m then x = math.max(m, math.min(W - m - tw, x)) end
        infoX = x
        cardX = x + Zoom.INFO_W + Zoom.GAP
    end
    local minY = m + Zoom.TOP_OVER
    local maxY = H - m - Zoom.BOTTOM_OVER - Zoom.H
    local cardY = math.max(minY, math.min(maxY, src.y + src.h / 2 - Zoom.H / 2))
    local infoY = math.max(m, math.min(H - m - infoH, cardY))
    return { cardX = cardX, cardY = cardY, infoX = infoX, infoY = infoY }
end

-- " (Link-up +150, Tired -300)" for a stat line; "" without keyword parts. Pure.
function Zoom.partsText(parts)
    local out = {}
    for _, p in ipairs(parts or {}) do
        if p.keyword then
            local n = p.amount or 0
            out[#out + 1] = Resolver.partName(p.keyword) .. (n < 0 and (" -" .. (-n)) or (" +" .. n))
        end
    end
    if #out == 0 then return "" end
    return " (" .. table.concat(out, ", ") .. ")"
end

-- "ATK 2000 + 200 = 2200 (…)" / "DEF 500 - 300 = 200 (Tired -300)". Pure.
local function statLine(label, base, bonus, parts)
    local op = bonus >= 0 and (" + " .. bonus) or (" - " .. (-bonus))
    return label .. base .. op .. " = " .. (base + bonus) .. Zoom.partsText(parts)
end

-- Extra lines under the ability text: { text, color = ink|bonus|bad|warn }.
-- hideHidden: the card is the opponent's (see Card.bonuses).
function Zoom.statusLines(cardDef, pitched, pitch, hideHidden)
    local lines = {}
    local function add(text, color) lines[#lines + 1] = { text = text, color = color } end
    if cardDef.playstyle then
        local ps = cardDef.playstyle
        add("Style: " .. (type(ps) == "table" and table.concat(ps, " · ") or tostring(ps)), "ink")
    end
    if cardDef.foulTendency then add("Foul tendency: " .. string.upper(tostring(cardDef.foulTendency)), "ink") end
    if not pitched then return lines end

    local st = cardDef.stats or {}
    local atkB, defB, atkParts, defParts = Card.bonuses(pitched, pitch, hideHidden)
    if atkB ~= 0 then
        add(statLine("ATK ", st.atk or 0, atkB, atkParts), atkB > 0 and "bonus" or "bad")
    end
    if defB ~= 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(statLine(label, st.def or 0, defB, defParts), defB > 0 and "bonus" or "bad")
    end
    local modeText = "Mode: ATTACK"
    if pitched.mode == "defense" then
        modeText = pitched.revealed and "Mode: DEFENSE (revealed)" or "Mode: DEFENSE (face-down)"
    end
    add(modeText, "ink")
    -- Stamina: hidden on the opponent's face-down cards; keepers never tire.
    if Stamina.visible(pitched, not hideHidden) then
        local total = Stamina.max(cardDef) or pitched.stamina
        if Stamina.tired(pitched) then
            add("TIRED: -" .. C.STAMINA.TIRED_ATK .. " ATK / -" .. C.STAMINA.TIRED_DEF
                .. " DEF (stamina 0 / " .. total .. ")", "bad")
        else
            add("Stamina " .. pitched.stamina .. " / " .. total, pitched.stamina <= 1 and "warn" or "ink")
        end
    end
    if pitched.exhausted then add("EXHAUSTED", "bad") end
    if pitched.cannotActNextTurn or pitched.lockedNextTurn then add("Cannot act next turn", "bad") end
    if pitched.summonedThisTurn and pitched.actsImmediately then
        add("Substitute: may attack this turn", "bonus")
    elseif pitched.summonedThisTurn and pitched.mode == "attack" and pitched.slotType ~= "keeper"
       and not C.MATCH.SUMMONED_CAN_ATTACK and not Resolver.canAttackWhenSummoned(pitched) then
        add("Just summoned: attacks next turn", "warn")
    end
    if (pitched.yellowCards or 0) > 0 then add("Yellow cards: " .. pitched.yellowCards, "warn") end
    return lines
end

-- A status line wraps onto extra rows when it is wider than the sticker (a stat line
-- naming several ability parts). Returns the wrapped rows.
local LINE_SIZE = 13
local function lineRows(text)
    local _, rows = Fonts.body(LINE_SIZE):getWrap(text, Zoom.INFO_W - 24)
    if #rows == 0 then rows = { text } end
    return rows
end

function Zoom.infoHeight(cardDef, lines)
    local n = 0
    for _, ln in ipairs(lines) do n = n + #lineRows(ln.text) end
    return Card.infoHeight(cardDef, Zoom.INFO_W) + (n > 0 and (n * Zoom.LINE_H + 6) or 0)
end

-- Info sticker only, centred above src (used for hand cards). Pure placement,
-- unit-tested. Returns x, y for Card.drawInfo(cardDef, x, y, Zoom.INFO_W).
function Zoom.placeInfoAbove(src, infoH, W)
    local m = Zoom.MARGIN
    local x = src.x + src.w / 2 - Zoom.INFO_W / 2
    x = math.max(m, math.min(W - m - Zoom.INFO_W, x))
    local y = math.max(m, src.y - Zoom.GAP - infoH)
    return x, y
end

-- Draw just the info sticker above a hovered hand card (no zoom card).
function Zoom.drawInfoAbove(cardDef, src)
    local infoH = Card.infoHeight(cardDef, Zoom.INFO_W)
    local x, y = Zoom.placeInfoAbove(src, infoH, Layout.W)
    Card.drawInfo(cardDef, x, y, Zoom.INFO_W)
end

local LINE_COLORS = {
    ink = Theme.inkText, bonus = Theme.hex("16a34a"), bad = Theme.hex("e0243a"), warn = Theme.hex("c98a00"),
}

-- z = { cardDef, pitched (optional), pitch (optional), hideHidden (opponent's card),
--       src = rect, scale (pop-in) }
function Zoom.draw(z)
    local lines = Zoom.statusLines(z.cardDef, z.pitched, z.pitch, z.hideHidden)
    local baseH = Card.infoHeight(z.cardDef, Zoom.INFO_W)
    local infoH = Zoom.infoHeight(z.cardDef, lines)
    local p = Zoom.place(z.src, infoH, Layout.W, Layout.H)
    local s = z.scale or 1
    local ox, oy = p.cardX + Zoom.W / 2, p.cardY + Zoom.H / 2

    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(s, s)
    love.graphics.translate(-ox, -oy)

    local atkB, defB = 0, 0
    if z.pitched then atkB, defB = Card.bonuses(z.pitched, z.pitch, z.hideHidden) end
    Card.drawFace(z.cardDef, p.cardX, p.cardY, Zoom.W, Zoom.H, {
        atkBonus  = atkB ~= 0 and atkB or nil,
        defBonus  = defB ~= 0 and defB or nil,
        exhausted = z.pitched and z.pitched.exhausted or nil,
        tired     = z.pitched and Stamina.tired(z.pitched) or nil,
    })
    Card.drawInfo(z.cardDef, p.infoX, p.infoY, Zoom.INFO_W, infoH - baseH)
    local y = p.infoY + baseH - 6
    for _, ln in ipairs(lines) do
        for _, row in ipairs(lineRows(ln.text)) do
            Draw.text(row, p.infoX + 12, y, Zoom.INFO_W - 24, "left", {
                size = LINE_SIZE, body = true, color = LINE_COLORS[ln.color] or Theme.inkText,
            })
            y = y + Zoom.LINE_H
        end
    end
    love.graphics.pop()
end

return Zoom
