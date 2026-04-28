-- engine/gwent/phases.lua
local C         = require("engine.gwent.constants")
local State     = require("engine.gwent.state")
local Abilities = require("engine.gwent.abilities")

local Phases = {}

local function log(match, entry) table.insert(match.log, entry) end
local function opp(id) return id == "player" and "opponent" or "player" end

local function findHandCard(match, pid, instanceId)
    local hand = match.players[pid].hand
    for i, hc in ipairs(hand) do
        if hc.instanceId == instanceId then return hc, i end
    end
    return nil, nil
end

-- ── Play unit card ─────────────────────────────────────────────────────────────

local PITCH_ROWS = { attack = true, midfield = true, defense = true }

function Phases.playCard(match, instanceId, row, opts)
    if not PITCH_ROWS[row] then return false, "invalid row: " .. tostring(row) end
    local pid = match.activePlayer
    local hc, hi = findHandCard(match, pid, instanceId)
    if not hc then return false, "card not in hand" end
    local def = hc.definition
    if def.row ~= row and def.ability ~= "AGILITY" then
        return false, "card belongs to row: " .. (def.row or "?")
    end

    -- Agility: if no row confirmed yet, set pendingAction and wait
    if def.ability == "AGILITY" and not (opts and opts.rowConfirmed) then
        match.pendingAction = {
            type       = "agility_choose",
            pid        = pid,
            instanceId = instanceId,
        }
        log(match, { type = "pending_agility", player = pid, card = def.name })
        return true, nil
    end

    table.remove(match.players[pid].hand, hi)

    -- Devour: set basePower = def.power + #graveyard before creating pitched card
    local overridePower = nil
    if def.ability == "DEVOUR" then
        overridePower = (def.power or 0) + #match.players[pid].graveyard
    end

    local pc = State.newPitchedCard(hc, overridePower)

    -- Spy: place on OPPONENT's board
    if def.ability == "SPY" then
        table.insert(match.players[opp(pid)].pitch[row], pc)
        log(match, { type = "play_spy", player = pid, card = def.name, row = row })
        Abilities.onPlay(match, pc, pid, opts)  -- draw 2
        return true, nil
    end

    table.insert(match.players[pid].pitch[row], pc)
    log(match, { type = "play_card", player = pid, card = def.name, row = row })

    Abilities.onPlay(match, pc, pid, opts)
    return true, nil
end

-- ── Play special card ─────────────────────────────────────────────────────────

function Phases.playSpecial(match, instanceId, opts)
    local pid = match.activePlayer
    local hc, hi = findHandCard(match, pid, instanceId)
    if not hc then return false, "card not in hand" end
    if hc.definition.row ~= "special" then return false, "not a special card" end

    table.remove(match.players[pid].hand, hi)
    table.insert(match.players[pid].graveyard, hc.definition)
    log(match, { type = "play_special", player = pid, card = hc.definition.name })

    local proxy = { definition = hc.definition, basePower = 0, instanceId = 0 }
    Abilities.onPlay(match, proxy, pid, opts)
    return true, nil
end

-- ── Resolve interactive pending actions ───────────────────────────────────────

-- Medic: graveyardIndex is 1-based index into player's graveyard of non-hero cards.
function Phases.resolveMedic(match, graveyardIndex)
    local pa = match.pendingAction
    if not pa or pa.type ~= "medic_choose" then return false, "no medic pending" end
    local pid = pa.pid
    match.pendingAction = nil

    local graveyard = match.players[pid].graveyard
    local def = graveyard[graveyardIndex]
    if not def then return false, "invalid graveyard index" end
    if def.hero then return false, "cannot resurrect hero" end

    table.remove(graveyard, graveyardIndex)
    local hc = State.newHandCard(def)
    local pc = State.newPitchedCard(hc)
    table.insert(match.players[pid].pitch[def.row], pc)
    log(match, { type = "medic_revive", player = pid, card = def.name, row = def.row })
    -- No ability triggers on resurrected card (W3 rule)
    return true, nil
