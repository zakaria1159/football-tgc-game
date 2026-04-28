-- engine/gwent/abilities.lua
---@diagnostic disable: unused-local
local State = require("engine.gwent.state")

local Abilities = {}

local function log(match, entry) table.insert(match.log, entry) end

-- ── Dispatch table ────────────────────────────────────────────────────────────

local D = {}

-- TIGHT_BOND: power computed dynamically in State.effectivePower. No onPlay action.
D.TIGHT_BOND = function(_match, _pc, _pid, _opts) end

-- MORALE_BOOST: power bonus computed dynamically. No onPlay action.
D.MORALE_BOOST = function(_match, _pc, _pid, _opts) end

-- AGILITY: handled in phases.playCard via pendingAction flow.
D.AGILITY = function(_match, _pc, _pid, _opts) end

-- SPY: card was placed on opponent's pitch. Draw 2 cards for the spy's owner.
D.SPY = function(match, _pc, pid, _opts)
    local p = match.players[pid]
    for _ = 1, 2 do
        if #p.deck > 0 then
            table.insert(p.hand, State.newHandCard(table.remove(p.deck, 1)))
        end
    end
    log(match, { type = "draw", player = pid, amount = 2, reason = "spy" })
end

-- MEDIC: sets pendingAction for graveyard targeting.
D.MEDIC = function(match, pc, pid, _opts)
    local graveyard = match.players[pid].graveyard
    local targets = {}
    for i, def in ipairs(graveyard) do
        if not def.hero then table.insert(targets, { index = i, def = def }) end
    end
    if #targets == 0 then return end
    match.pendingAction = {
        type             = "medic_choose",
        pid              = pid,
        sourceInstanceId = pc.instanceId,
    }
    log(match, { type = "pending_medic", player = pid })
end

-- MUSTER: auto-play all cards sharing musterGroup from hand and deck.
-- No ability triggers on mustered copies.
D.MUSTER = function(match, pc, pid, _opts)
    local group = pc.definition.musterGroup
    if not group then return end
    local p = match.players[pid]

    -- Collect from hand (iterate backwards to avoid index shift)
    local handTargets = {}
    for i = #p.hand, 1, -1 do
        local hc = p.hand[i]
        if hc.definition.musterGroup == group
        and hc.instanceId ~= pc.instanceId then
            table.insert(handTargets, i)
        end
    end
    for _, i in ipairs(handTargets) do
        local hc  = table.remove(p.hand, i)
        local npc = State.newPitchedCard(hc)
        table.insert(p.pitch[hc.definition.row], npc)
        log(match, { type = "muster_play", player = pid, card = hc.definition.name, row = hc.definition.row })
    end

    -- Collect from deck
    local deckTargets = {}
    for i = #p.deck, 1, -1 do
        if p.deck[i].musterGroup == group then
            table.insert(deckTargets, i)
        end
    end
    for _, i in ipairs(deckTargets) do
        local def = table.remove(p.deck, i)
        local hc  = State.newHandCard(def)
        local npc = State.newPitchedCard(hc)
        table.insert(p.pitch[def.row], npc)
        log(match, { type = "muster_play", player = pid, card = def.name, row = def.row })
    end
end

-- DEVOUR: basePower was set to def.power + #graveyard at play time in phases.playCard.
D.DEVOUR = function(_match, _pc, _pid, _opts) end

-- FOG_BONUS: power bonus computed dynamically in State.score. No onPlay action.
D.FOG_BONUS = function(_match, _pc, _pid, _opts) end

-- COMMANDERS_HORN_SELF (The General): activates horn on own attack row on play.
D.COMMANDERS_HORN_SELF = function(match, _pc, pid, _opts)
    match.hornRows[pid]["attack"] = true
    log(match, { type = "horn_activated", player = pid, row = "attack" })
end

-- WEATHER_SUMMON (The Phantom hero): auto-plays Torrential Rain.
D.WEATHER_SUMMON = function(match, _pc, _pid, _opts)
    match.weather["defense"] = "RAIN"
    log(match, { type = "weather", weatherType = "RAIN", row = "defense" })
end

-- ── Special card abilities ────────────────────────────────────────────────────

