local C       = require("engine.constants")
local Stamina = require("engine.stamina")

local State = {}

local function newPitch()
    local defs = {}
    local strs = {}
    for i = 1, C.PITCH.MAX_DEFENDERS do defs[i] = nil end
    for i = 1, C.PITCH.MAX_STRIKERS  do strs[i] = nil end
    return {
        keeper     = nil,
        defenders  = defs,
        midfielder = nil,
        strikers   = strs,
        traps      = {},
    }
end

local function shuffle(t)
    local s = {}
    for _, v in ipairs(t) do table.insert(s, v) end
    for i = #s, 2, -1 do
        local j = math.random(i)
        s[i], s[j] = s[j], s[i]
    end
    return s
end

local function newPlayerState(id, deck)
    local shuffled = shuffle(deck)

    -- Guarantee at least one keeper in opening hand
    local handSize = math.min(C.MATCH.STARTING_HAND_SIZE, #shuffled)
    local hasKeeper = false
    for i = 1, handSize do
        if shuffled[i].type == "keeper" then hasKeeper = true; break end
    end
    if not hasKeeper then
        for i = handSize + 1, #shuffled do
            if shuffled[i].type == "keeper" then
                local j = math.random(1, handSize)
                shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
                break
            end
        end
    end

    local hand = {}
    for i = 1, math.min(C.MATCH.STARTING_HAND_SIZE, #shuffled) do
        table.insert(hand, table.remove(shuffled, 1))
    end

    return {
        id               = id,
        hand             = hand,
        deck             = shuffled,
        graveyard        = {},
        pitch            = newPitch(),
        lp               = C.MATCH.STARTING_LP,
        halvesWon        = 0,
        totalDamageDealt = 0,
        halfDamageDealt  = 0,       -- LP damage dealt this half (half-limit / Extra Time decider)
        halfGoals        = 0,       -- goals scored this half (shots that dealt LP damage, minus VAR)
        halfCardsLost    = 0,       -- own field cards destroyed this half
        nextTurnSummonLimit = nil,  -- set by TIME_WASTING trap
        subsUsed         = 0,       -- substitutions this half (keeper swaps included; spec B2)
        subFreedSlot     = nil,     -- Substitution card: the slot its free placement fills this turn
    }
end

-- Creates a new pitched card from a definition.
function State.newPitchedCard(definition, slotType, mode)
    return {
        definition        = definition,
        exhausted         = false,
        mode              = mode or "attack",   -- "attack" or "defense"
        cannotActNextTurn = false,              -- set true after covering
        usedAsAttacker    = false,              -- set when it attacks; cleared at the start of its owner's turn
        revealed          = false,              -- face-down card seen by both players; still in defense mode
        slotType          = slotType or definition.type,
        stamina           = Stamina.max(definition),  -- full; nil = never tires (keepers, traps)
    }
end

-- Creates a new match state.
function State.newMatch(playerDeck, opponentDeck)
    return {
        id           = tostring(os.time()),
        turn         = 1,
        half         = 1,
        phase        = "draw",
        activePlayer = "player",
        halfStarter  = "player",   -- who kicks off this half (State.kickOffSeat)
        summonCount  = 0,
        bonusSummons = 0,          -- extra summons this turn (Metronome)
        coverUsed    = { player = false, opponent = false },
        extraTurnsLeft = 0,
        strategyPlayedThisTurn = false,
        players = {
            player   = newPlayerState("player",   playerDeck),
            opponent = newPlayerState("opponent", opponentDeck),
        },
        winner = nil,
        log    = {},
        halfTimeBreak = false,      -- true between a half ending and State.kickOff
        mulliganUsed  = { player = false, opponent = false },   -- this break
        lastHalfStats = nil,        -- { player = { lp, damage, goals, lost }, opponent = {...} }
    }
end

-- Appends an event to the match log.
function State.log(matchState, eventType, payload)
    table.insert(matchState.log, {
        turn      = matchState.turn,
        half      = matchState.half,
        phase     = matchState.phase,
        type      = eventType,
        payload   = payload or {},
    })
end

function State.activePlayerState(matchState)
    return matchState.players[matchState.activePlayer]
end

function State.opponentState(matchState)
    local opp = matchState.activePlayer == "player" and "opponent" or "player"
    return matchState.players[opp]
end

-- The other seat.
function State.other(playerId)
    return playerId == "player" and "opponent" or "player"
end

-- True on the first turn of a half (Extra Time included) for the player who started it:
-- that turn has no attacks and no attacking strategies (Direct Free Kick, Penalty).
function State.isOpeningTurn(matchState)
    return matchState.turn == 1 and matchState.activePlayer == (matchState.halfStarter or "player")
end

-- dealerId deals `amount` LP damage to the other seat.
function State.dealDamage(matchState, dealerId, amount)
    local dealer = matchState.players[dealerId]
    local victim = matchState.players[State.other(dealerId)]
    victim.lp = victim.lp - amount
    dealer.totalDamageDealt = dealer.totalDamageDealt + amount
    dealer.halfDamageDealt  = (dealer.halfDamageDealt or 0) + amount
end

-- A shot by scorerId dealt LP damage: one goal this half.
function State.countGoal(matchState, scorerId)
    local ps = matchState.players[scorerId]
    ps.halfGoals = (ps.halfGoals or 0) + 1
end

-- One of ownerId's field cards was destroyed this half.
function State.countCardLost(matchState, ownerId)
    local ps = matchState.players[ownerId]
    ps.halfCardsLost = (ps.halfCardsLost or 0) + 1
end

-- Undo damage (VAR): the victim gets the LP back and the dealer's totals drop.
-- VAR only ever overturns a goal, so the dealer's goal count drops too.
function State.refundDamage(matchState, dealerId, amount)
    local dealer = matchState.players[dealerId]
    local victim = matchState.players[State.other(dealerId)]
    victim.lp = victim.lp + amount
    dealer.totalDamageDealt = dealer.totalDamageDealt - amount
    dealer.halfDamageDealt  = (dealer.halfDamageDealt or 0) - amount
    dealer.halfGoals        = math.max(0, (dealer.halfGoals or 0) - 1)
end

-- Winner of a half that ran out of rounds: more LP → more damage dealt this half →
-- the player who went second this half.
function State.decideOnTime(matchState)
    local p = matchState.players.player
    local o = matchState.players.opponent
    if p.lp ~= o.lp then return p.lp > o.lp and "player" or "opponent" end
    local pd, od = p.halfDamageDealt or 0, o.halfDamageDealt or 0
    if pd ~= od then return pd > od and "player" or "opponent" end
    return State.other(matchState.halfStarter or "player")
end

function State.drawCard(matchState, playerId)
    local player = matchState.players[playerId]
    if #player.deck == 0 then return nil end
    local card = table.remove(player.deck, 1)
    table.insert(player.hand, card)
    return card
end

function State.removeFromHand(player, cardId)
    for i, card in ipairs(player.hand) do
        if card.id == cardId then
            return table.remove(player.hand, i)
        end
    end
    return nil
end

-- Count active (non-exhausted) cards of a given line for keeper formula.
function State.activeCount(pitch, line)
    local count = 0
    if line == "defender" then
        for _, c in ipairs(pitch.defenders) do
            if c and not c.exhausted then count = count + 1 end
        end
    elseif line == "midfielder" then
        if pitch.midfielder and not pitch.midfielder.exhausted then count = 1 end
    end
    return count
end

-- Check if a half has ended. Returns winnerId, reason ("lp" | "time"), or nil.
--   LP:   a player at 0 LP or less loses the half.
--   Time: halves 1 and 2 end after C.MATCH.HALF_ROUND_LIMIT rounds; Extra Time after
--         C.MATCH.EXTRA_TIME_TURNS rounds (extraTurnsLeft reaches 0).
function State.checkHalfEnd(matchState)
    local p = matchState.players.player
    local o = matchState.players.opponent
    if p.lp <= 0 then return "opponent", "lp" end
    if o.lp <= 0 then return "player", "lp" end
    if matchState.half == "extra" then
        if matchState.extraTurnsLeft <= 0 then
            -- Extra Time LP → Extra Time damage → the player who went second
            return State.decideOnTime(matchState), "time"
        end
        return nil
    end
    if matchState.turn > C.MATCH.HALF_ROUND_LIMIT then
        return State.decideOnTime(matchState), "time"
    end
    return nil
end

-- Stats of the half just played (read by the half-time screen), taken before the reset.
local function recordHalfStats(matchState)
    local stats = {}
    for _, seat in ipairs({ "player", "opponent" }) do
        local ps = matchState.players[seat]
        stats[seat] = {
            lp     = ps.lp,
            damage = ps.halfDamageDealt or 0,
            goals  = ps.halfGoals or 0,
            lost   = ps.halfCardsLost or 0,
        }
    end
    matchState.lastHalfStats = stats
end

-- Called when a half ends. Advances to next half or ends the match.
-- When the match goes on (half 2, Extra Time) the new half starts in a half-time break
-- (matchState.halfTimeBreak) until State.kickOff.
function State.endHalf(matchState, halfWinner, reason)
    State.log(matchState, "half_end", { half = matchState.half, winner = halfWinner, reason = reason or "lp" })
    matchState.players[halfWinner].halvesWon = matchState.players[halfWinner].halvesWon + 1
    recordHalfStats(matchState)

    local p = matchState.players.player
    local o = matchState.players.opponent

    -- Check match win
    if p.halvesWon >= 2 then
        matchState.winner = "player"; return
    elseif o.halvesWon >= 2 then
        matchState.winner = "opponent"; return
    end

    -- Both won one half → Extra Time
    if matchState.half == 1 then
        -- Start half 2
        State._resetHalf(matchState, 2)
    elseif matchState.half == 2 then
        if p.halvesWon ~= o.halvesWon then
            -- One player won both → match over (shouldn't reach here normally)
            matchState.winner = p.halvesWon > o.halvesWon and "player" or "opponent"
        else
            -- 1-1 → Extra Time
            State._resetHalf(matchState, "extra")
            matchState.extraTurnsLeft = C.MATCH.EXTRA_TIME_TURNS
        end
    end
end

-- Who kicks off a half: the player in half 1, the opponent in half 2, a coin toss
-- (math.random(2)) in Extra Time.
function State.kickOffSeat(half)
    if half == 2 then return "opponent" end
    if half == "extra" then return math.random(2) == 1 and "player" or "opponent" end
    return "player"
end

function State._resetHalf(matchState, newHalf)
    matchState.half         = newHalf
    matchState.turn         = 1
    matchState.phase        = "draw"
    matchState.halfStarter  = State.kickOffSeat(newHalf)
    matchState.activePlayer = matchState.halfStarter
    matchState.summonCount  = 0
    matchState.bonusSummons = 0
    matchState.coverUsed    = { player = false, opponent = false }
    matchState.strategyPlayedThisTurn = false
    matchState.bypassCoverNextStrikerAttack = nil
    matchState.halfTimeBreak = true
    matchState.mulliganUsed  = { player = false, opponent = false }

    -- Fixed order (not pairs): the redeal consumes math.random, so seeded runs repeat.
    for _, seat in ipairs({ "player", "opponent" }) do
        local ps = matchState.players[seat]
        ps.lp                  = C.MATCH.STARTING_LP
        ps.halfDamageDealt     = 0
        ps.halfGoals           = 0
        ps.halfCardsLost       = 0
        ps.nextTurnSummonLimit = nil
        ps.subsUsed            = 0     -- 3 substitutions per half; Extra Time gets 3 too
        ps.subFreedSlot        = nil

        -- Collect all non-destroyed cards (hand + pitch) back into pool for redeal.
        -- Graveyard (permanently destroyed) stays out.
        local pool = {}
        for _, cardDef in ipairs(ps.hand) do table.insert(pool, cardDef) end
        if ps.pitch.keeper     then table.insert(pool, ps.pitch.keeper.definition) end
        if ps.pitch.midfielder then table.insert(pool, ps.pitch.midfielder.definition) end
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if ps.pitch.defenders[i] then table.insert(pool, ps.pitch.defenders[i].definition) end
        end
        for i = 1, C.PITCH.MAX_STRIKERS do
            if ps.pitch.strikers[i] then table.insert(pool, ps.pitch.strikers[i].definition) end
        end
        for _, trap in ipairs(ps.pitch.traps) do table.insert(pool, trap.definition) end
        for _, cardDef in ipairs(ps.deck) do table.insert(pool, cardDef) end

        local shuffled = shuffle(pool)

        -- Guarantee at least one keeper in opening hand
        local handSize = math.min(C.MATCH.STARTING_HAND_SIZE, #shuffled)
        local hasKeeper = false
        for i = 1, handSize do
            if shuffled[i].type == "keeper" then hasKeeper = true; break end
        end
        if not hasKeeper then
            for i = handSize + 1, #shuffled do
                if shuffled[i].type == "keeper" then
                    local j = math.random(1, handSize)
                    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
                    break
                end
            end
        end

        local hand = {}
        for i = 1, handSize do table.insert(hand, table.remove(shuffled, 1)) end

        ps.hand  = hand
        ps.deck  = shuffled
        ps.pitch = newPitch()
    end
end

-- Ends the half-time break: play resumes.
function State.kickOff(matchState)
    matchState.halfTimeBreak = false
end

-- Half-time swap: during the break, playerId sends back up to C.MATCH.MULLIGAN_MAX cards
-- from their hand; they go into the deck, the deck is shuffled and as many cards are
-- drawn. Once per break per player (a refused or empty swap does not use it). No keeper
-- guarantee. Returns the number of cards swapped, or 0 + reason when refused.
function State.mulligan(matchState, playerId, cardIds)
    if not matchState.halfTimeBreak then return 0, "not in a half-time break" end
    matchState.mulliganUsed = matchState.mulliganUsed or {}
    if matchState.mulliganUsed[playerId] then return 0, "already swapped this break" end
    local n = #(cardIds or {})
    if n == 0 then return 0 end
    if n > C.MATCH.MULLIGAN_MAX then return 0, "at most " .. C.MATCH.MULLIGAN_MAX .. " cards" end

    local ps = matchState.players[playerId]
    -- Copies in a preset deck share an id, so an id may be chosen as many times as the
    -- hand holds it (and no more).
    local copies = {}
    for _, c in ipairs(ps.hand) do copies[c.id] = (copies[c.id] or 0) + 1 end
    for _, id in ipairs(cardIds) do
        if not copies[id] then return 0, "card not in hand" end
        if copies[id] == 0 then return 0, "card chosen twice" end
        copies[id] = copies[id] - 1
    end

    for _, id in ipairs(cardIds) do
        table.insert(ps.deck, State.removeFromHand(ps, id))
    end
    ps.deck = shuffle(ps.deck)
    for _ = 1, n do State.drawCard(matchState, playerId) end
    matchState.mulliganUsed[playerId] = true
    return n
end

return State
