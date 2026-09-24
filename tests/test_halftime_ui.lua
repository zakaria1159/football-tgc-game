local T  = require("tests.t")
local HT = require("ui.overlay.halftime")

local function center(r) return r.x + r.w / 2, r.y + r.h / 2 end
local function hand(n)
    local h = {}
    for i = 1, n do h[i] = { id = "c" .. i, name = "Card " .. i, type = "striker" } end
    return h
end

T.test("half-time labels: 2nd half vs extra time", function()
    local l = HT.labels(2)
    T.eq(l.title, "HALF TIME"); T.eq(l.kick, "KICK OFF — 2ND HALF"); T.eq(l.banner, "SECOND HALF")
    l = HT.labels("extra")
    T.eq(l.title, "FULL TIME — EXTRA TIME"); T.eq(l.kick, "KICK OFF — EXTRA TIME"); T.eq(l.banner, "EXTRA TIME")
end)

T.test("score and stats rows for the half just played", function()
    local m = { players = { player = { halvesWon = 1 }, opponent = { halvesWon = 0 } },
                lastHalfStats = { player   = { lp = 2300, damage = 4000, goals = 2, lost = 1 },
                                  opponent = { lp = -500, damage = 1700, goals = 0, lost = 3 } } }
    T.eq(HT.score(m), "YOU 1 – 0 OPP")
    local rows = HT.rows(m.lastHalfStats)
    T.eq(#rows, 4)
    T.eq(rows[1].label, "LP LEFT");    T.eq(rows[1].you, 2300); T.eq(rows[1].opp, 0, "LP never below 0")
    T.eq(rows[2].label, "DAMAGE");     T.eq(rows[2].you, 4000); T.eq(rows[2].opp, 1700)
    T.eq(rows[3].label, "GOALS");      T.eq(rows[3].you, 2);    T.eq(rows[3].opp, 0)
    T.eq(rows[4].label, "CARDS LOST"); T.eq(rows[4].you, 1);    T.eq(rows[4].opp, 3)
    rows = HT.rows(nil)
    T.eq(#rows, 4); T.eq(rows[1].you, 0); T.eq(rows[4].opp, 0)
end)

T.test("card layout: a centred row, no overlaps, above the buttons", function()
    local rs = HT.cardRects(5)
    T.eq(#rs, 5)
    T.near((rs[1].x + rs[5].x + rs[5].w) / 2, 640)
    for i = 2, 5 do T.ok(rs[i].x >= rs[i - 1].x + rs[i - 1].w, "no overlap " .. i) end
    T.ok(rs[1].y + rs[1].h < HT.SWAP_BTN.y and rs[1].y - HT.LIFT > HT.STATS.y + HT.STATS.h)
    T.ok(HT.SWAP_BTN.x + HT.SWAP_BTN.w < HT.KICK_BTN.x)
    T.near((HT.SWAP_BTN.x + HT.KICK_BTN.x + HT.KICK_BTN.w) / 2, 640)
end)

T.test("selection: toggle, at most 3, selected cards lift", function()
    local s = HT.new()
    T.eq(HT.count(s), 0); T.ok(not HT.canSwap(s))
    T.ok(HT.toggle(s, 2, 5)); T.ok(HT.toggle(s, 4, 5)); T.ok(HT.toggle(s, 5, 5))
    T.eq(HT.count(s), 3); T.ok(HT.canSwap(s))
    T.ok(not HT.toggle(s, 1, 5), "a 4th card is refused"); T.eq(HT.count(s), 3)
    T.ok(HT.toggle(s, 4, 5), "unselect"); T.eq(HT.count(s), 2)
    T.ok(not HT.toggle(s, 6, 5), "out of range")
    local rest, lifted = HT.cardRects(5)[1], HT.cardRect(s, 2, 5)
    T.eq(lifted.y, rest.y - HT.LIFT); T.eq(HT.cardRect(s, 1, 5).y, rest.y)
    local ids = HT.selectedIds(s, hand(5))
    T.eq(#ids, 2); T.eq(ids[1], "c2"); T.eq(ids[2], "c5")
end)

T.test("swap button label and state", function()
    local s = HT.new()
    T.eq(HT.swapLabel(s), "SWAP")
    HT.toggle(s, 1, 5); T.eq(HT.swapLabel(s), "SWAP 1 CARD")
    HT.toggle(s, 3, 5); T.eq(HT.swapLabel(s), "SWAP 2 CARDS")
    HT.afterSwap(s, 5, 2)
    T.ok(s.swapped); T.eq(HT.count(s), 0); T.ok(not HT.canSwap(s)); T.eq(HT.swapLabel(s), "SWAPPED")
    T.ok(not HT.toggle(s, 1, 5), "no selection after the swap")
    T.ok(HT.isNew(s, 4) and HT.isNew(s, 5) and not HT.isNew(s, 3), "drawn cards are the last n")
end)

T.test("mouse: cards toggle, SWAP only when enabled, KICK OFF", function()
    local s = HT.new()
    T.eq(HT.actionAt(s, 5, center(HT.KICK_BTN)), "kickoff")
    T.eq(HT.actionAt(s, 5, center(HT.SWAP_BTN)), nil, "disabled SWAP")
    local a, i = HT.actionAt(s, 5, center(HT.cardRects(5)[3]))
    T.eq(a, "toggle"); T.eq(i, 3)
    HT.toggle(s, 3, 5)
    a, i = HT.actionAt(s, 5, center(HT.cardRect(s, 3, 5)))
    T.eq(a, "toggle"); T.eq(i, 3, "a lifted card is hit where it is drawn")
    T.eq(HT.actionAt(s, 5, center(HT.SWAP_BTN)), "swap")
    T.eq(HT.actionAt(s, 5, 5, 5), nil)
end)

T.test("keyboard: Enter kicks off, S swaps, 1-5 toggle, Esc pauses", function()
    T.eq(HT.keyAction("return"), "kickoff"); T.eq(HT.keyAction("kpenter"), "kickoff")
    T.eq(HT.keyAction("s"), "swap"); T.eq(HT.keyAction("escape"), "pause")
    local a, i = HT.keyAction("1"); T.eq(a, "toggle"); T.eq(i, 1)
    a, i = HT.keyAction("5"); T.eq(a, "toggle"); T.eq(i, 5)
    T.eq(HT.keyAction("6"), nil); T.eq(HT.keyAction("space"), nil)
end)
