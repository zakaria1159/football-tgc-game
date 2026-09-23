-- Clash-portrait card renderer.
-- Public API (unchanged contract for existing callers):
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, canFlip, pitch, selected, target
--   Card.drawInHand(cardDef, x, y, opts)    opts: w, h, selected   → returns {x,y,w,h}
--   Card.drawTooltip(cardDef, x, y)
--   Card.drawLarge(cardDef, x, y, w)        → returns h
-- New:
--   Card.layout(w, h)                       pure geometry (unit-tested)
--   Card.drawFace(cardDef, x, y, w, h, opts) opts: stats, atkBonus, defBonus, exhausted, selected, target, alpha
--   Card.drawBack(x, y, w, h, opts)         opts: label, canFlip, selected, target, alpha
local Theme  = require("ui.theme")
local Combat = require("engine.combat")
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")

local Card = {}

local BASE_W = 108   -- design width; everything scales from here

-- ── Portrait cache (assets/cards/<id>.png|jpg) ────────────────────────────────

local _portraits = {}
local function getPortrait(cardDef)
    local id = cardDef and cardDef.id
    if not id then return nil end
    if _portraits[id] ~= nil then return _portraits[id] or nil end
    for _, ext in ipairs({ ".png", ".jpg" }) do
        local ok, img = pcall(love.graphics.newImage, "assets/cards/" .. id .. ext)
        if ok then
            img:setFilter("linear", "linear")
            _portraits[id] = img
            return img
        end
    end
    _portraits[id] = false
    return nil
end

-- ── Geometry ──────────────────────────────────────────────────────────────────

function Card.layout(w, h)
    local s = w / BASE_W
    local L = { w = w, h = h, s = s }
    L.border = math.max(2, math.floor(4 * s + 0.5))
    L.r      = math.floor(14 * s + 0.5)
    L.shadow = math.max(2, math.floor(5 * s + 0.5))

    local ribbonH = math.max(10, 20 * s)
    L.ribbon = { x = -6 * s, y = h * 0.66 - ribbonH / 2, w = w + 12 * s, h = ribbonH }

    local badge = math.max(16, 34 * s)
    L.atk = { cx = 8 * s,     cy = h - 6 * s, size = badge }
    L.def = { cx = w - 8 * s, cy = h - 6 * s, size = badge * 0.95 }

    L.tag = { cy = 0, h = math.max(9, 16 * s) }
    L.gem = { cx = w - 12 * s, cy = 12 * s, size = math.max(5, 9 * s) }

    local artTop, artBottom = L.border + 6 * s, L.ribbon.y - 2
    local iconSize = math.min(w * 0.56, (artBottom - artTop) * 0.92)
    L.icon = { cx = w / 2, cy = (artTop + artBottom) / 2, size = iconSize }
    return L
end

-- ── Pieces ────────────────────────────────────────────────────────────────────

local function drawTag(label, L, x, y, alpha)
    local size = math.max(7, math.floor(L.tag.h * 0.62))
    local tw = math.min(L.w - 8 * L.s, (#label * size * 0.62) + L.tag.h)
    Draw.pill(x + (L.w - tw) / 2, y + L.tag.cy - L.tag.h / 2, tw, L.tag.h, label, {
        fill = Theme.ink, textColor = Theme.white, border = math.max(1, math.floor(2 * L.s)),
        shadow = 0, size = size, alpha = alpha,
    })
end

local function drawGem(rarity, L, x, y, alpha)
    local c = Theme.rarityColors[rarity] or Theme.rarityColors.common
    local g = L.gem
    love.graphics.push()
    love.graphics.translate(x + g.cx, y + g.cy)
    love.graphics.rotate(math.pi / 4)
    Draw.setColor(Theme.white, alpha)
    love.graphics.rectangle("fill", -g.size / 2 - 2, -g.size / 2 - 2, g.size + 4, g.size + 4, 2)
    Draw.setColor(c, alpha)
    love.graphics.rectangle("fill", -g.size / 2, -g.size / 2, g.size, g.size, 1)
    love.graphics.pop()
end

local function drawRibbon(name, L, x, y, alpha)
    local rb = L.ribbon
    Draw.sticker(x + rb.x, y + rb.y, rb.w, rb.h, {
        r = math.max(3, 6 * L.s), fill = Theme.white, border = 0,
        shadow = math.max(1, math.floor(3 * L.s)), alpha = alpha,
    })
    local size = math.max(7, math.floor(rb.h * 0.62))
    Draw.text(name or "", x + rb.x + 4 * L.s, y + rb.y + (rb.h - size) / 2 - size * 0.06, rb.w - 8 * L.s, "center", {
        size = size, color = Theme.inkText, fit = true, minSize = 6, alpha = alpha,
    })
end

local function drawHighlights(L, x, y, opts, rarity)
    local a = opts.alpha or 1
    if rarity == "rare" or rarity == "legendary" then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.rarityColors[rarity], 0.9, a)
    end
    if opts.selected then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.highlight.selected, 1.4, a)
        Draw.ring(x - 3 * L.s, y - 3 * L.s, L.w + 6 * L.s, L.h + 6 * L.s, L.r + 3 * L.s,
            Theme.highlight.selected, math.max(2, 4 * L.s), a)
    elseif opts.target then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.highlight.target, 1.4, a)
        Draw.ring(x - 3 * L.s, y - 3 * L.s, L.w + 6 * L.s, L.h + 6 * L.s, L.r + 3 * L.s,
            Theme.highlight.target, math.max(2, 4 * L.s), a)
    end
