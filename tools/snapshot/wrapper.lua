-- Dev-only snapshot driver. snap.sh copies the project to a temp dir, renames the
-- real main.lua to real_main.lua and installs this file as main.lua.
function love.errorhandler(msg)
    io.stderr:write(debug.traceback(tostring(msg), 2) .. "\n")
    os.exit(1)
end

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

local lastStepTime = steps[#steps] and steps[#steps][1] or 0
local timedOut = false

local t, i = 0, 1
local baseUpdate = love.update
function love.update(dt)
    if baseUpdate then baseUpdate(dt) end
    -- Stall-proof: the script clock advances at most 1/30 s per frame and at most one
    -- step runs per frame, so a machine hiccup can't fire several steps in one frame.
    t = t + math.min(dt, 1 / 30)
    if steps[i] and t >= steps[i][1] then
        steps[i][2](ctx)
        i = i + 1
    end
    if not timedOut and (i > #steps or t > lastStepTime + 5) then
        timedOut = true
        if i <= #steps then
            io.stderr:write("snapshot: scenario timed out without calling quit()\n")
        end
        love.event.quit()
    end
end
