local T     = require("tests.t")
local H     = require("tests.helpers")
local AI    = require("ai.opponent")
local C     = require("engine.constants")

-- The simulator's mirrored view (tools/sim/sim.lua viewFor): the AI always thinks it is
-- "opponent"; for the first seat the two sides are swapped and everything else
-- (activePlayer included) is read from the real match.
local function mirrored(m)
    return setmetatable({ players = { opponent = m.players.player, player = m.players.opponent } },
                        { __index = m })
end

-- ── 1. Open-goal check from the AI's own view ─────────────────────────────────

T.test("AI (mirrored first seat): no keeper attack when the enemy defence is full", function()
    local m = H.match({ active = "player" })
    -- First seat: an attack-mode striker, no defenders.
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    -- AI seat (the enemy here): no keeper, both defenders, its own attack-mode striker.
    H.place(m, "opponent", "defender", 1, H.card("defender", 100, 2200))
    H.place(m, "opponent", "defender", 2, H.card("defender", 100, 2200))
    H.place(m, "opponent", "striker", 1, H.card("striker", 1800, 500))
    local v = mirrored(m)
    for _, diff in ipairs({ "easy", "medium", "hard" }) do
        local a = AI._planNextAttack(v, diff)
        T.ok(not (a and a.defenderSlot.type == "keeper"), diff .. ": no shot at a protected goal")
    end
end)

T.test("AI (mirrored first seat): shoots an open goal from its own view", function()
    local m = H.match({ active = "player" })
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 100, 2200))
    local a = AI._planNextAttack(mirrored(m), "medium")
    T.ok(a ~= nil)
    T.eq(a.defenderSlot.type, "keeper")
    T.eq(a.attackerSlot.type, "striker"); T.eq(a.attackerSlot.index, 1)
end)

-- ── 2. A refused attack is not planned again this turn ───────────────────────

local function refusingStore(m)
    return { match = m, declareAttack = function() return nil, "refused" end }
end

T.test("AI: an attacker whose attack was refused is skipped for the rest of the turn", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "striker", 2, H.card("striker", 1500, 500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 0, 1000))
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.attackerSlot.index, 1)
    AI.executeAction(refusingStore(m), a)
    local b = AI._planNextAttack(m, "medium")
    T.ok(b ~= nil, "moves on to the next attacker")
    T.eq(b.attackerSlot.index, 2)
    AI.executeAction(refusingStore(m), b)
    T.eq(AI._planNextAttack(m, "medium"), nil, "nothing left: gives up")
end)

T.test("AI: a refusal only blocks the attacker for the turn it happened", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    local a = AI._planNextAttack(m, "medium")
    AI.executeAction(refusingStore(m), a)
    T.eq(AI._planNextAttack(m, "medium"), nil)
    m.turn = m.turn + 2
    T.ok(AI._planNextAttack(m, "medium") ~= nil, "tries again next turn")
end)

-- ── 3. Same targeting table as the human ─────────────────────────────────────

-- The human's table (scenes/match.lua getAttackTargetSlots, rules.md "Who Can Attack What").
local function humanAllows(ePitch, aType, t)
    local hasDef, hasGap = false, false
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if ePitch.defenders[i] then hasDef = true else hasGap = true end
    end
    if aType == "striker" then
        if t.type == "defender" then return true end
        if t.type == "midfielder" then return not hasDef end
        if t.type == "keeper" then return hasGap end
        return false
    elseif aType == "midfielder" then
        return t.type == "midfielder" and ePitch.midfielder ~= nil
    elseif aType == "defender" then
        return t.type == "striker"
    end
    return false
end

T.test("AI: a striker does not attack the midfielder while the human has defenders", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "player", "defender", 1, H.card("defender", 100, 2200))
    H.place(m, "player", "defender", 2, H.card("defender", 100, 2200))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1000, 1500))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2100, 500))
    for _, diff in ipairs({ "easy", "medium", "hard" }) do
        local a = AI._planNextAttack(m, diff)
        T.ok(not (a and a.defenderSlot.type == "midfielder"), diff .. ": midfielder not targeted")
    end
end)

T.test("AI: every planned target is one the human could pick (random boards)", function()
    math.randomseed(4242)
    local types = { "defender", "midfielder", "striker" }
    for n = 1, 400 do
        local m = H.match({ active = "opponent" })
        local function maybe(owner, slotType, idx, ctype)
            if math.random() < 0.55 then
                local mode = math.random() < 0.6 and "attack" or "defense"
                local c = H.place(m, owner, slotType, idx,
                    H.card(ctype or types[math.random(3)], math.random(5, 25) * 100, math.random(5, 25) * 100), mode)
                if mode == "defense" and math.random() < 0.3 then c.revealed = true end
            end
        end
        for _, owner in ipairs({ "player", "opponent" }) do
            maybe(owner, "keeper", 0, "keeper")
            maybe(owner, "midfielder", 0)
            for i = 1, C.PITCH.MAX_DEFENDERS do maybe(owner, "defender", i) end
            for i = 1, C.PITCH.MAX_STRIKERS do maybe(owner, "striker", i) end
        end
        for _, diff in ipairs({ "easy", "medium", "hard" }) do
            local a = AI._planNextAttack(m, diff)
            if a then
                T.ok(humanAllows(m.players.player.pitch, a.attackerSlot.type, a.defenderSlot),
                     ("board %d %s: %s -> %s %d"):format(n, diff, a.attackerSlot.type,
                                                          a.defenderSlot.type, a.defenderSlot.index))
            end
        end
    end
end)

-- ── 4. Shot-strength estimate matches the engine ─────────────────────────────

T.test("AI: shot estimate gives the +200 midfielder bonus to striker-slot shooters only", function()
    local function board()
        local m = H.match({ active = "opponent" })
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 900))
        H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
        H.place(m, "opponent", "defender", 1, H.card("striker", 1800, 500))
        return m
    end
    local m = board()
    T.eq(AI.estimateAttackDamage(m, "player", H.slot("striker", 1), H.slot("keeper")), 2200)
    T.eq(AI.estimateAttackDamage(m, "player", H.slot("defender", 1), H.slot("keeper")), 1800)
    -- The engine agrees for a defender-slot shooter.
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("keeper"))
    T.eq(r.damage, 1800)
    m = board()
    r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.damage, 2200)
end)
