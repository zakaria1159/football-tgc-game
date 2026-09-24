local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- The player's summon phase: a striker on the pitch, the Substitution card and a replacement
-- striker in hand.
local function subCardMatch()
    local m = H.match({ phase = "summon" })
    local out  = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local card = H.give(m, "player", H.def("strat-substitution"))
    local inn  = H.give(m, "player", H.card("striker", 2200, 600))
    return m, H.store(m), card, out, inn
end

T.test("Substitution card: return a card, then place one in the freed slot — no summon, no sub", function()
    local m, s, card, out, inn = subCardMatch()
    local r = s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    T.eq(r.outcome, "substitution_done")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(s:freeSummon(inn.id, "striker", 1, "attack"), true)
    T.eq(m.summonCount, 0); T.eq(m.players.player.subsUsed, 0)
    T.eq(m.players.player.pitch.strikers[1].definition, inn)
    local back = false
    for _, c in ipairs(m.players.player.hand) do if c == out.definition then back = true end end
    T.ok(back)
end)

T.test("Substitution card: the incoming card may attack this turn (not a Pace trigger) but can't switch", function()
    local m, s, card, _, inn = subCardMatch()
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    s:freeSummon(inn.id, "striker", 1, "attack")
    local now = m.players.player.pitch.strikers[1]
    T.eq(now.actsImmediately, true)
    T.eq((Phases.canSwitch(now, "striker", { isOwnTurn = true, phase = "summon" })), nil)
    s:startAttackPhase()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#H.triggers(m), 0, "no Pace trigger")
end)

T.test("Substitution card: the free placement only fills the freed slot, once", function()
    local m, s, card, _, inn = subCardMatch()
    local extra = H.give(m, "player", H.card("striker", 1900, 500))
    local ok, err = s:freeSummon(inn.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "no free placement pending")
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    ok, err = s:freeSummon(inn.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "place it in the freed slot")
    T.eq(s:freeSummon(inn.id, "striker", 1, "attack"), true)
    ok, err = s:freeSummon(extra.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "no free placement pending")
end)

T.test("Substitution card: an unused free placement ends with the turn", function()
    local m, s, card = subCardMatch()
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    T.ok(m.players.player.subFreedSlot ~= nil)
    Phases.endTurn(m)
    T.eq(m.players.player.subFreedSlot, nil)
end)

T.test("Substitution card: its text states the special sub", function()
    local t = H.def("strat-substitution").abilityText
    T.ok(t:find("no summon", 1, true) ~= nil)
    T.ok(t:find("no substitution", 1, true) ~= nil)
    T.ok(t:find("may attack this turn", 1, true) ~= nil)
    T.ok(t:find("in response", 1, true) == nil, "the unimplemented response play is gone")
end)
