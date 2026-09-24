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

T.test("revealed UI: the switch ribbon mirrors the engine rule — never keepers, only the owner's own summon phase", function()
    local own = { isOwnTurn = true, phase = "summon" }
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", own), "FLIP UP")
    T.eq(Card.switchLabel(pc("defender", "defense", true), "defender", own), "TO ATTACK")
    -- Keepers never switch, even revealed and otherwise eligible.
    T.eq(Card.switchLabel(pc("keeper", "defense", true), "keeper", own), nil)
    -- Attack mode: it may go to face-up defense.
    T.eq(Card.switchLabel(pc("defender", "attack"), "defender", own), "TO DEFENSE")
    local exhausted = pc("defender", "defense"); exhausted.exhausted = true
    T.eq(Card.switchLabel(exhausted, "defender", own), nil)
    local fresh = pc("defender", "defense"); fresh.summonedThisTurn = true
    T.eq(Card.switchLabel(fresh, "defender", own), nil)
    local flipped = pc("defender", "defense"); flipped.modeChanged = true
    T.eq(Card.switchLabel(flipped, "defender", own), nil)
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", { isOwnTurn = true, phase = "attack" }), nil)
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", { isOwnTurn = false, phase = "summon" }), nil)
    T.eq(Card.switchLabel(pc("trap", "defense", false, "trap"), "trap", own), nil)
end)

T.test("revealed UI: the zoom says the card is revealed", function()
    local c = pc("defender", "defense", true)
    local lines = Zoom.statusLines(c.definition, c, { defenders = {}, strikers = {} })
    local found = false
    for _, l in ipairs(lines) do if l.text == "Mode: DEFENSE (revealed)" then found = true end end
    T.ok(found)
end)
