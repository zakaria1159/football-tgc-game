local T     = require("tests.t")
local Stats = require("ui.match.stats")

local function mid(mode, atk, def, ctype)
    return { definition = { type = ctype or "midfielder", stats = { atk = atk, def = def } }, mode = mode }
end
local function match(pMid, oMid)
    return { summonCount = 0, players = {
        player   = { pitch = { midfielder = pMid, defenders = {}, strikers = {}, traps = {} } },
        opponent = { pitch = { midfielder = oMid, defenders = {}, strikers = {}, traps = {} } },
    } }
end

T.test("crown goes to the midfielder with more power", function()
    T.eq(Stats.crownOwner(match(mid("attack", 1500, 800), mid("attack", 1200, 700))), "player")
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("attack", 1200, 700))), "opponent")
end)

T.test("opponent's face-down midfielder hides the crown (unknown), even if it would win or lose", function()
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("defense", 700, 1200))), nil, "would win")
    T.eq(Stats.crownOwner(match(mid("attack", 1500, 800), mid("defense", 700, 100))), nil, "would lose")
    -- the player's own face-down midfielder still counts — they know their own card
    T.eq(Stats.crownOwner(match(mid("defense", 700, 1200), mid("attack", 1000, 800))), "player")
end)

T.test("any unrevealed face-down card in the opponent's midfield slot hides the crown", function()
    -- A face-down defender there has 0 power; showing the crown would leak its type.
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("defense", 700, 1200, "defender"))), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("defense", 700, 1200, "striker"))), nil)
    -- Once revealed it is known: a revealed non-midfielder has no power.
    local revealed = mid("defense", 700, 1200, "defender"); revealed.revealed = true
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), revealed)), "player")
end)

T.test("no crown on a tie or without real midfielders", function()
    T.eq(Stats.crownOwner(match(nil, nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0, "striker"), nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0), mid("attack", 1000, 0))), nil)
end)

T.test("summons reads the player's limit (Time Wasting) and has no midfield bonus", function()
    local m = match(nil, nil)
    m.summonCount = 1
    m.players.player.nextTurnSummonLimit = 1
    local used, max, extra = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 1); T.eq(extra, nil)
    m.players.player.nextTurnSummonLimit = nil
    used, max = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 2)
end)
