local T        = require("tests.t")
local H        = require("tests.helpers")
local Combat   = require("engine.combat")
local Resolver = require("engine.cards.resolver")
local Card     = require("ui.card")
local Zoom     = require("ui.match.zoom")
local Fx       = require("ui.overlay.combatfx")
local AI       = require("ai.opponent")

T.test("tired: −300 ATK for a tired attacker — the fight result changes; it is no ability", function()
    local m = H.match()
    local a = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    a.stamina = 0
    local atk, parts = Combat.attackStat(a, "striker", m.players.player.pitch, m.players.opponent.pitch)
    T.eq(atk, 1700)
    T.eq(#parts, 1); T.eq(parts[1].keyword, "TIRED"); T.eq(parts[1].amount, -300)
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(#H.triggers(m), 0, "Tired is not an ability: no ability_triggered")
end)

T.test("tired: −300 DEF for a tired defender; bonuses still add up (+200 − 300)", function()
    local m = H.match()
    local pitch = m.players.opponent.pitch
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    d.stamina = 0
    T.eq((Combat.defendStat(d, "defender", pitch)), 1700)
    H.place(m, "player", "striker", 1, H.card("striker", 1750, 500))
    T.eq(H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "defender_destroyed")
end)

T.test("tired: shots lose 300 too; a non-keeper in goal tires, a keeper never does", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    s.stamina = 0
    local atk = Combat.attackStat(s, "striker", m.players.player.pitch, m.players.opponent.pitch, { keeper = k })
    T.eq(atk, 1700)
    T.eq(k.stamina, nil); T.eq((Combat.keeperDef(k, m.players.opponent.pitch)), 1800)
    local m2 = H.match()
    local stand = H.place(m2, "opponent", "keeper", 0, H.card("defender", 900, 1900))
    stand.stamina = 0
    local def, parts = Combat.keeperDef(stand, m2.players.opponent.pitch, false)
    T.eq(def, 1600); T.eq(parts[1].keyword, "TIRED")
    T.eq((Combat.keeperDef(stand, m2.players.opponent.pitch, true)), 1600, "penalty: base DEF, still tired")
end)

T.test("tired: hidden from the opponent's view while face-down; badges show the malus", function()
    local m = H.match()
    local pitch = m.players.opponent.pitch
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    fd.stamina = 0
    T.eq((Combat.defendStat(fd, "defender", pitch, false, true)), 1800, "visible only")
    T.eq((Combat.defendStat(fd, "defender", pitch)), 1500)
    local own = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    own.stamina = 0
    local atkB, defB, atkParts = Card.bonuses(own, m.players.player.pitch)
    T.eq(atkB, -100); T.eq(defB, -300)
    T.eq(atkParts[#atkParts].keyword, "TIRED")
end)

T.test("tired: combat snapshot tags read 'TIRED -300'; the AI's hidden tired card gets no tag", function()
    local m = H.match()
    local a  = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    a.stamina, fd.stamina = 0, 0
    local snap = H.store(m):_snapshotAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(snap.attacker.atk, 1700); T.eq(snap.attacker.tired, true)
    T.eq(Fx.tagText(snap.attacker.atkTags[1]), "TIRED -300")
    T.eq(snap.defender.def, 1500, "the total still counts it")
    T.eq(#snap.defender.defTags, 0); T.eq(snap.defender.tired, false)
    T.eq(Resolver.partName("TIRED"), "Tired")
end)

T.test("tired: the zoom's stat lines subtract it", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    s.stamina = 0
    local found = {}
    for _, l in ipairs(Zoom.statusLines(s.definition, s, m.players.player.pitch)) do found[l.text] = l.color end
    T.eq(found["ATK 2000 - 300 = 1700 (Tired -300)"], "bad")
    T.eq(found["DEF 500 - 300 = 200 (Tired -300)"], "bad")
end)

T.test("tired: the combat overlay keeps a negative bonus so the badge shows the real number", function()
    local v = Fx.cardView({ name = "X", type = "striker", atk = 1700, def = 500, atkBonus = -300,
                            defBonus = 0, tired = true, atkTags = { { name = "Tired", amount = -300 } } }, nil)
    T.eq(v.stats.atk, 2000); T.eq(v.atkBonus, -300); T.eq(v.atk, 1700)
    T.eq(v.tired, true); T.eq(v.atkTags[1], "TIRED -300")
end)

T.test("AI switch: a tired striker the enemy would beat goes to face-up defense", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local s = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1900))
    s.stamina = 0
    local n = 0
    for _, a in ipairs(AI._planSummons(m)) do
        if a.type == "toDefense" and a.slotType == "striker" then n = n + 1 end
    end
    T.eq(n, 1)
end)
