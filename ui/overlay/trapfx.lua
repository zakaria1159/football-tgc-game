-- Trap activation timeline. Pure (unit-tested); ui/overlay/trapactivation.lua draws from it.
local C = require("ui.overlay.combatfx")   -- progress / backout / quadout

local Fx = {}

Fx.FLASH_DUR  = 0.35   -- purple full-screen flash fades out
Fx.FLIP       = 0.10   -- trap card spins in and flips face-up
Fx.FLIP_DUR   = 0.50
Fx.STAMP      = 0.65   -- "TRAP ACTIVATED!" stamp slams down
Fx.STAMP_DUR  = 0.25
Fx.STAMP_FROM = 2.6    -- stamp starting scale
Fx.DUST       = 0.80   -- dust puff where the stamp lands
Fx.DUST_DUR   = 0.55
Fx.RIBBON     = 0.95   -- "YOU ACTIVATED A TRAP" / "OPPONENT TRAP"
Fx.RIBBON_DUR = 0.30
Fx.TEXT       = 1.15   -- trap name, effect and context
Fx.TEXT_DUR   = 0.25
Fx.HINT       = 1.45

local EFFECT = {
    OFFSIDE            = "Striker attack cancelled — caught offside!",
    RED_CARD           = "Winning attacker sent off!",
    VAR                = "VAR Review in progress",
    LAST_DEFENDER_FOUL = "Last defender fouled — direct free shot awarded!",
    MANAGERS_CHALLENGE = "Opposing trap negated — challenge upheld!",
}

function Fx.pose(t)
    local p = {}
    p.flash = 1 - C.progress(t, 0, Fx.FLASH_DUR)
    local f = C.progress(t, Fx.FLIP, Fx.FLIP_DUR)
    p.scale  = t < Fx.FLIP and 0 or 0.3 + 0.7 * C.backout(f)
    p.spin   = -(1 - C.quadout(f)) * math.pi * 1.5
    p.flipX  = math.abs(math.cos(f * math.pi))
    p.faceUp = f >= 0.5
    p.stamp  = C.progress(t, Fx.STAMP, Fx.STAMP_DUR)
    p.stampScale = Fx.STAMP_FROM - (Fx.STAMP_FROM - 1) * C.backout(p.stamp)
    p.stampAlpha = math.min(1, p.stamp * 4)
    p.dust   = C.progress(t, Fx.DUST, Fx.DUST_DUR)
    p.ribbon = t < Fx.RIBBON and 0 or C.backout(C.progress(t, Fx.RIBBON, Fx.RIBBON_DUR))
    p.text   = C.progress(t, Fx.TEXT, Fx.TEXT_DUR)
    p.hint   = C.progress(t, Fx.HINT, 0.25)
    return p
end

function Fx.headline(activator)
    if activator == "player" then return "YOU ACTIVATED A TRAP" end
    return "OPPONENT TRAP"
end

function Fx.effectText(trapDef)
    if not trapDef then return "" end
    return EFFECT[trapDef.ability] or trapDef.abilityText or ""
end

-- n dust puffs at progress k: spread sideways and slightly down from the stamp's
-- bottom edge, growing and fading. Each: { dx, dy, r, a }.
function Fx.dustPuffs(k, n)
    local out = {}
    local d = 30 + 110 * C.quadout(k)
    for i = 1, n do
        local ang = math.pi * (i - 0.5) / n
        out[i] = { dx = math.cos(ang) * d * 1.6, dy = math.sin(ang) * d * 0.35, r = 10 + 18 * k, a = 0.85 * (1 - k) }
    end
    return out
end

return Fx