end

local function drawExhausted(L, x, y, alpha)
    local ph = math.max(10, 16 * L.s)
    local pw = ph * 2.4
    Draw.pill(x + (L.w - pw) / 2, y + L.h * 0.30, pw, ph, "zzz", {
        fill = Theme.white, textColor = Theme.inkText, border = 0, shadow = math.max(1, math.floor(2 * L.s)),
        alpha = alpha,
    })
end

-- ── Face ──────────────────────────────────────────────────────────────────────

function Card.drawFace(cardDef, x, y, w, h, opts)
    opts = opts or {}
    local L     = Card.layout(w, h)
    local a     = opts.alpha or 1
    local ctype = cardDef.type
    local grad  = Theme.typeGrad[ctype] or Theme.typeGrad.formation

    drawHighlights(L, x, y, opts, cardDef.rarity)

    Draw.sticker(x, y, w, h, { r = L.r, fill = grad, dir = "d", border = L.border, shadow = L.shadow, alpha = a })

    local inX, inY = x + L.border, y + L.border
    local inW, inH = w - 2 * L.border, h - 2 * L.border
    local portrait = getPortrait(cardDef)
    if portrait then
        Draw.roundedImage(portrait, inX, inY, inW, inH, math.max(0, L.r - L.border), a)
    else
        -- soft top highlight + big type icon
        Draw.roundedFill(inX, inY, inW, inH * 0.5, math.max(0, L.r - L.border), { 1, 1, 1, 0.16 }, "v", a)
        Icons.draw(Icons.forType(ctype), x + L.icon.cx, y + L.icon.cy, L.icon.size, Theme.white,
            math.max(1, math.floor(3 * L.s)), a)
    end

    -- Exhausted: dim the art only; tag, name and stats stay crisp on top.
    if opts.exhausted then
        Draw.roundedFill(inX, inY, inW, inH, math.max(0, L.r - L.border),
            { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.55 }, "v", a)
    end

    drawTag(Theme.typeLabel[ctype] or string.upper(ctype or "?"), L, x, y, a)
    drawGem(cardDef.rarity, L, x, y, a)
    drawRibbon(cardDef.name, L, x, y, a)

    local stats = opts.stats or cardDef.stats or {}
    local hasStats = (ctype == "striker" or ctype == "defender" or ctype == "midfielder" or ctype == "keeper")
    if hasStats then
        Draw.atkBadge(x + L.atk.cx, y + L.atk.cy, L.atk.size, (stats.atk or 0) + (opts.atkBonus or 0), a)
        Draw.defBadge(x + L.def.cx, y + L.def.cy, L.def.size, (stats.def or 0) + (opts.defBonus or 0),
            opts.defBonus, a)
        if opts.atkBonus and opts.atkBonus > 0 then
            Draw.bonusTag(x + L.atk.cx, y + L.atk.cy - L.atk.size / 2 - 2, L.atk.size, opts.atkBonus, a)
        end
    end

    if opts.exhausted then drawExhausted(L, x, y, a) end
end

-- ── Back ──────────────────────────────────────────────────────────────────────

