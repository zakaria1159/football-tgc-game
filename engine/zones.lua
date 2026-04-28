local C = require("engine.constants")

local Zones = {}

-- Count active (non-exhausted, non-nil) cards in a list.
local function countActive(list)
    local n = 0
    for _, card in ipairs(list) do
        if card and not card.exhausted then n = n + 1 end
    end
    return n
end

-- Returns zone control state for both sides.
-- matchState.players.player.pitch / opponent.pitch
function Zones.evaluate(matchState)
    local pPitch = matchState.players.player.pitch
    local oPitch = matchState.players.opponent.pitch

    local pDefenders = countActive(pPitch.defenders)
    local pStrikers  = countActive(pPitch.strikers)
    local oDefenders = countActive(oPitch.defenders)
    local oStrikers  = countActive(oPitch.strikers)

    local result = {
        player = {
            defensiveSuperiority = pDefenders > oStrikers,
            attackingSuperiority  = pStrikers  > oDefenders,
            midfieldControl       = matchState.midfieldControl == "player",
        },
        opponent = {
            defensiveSuperiority = oDefenders > pStrikers,
            attackingSuperiority  = oStrikers  > pDefenders,
            midfieldControl       = matchState.midfieldControl == "opponent",
        },
    }

    return result
end

-- Returns the spare defender DEF bonus if defensive superiority applies.
-- Returns 0 otherwise.
function Zones.spareDefBonus(hasSuperority)
    if hasSuperority then
        return C.ZONE.DEF_SUPERIORITY_BONUS
    end
    return 0
end

-- Returns the slot zone given slot type and index.
function Zones.getZone(slotType, slotIndex)
    if slotType == "keeper" then
        return "penalty-area"
    elseif slotType == "defender" then
        if slotIndex == 1 then  -- center
            return "penalty-area"
        else
            return "defensive"
        end
    elseif slotType == "midfielder" then
        return "middle"
    elseif slotType == "striker" then
        return "attacking"
    end
    return "middle"
end

return Zones
