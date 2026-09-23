local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")
local Card   = require("ui.card")

-- ── Link-up ───────────────────────────────────────────────────────────────────

-- Player striker (ATK 2000) in slot 1, a Link-up card in slot 2; a face-up 2100-DEF defender.
local function linkUpBoard()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local cf = H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2100))
    return m, H.store(m), cf
end

T.test("Link-up: the other striker-slot card gets +150 ATK", function()
    local m, s, cf = linkUpBoard()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2150 vs 2100
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "LINK_UP"); T.eq(t[1].card, cf.definition.id)
    T.eq(t[1].player, "player"); T.eq(t[1].amount, 150)
end)

T.test("Link-up: the Link-up card itself gets nothing", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("LINK_UP", "striker", 2100, 900))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2100))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "tie")
    T.eq(#H.triggers(m), 0)
end)

T.test("combat snapshot: the overlay record carries the modified ATK and its tags", function()
    local _, s = linkUpBoard()
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    local a = s.combatQueue[1].attacker
    T.eq(a.atk, 2150); T.eq(a.atkBonus, 150)
    T.eq(#a.atkTags, 1); T.eq(a.atkTags[1].keyword, "LINK_UP")
    T.eq(a.atkTags[1].name, "Link-up"); T.eq(a.atkTags[1].amount, 150)
    T.eq(s.combatQueue[1].defender.def, 2100)
end)

-- ── Last man ──────────────────────────────────────────────────────────────────

T.test("Last man: +300 DEF while it is the only card in its defender slots", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)         -- 2200 vs 2300
    T.eq(m.players.player.lp, 3900)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "LAST_MAN"); T.eq(t[1].player, "opponent")
end)

T.test("Last man: no bonus with a second card in the defender slots", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1500))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Counter-press ─────────────────────────────────────────────────────────────

T.test("Counter-press: +300 DEF when it covers", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    T.eq(s.coverWindow.attackerSnap.atk, 1600)
    r = s:resolveCover(H.slot("midfielder"))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)         -- 1600 vs 1400 + 300
    T.eq(m.players.player.pitch.strikers[1], nil)
    local d = s.combatQueue[1].defender
    T.eq(d.def, 1700); T.eq(d.defTags[1].keyword, "COUNTER_PRESS")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "COUNTER_PRESS"); T.eq(t[1].player, "opponent")
end)

T.test("Counter-press: no bonus when it is attacked directly", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("midfielder"))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#H.triggers(m), 0)
end)

-- ── Engine ────────────────────────────────────────────────────────────────────

-- Player midfielder `midDef` in `mode`, a 2000-ATK striker; a face-up 2050-DEF defender.
local function midBoard(midDef, mode)
    local m = H.match()
    H.place(m, "player", "midfielder", 0, midDef, mode)
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2050))
    return m, H.store(m)
end

T.test("Engine: +100 ATK to strikers and +100 DEF to defenders, even face-down", function()
    local m, s = midBoard(H.kw("ENGINE", "midfielder", 1800, 1500), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2100 vs 2050
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 100)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "ENGINE")
end)

T.test("Engine: a plain midfielder keeps the normal mode bonus", function()
    local m, s = midBoard(H.card("midfielder", 1800, 1500), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")                              -- 2000 vs 2050
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Overlap ───────────────────────────────────────────────────────────────────

T.test("Overlap: +300 ATK instead of +200 in attack mode", function()
    local m = H.match()
    H.place(m, "player", "midfielder", 0, H.kw("OVERLAP", "midfielder", 1650, 1450))
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2250))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2300 vs 2250
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OVERLAP")
end)

T.test("Overlap: nothing extra in defense mode (the normal +200 DEF)", function()
    local m, s = midBoard(H.kw("OVERLAP", "midfielder", 1650, 1450), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Pitch badges ──────────────────────────────────────────────────────────────

T.test("card bonuses: pitch badges include Link-up and Last man", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    local st = H.place(m, "player", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    local pitch = m.players.player.pitch
    T.eq((Card.bonuses(s1, pitch)), 150)
    local _, d = Card.bonuses(st, pitch)
    T.eq(d, 300)
end)

T.test("card bonuses: the opponent's hidden ability sources are not shown", function()
    local m = H.match()
    local s1 = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LINK_UP", "striker", 2150, 900), "defense")
    local pitch = m.players.opponent.pitch
    T.eq((Card.bonuses(s1, pitch)), 150, "its owner sees it")
    T.eq((Card.bonuses(s1, pitch, true)), 0, "hidden from the other side")
end)
