local Theme  = require("ui.theme")
local Fonts  = require("ui.fonts")
local Combat = require("engine.combat")

local Card = {}

-- ── Image cache ───────────────────────────────────────────────────────────────

local _images = {}
local function getCardImage(cardDef)
    if not cardDef then return nil end
    local id    = cardDef.id   or ""
    local ctype = cardDef.type or ""
    if _images[id] ~= nil then return _images[id] end
    local prefix = ctype:sub(1, 3)
    local candidates = {
        "assets/cards/" .. id .. ".png",
        "assets/cards/" .. id .. ".jpg",
        "assets/cards/" .. prefix .. "-forward.png",
        "assets/cards/" .. ctype .. ".png",
    }
    for _, path in ipairs(candidates) do
        local ok, img = pcall(love.graphics.newImage, path)
        if ok then img:setFilter("linear","linear"); _images[id] = img; return img end
    end
    _images[id] = false
    return nil
end

-- ── Color helpers ─────────────────────────────────────────────────────────────

-- Mix c1 → c2 at t  (0 = c1, 1 = c2)
local function cmix(c1, c2, t)
    return { c1[1]+(c2[1]-c1[1])*t, c1[2]+(c2[2]-c1[2])*t, c1[3]+(c2[3]-c1[3])*t, 1 }
end

local BLACK = { 0, 0, 0, 1 }
local DARK  = { 0.039, 0.008, 0.016, 1 }  -- #0a0204

-- 2-stop vertical gradient via a quad mesh
local function vgrad(x, y, w, h, cTop, cBot)
    local mesh = love.graphics.newMesh({
        { x,   y,   0, 0, cTop[1], cTop[2], cTop[3], cTop[4] or 1 },
        { x+w, y,   1, 0, cTop[1], cTop[2], cTop[3], cTop[4] or 1 },
        { x+w, y+h, 1, 1, cBot[1], cBot[2], cBot[3], cBot[4] or 1 },
        { x,   y+h, 0, 1, cBot[1], cBot[2], cBot[3], cBot[4] or 1 },
    }, "fan")
    love.graphics.draw(mesh)
end

-- ── Shared primitives ─────────────────────────────────────────────────────────

local function shadow(x, y, w, h, r)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", x+4, y+4, w, h, r)
end

-- 4 corner brackets (L-shapes) in accent color with a subtle glow
local function brackets(x, y, w, h, size, acc, alpha)
    alpha = alpha or 1
    love.graphics.setColor(acc[1], acc[2], acc[3], alpha * 0.85)
    love.graphics.setLineWidth(1.5)
    local s = size
    love.graphics.line(x, y+s, x, y, x+s, y)
    love.graphics.line(x+w-s, y, x+w, y, x+w, y+s)
    love.graphics.line(x, y+h-s, x, y+h, x+s, y+h)
    love.graphics.line(x+w-s, y+h, x+w, y+h, x+w, y+h-s)
    love.graphics.setLineWidth(1)
end

-- Clipped stencil draw (draw fn only inside rect x,y,w,h)
local function withScissor(x, y, w, h, fn)
    love.graphics.setScissor(x, y, w, h)
    fn()
    love.graphics.setScissor()
end

-- ── Art zone field decoration (mini pitch lines) ──────────────────────────────

local function drawFieldLines(x, y, w, h)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.setLineWidth(1)
    -- outer box
    love.graphics.rectangle("line", x+4, y+4, w-8, h-8, 1)
    -- center line
    love.graphics.line(x+4, y + h/2, x+w-4, y + h/2)
    -- center circle
    love.graphics.circle("line", x + w/2, y + h/2, math.min(w,h) * 0.18)
    -- center dot
    love.graphics.circle("fill", x + w/2, y + h/2, 2)
    love.graphics.setLineWidth(1)
end

-- ── Main card draw (face-up) ──────────────────────────────────────────────────