end

-- Decoy: targetRow + targetIndex specify the non-hero pitched card to return to hand.
function Phases.resolveDecoy(match, targetRow, targetIndex)
    local pa = match.pendingAction
    if not pa or pa.type ~= "decoy_choose" then return false, "no decoy pending" end
    local pid = pa.pid
    match.pendingAction = nil

    if not PITCH_ROWS[targetRow] then return false, "invalid row" end
    local cards = match.players[pid].pitch[targetRow]
    local pc    = cards[targetIndex]
    if not pc then return false, "invalid target" end
    if pc.definition.hero then return false, "cannot decoy a hero" end

    table.remove(cards, targetIndex)
    local hc = State.newHandCard(pc.definition)
    table.insert(match.players[pid].hand, hc)
    log(match, { type = "decoy_return", player = pid, card = pc.definition.name })
    return true, nil
end

-- Agility: player has confirmed which row to place the card in.
function Phases.resolveAgility(match, chosenRow)
    local pa = match.pendingAction
    if not pa or pa.type ~= "agility_choose" then return false, "no agility pending" end
    local instanceId = pa.instanceId
    match.pendingAction = nil

    if not PITCH_ROWS[chosenRow] then return false, "invalid row" end
    return Phases.playCard(match, instanceId, chosenRow, { rowConfirmed = true })
end

-- Horn: player picks which of their rows to activate.
function Phases.resolveHorn(match, chosenRow)
    local pa = match.pendingAction
    if not pa or pa.type ~= "horn_choose" then return false, "no horn pending" end
    local pid = pa.pid
    match.pendingAction = nil

    if not PITCH_ROWS[chosenRow] then return false, "invalid row" end
    match.hornRows[pid][chosenRow] = true
    log(match, { type = "horn_activated", player = pid, row = chosenRow })
    return true, nil
end

-- ── Activate leader ───────────────────────────────────────────────────────────

function Phases.activateLeader(match, pid, opts)
    if match.leaderUsed[pid] then return false, "leader already used" end
    if match.winner then return false, "match over" end
    match.leaderUsed[pid] = true
    local leader = match.players[pid].leader
    log(match, { type = "leader_activated", player = pid, card = leader.name })
    Abilities.onLeader(match, leader, pid, opts or {})
    return true, nil
end

-- ── Pass ─────────────────────────────────────────────────────────────────────

function Phases.pass(match)
    local pid = match.activePlayer
    match.passed[pid] = true
    log(match, { type = "pass", player = pid })
    if match.passed.player and match.passed.opponent then
        Phases.endHalf(match)
    else
        Phases.endTurn(match)
    end
end

-- ── End turn ─────────────────────────────────────────────────────────────────

function Phases.endTurn(match)
    local nxt = opp(match.activePlayer)
    if match.passed[nxt] then return end
    match.activePlayer = nxt
end

-- ── End half ─────────────────────────────────────────────────────────────────

