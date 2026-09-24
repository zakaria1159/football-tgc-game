-- Headless AI-vs-AI balance simulator (plain Lua, no LÖVE).
-- Plays seeded matches on the real engine, store and AI and prints a stats table to
-- stdout. It never writes files.
--
-- Usage, from the repo root:
--   lua tools/sim/sim.lua [n=1000] [seed=20260923] [diff=medium] [decks=a,b,c] [cap=60] [cardmin=200]
--     n      matches per ordered matchup (every deck pair in both seat orders, mirrors included)
--     seed   base seed: match i of ordered matchup k uses seed + k*100000 + i
--     diff   AI difficulty for both seats: easy | medium | hard
--     decks  comma-separated keys of data/presetDecks.lua (default: all three)
--     cap    safety cap: a half still running after this many rounds counts as a stall
--     cardmin  a card's win rate is flagged only with at least this many games played
--
-- Seat "player" is the first seat (it kicks off half 1; "opponent" kicks off half 2 and a
-- coin toss decides Extra Time, as in the game). The AI plays it through a
-- mirrored view of the match; its trap prompts are answered with the AI's own trap policy.
-- Half-time breaks are instant: both seats swap cards with AI.mulliganChoice, then kick off.
-- Acceptance (spec §6): n=1000 with the three decks = 9,000 games; every deck's overall
-- win rate 42–58%; 0 stalls; first-seat match win rate 45–55%.
--
-- Abilities (2026-09-24 spec §5): per-keyword trigger counts (ability_triggered events) and
-- each field card's win rate when played (a seat that summoned it at least once in the
-- match). A card outside 35–65% with at least `cardmin` games is flagged for the owner
-- (ABILITY REVIEW line); acceptance itself is unchanged.

package.path = "./?.lua;./?/init.lua;" .. package.path

local args = {}
for _, a in ipairs(arg or {}) do
    local k, v = a:match("^([%w_]+)=(.*)$")
    if k then args[k] = v end
end
local function num(k, d) return args[k] and tonumber(args[k]) or d end

local N    = num("n", 1000)
local SEED = num("seed", 20260923)
local DIFF = args.diff or "medium"
local CAP  = num("cap", 60)
local CARD_MIN = num("cardmin", 200)

local C     = require("engine.constants")
local Store = require("store.match")
local AI    = require("ai.opponent")
local Decks = require("data.presetDecks")
local Resolver = require("engine.cards.resolver")

