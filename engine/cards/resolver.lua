-- Card abilities (docs/superpowers/specs/2026-09-24-card-abilities-design.md).
-- Every field card has exactly one keyword (definition.keyword); traps and strategies keep
-- their `ability` field and have none. Card definitions only carry data (keyword,
-- keywordName, abilityText); the rules live here and the engine calls these hooks at fixed
-- points (engine/combat.lua, engine/phases.lua, store/match.lua).
--   Pure helpers read pitched cards and pitches only, never matchState.activePlayer, so the
--   AI can call them on the simulator's mirrored view.
--   on* hooks change the match; every ability that fires is logged through R.trigger as an
--   `ability_triggered` event { player, card, name, keyword, hidden, ... }.
local C       = require("engine.constants")
local State   = require("engine.state")
local Stamina = require("engine.stamina")

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

-- ── Tired (stamina, spec B1) ─────────────────────────────────────────────────

R.TIRED = "TIRED"   -- stat-part keyword of the Tired malus (not an ability: never logged)

-- Labels of stat-part keywords that aren't abilities.
R.PART_LABELS = { TIRED = "Tired" }

-- Display name of a stat part's keyword: an ability name, "Tired", or the keyword itself.
function R.partName(keyword)
    return R.NAMES[keyword] or R.PART_LABELS[keyword] or keyword
end

-- Tired malus of a card: −amount and its part while the card is Tired (0 stamina), else 0.
-- visibleOnly: a face-down, unrevealed card's stamina is hidden information (no malus).
function R.tiredPart(pitched, amount, visibleOnly)
    if not Stamina.tired(pitched) or (visibleOnly and R.hidden(pitched)) then return 0, nil end
    return -amount, R.part(-amount, pitched, R.TIRED)
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
        if p.keyword and p.keyword ~= R.TIRED then   -- Tired is no ability
            R.trigger(matchState, ownerId, p.pitched, p.keyword, { amount = p.amount }, result)
        end
    end
end

-- True when a stat part list (R.atkBonus / R.defBonus parts) has this keyword.
function R.firedIn(parts, keyword)
    for _, p in ipairs(parts or {}) do
        if p.keyword == keyword then return true end
    end
    return false
end

-- ── Stat bonuses ──────────────────────────────────────────────────────────────

