-- Full match log (log button / L) and AI-hand debug (TAB) as white sticker panels.
local Theme  = require("ui.theme")
local Fonts  = require("ui.fonts")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local DebugLog = {}

local ORDER = { "player", "ability", "name", "cardName", "slot", "slotType", "slotIndex", "outcome",
                "damage", "half", "winner", "turn", "reason", "unimplemented" }

local function fmtValue(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, vv in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(vv) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function fmtPayload(p)
    if not p then return "" end
    local parts, seen = {}, {}
    for _, k in ipairs(ORDER) do
        if p[k] ~= nil then
            parts[#parts + 1] = k .. "=" .. fmtValue(p[k])
            seen[k] = true
        end
    end
    for k, v in pairs(p) do
        if not seen[k] then
            parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{...}" or tostring(v))
        end
    end
    return table.concat(parts, "  ")
end

-- Dark enough to read on white.
local function lineColor(t)
    if t == "card_played" or t == "card_drawn"    then return { 0.10, 0.55, 0.20 } end
    if t == "strategy_played"                     then return { 0.05, 0.50, 0.60 } end
    if t == "trap_activated"                      then return { 0.48, 0.17, 0.75 } end
    if t == "attack_declared" or t == "cover"     then return { 0.75, 0.45, 0.00 } end
    if t == "lp_damage"                           then return { 0.85, 0.10, 0.20 } end
    if t == "defender_destroy"                    then return { 0.85, 0.35, 0.05 } end
    if t == "shot"                                then return { 0.10, 0.40, 0.85 } end
    if t == "turn_end"                            then return { 0.45, 0.45, 0.55 } end
    if t == "half_end"                            then return { 0.70, 0.55, 0.00 } end
    if t == "attack_wasted"                       then return { 0.50, 0.50, 0.50 } end
    return { Theme.inkText[1], Theme.inkText[2], Theme.inkText[3] }
end

-- scroll = lines scrolled up from the newest. Returns the clamped scroll.
function DebugLog.draw(match, scroll)
    local W, H = Layout.W, Layout.H
    local panW, panH = 680, H - 140
    local panX, panY = (W - panW) / 2, 100

    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Draw.sticker(panX, panY, panW, panH, { r = 18, fill = Theme.white, border = 0, shadow = 6 })
    Draw.ribbon(panX + panW / 2, panY - 24, 300, 46, "MATCH LOG", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text })
    Draw.text(#match.log .. " events  ·  mouse wheel to scroll  ·  L or the log button to close",
        panX, panY + 34, panW, "center", { size = 12, body = true, color = Theme.inkText })

    local lineH, padX = 17, 18
    local innerY, innerH = panY + 58, panH - 70
    local maxLines  = math.floor(innerH / lineH)
    local total     = #match.log
    local maxScroll = math.max(0, total - maxLines)
    scroll = math.max(0, math.min(scroll or 0, maxScroll))
    local startIdx = math.max(1, total - maxLines - scroll + 1)
    local endIdx   = total - scroll

    local prev = love.graphics.getFont()
    love.graphics.setFont(Fonts.body(11))
    love.graphics.setScissor(panX + padX, innerY, panW - padX * 2, innerH)
    local y = innerY
    for i = startIdx, endIdx do
        local e = match.log[i]
        local col = lineColor(e.type)
        local prefix = string.format("[H%s T%02d %s] %s", tostring(e.half), e.turn or 0,
            string.upper(tostring(e.phase or ""):sub(1, 3)), tostring(e.type))
        love.graphics.setColor(col[1], col[2], col[3], 0.75)
        love.graphics.print(prefix, panX + padX, y)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.print(fmtPayload(e.payload), panX + padX + 250, y)
        y = y + lineH
    end
    love.graphics.setScissor()
    love.graphics.setFont(prev)

    if maxScroll > 0 then
        local trackH = innerH - 4
        local thumbH = math.max(20, trackH * maxLines / total)
        local thumbY = innerY + 2 + ((maxScroll - scroll) / maxScroll) * (trackH - thumbH)
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.15)
        love.graphics.rectangle("fill", panX + panW - 12, innerY, 6, trackH, 3, 3)
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.6)
        love.graphics.rectangle("fill", panX + panW - 12, thumbY, 6, thumbH, 3, 3)
    end
    return scroll
end

function DebugLog.drawAIHand(match)
    local o = match.players.opponent
    local panW = 360
    local panH = math.min(Layout.H - 120, 48 + #o.hand * 22 + 12)
    local panX, panY = (Layout.W - panW) / 2, 100
    Draw.sticker(panX, panY, panW, panH, { r = 16, fill = Theme.white, border = 0, shadow = 6 })
    Draw.text("AI HAND (" .. #o.hand .. " cards)", panX, panY + 12, panW, "center",
        { size = 18, color = Theme.inkText })
    local y = panY + 44
    for _, card in ipairs(o.hand) do
        if y > panY + panH - 22 then
            Draw.text("...", panX + 14, y, panW - 28, "left", { size = 13, body = true, color = Theme.inkText })
            break
        end
        local g = Theme.typeGrad[card.type]
        local stat = card.stats and ("  A" .. (card.stats.atk or 0) .. "/D" .. (card.stats.def or 0)) or ""
        Draw.text("[" .. string.upper(card.type:sub(1, 3)) .. "] " .. card.name .. stat,
            panX + 14, y, panW - 28, "left",
            { size = 13, body = true, color = g and g[2] or Theme.inkText, fit = true, minSize = 9 })
        y = y + 22
    end
end

return DebugLog