local function drawFaceUp(cardType, cardName, cardId, stats, mode, img, x, y, w, h, isExh)
    local r   = 6
    local base = (isExh and Theme.cardColorsDim[cardType]) or Theme.cardColors[cardType]
                 or { 0.18, 0.18, 0.18, 1 }
    local art  = Theme.cardArt[cardType]     or cmix(base, {1,1,1,1}, 0.25)
    local acc  = Theme.cardAccents[cardType] or { 0.6, 0.6, 0.6, 1 }

    -- 1. Drop shadow
    shadow(x, y, w, h, r)

    -- 2. Outer body: gradient acc→base→black  (the "glow ring" layer)
    local bodyTop = cmix(acc, BLACK, 0.60)
    local bodyBot = cmix(base, BLACK, 0.30)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x-1, y-1, w+2, h+2, r+1)
    vgrad(x, y, w, h, bodyTop, bodyBot)

    -- 3. Inner card body (inset 4px): radial-ish gradient base→dark
    local ix, iy = x+4, y+4
    local iw, ih = w-8, h-8
    local innerTop = cmix(base, BLACK, 0.45)
    local innerBot = cmix(DARK, BLACK, 0.20)
    vgrad(ix, iy, iw, ih, innerTop, innerBot)

    -- Subtle scanline overlay
    love.graphics.setColor(1, 1, 1, 0.022)
    for sy = iy, iy+ih, 3 do
        love.graphics.line(ix, sy, ix+iw, sy)
    end

    -- 4. Inner inset border (accent@60%)
    love.graphics.setColor(acc[1]*0.60, acc[2]*0.60, acc[3]*0.60, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ix, iy, iw, ih, 3)

    if img then
        -- ── Image-backed card ─────────────────────────────────────────────────
        local iw2, ih2 = img:getDimensions()
        love.graphics.setColor(isExh and {0.55,0.55,0.55,1} or {1,1,1,1})
        love.graphics.draw(img, x, y, 0, w/iw2, h/ih2)
    else
        -- Layout constants (proportional to card height)
        local HDR = math.max(13, math.floor(h * 0.20))  -- header strip
        local SB  = math.max(12, math.floor(h * 0.18))  -- stats bar
        local NP  = math.max(12, math.floor(h * 0.17))  -- nameplate
        local artY = iy + HDR
        local artH = ih - HDR - NP - SB - 4

        -- 5. Header strip: gradient acc→base→dim
        local stripTop = cmix(acc, BLACK, 0.50)
        local stripBot = cmix(base, BLACK, 0.40)
        withScissor(ix, iy, iw, HDR, function()
            vgrad(ix, iy, iw, HDR, stripTop, stripBot)
            -- Top highlight line (sheen)
            love.graphics.setColor(1, 1, 1, 0.22)
            love.graphics.setLineWidth(1)
            love.graphics.line(ix+2, iy+1, ix+iw-2, iy+1)
            -- Type label + dot
            Fonts.with(9, function()
                -- Glowing dot
                love.graphics.setColor(acc[1]*0.80, acc[2]*0.80, acc[3]*0.80, 1)
                love.graphics.circle("fill", ix+8, iy + HDR/2, 3)
                love.graphics.setColor(acc)
                love.graphics.circle("fill", ix+8, iy + HDR/2, 2)
                -- Type text
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print(cardType:sub(1,3):upper(), ix+16, iy + HDR/2 - 5)
            end)
        end)

        -- 6. Art zone
        if artH > 4 then
            local artBotC = cmix(art, BLACK, 0.40)
            withScissor(ix, artY, iw, artH, function()
                vgrad(ix, artY, iw, artH, art, artBotC)
                -- Sheen highlight
                love.graphics.setColor(1, 1, 1, 0.10)
                love.graphics.rectangle("fill", ix, artY, iw * 0.55, artH * 0.45)
                -- Field decoration
                drawFieldLines(ix, artY, iw, artH)
            end)
            -- Art zone border
            love.graphics.setColor(0, 0, 0, 0.80)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", ix, artY, iw, artH)
        end

        -- 7. Nameplate
        local npY = artY + artH + 2
        withScissor(ix, npY, iw, NP, function()
            vgrad(ix, npY, iw, NP, { 0.082, 0.031, 0.039, 1 }, DARK)
            -- Accent inset border
            love.graphics.setColor(acc[1]*0.40, acc[2]*0.40, acc[3]*0.40, 1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", ix, npY, iw, NP)
            -- Card name
            Fonts.with(9, function()
                -- Text glow (offset shadow in accent)
                love.graphics.setColor(acc[1]*0.35, acc[2]*0.35, acc[3]*0.35, 1)
                love.graphics.printf(cardName or "", ix+5, npY + NP/2 - 6, iw-10, "center")
                love.graphics.setColor(0.957, 0.914, 0.824, 1)  -- #f3e9d2
                love.graphics.printf(cardName or "", ix+4, npY + NP/2 - 7, iw-8, "center")
            end)
        end)

        -- 8. Stats bar  ATK  ◆  DEF
        local sbY = npY + NP + 2
        withScissor(ix, sbY, iw, SB, function()
            vgrad(ix, sbY, iw, SB, DARK, BLACK)
            love.graphics.setColor(0, 0, 0, 0.80)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", ix, sbY, iw, SB)

            local atk  = (stats and stats.atk) or 0
            local def  = (stats and stats.def) or 0
            local midX = ix + iw / 2
            local statY = sbY + SB/2 - 6

            -- ATK glow + value
            Fonts.with(9, function()
                local ac = Theme.atkColor
                love.graphics.setColor(ac[1]*0.40, ac[2]*0.40, ac[3]*0.40, 1)
                love.graphics.printf(tostring(atk), ix+2, statY+1, iw/2-8, "right")
                love.graphics.setColor(ac)
                love.graphics.printf(tostring(atk), ix+2, statY, iw/2-8, "right")
            end)

            -- ◆ divider
            Fonts.with(9, function()
                love.graphics.setColor(acc)
                love.graphics.printf("*", midX-4, statY, 8, "center")
            end)

            -- DEF glow + value
            Fonts.with(9, function()
                local dc = Theme.defColor
                love.graphics.setColor(dc[1]*0.40, dc[2]*0.40, dc[3]*0.40, 1)
                love.graphics.printf(tostring(def), midX+6, statY+1, iw/2-8, "left")
                love.graphics.setColor(dc)
                love.graphics.printf(tostring(def), midX+6, statY, iw/2-8, "left")
            end)
        end)
    end

    -- 9. Mode badge (top-right, always on top)
    local isAtk = (mode == "attack")
    local badgeC = isAtk and { 1.00, 0.84, 0.00, 1 } or { 0.29, 0.64, 1.00, 1 }
    local bdgX, bdgY, bdgS = x+w-16, y+4, 12
    love.graphics.setColor(0.071, 0.008, 0.016, 1)  -- #120204
    love.graphics.rectangle("fill", bdgX, bdgY, bdgS, bdgS, 2)
    love.graphics.setColor(badgeC[1]*0.60, badgeC[2]*0.60, badgeC[3]*0.60, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bdgX, bdgY, bdgS, bdgS, 2)
    -- dashed inner (approximated as a slightly inset dotted border)
    love.graphics.setColor(badgeC[1]*0.70, badgeC[2]*0.70, badgeC[3]*0.70, 0.80)
    love.graphics.rectangle("line", bdgX+2, bdgY+2, bdgS-4, bdgS-4, 1)
    -- Badge letter
    Fonts.with(9, function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(isAtk and "A" or "D", bdgX, bdgY+1, bdgS, "center")
    end)

    -- 10. Outer glow border (type accent)
    love.graphics.setColor(acc[1], acc[2], acc[3], 0.45)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, r)
    love.graphics.setLineWidth(1)

    -- 11. Corner brackets
    brackets(x+2, y+2, w-4, h-4, 7, acc)

    -- Exhausted overlay
    if isExh then
        love.graphics.setColor(0, 0, 0, 0.62)
        love.graphics.rectangle("fill", x, y, w, h, r)
        Fonts.with(9, function()
            love.graphics.setColor(0.60, 0.60, 0.65, 0.85)
            love.graphics.printf("TIRED", x, y+h/2-6, w, "center")
        end)
    end
