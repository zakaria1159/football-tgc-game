-- Pitch rendering — premium football pitch aesthetic.
local Theme = require("ui.theme")
local Card  = require("ui.card")
local Fonts = require("ui.fonts")
local C     = require("engine.constants")

local Pitch = {}

-- ── Colors ────────────────────────────────────────────────────────────────────

local PITCH_DARK  = { 0.051, 0.165, 0.078, 1 }   -- #0d2a14
local PITCH_LIGHT = { 0.071, 0.212, 0.110, 1 }   -- #12361c
local LINE        = { 0.902, 1.000, 0.902, 0.90 } -- rgba(230,255,230,0.9)
local LINE_DIM    = { 0.902, 1.000, 0.902, 0.55 }
local SLOT_BG_A   = { 0.024, 0.059, 0.031, 1 }   -- #060f08
local SLOT_BG_B   = { 0.039, 0.102, 0.059, 1 }   -- #0a1a0f
local SLOT_BORDER = { 0.353, 0.651, 0.400, 0.80 } -- rgba(90,166,102,0.8)
local SLOT_DASH   = { 0.353, 0.651, 0.400, 0.30 } -- dashed inner
local SLOT_LABEL  = { 0.353, 0.651, 0.400, 0.55 }
local GOLD        = { 1.000, 0.843, 0.000, 1 }
local RED         = { 1.000, 0.267, 0.267, 1 }
local TRAP_COL    = { 0.416, 0.180, 0.761, 1 }   -- purple for trap zone
local TRAP_BORDER = { 0.698, 0.478, 1.000, 0.70 }

-- ── Slot dimensions (from HTML: 88×110, radius 8) ────────────────────────────

local SW  = 88
local SH  = 110
local SR  = 8
local GAP = 16

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function vgrad(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2)
    local m = love.graphics.newMesh({
        { x,     y,     0, 0, r1, g1, b1, a1 },
        { x + w, y,     0, 0, r1, g1, b1, a1 },
        { x + w, y + h, 0, 0, r2, g2, b2, a2 },
        { x,     y + h, 0, 0, r2, g2, b2, a2 },
    }, "fan", "static")
    love.graphics.draw(m)
end

local function glowLine(x1, y1, x2, y2, col, alpha)
    love.graphics.setColor(0, 0, 0, 0.40)
    love.graphics.setLineWidth(3)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x1, y1, x2, y2)
    love.graphics.setLineWidth(1)
end

local function glowRect(x, y, w, h, col, alpha, lw)
    lw = lw or 2
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(lw + 1.5)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.setLineWidth(lw)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
end

local function glowCircle(x, y, rad, col, alpha)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(3.5)
    love.graphics.circle("line", x, y, rad)
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, rad)
    love.graphics.setLineWidth(1)
end

