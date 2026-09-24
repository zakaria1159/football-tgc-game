local C      = require("engine.constants")
local T      = require("engine.types")
local State  = require("engine.state")
local Combat = require("engine.combat")
local Resolver = require("engine.cards.resolver")
local Stamina = require("engine.stamina")

local Phases = {}

-- ─── DRAW ────────────────────────────────────────────────────────────────────

function Phases.draw(matchState)
    local id = matchState.activePlayer
    -- No normal draw on turn 1 of halves 1 and 2 (Extra Time draws on turn 1).
    if not (matchState.turn == 1 and matchState.half ~= "extra") then
        local card = State.drawCard(matchState, id)
        if card then
            State.log(matchState, T.EventType.CARD_DRAWN, { player = id, card = card.id })
        end
    end
    Phases._midfieldControl(matchState)
end

-- Midfield control: a player whose midfielder-type card has more power than the
-- opponent's (ATK in attack mode, DEF in defense mode; face-down cards count) draws
-- C.MATCH.MIDFIELD_CONTROL_DRAW extra card(s) after the normal draw.
function Phases._midfieldControl(matchState)
    local id     = matchState.activePlayer
    local myPow  = Combat.midfielderPower(matchState.players[id].pitch)
    local oppPow = Combat.midfielderPower(matchState.players[State.other(id)].pitch)
    if myPow <= oppPow then return end
    Resolver.onMidfieldControl(matchState, id)   -- Metronome (even with an empty deck)
    -- Nothing to draw (empty deck): no bonus, and no event for the UI to announce.
    local n = math.min(C.MATCH.MIDFIELD_CONTROL_DRAW, #matchState.players[id].deck)
    if n <= 0 then return end
    State.log(matchState, T.EventType.MIDFIELD_CONTROL,
        { player = id, myPow = myPow, oppPow = oppPow, bonus = "draw" })
    for _ = 1, n do
        local card = State.drawCard(matchState, id)
        if card then
            State.log(matchState, T.EventType.CARD_DRAWN,
                { player = id, card = card.id, source = "midfield_control" })
        end
    end
end

-- ─── SUMMON ───────────────────────────────────────────────────────────────────

-- Place a card from hand onto the pitch.
-- mode: "attack" (face up) or "defense" (face down)
-- freeSummon = true skips the summon-count check and increment (used by Substitution).
-- Returns true on success.
function Phases.summon(matchState, cardId, slotType, slotIndex, mode, freeSummon)
    local player = State.activePlayerState(matchState)

    -- Strategy cards cannot be summoned
    if slotType ~= "trap" then
        local peek = nil
        for _, c in ipairs(player.hand) do if c.id == cardId then peek = c; break end end
        if peek and peek.type == "strategy" then
            return false, "strategy cards cannot be summoned"
        end
    end

    -- Summon limit (skip for trap cards which use a free set action; skip for free summons)
    if not freeSummon and slotType ~= "trap" then
        local limit = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                    + (matchState.bonusSummons or 0)   -- Metronome
        if matchState.summonCount >= limit then
            return false, "summon limit reached"
        end
    end

    local cardDef = State.removeFromHand(player, cardId)
    if not cardDef then return false, "card not in hand" end

    -- Trap card: goes face-down into the trap zone (always defense, never costs a summon)
    if cardDef.type == "trap" then
        if #player.pitch.traps >= C.PITCH.MAX_TRAPS then
            table.insert(player.hand, cardDef)
            return false, "trap zone full"
        end
        local trapCard = State.newPitchedCard(cardDef, "trap", "defense")
        table.insert(player.pitch.traps, trapCard)
        State.log(matchState, T.EventType.CARD_PLAYED,
            { player = matchState.activePlayer, card = cardId, slot = "trap", mode = "defense" })
        return true
    end

    mode = mode or "attack"
    local pitched = State.newPitchedCard(cardDef, slotType, mode)
    pitched.summonedThisTurn = true   -- can't flip this turn; attacks next turn unless Pace (D1)

    if slotType == "keeper" then
        local old = player.pitch.keeper
        if old then
            -- Keeper substitution: a keeper card may replace the pitched keeper (a normal
            -- summon, never a free one). The old keeper goes back to hand as a plain card
            -- definition, so its per-half counters and flags are gone.
            if freeSummon or cardDef.type ~= "keeper" then
                table.insert(player.hand, cardDef)
                return false, "keeper slot occupied"
            end
            player.pitch.keeper = pitched
            table.insert(player.hand, old.definition)
            matchState.summonCount = matchState.summonCount + 1
            State.log(matchState, T.EventType.CARD_PLAYED,
                { player = matchState.activePlayer, card = cardId, slot = "keeper", index = 0,
                  mode = mode, action = "keeper_swap", name = cardDef.name,
                  replaced = old.definition.id, replacedName = old.definition.name })
            Phases._afterSummon(matchState, matchState.activePlayer, pitched)
            return true
        end
        player.pitch.keeper = pitched
    elseif slotType == "defender" then
        if slotIndex < 1 or slotIndex > C.PITCH.MAX_DEFENDERS then
            table.insert(player.hand, cardDef)
            return false, "defender slot out of range"
        end
        if player.pitch.defenders[slotIndex] then
            table.insert(player.hand, cardDef)
            return false, "defender slot occupied"
        end
        player.pitch.defenders[slotIndex] = pitched
    elseif slotType == "midfielder" then
        if player.pitch.midfielder then
            table.insert(player.hand, cardDef)
            return false, "midfielder slot occupied"
        end
        player.pitch.midfielder = pitched
    elseif slotType == "striker" then
        if slotIndex < 1 or slotIndex > C.PITCH.MAX_STRIKERS then
            table.insert(player.hand, cardDef)
            return false, "striker slot out of range"
        end
        if player.pitch.strikers[slotIndex] then
            table.insert(player.hand, cardDef)
            return false, "striker slot occupied"
        end
        player.pitch.strikers[slotIndex] = pitched
    else
        table.insert(player.hand, cardDef)
        return false, "invalid slot"
    end

    if not freeSummon then
        matchState.summonCount = matchState.summonCount + 1
    end
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = matchState.activePlayer, card = cardId, slot = slotType,
          index = slotIndex, mode = mode })
    Phases._afterSummon(matchState, matchState.activePlayer, pitched)   -- Press
    return true
