local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

T.test("AI Aerial: its Offside policy never targets an Aerial striker", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("AERIAL", "striker", 2200, 600))
    H.place(m, "player", "striker", 2, H.card("striker", 2200, 600))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    T.eq(AI.wantsOffside(m, "opponent", H.slot("striker", 1), H.slot("keeper")), false)
    T.eq(AI.wantsOffside(m, "opponent", H.slot("striker", 2), H.slot("keeper")), true)
end)

T.test("AI Beat the man: goes through an empty slot when the shot scores", function()
    local function board(attackerDef)
        local m = H.match({ active = "opponent" })
        H.place(m, "opponent", "striker", 1, attackerDef)
        H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
        H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))   -- effective DEF 1800
        return m
    end
    local a = AI._planNextAttack(board(H.kw("BEAT_THE_MAN", "striker", 2050, 500)), "medium")
    T.eq(a.defenderSlot.type, "defender"); T.eq(a.defenderSlot.index, 2)
    a = AI._planNextAttack(board(H.card("striker", 2050, 500)), "medium")
    T.eq(a.defenderSlot.index, 1, "a plain striker takes the winning fight")
end)

T.test("AI Through ball: shoots past a full defence when the shot scores", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2400, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "player", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.defenderSlot.type, "keeper"); T.eq(a.attackerSlot.type, "striker")
    m.players.opponent.pitch.midfielder = nil
    T.eq(AI._planNextAttack(m, "medium"), nil)
end)

T.test("AI Press: summons its Press striker first when the human shows a defender", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    m.players.opponent.nextTurnSummonLimit = 1
    H.give(m, "opponent", H.card("striker", 2200, 500))
    local press = H.give(m, "opponent", H.kw("PRESS", "striker", 2100, 700))
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    local acts = AI._planSummons(m)
    T.eq(#acts, 1); T.eq(acts[1].cardId, press.id)
    d.mode = "defense"
    acts = AI._planSummons(m)
    T.ok(acts[1].cardId ~= press.id, "no face-up defender: the stronger striker first")
end)

T.test("AI cover: Counter-press DEF counts in the cover decision", function()
    local function coverChoice(midDef)
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
        H.place(m, "opponent", "midfielder", 0, midDef)
        local s = H.store(m)
        s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
        return AI.decideCover(s)
    end
    T.eq(coverChoice(H.kw("COUNTER_PRESS", "midfielder", 1700, 1400)).type, "midfielder")
    T.eq(coverChoice(H.card("midfielder", 1700, 1400)), nil)
end)

T.test("AI cover: an Off the line keeper covers only when it wins outright", function()
    for _, case in ipairs({ { atk = 1700, covers = true }, { atk = 1800, covers = false },
                            { atk = 1900, covers = false } }) do
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", case.atk, 500))
        H.place(m, "opponent", "keeper", 0, H.kw("OFF_THE_LINE", "keeper", 400, 1800), "defense")
        local s = H.store(m)
        s.aiDifficulty = "hard"
        T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "cover_needed")
        T.eq(AI.decideCover(s) ~= nil, case.covers, "ATK " .. case.atk)
    end
end)

T.test("AI fight estimate: counts a face-up Last man bonus", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "player", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.defenderSlot.index, 2, "2300 DEF: goes round it")
end)