-- DECOY: sets pendingAction for picking a pitched non-hero card to return.
D.DECOY = function(match, _pc, pid, _opts)
    local p   = match.players[pid]
    local any = false
    for _, row in ipairs({"attack", "midfield", "defense"}) do
        for _, pc in ipairs(p.pitch[row]) do
            if not pc.definition.hero then any = true; break end
        end
        if any then break end
    end
    if not any then return end
    match.pendingAction = { type = "decoy_choose", pid = pid }
    log(match, { type = "pending_decoy", player = pid })
end

-- COMMANDERS_HORN: sets pendingAction for picking a row.
D.COMMANDERS_HORN = function(match, _pc, pid, _opts)
    match.pendingAction = { type = "horn_choose", pid = pid }
    log(match, { type = "pending_horn", player = pid })
end

-- SCORCH: destroy all non-hero cards tied at the highest effective power on the battlefield.
D.SCORCH = function(match, _pc, _pid, _opts)
    local maxP = -1
    for _, side in ipairs({"player", "opponent"}) do
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            local cards     = match.players[side].pitch[row]
            local isWeathered = match.weather[row] ~= nil
            local isHorned  = match.hornRows[side][row]
            for _, pc in ipairs(cards) do
                if not pc.definition.hero then
                    local p = State.effectivePower(pc, cards, isWeathered, isHorned)
                    if p > maxP then maxP = p end
                end
            end
        end
    end
    if maxP < 0 then return end

    for _, side in ipairs({"player", "opponent"}) do
        for _, row in ipairs({"attack", "midfield", "defense"}) do
            local cards     = match.players[side].pitch[row]
            local isWeathered = match.weather[row] ~= nil
            local isHorned  = match.hornRows[side][row]
            local keep = {}
            for _, pc in ipairs(cards) do
                local p = State.effectivePower(pc, cards, isWeathered, isHorned)
                if pc.definition.hero or p ~= maxP then
                    table.insert(keep, pc)
                else
                    table.insert(match.players[side].graveyard, pc.definition)
                    log(match, { type = "scorch", card = pc.definition.name, player = side })
                end
            end
            match.players[side].pitch[row] = keep
        end
    end
end

-- CLEAR_WEATHER: remove all weather.
D.CLEAR_WEATHER = function(match, _pc, _pid, _opts)
    match.weather = { attack = nil, midfield = nil, defense = nil }
    log(match, { type = "weather_clear" })
end

-- WEATHER_FROST: attack row → 1 (both sides).
D.WEATHER_FROST = function(match, _pc, _pid, _opts)
    match.weather["attack"] = "FROST"
    log(match, { type = "weather", weatherType = "FROST", row = "attack" })
end

-- WEATHER_FOG: midfield row → 1 (both sides).
D.WEATHER_FOG = function(match, _pc, _pid, _opts)
    match.weather["midfield"] = "FOG"
    log(match, { type = "weather", weatherType = "FOG", row = "midfield" })
end

-- WEATHER_RAIN: defense row → 1 (both sides).
D.WEATHER_RAIN = function(match, _pc, _pid, _opts)
    match.weather["defense"] = "RAIN"
    log(match, { type = "weather", weatherType = "RAIN", row = "defense" })
end

-- ── Leader abilities ──────────────────────────────────────────────────────────

function Abilities.onLeader(match, leaderDef, pid, _opts)
    local ability = leaderDef.ability
    if ability == "NR_LEADER_DRAW" then
        local p = match.players[pid]
        if #p.deck > 0 then
            table.insert(p.hand, State.newHandCard(table.remove(p.deck, 1)))
            log(match, { type = "draw", player = pid, amount = 1, reason = "leader" })
        end
    elseif ability == "MN_LEADER_WEATHER" then
        local weathers = { "WEATHER_FROST", "WEATHER_FOG", "WEATHER_RAIN" }
        local fn = D[weathers[math.random(#weathers)]]
        if fn then fn(match, nil, pid, {}) end
    end
end

-- ── onPlay dispatcher ─────────────────────────────────────────────────────────

function Abilities.onPlay(match, pc, pid, opts)
    local ability = pc.definition and pc.definition.ability
    if not ability then return end
    local fn = D[ability]
    if fn then fn(match, pc, pid, opts or {}) end
end

return Abilities
