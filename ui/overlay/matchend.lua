-- Half-time ribbon text and the match-end screen. Win: gold VICTORY! with the happy
-- (attacking) pose and confetti (scenes/match.lua bursts it). Loss: grey-blue DEFEAT with
-- the worried pose. Final LP, halves and LP damage; PLAY AGAIN / MAIN MENU.
-- Text, layout and input mapping are pure (unit-tested); draw uses LÖVE.
-- Actions: "restart" (same deck) | "home".
local Theme     = require("ui.theme")
local Draw      = require("ui.kit.draw")
local Button    = require("ui.kit.button")
local Character = require("ui.character")
local C         = require("ui.overlay.combatfx")   -- progress / backout

local MatchEnd = {}

MatchEnd.PLAY_AGAIN = { x = 395, y = 628, w = 230, h = 68 }
MatchEnd.MAIN_MENU  = { x = 655, y = 628, w = 230, h = 68 }
MatchEnd.PORTRAIT   = { x = 250, y = 240, w = 280, h = 340 }
MatchEnd.STATS      = { x = 570, y = 260, w = 460, h = 300 }

-- Ribbon text when a half ends without a winner. you/opp = halves won so far.
function MatchEnd.halfText(half, you, opp)
    local score = "YOU " .. you .. " – " .. opp .. " OPP"
    if half == 1 then return "HALF TIME · " .. score end
    if half == 2 then return "FULL TIME · " .. score .. " · EXTRA TIME" end
    return "EXTRA TIME OVER · " .. score
end

function MatchEnd.title(winner)
    if winner == "player" then return "VICTORY!", "win" end
    return "DEFEAT", "loss"
end

function MatchEnd.rows(match)
    local p, o = match.players.player, match.players.opponent
    return {
        { label = "FINAL LP",  you = math.max(0, p.lp),        opp = math.max(0, o.lp) },
        { label = "HALVES",    you = p.halvesWon or 0,         opp = o.halvesWon or 0 },
        { label = "LP DAMAGE", you = p.totalDamageDealt or 0,  opp = o.totalDamageDealt or 0 },
    }
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function MatchEnd.actionAt(x, y)
    if inRect(x, y, MatchEnd.PLAY_AGAIN) then return "restart" end
    if inRect(x, y, MatchEnd.MAIN_MENU) then return "home" end
    return nil
end

function MatchEnd.keyAction(key)
    if key == "r" then return "restart" end
    if key == "escape" then return "home" end
    return nil
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local WIN_FILL  = { Theme.hex("ffe08a"), Theme.hex("ffb43a") }
local LOSS_FILL = { Theme.hex("aab4cf"), Theme.hex("6b7896") }
local buttons = nil

-- t: seconds since the screen appeared; mx, my: match mouse.
function MatchEnd.draw(match, t, mx, my)
    if not buttons then
        local A, M = MatchEnd.PLAY_AGAIN, MatchEnd.MAIN_MENU
        buttons = {
            Button.new({ id = "restart", label = "PLAY AGAIN", variant = "go", fontSize = 28,
                         x = A.x, y = A.y, w = A.w, h = A.h }),
            Button.new({ id = "home", label = "MAIN MENU", variant = "neutral", fontSize = 28,
                         x = M.x, y = M.y, w = M.w, h = M.h }),
        }
    end
    local won = match.winner == "player"
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.78 * C.progress(t, 0, 0.3))
    love.graphics.rectangle("fill", 0, 0, 1280, 800)

    local pop = C.backout(C.progress(t, 0.05, 0.4))
    love.graphics.push()
    love.graphics.translate(640, 152)
    love.graphics.scale(pop, pop)
    love.graphics.translate(-640, -152)
    Draw.ribbon(640, 104, 560, 96, (MatchEnd.title(match.winner)), {
        fill = won and Theme.outcome.yellow or Theme.outcome.grey,
        textColor = won and Theme.button.primary.text or Theme.white, size = 72, textShadow = not won,
    })
    love.graphics.pop()

    local P = MatchEnd.PORTRAIT
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 24, fill = won and WIN_FILL or LOSS_FILL, border = 5, shadow = 7 })
    Character.drawPortrait(P.x + 5, P.y + 5, P.w - 10, P.h - 10, won and "attacking" or "worried")

    local S = MatchEnd.STATS
    Draw.sticker(S.x, S.y, S.w, S.h, { r = 24, fill = Theme.white, border = 0, shadow = 7 })
    Draw.text("YOU", S.x + 200, S.y + 22, 110, "center", { size = 22, color = Theme.grad.lpYou[2] })
    Draw.text("OPP", S.x + 320, S.y + 22, 110, "center", { size = 22, color = Theme.grad.lpOpp[2] })
    for i, row in ipairs(MatchEnd.rows(match)) do
        local y = S.y + 64 + (i - 1) * 72
        Draw.text(row.label, S.x + 24, y + 12, 170, "left", { size = 22, color = Theme.inkText, fit = true })
        Draw.pill(S.x + 200, y, 110, 48, tostring(row.you), { fill = Theme.grad.lpYou, textColor = Theme.white, size = 26 })
        Draw.pill(S.x + 320, y, 110, 48, tostring(row.opp), { fill = Theme.grad.lpOpp, textColor = Theme.white, size = 26 })
    end

    local dt, down = love.timer.getDelta(), love.mouse.isDown(1)
    for _, b in ipairs(buttons) do
        b:update(dt, mx or -1, my or -1, down)
        b:draw()
    end
    Draw.text("R  PLAY AGAIN   ·   ESC  MAIN MENU", 0, 716, 1280, "center", {
        size = 14, body = true, color = Theme.white, shadowY = 1,
    })
end

return MatchEnd
