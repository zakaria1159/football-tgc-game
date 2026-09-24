local T          = require("tests.t")
local DeckSelect = require("ui.menu.deckselect")

T.test("deck tiles are equal, centred, evenly spaced and clear of title and buttons", function()
    local n = #DeckSelect.DECKS
    T.eq(n, 3)
    local first, last = DeckSelect.tileRect(1), DeckSelect.tileRect(n)
    T.near((first.x + last.x + last.w) / 2, 640)
    for i = 2, n do
        local a, b = DeckSelect.tileRect(i - 1), DeckSelect.tileRect(i)
        T.eq(b.w, a.w); T.near(b.x - (a.x + a.w), DeckSelect.GAP)
    end
    local F, Ti = DeckSelect.FAN, DeckSelect.TITLE
    for i = 1, n do
        local r = DeckSelect.tileRect(i)
        T.ok(r.y + r.h < DeckSelect.BACK.y - 40, "tile " .. i .. " too low")
        T.ok(r.y + F.bottom - F.h - DeckSelect.LIFT > Ti.y + Ti.h + 4, "fanned cards would hit the title")
    end
    T.ok(DeckSelect.BACK.x + DeckSelect.BACK.w < DeckSelect.KICKOFF.x)
    T.ok(DeckSelect.KICKOFF.x + DeckSelect.KICKOFF.w <= 1280 and DeckSelect.KICKOFF.y + DeckSelect.KICKOFF.h <= 800)
end)

T.test("hitAt maps tiles and buttons", function()
    for i = 1, 3 do
        local r = DeckSelect.tileRect(i)
        T.eq(DeckSelect.hitAt(r.x + r.w / 2, r.y + r.h / 2), i)
    end
    local b, k = DeckSelect.BACK, DeckSelect.KICKOFF
    T.eq(DeckSelect.hitAt(b.x + 5, b.y + 5), "back")
    T.eq(DeckSelect.hitAt(k.x + k.w - 5, k.y + k.h - 5), "kickoff")
    T.eq(DeckSelect.hitAt(640, 20), nil)
end)

T.test("showcase: three distinct field cards, rarest in the centre", function()
    local cards = {
        { id = "a", type = "striker",    rarity = "common" },
        { id = "t", type = "trap",       rarity = "legendary" },
        { id = "b", type = "keeper",     rarity = "rare" },
        { id = "b", type = "keeper",     rarity = "rare" },
        { id = "c", type = "defender",   rarity = "uncommon" },
        { id = "d", type = "midfielder", rarity = "common" },
    }
    local s = DeckSelect.showcase(cards)
    T.eq(#s, 3)
    T.eq(s[1].id, "c"); T.eq(s[2].id, "b"); T.eq(s[3].id, "a")
end)

T.test("every preset deck has a showcase of three distinct cards", function()
    local Decks = require("data.presetDecks")
    for _, d in ipairs(DeckSelect.DECKS) do
        local deck = Decks[d.key]
        T.ok(deck, "no preset deck " .. d.key)
        local s = DeckSelect.showcase(deck.cards)
        T.eq(#s, 3, d.key)
        T.ok(s[1].id ~= s[2].id and s[2].id ~= s[3].id and s[1].id ~= s[3].id, d.key .. " repeats a card")
    end
end)
