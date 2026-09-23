-- Keyboard focus over a list of `count` items. Pure (unit-tested).
local Nav = {}
Nav.__index = Nav

-- opts: wrap (default false), index (default 1)
function Nav.new(count, opts)
    opts = opts or {}
    return setmetatable({ count = count, index = opts.index or 1, wrap = opts.wrap or false }, Nav)
end

function Nav:move(d)
    local i = self.index + d
    if self.wrap then
        i = (i - 1) % self.count + 1
    else
        i = math.max(1, math.min(self.count, i))
    end
    self.index = i
    return i
end

-- Focus item i if it exists. Returns the focused index.
function Nav:set(i)
    if i and i >= 1 and i <= self.count then self.index = i end
    return self.index
end

return Nav
