local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local Card   = require("ui.card")
local Toasts = require("ui.match.toasts")

local OWN = { isOwnTurn = true, phase = "summon" }

local function pc(mode, revealed)
    return { definition = { type = "defender", stats = { atk = 900, def = 1500 } },
             mode = mode, revealed = revealed, slotType = "defender" }
end

T.test("canSwitch: defense → attack and attack → defense in the owner's summon phase", function()
    T.eq(Phases.canSwitch(pc("defense"), "defender", OWN), "attack")
    T.eq(Phases.canSwitch(pc("defense", true), "defender", OWN), "attack")
    T.eq(Phases.canSwitch(pc("attack"), "defender", OWN), "defense")
    T.eq(Phases.canSwitch(pc("attack"), "striker", OWN), "defense")
    T.eq(Phases.canSwitch(pc("attack"), "midfielder", OWN), "defense")
end)

T.test("canSwitch: never keepers or traps, nor a card played, switched, attacking or exhausted this turn", function()
    T.eq(Phases.canSwitch(nil, "defender", OWN), nil)
    T.eq(Phases.canSwitch(pc("defense", true), "keeper", OWN), nil)
    T.eq(Phases.canSwitch(pc("attack"), "keeper", OWN), nil)
    local trap = pc("defense"); trap.slotType = "trap"
    T.eq(Phases.canSwitch(trap, "trap", OWN), nil)
    for _, flag in ipairs({ "summonedThisTurn", "modeChanged", "usedAsAttacker", "exhausted" }) do
        local c = pc("attack"); c[flag] = true
        local to, why = Phases.canSwitch(c, "defender", OWN)
        T.eq(to, nil, flag); T.ok(type(why) == "string", flag .. " reason")
    end
end)

T.test("canSwitch: only on the owner's own turn, in the summon phase, outside the break", function()
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = false, phase = "summon" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = true, phase = "attack" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = true, phase = "draw" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender",
        { isOwnTurn = true, phase = "summon", halfTimeBreak = true }), nil)
end)

T.test("switch attack → defense: face-up defense, logged, once per turn", function()
    local m = H.match({ phase = "summon" })
    local c = H.place(m, "player", "striker", 1, H.card("striker", 2000, 600))
    local s = H.store(m)
    T.eq(s:changeMode("striker", 1), true)
    T.eq(c.mode, "defense"); T.eq(c.revealed, true); T.eq(c.modeChanged, true)
    local e = H.events(m, "card_played")
    T.eq(#e, 1); T.eq(e[1].payload.action, "mode_change"); T.eq(e[1].payload.mode, "defense")
    local ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "already switched this turn")
    T.eq(c.mode, "defense")
end)

T.test("switched to defense: it can't attack, and it gives up no LP when destroyed", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1500))
    local s = H.store(m)
    T.eq(s:changeMode("defender", 1), true)
    m.phase = "attack"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 600))
    local ok, err = Phases.validateAttack(m, H.slot("defender", 1), H.slot("striker", 1))
    T.eq(ok, false); T.eq(err, "card is in defense mode")
    -- The opponent's turn: its striker destroys the face-up defense card, no battle damage.
    m.activePlayer = "opponent"
    local lp = m.players.player.lp
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(m.players.player.lp, lp)
    T.eq(m.players.player.pitch.defenders[1], nil)
end)

T.test("switched to defense: its owner may flip it back to attack on their next turn", function()
    local m = H.match({ phase = "summon" })
    local c = H.place(m, "player", "midfielder", 0, H.card("midfielder", 1600, 1500))
    local s = H.store(m)
    T.eq(s:changeMode("midfielder", 0), true)
    Phases.endTurn(m)           -- the player's turn ends
    Phases.endTurn(m)           -- the opponent's turn ends
    m.phase = "summon"
    T.eq(c.modeChanged, false)
    T.eq(s:changeMode("midfielder", 0), true)
    T.eq(c.mode, "attack")
end)

T.test("switch refusals through the store: keeper, played this turn, wrong phase", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "attack")
    local s = H.store(m)
    local ok, err = s:changeMode("keeper", 0)
    T.eq(ok, false); T.eq(err, "keepers and traps never change position")
    local c = H.give(m, "player", H.card("striker", 2000, 600))
    T.eq(s:summonCard(c.id, "striker", 1, "attack"), true)
    ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "played this turn: switch it next turn")
    m.phase = "attack"
    ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "wrong phase")
end)

T.test("switch ribbon: FLIP UP, TO ATTACK, TO DEFENSE — or nothing when the rule says no", function()
    T.eq(Card.switchLabel(pc("defense"), "defender", OWN), "FLIP UP")
    T.eq(Card.switchLabel(pc("defense", true), "defender", OWN), "TO ATTACK")
    T.eq(Card.switchLabel(pc("attack"), "defender", OWN), "TO DEFENSE")
    T.eq(Card.switchLabel(pc("defense", true), "keeper", OWN), nil)
    local fresh = pc("attack"); fresh.summonedThisTurn = true
    T.eq(Card.switchLabel(fresh, "striker", OWN), nil)
    T.eq(Card.switchLabel(pc("attack"), "striker", { isOwnTurn = false, phase = "summon" }), nil)
end)

T.test("toasts: a switch to defense says so", function()
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "player", action = "mode_change",
        mode = "defense" } })), "You switched a card to defense")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "opponent", action = "mode_change",
        mode = "attack" } })), "Opp flipped a card face-up")
end)
