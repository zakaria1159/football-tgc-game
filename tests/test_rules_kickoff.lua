-- Alternating kick-off: the player kicks off half 1, the opponent half 2, a coin toss
-- (math.random(2)) decides Extra Time.
local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")

-- A match that has just gone to half 2 (the player won half 1).
local function half2()
    local m = H.match({ turn = 5, active = "opponent" })
    State.endHalf(m, "player", "lp")
    State.kickOff(m)
    return m
end

T.test("kick-off: the player kicks off half 1", function()
    local m = State.newMatch(H.filler(10), H.filler(10))
    T.eq(m.halfStarter, "player"); T.eq(m.activePlayer, "player")
end)

T.test("kick-off: the opponent kicks off half 2", function()
    local m = half2()
    T.eq(m.half, 2); T.eq(m.turn, 1)
    T.eq(m.halfStarter, "opponent"); T.eq(m.activePlayer, "opponent")
end)

T.test("kick-off: half 2 opening-turn block is the opponent's; the player may attack on its turn 1", function()
    local m = half2()
    T.ok(State.isOpeningTurn(m))
    m.phase = "attack"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    local r, err = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "no attacks on the first turn of a half")

    Phases.endTurn(m)
    T.eq(m.activePlayer, "player")
    T.eq(m.turn, 1, "the round ends when play returns to the half's starter")
    T.ok(not State.isOpeningTurn(m))
    m.phase = "attack"
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    local r2 = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r2.outcome, "defender_destroyed")

    Phases.endTurn(m)
    T.eq(m.activePlayer, "opponent"); T.eq(m.turn, 2)
end)

T.test("kick-off: neither player draws on its turn 1 of half 2", function()
    local m = half2()
    local o, p = m.players.opponent, m.players.player
    local oh = #o.hand
    Phases.draw(m)
    T.eq(#o.hand, oh, "opponent: no draw on turn 1")
    Phases.endTurn(m)
    local ph = #p.hand
    Phases.draw(m)
    T.eq(#p.hand, ph, "player: no draw on turn 1")
end)

T.test("kick-off: decideOnTime's second-player tiebreak picks the player in half 2", function()
    local m = half2()
    T.eq(State.decideOnTime(m), "player")
end)

T.test("kick-off: half 2 runs HALF_ROUND_LIMIT rounds, the player's turn closing each", function()
    local C = require("engine.constants")
    local m = half2()
    for _ = 1, C.MATCH.HALF_ROUND_LIMIT * 2 - 1 do Phases.endTurn(m) end
    T.eq(m.half, 2, "still half 2 before the last turn")
    T.eq(m.activePlayer, "player"); T.eq(m.turn, C.MATCH.HALF_ROUND_LIMIT)
    Phases.endTurn(m)
    -- Level on LP and damage: the player (second in half 2) takes it, and with it the match.
    T.eq(m.winner, "player")
end)

T.test("kick-off: Extra Time starter is a coin toss, always one of the two seats", function()
    local seen = {}
    for seed = 1, 40 do
        math.randomseed(seed)
        local m = half2()
        State.endHalf(m, "opponent", "lp")
        T.eq(m.half, "extra")
        T.ok(m.halfStarter == "player" or m.halfStarter == "opponent", "a seat")
        T.eq(m.activePlayer, m.halfStarter)
        seen[m.halfStarter] = true
    end
    T.ok(seen.player and seen.opponent, "both outcomes happen across seeds")
end)

T.test("kick-off: Extra Time counts down once per round whoever starts", function()
    local C = require("engine.constants")
    for _, starter in ipairs({ "player", "opponent" }) do
        local m = H.match({ turn = 1, half = "extra", active = starter })
        m.halfStarter = starter
        m.extraTurnsLeft = C.MATCH.EXTRA_TIME_TURNS
        Phases.endTurn(m)
        T.eq(m.extraTurnsLeft, C.MATCH.EXTRA_TIME_TURNS, starter .. ": not after the first turn")
        Phases.endTurn(m)
        T.eq(m.extraTurnsLeft, C.MATCH.EXTRA_TIME_TURNS - 1, starter .. ": after the round")
        T.eq(m.activePlayer, starter)
    end
end)
