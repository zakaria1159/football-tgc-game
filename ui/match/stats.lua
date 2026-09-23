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

-- used, max — "SUMMONS used / max". max is 2, or 1 under the opponent's Time Wasting.
-- Midfield control gives a card, not a summon, so there is no bonus flag.
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    return used, max
end

return Stats
