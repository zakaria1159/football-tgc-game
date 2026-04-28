-- engine/gwent/state.lua
local C = require("engine.gwent.constants")

local State = {}

local _nextId = 0
local function nextId()
    _nextId = _nextId + 1
    return _nextId
end

-- ── Card constructors ─────────────────────────────────────────────────────────

function State.newHandCard(cardDef)
    return {
        definition = cardDef,
        instanceId = nextId(),
    }
end

-- basePower is final; Devour sets it to def.power + graveyardCount at play time.
function State.newPitchedCard(handCard, overridePower)
    local def = handCard.definition
    return {
        definition = def,
        basePower  = overridePower or def.power or 0,
        instanceId = nextId(),
    }
end

-- ── Power calculation ─────────────────────────────────────────────────────────

-- rowCards: all cards currently in the same row as pc (including pc itself).
-- isWeathered: true if a weather card is active on this row.
-- isHorned: true if Commander's Horn is active on this row for this player.
function State.effectivePower(pc, rowCards, isWeathered, isHorned)
    local def = pc.definition
    -- Heroes are always their base power — immune to everything.
    if def.hero then
        return pc.basePower
    end
    -- Weather reduces non-hero to 1.
    if isWeathered then
        return 1
    end

    -- Tight Bond multiplier
    local tbMult = 1
    if def.ability == "TIGHT_BOND" then
        local count = 0
        for _, c in ipairs(rowCards) do
            if c.definition.name == def.name then count = count + 1 end
        end
        if count > 1 then tbMult = count end
    end

    -- Commander's Horn doubles non-hero base power
    local hornMult = isHorned and 2 or 1

    -- Morale Boost: count other non-hero MB cards in row
    local morale = 0
    for _, c in ipairs(rowCards) do
        if c.instanceId ~= pc.instanceId
        and c.definition.ability == "MORALE_BOOST"
        and not c.definition.hero then
            morale = morale + 1
        end
    end

    return pc.basePower * tbMult * hornMult + morale
end

-- Sum effective power for one player.
-- match is needed for weather and horn state.
-- pid = "player" or "opponent"
function State.score(playerState, match, pid)
    local total = 0
    for _, row in ipairs({"attack", "midfield", "defense"}) do
        local cards     = playerState.pitch[row]
        local isWeathered = match.weather[row] ~= nil
        local isHorned  = match.hornRows[pid] and match.hornRows[pid][row] or false
        for _, pc in ipairs(cards) do
            local power = State.effectivePower(pc, cards, isWeathered, isHorned)
            -- FOG_BONUS: +2 if this card has FOG_BONUS and fog is active on midfield
            -- and this card's own row is NOT weathered (so it isn't already capped at 1)
            if pc.definition.ability == "FOG_BONUS"
            and not pc.definition.hero
            and not isWeathered
            and match.weather["midfield"] ~= nil then
                power = power + 2
            end
            total = total + power
        end
    end
    return total
end

-- ── Pitch constructor ─────────────────────────────────────────────────────────

function State.newPitch()
    return { attack = {}, midfield = {}, defense = {} }
end

-- ── Match constructor ─────────────────────────────────────────────────────────

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function buildPlayer(deckDef)
    local deck = {}
    for _, c in ipairs(deckDef.cards) do table.insert(deck, c) end
    shuffle(deck)
    local hand = {}
    for _ = 1, C.STARTING_HAND_SIZE do
        if #deck > 0 then
            table.insert(hand, State.newHandCard(table.remove(deck, 1)))
        end
    end
    return {
        hand      = hand,
        deck      = deck,
        graveyard = {},
        pitch     = State.newPitch(),
        leader    = deckDef.leader,
        faction   = deckDef.faction,
    }
end

function State.newMatch(playerDeckDef, opponentDeckDef)
    return {
        half         = 1,
        activePlayer = "player",
        phase        = "mulligan",
        winner       = nil,
        halvesWon    = { player = 0, opponent = 0 },
        passed       = { player = false, opponent = false },
        leaderUsed   = { player = false, opponent = false },
        -- Weather is global per row (affects both sides).
        -- Values: "FROST" | "FOG" | "RAIN" | nil
        weather      = { attack = nil, midfield = nil, defense = nil },
        -- Horn is per player per row. Persists until end of half.
        hornRows     = {
            player   = { attack = false, midfield = false, defense = false },
            opponent = { attack = false, midfield = false, defense = false },
        },
        mulliganLeft = { player = C.MULLIGAN_START, opponent = C.MULLIGAN_START },
        players = {
            player   = buildPlayer(playerDeckDef),
            opponent = buildPlayer(opponentDeckDef),
        },
        -- Pending interactive action (Medic target, Decoy target, etc.)
        -- { type = "medic_choose"|"decoy_choose"|"agility_choose"|"horn_choose",
        --   pid = "player"|"opponent", sourceInstanceId = n, ... }
        pendingAction = nil,
        log = {},
    }
end

return State
