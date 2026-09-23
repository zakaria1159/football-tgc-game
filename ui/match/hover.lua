-- Hover-with-delay tracker. Pure (unit-tested).
local Hover = {}
Hover.__index = Hover
Hover.DELAY = 0.3

function Hover.new(delay)
    return setmetatable({ key = nil, t = 0, delay = delay or Hover.DELAY, payload = nil }, Hover)
end

-- key: stable id of the thing under the mouse (nil = nothing). Returns true once shown.
function Hover:update(dt, key, payload)
    if key ~= self.key then
        self.key, self.t, self.payload = key, 0, payload
        return false
    end
    if key == nil then return false end
    self.t = self.t + dt
    self.payload = payload
    return self.t >= self.delay
end

function Hover:shown() return self.key ~= nil and self.t >= self.delay end

function Hover:reset() self.key, self.t, self.payload = nil, 0, nil end

return Hover
