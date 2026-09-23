local T        = require("tests.t")
local HomeMenu = require("ui.menu.home")
local Backdrop = require("ui.menu.backdrop")

T.test("home buttons are centred, stacked below the logo and on screen", function()
    local prev
    for i = 1, #HomeMenu.ITEMS do
        local r = HomeMenu.buttonRect(i)
        T.near(r.x + r.w / 2, 640)
        T.ok(r.y >= 330 and r.y + r.h <= 700, "button " .. i .. " outside its band")
        if prev then T.ok(r.y >= prev.y + prev.h + 10, "buttons " .. (i - 1) .. "/" .. i .. " overlap") end
        prev = r
    end
    T.eq(HomeMenu.ITEMS[1].id, "play"); T.eq(HomeMenu.ITEMS[2].id, "library"); T.eq(HomeMenu.ITEMS[3].id, "quit")
    T.eq(HomeMenu.ITEMS[2].variant, "blue")
end)

T.test("buttonAt maps button centres and misses elsewhere", function()
    for i = 1, 3 do
        local r = HomeMenu.buttonRect(i)
        T.eq(HomeMenu.buttonAt(r.x + r.w / 2, r.y + r.h / 2), i)
    end
    T.eq(HomeMenu.buttonAt(100, 100), nil)
    T.eq(HomeMenu.buttonAt(640, 340), nil)
    local a, b = HomeMenu.buttonRect(1), HomeMenu.buttonRect(2)
    T.eq(HomeMenu.buttonAt(640, (a.y + a.h + b.y) / 2), nil)
end)

T.test("logo bob stays within 6px", function()
    for t = 0, 5, 0.1 do T.ok(math.abs(HomeMenu.bob(t)) <= 6 + 1e-9) end
end)

T.test("backdrop stripes scroll and wrap every stripe spacing", function()
    T.near(Backdrop.offset(0), 0)
    T.near(Backdrop.offset(1), Backdrop.STRIPE_SPEED)
    T.near(Backdrop.offset(Backdrop.STRIPE_SPACING / Backdrop.STRIPE_SPEED), 0, 1e-6)
    for t = 0, 20, 0.7 do
        local o = Backdrop.offset(t)
        T.ok(o >= 0 and o < Backdrop.STRIPE_SPACING)
    end
end)
