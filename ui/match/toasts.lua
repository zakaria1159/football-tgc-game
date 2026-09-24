-- Toast stack for the 3 latest match-log events (replaces the HUD log panel).
-- Queue, timing and text are pure (unit-tested); Toasts:draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local Toasts = {}
Toasts.__index = Toasts

Toasts.LIFE  = 4.0
Toasts.FADE  = 0.5
Toasts.SLIDE = 0.25
Toasts.MAX   = 3

function Toasts.new() return setmetatable({ items = {} }, Toasts) end

function Toasts:push(text, kind)
    table.insert(self.items, 1, { text = text, kind = kind or "info", age = 0 })
    while #self.items > Toasts.MAX do table.remove(self.items) end
end

function Toasts:update(dt)
    for i = #self.items, 1, -1 do
        local it = self.items[i]
        it.age = it.age + dt
        if it.age >= Toasts.LIFE then table.remove(self.items, i) end
    end
end

-- x offset (slides in from the left) and alpha for a toast of this age.
function Toasts.pose(age)
    local slide, alpha = 0, 1
    if age < Toasts.SLIDE then
        local k = age / Toasts.SLIDE
        slide = -40 * (1 - k) * (1 - k)
        alpha = k
    end
    local fadeStart = Toasts.LIFE - Toasts.FADE
    if age > fadeStart then alpha = math.max(0, 1 - (age - fadeStart) / Toasts.FADE) end
    return slide, alpha
end

-- text, kind for a log entry (nil = no toast). kind: good | bad | trap | half | info
function Toasts.describe(entry)
    local t = entry.type or ""
    local p = entry.payload or {}
    local mine = p.player == "player"
    local who = mine and "You" or "Opp"

    if t == "card_drawn" or t == "turn_end" then return nil end
    if t == "lp_damage" then
        local you = p.dealer == "player"
        local txt = (you and "You dealt " or "You took ") .. tostring(p.damage or 0) .. " LP"
        if p.source == "facedown_penalty" then txt = txt .. " (bluff!)" end
        return txt, you and "good" or "bad"
    end
    if t == "half_end"  then return "Half " .. tostring(p.half or "?") .. " over", "half" end
    if t == "match_end" then return "FULL TIME", "half" end
    if t == "midfield_control" then
        return (mine and "You control" or "Opp controls") .. " midfield +1 summon", mine and "good" or "bad"
    end
    if t == "trap_activated" then
        local nm = (p.trap or "trap"):gsub("^trap%-", ""):gsub("%-", " ")
        return "TRAP! " .. string.upper(nm) .. " (" .. who .. ")", "trap"
    end
    if t == "card_played" then
        if p.action == "mode_change" then return who .. " flipped a card face-up", "info" end
        if p.slot == "trap" then return who .. " set a trap", "trap" end
        return who .. " summoned a " .. string.upper(tostring(p.slot or "card")), "info"
    end
    if t == "defender_destroy" then
        return string.upper(p.slot and p.slot.type or "card") .. " destroyed", "info"
    end
    if t == "cover" then
        return "COVER by " .. string.upper(p.coverer and p.coverer.type or "?"), "info"
    end
    if t == "shot" then
        if p.outcome == "save" then return "Keeper SAVES!", "info" end
        if p.outcome == "tie"  then return "Keeper blocks - tie", "info" end
        return "Shot: " .. tostring(p.outcome or "?"), "info"
    end
    if t == "attack_declared" then
        local a = p.attacker and p.attacker.type or "?"
        local d = p.defender and p.defender.type or "?"
        return string.upper(a) .. " attacks " .. string.upper(d), "info"
    end
    if t == "strategy_played" then
        local ab = string.lower(p.ability or "strategy"):gsub("_", " ")
        return who .. " played " .. ab, "info"
    end
    if t == "attack_wasted" then return "Attack wasted", "info" end
    local s = t:gsub("_", " ")
    return s, "info"
end

local FILLS = {
    good = Theme.grad.lpYou, bad = Theme.grad.lpOpp, trap = Theme.typeGrad.trap,
    half = Theme.button.primary.fill, info = Theme.white,
}
local TEXT = { info = Theme.inkText, half = Theme.button.primary.text }

function Toasts:draw()
    for i, it in ipairs(self.items) do
        local r = Layout.toastRect(i)
        local slide, a = Toasts.pose(it.age)
        local x = r.x + slide
        Draw.sticker(x, r.y, r.w, r.h, { r = 10, fill = FILLS[it.kind] or FILLS.info, border = 2, shadow = 3, alpha = a })
        Draw.text(it.text, x + 10, r.y + 6, r.w - 20, "left", {
            size = 13, body = true, color = TEXT[it.kind] or Theme.white, fit = true, minSize = 9, alpha = a,
        })
    end
end

return Toasts
