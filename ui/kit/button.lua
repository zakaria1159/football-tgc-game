-- Chunky 3D arcade button. Logic (hover/press/lift) is pure; draw() uses LÖVE.
local Theme = require("ui.theme")

local Button = {}
Button.__index = Button

-- opts: label, x, y, w, h, variant ("primary"|"go"|"danger"|"neutral"|"icon"),
--       fontSize, icon (name in assets/icons), enabled (default true), id
function Button.new(opts)
    local b = setmetatable({}, Button)
    b.id       = opts.id
    b.label    = opts.label or ""
    b.x, b.y   = opts.x or 0, opts.y or 0
    b.w, b.h   = opts.w or 160, opts.h or 48
    b.variant  = opts.variant or "primary"
    b.fontSize = opts.fontSize
    b.icon     = opts.icon
    b.enabled  = opts.enabled ~= false
    b.focused  = false
    b.hover    = false
    b.pressed  = false
    b.lift     = 0
    b.shadow   = math.max(3, math.floor(b.h * 0.1))
    b.time     = 0
    return b
end

function Button:setRect(x, y, w, h)
    self.x, self.y = x, y
    if w then self.w = w end
    if h then self.h = h; self.shadow = math.max(3, math.floor(h * 0.1)) end
end

function Button:contains(mx, my)
    return mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function Button:hit(mx, my)
    return self.enabled and self:contains(mx, my)
end

function Button:update(dt, mx, my, mouseDown)
    self.time = self.time + dt
    local inside = self.enabled and self:contains(mx, my)
    self.hover   = inside
    self.pressed = inside and mouseDown or false
    local target = 0
    if self.pressed then target = self.shadow
    elseif self.hover or self.focused then target = -2 end
    self.lift = self.lift + (target - self.lift) * math.min(1, dt * 18)
end

function Button:draw()
    local Draw  = require("ui.kit.draw")
    local style = Theme.button[self.variant] or Theme.button.primary
    local alpha = self.enabled and 1 or 0.5
    local x, y, w, h = self.x, self.y + self.lift, self.w, self.h
    local r  = self.variant == "icon" and math.floor(h * 0.25) or math.floor(h * 0.28)
    local sh = math.max(0, self.shadow - self.lift)

    if self.focused and self.enabled then
        local pulse = 0.5 + 0.5 * math.sin(self.time * 5)
        Draw.glow(x, y, w, h, r, Theme.white, 0.6 + 0.4 * pulse)
    end

    Draw.sticker(x, y, w, h, {
        r = r, fill = style.fill, dir = "v",
        border = self.variant == "icon" and 2 or 3,
        borderColor = self.variant == "icon" and { 1, 1, 1, 0.55 } or Theme.white,
        shadow = sh, shadowColor = style.shadow, alpha = alpha,
    })
    -- glossy top highlight
    love.graphics.setColor(1, 1, 1, 0.22 * alpha)
    love.graphics.rectangle("fill", x + 6, y + 5, w - 12, h * 0.32, r * 0.6, r * 0.6, 8)

    local size = self.fontSize or math.floor(h * 0.42)
    local textX, textW = x + 8, w - 16
    if self.icon then
        local Icons = require("ui.kit.icons")
        local isz = math.floor(h * 0.5)
        if self.label == "" then
            Icons.draw(self.icon, x + w / 2, y + h / 2, isz, style.text, 1, alpha)
            return
        end
        Icons.draw(self.icon, x + 12 + isz / 2, y + h / 2, isz, style.text, 1, alpha)
        textX, textW = x + 16 + isz, w - 24 - isz
    end
    Draw.text(self.label, textX, y + (h - size) / 2 - size * 0.08, textW, "center", {
        size = size, color = style.text, fit = true, minSize = 8, alpha = alpha,
        shadowY = (self.variant == "primary" or self.variant == "neutral") and 0 or 2,
        shadowColor = style.shadow,
    })
end

return Button
