-- Dev-only: renders the card renderer at every size and state on the arcade background.
local Card  = require("ui.card")
local Draw  = require("ui.kit.draw")
local Theme = require("ui.theme")

local defs = {}
for _, f in ipairs({ "strikers", "defenders", "midfielders", "keepers", "traps", "strategies" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do defs[#defs + 1] = d end
end
local function pick(pred) for _, d in ipairs(defs) do if pred(d) then return d end end end
local rare   = pick(function(d) return d.type == "striker" and d.rarity == "rare" end) or defs[1]
local def    = pick(function(d) return d.type == "defender" end)
local mid    = pick(function(d) return d.type == "midfielder" end)
local keeper = pick(function(d) return d.type == "keeper" end)
local trap   = pick(function(d) return d.type == "trap" end)
local strat  = pick(function(d) return d.type == "strategy" end)

local G = {}
function G.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    Draw.background(W, H)
    -- Row 1: pitch size, all types + states
    local x, y = 30, 40
    for _, d in ipairs({ rare, def, mid, keeper, trap, strat }) do
        Card.drawFace(d, x, y, 108, 148, {}); x = x + 130
    end
    Card.drawFace(rare, x, y, 108, 148, { selected = true }); x = x + 130
    Card.drawFace(def, x, y, 108, 148, { target = true }); x = x + 130
    Card.drawFace(rare, x, y, 108, 148, { exhausted = true, atkBonus = 200 })
    -- Row 2: backs, bonuses, hand size, legacy small sizes
    x, y = 30, 230
    Card.drawBack(x, y, 108, 148, { label = "DEF" }); x = x + 130
    Card.drawBack(x, y, 108, 148, { label = "DEF", canFlip = true }); x = x + 130
    Card.drawFace(def, x, y, 108, 148, { defBonus = 300 }); x = x + 140
    Card.drawFace(rare, x, y, 120, 165, { selected = true }); x = x + 150
    Card.drawFace(keeper, x, y, 84, 106, {}); x = x + 110
    Card.drawFace(mid, x, y, 68, 80, {}); x = x + 90
    Card.drawInfo(rare, x, y, 230)
    -- Row 3: zoom size + info
    Card.drawFace(rare, 30, 430, 250, 342, {})
    Card.drawInfo(rare, 300, 430, 300)
    Draw.pill(640, 440, 180, 32, "SUMMONS 1 / 2", {})
    local Button = require("ui.kit.button")
    for i, v in ipairs({ "primary", "go", "danger", "neutral" }) do
        local b = Button.new({ label = string.upper(v), variant = v, x = 640 + ((i - 1) % 2) * 200, y = 500 + math.floor((i - 1) / 2) * 80, w = 180, h = 56 })
        b:draw()
    end
    local ib = Button.new({ icon = "whistle", variant = "icon", x = 1060, y = 500, w = 48, h = 48 }); ib:draw()
    Draw.ribbon(840, 680, 360, 48, "MIDFIELD CONTROL +1", { fill = Theme.button.primary.fill, textColor = Theme.button.primary.text })
end

-- Keyword pills: all 24 field cards at small size, then hand, pitch states and zoom + info.
function G.drawKeywords()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    Draw.background(W, H)
    local field = {}
    for _, d in ipairs(defs) do
        if d.type == "striker" or d.type == "midfielder" or d.type == "defender" or d.type == "keeper" then
            field[#field + 1] = d
        end
    end
    for i, d in ipairs(field) do
        local col, row = (i - 1) % 12, math.floor((i - 1) / 12)
        Card.drawFace(d, 30 + col * 102, 30 + row * 150, 84, 106, {})
    end
    local function byId(id) return pick(function(d) return d.id == id end) end
    local y = 340
    Card.drawFace(byId("str-speed-demon"), 30, y, 120, 165, { badges = "left" })
    Card.drawPitched({ definition = byId("keeper-the-wall"), mode = "defense", revealed = true,
                       slotType = "keeper", exhausted = true }, 180, y, {})
    Card.drawPitched({ definition = byId("def-libero"), mode = "defense", revealed = true,
                       slotType = "defender" }, 310, y, { canFlip = true })
    Card.drawFace(byId("mid-pressing-monster"), 440, y, 68, 80, {})
    -- Right of the pitch states, sized so the info sticker stays on screen.
    Card.drawLarge(byId("mid-creative-playmaker"), 1010, 305, 220)
end

return G
