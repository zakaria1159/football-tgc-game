-- Cinematic overlay shown whenever a trap card is activated.
-- data: { activator, trapDef, contextText }
-- anim: { slideY, stampAlpha, glowAlpha, textAlpha }

local Fonts = require("ui.fonts")

local TrapActivationOverlay = {}

local PURPLE      = { 0.700, 0.280, 1.000, 1 }
local PURPLE_DIM  = { 0.480, 0.180, 0.720, 1 }
local PURPLE_GLOW = { 0.580, 0.160, 0.940, 1 }
local PURPLE_DARK = { 0.100, 0.020, 0.200, 1 }
local PAGE        = { 0.018, 0.006, 0.038, 1 }
local GOLD        = { 1.000, 0.843, 0.000, 1 }
local CREAM       = { 0.953, 0.914, 0.824, 1 }

local ABILITY_EFFECT = {
    OFFSIDE            = "Striker attack cancelled — caught offside!",
    RED_CARD           = "Winning attacker sent off!",
    VAR                = "VAR Review in progress",
    LAST_DEFENDER_FOUL = "Last defender fouled — direct free shot awarded!",
    MANAGERS_CHALLENGE = "Opposing trap negated — challenge upheld!",
}

local function vgrad(x, y, w, h, cT, cB)
    local m = love.graphics.newMesh({
        { x,   y,   0, 0, cT[1], cT[2], cT[3], cT[4] or 1 },
        { x+w, y,   1, 0, cT[1], cT[2], cT[3], cT[4] or 1 },
        { x+w, y+h, 1, 1, cB[1], cB[2], cB[3], cB[4] or 1 },
        { x,   y+h, 0, 1, cB[1], cB[2], cB[3], cB[4] or 1 },
    }, "fan")
    love.graphics.draw(m)
end

