-- engine/cards/definitions/gwent_monsters.lua
local MN = {}

MN.cards = {
    -- ── Heroes ───────────────────────────────────────────────────────────────
    { id = "mn-enforcer", name = "The Enforcer", row = "attack",  power = 10, hero = true, faction = "monsters",
      abilityText = "Hero. Immune to abilities and weather." },
    { id = "mn-phantom",  name = "The Phantom",  row = "defense", power = 8,  hero = true, faction = "monsters", ability = "WEATHER_SUMMON",
      abilityText = "Hero. Summons Torrential Rain when deployed." },

    -- ── Units ────────────────────────────────────────────────────────────────
    -- Muster group: ghouls (all 3 copies share musterGroup)
    { id = "mn-ghoul",    name = "The Ghoul",    row = "attack",   power = 2, hero = false, faction = "monsters", ability = "MUSTER", musterGroup = "ghouls",
      abilityText = "Muster: summons all Ghouls from hand and deck." },
    -- Muster group: horde
    { id = "mn-horde",    name = "The Horde",    row = "attack",   power = 4, hero = false, faction = "monsters", ability = "MUSTER", musterGroup = "horde",
      abilityText = "Muster: summons all Horde from hand and deck." },
    -- Muster group: sisters (3 different cards, different rows, same musterGroup)
    { id = "mn-seer",     name = "The Seer",     row = "attack",   power = 5, hero = false, faction = "monsters", ability = "MUSTER", musterGroup = "sisters",
      abilityText = "Muster: summons all Sisters from hand and deck." },
    { id = "mn-witch",    name = "The Witch",    row = "midfield", power = 5, hero = false, faction = "monsters", ability = "MUSTER", musterGroup = "sisters",
      abilityText = "Muster: summons all Sisters from hand and deck." },
    { id = "mn-oracle",   name = "The Oracle",   row = "defense",  power = 5, hero = false, faction = "monsters", ability = "MUSTER", musterGroup = "sisters",
      abilityText = "Muster: summons all Sisters from hand and deck." },
    -- Tight Bond
    { id = "mn-rider",    name = "The Rider",    row = "attack",   power = 4, hero = false, faction = "monsters", ability = "TIGHT_BOND",
      abilityText = "Tight Bond: power multiplied by number of copies in this row." },
    -- Special unit abilities
    { id = "mn-fogwalker",name = "The Fogwalker",row = "midfield", power = 2, hero = false, faction = "monsters", ability = "FOG_BONUS",
      abilityText = "+2 power while Impenetrable Fog is active." },
    { id = "mn-devourer", name = "The Devourer", row = "attack",   power = 4, hero = false, faction = "monsters", ability = "DEVOUR",
      abilityText = "Gains +1 power for each card in your graveyard when played." },

    -- ── Special cards ────────────────────────────────────────────────────────
    { id = "mn-frost",    name = "Biting Frost",       row = "special", power = nil, faction = "monsters", ability = "WEATHER_FROST",
      abilityText = "All attack row cards reduced to 1 power (both sides)." },
    { id = "mn-fog",      name = "Impenetrable Fog",   row = "special", power = nil, faction = "monsters", ability = "WEATHER_FOG",
      abilityText = "All midfield row cards reduced to 1 power (both sides)." },
    { id = "mn-rain",     name = "Torrential Rain",    row = "special", power = nil, faction = "monsters", ability = "WEATHER_RAIN",
      abilityText = "All defense row cards reduced to 1 power (both sides)." },
    { id = "mn-horn",     name = "Commander's Horn",   row = "special", power = nil, faction = "monsters", ability = "COMMANDERS_HORN",
      abilityText = "Double power of all non-hero cards in one of your rows this half." },
    { id = "mn-clear",    name = "Clear Weather",      row = "special", power = nil, faction = "monsters", ability = "CLEAR_WEATHER",
      abilityText = "Remove all weather effects from the battlefield." },
}

MN.leader = {
    id          = "mn-leader",
    name        = "The Predator",
    row         = "leader",
    faction     = "monsters",
    ability     = "MN_LEADER_WEATHER",
    abilityText = "Play a random weather card.",
}

return MN
