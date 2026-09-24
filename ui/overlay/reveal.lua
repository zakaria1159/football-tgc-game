-- Scout Report reveal: the card flips up at zoom size under a SCOUTED ribbon and shrinks
-- away as the timer runs out. Reveal.pose is pure (unit-tested); draw uses LÖVE.
-- Input is unchanged: a click dismisses (scenes/match.lua).
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local C     = require("ui.overlay.combatfx")   -- progress / backout

local Reveal = {}
Reveal.FLIP_DUR = 0.45
Reveal.OUT_DUR  = 0.30

local W, H   = 1280, 800
local CW, CH = 200, 274
local CX, CY = 640, 390

-- elapsed: seconds since shown; remaining: seconds left on the timer.
function Reveal.pose(elapsed, remaining)
    local f   = C.progress(elapsed, 0, Reveal.FLIP_DUR)
    local out = 1 - C.progress(remaining, 0, Reveal.OUT_DUR)
    return {
        flipX  = math.abs(math.cos(f * math.pi)),
        faceUp = f >= 0.5,
        scale  = (0.8 + 0.2 * f) * (1 - out),
        alpha  = 1 - out,
        ribbon = C.backout(C.progress(elapsed, 0.3, 0.25)) * (1 - out),
        hint   = C.progress(elapsed, 0.6, 0.25) * (1 - out),
    }
end

function Reveal.draw(pitched, elapsed, remaining)
    local p = Reveal.pose(elapsed, remaining)
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.72 * p.alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local def = pitched and pitched.definition
    if def then
        love.graphics.push()
        love.graphics.translate(CX, CY)
        love.graphics.scale(p.scale * p.flipX, p.scale)
        if p.faceUp then
            Card.drawFace(def, -CW / 2, -CH / 2, CW, CH, {})
        else
            Card.drawBack(-CW / 2, -CH / 2, CW, CH, { label = "DEF" })
        end
        love.graphics.pop()
    else
        Draw.text("NO CARD IN THAT SLOT", 0, CY - 20, W, "center", {
            size = 32, color = Theme.white, shadowY = 3, alpha = p.alpha,
        })
    end

    if p.ribbon > 0 then
        local ry = CY - CH / 2 - 84
        love.graphics.push()
        love.graphics.translate(CX, ry + 30)
        love.graphics.scale(p.ribbon, p.ribbon)
        love.graphics.translate(-CX, -(ry + 30))
        Draw.ribbon(CX, ry, 340, 60, "SCOUTED", {
            fill = Theme.outcome.blue, textColor = Theme.white, size = 38, textShadow = true,
        })
        love.graphics.pop()
    end
    if p.hint > 0 then Draw.hintPill(CX, CY + CH / 2 + 48, "CLICK TO DISMISS", p.hint) end
end

return Reveal