-- Dashed rectangle approximation (draws short segments with gaps).
local function dashedRect(x, y, w, h, col, alpha, segLen, segGap)
    segLen = segLen or 6
    segGap = segGap or 4
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.setLineWidth(1)
    local function dashes(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local ux, uy = dx / len, dy / len
        local t = 0
        local drawing = true
        while t < len do
            local t2 = math.min(t + (drawing and segLen or segGap), len)
            if drawing then
                love.graphics.line(
                    x1 + ux * t,  y1 + uy * t,
                    x1 + ux * t2, y1 + uy * t2)
            end
            t = t2
            drawing = not drawing
        end
    end
    dashes(x, y, x + w, y)
    dashes(x + w, y, x + w, y + h)
    dashes(x + w, y + h, x, y + h)
    dashes(x, y + h, x, y)
end

-- Row Y positions for one side.
local function rowYs(sideY, sideH, flipped)
    local pad    = 10
    local YGAP   = 5   -- gap between consecutive slot edges
    local rowH   = (sideH - 2 * pad) / 4
    -- Cap slot height so cards never bleed into the adjacent row
    local slotH  = math.floor(math.min(SH, rowH - YGAP))
    local function rY(i) return sideY + pad + (i - 1) * rowH + (rowH - slotH) / 2 end
    if flipped then
        -- opponent top→bot: keeper, defender, midfielder, striker
        return { keeper = rY(1), defenders = rY(2), midfielder = rY(3), strikers = rY(4), slotH = slotH }
    else
        -- own top→bot: striker, midfielder, defender, keeper
        return { strikers = rY(1), midfielder = rY(2), defenders = rY(3), keeper = rY(4), slotH = slotH }
    end
end

local function centerSlots(n, pX, pW)
    return pX + (pW - (n * SW + (n - 1) * GAP)) / 2
end

-- ── Pitch background ──────────────────────────────────────────────────────────

local function drawPitchBackground(pX, pY, pW, pH)
    -- Base dark green
    love.graphics.setColor(PITCH_DARK)
    love.graphics.rectangle("fill", pX, pY, pW, pH)

    -- 55px alternating vertical mow stripes
    local stripeW = 55
    local n = math.ceil(pW / stripeW)
    for i = 0, n - 1 do
        if i % 2 == 1 then
            love.graphics.setColor(PITCH_LIGHT)
            love.graphics.rectangle("fill", pX + i * stripeW, pY, stripeW, pH)
        end
    end

    -- Subtle center vignette (lighter at center)
    local cx = pX + pW / 2
    local cy = pY + pH / 2
    local segments = 32
    for ri = 1, segments do
        local t  = ri / segments
        local a  = 0.04 * (1 - t)
        local rx = pW * 0.35 * t
        local ry = pH * 0.30 * t
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.ellipse("fill", cx, cy, rx, ry)
    end

    -- Edge darkening gradient (top/bottom fade to black)
    vgrad(pX, pY,      pW, pH * 0.20, 0, 0, 0, 0.45, 0, 0, 0, 0)
    vgrad(pX, pY + pH * 0.80, pW, pH * 0.20, 0, 0, 0, 0, 0, 0, 0, 0.45)

    -- Gold side borders
    love.graphics.setColor(1.000, 0.843, 0.000, 0.15)
    love.graphics.setLineWidth(1)
    love.graphics.line(pX,      pY, pX,      pY + pH)
    love.graphics.line(pX + pW, pY, pX + pW, pY + pH)
    love.graphics.setLineWidth(1)
end

-- ── Pitch markings ────────────────────────────────────────────────────────────

local function drawPitchMarkings(pX, pY, pW, pH)
    local inset = 20
    local mX = pX + inset
    local mY = pY + inset
    local mW = pW - 2 * inset
    local mH = pH - 2 * inset
    local cx = pX + pW / 2
    local cy = pY + pH / 2

    -- Outer pitch border (2px glowing white)
    glowRect(mX, mY, mW, mH, LINE, LINE[4], 2)

    -- Goals: 80×6px bars, positioned just outside the border (top and bottom)
    local goalW = 80
    local goalH = 6
    local goalX = cx - goalW / 2
    -- Top goal (above border)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.rectangle("fill", goalX, mY - goalH, goalW, goalH)
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.rectangle("fill", goalX, mY - goalH - 1, goalW, 1)
    -- Bottom goal
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.rectangle("fill", goalX, mY + mH, goalW, goalH)
    love.graphics.setColor(1, 1, 1, 0.50)
    love.graphics.rectangle("fill", goalX, mY + mH + goalH, goalW, 1)

    -- Penalty boxes: 380px wide × 100px tall (scaled proportionally to actual pitch)
    -- HTML pitch is 880px wide and ~760px tall (800 - topbar - hand); scale height
    local scaleH  = mH / 760
    local pboxW   = math.floor(380 * (mW / 840))
    local pboxH   = math.floor(100 * scaleH)
    local pboxX   = cx - pboxW / 2
    -- Top penalty box (open top = no top border), drawn as 3 sides
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(3.5)
    love.graphics.line(pboxX, mY, pboxX, mY + pboxH)
    love.graphics.line(pboxX, mY + pboxH, pboxX + pboxW, mY + pboxH)
    love.graphics.line(pboxX + pboxW, mY + pboxH, pboxX + pboxW, mY)
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4])
    love.graphics.setLineWidth(2)
    love.graphics.line(pboxX, mY, pboxX, mY + pboxH)
    love.graphics.line(pboxX, mY + pboxH, pboxX + pboxW, mY + pboxH)
    love.graphics.line(pboxX + pboxW, mY + pboxH, pboxX + pboxW, mY)
    -- Bottom penalty box (open bottom)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(3.5)
    local pboxBY = mY + mH - pboxH
    love.graphics.line(pboxX, pboxBY, pboxX, mY + mH)
    love.graphics.line(pboxX, pboxBY, pboxX + pboxW, pboxBY)
    love.graphics.line(pboxX + pboxW, pboxBY, pboxX + pboxW, mY + mH)
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4])
    love.graphics.setLineWidth(2)
    love.graphics.line(pboxX, pboxBY, pboxX, mY + mH)
    love.graphics.line(pboxX, pboxBY, pboxX + pboxW, pboxBY)
    love.graphics.line(pboxX + pboxW, pboxBY, pboxX + pboxW, mY + mH)
    love.graphics.setLineWidth(1)

    -- Goal boxes: 200px wide × 44px tall
    local gboxW = math.floor(200 * (mW / 840))
    local gboxH = math.floor(44 * scaleH)
    local gboxX = cx - gboxW / 2
    -- Top goal box
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4] * 0.75)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(gboxX, mY, gboxX, mY + gboxH)
    love.graphics.line(gboxX, mY + gboxH, gboxX + gboxW, mY + gboxH)
    love.graphics.line(gboxX + gboxW, mY + gboxH, gboxX + gboxW, mY)
    -- Bottom goal box
    love.graphics.line(gboxX, mY + mH, gboxX, mY + mH - gboxH)
    love.graphics.line(gboxX, mY + mH - gboxH, gboxX + gboxW, mY + mH - gboxH)
    love.graphics.line(gboxX + gboxW, mY + mH - gboxH, gboxX + gboxW, mY + mH)
    love.graphics.setLineWidth(1)

    -- Penalty spots: 70px from inset edge
    local pspotY = math.floor(70 * scaleH)
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4] * 0.90)
    love.graphics.circle("fill", cx, mY + pspotY, 2.5)
    love.graphics.circle("fill", cx, mY + mH - pspotY, 2.5)

    -- Center line (horizontal)
    glowLine(mX, cy, mX + mW, cy, { LINE[1], LINE[2], LINE[3] }, LINE[4])

    -- Center circle: 75px radius (150px diameter from HTML; scale to pitch)
    local circleR = math.floor(75 * (mW / 840))
    -- Slight fill inside circle
    love.graphics.setColor(PITCH_LIGHT[1], PITCH_LIGHT[2], PITCH_LIGHT[3], 0.40)
    love.graphics.circle("fill", cx, cy, circleR)
    glowCircle(cx, cy, circleR, { LINE[1], LINE[2], LINE[3] }, LINE[4])

    -- Center spot: 6px diameter
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4])
    love.graphics.circle("fill", cx, cy, 3)

    -- Corner arcs: 24px radius quarter circles (just inside each corner)
    local arcR = 24
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(3.5)
    love.graphics.arc("line", "open", mX,      mY,      arcR, 0,              math.pi / 2)
    love.graphics.arc("line", "open", mX + mW, mY,      arcR, math.pi / 2,    math.pi)
    love.graphics.arc("line", "open", mX,      mY + mH, arcR, -math.pi / 2,   0)
    love.graphics.arc("line", "open", mX + mW, mY + mH, arcR, math.pi,        3 * math.pi / 2)
    love.graphics.setColor(LINE[1], LINE[2], LINE[3], LINE[4] * 0.80)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", mX,      mY,      arcR, 0,              math.pi / 2)
    love.graphics.arc("line", "open", mX + mW, mY,      arcR, math.pi / 2,    math.pi)
    love.graphics.arc("line", "open", mX,      mY + mH, arcR, -math.pi / 2,   0)
    love.graphics.arc("line", "open", mX + mW, mY + mH, arcR, math.pi,        3 * math.pi / 2)
    love.graphics.setLineWidth(1)
