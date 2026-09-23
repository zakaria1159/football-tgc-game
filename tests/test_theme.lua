local T     = require("tests.t")
local Theme = require("ui.theme")

T.test("hex converts to 0..1 rgba", function()
    local c = Theme.hex("ff8000")
    T.near(c[1], 1); T.near(c[2], 128/255); T.near(c[3], 0); T.near(c[4], 1)
    T.near(Theme.hex("#000000", 0.5)[4], 0.5)
end)

T.test("every card type has a two-stop gradient and a label", function()
    for _, t in ipairs({ "striker", "defender", "midfielder", "keeper", "trap", "strategy", "formation" }) do
        local g = Theme.typeGrad[t]
        T.ok(g and g[1] and g[2], "missing typeGrad for " .. t)
        T.ok(Theme.typeLabel[t], "missing typeLabel for " .. t)
    end
end)

T.test("every rarity has a color", function()
    for _, r in ipairs({ "common", "uncommon", "rare", "legendary" }) do
        T.ok(Theme.rarityColors[r], "missing rarity " .. r)
    end
end)

T.test("card sizes match the spec", function()
    T.eq(Theme.cardSize.pitch.w, 108); T.eq(Theme.cardSize.pitch.h, 148)
    T.eq(Theme.cardSize.hand.w, 120);  T.eq(Theme.cardSize.hand.h, 165)
    T.eq(Theme.cardSize.zoom.w, 300);  T.eq(Theme.cardSize.zoom.h, 410)
end)

T.test("button variants have gradient, text and shadow colors", function()
    for _, v in ipairs({ "primary", "go", "danger", "neutral", "blue", "icon" }) do
        local b = Theme.button[v]
        T.ok(b and b.fill and b.text and b.shadow, "incomplete button variant " .. v)
    end
end)

T.test("overlay outcome colours and deck fills are two-stop gradients", function()
    for _, k in ipairs({ "red", "orange", "blue", "yellow", "grey", "purple" }) do
        local g = Theme.outcome[k]
        T.ok(g and g[1] and g[2], "missing outcome " .. k)
    end
    for _, k in ipairs({ "tikitaka", "longball", "catenaccio" }) do
        local g = Theme.deckFill[k]
        T.ok(g and g[1] and g[2], "missing deckFill " .. k)
    end
    T.near(Theme.dim[4], 0.72)
end)