end

-- ── Face-down card ────────────────────────────────────────────────────────────

local function drawFaceDown(x, y, w, h, showLabel, canFlip)
    local r   = 6
    local acc = { 1.000, 0.416, 0.478, 1 }  -- striker red accent (HTML uses this for back)

    shadow(x, y, w, h, r)
    -- Outer shell
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x-1, y-1, w+2, h+2, r+1)

    -- Background gradient
    vgrad(x, y, w, h, { 0.165, 0.020, 0.063, 1 }, { 0.039, 0.008, 0.016, 1 })

    -- Diagonal stripe pattern (45°)
    withScissor(x+4, y+4, w-8, h-8, function()
        love.graphics.setColor(0.063, 0.016, 0.024, 1)
        love.graphics.setLineWidth(10)
        local len = math.sqrt(w*w + h*h) + 20
        local cx, cy = x + w/2, y + h/2
        for i = -3, 3 do
            local ox = i * 18
            love.graphics.line(cx - len + ox, cy - len, cx + len + ox, cy + len)
        end
        love.graphics.setLineWidth(1)
    end)

    -- Inner frame
    love.graphics.setColor(0.039, 0.008, 0.016, 1)
    love.graphics.rectangle("fill", x+8, y+8, w-16, h-16, 4)

    -- X cross in accent
    withScissor(x+8, y+8, w-16, h-16, function()
        love.graphics.setColor(acc[1]*0.70, acc[2]*0.70, acc[3]*0.70, 0.90)
        love.graphics.setLineWidth(2)
        love.graphics.line(x+10, y+10, x+w-10, y+h-10)
        love.graphics.line(x+w-10, y+10, x+10, y+h-10)
        love.graphics.setLineWidth(1)
    end)

    -- Diamond emblem center
    local cx, cy = x + w/2, y + h/2
    local ds = math.min(w, h) * 0.28
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(math.pi / 4)
    love.graphics.setColor(0.063, 0.016, 0.024, 1)
    love.graphics.rectangle("fill", -ds, -ds, ds*2, ds*2, 2)
    love.graphics.setColor(acc[1]*0.80, acc[2]*0.80, acc[3]*0.80, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", -ds, -ds, ds*2, ds*2, 2)
    -- inner diamond ring
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, 0.80)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", -ds+4, -ds+4, (ds-4)*2, (ds-4)*2, 1)
    love.graphics.pop()
    love.graphics.setLineWidth(1)

    -- "F" letter (not rotated)
    Fonts.with(math.floor(math.min(w,h) * 0.20), function()
        love.graphics.setColor(acc[1]*0.85, acc[2]*0.85, acc[3]*0.85, 1)
        love.graphics.printf("F", x, cy - math.min(w,h)*0.11, w, "center")
    end)

    -- "DEF" label if visible
    if showLabel then
        Fonts.with(9, function()
            love.graphics.setColor(acc[1]*0.65, acc[2]*0.65, acc[3]*0.65, 0.85)
            love.graphics.printf("DEF", x, y+h-16, w, "center")
        end)
    end

    -- Flip indicator: green banner when this card can be flipped to attack
    if canFlip then
        local bh = math.max(14, math.floor(h * 0.18))
        local by = y + math.floor(h * 0.38)
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", x, by, w, bh)
        love.graphics.setColor(0.20, 0.90, 0.40, 0.90)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, by, w, bh)
        Fonts.with(9, function()
            love.graphics.setColor(0.20, 0.90, 0.40, 1)
            love.graphics.printf("FLIP ^", x, by + bh/2 - 5, w, "center")
        end)
    end

    -- Outer border + brackets
    love.graphics.setColor(acc[1]*0.50, acc[2]*0.50, acc[3]*0.50, 0.70)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, r)
    love.graphics.setLineWidth(1)
    brackets(x+2, y+2, w-4, h-4, 7, acc, 0.70)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.pitchCard.w
    local h = opts.h or Theme.pitchCard.h

    if pitched.mode == "defense" then
        drawFaceDown(x, y, w, h, not opts.faceDown, opts.canFlip)
        return
    end

    local d     = pitched.definition
    local img   = getCardImage(d)
    local stats = d.stats

    -- Apply midfielder card bonus to the displayed stat when active
    if opts.pitch and stats then
        local slotT    = pitched.slotType
        local atkBonus = (slotT == "striker")  and Combat.midfielderCardAtkBonus(opts.pitch) or 0
        local defBonus = (slotT == "defender") and Combat.midfielderCardDefBonus(opts.pitch) or 0
        if atkBonus > 0 or defBonus > 0 then
            stats = {
                atk = (stats.atk or 0) + atkBonus,
                def = (stats.def or 0) + defBonus,
            }
        end
    end

    drawFaceUp(d.type, d.name, d.id, stats, pitched.mode, img, x, y, w, h, pitched.exhausted)
