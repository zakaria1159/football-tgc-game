local T = require("tests.t")
local H = require("tests.helpers")

-- Player striker (ATK 2100) against an opponent with no keeper and no defenders.
local function emptyGoal()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    return m, H.store(m)
end

T.test("open goal: a striker aimed at an empty keeper slot scores its full ATK", function()
    local m, s = emptyGoal()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 2100)
    T.eq(m.players.opponent.lp, 1900)
    T.eq(m.players.player.totalDamageDealt, 2100)
end)

T.test("open goal: advancing through an empty defence into an empty keeper slot scores", function()
    local m, s = emptyGoal()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 2))
    T.eq(r.outcome, "damage"); T.eq(m.players.opponent.lp, 1900)
    local dmg = H.events(m, "lp_damage")
    T.eq(dmg[#dmg].payload.source, "open_goal")
end)

T.test("open goal: the attack-mode midfielder card bonus counts", function()
    local m, s = emptyGoal()
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.damage, 2300)
end)

T.test("open goal: still needs a gap in the defender line", function()
    local m, s = emptyGoal()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
    T.eq(m.players.opponent.lp, 4000)
end)

local function shotWith(stratId)
    local m, s = emptyGoal()
    local card = H.give(m, "player", H.def(stratId))
    local r, err = s:playStrategy(card.id)
    return m, r, err
end

T.test("open goal: Direct Free Kick at an empty keeper slot scores full ATK", function()
    local m, r = shotWith("strat-direct-free-kick")
    T.ok(r, "played"); T.eq(r.outcome, "damage"); T.eq(r.damage, 2100)
    T.eq(m.players.opponent.lp, 1900)
end)

T.test("open goal: Penalty at an empty keeper slot scores full ATK", function()
    local m, r = shotWith("strat-penalty")
    T.ok(r, "played"); T.eq(r.outcome, "damage"); T.eq(m.players.opponent.lp, 1900)
end)

T.test("open goal: the AI's VAR still overturns it", function()
    local m, s = emptyGoal()
    H.trap(m, "opponent", "trap-var")
    s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(m.players.opponent.lp, 4000)
    T.eq(#m.players.opponent.pitch.traps, 0)
    T.eq(m.players.player.pitch.strikers[1], nil)
    local hand = m.players.player.hand
    T.eq(hand[#hand].type, "striker")
end)
