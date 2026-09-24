local T     = require("tests.t")
local H     = require("tests.helpers")
local State = require("engine.state")
local AI    = require("ai.opponent")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ids(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.id end
    return out
end

-- Sorted ids of a player's hand + deck (card identity check).
local function pool(m, seat)
    local out = {}
    for _, c in ipairs(m.players[seat].hand) do out[#out + 1] = c.id end
    for _, c in ipairs(m.players[seat].deck) do out[#out + 1] = c.id end
    table.sort(out)
    return table.concat(out, ",")
end

-- Match in the half-time break after half 1 (player won it).
local function inBreak()
    local m = H.match()
    State.endHalf(m, "player", "lp")
    return m
end

local function has(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end

-- ── halfTimeBreak / kickOff ───────────────────────────────────────────────────

T.test("halftime: the break starts when half 1 ends", function()
    local m = H.match()
    T.ok(not m.halfTimeBreak, "no break at the start")
    State.endHalf(m, "player", "lp")
    T.eq(m.half, 2)
    T.eq(m.halfTimeBreak, true)
end)

T.test("halftime: the break starts before Extra Time (1-1 after half 2)", function()
    local m = H.match({ half = 2 })
    m.players.player.halvesWon = 1
    State.endHalf(m, "opponent", "lp")
    T.eq(m.half, "extra")
    T.eq(m.halfTimeBreak, true)
end)

T.test("halftime: no break when the match ends", function()
    local m = H.match({ half = 2 })
    m.players.player.halvesWon = 1
    State.endHalf(m, "player", "lp")
    T.eq(m.winner, "player")
    T.ok(not m.halfTimeBreak)
end)

T.test("halftime: kickOff clears the break", function()
    local m = inBreak()
    State.kickOff(m)
    T.ok(not m.halfTimeBreak)
end)

-- ── State.mulligan ────────────────────────────────────────────────────────────

T.test("mulligan: swaps the chosen cards, keeps hand size, deck size and card identities", function()
    local m = inBreak()
    local p = m.players.player
    local handN, deckN, before = #p.hand, #p.deck, pool(m, "player")
    local chosen = { p.hand[1].id, p.hand[3].id }
    T.eq(State.mulligan(m, "player", chosen), 2)
    T.eq(#p.hand, handN); T.eq(#p.deck, deckN)
    T.eq(pool(m, "player"), before)
end)

T.test("mulligan: the chosen cards leave the hand when the deck has other cards", function()
    local m = inBreak()
    local p = m.players.player
    -- Deck of distinct cards that are not in the hand: the swapped cards must be new draws
    -- unless the shuffle brought them back; with 1 card sent back into a 6-card deck, check
    -- the hand still holds the 4 kept cards.
    local kept = { p.hand[2].id, p.hand[3].id, p.hand[4].id, p.hand[5].id }
    State.mulligan(m, "player", { p.hand[1].id })
    local now = ids(p.hand)
    for _, id in ipairs(kept) do T.ok(has(now, id), "kept " .. id) end
end)

T.test("mulligan: more than 3 cards is refused", function()
    local m = inBreak()
    local p = m.players.player
    local before = table.concat(ids(p.hand), ",")
    T.eq(State.mulligan(m, "player", { p.hand[1].id, p.hand[2].id, p.hand[3].id, p.hand[4].id }), 0)
    T.eq(table.concat(ids(p.hand), ","), before)
    T.eq(State.mulligan(m, "player", { p.hand[1].id, p.hand[2].id, p.hand[3].id }), 3, "3 is fine")
end)

T.test("mulligan: only cards in that player's hand", function()
    local m = inBreak()
    local p = m.players.player
    T.eq(State.mulligan(m, "player", { p.deck[1].id }), 0, "deck card")
    T.eq(State.mulligan(m, "player", { m.players.opponent.hand[1].id }), 0, "opponent's card")
    T.eq(State.mulligan(m, "player", { p.hand[1].id, p.hand[1].id }), 0, "same card twice")
    T.eq(State.mulligan(m, "player", { p.hand[1].id }), 1, "a refusal does not use the swap")
end)

T.test("mulligan: only during the break", function()
    local m = H.match()
    H.give(m, "player", H.card("striker", 1000, 500))
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 0, "mid-half")
    local m2 = inBreak()
    State.kickOff(m2)
    T.eq(State.mulligan(m2, "player", { m2.players.player.hand[1].id }), 0, "after kick-off")
end)

T.test("mulligan: once per break per player", function()
    local m = inBreak()
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 1)
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 0, "second swap")
    T.eq(State.mulligan(m, "opponent", { m.players.opponent.hand[1].id }), 1, "other seat")
end)

T.test("mulligan: a new break allows a new swap", function()
    local m = inBreak()                  -- player 1-0
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 1)
    State.kickOff(m)
    State.endHalf(m, "opponent", "lp")   -- 1-1 → Extra Time break
    T.eq(m.halfTimeBreak, true)
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 1)
end)

