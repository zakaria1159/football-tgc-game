-- Timed scripts for tools/snapshot/snap.sh. Each step: { seconds, function(ctx) ... end }.
-- ctx.snap(label) saves a screenshot; ctx.quit() exits. Every scenario must end with ctx.quit().
-- Match scenarios seed math.random so the dealt hands are identical on every run, and read
-- click positions from ui/match/layout.lua + ui/match/handfan.lua so they follow the layout.
local Layout  = require("ui.match.layout")
local HandFan = require("ui.match.handfan")

local S = {}

local function store() return require("scenes.match").debugStore() end
local function hand() return store().match.players.player.hand end
local function center(r) return r.x + r.w / 2, r.y + r.h / 2 end
local function move(x, y) love.mousemoved(x, y, 0, 0) end
local function press(x, y) love.mousepressed(x, y, 1) end
local function click(x, y) move(x, y); press(x, y) end

local function firstOf(types)
    for _, t in ipairs(types) do
        for _, c in ipairs(hand()) do
            if c.type == t then return c end
        end
    end
    return nil
end

-- Point 70px above the bottom of a hand card at rest (inside it despite rotation).
local function handPoint(card)
    local h = hand()
    for i, c in ipairs(h) do
        if c == card then
            local cards = HandFan.layout(#h, Layout.bottom.hand)
            return cards[i].cx, cards[i].by - 70
        end
    end
    return nil
end

local FIELD_SLOT = { striker = { "striker", 1 }, defender = { "defender", 1 }, midfielder = { "midfielder", 0 } }
local function fieldSlot(card)
    local s = card and FIELD_SLOT[card.type]
    return s and Layout.slot("player", s[1], s[2]) or nil
end

-- Unblock the AI: let attacks through, dismiss combat / trap-activation overlays.
local function advance()
    local st = store()
    if not st or not st.match then return end
    if st.coverWindow and st.match.activePlayer == "opponent" then
        for _, hb in ipairs(require("ui.cover_prompt").getHitboxes(st.coverWindow)) do
            if hb.type == "letthrough" then press(hb.x + hb.w / 2, hb.y + hb.h / 2); return end
        end
    end
    love.keypressed("space")
end

local function byTime(steps)
    table.sort(steps, function(a, b) return a[1] < b[1] end)
    return steps
end

S.home = {
    { 1.0, function(c) c.snap("deck") end },
    { 1.5, function(c) c.quit() end },
}

S.library = {
    { 0.5, function() love.mousepressed(640, 538, 1) end },  -- CARD LIBRARY button (scenes/home.lua)
    { 1.5, function(c) c.snap("grid") end },
    { 2.0, function(c) c.quit() end },
}

S.match = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, function() love.keypressed("return") end },       -- start with the first deck
    { 3.0, function(c) c.snap("start") end },
    { 9.0, function(c) c.snap("later") end },
    { 9.5, function(c) c.quit() end },
}

S.cards = {
    { 0.3, function() love.draw = require("tools.snapshot.card_gallery").draw end },
    { 1.0, function(c) c.snap("gallery") end },
    { 1.5, function(c) c.quit() end },
}

-- Summon a keeper + one field card, start the attack phase, select an attacker,
-- end the turn and let the AI play.
local picked = {}
S.summon = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  function() love.keypressed("return") end },
    { 1.5,  function()
        picked.keeper = firstOf({ "keeper" })
        picked.field  = firstOf({ "striker", "defender", "midfielder" })
        move(handPoint(picked.keeper))
    end },
    { 2.0,  function(c) c.snap("hover") end },
    { 2.1,  function() press(handPoint(picked.keeper)) end },
    { 2.3,  function() move(640, 300) end },
    { 2.6,  function(c) c.snap("selected") end },
    { 2.7,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 3.5,  function(c) c.snap("placed") end },
    { 3.6,  function() if picked.field then move(handPoint(picked.field)) end end },
    { 3.9,  function() if picked.field then press(handPoint(picked.field)) end end },
    { 4.1,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
    { 4.8,  function(c) c.snap("two") end },
    { 4.9,  function() click(center(Layout.bottom.startAttack)) end },
    { 5.2,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
    { 5.4,  function() move(640, 60) end },
    { 5.8,  function(c) c.snap("attack") end },
    { 5.9,  function() if picked.field then love.keypressed("escape") end end },
    { 6.0,  function() click(center(Layout.bottom.endTurn)) end },
    { 8.25, function(c) c.snap("aiturn") end },
    { 14.25, function(c) c.snap("myturn") end },
    { 14.5, function(c) c.quit() end },
}
for t = 6.5, 14.0, 0.5 do S.summon[#S.summon + 1] = { t, advance } end
byTime(S.summon)

return S
