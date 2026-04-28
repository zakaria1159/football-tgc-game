-- Combat overlay — full-screen cinematic design from HTML template.
-- data: { attacker, defender, outcome, margin, damage }
-- anim: { atkOffX, defOffX, clashX, resultAlpha, shakeX }

local Theme     = require("ui.theme")
local Fonts     = require("ui.fonts")
local Character = require("ui.character")

local CombatOverlay = {}

-- ── Palette (from HTML :root) ─────────────────────────────────────────────────

local GOLD     = { 1.000, 0.843, 0.000, 1 }
local GOLD_DIM = { 0.722, 0.580, 0.122, 1 }
local INK_DIM  = { 0.604, 0.553, 0.690, 1 }
local BLACK    = { 0, 0, 0, 1 }
local PAGE     = { 0.039, 0.024, 0.059, 1 }
local ATK_C    = { 1.000, 0.267, 0.329, 1 }
local DEF_C    = { 0.290, 0.639, 1.000, 1 }

local OUT_COL = {
    defender_destroyed = { 1.000, 0.228, 0.333, 1 },
    defender_exhausted = { 1.000, 0.750, 0.150, 1 },
    attacker_exhausted = { 0.541, 0.522, 0.592, 1 },
    tie                = { 0.541, 0.522, 0.592, 1 },
    damage             = { 0.302, 0.859, 0.478, 1 },
    save               = { 0.302, 0.859, 0.478, 1 },
}

local OUT_TEXT = {
    defender_destroyed = "DESTROYED",
    defender_exhausted = "EXHAUSTED",
    attacker_exhausted = "BLOCKED",
    tie                = "TIE",
    damage             = "LP DAMAGE",
    save               = "KEEPER SAVES",
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function cmix(c1, c2, t)
    return { c1[1]+(c2[1]-c1[1])*t, c1[2]+(c2[2]-c1[2])*t, c1[3]+(c2[3]-c1[3])*t, 1 }
end

local function vgrad(x, y, w, h, cT, cB)
    local m = love.graphics.newMesh({
        { x,   y,   0, 0, cT[1], cT[2], cT[3], cT[4] or 1 },
        { x+w, y,   1, 0, cT[1], cT[2], cT[3], cT[4] or 1 },
        { x+w, y+h, 1, 1, cB[1], cB[2], cB[3], cB[4] or 1 },
        { x,   y+h, 0, 1, cB[1], cB[2], cB[3], cB[4] or 1 },
    }, "fan")
    love.graphics.draw(m)
end

local function withScissor(x, y, w, h, fn)
    love.graphics.setScissor(math.floor(x), math.floor(y), math.ceil(w), math.ceil(h))
    fn()
    love.graphics.setScissor()
end

local function goldenBrackets(x, y, w, h, size)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.85)
    love.graphics.setLineWidth(2)
    local s = size
    love.graphics.line(x, y+s, x, y, x+s, y)
    love.graphics.line(x+w-s, y, x+w, y, x+w, y+s)
    love.graphics.line(x, y+h-s, x, y+h, x+s, y+h)
    love.graphics.line(x+w-s, y+h, x+w, y+h, x+w, y+h-s)
    love.graphics.setLineWidth(1)
end

-- ── Card box (combat overlay sized) ──────────────────────────────────────────
-- Implements .cbox / .cbox__inner from HTML — full card design at 240×270

