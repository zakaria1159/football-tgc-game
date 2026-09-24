local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")

-- Extra Time with its 6 rounds played, 1–1 in halves.
local function et(pLP, oLP)
    local m = H.match({ half = "extra", turn = 7, active = "player", phase = "draw" })
    m.extraTurnsLeft = 0
    m.players.player.halvesWon, m.players.opponent.halvesWon = 1, 1
    m.players.player.lp, m.players.opponent.lp = pLP, oLP
    return m
end

T.test("extra time: more LP in Extra Time wins, whatever the match damage", function()
    local m = et(3000, 2000)
    m.players.opponent.totalDamageDealt = 9000
    T.eq(State.checkHalfEnd(m), "player")
end)

T.test("extra time: level LP → more damage dealt during Extra Time wins", function()
    local m = et(2500, 2500)
    m.players.player.totalDamageDealt   = 9000
    m.players.player.halfDamageDealt    = 300
    m.players.opponent.halfDamageDealt  = 700
    T.eq(State.checkHalfEnd(m), "opponent")
end)

T.test("extra time: a full tie goes to the player who went second, not the human", function()
    T.eq(State.checkHalfEnd(et(2500, 2500)), "opponent")
end)

T.test("extra time: after the 6th round the decider ends the match", function()
    local m = H.match({ half = "extra", turn = 6, active = "opponent" })
    m.extraTurnsLeft = 1
    m.players.player.halvesWon, m.players.opponent.halvesWon = 1, 1
    m.players.player.lp, m.players.opponent.lp = 1000, 1500
    Phases.endTurn(m)
    T.eq(m.winner, "opponent")
end)
