-- Cover prompt and trap window as the bottom sticker panel (ui/overlay/promptpanel.lua),
-- with the relevant pitch slots pulsing above a light dim. Data contracts unchanged:
--   coverWindow = { attackerSnap, attackerSlot, emptySlot, eligibleCoverers = { { type, index, card } } }
--   trapWindow  = { type, attackerSnap, defenderSnap, aiTrapCard?, traps = { { card, slotIndex } } }
-- Both draw functions return the hitboxes Match.mousepressed tests clicks against.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Layout   = require("ui.match.layout")
local Panel    = require("ui.overlay.promptpanel")
local CombatFx = require("ui.overlay.combatfx")

local Prompts = {}

local buttons = {}

-- Cached kit button placed at r, updated with the match mouse, drawn.
local function button(id, label, variant, r, mx, my)
    local b = buttons[id]
    if not b then
        b = Button.new({ id = id, label = label, variant = variant, fontSize = 20 })
        buttons[id] = b
    end
    b.label = label
    b:setRect(r.x, r.y, r.w, r.h)
    b:update(love.timer.getDelta(), mx or -1, my or -1, love.mouse.isDown(1))
    b:draw()
end

local function pulseRect(r, color)
    if not r then return end
    local k = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
    Draw.glow(r.x, r.y, r.w, r.h, 14, color, 0.6 + 0.8 * k)
    Draw.ring(r.x - 4, r.y - 4, r.w + 8, r.h + 8, 16, color, 4, 0.6 + 0.4 * k)
end

local function dim()
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.30)
    love.graphics.rectangle("fill", 0, 0, Layout.W, Layout.H)
end

local function panel(L, title, fill, textColor)
    local P = L.panel
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 24, fill = Theme.white, border = 0, shadow = 7 })
    Draw.ribbon(P.x + P.w / 2, P.y - 22, 400, 46, title, {
        fill = fill, textColor = textColor, size = 26, textShadow = textColor == Theme.white,
    })
end

-- Attacking card (hand size) with an arrow toward the info column.
local function source(L, snap)
    local v = CombatFx.cardView(snap, CombatFx.lookup)
    if not v then return end
    local r = L.source
    Card.drawFace(v.cardDef, r.x, r.y, r.w, r.h, {
        stats = v.stats, atkBonus = v.atkBonus > 0 and v.atkBonus or nil,
    })
    Draw.arrow(r.x + r.w + 12, r.y + r.h / 2, 18, 1, Theme.inkText)
end

local function info(L, heading, body, note)
    local r = L.info
    Draw.text(heading, r.x, r.y + 6, r.w, "left", { size = 22, color = Theme.inkText, fit = true, minSize = 14 })
    Draw.text(body, r.x, r.y + 40, r.w, "left", { size = 15, body = true, color = Theme.inkText })
    if note then
        Draw.text(note, r.x, r.y + 118, r.w, "left", { size = 13, body = true, color = { 0.42, 0.42, 0.6, 1 } })
    end
end

local function snapLine(snap, stat)
    if not snap then return "an empty slot" end
    return snap.name .. " (" .. string.upper(stat) .. " " .. tostring(snap[stat] or 0) .. ")"
end

function Prompts.drawCover(cw, slide, mx, my)
    local L = Panel.layout(#cw.eligibleCoverers, slide)
    dim()
    local a = cw.attackerSlot
    if a then pulseRect(Layout.slot("opponent", a.type, a.index or 0), Theme.highlight.target) end
    for _, cov in ipairs(cw.eligibleCoverers) do
        pulseRect(Layout.slot("player", cov.type, cov.index or 0), Theme.highlight.selected)
    end
    panel(L, "COVER?", Theme.button.primary.fill, Theme.button.primary.text)
    source(L, cw.attackerSnap)
    local es = cw.emptySlot or {}
    local slotName = Theme.typeLabel[es.type] or string.upper(tostring(es.type or "?"))
    info(L, "INCOMING ATTACK",
        snapLine(cw.attackerSnap, "atk") .. " is attacking your empty " .. slotName .. " slot.",
        "A covering card can't act next turn.")
    for i, cov in ipairs(cw.eligibleCoverers) do
        local o = L.options[i]
        if o then
            Card.drawFace(cov.card.definition, o.card.x, o.card.y, o.card.w, o.card.h, {})
            button("cover" .. i, "COVER", "go", o.button, mx, my)
        end
    end
    button("letthrough", "LET THROUGH", "neutral", L.pass, mx, my)
    return Panel.coverHitboxes(cw, slide)
end

function Prompts.drawTrapWindow(tw, slide, mx, my)
    local L = Panel.layout(#tw.traps, slide)
    dim()
    for _, e in ipairs(tw.traps) do
        pulseRect(Layout.trapSlot("player", e.slotIndex), Theme.typeGrad.trap[1])
    end
    panel(L, Panel.trapTitle(tw.type), Theme.outcome.purple, Theme.white)
    source(L, tw.attackerSnap)
    local note = "Activate a trap, or pass."
    if tw.aiTrapCard and tw.aiTrapCard.definition then
        note = "Opponent plays " .. tw.aiTrapCard.definition.name .. ". Counter it?"
    end
    info(L, "YOUR TRAPS ARE READY",
        snapLine(tw.attackerSnap, "atk") .. " vs " .. snapLine(tw.defenderSnap, "def") .. ".", note)
    for i, e in ipairs(tw.traps) do
        local o = L.options[i]
        if o then
            Card.drawFace(e.card.definition, o.card.x, o.card.y, o.card.w, o.card.h, {})
            button("activate" .. i, "ACTIVATE", "go", o.button, mx, my)
        end
    end
    button("pass", "PASS", "neutral", L.pass, mx, my)
    return Panel.trapHitboxes(tw, slide)
end

return Prompts
