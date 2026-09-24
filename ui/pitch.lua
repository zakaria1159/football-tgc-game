-- Landscape pitch: you on the left (GK · DEF×2 · MID · STR×2), opponent mirrored right.
-- Pitch.draw(match, st, anims) returns hitboxes { x, y, w, h, slotType, slotIndex, owner }
-- (card slots for both sides + your own trap slots).
--   st    = { highlightedSlots, attackTargetSlots, selectedAttackerSlot, phase }
--   anims = { hidden = { [slotKey] = true }, pop = { [slotKey] = { sx, sy } } }
local Theme  = require("ui.theme")
local Card   = require("ui.card")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")
local Stats  = require("ui.match.stats")

local Pitch = {}

local GRASS_A   = Theme.hex("46c460")
local GRASS_B   = Theme.hex("4fd06a")
local LINE      = { 1, 1, 1, 0.85 }
local TRAP_TINT = Theme.typeGrad.trap[1]
local LABEL     = { keeper = "GK", defender = "DEF", midfielder = "MID", striker = "STR" }

function Pitch.slotKey(owner, slotType, slotIndex)
    return owner .. ":" .. slotType .. ":" .. tostring(slotIndex)
end

local function listHas(list, owner, slotType, slotIndex)
    for _, s in ipairs(list or {}) do
        if s.owner == owner and s.slotType == slotType and s.slotIndex == slotIndex then return true end
    end
    return false
end

local function pulse(speed) return 0.5 + 0.5 * math.sin(love.timer.getTime() * (speed or 6)) end

local function cardIn(pitch, slotType, idx)
    if slotType == "keeper"     then return pitch.keeper end
    if slotType == "midfielder" then return pitch.midfielder end
    if slotType == "defender"   then return pitch.defenders[idx] end
    if slotType == "striker"    then return pitch.strikers[idx] end
    if slotType == "trap"       then return pitch.traps[idx] end
    return nil
end

-- Dashed outline following a rounded rect (dash 8, gap 6).
local function dashedRounded(x, y, w, h, r, color, alpha)
    local pts = Draw.roundedRectPoints(x, y, w, h, r, 4)
    pts[#pts + 1] = pts[1]; pts[#pts + 1] = pts[2]
    Draw.setColor(color, alpha)
    love.graphics.setLineWidth(2)
    local on, left = true, 8
    for i = 1, #pts - 2, 2 do
        local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local pos = 0
        while pos < len do
            local step = math.min(left, len - pos)
            if on then
                local a, b = pos / len, (pos + step) / len
                love.graphics.line(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)
            end
            pos, left = pos + step, left - step
            if left <= 0 then
                on = not on
                left = on and 8 or 6
            end
        end
    end
    love.graphics.setLineWidth(1)
end

local function drawGoals(P)
    local cy = P.y + P.h / 2
    Draw.sticker(P.x - 14, cy - 50, 22, 100, { r = 5, fill = Theme.white, border = 0, shadow = 3 })
    Draw.sticker(P.x + P.w - 8, cy - 50, 22, 100, { r = 5, fill = Theme.white, border = 0, shadow = 3 })
end

local function drawGrass(P)
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 22, fill = GRASS_A, border = 4, shadow = 6 })
    local ix, iy, iw, ih = P.x + 4, P.y + 4, P.w - 8, P.h - 8
    local n = 17                       -- first and last stripes are base colour (rounded corners)
    local sw = iw / n
    Draw.setColor(GRASS_B)
    for i = 1, n - 2, 2 do love.graphics.rectangle("fill", ix + i * sw, iy, sw, ih) end
end

local function drawMarkings(P)
    local cx, cy = Layout.midX, P.y + P.h / 2
    local x0, x1 = P.x + 4, P.x + P.w - 4
    Draw.setColor(LINE)
    love.graphics.setLineWidth(4)
    love.graphics.line(cx, P.y + 4, cx, P.y + P.h - 4)
    love.graphics.circle("line", cx, cy, 70, 48)
    love.graphics.circle("fill", cx, cy, 6, 16)
    for _, side in ipairs({ { x0, 1 }, { x1, -1 } }) do
        local gx, dir = side[1], side[2]
        local bx, gax = gx + dir * 196, gx + dir * 70
        love.graphics.line(gx, cy - 150, bx, cy - 150, bx, cy + 150, gx, cy + 150)   -- penalty box
        love.graphics.line(gx, cy - 75, gax, cy - 75, gax, cy + 75, gx, cy + 75)     -- goal area
        love.graphics.circle("fill", gx + dir * 140, cy, 4, 12)                       -- penalty spot
    end
    love.graphics.setLineWidth(1)
end

