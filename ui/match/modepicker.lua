-- Mode picker (spec A1): after a card from the hand is dropped on a slot, a small panel
-- anchored on that slot asks ATTACK (face-up) or DEFEND (face-down). Keys: A, D, Esc (cancel:
-- the card stays selected, nothing is placed). Traps skip it (always face-down). Keepers get
-- a note: they never flip later. Substitutions use the same picker. Everything except
-- ModePicker.draw is pure (unit-tested).
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local ModePicker = {}

ModePicker.W      = 164
ModePicker.BTN_H  = 44
ModePicker.PAD    = 10
ModePicker.GAP    = 8
ModePicker.NOTE_H = 30
ModePicker.MARGIN = 8
ModePicker.KEEPER_NOTE = "Keepers never flip later"

-- True when placing cardDef needs a mode choice: field cards and keepers; not traps (always
-- face-down) or strategies (never placed).
function ModePicker.needsPicker(cardDef)
    local t = cardDef and cardDef.type
    return t == "striker" or t == "midfielder" or t == "defender" or t == "keeper"
end

-- Note under the buttons, or nil. A keeper (card or slot) keeps its mode for good.
function ModePicker.note(cardDef, slotType)
    if (cardDef and cardDef.type == "keeper") or slotType == "keeper" then return ModePicker.KEEPER_NOTE end
    return nil
end

-- A picker for placing cardDef on slot (a pitch hitbox { x, y, w, h, slotType, slotIndex }).
-- free: the Substitution card's free placement (store:freeSummon).
function ModePicker.open(cardDef, slot, free)
    return { cardId = cardDef.id, cardDef = cardDef, slot = slot, free = free == true,
             note = ModePicker.note(cardDef, slot.slotType) }
end

-- { panel, attack, defense, note } rects: the panel centred on the slot, kept on screen.
function ModePicker.rects(p)
    local P = ModePicker
    local h = P.PAD * 2 + P.BTN_H * 2 + P.GAP + (p.note and P.NOTE_H or 0)
    local s = p.slot
    local x = s.x + s.w / 2 - P.W / 2
    local y = s.y + s.h / 2 - h / 2
    x = math.max(P.MARGIN, math.min(Layout.W - P.MARGIN - P.W, x))
    y = math.max(P.MARGIN, math.min(Layout.H - P.MARGIN - h, y))
    local bw = P.W - P.PAD * 2
    return {
        panel   = { x = x, y = y, w = P.W, h = h },
        attack  = { x = x + P.PAD, y = y + P.PAD, w = bw, h = P.BTN_H },
        defense = { x = x + P.PAD, y = y + P.PAD + P.BTN_H + P.GAP, w = bw, h = P.BTN_H },
        note    = p.note and { x = x + P.PAD, y = y + P.PAD + P.BTN_H * 2 + P.GAP, w = bw, h = P.NOTE_H }
                  or nil,
    }
end

-- "attack" | "defense" for a click on a button, "inside" elsewhere on the panel, "outside".
function ModePicker.actionAt(p, x, y)
    local r = ModePicker.rects(p)
    if Layout.inRect(x, y, r.attack) then return "attack" end
    if Layout.inRect(x, y, r.defense) then return "defense" end
    if Layout.inRect(x, y, r.panel) then return "inside" end
    return "outside"
end

-- "attack" (A) | "defense" (D) | "cancel" (Esc) | nil.
function ModePicker.keyAction(key)
    if key == "a" then return "attack" end
    if key == "d" then return "defense" end
    if key == "escape" then return "cancel" end
    return nil
end

local function button(r, label, sub, fill, hover)
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 12, fill = fill, border = 3, shadow = hover and 5 or 3 })
    Draw.text(label, r.x, r.y + 5, r.w, "center", { size = 20, color = Theme.white, shadowY = 2 })
    Draw.text(sub, r.x, r.y + 27, r.w, "center", { size = 11, body = true, color = { 1, 1, 1, 0.9 } })
end

-- Draws the picker; mx, my: the mouse (the hovered button lifts).
function ModePicker.draw(p, mx, my)
    local r = ModePicker.rects(p)
    mx, my = mx or -1, my or -1
    Draw.sticker(r.panel.x, r.panel.y, r.panel.w, r.panel.h, { r = 16, fill = Theme.white, border = 4, shadow = 6 })
    button(r.attack, "ATTACK", "face-up  ·  A", Theme.grad.atk, Layout.inRect(mx, my, r.attack))
    button(r.defense, "DEFEND", "face-down  ·  D", Theme.grad.def, Layout.inRect(mx, my, r.defense))
    if r.note then
        Draw.text(p.note, r.note.x, r.note.y + 8, r.note.w, "center",
            { size = 12, body = true, color = Theme.inkText, fit = true, minSize = 9 })
    end
end

return ModePicker
