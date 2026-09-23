-- Board facts shown in the match UI. Pure (unit-tested).
local Combat = require("engine.combat")
local C      = require("engine.constants")

local Stats = {}

-- "player" | "opponent" | nil — whose midfielder currently has more power (★ crown).
-- The opponent's face-down midfielder is hidden information: if theirs is face-down,
-- its power (and thus the crown) is unknown. The player's own face-down card still
-- counts since they know it.
function Stats.crownOwner(match)
    local oMid = match.players.opponent.pitch and match.players.opponent.pitch.midfielder
    if oMid and oMid.definition.type == "midfielder" and oMid.mode == "defense" then
        return nil
    end
    local p = Combat.midfielderPower(match.players.player.pitch)
    local o = Combat.midfielderPower(match.players.opponent.pitch)
    if p > o then return "player" end
    if o > p then return "opponent" end
    return nil
end

-- used, max, bonus — same numbers the old HUD showed ("SUMMONS used / max ★").
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    return used, max, max > C.MATCH.MAX_SUMMONS_PER_TURN
end

return Stats