end

-- ── Midline chip ──────────────────────────────────────────────────────────────

local function drawMidlineChip(matchState, pX, pW, cy)
    local turn  = (matchState and matchState.turn) or 1
    local phase = (matchState and matchState.phase) or "draw"
    local label = "TURN " .. string.format("%02d", turn) .. "  ·  " .. phase:upper()

    local chipW = 220
    local chipH = 24
    local chipX = pX + (pW - chipW) / 2
    local chipY = cy - chipH / 2

    -- Dark fill
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", chipX, chipY, chipW, chipH, 3)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", chipX + 1, chipY + 1, chipW - 2, chipH - 2, 3)

    -- Gold border glow
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.20)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", chipX - 1, chipY - 1, chipW + 2, chipH + 2, 4)
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.45)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", chipX, chipY, chipW, chipH, 3)
    love.graphics.setLineWidth(1)

    -- Text
    Fonts.with(8, function()
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.printf(label, chipX + 1, chipY + 9, chipW, "center")
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
        love.graphics.printf(label, chipX, chipY + 8, chipW, "center")
    end)
end

-- ── Public draw function ─────────────────────────────────────────────────────

function Pitch.draw(matchState, interactionState)
    if not matchState then return {} end

    local L  = Theme.layout
    local pX = L.pitchX
    local pW = L.pitchW
    local H  = love.graphics.getHeight()
    local pY = L.topBarH
    local pH = H - pY - L.handH
    local half = pH / 2
    local cy = pY + half

    drawPitchBackground(pX, pY, pW, pH)
    drawPitchMarkings(pX, pY, pW, pH)

    local hitboxes = {}

    -- Opponent side (top half, flipped — keeper at top)
    local oRows = rowYs(pY, half, true)
    Pitch._drawSide(matchState, "opponent", pX, pW, oRows, interactionState, hitboxes, true)

    -- Player side (bottom half — keeper at bottom)
    local pRows = rowYs(pY + half, half, false)
    Pitch._drawSide(matchState, "player", pX, pW, pRows, interactionState, hitboxes, false)

    drawMidlineChip(matchState, pX, pW, cy)

    return hitboxes
