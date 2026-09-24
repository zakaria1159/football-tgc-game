local T          = require("tests.t")
local ModePicker = require("ui.match.modepicker")
local Layout     = require("ui.match.layout")

local function slot(slotType, index)
    local r = Layout.slot("player", slotType, index)
    return { x = r.x, y = r.y, w = r.w, h = r.h, slotType = slotType, slotIndex = index, owner = "player" }
end

T.test("mode picker: field cards and keepers choose; traps and strategies don't", function()
    T.eq(ModePicker.needsPicker({ type = "striker" }), true)
    T.eq(ModePicker.needsPicker({ type = "midfielder" }), true)
    T.eq(ModePicker.needsPicker({ type = "defender" }), true)
    T.eq(ModePicker.needsPicker({ type = "keeper" }), true)
    T.eq(ModePicker.needsPicker({ type = "trap" }), false)
    T.eq(ModePicker.needsPicker({ type = "strategy" }), false)
    T.eq(ModePicker.needsPicker(nil), false)
end)

T.test("mode picker: a keeper's choice is permanent and the picker says so", function()
    T.eq(ModePicker.open({ id = "k", type = "keeper" }, slot("keeper", 0)).note, "Keepers never flip later")
    T.eq(ModePicker.open({ id = "d", type = "defender" }, slot("keeper", 0)).note, "Keepers never flip later")
    T.eq(ModePicker.open({ id = "s", type = "striker" }, slot("striker", 1)).note, nil)
    local p = ModePicker.open({ id = "s", type = "striker" }, slot("striker", 1), true)
    T.eq(p.cardId, "s"); T.eq(p.free, true)
end)

T.test("mode picker: anchored on the slot, on screen, two stacked buttons inside the panel", function()
    for _, s in ipairs(Layout.slots()) do
        if s.owner == "player" then
            for _, def in ipairs({ { id = "x", type = "striker" }, { id = "k", type = "keeper" } }) do
                local r = ModePicker.rects(ModePicker.open(def, s))
                local P = r.panel
                T.ok(P.x >= 0 and P.y >= 0 and P.x + P.w <= Layout.W and P.y + P.h <= Layout.H, "on screen")
                T.near(P.x + P.w / 2, s.x + s.w / 2, 0.5, "centred on the slot")
                T.near(P.y + P.h / 2, s.y + s.h / 2, 0.5, "centred on the slot")
                for _, b in ipairs({ r.attack, r.defense }) do
                    T.ok(b.x >= P.x and b.y >= P.y and b.x + b.w <= P.x + P.w and b.y + b.h <= P.y + P.h,
                        "button inside the panel")
                end
                T.ok(r.defense.y >= r.attack.y + r.attack.h, "stacked, no overlap")
            end
        end
    end
end)

T.test("mode picker: clicks map to ATTACK, DEFEND, inside the panel, or outside", function()
    local p = ModePicker.open({ id = "x", type = "striker" }, slot("striker", 1))
    local r = ModePicker.rects(p)
    local function c(b) return b.x + b.w / 2, b.y + b.h / 2 end
    T.eq(ModePicker.actionAt(p, c(r.attack)), "attack")
    T.eq(ModePicker.actionAt(p, c(r.defense)), "defense")
    T.eq(ModePicker.actionAt(p, r.panel.x + 2, r.panel.y + 2), "inside")
    T.eq(ModePicker.actionAt(p, 5, 795), "outside")
end)

T.test("mode picker: A attacks, D defends, Esc cancels", function()
    T.eq(ModePicker.keyAction("a"), "attack")
    T.eq(ModePicker.keyAction("d"), "defense")
    T.eq(ModePicker.keyAction("escape"), "cancel")
    T.eq(ModePicker.keyAction("m"), nil)
end)
