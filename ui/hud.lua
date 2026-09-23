local Theme = require("ui.theme")
local Fonts = require("ui.fonts")
local Audio = require("ui.audio")
local C     = require("engine.constants")

local HUD = {}
HUD.debugAIHand = false

local LOG_MAX = 8
local LP_MAX  = 4000

local function logColor(eventType)
    return Theme.logColors[eventType] or Theme.logColors.default
end

local function shortEvent(entry)
    local t = entry.type or ""
    local p = entry.payload or {}
    local you = (p.player == "player") and "You" or "Opp"
    local dlr = (p.dealer == "player") and "You" or "Opp"

    if t == "lp_damage" then
        local src = (p.source == "facedown_penalty") and " (bluff!)" or ""
        return dlr .. " +" .. (p.damage or 0) .. " LP dmg" .. src
    end
    if t == "half_end"         then return "═ Half " .. (p.half or "?") .. " ends ═" end
    if t == "defender_destroy" then
        local sl = p.slot and p.slot.type or "card"
        return "Destroyed: " .. sl
    end
    if t == "cover"  then
        local ct = p.coverer and p.coverer.type or "?"
        return ct:upper() .. " covers gap"
    end
    if t == "shot" then
        local oc = p.outcome or "?"
        if oc == "save" then return "SAVED (margin " .. (p.margin or 0) .. ")"
        elseif oc == "tie" then return "Keeper blocked — tie"
        else return "Shot: " .. oc end
    end
    if t == "card_played" then
        return you .. " → " .. (p.slot or "?") .. " slot"
    end
    if t == "card_drawn" then
        return you .. " drew"
    end
    if t == "attack_declared" then
        local a = p.attacker and p.attacker.type or "?"
        local d = p.defender and p.defender.type or "?"
        return a:upper() .. " → " .. d:upper()
    end
    if t == "strategy_played" then
        local ab = (p.ability or "UNKNOWN"):lower():gsub("_", " ")
        return "STRAT: " .. ab
    end
    if t == "trap_activated" then
        local nm = (p.trap or "trap"):gsub("^trap%-", ""):gsub("%-", " ")
        local who = (p.player == "player") and "You" or "Opp"
        return "TRAP: " .. nm .. " [" .. who .. "]"
    end
    if t == "attack_wasted"    then return "Attack wasted" end
    if t == "turn_end"         then return "─ Turn " .. (p.turn or "?") .. " end ─" end
    return t:gsub("_", " ")
end

-- Draws a visually-grouped section header inside a panel
local function sectionHeader(px, y, pw, label, col)
    col = col or { 0.35, 0.10, 0.10, 1 }
    local lw = pw - 16
    local lx = px + 8
    -- Decorative line
    love.graphics.setColor(col[1], col[2], col[3], 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.line(lx, y + 7, lx + lw, y + 7)
    -- Label chip
    Fonts.with(9, function()
        local tw = Fonts.get(9):getWidth(label) + 10
        local tx = px + (pw - tw) / 2
        love.graphics.setColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6, 1)
        love.graphics.rectangle("fill", tx, y, tw, 14, 2)
        love.graphics.setColor(col[1], col[2], col[3], 0.90)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", tx, y, tw, 14, 2)
        love.graphics.setColor(0.78, 0.70, 0.70, 1)
        love.graphics.printf(label, tx, y + 2, tw, "center")
    end)
    return y + 18
end

