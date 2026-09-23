local T = {}

T.CardType = {
    KEEPER     = "keeper",
    DEFENDER   = "defender",
    MIDFIELDER = "midfielder",
    STRIKER    = "striker",
}

T.Rarity = {
    COMMON    = "common",
    UNCOMMON  = "uncommon",
    RARE      = "rare",
    EPIC      = "epic",
    LEGENDARY = "legendary",
}

-- Card placement mode
T.CardMode = {
    ATTACK  = "attack",   -- face up, uses ATK when defending
    DEFENSE = "defense",  -- face down, uses DEF when defending, cannot attack
}

T.CombatOutcome = {
    ATTACKER_EXHAUSTED  = "attacker_exhausted",   -- negative margin
    TIE                 = "tie",                   -- margin 0, both exhausted
    DEFENDER_EXHAUSTED  = "defender_exhausted",    -- margin 1–299
    DEFENDER_DESTROYED  = "defender_destroyed",    -- margin >= 300
}

T.ShotOutcome = {
    DAMAGE = "damage",   -- LP damage dealt, keeper exhausted
    TIE    = "tie",      -- no damage, both exhausted
    SAVE   = "save",     -- no damage, striker exhausted
}

T.EventType = {
    CARD_DRAWN        = "card_drawn",
    CARD_PLAYED       = "card_played",
    ATTACK_DECLARED   = "attack_declared",
    DEFENDER_EXHAUST  = "defender_exhaust",
    DEFENDER_DESTROY  = "defender_destroy",
    COVER             = "cover",
    SHOT              = "shot",
    LP_DAMAGE         = "lp_damage",
    HALF_END          = "half_end",
    TURN_END          = "turn_end",
    MATCH_END         = "match_end",
    MIDFIELD_CONTROL  = "midfield_control",
}

return T
