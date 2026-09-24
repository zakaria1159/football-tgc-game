local T    = require("tests.t")
local Card = require("ui.card")

local function card(ctype, atk, def, slotType, mode)
    return { definition = { type = ctype, stats = { atk = atk, def = def } },
             slotType = slotType or ctype, mode = mode or "attack" }
end

T.test("keeper bonus is effective DEF minus base DEF", function()
    local k = card("keeper", 0, 1000)
    local pitch = { keeper = k, defenders = { card("defender", 800, 1200) },
                    midfielder = card("midfielder", 1500, 900), strikers = {} }
    local a, d = Card.bonuses(k, pitch)
    T.eq(a, 0); T.eq(d, 450)   -- +300 defender, +150 midfielder
end)

T.test("midfielder boosts strikers in attack mode and defenders in defense mode", function()
    local atkPitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900, nil, "attack") }
    local defPitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900, nil, "defense") }
    local s, d = card("striker", 2000, 500), card("defender", 800, 1200)
    local a1, d1 = Card.bonuses(s, atkPitch); T.eq(a1, 200); T.eq(d1, 0)
    local a2, d2 = Card.bonuses(d, atkPitch); T.eq(a2, 0);   T.eq(d2, 0)
    local a3, d3 = Card.bonuses(d, defPitch); T.eq(a3, 0);   T.eq(d3, 200)
end)

T.test("no pitch or a trap gives no bonus", function()
    local a, d = Card.bonuses(card("striker", 2000, 500), nil); T.eq(a, 0); T.eq(d, 0)
    local pitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900) }
    a, d = Card.bonuses(card("trap", 0, 0, "trap", "defense"), pitch); T.eq(a, 0); T.eq(d, 0)
end)
