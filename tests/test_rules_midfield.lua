local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- Start of turn 3 (draw phase). Midfielders given as { mode, atk, def } or nil.
local function setup(pMid, oMid, active)
    local m = H.match({ turn = 3, phase = "draw", active = active or "player" })
    if pMid then H.place(m, "player", "midfielder", 0, H.card("midfielder", pMid[2], pMid[3]), pMid[1]) end
    if oMid then H.place(m, "opponent", "midfielder", 0, H.card("midfielder", oMid[2], oMid[3]), oMid[1]) end
    return m, H.store(m)
end

T.test("midfield: the stronger midfielder draws 1 extra card after the normal draw", function()
    local m, s = setup({ "attack", 1800, 1500 }, { "attack", 1500, 1500 })
    s:drawPhase()
    T.eq(#m.players.player.hand, 2); T.eq(#m.players.player.deck, 8)
    local kinds = {}
    for _, e in ipairs(m.log) do
        if e.type == "card_drawn" or e.type == "midfield_control" then kinds[#kinds + 1] = e.type end
    end
    T.eq(table.concat(kinds, ","), "card_drawn,midfield_control,card_drawn")
    local mc = H.events(m, "midfield_control")[1].payload
    T.eq(mc.player, "player"); T.eq(mc.bonus, "draw"); T.eq(mc.myPow, 1800); T.eq(mc.oppPow, 1500)
end)

T.test("midfield: control no longer raises the summon limit", function()
    local m = H.match({ turn = 2, active = "opponent" })
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    Phases.endTurn(m)
    T.eq(m.players.player.nextTurnSummonLimit, nil)
end)

T.test("midfield: a face-down midfielder counts with its DEF", function()
    local m, s = setup({ "attack", 1800, 1500 }, { "defense", 1500, 1900 })
    s:drawPhase()
    T.eq(#m.players.player.hand, 1, "no extra card: 1900 DEF beats 1800 ATK")
    local m2, s2 = setup({ "attack", 1800, 1500 }, { "defense", 1500, 1900 }, "opponent")
    s2:drawPhase()
    T.eq(#m2.players.opponent.hand, 2, "the face-down side controls midfield")
end)

T.test("midfield: equal power or no midfielder gives no extra card", function()
    local m, s = setup({ "attack", 1500, 1500 }, { "attack", 1500, 1500 })
    s:drawPhase(); T.eq(#m.players.player.hand, 1)
    local m2, s2 = setup(nil, nil)
    s2:drawPhase(); T.eq(#m2.players.player.hand, 1)
    T.eq(#H.events(m2, "midfield_control"), 0)
end)

T.test("midfield: an empty deck just skips the extra card", function()
    local m, s = setup({ "attack", 1800, 1500 }, nil)
    m.players.player.deck = {}
    s:drawPhase()
    T.eq(#m.players.player.hand, 0)
    T.eq(#H.events(m, "midfield_control"), 0)  -- nothing drawn: no event, no banner
    T.eq(m.phase, "summon")
end)
