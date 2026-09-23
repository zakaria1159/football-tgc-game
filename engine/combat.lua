local C = require("engine.constants")

local Combat = {}

-- Returns the stat a card uses in the given role.
-- role "attack"  → always ATK (only attack-mode cards can attack)
-- role "defend"  → ATK if card is in attack mode, DEF if in defense mode
function Combat.getStat(card, role)
    local stats = card.definition.stats or {}
    if role == "attack" then
        return stats.atk or 0
    else
        return stats.def or 0
    end
end

-- Keeper effective DEF = base DEF + (active defenders × 300) + (active midfielder × 150)
-- Active = card exists and has not attacked since the start of its owner's latest turn.
function Combat.keeperEffectiveDef(keeper, pitch)
    local base = (keeper.definition.stats and keeper.definition.stats.def) or 0
    local bonus = 0

    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders[i]
        if c and not c.usedAsAttacker then
            bonus = bonus + C.COMBAT.DEFENDER_BONUS
        end
    end

    if pitch.midfielder and not pitch.midfielder.usedAsAttacker then
        bonus = bonus + C.COMBAT.MIDFIELDER_BONUS
    end

    return base + bonus
end

-- Midfield power for tempo control — only actual midfielder-type cards count.
-- Uses ATK if attack mode, DEF if defense mode. Non-midfielder cards in the slot return 0.
function Combat.midfielderPower(pitch)
    local mid = pitch and pitch.midfielder
    if not mid then return 0 end
    if mid.definition.type ~= "midfielder" then return 0 end
    local stats = mid.definition.stats or {}
    return mid.mode == "attack" and (stats.atk or 0) or (stats.def or 0)
end

-- +200 ATK bonus from a midfielder card in attack mode on the given pitch.
function Combat.midfielderCardAtkBonus(pitch)
    local mid = pitch and pitch.midfielder
    if mid and mid.mode == "attack" and mid.definition.type == "midfielder" then
        return C.COMBAT.MIDFIELDER_CARD_ATK_BONUS
    end
    return 0
end

-- +200 DEF bonus from a midfielder card in defense mode on the given pitch.
function Combat.midfielderCardDefBonus(pitch)
    local mid = pitch and pitch.midfielder
    if mid and mid.mode == "defense" and mid.definition.type == "midfielder" then
        return C.COMBAT.MIDFIELDER_CARD_DEF_BONUS
    end
    return 0
end

-- Returns { outcome, margin, defenderDestroyed, attackerDestroyed }
-- attackerSlotType / defenderSlotType + atkPitch / defPitch are optional; used to apply
-- midfielder card bonuses (striker slot gets +ATK, defender slot gets +DEF).
function Combat.resolve(attacker, defender, attackerSlotType, defenderSlotType, atkPitch, defPitch)
    local atkStat = Combat.getStat(attacker, "attack")
    if attackerSlotType == "striker" then
        atkStat = atkStat + Combat.midfielderCardAtkBonus(atkPitch)
    end

    local defStat = Combat.getStat(defender, "defend")
    if defenderSlotType == "defender" then
        defStat = defStat + Combat.midfielderCardDefBonus(defPitch)
    end

    local margin  = atkStat - defStat

    local outcome
    local defDestroyed = false
    local atkDestroyed = false

    if margin > 0 then
        outcome      = "defender_destroyed"
        defDestroyed = true
    elseif margin == 0 then
        outcome      = "tie"
        defDestroyed = true
        atkDestroyed = true
    else
        outcome = "attacker_exhausted"
        if attacker.exhausted then
            atkDestroyed = true
        end
    end

    return {
        outcome           = outcome,
        margin            = margin,
        defenderDestroyed = defDestroyed,
        attackerDestroyed = atkDestroyed,
    }
end

-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.
-- penaltyMode = true → keeper uses base DEF only (no active defender/midfielder bonuses).
-- attackerSlotType: only a striker-slot shooter gets the midfielder card ATK bonus.
-- Returns { outcome, damage, margin, openGoal }
-- outcome: "damage" | "tie" | "save"
function Combat.resolveShot(striker, keeper, oppPitch, strikerPitch, penaltyMode, attackerSlotType)
    local atkStat = Combat.getStat(striker, "attack")
    if attackerSlotType == "striker" then
        atkStat = atkStat + Combat.midfielderCardAtkBonus(strikerPitch)
    end
    if not keeper then
        return { outcome = "damage", damage = atkStat, margin = atkStat, openGoal = true }
    end
    local defStat = penaltyMode
        and Combat.getStat(keeper, "defend")
        or  Combat.keeperEffectiveDef(keeper, oppPitch)
    local margin  = atkStat - defStat

    local outcome, damage
    if margin > 0 then
        outcome = "damage"
        damage  = margin
    elseif margin == 0 then
        outcome = "tie"
        damage  = 0
    else
        outcome = "save"
        damage  = 0
    end

    return { outcome = outcome, damage = damage, margin = margin }
end

return Combat