function HUD.draw(matchState)
    if not matchState then return end

    local L  = Theme.layout
    local px = L.panelX
    local pw = L.panelW
    local H  = love.graphics.getHeight()

    -- Panel background (layered for depth)
    love.graphics.setColor(0.028, 0.005, 0.005, 1)
    love.graphics.rectangle("fill", px, 0, pw, H)
    love.graphics.setColor(0.045, 0.010, 0.010, 1)
    love.graphics.rectangle("fill", px + 2, 0, pw - 2, H)

    -- Left border (glowing line)
    love.graphics.setColor(Theme.hud.border[1], Theme.hud.border[2], Theme.hud.border[3], 0.35)
    love.graphics.setLineWidth(4)
    love.graphics.line(px, 0, px, H)
    love.graphics.setColor(Theme.hud.border)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(px + 1, 0, px + 1, H)
    love.graphics.setLineWidth(1)

    local y = 10

    -- Title
    Fonts.with(11, function()
        love.graphics.setColor(Theme.hud.border)
        love.graphics.printf("FOOTBALL TCG", px, y, pw, "center")
    end)
    y = y + 22

    -- Half / Turn / Phase pill
    local halfLabel = "HALF " .. tostring(matchState.half):upper()
    if matchState.half == "extra" then halfLabel = "EXTRA TIME" end
    local phaseCol = Theme.phases[matchState.phase] or Theme.hud.text
    love.graphics.setColor(phaseCol[1], phaseCol[2], phaseCol[3], 0.15)
    love.graphics.rectangle("fill", px + 6, y, pw - 12, 20, 3)
    love.graphics.setColor(phaseCol[1], phaseCol[2], phaseCol[3], 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px + 6, y, pw - 12, 20, 3)
    love.graphics.setLineWidth(1)
    Fonts.with(9, function()
        love.graphics.setColor(phaseCol)
        love.graphics.printf(halfLabel, px, y + 2, pw, "center")
    end)
    y = y + 24

    -- Turn and phase
    Fonts.with(9, function()
        love.graphics.setColor(0.55, 0.50, 0.52, 1)
        love.graphics.printf("TURN " .. matchState.turn .. "  " .. matchState.phase:upper(), px, y, pw, "center")
    end)
    y = y + 16

    -- Active player label
    local isPlayerTurn = matchState.activePlayer == "player"
    Fonts.with(11, function()
        love.graphics.setColor(isPlayerTurn and Theme.hud.accent or Theme.hud.danger)
        love.graphics.printf(isPlayerTurn and "YOUR TURN" or "OPP TURN", px, y, pw, "center")
    end)
    y = y + 18

    -- Summon counter — reads the real limit so midfield control bonus shows correctly
    local summonCount = matchState.summonCount or 0
    local maxSummons  = (matchState.players.player.nextTurnSummonLimit
                         or C.MATCH.MAX_SUMMONS_PER_TURN)
    local midBonus    = maxSummons > C.MATCH.MAX_SUMMONS_PER_TURN
    Fonts.with(9, function()
        love.graphics.setColor(midBonus and 0.45 or 0.55,
                               midBonus and 0.80 or 0.50,
                               midBonus and 0.45 or 0.52, 1)
        local label = "SUMMONS  " .. summonCount .. " / " .. maxSummons
        if midBonus then label = label .. "  ★" end
        love.graphics.printf(label, px, y, pw, "center")
    end)
    y = y + 16

    -- LP section
    y = sectionHeader(px, y, pw, "LIFE POINTS", {0.55, 0.10, 0.10})

    local p = matchState.players.player
    local o = matchState.players.opponent
    HUD._drawLPBar(px + 6, y,      pw - 12, p.lp, "YOU", Theme.hud.accent)
    y = y + 30
    HUD._drawLPBar(px + 6, y,      pw - 12, o.lp, "OPP", Theme.hud.danger)
    y = y + 26

    -- Halves won
    Fonts.with(9, function()
        love.graphics.setColor(0.55, 0.50, 0.52, 1)
        love.graphics.printf("Halves  You " .. p.halvesWon .. "  Opp " .. o.halvesWon, px, y, pw, "center")
    end)
    y = y + 16

    -- Keeper DEF
    y = sectionHeader(px, y, pw, "KEEPER DEF", {0.10, 0.25, 0.55})
    local Combat = require("engine.combat")
    local function keeperEffDef(playerState)
        if not playerState.pitch.keeper then return "-" end
        return tostring(Combat.keeperEffectiveDef(playerState.pitch.keeper, playerState.pitch))
    end
    Fonts.with(11, function()
        love.graphics.setColor(Theme.hud.accent)
        love.graphics.printf("You: " .. keeperEffDef(p), px, y, pw / 2, "center")
        love.graphics.setColor(Theme.hud.danger)
        love.graphics.printf("Opp: " .. keeperEffDef(o), px + pw / 2, y, pw / 2, "center")
    end)
    y = y + 18

    -- Midfielder bonuses
    local function midBonus(ps, label, col)
        local mid = ps.pitch.midfielder
        if not mid or mid.definition.type ~= "midfielder" then return nil end
        if mid.mode == "attack" then
            return { text = label .. ": Strikers +200 ATK", col = col }
        else
            return { text = label .. ": Defenders +200 DEF", col = col }
        end
    end
    local pb = midBonus(p, "You", Theme.hud.accent)
    local ob = midBonus(o, "Opp", Theme.hud.danger)
    if pb or ob then
        y = sectionHeader(px, y, pw, "MID BONUS", {0.10, 0.35, 0.20})
        Fonts.with(9, function()
            if pb then
                love.graphics.setColor(pb.col)
                love.graphics.printf(pb.text, px, y, pw, "center")
                y = y + 13
            end
            if ob then
                love.graphics.setColor(ob.col)
                love.graphics.printf(ob.text, px, y, pw, "center")
                y = y + 13
            end
        end)
    end

    -- Deck counts
    Fonts.with(9, function()
        love.graphics.setColor(0.45, 0.42, 0.44, 1)
        love.graphics.printf("Deck " .. #p.deck .. "  |  Opp " .. #o.deck, px, y, pw, "center")
    end)
    y = y + 16

    -- Action log
    y = sectionHeader(px, y, pw, "MATCH LOG", {0.35, 0.10, 0.35})

    local log = matchState.log or {}
    local startIdx = math.max(1, #log - LOG_MAX + 1)
    Fonts.with(9, function()
        for i = startIdx, #log do
            local entry = log[i]
            love.graphics.setColor(logColor(entry.type))
            love.graphics.printf(shortEvent(entry), px + 6, y, pw - 12, "left")
            y = y + 13
        end
    end)

    HUD.drawPhaseButtons(matchState, px, pw, H)
end

function HUD._drawLPBar(x, y, w, lp, label, col)
    local ratio = math.max(0, lp / LP_MAX)
    local barH  = 18

    -- Background track
    love.graphics.setColor(0.10, 0.06, 0.06, 1)
    love.graphics.rectangle("fill", x, y, w, barH, 3)

    -- Inner shadow
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", x, y, w, barH / 2, 3)

    -- Filled portion
    if ratio > 0 then
        local fillW = math.floor(w * ratio)
        love.graphics.setColor(col[1], col[2], col[3], 0.80)
        love.graphics.rectangle("fill", x, y, fillW, barH, 3)
        -- Shine stripe on top of fill
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.rectangle("fill", x, y, fillW, math.floor(barH / 2), 3)
    end

    -- Border
    love.graphics.setColor(col[1], col[2], col[3], 0.55)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, barH, 3)
    love.graphics.setLineWidth(1)

    -- Label
    Fonts.with(9, function()
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(label .. " " .. lp, x, y + 3, w, "center")
    end)
end

function HUD.drawPhaseButtons(matchState, px, pw, H)
    local btnW = pw - 12
    local btnX = px + 6

    -- END TURN button
    love.graphics.setColor(0.30, 0.07, 0.07, 1)
    love.graphics.rectangle("fill", btnX, H - 118, btnW, 32, 4)
    love.graphics.setColor(0.15, 0.04, 0.04, 1)
    love.graphics.rectangle("fill", btnX, H - 118, btnW, 10, 4)
    love.graphics.setColor(Theme.hud.danger)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", btnX, H - 118, btnW, 32, 4)
    love.graphics.setLineWidth(1)
    Fonts.with(11, function()
        love.graphics.setColor(1, 0.85, 0.85, 1)
        love.graphics.printf("END TURN", btnX, H - 108, btnW, "center")
    end)

    -- START ATTACK button
    if matchState.phase == "summon" then
        love.graphics.setColor(0.05, 0.22, 0.10, 1)
        love.graphics.rectangle("fill", btnX, H - 78, btnW, 32, 4)
        love.graphics.setColor(0.02, 0.12, 0.05, 1)
        love.graphics.rectangle("fill", btnX, H - 78, btnW, 10, 4)
        love.graphics.setColor(Theme.hud.accent)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", btnX, H - 78, btnW, 32, 4)
        love.graphics.setLineWidth(1)
        Fonts.with(11, function()
            love.graphics.setColor(0.85, 1, 0.90, 1)
            love.graphics.printf("START ATTACK", btnX, H - 68, btnW, "center")
        end)
    end

    -- MUTE button
    local muted = Audio.isMuted()
    local muteLabel = muted and "MUSIC: OFF" or "MUSIC: ON"
    local muteR = muted and 0.20 or 0.08
    local muteG = muted and 0.08 or 0.18
    local muteB = muted and 0.08 or 0.08
    love.graphics.setColor(muteR, muteG, muteB, 1)
    love.graphics.rectangle("fill", btnX, H - 38, btnW, 24, 4)
    love.graphics.setColor(muted and 0.65 or 0.35, muted and 0.20 or 0.55, 0.20, 0.80)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btnX, H - 38, btnW, 24, 4)
    Fonts.with(9, function()
        love.graphics.setColor(muted and { 1, 0.55, 0.55, 1 } or { 0.70, 1, 0.75, 1 })
        love.graphics.printf(muteLabel, btnX, H - 31, btnW, "center")
    end)
