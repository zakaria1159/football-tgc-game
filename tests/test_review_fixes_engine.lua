local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")
local Combat = require("engine.combat")

-- ── 1. Shot ATK bonus only for striker-slot shooters ─────────────────────────

-- Player: an attack-mode midfielder and a 1000-ATK shooter in slotType.
-- Opponent: a 1100-DEF keeper behind an empty defender line (a gap).
local function shotBoard(slotType)
    local m = H.match()
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 500, 500))
    H.place(m, "player", slotType, 1, H.card(slotType, 1000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1100))
    return m, H.store(m)
end

T.test("review fix: a defender-slot shot gets no midfielder ATK bonus (save)", function()
    local m, s = shotBoard("defender")
    local r = s:declareAttack(H.slot("defender", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")
    T.eq(r.damage, 0)
    T.eq(m.players.opponent.lp, 4000)
    T.eq(s.combatQueue[1].attacker.atk, 1000, "overlay ATK")
end)

T.test("review fix: the same shot from a striker slot keeps the bonus (goal for 100)", function()
    local m, s = shotBoard("striker")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage")
    T.eq(r.damage, 100)
    T.eq(m.players.opponent.lp, 3900)
    T.eq(s.combatQueue[1].attacker.atk, 1200, "overlay ATK")
end)

-- ── 2. Wasted midfielder attacks count as attacks ────────────────────────────

T.test("review fix: a midfielder's wasted shot drops its keeper's bonus by 150", function()
    local m = H.match()
    local keeper = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1000))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 800, 800))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1000))
    local pitch  = m.players.player.pitch
    local before = Combat.keeperEffectiveDef(keeper, pitch)
    local r = Phases.attack(m, H.slot("midfielder"), H.slot("keeper"))
    T.eq(r.outcome, "wasted")
    T.eq(Combat.keeperEffectiveDef(keeper, pitch), before - 150)
end)

T.test("review fix: a midfielder attacking an empty midfielder slot drops the bonus by 150", function()
    local m = H.match()
    local keeper = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1000))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 800, 800))
    H.place(m, "opponent", "defender", 1, H.card("defender", 500, 500))
    local pitch  = m.players.player.pitch
    local before = Combat.keeperEffectiveDef(keeper, pitch)
    local r = Phases.attack(m, H.slot("midfielder"), H.slot("midfielder"))
    T.eq(r.outcome, "wasted")
    T.eq(r.reason, "midfielder_empty_midfielder")
    T.eq(Combat.keeperEffectiveDef(keeper, pitch), before - 150)
end)

-- ── 3. Midfield control with an empty deck ──────────────────────────────────

T.test("review fix: midfield control with an empty deck draws nothing and logs nothing", function()
    local m = H.match({ phase = "draw" })
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 900, 900))
    m.players.player.deck = {}
    Phases.draw(m)
    T.eq(#H.events(m, "midfield_control"), 0)
    T.eq(#m.players.player.hand, 0)
end)

T.test("review fix: midfield control with cards left still draws and logs", function()
    local m = H.match({ phase = "draw" })
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 900, 900))
    Phases.draw(m)
    T.eq(#H.events(m, "midfield_control"), 1)
    T.eq(#m.players.player.hand, 2)
end)

-- ── 4. Last Defender Foul after Manager's Challenge ─────────────────────────

T.test("review fix: Last Defender Foul window opens after MC overturns the AI's Offside", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    local off = H.trap(m, "opponent", "trap-offside")
    local mc  = H.trap(m, "player", "trap-managers-challenge")
    H.trap(m, "player", "trap-last-defender-foul")
    local s = H.store(m)
    local snap = s:_snapshotAttack(H.slot("striker", 1), H.slot("defender", 1))
    s.trapWindow = {
        type         = "counter_offside",
        attackerSlot = H.slot("striker", 1),
        defenderSlot = H.slot("defender", 1),
        aiTrapCard   = off,
        aiTrapIdx    = 1,
        traps        = { { card = mc, slotIndex = 1 } },
        attackerSnap = snap.attacker,
        defenderSnap = snap.defender,
    }
    s:resolveTrap(1)
    T.ok(s.trapWindow, "window open")
    T.eq(s.trapWindow.type, "post_last_defender")
    s:resolveTrap(1)
    T.eq(m.players.opponent.pitch.defenders[1], nil)
    T.eq(m.bypassCoverNextStrikerAttack, true)
end)

-- ── 5. Trap windows don't survive a half ────────────────────────────────────

T.test("review fix: a counter Red Card window is closed when the attack ends the half", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2500, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 500, 500))
    H.trap(m, "opponent", "trap-red-card")
    H.trap(m, "player", "trap-var")
    m.players.opponent.lp = 1000
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.half, 2)
    T.eq(s.trapWindow, nil)
    T.eq(s.coverWindow, nil)
    local c = H.place(m, "player", "striker", 1, H.card("striker", 700, 700))
    s:resolveTrap(nil)
    T.eq(m.players.player.pitch.strikers[1], c, "new half's striker untouched")
end)

T.test("review fix: the human's Red Card window is closed when the AI ends the half", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2500, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 500, 500))
    H.trap(m, "player", "trap-red-card")
    m.players.player.lp = 1000
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.half, 2)
    T.eq(s.trapWindow, nil)
    local c = H.place(m, "opponent", "striker", 1, H.card("striker", 700, 700))
    s:resolveTrap(1)
    T.eq(m.players.opponent.pitch.strikers[1], c, "new half's striker untouched")
end)

-- ── 6. Keeper-guarantee swap keeps the deck intact ───────────────────────────

local function keeperLastDeck()
    local d = H.filler(9)
    d[10] = H.card("keeper", 300, 1000)
    return d
end

local function counts(list, out)
    out = out or {}
    for _, c in ipairs(list) do out[c.id] = (out[c.id] or 0) + 1 end
    return out
end

local function sameCounts(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function hasKeeper(hand)
    for _, c in ipairs(hand) do if c.type == "keeper" then return true end end
    return false
end

T.test("review fix: the opening-hand keeper swap neither duplicates nor loses cards", function()
    for seed = 1, 40 do
        math.randomseed(seed)
        local deck = keeperLastDeck()
        local m  = State.newMatch(deck, keeperLastDeck())
        local ps = m.players.player
        T.eq(#ps.hand, 5)
        T.ok(hasKeeper(ps.hand), "keeper in hand, seed " .. seed)
        T.ok(sameCounts(counts(deck), counts(ps.deck, counts(ps.hand))), "cards intact, seed " .. seed)
    end
end)

T.test("review fix: the half-time redeal keeper swap neither duplicates nor loses cards", function()
    for seed = 1, 40 do
        math.randomseed(seed)
        local deck = keeperLastDeck()
        local m  = H.match()
        local ps = m.players.player
        ps.hand, ps.deck = {}, {}
        for i = 1, 10 do ps.deck[i] = deck[i] end
        State._resetHalf(m, 2)
        T.eq(#ps.hand, 5)
        T.ok(hasKeeper(ps.hand), "keeper in hand, seed " .. seed)
        T.ok(sameCounts(counts(deck), counts(ps.deck, counts(ps.hand))), "cards intact, seed " .. seed)
    end
end)
