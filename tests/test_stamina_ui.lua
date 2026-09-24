local T       = require("tests.t")
local H       = require("tests.helpers")
local Card    = require("ui.card")
local Zoom    = require("ui.match.zoom")
local Toasts  = require("ui.match.toasts")
local Stamina = require("engine.stamina")

T.test("stamina pips: between the badges and under the name ribbon; on a back, above the DEF label", function()
    local L  = Card.layout(108, 148)
    local st = L.stamina
    local rw = Card.staminaRowWidth(L, 7)          -- the longest row (Engine)
    T.ok(st.cy - st.h / 2 >= L.ribbon.y + L.ribbon.h, "under the name ribbon")
    T.ok(st.cx - rw / 2 >= L.atk.cx + L.atk.size / 2, "right of the ATK badge")
    T.ok(st.cx + rw / 2 <= L.def.cx - L.def.size / 2, "left of the DEF badge")
    T.ok(st.cy + st.h / 2 <= 148, "inside the card")
    T.ok(st.backCy - st.h / 2 >= 148 / 2 + math.min(108, 148) * 0.42 / 2, "back: below the ball")
    local pad = L.border + 5 * L.s
    T.ok(st.backCy + st.h / 2 <= 148 - pad - math.max(10, 16 * L.s) - 2 * L.s, "back: above the DEF label")
    local sw = L.sweat
    T.ok(sw.cy - sw.size / 2 >= L.tag.cy + L.tag.h / 2, "sweat drop below the type tag")
    T.ok(sw.cx + sw.size / 2 <= (108 - L.defPill.h * 2.6) / 2, "sweat drop left of the DEF pill")
    T.ok(sw.cy + sw.size / 2 <= L.flip.y, "sweat drop above the switch ribbon")
end)

T.test("stamina pips: filled / total, tired at 0, nothing for cards that never tire", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local v = Card.staminaView(s)
    T.eq(v.filled, 4); T.eq(v.total, 4); T.eq(v.tired, false)
    s.stamina = 0
    v = Card.staminaView(s)
    T.eq(v.filled, 0); T.eq(v.tired, true)
    local e = H.place(m, "player", "midfielder", 0, H.kw("ENGINE", "midfielder", 1800, 1500))
    T.eq(Card.staminaView(e).total, 7)
    T.eq(Card.staminaView(H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")), nil)
end)

T.test("stamina visibility: your own cards always; the opponent's only while face-up", function()
    local m = H.match()
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    local up = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    T.eq(Stamina.visible(fd, true), true)
    T.eq(Stamina.visible(fd, false), false)
    fd.revealed = true
    T.eq(Stamina.visible(fd, false), true)
    T.eq(Stamina.visible(up, false), true)
    T.eq(Stamina.visible(H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800)), true), false)
end)

T.test("zoom: stamina line, TIRED line, none for keepers", function()
    local m = H.match()
    local pitch = m.players.player.pitch
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local function has(lines, text)
        for _, l in ipairs(lines) do if l.text == text then return true end end
        return false
    end
    T.ok(has(Zoom.statusLines(s.definition, s, pitch), "Stamina 4 / 4"))
    s.stamina = 0
    T.ok(has(Zoom.statusLines(s.definition, s, pitch), "TIRED: -300 ATK / -300 DEF (stamina 0 / 4)"))
    local k = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    for _, l in ipairs(Zoom.statusLines(k.definition, k, pitch)) do
        T.ok(not l.text:find("Stamina") and not l.text:find("TIRED"), l.text)
    end
end)

T.test("toasts: your tired card is named; the opponent's only while face-up", function()
    T.eq((Toasts.describe({ type = "card_tired", payload = { player = "player", name = "The Poacher" } })),
        "The Poacher is TIRED (-300)")
    T.eq((Toasts.describe({ type = "card_tired", payload = { player = "opponent", name = "Libero" } })),
        "Opp's Libero is TIRED")
    T.eq((Toasts.describe({ type = "card_tired",
        payload = { player = "opponent", name = "Libero", hidden = true } })), nil)
end)