end

-- Summon hooks once a card is on the pitch: Press, which costs its card
-- C.STAMINA.ABILITY_COST when it fires.
function Phases._afterSummon(matchState, ownerId, pitched)
    if Resolver.onSummon(matchState, ownerId, pitched) then
        Phases._spend(matchState, ownerId, pitched, C.STAMINA.ABILITY_COST)
    end
end

-- May the active player bring cardDef on as a keeper substitution now? A keeper card from
-- hand onto an occupied keeper slot, in the summon phase, outside a half-time break, with a
-- summon left (it costs one, like Phases.summon).
function Phases.canKeeperSwap(matchState, cardDef)
    if not cardDef or cardDef.type ~= "keeper" then return false end
    if matchState.halfTimeBreak or matchState.phase ~= "summon" then return false end
    local player = State.activePlayerState(matchState)
    if not player.pitch.keeper then return false end
    local limit = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                + (matchState.bonusSummons or 0)
    return matchState.summonCount < limit
end

-- ─── STRATEGY CARDS ──────────────────────────────────────────────────────────

-- Play a strategy card from hand during the attack phase (or summon phase for Substitution).
-- opts: optional context table for targeting effects (e.g. SCOUT_REPORT, SUBSTITUTION).
-- Returns result table on success, or false + error string on failure.
function Phases.playStrategy(matchState, cardId, opts)
    local activeId   = matchState.activePlayer
    local opponentId = activeId == "player" and "opponent" or "player"
    local player     = matchState.players[activeId]

    local cardDef = State.removeFromHand(player, cardId)
    if not cardDef then return false, "card not in hand" end
    if cardDef.type ~= "strategy" then
        table.insert(player.hand, cardDef)
        return false, "not a strategy card"
    end

    local ability = cardDef.ability

    -- SUBSTITUTION is played during summon phase — no strategy limit
    if ability ~= "SUBSTITUTION" then
        if matchState.strategyPlayedThisTurn then
            table.insert(player.hand, cardDef)
            return false, "already played a strategy this turn"
        end
        if matchState.phase ~= "attack" then
            table.insert(player.hand, cardDef)
            return false, "strategies must be played during the attack phase"
        end
    else
        if matchState.phase ~= "summon" then
            table.insert(player.hand, cardDef)
            return false, "substitution must be played during the summon phase"
        end
    end

    -- First turn of a half: the starter may not shoot either.
    if (ability == "DIRECT_FREE_KICK" or ability == "PENALTY") and State.isOpeningTurn(matchState) then
        table.insert(player.hand, cardDef)
        return false, "no attacks on the first turn of a half"
    end

    -- Commit: discard the card
    table.insert(player.graveyard, cardDef)
    if ability ~= "SUBSTITUTION" then
        matchState.strategyPlayedThisTurn = true
    end

    -- ── DIRECT FREE KICK / PENALTY ─────────────────────────────────────────────
    -- The best striker shoots at the keeper (Penalty: base DEF only). An empty keeper
    -- slot is an open goal for the striker's full ATK.
    if ability == "DIRECT_FREE_KICK" or ability == "PENALTY" then
        local best, bestSlot = Phases._bestStriker(player.pitch)
        if not best then
            table.remove(player.graveyard); table.insert(player.hand, cardDef)
            matchState.strategyPlayedThisTurn = false
            return false, ability == "PENALTY" and "Need an active striker on pitch to take a penalty"
                                               or  "Need an active striker on pitch to take a free kick"
        end
        local keeper = matchState.players[opponentId].pitch.keeper
        State.log(matchState, "strategy_played", { ability = ability, player = matchState.activePlayer })
        return Phases._goalAttempt(matchState, best, keeper, bestSlot, opponentId, ability == "PENALTY")

    -- ── TIME WASTING ────────────────────────────────────────────────────────────
    elseif ability == "TIME_WASTING" then
        if player.lp <= matchState.players[opponentId].lp then
            table.remove(player.graveyard); table.insert(player.hand, cardDef)
            matchState.strategyPlayedThisTurn = false
            return false, "Time Wasting requires you to be winning on LP"
        end
        matchState.players[opponentId].nextTurnSummonLimit = 1
        State.log(matchState, "strategy_played", { ability = ability, player = matchState.activePlayer })
        return { outcome = "time_wasting" }, nil

    -- ── SCOUT REPORT ────────────────────────────────────────────────────────────
    elseif ability == "SCOUT_REPORT" then
        -- opts.targetSlot = { owner, type, index } or nil → reveal first face-down found
        local revealedCard = nil
        if opts and opts.targetSlot then
            local tPitch = matchState.players[opts.targetSlot.owner].pitch
            revealedCard = Phases._getSlot(tPitch, opts.targetSlot)
            -- Scouted face-down cards stay revealed (face-up, still in defense mode).
            if revealedCard and revealedCard.mode == "defense" then revealedCard.revealed = true end
        end
        State.log(matchState, "strategy_played", { ability = ability, player = matchState.activePlayer })
        return { outcome = "scout_report", revealedCard = revealedCard }, nil

    -- ── SUBSTITUTION ────────────────────────────────────────────────────────────
    elseif ability == "SUBSTITUTION" then
        -- opts.returnSlot = { type, index } — the pitch slot to pull from
        if not opts or not opts.returnSlot then
            -- Return card to hand — caller needs to set up UI for target selection
            table.remove(player.graveyard); table.insert(player.hand, cardDef)
            matchState.strategyPlayedThisTurn = false
            return { outcome = "substitution_needs_target" }, nil
        end
        local returnCard = Phases._getSlot(player.pitch, opts.returnSlot)
        if not returnCard then
            table.remove(player.graveyard); table.insert(player.hand, cardDef)
            return false, "no card in return slot"
        end
        -- Remove from pitch → add definition back to hand
        Phases._setSlot(player.pitch, opts.returnSlot, nil)
        table.insert(player.hand, returnCard.definition)
        State.log(matchState, "strategy_played", { ability = ability, slot = opts.returnSlot, player = matchState.activePlayer })
        return { outcome = "substitution_done", freedSlot = opts.returnSlot }, nil

    else
        State.log(matchState, "strategy_played", { ability = ability, unimplemented = true, player = matchState.activePlayer })
        return { outcome = "strategy_no_effect" }, nil
    end
