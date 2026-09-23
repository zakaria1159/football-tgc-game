-- Combat overlay (arcade). Behaviour and data contract unchanged:
--   rec = { attacker, defender, outcome, margin, damage, activePlayer, abilities }   (store:_pushCombat)
--   attacker / defender = { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper,
--                           atkTags, defTags }
-- CombatOverlay.draw(rec, t): t = seconds since the overlay opened. All timing lives in
-- ui/overlay/combatfx.lua (pure, unit-tested). The player's card is always on the left
-- (Fx.sides): when the opponent attacks, the attacker is drawn on the right and lunges left.
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local Fx    = require("ui.overlay.combatfx")

local CombatOverlay = {}

local W, H      = 1280, 800
local CW, CH    = 200, 274          -- zoom card size (ui/match/zoom.lua)
local CARD_Y    = 150
local BADGE_Y   = 540
local BADGE_S   = 96
local PAD       = 40                -- canvas margin (tag, badges, glow) for the shatter

local cache   = { rec = nil }       -- card views for the current record
local shatter = { view = nil }      -- canvas + pieces for the destroyed card

local function drawFace(view, x, y, exhausted)
    Card.drawFace(view.cardDef, x, y, CW, CH, {
        stats     = view.stats,
        atkBonus  = view.atkBonus > 0 and view.atkBonus or nil,
        defBonus  = view.defBonus > 0 and view.defBonus or nil,
        exhausted = exhausted or nil,
    })
end

-- Render the card once into a canvas and cut it into pieces.
local function buildShatter(view)
    if shatter.canvas then shatter.canvas:release() end
    local cw, ch = CW + PAD * 2, CH + PAD * 2
    local canvas = love.graphics.newCanvas(cw, ch)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    drawFace(view, PAD, PAD, false)
    love.graphics.setCanvas()
    love.graphics.pop()
    shatter.view, shatter.canvas = view, canvas
    shatter.pieces = Fx.shatterPieces(cw, ch, 3, 2, 7)
    shatter.quads = {}
    for i, pc in ipairs(shatter.pieces) do
        shatter.quads[i] = love.graphics.newQuad(pc.sx, pc.sy, pc.w, pc.h, cw, ch)
    end
end

local function drawShatter(view, cx, k)
    if shatter.view ~= view then buildShatter(view) end
    local ox, oy = cx - CW / 2 - PAD, CARD_Y - PAD
    love.graphics.setBlendMode("alpha", "premultiplied")
    for i, pc in ipairs(shatter.pieces) do
        local dx, dy, rot, a = Fx.piecePose(pc, k)
        love.graphics.setColor(a, a, a, a)
        love.graphics.draw(shatter.canvas, shatter.quads[i],
            ox + pc.sx + pc.w / 2 + dx, oy + pc.sy + pc.h / 2 + dy, rot, 1, 1, pc.w / 2, pc.h / 2)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- One combatant centred on cx. fate: "destroyed" | "exhausted" | nil.
local function drawSide(view, cx, p, fate)
    local x, y = cx - CW / 2, CARD_Y
    if not view then
        Draw.roundedFill(x, y, CW, CH, 24, { 1, 1, 1, 0.12 })
        Draw.text("EMPTY", x, y + CH / 2 - 16, CW, "center", { size = 28, color = { 1, 1, 1, 0.6 } })
        return
    end
    if fate == "destroyed" and p.shatter > 0 then
        drawShatter(view, cx, p.shatter)
        return
    end
    local flip = view.hidden and p.flip or 1
    love.graphics.push()
    love.graphics.translate(cx, y + CH)              -- squash / flip anchored at the bottom centre
    love.graphics.scale(p.sx * flip, p.sy)
    love.graphics.translate(-cx, -(y + CH))
    if view.hidden and not p.reveal then
        Card.drawBack(x, y, CW, CH, { label = "DEF" })
    else
        drawFace(view, x, y, fate == "exhausted" and p.result > 0)
    end
    love.graphics.pop()
end

-- VS badge before the clash, then the CLASH! starburst.
local function drawClash(p)
    local cx, cy = W / 2 + p.shake, CARD_Y + CH / 2
    if not p.reveal then
        Draw.setColor(Theme.ink);   love.graphics.circle("fill", cx, cy + 5, 42, 40)
        Draw.setColor(Theme.white); love.graphics.circle("fill", cx, cy, 42, 40)
        Draw.text("VS", cx - 42, cy - 21, 84, "center", { size = 38, color = Theme.inkText })
        return
    end
    local s = p.clash
    if s <= 0 then return end
    Draw.burst(cx, cy, 118 * s, 76 * s, 14, Theme.highlight.selected, 1, love.timer.getTime() * 0.5)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-0.08)
    love.graphics.scale(s, s)
    Draw.text("CLASH!", -130, -28, 260, "center", {
        size = 52, color = Theme.white, outline = 3, outlineColor = Theme.ink, shadowY = 4,
    })
    love.graphics.pop()
