local T       = require("tests.t")
local Library = require("ui.menu.library")

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

T.test("tabs run left to right without overlapping the close button or the grid", function()
    local tabs = Library.tabRects()
    T.eq(#tabs, 7); T.eq(tabs[1].key, "all"); T.eq(tabs[7].key, "strategy")
    for i = 2, #tabs do
        T.ok(tabs[i].x >= tabs[i - 1].x + tabs[i - 1].w + Library.TAB_GAP - 1e-9)
    end
    for _, t in ipairs(tabs) do
        T.ok(not overlap(t, Library.CLOSE)); T.ok(t.y + t.h <= Library.VIEW.y)
    end
end)

T.test("tabAt maps tab centres", function()
    for _, t in ipairs(Library.tabRects()) do
        T.eq(Library.tabAt(t.x + t.w / 2, t.y + t.h / 2), t.key)
    end
    T.eq(Library.tabAt(640, 400), nil)
end)

T.test("grid cells: 7 columns of hand-size cards, rows 212px apart", function()
    local a = Library.cellRect(1, 0)
    T.eq(a.x, 100); T.eq(a.y, 166); T.eq(a.w, 120); T.eq(a.h, 165)
    T.eq(Library.cellRect(7, 0).x, 1060)
    local b = Library.cellRect(8, 0); T.eq(b.x, 100); T.eq(b.y, 378)
    T.eq(Library.cellRect(8, 100).y, 278)
    T.ok(Library.cellRect(7, 0).x + 120 <= 1280 - 40)
end)

T.test("maxScroll / clampScroll", function()
    T.eq(Library.maxScroll(0), 0); T.eq(Library.maxScroll(7), 0)
    T.eq(Library.maxScroll(40), 638)
    T.eq(Library.clampScroll(-50, 40), 0)
    T.eq(Library.clampScroll(9999, 40), 638)
    T.eq(Library.clampScroll(300, 40), 300)
end)

T.test("cardAt only hits cards inside the grid viewport", function()
    T.eq(Library.cardAt(160, 250, 10, 0), 1)
    T.eq(Library.cardAt(260, 250, 10, 0), 2)
    T.eq(Library.cardAt(240, 250, 10, 0), nil)     -- gap between columns
    T.eq(Library.cardAt(160, 250, 0, 0), nil)
    T.eq(Library.cardAt(160, 160, 10, 80), 1)      -- visible part of a card scrolled half out
    T.eq(Library.cardAt(160, 140, 10, 80), nil)    -- same card, above the viewport
end)

T.test("filter keeps one card type", function()
    local cards = { { type = "striker" }, { type = "trap" }, { type = "striker" } }
    T.eq(#Library.filter(cards, "all"), 3)
    T.eq(#Library.filter(cards, "striker"), 2)
    T.eq(#Library.filter(cards, "keeper"), 0)
end)

T.test("input: wheel clamps, arrows cycle tabs, Esc and the close button close", function()
    Library.open()
    local f, s = Library.state(); T.eq(f, "all"); T.eq(s, 0)
    Library.wheelmoved(0, -1000)
    f, s = Library.state(); T.ok(s > 0, "all cards need scrolling")
    Library.wheelmoved(0, 1000)
    f, s = Library.state(); T.eq(s, 0)
    Library.keypressed("right"); f = Library.state(); T.eq(f, "striker")
    Library.keypressed("left"); Library.keypressed("left"); f = Library.state(); T.eq(f, "strategy")
    T.eq(Library.keypressed("escape"), "close")
    local C = Library.CLOSE
    T.eq(Library.mousepressed(C.x + 10, C.y + 10, 1), "close")
    local tab = Library.tabRects()[6]
    T.eq(Library.mousepressed(tab.x + 5, tab.y + 5, 1), nil)
    T.eq(Library.state(), "trap")
end)
