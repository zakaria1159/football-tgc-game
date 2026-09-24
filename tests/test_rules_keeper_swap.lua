local T      = require("tests.t")
local H      = require("tests.helpers")
local C      = require("engine.constants")
local Phases = require("engine.phases")
local Resolver = require("engine.cards.resolver")
local Toasts = require("ui.match.toasts")
local AI     = require("ai.opponent")

-- ── Keeper substitution (engine) ──────────────────────────────────────────────

local function swapMatch(opts)
    local m = H.match(opts or { phase = "summon" })
    local old = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500), "defense")
    local new = H.give(m, "player", H.card("keeper", 300, 1900))
    return m, old, new
end

local function inHand(m, owner, def)
    for _, c in ipairs(m.players[owner].hand) do if c == def then return true end end
    return false
end

T.test("Keeper swap: uses a summon; the old keeper goes back to hand, the new one is in goal", function()
    local m, old, new = swapMatch()
    local s = H.store(m)
    T.ok(Phases.canKeeperSwap(m, new))
    local ok = s:summonCard(new.id, "keeper", 0, "defense")
    T.eq(ok, true)
    T.eq(m.summonCount, 1)
    T.eq(m.players.player.pitch.keeper.definition, new)
    T.eq(m.players.player.pitch.keeper.mode, "defense")
    T.ok(inHand(m, "player", old.definition), "old keeper back in hand")
    T.ok(not inHand(m, "player", new), "new keeper left the hand")
    T.eq(#m.players.player.deck, 10, "nothing goes back to the deck")
    local e = H.events(m, "card_played")
    T.eq(#e, 1)
    T.eq(e[1].payload.action, "keeper_swap")
    T.eq(e[1].payload.card, new.id)
    T.eq(e[1].payload.replaced, old.definition.id)
end)

T.test("Keeper swap: the incoming keeper takes the player's chosen mode and may be swapped on the opening turn", function()
    local m, _, new = swapMatch({ phase = "summon", turn = 1 })
    T.ok(require("engine.state").isOpeningTurn(m))
    T.eq(H.store(m):summonCard(new.id, "keeper", 0, "attack"), true)
    T.eq(m.players.player.pitch.keeper.mode, "attack")
end)

T.test("Keeper swap: an empty keeper slot is a normal summon", function()
    local m = H.match({ phase = "summon" })
    local k = H.give(m, "player", H.card("keeper", 300, 1900))
    T.ok(not Phases.canKeeperSwap(m, k))
    T.eq(H.store(m):summonCard(k.id, "keeper", 0, "defense"), true)
    T.eq(H.events(m, "card_played")[1].payload.action, nil)
end)

T.test("Keeper swap: refused for a non-keeper card, at the summon limit, during the break, as a free summon", function()
    local m, old = swapMatch()
    local d = H.give(m, "player", H.card("defender", 900, 2000))
    local s = H.store(m)
    T.ok(not Phases.canKeeperSwap(m, d))
    local ok, err = s:summonCard(d.id, "keeper", 0, "defense")
    T.ok(not ok); T.eq(err, "keeper slot occupied")
    T.eq(m.players.player.pitch.keeper, old); T.ok(inHand(m, "player", d)); T.eq(m.summonCount, 0)

    local m2, old2, new2 = swapMatch()
    m2.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    T.ok(not Phases.canKeeperSwap(m2, new2))
    ok, err = H.store(m2):summonCard(new2.id, "keeper", 0, "defense")
    T.ok(not ok); T.eq(err, "summon limit reached")
    T.eq(m2.players.player.pitch.keeper, old2)

    local m3, old3, new3 = swapMatch()
    m3.halfTimeBreak = true
    T.ok(not Phases.canKeeperSwap(m3, new3))
    T.ok(not H.store(m3):summonCard(new3.id, "keeper", 0, "defense"))
    T.eq(m3.players.player.pitch.keeper, old3)

    local m4, old4, new4 = swapMatch()
    T.ok(not H.store(m4):freeSummon(new4.id, "keeper", 0, "defense"))
    T.eq(m4.players.player.pitch.keeper, old4); T.eq(m4.summonCount, 0)
end)

T.test("Keeper swap: the returned keeper's Safe hands saves reset when it comes back on", function()
    local m = H.match({ phase = "summon" })
    local sh  = H.place(m, "player", "keeper", 0, H.kw("SAFE_HANDS", "keeper", 300, 1750), "defense")
    sh.saves = 2
    T.eq((Resolver.keeperOwnBonus(sh)), 200)
    local other = H.give(m, "player", H.card("keeper", 300, 1900))
    local s = H.store(m)
    T.eq(s:summonCard(other.id, "keeper", 0, "defense"), true)
    T.eq(s:summonCard(sh.definition.id, "keeper", 0, "defense"), true)
    local back = m.players.player.pitch.keeper
    T.eq(back.definition, sh.definition)
    T.ok(back ~= sh, "a fresh pitched card")
    T.eq(back.saves, nil)
    T.eq((Resolver.keeperOwnBonus(back)), 0)
end)

T.test("Keeper swap: toast names your keeper and hides the opponent's", function()
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "player", action = "keeper_swap",
        slot = "keeper", name = "The Wall" } })), "You brought on The Wall in goal")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "opponent", action = "keeper_swap",
        slot = "keeper", name = "The Wall" } })), "Opp changed keeper")
