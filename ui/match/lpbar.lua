-- LP bar with count-down numbers and a trailing white "damage chunk".
-- State logic is pure (unit-tested); LPBar.draw uses LÖVE.
-- Fills are flat rounded rects (no gradient meshes) because their width animates.
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")

local LPBar = {}
LPBar.__index = LPBar

LPBar.COUNT_TIME  = 0.6    -- number + fill count down
LPBar.CHUNK_DELAY = 0.35   -- white chunk waits...
LPBar.CHUNK_TIME  = 0.45   -- ...then drains

function LPBar.new(value, max)
    return setmetatable({
        max = max or 4000, target = value, shown = value, chunk = value,
        from = value, chunkFrom = value, t = 0, active = false,
    }, LPBar)
end

function LPBar:set(value)
    if value == self.target then return end
    if value > self.target then          -- gains are instant
        self.target, self.shown, self.chunk = value, value, value
        self.active = false
        return
    end
    self.from      = self.shown
    self.chunkFrom = self.chunk
    self.target    = value
    self.t         = 0
    self.active    = true
end

function LPBar:update(dt)
    if not self.active then return end
    self.t = self.t + dt
    local k = math.min(1, self.t / LPBar.COUNT_TIME)
    k = 1 - (1 - k) * (1 - k)            -- ease-out
    self.shown = math.floor(self.from + (self.target - self.from) * k + 0.5)
    local ct = math.min(1, math.max(0, self.t - LPBar.CHUNK_DELAY) / LPBar.CHUNK_TIME)
    self.chunk = self.chunkFrom + (self.target - self.chunkFrom) * ct
    if k >= 1 and ct >= 1 then
        self.shown, self.chunk, self.active = self.target, self.target, false
    end
end

-- fill ratio, chunk ratio (chunk never smaller than fill), both clamped to 0..1.
function LPBar:ratios()
    local f = math.max(0, math.min(1, self.shown / self.max))
    local c = math.max(0, math.min(1, self.chunk / self.max))
    return f, math.max(f, c)
end

-- r: rect; grad: {top, bottom}; mirrored: fill anchored at the right edge (opponent).
function LPBar.draw(bar, r, grad, label, mirrored)
    Draw.sticker(r.x, r.y, r.w, r.h, {
        r = r.h / 2, fill = { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.6 }, border = 3, shadow = 4,
    })
    local inset = 5
    local ix, iy, iw, ih = r.x + inset, r.y + inset, r.w - inset * 2, r.h - inset * 2
    local f, c = bar:ratios()
    local fw, cw = math.floor(iw * f + 0.5), math.floor(iw * c + 0.5)
    local function left(w) return mirrored and (ix + iw - w) or ix end
    if cw > 0 then Draw.roundedFill(left(cw), iy, cw, ih, ih / 2, Theme.white) end
    if fw > 0 then
        Draw.roundedFill(left(fw), iy, fw, ih, ih / 2, grad[2])
        local gh = math.floor(ih * 0.55)
        Draw.roundedFill(left(fw), iy, fw, gh, gh / 2, grad[1])
    end
    Draw.text(label, r.x, r.y + (r.h - 18) / 2 - 2, r.w, "center", {
        size = 18, color = Theme.white, outline = 2, outlineColor = Theme.ink,
    })
end

return LPBar
