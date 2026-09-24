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

-- Card definition by id (synthetic overlay records).
local function defById(id)
    for _, f in ipairs({ "strikers", "midfielders", "defenders", "keepers", "traps", "strategies" }) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do
            if d.id == id then return d end
        end
    end
    error("no card " .. id)
end

-- Combat snapshot like store:_snapshotAttack, from a card id plus overrides.
local function snapFrom(id, over)
    local d = defById(id)
    local s = { name = d.name, type = d.type, mode = "attack", wasHidden = false,
                atk = d.stats.atk, def = d.stats.def, atkBonus = 0, defBonus = 0, isKeeper = false }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
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
        for _, hb in ipairs(require("ui.overlay.promptpanel").coverHitboxes(st.coverWindow, 0)) do
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
    { 3.0,  function() require("scenes.match").flash("MIDFIELD CONTROL +1 CARD", "good") end },
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

-- Combat overlay: destroyed (face-down defender flips, shatter), keeper save (Eff. DEF
-- bonus tag), LP damage; then opponent attacks: your card stays on the left, the attacker
-- slides in from the right and lunges left, your destroyed defender shatters on the left,
-- and an open goal puts EMPTY on the left. Synthetic records via Match.debugOverlay
-- (harness-only).
local function combat(rec) return function() require("scenes.match").debugOverlay("combat", rec) end end
S.combat = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, combat({
        attacker = snapFrom("str-clinical-finisher", { atk = 2500, atkBonus = 200 }),
        defender = snapFrom("def-destroyer", { mode = "defense", wasHidden = true }),
        outcome = "defender_destroyed", margin = 600, damage = 0, activePlayer = "player" }) },
    { 1.56, function(c) c.snap("slide") end },
    { 2.2,  function(c) c.snap("clash") end },
    { 2.5,  function(c) c.snap("count") end },
    { 3.0,  function(c) c.snap("shatter") end },
    { 3.6,  function(c) c.snap("destroyed") end },
    { 3.7,  function() love.keypressed("space") end },
    { 3.8,  combat({
        attacker = snapFrom("str-poacher"),
        defender = snapFrom("keeper-iron-fists", { def = 2250, isKeeper = true }),
        outcome = "save", margin = -250, damage = 0, activePlayer = "opponent" }) },
    { 3.9,  function(c) c.snap("opp_slide") end },
    { 4.35, function(c) c.snap("opp_lunge") end },
    { 5.9,  function(c) c.snap("save") end },
    { 6.0,  function() love.keypressed("space") end },
    { 6.1,  combat({
        attacker = snapFrom("str-speed-demon"),
        defender = snapFrom("keeper-reliable-hands", { isKeeper = true }),
        outcome = "damage", margin = 500, damage = 500, activePlayer = "player" }) },
    { 8.2,  function(c) c.snap("damage") end },
    { 8.3,  function() love.keypressed("space") end },
    { 8.4,  combat({
        attacker = snapFrom("str-speed-demon"),
        defender = snapFrom("def-the-rock", { mode = "defense", wasHidden = true }),
        outcome = "defender_destroyed", margin = 400, damage = 0, activePlayer = "opponent" }) },
    { 9.9,  function(c) c.snap("opp_shatter") end },
    { 10.5, function(c) c.snap("opp_destroyed") end },
    { 10.6, function() love.keypressed("space") end },
    { 10.7, combat({
        attacker = snapFrom("str-poacher"), defender = nil,
        outcome = "damage", margin = 0, damage = 800, activePlayer = "opponent" }) },
    { 12.8, function(c) c.snap("opp_open") end },
    { 12.9, function() love.keypressed("space") end },
    { 13.2, function(c) c.snap("dismissed") end },
    { 13.5, function(c) c.quit() end },
}

-- Trap activation: flash, flip, stamp, dust, full; then an opponent trap.
local function trapRec(rec) return function() require("scenes.match").debugOverlay("trap", rec) end end
S.trap = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  trapRec({ activator = "player", trapDef = defById("trap-offside"),
                      contextText = "The Poacher was caught offside!" }) },
    { 1.62, function(c) c.snap("flash") end },
    { 1.9,  function(c) c.snap("flip") end },
    { 2.2,  function(c) c.snap("stamp") end },
    { 2.45, function(c) c.snap("dust") end },
    { 3.3,  function(c) c.snap("full") end },
    { 3.4,  function() love.keypressed("space") end },
    { 3.5,  trapRec({ activator = "opponent", trapDef = defById("trap-red-card"),
                      contextText = "Your The Poacher was sent off!" }) },
    { 5.4,  function(c) c.snap("opponent") end },
    { 5.5,  function() love.keypressed("space") end },
    { 5.8,  function(c) c.snap("dismissed") end },
    { 6.0,  function(c) c.quit() end },
}

