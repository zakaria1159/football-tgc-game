local C = require("engine.constants")
local T = require("engine.types")

local Fouls = {}

-- Decides whether a mistimed tackle produces a foul.
-- rng: function() -> 0..1
function Fouls.resolveMistimed(rng)
    local roll = rng()
    if roll < C.FOUL.MISTIMED_CLEAN_RATE then
        return T.FoulOutcome.CLEAN
    elseif roll < C.FOUL.MISTIMED_CLEAN_RATE + C.FOUL.MISTIMED_MINOR_RATE then
        return T.FoulOutcome.MINOR_FOUL
    elseif roll < C.FOUL.MISTIMED_CLEAN_RATE + C.FOUL.MISTIMED_MINOR_RATE + C.FOUL.MISTIMED_YELLOW_RATE then
        return T.FoulOutcome.YELLOW
    else
        return T.FoulOutcome.RED
    end
end

-- Returns the foul consequence given zone.
-- consequence: { attackType, atkValue, keeperDefReduction, cardColor }
-- attackType: "free_kick" or "penalty"
function Fouls.consequence(zone)
    if zone == "penalty-area" then
        return {
            attackType       = "penalty",
            atkValue         = C.FOUL.PENALTY_ATK,
            keeperDefReduction = C.COMBAT.PENALTY_DEF_REDUCTION,
            cardColor        = "yellow",
        }
    elseif zone == "defensive" then
        return {
            attackType       = "free_kick",
            atkValue         = C.FOUL.FREE_KICK_DEF_ATK,
            keeperDefReduction = 0,
            cardColor        = "yellow",
        }
    else  -- midfield
        return {
            attackType       = "free_kick",
            atkValue         = C.FOUL.FREE_KICK_MIDFIELD_ATK,
            keeperDefReduction = 0,
            cardColor        = nil,
        }
    end
end

-- Returns true if foul should trigger for this defender given attacker margin and foulTendency.
-- Called when an attacker narrowly beats a defender (margin > 0, margin < MISTIMED_THRESHOLD).
function Fouls.shouldCheckMistimed(margin, foulTendency)
    if margin >= C.FOUL.MISTIMED_THRESHOLD then return false end
    if foulTendency == T.FoulTendency.VERY_HIGH then return true end
    if foulTendency == T.FoulTendency.HIGH then return true end
    if foulTendency == T.FoulTendency.MEDIUM then return true end
    return false
end

-- Apply yellow/red card logic to a card.
-- Returns updated card and whether card is destroyed.
function Fouls.applyCard(card, cardColor)
    if cardColor == "red" then
        return card, true
    elseif cardColor == "yellow" then
        card.yellowCards = (card.yellowCards or 0) + 1
        if card.yellowCards >= 2 then
            return card, true  -- second yellow = red = destroyed
        end
    end
    return card, false
end

return Fouls
