local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local Stats  = require("ui.match.stats")

-- ── Press ─────────────────────────────────────────────────────────────────────

T.test("Press: summoning it exhausts the enemy's face-up defender with the highest DEF", function()
    local m = H.match({ phase = "summon" })
    local low  = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    local high = H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    T.eq(H.store(m):summonCard(c.id, "striker", 1, "defense"), true)
    T.eq(high.exhausted, true); T.eq(low.exhausted, false)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PRESS"); T.eq(t[1].target.index, 2)
    -- It can't cover this turn: only `low` may cover an empty midfielder slot.
    T.eq(#Phases._eligibleCoverers(m.players.opponent.pitch, H.slot("midfielder")), 1)
    Phases.endTurn(m)
    T.eq(high.exhausted, false); T.eq(high.pressed, nil)
end)

T.test("Press: with no face-up defender it exhausts a face-down one", function()
    local m = H.match({ phase = "summon" })
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m):summonCard(c.id, "striker", 1, "attack")
    T.eq(fd.exhausted, true)
end)

T.test("Press: nothing to press without enemy defenders", function()
    local m = H.match({ phase = "summon" })
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m):summonCard(c.id, "striker", 1, "attack")
    T.eq(#H.triggers(m), 0)
end)

-- ── Metronome ─────────────────────────────────────────────────────────────────

local function midfieldTurn(myMid)
    local m = H.match({ turn = 3, phase = "draw" })
    H.place(m, "player", "midfielder", 0, myMid, "defense")               -- DEF 1700 in control
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1600, 1400))
    return m, H.store(m)
end

T.test("Metronome: controlling midfield also gives +1 summon this turn", function()
    local m, s = midfieldTurn(H.kw("METRONOME", "midfielder", 1500, 1700))
    s:drawPhase()
    T.eq(m.bonusSummons, 1)
    T.eq(H.triggers(m)[1].keyword, "METRONOME")
    local used, max = Stats.summons(m)
    T.eq(used, 0); T.eq(max, 3)
    H.give(m, "player", H.card("striker", 2000, 500))
    local h = m.players.player.hand                     -- 2 drawn + 1 given
    T.eq(#h, 3)
    T.eq(s:summonCard(h[1].id, "defender", 1, "defense"), true)
    T.eq(s:summonCard(h[1].id, "defender", 2, "defense"), true)
    T.eq(s:summonCard(h[1].id, "striker", 1, "attack"), true)
    H.give(m, "player", H.card("striker", 2000, 500))
    local ok, err = s:summonCard(h[1].id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "summon limit reached")
    Phases.endTurn(m)
    T.eq(m.bonusSummons, 0)
end)

T.test("Metronome: a plain midfielder in control gives no extra summon", function()
    local m, s = midfieldTurn(H.card("midfielder", 1500, 1700))
    s:drawPhase()
    T.eq(m.bonusSummons or 0, 0)
    T.eq(#H.triggers(m), 0)
    T.eq(#m.players.player.hand, 2)
end)
