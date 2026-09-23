-- Multicolor confetti bursts (goal / LP damage). One particle system per color,
-- since a ParticleSystem's colors are shared by all its particles.
local Theme = require("ui.theme")

local Confetti = {}

local COLORS = { "ffd23a", "ff5ec8", "4fb8ff", "7dff8a", "ff7a59", "ffffff" }
local systems = nil

local function build()
    systems = {}
    local tex = love.graphics.newCanvas(8, 4)
    love.graphics.push("all")
    love.graphics.setCanvas(tex)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setCanvas()
    love.graphics.pop()
    for _, h in ipairs(COLORS) do
        local c = Theme.hex(h)
        local ps = love.graphics.newParticleSystem(tex, 60)
        ps:setParticleLifetime(1.0, 1.8)
        ps:setEmissionRate(0)
        ps:setDirection(-math.pi / 2)
        ps:setSpread(math.pi * 0.9)
        ps:setSpeed(260, 520)
        ps:setLinearAcceleration(0, 520, 0, 620)
        ps:setLinearDamping(0.8)
        ps:setSpin(-10, 10)
        ps:setRotation(0, math.pi * 2)
        ps:setSizes(1.2, 1.0)
        ps:setColors(c[1], c[2], c[3], 1, c[1], c[2], c[3], 1, c[1], c[2], c[3], 0)
        systems[#systems + 1] = ps
    end
end

-- Call from update (not while drawing): builds its texture on first use.
function Confetti.burst(x, y, n)
    if not systems then build() end
    local each = math.ceil((n or 60) / #systems)
    for _, ps in ipairs(systems) do
        ps:setPosition(x, y)
        ps:emit(each)
    end
end

function Confetti.update(dt)
    if not systems then return end
    for _, ps in ipairs(systems) do ps:update(dt) end
end

function Confetti.draw()
    if not systems then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, ps in ipairs(systems) do love.graphics.draw(ps) end
end

return Confetti
