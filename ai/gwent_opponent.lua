-- ai/gwent_opponent.lua
---@diagnostic disable: unused-local
local State  = require("engine.gwent.state")
local Phases = require("engine.gwent.phases")

local AI = {}

function AI.pickAction(store)
    local match = store.match
    if not match then return nil end
    local difficulty = store.aiDifficulty or "medium"

    -- Resolve pending action first (Medic, Decoy, Agility, Horn)
    if match.pendingAction and match.pendingAction.pid == "opponent" then
        return AI._resolvePending(match, difficulty)
    end

    if match.phase == "mulligan" and match.mulliganLeft.opponent > 0 then
        return { type = "mulligan", instanceIds = AI._pickMulligan(match, difficulty) }
    end
    if match.phase ~= "play" then return nil end
    if match.activePlayer ~= "opponent" then return nil end
    if match.winner then return nil end

    return AI._pickMainAction(match, difficulty)
end

-- ── Resolve pending actions ───────────────────────────────────────────────────

function AI._resolvePending(match, _difficulty)
    local pa = match.pendingAction
    if pa.type == "medic_choose" then
        local graveyard = match.players["opponent"].graveyard
        local bestIdx, bestP = 1, -1
        for i, def in ipairs(graveyard) do
            if not def.hero then
                local p = def.power or 0
                if p > bestP then bestP = p; bestIdx = i end
            end
        end
        return { type = "medic", graveyardIndex = bestIdx }

    elseif pa.type == "decoy_choose" then
        local bestRow, bestIdx, bestP = "attack", 1, math.huge
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            local cards = match.players["opponent"].pitch[row]
            local isW = match.weather[row] ~= nil
            local isH = match.hornRows["opponent"][row]
            for i, pc in ipairs(cards) do
                if not pc.definition.hero then
                    local p = State.effectivePower(pc, cards, isW, isH)
                    if p < bestP then bestP = p; bestRow = row; bestIdx = i end
                end
            end
        end
        return { type = "decoy", targetRow = bestRow, targetIndex = bestIdx }

    elseif pa.type == "agility_choose" then
        local bestRow, bestN = "attack", -1
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            local n = #match.players["opponent"].pitch[row]
            if n > bestN then bestN = n; bestRow = row end
        end
        return { type = "agility", chosenRow = bestRow }

    elseif pa.type == "horn_choose" then
        local bestRow, bestP = "attack", -1
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            local total = 0
            for _, pc in ipairs(match.players["opponent"].pitch[row]) do
                if not pc.definition.hero then total = total + pc.basePower end
            end
            if total > bestP then bestP = total; bestRow = row end
        end
        return { type = "horn", chosenRow = bestRow }
    end
    return nil
end

-- ── Mulligan ──────────────────────────────────────────────────────────────────