end)

-- ── Keeper substitution (AI) ──────────────────────────────────────────────────

local function aiMatch(curDef)
    local m = H.match({ active = "opponent", phase = "summon" })
    local cur = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, curDef), "defense")
    return m, cur
end

local function keeperSwaps(acts)
    local out = {}
    for _, a in ipairs(acts) do
        if a.type == "summon" and a.slotType == "keeper" then out[#out + 1] = a end
    end
    return out
end

T.test("AI keeper swap: brings on a clearly better keeper with a summon to spare", function()
    local m = aiMatch(1500)
    local k = H.give(m, "opponent", H.card("keeper", 300, 2000))
    local sw = keeperSwaps(AI._planSummons(m))
    T.eq(#sw, 1); T.eq(sw[1].cardId, k.id)
    AI.executeAction(H.store(m), sw[1])
    T.eq(m.players.opponent.pitch.keeper.definition, k)
end)

T.test("AI keeper swap: never for a worse or barely better keeper", function()
    local m = aiMatch(1900)
    H.give(m, "opponent", H.card("keeper", 300, 1800))
    H.give(m, "opponent", H.card("keeper", 300, 1950))
    T.eq(#keeperSwaps(AI._planSummons(m)), 0)
end)

T.test("AI keeper swap: normal summons come first; no swap without a summon to spare", function()
    local m = aiMatch(1500)
    H.give(m, "opponent", H.card("keeper", 300, 2000))
    H.give(m, "opponent", H.card("striker", 2000, 500))
    H.give(m, "opponent", H.card("striker", 1900, 500))
    local acts = AI._planSummons(m)
    T.eq(#keeperSwaps(acts), 0)
    m.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    m.players.opponent.hand = {}
    H.give(m, "opponent", H.card("keeper", 300, 2000))
    T.eq(#keeperSwaps(AI._planSummons(m)), 0, "summon limit reached")
end)

T.test("AI keeper swap: Safe hands saves count against swapping; Fortress counts against Penalties", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    local sh = H.place(m, "opponent", "keeper", 0, H.kw("SAFE_HANDS", "keeper", 300, 1750), "defense")
    H.give(m, "opponent", H.card("keeper", 300, 1900))
    T.eq(#keeperSwaps(AI._planSummons(m)), 1, "150 better")
    sh.saves = 1
    T.eq(#keeperSwaps(AI._planSummons(m)), 0, "one save: only 50 better")

    m = aiMatch(1900)
    H.give(m, "opponent", H.kw("FORTRESS", "keeper", 300, 1800))
    T.eq(#keeperSwaps(AI._planSummons(m)), 0)
    table.insert(m.log, { type = "strategy_played", payload = { ability = "PENALTY", player = "player" } })
    T.eq(#keeperSwaps(AI._planSummons(m)), 1, "Fortress +200 against a Penalty deck")
end)
