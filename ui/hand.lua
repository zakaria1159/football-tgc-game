local Theme = require("ui.theme")
local Card  = require("ui.card")
local Fonts = require("ui.fonts")

local Hand = {}

-- Dock magnification constants
local MAG_BOOST  = 0.52   -- hovered card grows to 1.52x its base size
local MAG_RADIUS = 115    -- px from card centre where influence fades to zero

local function dockScale(dist)
    if dist >= MAG_RADIUS then return 1.0 end
    local t = 1.0 - dist / MAG_RADIUS
    t = t * t * (3 - 2 * t)   -- smoothstep
    return 1.0 + MAG_BOOST * t
end

function Hand.draw(hand, selectedCardId, hoverX)
    if not hand then return {} end

    local L      = Theme.layout
    local H      = love.graphics.getHeight()
    local handY  = H - L.handH
    local GAP    = Theme.card.gap
    local baseH  = math.min(Theme.card.h, L.handH - 10)
    local baseW  = math.floor(Theme.card.w * (baseH / Theme.card.h))

    -- Background strip
    love.graphics.setColor(0.025, 0.025, 0.035, 1)
    love.graphics.rectangle("fill", 0, handY, L.pitchW, L.handH)
    love.graphics.setColor(0.038, 0.038, 0.050, 1)
    love.graphics.rectangle("fill", 2, handY + 2, L.pitchW - 4, L.handH - 2)

    -- Top border glow
    love.graphics.setColor(0.28, 0.28, 0.40, 0.30)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, handY, L.pitchW, handY)
    love.graphics.setColor(0.35, 0.35, 0.50, 0.70)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(0, handY + 1, L.pitchW, handY + 1)
    love.graphics.setLineWidth(1)

    -- "YOUR HAND" label
    Fonts.with(9, function()
        love.graphics.setColor(0.40, 0.40, 0.55, 1)
        love.graphics.print("YOUR HAND  (" .. #hand .. ")", L.pitchX + 6, handY + 5)
    end)

    if #hand == 0 then return {} end

    -- ── Dock magnification ────────────────────────────────────────────────────
    -- Step 1: compute scale for each card using unshifted base centres
    local totalBaseW = #hand * (baseW + GAP) - GAP
    local baseStart  = math.max(10, (L.pitchW - totalBaseW) / 2)

    local scales = {}
    for i = 1, #hand do
        local cx = baseStart + (i - 1) * (baseW + GAP) + baseW * 0.5
        scales[i] = hoverX and dockScale(math.abs(hoverX - cx)) or 1.0
    end

    -- Step 2: compute x positions using scaled widths (cards shift to make room)
    local totalScaledW = -GAP
    for i = 1, #hand do
        totalScaledW = totalScaledW + math.floor(baseW * scales[i]) + GAP
    end
    local curX   = math.max(10, (L.pitchW - totalScaledW) / 2)
    local bottomY = H - 6   -- cards are bottom-anchored here

    -- ── Draw ──────────────────────────────────────────────────────────────────
    local hitboxes = {}
    for i, cardDef in ipairs(hand) do
        local sc  = scales[i]
        local w   = math.floor(baseW * sc)
        local h   = math.floor(baseH * sc)
        local x   = math.floor(curX)
        local y   = bottomY - h
        local sel = selectedCardId == cardDef.id
        if sel then y = y - 8 end

        local hbox = Card.drawInHand(cardDef, x, y, { selected = sel, w = w, h = h })
        hbox.cardId  = cardDef.id
        hbox.cardDef = cardDef
        -- Keep hitbox spanning the full strip height so clicking is forgiving
        hbox.y = handY + 4
        hbox.h = L.handH - 4
        table.insert(hitboxes, hbox)

        curX = curX + w + GAP
    end

    return hitboxes
end

return Hand
