local State  = require("engine.state")
local Phases = require("engine.phases")
local Combat = require("engine.combat")

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
    if not self:_assertPhase("draw") then return end
    Phases.draw(self.match)
    self.match.phase = "summon"
    self:_notify()
end

function Store:summonCard(cardId, slotType, slotIndex, mode)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack")
    if ok then self:_notify() end
    return ok, err
end

-- Perform a free summon (Substitution replacement) — bypasses summon count.
function Store:freeSummon(cardId, slotType, slotIndex, mode)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack", true)
    if ok then self:_notify() end
    return ok, err
end

function Store:changeMode(slotType, slotIndex)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.changeMode(self.match, slotType, slotIndex)
    if ok then self:_notify() end
    return ok, err
end

function Store:startAttackPhase()
    if not self:_assertPhase("summon") then return end
    self.match.phase = "attack"
    self:_notify()
end

function Store:declareAttack(attackerSlot, defenderSlot)
    if not self:_assertPhase("attack") then return nil, "wrong phase" end
    if self.match.winner then return nil, "match over" end

    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = activeId == "player" and "opponent" or "player"

    -- Illegal attacks (first turn of a half, keeper protected, exhausted …) are refused
    -- before any trap window can open.
    local okAtk, whyNot = Phases.validateAttack(match, attackerSlot, defenderSlot)
    if not okAtk then return nil, whyNot end

    -- Resolve real snap target: if the declared slot is empty and no cover is possible,
    -- the attacker will advance to the next occupied line — snap that card instead.
    local snapDefSlot = defenderSlot
    do
        local oppPitch = match.players[opponentId].pitch
        local slotCard = Phases._getSlot(oppPitch, defenderSlot)
        if not slotCard and defenderSlot.type ~= "striker" then
            local coverUsed = match.coverUsed[opponentId]
            local coverers  = Phases._eligibleCoverers(oppPitch, defenderSlot)
            if coverUsed or #coverers == 0 then
                local nextSlot = Phases._nextOccupiedLine(oppPitch, defenderSlot)
                if nextSlot then snapDefSlot = nextSlot end
            end
        end
    end

    local snap = self:_snapshotAttack(attackerSlot, snapDefSlot)

    -- Snapshot defender count BEFORE attack for LAST_DEFENDER_FOUL check
    local C = require("engine.constants")
    local opponentDefCount = 0
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if match.players[opponentId].pitch.defenders[i] then
            opponentDefCount = opponentDefCount + 1
        end
    end

    -- ── Pre-attack trap check (OFFSIDE) ───────────────────────────────────────
    -- When AI attacks with striker: show player's OFFSIDE/MC window
    if activeId == "opponent" and attackerSlot.type == "striker" then
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
    if activeId == "player" and attackerSlot.type == "striker" then
        local offsideTrap, offsideIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
        if offsideTrap then
            local mcTrap, mcIdx = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if mcTrap then
                -- Player can counter AI's OFFSIDE with MC
                self.trapWindow = {
                    type         = "counter_offside",
                    attackerSlot = attackerSlot,
                    defenderSlot = defenderSlot,
                    aiTrapCard   = offsideTrap,
                    aiTrapIdx    = offsideIdx,
                    traps        = { { card = mcTrap, slotIndex = mcIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_notify()
                return { outcome = "trap_window" }, nil
            else
                -- Auto-fire AI OFFSIDE
                local trapDef = Phases.activateTrap(match, "opponent", offsideIdx)
                local attCard = Phases._getSlotForPlayer(match, "player", attackerSlot)
                if attCard then attCard.exhausted = true end
                local atkName = snap.attacker and snap.attacker.name or "Striker"
                self:_pushTrapActivation("opponent", trapDef or offsideTrap.definition,
                    "Your " .. atkName .. " was caught offside!")
                self:_notify()
                return { outcome = "offside_cancelled" }, nil
            end
        end
    end

    local result, err = Phases.attack(match, attackerSlot, defenderSlot)

    if not result then
        return nil, err
    end

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

    -- ── Post-combat trap checks ───────────────────────────────────────────────

    -- When AI destroys player's card: RED_CARD window (player can punish the winning attacker)
    if activeId == "opponent" and
       (result.outcome == "defender_destroyed" or result.outcome == "tie") then
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
            self:_notify()
            return result, nil
        end
    end

    -- When AI scores LP damage: VAR window for player (defer _checkHalf until after decision)
    if activeId == "opponent" and result.outcome == "damage" then
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
            self:_notify()
            return result, nil
        end
    end

    -- When player wins combat: check AI RED_CARD; player can counter with VAR or MC
    if activeId == "player" and
       (result.outcome == "defender_destroyed" or result.outcome == "tie") then
        local rcTrap, rcIdx = self:_findTrap(match.players.opponent.pitch, "RED_CARD")
        if rcTrap then
            local counters = {}
            local varTrap, varIdx = self:_findTrap(match.players.player.pitch, "VAR")
            local mcTrap,  mcIdx  = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if varTrap then table.insert(counters, { card = varTrap, slotIndex = varIdx }) end
            if mcTrap  then table.insert(counters, { card = mcTrap,  slotIndex = mcIdx  }) end
            if #counters > 0 then
                self.trapWindow = {
                    type         = "counter_red_card",
                    attackerSlot = attackerSlot,
                    aiTrapCard   = rcTrap,
                    aiTrapIdx    = rcIdx,
                    traps        = counters,
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_checkHalf()
                self:_notify()
                return result, nil
            else
                -- Auto-fire AI RED_CARD
                local trapDef = Phases.activateTrap(match, "opponent", rcIdx)
                Phases._destroyCard(match, "player", attackerSlot.type, attackerSlot.index or 0)
                local atkName = snap.attacker and snap.attacker.name or "Attacker"
                self:_pushTrapActivation("opponent", trapDef or rcTrap.definition,
                    "Your " .. atkName .. " was sent off!")
            end
        end
    end

    -- When player scores LP damage: AI VAR auto-activates
    -- When player scores LP damage: AI VAR auto-activates (restores own LP, returns player's striker)
    if activeId == "player" and result.outcome == "damage" then
        local varTrap, varIdx = self:_findTrap(match.players.opponent.pitch, "VAR")
        if varTrap then
            Phases.activateTrap(match, "opponent", varIdx)
            match.players.opponent.lp = match.players.opponent.lp + (result.damage or 0)
            local pitch = match.players.player.pitch
            local striker = pitch.strikers[attackerSlot.index]
            if striker then
                table.insert(match.players.player.hand, striker.definition)
                pitch.strikers[attackerSlot.index] = nil
            end
            local atkName = snap.attacker and snap.attacker.name or "Striker"
            self:_pushTrapActivation("opponent", varTrap.definition,
                "VAR overturns the goal! " .. atkName .. " returned to your hand.")
        end
    end

    -- When player attacks opponent's LAST defender and doesn't win: LAST_DEFENDER_FOUL
    if activeId == "player" and defenderSlot.type == "defender" and
       opponentDefCount == 1 and
       result.outcome ~= "defender_destroyed" then
        local ldfTrap, ldfIdx = self:_findTrap(match.players.player.pitch, "LAST_DEFENDER_FOUL")
        if ldfTrap then
            self.trapWindow = {
                type               = "post_last_defender",
                defenderSlot       = defenderSlot,
                defenderStillAlive = (result.outcome == "attacker_exhausted"),
                traps              = { { card = ldfTrap, slotIndex = ldfIdx } },
                attackerSnap       = snap.attacker,
                defenderSnap       = snap.defender,
            }
            self:_checkHalf()
            self:_notify()
            return result, nil
        end
    end

    self:_checkHalf()
    self:_notify()
    return result, nil
end

-- Called after the player decides to activate or pass a trap window.
-- trapSlotIndex = 1-based index within trapWindow.traps to activate, or nil to pass.
function Store:resolveTrap(trapSlotIndex)
    if not self.trapWindow then return end
    local tw = self.trapWindow
    self.trapWindow = nil

    local match      = self.match
    -- opponentId = who the AI / active attacking player is (varies by window type)
    local opponentId = match.activePlayer  -- correct for pre_attack / post_destroy (AI is active)

    -- ── Counter windows (player is active, AI trap was about to auto-fire) ────

    if tw.type == "counter_offside" then
        if trapSlotIndex then
            -- Player uses MC to negate AI's OFFSIDE
            local entry   = tw.traps[trapSlotIndex]
            local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
            if not trapDef then self:_notify(); return end
            -- Consume AI's OFFSIDE trap and pay 1000 LP
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            match.players.player.lp = match.players.player.lp - 1000
            -- Attack now proceeds normally
            local snap   = { attacker = tw.attackerSnap, defender = tw.defenderSnap }
            local result = Phases.attack(match, tw.attackerSlot, tw.defenderSlot)
            if result then
                if result.outcome == "cover_needed" then
                    self.coverWindow = {
                        attackerSlot     = tw.attackerSlot,
                        emptySlot        = tw.defenderSlot,
                        eligibleCoverers = result.eligibleCoverers,
                        attackerSnap     = tw.attackerSnap,
                    }
                else
                    self:_pushCombat(snap, result)
                end
            end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("player", trapDef,
                "Manager's Challenge! " .. atkName .. " onside — attack proceeds. (-1000 LP)")
        else
            -- Player passes — AI's OFFSIDE fires
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            local attCard = Phases._getSlotForPlayer(match, "player", tw.attackerSlot)
            if attCard then attCard.exhausted = true end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("opponent", tw.aiTrapCard.definition,
                "Your " .. atkName .. " was caught offside!")
        end
        self:_checkHalf()
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
            local attCard = Phases._getSlotForPlayer(match, opponentId, tw.attackerSlot)
            if attCard then attCard.exhausted = true end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            ctxText = atkName .. " blocked — offside!"

        elseif tw.type == "pre_attack" and ability == "MANAGERS_CHALLENGE" then
            -- MC negates the opponent's OFFSIDE; attack proceeds + pay 1000 LP
            match.players.player.lp = match.players.player.lp - 1000
            -- Find and discard AI's OFFSIDE that was about to fire
            local aiOff, aiOffIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
            if aiOff then Phases.activateTrap(match, "opponent", aiOffIdx) end
            -- Execute the attack
            local snap   = { attacker = tw.attackerSnap, defender = tw.defenderSnap }
            local result = Phases.attack(match, tw.attackerSlot, tw.defenderSlot)
            if result then
                if result.outcome == "cover_needed" then
                    self.coverWindow = {
                        attackerSlot     = tw.attackerSlot,
                        emptySlot        = tw.defenderSlot,
                        eligibleCoverers = result.eligibleCoverers,
                        attackerSnap     = tw.attackerSnap,
                    }
                else
                    self:_pushCombat(snap, result)
                end
            end
            ctxText = "Offside overruled by Manager's Challenge! (-1000 LP)"
            self:_checkHalf()
            self:_pushTrapActivation("player", trapDef, ctxText)
            self:_notify()
            return

        elseif tw.type == "post_destroy" and ability == "RED_CARD" then
            Phases._destroyCard(match, opponentId, tw.attackerSlot.type, tw.attackerSlot.index or 0)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            ctxText = atkName .. " sent off after winning combat"

        elseif tw.type == "post_damage" and ability == "VAR" then
            -- Undo LP damage, return AI's striker to opponent's hand
            match.players.player.lp = match.players.player.lp + (tw.damage or 0)
            local oppPitch = match.players.opponent.pitch
            local striker  = oppPitch.strikers[tw.attackerSlot.index]
            if striker then
                table.insert(match.players.opponent.hand, striker.definition)
                oppPitch.strikers[tw.attackerSlot.index] = nil
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
        -- Pass
        if tw.type == "pre_attack" then
            local snap   = { attacker = tw.attackerSnap, defender = tw.defenderSnap }
            local result = Phases.attack(match, tw.attackerSlot, tw.defenderSlot)
            if result then
                if result.outcome == "cover_needed" then
                    self.coverWindow = {
                        attackerSlot     = tw.attackerSlot,
                        emptySlot        = tw.defenderSlot,
                        eligibleCoverers = result.eligibleCoverers,
                        attackerSnap     = tw.attackerSnap,
                    }
                else
                    self:_pushCombat(snap, result)
                    self:_checkHalf()
                end
            end
        end
        -- post_destroy, post_damage, post_last_defender pass: no further action
    end

    self:_checkHalf()
    self:_notify()
end

-- Play a strategy card from hand.
function Store:playStrategy(cardId, opts)
    local match    = self.match
    local activeId = match.activePlayer

    -- Strategy shots are snapshotted before they resolve: the best striker and the keeper
    -- as they stand now (Penalty: the keeper's base DEF).
    local shotSnap
    for _, c in ipairs(match.players[activeId].hand) do
        if c.id == cardId and (c.ability == "DIRECT_FREE_KICK" or c.ability == "PENALTY") then
            local _, bestSlot = Phases._bestStriker(match.players[activeId].pitch)
            if bestSlot then
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 })
                local keeper = match.players[State.other(activeId)].pitch.keeper
                if c.ability == "PENALTY" and keeper and shotSnap.defender then
                    shotSnap.defender.def = Combat.getStat(keeper, "defend")
                end
            end
            break
        end
    end

    local result, err = Phases.playStrategy(match, cardId, opts)
    if result then
        local o = result.outcome
        if shotSnap and (o == "damage" or o == "tie" or o == "save") then
            self:_pushCombat(shotSnap, result)
        end
        self:_checkHalf()
        self:_notify()
    end
    return result, err
end

-- Called after the player decides to cover or let through.
function Store:resolveCover(covererSlot)
    if not self.coverWindow then return end

    local attackerSlot = self.coverWindow.attackerSlot
    local emptySlot    = self.coverWindow.emptySlot
    local match        = self.match
    local opponentId   = match.activePlayer == "player" and "opponent" or "player"

    -- When the player passes (no cover), the attacker advances to the next occupied line.
    -- Snap that card instead of the empty slot so the combat overlay shows the real defender.
    local defSlotForSnap = covererSlot
    if not covererSlot then
        local nextSlot = Phases._nextOccupiedLine(match.players[opponentId].pitch, emptySlot)
        defSlotForSnap = nextSlot or emptySlot
    end
    local snap = self:_snapshotAttack(attackerSlot, defSlotForSnap)
    self.coverWindow = nil

    local result, err = Phases.resolveCover(self.match, attackerSlot, emptySlot, covererSlot)

    if result and result.outcome ~= "wasted" and result.outcome ~= "cover_needed" then
        self:_pushCombat(snap, result)
    end

    self:_checkHalf()
    self:_notify()
    return result, err
end

function Store:endTurn()
    self.coverWindow = nil
    self.trapWindow  = nil
    Phases.endTurn(self.match)
    self:_notify()
end

function Store:popCombat()
    if #self.combatQueue == 0 then return nil end
    return table.remove(self.combatQueue, 1)
end

-- ── Private helpers ────────────────────────────────────────────────────────────

function Store:_checkHalf()
    local hw = State.checkHalfEnd(self.match)
    if hw and not self.match.winner then
        State.endHalf(self.match, hw)
    end
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

function Store:_snapshotAttack(attackerSlot, defenderSlot)
    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = activeId == "player" and "opponent" or "player"
    local Combat     = require("engine.combat")

    local function getCard(pitch, slot)
        if not slot then return nil end
        if slot.type == "keeper"     then return pitch.keeper end
        if slot.type == "defender"   then return pitch.defenders[slot.index] end
        if slot.type == "midfielder" then return pitch.midfielder end
        if slot.type == "striker"    then return pitch.strikers[slot.index] end
        return nil
    end

    local atkCard = getCard(match.players[activeId].pitch,   attackerSlot)
    local defCard = getCard(match.players[opponentId].pitch, defenderSlot)

    local function snap(card, isKeeper, slotType)
        if not card then return nil end
        local d        = card.definition
        local oppPitch = match.players[opponentId].pitch
        local atkPitch = match.players[activeId].pitch

        local atkBonus = 0
        local defBonus = 0
        local defStat

        if isKeeper then
            defStat = Combat.keeperEffectiveDef(card, oppPitch)
        else
            defStat = Combat.getStat(card, "defend")
            if slotType == "defender" then
                defBonus = Combat.midfielderCardDefBonus(oppPitch)
                defStat  = defStat + defBonus
            end
        end

        local atkStat = Combat.getStat(card, "attack")
        if slotType == "striker" then
            atkBonus = Combat.midfielderCardAtkBonus(atkPitch)
            atkStat  = atkStat + atkBonus
        end

        return {
            name      = d.name,
            type      = d.type,
            mode      = card.mode,
            wasHidden = (card.mode == "defense"),
            atk       = atkStat,
            def       = defStat,
            atkBonus  = atkBonus,
            defBonus  = defBonus,
            isKeeper  = isKeeper,
        }
    end

    local isKeeperShot = defenderSlot and defenderSlot.type == "keeper"
    return {
        attacker = snap(atkCard, false,         attackerSlot and attackerSlot.type),
        defender = snap(defCard, isKeeperShot,  defenderSlot and defenderSlot.type),
    }
end

function Store:_assertPhase(expected)
    return self.match and self.match.phase == expected
end

function Store:_notify()
    if self.onUpdate then self.onUpdate(self.match) end
end

return Store
