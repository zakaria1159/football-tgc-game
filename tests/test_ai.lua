local T     = require("tests.t")
local H     = require("tests.helpers")
local AI    = require("ai.opponent")
local State = require("engine.state")

local function used(opts)
    local u = { keeper = false, defenders = { false, false }, midfielder = false, strikers = { false, false } }
    for k, v in pairs(opts or {}) do u[k] = v end
    return u
end

T.test("AI: a midfielder never overflows into a striker slot", function()
    local mid = H.card("midfielder", 1800, 1500)
    local slot, mode = AI._pickBestSlot(mid, used({ midfielder = true }))
    T.eq(slot.slotType, "defender"); T.eq(mode, "defense")
    slot = AI._pickBestSlot(mid, used({ midfielder = true, defenders = { true, true } }))
    T.eq(slot, nil)
end)

T.test("AI: a defender never goes into a striker slot", function()
    local d = H.card("defender", 900, 1900)
    T.eq(AI._pickBestSlot(d, used({ midfielder = true, defenders = { true, true } })), nil)
end)

T.test("AI: strikers fill striker slots, then the midfielder slot", function()
    local s = H.card("striker", 2000, 500)
    local slot, mode = AI._pickBestSlot(s, used())
    T.eq(slot.slotType, "striker"); T.eq(slot.slotIndex, 1); T.eq(mode, "attack")
    slot = AI._pickBestSlot(s, used({ strikers = { true, true } }))
    T.eq(slot.slotType, "midfielder")
end)

T.test("AI: summon planning counts summons already made against the Time Wasting limit", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    m.players.opponent.nextTurnSummonLimit = 1
    m.summonCount = 1
    H.give(m, "opponent", H.card("striker", 2000, 500))
    T.eq(#AI._planSummons(m), 0)
end)

T.test("AI trap discipline: Offside is kept against a small attack", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#m.players.opponent.pitch.traps, 1)
end)

T.test("AI trap discipline: Offside fires on an attack worth 300+ LP", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(m.players.opponent.lp, 4000)
end)

T.test("AI trap discipline: Offside on an empty slot only when the AI can't cover it", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    T.eq(#m.players.opponent.pitch.traps, 1)

    local m2 = H.match()
    H.place(m2, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m2, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m2, "opponent", "trap-offside")
    local r2 = H.store(m2):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r2.outcome, "offside_cancelled")
end)

T.test("AI trap discipline: Red Card only punishes attackers with 2000+ ATK", function()
    for _, case in ipairs({ { atk = 1900, fires = false }, { atk = 2100, fires = true } }) do
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", case.atk, 500))
        H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1000))
        H.trap(m, "opponent", "trap-red-card")
        H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
        T.eq(m.players.player.pitch.strikers[1] == nil, case.fires, "ATK " .. case.atk)
    end
end)

T.test("AI: the turn plan tag changes when the half changes", function()
    local m = H.match({ turn = 5, active = "opponent" })
    local before = AI.planTag(m)
    State.endHalf(m, "opponent")
    m.activePlayer = "opponent"   -- the AI's first turn of half 2 (turn 1)
    T.ok(AI.planTag(m) ~= before)
    T.eq(AI.planTag(m), "2:1")
end)

-- ── Open goal (owner-approved addition) ──────────────────────────────────────

T.test("AI: shoots at an empty keeper slot with its best striker when a defender slot is open", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "opponent", "striker", 2, H.card("striker", 2200, 500))
    -- A weak face-up defender the AI would otherwise beat, plus a gap in slot 2.
    H.place(m, "player", "defender", 1, H.card("defender", 100, 400))
    for _, diff in ipairs({ "easy", "medium", "hard" }) do
        local a = AI._planNextAttack(m, diff)
        T.ok(a ~= nil, diff .. ": an attack is planned")
        T.eq(a.defenderSlot.type, "keeper", diff)
        T.eq(a.defenderSlot.index, 0, diff)
        T.eq(a.attackerSlot.type, "striker", diff)
        T.eq(a.attackerSlot.index, 2, diff .. ": the highest-ATK striker shoots")
    end
end)

T.test("AI: no keeper-slot attack when both defender slots are filled", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 100, 400))
    H.place(m, "player", "defender", 2, H.card("defender", 100, 400))
    for _, diff in ipairs({ "easy", "medium", "hard" }) do
        local a = AI._planNextAttack(m, diff)
        T.ok(a ~= nil, diff .. ": still attacks a defender")
        T.ok(a.defenderSlot.type ~= "keeper", diff .. ": no shot at a protected goal")
    end
end)

T.test("AI: no open-goal attack on its own opening turn", function()
    local m = H.match({ turn = 1, active = "opponent" })
    m.halfStarter = "opponent"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    T.ok(State.isOpeningTurn(m))
    T.eq(AI._planNextAttack(m, "hard"), nil)
end)
