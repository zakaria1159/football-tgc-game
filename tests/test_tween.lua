local T     = require("tests.t")
local flux  = require("lib.flux")
local Tween = require("ui.kit.tween")

local function run(seconds) for _ = 1, math.floor(seconds * 60) do flux.update(1 / 60) end end

T.test("popIn scales 0 -> 1", function()
    local o = {}
    Tween.popIn(o, 0.3)
    T.near(o.scale, 0)
    run(0.5)
    T.near(o.scale, 1, 1e-3)
end)

T.test("squash returns sx/sy to 1", function()
    local o = { sx = 1, sy = 1 }
    Tween.squash(o, 0.3)
    T.ok(o.sx ~= 1 or o.sy ~= 1, "squash starts deformed")
    run(0.6)
    T.near(o.sx, 1, 1e-3); T.near(o.sy, 1, 1e-3)
end)

T.test("bounce returns key to 0", function()
    local o = { y = 0 }
    Tween.bounce(o, "y", 12, 0.3)
    run(0.6)
    T.near(o.y, 0, 1e-3)
end)

T.test("countTo reaches the integer target", function()
    local o = { lp = 4000 }
    Tween.countTo(o, "lp", 3400, 0.4)
    run(0.6)
    T.eq(o.lp, 3400)
end)
