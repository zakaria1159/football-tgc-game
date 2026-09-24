local T        = require("tests.t")
local MatchEnd = require("ui.overlay.matchend")

T.test("half-time ribbon text", function()
    T.eq(MatchEnd.halfText(1, 1, 0), "HALF TIME · YOU 1 – 0 OPP")
    T.eq(MatchEnd.halfText(2, 1, 1), "FULL TIME · YOU 1 – 1 OPP · EXTRA TIME")
    T.eq(MatchEnd.halfText("extra", 2, 1), "EXTRA TIME OVER · YOU 2 – 1 OPP")
end)

T.test("match-end buttons and keys", function()
    local a, b = MatchEnd.PLAY_AGAIN, MatchEnd.MAIN_MENU
    T.eq(MatchEnd.actionAt(a.x + a.w / 2, a.y + a.h / 2), "restart")
    T.eq(MatchEnd.actionAt(b.x + b.w / 2, b.y + b.h / 2), "home")
    T.eq(MatchEnd.actionAt(640, 100), nil)
    T.ok(a.x + a.w < b.x); T.near((a.x + b.x + b.w) / 2, 640)
    T.eq(MatchEnd.keyAction("r"), "restart"); T.eq(MatchEnd.keyAction("escape"), "home")
    T.eq(MatchEnd.keyAction("space"), nil)
end)

T.test("title and summary rows", function()
    T.eq((MatchEnd.title("player")), "VICTORY!"); T.eq((MatchEnd.title("opponent")), "DEFEAT")
    local m = { players = { player   = { lp = 1200, halvesWon = 2, totalDamageDealt = 5400 },
                            opponent = { lp = -300, halvesWon = 1, totalDamageDealt = 3100 } } }
    local rows = MatchEnd.rows(m)
    T.eq(#rows, 3)
    T.eq(rows[1].label, "FINAL LP"); T.eq(rows[1].you, 1200); T.eq(rows[1].opp, 0)
    T.eq(rows[2].you, 2); T.eq(rows[2].opp, 1)
    T.eq(rows[3].you, 5400); T.eq(rows[3].opp, 3100)
end)
