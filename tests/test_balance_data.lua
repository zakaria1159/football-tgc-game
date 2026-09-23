local T     = require("tests.t")
local Decks = require("data.presetDecks")

local function byId(file)
    local t = {}
    for _, c in ipairs(require("engine.cards.definitions." .. file)) do t[c.id] = c end
    return t
end

T.test("balance: striker ATK curve", function()
    local s = byId("strikers")
    local want = {
        ["str-target-man"] = 2200, ["str-speed-demon"] = 2150, ["str-complete-forward"] = 2150,
        ["str-fox-in-the-box"] = 2150, ["str-poacher"] = 2100, ["str-pressing-forward"] = 2100,
        ["str-pacy-winger"] = 2050, ["str-clinical-finisher"] = 2300,
    }
    for id, atk in pairs(want) do T.eq(s[id].stats.atk, atk, id) end
end)

T.test("balance: keeper DEF rises with rarity", function()
    local k = byId("keepers")
    T.eq(k["keeper-reliable-hands"].stats.def, 1750)
    T.eq(k["keeper-sweeper-keeper"].stats.def, 1800)
    T.eq(k["keeper-iron-fists"].stats.def, 1900)
    T.eq(k["keeper-the-wall"].stats.def, 2000)
end)

local function count(deck)
    local n = {}
    for _, c in ipairs(deck.cards) do n[c.id] = (n[c.id] or 0) + 1 end
    return n
end

T.test("balance: Tiki-Taka swaps a Sweeper Keeper and two Deep-Lying Playmakers", function()
    local n = count(Decks.tikitaka)
    T.eq(n["keeper-sweeper-keeper"], 1); T.eq(n["keeper-iron-fists"], 1); T.eq(n["keeper-reliable-hands"], 1)
    T.eq(n["mid-deep-lying-playmaker"], 1)
    T.eq(n["str-complete-forward"], 3); T.eq(n["str-speed-demon"], 2)
end)

T.test("balance: every preset deck has 40 cards", function()
    for key, d in pairs(Decks) do T.eq(#d.cards, 40, key) end
end)