local deckNames = {}
for d in (args.decks or "tikitaka,longball,catenaccio"):gmatch("[^,]+") do
    assert(Decks[d], "unknown deck: " .. d)
    deckNames[#deckNames + 1] = d
end

-- ── Seats ─────────────────────────────────────────────────────────────────────

-- The AI always plays "opponent"; for the "player" seat it sees the match mirrored.
local function viewFor(match, seat)
    if seat == "opponent" then return match end
    return setmetatable({ players = { opponent = match.players.player, player = match.players.opponent } },
                        { __index = match })
end

local function proxyStore(store, seat)
    if seat == "opponent" then return store end
    return setmetatable({ match = viewFor(store.match, seat), aiDifficulty = store.aiDifficulty }, {
        __index = function(_, k)
            local v = store[k]
            if type(v) == "function" then
                return function(_, ...) return v(store, ...) end
            end
            return v
        end,
    })
end

-- The first seat's trap prompts, answered like the AI's automatic traps.
local function answerTrapWindow(store)
    local tw, m = store.trapWindow, store.match
    if tw.type == "pre_attack" then
        for i, e in ipairs(tw.traps) do
            if e.card.definition.ability == "OFFSIDE"
               and AI.wantsOffside(m, "player", tw.attackerSlot, tw.defenderSlot) then
                return store:resolveTrap(i)
            end
        end
    elseif tw.type == "post_destroy" then
        if AI.wantsRedCard(tw.attackerSnap and tw.attackerSnap.atk or 0) then
            return store:resolveTrap(1)
        end
    elseif tw.type == "post_damage" then
        return store:resolveTrap(1)
    end
    -- Counter windows and Last Defender Foul: the AI seat never has these, so pass.
    return store:resolveTrap(nil)
end

-- ── One match ─────────────────────────────────────────────────────────────────

local function playMatch(deckP, deckO, seed)
    math.randomseed(seed)
    local store = Store.new()
    store.aiDifficulty = DIFF
    store:startMatch(Decks[deckP].cards, Decks[deckO].cards)
    local m = store.match
    local plans, tags = {}, {}
    local steps, turnKey, turnSteps = 0, nil, 0
    local stall = false

    while not m.winner do
        steps = steps + 1
        if steps > 200000 or m.turn > CAP then stall = true; break end
        if m.halfTimeBreak then
            -- Half-time is instant: the store already made the "opponent" seat's AI swap;
            -- the first seat swaps with the same rule, then kick off.
            store:mulligan(AI.mulliganChoice(m, "player"), "player")
            store:kickOff()
        elseif store.coverWindow then
            store:resolveCover(AI.decideCover(store))
        elseif store.trapWindow then
            answerTrapWindow(store)
        else
            local seat = m.activePlayer
            local key  = tostring(m.half) .. ":" .. m.turn .. ":" .. seat
            if key ~= turnKey then turnKey, turnSteps = key, 0 end
            turnSteps = turnSteps + 1
            if turnSteps > 300 then stall = true; break end
            -- A plan left over from the previous half is dropped (as scenes/match.lua does).
            if plans[seat] and tags[seat] ~= AI.planTag(m) then plans[seat] = nil end
            if not plans[seat] then
                plans[seat] = { list = AI.planTurn(), idx = 1 }
                tags[seat]  = AI.planTag(m)
            end
            local p      = plans[seat]
            local action = p.list[p.idx]
            if not action then
                plans[seat] = nil
            else
                local done, extra = AI.executeAction(proxyStore(store, seat), action)
                p.idx = p.idx + 1
                if extra then
                    for i = #extra, 1, -1 do table.insert(p.list, p.idx, extra[i]) end
                end
                if done then plans[seat] = nil end
            end
        end
    end
    return m, stall
end

-- ── Stats ─────────────────────────────────────────────────────────────────────

local function inc(t, k, v) t[k] = (t[k] or 0) + (v or 1) end

local S = {
    games = 0, firstWins = 0, stalls = 0,
    deckGames = {}, deckWins = {}, mu = {},
    halves = 0, regHalves = 0, regHalvesFirst = 0, timeHalves = 0,
    extraTime = 0, twoNil = 0,
    rounds = {}, roundsN = {},
    mcTriggers = 0, mcGames = 0, mcLeaderWins = 0,
    openGoals = 0, trapSet = {}, trapAct = {},
    kw = {}, cardGames = {}, cardWins = {},
}

local ROUND_CAP = { ["1"] = C.MATCH.HALF_ROUND_LIMIT, ["2"] = C.MATCH.HALF_ROUND_LIMIT,
                    extra = C.MATCH.EXTRA_TIME_TURNS }

local function record(m, stall, deckOf)
    local w = m.winner
    S.games = S.games + 1
    if stall then S.stalls = S.stalls + 1 end
    inc(S.deckGames, deckOf.player); inc(S.deckGames, deckOf.opponent)
    if w then
        inc(S.deckWins, deckOf[w])
        if w == "player" then S.firstWins = S.firstWins + 1 end
    end
    local key = deckOf.player .. " (1st) vs " .. deckOf.opponent
    S.mu[key] = S.mu[key] or { g = 0, w = 0 }
    S.mu[key].g = S.mu[key].g + 1
    if w == "player" then S.mu[key].w = S.mu[key].w + 1 end

    local mc, sawExtra = { player = 0, opponent = 0 }, false
    local played = { player = {}, opponent = {} }   -- field card ids each seat summoned
    for _, e in ipairs(m.log) do
        local p = e.payload
        if e.type == "half_end" then
            local h = tostring(p.half)
            S.halves = S.halves + 1
            inc(S.rounds, h, math.min(e.turn, ROUND_CAP[h]))
            inc(S.roundsN, h)
            if p.reason == "time" then S.timeHalves = S.timeHalves + 1 end
            if h == "extra" then
                sawExtra = true
            else
                S.regHalves = S.regHalves + 1
                if p.winner == "player" then S.regHalvesFirst = S.regHalvesFirst + 1 end
            end
        elseif e.type == "midfield_control" then
            mc[p.player] = mc[p.player] + 1
            S.mcTriggers = S.mcTriggers + 1
        elseif e.type == "lp_damage" and p.source == "open_goal" then
            S.openGoals = S.openGoals + 1
        elseif e.type == "card_played" and p.slot == "trap" then
            inc(S.trapSet, p.card)
        elseif e.type == "trap_activated" then
            inc(S.trapAct, p.trap)
        elseif e.type == "ability_triggered" then
            inc(S.kw, p.keyword)
        end
        if e.type == "card_played" and p.card and p.slot ~= "trap" and played[p.player] then
            played[p.player][p.card] = true
        end
    end
    for _, seat in ipairs({ "player", "opponent" }) do
        for id in pairs(played[seat]) do
            inc(S.cardGames, id)
            if w == seat then inc(S.cardWins, id) end
        end
    end
    if sawExtra then S.extraTime = S.extraTime + 1 elseif w then S.twoNil = S.twoNil + 1 end
    if mc.player ~= mc.opponent then
        S.mcGames = S.mcGames + 1
        local leader = mc.player > mc.opponent and "player" or "opponent"
        if w == leader then S.mcLeaderWins = S.mcLeaderWins + 1 end
    end
end

-- ── Run ───────────────────────────────────────────────────────────────────────

local k = 0
for _, a in ipairs(deckNames) do
    for _, b in ipairs(deckNames) do
        k = k + 1
        for i = 1, N do
            local m, stall = playMatch(a, b, SEED + k * 100000 + i)
            record(m, stall, { player = a, opponent = b })
        end
    end
end

-- ── Report ────────────────────────────────────────────────────────────────────

local function pct(a, b) return b > 0 and 100 * a / b or 0 end
local function avg(a, b) return b > 0 and a / b or 0 end
local function sortedKeys(t)
    local ks = {}
    for key in pairs(t) do ks[#ks + 1] = key end
    table.sort(ks)
    return ks
end

print(string.format("config: n=%d per ordered matchup  seed=%d  diff=%s  decks=%s  cap=%d rounds",
    N, SEED, DIFF, table.concat(deckNames, ","), CAP))
print("decks:")
for _, d in ipairs(deckNames) do
    local cards = Decks[d].cards
    local sN, sAtk, kN, kDef = 0, 0, 0, 0
    for _, c in ipairs(cards) do
        if c.type == "striker" then sN = sN + 1; sAtk = sAtk + c.stats.atk end
        if c.type == "keeper"  then kN = kN + 1; kDef = kDef + c.stats.def end
    end
    print(string.format("  %-11s %d cards  strikers %d (avg ATK %.0f)  keepers %d (avg DEF %.0f)",
        d, #cards, sN, avg(sAtk, sN), kN, avg(kDef, kN)))
end
print(string.format("games=%d  stalls=%d  first-seat match wins=%.1f%%",
    S.games, S.stalls, pct(S.firstWins, S.games)))
print(string.format("halves=%d  decided on time=%d  first seat won %.1f%% of halves 1-2  2-0=%.1f%%  extra time=%.1f%%",
    S.halves, S.timeHalves, pct(S.regHalvesFirst, S.regHalves), pct(S.twoNil, S.games),
    pct(S.extraTime, S.games)))
print(string.format("avg rounds: half 1=%.2f  half 2=%.2f  extra time=%.2f",
    avg(S.rounds["1"] or 0, S.roundsN["1"] or 0), avg(S.rounds["2"] or 0, S.roundsN["2"] or 0),
    avg(S.rounds.extra or 0, S.roundsN.extra or 0)))
print(string.format("midfield control: %.2f extra draws/match; the side with more control won %.1f%% of %d games",
    avg(S.mcTriggers, S.games), pct(S.mcLeaderWins, S.mcGames), S.mcGames))
print(string.format("open goals: %.2f/match", avg(S.openGoals, S.games)))
print("deck win rates:")
local deckRate = {}
for _, d in ipairs(deckNames) do
    deckRate[d] = pct(S.deckWins[d] or 0, S.deckGames[d] or 0)
    print(string.format("  %-11s %5.1f%%  (%d appearances)", d, deckRate[d], S.deckGames[d] or 0))
end
print("matchups (first-seat win rate):")
for _, key in ipairs(sortedKeys(S.mu)) do
    local v = S.mu[key]
    print(string.format("  %-34s %5.1f%%  (%d)", key, pct(v.w, v.g), v.g))
end
print("traps set / activated:")
for _, key in ipairs(sortedKeys(S.trapSet)) do
    print(string.format("  %-26s set=%6d  act=%6d  (%.1f%%)", key, S.trapSet[key], S.trapAct[key] or 0,
        pct(S.trapAct[key] or 0, S.trapSet[key])))
end

-- ── Abilities (2026-09-24 spec §5) ────────────────────────────────────────────

print("ability triggers:")
for _, kw in ipairs(Resolver.ORDER) do
    print(string.format("  %-14s %8d  (%.2f/match)", Resolver.NAMES[kw], S.kw[kw] or 0,
        avg(S.kw[kw] or 0, S.games)))
end
print(string.format("win rate when played (flagged outside 35-65%% with at least %d games):", CARD_MIN))
local flagged = 0
for _, f in ipairs({ "strikers", "midfielders", "defenders", "keepers" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do
        local g, wn = S.cardGames[d.id] or 0, S.cardWins[d.id] or 0
        local rate  = pct(wn, g)
        local flag  = ""
        if g >= CARD_MIN and (rate > 65 or rate < 35) then
            flag = "  <-- REVIEW"
            flagged = flagged + 1
        end
        print(string.format("  %-22s %-14s %5.1f%%  (%d games)%s", d.name, d.keywordName or "-",
            rate, g, flag))
    end
end

-- ── Acceptance (spec §6) ──────────────────────────────────────────────────────

local allPass = true
local function check(label, pass)
    print(string.format("  %-4s %s", pass and "PASS" or "FAIL", label))
    allPass = allPass and pass
end
print("acceptance (spec §6):")
check(string.format("games = 9000 (got %d)", S.games), S.games == 9000)
local lo, hi = 100, 0
for _, d in ipairs(deckNames) do
    lo = math.min(lo, deckRate[d])
    hi = math.max(hi, deckRate[d])
end
check(string.format("every deck's win rate within 42-58%% (min %.1f%%, max %.1f%%)", lo, hi),
    lo >= 42 and hi <= 58)
check(string.format("stalls = 0 (got %d)", S.stalls), S.stalls == 0)
local first = pct(S.firstWins, S.games)
check(string.format("first-seat match win rate within 45-55%% (got %.1f%%)", first),
    first >= 45 and first <= 55)
print("ACCEPTANCE: " .. (allPass and "PASS" or "FAIL"))
print("ABILITY REVIEW: " .. (flagged == 0 and "OK" or (flagged .. " card(s) outside 35-65%")))
