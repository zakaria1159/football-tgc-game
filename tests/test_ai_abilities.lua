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

T.test("AI Through ball: judges the one-on-one against the keeper's base DEF", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "player", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 2000))  -- 2600 effective
    local a = AI._planNextAttack(m, "medium")
    T.eq(a and a.defenderSlot.type, "keeper")
    m.players.player.pitch.keeper = nil
    H.place(m, "player", "keeper", 0, H.kw("FORTRESS", "keeper", 300, 2000))
    T.eq(AI._planNextAttack(m, "medium"), nil, "Fortress: full DEF, no shot")
end)

T.test("AI damage estimate: a Through ball shot is judged against base DEF", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 2000))
    T.eq(AI.estimateAttackDamage(m, "opponent", H.slot("striker", 1), H.slot("keeper")), 200)
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

-- Human striker (atk) attacks the AI's empty `target` slot; board(m) places the AI's cards.
local function coverPick(atk, target, board, difficulty)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", atk, 500))
    board(m)
    local s = H.store(m)
    s.aiDifficulty = difficulty or "medium"
    T.eq(s:declareAttack(H.slot("striker", 1), target).outcome, "cover_needed")
    return AI.decideCover(s)
end

T.test("AI cover: a winning coverer (Counter-press DEF counted) beats an unlocked loser", function()
    local function pick(midDef)
        return coverPick(1600, H.slot("defender", 1), function(m)
            H.place(m, "opponent", "midfielder", 0, midDef)
            H.place(m, "opponent", "defender", 2, H.kw("SWEEPER", "defender", 1600, 1500))
        end)
    end
    T.eq(pick(H.kw("COUNTER_PRESS", "midfielder", 1700, 1400)).type, "midfielder")   -- 1700 wins
    T.eq(pick(H.card("midfielder", 1700, 1400)).type, "defender")                   -- both lose
end)

T.test("AI cover: a losing cover (last-ditch tackle) is taken when letting through concedes", function()
    for _, diff in ipairs({ "medium", "hard" }) do
        local c = coverPick(2000, H.slot("defender", 1), function(m)
            H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
        end, diff)
        T.eq(c and c.type, "midfielder", diff)
    end
    T.eq(coverPick(2000, H.slot("defender", 1), function(m)
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    end, "easy"), nil)
end)

T.test("AI cover: covers when letting through would cost a card, not when the next fight wins", function()
    local function pick(nextDef)
        return coverPick(1600, H.slot("midfielder"), function(m)
            H.place(m, "opponent", "defender", 1, H.card("defender", 900, nextDef), "defense")
            H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1000))
        end)
    end
    T.eq(pick(1800), nil)                                  -- the face-down 1800 stops it
    local c = pick(1500)                                   -- it would be destroyed: tackle
    T.eq(c.type, "defender"); T.eq(c.index, 2)
end)

T.test("AI cover: among locked losers, the lowest-value card covers", function()
    local c = coverPick(2000, H.slot("defender", 1), function(m)
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1400))  -- 2900
        H.place(m, "opponent", "defender", 2, H.kw("INTERCEPT", "defender", 950, 1800))  -- 2750
    end)
    T.eq(c.type, "defender"); T.eq(c.index, 2)
end)

T.test("AI cover: an unlocked loser (Sweeper) beats a cheaper locked one", function()
    local c = coverPick(2000, H.slot("defender", 1), function(m)
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
        H.place(m, "opponent", "defender", 2, H.kw("SWEEPER", "defender", 1600, 1500))
    end)
    T.eq(c.type, "defender"); T.eq(c.index, 2)
end)

T.test("AI cover: the Off the line keeper covers only when no other card can", function()
    local k = H.kw("OFF_THE_LINE", "keeper", 400, 1800)
    local c = coverPick(1700, H.slot("defender", 1), function(m)
        H.place(m, "opponent", "keeper", 0, k, "defense")
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    end)
    T.eq(c, nil, "the keeper saves the shot anyway; the midfielder would only lose")
    c = coverPick(2000, H.slot("defender", 1), function(m)     -- 2000 vs 1800 + 150: a goal
        H.place(m, "opponent", "keeper", 0, k, "defense")
        H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    end)
    T.eq(c.type, "midfielder")
    for _, atk in ipairs({ 1700, 1900 }) do                -- alone: it covers (win or tackle)
        c = coverPick(atk, H.slot("defender", 1), function(m)
            H.place(m, "opponent", "keeper", 0, k, "defense")
        end)
        T.eq(c and c.type, "keeper", "ATK " .. atk)
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
