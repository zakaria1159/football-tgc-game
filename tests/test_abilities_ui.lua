local T    = require("tests.t")
local H    = require("tests.helpers")
local Card = require("ui.card")
local Zoom = require("ui.match.zoom")
local Fx   = require("ui.overlay.combatfx")

local SIZES = { { 68, 80 }, { 84, 106 }, { 108, 148 }, { 120, 165 }, { 200, 274 }, { 300, 410 } }

T.test("keyword pill: above the name ribbon, below every status piece, clear of tag, gem and badges", function()
    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local L, at = Card.layout(w, h), " at " .. w
        local k = L.kw
        T.ok(k.h >= 9, "legible" .. at)
        T.ok(k.y + k.h <= L.ribbon.y, "above the ribbon" .. at)
        T.ok(k.y >= L.tag.cy + L.tag.h / 2, "below the type tag" .. at)
        T.ok(k.y >= L.gem.cy + L.gem.size, "below the gem" .. at)
        T.ok(k.y >= L.zzz.y + L.zzz.h, "below the exhausted pill" .. at)
        T.ok(k.y >= L.defPill.y + L.defPill.h, "below the revealed DEF pill" .. at)
        T.ok(k.y >= L.flip.y + L.flip.h, "below the TO ATTACK ribbon" .. at)
        T.ok(k.y + k.h <= L.atk.cy - L.atk.size / 2, "above the badges" .. at)
        T.ok(k.maxW > 0 and k.cx - k.maxW / 2 >= 0 and k.cx + k.maxW / 2 <= w, "inside the card" .. at)
    end
end)

T.test("keyword pill text: upper-case keyword name for field cards only", function()
    T.eq(Card.keywordLabel({ type = "striker", keywordName = "Link-up" }), "LINK-UP")
    T.eq(Card.keywordLabel({ type = "keeper", keywordName = "Off the line" }), "OFF THE LINE")
    T.eq(Card.keywordLabel({ type = "trap", keywordName = "X" }), nil)
    T.eq(Card.keywordLabel({ type = "striker" }), nil)
    T.eq(Card.keywordLabel(nil), nil)
end)

local function has(lines, text)
    for _, l in ipairs(lines) do if l.text == text then return true end end
    return false
end

T.test("zoom: stat lines name the ability bonuses", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    H.place(m, "player", "midfielder", 0, H.kw("OVERLAP", "midfielder", 1650, 1450))
    local lines = Zoom.statusLines(s1.definition, s1, m.players.player.pitch)
    T.ok(has(lines, "ATK 2000 + 450 = 2450 (Overlap +300, Link-up +150)"))
    T.eq(Zoom.partsText({}), "")
end)

T.test("zoom: locked and just-summoned cards say so (not a Pace card)", function()
    local m = H.match()
    local pitch = m.players.player.pitch
    local c = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    c.lockedNextTurn = true
    T.ok(has(Zoom.statusLines(c.definition, c, pitch), "Cannot act next turn"))
    local fresh = H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    fresh.summonedThisTurn = true
    T.ok(has(Zoom.statusLines(fresh.definition, fresh, pitch), "Just summoned: attacks next turn"))
    local pace = H.place(m, "player", "defender", 1, H.kw("PACE", "striker", 2150, 550))
    pace.summonedThisTurn = true
    T.ok(not has(Zoom.statusLines(pace.definition, pace, pitch), "Just summoned: attacks next turn"))
end)

T.test("combat overlay: ability tags read 'NAME +N'", function()
    T.eq(Fx.tagText({ name = "Link-up", amount = 150 }), "LINK-UP +150")
    T.eq(Fx.tagText({ name = "Fortress", amount = 0 }), "FORTRESS")
    local list = Fx.bonusTags({ atkTags = { { name = "Link-up", amount = 150 },
                                            { name = "Instinct", amount = 300 } } }, "atk")
    T.eq(#list, 2); T.eq(list[2], "INSTINCT +300")
    T.eq(#Fx.bonusTags(nil, "atk"), 0)
    local v = Fx.cardView({ name = "X", type = "striker", atk = 2150, def = 500, atkBonus = 150,
                            defBonus = 0, atkTags = { { name = "Link-up", amount = 150 } } }, nil)
    T.eq(v.atkTags[1], "LINK-UP +150"); T.eq(#v.defTags, 0)
end)

T.test("combat overlay: rule abilities that fired are named once; stat ones are tags", function()
    T.eq(Fx.abilityLine({ abilities = { "CLINICAL" } }), "CLINICAL!")
    T.eq(Fx.abilityLine({ abilities = { "PUNCH_CLEAR", "LAST_MAN", "PUNCH_CLEAR" } }), "PUNCH CLEAR!")
    T.eq(Fx.abilityLine({ abilities = { "IMMOVABLE", "HARD_TACKLE" } }), "IMMOVABLE · HARD TACKLE!")
    T.eq(Fx.abilityLine({ abilities = { "BOLT" } }), nil)
    T.eq(Fx.abilityLine({}), nil)
end)
