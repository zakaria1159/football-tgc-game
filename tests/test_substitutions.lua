local T      = require("tests.t")
local H      = require("tests.helpers")
local C      = require("engine.constants")
local State  = require("engine.state")
local Phases = require("engine.phases")
local Stats  = require("ui.match.stats")
local Layout = require("ui.match.layout")
local Toasts = require("ui.match.toasts")

local function inHand(m, owner, def)
    for _, c in ipairs(m.players[owner].hand) do if c == def then return true end end
    return false
end

-- The player's summon phase: a striker on the pitch, another in hand.
local function subMatch()
    local m = H.match({ phase = "summon" })
    local out = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local inn = H.give(m, "player", H.card("striker", 2200, 600))
    return m, out, inn
end

T.test("substitution: onto an occupied slot — uses a summon and a sub; the old card goes back to hand", function()
    local m, out, inn = subMatch()
    local s = H.store(m)
    T.eq(s:summonCard(inn.id, "striker", 1, "attack"), true)
    T.eq(m.summonCount, 1); T.eq(m.players.player.subsUsed, 1)
    local now = m.players.player.pitch.strikers[1]
    T.eq(now.definition, inn); T.eq(now.mode, "attack")
    T.ok(inHand(m, "player", out.definition)); T.ok(not inHand(m, "player", inn))
    local e = H.events(m, "card_played")
    T.eq(#e, 1); T.eq(e[1].payload.action, "substitution")
    T.eq(e[1].payload.replaced, out.definition.id); T.eq(e[1].payload.name, inn.name)
end)

T.test("substitution: the incoming card waits a turn to attack (Pace excepted) and can't switch", function()
    local m, _, inn = subMatch()
    H.store(m):summonCard(inn.id, "striker", 1, "attack")
    local now = m.players.player.pitch.strikers[1]
    T.eq(Phases.canAttackNow(now), false)
    T.eq((Phases.canSwitch(now, "striker", { isOwnTurn = true, phase = "summon" })), nil)
    local m2 = H.match({ phase = "summon" })
    H.place(m2, "player", "striker", 1, H.card("striker", 2000, 500))
    local pace = H.give(m2, "player", H.kw("PACE", "striker", 2150, 550))
    H.store(m2):summonCard(pace.id, "striker", 1, "attack")
    T.eq(Phases.canAttackNow(m2.players.player.pitch.strikers[1]), true)
end)

T.test("substitution: the incoming card is fully rested; the outgoing one is too when it comes back", function()
    local m, out, inn = subMatch()
    out.stamina = 0
    local s = H.store(m)
    s:summonCard(inn.id, "striker", 1, "attack")
    T.eq(m.players.player.pitch.strikers[1].stamina, 4)
    T.eq(s:summonCard(out.definition.id, "striker", 2, "attack"), true)
    T.eq(m.players.player.pitch.strikers[2].stamina, 4)
end)

T.test("substitution: 3 per half, keeper swaps included; then refused", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1700), "defense")
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local s = H.store(m)
    local k = H.give(m, "player", H.card("keeper", 300, 1900))
    T.eq(s:summonCard(k.id, "keeper", 0, "defense"), true)
    T.eq(m.players.player.subsUsed, 1)
    local a = H.give(m, "player", H.card("striker", 2100, 500))
    T.eq(s:summonCard(a.id, "striker", 1, "attack"), true)
    m.summonCount = 0                                  -- a new summon budget, same half
    local b = H.give(m, "player", H.card("striker", 2200, 500))
    T.eq(s:summonCard(b.id, "striker", 1, "attack"), true)
    T.eq(m.players.player.subsUsed, 3)
    local c = H.give(m, "player", H.card("striker", 2300, 500))
    local ok, err = s:summonCard(c.id, "striker", 1, "attack")
    T.eq(ok, false); T.eq(err, "no substitutions left this half")
    T.ok(inHand(m, "player", c)); T.eq(m.players.player.pitch.strikers[1].definition, b)
    T.eq(Phases.canKeeperSwap(m, H.give(m, "player", H.card("keeper", 300, 2000))), false)
end)

T.test("substitution: the summon limit applies; a sub is never a free placement", function()
    local m, out, inn = subMatch()
    m.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    local ok, err = H.store(m):summonCard(inn.id, "striker", 1, "attack")
    T.eq(ok, false); T.eq(err, "summon limit reached")
    T.eq(m.players.player.pitch.strikers[1], out); T.eq(m.players.player.subsUsed, 0)
    local m2, out2, inn2 = subMatch()
    T.eq(H.store(m2):freeSummon(inn2.id, "striker", 1, "attack"), false)
    T.eq(m2.players.player.pitch.strikers[1], out2)
end)

T.test("substitution: resets every half; Extra Time gets 3 too", function()
    local m = H.match({ phase = "summon" })
    m.players.player.subsUsed = 3
    m.players.opponent.subsUsed = 2
    State.endHalf(m, "player", "time")
    T.eq(m.players.player.subsUsed, 0); T.eq(m.players.opponent.subsUsed, 0)
    m.players.player.subsUsed = 3
    State.kickOff(m)
    State.endHalf(m, "opponent", "time")        -- 1-1: Extra Time
    T.eq(m.half, "extra"); T.eq(m.players.player.subsUsed, 0)
end)

T.test("substitution: refused for traps and strategies, a non-keeper in goal, an empty slot, the break, other phases", function()
    local m, out = subMatch()
    T.eq((Phases.canSubstitute(m, "player", H.def("trap-offside"), "striker", 1)), false)
    T.eq((Phases.canSubstitute(m, "player", H.def("strat-penalty"), "striker", 1)), false)
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local ok, why = Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "keeper", 0)
    T.eq(ok, false); T.eq(why, "keeper slot occupied")
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 2)), false,
        "an empty slot is a summon")
    m.halfTimeBreak = true
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 1)), false)
    m.halfTimeBreak = false; m.phase = "attack"
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 1)), false)
    T.eq(m.players.player.pitch.strikers[1], out)
end)

T.test("substitution: canSubstitute reads the seat it is given (the AI's mirrored view)", function()
    local m = H.match({ phase = "summon" })        -- the player is active
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    local card = H.card("striker", 2200, 500)
    T.eq((Phases.canSubstitute(m, "opponent", card, "striker", 1)), true)
    T.eq((Phases.canSubstitute(m, "player", card, "striker", 1)), false, "nothing on the player's slot")
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq((Phases.canSubstitute(m, "opponent", card, "striker", 1)), false)
end)

T.test("SUBS counter: n / 3 for your seat, in the bottom bar where the mode toggle was; toasts", function()
    local m = H.match()
    local used, max = Stats.subs(m)
    T.eq(used, 0); T.eq(max, 3)
    m.players.player.subsUsed = 2
    used, max = Stats.subs(m)
    T.eq(used, 2); T.eq(max, C.MATCH.SUBS_PER_HALF)
    local r, B = Layout.bottom.subs, Layout.bottom
    T.ok(r.y >= B.summons.y + B.summons.h and r.y + r.h <= B.startAttack.y, "between SUMMONS and START ATTACK")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "player", action = "substitution",
        name = "The Poacher", replacedName = "Speed Demon" } })), "You brought on The Poacher for Speed Demon")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "opponent", action = "substitution",
        name = "The Poacher" } })), "Opp made a substitution")
end)
