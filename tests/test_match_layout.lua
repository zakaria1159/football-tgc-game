local T      = require("tests.t")
local Layout = require("ui.match.layout")

local function inside(r, box)
    return r.x >= box.x and r.y >= box.y and r.x + r.w <= box.x + box.w and r.y + r.h <= box.y + box.h
end
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function all()
    local list = Layout.slots()
    for _, t in ipairs(Layout.trapSlots()) do list[#list + 1] = t end
    return list
end

T.test("every slot and trap slot sits inside the pitch", function()
    for _, s in ipairs(all()) do
        T.ok(inside(s, Layout.pitch), s.owner .. " " .. s.slotType .. " " .. s.slotIndex .. " outside pitch")
    end
    T.eq(#Layout.slots(), 12); T.eq(#Layout.trapSlots(), 4)
end)

T.test("opponent slots mirror player slots around x=640", function()
    for _, s in ipairs(Layout.slots()) do
        if s.owner == "player" then
            local o = Layout.slot("opponent", s.slotType, s.slotIndex)
            T.near(o.x + o.w / 2, 1280 - (s.x + s.w / 2)); T.eq(o.y, s.y)
        end
    end
    for i = 1, 2 do
        local p, o = Layout.trapSlot("player", i), Layout.trapSlot("opponent", i)
        T.near(o.x + o.w / 2, 1280 - (p.x + p.w / 2)); T.eq(o.y, p.y)
    end
end)

T.test("two-card columns stack, single-card columns are centred", function()
    local d1, d2 = Layout.slot("player", "defender", 1), Layout.slot("player", "defender", 2)
    T.eq(d1.x, d2.x); T.ok(d2.y >= d1.y + d1.h + 20, "stack gap leaves room for badges")
    local k = Layout.slot("player", "keeper", 0)
    T.near(k.y + k.h / 2, Layout.pitch.y + Layout.pitch.h / 2)
    T.eq(k.w, 108); T.eq(k.h, 148)
end)

T.test("no two slots overlap", function()
    local list = all()
    for i = 1, #list do
        for j = i + 1, #list do
            T.ok(not overlap(list[i], list[j]), "overlap " .. i .. " / " .. j)
        end
    end
end)

T.test("top bar and bottom area rects are on screen and disjoint", function()
    local T0, B = Layout.top, Layout.bottom
    local rects = { T0.youBar, T0.oppBar, T0.phasePill, T0.turnChip, T0.pause, T0.music, T0.log, T0.oppDeck,
        B.portrait, B.deck, B.deckCount, B.summons, B.startAttack, B.endTurn, B.hint, B.hand,
        Layout.toastRect(1), Layout.toastRect(2), Layout.toastRect(3) }
    local screen = { x = 0, y = 0, w = 1280, h = 800 }
    for i = 1, #rects do
        T.ok(inside(rects[i], screen), "rect " .. i .. " off screen")
        for j = i + 1, #rects do T.ok(not overlap(rects[i], rects[j]), "overlap " .. i .. " / " .. j) end
    end
end)

T.test("buttonAt maps clicks to actions", function()
    local function c(r) return r.x + r.w / 2, r.y + r.h / 2 end
    local B, T0 = Layout.bottom, Layout.top
    local x, y = c(B.endTurn);     T.eq(Layout.buttonAt(x, y, "attack"), "endTurn")
    x, y = c(B.startAttack);       T.eq(Layout.buttonAt(x, y, "summon"), "startAttack")
    T.eq(Layout.buttonAt(x, y, "attack"), nil)
    T.eq(Layout.bottom.toggle, nil, "the ATTACK/DEFENSE toggle is gone (mode picker)")
    T.eq(Layout.toggleHalf, nil)
    x, y = c(T0.pause); T.eq(Layout.buttonAt(x, y, "summon"), "pause")
    x, y = c(T0.music); T.eq(Layout.buttonAt(x, y, "summon"), "music")
    x, y = c(T0.log);   T.eq(Layout.buttonAt(x, y, "summon"), "log")
    T.eq(Layout.buttonAt(640, 300, "summon"), nil)
end)

T.test("toast rects stack upward from the newest", function()
    T.eq(Layout.toastRect(1).y, 640); T.eq(Layout.toastRect(2).y, 606); T.eq(Layout.toastRect(3).y, 572)
end)

T.test("slot returns nil for unknown slots", function()
    T.eq(Layout.slot("player", "defender", 3), nil)
    T.eq(Layout.slot("player", "trap", 1), nil)
    T.eq(Layout.trapSlot("player", 3), nil)
end)