function AI._pickMulligan(match, difficulty)
    local hand = match.players.opponent.hand
    local left = match.mulliganLeft.opponent
    if left == 0 or #hand == 0 then return {} end
    if difficulty == "easy" then
        local out = {}
        for i = 1, math.min(left, #hand) do
            if math.random(2) == 1 then table.insert(out, hand[i].instanceId) end
        end
        return out
    end
    local scored = {}
    for _, hc in ipairs(hand) do
        if not hc.definition.hero and hc.definition.row ~= "special" then
            table.insert(scored, { hc = hc, p = hc.definition.power or 0 })
        end
    end
    table.sort(scored, function(a, b) return a.p < b.p end)
    local out = {}
    for i = 1, math.min(left, #scored) do
        if scored[i].p < 3 then table.insert(out, scored[i].hc.instanceId) end
    end
    return out
end

-- ── Main action ───────────────────────────────────────────────────────────────

function AI._pickMainAction(match, difficulty)
    local myScore  = State.score(match.players.opponent, match, "opponent")
    local oppScore = State.score(match.players.player,   match, "player")

    if AI._shouldPass(match, myScore, oppScore, difficulty) then
        return { type = "pass" }
    end

    if not match.leaderUsed.opponent and difficulty ~= "easy" then
        if myScore <= oppScore then
            return { type = "leader" }
        end
    end

    local action = AI._pickCard(match, difficulty)
    if action then return action end
    return { type = "pass" }
end

function AI._shouldPass(match, myScore, oppScore, difficulty)
    local hand = match.players.opponent.hand
    if #hand == 0 then return true end
    if difficulty == "easy" then return false end
    if match.passed.player and myScore > oppScore then return true end
    if myScore > oppScore then
        local lead = myScore - oppScore
        if difficulty == "medium" and lead >= 6 then return true end
        if difficulty == "hard" then
            local handPower = 0
            for _, hc in ipairs(hand) do handPower = handPower + (hc.definition.power or 0) end
            if handPower <= lead then return true end
        end
    end
    return false
end

-- ── Card selection ────────────────────────────────────────────────────────────

function AI._pickCard(match, difficulty)
    local hand = match.players.opponent.hand
    if #hand == 0 then return nil end

    if difficulty == "easy" then
        local playable = {}
        for _, hc in ipairs(hand) do
            if hc.definition.row ~= "special" then table.insert(playable, hc) end
        end
        if #playable == 0 then
            local hc = hand[math.random(#hand)]
            return { type = "special", instanceId = hc.instanceId }
        end
        local pick = playable[math.random(#playable)]
        return { type = "card", instanceId = pick.instanceId, row = pick.definition.row }
    end

    local best, bestScore = nil, -math.huge
    for _, hc in ipairs(hand) do
        local def = hc.definition
        if def.row == "special" then
            local s = AI._scoreSpecial(match, def, difficulty)
            if s > bestScore then
                bestScore = s
                best = { type = "special", instanceId = hc.instanceId }
            end
        else
            local s, row = AI._scoreUnit(match, hc, difficulty)
            if s > bestScore then
                bestScore = s
                best = { type = "card", instanceId = hc.instanceId, row = row or def.row }
            end
        end
    end
    return best
end

function AI._scoreUnit(match, hc, _difficulty)
    local def   = hc.definition
    local row   = def.row
    local p     = def.power or 0
    local pitch = match.players.opponent.pitch
    local isW   = match.weather[row] ~= nil
    local isH   = match.hornRows.opponent[row]

    local simCards = {}
    for _, c in ipairs(pitch[row]) do table.insert(simCards, c) end
    local fakePc = { definition = def, basePower = p, instanceId = -1 }
    table.insert(simCards, fakePc)

    local contrib = State.effectivePower(fakePc, simCards, isW, isH)

    if isW and not def.hero then
        contrib = 1
    end

    if def.ability == "SPY" then
        return p + 8, row
    end

    return contrib, row
end

function AI._scoreSpecial(match, def, difficulty)
    local ability  = def.ability
    local oppPitch = match.players.player.pitch

    if ability == "WEATHER_FROST" and match.weather.attack == nil then
        local gain = 0
        for _, pc in ipairs(oppPitch.attack) do
            if not pc.definition.hero then gain = gain + (pc.basePower - 1) end
        end
        return gain > 0 and gain or -1
    elseif ability == "WEATHER_FOG" and match.weather.midfield == nil then
        local gain = 0
        for _, pc in ipairs(oppPitch.midfield) do
            if not pc.definition.hero then gain = gain + (pc.basePower - 1) end
        end
        return gain > 0 and gain or -1
    elseif ability == "WEATHER_RAIN" and match.weather.defense == nil then
        local gain = 0
        for _, pc in ipairs(oppPitch.defense) do
            if not pc.definition.hero then gain = gain + (pc.basePower - 1) end
        end
        return gain > 0 and gain or -1
    elseif ability == "CLEAR_WEATHER" then
        local myPitch = match.players.opponent.pitch
        local loss = 0
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            if match.weather[row] ~= nil then
                for _, pc in ipairs(myPitch[row]) do
                    if not pc.definition.hero then loss = loss + (pc.basePower - 1) end
                end
            end
        end
        return loss > 0 and loss or -1
    elseif ability == "COMMANDERS_HORN" then
        local bestGain = 0
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            if not match.hornRows.opponent[row] then
                local gain = 0
                for _, pc in ipairs(match.players.opponent.pitch[row]) do
                    if not pc.definition.hero then gain = gain + pc.basePower end
                end
                if gain > bestGain then bestGain = gain end
            end
        end
        return bestGain > 0 and bestGain or -1
    elseif ability == "SCORCH" then
        return difficulty == "hard" and 5 or 2
    elseif ability == "DECOY" then
        return 3
    end
    return -1
end

return AI
