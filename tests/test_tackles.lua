-- Tackles: a field fight where the attacker sits in a defender slot and the target in a
-- striker slot. Tackles win or lose cards, never LP (rules.md "Tackles").
local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

-- LP of both seats and the damage stats (total and this half) of both seats.
local function lpState(m)
    local p, o = m.players.player, m.players.opponent
    return { p.lp, o.lp, p.totalDamageDealt, o.totalDamageDealt,
             p.halfDamageDealt or 0, o.halfDamageDealt or 0 }
end

local function sameLp(m, before, msg)
    local now = lpState(m)
    for i = 1, #before do T.eq(now[i], before[i], (msg or "lp state") .. " [" .. i .. "]") end
end

-- ── Engine ────────────────────────────────────────────────────────────────────

T.test("Tackle win: an attack-mode striker is destroyed, no LP lost, tackle flag set", function()
    local m = H.match()
    local d = H.place(m, "player", "defender", 1, H.card("defender", 1800, 1600))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1200))
    local before = lpState(m)
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(r.tackle, true)
    T.eq(r.damage or 0, 0)
    T.eq(m.players.opponent.pitch.strikers[1], nil, "striker destroyed")
    T.eq(d.exhausted, true, "tackler exhausted")
    sameLp(m, before)
    T.eq(#H.events(m, "lp_damage"), 0)
end)

T.test("Tackle loss: the tackler is destroyed, the striker survives, no LP lost", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.card("defender", 1000, 1600))
    local s = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1400))
    local before = lpState(m)
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(r.tackle, true)
    T.eq(r.attackerDestroyed, true)
    T.eq(m.players.player.pitch.defenders[1], nil, "tackler destroyed")
    T.eq(m.players.opponent.pitch.strikers[1], s, "striker survives")
    sameLp(m, before)
    T.eq(#H.events(m, "lp_damage"), 0)
end)

T.test("Tackle loss against a face-down striker: revealed, no LP lost", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.card("defender", 1000, 1600))
    local s = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1400), "defense")
    local before = lpState(m)
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(r.tackle, true)
    T.eq(s.revealed, true)
    sameLp(m, before)
    T.eq(#H.events(m, "lp_damage"), 0)
end)

T.test("Tackle tie: both cards destroyed, no LP lost", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.card("defender", 1400, 1600))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1400))
    local before = lpState(m)
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "tie")
    T.eq(r.tackle, true)
    T.eq(m.players.player.pitch.defenders[1], nil)
    T.eq(m.players.opponent.pitch.strikers[1], nil)
    sameLp(m, before)
end)

T.test("Tackle: Build-up still draws a card on a tackle win", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.kw("BUILD_UP", "defender", 1800, 1700))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1200))
    local before = lpState(m)
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(r.tackle, true)
    T.eq(#m.players.player.hand, 1)
    T.eq(H.triggers(m)[1].keyword, "BUILD_UP")
    sameLp(m, before)
end)

-- The slot decides, not the card type: any card in a defender slot tackles.
for _, ctype in ipairs({ "striker", "midfielder" }) do
    T.test("Tackle by slot: a " .. ctype .. " card in a defender slot tackles with no LP either way", function()
        local m = H.match()
        H.place(m, "player", "defender", 1, H.card(ctype, 1800, 1600))
        H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1200))
        local before = lpState(m)
        local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
        T.eq(r.tackle, true)
        T.eq(r.outcome, "defender_destroyed")
        T.eq(m.players.opponent.pitch.strikers[1], nil, "striker destroyed")
        sameLp(m, before, "win")
        T.eq(#H.events(m, "lp_damage"), 0)

        m = H.match()
        H.place(m, "player", "defender", 1, H.card(ctype, 900, 1600))
        H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 1200))
        before = lpState(m)
        r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
        T.eq(r.tackle, true)
        T.eq(m.players.player.pitch.defenders[1], nil, "tackler destroyed")
        sameLp(m, before, "loss")
        T.eq(#H.events(m, "lp_damage"), 0)
    end)
end

-- ── Controls: other fights still deal LP ──────────────────────────────────────

T.test("Tackle control: midfielder vs attack-mode midfielder still deals LP", function()
    local m = H.match()
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1200))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1300))
    local lp = m.players.opponent.lp
    local r = H.store(m):declareAttack(H.slot("midfielder"), H.slot("midfielder"))
    T.eq(r.outcome, "defender_destroyed")
    T.ok(not r.tackle)
    T.eq(m.players.opponent.lp, lp - 500)
    T.eq(m.players.player.totalDamageDealt, 500)
end)

T.test("Tackle control: a striker attacking an attack-mode defender still deals LP", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 1200, 1700))
    local lp = m.players.opponent.lp
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.ok(not r.tackle)
    T.eq(m.players.opponent.lp, lp - 300)
end)

T.test("Tackle control: a striker losing to a defender still costs its owner LP", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 1200, 1700))
    local lp = m.players.player.lp
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.ok(not r.tackle)
    T.eq(m.players.player.lp, lp - 200)
end)

-- ── AI ────────────────────────────────────────────────────────────────────────

T.test("Tackle AI: a tackle is estimated at 0 LP, and the AI still tackles a beatable striker", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "defender", 1, H.card("defender", 1800, 1600))
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 1200))
    T.eq(AI.estimateAttackDamage(m, "player", H.slot("defender", 1), H.slot("striker", 1)), 0)
    local atk = AI._planNextAttack(m, "medium")
    T.ok(atk, "an attack is planned")
    T.eq(atk.attackerSlot.type, "defender")
    T.eq(atk.defenderSlot.type, "striker"); T.eq(atk.defenderSlot.index, 1)
end)
