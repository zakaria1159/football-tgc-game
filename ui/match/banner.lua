-- Ribbon banner for Match.flash messages (MIDFIELD CONTROL, GOAL!, errors).
-- Timing is pure (unit-tested); draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local Banner = {}
Banner.__index = Banner

Banner.IN, Banner.HOLD, Banner.OUT = 0.3, 1.6, 0.35
Banner.Y, Banner.W, Banner.H = 250, 560, 60
Banner.SLIDE = 900

local STYLES = {
    good  = { fill = Theme.button.go.fill,      text = Theme.white,               shadow = true },
    bad   = { fill = Theme.button.danger.fill,  text = Theme.white,               shadow = true },
    info  = { fill = Theme.button.primary.fill, text = Theme.button.primary.text, shadow = false },
    error = { fill = Theme.button.neutral.fill, text = Theme.inkText,             shadow = false },
}

function Banner.new() return setmetatable({ text = nil, kind = "info", t = 0 }, Banner) end

function Banner.total() return Banner.IN + Banner.HOLD + Banner.OUT end

function Banner:show(text, kind)
    self.text, self.kind, self.t = text, kind or "info", 0
end

function Banner:update(dt)
    if not self.text then return end
    self.t = self.t + dt
    if self.t >= Banner.total() then self.text = nil end
end

-- x offset and alpha at time t.
function Banner.pose(t)
    if t < Banner.IN then
        local k = 1 - t / Banner.IN
        return -Banner.SLIDE * k * k * k, 1
    elseif t < Banner.IN + Banner.HOLD then
        return 0, 1
    end
    local k = math.min(1, (t - Banner.IN - Banner.HOLD) / Banner.OUT)
    return Banner.SLIDE * k * k, 1 - k
end

function Banner:draw()
    if not self.text then return end
    local dx, a = Banner.pose(self.t)
    local st = STYLES[self.kind] or STYLES.info
    Draw.ribbon(Layout.midX + dx, Banner.Y, Banner.W, Banner.H, self.text, {
        fill = st.fill, textColor = st.text, size = 32, alpha = a, textShadow = st.shadow,
    })
end

return Banner
