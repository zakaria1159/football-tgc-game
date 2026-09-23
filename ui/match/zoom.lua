-- Card zoom: zoom-size card + info sticker beside the hovered card, clamped on screen.
-- Zoom.place / Zoom.statusLines are pure (unit-tested); Zoom.draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Card   = require("ui.card")
local Layout = require("ui.match.layout")

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

-- Extra lines under the ability text: { text, color = ink|bonus|bad|warn }.
function Zoom.statusLines(cardDef, pitched, pitch)
    local lines = {}
    local function add(text, color) lines[#lines + 1] = { text = text, color = color } end
    if cardDef.playstyle then
        local ps = cardDef.playstyle
        add("Style: " .. (type(ps) == "table" and table.concat(ps, " · ") or tostring(ps)), "ink")
    end
    if cardDef.foulTendency then add("Foul tendency: " .. string.upper(tostring(cardDef.foulTendency)), "ink") end
    if not pitched then return lines end

    local st = cardDef.stats or {}
    local atkB, defB = Card.bonuses(pitched, pitch)
    if atkB > 0 then
        add("ATK " .. (st.atk or 0) .. " + " .. atkB .. " = " .. ((st.atk or 0) + atkB), "bonus")
    end
    if defB > 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(label .. (st.def or 0) .. " + " .. defB .. " = " .. ((st.def or 0) + defB), "bonus")
    end
    local modeText = "Mode: ATTACK"
    if pitched.mode == "defense" then
        modeText = pitched.revealed and "Mode: DEFENSE (revealed)" or "Mode: DEFENSE (face-down)"
    end
    add(modeText, "ink")
    if pitched.exhausted then add("EXHAUSTED", "bad") end
    if pitched.cannotActNextTurn then add("Cannot act next turn", "bad") end
    if (pitched.yellowCards or 0) > 0 then add("Yellow cards: " .. pitched.yellowCards, "warn") end
    return lines
end

function Zoom.infoHeight(cardDef, lines)
    return Card.infoHeight(cardDef, Zoom.INFO_W) + (#lines > 0 and (#lines * Zoom.LINE_H + 6) or 0)
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

-- z = { cardDef, pitched (optional), pitch (optional), src = rect, scale (pop-in) }
function Zoom.draw(z)
    local lines = Zoom.statusLines(z.cardDef, z.pitched, z.pitch)
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
    if z.pitched then atkB, defB = Card.bonuses(z.pitched, z.pitch) end
    Card.drawFace(z.cardDef, p.cardX, p.cardY, Zoom.W, Zoom.H, {
        atkBonus  = atkB > 0 and atkB or nil,
        defBonus  = defB > 0 and defB or nil,
        exhausted = z.pitched and z.pitched.exhausted or nil,
    })
    Card.drawInfo(z.cardDef, p.infoX, p.infoY, Zoom.INFO_W, infoH - baseH)
    local y = p.infoY + baseH - 6
    for _, ln in ipairs(lines) do
        Draw.text(ln.text, p.infoX + 12, y, Zoom.INFO_W - 24, "left", {
            size = 13, body = true, color = LINE_COLORS[ln.color] or Theme.inkText, fit = true, minSize = 9,
        })
        y = y + Zoom.LINE_H
    end
    love.graphics.pop()
end

return Zoom
