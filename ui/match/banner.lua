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
    half  = { fill = Theme.outcome.blue,        text = Theme.white,               shadow = true },
}

-- opts (all optional): y, w, h, size, hold, slide. Defaults are the flash banner.
function Banner.new(opts)
    opts = opts or {}
    return setmetatable({
        text = nil, kind = "info", t = 0,
        y = opts.y or Banner.Y, w = opts.w or Banner.W, h = opts.h or Banner.H,
        size = opts.size or 32, hold = opts.hold or Banner.HOLD, slide = opts.slide or Banner.SLIDE,
    }, Banner)
end

function Banner.total(hold) return Banner.IN + (hold or Banner.HOLD) + Banner.OUT end

function Banner:show(text, kind)
    self.text, self.kind, self.t = text, kind or "info", 0
end

function Banner:update(dt)
    if not self.text then return end
    self.t = self.t + dt
    if self.t >= Banner.total(self.hold) then self.text = nil end
end

-- x offset and alpha at time t (hold/slide default to the flash banner's).
function Banner.pose(t, hold, slide)
    hold, slide = hold or Banner.HOLD, slide or Banner.SLIDE
    if t < Banner.IN then
        local k = 1 - t / Banner.IN
        return -slide * k * k * k, 1
    elseif t < Banner.IN + hold then
        return 0, 1
    end
    local k = math.min(1, (t - Banner.IN - hold) / Banner.OUT)
    return slide * k * k, 1 - k
end

function Banner:draw()
    if not self.text then return end
    local dx, a = Banner.pose(self.t, self.hold, self.slide)
    local st = STYLES[self.kind] or STYLES.info
    Draw.ribbon(Layout.midX + dx, self.y, self.w, self.h, self.text, {
        fill = st.fill, textColor = st.text, size = self.size, alpha = a, textShadow = st.shadow,
    })
end

return Banner