end

-- ─── TRAP ACTIVATION ─────────────────────────────────────────────────────────

-- Activate a trap in the given player's trap zone by slot index (1-based).
-- Returns the activated trap card's definition, or nil if invalid.
function Phases.activateTrap(matchState, playerId, trapIndex)
    local pitch = matchState.players[playerId].pitch
    local trap  = pitch.traps[trapIndex]
    if not trap then return nil end
    table.remove(pitch.traps, trapIndex)
    table.insert(matchState.players[playerId].graveyard, trap.definition)
    State.log(matchState, "trap_activated",
        { player = playerId, trap = trap.definition.id, ability = trap.definition.ability })
    return trap.definition
end

-- An attack cancelled by Offside: the attacker is exhausted but not destroyed; Hard tackle
-- may also lock it. attackerId owns the attacker; defenderSlot is the declared target.
function Phases.cancelAttack(matchState, attackerId, attackerSlot, defenderSlot)
    local attacker = Phases._getSlotForPlayer(matchState, attackerId, attackerSlot)
    if not attacker then return end
    attacker.exhausted = true
    local target = defenderSlot and Phases._getSlotForPlayer(matchState, State.other(attackerId), defenderSlot)
    Resolver.onAttackCancelled(matchState, attackerId, attacker, target)
end

-- ─── ATTACK ───────────────────────────────────────────────────────────────────

-- Resolve an attack. defenderSlot may point to an empty slot.
-- Returns:
--   result table on direct combat resolution, OR
--   { outcome = "empty_slot", ... } when a covering decision is needed, OR
--   nil + error string on failure.
-- Position switch (spec A2): the one rule shared by the engine (Phases.changeMode), the UI
-- (Card.switchLabel) and the AI (AI.canSwitch). Pure: reads the card and ctx only.
--   ctx = { isOwnTurn, phase, halfTimeBreak } — isOwnTurn: the card's owner is the active player.
-- Once per turn per card, in its owner's summon phase: defense (face-down or revealed) →
-- attack, or attack → defense (face-up: revealed). Never keepers or traps; never on the turn
-- the card was played or substituted in, after it attacked this turn, while exhausted,
-- during the half-time break or on the opponent's turn.
-- Returns the mode the card would switch to ("attack" | "defense"), or nil + reason.
function Phases.canSwitch(card, slotType, ctx)
    ctx = ctx or {}
    if not card then return nil, "no card in slot" end
    if slotType == "keeper" or slotType == "trap" or card.slotType == "trap" then
        return nil, "keepers and traps never change position"
    end
    if ctx.halfTimeBreak then return nil, "half-time" end
    if not ctx.isOwnTurn or ctx.phase ~= "summon" then
        return nil, "switch positions in your summon phase"
    end
    if card.summonedThisTurn then return nil, "played this turn: switch it next turn" end
    if card.modeChanged then return nil, "already switched this turn" end
    if card.usedAsAttacker then return nil, "attacked this turn" end
    if card.exhausted then return nil, "exhausted" end
    return card.mode == "attack" and "defense" or "attack"
