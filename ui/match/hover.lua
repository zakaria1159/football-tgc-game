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

-- Whether a pitched card may be zoomed. The opponent's traps and unrevealed face-down
-- cards are hidden information; everything else (revealed cards included) is not.
-- Pure (unit-tested).
function Hover.zoomable(owner, slotType, card)
    if not card then return false end
    if owner ~= "opponent" then return true end
    if slotType == "trap" then return false end
    return card.mode ~= "defense" or card.revealed == true
end

return Hover