local function drawCombatCard(card, x, y, w, h, isAttacker, outcome, revealed)
    local r = 8

    -- Face-down before reveal
    if not revealed then
        love.graphics.setColor(0.06, 0.12, 0.28, 1)
        love.graphics.rectangle("fill", x, y, w, h, r)
        love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, r)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.14, 0.24, 0.50, 1)
        love.graphics.rectangle("fill", x+12, y+12, w-24, h-24, 6)
        love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], 0.28)
        love.graphics.line(x+14, y+14, x+w-14, y+h-14)
        love.graphics.line(x+w-14, y+14, x+14, y+h-14)
        Fonts.with(11, function()
            love.graphics.setColor(0.45, 0.70, 1.00, 0.80)
            love.graphics.printf("FACE DOWN", x, y+h/2-10, w, "center")
            love.graphics.setColor(0.35, 0.55, 0.85, 0.60)
            love.graphics.printf(isAttacker and "ATTACKER" or "DEFENDER", x, y+h/2+8, w, "center")
        end)
        return
    end

    -- Empty slot
    if not card then
        love.graphics.setColor(0.10, 0.08, 0.15, 1)
        love.graphics.rectangle("fill", x, y, w, h, r)
        love.graphics.setColor(0.25, 0.20, 0.35, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, w, h, r)
        Fonts.with(11, function()
            love.graphics.setColor(0.35, 0.30, 0.45, 1)
            love.graphics.printf("(empty)", x, y+h/2-8, w, "center")
        end)
        return
    end

    local base = Theme.cardColors[card.type]  or { 0.18, 0.18, 0.18, 1 }
    local acc  = Theme.cardAccents[card.type] or { 0.60, 0.60, 0.60, 1 }
    local art  = Theme.cardArt[card.type]     or cmix(base, {1,1,1,1}, 0.25)

    local isAtkMode = (card.mode == "attack")

    local destroyed = (not isAttacker) and (outcome == "defender_destroyed")
    local exhausted = ((not isAttacker) and (outcome == "defender_exhausted" or outcome == "tie"))
                   or (isAttacker and (outcome == "attacker_exhausted" or outcome == "tie"))
    local dimF = (destroyed or exhausted) and 0.40 or 1.0

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.60)
    love.graphics.rectangle("fill", x+6, y+6, w, h, r)

    -- Outer glow (type accent)
    love.graphics.setColor(acc[1], acc[2], acc[3], 0.30 * dimF)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", x-3, y-3, w+6, h+6, r+3)
    love.graphics.setLineWidth(1)

    -- Outer shell gradient (acc→base)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x-1, y-1, w+2, h+2, r+1)
    vgrad(x, y, w, h, cmix(acc, BLACK, 0.55), cmix(base, BLACK, 0.40))

    -- Inner body
    local ix, iy, iw, ih = x+4, y+4, w-8, h-8
    vgrad(ix, iy, iw, ih, cmix(base, BLACK, 0.45), { 0.039, 0.008, 0.016, 1 })

    -- Scanlines overlay
    love.graphics.setColor(1, 1, 1, 0.022)
    for sy = iy, iy+ih, 3 do
        love.graphics.line(ix, sy, ix+iw, sy)
    end

    -- Inner border
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, dimF)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ix, iy, iw, ih, 4)

    -- Layout: header 26px | art flex | nameplate 34px | stats 40px
    local HDR  = 26
    local NP   = 34
    local SB   = 40
    local GAP  = 4
    local artY = iy + HDR + GAP
    local artH = ih - HDR - NP - SB - GAP * 3
    local npY  = artY + artH + GAP
    local sbY  = npY + NP + GAP

    -- Header strip (.cstrip)
    withScissor(ix, iy, iw, HDR, function()
        vgrad(ix, iy, iw, HDR,
            cmix(acc, BLACK, 0.45),
            cmix(base, BLACK, 0.35))
        -- Sheen top line
        love.graphics.setColor(1, 1, 1, 0.20)
        love.graphics.line(ix+2, iy+1, ix+iw-2, iy+1)
        -- Dot indicator
        love.graphics.setColor(acc[1], acc[2], acc[3], dimF)
        love.graphics.circle("fill", ix+12, iy+HDR/2, 3.5)
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.circle("fill", ix+12, iy+HDR/2, 1.5)
        -- Type label
        Fonts.with(9, function()
            love.graphics.setColor(1, 1, 1, 0.95 * dimF)
            love.graphics.print((card.type or ""):sub(1,3):upper(), ix+22, iy+HDR/2-5)
        end)
    end)

    -- Mode badge (.cmode) top-right corner
    local bdgX = ix + iw - 26
    local bdgY = iy + 4
    local bdgS = 22
    love.graphics.setColor(0.071, 0.008, 0.016, 1)
    love.graphics.rectangle("fill", bdgX, bdgY, bdgS, bdgS, 3)
    love.graphics.setColor(acc[1]*0.60, acc[2]*0.60, acc[3]*0.60, dimF)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bdgX, bdgY, bdgS, bdgS, 3)
    love.graphics.rectangle("line", bdgX+2, bdgY+2, bdgS-4, bdgS-4, 2)
    Fonts.with(9, function()
        love.graphics.setColor(1, 1, 1, dimF)
        love.graphics.printf(isAtkMode and "A" or "D", bdgX, bdgY+6, bdgS, "center")
    end)

    -- Art zone (.cart) with field lines
    if artH > 0 then
        withScissor(ix, artY, iw, artH, function()
            vgrad(ix, artY, iw, artH, art, cmix(art, BLACK, 0.40))
            -- Highlight sheen top-left
            love.graphics.setColor(1, 1, 1, 0.10)
            love.graphics.rectangle("fill", ix, artY, iw*0.55, artH*0.45)
            -- Field lines
            love.graphics.setColor(1, 1, 1, 0.18)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", ix+6, artY+4, iw-12, artH-8, 2)
            love.graphics.line(ix+6, artY+artH/2, ix+iw-6, artY+artH/2)
            love.graphics.circle("line", ix+iw/2, artY+artH/2, math.min(iw,artH)*0.20)
            -- "ART" tag (dashed border)
            Fonts.with(9, function()
                love.graphics.setColor(1, 1, 1, 0.50)
                love.graphics.rectangle("line", ix+6, artY+artH-18, 28, 14, 1)
                love.graphics.printf("ART", ix+6, artY+artH-16, 28, "center")
            end)
        end)
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ix, artY, iw, artH)
    end

    -- Nameplate (.cname)
    withScissor(ix, npY, iw, NP, function()
        vgrad(ix, npY, iw, NP,
            { 0.082, 0.031, 0.039, 1 },
            { 0.039, 0.012, 0.020, 1 })
        love.graphics.setColor(acc[1]*0.40, acc[2]*0.40, acc[3]*0.40, dimF)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ix, npY, iw, NP)
        Fonts.with(9, function()
            -- Glow shadow
            love.graphics.setColor(acc[1]*0.35, acc[2]*0.35, acc[3]*0.35, dimF)
            love.graphics.printf(card.name or "", ix+5, npY+5, iw-10, "center")
            -- Cream name
            love.graphics.setColor(0.953, 0.914, 0.824, dimF)
            love.graphics.printf(card.name or "", ix+5, npY+4, iw-10, "center")
            -- Sub label (type, dim purple)
            love.graphics.setColor(0.48, 0.42, 0.60, 0.80 * dimF)
            love.graphics.printf((card.type or ""):upper(), ix+5, npY+NP-15, iw-10, "center")
        end)
    end)

    -- Stats row (.cstats): ATK | ◆ | DEF with large values
    withScissor(ix, sbY, iw, SB, function()
        vgrad(ix, sbY, iw, SB,
            { 0.039, 0.008, 0.016, 1 },
            BLACK)
        love.graphics.setColor(0, 0, 0, 0.80)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ix, sbY, iw, SB)

        local atk  = card.atk or 0
        local def  = card.def or 0
        local midX = ix + iw/2
        local labY = sbY + 5
        local valY = sbY + 15

        -- ATK label
        Fonts.with(9, function()
            love.graphics.setColor(ATK_C[1]*0.70, ATK_C[2]*0.70, ATK_C[3]*0.70, dimF)
            love.graphics.printf("ATK", ix+6, labY, iw/2-10, "left")
        end)
        -- ATK value (large, glow shadow)
        Fonts.with(16, function()
            love.graphics.setColor(ATK_C[1]*0.38, ATK_C[2]*0.38, ATK_C[3]*0.38, dimF)
            love.graphics.printf(tostring(atk), ix+6, valY+1, iw/2-10, "left")
            love.graphics.setColor(ATK_C[1], ATK_C[2], ATK_C[3], dimF)
            love.graphics.printf(tostring(atk), ix+6, valY, iw/2-10, "left")
        end)

        -- Gold divider ◆
        Fonts.with(9, function()
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.80 * dimF)
            love.graphics.printf("*", midX-5, sbY+SB/2-5, 10, "center")
        end)

        -- DEF label
        Fonts.with(9, function()
            love.graphics.setColor(DEF_C[1]*0.70, DEF_C[2]*0.70, DEF_C[3]*0.70, dimF)
            love.graphics.printf("DEF", midX+8, labY, iw/2-14, "right")
        end)
        -- DEF value (large, glow shadow)
        Fonts.with(16, function()
            love.graphics.setColor(DEF_C[1]*0.38, DEF_C[2]*0.38, DEF_C[3]*0.38, dimF)
            love.graphics.printf(tostring(def), midX+8, valY+1, iw/2-14, "right")
            love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], dimF)
            love.graphics.printf(tostring(def), midX+8, valY, iw/2-14, "right")
        end)
    end)

    if destroyed then
        withScissor(x, y, w, h, function()
            -- Crimson gradient wash rising from below
            vgrad(x, y, w, h,
                { 0.00, 0.00, 0.00, 0.50 },
                { 0.28, 0.01, 0.02, 0.88 })

            -- Deep red border glow (outer halo + sharp inner ring)
            love.graphics.setColor(0.85, 0.04, 0.02, 0.32)
            love.graphics.setLineWidth(10)
            love.graphics.rectangle("line", x, y, w, h, r)
            love.graphics.setColor(0.90, 0.08, 0.03, 0.95)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", x, y, w, h, r)
            love.graphics.setLineWidth(1)

            -- Fracture lines radiating from card center
            local cx = x + w * 0.50
            local cy = y + h * 0.42
            local cracks = {
                { ang = -0.55, len = 0.78 },
                { ang =  0.38, len = 0.70 },
                { ang =  1.82, len = 0.82 },
                { ang =  2.85, len = 0.68 },
                { ang = -1.95, len = 0.60 },
                { ang =  1.10, len = 0.45 },
                { ang = -2.60, len = 0.50 },
            }
            local half = math.min(w, h) * 0.52
            for _, c in ipairs(cracks) do
                local ex = cx + math.cos(c.ang) * half * c.len
                local ey = cy + math.sin(c.ang) * half * c.len
                -- Ember glow halo
                love.graphics.setColor(0.95, 0.28, 0.06, 0.22)
                love.graphics.setLineWidth(5)
                love.graphics.line(cx, cy, ex, ey)
                -- Warm crack core
                love.graphics.setColor(0.98, 0.55, 0.22, 0.75)
                love.graphics.setLineWidth(1)
                love.graphics.line(cx, cy, ex, ey)
            end
            love.graphics.setLineWidth(1)

            -- Impact ember at fracture origin
            love.graphics.setColor(0.90, 0.20, 0.04, 0.65)
            love.graphics.circle("fill", cx, cy, 9)
            love.graphics.setColor(1.00, 0.72, 0.30, 0.90)
            love.graphics.circle("fill", cx, cy, 4)
            love.graphics.setColor(1.00, 0.96, 0.80, 1.00)
            love.graphics.circle("fill", cx, cy, 1.5)

            -- Debris fragments near corners
            local frags = {
                { x+14, y+22 }, { x+w-20, y+18 },
                { x+10, y+h-28 }, { x+w-16, y+h-22 },
                { x+w-30, y+32 }, { x+18, y+h-40 },
            }
            for _, f in ipairs(frags) do
                love.graphics.setColor(0.85, 0.20, 0.05, 0.55)
                love.graphics.rectangle("fill", f[1], f[2], 5, 5, 1)
                love.graphics.setColor(1.00, 0.55, 0.25, 0.40)
                love.graphics.rectangle("line", f[1], f[2], 5, 5, 1)
            end
        end)

        -- Rotated "ELIMINATED" stamp centered on lower card half
        local stampCX = x + w * 0.50
        local stampCY = y + h * 0.70
        love.graphics.push()
        love.graphics.translate(stampCX, stampCY)
        love.graphics.rotate(-0.20)
        local sw, sh = w - 22, 36
        -- Stamp shadow
        love.graphics.setColor(0, 0, 0, 0.70)
        love.graphics.rectangle("fill", -sw/2 + 3, -sh/2 + 3, sw, sh, 3)
        -- Stamp body
        love.graphics.setColor(0.48, 0.02, 0.01, 0.94)
        love.graphics.rectangle("fill", -sw/2, -sh/2, sw, sh, 3)
        -- Outer border
        love.graphics.setColor(0.92, 0.08, 0.03, 1.00)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", -sw/2, -sh/2, sw, sh, 3)
        -- Inner border (double-stamp effect)
        love.graphics.setColor(0.75, 0.06, 0.02, 0.70)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -sw/2 + 4, -sh/2 + 4, sw - 8, sh - 8, 2)
        love.graphics.setLineWidth(1)
        Fonts.with(13, function()
            -- Text shadow
            love.graphics.setColor(0.30, 0.00, 0.00, 0.80)
            love.graphics.printf("ELIMINATED", -sw/2 + 1, -sh/2 + 11, sw, "center")
            -- Main warm-cream text
            love.graphics.setColor(1.00, 0.82, 0.72, 1.00)
            love.graphics.printf("ELIMINATED", -sw/2, -sh/2 + 10, sw, "center")
        end)
        love.graphics.pop()

    elseif exhausted then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", x, y, w, h, r)
        Fonts.with(11, function()
            love.graphics.setColor(0.70, 0.70, 0.75, 0.90)
            love.graphics.printf("EXHAUSTED", x, y+h/2-8, w, "center")
        end)
    end
