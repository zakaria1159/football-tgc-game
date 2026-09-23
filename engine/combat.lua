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
--   Effective DEF = base DEF + Safe hands + line bonus: each active defender-slot card
--   +300 (Bolt +500), an active midfielder-slot card +150 (any card, either mode).
--   penaltyMode: base DEF + Safe hands only, unless the keeper has Fortress (full DEF).
--   Active = has not attacked since the start of its owner's latest turn.
--   visibleOnly: a face-down, unrevealed Bolt card counts as a plain +300.
-- Returns total, parts.
function Combat.keeperDef(keeper, pitch, penaltyMode, visibleOnly)
    local parts = {}
    local own, ownPart = Resolver.keeperOwnBonus(keeper)
    if ownPart then parts[#parts + 1] = ownPart end
    local base = Combat.getStat(keeper, "defend") + own

    local line, lineParts = 0, {}
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch and pitch.defenders and pitch.defenders[i]
        if c and not c.usedAsAttacker then
            local b, p = Resolver.keeperLineBonus(c, visibleOnly)
            line = line + b
            if p then lineParts[#lineParts + 1] = p end
        end
    end
    local mid = pitch and pitch.midfielder
    if mid and not mid.usedAsAttacker then line = line + C.COMBAT.MIDFIELDER_BONUS end

    if penaltyMode then
        if not Resolver.penaltyFullDef(keeper) then return base, parts end
        if line > 0 then parts[#parts + 1] = Resolver.part(line, keeper, "FORTRESS") end
    end
    for _, p in ipairs(lineParts) do parts[#parts + 1] = p end
    return base + line, parts
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
-- Clinical: a tie is a goal for C.ABILITY.CLINICAL_DAMAGE (result.clinical = true).
-- Returns { outcome, damage, margin, openGoal, clinical, atkStat, defStat, atkParts, defParts }
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

    local outcome, damage, clinical
    if margin > 0 then
        outcome = "damage"
        damage  = margin
    elseif margin == 0 then
        if Resolver.clinical(striker) then
            outcome, damage, clinical = "damage", C.ABILITY.CLINICAL_DAMAGE, true
        else
            outcome, damage = "tie", 0
        end
    else
        outcome = "save"
        damage  = 0
    end

    return { outcome = outcome, damage = damage, margin = margin, clinical = clinical,
             atkStat = atkStat, defStat = defStat, atkParts = atkParts, defParts = defParts }
end

return Combat
