local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

-- The summon action planned for cardDef, or nil.
local function summonOf(acts, cardDef)
    for _, a in ipairs(acts) do
        if a.type == "summon" and a.cardId == cardDef.id then return a end
    end
end

local function flips(acts)
    local out = {}
    for _, a in ipairs(acts) do if a.type == "flip" then out[#out + 1] = a end end
    return out
end

local function summonMatch()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500), "defense")
    return m
end

T.test("AI cover specialists: Libero (Sweeper) and Pressing Back (Intercept) go in face-up", function()
    local m = summonMatch()
    local sweeper   = H.give(m, "opponent", H.kw("SWEEPER", "defender", 1200, 1900))
    local intercept = H.give(m, "opponent", H.kw("INTERCEPT", "defender", 1300, 1800))
    local acts = AI._planSummons(m)
    local a, b = summonOf(acts, sweeper), summonOf(acts, intercept)
    T.eq(a and a.slotType, "defender"); T.eq(a and a.mode, "attack")
    T.eq(b and b.slotType, "defender"); T.eq(b and b.mode, "attack")
end)

T.test("AI cover specialists: a plain defender still goes in face-down", function()
    local m = summonMatch()
    local d = H.give(m, "opponent", H.card("defender", 900, 2000))
    local a = summonOf(AI._planSummons(m), d)
    T.eq(a and a.mode, "defense")
end)

T.test("AI cover: a midfielder goes in face-up when a defender slot is open and nobody covers", function()
    local m = summonMatch()
    local mid = H.give(m, "opponent", H.card("midfielder", 1200, 1600))   -- DEF > ATK
    local a = summonOf(AI._planSummons(m), mid)
    T.eq(a and a.mode, "attack")
    -- Both defender slots filled: nothing to cover, it keeps its defensive mode.
    m = summonMatch()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 2000), "defense")
    mid = H.give(m, "opponent", H.card("midfielder", 1200, 1600))
    a = summonOf(AI._planSummons(m), mid)
    T.eq(a and a.mode, "defense")
end)

T.test("AI flip: flips a revealed Intercept defender to cover an open defender slot", function()
    local m = summonMatch()
    local d = H.place(m, "opponent", "defender", 1, H.kw("INTERCEPT", "defender", 1300, 1800), "defense")
    d.revealed = true
    local f = flips(AI._planSummons(m))
    T.eq(#f, 1); T.eq(f[1].slotType, "defender"); T.eq(f[1].slotIndex, 1)
    local s = H.store(m)
    AI.executeAction(s, f[1])
    T.eq(d.mode, "attack")
    T.eq(#flips(AI._planSummons(m)), 0, "already face-up: no second flip")
end)

T.test("AI flip: flips a revealed midfielder to cover, never a face-down one", function()
    local m = summonMatch()
    local mid = H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1600), "defense")
    T.eq(#flips(AI._planSummons(m)), 0, "face-down cards stay hidden")
    mid.revealed = true
    local f = flips(AI._planSummons(m))
    T.eq(#f, 1); T.eq(f[1].slotType, "midfielder")
    mid.summonedThisTurn = true
    T.eq(#flips(AI._planSummons(m)), 0, "summoned this turn: can't flip")
end)

T.test("AI flip: flips a revealed defender that wins a fight against a face-up striker", function()
    local m = summonMatch()
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "attack")   -- covers
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 1800, 1500), "defense")
    d.revealed = true
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 1000), "attack")
    local f = flips(AI._planSummons(m))
    T.eq(#f, 1); T.eq(f[1].slotIndex, 1)
    m.players.player.pitch.strikers[1] = nil
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 2000), "attack")
    T.eq(#flips(AI._planSummons(m)), 0, "no useful cover or win: stays in defense")
end)

T.test("AI flip: never flips a keeper", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    local k = H.place(m, "opponent", "keeper", 0, H.kw("OFF_THE_LINE", "keeper", 300, 1500), "defense")
    k.revealed = true
    for _, a in ipairs(flips(AI._planSummons(m))) do T.ok(a.slotType ~= "keeper") end
    local _, _, err = AI.executeAction(H.store(m), { type = "flip", slotType = "keeper", slotIndex = 0 })
    T.ok(err ~= nil, "the engine refuses a keeper flip")
    T.eq(k.mode, "defense")
end)

T.test("AI flip: a refused flip is not planned again this turn", function()
    local m = summonMatch()
    local d = H.place(m, "opponent", "defender", 1, H.kw("INTERCEPT", "defender", 1300, 1800), "defense")
    d.revealed = true
    local f = flips(AI._planSummons(m))
    T.eq(#f, 1)
    m.phase = "attack"                       -- the store refuses outside the summon phase
    local _, _, err = AI.executeAction(H.store(m), f[1])
    T.ok(err ~= nil)
    m.phase = "summon"
    T.eq(#flips(AI._planSummons(m)), 0)
end)

local function throughBallBoard(keeperDef)
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2400, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1000), "defense")   -- face-down
    H.place(m, "player", "defender", 2, H.card("defender", 900, 1000), "defense")   -- face-down
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, keeperDef), "defense")
    return m
end

T.test("AI Through ball: a scoring one-on-one beats attacking a face-down defender", function()
    local a = AI._planNextAttack(throughBallBoard(1500), "medium")
    T.eq(a and a.defenderSlot.type, "keeper")
    T.eq(a and a.attackerSlot.type, "striker")
end)

T.test("AI Through ball: no one-on-one that the keeper saves", function()
    local a = AI._planNextAttack(throughBallBoard(2600), "medium")
    T.eq(a and a.defenderSlot.type, "defender", "attacks the face-down defender instead")
    local m = throughBallBoard(1500)
    m.players.opponent.pitch.throughBallUsed = true
    a = AI._planNextAttack(m, "medium")
    T.eq(a and a.defenderSlot.type, "defender", "Through ball already used this turn")
end)
