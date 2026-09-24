-- Match bottom area (y 540–800) except the hand: portrait, deck pile, toast stack,
-- SUMMONS pill, START ATTACK / END TURN and the hint line. (The mode is chosen on the slot:
-- ui/match/modepicker.lua.)
-- Clicks are mapped by Layout.buttonAt; this module only draws and animates.
local Theme     = require("ui.theme")
local Draw      = require("ui.kit.draw")
local Button    = require("ui.kit.button")
local Card      = require("ui.card")
local Layout    = require("ui.match.layout")
local Stats     = require("ui.match.stats")
local Character = require("ui.character")

local BottomBar = {}

local buttons = nil
local PORTRAIT_FILL = { Theme.hex("8fc2ff"), Theme.hex("5b63f0") }

function BottomBar.reset()
    local B = Layout.bottom
    buttons = {
        startAttack = Button.new({ id = "startAttack", label = "START ATTACK", variant = "go",
            x = B.startAttack.x, y = B.startAttack.y, w = B.startAttack.w, h = B.startAttack.h, fontSize = 24 }),
        endTurn = Button.new({ id = "endTurn", label = "END TURN", variant = "primary",
            x = B.endTurn.x, y = B.endTurn.y, w = B.endTurn.w, h = B.endTurn.h, fontSize = 32 }),
    }
end

function BottomBar.update(dt, match, mx, my)
    if not buttons then BottomBar.reset() end
    local myTurn = match.activePlayer == "player" and not match.winner
    buttons.endTurn.enabled     = myTurn
    buttons.startAttack.enabled = myTurn and match.phase == "summon"
    local down = love.mouse.isDown(1)
    buttons.endTurn:update(dt, mx or -1, my or -1, down)
    buttons.startAttack:update(dt, mx or -1, my or -1, down)
end

local function drawPortrait()
    local r = Layout.bottom.portrait
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 18, fill = PORTRAIT_FILL, border = 4, shadow = 5 })
    Character.drawPortrait(r.x + 4, r.y + 4, r.w - 8, r.h - 8)
end

local function drawDeck(count)
    local d, c = Layout.bottom.deck, Layout.bottom.deckCount
    if count > 1 then Card.drawBack(d.x + 5, d.y - 5, d.w, d.h) end
    if count > 0 then
        Card.drawBack(d.x, d.y, d.w, d.h)
    else
        Draw.roundedFill(d.x, d.y, d.w, d.h, 10, { 1, 1, 1, 0.15 })
    end
    Draw.text("DECK", c.x, c.y - 20, c.w, "center", { size = 14, shadowY = 2 })
    Draw.pill(c.x, c.y, c.w, c.h, tostring(count), { fill = Theme.white, textColor = Theme.inkText, size = 18 })
end

local function drawSummons(match)
    local r = Layout.bottom.summons
    local used, max = Stats.summons(match)
    Draw.pill(r.x, r.y, r.w, r.h, "SUMMONS " .. used .. " / " .. max, {
        fill = Theme.white, textColor = Theme.inkText, size = 18,
    })
end

-- st = { toasts = Toasts instance, hint = string }
function BottomBar.draw(match, st)
    if not buttons then BottomBar.reset() end
    drawPortrait()
    drawDeck(#match.players.player.deck)
    if st.toasts then st.toasts:draw() end
    drawSummons(match)
    if match.phase == "summon" and match.activePlayer == "player" then buttons.startAttack:draw() end
    buttons.endTurn:draw()
    if st.hint and st.hint ~= "" then
        local h = Layout.bottom.hint
        Draw.text(st.hint, h.x, h.y, h.w, "center", {
            size = 12, body = true, color = Theme.white, shadowY = 1, fit = true, minSize = 9,
        })
    end
end

return BottomBar
