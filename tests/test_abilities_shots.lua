local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")

-- ── Instinct ──────────────────────────────────────────────────────────────────

local function instinctBoard(keeperExhausted)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("INSTINCT", "striker", 2150, 650))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 2400))
    k.exhausted = keeperExhausted
    return m, H.store(m)
end

T.test("Instinct: +300 ATK on a shot at an exhausted keeper", function()
    local m, s = instinctBoard(true)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 50)                      -- 2450 vs 2400
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "INSTINCT"); T.eq(t[1].player, "player")
end)

T.test("Instinct: no bonus while the keeper is fresh", function()
    local m, s = instinctBoard(false)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")
    T.eq(#H.triggers(m), 0)
end)

-- ── Opportunist ───────────────────────────────────────────────────────────────

T.test("Opportunist: +400 ATK on a shot while an enemy defender slot is empty", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("OPPORTUNIST", "striker", 2100, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1700))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 500)                     -- 2500 vs 1700 + 300
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OPPORTUNIST")
end)

T.test("Opportunist: no bonus when both enemy defender slots are filled (Direct Free Kick)", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("OPPORTUNIST", "striker", 2100, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local card = H.give(m, "player", H.def("strat-direct-free-kick"))
    local r = H.store(m):playStrategy(card.id)
    T.eq(r.outcome, "tie")                                             -- 2100 vs 1500 + 600
    T.eq(#H.triggers(m), 0)
end)

-- ── Safe hands ────────────────────────────────────────────────────────────────

local function safeHandsBoard(saves)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1900, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.kw("SAFE_HANDS", "keeper", 300, 1750))
    k.saves = saves
    return m, H.store(m), k
end

T.test("Safe hands: +100 DEF per save this half, and a save counts", function()
    local m, s, k = safeHandsBoard(2)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")                                            -- 1900 vs 1750 + 200
    T.eq(k.saves, 3)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "SAFE_HANDS"); T.eq(t[1].amount, 200)
    T.eq(t[1].player, "opponent")
end)

T.test("Safe hands: no bonus before its first save", function()
    local m, s, k = safeHandsBoard(nil)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 150)
    T.eq(k.saves or 0, 0)
    T.eq(#H.triggers(m), 0)
end)

T.test("Safe hands: the bonus stops at +300", function()
    local m, _, k = safeHandsBoard(5)
    T.eq(Combat.keeperEffectiveDef(k, m.players.opponent.pitch), 2050)
end)

-- ── Bolt ──────────────────────────────────────────────────────────────────────

local function boltBoard()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2500, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800))
    local b = H.place(m, "opponent", "defender", 1, H.kw("BOLT", "defender", 750, 1950), "defense")
    return m, H.store(m), b
end

T.test("Bolt: counts +500 toward the keeper's effective DEF", function()
    local m, s = boltBoard()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)                     -- 2500 vs 1800 + 500
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BOLT"); T.eq(t[1].player, "opponent")
end)

T.test("Bolt: a Bolt card that attacked stops counting, like any defender", function()
    local m, s, b = boltBoard()
    b.usedAsAttacker = true
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.damage, 700)
    T.eq(#H.triggers(m), 0)
end)

-- ── Fortress ──────────────────────────────────────────────────────────────────

local function penaltyBoard(keeperDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2300, 500))
    H.place(m, "opponent", "keeper", 0, keeperDef)
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    local s = H.store(m)
    local card = H.give(m, "player", H.def("strat-penalty"))
    return m, s, s:playStrategy(card.id)
end

T.test("Fortress: a Penalty faces the full effective DEF", function()
    local m, s, r = penaltyBoard(H.kw("FORTRESS", "keeper", 300, 2000))
    T.eq(r.outcome, "tie")                                             -- 2300 vs 2000 + 300
    T.eq(s.combatQueue[1].defender.def, 2300)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "FORTRESS")
end)

T.test("Fortress: other keepers face a Penalty with base DEF", function()
    local m, s, r = penaltyBoard(H.card("keeper", 300, 2000))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 300)
    T.eq(s.combatQueue[1].defender.def, 2000)
    T.eq(#H.triggers(m), 0)
end)
