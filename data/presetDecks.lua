local keepers    = require("engine.cards.definitions.keepers")
local defenders  = require("engine.cards.definitions.defenders")
local midfielders = require("engine.cards.definitions.midfielders")
local strikers   = require("engine.cards.definitions.strikers")
local traps      = require("engine.cards.definitions.traps")
local strategies = require("engine.cards.definitions.strategies")

local function find(list, id)
    for _, c in ipairs(list) do if c.id == id then return c end end
    error("Card not found: " .. id)
end

local function rep(card, n)
    local t = {}
    for _ = 1, n do table.insert(t, card) end
    return t
end

local function concat(...)
    local out = {}
    for _, t in ipairs({...}) do for _, v in ipairs(t) do table.insert(out, v) end end
    return out
end

local Decks = {}

-- ── Tiki-Taka (40 cards) ─────────────────────────────────────────────────────
-- Possession-focused: creative midfielders, agile strikers, solid defence.
Decks.tikitaka = {
    name  = "The Beautiful Game",
    cards = concat(
        -- Field (29)
        rep(find(keepers,    "keeper-sweeper-keeper"),    1),
        rep(find(keepers,    "keeper-iron-fists"),        1),
        rep(find(keepers,    "keeper-reliable-hands"),    1),
        rep(find(defenders,  "def-ball-playing"),         3),
        rep(find(defenders,  "def-the-rock"),             2),
        rep(find(defenders,  "def-libero"),               2),
        rep(find(defenders,  "def-pressing-back"),        2),
        rep(find(midfielders,"mid-creative-playmaker"),   2),
        rep(find(midfielders,"mid-deep-lying-playmaker"), 1),
        rep(find(midfielders,"mid-box-to-box"),           2),
        rep(find(strikers,   "str-poacher"),              3),
        rep(find(strikers,   "str-clinical-finisher"),    2),
        rep(find(strikers,   "str-complete-forward"),     3),
        rep(find(strikers,   "str-fox-in-the-box"),       1),
        rep(find(strikers,   "str-speed-demon"),          2),
        rep(find(midfielders,"mid-pressing-monster"),      1),
        -- Traps (6)
        rep(find(traps, "trap-var"),                      1),
        rep(find(traps, "trap-offside"),                  2),
        rep(find(traps, "trap-red-card"),                 1),
        rep(find(traps, "trap-managers-challenge"),       1),
        rep(find(traps, "trap-last-defender-foul"),       1),
        -- Strategies (5)
        rep(find(strategies, "strat-direct-free-kick"),   1),
        rep(find(strategies, "strat-penalty"),            1),
        rep(find(strategies, "strat-scout-report"),       1),
        rep(find(strategies, "strat-time-wasting"),       1),
        rep(find(strategies, "strat-substitution"),       1)
    ),
}

-- ── Long Ball (40 cards) ──────────────────────────────────────────────────────
-- Direct power: tall strikers, solid keeper, pressure traps.
Decks.longball = {
    name  = "Direct Football",
    cards = concat(
        -- Field (31)
        rep(find(keepers,    "keeper-reliable-hands"),    2),
        rep(find(keepers,    "keeper-iron-fists"),        1),
        rep(find(defenders,  "def-stopper"),              2),
        rep(find(defenders,  "def-destroyer"),            3),
        rep(find(defenders,  "def-pressing-back"),        3),
        rep(find(defenders,  "def-the-rock"),             1),
        rep(find(midfielders,"mid-direct-support"),       3),
        rep(find(midfielders,"mid-box-to-box"),           2),
        rep(find(strikers,   "str-target-man"),           3),
        rep(find(strikers,   "str-speed-demon"),          3),
        rep(find(strikers,   "str-pacy-winger"),          3),
        rep(find(strikers,   "str-pressing-forward"),     2),
        rep(find(strikers,   "str-clinical-finisher"),    2),  -- +2
        rep(find(defenders,  "def-libero"),               1),  -- +1
        -- Traps (5)
        rep(find(traps, "trap-offside"),                  2),
        rep(find(traps, "trap-red-card"),                 2),
        rep(find(traps, "trap-last-defender-foul"),       1),
        -- Strategies (4)
        rep(find(strategies, "strat-direct-free-kick"),   1),
        rep(find(strategies, "strat-penalty"),            1),
        rep(find(strategies, "strat-time-wasting"),       1),
        rep(find(strategies, "strat-substitution"),       1)
    ),
}

-- ── Catenaccio (40 cards) ────────────────────────────────────────────────────
-- Defensive fortress: shut-out traps, counter-attack strategies.
Decks.catenaccio = {
    name  = "The Wall",
    cards = concat(
        -- Field (31)
        rep(find(keepers,    "keeper-the-wall"),          1),
        rep(find(keepers,    "keeper-iron-fists"),        2),
        rep(find(keepers,    "keeper-reliable-hands"),    1),
        rep(find(defenders,  "def-the-rock"),             2),
        rep(find(defenders,  "def-catenaccio-anchor"),    2),
        rep(find(defenders,  "def-stopper"),              2),
        rep(find(defenders,  "def-destroyer"),            2),
        rep(find(defenders,  "def-pressing-back"),        2),
        rep(find(midfielders,"mid-box-to-box"),           3),
        rep(find(midfielders,"mid-pressing-monster"),     3),
        rep(find(strikers,   "str-fox-in-the-box"),       2),
        rep(find(strikers,   "str-clinical-finisher"),    2),
        rep(find(strikers,   "str-poacher"),              3),
        rep(find(strikers,   "str-speed-demon"),          1),  -- +1
        rep(find(defenders,  "def-libero"),               2),  -- +2
        rep(find(midfielders,"mid-direct-support"),       1),  -- +1
        -- Traps (6)
        rep(find(traps, "trap-var"),                      1),
        rep(find(traps, "trap-offside"),                  2),
        rep(find(traps, "trap-red-card"),                 1),
        rep(find(traps, "trap-last-defender-foul"),       1),
        rep(find(traps, "trap-managers-challenge"),       1),
        -- Strategies (3)
        rep(find(strategies, "strat-direct-free-kick"),   1),
        rep(find(strategies, "strat-scout-report"),       1),
        rep(find(strategies, "strat-substitution"),       1)
    ),
}

return Decks