function Card.drawBack(x, y, w, h, opts)
    opts = opts or {}
    local L = Card.layout(w, h)
    local a = opts.alpha or 1
    drawHighlights(L, x, y, opts, nil)
    Draw.sticker(x, y, w, h, { r = L.r, fill = Theme.cardBack, dir = "v", border = L.border, shadow = L.shadow, alpha = a })
    local pad = L.border + 5 * L.s
    Draw.stripes(x + pad, y + pad, w - 2 * pad, h - 2 * pad, math.max(6, 12 * L.s), math.max(2, 4 * L.s),
        { 1, 1, 1, 0.06 }, a)
    Draw.ring(x + pad, y + pad, w - 2 * pad, h - 2 * pad, math.max(2, 6 * L.s), { 1, 1, 1, 0.25 },
        math.max(1, 2 * L.s), a)
    Icons.draw("soccer-ball", x + w / 2, y + h / 2, math.min(w, h) * 0.42, { 1, 1, 1, 0.9 },
        math.max(1, math.floor(3 * L.s)), a)

    if opts.label then
        local ph = math.max(10, 16 * L.s)
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + h - pad - ph - 2 * L.s, pw, ph, opts.label, {
            fill = Theme.grad.def, textColor = Theme.white, border = math.max(1, math.floor(2 * L.s)),
            shadow = 0, alpha = a,
        })
    end
    if opts.canFlip then
        local rh = math.max(12, 20 * L.s)
        Draw.ribbon(x + w / 2, y + pad + 2 * L.s, w * 0.9, rh, "FLIP UP", {
            fill = Theme.grad.bonus, textColor = Theme.white, alpha = a,
        })
    end
end

-- ── Public API (existing contract) ────────────────────────────────────────────

function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h

    if pitched.mode == "defense" then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and "DEF" or nil, canFlip = opts.canFlip,
            selected = opts.selected, target = opts.target,
        })
        return
    end

    local atkBonus, defBonus = 0, 0
    if opts.pitch then
        if pitched.slotType == "striker"  then atkBonus = Combat.midfielderCardAtkBonus(opts.pitch) or 0 end
        if pitched.slotType == "defender" then defBonus = Combat.midfielderCardDefBonus(opts.pitch) or 0 end
    end

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })
end

function Card.drawInHand(cardDef, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.hand.w
    local h = opts.h or Theme.cardSize.hand.h
    Card.drawFace(cardDef, x, y, w, h, { selected = opts.selected })
    return { x = x, y = y, w = w, h = h }
end

-- Info sticker: name, type · rarity, ability text. Returns its height.
function Card.drawInfo(cardDef, x, y, w)
    local Fonts = require("ui.fonts")
    local pad = 12
    local body = Fonts.body(12)
    local _, lines = body:getWrap(cardDef.abilityText or "", w - pad * 2)
    local h = pad + 22 + 16 + #lines * body:getHeight() + pad
    Draw.sticker(x, y, w, h, { r = 12, fill = Theme.white, border = 0, shadow = 4 })
    Draw.text(cardDef.name or "", x + pad, y + pad, w - pad * 2, "left",
        { size = 18, color = Theme.inkText, fit = true })
    local rc = Theme.rarityColors[cardDef.rarity] or Theme.rarityColors.common
    Draw.text(((Theme.typeLabel[cardDef.type] or "") .. " · " .. string.upper(cardDef.rarity or "")),
        x + pad, y + pad + 22, w - pad * 2, "left",
        { size = 11, body = true, color = { rc[1] * 0.6, rc[2] * 0.6, rc[3] * 0.6, 1 } })
    Draw.text(cardDef.abilityText or "", x + pad, y + pad + 38, w - pad * 2, "left",
        { size = 12, body = true, color = { 0.35, 0.35, 0.54, 1 } })
    return h
end

function Card.drawTooltip(cardDef, x, y)
    local w = 230
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if x + w > W - 8 then x = W - 8 - w end
    if x < 8 then x = 8 end
    if y < 8 then y = 8 end
    if y + 140 > H then y = H - 140 end
    Card.drawInfo(cardDef, x, y, w)
end

function Card.drawLarge(cardDef, x, y, w)
    local h = math.floor(w * 148 / 108)
    Card.drawFace(cardDef, x, y, w, h, {})
    return h
end

return Card