end

-- ── Side renderer ────────────────────────────────────────────────────────────

function Pitch._drawSide(matchState, owner, pX, pW, rows, interactionState, hitboxes, flipped)
    local pitch = matchState.players[owner].pitch

    local maxDef  = C.PITCH.MAX_DEFENDERS
    local maxStr  = C.PITCH.MAX_STRIKERS
    local slotH   = rows.slotH or SH

    local kx = pX + pW / 2 - SW / 2
    Pitch._slot(pitch.keeper, kx, rows.keeper, "keeper", 0, owner, interactionState, hitboxes, slotH, pitch)

    local dx = centerSlots(maxDef, pX, pW)
    for i = 1, maxDef do
        local x = dx + (i - 1) * (SW + GAP)
        Pitch._slot(pitch.defenders[i], x, rows.defenders, "defender", i, owner, interactionState, hitboxes, slotH, pitch)
    end

    local mx = pX + pW / 2 - SW / 2
    Pitch._slot(pitch.midfielder, mx, rows.midfielder, "midfielder", 0, owner, interactionState, hitboxes, slotH, pitch)

    local sx = centerSlots(maxStr, pX, pW)
    for i = 1, maxStr do
        local x = sx + (i - 1) * (SW + GAP)
        Pitch._slot(pitch.strikers[i], x, rows.strikers, "striker", i, owner, interactionState, hitboxes, slotH, pitch)
    end

    -- Trap zone: 2 slots stacked at the far right, vertically centered in the side
    local trapX  = pX + pW - SW - 10
    local trapY1 = rows.midfielder - math.floor(slotH / 2) - 4
    local trapY2 = trapY1 + slotH + 6
    Pitch._trapSlot(pitch.traps[1], trapX, trapY1, 1, owner, interactionState, hitboxes, slotH)
    Pitch._trapSlot(pitch.traps[2], trapX, trapY2, 2, owner, interactionState, hitboxes, slotH)
end

-- ── Single slot ──────────────────────────────────────────────────────────────

