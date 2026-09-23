local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- ── Immovable ─────────────────────────────────────────────────────────────────

T.test("Immovable: on a tie The Rock survives and only the attacker is destroyed", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    local rock = H.place(m, "opponent", "defender", 1, H.kw("IMMOVABLE", "defender", 800, 2100))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "tie")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(m.players.opponent.pitch.defenders[1], rock)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "IMMOVABLE"); T.eq(t[1].player, "opponent")
end)

T.test("Immovable: The Rock also survives a tie it starts", function()
    local m = H.match()
    local rock = H.place(m, "player", "defender", 1, H.kw("IMMOVABLE", "defender", 800, 2100))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 800))
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "tie")
    T.eq(m.players.opponent.pitch.strikers[1], nil)
    T.eq(m.players.player.pitch.defenders[1], rock)
    T.eq(rock.exhausted, true)
end)

T.test("Immovable: a plain tie still destroys both cards", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 800, 2100))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(m.players.opponent.pitch.defenders[1], nil)
    T.eq(#H.triggers(m), 0)
end)

-- ── Hard tackle ───────────────────────────────────────────────────────────────

T.test("Hard tackle: an attacker that beats The Destroyer can't act on its owner's next turn", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(s1.lockedNextTurn, true)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "HARD_TACKLE"); T.eq(t[1].player, "opponent")
    s:endTurn(); s:endTurn()                 -- the opponent's turn, then the player's next turn
    m.phase = "attack"
    local r2, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r2, nil); T.eq(err, "attacker cannot act")
    s:endTurn(); s:endTurn()
    T.eq((Phases.validateAttack(m, H.slot("striker", 1), H.slot("keeper"))), true, "free again")
end)

T.test("Hard tackle: an attacker that loses is just destroyed (no trigger)", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(#H.triggers(m), 0)
end)

T.test("Hard tackle: an attack on The Destroyer cancelled by Offside also locks the attacker", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2300, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(s1.exhausted, true); T.eq(s1.lockedNextTurn, true)
end)

-- ── Build-up ──────────────────────────────────────────────────────────────────

T.test("Build-up: winning a fight as the defender draws its owner a card", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(#m.players.opponent.hand, 1); T.eq(#m.players.opponent.deck, 9)
    T.eq(H.events(m, "card_drawn")[1].payload.source, "build_up")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BUILD_UP"); T.eq(t[1].player, "opponent")
end)

T.test("Build-up: winning as the attacker draws too", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#m.players.player.hand, 1)
end)

T.test("Build-up: a tie draws nothing", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1700, 500))
    H.place(m, "opponent", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(#m.players.opponent.hand, 0)
    T.eq(#H.triggers(m), 0)
end)

-- ── Punch clear ───────────────────────────────────────────────────────────────

local function punchBoard(atk)
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", atk, 500))
    H.place(m, "opponent", "keeper", 0, H.kw("PUNCH_CLEAR", "keeper", 300, 1900))
    return m, H.store(m), s1
end

T.test("Punch clear: after a save the shooter can't act on its owner's next turn", function()
    local m, s, s1 = punchBoard(1800)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")
    T.eq(s1.lockedNextTurn, true)
    T.eq(r.abilities[1], "PUNCH_CLEAR")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PUNCH_CLEAR"); T.eq(t[1].player, "opponent")
end)

T.test("Punch clear: a goal leaves the shooter free", function()
    local m, s, s1 = punchBoard(2000)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage")
    T.eq(s1.lockedNextTurn, nil)
    T.eq(#H.triggers(m), 0)
end)

-- ── Clinical ──────────────────────────────────────────────────────────────────

local function clinicalBoard(shooterDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, shooterDef)
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 2000))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))   -- effective DEF 2300
    return m, H.store(m)
end

T.test("Clinical: a shot that ties the keeper's DEF is a goal for 300", function()
    local m, s = clinicalBoard(H.kw("CLINICAL", "striker", 2300, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 300)
    T.eq(m.players.opponent.lp, 3700)
    T.eq(m.players.player.halfGoals, 1)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "CLINICAL")
end)

T.test("Clinical: other strikers still just tie", function()
    local m, s = clinicalBoard(H.card("striker", 2300, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "tie")
    T.eq(m.players.opponent.lp, 4000)
end)

-- ── End of turn (D2) ──────────────────────────────────────────────────────────

T.test("end of turn: a card behind an empty slot recovers too", function()
    local m = H.match()
    local s2 = H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    local d2 = H.place(m, "player", "defender", 2, H.card("defender", 900, 1500))
    s2.exhausted = true
    d2.cannotActNextTurn = true
    Phases.endTurn(m)
    T.eq(s2.exhausted, false); T.eq(d2.cannotActNextTurn, false)
end)