end

function HUD.drawModeButton(selectedMode, H)
    local L    = Theme.layout
    local px   = L.panelX
    local pw   = L.panelW
    local btnW = pw - 12
    local btnX = px + 6

    if selectedMode == "attack" then
        love.graphics.setColor(0.28, 0.08, 0.04, 1)
        love.graphics.rectangle("fill", btnX, H - 158, btnW, 32, 4)
        love.graphics.setColor(0.14, 0.04, 0.02, 1)
        love.graphics.rectangle("fill", btnX, H - 158, btnW, 10, 4)
        love.graphics.setColor(1.00, 0.45, 0.20, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", btnX, H - 158, btnW, 32, 4)
        love.graphics.setLineWidth(1)
        Fonts.with(11, function()
            love.graphics.setColor(1, 0.80, 0.65, 1)
            love.graphics.printf("MODE: ATTACK", btnX, H - 148, btnW, "center")
        end)
    else
        love.graphics.setColor(0.03, 0.10, 0.22, 1)
        love.graphics.rectangle("fill", btnX, H - 158, btnW, 32, 4)
        love.graphics.setColor(0.02, 0.05, 0.12, 1)
        love.graphics.rectangle("fill", btnX, H - 158, btnW, 10, 4)
        love.graphics.setColor(0.30, 0.65, 1.00, 1)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", btnX, H - 158, btnW, 32, 4)
        love.graphics.setLineWidth(1)
        Fonts.with(11, function()
            love.graphics.setColor(0.65, 0.85, 1, 1)
            love.graphics.printf("MODE: DEFENSE", btnX, H - 148, btnW, "center")
        end)
    end
end

function HUD.getButtonHitboxes(H)
    local L    = Theme.layout
    local px   = L.panelX
    local pw   = L.panelW
    local btnW = pw - 12
    local btnX = px + 6
    return {
        endTurn     = { x = btnX, y = H - 118, w = btnW, h = 32 },
        startAttack = { x = btnX, y = H - 78,  w = btnW, h = 32 },
        modeToggle  = { x = btnX, y = H - 158, w = btnW, h = 32 },
        muteMusic   = { x = btnX, y = H - 38,  w = btnW, h = 24 },
    }
end

return HUD