end

-- Switches the active player's card in a slot (Phases.canSwitch). attack → defense leaves it
-- face-up: revealed, because the opponent has already seen it. Returns true, or false + reason.
function Phases.changeMode(matchState, slotType, slotIndex)
    local activeId = matchState.activePlayer
    local card = Phases._getSlotForPlayer(matchState, activeId, { type = slotType, index = slotIndex })
    local toMode, why = Phases.canSwitch(card, slotType, {
        isOwnTurn = true, phase = matchState.phase, halfTimeBreak = matchState.halfTimeBreak,
    })
    if not toMode then return false, why end
    card.mode        = toMode
    card.modeChanged = true
    if toMode == "defense" then card.revealed = true end
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = activeId, slot = slotType, index = slotIndex, mode = toMode, action = "mode_change" })
    return true
end

-- True when a card can declare an attack right now: attack mode, not exhausted, not locked,
-- and not summoned this turn — unless it has Pace, or C.MATCH.SUMMONED_CAN_ATTACK is on.
-- Pure (engine, AI, scene).
function Phases.canAttackNow(card)
    if not card or card.exhausted or card.cannotActNextTurn or card.mode ~= "attack" then
        return false
    end
    if card.summonedThisTurn and not C.MATCH.SUMMONED_CAN_ATTACK
       and not Resolver.canAttackWhenSummoned(card) then
        return false
    end
    return true
end

-- Through ball: a striker-slot attack on the keeper slot while both enemy defender slots
-- are filled. Returns the Through ball card on the active player's pitch, or nil.
function Phases._throughBallFor(matchState, attackerSlot, defenderSlot)
    if defenderSlot.type ~= "keeper" or attackerSlot.type ~= "striker" then return nil end
    local oppPitch = matchState.players[State.other(matchState.activePlayer)].pitch
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not oppPitch.defenders[i] then return nil end   -- a gap: a normal shot
    end
    return Resolver.throughBall(matchState.players[matchState.activePlayer].pitch)
end

-- Checks an attack before any trap or cover window opens. Returns true, or false + reason.
function Phases.validateAttack(matchState, attackerSlot, defenderSlot)
    if State.isOpeningTurn(matchState) then
        return false, "no attacks on the first turn of a half"
    end
    local attacker = Phases._getSlotForPlayer(matchState, matchState.activePlayer, attackerSlot)
    if not attacker then return false, "no attacker" end
    if attacker.exhausted then return false, "attacker exhausted" end
    if attacker.cannotActNextTurn then return false, "attacker cannot act" end
    if attacker.mode ~= "attack" then return false, "card is in defense mode" end
    if not Phases.canAttackNow(attacker) then return false, "summoned this turn — attacks next turn" end
    if defenderSlot.type == "keeper" then
        -- Direct shots need a gap in the defender line (occupied or empty keeper slot),
        -- unless a Through ball is on.
        local oppPitch = matchState.players[State.other(matchState.activePlayer)].pitch
        local hasGap = false
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not oppPitch.defenders[i] then hasGap = true; break end
        end
        if not hasGap and not Phases._throughBallFor(matchState, attackerSlot, defenderSlot) then
            return false, "keeper protected — clear a defender first"
        end
    end
    return true
end

function Phases.attack(matchState, attackerSlot, defenderSlot)
    local ok, err = Phases.validateAttack(matchState, attackerSlot, defenderSlot)
    if not ok then return nil, err end

    local attacker   = Phases._getSlotForPlayer(matchState, matchState.activePlayer, attackerSlot)
    local opponentId = State.other(matchState.activePlayer)
    local defender   = Phases._getSlotForPlayer(matchState, opponentId, defenderSlot)

    State.log(matchState, T.EventType.ATTACK_DECLARED,
        { attacker = attackerSlot, defender = defenderSlot })

    -- Pace: a card summoned this turn only gets this far with Pace.
    if attacker.summonedThisTurn and not C.MATCH.SUMMONED_CAN_ATTACK then
        Resolver.trigger(matchState, matchState.activePlayer, attacker, "PACE")
    end

    -- The keeper slot (occupied or empty) is always a shot, never card-vs-card combat.
    if defenderSlot.type == "keeper" then
        -- Through ball: shooting past a full defender line uses it up for this turn.
        local playmaker = Phases._throughBallFor(matchState, attackerSlot, defenderSlot)
        if playmaker then
            matchState.players[matchState.activePlayer].pitch.throughBallUsed = true
            Resolver.trigger(matchState, matchState.activePlayer, playmaker, "THROUGH_BALL")
        end
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId, playmaker ~= nil)
    end
    if defender then
        return Phases._doCombat(matchState, attacker, defender, attackerSlot, defenderSlot, opponentId)
    end
    -- Empty slot — check if covering is available
    return Phases._handleEmpty(matchState, attacker, attackerSlot, defenderSlot, opponentId)
end

