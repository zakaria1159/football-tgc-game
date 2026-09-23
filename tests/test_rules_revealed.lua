local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")
local AI     = require("ai.opponent")

T.test("revealed: a face-down defender that survives is revealed but stays in defense", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(d.mode, "defense"); T.eq(d.revealed, true)
    T.eq(m.players.opponent.pitch.defenders[1], d)
end)

T.test("revealed: it still gives up no battle damage when it later loses", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    H.place(m, "player", "striker", 2, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))    -- bounces off, reveals it
    local lp = m.players.opponent.lp
    local r = s:declareAttack(H.slot("striker", 2), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(m.players.opponent.lp, lp)
end)

T.test("revealed: a defense-mode midfielder keeps its +200 DEF bonus and DEF midfield power", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1700), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("midfielder"))
    local pitch = m.players.opponent.pitch
    T.eq(pitch.midfielder.revealed, true)
    T.eq(Combat.midfielderCardDefBonus(pitch), 200)
    T.eq(Combat.midfielderPower(pitch), 1700)
end)

T.test("revealed: a face-down keeper stays in defense after a shot", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(k.mode, "defense"); T.eq(k.revealed, true)
end)

T.test("revealed: Scout Report reveals its target for good", function()
    local m = H.match()
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    local card = H.give(m, "player", H.def("strat-scout-report"))
    local r = H.store(m):playStrategy(card.id,
        { targetSlot = { owner = "opponent", type = "defender", index = 1 } })
    T.eq(r.revealedCard, d); T.eq(d.revealed, true); T.eq(d.mode, "defense")
end)

T.test("revealed: its owner may still flip it to attack", function()
    local m = H.match({ phase = "summon" })
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local ok = H.store(m):changeMode("defender", 1)
    T.eq(ok, true); T.eq(d.mode, "attack")
end)

T.test("revealed: the combat snapshot shows it face-up", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local snap = H.store(m):_snapshotAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(snap.defender.wasHidden, false)
end)

T.test("revealed: a keeper can never be flipped to attack, even after a shot reveals it", function()
    local m = H.match({ phase = "summon" })
    local k = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600), "defense")
    k.revealed = true
    local ok, err = H.store(m):changeMode("keeper", 0)
    T.eq(ok, false); T.eq(k.mode, "defense")
    T.ok(err ~= nil)
end)

T.test("revealed: the AI reads a revealed card's DEF instead of guessing", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 1800, 500))
    -- A keeper, so the AI's open-goal rule doesn't take over this scenario.
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600), "defense")
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local atk = AI._planNextAttack(m, "medium")
    T.eq(atk.defenderSlot.type, "defender"); T.eq(atk.defenderSlot.index, 2)
end)
