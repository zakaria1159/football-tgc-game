local T     = require("tests.t")
local Icons = require("ui.kit.icons")

T.test("each card type maps to an icon file that exists", function()
    for _, t in ipairs({ "striker", "defender", "midfielder", "keeper", "trap", "strategy", "formation" }) do
        local name = Icons.forType(t)
        local f = io.open("assets/icons/" .. name .. ".png", "rb")
        T.ok(f, "missing assets/icons/" .. name .. ".png for " .. t)
        if f then f:close() end
    end
end)

T.test("unknown types fall back to the ball", function()
    T.eq(Icons.forType("banana"), "soccer-ball")
    T.eq(Icons.forType(nil), "soccer-ball")
end)