end

function Card.drawInHand(cardDef, x, y, opts)
    opts = opts or {}
    local w   = opts.w or Theme.card.w
    local h   = opts.h or Theme.card.h
    local img = getCardImage(cardDef)

    drawFaceUp(cardDef.type, cardDef.name, cardDef.id, cardDef.stats, "attack", img, x, y, w, h, false)

    -- Selection glow (multiple rings)
    if opts.selected then
        local acc = Theme.cardAccents[cardDef.type] or { 1, 0.84, 0, 1 }
        for ring = 3, 1, -1 do
            love.graphics.setColor(acc[1], acc[2], acc[3], 0.10 * ring)
            love.graphics.setLineWidth(ring * 2.5)
            love.graphics.rectangle("line", x-ring*2, y-ring*2, w+ring*4, h+ring*4, 8+ring*2)
        end
        love.graphics.setColor(acc)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", x-2, y-2, w+4, h+4, 8)
        love.graphics.setLineWidth(1)
        brackets(x-2, y-2, w+4, h+4, 9, acc, 1.0)
    end

    return { x=x, y=y, w=w, h=h }
end

-- ── Tooltip ───────────────────────────────────────────────────────────────────

function Card.drawTooltip(cardDef, x, y)
    local w, h = 200, 110
    if x+w > love.graphics.getWidth()  then x = x - w - 10 end
    if y+h > love.graphics.getHeight() then y = y - h end

    local acc = Theme.cardAccents[cardDef.type] or { 0.55, 0.10, 0.10, 1 }
    love.graphics.setColor(0, 0, 0, 0.70)
    love.graphics.rectangle("fill", x+4, y+4, w, h, 6)
    vgrad(x, y, w, h, { 0.055, 0.020, 0.025, 1 }, { 0.025, 0.008, 0.012, 1 })
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(acc[1]*0.25, acc[2]*0.25, acc[3]*0.25, 1)
    love.graphics.line(x+12, y+28, x+w-12, y+28)

    Fonts.with(11, function()
        love.graphics.setColor(0.957, 0.914, 0.824, 1)
        love.graphics.print(cardDef.name or "", x+10, y+9)
    end)
    Fonts.with(9, function()
        love.graphics.setColor(0.718, 0.604, 0.447, 1)
        love.graphics.printf(cardDef.abilityText or "", x+10, y+34, w-20, "left")
        love.graphics.setColor(0.50, 0.45, 0.40, 1)
        love.graphics.print((cardDef.rarity or ""):upper() .. "  |  " .. (cardDef.type or ""):upper(), x+10, y+h-18)
    end)