-- An attack that reached the goal. The midfielder slot can't shoot (wasted); any other
-- card shoots at the keeper, or scores an open goal when the keeper slot is empty.
-- oneOnOne: a Through ball shot — the keeper's penalty DEF (base DEF; Fortress: full DEF).
function Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId, oneOnOne)
    if attackerSlot.type == "midfielder" then
        attacker.exhausted      = true
        attacker.usedAsAttacker = true  -- a wasted attack still counts (keeper +150 lost)
        Phases._spend(matchState, matchState.activePlayer, attacker, C.STAMINA.ACTION_COST)
        State.log(matchState, "attack_wasted", { reason = "midfielder_keeper" })
        return { outcome = "wasted", reason = "midfielder_keeper" }
    end
    local keeper = matchState.players[opponentId].pitch.keeper
    return Phases._goalAttempt(matchState, attacker, keeper, attackerSlot, opponentId, oneOnOne)
end

-- Called after the defending player decides to cover (or not).
-- covererSlot = { type, index } or nil (pass/let through)
function Phases.resolveCover(matchState, attackerSlot, originalEmptySlot, covererSlot)
    local activeId   = matchState.activePlayer
    local opponentId = activeId == "player" and "opponent" or "player"
    local attacker   = Phases._getSlotForPlayer(matchState, activeId, attackerSlot)

    if not attacker then return nil, "no attacker" end

    if covererSlot then
        -- Mark cover as used (once per turn per side — Off the line included)
        matchState.coverUsed[opponentId] = true
        local coverer = Phases._getSlotForPlayer(matchState, opponentId, covererSlot)
        if not coverer then return nil, "no coverer" end

        -- Coverers are attack-mode cards, except an Intercept defender or an Off the line
        -- keeper in defense mode: it gets revealed (face-up) and stays in defense mode.
        if coverer.mode == "defense" then coverer.revealed = true end

        -- A covering card cannot act next turn — not a Sweeper or an Off the line keeper
        if Resolver.coverLocks(coverer) then coverer.cannotActNextTurn = true end

        State.log(matchState, T.EventType.COVER,
            { coverer = covererSlot, emptySlot = originalEmptySlot })

        local keyword = Resolver.coverKeyword(coverer, covererSlot.type, originalEmptySlot.type)
        local result  = Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot,
                                         opponentId, true)
        if keyword then Resolver.trigger(matchState, opponentId, coverer, keyword, nil, result) end
        -- Stamina: covering costs the coverer C.STAMINA.ACTION_COST, won or lost (a coverer
        -- destroyed on a tie has left the pitch).
        if not result.defenderDestroyed then
            Phases._spend(matchState, opponentId, coverer, C.STAMINA.ACTION_COST)
        end
        return result
    else
        -- Let through: advance to next occupied line
        return Phases._advanceThrough(matchState, attacker, attackerSlot, originalEmptySlot, opponentId)
    end
end

-- ─── Internal helpers ─────────────────────────────────────────────────────────

function Phases._handleEmpty(matchState, attacker, attackerSlot, emptySlot, opponentId)
    -- Defenders attacking an empty striker slot: no covering, no advance — just wasted
    if emptySlot.type == "striker" then
        attacker.exhausted = true
        Phases._spend(matchState, matchState.activePlayer, attacker, C.STAMINA.ACTION_COST)
        State.log(matchState, "attack_wasted", { reason = "empty_striker_slot" })
        return { outcome = "wasted", reason = "empty_striker_slot" }
    end

    -- Midfielder cannot attack an empty midfielder slot
    if attackerSlot.type == "midfielder" and emptySlot.type == "midfielder" then
        attacker.exhausted      = true
        attacker.usedAsAttacker = true  -- a wasted attack still counts (keeper +150 lost)
        Phases._spend(matchState, matchState.activePlayer, attacker, C.STAMINA.ACTION_COST)
        State.log(matchState, "attack_wasted", { reason = "midfielder_empty_midfielder" })
        return { outcome = "wasted", reason = "midfielder_empty_midfielder" }
    end

    local oppPitch  = matchState.players[opponentId].pitch
    local coverUsed = matchState.coverUsed[opponentId]
    local coverers  = Phases._eligibleCoverers(oppPitch, emptySlot)
    local canCover  = not coverUsed and #coverers > 0

    -- Beat the man: its attacks into empty slots can't be covered. Checked before the Last
    -- Defender Foul bypass so that bypass is not used up.
    if Resolver.uncoverable(attacker) then
        local r = Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
        if canCover then
            Resolver.trigger(matchState, matchState.activePlayer, attacker, "BEAT_THE_MAN", nil, r)
        end
        return r
    end

    -- LAST_DEFENDER_FOUL bypass: skip cover window for this striker advance
    if matchState.bypassCoverNextStrikerAttack and attackerSlot.type == "striker" then
        matchState.bypassCoverNextStrikerAttack = nil
        return Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
    end

    if canCover then
        return {
            outcome          = "cover_needed",
            attackerSlot     = attackerSlot,
            emptySlot        = emptySlot,
            eligibleCoverers = coverers,
        }
    end

    return Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
end

