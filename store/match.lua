local State  = require("engine.state")
local Phases = require("engine.phases")
local Combat = require("engine.combat")
local Resolver = require("engine.cards.resolver")
local C      = require("engine.constants")
local AI     = require("ai.opponent")

local Store = {}
Store.__index = Store

function Store.new()
    local s = setmetatable({}, Store)
    s.match                = nil
    s.onUpdate             = nil
    s.combatQueue          = {}
    s.trapActivationQueue  = {}
    s.coverWindow          = nil
    s.trapWindow           = nil   -- { type, attackerSlot, defenderSlot, traps, attackerSnap, defenderSnap }
    return s
end

function Store:startMatch(playerDeck, opponentDeck)
    self.match                = State.newMatch(playerDeck, opponentDeck)
    self.combatQueue          = {}
    self.trapActivationQueue  = {}
    self.coverWindow          = nil
    self.trapWindow           = nil
    self:_notify()
end

function Store:popTrapActivation()
    if #self.trapActivationQueue == 0 then return nil end
    return table.remove(self.trapActivationQueue, 1)
end

function Store:_pushTrapActivation(activatorId, trapDef, contextText)
    table.insert(self.trapActivationQueue, {
        activator   = activatorId,
        trapDef     = trapDef,
        contextText = contextText or "",
    })
end

function Store:drawPhase()
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("draw") then return end
    Phases.draw(self.match)
    self.match.phase = "summon"
    self:_notify()
end

function Store:summonCard(cardId, slotType, slotIndex, mode)
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack")
    if ok then self:_notify() end
    return ok, err
end

-- Perform a free summon (Substitution replacement) — bypasses summon count.
function Store:freeSummon(cardId, slotType, slotIndex, mode)
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack", true)
    if ok then self:_notify() end
    return ok, err
end

function Store:changeMode(slotType, slotIndex)
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.changeMode(self.match, slotType, slotIndex)
    if ok then self:_notify() end
    return ok, err
end

function Store:startAttackPhase()
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("summon") then return end
    self.match.phase = "attack"
    self:_notify()
end

-- Face-up for Last Defender Foul: attack mode, or revealed.
local function faceUp(card)
    return card ~= nil and (card.mode == "attack" or card.revealed == true)
end

-- True when defenderSlot holds the defending side's only face-up defender (checked on
-- the board before the attack resolves).
function Store:_isLastFaceUpDefender(defenderId, defenderSlot)
    if defenderSlot.type ~= "defender" then return false end
    local pitch = self.match.players[defenderId].pitch
    if not faceUp(pitch.defenders[defenderSlot.index]) then return false end
    local n = 0
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if faceUp(pitch.defenders[i]) then n = n + 1 end
    end
    return n == 1
end

