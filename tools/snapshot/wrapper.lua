-- Dev-only snapshot driver. snap.sh copies the project to a temp dir, renames the
-- real main.lua to real_main.lua and installs this file as main.lua.
require("real_main")

local scenarios = require("tools.snapshot.scenarios")
local out   = assert(os.getenv("SNAP_OUT"), "SNAP_OUT not set")
local name  = os.getenv("SNAP_SCENARIO") or "home"
local steps = assert(scenarios[name], "unknown scenario: " .. name)

local ctx = {}
function ctx.snap(label)
    love.graphics.captureScreenshot(function(img)
        local f = assert(io.open(out .. "/" .. name .. "_" .. label .. ".png", "wb"))
        f:write(img:encode("png"):getString())
        f:close()
    end)
end
function ctx.quit() love.event.quit() end

local t, i = 0, 1
local baseUpdate = love.update
function love.update(dt)
    if baseUpdate then baseUpdate(dt) end
    t = t + dt
    while steps[i] and t >= steps[i][1] do
        steps[i][2](ctx)
        i = i + 1
    end
end