-- Advance through empty lines until hitting an occupied card or the goal.
function Phases._advanceThrough(matchState, attacker, attackerSlot, fromSlot, opponentId)
    local oppPitch = matchState.players[opponentId].pitch
    local nextSlot = Phases._nextOccupiedLine(oppPitch, fromSlot)

    -- Nothing left before the goal (only the keeper, or an empty keeper slot): shot.
    if not nextSlot or nextSlot.type == "keeper" then
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    end

    local target = Phases._getSlot(oppPitch, nextSlot)
    return Phases._doCombat(matchState, attacker, target, attackerSlot, nextSlot, opponentId)
end

-- Returns { type, index } of the next occupied line after fromSlot, or nil.
-- Advance order toward goal: midfielder → defender → keeper
function Phases._nextOccupiedLine(pitch, fromSlot)
    local order = { "midfielder", "defender", "keeper" }
    local fromLine = fromSlot.type

    local startIdx = 1
    for i, line in ipairs(order) do
        if line == fromLine then startIdx = i + 1; break end
    end

    for i = startIdx, #order do
        local line = order[i]
        if line == "keeper" then
            if pitch.keeper then return { type = "keeper", index = 0 } end
        elseif line == "midfielder" then
            if pitch.midfielder then return { type = "midfielder", index = 0 } end
        elseif line == "defender" then
            for j = 1, C.PITCH.MAX_DEFENDERS do
                if pitch.defenders[j] then return { type = "defender", index = j } end
            end
        end
    end
    return nil
end

-- Returns eligible covering cards for an empty slot: { type, index, card } in slot order
-- (midfielder, defenders, keeper). Every coverer must be ready (not exhausted, not locked).
--   Empty defender slot: the midfielder; an Intercept or Sweeper defender; an Off the line keeper.
--   Empty midfielder slot: any defender.
-- Field coverers must be in attack mode, except an Intercept defender covering an empty
-- defender slot (Resolver.coversInDefense); an Off the line keeper covers in either mode.
function Phases._eligibleCoverers(pitch, emptySlot)
    local coverers = {}
    local et = emptySlot.type
    if et ~= "defender" and et ~= "midfielder" then return coverers end
    local function ready(card)
        return card and not card.exhausted and not card.cannotActNextTurn
    end
    local function add(card, slotType, slotIndex)
        table.insert(coverers, { type = slotType, index = slotIndex, card = card })
    end

    local mid = pitch.midfielder
    if ready(mid) and mid.mode == "attack"
       and (et == "defender" or Resolver.canCoverSlot(mid, "midfielder", et)) then
        add(mid, "midfielder", 0)
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = pitch.defenders[i]
        if ready(d) and (d.mode == "attack" or Resolver.coversInDefense(d, "defender", et))
           and (et == "midfielder" or Resolver.canCoverSlot(d, "defender", et)) then
            add(d, "defender", i)
        end
    end
    local k = pitch.keeper
    if ready(k) and Resolver.canCoverSlot(k, "keeper", et) then add(k, "keeper", 0) end
    return coverers
end

-- Full combat resolution between attacker and defender. covering: the defender covers an
-- empty slot (Counter-press; a lost cover is a last-ditch tackle, outcome "tackled").
function Phases._doCombat(matchState, attacker, defender, attackerSlot, defenderSlot, opponentId, covering)
    attacker.usedAsAttacker = true

    local activeId        = matchState.activePlayer
    local atkPitch        = matchState.players[activeId].pitch
    local defPitch        = matchState.players[opponentId].pitch
    local defenderFaceDown = defender.mode == "defense"

    local result = Combat.resolve(
        attacker, defender,
        attackerSlot.type, defenderSlot.type,
        atkPitch, defPitch, { covering = covering }
    )
    -- Stat abilities that changed this fight (Link-up, Last man, Counter-press, Engine, Overlap)
    Resolver.logParts(matchState, activeId, result.atkParts, result)
    Resolver.logParts(matchState, opponentId, result.defParts, result)

    -- A face-down defender is revealed but stays in defense mode (no battle damage,
    -- defense bonuses kept). Attackers are always in attack mode.
    if defender.mode == "defense" then defender.revealed = true end

    if result.outcome == "defender_destroyed" and covering then
        -- Last-ditch tackle: a coverer that loses is only exhausted (its cover lock, if any,
        -- was set by Phases.resolveCover). No LP damage, and the attack stops here.
        attacker.exhausted = true
        defender.exhausted = true
        result.outcome           = "tackled"
        result.defenderDestroyed = false
        result.damage            = 0
        State.log(matchState, T.EventType.COVER,
            { coverer = defenderSlot, outcome = "tackled", margin = result.margin })

    elseif result.outcome == "defender_destroyed" then
        attacker.exhausted = true
        Phases._destroyCard(matchState, opponentId, defenderSlot.type, defenderSlot.index or 0)
        State.log(matchState, T.EventType.DEFENDER_DESTROY, { slot = defenderSlot })
        -- Battle damage: defender was in attack mode, so its owner takes LP = ATK difference
        if not defenderFaceDown then
            local dmg = result.margin
            State.dealDamage(matchState, activeId, dmg)
            result.damage = dmg
            State.log(matchState, T.EventType.LP_DAMAGE,
                { dealer = activeId, damage = dmg,
                  remainingLP = matchState.players[opponentId].lp,
                  source = "battle_damage" })
        end

    elseif result.outcome == "tie" then
        -- Immovable: that card survives a tie; only the other one is destroyed.
        if Resolver.survivesTie(attacker) then
            attacker.exhausted = true
            result.attackerDestroyed = false
            Resolver.trigger(matchState, activeId, attacker, "IMMOVABLE", nil, result)
        else
            Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        end
        if Resolver.survivesTie(defender) then
            result.defenderDestroyed = false
            Resolver.trigger(matchState, opponentId, defender, "IMMOVABLE", nil, result)
        else
            Phases._destroyCard(matchState, opponentId, defenderSlot.type, defenderSlot.index or 0)
            State.log(matchState, T.EventType.DEFENDER_DESTROY, { slot = defenderSlot })
        end

    else  -- attacker lost: always destroyed + LP damage (face-down or face-up)
        Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        result.attackerDestroyed = true
        local penalty = -result.margin  -- margin is negative, so penalty > 0
        State.dealDamage(matchState, opponentId, penalty)
        result.damage = penalty
        State.log(matchState, T.EventType.LP_DAMAGE,
            { dealer = opponentId, damage = penalty,
              remainingLP = matchState.players[activeId].lp,
              source = defenderFaceDown and "facedown_penalty" or "battle_damage" })
    end

    -- Stamina: the attack costs its attacker C.STAMINA.ACTION_COST once it resolves (a
    -- destroyed card has left the pitch); the coverer's cost is paid in Phases.resolveCover.
    -- Counter-press costs its card C.STAMINA.ABILITY_COST more when it fired.
    if not result.attackerDestroyed then
        Phases._spend(matchState, activeId, attacker, C.STAMINA.ACTION_COST)
    end
    if not result.defenderDestroyed and Resolver.firedIn(result.defParts, "COUNTER_PRESS") then
        Phases._spend(matchState, opponentId, defender, C.STAMINA.ABILITY_COST)
    end

    -- Hard tackle, Build-up
    Resolver.onFightResolved(matchState, {
        attackerId = activeId, defenderId = opponentId,
        attacker = attacker, defender = defender, result = result,
    })
    return result