function Pitch._slot(pitchedCard, x, y, slotType, slotIndex, owner, interactionState, hitboxes, slotH, pitch)
    slotH = slotH or SH
    local r = SR

    local highlight    = false
    local attackTarget = false
    local selectedAtk  = false

    if interactionState then
        if interactionState.highlightedSlots then
            for _, s in ipairs(interactionState.highlightedSlots) do
                if s.slotType == slotType and s.slotIndex == slotIndex and s.owner == owner then
                    highlight = true; break
                end
            end
        end
        if interactionState.attackTargetSlots then
            for _, s in ipairs(interactionState.attackTargetSlots) do
                if s.slotType == slotType and s.slotIndex == slotIndex and s.owner == owner then
                    attackTarget = true; break
                end
            end
        end
        if interactionState.selectedAttackerSlot then
            local sa = interactionState.selectedAttackerSlot
            if sa.type == slotType and sa.index == slotIndex and owner == "player" then
                selectedAtk = true
            end
        end
    end

    local t = love.timer.getTime()

    -- Drop shadow for filled slots
    if pitchedCard then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", x + 4, y + 4, SW, slotH, r)
    end

    -- Slot base: dark green fill + inset shadow for depth
    love.graphics.setColor(SLOT_BG_A[1], SLOT_BG_A[2], SLOT_BG_A[3], 1)
    love.graphics.rectangle("fill", x, y, SW, slotH, r)
    -- Subtle lighter bottom half (gradient approximation)
    love.graphics.setColor(SLOT_BG_B[1], SLOT_BG_B[2], SLOT_BG_B[3], 0.70)
    love.graphics.rectangle("fill", x, y + slotH * 0.5, SW, slotH * 0.5, r)
    -- Inset shadow at top (pressed-in look)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x + 2, y + 2, SW - 4, slotH - 4, r - 1)
    love.graphics.setLineWidth(1)

    if selectedAtk then
        -- Gold pulsing glow (multi-ring)
        local pulse = 0.5 + 0.5 * math.sin(t * (2 * math.pi / 1.6))
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.08 + 0.07 * pulse)
        love.graphics.rectangle("fill", x, y, SW, slotH, r)
        for ring = 3, 1, -1 do
            local ra = (0.15 + 0.20 * pulse) * ring / 3
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], ra)
            love.graphics.setLineWidth(ring * 2.5)
            love.graphics.rectangle("line", x - ring * 3, y - ring * 3, SW + ring * 6, slotH + ring * 6, r + ring * 3)
        end
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.90 + 0.10 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, SW, slotH, r)
        love.graphics.setLineWidth(1)

    elseif attackTarget then
        -- Red pulsing glow
        local pulse = 0.5 + 0.5 * math.sin(t * (2 * math.pi / 1.3))
        love.graphics.setColor(RED[1], RED[2], RED[3], 0.08 + 0.07 * pulse)
        love.graphics.rectangle("fill", x, y, SW, slotH, r)
        for ring = 3, 1, -1 do
            local ra = (0.15 + 0.25 * pulse) * ring / 3
            love.graphics.setColor(RED[1], RED[2], RED[3], ra)
            love.graphics.setLineWidth(ring * 2.5)
            love.graphics.rectangle("line", x - ring * 3, y - ring * 3, SW + ring * 6, slotH + ring * 6, r + ring * 3)
        end
        love.graphics.setColor(RED[1], RED[2], RED[3], 0.90 + 0.10 * pulse)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, SW, slotH, r)
        love.graphics.setLineWidth(1)

    elseif highlight then
        -- Soft gold highlight (no pulse)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.10)
        love.graphics.rectangle("fill", x, y, SW, slotH, r)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.70)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, SW, slotH, r)
        love.graphics.setLineWidth(1)

    else
        -- Normal: green border + dashed inner
        love.graphics.setColor(SLOT_BORDER[1], SLOT_BORDER[2], SLOT_BORDER[3], SLOT_BORDER[4])
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, SW, slotH, r)
        love.graphics.setLineWidth(1)
        -- Dashed inner border at inset 4px
        dashedRect(x + 4, y + 4, SW - 8, slotH - 8,
            { SLOT_DASH[1], SLOT_DASH[2], SLOT_DASH[3] }, SLOT_DASH[4], 6, 4)
    end

    if pitchedCard then
        local faceDown = (owner == "opponent" and pitchedCard.mode == "defense")
        local pad  = Theme.slot.pad
        local cardW = math.min(Theme.pitchCard.w, SW - 2 * pad)
        local cardH = math.min(Theme.pitchCard.h, slotH - 2 * pad)
        local canFlip = owner == "player"
            and interactionState and interactionState.phase == "summon"
            and pitchedCard.mode == "defense"
            and not pitchedCard.summonedThisTurn
            and not pitchedCard.modeChanged
        Card.drawPitched(pitchedCard, x + pad, y + pad, { faceDown = faceDown, w = cardW, h = cardH, pitch = pitch, canFlip = canFlip })
    else
        -- Empty slot label
        Fonts.with(9, function()
            love.graphics.setColor(SLOT_LABEL[1], SLOT_LABEL[2], SLOT_LABEL[3], SLOT_LABEL[4])
            love.graphics.printf(slotType:sub(1, 3):upper(), x, y + slotH / 2 - 6, SW, "center")
        end)
    end

    table.insert(hitboxes, {
        x = x, y = y, w = SW, h = slotH,
        slotType = slotType, slotIndex = slotIndex, owner = owner,
    })
