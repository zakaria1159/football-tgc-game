local T = require("tests.t")
local H = require("tests.helpers")

-- ── Last-ditch tackle: a coverer that loses is exhausted, not destroyed ───────

-- Striker (player) attacks the empty defender slot 1; the opponent covers with `coverer`.
local function coverFight(atk, slotType, index, covererDef, mode)
    local m = H.match()
    local st = H.place(m, "player", "striker", 1, H.card("striker", atk, 500))
    local c  = H.place(m, "opponent", slotType, index, covererDef, mode)
    local s  = H.store(m)
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "cover_needed")
    local r = s:resolveCover(H.slot(slotType, index))
    return m, s, r, st, c
end

T.test("Last-ditch tackle: a losing cover stops the attack; the coverer survives exhausted", function()
    local m, s, r, st, mid = coverFight(2000, "midfielder", 0, H.card("midfielder", 1700, 1400))
    T.eq(r.outcome, "tackled"); T.eq(r.defenderDestroyed, false); T.eq(r.damage, 0)
    T.eq(m.players.opponent.pitch.midfielder, mid)
    T.eq(mid.exhausted, true); T.eq(mid.cannotActNextTurn, true)
    T.eq(m.players.player.pitch.strikers[1], st); T.eq(st.exhausted, true)
    T.eq(m.players.opponent.lp, 4000); T.eq(m.players.player.lp, 4000)   -- no LP, no goal
    T.eq(#H.events(m, "lp_damage"), 0); T.eq(#H.events(m, "defender_destroy"), 0)
    local covers = H.events(m, "cover")
    T.eq(#covers, 2); T.eq(covers[2].payload.outcome, "tackled")
    T.eq(s.combatQueue[1].outcome, "tackled")
    T.eq(s.coverWindow, nil); T.eq(s.trapWindow, nil)
end)

T.test("Last-ditch tackle: a losing Sweeper is exhausted but not locked", function()
    local m, _, r, _, lib = coverFight(2000, "defender", 2, H.kw("SWEEPER", "defender", 1600, 1500))
    T.eq(r.outcome, "tackled")
    T.eq(m.players.opponent.pitch.defenders[2], lib)
    T.eq(lib.exhausted, true); T.eq(lib.cannotActNextTurn, false)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "SWEEPER")
end)

T.test("Last-ditch tackle: an Off the line keeper that loses survives, unlocked", function()
    local m, _, r, _, k = coverFight(2000, "keeper", 0, H.kw("OFF_THE_LINE", "keeper", 400, 1800), "defense")
    T.eq(r.outcome, "tackled")
    T.eq(m.players.opponent.pitch.keeper, k)
    T.eq(k.exhausted, true); T.eq(k.cannotActNextTurn, false); T.eq(k.revealed, true)
    T.eq(m.players.opponent.lp, 4000)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OFF_THE_LINE")
end)

T.test("Last-ditch tackle: Counter-press still adds DEF and triggers on a lost cover", function()
    local m, s, r = coverFight(2000, "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    T.eq(r.outcome, "tackled"); T.eq(r.defStat, 1700)
    T.eq(s.combatQueue[1].defender.def, 1700)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "COUNTER_PRESS")
end)

T.test("Last-ditch tackle: Intercept still triggers on a lost cover", function()
    local m, _, r, _, pb = coverFight(2000, "defender", 2, H.kw("INTERCEPT", "defender", 950, 1800))
    T.eq(r.outcome, "tackled"); T.eq(pb.cannotActNextTurn, true)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "INTERCEPT")
end)

T.test("Last-ditch tackle: a Hard tackle coverer still locks the attacker", function()
    local m, _, r, st = coverFight(2000, "midfielder", 0, H.kw("HARD_TACKLE", "midfielder", 900, 1500))
    T.eq(r.outcome, "tackled"); T.eq(st.lockedNextTurn, true)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "HARD_TACKLE")
end)

T.test("Last-ditch tackle: a winning cover is unchanged (attacker destroyed, LP damage)", function()
    local m, _, r, _, mid = coverFight(1300, "midfielder", 0, H.card("midfielder", 1700, 1400))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(m.players.player.lp, 3900)
    T.eq(mid.exhausted, false); T.eq(mid.cannotActNextTurn, true)
end)

T.test("Last-ditch tackle: a tied cover still destroys both", function()
    local m, _, r = coverFight(1400, "midfielder", 0, H.card("midfielder", 1700, 1400))
    T.eq(r.outcome, "tie")
    T.eq(m.players.player.pitch.strikers[1], nil); T.eq(m.players.opponent.pitch.midfielder, nil)
end)

T.test("Last-ditch tackle: the AI's Red Card doesn't fire either", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    H.trap(m, "opponent", "trap-red-card")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(s:resolveCover(H.slot("midfielder")).outcome, "tackled")
    T.eq(#m.players.opponent.pitch.traps, 1)
    T.ok(m.players.player.pitch.strikers[1] ~= nil, "attacker not sent off")
end)

-- ── Through ball = one-on-one ─────────────────────────────────────────────────

-- Striker 2200 vs a 2000 keeper behind two 1500 defenders (+300 each: 2600 effective).
local function oneOnOne(keeperDef, playmaker)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.place(m, "opponent", "keeper", 0, keeperDef)
    if playmaker then
        H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1500))
        H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    end
    local s = H.store(m)
    return m, s, s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
end

T.test("Through ball: the shot faces the keeper's base DEF and scores", function()
    local m, s, r = oneOnOne(H.card("keeper", 300, 2000), true)
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)                     -- 2200 vs 2000
    T.eq(s.combatQueue[1].defender.def, 2000)
    T.eq(m.players.opponent.lp, 3800)
end)

T.test("Through ball: the same striker on a normal shot vs full DEF is saved", function()
    local _, s, r = oneOnOne(H.card("keeper", 300, 2000), false)
    T.eq(r.outcome, "save")                                            -- 2200 vs 2000 + 300
    T.eq(s.combatQueue[1].defender.def, 2300)
end)

T.test("Through ball: Fortress still faces it with the full effective DEF", function()
    local _, s, r = oneOnOne(H.kw("FORTRESS", "keeper", 300, 2000), true)
    T.eq(r.outcome, "save")                                            -- 2200 vs 2600
    T.eq(s.combatQueue[1].defender.def, 2600)
end)

T.test("Through ball: Safe hands still applies", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1500))
    local k = H.place(m, "opponent", "keeper", 0, H.kw("SAFE_HANDS", "keeper", 300, 2000))
    k.saves = 3                                                        -- +300 (max)
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")                                            -- 2200 vs 2000 + 300
    T.eq(s.combatQueue[1].defender.def, 2300)
end)
