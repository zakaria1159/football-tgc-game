-- Fanned-hand geometry with macOS-Dock-style magnification. Pure (unit-tested).
-- Each card is drawn as: translate(cx, by) · rotate(angle) · scale(scale) · card at (-W/2, -H).
local HandFan = {}

HandFan.CARD_W, HandFan.CARD_H = 120, 165   -- Theme.cardSize.hand
HandFan.MAX_SPACING = 112    -- centre-to-centre at rest
HandFan.ANGLE_STEP  = 0.06   -- radians between neighbours
HandFan.MAX_ANGLE   = 0.20   -- outermost card rotation cap
HandFan.ARC_DROP    = 2.5    -- px × (offset from centre)²
HandFan.BOOST       = 0.35   -- hovered card scale = 1 + BOOST
HandFan.RADIUS      = 110    -- px from a card centre where magnification fades out
HandFan.LIFT        = 28     -- hovered card rises this much
HandFan.SELECT_LIFT = 18

local function smoothstep(t) return t * t * (3 - 2 * t) end

-- n cards in area { x, y, w, cx, baseY }. hoverX/hoverY = mouse (nil = none).
-- Returns cards[i] = { index, baseCx, cx, by, angle, scale, t } and a draw order
-- (index order, with the most-magnified card last).
function HandFan.layout(n, area, hoverX, hoverY, selectedIndex)
    local cards, order = {}, {}
    if n <= 0 then return cards, order end
    local W = HandFan.CARD_W
    local sp, step = HandFan.MAX_SPACING, HandFan.ANGLE_STEP
    if n > 1 then
        sp   = math.min(sp, (area.w - W) / (n - 1))
        step = math.min(step, HandFan.MAX_ANGLE / ((n - 1) / 2))
    end
    local mid = (n + 1) / 2
    local hovering = hoverX ~= nil and hoverY ~= nil and hoverY >= area.y
        and hoverX >= area.x - HandFan.RADIUS and hoverX <= area.x + area.w + HandFan.RADIUS
        and (area.maxHoverX == nil or hoverX <= area.maxHoverX)
    local hot, hotT = nil, 0

    for i = 1, n do
        local off = i - mid
        local baseCx = area.cx + off * sp
        local t = 0
        if hovering then
            local d = math.abs(hoverX - baseCx)
            if d < HandFan.RADIUS then t = smoothstep(1 - d / HandFan.RADIUS) end
        end
        if t > hotT then hot, hotT = i, t end
        local by = area.baseY + off * off * HandFan.ARC_DROP - HandFan.LIFT * t
        if i == selectedIndex then by = by - HandFan.SELECT_LIFT end
        cards[i] = {
            index = i, baseCx = baseCx, cx = baseCx, by = by, t = t,
            scale = 1 + HandFan.BOOST * t,
            angle = off * step * (1 - t),
        }
    end

    -- Each card grows equally to both sides: push the others away by half its growth.
    for i = 1, n do
        local shift = 0
        for j = 1, n do
            local grow = (cards[j].scale - 1) * W * 0.5
            if j < i then shift = shift + grow elseif j > i then shift = shift - grow end
        end
        cards[i].cx = cards[i].baseCx + shift
    end

    for i = 1, n do if i ~= hot then order[#order + 1] = i end end
    if hot then order[#order + 1] = hot end
    return cards, order
end

-- Index of the top-most card under (px, py), or nil. A few px below the card
-- bottom still counts so the screen edge is forgiving.
function HandFan.hit(cards, order, px, py)
    local W, H = HandFan.CARD_W, HandFan.CARD_H
    for k = #order, 1, -1 do
        local c = cards[order[k]]
        local dx, dy = px - c.cx, py - c.by
        local cs, sn = math.cos(-c.angle), math.sin(-c.angle)
        local lx = (dx * cs - dy * sn) / c.scale
        local ly = (dx * sn + dy * cs) / c.scale
        if lx >= -W / 2 and lx <= W / 2 and ly >= -H and ly <= 12 then return c.index end
    end
    return nil
end

-- Axis-aligned screen rect of a card (rotation ignored) — used as an animation origin.
function HandFan.rect(c)
    local w, h = HandFan.CARD_W * c.scale, HandFan.CARD_H * c.scale
    return { x = c.cx - w / 2, y = c.by - h, w = w, h = h }
end

return HandFan