function Phases.endHalf(match)
    local ps = State.score(match.players.player,   match, "player")
    local os = State.score(match.players.opponent, match, "opponent")

    local halfWinner = nil
    if ps > os     then halfWinner = "player"
    elseif os > ps then halfWinner = "opponent"
    end
    if halfWinner then
        match.halvesWon[halfWinner] = match.halvesWon[halfWinner] + 1
    end
    log(match, { type = "half_end", half = match.half,
                 playerScore = ps, opponentScore = os, winner = halfWinner })

    -- Monsters faction: keep 1 random non-hero unit card on board
    for _, side in ipairs({"player", "opponent"}) do
        if match.players[side].faction == "monsters" then
            local keepers = {}
            for _, row in ipairs({"attack", "midfield", "defense"}) do
                for _, pc in ipairs(match.players[side].pitch[row]) do
                    if not pc.definition.hero then
                        table.insert(keepers, { pc = pc, row = row })
                    end
                end
            end
            local keepEntry = #keepers > 0 and keepers[math.random(#keepers)] or nil

            for _, row in ipairs({"attack", "midfield", "defense"}) do
                for _, pc in ipairs(match.players[side].pitch[row]) do
                    table.insert(match.players[side].graveyard, pc.definition)
                end
            end
            match.players[side].pitch = State.newPitch()

            if keepEntry then
                table.insert(match.players[side].pitch[keepEntry.row], keepEntry.pc)
                log(match, { type = "monsters_keep", player = side, card = keepEntry.pc.definition.name })
            end
        else
            for _, row in ipairs({"attack", "midfield", "defense"}) do
                for _, pc in ipairs(match.players[side].pitch[row]) do
                    table.insert(match.players[side].graveyard, pc.definition)
                end
            end
            match.players[side].pitch = State.newPitch()
        end
    end

    -- Clear weather and horn at half end
    match.weather  = { attack = nil, midfield = nil, defense = nil }
    match.hornRows = {
        player   = { attack = false, midfield = false, defense = false },
        opponent = { attack = false, midfield = false, defense = false },
    }
    match.pendingAction = nil

    -- Check match win condition
    if match.halvesWon.player >= 2 then
        match.winner = "player"; match.phase = "match_end"; return
    elseif match.halvesWon.opponent >= 2 then
        match.winner = "opponent"; match.phase = "match_end"; return
    end
    if match.half == 2 and match.halvesWon.player == 1 and match.halvesWon.opponent == 1 then
        match.half = "extra"
    elseif match.half == "extra" then
        match.winner = halfWinner or "draw"; match.phase = "match_end"; return
    else
        match.half = match.half + 1
    end

    Phases.startHalf(match, halfWinner)
end

-- ── Start half ────────────────────────────────────────────────────────────────

function Phases.startHalf(match, prevHalfWinner)
    match.passed = { player = false, opponent = false }
    match.phase  = "mulligan"

    -- Between-half draw (NR faction gets +1 if they won the previous half)
    for _, side in ipairs({"player", "opponent"}) do
        local p    = match.players[side]
        local draw = math.min(C.BETWEEN_HALF_DRAW, #p.deck)
        if p.faction == "northern_realms" and prevHalfWinner == side then
            draw = math.min(draw + 1, #p.deck)
        end
        for _ = 1, draw do
            table.insert(p.hand, State.newHandCard(table.remove(p.deck, 1)))
        end
    end

    match.mulliganLeft = { player = C.MULLIGAN_BETWEEN, opponent = C.MULLIGAN_BETWEEN }

    if prevHalfWinner == "player" then
        match.activePlayer = "opponent"
    elseif prevHalfWinner == "opponent" then
        match.activePlayer = "player"
    end

    log(match, { type = "half_start", half = match.half })
end

-- ── Mulligan ──────────────────────────────────────────────────────────────────

function Phases.resolveMulligan(match, pid, instanceIds)
    local left  = match.mulliganLeft[pid]
    local hand  = match.players[pid].hand
    local deck  = match.players[pid].deck
    local toSwap = {}
    for i = 1, math.min(#instanceIds, left) do toSwap[i] = instanceIds[i] end

    local swapped = 0
    for _, iid in ipairs(toSwap) do
        for i, hc in ipairs(hand) do
            if hc.instanceId == iid then
                table.remove(hand, i)
                table.insert(deck, hc.definition)
                swapped = swapped + 1
                break
            end
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i); deck[i], deck[j] = deck[j], deck[i]
    end
    for _ = 1, swapped do
        if #deck > 0 then
            table.insert(hand, State.newHandCard(table.remove(deck, 1)))
        end
    end

    match.mulliganLeft[pid] = 0
    if match.mulliganLeft.player <= 0 and match.mulliganLeft.opponent <= 0 then
        match.phase = "play"
    end
end

return Phases
