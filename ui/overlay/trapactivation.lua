-- Trap activation overlay (arcade). Behaviour and data contract unchanged:
--   rec = { activator = "player" | "opponent", trapDef, contextText }   (store:_pushTrapActivation)
-- TrapActivation.draw(rec, t): t = seconds since it opened (ui/overlay/trapfx.lua).
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local Fx    = require("ui.overlay.trapfx")

local TrapActivation = {}

local W, H    = 1280, 800
local CW, CH  = 200, 274
local CX, CY  = 640, 290       -- card centre
local STAMP_Y = 350

function TrapActivation.draw(rec, t)
    if not rec then return end
    local p = Fx.pose(t or 0)
    local purple = Theme.outcome.purple

    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if p.flash > 0 then
        Draw.setColor(purple[1], p.flash * 0.7)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    Draw.setColor(purple[1], 0.35)
    love.graphics.circle("fill", CX, CY, 230, 64)

    -- Card: spins in, scales up, flips face-up
    if p.scale > 0 then
        love.graphics.push()
        love.graphics.translate(CX, CY)
        love.graphics.rotate(p.spin)
        love.graphics.scale(p.scale * p.flipX, p.scale)
        if p.faceUp and rec.trapDef then
            Card.drawFace(rec.trapDef, -CW / 2, -CH / 2, CW, CH, {})
        else
            Card.drawBack(-CW / 2, -CH / 2, CW, CH, { label = "TRAP" })
        end
        love.graphics.pop()
    end

    -- Dust puff where the stamp lands
    if p.dust > 0 and p.dust < 1 then
        for _, d in ipairs(Fx.dustPuffs(p.dust, 8)) do
            love.graphics.setColor(1, 1, 1, d.a)
            love.graphics.circle("fill", CX + d.dx, STAMP_Y + 34 + d.dy, d.r, 24)
        end
    end

    -- "TRAP ACTIVATED!" stamp
    if p.stamp > 0 then
        love.graphics.push()
        love.graphics.translate(CX, STAMP_Y)
        love.graphics.rotate(-0.12)
        love.graphics.scale(p.stampScale, p.stampScale)
        Draw.sticker(-190, -34, 380, 68, { r = 14, fill = purple, border = 4, shadow = 6, alpha = p.stampAlpha })
        Draw.text("TRAP ACTIVATED!", -180, -24, 360, "center", {
            size = 42, color = Theme.white, shadowY = 3, alpha = p.stampAlpha, fit = true,
        })
        love.graphics.pop()
    end

    -- Who activated it
    if p.ribbon > 0 then
        local mine = rec.activator == "player"
        local ry = 500
        love.graphics.push()
        love.graphics.translate(CX, ry + 30)
        love.graphics.scale(p.ribbon, p.ribbon)
        love.graphics.translate(-CX, -(ry + 30))
        Draw.ribbon(CX, ry, 520, 60, Fx.headline(rec.activator), {
            fill = mine and Theme.button.primary.fill or Theme.outcome.red,
            textColor = mine and Theme.button.primary.text or Theme.white, size = 34, textShadow = not mine,
        })
        love.graphics.pop()
    end

    -- Trap name, effect and context
    if p.text > 0 then
        local a = p.text
        local px, py, pw, ph = CX - 300, 584, 600, 124
        Draw.sticker(px, py, pw, ph, { r = 18, fill = Theme.white, border = 0, shadow = 5, alpha = a })
        Draw.text(rec.trapDef and rec.trapDef.name or "TRAP", px + 16, py + 10, pw - 32, "center", {
            size = 24, color = Theme.typeGrad.trap[2], alpha = a, fit = true,
        })
        Draw.text(Fx.effectText(rec.trapDef), px + 16, py + 44, pw - 32, "center", {
            size = 15, body = true, color = Theme.inkText, alpha = a,
        })
        Draw.text(rec.contextText or "", px + 16, py + 88, pw - 32, "center", {
            size = 14, body = true, color = { 0.42, 0.42, 0.6, 1 }, alpha = a,
        })
    end

    if p.hint > 0 then Draw.hintPill(CX, 744, "CLICK OR SPACE", p.hint) end
end

return TrapActivation
