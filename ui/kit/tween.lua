-- Bouncy motion helpers on top of lib/flux. All return the flux tween.
local flux = require("lib.flux")

local Tween = {}

-- obj.scale 0 → 1 with overshoot.
function Tween.popIn(obj, dur)
    obj.scale = 0
    return flux.to(obj, dur or 0.3, { scale = 1 }):ease("backout")
end

-- Squash then spring back: obj.sx / obj.sy → 1.
function Tween.squash(obj, dur)
    obj.sx, obj.sy = 1.18, 0.82
    return flux.to(obj, dur or 0.3, { sx = 1, sy = 1 }):ease("elasticout")
end

-- Kick obj[key] by `amount` then settle back to 0.
function Tween.bounce(obj, key, amount, dur)
    obj[key] = amount
    return flux.to(obj, dur or 0.3, { [key] = 0 }):ease("elasticout")
end

-- Animate obj[key] to target, rounding to integers on every step (for counters).
function Tween.countTo(obj, key, target, dur)
    local proxy = { v = obj[key] or 0 }
    return flux.to(proxy, dur or 0.4, { v = target }):ease("quadout")
        :onupdate(function() obj[key] = math.floor(proxy.v + 0.5) end)
        :oncomplete(function() obj[key] = target end)
end

return Tween
