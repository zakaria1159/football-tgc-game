-- data/gwent_decks.lua
local NR = require("engine.cards.definitions.gwent_northern_realms")
local MN = require("engine.cards.definitions.gwent_monsters")

local function find(list, id)
    for _, c in ipairs(list) do if c.id == id then return c end end
    error("Gwent card not found: " .. id)
end

local function rep(card, n)
    local t = {}
    for _ = 1, n do table.insert(t, card) end
    return t
end

local function concat(...)
    local out = {}
    for _, t in ipairs({...}) do for _, v in ipairs(t) do table.insert(out, v) end end
    return out
end

local Decks = {}

-- ── Northern Realms — The Lions (25 cards) ───────────────────────────────────
Decks.northern_realms = {
    faction = "northern_realms",
    leader  = NR.leader,
    cards   = concat(
        -- Heroes (8)
        rep(find(NR.cards, "nr-legend"),    1),
        rep(find(NR.cards, "nr-prodigy"),   1),
        rep(find(NR.cards, "nr-architect"), 1),
        rep(find(NR.cards, "nr-revival"),   1),
        rep(find(NR.cards, "nr-captain"),   1),
        rep(find(NR.cards, "nr-king"),      1),
        rep(find(NR.cards, "nr-general"),   1),
        rep(find(NR.cards, "nr-eagle"),     1),
        -- Units (11)
        rep(find(NR.cards, "nr-scout"),     1),
        rep(find(NR.cards, "nr-striker"),   2),
        rep(find(NR.cards, "nr-runner"),    3),
        rep(find(NR.cards, "nr-marksman"),  1),
        rep(find(NR.cards, "nr-medic"),     1),
        rep(find(NR.cards, "nr-cannon"),    2),
        rep(find(NR.cards, "nr-tower"),     1),
        rep(find(NR.cards, "nr-engineer"),  1),
        -- Specials (6)
        rep(find(NR.cards, "nr-decoy"),     2),
        rep(find(NR.cards, "nr-horn"),      2),
        rep(find(NR.cards, "nr-scorch"),    1),
        rep(find(NR.cards, "nr-clear"),     1)
    ),
}

-- ── Monsters — The Wilds (22 cards) ─────────────────────────────────────────
Decks.monsters = {
    faction = "monsters",
    leader  = MN.leader,
    cards   = concat(
        -- Heroes (2)
        rep(find(MN.cards, "mn-enforcer"),  1),
        rep(find(MN.cards, "mn-phantom"),   1),
        -- Units (15)
        rep(find(MN.cards, "mn-ghoul"),     3),
        rep(find(MN.cards, "mn-horde"),     3),
        rep(find(MN.cards, "mn-seer"),      1),
        rep(find(MN.cards, "mn-witch"),     1),
        rep(find(MN.cards, "mn-oracle"),    1),
        rep(find(MN.cards, "mn-rider"),     3),
        rep(find(MN.cards, "mn-fogwalker"), 1),
        rep(find(MN.cards, "mn-devourer"),  1),
        -- Specials (5)
        rep(find(MN.cards, "mn-frost"),     1),
        rep(find(MN.cards, "mn-fog"),       1),
        rep(find(MN.cards, "mn-rain"),      1),
        rep(find(MN.cards, "mn-horn"),      1),
        rep(find(MN.cards, "mn-clear"),     1)
    ),
}

return Decks