-- Pitched card for harness-built boards.
local function pitched(id, slotType, mode)
    return { definition = defById(id), mode = mode or "attack", exhausted = false, slotType = slotType }
end

-- Cover prompt (synthetic window, harness-only): the opponent striker attacks your empty
-- DEF slot; your midfielder can cover.
S.cover = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        local P, O = st.match.players.player.pitch, st.match.players.opponent.pitch
        P.midfielder = pitched("mid-box-to-box", "midfielder")
        O.strikers[1] = pitched("str-speed-demon", "striker")
        st.match.activePlayer = "opponent"
        st.coverWindow = {
            attackerSlot     = { type = "striker", index = 1 },
            emptySlot        = { type = "defender", index = 1 },
            eligibleCoverers = { { type = "midfielder", index = 0, card = P.midfielder } },
            attackerSnap     = snapFrom("str-speed-demon"),
        }
    end },
    { 1.62, function(c) c.snap("slide") end },
    { 2.0,  function()
        local hb = require("ui.overlay.promptpanel").coverHitboxes(store().coverWindow, 0)[1]
        move(hb.x + hb.w / 2, hb.y + hb.h / 2)
    end },
    { 2.4,  function(c) c.snap("panel") end },
    { 2.6,  function(c) c.quit() end },
}

-- Trap window (synthetic, harness-only): pre-attack with OFFSIDE + MANAGER'S CHALLENGE set.
S.trapwin = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        local P = st.match.players.player.pitch
        P.traps[1] = pitched("trap-offside", "trap", "defense")
        P.traps[2] = pitched("trap-managers-challenge", "trap", "defense")
        st.trapWindow = {
            type         = "pre_attack",
            attackerSlot = { type = "striker", index = 1 },
            defenderSlot = { type = "defender", index = 1 },
            traps        = { { card = P.traps[1], slotIndex = 1 }, { card = P.traps[2], slotIndex = 2 } },
            attackerSnap = snapFrom("str-poacher"),
            defenderSnap = snapFrom("def-the-rock"),
        }
    end },
    { 1.62, function(c) c.snap("slide") end },
    { 2.0,  function()
        local hb = require("ui.overlay.promptpanel").trapHitboxes(store().trapWindow, 0)[1]
        move(hb.x + hb.w / 2, hb.y + hb.h / 2)
    end },
    { 2.4,  function(c) c.snap("panel") end },
    { 2.6,  function(c) c.quit() end },
}

-- Scout reveal (synthetic, harness-only): flip, shown, shrinking, gone.
S.scout = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        require("scenes.match").debugOverlay("scout", pitched("keeper-iron-fists", "keeper", "defense"))
    end },
    { 1.75, function(c) c.snap("flip") end },
    { 2.4,  function(c) c.snap("shown") end },
    { 4.85, function(c) c.snap("shrink") end },
    { 5.2,  function(c) c.snap("gone") end },
    { 5.5,  function(c) c.quit() end },
}

-- Half time (harness-only: zero the opponent's LP and let the store end the half). The
-- ribbon plays, then the half-time screen: pick 2 cards (click + key), SWAP, pause over the
-- screen, KICK OFF, the SECOND HALF banner, then the pitch.
local function htCard(i)
    local HT = require("ui.overlay.halftime")
    local r = HT.cardRects(#hand())[i]
    return r.x + r.w / 2, r.y + r.h / 2
end
S.halftime = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        st.match.players.opponent.lp = 0
        st:_checkHalf()
    end },
    { 1.72, function(c) c.snap("slide") end },
    { 2.4,  function(c) c.snap("ribbon") end },
    { 5.3,  function(c) c.snap("screen") end },
    { 5.4,  function() click(htCard(2)) end },
    { 5.5,  function() love.keypressed("4") end },
    { 5.6,  function() move(center(require("ui.overlay.halftime").SWAP_BTN)) end },
    { 5.9,  function(c) c.snap("selected") end },
    { 6.0,  function() love.keypressed("s") end },
    { 6.1,  function() move(640, 120) end },
    { 6.7,  function(c) c.snap("swapped") end },
    { 6.8,  function() love.keypressed("escape") end },
    { 7.2,  function(c) c.snap("pause") end },
    { 7.3,  function() love.keypressed("escape") end },
    { 7.6,  function() love.keypressed("return") end },
    { 8.1,  function(c) c.snap("banner") end },
    { 10.0, function(c) c.snap("pitch") end },
    { 10.3, function(c) c.quit() end },
}

