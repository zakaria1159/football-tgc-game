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

-- Harness-only: ignore the physical cursor. The OS sends mousemoved when the window opens
-- or the real mouse moves, and hovering a home button moves the keyboard focus to it, so
-- only the scripted move() above may drive the mouse (it calls love.mousemoved directly).
if love.handlers then love.handlers.mousemoved = function() end end

-- Home → PLAY → deck select → KICK OFF with the first deck (The Beautiful Game).
local function kickOff()
    love.keypressed("return")
    love.keypressed("return")
end

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

-- Home menu, keyboard focus, deck select (two selections), back to home.
S.home = {
    { 1.0, function(c) c.snap("menu") end },
    { 1.1, function() love.keypressed("down") end },
    { 1.5, function(c) c.snap("focus") end },
    { 1.6, function() love.keypressed("up"); love.keypressed("return") end },
    { 2.2, function(c) c.snap("deck") end },
    { 2.3, function() love.keypressed("right") end },
    { 2.8, function(c) c.snap("deck2") end },
    { 2.9, function() love.keypressed("escape") end },
    { 3.2, function(c) c.snap("back") end },
    { 3.5, function(c) c.quit() end },
}

-- Card library from the home menu: grid, hover zoom, TRAPS tab, scrolled, closed.
S.library = {
    { 0.5, function() click(center(require("ui.menu.home").buttonRect(2))) end },
    { 1.2, function(c) c.snap("grid") end },
    { 1.3, function() move(center(require("ui.menu.library").cellRect(2, 0))) end },
    { 1.9, function(c) c.snap("hover") end },
    { 2.0, function() click(center(require("ui.menu.library").tabRects()[6])) end },
    { 2.5, function(c) c.snap("traps") end },
    { 2.6, function() for _ = 1, 5 do love.keypressed("left") end end },   -- back to ALL
    { 2.7, function() love.wheelmoved(0, -20) end },
    { 3.2, function(c) c.snap("scrolled") end },
    { 3.3, function() love.keypressed("escape") end },
    { 3.6, function(c) c.snap("closed") end },
    { 4.0, function(c) c.quit() end },
}

S.match = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },   -- start with the first deck
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
    { 0.5,  kickOff },
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

-- Juice: LP drain + GOAL banner + confetti, midfield banner, draw animation, summon pop.
-- (Setting opponent LP directly is harness-only; it just feeds the LP bar.)
S.juice = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        store().match.players.opponent.lp = 3200
        require("scenes.match").onLPDamage("player", true)
    end },
    { 1.85, function(c) c.snap("drain") end },
    { 2.9,  function(c) c.snap("settled") end },
    { 3.0,  function() require("scenes.match").flash("MIDFIELD CONTROL +1 SUMMON", "good") end },
    { 3.4,  function(c) c.snap("banner") end },
    { 3.5,  function() require("scenes.match").spawnDrawAnim(true) end },
    { 3.7,  function(c) c.snap("drawanim") end },
    { 3.8,  function(c)
        -- The full squash lasts about one frame, so snap on the frame it starts
        -- (flux won't advance the new tween until the next update).
        local Tween = require("ui.kit.tween")
        local squash = Tween.squash
        Tween.squash = function(obj, dur)
            Tween.squash = squash
            local tw = squash(obj, dur)
            c.snap("pop")
            return tw
        end
        press(handPoint(firstOf({ "keeper" })))
    end },
    { 4.0,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 4.05, function() move(640, 300) end },                  -- keep the zoom off the pop shot
    { 4.9,  function(c) c.snap("popdone") end },
    { 5.0,  function(c) c.quit() end },
}

-- Top-bar icons: log panel, AI hand (TAB), pause menu.
S.debug = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function() click(center(Layout.top.log)) end },
    { 2.0, function(c) c.snap("log") end },
    { 2.1, function() love.keypressed("l") end },
    { 2.2, function() love.keypressed("tab") end },
    { 2.6, function(c) c.snap("aihand") end },
    { 2.7, function() love.keypressed("tab") end },
    { 2.8, function() click(center(Layout.top.pause)) end },
    { 3.2, function(c) c.snap("pause") end },
    { 3.3, function() love.keypressed("escape") end },
    { 3.6, function(c) c.snap("resumed") end },
    { 4.0, function(c) c.quit() end },
}

-- Pause menu: pop-in, keyboard focus, CARD LIBRARY from pause, back, RESUME by click.
S.pause = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function() love.keypressed("escape") end },
    { 1.6, function(c) c.snap("pop") end },
    { 2.1, function(c) c.snap("menu") end },
    { 2.2, function() love.keypressed("down") end },
    { 2.5, function(c) c.snap("focus") end },
    { 2.6, function() love.keypressed("return") end },       -- CARD LIBRARY
    { 3.2, function(c) c.snap("library") end },
    { 3.3, function() love.keypressed("escape") end },       -- back to the pause menu
    { 3.6, function(c) c.snap("back") end },
    { 3.7, function() click(center(require("ui.menu.pause").buttonRect(1))) end },   -- RESUME
    { 4.1, function(c) c.snap("resumed") end },
    { 4.5, function(c) c.quit() end },
}

return S