end

-- Shot at the goal: every attack that reaches the keeper ends here (the keeper is never
-- destroyed). keeper == nil → open goal for the shooter's full ATK.
-- penaltyMode = true → keeper uses base DEF only (no active defender bonuses).
function Phases._goalAttempt(matchState, striker, keeper, attackerSlot, opponentId, penaltyMode)
    local activeId = matchState.activePlayer
    local oppPitch = matchState.players[opponentId].pitch
    local atkPitch = matchState.players[activeId].pitch
    local result   = Combat.resolveShot(striker, keeper, oppPitch, atkPitch, penaltyMode,
                                        attackerSlot and attackerSlot.type)
    result.attackerSlot = attackerSlot
    -- Stat abilities that changed this shot (shooter's and keeper's side)
    Resolver.logParts(matchState, activeId, result.atkParts, result)
    Resolver.logParts(matchState, opponentId, result.defParts, result)

    -- A face-down keeper is revealed (it stays in defense mode)
    if keeper and keeper.mode == "defense" then keeper.revealed = true end

    striker.usedAsAttacker = true
    striker.exhausted      = true
    Phases._spend(matchState, activeId, striker, C.STAMINA.ACTION_COST)   -- stamina: the shot

    if result.outcome == "damage" then
        if keeper then keeper.exhausted = true end
        State.dealDamage(matchState, activeId, result.damage)
        State.countGoal(matchState, activeId)
        State.log(matchState, T.EventType.LP_DAMAGE,
            { dealer = activeId, damage = result.damage,
              remainingLP = matchState.players[opponentId].lp,
              source = result.openGoal and "open_goal" or nil })

    elseif result.outcome == "tie" then
        keeper.exhausted  = true
        State.log(matchState, T.EventType.SHOT, { outcome = "tie", margin = 0 })

    else  -- save
        keeper.saves = (keeper.saves or 0) + 1   -- Safe hands
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end

    -- Clinical, Punch clear
    Resolver.onShotResolved(matchState, activeId, striker, keeper, result)
    return result
end

-- ─── END TURN ────────────────────────────────────────────────────────────────