-- Victory (harness-only: you already won a half; win the second), then R to play again.
S.victory = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        st.match.players.player.halvesWon = 1
        st.match.players.player.totalDamageDealt = 4000
        st.match.players.opponent.lp = 0
        st:_checkHalf()
    end },
    { 1.62, function(c) c.snap("pop") end },
    { 2.6,  function(c) c.snap("win") end },
    { 2.7,  function() move(center(require("ui.overlay.matchend").PLAY_AGAIN)) end },
    { 3.0,  function(c) c.snap("hover") end },
    { 3.1,  function() love.keypressed("r") end },
    { 3.6,  function(c) c.snap("again") end },
    { 3.8,  function(c) c.quit() end },
}

-- Defeat (harness-only), then ESC to the main menu.
S.defeat = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        st.match.players.opponent.halvesWon = 1
        st.match.players.player.lp = 0
        st:_checkHalf()
    end },
    { 2.6, function(c) c.snap("loss") end },
    { 2.7, function() love.keypressed("escape") end },
    { 3.1, function(c) c.snap("home") end },
    { 3.3, function(c) c.quit() end },
}

-- Revealed cards (harness-only board): revealed defense cards are face-up with a DEF marker
-- for both sides; the opponent's unrevealed face-down card and trap stay hidden; the
-- opponent's revealed card zooms, the hidden one doesn't; the crown reads the revealed MID.
S.revealed = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        local P, O = st.match.players.player.pitch, st.match.players.opponent.pitch
        local function revealed(id, slotType)
            local c = pitched(id, slotType, "defense")
            c.revealed = true
            return c
        end
        P.defenders[1] = revealed("def-the-rock", "defender")
        P.defenders[2] = pitched("def-stopper", "defender", "defense")
        P.midfielder   = pitched("mid-box-to-box", "midfielder", "defense")
        -- Revealed keeper: face-up defense, must never show the flip ribbon.
        P.keeper       = revealed("keeper-iron-fists", "keeper")
        -- Revealed but exhausted: legal to flip in every other way, but exhausted right now.
        P.strikers[1]  = revealed("str-target-man", "striker")
        P.strikers[1].exhausted = true
        O.defenders[1] = revealed("def-destroyer", "defender")
        O.defenders[2] = pitched("def-libero", "defender", "defense")
        O.midfielder   = revealed("mid-deep-lying-playmaker", "midfielder")
        O.keeper       = revealed("keeper-iron-fists", "keeper")
        O.traps[1]     = pitched("trap-offside", "trap", "defense")
    end },
    { 1.9, function(c) c.snap("board") end },
    { 2.0, function() move(center(Layout.slot("opponent", "defender", 1))) end },
    { 2.6, function(c) c.snap("zoom") end },
    { 2.7, function() move(center(Layout.slot("opponent", "defender", 2))) end },
    { 3.3, function(c) c.snap("hidden") end },
    { 3.5, function(c) c.quit() end },
}

-- Midfield control through the real engine (harness-only board): your Box-to-Box (ATK 1800)
-- outpowers their Deep-Lying Playmaker (ATK 1500); re-running your draw phase on turn 2
-- draws the normal card plus the midfield card, with the banner and the toast.
S.midfield = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local m = store().match
        m.players.player.pitch.midfielder   = pitched("mid-box-to-box", "midfielder")
        m.players.opponent.pitch.midfielder = pitched("mid-deep-lying-playmaker", "midfielder")
        m.turn  = 2
        m.phase = "draw"      -- scenes/match.lua runs store:drawPhase() on the next update
    end },
    { 1.9, function(c) c.snap("banner") end },
    { 2.6, function(c) c.snap("toast") end },
    { 2.8, function(c) c.quit() end },
}

return S
