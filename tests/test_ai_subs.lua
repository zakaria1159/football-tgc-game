local T  = require("tests.t")
local H  = require("tests.helpers")
local C  = require("engine.constants")
local AI = require("ai.opponent")

-- The AI's summon phase: keeper, both defender slots and the midfielder slot filled.
local function aiTurn()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    return m
end

local function ofType(acts, t)
    local out = {}
    for _, a in ipairs(acts) do if a.type == t then out[#out + 1] = a end end
    return out
end

T.test("AI subs: a tired striker comes off for a striker from hand (a summon and a sub)", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    local inn = H.give(m, "opponent", H.card("striker", 2200, 600))
    H.give(m, "opponent", H.card("defender", 900, 2000))           -- not the same line
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1)
    T.eq(acts[1].cardId, inn.id); T.eq(acts[1].slotType, "striker"); T.eq(acts[1].slotIndex, 1)
    T.eq(acts[1].mode, "attack")
    AI.executeAction(H.store(m), acts[1])
    T.eq(m.players.opponent.pitch.strikers[1].definition, inn)
    T.eq(m.players.opponent.subsUsed, 1)
end)

T.test("AI subs: a striker at 1 stamina comes off; other lines only when tired", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 1
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    m.players.opponent.pitch.defenders[1].stamina = 1
    local s = H.give(m, "opponent", H.card("striker", 2200, 600))
    H.give(m, "opponent", H.card("defender", 900, 2000))
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1); T.eq(acts[1].cardId, s.id); T.eq(acts[1].slotIndex, 1)
end)

T.test("AI subs: none without a same-line card, a sub or a summon left", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    H.give(m, "opponent", H.card("midfielder", 1800, 1500))
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no striker in hand")
    H.give(m, "opponent", H.card("striker", 2200, 600))
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no subs left")
    m.players.opponent.subsUsed = 0
    m.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no summons left")
end)

T.test("AI subs: the keeper swap stays within the 3-sub budget", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500), "defense")
    H.give(m, "opponent", H.card("keeper", 300, 2000))
    local function swaps()
        local n = 0
        for _, a in ipairs(AI._planSummons(m)) do
            if a.type == "summon" and a.slotType == "keeper" then n = n + 1 end
        end
        return n
    end
    T.eq(swaps(), 1)
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq(swaps(), 0)
end)

T.test("AI subs: the Substitution card goes first — free, no sub used, and the new striker attacks at once", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    local card = H.give(m, "opponent", H.def("strat-substitution"))
    local inn  = H.give(m, "opponent", H.card("striker", 2400, 600))
    local acts = AI._planSummons(m)
    local sc = ofType(acts, "subCard")
    T.eq(#sc, 1); T.eq(sc[1].cardId, card.id); T.eq(sc[1].inId, inn.id)
    T.eq(#ofType(acts, "summon"), 0)
    local s = H.store(m)
    AI.executeAction(s, sc[1])
    T.eq(m.players.opponent.pitch.strikers[1].definition, inn)
    T.eq(m.summonCount, 0); T.eq(m.players.opponent.subsUsed, 0)
    s:startAttackPhase()
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1800), "defense")
    local atk = AI._planNextAttack(m, "medium")
    T.ok(atk ~= nil and atk.attackerSlot.index == 1, "the substitute attacks this turn")
end)

T.test("AI subs: empty slots are filled before anyone is subbed", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    local inn = H.give(m, "opponent", H.card("striker", 2200, 600))
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1); T.eq(acts[1].cardId, inn.id); T.eq(acts[1].slotIndex, 2, "the empty striker slot")
end)
