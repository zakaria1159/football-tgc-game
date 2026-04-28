local T = require("engine.types")

local Traps = {}

-- Returns true if this trap can activate given the current window event.
-- event: { type, phase, payload }
function Traps.canActivate(trap, event)
    local cat = trap.definition.trapCategory

    if cat == T.TrapCategory.A then
        -- after striker declares attack, before resolved
        return event.type == "attack_declared"

    elseif cat == T.TrapCategory.B then
        -- after opponent plays strategy card, before it resolves
        return event.type == "strategy_played" and event.byOpponent

    elseif cat == T.TrapCategory.C then
        -- after opponent places a card onto pitch
        return event.type == "card_summoned" and event.byOpponent

    elseif cat == T.TrapCategory.D then
        -- automatic: turn boundary or game state condition
        return Traps.checkPassiveCondition(trap, event)
    end

    return false
end

function Traps.checkPassiveCondition(trap, event)
    local ability = trap.definition.ability

    if ability == "MOMENTUM_SHIFT" then
        -- activates at start of opponent's attack phase
        return event.type == "attack_phase_start" and event.byOpponent

    elseif ability == "CROWD_PRESSURE" then
        return event.type == "attack_declared"
    end

    return false
end

-- Applies the trap effect. Returns a result table describing what happened.
-- state: match state (read-only reference for context)
-- event: the triggering event
function Traps.apply(trap, state, event)
    local ability = trap.definition.ability

    if ability == "OFFSIDE" then
        -- cancel the incoming striker attack
        return { cancelAttack = true, logMsg = "Offside! Attack cancelled." }

    elseif ability == "LAST_DITCH_TACKLE" then
        -- exhausted defender fights back at full DEF
        return { triggerCounterDefense = true, logMsg = "Last Ditch Tackle! Defender fights back!" }

    elseif ability == "GK_HEROICS" then
        return { keeperDefBonus = 600, logMsg = "Goalkeeper Heroics! Keeper gets +600 DEF!" }

    elseif ability == "PROFESSIONAL_FOUL" then
        -- force a foul: yellow card, free kick, attack cancelled
        return { forceFoul = true, foulZone = event.defenderZone, logMsg = "Professional Foul!" }

    elseif ability == "VAR_REVIEW" then
        -- handled separately in phases.lua (special multi-trigger logic)
        return { varReview = true, logMsg = "VAR Review!" }

    elseif ability == "SLIDING_TACKLE" then
        -- defender wins regardless of margin, but if they'd still lose they're destroyed
        return { slidingTackle = true, boost = 400, logMsg = "Sliding Tackle!" }

    elseif ability == "CROWD_PRESSURE" then
        -- opponent's next striker attack this turn gets -200 ATK
        return { atkDebuff = 200, target = "opponent_next_striker", logMsg = "Crowd Pressure! Opponent striker -200 ATK." }

    elseif ability == "MOMENTUM_SHIFT" then
        -- swap one exhausted of yours with one active of opponent
        return { momentumShift = true, logMsg = "Momentum Shift! Swap exhaustion states." }
    end

    return { logMsg = "Trap activated." }
end

return Traps