-- style: "valid" (pulsing white) | "target" (red) | nil
local function drawEmpty(r, label, style, isTrap)
    local rad  = r.w < 80 and 9 or 14
    local tint = isTrap and TRAP_TINT or Theme.white
    Draw.roundedFill(r.x, r.y, r.w, r.h, rad, { tint[1], tint[2], tint[3], 0.16 })
    local a = 0.55
    if style == "valid" then
        local p = pulse(6)
        Draw.glow(r.x, r.y, r.w, r.h, rad, Theme.highlight.valid, 0.5 + 0.6 * p)
        a = 0.7 + 0.3 * p
    elseif style == "target" then
        Draw.glow(r.x, r.y, r.w, r.h, rad, Theme.highlight.target, 0.6 + 0.6 * pulse(5))
        Draw.ring(r.x, r.y, r.w, r.h, rad, Theme.highlight.target, 3)
    end
    dashedRounded(r.x + 3, r.y + 3, r.w - 6, r.h - 6, rad - 2, tint, a)
    local small = r.w < 80
    Draw.text(label, r.x, r.y + r.h / 2 - (small and 7 or 11), r.w, "center", {
        size = small and 12 or 20, color = { 1, 1, 1, a },
    })
end

local function drawOccupied(pitched, r, owner, slotType, slotIndex, st, pitch, pop, highlight)
    local sa = st.selectedAttackerSlot
    local opts = {
        w = r.w, h = r.h, pitch = pitch, hideHidden = owner == "opponent",
        faceDown = (owner == "opponent") and not Card.showsFace(pitched),
        -- Position-switch ribbon (Phases.canSwitch via Card.switchLabel), your cards only.
        switchLabel = owner == "player" and Card.switchLabel(pitched, slotType, {
                          isOwnTurn = st.activePlayer == "player", phase = st.phase,
                          halfTimeBreak = st.halfTimeBreak }) or nil,
        selected = owner == "player" and sa ~= nil and sa.type == slotType and sa.index == slotIndex,
        target   = sa ~= nil and listHas(st.attackTargetSlots, owner, slotType, slotIndex),
    }
    if pop then
        local px, py = r.x + r.w / 2, r.y + r.h
        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.scale(pop.sx, pop.sy)
        love.graphics.translate(-px, -py)
    end
    if highlight then Draw.glow(r.x, r.y, r.w, r.h, 14, Theme.highlight.valid, 0.5 + 0.6 * pulse(6)) end
    Card.drawPitched(pitched, r.x, r.y, opts)
    if pop then love.graphics.pop() end
end

function Pitch.draw(match, st, anims)
    if not match then return {} end
    st = st or {}
    st.activePlayer  = match.activePlayer
    st.halfTimeBreak = match.halfTimeBreak
    anims = anims or {}
    local hidden, pops = anims.hidden or {}, anims.pop or {}
    local P = Layout.pitch

    drawGoals(P)
    drawGrass(P)
    drawMarkings(P)

    local crown = Stats.crownOwner(match)
    local hitboxes = {}

    for _, s in ipairs(Layout.slots()) do
        local pitch = match.players[s.owner].pitch
        local card  = cardIn(pitch, s.slotType, s.slotIndex)
        local key   = Pitch.slotKey(s.owner, s.slotType, s.slotIndex)
        local valid  = listHas(st.highlightedSlots, s.owner, s.slotType, s.slotIndex)
        local target = st.selectedAttackerSlot ~= nil and listHas(st.attackTargetSlots, s.owner, s.slotType, s.slotIndex)
        if card and not hidden[key] then
            drawOccupied(card, s, s.owner, s.slotType, s.slotIndex, st, pitch, pops[key], valid)
            if crown == s.owner and s.slotType == "midfielder" then
                Draw.star(s.x + s.w / 2, s.y - 26, 15, Theme.highlight.selected)
            end
        else
            drawEmpty(s, LABEL[s.slotType], target and "target" or (valid and "valid" or nil), false)
        end
        hitboxes[#hitboxes + 1] = { x = s.x, y = s.y, w = s.w, h = s.h,
            slotType = s.slotType, slotIndex = s.slotIndex, owner = s.owner }
    end

    for _, s in ipairs(Layout.trapSlots()) do
        local card  = match.players[s.owner].pitch.traps[s.slotIndex]
        local key   = Pitch.slotKey(s.owner, "trap", s.slotIndex)
        local valid = listHas(st.highlightedSlots, s.owner, "trap", s.slotIndex)
        if card and not hidden[key] then
            drawOccupied(card, s, s.owner, "trap", s.slotIndex, st, nil, pops[key], false)
        else
            drawEmpty(s, "TRAP", valid and "valid" or nil, true)
        end
        if s.owner == "player" then     -- only your own trap zone is clickable
            hitboxes[#hitboxes + 1] = { x = s.x, y = s.y, w = s.w, h = s.h,
                slotType = "trap", slotIndex = s.slotIndex, owner = s.owner }
        end
    end

    return hitboxes
end

return Pitch