function Phases.endTurn(matchState)
    local activeId = matchState.activePlayer

    -- Only the active player's cards recover. A card locked this turn (Hard tackle, Punch
    -- clear: lockedNextTurn) can't act on its owner's next turn. Numeric loops: a slot may be
    -- empty in front of an occupied one.
    local function recoverPitch(pitch)
        local function recoverCard(c)
            if c then
                c.exhausted         = false
                c.cannotActNextTurn = c.lockedNextTurn == true
                c.lockedNextTurn    = nil
                c.summonedThisTurn  = false
                c.modeChanged       = false
            end
        end
        recoverCard(pitch.keeper)
        recoverCard(pitch.midfielder)
        for i = 1, C.PITCH.MAX_DEFENDERS do recoverCard(pitch.defenders[i]) end
        for i = 1, C.PITCH.MAX_STRIKERS  do recoverCard(pitch.strikers[i])  end
    end

    recoverPitch(matchState.players[activeId].pitch)
    -- Stamina: every field card on the active player's pitch spends C.STAMINA.TURN_COST.
    for _, e in ipairs(Resolver.fieldCards(matchState.players[activeId].pitch)) do
        Phases._spend(matchState, activeId, e.card, C.STAMINA.TURN_COST)
    end
    matchState.players[activeId].pitch.throughBallUsed = nil   -- Through ball: once per turn

    State.log(matchState, T.EventType.TURN_END, { turn = matchState.turn })

    matchState.coverUsed[activeId]         = false
    matchState.strategyPlayedThisTurn      = false
    matchState.bonusSummons                = 0     -- Metronome: this turn only
    -- Press: the other side's pressed cards were exhausted for this turn only.
    Phases._clearPressed(matchState.players[State.other(activeId)].pitch)
    -- Consume the summon limit that was set by TIME_WASTING on the previous opponent turn
    matchState.players[activeId].nextTurnSummonLimit = nil

    -- Check if half ended
    local halfWinner, reason = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner, reason)
        return
    end

    -- Switch active player. A round ends when play returns to the half's starter.
    matchState.activePlayer = State.other(activeId)
    if matchState.activePlayer == (matchState.halfStarter or "player") then
        matchState.turn = matchState.turn + 1
        if matchState.half == "extra" then
            matchState.extraTurnsLeft = matchState.extraTurnsLeft - 1
        end
    end

    -- Keeper bonus timing: the new active player's cards that attacked count toward
    -- their keeper's effective DEF again from now on.
    Phases._clearAttackerFlags(matchState.players[matchState.activePlayer].pitch)

    matchState.phase       = "draw"
    matchState.summonCount = 0

    -- Check half end again after the round count moved on (half limit, Extra Time countdown)
    halfWinner, reason = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner, reason)
    end
end

-- Clears the "attacked" flag on every card of a pitch (start of its owner's turn).
-- Numeric loops: a slot may be empty in front of an occupied one.
function Phases._clearAttackerFlags(pitch)
    local function clear(c) if c then c.usedAsAttacker = false end end
    clear(pitch.keeper)
    clear(pitch.midfielder)
    for i = 1, C.PITCH.MAX_DEFENDERS do clear(pitch.defenders[i]) end
    for i = 1, C.PITCH.MAX_STRIKERS  do clear(pitch.strikers[i])  end
end

-- Press: a pressed card was exhausted for the presser's turn only (it can't cover then);
-- clear it at the end of that turn so it acts normally on its own turn.
function Phases._clearPressed(pitch)
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders[i]
        if c and c.pressed then
            c.pressed   = nil
            c.exhausted = false
        end
    end
end

-- ─── Slot helpers ─────────────────────────────────────────────────────────────

function Phases._getSlot(pitch, slot)
    if slot.type == "keeper"     then return pitch.keeper end
    if slot.type == "defender"   then return pitch.defenders[slot.index] end
    if slot.type == "midfielder" then return pitch.midfielder end
    if slot.type == "striker"    then return pitch.strikers[slot.index] end
    return nil
end

function Phases._setSlot(pitch, slot, card)
    if slot.type == "keeper"     then pitch.keeper = card end
    if slot.type == "defender"   then pitch.defenders[slot.index] = card end
    if slot.type == "midfielder" then pitch.midfielder = card end
    if slot.type == "striker"    then pitch.strikers[slot.index] = card end
end

function Phases._getSlotForPlayer(matchState, playerId, slot)
    return Phases._getSlot(matchState.players[playerId].pitch, slot)
end

-- Stamina (spec B1): ownerId's card spends n (engine/stamina.lua). Logs `card_tired`
-- { player, card, name, hidden } when that makes it Tired.
function Phases._spend(matchState, ownerId, card, n)
    if Stamina.spend(card, n) then
        State.log(matchState, "card_tired", { player = ownerId, card = card.definition.id,
            name = card.definition.name, hidden = Resolver.hidden(card) })
    end
end

-- Returns (pitchedCard, slotTable) for the highest-ATK available striker, or nil.
function Phases._bestStriker(pitch)
    local best, bestSlot, bestAtk = nil, nil, -1
    for i = 1, C.PITCH.MAX_STRIKERS do
        local c = pitch.strikers[i]
        if Phases.canAttackNow(c) then
            local atk = Combat.attackStat(c, "striker", pitch)
            if atk > bestAtk then bestAtk = atk; best = c; bestSlot = { type="striker", index=i } end
        end
    end
    return best, bestSlot
end

function Phases._destroyCard(matchState, playerId, slotType, slotIndex)
    local player = matchState.players[playerId]
    local pitch  = player.pitch
    local card

    if slotType == "keeper" then
        card = pitch.keeper; pitch.keeper = nil
    elseif slotType == "defender" then
        card = pitch.defenders[slotIndex]; pitch.defenders[slotIndex] = nil
    elseif slotType == "midfielder" then
        card = pitch.midfielder; pitch.midfielder = nil
    elseif slotType == "striker" then
        card = pitch.strikers[slotIndex]; pitch.strikers[slotIndex] = nil
    end

    if card then
        table.insert(player.graveyard, card.definition)
        State.countCardLost(matchState, playerId)
    end
end

return Phases