end

-- ── Trap slot ─────────────────────────────────────────────────────────────────

function Pitch._trapSlot(trapCard, x, y, slotIndex, owner, interactionState, hitboxes, slotH)
    slotH = slotH or SH

    local highlight = false
    if interactionState and interactionState.highlightedSlots then
        for _, s in ipairs(interactionState.highlightedSlots) do
            if s.slotType == "trap" and s.slotIndex == slotIndex and s.owner == owner then
                highlight = true; break
            end
        end
    end

    local t = love.timer.getTime()

    -- Shadow
    if trapCard then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", x + 4, y + 4, SW, slotH, SR)
    end

    -- Base fill (dark purple)
    love.graphics.setColor(0.08, 0.03, 0.16, 1)
    love.graphics.rectangle("fill", x, y, SW, slotH, SR)
    love.graphics.setColor(0.12, 0.05, 0.22, 0.70)
    love.graphics.rectangle("fill", x, y + slotH * 0.5, SW, slotH * 0.5, SR)
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x + 2, y + 2, SW - 4, slotH - 4, SR - 1)
    love.graphics.setLineWidth(1)

    if highlight then
        local pulse = 0.5 + 0.5 * math.sin(t * (2 * math.pi / 1.6))
        love.graphics.setColor(TRAP_COL[1], TRAP_COL[2], TRAP_COL[3], 0.12 + 0.08 * pulse)
        love.graphics.rectangle("fill", x, y, SW, slotH, SR)
        for ring = 3, 1, -1 do
            love.graphics.setColor(TRAP_COL[1], TRAP_COL[2], TRAP_COL[3], (0.15 + 0.20 * pulse) * ring / 3)
            love.graphics.setLineWidth(ring * 2.5)
            love.graphics.rectangle("line", x - ring*3, y - ring*3, SW + ring*6, slotH + ring*6, SR + ring*3)
        end
        love.graphics.setColor(TRAP_COL[1], TRAP_COL[2], TRAP_COL[3], 0.90)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, SW, slotH, SR)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(TRAP_BORDER[1], TRAP_BORDER[2], TRAP_BORDER[3], TRAP_BORDER[4])
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, y, SW, slotH, SR)
        love.graphics.setLineWidth(1)
        dashedRect(x + 4, y + 4, SW - 8, slotH - 8, { TRAP_COL[1], TRAP_COL[2], TRAP_COL[3] }, 0.25, 6, 4)
    end

    if trapCard then
        -- Owner sees their own trap face-up; opponent's traps are face-down mystery
        local faceDown = (owner == "opponent")
        local pad = Theme.slot.pad
        local cardW = math.min(Theme.pitchCard.w, SW - 2 * pad)
        local cardH = math.min(Theme.pitchCard.h, slotH - 2 * pad)
        Card.drawPitched(trapCard, x + pad, y + pad,
            { faceDown = faceDown, w = cardW, h = cardH, forceTrapBack = faceDown })
    else
        Fonts.with(8, function()
            love.graphics.setColor(TRAP_COL[1], TRAP_COL[2], TRAP_COL[3], 0.55)
            love.graphics.printf("TRAP", x, y + slotH / 2 - 5, SW, "center")
        end)
    end

    -- Only player's own trap zone is clickable for placement
    if owner == "player" then
        table.insert(hitboxes, {
            x = x, y = y, w = SW, h = slotH,
            slotType = "trap", slotIndex = slotIndex, owner = owner,
        })
    end
end

return Pitch
