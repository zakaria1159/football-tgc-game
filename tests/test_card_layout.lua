local T     = require("tests.t")
local Card  = require("ui.card")

T.test("layout at pitch size uses scale 1", function()
    local L = Card.layout(108, 148)
    T.near(L.s, 1)
    T.eq(L.border, 4)
    T.eq(L.r, 14)
end)

local SIZES = { { 68, 80 }, { 84, 106 }, { 108, 148 }, { 120, 165 }, { 300, 410 } }

T.test("ribbon is wider than the card and sits above the badges", function()
    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local L = Card.layout(w, h)
        T.ok(L.ribbon.x < 0 and L.ribbon.x + L.ribbon.w > w, "ribbon overhangs both sides at " .. w)
        T.ok(L.ribbon.y + L.ribbon.h <= L.atk.cy - L.atk.size * 0.25, "ribbon above badge centers at " .. w)
    end
end)

T.test("badges sit on the bottom corners", function()
    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local L = Card.layout(w, h)
        T.ok(L.atk.cx < w * 0.2 and L.def.cx > w * 0.8, "badges on the sides at " .. w)
        T.ok(L.atk.cy > h * 0.85 and L.def.cy > h * 0.85, "badges at the bottom at " .. w)
    end
end)

T.test("art icon stays inside the card body", function()
    for _, sz in ipairs(SIZES) do
        local L = Card.layout(sz[1], sz[2])
        T.ok(L.icon.cy - L.icon.size / 2 >= 0, "icon top inside at " .. sz[1])
        T.ok(L.icon.cy + L.icon.size / 2 <= L.ribbon.y + 2, "icon above ribbon at " .. sz[1])
    end
end)

T.test("scale follows width", function()
    T.near(Card.layout(300, 410).s, 300 / 108)
    T.near(Card.layout(54, 74).s, 0.5)
end)
