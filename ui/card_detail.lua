local Theme  = require("ui.theme")
local Card   = require("ui.card")
local Fonts  = require("ui.fonts")
local Combat = require("engine.combat")

local CardDetail = {}

function CardDetail.draw(cardDef, pitchedCard, pitch)
    local L  = Theme.layout
    local px = L.leftPanelX
    local pw = L.leftPanelW
    local H  = love.graphics.getHeight()

    -- Panel background (layered depth)
    love.graphics.setColor(0.028, 0.005, 0.005, 1)
    love.graphics.rectangle("fill", px, 0, pw, H)
    love.graphics.setColor(0.042, 0.008, 0.008, 1)
    love.graphics.rectangle("fill", px, 0, pw - 2, H)

    -- Right border (glowing)
    love.graphics.setColor(Theme.hud.border[1], Theme.hud.border[2], Theme.hud.border[3], 0.35)
    love.graphics.setLineWidth(4)
    love.graphics.line(px + pw, 0, px + pw, H)
    love.graphics.setColor(Theme.hud.border)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px + pw - 1, 0, px + pw - 1, H)
    love.graphics.setLineWidth(1)

    -- Panel title
    Fonts.with(9, function()
        love.graphics.setColor(Theme.hud.border)
        love.graphics.printf("CARD DETAIL", px, 12, pw, "center")
    end)
    love.graphics.setColor(0.25, 0.08, 0.08, 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + 10, 30, px + pw - 10, 30)

    if not cardDef then
        Fonts.with(11, function()
            love.graphics.setColor(0.25, 0.18, 0.18, 1)
            love.graphics.printf("CLICK ANY\nCARD", px, H / 2 - 20, pw, "center")
        end)
        return
    end

    -- Large card preview
    local pad   = 10
    local cardW = pw - pad * 2
    local cardH = Card.drawLarge(cardDef, px + pad, 40, cardW)

    local y = 40 + cardH + 12

    -- Type · rarity pill
    local col  = Theme.cardColors[cardDef.type] or { 0.3, 0.3, 0.3, 1 }
    local hdr  = Theme.cardHeaders[cardDef.type] or { 0.4, 0.4, 0.4, 1 }
    local pillW = pw - 20
    love.graphics.setColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6, 1)
    love.graphics.rectangle("fill", px + 10, y, pillW, 18, 3)
    love.graphics.setColor(hdr)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 10, y, pillW, 18, 3)
    Fonts.with(9, function()
        love.graphics.setColor(1, 1, 1, 0.90)
        love.graphics.printf(
            (cardDef.type or ""):upper() .. "  ·  " .. (cardDef.rarity or ""):upper(),
            px + 10, y + 3, pillW, "center")
    end)
    y = y + 26

    -- ATK / DEF stats (with midfielder card bonuses)
    local stats    = cardDef.stats or {}
    local atkVal   = stats.atk or 0
    local defVal   = stats.def or 0
    local effAtk   = atkVal
    local effDef   = defVal
    local atkBonus = 0
    local defBonus = 0
    local defLabel = "DEF"

    if pitchedCard and pitch then
        local slotT = pitchedCard.slotType
        if cardDef.type == "keeper" then
            effDef   = Combat.keeperEffectiveDef(pitchedCard, pitch)
            defLabel = "EFF DEF"
        elseif slotT == "defender" then
            defBonus = Combat.midfielderCardDefBonus(pitch)
            effDef   = defVal + defBonus
        elseif slotT == "striker" then
            atkBonus = Combat.midfielderCardAtkBonus(pitch)
            effAtk   = atkVal + atkBonus
        end
    end

    local statBoxW = math.floor((pw - 22) / 2)

    -- ATK box
    local atkHighlight = atkBonus > 0
    love.graphics.setColor(atkHighlight and 0.28 or 0.22, 0.06, 0.06, 1)
    love.graphics.rectangle("fill", px + 6, y, statBoxW, 36, 3)
    love.graphics.setColor(atkHighlight and 1.00 or 0.70, 0.25, 0.25, 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 6, y, statBoxW, 36, 3)
    Fonts.with(9, function()
        love.graphics.setColor(1.00, 0.55, 0.55, 1)
        love.graphics.printf("ATK", px + 6, y + 4, statBoxW, "center")
    end)
    Fonts.with(13, function()
        love.graphics.setColor(atkHighlight and 1.00 or 1.00, atkHighlight and 0.65 or 0.40, 0.40, 1)
        love.graphics.printf(effAtk > 0 and tostring(effAtk) or "—", px + 6, y + 17, statBoxW, "center")
    end)

    -- DEF box
    local defBoxX    = px + 6 + statBoxW + 10
    local defHighlight = defBonus > 0 or (cardDef.type == "keeper" and effDef ~= defVal)
    love.graphics.setColor(0.05, defHighlight and 0.14 or 0.10, 0.22, 1)
    love.graphics.rectangle("fill", defBoxX, y, statBoxW, 36, 3)
    love.graphics.setColor(0.25, defHighlight and 0.60 or 0.45, 0.70, 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", defBoxX, y, statBoxW, 36, 3)
    Fonts.with(9, function()
        love.graphics.setColor(0.55, 0.75, 1.00, 1)
        love.graphics.printf(defLabel, defBoxX, y + 4, statBoxW, "center")
    end)
    Fonts.with(13, function()
        love.graphics.setColor(0.40, defHighlight and 0.80 or 0.65, 1.00, 1)
        love.graphics.printf(effDef > 0 and tostring(effDef) or "—", defBoxX, y + 17, statBoxW, "center")
    end)
    y = y + 44

    -- Bonus breakdown line
    if atkBonus > 0 then
        Fonts.with(9, function()
            love.graphics.setColor(1.00, 0.65, 0.35, 1)
            love.graphics.printf("base " .. atkVal .. "  +  " .. atkBonus .. " MID",
                px + 6, y, pw - 12, "center")
        end)
        y = y + 16
    elseif defBonus > 0 then
        Fonts.with(9, function()
            love.graphics.setColor(0.40, 0.80, 1.00, 1)
            love.graphics.printf("base " .. defVal .. "  +  " .. defBonus .. " MID",
                px + 6, y, pw - 12, "center")
        end)
        y = y + 16
    elseif cardDef.type == "keeper" and effDef ~= defVal then
        Fonts.with(9, function()
            love.graphics.setColor(0.40, 0.52, 0.72, 1)
            love.graphics.printf("base " .. defVal .. " + " .. (effDef - defVal) .. " bonus",
                px + 6, y, pw - 12, "center")
        end)
        y = y + 16
    end

    -- Pitched card status
    if pitchedCard then
        love.graphics.setColor(0.22, 0.08, 0.08, 0.55)
        love.graphics.setLineWidth(1)
        love.graphics.line(px + 10, y, px + pw - 10, y)
        y = y + 8

        Fonts.with(9, function()
            if pitchedCard.exhausted then
                love.graphics.setColor(0.55, 0.55, 0.60, 1)
                love.graphics.printf("EXHAUSTED", px + 6, y, pw - 12, "center")
                y = y + 14
            end
            if pitchedCard.cannotActNextTurn then
                love.graphics.setColor(1.00, 0.60, 0.20, 1)
                love.graphics.printf("CANNOT ACT NEXT TURN", px + 6, y, pw - 12, "center")
                y = y + 14
            end
            local modeCol = pitchedCard.mode == "defense"
                and { 0.30, 0.65, 1.00, 1 } or { 1.00, 0.55, 0.20, 1 }
            love.graphics.setColor(modeCol)
            love.graphics.printf("MODE: " .. (pitchedCard.mode or "attack"):upper(),
                px + 6, y, pw - 12, "center")
        end)
    end
end

return CardDetail
