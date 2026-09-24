-- Clash-portrait card renderer.
-- Public API (unchanged contract for existing callers):
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, switchLabel, pitch, hideHidden, selected, target
--   Card.switchLabel(pitched, slotType, ctx) position-switch ribbon text or nil (pure, unit-tested)
--   Card.showsFace(pitched)                 face-up? (attack mode or revealed; never traps) — pure
--   Card.drawInHand(cardDef, x, y, opts)    opts: w, h, selected   → returns {x,y,w,h}
--   Card.drawLarge(cardDef, x, y, w)        → face + info sticker, returns total h
-- New:
--   Card.layout(w, h)                       pure geometry (unit-tested)
--   Card.keywordLabel(cardDef)              keyword pill text or nil (pure, unit-tested)
--   Card.drawFace(cardDef, x, y, w, h, opts) opts: stats, atkBonus, defBonus, exhausted, selected, target, alpha,
--                                                   badges = "corners"|"left"|"none"
--   Card.drawBadges(cardDef, x, y, w, h, opts) badges only; opts: stats, atkBonus, defBonus, alpha,
--                                                   badges = "corners"|"left"|"none"
--   Card.drawBack(x, y, w, h, opts)         opts: label, canFlip, selected, target, alpha
local Theme  = require("ui.theme")
local Fonts  = require("ui.fonts")
local Combat = require("engine.combat")
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")
local Phases = require("engine.phases")

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

    -- Hand-only layout: ATK and DEF paired at the bottom-left so neither is
    -- covered by the neighbouring fanned card (see ui/hand.lua).
    L.atkLeft = { cx = L.atk.cx, cy = L.atk.cy, size = L.atk.size }
    L.defLeft = {
        cx   = L.atkLeft.cx + L.atkLeft.size * 0.5 + L.def.size * 0.5 + 2 * s,
        cy   = L.atkLeft.cy,
        size = L.def.size,
    }

    L.tag = { cy = 0, h = math.max(9, 16 * s) }
    L.gem = { cx = w - 12 * s, cy = 12 * s, size = math.max(5, 9 * s) }

    local artTop, artBottom = L.border + 6 * s, L.ribbon.y - 2
    local iconSize = math.min(w * 0.56, (artBottom - artTop) * 0.92)
    L.icon = { cx = w / 2, cy = (artTop + artBottom) / 2, size = iconSize }
    -- Status pieces drawn over the art (drawExhausted, drawPitched).
    local ph = math.max(10, 16 * s)
    L.zzz     = { y = h * 0.30, h = ph }                  -- exhausted pill
    L.defPill = { y = h * 0.12, h = ph }                  -- revealed card's DEF marker
    L.flip    = { y = h * 0.26, h = math.max(12, 20 * s) }  -- revealed card's TO ATTACK ribbon
    -- Keyword pill: centred just above the name ribbon, below the status pieces; never over
    -- the ribbon, the badges, the type tag or the gem.
    local kwH = math.max(9, 14 * s)
    L.kw = { cx = w / 2, y = L.ribbon.y - kwH - math.max(1, 2 * s), h = kwH, maxW = w - 16 * s }
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
    local ph = L.zzz.h
    local pw = ph * 2.4
    Draw.pill(x + (L.w - pw) / 2, y + L.zzz.y, pw, ph, "zzz", {
        fill = Theme.white, textColor = Theme.inkText, border = 0, shadow = math.max(1, math.floor(2 * L.s)),
        alpha = alpha,
    })
end

