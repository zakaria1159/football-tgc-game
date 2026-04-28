-- Shown when the opponent attacks a player's empty slot.
-- coverWindow = { attackerSnap, attackerSlot, emptySlot, eligibleCoverers }
local Theme = require("ui.theme")
local Fonts = require("ui.fonts")

local CoverPrompt = {}

function CoverPrompt.draw(coverWindow)
    if not coverWindow then return end

    local W   = love.graphics.getWidth()
    local H   = love.graphics.getHeight()

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panW = 460
    local panH = 200 + #coverWindow.eligibleCoverers * 56
    local panX = (W - panW) / 2
    local panY = H / 2 - panH / 2

    love.graphics.setColor(0.10, 0.04, 0.10, 1)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 10)
    love.graphics.setColor(0.75, 0.84, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    -- Title
    Fonts.with(22, function()
        love.graphics.setColor(1.00, 0.84, 0.00, 1)
        love.graphics.printf("COVER?", panX, panY + 10, panW, "center")
    end)

    -- Attack info
    local atkSnap = coverWindow.attackerSnap
    local atkStr  = atkSnap and (atkSnap.name .. "  ATK " .. atkSnap.atk) or "Unknown attacker"
    local slotStr = coverWindow.emptySlot.type:upper() .. " slot " .. (coverWindow.emptySlot.index or "")
    Fonts.with(9, function()
        love.graphics.setColor(0.75, 0.75, 0.80, 1)
        love.graphics.printf(atkStr .. "  →  empty " .. slotStr, panX + 10, panY + 44, panW - 20, "center")
    end)

    love.graphics.setColor(0.45, 0.35, 0.10, 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.line(panX + 16, panY + 62, panX + panW - 16, panY + 62)

    -- Eligible coverers
    local y = panY + 72
    for _, cov in ipairs(coverWindow.eligibleCoverers) do
        local def = cov.card.definition
        local stats = def.stats or {}
        local modeStat  = stats.atk or 0
        local modeLabel = "ATK "

        local col = Theme.cardColors[def.type] or { 0.3, 0.3, 0.3, 1 }
        love.graphics.setColor(col[1] * 0.50, col[2] * 0.50, col[3] * 0.50, 1)
        love.graphics.rectangle("fill", panX + 12, y, panW - 24, 48, 6)
        love.graphics.setColor(col)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", panX + 12, y, panW - 24, 48, 6)
        love.graphics.setLineWidth(1)

        Fonts.with(11, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(def.name, panX + 20, y + 8)
        end)
        Fonts.with(9, function()
            love.graphics.setColor(0.65, 0.65, 0.70, 1)
            love.graphics.print(modeLabel .. modeStat .. "  ·  cannot act next turn", panX + 20, y + 26)
        end)

        -- COVER button
        love.graphics.setColor(0.45, 0.40, 0.05, 1)
        love.graphics.rectangle("fill", panX + panW - 100, y + 10, 80, 28, 5)
        love.graphics.setColor(1.00, 0.84, 0.00, 0.80)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", panX + panW - 100, y + 10, 80, 28, 5)
        Fonts.with(9, function()
            love.graphics.setColor(1, 0.95, 0.6, 1)
            love.graphics.printf("COVER", panX + panW - 100, y + 16, 80, "center")
        end)

        y = y + 56
    end

    -- Let Through button
    love.graphics.setColor(0.15, 0.15, 0.20, 1)
    love.graphics.rectangle("fill", panX + panW/2 - 80, y + 10, 160, 34, 6)
    love.graphics.setColor(0.45, 0.45, 0.55, 0.80)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", panX + panW/2 - 80, y + 10, 160, 34, 6)
    love.graphics.setLineWidth(1)
    Fonts.with(11, function()
        love.graphics.setColor(0.70, 0.70, 0.78, 1)
        love.graphics.printf("LET THROUGH", panX, y + 18, panW, "center")
    end)
end

function CoverPrompt.getHitboxes(coverWindow)
    if not coverWindow then return {} end

    local W   = love.graphics.getWidth()
    local H   = love.graphics.getHeight()
    local panW = 460
    local panH = 200 + #coverWindow.eligibleCoverers * 56
    local panX = (W - panW) / 2
    local panY = H / 2 - panH / 2

    local boxes = {}
    local y = panY + 70
    for _, cov in ipairs(coverWindow.eligibleCoverers) do
        table.insert(boxes, {
            type      = "cover",
            coverer   = { type = cov.type, index = cov.index },
            x = panX + panW - 100, y = y + 10, w = 80, h = 28,
        })
        y = y + 56
    end
    table.insert(boxes, {
        type = "letthrough",
        x = panX + panW/2 - 80, y = y + 10, w = 160, h = 34,
    })
    return boxes
end

return CoverPrompt
