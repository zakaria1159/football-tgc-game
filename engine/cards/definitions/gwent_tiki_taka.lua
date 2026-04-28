-- engine/cards/definitions/gwent_tiki_taka.lua
local TT = {}

TT.cards = {
    -- ── Attack ────────────────────────────────────────────────────────────────
    { id = "gtt-poacher",     name = "The Poacher",     row = "attack",   power = 4,  rarity = "uncommon",  faction = "tiki_taka", ability = "BOOST_SELF_PER_ATTACK_ROW",     abilityText = "Boost self +1 for each other card in your attack row." },
    { id = "gtt-raumdeuter",  name = "The Raumdeuter",  row = "attack",   power = 3,  rarity = "common",    faction = "tiki_taka", ability = "BOOST_LEFT_IN_ROW",             abilityText = "Boost the card to your left in the attack row +2." },
    { id = "gtt-falsanine",   name = "The False Nine",  row = "attack",   power = 2,  rarity = "common",    faction = "tiki_taka", ability = "MOVE_TO_MID_BOOST_ALL_MID",     abilityText = "Move to your midfield row and boost all midfield cards +1." },
    { id = "gtt-finisher",    name = "The Finisher",    row = "attack",   power = 6,  rarity = "uncommon",  faction = "tiki_taka", ability = "BOOST_SELF_IF_MID_GTE_3",       abilityText = "Boost self +2 if you have 3+ cards in your midfield row." },
    { id = "gtt-talisman",    name = "The Talisman",    row = "attack",   power = 10, rarity = "legendary", faction = "tiki_taka", ability = "BOOST_ALL_ATK_AND_MID",         abilityText = "Boost all cards in your attack and midfield rows +1." },
    -- ── Midfield ──────────────────────────────────────────────────────────────
    { id = "gtt-metronome",   name = "The Metronome",   row = "midfield", power = 3,  rarity = "common",    faction = "tiki_taka", ability = "BOOST_TWO_MID",                 abilityText = "Boost two other midfield cards +1 each." },
    { id = "gtt-playmaker",   name = "The Playmaker",   row = "midfield", power = 4,  rarity = "uncommon",  faction = "tiki_taka", ability = "BOOST_TOP_ATTACK",              abilityText = "Boost the highest power card in your attack row +2." },
    { id = "gtt-boxtbox",     name = "The Box to Box",  row = "midfield", power = 5,  rarity = "uncommon",  faction = "tiki_taka", ability = "BOOST_SELF_ON_HALF_SURVIVE",    abilityText = "Gains +1 base power for each half it survives in hand unplayed." },
    { id = "gtt-conductor",   name = "The Conductor",   row = "midfield", power = 2,  rarity = "common",    faction = "tiki_taka", ability = "DRAW_CARD",                     abilityText = "Draw 1 card from your deck." },
    { id = "gtt-engine",      name = "The Engine",      row = "midfield", power = 3,  rarity = "common",    faction = "tiki_taka", ability = "BOOST_ALL_FACTION_MID",         abilityText = "Boost all Tiki-Taka midfield cards +1." },
    { id = "gtt-deepthreat",  name = "The Deep Threat", row = "midfield", power = 7,  rarity = "rare",      faction = "tiki_taka", ability = "BOOST_ALL_MID",                 abilityText = "Boost all midfield cards +1." },
    -- ── Defense ───────────────────────────────────────────────────────────────
    { id = "gtt-sweeper",     name = "The Sweeper",     row = "defense",  power = 4,  rarity = "uncommon",  faction = "tiki_taka", ability = "IMMUNE_MIN_2",                  abilityText = "Cannot be reduced below 2 power." },
    { id = "gtt-libero",      name = "The Libero",      row = "defense",  power = 3,  rarity = "common",    faction = "tiki_taka", ability = "BOOST_ALL_DEF",                 abilityText = "Boost all other defense row cards +1." },
    { id = "gtt-wall",        name = "The Wall",        row = "defense",  power = 6,  rarity = "uncommon",  faction = "tiki_taka", ability = "IMMUNE_WEATHER",                abilityText = "Immune to weather card effects." },
    { id = "gtt-keeper",      name = "The Keeper",      row = "defense",  power = 5,  rarity = "uncommon",  faction = "tiki_taka", ability = "BOOST_ON_WEATHER_PLAYED",       abilityText = "Boost self +2 when opponent plays a weather card." },
    { id = "gtt-organizer",   name = "The Organizer",   row = "defense",  power = 2,  rarity = "common",    faction = "tiki_taka", ability = "BOOST_TWO_LOWEST_DEF",          abilityText = "Boost the two lowest power cards in your defense row +1 each." },
    -- ── Strategy ──────────────────────────────────────────────────────────────
    { id = "gtt-onetouch",    name = "One Touch",        row = "strategy", power = nil, rarity = "strategy", faction = "tiki_taka", ability = "ONE_TOUCH",        abilityText = "Boost all cards in one of your rows +1." },
    { id = "gtt-ttpress",     name = "Tiki-Taka Press",  row = "strategy", power = nil, rarity = "strategy", faction = "tiki_taka", ability = "TIKI_TAKA_PRESS",  abilityText = "Look at opponent's hand. Choose one card to discard." },
    { id = "gtt-positplay",   name = "Positional Play",  row = "strategy", power = nil, rarity = "strategy", faction = "tiki_taka", ability = "POSITIONAL_PLAY",  abilityText = "Move one of your cards to any row. It keeps its full power." },
    -- ── Traps ─────────────────────────────────────────────────────────────────
    { id = "gtt-intercept",   name = "Interception",     row = "trap",     power = nil, rarity = "trap",     faction = "tiki_taka", ability = "INTERCEPTION",     abilityText = "Trigger: opponent plays to midfield. Effect: reduce that card -2." },
    { id = "gtt-pressres",    name = "Press Resistance",  row = "trap",     power = nil, rarity = "trap",     faction = "tiki_taka", ability = "PRESS_RESISTANCE", abilityText = "Trigger: opponent reduces one of your cards. Effect: restore it." },
}

TT.leader = {
    id          = "gtt-leader-maestro",
    name        = "El Maestro",
    row         = "leader",
    faction     = "tiki_taka",
    ability     = "EL_MAESTRO",
    abilityText = "Boost all cards in your midfield row +2.",
}

return TT