-- Midfielder card bonus for striker-slot ATK (a midfielder-type card in the midfielder
-- slot): +200 in attack mode; Overlap +300 in attack mode; Engine +100 in either mode.
-- visibleOnly: a face-down, unrevealed midfielder gives nothing (its opponent's view).
-- Returns amount, part (a keyword part, or nil for the plain bonus or no bonus).
function R.midfieldAtkBonus(pitch, visibleOnly)
    local mid = pitch and pitch.midfielder
    if not mid or mid.definition.type ~= "midfielder" then return 0, nil end
    if visibleOnly and R.hidden(mid) then return 0, nil end
    local kw = R.keyword(mid)
    if kw == "ENGINE" then return A.ENGINE_ATK, R.part(A.ENGINE_ATK, mid, "ENGINE") end
    if mid.mode ~= "attack" then return 0, nil end
    if kw == "OVERLAP" then return A.OVERLAP_ATK, R.part(A.OVERLAP_ATK, mid, "OVERLAP") end
    return C.COMBAT.MIDFIELDER_CARD_ATK_BONUS, nil
end

-- Midfielder card bonus for defender-slot DEF: +200 in defense mode; Engine +100 in either
-- mode. Returns amount, part.
function R.midfieldDefBonus(pitch, visibleOnly)
    local mid = pitch and pitch.midfielder
    if not mid or mid.definition.type ~= "midfielder" then return 0, nil end
    if visibleOnly and R.hidden(mid) then return 0, nil end
    if R.has(mid, "ENGINE") then return A.ENGINE_DEF, R.part(A.ENGINE_DEF, mid, "ENGINE") end
    if mid.mode ~= "defense" then return 0, nil end
    return C.COMBAT.MIDFIELDER_CARD_DEF_BONUS, nil
end

-- ATK bonus of an attacking card.
--   ctx = { slotType, ownPitch, oppPitch, shot, keeper, visibleOnly }
--   striker slot: the midfielder card bonus (R.midfieldAtkBonus) and Link-up (+150 from
--   each other Link-up card on the attacker's pitch, any slot).
--   shots (any slot, strategy shots included): Instinct (+300 while the keeper is
--   exhausted) and Opportunist (+400 while an enemy defender slot is empty).
--   any slot: Tired (−C.STAMINA.TIRED_ATK at 0 stamina, R.tiredPart; a TIRED part).
-- Returns total, parts (keyword parts only).
function R.atkBonus(pitched, ctx)
    local total, parts = 0, {}
    local function add(amount, part)
        total = total + amount
        if part then parts[#parts + 1] = part end
    end
    if ctx.slotType == "striker" then
        add(R.midfieldAtkBonus(ctx.ownPitch, ctx.visibleOnly))
        for _, e in ipairs(R.fieldCards(ctx.ownPitch)) do
            local c = e.card
            if c ~= pitched and R.has(c, "LINK_UP") and not (ctx.visibleOnly and R.hidden(c)) then
                add(A.LINK_UP_ATK, R.part(A.LINK_UP_ATK, c, "LINK_UP"))
            end
        end
    end
    if ctx.shot then
        if R.has(pitched, "INSTINCT") and ctx.keeper and ctx.keeper.exhausted then
            add(A.INSTINCT_ATK, R.part(A.INSTINCT_ATK, pitched, "INSTINCT"))
        end
        if R.has(pitched, "OPPORTUNIST") and R.hasEmptyDefenderSlot(ctx.oppPitch) then
            add(A.OPPORTUNIST_ATK, R.part(A.OPPORTUNIST_ATK, pitched, "OPPORTUNIST"))
        end
    end
    add(R.tiredPart(pitched, C.STAMINA.TIRED_ATK, ctx.visibleOnly))   -- Tired (any slot)
    return total, parts
end

-- DEF bonus of a defending card.
--   ctx = { slotType, ownPitch, covering, visibleOnly }
--   defender slot: the midfielder card bonus (R.midfieldDefBonus) and Last man (+300 while
--   it is the only card in its owner's defender slots); covering: Counter-press (+300);
--   any slot: Tired (−C.STAMINA.TIRED_DEF at 0 stamina).
-- Returns total, parts.
function R.defBonus(pitched, ctx)
    local total, parts = 0, {}
    local function add(amount, part)
        total = total + amount
        if part then parts[#parts + 1] = part end
    end
    if ctx.slotType == "defender" then
        add(R.midfieldDefBonus(ctx.ownPitch, ctx.visibleOnly))
        if R.has(pitched, "LAST_MAN") then
            local n = 0
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if ctx.ownPitch and ctx.ownPitch.defenders and ctx.ownPitch.defenders[i] then n = n + 1 end
            end
            if n == 1 then add(A.LAST_MAN_DEF, R.part(A.LAST_MAN_DEF, pitched, "LAST_MAN")) end
        end
    end
    if ctx.covering and R.has(pitched, "COUNTER_PRESS") then
        add(A.COUNTER_PRESS_DEF, R.part(A.COUNTER_PRESS_DEF, pitched, "COUNTER_PRESS"))
    end
    add(R.tiredPart(pitched, C.STAMINA.TIRED_DEF, ctx.visibleOnly))   -- Tired (any slot)
    return total, parts
end

-- True when at least one defender slot of the pitch is empty.
function R.hasEmptyDefenderSlot(pitch)
    if not pitch then return false end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not (pitch.defenders and pitch.defenders[i]) then return true end
    end
    return false
end

-- Keeper line bonus of one active card in the defender slots: Bolt +500, else +300.
-- visibleOnly: a face-down, unrevealed Bolt card counts as a plain +300.
-- Returns amount, part.
function R.keeperLineBonus(pitched, visibleOnly)
    if R.has(pitched, "BOLT") and not (visibleOnly and R.hidden(pitched)) then
        return A.BOLT_LINE, R.part(A.BOLT_LINE, pitched, "BOLT")
    end
    return C.COMBAT.DEFENDER_BONUS, nil
end

-- Safe hands: +100 DEF for each save this keeper made this half (max +300). The keeper's
-- own DEF, so it also counts against a Penalty. pitched.saves counts saves
-- (engine/phases.lua _goalAttempt); a new half means a new pitch. Returns amount, part.
function R.keeperOwnBonus(keeper)
    if not R.has(keeper, "SAFE_HANDS") then return 0, nil end
    local n = math.min(A.SAFE_HANDS_MAX, A.SAFE_HANDS_PER_SAVE * (keeper.saves or 0))
    if n <= 0 then return 0, nil end
    return n, R.part(n, keeper, "SAFE_HANDS")
end

-- Fortress: penalties face this keeper's full effective DEF.
function R.penaltyFullDef(keeper)
    return R.has(keeper, "FORTRESS")
end

-- ── Rule hooks ────────────────────────────────────────────────────────────────

-- Clinical: a shot tie becomes a goal for C.ABILITY.CLINICAL_DAMAGE (Combat.resolveShot).
function R.clinical(shooter)
    return R.has(shooter, "CLINICAL")
end

-- Immovable: this card survives a tie (engine/phases.lua _doCombat).
function R.survivesTie(pitched)
    return R.has(pitched, "IMMOVABLE")
end

-- After a shot (engine/phases.lua _goalAttempt).
--   Clinical: the tie was turned into a goal (Combat.resolveShot sets result.clinical).
--   Punch clear: after this keeper's save, the shooter can't act on its owner's next turn
--   (pitched.lockedNextTurn, turned into cannotActNextTurn at the end of this turn).
function R.onShotResolved(matchState, shooterId, shooter, keeper, result)
    if result.clinical then R.trigger(matchState, shooterId, shooter, "CLINICAL", nil, result) end
    if result.outcome == "save" and R.has(keeper, "PUNCH_CLEAR") then
        shooter.lockedNextTurn = true
        R.trigger(matchState, State.other(shooterId), keeper, "PUNCH_CLEAR", nil, result)
    end
end

-- After a fight (declared attack, advance or cover), once destroyed cards are gone.
--   f = { attackerId, defenderId, attacker, defender, result }; result.attackerDestroyed /
--   result.defenderDestroyed say who is gone.
--   Hard tackle: an attacker that fought a Hard tackle card and survived is locked for its
--   owner's next turn.
--   Build-up: a Build-up card that destroyed the other card and survived draws its owner
--   1 card (nothing when the deck is empty).
function R.onFightResolved(matchState, f)
    local r = f.result
    if R.has(f.defender, "HARD_TACKLE") and not r.attackerDestroyed then
        f.attacker.lockedNextTurn = true
        R.trigger(matchState, f.defenderId, f.defender, "HARD_TACKLE", nil, r)
    end
    local function buildUp(card, ownerId, won)
        if not (won and R.has(card, "BUILD_UP")) then return end
        local drawn = State.drawCard(matchState, ownerId)
        if not drawn then return end
        R.trigger(matchState, ownerId, card, "BUILD_UP", nil, r)
        State.log(matchState, "card_drawn", { player = ownerId, card = drawn.id, source = "build_up" })
    end
    buildUp(f.attacker, f.attackerId, r.defenderDestroyed and not r.attackerDestroyed)
    buildUp(f.defender, f.defenderId, r.attackerDestroyed and not r.defenderDestroyed)
end

-- Offside cancelled an attack (engine/phases.lua Phases.cancelAttack). Hard tackle: when the
-- declared target is a Hard tackle card, the attacker is locked for its owner's next turn.
function R.onAttackCancelled(matchState, attackerId, attacker, target)
    if not R.has(target, "HARD_TACKLE") then return end
    attacker.lockedNextTurn = true
    R.trigger(matchState, State.other(attackerId), target, "HARD_TACKLE")
end

-- ── Attack hooks ──────────────────────────────────────────────────────────────

-- Pace: may attack on the turn it is summoned (attack mode only).
function R.canAttackWhenSummoned(pitched)
    return R.has(pitched, "PACE") and pitched.mode == "attack"
end

-- Through ball: the Through ball card on this pitch (any slot, any mode) while it is unused
-- this turn (pitch.throughBallUsed, cleared by Phases.endTurn), else nil.
function R.throughBall(pitch)
    if not pitch or pitch.throughBallUsed then return nil end
    for _, e in ipairs(R.fieldCards(pitch)) do
        if R.has(e.card, "THROUGH_BALL") then return e.card end
    end
    return nil
end

-- Aerial: Offside can't be activated against this card's attacks.
function R.immuneToOffside(attacker)
    return R.has(attacker, "AERIAL")
end

-- Beat the man: this card's attacks into empty slots can't be covered.
function R.uncoverable(attacker)
    return R.has(attacker, "BEAT_THE_MAN")
end

-- ── Turn hooks ────────────────────────────────────────────────────────────────

-- Press target on the enemy pitch: the defender-slot index of its face-up (attack or
-- revealed) card with the highest DEF (lowest index on a tie), else its first face-down
-- card; nil when there is none. Cards already pressed this turn are skipped.
function R.pressTarget(oppPitch)
    local best, bestDef = nil, -1
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = oppPitch.defenders[i]
        if c and not c.pressed and not R.hidden(c) then
            local d = c.definition.stats and c.definition.stats.def or 0
            if d > bestDef then best, bestDef = i, d end
        end
    end
    if best then return best end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = oppPitch.defenders[i]
        if c and not c.pressed then return i end
    end
    return nil
end

-- Summon hook (engine/phases.lua Phases._afterSummon), after the card is on the pitch.
--   Press: exhaust one enemy defender-slot card (R.pressTarget) for this turn, so it can't
--   cover; pitched.pressed marks it and Phases.endTurn clears both flags at this turn's end.
-- Returns true when Press fired (it costs its card stamina: Phases._afterSummon).
function R.onSummon(matchState, ownerId, pitched)
    if not R.has(pitched, "PRESS") then return false end
    local oppPitch = matchState.players[State.other(ownerId)].pitch
    local i = R.pressTarget(oppPitch)
    if not i then return false end
    local target = oppPitch.defenders[i]
    target.exhausted = true
    target.pressed   = true
    R.trigger(matchState, ownerId, pitched, "PRESS", { target = { type = "defender", index = i } })
    return true
end

-- Midfield control hook (engine/phases.lua _midfieldControl) for the player in control.
--   Metronome: a Metronome card in the midfielder slot gives +1 summon this turn
--   (matchState.bonusSummons, reset by Phases.endTurn).
function R.onMidfieldControl(matchState, playerId)
    local mid = matchState.players[playerId].pitch.midfielder
    if not R.has(mid, "METRONOME") then return end
    matchState.bonusSummons = (matchState.bonusSummons or 0) + A.METRONOME_SUMMONS
    R.trigger(matchState, playerId, mid, "METRONOME")
end

-- ── Cover hooks ───────────────────────────────────────────────────────────────

-- Extra cover permissions (the normal rule: the midfielder covers an empty defender slot,
-- any defender covers an empty midfielder slot). fromSlotType: the covering card's slot.
--   Intercept: a defender-slot card may cover an empty defender slot.
--   Sweeper: a defender- or midfielder-slot card may cover an empty defender or midfielder slot.
--   Off the line: the keeper may cover an empty defender slot.
function R.canCoverSlot(pitched, fromSlotType, emptySlotType)
    local kw = R.keyword(pitched)
    if kw == "INTERCEPT" then
        return fromSlotType == "defender" and emptySlotType == "defender"
    end
    if kw == "SWEEPER" then
        return (fromSlotType == "defender" or fromSlotType == "midfielder")
           and (emptySlotType == "defender" or emptySlotType == "midfielder")
    end
    if kw == "OFF_THE_LINE" then
        return fromSlotType == "keeper" and emptySlotType == "defender"
    end
    return false
end

-- Mode exception: may this card cover emptySlotType from fromSlotType while in defense mode
-- (face-down or revealed)? Intercept covering an empty defender slot, and the Off the line
-- keeper. Every other coverer needs attack mode. A face-down coverer is revealed.
function R.coversInDefense(pitched, fromSlotType, emptySlotType)
    local kw = R.keyword(pitched)
    if kw == "INTERCEPT" then return fromSlotType == "defender" and emptySlotType == "defender" end
    if kw == "OFF_THE_LINE" then return fromSlotType == "keeper" and emptySlotType == "defender" end
    return false
end

-- Covering stops the coverer acting on its owner's next turn, except Sweeper and Off the line.
function R.coverLocks(pitched)
    return not (R.has(pitched, "SWEEPER") or R.has(pitched, "OFF_THE_LINE"))
end

-- The keyword to announce when this card covers, or nil for a plain cover.
function R.coverKeyword(pitched, fromSlotType, emptySlotType)
    local kw = R.keyword(pitched)
    if kw == "SWEEPER" or kw == "OFF_THE_LINE" then return kw end
    if kw == "INTERCEPT" and fromSlotType == "defender" and emptySlotType == "defender" then return kw end
    return nil
end

return R
