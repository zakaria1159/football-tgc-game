local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")

local Combat = {}

-- Base stat of a card: role "attack" → ATK, "defend" → DEF (a defending card always uses
-- its DEF, whatever its mode).
function Combat.getStat(card, role)
    local stats = card.definition.stats or {}
    if role == "attack" then
        return stats.atk or 0
    else
        return stats.def or 0
    end
end

-- ATK an attacking card uses: base ATK + the midfielder card bonus (striker slot) + ability
-- bonuses (engine/cards/resolver.lua R.atkBonus).
--   ownPitch / oppPitch: the attacker's and the defending side's pitches (either may be nil).
--   shot: nil for a fight; { keeper = pitched or nil } for a shot at goal (nil = open goal).
--   visibleOnly: skip bonuses from face-down, unrevealed cards (what their opponent sees).
-- Returns total, parts (keyword parts: { keyword, amount, pitched, card }).
function Combat.attackStat(attacker, slotType, ownPitch, oppPitch, shot, visibleOnly)
    local bonus, parts = Resolver.atkBonus(attacker, {
        slotType = slotType, ownPitch = ownPitch, oppPitch = oppPitch,
        shot = shot ~= nil, keeper = shot and shot.keeper or nil, visibleOnly = visibleOnly,
    })
    return Combat.getStat(attacker, "attack") + bonus, parts
end

-- DEF a defending card uses: base DEF + the midfielder card bonus (defender slot) + ability
-- bonuses (R.defBonus). covering: the card covers an empty slot. Returns total, parts.
function Combat.defendStat(defender, slotType, ownPitch, covering, visibleOnly)
    local bonus, parts = Resolver.defBonus(defender, {
        slotType = slotType, ownPitch = ownPitch, covering = covering, visibleOnly = visibleOnly,
    })
    return Combat.getStat(defender, "defend") + bonus, parts
end

-- Keeper DEF against a shot, with its keyword parts.
--   Effective DEF = base DEF + 300 × active defender-slot cards + 150 × an active
--   midfielder-slot card (any card, either mode). penaltyMode: base DEF only.
--   Active = has not attacked since the start of its owner's latest turn.
-- Returns total, parts.
function Combat.keeperDef(keeper, pitch, penaltyMode, visibleOnly)
    local base = Combat.getStat(keeper, "defend")
    if penaltyMode then return base, {} end
    local bonus = 0
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch and pitch.defenders and pitch.defenders[i]
        if c and not c.usedAsAttacker then bonus = bonus + C.COMBAT.DEFENDER_BONUS end
    end
    local mid = pitch and pitch.midfielder
    if mid and not mid.usedAsAttacker then bonus = bonus + C.COMBAT.MIDFIELDER_BONUS end
    return base + bonus, {}
end

-- Keeper effective DEF as a number (see Combat.keeperDef).
function Combat.keeperEffectiveDef(keeper, pitch)
    return (Combat.keeperDef(keeper, pitch, false))
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

-- Striker-slot ATK bonus from the midfielder card (+200 in attack mode; Engine, Overlap).
function Combat.midfielderCardAtkBonus(pitch)
    return (Resolver.midfieldAtkBonus(pitch))
end

-- Defender-slot DEF bonus from the midfielder card (+200 in defense mode; Engine).
function Combat.midfielderCardDefBonus(pitch)
    return (Resolver.midfieldDefBonus(pitch))
end

-- Fight: attacker ATK vs defender DEF (Combat.attackStat / defendStat with the slot types
-- and pitches). opts.covering: the defender covers an empty slot.
-- Returns { outcome, margin, defenderDestroyed, attackerDestroyed,
--           atkStat, defStat, atkParts, defParts }
function Combat.resolve(attacker, defender, attackerSlotType, defenderSlotType, atkPitch, defPitch, opts)
    opts = opts or {}
    local atkStat, atkParts = Combat.attackStat(attacker, attackerSlotType, atkPitch, defPitch)
    local defStat, defParts = Combat.defendStat(defender, defenderSlotType, defPitch, opts.covering)

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
        atkStat           = atkStat,
        defStat           = defStat,
        atkParts          = atkParts,
        defParts          = defParts,
    }
end

-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.
-- penaltyMode = true → the keeper's penalty DEF (Combat.keeperDef).
-- attackerSlotType: only a striker-slot shooter gets the midfielder card ATK bonus.
-- Returns { outcome, damage, margin, openGoal, atkStat, defStat, atkParts, defParts }
-- outcome: "damage" | "tie" | "save"
function Combat.resolveShot(striker, keeper, oppPitch, strikerPitch, penaltyMode, attackerSlotType)
    local atkStat, atkParts = Combat.attackStat(striker, attackerSlotType, strikerPitch, oppPitch,
                                                { keeper = keeper })
    if not keeper then
        return { outcome = "damage", damage = atkStat, margin = atkStat, openGoal = true,
                 atkStat = atkStat, atkParts = atkParts, defParts = {} }
    end
    local defStat, defParts = Combat.keeperDef(keeper, oppPitch, penaltyMode)
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

    return { outcome = outcome, damage = damage, margin = margin,
             atkStat = atkStat, defStat = defStat, atkParts = atkParts, defParts = defParts }
end

return Combat
