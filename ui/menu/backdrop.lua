-- Menu background: arcade gradient, slow-scrolling soft diagonal stripes and big faded
-- card backs in the corners. Shared by home, deck select and the card library.
local Draw = require("ui.kit.draw")
local Card = require("ui.card")

local Backdrop = {}

Backdrop.STRIPE_SPACING = 90
Backdrop.STRIPE_SPEED   = 18     -- px per second

-- Stripe phase at time t, in [0, STRIPE_SPACING). Pure (unit-tested).
function Backdrop.offset(t)
    return (t * Backdrop.STRIPE_SPEED) % Backdrop.STRIPE_SPACING
end

-- Top-left corners of the 200×274 faded card backs (partly off-screen) and their tilt.
local CORNERS = {
    { x = -60,  y = -70, rot = -0.35 },
    { x = 1150, y = -90, rot = 0.30 },
    { x = -80,  y = 610, rot = 0.28 },
    { x = 1140, y = 600, rot = -0.32 },
}

-- t: seconds (drives the stripe scroll). cards == false hides the corner card backs.
function Backdrop.draw(t, W, H, cards)
    Draw.background(W, H)
    local sp = Backdrop.STRIPE_SPACING
    Draw.stripes(-sp + Backdrop.offset(t), 0, W + sp, H, sp, 34, { 1, 1, 1, 0.06 })
    if cards == false then return end
    for _, c in ipairs(CORNERS) do
        love.graphics.push()
        love.graphics.translate(c.x + 100, c.y + 137)
        love.graphics.rotate(c.rot)
        Card.drawBack(-100, -137, 200, 274, { alpha = 0.22 })
        love.graphics.pop()
    end
end

return Backdrop
