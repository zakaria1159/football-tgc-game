-- Shown when a Cat-A trap window opens (AI attacks, player has face-down traps).
-- trapWindow = { attackerSnap, defenderSnap, traps = [{ slotIndex, definition }] }

local Theme = require("ui.theme")
local Fonts = require("ui.fonts")

local TrapPrompt = {}

function TrapPrompt.draw(trapWindow)
    if not trapWindow then return end

    local W   = love.graphics.getWidth()
    local H   = love.graphics.getHeight()

    -- Dark backdrop
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Panel
    local panW = 480
    local panH = 260 + #trapWindow.traps * 52
    local panX = (W - panW) / 2
    local panY = H / 2 - panH / 2

    love.graphics.setColor(0.10, 0.04, 0.10, 1)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 10)
    love.graphics.setColor(0.75, 0.25, 0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    -- Title
    Fonts.with(22, function()
        love.graphics.setColor(0.90, 0.35, 0.65, 1)
        love.graphics.printf("TRAP WINDOW", panX, panY + 10, panW, "center")
    end)

    -- Attack summary
    local atkSnap = trapWindow.attackerSnap
    local defSnap = trapWindow.defenderSnap
    local atkStr = atkSnap and (atkSnap.name .. "  ATK " .. atkSnap.atk) or "Unknown"
    local defStr = defSnap and (defSnap.name .. "  DEF " .. defSnap.def) or "Empty slot"
    Fonts.with(9, function()
        love.graphics.setColor(0.80, 0.80, 0.85, 1)
        love.graphics.printf(atkStr .. "  →  " .. defStr, panX + 10, panY + 44, panW - 20, "center")
    end)

    love.graphics.setColor(0.35, 0.35, 0.50, 1)
    love.graphics.line(panX + 16, panY + 60, panX + panW - 16, panY + 60)

    -- Trap options
    local y = panY + 70
    for i, trapEntry in ipairs(trapWindow.traps) do
        local def = trapEntry.definition
        -- Trap card box
        love.graphics.setColor(0.55, 0.20, 0.40, 1)
        love.graphics.rectangle("fill", panX + 12, y, panW - 24, 44, 6)
        love.graphics.setColor(0.80, 0.30, 0.60, 1)
        love.graphics.rectangle("line", panX + 12, y, panW - 24, 44, 6)

        Fonts.with(11, function()
            love.graphics.setColor(0.95, 0.75, 0.85, 1)
            love.graphics.print(def.name, panX + 20, y + 6)
        end)
        Fonts.with(9, function()
            love.graphics.setColor(0.70, 0.55, 0.65, 1)
            love.graphics.printf(def.abilityText or "", panX + 20, y + 22, panW - 100, "left")
        end)

        -- Activate button
        love.graphics.setColor(0.75, 0.20, 0.45, 1)
        love.graphics.rectangle("fill", panX + panW - 100, y + 8, 80, 28, 5)
        love.graphics.setColor(1, 1, 1, 1)
        Fonts.with(9, function()
            love.graphics.printf("ACTIVATE", panX + panW - 100, y + 14, 80, "center")
        end)

        y = y + 52
    end

    -- Pass button
    love.graphics.setColor(0.22, 0.22, 0.32, 1)
    love.graphics.rectangle("fill", panX + panW/2 - 70, y + 10, 140, 34, 6)
    love.graphics.setColor(0.65, 0.65, 0.72, 1)
    love.graphics.rectangle("line", panX + panW/2 - 70, y + 10, 140, 34, 6)
    Fonts.with(11, function()
        love.graphics.setColor(0.75, 0.75, 0.80, 1)
        love.graphics.printf("PASS (don't activate)", panX, y + 18, panW, "center")
    end)
end

-- Returns hitboxes for click detection.
function TrapPrompt.getHitboxes(trapWindow)
    if not trapWindow then return {} end

    local W   = love.graphics.getWidth()
    local H   = love.graphics.getHeight()
    local panW = 480
    local panH = 260 + #trapWindow.traps * 52
    local panX = (W - panW) / 2
    local panY = H / 2 - panH / 2

    local boxes = {}
    local y = panY + 70
    for i, trapEntry in ipairs(trapWindow.traps) do
        table.insert(boxes, {
            type      = "activate",
            slotIndex = trapEntry.slotIndex,
            x = panX + panW - 100, y = y + 8, w = 80, h = 28,
        })
        y = y + 52
    end
    -- Pass button
    table.insert(boxes, {
        type = "pass",
        x = panX + panW/2 - 70, y = y + 10, w = 140, h = 34,
    })
    return boxes
end

return TrapPrompt