T.test("mulligan: an empty choice swaps nothing and keeps the swap available", function()
    local m = inBreak()
    T.eq(State.mulligan(m, "player", {}), 0)
    T.eq(State.mulligan(m, "player", { m.players.player.hand[1].id }), 1)
end)

-- ── lastHalfStats ─────────────────────────────────────────────────────────────

T.test("lastHalfStats: LP, damage, goals and cards lost of the half just played", function()
    local m = H.match()
    local s = H.store(m)
    -- The player's striker beats a face-down defender (opponent loses 1 card, no damage),
    -- then the player scores two open goals: 1500 + 2600 = 4100.
    H.place(m, "player", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "player", "striker", 2, H.card("striker", 2600, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 400), "defense")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.players.opponent.pitch.defenders[1], nil, "defender destroyed")
    m.players.player.pitch.strikers[1].exhausted = false
    s:declareAttack(H.slot("striker", 1), H.slot("keeper"))       -- goal 1: 1500
    T.eq(m.players.opponent.lp, 2500)
    s:declareAttack(H.slot("striker", 2), H.slot("keeper"))       -- goal 2: 2600 → half over
    T.eq(m.half, 2)
    local st = m.lastHalfStats
    T.ok(st, "stats recorded")
    T.eq(st.player.lp, 4000);    T.eq(st.opponent.lp, -100)
    T.eq(st.player.damage, 4100); T.eq(st.opponent.damage, 0)
    T.eq(st.player.goals, 2);    T.eq(st.opponent.goals, 0)
    T.eq(st.player.lost, 0);     T.eq(st.opponent.lost, 1)
end)

T.test("lastHalfStats: battle damage is not a goal; a lost fight is a card lost", function()
    local m = H.match()
    local s = H.store(m)
    H.place(m, "player", "striker", 1, H.card("striker", 800, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 1200, 1200))
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))   -- attacker loses: 400 to opponent
    State.endHalf(m, "opponent", "time")
    local st = m.lastHalfStats
    T.eq(st.opponent.damage, 400); T.eq(st.opponent.goals, 0)
    T.eq(st.player.lost, 1);       T.eq(st.opponent.lost, 0)
end)

T.test("lastHalfStats: a goal overturned by VAR is not counted", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-var")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    State.endHalf(m, "player", "time")
    T.eq(m.lastHalfStats.player.goals, 0)
    T.eq(m.lastHalfStats.player.damage, 0)
end)

T.test("lastHalfStats: counters start again in the new half", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 800, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 1200, 1200))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    State.endHalf(m, "opponent", "time")
    State.kickOff(m)
    State.endHalf(m, "player", "time")   -- 1-1, nothing happened in half 2
    T.eq(m.lastHalfStats.player.lost, 0)
    T.eq(m.lastHalfStats.opponent.damage, 0)
    T.eq(m.lastHalfStats.player.lp, 4000)
end)

-- ── Store refuses gameplay during the break ───────────────────────────────────