end

-- ── Large card (left panel) ───────────────────────────────────────────────────

function Card.drawLarge(cardDef, x, y, w)
    local h   = math.floor(w * 1.25)  -- 4:5 ratio matching the HTML template
    local r   = 8
    local img = getCardImage(cardDef)
    local base = Theme.cardColors[cardDef.type]   or { 0.18, 0.18, 0.18, 1 }
    local art  = Theme.cardArt[cardDef.type]      or cmix(base, {1,1,1,1}, 0.25)
    local acc  = Theme.cardAccents[cardDef.type]  or { 0.6, 0.6, 0.6, 1 }

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", x+5, y+5, w, h, r)

    -- Outer shell gradient
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x-1, y-1, w+2, h+2, r+1)
    vgrad(x, y, w, h, cmix(acc, BLACK, 0.60), cmix(base, BLACK, 0.30))

    -- Inner body
    local ix, iy = x+5, y+5
    local iw, ih = w-10, h-10
    vgrad(ix, iy, iw, ih, cmix(base, BLACK, 0.45), DARK)

    -- Inner border
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ix, iy, iw, ih, 4)

    if img then
        local iw2, ih2 = img:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, w/iw2, h/ih2)
    else
        local HDR = math.floor(ih * 0.14)
        local SB  = math.floor(ih * 0.14)
        local NP  = math.floor(ih * 0.12)
        local artY = iy + HDR
        local artH = ih - HDR - NP - SB - 6

        -- Header strip
        withScissor(ix, iy, iw, HDR, function()
            vgrad(ix, iy, iw, HDR, cmix(acc, BLACK, 0.50), cmix(base, BLACK, 0.40))
            love.graphics.setColor(1, 1, 1, 0.20)
            love.graphics.line(ix+2, iy+1, ix+iw-2, iy+1)
            love.graphics.setColor(acc)
            love.graphics.circle("fill", ix+10, iy+HDR/2, 4)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle("fill", ix+10, iy+HDR/2, 2)
            Fonts.with(math.max(9, math.floor(w*0.075)), function()
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.print((cardDef.type or ""):sub(1,3):upper(), ix+20, iy+HDR/2-6)
                love.graphics.setColor(acc[1]*0.70, acc[2]*0.70, acc[3]*0.70, 0.75)
                love.graphics.printf((cardDef.rarity or ""):upper(), ix, iy+HDR/2-6, iw-6, "right")
            end)
        end)

        -- Art zone
        if artH > 4 then
            withScissor(ix, artY, iw, artH, function()
                vgrad(ix, artY, iw, artH, art, cmix(art, BLACK, 0.40))
                love.graphics.setColor(1, 1, 1, 0.10)
                love.graphics.rectangle("fill", ix, artY, iw*0.55, artH*0.45)
                drawFieldLines(ix, artY, iw, artH)
                -- Ability text overlay
                if cardDef.abilityText and cardDef.abilityText ~= "" then
                    local pad = 8
                    love.graphics.setColor(0, 0, 0, 0.55)
                    love.graphics.rectangle("fill", ix+pad, artY+pad, iw-pad*2, artH-pad*2, 3)
                    Fonts.with(math.max(9, math.floor(w*0.068)), function()
                        love.graphics.setColor(0.957, 0.914, 0.824, 0.92)
                        love.graphics.printf(cardDef.abilityText,
                            ix+pad+4, artY+pad+6, iw-pad*2-8, "center")
                    end)
                end
            end)
            love.graphics.setColor(0, 0, 0, 0.80)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", ix, artY, iw, artH)
        end

        -- Nameplate
        local npY = artY + artH + 2
        withScissor(ix, npY, iw, NP, function()
            vgrad(ix, npY, iw, NP, { 0.082, 0.031, 0.039, 1 }, DARK)
            love.graphics.setColor(acc[1]*0.40, acc[2]*0.40, acc[3]*0.40, 1)
            love.graphics.rectangle("line", ix, npY, iw, NP)
            Fonts.with(math.max(9, math.floor(w*0.082)), function()
                love.graphics.setColor(acc[1]*0.35, acc[2]*0.35, acc[3]*0.35, 1)
                love.graphics.printf(cardDef.name or "", ix+5, npY+NP/2-6, iw-10, "center")
                love.graphics.setColor(0.957, 0.914, 0.824, 1)
                love.graphics.printf(cardDef.name or "", ix+4, npY+NP/2-7, iw-8, "center")
            end)
        end)

        -- Stats bar
        local sbY = npY + NP + 2
        withScissor(ix, sbY, iw, SB, function()
            vgrad(ix, sbY, iw, SB, DARK, BLACK)
            love.graphics.setColor(0, 0, 0, 0.80)
            love.graphics.rectangle("line", ix, sbY, iw, SB)
            local stats  = cardDef.stats or {}
            local statY  = sbY + SB/2 - 8
            local midX   = ix + iw/2

            Fonts.with(math.max(9, math.floor(w*0.072)), function()
                love.graphics.setColor(Theme.atkColor[1]*0.40, Theme.atkColor[2]*0.40, Theme.atkColor[3]*0.40, 1)
                love.graphics.printf(tostring(stats.atk or 0), ix+4, statY+1, iw/2-10, "right")
                love.graphics.setColor(Theme.atkColor)
                love.graphics.printf(tostring(stats.atk or 0), ix+4, statY, iw/2-10, "right")

                love.graphics.setColor(acc)
                love.graphics.printf("*", midX-4, statY, 8, "center")

                love.graphics.setColor(Theme.defColor[1]*0.40, Theme.defColor[2]*0.40, Theme.defColor[3]*0.40, 1)
                love.graphics.printf(tostring(stats.def or 0), midX+8, statY+1, iw/2-10, "left")
                love.graphics.setColor(Theme.defColor)
                love.graphics.printf(tostring(stats.def or 0), midX+8, statY, iw/2-10, "left")
            end)
        end)
    end

    -- Outer border + brackets
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, r)
    love.graphics.setLineWidth(1)
    brackets(x+3, y+3, w-6, h-6, 12, acc)

    return h
end

return Card
