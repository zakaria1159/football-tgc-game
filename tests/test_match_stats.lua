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
    T.eq(Stats.crownOwner(match(mid("attack", 1500, 800), mid("defense", 700, 1200))), "player")
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("defense", 700, 1200))), "opponent")
end)

T.test("no crown on a tie or without real midfielders", function()
    T.eq(Stats.crownOwner(match(nil, nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0, "striker"), nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0), mid("attack", 1000, 0))), nil)
end)

T.test("summons reads the player's limit and flags the midfield bonus", function()
    local m = match(nil, nil)
    m.summonCount = 1
    m.players.player.nextTurnSummonLimit = 3
    local used, max, bonus = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 3); T.eq(bonus, true)
    m.players.player.nextTurnSummonLimit = nil
    used, max, bonus = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 2); T.eq(bonus, false)
end)
