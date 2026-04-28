-- Resolves named card abilities. Called by phases.lua / combat resolution.
-- Never put game logic inside card definitions — always call through here.

local Resolver = {}

-- Returns any combat modifier that this card's ability applies before a combat resolves.
-- context: { attacker, defender, phase, matchState }
function Resolver.preCombat(card, context)
    local ability = card.definition.ability
    if not ability then return {} end

    if ability == "POACHER_DOUBLE_XG" then
        -- engine v2: poacher doubles effective ATK on poor/half chance equivalent
        -- "poor" = margin 1-299, "half" = 300-599 in v2 terms
        local margin = (context.attackerStat or 0) - (context.defenderStat or 0)
        if margin > 0 and margin < 600 then
            return { atkBonus = math.floor((context.attackerStat or 0) * 1.0) }
        end
    end

    if ability == "TARGET_MAN_BYPASS" then
        -- bypass midfield zone control penalty (handled in phases)
        return { bypassMidfieldControl = true }
    end

    if ability == "PRESSING_FORWARD_EXHAUST" then
        -- if striker wins combat, opponent's next card is also exhausted
        return { cascadeExhaust = true }
    end

    return {}
end

-- Returns any modifier for a keeper save attempt.
function Resolver.keeperSave(keeper, context)
    local ability = keeper.definition.ability
    if not ability then return {} end

    if ability == "IRON_FISTS_SAVE" then
        -- if keeper saves, opponent striker is exhausted (normally attacker exhausts anyway on save)
        return { strikerExhaustOnSave = true }
    end

    if ability == "SWEEPER_KEEPER_COVER" then
        -- can cover empty defender slots at 100% DEF (no position penalty)
        return { noCoverPenalty = true }
    end

    return {}
end

-- Returns formation bonus modifiers when midfield control is active.
-- formation: card definition, tagDensity: number of matching pitched cards
function Resolver.formationBonus(formation, tagDensity, hasMidfieldControl)
    if not hasMidfieldControl then return {} end

    local C = require("engine.constants")
    local ability = formation.ability
    local multiplier = 1.0

    if tagDensity <= 3 then
        multiplier = C.TAG_DENSITY.WEAK_MULTIPLIER
    end

    local bonus = { midBonus = 0 }

    if tagDensity >= C.TAG_DENSITY.BOOSTED_THRESHOLD then
        bonus.midBonus = C.TAG_DENSITY.BOOSTED_MID_BONUS
    end

    if ability == "TIKI_TAKA_BONUS" then
        bonus.drawOnStrikerSuccess = true

    elseif ability == "LONG_BALL_BONUS" then
        bonus.strikerAtkBonus = math.floor(200 * multiplier)

    elseif ability == "CATENACCIO_BONUS" then
        bonus.defenderDefBonus = math.floor(200 * multiplier)

    elseif ability == "GEGENPRESS_BONUS" then
        bonus.allAtkBonus = math.floor(150 * multiplier)
        bonus.lateGamePenalty = -200  -- applied after turn 6

    elseif ability == "TOTAL_FOOTBALL_BONUS" then
        bonus.freePitchMove = true

    elseif ability == "COUNTER_ATTACK_BONUS" then
        bonus.firstFailNoExhaust = true
    end

    return bonus
end

return Resolver