end

-- ── Public draw ───────────────────────────────────────────────────────────────

function CombatOverlay.draw(data, anim)
    if not data then return end
    anim = anim or {}

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    local clashX      = anim.clashX      or 0
    local resultAlpha = anim.resultAlpha  or 0
    local shakeX      = anim.shakeX      or 0

    local outcome = data.outcome or "tie"
    local outCol  = OUT_COL[outcome]  or { 0.80, 0.80, 0.80, 1 }
    local outText = OUT_TEXT[outcome] or outcome:upper()

    -- ── 1. Cinematic backdrop (.overlay::before) ─────────────────────────────
    love.graphics.setColor(PAGE)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Warm left radial (red, 18% x)
    love.graphics.setColor(0.706, 0.078, 0.157, 0.28)
    love.graphics.circle("fill", W * 0.18, H * 0.50, W * 0.52)
    -- Cool right radial (blue, 82% x)
    love.graphics.setColor(0.078, 0.314, 0.706, 0.28)
    love.graphics.circle("fill", W * 0.82, H * 0.50, W * 0.52)
    -- Dark purple center
    love.graphics.setColor(0.071, 0.022, 0.149, 0.50)
    love.graphics.circle("fill", W/2, H * 0.44, W * 0.55)

    -- Diagonal impact rays from center (.overlay::after conic-gradient)
    if clashX > 0.01 then
        local rCX, rCY = W/2 + shakeX, H * 0.36
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.048 * clashX)
        love.graphics.setLineWidth(1)
        for i = 0, 11 do
            local ang = i * math.pi / 6
            local len = math.max(W, H)
            love.graphics.line(rCX, rCY, rCX + math.cos(ang)*len, rCY + math.sin(ang)*len)
        end
        love.graphics.setLineWidth(1)
    end

    -- Outcome-matched edge glow (fades in with result)
    if resultAlpha > 0.02 then
        love.graphics.setColor(outCol[1], outCol[2], outCol[3], 0.18 * resultAlpha)
        love.graphics.setLineWidth(14)
        love.graphics.rectangle("line", 4, 4, W-8, H-8)
        love.graphics.setColor(outCol[1], outCol[2], outCol[3], 0.40 * resultAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", 4, 4, W-8, H-8)
        love.graphics.setLineWidth(1)
    end

    -- Scanlines
    love.graphics.setColor(1, 1, 1, 0.020)
    for sy = 0, H, 3 do
        love.graphics.line(0, sy, W, sy)
    end

    -- Corner brackets (.ob) — gold
    goldenBrackets(10, 10, W-20, H-20, 22)

    -- ── 2. Meta strip (top center) ────────────────────────────────────────────
    Fonts.with(9, function()
        -- Gold dots flanking the text
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.80)
        love.graphics.circle("fill", W/2 - 94, 20, 3)
        love.graphics.circle("fill", W/2 + 94, 20, 3)
        love.graphics.setColor(GOLD_DIM)
        love.graphics.printf("TURN  ·  PHASE  ·  COMBAT", 0, 13, W, "center")
    end)

    -- ── 3. Title "COMBAT" (.title) ────────────────────────────────────────────
    local titleY = 32
    Fonts.with(33, function()
        -- 3D shadow offset
        love.graphics.setColor(0.165, 0.118, 0.000, 1)
        love.graphics.printf("COMBAT", shakeX, titleY + 4, W, "center")
        -- Glow halo
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.28)
        love.graphics.printf("COMBAT", shakeX, titleY, W, "center")
        -- Main gold text
        love.graphics.setColor(GOLD)
        love.graphics.printf("COMBAT", shakeX, titleY, W, "center")
    end)
    -- Underline gradient bar (.title .underline)
    local ulW = 220
    local ulX = W/2 - ulW/2 + shakeX
    local ulY = titleY + 46
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0)
    -- Approximate gradient: transparent → gold → transparent
    for i = 0, ulW do
        local t = i / ulW
        local a = math.sin(t * math.pi) * 0.60
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], a)
        love.graphics.line(ulX + i, ulY, ulX + i, ulY + 2)
    end

    -- ── 4. Arena ──────────────────────────────────────────────────────────────
    local cardW    = 230
    local cardH    = 264
    local cardTopY = 94

    local atkCX = W * 0.25 + shakeX - clashX * 44
    local defCX = W * 0.75 + shakeX + clashX * 44

    -- Role labels (.side .role)
    local atkOffX = anim.atkOffX or 0
    local defOffX = anim.defOffX or 0
    Fonts.with(9, function()
        love.graphics.setColor(ATK_C[1], ATK_C[2], ATK_C[3], 0.90)
        love.graphics.printf("▶  ATTACKER", 0, cardTopY - 18, W * 0.50, "center")
        love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], 0.90)
        love.graphics.printf("DEFENDER  ◀", W * 0.50, cardTopY - 18, W * 0.50, "center")
    end)

    local atkX = math.floor(atkCX - cardW/2 + atkOffX)
    local defX = math.floor(defCX - cardW/2 + defOffX)

    local revealed    = clashX >= 0.5 or resultAlpha > 0.05
    local atkReveal   = revealed or not (data.attacker and data.attacker.wasHidden)
    local defReveal   = revealed or not (data.defender and data.defender.wasHidden)

    drawCombatCard(data.attacker, atkX, cardTopY, cardW, cardH, true,  outcome, atkReveal)
    drawCombatCard(data.defender, defX, cardTopY, cardW, cardH, false, outcome, defReveal)

    -- ── 5. VS / CLASH pillar (.vs) ────────────────────────────────────────────
    local vsCX = W/2 + shakeX
    local vsCY = cardTopY + cardH/2
    local vsR  = 46
    local vsOutR = vsR + 14

    -- Inner glow fill
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.12)
    love.graphics.circle("fill", vsCX, vsCY, vsR)
    -- Inner solid ring (.vs__ring)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.80)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", vsCX, vsCY, vsR)
    love.graphics.setLineWidth(1)
    -- Outer dashed ring (.vs__ring--outer) — approximated with arc segments
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.42)
    love.graphics.setLineWidth(1)
    for i = 0, 15 do
        local a1 = (i / 16) * math.pi * 2
        local a2 = ((i + 0.55) / 16) * math.pi * 2
        love.graphics.arc("line", "open", vsCX, vsCY, vsOutR, a1, a2)
    end
    love.graphics.setLineWidth(1)

    local vsAlpha    = math.max(0, 1 - clashX * 5)
    local clashAlpha = math.min(1, clashX * 3)

    -- "VS" text (.vs__text)
    if vsAlpha > 0.02 then
        Fonts.with(33, function()
            love.graphics.setColor(0.165, 0.118, 0.000, vsAlpha)
            love.graphics.printf("VS", vsCX - W/2, vsCY - 22, W, "center")
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], vsAlpha)
            love.graphics.printf("VS", vsCX - W/2, vsCY - 22, W, "center")
        end)
    end

    -- "CLASH!" + spark burst (.vs__text--clash, .vs__sparks)
    if clashAlpha > 0.02 then
        -- Spark lines radiating from VS center
        love.graphics.setLineWidth(2)
        for i = 0, 11 do
            local ang = i * math.pi / 6
            local len = 22 + clashAlpha * 42
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], clashAlpha * 0.65)
            love.graphics.line(vsCX, vsCY,
                vsCX + math.cos(ang)*len, vsCY + math.sin(ang)*len)
        end
        love.graphics.setLineWidth(1)
        -- White glow "CLASH!"
        Fonts.with(22, function()
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], clashAlpha * 0.40)
            love.graphics.printf("CLASH!", vsCX - W/2, vsCY - 14, W, "center")
            love.graphics.setColor(1.00, 0.96, 0.82, clashAlpha)
            love.graphics.printf("CLASH!", vsCX - W/2, vsCY - 14, W, "center")
        end)
    end

    -- State label below VS (.vs__state)
    Fonts.with(9, function()
        love.graphics.setColor(GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], 0.75)
        love.graphics.printf(
            clashX > 0.5 and "STATE  ·  CLASH" or "STATE  ·  VS",
            vsCX - W/2, vsCY + vsR + 8, W, "center")
    end)

    -- ── 6. Stat comparison bar (.bar) ─────────────────────────────────────────
    local barTopY = cardTopY + cardH + 16
    local barW    = W - 320
    local barX    = (W - barW) / 2
    local barH    = 22

    if data.attacker and data.defender then
        local atkVal   = data.attacker.atk or 0
        local defVal   = data.defender.def or 0
        local atkBonus = data.attacker.atkBonus or 0
        local defBonus = data.defender.defBonus or 0
        local defLabel = data.defender.isKeeper and "EFF.DEF" or "DEF"

        local total   = math.max(atkVal + defVal, 1)
        local atkFill = math.floor(barW * atkVal / total)
        local defFill = math.floor(barW * defVal / total)

        -- Labels above bar
        Fonts.with(9, function()
            -- ATK label + bonus tag
            love.graphics.setColor(ATK_C[1], ATK_C[2], ATK_C[3], 1)
            local atkLabel = "ATK  " .. atkVal
            if atkBonus > 0 then atkLabel = atkLabel .. " (+" .. atkBonus .. " MID)" end
            love.graphics.print(atkLabel, barX, barTopY - 18)
            -- DEF label + bonus tag
            love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], 1)
            local defLabelStr = defVal .. "  " .. defLabel
            if defBonus > 0 then defLabelStr = "(+" .. defBonus .. " MID)  " .. defLabelStr end
            love.graphics.printf(defLabelStr, barX, barTopY - 18, barW, "right")
        end)

        -- Track (.bar__track)
        love.graphics.setColor(0.071, 0.031, 0.125, 1)
        love.graphics.rectangle("fill", barX, barTopY, barW, barH, 2)
        -- Tick marks (.bar__track::before)
        love.graphics.setColor(1, 1, 1, 0.05)
        for tx = barX, barX + barW, 40 do
            love.graphics.line(tx, barTopY, tx, barTopY + barH)
        end
        -- Track border
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.22)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX, barTopY, barW, barH, 2)

        -- ATK fill from left with angled right edge (.bar__fill--atk clip-path)
        withScissor(barX, barTopY, atkFill + 2, barH, function()
            love.graphics.setColor(ATK_C[1], ATK_C[2], ATK_C[3], 1)
            love.graphics.polygon("fill",
                barX,           barTopY,
                barX + atkFill, barTopY,
                barX + atkFill - 8, barTopY + barH,
                barX,           barTopY + barH)
            -- Shine
            love.graphics.setColor(1, 1, 1, 0.18)
            love.graphics.rectangle("fill", barX, barTopY, atkFill, barH/2)
        end)

        -- DEF fill from right with angled left edge (.bar__fill--def clip-path)
        withScissor(barX + barW - defFill - 2, barTopY, defFill + 2, barH, function()
            love.graphics.setColor(DEF_C[1], DEF_C[2], DEF_C[3], 0.80)
            love.graphics.polygon("fill",
                barX + barW - defFill + 8, barTopY,
                barX + barW,               barTopY,
                barX + barW,               barTopY + barH,
                barX + barW - defFill,     barTopY + barH)
            -- Shine
            love.graphics.setColor(1, 1, 1, 0.18)
            love.graphics.rectangle("fill",
                barX + barW - defFill, barTopY, defFill, barH/2)
        end)

        -- Center line (.bar__center) — gold vertical
        local centerX = math.floor(barX + barW/2)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
        love.graphics.setLineWidth(2)
        love.graphics.line(centerX, barTopY - 5, centerX, barTopY + barH + 5)
        love.graphics.setLineWidth(1)

        -- Margin zone + diagonal hatching (.bar__margin)
        local margin = atkVal - defVal
        if margin ~= 0 then
            local marginW = math.abs(margin) / total * barW
            local marginX = margin > 0 and centerX or (centerX - marginW)
            marginX = math.max(barX, math.min(barX + barW - marginW, marginX))

            withScissor(marginX, barTopY, math.max(marginW, 1), barH, function()
                love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.30)
                love.graphics.setLineWidth(1)
                for i = -barH, marginW + barH, 8 do
                    love.graphics.line(
                        marginX + i,        barTopY,
                        marginX + i + barH, barTopY + barH)
                end
                -- Margin borders
                love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.70)
                love.graphics.line(marginX, barTopY - 4, marginX, barTopY + barH + 4)
                love.graphics.line(marginX + marginW, barTopY - 4, marginX + marginW, barTopY + barH + 4)
            end)

            -- Margin tag above bar (.bar__margin-tag)
            local tagCX = marginX + marginW/2
            Fonts.with(9, function()
                love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.90)
                local sign = margin >= 0 and "+" or ""
                love.graphics.printf(
                    "Δ " .. sign .. margin,
                    tagCX - 50, barTopY - 36, 100, "center")
            end)
        end
    end

    -- ── 7. Result (fades in after clash) (.result) ───────────────────────────
    if resultAlpha > 0.02 then
        local resY = barTopY + barH + 16

        -- LP damage number (.lp) — large gold
        if (outcome == "damage" or outcome == "defender_destroyed") and (data.damage or 0) > 0 then
            Fonts.with(33, function()
                love.graphics.setColor(0.165, 0.118, 0.000, resultAlpha)
                love.graphics.printf("LP  −" .. data.damage, shakeX, resY + 4, W, "center")
                love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], resultAlpha)
                love.graphics.printf("LP  −" .. data.damage, shakeX, resY, W, "center")
            end)
            resY = resY + 52
        end

        -- Outcome pill (.pill) — rounded, outcome-colored border + glow
        local pillW = 310
        local pillH = 40
        local pillX = W/2 - pillW/2 + shakeX
        local pillR = 20

        -- Halo behind pill
        love.graphics.setColor(outCol[1], outCol[2], outCol[3], 0.20 * resultAlpha)
        love.graphics.rectangle("fill", pillX-10, resY-5, pillW+20, pillH+10, pillR+6)
        -- Dark pill body
        love.graphics.setColor(0, 0, 0, 0.80 * resultAlpha)
        love.graphics.rectangle("fill", pillX, resY, pillW, pillH, pillR)
        -- Pill border
        love.graphics.setColor(outCol[1], outCol[2], outCol[3], 0.80 * resultAlpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", pillX, resY, pillW, pillH, pillR)
        love.graphics.setLineWidth(1)
        -- Dot marker (.pill .marker)
        love.graphics.setColor(outCol[1], outCol[2], outCol[3], resultAlpha)
        love.graphics.circle("fill", pillX + 24, resY + pillH/2, 4)
        -- Outcome text
        Fonts.with(11, function()
            love.graphics.setColor(outCol[1], outCol[2], outCol[3], resultAlpha)
            love.graphics.printf(outText, pillX, resY + pillH/2 - 7, pillW, "center")
        end)
        resY = resY + pillH + 10

        -- Margin / LP summary line
        if data.margin ~= nil then
            local marginStr
            if outcome == "damage" then
                marginStr = "−" .. (data.damage or 0) .. " LP  ·  margin " .. data.margin
            elseif outcome == "save" or outcome == "tie" then
                marginStr = "no LP damage  ·  margin " .. (data.margin or 0)
            else
                local s = (data.margin or 0) >= 0 and "+" or ""
                marginStr = "margin " .. s .. (data.margin or 0)
            end
            Fonts.with(9, function()
                love.graphics.setColor(INK_DIM[1], INK_DIM[2], INK_DIM[3], 0.65 * resultAlpha)
                love.graphics.printf(marginStr, shakeX, resY, W, "center")
            end)
            resY = resY + 16
        end

        -- Dismiss hint (fades in after pill is fully visible)
        Fonts.with(9, function()
            love.graphics.setColor(0.35, 0.28, 0.42, math.max(0, resultAlpha - 0.35))
            love.graphics.printf("CLICK  OR  SPACE  TO  CONTINUE", shakeX, resY + 6, W, "center")
        end)
    end

    -- Character portrait in the margin (player side)
    local isPlayerAttacking = (data.activePlayer == "player") or (data.activePlayer == nil)
    if isPlayerAttacking then
        Character.drawSide("left", W, H)
    else
        Character.drawSide("right", W, H, "worried")
    end

    love.graphics.setFont(Fonts.get(16))
end

-- ── Snapshot helper (called before resolution) ────────────────────────────────

function CombatOverlay.snapshot(pitchedCard)
    if not pitchedCard then return nil end
    local d = pitchedCard.definition
    return {
        name      = d.name,
        type      = d.type,
        mode      = pitchedCard.mode,
        wasHidden = (pitchedCard.mode == "defense"),
        atk       = d.stats and d.stats.atk or 0,
        def       = d.stats and d.stats.def or 0,
        isKeeper  = (d.type == "keeper"),
        rarity    = d.rarity,
    }
end

return CombatOverlay
