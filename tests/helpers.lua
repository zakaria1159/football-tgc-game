-- Builders for rules tests: the real engine, store and AI with hand-placed boards.
-- Not a test file (tests/run.lua only loads tests/test_*.lua).
local State = require("engine.state")
local Store = require("store.match")
local Resolver = require("engine.cards.resolver")

local H = {}

local DEFS = {}
for _, f in ipairs({ "keepers", "defenders", "midfielders", "strikers", "traps", "strategies" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do DEFS[d.id] = d end
end

-- Real card definition by id (traps, strategies).
function H.def(id) return assert(DEFS[id], "no card " .. id) end

local serial = 0
-- Field-card definition with exact stats, so rules tests don't depend on balance data.
function H.card(ctype, atk, def)
    serial = serial + 1
    return { id = "t-" .. ctype .. "-" .. serial, name = "Test " .. ctype .. " " .. serial,
             type = ctype, rarity = "common", stats = { atk = atk, def = def } }
end

-- n filler cards (distinct ids) for a deck.
function H.filler(n)
    local t = {}
    for i = 1, n do t[i] = H.card("defender", 100, 100) end
    return t
end

-- Match with empty boards and hands and a 10-card filler deck on each side.
-- opts: turn (2), half (1), phase ("attack"), active ("player").
function H.match(opts)
    opts = opts or {}
    local m = State.newMatch(H.filler(10), H.filler(10))
    for _, id in ipairs({ "player", "opponent" }) do
        m.players[id].hand = {}
        m.players[id].deck = H.filler(10)
    end
    m.turn         = opts.turn or 2
    m.half         = opts.half or 1
    m.phase        = opts.phase or "attack"
    m.activePlayer = opts.active or "player"
    return m
end

-- Put a pitched card on owner's board. slotType: keeper|defender|midfielder|striker|trap.
-- mode defaults to "attack" ("defense" for traps).
function H.place(m, owner, slotType, index, cardDef, mode)
    local pitch = m.players[owner].pitch
    local card  = State.newPitchedCard(cardDef, slotType,
        mode or (slotType == "trap" and "defense" or "attack"))
    if slotType == "keeper" then pitch.keeper = card
    elseif slotType == "midfielder" then pitch.midfielder = card
    elseif slotType == "defender" then pitch.defenders[index] = card
    elseif slotType == "striker" then pitch.strikers[index] = card
    elseif slotType == "trap" then table.insert(pitch.traps, card) end
    return card
end

-- Set a real trap (e.g. "trap-var") in owner's trap zone.
function H.trap(m, owner, id) return H.place(m, owner, "trap", nil, H.def(id), "defense") end

-- Put a card definition in owner's hand; returns it.
function H.give(m, owner, cardDef)
    table.insert(m.players[owner].hand, cardDef)
    return cardDef
end

-- Store around a prepared match (no startMatch shuffle).
function H.store(m)
    local s = Store.new()
    s.match = m
    return s
end

-- Log entries of one type, in order.
function H.events(m, eventType)
    local out = {}
    for _, e in ipairs(m.log) do if e.type == eventType then out[#out + 1] = e end end
    return out
end

-- Slot table shorthand: H.slot("striker", 1), H.slot("keeper").
function H.slot(slotType, index) return { type = slotType, index = index or 0 } end

-- Field-card definition with exact stats and one ability keyword (tests don't depend on
-- card data): H.kw("LINK_UP", "striker", 2150, 900).
function H.kw(keyword, ctype, atk, def)
    local c = H.card(ctype, atk, def)
    c.keyword     = keyword
    c.keywordName = Resolver.NAMES[keyword]
    return c
end

-- Payloads of the ability_triggered events, in order.
function H.triggers(m)
    local out = {}
    for _, e in ipairs(H.events(m, "ability_triggered")) do out[#out + 1] = e.payload end
    return out
end

return H
