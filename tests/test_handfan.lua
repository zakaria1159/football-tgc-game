local T       = require("tests.t")
local HandFan = require("ui.match.handfan")

local AREA = { x = 444, y = 540, w = 512, cx = 700, baseY = 782 }
local W, H = HandFan.CARD_W, HandFan.CARD_H

T.test("empty hand returns nothing", function()
    local cards, order = HandFan.layout(0, AREA)
    T.eq(#cards, 0); T.eq(#order, 0)
end)

T.test("cards are centred and symmetric at rest", function()
    local c = HandFan.layout(5, AREA)
    T.near(c[3].cx, 700); T.near(c[3].angle, 0)
    T.near(c[1].cx + c[5].cx, 1400)
    T.near(c[1].angle, -c[5].angle)
    T.ok(c[1].angle < 0 and c[5].angle > 0)
    T.ok(c[1].by > c[3].by, "edges droop along the arc")
end)

T.test("spacing shrinks so big hands fit the area", function()
    local c = HandFan.layout(9, AREA)
    T.ok(c[9].cx - c[1].cx + W <= AREA.w + 1e-9)
end)

T.test("hovered card grows, straightens, lifts and is drawn last", function()
    local rest = HandFan.layout(5, AREA)
    local c, order = HandFan.layout(5, AREA, rest[2].baseCx, 700)
    T.near(c[2].scale, 1 + HandFan.BOOST)
    T.near(c[2].angle, 0)
    T.near(c[2].by, AREA.baseY + HandFan.ARC_DROP - HandFan.LIFT)
    T.near(c[2].cx, rest[2].baseCx, 1e-6)
    T.eq(order[#order], 2)
end)

T.test("neighbours are pushed away from the hovered card", function()
    local rest = HandFan.layout(5, AREA)
    local c = HandFan.layout(5, AREA, rest[3].baseCx, 700)
    T.ok(c[2].cx < c[2].baseCx); T.ok(c[4].cx > c[4].baseCx)
    T.near(c[3].cx, c[3].baseCx)
end)

T.test("mouse above the hand area does not magnify", function()
    local c = HandFan.layout(5, AREA, 700, 400)
    for i = 1, 5 do T.near(c[i].scale, 1) end
end)

T.test("hit finds the rotated card under the point", function()
    local c, order = HandFan.layout(5, AREA)
    local px = c[1].cx + (H / 2) * math.sin(c[1].angle)
    local py = c[1].by - (H / 2) * math.cos(c[1].angle)
    T.eq(HandFan.hit(c, order, px, py), 1)
    T.eq(HandFan.hit(c, order, 0, 0), nil)
    local hc, horder = HandFan.layout(5, AREA, c[3].baseCx, 700)
    T.eq(HandFan.hit(hc, horder, c[3].baseCx, AREA.baseY - 60), 3)
end)

T.test("selected card lifts", function()
    local c = HandFan.layout(5, AREA, nil, nil, 2)
    T.near(c[2].by, AREA.baseY + HandFan.ARC_DROP - HandFan.SELECT_LIFT)
end)
