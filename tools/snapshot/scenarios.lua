-- Timed scripts for tools/snapshot/snap.sh. Each step: { seconds, function(ctx) ... end }.
-- ctx.snap(label) saves a screenshot; ctx.quit() exits. Every scenario must end with ctx.quit().
local S = {}

S.home = {
    { 1.0, function(c) c.snap("deck") end },
    { 1.5, function(c) c.quit() end },
}

S.library = {
    { 0.5, function() love.mousepressed(640, 538, 1) end },  -- CARD LIBRARY button (scenes/home.lua)
    { 1.5, function(c) c.snap("grid") end },
    { 2.0, function(c) c.quit() end },
}

S.match = {
    { 0.5, function() love.keypressed("return") end },       -- start with the first deck
    { 3.0, function(c) c.snap("start") end },
    { 9.0, function(c) c.snap("later") end },
    { 9.5, function(c) c.quit() end },
}

return S
