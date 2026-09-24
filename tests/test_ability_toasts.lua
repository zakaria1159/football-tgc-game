local T        = require("tests.t")
local Toasts   = require("ui.match.toasts")
local Resolver = require("engine.cards.resolver")

local function ability(player, keyword, name, hidden)
    return { type = "ability_triggered",
             payload = { player = player, keyword = keyword, name = name, hidden = hidden } }
end

T.test("ability toasts: yours are good, the opponent's bad, with the card name", function()
    local txt, kind = Toasts.describe(ability("player", "PACE", "Speed Demon"))
    T.eq(txt, "Pace: Speed Demon attacks at once"); T.eq(kind, "good")
    txt, kind = Toasts.describe(ability("opponent", "PUNCH_CLEAR", "Iron Fists"))
    T.eq(txt, "Punch clear! Iron Fists"); T.eq(kind, "bad")
end)

T.test("ability toasts: the opponent's face-down card is not named", function()
    local txt = Toasts.describe(ability("opponent", "PRESS", "Pressing Forward", true))
    T.eq(txt, "Press: a face-down card presses a defender")
    txt = Toasts.describe(ability("player", "PRESS", "Pressing Forward", true))
    T.eq(txt, "Press: Pressing Forward presses a defender")
end)

T.test("ability toasts: always-on stat bonuses stay quiet; every other keyword has a text", function()
    for _, kw in ipairs(Resolver.ORDER) do
        local txt = Toasts.describe(ability("player", kw, "Card X"))
        if Toasts.QUIET[kw] then
            T.eq(txt, nil, kw)
        else
            T.ok(type(txt) == "string" and txt:find("Card X", 1, true) ~= nil, kw)
        end
    end
end)