T.test("store: gameplay actions are refused during the break", function()
    local m = inBreak()
    local s = H.store(m)
    local card = m.players.player.hand[1]
    local r, err
    m.phase = "summon"
    r, err = s:summonCard(card.id, "defender", 1, "attack"); T.eq(r, nil); T.eq(err, "half-time", "summon")
    r, err = s:freeSummon(card.id, "defender", 1, "attack"); T.eq(r, nil); T.eq(err, "half-time", "free")
    r, err = s:changeMode("defender", 1);                    T.eq(r, nil); T.eq(err, "half-time", "flip")
    r, err = s:startAttackPhase();                           T.eq(r, nil); T.eq(err, "half-time", "atk phase")
    T.eq(m.phase, "summon")
    m.phase = "attack"
    r, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper")); T.eq(r, nil); T.eq(err, "half-time")
    local strat = H.give(m, "player", H.def("strat-direct-free-kick"))
    r, err = s:playStrategy(strat.id);                       T.eq(r, nil); T.eq(err, "half-time", "strategy")
    local turn = m.turn
    r, err = s:endTurn();                                    T.eq(r, nil); T.eq(err, "half-time", "end turn")
    T.eq(m.turn, turn); T.eq(m.activePlayer, "opponent", "half 2's starter, unchanged")
    m.phase = "draw"
    local handN = #m.players.player.hand
    r, err = s:drawPhase();                                  T.eq(r, nil); T.eq(err, "half-time", "draw")
    T.eq(m.phase, "draw"); T.eq(#m.players.player.hand, handN)
    r, err = s:resolveCover(nil);                            T.eq(r, nil); T.eq(err, "half-time", "cover")
    r, err = s:resolveTrap(nil);                             T.eq(r, nil); T.eq(err, "half-time", "trap")
end)

T.test("store: kickOff ends the break and play resumes", function()
    local m = inBreak()
    local s = H.store(m)
    m.phase = "draw"
    s:kickOff()
    T.ok(not m.halfTimeBreak)
    s:drawPhase()
    T.eq(m.phase, "summon")
end)

T.test("store: mulligan for the human seat", function()
    local m = inBreak()
    local s = H.store(m)
    T.eq(s:mulligan({ m.players.player.hand[1].id }), 1)
    T.eq(s:mulligan({ m.players.player.hand[1].id }), 0, "once per break")
end)

T.test("store: the AI seat mulligans automatically when a half ends in the store", function()
    local m = H.match()
    local s = H.store(m)
    -- The opponent's whole pool is traps: its new hand is 5 traps, so it sends back 3.
    local deck = {}
    for i = 1, 10 do deck[i] = { id = "t-trap-" .. i, name = "Trap " .. i, type = "trap",
                                 ability = "VAR", rarity = "common" } end
    m.players.opponent.deck = deck
    H.place(m, "player", "striker", 1, H.card("striker", 4000, 500))
    s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(m.half, 2); T.eq(m.halfTimeBreak, true)
    T.eq(m.mulliganUsed.opponent, true, "AI swapped")
    T.ok(not m.mulliganUsed.player, "the human decides on the screen")
    T.eq(#m.players.opponent.hand, 5)
end)

T.test("store: the AI seat also mulligans when the half ends on time at end of turn", function()
    local m = H.match({ turn = 99, active = "opponent", phase = "attack" })
    local s = H.store(m)
    local deck = {}
    for i = 1, 10 do deck[i] = { id = "t-trap-e" .. i, name = "Trap " .. i, type = "trap",
                                 ability = "VAR", rarity = "common" } end
    m.players.opponent.deck = deck
    s:endTurn()
    T.eq(m.half, 2); T.eq(m.halfTimeBreak, true)
    T.eq(m.mulliganUsed.opponent, true)
end)

-- ── AI.mulliganChoice ─────────────────────────────────────────────────────────

local function aiHand(cards)
    local m = inBreak()
    m.players.opponent.hand = cards
    return m
end
local function trap(n) return { id = "x-trap-" .. n, name = "Trap", type = "trap", rarity = "common" } end
local function strat(n) return { id = "x-strat-" .. n, name = "Strat", type = "strategy", rarity = "common" } end

T.test("AI mulligan: keeps the first 2 traps/strategies, sends back the rest", function()
    local k = H.card("keeper", 300, 1500)
    local m = aiHand({ trap(1), k, strat(2), trap(3), H.card("striker", 1500, 500) })
    local c = AI.mulliganChoice(m, "opponent")
    T.eq(#c, 1); T.eq(c[1], "x-trap-3")
end)

T.test("AI mulligan: sends back a second keeper", function()
    local k1, k2 = H.card("keeper", 300, 1500), H.card("keeper", 300, 1400)
    local m = aiHand({ k1, H.card("defender", 900, 900), k2, trap(1), H.card("striker", 1500, 500) })
    local c = AI.mulliganChoice(m, "opponent")
    T.eq(#c, 1); T.eq(c[1], k2.id)
end)

T.test("AI mulligan: never more than 3 cards", function()
    local m = aiHand({ trap(1), trap(2), trap(3), strat(4), strat(5) })
    local c = AI.mulliganChoice(m, "opponent")
    T.eq(#c, 3)
    T.ok(not has(c, "x-trap-1") and not has(c, "x-trap-2"), "keeps the first two")
end)

T.test("AI mulligan: a good hand is kept", function()
    local m = aiHand({ H.card("keeper", 300, 1500), H.card("defender", 900, 900), trap(1),
                       strat(2), H.card("striker", 1500, 500) })
    T.eq(#AI.mulliganChoice(m, "opponent"), 0)
end)

T.test("AI mulligan: works for either seat and its choice is accepted by State.mulligan", function()
    local m = inBreak()
    m.players.player.hand = { trap(1), trap(2), trap(3), H.card("keeper", 1, 1), H.card("keeper", 1, 1) }
    local c = AI.mulliganChoice(m, "player")
    T.eq(#c, 2)
    T.eq(State.mulligan(m, "player", c), 2)
end)

T.test("mulligan: two copies of the same card (same id, as in preset decks) can both go back", function()
    local m = inBreak()
    local p = m.players.player
    local dup = H.def("trap-offside")
    p.hand[1], p.hand[2] = dup, dup
    local before = pool(m, "player")
    T.eq(State.mulligan(m, "player", { dup.id, dup.id }), 2)
    T.eq(#p.hand, 5); T.eq(pool(m, "player"), before, "same cards overall")
    local m2 = inBreak()
    m2.players.player.hand[1] = dup
    T.eq(State.mulligan(m2, "player", { dup.id, dup.id }), 0, "only one copy in hand")
end)