-- Keyword pill ("LINK-UP") centred above the name ribbon; nil label draws nothing.
local function drawKeyword(label, L, x, y, alpha)
    if not label then return end
    local k    = L.kw
    local size = math.max(6, math.floor(k.h * 0.62))
    local tw   = math.min(k.maxW, #label * size * 0.62 + k.h)
    Draw.pill(x + k.cx - tw / 2, y + k.y, tw, k.h, label, {
        fill = Theme.grad.keyword, textColor = Theme.inkText,
        border = math.max(1, math.floor(2 * L.s)), shadow = 0, size = size, alpha = alpha,
    })
end

-- "TO DEFENSE ▼" ribbon on an attack-mode card that may switch (the arrow is drawn: the fonts
-- have no ▼). Same place and size as the revealed card's TO ATTACK ribbon (L.flip).
local function drawToDefense(L, x, y)
    local fh = L.flip.h
    local rw = L.w * 0.9
    local rx = x + (L.w - rw) / 2
    local ry = y + L.flip.y
    Draw.sticker(rx, ry, rw, fh, { r = fh * 0.2, fill = Theme.grad.def, border = 3, shadow = 4 })
    local arrow = fh * 0.55
    local size  = math.floor(fh * 0.6)
    Draw.text("TO DEFENSE", rx + 6, ry + (fh - size) / 2 - size * 0.08, rw - 16 - arrow, "center", {
        size = size, color = Theme.white, fit = true, minSize = 6,
    })
    Draw.arrowDown(rx + rw - 6 - arrow / 2, ry + fh / 2, arrow, Theme.white)
end

-- ── Face ──────────────────────────────────────────────────────────────────────

-- Draws only the ATK/DEF badges (and bonus tag) for a card, given its layout.
-- opts: stats, atkBonus, defBonus, alpha, badges = "corners" (default) | "left" | "none".
function Card.drawBadges(cardDef, x, y, w, h, opts)
    opts = opts or {}
    if opts.badges == "none" then return end
    local L     = Card.layout(w, h)
    local a     = opts.alpha or 1
    local ctype = cardDef.type
    local stats = opts.stats or cardDef.stats or {}
    local hasStats = (ctype == "striker" or ctype == "defender" or ctype == "midfielder" or ctype == "keeper")
    if not hasStats then return end

    local atkPos, defPos = L.atk, L.def
    if opts.badges == "left" then
        atkPos, defPos = L.atkLeft, L.defLeft
    end

    Draw.atkBadge(x + atkPos.cx, y + atkPos.cy, atkPos.size, (stats.atk or 0) + (opts.atkBonus or 0), a)
    Draw.defBadge(x + defPos.cx, y + defPos.cy, defPos.size, (stats.def or 0) + (opts.defBonus or 0),
        opts.defBonus, a)
    if opts.atkBonus and opts.atkBonus > 0 then
        Draw.bonusTag(x + atkPos.cx, y + atkPos.cy - atkPos.size / 2 - 2, atkPos.size, opts.atkBonus, a)
    end
end

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
    drawKeyword(Card.keywordLabel(cardDef), L, x, y, a)

    Card.drawBadges(cardDef, x, y, w, h, opts)

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

-- Bonuses shown on a pitched card's badges: its always-on bonuses. Pure (unit-tested).
--   striker  → +ATK: midfielder card bonus (Engine / Overlap) and Link-up
--   defender → +DEF: midfielder card bonus (Engine) and Last man
--   keeper   → effective DEF minus base DEF (line, Bolt, midfielder, Safe hands)
-- Situational bonuses (Instinct, Opportunist, Counter-press) are not shown here.
-- hideHidden: the card is the opponent's; bonuses from their face-down, unrevealed cards
-- (a hidden midfielder's bonus, a hidden Link-up or Bolt card) are hidden information.
-- Returns atkBonus, defBonus, atkParts, defParts.
function Card.bonuses(pitched, pitch, hideHidden)
    if not pitch then return 0, 0, {}, {} end
    local st    = pitched.slotType
    local stats = pitched.definition.stats or {}
    if st == "striker" then
        local atk, parts = Combat.attackStat(pitched, "striker", pitch, nil, nil, hideHidden)
        return atk - (stats.atk or 0), 0, parts, {}
    end
    if st == "defender" then
        local def, parts = Combat.defendStat(pitched, "defender", pitch, false, hideHidden)
        return 0, def - (stats.def or 0), {}, parts
    end
    if st == "keeper" then
        local def, parts = Combat.keeperDef(pitched, pitch, false, hideHidden)
        return 0, def - (stats.def or 0), {}, parts
    end
    return 0, 0, {}, {}
end

-- Keyword pill text for a field card ("LINK-UP"), or nil (traps, strategies, no keyword).
-- Pure (unit-tested).
function Card.keywordLabel(cardDef)
    local t = cardDef and cardDef.type
    if t ~= "striker" and t ~= "defender" and t ~= "midfielder" and t ~= "keeper" then return nil end
    if not cardDef.keywordName then return nil end
    return string.upper(cardDef.keywordName)
end

-- True when a pitched card is drawn face-up: attack mode, or a revealed defense-mode
-- card (seen by both players). Traps and unrevealed face-down cards show their back.
-- Pure (unit-tested).
function Card.showsFace(pitched)
    if pitched.slotType == "trap" then return false end
    return pitched.mode ~= "defense" or pitched.revealed == true
end

-- Position-switch ribbon for a pitched card: "FLIP UP" (face-down), "TO ATTACK" (revealed
-- defense), "TO DEFENSE" (attack mode), or nil when Phases.canSwitch refuses (the rule the
-- engine uses). ctx: { isOwnTurn, phase, halfTimeBreak }. Pure (unit-tested).
function Card.switchLabel(pitched, slotType, ctx)
    if not Phases.canSwitch(pitched, slotType, ctx) then return nil end
    if pitched.mode == "attack" then return "TO DEFENSE" end
    return pitched.revealed and "TO ATTACK" or "FLIP UP"
end

function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h

    if not Card.showsFace(pitched) then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and (pitched.slotType == "trap" and "TRAP" or "DEF") or nil,
            canFlip = opts.switchLabel ~= nil,
            selected = opts.selected, target = opts.target,
        })
        return
    end

    local atkBonus, defBonus = Card.bonuses(pitched, opts.pitch, opts.hideHidden)

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })

    local L = Card.layout(w, h)
    if pitched.mode == "defense" then
        -- Revealed defense-mode card: face-up for both players, with a DEF marker.
        local ph = L.defPill.h
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + L.defPill.y, pw, ph, "DEF", {
            fill = Theme.grad.def, textColor = Theme.white,
            border = math.max(1, math.floor(2 * L.s)), shadow = 0,
        })
        if opts.switchLabel then
            Draw.ribbon(x + w / 2, y + L.flip.y, w * 0.9, L.flip.h, opts.switchLabel, {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    elseif opts.switchLabel then
        drawToDefense(L, x, y)
    end
end

function Card.drawInHand(cardDef, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.hand.w
    local h = opts.h or Theme.cardSize.hand.h
    Card.drawFace(cardDef, x, y, w, h, { selected = opts.selected, badges = "left" })
    return { x = x, y = y, w = w, h = h }
end

local INFO_PAD = 12

-- Height of the info sticker for cardDef at width w (wraps the ability text; a field card
-- adds its keyword heading).
function Card.infoHeight(cardDef, w)
    local body = Fonts.body(12)
    local _, lines = body:getWrap(cardDef.abilityText or "", w - INFO_PAD * 2)
    local heading = Card.keywordLabel(cardDef) and 18 or 0
    return INFO_PAD + 22 + 16 + heading + #lines * body:getHeight() + INFO_PAD
end

-- Info sticker: name, type · rarity, keyword heading (field cards), ability text.
-- Returns its height.
function Card.drawInfo(cardDef, x, y, w, extraH)
    local pad = INFO_PAD
    local h = Card.infoHeight(cardDef, w) + (extraH or 0)
    Draw.sticker(x, y, w, h, { r = 12, fill = Theme.white, border = 0, shadow = 4 })
    Draw.text(cardDef.name or "", x + pad, y + pad, w - pad * 2, "left",
        { size = 18, color = Theme.inkText, fit = true })
    local rc = Theme.rarityColors[cardDef.rarity] or Theme.rarityColors.common
    Draw.text(((Theme.typeLabel[cardDef.type] or "") .. " · " .. string.upper(cardDef.rarity or "")),
        x + pad, y + pad + 22, w - pad * 2, "left",
        { size = 11, body = true, color = { rc[1] * 0.6, rc[2] * 0.6, rc[3] * 0.6, 1 } })
    local textY = y + pad + 38
    local kw = Card.keywordLabel(cardDef)
    if kw then
        Draw.text(kw, x + pad, textY, w - pad * 2, "left",
            { size = 14, color = Theme.button.primary.text, fit = true })
        textY = textY + 18
    end
    Draw.text(cardDef.abilityText or "", x + pad, textY, w - pad * 2, "left",
        { size = 12, body = true, color = { 0.35, 0.35, 0.54, 1 } })
    return h
end

-- Big card face with the info sticker (ability text) below it, all kept inside the
-- w-wide column starting at y: the face is inset so the overhanging ribbon, badges
-- and top tag don't spill out. Returns the combined height.
function Card.drawLarge(cardDef, x, y, w)
    local fw = math.floor(w * BASE_W / (BASE_W + 18))    -- room for 9*s overhang per side
    local fh = math.floor(fw * 148 / 108)
    local L  = Card.layout(fw, fh)
    local top = math.ceil(L.tag.h / 2)
    Card.drawFace(cardDef, x + math.floor((w - fw) / 2), y + top, fw, fh, {})
    local bottom = top + fh
    local t = cardDef.type
    if t == "striker" or t == "defender" or t == "midfielder" or t == "keeper" then
        bottom = top + L.atk.cy + L.atk.size * 0.5 + math.max(2, L.atk.size * 0.08)  -- badge + its shadow
    end
    local infoY = math.ceil(bottom) + 8
    local infoH = Card.drawInfo(cardDef, x, y + infoY, w)
    return infoY + infoH
end

return Card
