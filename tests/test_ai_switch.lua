local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

local function switches(acts)
    local out = {}
    for _, a in ipairs(acts) do if a.type == "toDefense" then out[#out + 1] = a end end
    return out
end

-- The AI's summon phase with a keeper in goal and nothing in hand.
local function aiTurn()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    return m
end

T.test("AI switch: a weak midfielder the enemy midfielder would beat goes to face-up defense", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    local mid = H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1); T.eq(sw[1].slotType, "midfielder")
    AI.executeAction(H.store(m), sw[1])
    T.eq(mid.mode, "defense"); T.eq(mid.revealed, true)
end)

T.test("AI switch: a defender that can't beat any striker, facing a stronger one, pulls back", function()
    local m = aiTurn()
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 1000, 1600))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 1200))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1); T.eq(sw[1].slotType, "defender"); T.eq(sw[1].slotIndex, 1)
end)

T.test("AI switch: stays in attack when nothing beats it, when it wins a fight, and for strikers", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1200, 1000))
    T.eq(#switches(AI._planSummons(m)), 0, "not exposed")

    m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1700, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    T.eq(#switches(AI._planSummons(m)), 0, "it wins a fight this turn")

    m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1900))
    T.eq(#switches(AI._planSummons(m)), 0, "a striker-slot card stays")
end)

T.test("AI switch: never pulls back the only card covering an open defender slot", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")   -- slot 2 open
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    T.eq(#switches(AI._planSummons(m)), 0)
end)

T.test("AI switch: a refused switch is not planned again this turn", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1)
    m.phase = "attack"                      -- the store refuses outside the summon phase
    local _, _, err = AI.executeAction(H.store(m), sw[1])
    T.ok(err ~= nil)
    m.phase = "summon"
    T.eq(#switches(AI._planSummons(m)), 0)
end)
