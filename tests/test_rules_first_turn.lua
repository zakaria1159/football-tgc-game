local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

-- Player striker vs a face-up opponent defender, on the given turn / half.
local function setup(opts)
    local m = H.match(opts)
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    return m, H.store(m)
end

T.test("first turn: the half's starter cannot attack on turn 1", function()
    local m, s = setup({ turn = 1 })
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "no attacks on the first turn of a half")
    T.ok(m.players.opponent.pitch.defenders[1] ~= nil)
    T.eq(m.players.opponent.lp, 4000)
end)

T.test("first turn: no Direct Free Kick or Penalty either; the card stays in hand", function()
    for _, id in ipairs({ "strat-direct-free-kick", "strat-penalty" }) do
        local m, s = setup({ turn = 1 })
        H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
        local card = H.give(m, "player", H.def(id))
        local r, err = s:playStrategy(card.id)
        T.ok(not r, id .. " refused"); T.eq(err, "no attacks on the first turn of a half")
        T.eq(#m.players.player.hand, 1); T.eq(m.strategyPlayedThisTurn, false)
        T.eq(m.players.opponent.lp, 4000)
    end
end)

T.test("first turn: the AI's Offside is not spent on a refused attack", function()
    local m, s = setup({ turn = 1 })
    H.trap(m, "opponent", "trap-offside")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(#m.players.opponent.pitch.traps, 1)
    T.eq(m.players.player.pitch.strikers[1].exhausted, false)
end)

T.test("first turn: the second player may attack on its turn 1", function()
    local m = H.match({ turn = 1, active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
end)

T.test("first turn: Extra Time's starter is blocked on its turn 1 too", function()
    local _, s = setup({ turn = 1, half = "extra" })
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "no attacks on the first turn of a half")
end)

T.test("first turn: the AI plans no attack and no shot on its opening turn", function()
    local m = H.match({ turn = 1, active = "opponent" })
    m.halfStarter = "opponent"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))
    H.give(m, "opponent", H.def("strat-penalty"))
    T.eq(AI._planNextAttack(m, "medium"), nil)
    T.eq(AI._pickStrategy(m, "medium"), nil)
end)
