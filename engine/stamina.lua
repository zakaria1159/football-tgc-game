-- Stamina (docs/superpowers/specs/2026-09-24-modes-stamina-design.md, B1). Pure; depends only
-- on engine.constants, so engine.state can use it.
--   pitched.stamina: current stamina of a field card; nil for cards that never tire
--   (keepers, traps). Full on entering the pitch (State.newPitchedCard); drained by
--   engine/phases.lua (Phases._spend). At 0 the card is Tired: −300 ATK / −300 DEF through
--   engine/cards/resolver.lua (R.tiredPart).
local C = require("engine.constants")

local Stamina = {}

-- Full stamina for a card definition: strikers 4, midfielders 5, defenders 6, Engine +2;
-- nil for keepers, traps and strategies (they never tire).
function Stamina.max(cardDef)
    local base = cardDef and C.STAMINA.MAX[cardDef.type]
    if not base then return nil end
    if cardDef.keyword == "ENGINE" then base = base + C.STAMINA.ENGINE_BONUS end
    return base
end

-- True at 0 stamina (Tired).
function Stamina.tired(pitched)
    return pitched ~= nil and pitched.stamina ~= nil and pitched.stamina <= 0
end

-- Takes n (default 1) stamina from a pitched card; never below 0. Returns true when this
-- made the card Tired.
function Stamina.spend(pitched, n)
    if not pitched or pitched.stamina == nil or pitched.stamina <= 0 then return false end
    pitched.stamina = math.max(0, pitched.stamina - (n or 1))
    return pitched.stamina == 0
end

-- Whether a viewer sees this card's stamina: its owner always; the other player only while
-- the card is face-up (attack mode or revealed). Cards that never tire show none.
function Stamina.visible(pitched, isOwner)
    if not pitched or pitched.stamina == nil then return false end
    if isOwner then return true end
    return pitched.mode ~= "defense" or pitched.revealed == true
end

return Stamina
