local Fonts = require("ui.fonts")

local PauseMenu = {}

local BUTTONS = {
    { label = "RESUME",       action = "resume"  },
    { label = "CARD LIBRARY", action = "library" },
    { label = "QUIT TO MENU", action = "home"    },
}

local BTN_W   = 300
local BTN_H   = 52
local BTN_GAP = 14

local function panelRect()
    local W    = love.graphics.getWidth()
    local H    = love.graphics.getHeight()
    local panW = 380
    local panH = 76 + #BUTTONS * (BTN_H + BTN_GAP) + BTN_GAP
    return (W - panW) / 2, (H - panH) / 2, panW, panH
end

function PauseMenu.draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Semi-transparent backdrop
    love.graphics.setColor(0, 0, 0, 0.68)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panX, panY, panW, panH = panelRect()

    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.60)
    love.graphics.rectangle("fill", panX+6, panY+6, panW, panH, 10)

    -- Panel body
    love.graphics.setColor(0.06, 0.04, 0.12, 0.98)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 10)

    -- Panel border
    love.graphics.setColor(0.42, 0.30, 0.65, 0.75)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    -- Inner accent border
    love.graphics.setColor(0.28, 0.18, 0.45, 0.40)
    love.graphics.rectangle("line", panX+4, panY+4, panW-8, panH-8, 8)

    -- Title
    Fonts.with(22, function()
        love.graphics.setColor(0.18, 0.12, 0.32, 1)
        love.graphics.printf("PAUSED", panX+2, panY+20, panW, "center")
        love.graphics.setColor(0.82, 0.72, 1.00, 1)
        love.graphics.printf("PAUSED", panX, panY+18, panW, "center")
    end)

    -- Divider
    love.graphics.setColor(0.35, 0.24, 0.55, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.line(panX+24, panY+56, panX+panW-24, panY+56)

    -- Buttons
    local mx, my = love.mouse.getPosition()
    for i, btn in ipairs(BUTTONS) do
        local bx = panX + (panW - BTN_W) / 2
        local by = panY + 66 + (i-1) * (BTN_H + BTN_GAP)
        local hov = mx >= bx and mx <= bx+BTN_W and my >= by and my <= by+BTN_H

        -- Button glow when hovered
        if hov then
            love.graphics.setColor(0.45, 0.28, 0.75, 0.22)
            love.graphics.rectangle("fill", bx-3, by-3, BTN_W+6, BTN_H+6, 9)
        end

        -- Button body
        local bg = hov and { 0.22, 0.14, 0.40, 1 } or { 0.10, 0.07, 0.18, 1 }
        love.graphics.setColor(bg)
        love.graphics.rectangle("fill", bx, by, BTN_W, BTN_H, 6)

        -- Button border
        love.graphics.setColor(0.50, 0.35, 0.80, hov and 0.90 or 0.40)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", bx, by, BTN_W, BTN_H, 6)
        love.graphics.setLineWidth(1)

        -- Button text
        Fonts.with(16, function()
            if hov then
                love.graphics.setColor(0.30, 0.20, 0.50, 1)
                love.graphics.printf(btn.label, bx+2, by + BTN_H/2 - 10, BTN_W, "center")
            end
            love.graphics.setColor(hov and 1.0 or 0.75,
                                   hov and 0.95 or 0.68,
                                   hov and 1.0 or 0.90, 1)
            love.graphics.printf(btn.label, bx, by + BTN_H/2 - 10, BTN_W, "center")
        end)
    end
end

function PauseMenu.keypressed(key)
    if key == "escape" then return "resume" end
    return nil
end

function PauseMenu.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    local panX, panY, panW = panelRect()
    for i, btn in ipairs(BUTTONS) do
        local bx = panX + (panW - BTN_W) / 2
        local by = panY + 66 + (i-1) * (BTN_H + BTN_GAP)
        if x >= bx and x <= bx+BTN_W and y >= by and y <= by+BTN_H then
            return btn.action
        end
    end
    return nil
end

return PauseMenu
