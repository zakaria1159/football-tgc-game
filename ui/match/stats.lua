-- Board facts shown in the match UI. Pure (unit-tested).
local Combat = require("engine.combat")
local C      = require("engine.constants")

local Stats = {}

-- "player" | "opponent" | nil — whose midfielder currently has more power (★ crown).
-- Any unrevealed face-down card in the opponent's midfield slot is hidden information:
-- its power, and even whether it is a midfielder, is unknown, so there is no crown. The
-- player's own face-down card still counts since they know it.
function Stats.crownOwner(match)
    local oMid = match.players.opponent.pitch and match.players.opponent.pitch.midfielder
    if oMid and oMid.mode == "defense" and not oMid.revealed then
        return nil
    end
    local p = Combat.midfielderPower(match.players.player.pitch)
    local o = Combat.midfielderPower(match.players.opponent.pitch)
    if p > o then return "player" end
    if o > p then return "opponent" end
    return nil
end

-- used, max — "SUMMONS used / max". max is 2, or 1 under the opponent's Time Wasting, plus
-- Metronome's extra summon on your own turn. Midfield control itself gives a card.
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    if match.activePlayer == "player" then max = max + (match.bonusSummons or 0) end
    return used, max
end

-- used, max — "SUBS used / max": your substitutions this half (keeper swaps included).
function Stats.subs(match)
    return match.players.player.subsUsed or 0, C.MATCH.SUBS_PER_HALF
end

return Stats
