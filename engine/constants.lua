local C = {}

C.MATCH = {
    STARTING_HAND_SIZE        = 5,
    MAX_SUMMONS_PER_TURN      = 2,
    STARTING_LP               = 4000,
    EXTRA_TIME_TURNS          = 6,    -- Extra Time rounds
    HALF_ROUND_LIMIT          = 14,   -- rounds per half (halves 1 and 2); a round = one turn each
    MIDFIELD_CONTROL_DRAW     = 1,    -- extra cards drawn at turn start by the player controlling midfield
    MULLIGAN_MAX              = 3,    -- cards a player may send back at a half-time break
}

C.COMBAT = {
    DEFENDER_BONUS            = 300,  -- per active defender contributing to keeper DEF
    MIDFIELDER_BONUS          = 150,  -- active midfielder contributing to keeper DEF
    MIDFIELDER_CARD_ATK_BONUS = 200,  -- midfielder card (attack mode) → striker ATK bonus
    MIDFIELDER_CARD_DEF_BONUS = 200,  -- midfielder card (defense mode) → defender DEF bonus
}

-- Card abilities (engine/cards/resolver.lua). One number per ability rule.
C.ABILITY = {
    LINK_UP_ATK         = 150,  -- Link-up: to each other striker-slot card
    INSTINCT_ATK        = 300,  -- Instinct: shots at an exhausted keeper
    OPPORTUNIST_ATK     = 400,  -- Opportunist: shots while an enemy defender slot is empty
    LAST_MAN_DEF        = 300,  -- Last man: the only card in its owner's defender slots
    COUNTER_PRESS_DEF   = 300,  -- Counter-press: when it covers
    SAFE_HANDS_PER_SAVE = 100,  -- Safe hands: per save this half
    SAFE_HANDS_MAX      = 300,
    ENGINE_ATK          = 100,  -- Engine: striker-slot ATK, either mode (instead of +200)
    ENGINE_DEF          = 100,  -- Engine: defender-slot DEF, either mode (instead of +200)
    OVERLAP_ATK         = 300,  -- Overlap: striker-slot ATK in attack mode (instead of +200)
    BOLT_LINE           = 500,  -- Bolt: toward its keeper's effective DEF (instead of +300)
    CLINICAL_DAMAGE     = 300,  -- Clinical: LP dealt by a shot that ties the keeper's DEF
    METRONOME_SUMMONS   = 1,    -- Metronome: extra summons when controlling midfield
}

-- Keeper effective DEF = base DEF + (active defenders × 300) + (active midfielder × 150)

C.SLOT_ORDER = { "defender", "midfielder", "keeper" }

C.PITCH = {
    MAX_DEFENDERS = 2,
    MAX_STRIKERS  = 2,
    MAX_TRAPS     = 2,
}

return C
