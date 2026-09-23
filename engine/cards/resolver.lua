-- Card abilities (docs/superpowers/specs/2026-09-24-card-abilities-design.md).
-- Every field card has exactly one keyword (definition.keyword); traps and strategies keep
-- their `ability` field and have none. Card definitions only carry data (keyword,
-- keywordName, abilityText); the rules live here and the engine calls these hooks at fixed
-- points (engine/combat.lua, engine/phases.lua, store/match.lua).
--   Pure helpers read pitched cards and pitches only, never matchState.activePlayer, so the
--   AI can call them on the simulator's mirrored view.
--   on* hooks change the match; every ability that fires is logged through R.trigger as an
--   `ability_triggered` event { player, card, name, keyword, hidden, ... }.
local C     = require("engine.constants")
local State = require("engine.state")

local A = C.ABILITY

local R = {}

-- Keyword ids in the spec's order (strikers, midfielders, defenders, keepers).
R.ORDER = {
    "CLINICAL", "AERIAL", "PACE", "LINK_UP", "INSTINCT", "OPPORTUNIST", "PRESS", "BEAT_THE_MAN",
    "ENGINE", "METRONOME", "COUNTER_PRESS", "THROUGH_BALL", "OVERLAP",
    "IMMOVABLE", "LAST_MAN", "BOLT", "HARD_TACKLE", "INTERCEPT", "BUILD_UP", "SWEEPER",
    "FORTRESS", "PUNCH_CLEAR", "OFF_THE_LINE", "SAFE_HANDS",
}

-- Display names (definition.keywordName).
R.NAMES = {
    CLINICAL = "Clinical", AERIAL = "Aerial", PACE = "Pace", LINK_UP = "Link-up",
    INSTINCT = "Instinct", OPPORTUNIST = "Opportunist", PRESS = "Press",
    BEAT_THE_MAN = "Beat the man",
    ENGINE = "Engine", METRONOME = "Metronome", COUNTER_PRESS = "Counter-press",
    THROUGH_BALL = "Through ball", OVERLAP = "Overlap",
    IMMOVABLE = "Immovable", LAST_MAN = "Last man", BOLT = "Bolt", HARD_TACKLE = "Hard tackle",
    INTERCEPT = "Intercept", BUILD_UP = "Build-up", SWEEPER = "Sweeper",
    FORTRESS = "Fortress", PUNCH_CLEAR = "Punch clear", OFF_THE_LINE = "Off the line",
    SAFE_HANDS = "Safe hands",
}

-- ── Reading cards ─────────────────────────────────────────────────────────────

-- Keyword id of a pitched card, or nil.
function R.keyword(pitched)
    return pitched and pitched.definition and pitched.definition.keyword or nil
end

-- True when the pitched card has this keyword.
function R.has(pitched, keyword)
    return pitched ~= nil and R.keyword(pitched) == keyword
end

-- True for a face-down card that has not been revealed (hidden from its opponent).
function R.hidden(pitched)
    return pitched ~= nil and pitched.mode == "defense" and not pitched.revealed
end

-- Every card on a pitch as { card, slotType, index }: keeper, defenders, midfielder,
-- strikers. Numeric loops: a slot may be empty in front of an occupied one.
function R.fieldCards(pitch)
    local out = {}
    if not pitch then return out end
    if pitch.keeper then out[#out + 1] = { card = pitch.keeper, slotType = "keeper", index = 0 } end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders and pitch.defenders[i]
        if c then out[#out + 1] = { card = c, slotType = "defender", index = i } end
    end
    if pitch.midfielder then
        out[#out + 1] = { card = pitch.midfielder, slotType = "midfielder", index = 0 }
    end
    for i = 1, C.PITCH.MAX_STRIKERS do
        local c = pitch.strikers and pitch.strikers[i]
        if c then out[#out + 1] = { card = c, slotType = "striker", index = i } end
    end
    return out
end

-- A stat part: `amount` added by `keyword` on the card `pitched` (the source of the bonus).
function R.part(amount, pitched, keyword)
    return { keyword = keyword, amount = amount, pitched = pitched,
             card = pitched and pitched.definition or nil }
end

-- ── Events ────────────────────────────────────────────────────────────────────

-- Logs one ability that fired. ownerId owns `pitched` (the card with the ability).
-- extra: more payload fields. result (optional): the attack / shot result; the keyword is
-- added to result.abilities for the combat overlay.
function R.trigger(matchState, ownerId, pitched, keyword, extra, result)
    local d = pitched and pitched.definition or {}
    local payload = { player = ownerId, card = d.id, name = d.name, keyword = keyword,
                      hidden = R.hidden(pitched) }
    for k, v in pairs(extra or {}) do payload[k] = v end
    State.log(matchState, "ability_triggered", payload)
    if result then
        result.abilities = result.abilities or {}
        result.abilities[#result.abilities + 1] = keyword
    end
end

-- Logs every keyword part of a stat (parts from R.atkBonus / R.defBonus / keeper DEF).
function R.logParts(matchState, ownerId, parts, result)
    for _, p in ipairs(parts or {}) do
        if p.keyword then
            R.trigger(matchState, ownerId, p.pitched, p.keyword, { amount = p.amount }, result)
        end
    end
end

return R
