local Theme = require("ui.theme")
local Card  = require("ui.card")
local Fonts = require("ui.fonts")

local Hand = {}

function Hand.draw(hand, selectedCardId)
    if not hand then return {} end

    local L     = Theme.layout
    local H     = love.graphics.getHeight()
    local handY = H - L.handH
    local GAP   = Theme.card.gap
    local CH    = math.min(Theme.card.h, L.handH - 10)
    local CW    = math.floor(Theme.card.w * (CH / Theme.card.h))
    local padY  = math.max(4, (L.handH - CH) / 2)

    -- Background strip (layered depth)
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

    local hitboxes = {}
    local totalW   = #hand * (CW + GAP) - GAP
    local startX   = math.max(10, (L.pitchW - totalW) / 2)

    -- Fan effect: cards near center rise slightly
    local cardCount = #hand
    local centerIdx = (cardCount + 1) / 2

    for i, cardDef in ipairs(hand) do
        local x   = startX + (i - 1) * (CW + GAP)
        local dist = math.abs(i - centerIdx)
        local lift = math.max(0, 8 - dist * 3)  -- center cards rise slightly
        local cy  = handY + padY - lift
        local sel = selectedCardId == cardDef.id
        -- selected card lifts higher
        if sel then cy = cy - 10 end
        local hbox = Card.drawInHand(cardDef, x, cy, { selected = sel, w = CW, h = CH })
        hbox.cardId  = cardDef.id
        hbox.cardDef = cardDef
        -- keep hitbox at non-lifted position for easier clicking
        hbox.y = handY + padY - (sel and 10 or 0)
        table.insert(hitboxes, hbox)
    end

    return hitboxes
end

return Hand
