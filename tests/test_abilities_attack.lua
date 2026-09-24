local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local AI     = require("ai.opponent")

-- ── Pace (and D1: summoned cards attack from their next turn) ────────────────

local function summonTurn()
    local m = H.match({ phase = "summon" })
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    return m, H.store(m)
end

T.test("Pace: a Pace card summoned in attack mode attacks at once", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.kw("PACE", "striker", 2150, 550))
    T.eq(s:summonCard(c.id, "striker", 1, "attack"), true)
    s:startAttackPhase()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PACE"); T.eq(t[1].player, "player")
end)

T.test("Pace: any other card summoned this turn attacks from its next turn", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.card("striker", 2150, 550))
    s:summonCard(c.id, "striker", 1, "attack")
    s:startAttackPhase()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "summoned this turn — attacks next turn")
    s:endTurn(); s:endTurn(); s:drawPhase(); s:startAttackPhase()
    r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
end)

T.test("Pace: attack mode only — summoned face-down it can't attack", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.kw("PACE", "striker", 2150, 550))
    s:summonCard(c.id, "striker", 1, "defense")
    s:startAttackPhase()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "card is in defense mode")
end)

T.test("AI Pace: attacks with a fresh Pace card, not with other fresh cards", function()
    local m = H.match({ active = "opponent" })
    local fresh = H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    fresh.summonedThisTurn = true
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    T.eq(AI._planNextAttack(m, "medium"), nil)
    local pace = H.place(m, "opponent", "striker", 2, H.kw("PACE", "striker", 2150, 550))
    pace.summonedThisTurn = true
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.attackerSlot.index, 2)
end)

-- ── Through ball ──────────────────────────────────────────────────────────────

local function fullDefence()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2400, 500))
    H.place(m, "player", "striker", 2, H.card("striker", 2400, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
    return m, H.store(m)
end

T.test("Through ball: a striker may shoot past a full defence (one-on-one: base DEF)", function()
    local m, s = fullDefence()
    local cp = H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 900)                     -- 2400 vs 1500
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "THROUGH_BALL"); T.eq(t[1].card, cp.definition.id)
end)

T.test("Through ball: once per turn", function()
    local m, s = fullDefence()
    H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("keeper")).outcome, "damage")
    local r, err = s:declareAttack(H.slot("striker", 2), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
    Phases.endTurn(m)
    T.eq(m.players.player.pitch.throughBallUsed, nil)
end)

T.test("Through ball: without it a full defence protects the keeper", function()
    local _, s = fullDefence()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
end)

-- ── Aerial ────────────────────────────────────────────────────────────────────

local function offsideBoard(attackerDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, attackerDef)
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-offside")
    return m, H.store(m)
end

T.test("Aerial: the AI's Offside can't be used against it", function()
    local m, s = offsideBoard(H.kw("AERIAL", "striker", 2200, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 600)
    T.eq(#m.players.opponent.pitch.traps, 1)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "AERIAL")
end)

T.test("Aerial: a normal striker is still caught offside", function()
    local m, s = offsideBoard(H.card("striker", 2200, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(#m.players.opponent.pitch.traps, 0)
end)

T.test("Aerial: no Offside window opens for the human against the AI's Aerial striker", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.kw("AERIAL", "striker", 2200, 600))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "player", "trap-offside")
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage")
    T.eq(s.trapWindow, nil)
end)

-- ── Beat the man ──────────────────────────────────────────────────────────────

local function emptySlotBoard(attackerDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, attackerDef)
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1700, 1400))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1700))
    return m, H.store(m)
end

T.test("Beat the man: its attack into an empty slot can't be covered", function()
    local m, s = emptySlotBoard(H.kw("BEAT_THE_MAN", "striker", 2050, 500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)                     -- 2050 vs 1700 + 150
    T.eq(s.coverWindow, nil)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BEAT_THE_MAN")
end)

T.test("Beat the man: other attacks into an empty slot can be covered", function()
    local _, s = emptySlotBoard(H.card("striker", 2050, 500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
end)
