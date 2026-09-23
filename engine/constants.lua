local C = {}

C.MATCH = {
    STARTING_HAND_SIZE        = 5,
    MAX_SUMMONS_PER_TURN      = 2,
    STARTING_LP               = 4000,
    EXTRA_TIME_TURNS          = 6,    -- Extra Time rounds
    HALF_ROUND_LIMIT          = 14,   -- rounds per half (halves 1 and 2); a round = one turn each
    MIDFIELD_CONTROL_DRAW     = 1,    -- extra cards drawn at turn start by the player controlling midfield
}

C.COMBAT = {
    DEFENDER_BONUS            = 300,  -- per active defender contributing to keeper DEF
    MIDFIELDER_BONUS          = 150,  -- active midfielder contributing to keeper DEF
    MIDFIELDER_CARD_ATK_BONUS = 200,  -- midfielder card (attack mode) → striker ATK bonus
    MIDFIELDER_CARD_DEF_BONUS = 200,  -- midfielder card (defense mode) → defender DEF bonus
}

-- Keeper effective DEF = base DEF + (active defenders × 300) + (active midfielder × 150)

C.SLOT_ORDER = { "defender", "midfielder", "keeper" }

C.PITCH = {
    MAX_DEFENDERS = 2,
    MAX_STRIKERS  = 2,
    MAX_TRAPS     = 2,
}

return C
