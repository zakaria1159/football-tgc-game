local T     = require("tests.t")
local Card  = require("ui.card")
local Hover = require("ui.match.hover")
local Stats = require("ui.match.stats")
local Zoom  = require("ui.match.zoom")

local function pc(ctype, mode, revealed, slotType)
    return { definition = { type = ctype, stats = { atk = 1500, def = 1700 } }, mode = mode,
             revealed = revealed, slotType = slotType or ctype }
end

T.test("revealed UI: a revealed defense card shows its face; face-down cards and traps don't", function()
    T.eq(Card.showsFace(pc("defender", "attack")), true)
    T.eq(Card.showsFace(pc("defender", "defense")), false)
    T.eq(Card.showsFace(pc("defender", "defense", true)), true)
    T.eq(Card.showsFace(pc("trap", "defense", false, "trap")), false)
end)

T.test("revealed UI: the opponent's revealed cards are zoomable; hidden ones and traps are not", function()
    T.eq(Hover.zoomable("opponent", "defender", pc("defender", "defense", true)), true)
    T.eq(Hover.zoomable("opponent", "defender", pc("defender", "defense")), false)
    T.eq(Hover.zoomable("opponent", "trap", pc("trap", "defense", false, "trap")), false)
    T.eq(Hover.zoomable("player", "defender", pc("defender", "defense")), true)
    T.eq(Hover.zoomable("player", "trap", pc("trap", "defense", false, "trap")), true)
    T.eq(Hover.zoomable("opponent", "striker", nil), false)
end)

T.test("revealed UI: the crown uses the opponent's revealed defense-mode midfielder", function()
    local m = { players = {
        player   = { pitch = { midfielder = pc("midfielder", "attack"), defenders = {}, strikers = {}, traps = {} } },
        opponent = { pitch = { midfielder = pc("midfielder", "defense", true), defenders = {}, strikers = {}, traps = {} } },
    } }
    T.eq(Stats.crownOwner(m), "opponent")   -- 1700 DEF vs 1500 ATK
end)

T.test("revealed UI: canFlip mirrors the engine rule — never keepers, only the owner's own summon phase", function()
    local own = { isOwnTurn = true, phase = "summon" }
    T.eq(Card.canFlip(pc("defender", "defense"), "defender", own), true)
    -- Keepers never flip, even revealed and otherwise eligible.
    T.eq(Card.canFlip(pc("keeper", "defense", true), "keeper", own), false)
    -- Already in attack mode.
    T.eq(Card.canFlip(pc("defender", "attack"), "defender", own), false)
    -- Exhausted.
    local exhausted = pc("defender", "defense")
    exhausted.exhausted = true
    T.eq(Card.canFlip(exhausted, "defender", own), false)
    -- Summoned this turn.
    local fresh = pc("defender", "defense")
    fresh.summonedThisTurn = true
    T.eq(Card.canFlip(fresh, "defender", own), false)
    -- Already flipped this turn.
    local flipped = pc("defender", "defense")
    flipped.modeChanged = true
    T.eq(Card.canFlip(flipped, "defender", own), false)
    -- Wrong phase.
    T.eq(Card.canFlip(pc("defender", "defense"), "defender", { isOwnTurn = true, phase = "attack" }), false)
    -- Not the owner's turn.
    T.eq(Card.canFlip(pc("defender", "defense"), "defender", { isOwnTurn = false, phase = "summon" }), false)
    -- Traps never flip.
    T.eq(Card.canFlip(pc("trap", "defense", false, "trap"), "trap", own), false)
end)

T.test("revealed UI: the zoom says the card is revealed", function()
    local c = pc("defender", "defense", true)
    local lines = Zoom.statusLines(c.definition, c, { defenders = {}, strikers = {} })
    local found = false
    for _, l in ipairs(lines) do if l.text == "Mode: DEFENSE (revealed)" then found = true end end
    T.ok(found)
end)
