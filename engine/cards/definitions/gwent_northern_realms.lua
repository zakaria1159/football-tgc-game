-- engine/cards/definitions/gwent_northern_realms.lua
local NR = {}

NR.cards = {
    -- ── Heroes (immune to everything) ────────────────────────────────────────
    { id = "nr-legend",    name = "The Legend",    row = "attack",   power = 15, hero = true,  faction = "northern_realms",
      abilityText = "Hero. Immune to abilities and weather." },
    { id = "nr-prodigy",   name = "The Prodigy",   row = "attack",   power = 15, hero = true,  faction = "northern_realms", ability = "AGILITY",
      abilityText = "Hero. Agility: place in any row." },
    { id = "nr-architect", name = "The Architect", row = "attack",   power = 7,  hero = true,  faction = "northern_realms",
      abilityText = "Hero. Immune to abilities and weather." },
    { id = "nr-revival",   name = "The Revival",   row = "midfield", power = 7,  hero = true,  faction = "northern_realms", ability = "MEDIC",
      abilityText = "Hero. Medic: choose a non-hero card from your graveyard and play it." },
    { id = "nr-captain",   name = "The Captain",   row = "attack",   power = 10, hero = true,  faction = "northern_realms",
      abilityText = "Hero. Immune to abilities and weather." },
    { id = "nr-king",      name = "The King",      row = "attack",   power = 10, hero = true,  faction = "northern_realms",
      abilityText = "Hero. Immune to abilities and weather." },
    { id = "nr-general",   name = "The General",   row = "attack",   power = 10, hero = true,  faction = "northern_realms", ability = "COMMANDERS_HORN_SELF",
      abilityText = "Hero. Activates Commander's Horn on your attack row when played." },
    { id = "nr-eagle",     name = "The Eagle",     row = "midfield", power = 10, hero = true,  faction = "northern_realms",
      abilityText = "Hero. Immune to abilities and weather." },

    -- ── Units ────────────────────────────────────────────────────────────────
    { id = "nr-scout",     name = "The Scout",     row = "midfield", power = 0,  hero = false, faction = "northern_realms", ability = "SPY",
      abilityText = "Spy: goes to opponent's side. You draw 2 cards." },
    { id = "nr-striker",   name = "The Striker",   row = "attack",   power = 4,  hero = false, faction = "northern_realms", ability = "TIGHT_BOND",
      abilityText = "Tight Bond: power multiplied by number of copies in this row." },
    { id = "nr-runner",    name = "The Runner",    row = "attack",   power = 1,  hero = false, faction = "northern_realms", ability = "TIGHT_BOND",
      abilityText = "Tight Bond: power multiplied by number of copies in this row." },
    { id = "nr-marksman",  name = "The Marksman",  row = "midfield", power = 5,  hero = false, faction = "northern_realms", ability = "TIGHT_BOND",
      abilityText = "Tight Bond: power multiplied by number of copies in this row." },
    { id = "nr-medic",     name = "The Medic",     row = "midfield", power = 5,  hero = false, faction = "northern_realms", ability = "MEDIC",
      abilityText = "Medic: choose a non-hero card from your graveyard and play it." },
    { id = "nr-cannon",    name = "The Cannon",    row = "defense",  power = 8,  hero = false, faction = "northern_realms", ability = "TIGHT_BOND",
      abilityText = "Tight Bond: power multiplied by number of copies in this row." },
    { id = "nr-tower",     name = "The Tower",     row = "defense",  power = 6,  hero = false, faction = "northern_realms",
      abilityText = "No ability." },
    { id = "nr-engineer",  name = "The Engineer",  row = "defense",  power = 6,  hero = false, faction = "northern_realms", ability = "MORALE_BOOST",
      abilityText = "Morale Boost: +1 to all other cards in this row." },

    -- ── Special cards (row = "special", consumed on play) ────────────────────
    { id = "nr-decoy",     name = "Decoy",              row = "special", power = nil, faction = "northern_realms", ability = "DECOY",
      abilityText = "Return one of your non-hero pitched cards to your hand." },
    { id = "nr-horn",      name = "Commander's Horn",   row = "special", power = nil, faction = "northern_realms", ability = "COMMANDERS_HORN",
      abilityText = "Double power of all non-hero cards in one of your rows this half." },
    { id = "nr-scorch",    name = "Scorch",             row = "special", power = nil, faction = "northern_realms", ability = "SCORCH",
      abilityText = "Destroy all non-hero cards tied at the highest power on the battlefield." },
    { id = "nr-clear",     name = "Clear Weather",      row = "special", power = nil, faction = "northern_realms", ability = "CLEAR_WEATHER",
      abilityText = "Remove all weather effects from the battlefield." },
}

NR.leader = {
    id          = "nr-leader",
    name        = "The Commander",
    row         = "leader",
    faction     = "northern_realms",
    ability     = "NR_LEADER_DRAW",
    abilityText = "Draw 1 card from your deck.",
}

return NR
