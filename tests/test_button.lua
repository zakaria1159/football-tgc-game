local T      = require("tests.t")
local Button = require("ui.kit.button")

local function mk(extra)
    local o = { label = "GO", x = 100, y = 50, w = 200, h = 60 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return Button.new(o)
end

T.test("contains uses the button rect", function()
    local b = mk()
    T.ok(b:contains(100, 50)); T.ok(b:contains(300, 110))
    T.ok(not b:contains(99, 50)); T.ok(not b:contains(150, 111))
end)

T.test("hover and press follow the mouse", function()
    local b = mk()
    b:update(0.016, 150, 70, false)
    T.ok(b.hover and not b.pressed)
    b:update(0.016, 150, 70, true)
    T.ok(b.pressed)
    b:update(0.016, 10, 10, false)
    T.ok(not b.hover and not b.pressed)
end)

T.test("lift eases toward -2 on hover and +shadow on press", function()
    local b = mk()
    for _ = 1, 120 do b:update(1 / 60, 150, 70, false) end
    T.near(b.lift, -2, 0.05)
    for _ = 1, 120 do b:update(1 / 60, 150, 70, true) end
    T.near(b.lift, b.shadow, 0.05)
end)

T.test("disabled buttons ignore the mouse", function()
    local b = mk({ enabled = false })
    b:update(0.016, 150, 70, true)
    T.ok(not b.hover and not b.pressed)
    T.ok(not b:hit(150, 70))
end)

T.test("hit returns true only when enabled and inside", function()
    local b = mk()
    T.ok(b:hit(150, 70)); T.ok(not b:hit(0, 0))
end)

T.test("default variant is primary; shadow scales with height", function()
    local b = mk()
    T.eq(b.variant, "primary")
    T.eq(b.shadow, 6)
end)
