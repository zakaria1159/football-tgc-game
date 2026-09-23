local Theme = require("ui.theme")

local Log = {}

-- Maximum lines shown in the log panel
local MAX_LINES = 18

-- Human-readable descriptions for event types
local function describe(event)
    local t = event.type
    local p = event.payload or {}

    if t == "match_start"      then return "Match started!"
    elseif t == "turn_start"   then return "Turn " .. (p.turn or "?") .. " begins."
    elseif t == "card_drawn"   then return (p.player == "player" and "You" or "Opponent") .. " drew a card."
    elseif t == "card_played"  then return (p.player == "player" and "You" or "Opponent") .. " played " .. (p.card or "a card") .. " to " .. (p.slot or "pitch") .. "."
    elseif t == "midfield_duel" then
        if p.result == "auto_player" then return "You control midfield (no opponent midfielder)."
        elseif p.result == "auto_opponent" then return "Opponent controls midfield."
        else
            local who = (p.margin or 0) > 0 and "You" or ((p.margin or 0) < 0 and "Opponent" or "")
            if p.outcome == "tie" then return "Midfield duel: TIE — both exhausted."
            else return "Midfield duel: " .. who .. " wins! (margin " .. (p.margin or 0) .. ")"
            end
        end
    elseif t == "midfield_control" then
        local who = p.player == "player" and "You control" or "Opponent controls"
        return who .. " midfield (" .. (p.myPow or 0) .. " vs " .. (p.oppPow or 0) .. ")  +1 summon"
    elseif t == "attack_declared" then return "Attack declared on " .. (p.defender and p.defender.type or "?") .. " slot."
    elseif t == "defender_exhaust" then return "Defender exhausted."
    elseif t == "defender_destroy" then return "Defender DESTROYED!"
    elseif t == "shot_saved"   then return "SHOT SAVED! (margin " .. (p.margin or 0) .. ")"
    elseif t == "goal"         then return "⚽ GOAL! " .. (p.scorer == "player" and "YOU SCORED!" or "Opponent scored!")
    elseif t == "foul"         then return "FOUL! " .. (p.zone or "") .. " — " .. (p.consequence and p.consequence.attackType or "")
    elseif t == "yellow_card"  then return "Yellow card!"
    elseif t == "red_card"     then return "RED CARD! Card destroyed."
    elseif t == "trap_activated" then return "TRAP activated: " .. (p.trap or "?")
    elseif t == "turn_end"     then return "--- Turn " .. (p.turn or "?") .. " ends ---"
    elseif t == "match_end"    then return "MATCH OVER. Winner: " .. (p.winner or "?")
    elseif t == "attack_wasted" then return "Attack wasted — no defender, no cover."
    else return t
    end
end

function Log.draw(matchLog)
    if not matchLog then return end

    local L   = Theme.layout
    local px  = L.panelX
    local pw  = L.panelW
    local H   = love.graphics.getHeight()

    -- Determine log area (below the main HUD stats, above buttons)
    local logY = 380
    local logH = H - logY - 180
    local logX = px + 6

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.14, 1)
    love.graphics.rectangle("fill", px + 4, logY, pw - 8, logH, 4)
    love.graphics.setColor(0.20, 0.20, 0.30, 1)
    love.graphics.rectangle("line", px + 4, logY, pw - 8, logH, 4)

    -- Label
    love.graphics.setColor(Theme.hud.subtext)
    love.graphics.print("MATCH LOG", logX, logY + 4)

    -- Recent events (newest at bottom)
    local lineH  = 14
    local maxY   = logY + logH - 8
    local startI = math.max(1, #matchLog - MAX_LINES + 1)

    for i = startI, #matchLog do
        local event = matchLog[i]
        local lineY = logY + 20 + (i - startI) * lineH
        if lineY + lineH > maxY then break end

        -- Color by type
        local col = Theme.hud.subtext
        if event.type == "goal"             then col = { 0.3, 1.0, 0.5, 1 }
        elseif event.type == "shot_saved"   then col = { 0.9, 0.5, 0.2, 1 }
        elseif event.type == "defender_destroy" then col = { 1.0, 0.3, 0.3, 1 }
        elseif event.type == "trap_activated"   then col = { 0.9, 0.3, 0.8, 1 }
        elseif event.type == "foul"         then col = { 1.0, 0.8, 0.1, 1 }
        elseif event.type == "turn_end"     then col = { 0.4, 0.4, 0.5, 1 }
        end

        love.graphics.setColor(col)
        love.graphics.printf(describe(event), logX, lineY, pw - 12, "left")
    end
end

return Log