function Store:declareAttack(attackerSlot, defenderSlot)
    if self:_inBreak() then return nil, "half-time" end
    if not self:_assertPhase("attack") then return nil, "wrong phase" end
    if self.match.winner then return nil, "match over" end

    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = State.other(activeId)

    -- Illegal attacks (first turn of a half, keeper protected, exhausted …) are refused
    -- before any trap window can open.
    local okAtk, whyNot = Phases.validateAttack(match, attackerSlot, defenderSlot)
    if not okAtk then return nil, whyNot end

    -- Snapshot target: if the declared slot is empty and no cover is possible, the attacker
    -- advances to the next occupied line (or the goal), so snap that instead. While a cover
    -- is still possible, snap the attacker's fight ATK (the cover window shows it).
    local snapDefSlot, snapOpts = defenderSlot, nil
    do
        local oppPitch = match.players[opponentId].pitch
        local slotCard = Phases._getSlot(oppPitch, defenderSlot)
        if not slotCard and defenderSlot.type ~= "striker" then
            local coverUsed = match.coverUsed[opponentId]
            local coverers  = Phases._eligibleCoverers(oppPitch, defenderSlot)
            local attackerCard = Phases._getSlotForPlayer(match, activeId, attackerSlot)
            if coverUsed or #coverers == 0 or Resolver.uncoverable(attackerCard) then
                local nextSlot = Phases._nextOccupiedLine(oppPitch, defenderSlot)
                if nextSlot then snapDefSlot = nextSlot end
            else
                snapOpts = { fight = true }
            end
        end
    end

    -- Through ball: a one-on-one shot faces the keeper's penalty DEF.
    if Phases._throughBallFor(match, attackerSlot, defenderSlot) then snapOpts = { penalty = true } end

    local snap = self:_snapshotAttack(attackerSlot, snapDefSlot, snapOpts)

    -- Last Defender Foul is judged on the board before the attack.
    local lastDefender = activeId == "player" and self:_isLastFaceUpDefender(opponentId, defenderSlot)

    -- Aerial: Offside can't be activated against this card's attacks.
    local attackerCard = Phases._getSlotForPlayer(match, activeId, attackerSlot)
    local aerial = Resolver.immuneToOffside(attackerCard)
    if aerial and attackerSlot.type == "striker"
       and self:_findTrap(match.players[opponentId].pitch, "OFFSIDE") then
        Resolver.trigger(match, activeId, attackerCard, "AERIAL")
    end

    -- ── Pre-attack trap check (OFFSIDE) ───────────────────────────────────────
    -- When AI attacks with striker: show player's OFFSIDE/MC window
    if activeId == "opponent" and attackerSlot.type == "striker" and not aerial then
        local offsideTrap, offsideIdx = self:_findTrap(match.players.player.pitch, "OFFSIDE")
        if offsideTrap then
            local traps = { { card = offsideTrap, slotIndex = offsideIdx } }
            local mcTrap, mcIdx = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if mcTrap then table.insert(traps, { card = mcTrap, slotIndex = mcIdx }) end
            self.trapWindow = {
                type         = "pre_attack",
                attackerSlot = attackerSlot,
                defenderSlot = defenderSlot,
                traps        = traps,
                attackerSnap = snap.attacker,
                defenderSnap = snap.defender,
            }
            self:_notify()
            return { outcome = "trap_window" }, nil
        end
    end

    -- When player attacks with striker: AI OFFSIDE auto-fires (or player can counter with MC)
    if activeId == "player" and attackerSlot.type == "striker" and not aerial then
        local aiOffside, aiOffsideIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
        if aiOffside and AI.wantsOffside(match, "opponent", attackerSlot, defenderSlot) then
            local mcTrap, mcIdx = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if mcTrap then
                -- Player can counter AI's OFFSIDE with MC
                self.trapWindow = {
                    type         = "counter_offside",
                    attackerSlot = attackerSlot,
                    defenderSlot = defenderSlot,
                    aiTrapCard   = aiOffside,
                    aiTrapIdx    = aiOffsideIdx,
                    traps        = { { card = mcTrap, slotIndex = mcIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_notify()
                return { outcome = "trap_window" }, nil
            else
                -- Auto-fire AI OFFSIDE
                local trapDef = Phases.activateTrap(match, "opponent", aiOffsideIdx)
                Phases.cancelAttack(match, "player", attackerSlot, defenderSlot)
                local atkName = snap.attacker and snap.attacker.name or "Striker"
                self:_pushTrapActivation("opponent", trapDef or aiOffside.definition,
                    "Your " .. atkName .. " was caught offside!")
                self:_notify()
                return { outcome = "offside_cancelled" }, nil
            end
        end
    end

    local result, err = Phases.attack(match, attackerSlot, defenderSlot)
    if not result then return nil, err end

    if result.outcome == "cover_needed" then
        self.coverWindow = {
            attackerSlot     = attackerSlot,
            emptySlot        = defenderSlot,
            eligibleCoverers = result.eligibleCoverers,
            attackerSnap     = snap.attacker,
        }
        self:_notify()
        return result, nil
    end

    self:_pushCombat(snap, result)
    if self:_afterCombatTraps(snap, result, attackerSlot) then
        self:_notify()
        return result, nil
    end

    if self:_lastDefenderFoulWindow(lastDefender, snap, result, defenderSlot) then
        self:_checkHalf()
        self:_notify()
        return result, nil
    end

    self:_checkHalf()
    self:_notify()
    return result, nil
end

-- LAST_DEFENDER_FOUL: the player's attack on the opponent's last face-up defender
-- (lastDefender, judged before the attack) was beaten (not a tie), so that defender is
-- still standing. Opens the player's window; returns true when it did.
function Store:_lastDefenderFoulWindow(lastDefender, snap, result, defenderSlot)
    if not (lastDefender and result and result.outcome == "attacker_exhausted") then return false end
    local ldfTrap, ldfIdx = self:_findTrap(self.match.players.player.pitch, "LAST_DEFENDER_FOUL")
    if not ldfTrap then return false end
    self.trapWindow = {
        type               = "post_last_defender",
        defenderSlot       = defenderSlot,
        defenderStillAlive = true,
        traps              = { { card = ldfTrap, slotIndex = ldfIdx } },
        attackerSnap       = snap.attacker,
        defenderSnap       = snap.defender,
    }
    return true
end

-- Red Card / VAR after any resolved attack or shot: declared attack, cover or
-- let-through, an attack resumed after a trap window, Direct Free Kick, Penalty.
-- Returns true when a trap window for the human is now open; the caller then returns
-- without _checkHalf (post_destroy / counter_red_card windows run it here, as before;
-- post_damage waits for the VAR decision).
function Store:_afterCombatTraps(snap, result, attackerSlot)
    local match    = self.match
    local activeId = match.activePlayer
    local outcome  = result and result.outcome

    if activeId == "opponent" then
        -- AI destroyed one of the player's cards (not a tie): player's RED_CARD window
        if outcome == "defender_destroyed" then
            local rcTrap, rcIdx = self:_findTrap(match.players.player.pitch, "RED_CARD")
            if rcTrap then
                self.trapWindow = {
                    type         = "post_destroy",
                    attackerSlot = attackerSlot,
                    traps        = { { card = rcTrap, slotIndex = rcIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_checkHalf()
                return true
            end
        -- AI scored: player's VAR window (_checkHalf waits for the decision)
        elseif outcome == "damage" then
            local varTrap, varIdx = self:_findTrap(match.players.player.pitch, "VAR")
            if varTrap then
                self.trapWindow = {
                    type         = "post_damage",
                    attackerSlot = attackerSlot,
                    traps        = { { card = varTrap, slotIndex = varIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                    damage       = result.damage,
                }
                return true
            end
        end
        return false
    end

    -- Player won a fight (not a tie): AI RED_CARD; the player may counter with VAR or MC
    if outcome == "defender_destroyed" then
        local aiRedCard, aiRedIdx = self:_findTrap(match.players.opponent.pitch, "RED_CARD")
        if aiRedCard and AI.wantsRedCard(snap.attacker and snap.attacker.atk or 0) then
            local counters = {}
            local varTrap, varIdx = self:_findTrap(match.players.player.pitch, "VAR")
            local mcTrap,  mcIdx  = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if varTrap then table.insert(counters, { card = varTrap, slotIndex = varIdx }) end
            if mcTrap  then table.insert(counters, { card = mcTrap,  slotIndex = mcIdx  }) end
            if #counters > 0 then
                self.trapWindow = {
                    type         = "counter_red_card",
                    attackerSlot = attackerSlot,
                    aiTrapCard   = aiRedCard,
                    aiTrapIdx    = aiRedIdx,
                    traps        = counters,
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_checkHalf()
                return true
            end
            -- Auto-fire AI RED_CARD
            local trapDef = Phases.activateTrap(match, "opponent", aiRedIdx)
            Phases._destroyCard(match, "player", attackerSlot.type, attackerSlot.index or 0)
            local atkName = snap.attacker and snap.attacker.name or "Attacker"
            self:_pushTrapActivation("opponent", trapDef or aiRedCard.definition,
                "Your " .. atkName .. " was sent off!")
        end
    -- Player scored: AI VAR auto-activates (LP back, the shooter returns to the player's hand)
    elseif outcome == "damage" then
        local varTrap, varIdx = self:_findTrap(match.players.opponent.pitch, "VAR")
        if varTrap then
            Phases.activateTrap(match, "opponent", varIdx)
            State.refundDamage(match, "player", result.damage or 0)
            local pitch   = match.players.player.pitch
            local shooter = Phases._getSlot(pitch, attackerSlot)
            if shooter then
                table.insert(match.players.player.hand, shooter.definition)
                Phases._setSlot(pitch, attackerSlot, nil)
            end
            local atkName = snap.attacker and snap.attacker.name or "Striker"
            self:_pushTrapActivation("opponent", varTrap.definition,
                "VAR overturns the goal! " .. atkName .. " returned to your hand.")
        end
    end
    return false
end

-- Runs an attack that was waiting on a pre-attack trap window (Offside passed, or
-- overruled by Manager's Challenge). Returns true when a cover or trap window opened.
function Store:_resumeAttack(tw)
    local snap   = { attacker = tw.attackerSnap, defender = tw.defenderSnap }
    local activeId     = self.match.activePlayer
    local lastDefender = activeId == "player"
                         and self:_isLastFaceUpDefender(State.other(activeId), tw.defenderSlot)
    local result = Phases.attack(self.match, tw.attackerSlot, tw.defenderSlot)
    if not result then return false end
    if result.outcome == "cover_needed" then
        self.coverWindow = {
            attackerSlot     = tw.attackerSlot,
            emptySlot        = tw.defenderSlot,
            eligibleCoverers = result.eligibleCoverers,
            attackerSnap     = tw.attackerSnap,
        }
        return true
    end
    self:_pushCombat(snap, result)
    if self:_afterCombatTraps(snap, result, tw.attackerSlot) then return true end
    if self:_lastDefenderFoulWindow(lastDefender, snap, result, tw.defenderSlot) then
        self:_checkHalf()
        return true
    end
    return false
end

-- Called after the player decides to activate or pass a trap window.
-- trapSlotIndex = 1-based index within trapWindow.traps to activate, or nil to pass.
function Store:resolveTrap(trapSlotIndex)
    if self:_inBreak() then return nil, "half-time" end
    if not self.trapWindow then return end
    local tw = self.trapWindow
    self.trapWindow = nil

    local match      = self.match
    -- opponentId = the AI when it is the attacking player (pre_attack / post_destroy)
    local opponentId = match.activePlayer

    -- ── Counter windows (player is active, AI trap was about to auto-fire) ────

    if tw.type == "counter_offside" then
        local open = false
        if trapSlotIndex then
            -- Player uses MC to negate AI's OFFSIDE
            local entry   = tw.traps[trapSlotIndex]
            local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
            if not trapDef then self:_notify(); return end
            -- Consume AI's OFFSIDE trap and pay 1000 LP
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            match.players.player.lp = match.players.player.lp - 1000
            -- Attack now proceeds normally
            open = self:_resumeAttack(tw)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("player", trapDef,
                "Manager's Challenge! " .. atkName .. " onside — attack proceeds. (-1000 LP)")
        else
            -- Player passes — AI's OFFSIDE fires
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            Phases.cancelAttack(match, "player", tw.attackerSlot, tw.defenderSlot)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("opponent", tw.aiTrapCard.definition,
                "Your " .. atkName .. " was caught offside!")
        end
        if not open then self:_checkHalf() end
        self:_notify()
        return
    end

    if tw.type == "counter_red_card" then
        if trapSlotIndex then
            -- Player uses VAR or MC to negate AI's RED_CARD
            local entry   = tw.traps[trapSlotIndex]
            local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
            if not trapDef then self:_notify(); return end
            if trapDef.ability == "MANAGERS_CHALLENGE" then
                -- MC: also discard AI's RED_CARD and pay 1000 LP
                Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
                match.players.player.lp = match.players.player.lp - 1000
            end
            -- Attacker survives (already exhausted after winning, stays on pitch)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            self:_pushTrapActivation("player", trapDef,
                "Red Card overturned! " .. atkName .. " stays on the pitch.")
        else
            -- Player passes — AI's RED_CARD fires
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            Phases._destroyCard(match, "player", tw.attackerSlot.type, tw.attackerSlot.index or 0)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            self:_pushTrapActivation("opponent", tw.aiTrapCard.definition,
                "Your " .. atkName .. " was sent off!")
        end
        self:_checkHalf()
        self:_notify()
        return
    end

    -- ── Standard player-activated trap windows (AI is active) ─────────────────

    if trapSlotIndex then
        local entry   = tw.traps[trapSlotIndex]
        local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
        if not trapDef then self:_notify(); return end

        local ability = trapDef.ability
        local ctxText = ""

        if tw.type == "pre_attack" and ability == "OFFSIDE" then
            Phases.cancelAttack(match, opponentId, tw.attackerSlot, tw.defenderSlot)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            ctxText = atkName .. " blocked — offside!"

        elseif tw.type == "pre_attack" and ability == "MANAGERS_CHALLENGE" then
            -- MC lets the attack through + pay 1000 LP
            match.players.player.lp = match.players.player.lp - 1000
            -- Find and discard AI's OFFSIDE that was about to fire
            local aiOff, aiOffIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
            if aiOff then Phases.activateTrap(match, "opponent", aiOffIdx) end
            local open = self:_resumeAttack(tw)
            self:_pushTrapActivation("player", trapDef, "Offside overruled by Manager's Challenge! (-1000 LP)")
            if not open then self:_checkHalf() end
            self:_notify()
            return

        elseif tw.type == "post_destroy" and ability == "RED_CARD" then
            Phases._destroyCard(match, opponentId, tw.attackerSlot.type, tw.attackerSlot.index or 0)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            ctxText = atkName .. " sent off after winning combat"

        elseif tw.type == "post_damage" and ability == "VAR" then
            -- Undo LP damage, return the AI's shooter to its hand
            State.refundDamage(match, "opponent", tw.damage or 0)
            local oppPitch = match.players.opponent.pitch
            local shooter  = Phases._getSlot(oppPitch, tw.attackerSlot)
            if shooter then
                table.insert(match.players.opponent.hand, shooter.definition)
                Phases._setSlot(oppPitch, tw.attackerSlot, nil)
            end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            ctxText = "Goal overturned! " .. atkName .. " returned to opponent's hand."

        elseif tw.type == "post_last_defender" and ability == "LAST_DEFENDER_FOUL" then
            -- Destroy the last defender if it survived (attacker_exhausted case)
            if tw.defenderStillAlive then
                Phases._destroyCard(match, "opponent", tw.defenderSlot.type, tw.defenderSlot.index or 0)
            end
            -- Grant bypass covering for next striker attack this turn
            match.bypassCoverNextStrikerAttack = true
            local defName = tw.defenderSnap and tw.defenderSnap.name or "Defender"
            ctxText = defName .. " sent off! Last defender foul — next striker bypasses cover."
        end

        self:_pushTrapActivation("player", trapDef, ctxText)
    else
        -- Pass: a waiting attack goes ahead (and may open its own windows)
        if tw.type == "pre_attack" then
            local open = self:_resumeAttack(tw)
            if not open then self:_checkHalf() end
            self:_notify()
            return
        end
        -- post_destroy, post_damage, post_last_defender pass: no further action
    end

    self:_checkHalf()
    self:_notify()
end

-- Play a strategy card from hand.
function Store:playStrategy(cardId, opts)
    if self:_inBreak() then return nil, "half-time" end
    local match    = self.match
    local activeId = match.activePlayer

    -- Strategy shots are snapshotted before they resolve: the best striker and the keeper
    -- as they stand now (Penalty: the keeper's base DEF).
    local shotSnap
    for _, c in ipairs(match.players[activeId].hand) do
        if c.id == cardId and (c.ability == "DIRECT_FREE_KICK" or c.ability == "PENALTY") then
            local _, bestSlot = Phases._bestStriker(match.players[activeId].pitch)
            if bestSlot then
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 },
                                                { penalty = c.ability == "PENALTY" })
            end
            break
        end
    end

    local result, err = Phases.playStrategy(match, cardId, opts)
    if result then
        local o = result.outcome
        if shotSnap and (o == "damage" or o == "tie" or o == "save") then
            self:_pushCombat(shotSnap, result)
            if self:_afterCombatTraps(shotSnap, result, result.attackerSlot) then
                self:_notify()
                return result, err
            end
        end
        self:_checkHalf()
        self:_notify()
    end
    return result, err
end

-- Called after the player decides to cover or let through.
function Store:resolveCover(covererSlot)
    if self:_inBreak() then return nil, "half-time" end
    if not self.coverWindow then return end

    local attackerSlot = self.coverWindow.attackerSlot
    local emptySlot    = self.coverWindow.emptySlot
    local match        = self.match
    local opponentId   = State.other(match.activePlayer)

    -- When the player passes (no cover), the attacker advances to the next occupied line.
    -- Snap that card instead of the empty slot so the combat overlay shows the real defender.
    local defSlotForSnap = covererSlot
    if not covererSlot then
        local nextSlot = Phases._nextOccupiedLine(match.players[opponentId].pitch, emptySlot)
        defSlotForSnap = nextSlot or emptySlot
    end
    local snap = self:_snapshotAttack(attackerSlot, defSlotForSnap,
                                      covererSlot and { covering = true } or nil)
    self.coverWindow = nil

    local result, err = Phases.resolveCover(self.match, attackerSlot, emptySlot, covererSlot)

    if result and result.outcome ~= "wasted" and result.outcome ~= "cover_needed" then
        self:_pushCombat(snap, result)
        if self:_afterCombatTraps(snap, result, attackerSlot) then
            self:_notify()
            return result, err
        end
    end

    self:_checkHalf()
    self:_notify()
    return result, err
end

function Store:endTurn()
    if self:_inBreak() then return nil, "half-time" end
    self.coverWindow = nil
    self.trapWindow  = nil
    Phases.endTurn(self.match)
    -- endTurn is refused during a break, so a break now means this turn ended the half.
    if self.match.halfTimeBreak then self:_startBreak() end
    self:_notify()
end

-- ── Half-time break ────────────────────────────────────────────────────────────

-- Half-time swap for a seat (the human's, from the half-time screen). Returns the number
-- of cards swapped (0 + reason when refused; see State.mulligan).
function Store:mulligan(cardIds, playerId)
    local n, err = State.mulligan(self.match, playerId or "player", cardIds)
    if n > 0 then self:_notify() end
    return n, err
end

-- Ends the half-time break; play resumes with the new half's first turn.
function Store:kickOff()
    if not self:_inBreak() then return false end
    State.kickOff(self.match)
    self:_notify()
    return true
end

function Store:popCombat()
    if #self.combatQueue == 0 then return nil end
    return table.remove(self.combatQueue, 1)
end

-- ── Private helpers ────────────────────────────────────────────────────────────

function Store:_checkHalf()
    local hw, reason = State.checkHalfEnd(self.match)
    if hw and not self.match.winner then
        State.endHalf(self.match, hw, reason)
        -- A window from the old half must not resolve against the new half's board.
        self.trapWindow  = nil
        self.coverWindow = nil
        if self.match.halfTimeBreak then self:_startBreak() end
    end
end

-- A half-time break has just started: the AI seat ("opponent") makes its swap now; the
-- human's comes from the half-time screen (Store:mulligan), then Store:kickOff.
function Store:_startBreak()
    local m = self.match
    State.mulligan(m, "opponent", AI.mulliganChoice(m, "opponent"))
end

function Store:_inBreak()
    return self.match ~= nil and self.match.halfTimeBreak == true
end

function Store:_pushCombat(snap, result)
    if result and result.outcome and result.outcome ~= "wasted" then
        table.insert(self.combatQueue, {
            attacker     = snap.attacker,
            defender     = snap.defender,
            outcome      = result.outcome,
            margin       = result.margin or 0,
            damage       = result.damage or 0,
            activePlayer = self.match and self.match.activePlayer or "player",
            abilities    = result.abilities or {},   -- keywords that fired (overlay)
        })
    end
end

-- Returns (pitchedCard, trapSlotIndex) for the first trap in the zone matching ability, or nil.
function Store:_findTrap(pitch, ability)
    for i, trap in ipairs(pitch.traps) do
        if trap.definition.ability == ability then
            return trap, i
        end
    end
    return nil, nil
end

-- Combat snapshot for the overlay, taken before the attack resolves, with the numbers the
-- engine will use (Combat.attackStat / defendStat / keeperDef).
--   opts.covering: the defender slot holds a card covering an empty slot (a fight, also for
--                  an Off the line keeper).
--   opts.fight:    the declared slot is empty and a cover may still happen: the attacker's
--                  fight ATK (the cover window shows it).
--   opts.penalty:  a Penalty or a Through ball shot (the keeper's penalty DEF).
-- Otherwise a keeper target, or an empty non-striker slot (open goal), is a shot.
-- Each side: { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper,
--              atkTags, defTags } — tags { keyword, name, amount } from ability parts.
function Store:_snapshotAttack(attackerSlot, defenderSlot, opts)
    opts = opts or {}
    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = State.other(activeId)
    local atkPitch   = match.players[activeId].pitch
    local defPitch   = match.players[opponentId].pitch
    local atkCard    = attackerSlot and Phases._getSlot(atkPitch, attackerSlot) or nil
    local defCard    = defenderSlot and Phases._getSlot(defPitch, defenderSlot) or nil
    local isShot     = defenderSlot ~= nil and not opts.covering and not opts.fight
                       and (defenderSlot.type == "keeper"
                            or (defCard == nil and defenderSlot.type ~= "striker"))

    -- Ability tags for the overlay. A tag whose source is one of the AI's face-down,
    -- unrevealed cards is left out (hidden information); the totals still count it.
    local function tags(parts, ownerId)
        local out = {}
        for _, p in ipairs(parts or {}) do
            if not (ownerId == "opponent" and Resolver.hidden(p.pitched)) then
                out[#out + 1] = { keyword = p.keyword,
                                  name = Resolver.NAMES[p.keyword] or p.keyword,
                                  amount = p.amount }
            end
        end
        return out
    end

    local function base(card, isKeeper)
        local d = card.definition
        return {
            name = d.name, type = d.type, mode = card.mode,
            wasHidden = (card.mode == "defense" and not card.revealed),
            atk = Combat.getStat(card, "attack"), def = Combat.getStat(card, "defend"),
            atkBonus = 0, defBonus = 0, isKeeper = isKeeper, atkTags = {}, defTags = {},
        }
    end

    local attacker
    if atkCard then
        attacker = base(atkCard, false)
        local atk, parts = Combat.attackStat(atkCard, attackerSlot.type, atkPitch, defPitch,
                                             isShot and { keeper = defPitch.keeper } or nil)
        attacker.atkBonus = atk - attacker.atk
        attacker.atk      = atk
        attacker.atkTags  = tags(parts, activeId)
    end

    local defender
    if defCard then
        local isKeeper = defenderSlot.type == "keeper" and not opts.covering
        defender = base(defCard, isKeeper)
        local def, parts
        if isKeeper then
            def, parts = Combat.keeperDef(defCard, defPitch, opts.penalty)
        else
            def, parts = Combat.defendStat(defCard, defenderSlot.type, defPitch, opts.covering)
        end
        defender.defBonus = def - defender.def
        defender.def      = def
        defender.defTags  = tags(parts, opponentId)
    end

    return { attacker = attacker, defender = defender }
end

function Store:_assertPhase(expected)
    return self.match and self.match.phase == expected
end

function Store:_notify()
    if self.onUpdate then self.onUpdate(self.match) end
end

return Store
