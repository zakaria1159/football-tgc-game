-- engine/cards/definitions/gwent_gegenpresse.lua
local GG = {}

GG.cards = {
    -- ── Attack ────────────────────────────────────────────────────────────────
    { id = "ggg-hunter",      name = "The Hunter",       row = "attack",   power = 5,  rarity = "uncommon",  faction = "gegenpresse", ability = "REDUCE_TOP_OPPONENT_ATK",         abilityText = "Reduce the highest power card in opponent's attack row -2." },
    { id = "ggg-presstriker", name = "The Press Striker",row = "attack",   power = 4,  rarity = "common",    faction = "gegenpresse", ability = "REDUCE_ALL_OPPONENT_ATK_1",       abilityText = "Reduce all opponent attack row cards -1." },
    { id = "ggg-poacher",     name = "The Poacher",      row = "attack",   power = 3,  rarity = "common",    faction = "gegenpresse", ability = "BOOST_SELF_IF_REDUCTION_THIS_TURN",abilityText = "Boost self +2 if any opponent card was reduced this half." },
    { id = "ggg-enforcer",    name = "The Enforcer",     row = "attack",   power = 7,  rarity = "rare",      faction = "gegenpresse", ability = "REDUCE_ANY_OPPONENT_3",           abilityText = "Reduce one opponent card in any row -3." },
    { id = "ggg-blitzer",     name = "The Blitzer",      row = "attack",   power = 10, rarity = "legendary", faction = "gegenpresse", ability = "REDUCE_ATK_MID_1_OR_2",           abilityText = "Reduce all opponent attack+mid -1, or -2 if opponent leads." },
    -- ── Midfield ──────────────────────────────────────────────────────────────
    { id = "ggg-presser",     name = "The Presser",      row = "midfield", power = 4,  rarity = "common",    faction = "gegenpresse", ability = "REDUCE_ONE_OPPONENT_MID_2",       abilityText = "Reduce one opponent midfield card -2." },
    { id = "ggg-ballwinner",  name = "The Ball Winner",  row = "midfield", power = 3,  rarity = "common",    faction = "gegenpresse", ability = "REDUCE_LOWEST_OPPONENT_MID_TO_1", abilityText = "Reduce the lowest power card in opponent's midfield to 1." },
    { id = "ggg-disruptor",   name = "The Disruptor",    row = "midfield", power = 5,  rarity = "uncommon",  faction = "gegenpresse", ability = "REDUCE_ALL_OPPONENT_MID_1",       abilityText = "Reduce all opponent midfield cards -1. Reduce self -1 at half end." },
    { id = "ggg-interceptor", name = "The Interceptor",  row = "midfield", power = 2,  rarity = "common",    faction = "gegenpresse", ability = "BOOST_SELF_ON_STRATEGY",          abilityText = "Boost self +2 when opponent plays a strategy card." },
    { id = "ggg-dynamo",      name = "The Dynamo",       row = "midfield", power = 6,  rarity = "uncommon",  faction = "gegenpresse", ability = "REDUCE_ONE_PER_ROW",              abilityText = "Reduce one opponent card in each row -1." },
    { id = "ggg-destroyer",   name = "The Destroyer",    row = "midfield", power = 5,  rarity = "rare",      faction = "gegenpresse", ability = "REDUCE_TOP_ANYWHERE_3",           abilityText = "Reduce the highest power card on opponent's pitch -3." },
    -- ── Defense ───────────────────────────────────────────────────────────────
    { id = "ggg-agkeeper",    name = "The Aggressive Keeper", row = "defense", power = 5, rarity = "uncommon", faction = "gegenpresse", ability = "REDUCE_OPPONENT_ATK_ON_PLAY",  abilityText = "When opponent plays a card to attack, reduce it -1." },
    { id = "ggg-sweeper",     name = "The Sweeper",       row = "defense",  power = 4,  rarity = "common",    faction = "gegenpresse", ability = "REDUCE_ONE_OPPONENT_DEF_2",       abilityText = "Reduce one opponent defense card -2." },
    { id = "ggg-marker",      name = "The Marker",        row = "defense",  power = 3,  rarity = "common",    faction = "gegenpresse", ability = "LOCK_OPPONENT_CARD",              abilityText = "Lock one opponent card — it cannot be boosted this half." },
    { id = "ggg-bruiser",     name = "The Bruiser",       row = "defense",  power = 6,  rarity = "uncommon",  faction = "gegenpresse", ability = "REDUCE_ALL_OPPONENT_ATK_1_DEF",   abilityText = "Reduce all opponent attack row cards -1." },
    { id = "ggg-sweekeeper",  name = "The Sweeper Keeper",row = "defense",  power = 7,  rarity = "rare",      faction = "gegenpresse", ability = "REDUCE_TOP_OPPONENT_ATK_3",       abilityText = "Reduce the highest power card in opponent's attack row -3." },
    -- ── Strategy ──────────────────────────────────────────────────────────────
    { id = "ggg-highpress",   name = "High Press",        row = "strategy", power = nil, rarity = "strategy", faction = "gegenpresse", ability = "HIGH_PRESS",      abilityText = "Reduce all opponent cards in one row -2." },
    { id = "ggg-counterpress",name = "Counter Press",     row = "strategy", power = nil, rarity = "strategy", faction = "gegenpresse", ability = "COUNTER_PRESS",   abilityText = "When opponent passes, reduce all their cards in one row -1." },
    { id = "ggg-intensity",   name = "Intensity",         row = "strategy", power = nil, rarity = "strategy", faction = "gegenpresse", ability = "INTENSITY",       abilityText = "All your Gegenpresse cards +1 this half. All your cards -1 next half." },
    -- ── Traps ─────────────────────────────────────────────────────────────────
    { id = "ggg-presstrig",   name = "Press Trigger",     row = "trap",     power = nil, rarity = "trap",     faction = "gegenpresse", ability = "PRESS_TRIGGER",   abilityText = "Trigger: opponent plays any card. Effect: reduce it -2." },
    { id = "ggg-collpress",   name = "Collective Press",  row = "trap",     power = nil, rarity = "trap",     faction = "gegenpresse", ability = "COLLECTIVE_PRESS", abilityText = "Trigger: opponent plays 3rd card in a row. Effect: reduce all in that row -1." },
}

GG.leader = {
    id          = "ggg-leader-presser",
    name        = "The Presser",
    row         = "leader",
    faction     = "gegenpresse",
    ability     = "THE_PRESSER_LEADER",
    abilityText = "Reduce all opponent cards in one chosen row -2.",
}

return GG