function TrapActivationOverlay.draw(data, anim)
    if not data then return end
    anim = anim or {}

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    local slideY     = anim.slideY     or 0
    local stampAlpha = anim.stampAlpha or 0
    local glowAlpha  = anim.glowAlpha  or 0
    local textAlpha  = anim.textAlpha  or 0

    -- 1. Backdrop
    love.graphics.setColor(PAGE)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.220, 0.040, 0.440, 0.38)
    love.graphics.circle("fill", W * 0.50, H * 0.38, W * 0.62)
    love.graphics.setColor(0.140, 0.016, 0.300, 0.28)
    love.graphics.circle("fill", W * 0.50, H * 0.38, W * 0.30)

    -- Light rays
    if glowAlpha > 0.02 then
        local rCX, rCY = W / 2, H * 0.28
        love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.040 * glowAlpha)
        love.graphics.setLineWidth(1)
        for i = 0, 11 do
            local ang = i * math.pi / 6
            local len = math.max(W, H) * 1.2
            love.graphics.line(rCX, rCY, rCX + math.cos(ang) * len, rCY + math.sin(ang) * len)
        end
        love.graphics.setLineWidth(1)
    end

    -- Edge glow
    if glowAlpha > 0.02 then
        love.graphics.setColor(PURPLE_GLOW[1], PURPLE_GLOW[2], PURPLE_GLOW[3], 0.20 * glowAlpha)
        love.graphics.setLineWidth(14)
        love.graphics.rectangle("line", 4, 4, W - 8, H - 8)
        love.graphics.setColor(PURPLE_GLOW[1], PURPLE_GLOW[2], PURPLE_GLOW[3], 0.55 * glowAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", 4, 4, W - 8, H - 8)
        love.graphics.setLineWidth(1)
    end

    -- Scanlines
    love.graphics.setColor(1, 1, 1, 0.017)
    for sy = 0, H, 3 do
        love.graphics.line(0, sy, W, sy)
    end

    -- Gold corner brackets
    love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.75)
    love.graphics.setLineWidth(2)
    local br = 22
    love.graphics.line(10, 10 + br, 10, 10, 10 + br, 10)
    love.graphics.line(W - 10 - br, 10, W - 10, 10, W - 10, 10 + br)
    love.graphics.line(10, H - 10 - br, 10, H - 10, 10 + br, H - 10)
    love.graphics.line(W - 10 - br, H - 10, W - 10, H - 10, W - 10, H - 10 - br)
    love.graphics.setLineWidth(1)

    -- 2. Top meta strip
    Fonts.with(9, function()
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.75)
        love.graphics.circle("fill", W / 2 - 100, 20, 3)
        love.graphics.circle("fill", W / 2 + 100, 20, 3)
        love.graphics.setColor(PURPLE_DIM)
        love.graphics.printf("TURN  ·  PHASE  ·  TRAP", 0, 13, W, "center")
    end)

    -- 3. Header
    local isPlayer   = (data.activator == "player")
    local headerLine = isPlayer and "TRAP  ACTIVATED" or "OPPONENT  TRAP"
    local subLine    = isPlayer and "YOU ACTIVATED A TRAP CARD" or "OPPONENT ACTIVATED A TRAP CARD"

    Fonts.with(33, function()
        love.graphics.setColor(PURPLE_DARK)
        love.graphics.printf(headerLine, 2, 38, W, "center")
        love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.32)
        love.graphics.printf(headerLine, 0, 34, W, "center")
        love.graphics.setColor(PURPLE)
        love.graphics.printf(headerLine, 0, 34, W, "center")
    end)

    local ulW = 280
    local ulX = W / 2 - ulW / 2
    local ulY = 80
    for i = 0, ulW do
        local t = i / ulW
        local a = math.sin(t * math.pi) * 0.52
        love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], a)
        love.graphics.line(ulX + i, ulY, ulX + i, ulY + 2)
    end

    Fonts.with(9, function()
        love.graphics.setColor(PURPLE_DIM)
        love.graphics.printf(subLine, 0, 88, W, "center")
    end)

    -- 4. Trap card panel (slides up)
    local panW = 420
    local panH = 240
    local panX = W / 2 - panW / 2
    local panY = 110 + slideY

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", panX + 7, panY + 7, panW, panH, 12)

    love.graphics.setColor(PURPLE_GLOW[1], PURPLE_GLOW[2], PURPLE_GLOW[3], 0.40)
    love.graphics.setLineWidth(6)
    love.graphics.rectangle("line", panX - 4, panY - 4, panW + 8, panH + 8, 14)
    love.graphics.setLineWidth(1)

    vgrad(panX, panY, panW, panH,
        { 0.130, 0.028, 0.250, 1 },
        { 0.036, 0.008, 0.080, 1 })

    love.graphics.setColor(PURPLE_GLOW[1], PURPLE_GLOW[2], PURPLE_GLOW[3], 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    -- Scanlines over panel
    love.graphics.setScissor(math.floor(panX), math.floor(panY), math.ceil(panW), math.ceil(panH))
    love.graphics.setColor(1, 1, 1, 0.020)
    for sy = panY, panY + panH, 3 do
        love.graphics.line(panX, sy, panX + panW, sy)
    end
    love.graphics.setScissor()

    -- Header strip
    love.graphics.setScissor(math.floor(panX), math.floor(panY), math.ceil(panW), 32)
    vgrad(panX, panY, panW, 32,
        { 0.260, 0.060, 0.500, 1 },
        { 0.150, 0.030, 0.310, 1 })
    love.graphics.setScissor()

    love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.line(panX, panY + 32, panX + panW, panY + 32)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], 1)
    love.graphics.circle("fill", panX + 16, panY + 16, 4)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.circle("fill", panX + 16, panY + 16, 2)

    Fonts.with(9, function()
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print("TRAP  ·  REACTIVE", panX + 26, panY + 9)
    end)

    -- Trap name
    local trapName = data.trapDef and data.trapDef.name or "TRAP"
    Fonts.with(22, function()
        love.graphics.setColor(0.100, 0.020, 0.200, 1)
        love.graphics.printf(trapName, panX, panY + 44, panW, "center")
        love.graphics.setColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.38)
        love.graphics.printf(trapName, panX, panY + 42, panW, "center")
        love.graphics.setColor(CREAM)
        love.graphics.printf(trapName, panX, panY + 42, panW, "center")
    end)

    -- Effect text
    local ability    = data.trapDef and data.trapDef.ability or ""
    local effectText = ABILITY_EFFECT[ability]
                    or (data.trapDef and data.trapDef.abilityText)
                    or ""
    Fonts.with(9, function()
        love.graphics.setColor(0.780, 0.650, 0.900, 1)
        love.graphics.printf(effectText, panX + 20, panY + 80, panW - 40, "center")
    end)

    -- Divider
    love.graphics.setColor(PURPLE_GLOW[1], PURPLE_GLOW[2], PURPLE_GLOW[3], 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(panX + 24, panY + 136, panX + panW - 24, panY + 136)
    love.graphics.setLineWidth(1)

    -- Context
    local ctxText = data.contextText or ""
    Fonts.with(9, function()
        love.graphics.setColor(0.640, 0.610, 0.680, 1)
        love.graphics.printf(ctxText, panX + 10, panY + 148, panW - 20, "center")
    end)

    -- Rarity badge
    local rarity = data.trapDef and data.trapDef.rarity or ""
    if rarity ~= "" then
        Fonts.with(8, function()
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.65)
            love.graphics.printf(rarity:upper(), panX, panY + panH - 20, panW - 12, "right")
        end)
    end

    -- 5. "ACTIVATED" stamp
    if stampAlpha > 0.02 then
        local stampCX = W / 2
        local stampCY = panY + panH * 0.50
        love.graphics.push()
        love.graphics.translate(stampCX, stampCY)
        love.graphics.rotate(-0.14)
        local sw, sh = panW - 28, 50
        love.graphics.setColor(0, 0, 0, 0.72 * stampAlpha)
        love.graphics.rectangle("fill", -sw / 2 + 4, -sh / 2 + 4, sw, sh, 5)
        love.graphics.setColor(0.340, 0.035, 0.640, 0.94 * stampAlpha)
        love.graphics.rectangle("fill", -sw / 2, -sh / 2, sw, sh, 5)
        love.graphics.setColor(0.780, 0.260, 1.000, stampAlpha)
        love.graphics.setLineWidth(2.5)
        love.graphics.rectangle("line", -sw / 2, -sh / 2, sw, sh, 5)
        love.graphics.setColor(0.550, 0.130, 0.900, 0.65 * stampAlpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -sw / 2 + 5, -sh / 2 + 5, sw - 10, sh - 10, 3)
        love.graphics.setLineWidth(1)
        Fonts.with(18, function()
            love.graphics.setColor(0.200, 0.000, 0.400, 0.82 * stampAlpha)
            love.graphics.printf("ACTIVATED", -sw / 2 + 1, -sh / 2 + 16, sw, "center")
            love.graphics.setColor(1.000, 0.880, 1.000, stampAlpha)
            love.graphics.printf("ACTIVATED", -sw / 2, -sh / 2 + 15, sw, "center")
        end)
        love.graphics.pop()
    end

    -- 6. Dismiss hint
    if textAlpha > 0.02 then
        Fonts.with(9, function()
            love.graphics.setColor(0.340, 0.250, 0.450, textAlpha)
            love.graphics.printf("CLICK  OR  SPACE  TO  CONTINUE", 0, panY + panH + 28, W, "center")
        end)
    end

    love.graphics.setFont(Fonts.get(16))
end

return TrapActivationOverlay
