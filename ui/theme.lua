-- All colors and visual constants (arcade style).
local Theme = {}

local function hex(s, a)
    s = s:gsub("#", "")
    return {
        tonumber(s:sub(1, 2), 16) / 255,
        tonumber(s:sub(3, 4), 16) / 255,
        tonumber(s:sub(5, 6), 16) / 255,
        a or 1,
    }
end
Theme.hex = hex

Theme.ink     = hex("1d1d59")   -- outlines, hard drop shadows
Theme.inkText = hex("2b2b6b")   -- dark text on white
Theme.white   = { 1, 1, 1, 1 }

Theme.bg = { top = hex("3d7cff"), bottom = hex("6b4dff") }

Theme.grad = {
    atk   = { hex("ff6a6a"), hex("e0243a") },
    def   = { hex("6ac8ff"), hex("1f78e0") },
    lpYou = { hex("7dff8a"), hex("2ec44a") },
    lpOpp = { hex("ff8a8a"), hex("e0243a") },
    bonus = { hex("7dff8a"), hex("22b347") },
    keyword = { hex("fff3a8"), hex("ffc93a") },   -- ability keyword pills and tags
}

Theme.highlight = {
    selected = hex("ffe14a"),
    target   = hex("ff4a4a"),
    valid    = { 1, 1, 1, 1 },
}

Theme.button = {
    primary = { fill = { hex("ffd23a"), hex("ff9a1a") }, text = hex("5a2a00"), shadow = hex("a14e00") },
    go      = { fill = { hex("7dff8a"), hex("22b347") }, text = { 1, 1, 1, 1 }, shadow = hex("137a2e") },
    danger  = { fill = { hex("ff8a8a"), hex("e0243a") }, text = { 1, 1, 1, 1 }, shadow = hex("8f1026") },
    neutral = { fill = { hex("ffffff"), hex("dfe3f0") }, text = hex("2b2b6b"), shadow = hex("1d1d59") },
    blue    = { fill = { hex("6ac8ff"), hex("1f78e0") }, text = { 1, 1, 1, 1 }, shadow = hex("0f4a9a") },
    icon    = { fill = { { 1, 1, 1, 0.18 }, { 1, 1, 1, 0.10 } }, text = { 1, 1, 1, 1 }, shadow = { 0.114, 0.114, 0.349, 0.6 } },
}

Theme.typeGrad = {
    striker    = { hex("ff7a59"), hex("e8344a") },
    defender   = { hex("4fb8ff"), hex("2563eb") },
    midfielder = { hex("6ee7a0"), hex("16a34a") },
    keeper     = { hex("ffc15a"), hex("ea7a0c") },
    trap       = { hex("c77dff"), hex("7b2cbf") },
    strategy   = { hex("5eead4"), hex("0f9488") },
    formation  = { hex("ffe08a"), hex("d4a017") },
}

Theme.typeLabel = {
    striker = "STRIKER", defender = "DEFENDER", midfielder = "MIDFIELD", keeper = "KEEPER",
    trap = "TRAP", strategy = "STRATEGY", formation = "FORMATION",
}

Theme.rarityColors = {
    common    = hex("cfd6e6"),
    uncommon  = hex("5eead4"),
    rare      = hex("ffc93a"),
    legendary = hex("ff5ec8"),
}

Theme.cardBack = { hex("35358a"), hex("22226a") }

Theme.cardSize = {
    pitch = { w = 108, h = 148 },
    hand  = { w = 120, h = 165 },
    zoom  = { w = 300, h = 410 },
}

-- Result ribbons, trap purple, match-end grey (overlays).
Theme.outcome = {
    red    = { hex("ff8a8a"), hex("e0243a") },
    orange = { hex("ffc15a"), hex("f07a0c") },
    blue   = { hex("6ac8ff"), hex("1f78e0") },
    yellow = { hex("ffd23a"), hex("ff9a1a") },
    grey   = { hex("d7dcea"), hex("8f99b5") },
    purple = { hex("c77dff"), hex("7b2cbf") },
}

-- Tired cards (stamina 0): red rim, pale badge interior and red numbers, the TIRED pill, the
-- sweat drop, and the last stamina pip's warning colour.
Theme.tired = {
    number = hex("e0243a"),
    fill   = hex("f4f5fb"),
    pill   = { hex("ff8a8a"), hex("e0243a") },
    sweat  = hex("4fb8ff"),
    low    = hex("ffc15a"),
}

-- Deck-select tiles (keys match data/presetDecks.lua).
Theme.deckFill = {
    tikitaka   = { hex("6ee7a0"), hex("16a34a") },
    longball   = { hex("ff7a59"), hex("e0243a") },
    catenaccio = { hex("4fb8ff"), hex("2563eb") },
}

-- Navy dim behind menus and overlays.
Theme.dim = hex("1d1d59", 0.72)

return Theme
