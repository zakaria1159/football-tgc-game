-- Player hand: fanned, rotated hand-size cards with Dock magnification.
-- Card size never changes (scale/rotate transforms only) so card meshes stay cached.
-- Hand.draw returns a hit structure { cards, order, defs } for Hand.hit / Hand.rectOf.
local Card    = require("ui.card")
local HandFan = require("ui.match.handfan")
local Layout  = require("ui.match.layout")

local Hand = {}

function Hand.draw(hand, selectedCardId, mouseX, mouseY)
    -- Shallow copy: a click between draw and a hand mutation must still map to the drawn card.
    local defs = {}
    for i, d in ipairs(hand or {}) do defs[i] = d end
    local hb = { cards = {}, order = {}, defs = defs }
    if #defs == 0 then return hb end
    local sel = nil
    for i, c in ipairs(hand) do
        if selectedCardId and c.id == selectedCardId then sel = i; break end
    end
    local cards, order = HandFan.layout(#hand, Layout.bottom.hand, mouseX, mouseY, sel)
    local W, H = HandFan.CARD_W, HandFan.CARD_H
    for _, i in ipairs(order) do
        local c = cards[i]
        love.graphics.push()
        love.graphics.translate(c.cx, c.by)
        love.graphics.rotate(c.angle)
        love.graphics.scale(c.scale, c.scale)
        Card.drawFace(hand[i], -W / 2, -H, W, H, { selected = (i == sel) })
        love.graphics.pop()
    end
    hb.cards, hb.order = cards, order
    return hb
end

-- cardDef, index, screen rect of the top-most hand card under (x, y); nil if none.
function Hand.hit(hb, x, y)
    if not hb or not hb.cards or #hb.cards == 0 then return nil end
    local i = HandFan.hit(hb.cards, hb.order, x, y)
    if not i then return nil end
    return hb.defs[i], i, HandFan.rect(hb.cards[i])
end

-- Screen rect of the first hand card with this id (animation origin), or nil.
function Hand.rectOf(hb, cardId)
    if not hb or not hb.defs then return nil end
    for i, d in ipairs(hb.defs) do
        if d.id == cardId and hb.cards[i] then return HandFan.rect(hb.cards[i]) end
    end
    return nil
end

return Hand
