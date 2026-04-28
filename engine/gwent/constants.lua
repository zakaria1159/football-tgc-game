-- engine/gwent/constants.lua
local C = {}

C.STARTING_HAND_SIZE  = 10
C.BETWEEN_HALF_DRAW   = 2
C.MULLIGAN_START      = 2
C.MULLIGAN_BETWEEN    = 1
C.MIN_POWER           = 0

-- Ability keys used across abilities.lua and card definitions
C.ABILITIES = {
    TIGHT_BOND            = "TIGHT_BOND",
    MORALE_BOOST          = "MORALE_BOOST",
    SPY                   = "SPY",
    MEDIC                 = "MEDIC",
    MUSTER                = "MUSTER",
    AGILITY               = "AGILITY",
    DEVOUR                = "DEVOUR",
    FOG_BONUS             = "FOG_BONUS",
    COMMANDERS_HORN_SELF  = "COMMANDERS_HORN_SELF",
    -- Special card abilities
    DECOY                 = "DECOY",
    COMMANDERS_HORN       = "COMMANDERS_HORN",
    SCORCH                = "SCORCH",
    CLEAR_WEATHER         = "CLEAR_WEATHER",
    WEATHER_FROST         = "WEATHER_FROST",
    WEATHER_FOG           = "WEATHER_FOG",
    WEATHER_RAIN          = "WEATHER_RAIN",
    WEATHER_SUMMON        = "WEATHER_SUMMON",
}

return C
