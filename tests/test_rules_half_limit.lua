local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")

-- The opponent (second player) is about to end round `turn`.
local function lastTurn(turn, pLP, oLP)
    local m = H.match({ turn = turn, active = "opponent", phase = "attack" })
    m.players.player.lp, m.players.opponent.lp = pLP, oLP
    return m
end

T.test("half limit: the half ends after round 14 and the LP leader wins it", function()
    local m = lastTurn(14, 3000, 2500)
    Phases.endTurn(m)
    T.eq(m.players.player.halvesWon, 1)
    T.eq(m.half, 2)
    local ends = H.events(m, "half_end")
    T.eq(ends[1].payload.winner, "player"); T.eq(ends[1].payload.reason, "time")
end)

T.test("half limit: round 14 is still played in full", function()
    local m = lastTurn(13, 3000, 2500)
    Phases.endTurn(m)
    T.eq(m.half, 1); T.eq(m.turn, 14); T.eq(m.activePlayer, "player")
end)

T.test("half limit: level on LP, more damage dealt this half wins", function()
    local m = lastTurn(14, 3000, 3000)
    m.players.player.halfDamageDealt   = 500
    m.players.opponent.halfDamageDealt = 800
    m.players.player.totalDamageDealt  = 9000   -- earlier halves don't count
    Phases.endTurn(m)
    T.eq(m.players.opponent.halvesWon, 1)
end)

T.test("half limit: level on LP and damage, the player who went second wins", function()
    local m = lastTurn(14, 3000, 3000)
    Phases.endTurn(m)
    T.eq(m.players.opponent.halvesWon, 1, "player started, so opponent went second")
    local m2 = lastTurn(14, 3000, 3000)
    m2.halfStarter = "opponent"
    T.eq(State.decideOnTime(m2), "player")
end)

T.test("half limit: damage this half resets at half time; the match total does not", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.players.player.halfDamageDealt, 500)
    State.endHalf(m, "player")
    T.eq(m.players.player.halfDamageDealt, 0)
    T.eq(m.players.player.totalDamageDealt, 500)
end)

T.test("half limit: a goal overturned by VAR no longer counts as damage dealt", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-var")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(m.players.opponent.lp, 4000)
    T.eq(m.players.player.totalDamageDealt, 0)
    T.eq(m.players.player.halfDamageDealt, 0)
end)