end

local TAG_Y = 462   -- ability tag row, between the cards and the big badges

-- Ability bonus tags ("LINK-UP +150") centred on cx, at most 3.
local function drawTags(tags, cx, alpha)
    local n = math.min(#tags, 3)
    if n == 0 then return end
    local tw, th, gap = 140, 26, 8
    local x0 = cx - (n * tw + (n - 1) * gap) / 2
    for i = 1, n do
        Draw.pill(x0 + (i - 1) * (tw + gap), TAG_Y, tw, th, tags[i], {
            fill = Theme.grad.keyword, textColor = Theme.inkText, size = 14, border = 2, shadow = 3,
            alpha = alpha,
        })
    end
end

-- Big ATK / DEF badges that grow and count up, with their labels and ability tags.
local function drawBadges(rec, p, sides)
    if p.badge <= 0 then return end
    local s = BADGE_S * p.badge
    local labelY = BADGE_Y + BADGE_S / 2 + 12
    local la = math.min(1, p.badge)                  -- labels fade in with the badges
    local a, d = cache.atk, cache.def
    if a then
        local x = sides.atk.cx + p.shake
        Draw.atkBadge(x, BADGE_Y, s, Fx.countValue(a.atk, p.count))
        Draw.pill(x - 60, labelY, 120, 28, a.atkBonus > 0 and ("ATK +" .. a.atkBonus) or "ATK", {
            fill = Theme.white, textColor = Theme.grad.atk[2], size = 16, border = 2, shadow = 3, alpha = la,
        })
        drawTags(a.atkTags, x, la)
    end
    if d then
        local x = sides.def.cx + p.shake
        Draw.defBadge(x, BADGE_Y, s * 0.95, Fx.countValue(d.def, p.count), d.defBonus > 0 and d.defBonus or nil)
        Draw.pill(x - 60, labelY, 120, 28, rec.defender.isKeeper and "EFF. DEF" or "DEF", {
            fill = Theme.white, textColor = Theme.grad.def[2], size = 16, border = 2, shadow = 3, alpha = la,
        })
        drawTags(d.defTags, x, la)
    end
end

function CombatOverlay.draw(rec, t)
    if not rec then return end
    if cache.rec ~= rec then
        cache = { rec = rec, atk = Fx.cardView(rec.attacker, Fx.lookup), def = Fx.cardView(rec.defender, Fx.lookup) }
    end
    local sides = Fx.sides(rec.activePlayer)
    local p = Fx.pose(t or 0, sides.atk.side)
    local atkFate, defFate = Fx.fates(rec.outcome)

    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local mine = rec.activePlayer ~= "opponent"
    Draw.pill(W / 2 - 160, 44, 320, 46, mine and "YOU ATTACK!" or "OPPONENT ATTACKS!", {
        fill = mine and Theme.button.primary.fill or Theme.outcome.red,
        textColor = mine and Theme.button.primary.text or Theme.white, size = 26, border = 3, shadow = 4,
    })

    local ax = sides.atk.cx + p.atkX + p.shake
    local dx = sides.def.cx + p.defX + p.shake
    -- The defender first, so the lunging attacker is drawn over it.
    drawSide(cache.def, dx, p, defFate)
    drawSide(cache.atk, ax, p, atkFate)
    drawClash(p)
    drawBadges(rec, p, sides)

    if p.result > 0 then
        local st = Fx.result(rec.outcome, rec.damage)
        local cy = 682
        love.graphics.push()
        love.graphics.translate(W / 2, cy)
        love.graphics.scale(p.result, p.result)
        love.graphics.translate(-W / 2, -cy)
        Draw.ribbon(W / 2, cy - 32, 540, 64, st.text, {
            fill = st.fill, textColor = st.textColor, size = 38, textShadow = st.shadow,
        })
        love.graphics.pop()
    end
    -- Rule abilities that fired (Clinical, Immovable, Punch clear …), under the banner.
    local line = Fx.abilityLine(rec)
    if line and p.result > 0 then
        Draw.pill(W / 2 - 180, 98, 360, 36, line, {
            fill = Theme.grad.keyword, textColor = Theme.inkText, size = 20, border = 3, shadow = 4,
            alpha = math.min(1, p.result),
        })
    end
    if p.hint > 0 then Draw.hintPill(W / 2, 744, "CLICK OR SPACE", p.hint) end
end

return CombatOverlay
