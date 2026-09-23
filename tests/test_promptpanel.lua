local T     = require("tests.t")
local Panel = require("ui.overlay.promptpanel")

local function inside(r, box)
    return r.x >= box.x and r.y >= box.y and r.x + r.w <= box.x + box.w and r.y + r.h <= box.y + box.h
end
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

T.test("panel layout fits 1 to 3 options without overlaps and keeps the pitch visible", function()
    for n = 1, 3 do
        local L = Panel.layout(n, 0)
        local rects = { L.source, L.info, L.pass }
        for _, o in ipairs(L.options) do rects[#rects + 1] = o.card; rects[#rects + 1] = o.button end
        T.eq(#L.options, n)
        for i = 1, #rects do
            T.ok(inside(rects[i], L.panel), "n=" .. n .. " rect " .. i .. " outside the panel")
            for j = i + 1, #rects do
                T.ok(not overlap(rects[i], rects[j]), "n=" .. n .. " overlap " .. i .. "/" .. j)
            end
        end
        T.ok(L.panel.y + L.panel.h <= 800 - 6, "panel + shadow on screen")
        T.ok(L.panel.y >= 540, "pitch (y < 520) stays visible")
    end
    T.eq(#Panel.layout(5, 0).options, Panel.MAX_OPTIONS)
end)

T.test("sliding moves every rect by the same offset", function()
    local a, b = Panel.layout(2, 0), Panel.layout(2, 100)
    T.eq(b.panel.y - a.panel.y, 100); T.eq(b.pass.y - a.pass.y, 100)
    T.eq(b.options[2].button.y - a.options[2].button.y, 100); T.eq(b.source.x, a.source.x)
end)

T.test("cover hitboxes: a COVER per coverer (button and card), LET THROUGH last", function()
    local cw = { eligibleCoverers = { { type = "defender", index = 1, card = {} },
                                      { type = "defender", index = 2, card = {} } } }
    local boxes = Panel.coverHitboxes(cw, 0)
    local L = Panel.layout(2, 0)
    T.eq(#boxes, 5)
    T.eq(boxes[1].type, "cover"); T.eq(boxes[1].coverer.type, "defender"); T.eq(boxes[1].coverer.index, 1)
    T.eq(boxes[1].x, L.options[1].button.x); T.eq(boxes[2].x, L.options[1].card.x)
    T.eq(boxes[3].coverer.index, 2)
    T.eq(boxes[5].type, "letthrough"); T.eq(boxes[5].x, L.pass.x)
end)

T.test("trap hitboxes: ACTIVATE per trap (button and card) with its index, PASS last", function()
    local tw = { traps = { { card = {}, slotIndex = 2 } } }
    local boxes = Panel.trapHitboxes(tw, 10)
    T.eq(#boxes, 3)
    T.eq(boxes[1].type, "activate"); T.eq(boxes[1].trapIndex, 1)
    T.eq(boxes[2].trapIndex, 1)
    T.eq(boxes[3].type, "pass"); T.eq(boxes[3].y, Panel.layout(1, 10).pass.y)
end)

T.test("no window, no hitboxes", function()
    T.eq(#Panel.coverHitboxes(nil, 0), 0); T.eq(#Panel.trapHitboxes(nil, 0), 0)
end)

T.test("trap window titles", function()
    T.eq(Panel.trapTitle("pre_attack"), "TRAP WINDOW · STRIKER ATTACKS")
    T.eq(Panel.trapTitle("counter_red_card"), "COUNTER TRAP · RED CARD INCOMING")
    T.eq(Panel.trapTitle("??"), "TRAP WINDOW")
end)
