local T    = require("tests.t")
local Zoom = require("ui.match.zoom")

T.test("zoom goes right of the source when it fits", function()
    local p = Zoom.place({ x = 100, y = 300, w = 108, h = 148 }, 200, 1280, 800)
    T.eq(p.cardX, 222); T.eq(p.infoX, 536); T.eq(p.cardY, 169); T.eq(p.infoY, 169)
end)

T.test("zoom flips left near the right edge (card next to the source)", function()
    local p = Zoom.place({ x = 1112, y = 231, w = 108, h = 148 }, 200, 1280, 800)
    T.eq(p.infoX, 534); T.eq(p.cardX, 798)
    T.ok(p.cardX + Zoom.W <= 1112)
end)

T.test("zoom clamps vertically, leaving room for tag and badges", function()
    T.eq(Zoom.place({ x = 640, y = 640, w = 120, h = 165 }, 200, 1280, 800).cardY, 332)
    T.eq(Zoom.place({ x = 100, y = 0, w = 10, h = 10 }, 200, 1280, 800).cardY, 32)
end)

T.test("zoom goes above the source, centred, when opts.above is set", function()
    local p = Zoom.place({ x = 640, y = 600, w = 120, h = 165 }, 200, 1280, 800, { above = true })
    T.eq(p.infoX, 418); T.eq(p.cardX, 682)
    T.eq(p.cardY, 126); T.eq(p.infoY, 126)
    T.ok(p.cardY + Zoom.H + Zoom.BOTTOM_OVER <= 600)
end)

T.test("zoom clamps horizontally when neither side fits", function()
    local p = Zoom.place({ x = 400, y = 300, w = 500, h = 100 }, 200, 1280, 800)
    T.eq(p.infoX, 8); T.eq(p.cardX, 272)
end)

local function has(lines, text)
    for _, l in ipairs(lines) do if l.text == text then return true end end
    return false
end

T.test("a plain hand card has no status lines", function()
    T.eq(#Zoom.statusLines({ type = "striker", stats = { atk = 1, def = 1 } }, nil, nil), 0)
end)

T.test("pitched striker shows bonus, mode, exhausted and yellow cards", function()
    local def = { type = "striker", stats = { atk = 2000, def = 500 } }
    local pitched = { definition = def, slotType = "striker", mode = "attack", exhausted = true, yellowCards = 1 }
    local pitch = { defenders = {}, strikers = {},
        midfielder = { definition = { type = "midfielder", stats = { atk = 1500, def = 900 } }, mode = "attack" } }
    local lines = Zoom.statusLines(def, pitched, pitch)
    T.ok(has(lines, "ATK 2000 + 200 = 2200"))
    T.ok(has(lines, "Mode: ATTACK"))
    T.ok(has(lines, "EXHAUSTED"))
    T.ok(has(lines, "Yellow cards: 1"))
end)

T.test("pitched keeper shows effective DEF", function()
    local def = { type = "keeper", stats = { atk = 0, def = 1000 } }
    local keeper = { definition = def, slotType = "keeper", mode = "defense" }
    local pitch = { keeper = keeper, strikers = {},
        defenders = { { definition = { type = "defender", stats = { atk = 1, def = 1 } }, mode = "attack" } } }
    local lines = Zoom.statusLines(def, keeper, pitch)
    T.ok(has(lines, "Effective DEF 1000 + 300 = 1300"))
    T.ok(has(lines, "Mode: DEFENSE (face-down)"))
end)
