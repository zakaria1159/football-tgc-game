local Combat = require("engine.combat")
local C      = require("engine.constants")
local Phases = require("engine.phases")
local State  = require("engine.state")
local Resolver = require("engine.cards.resolver")

local AI = {}

-- ── Turn planning ─────────────────────────────────────────────────────────────

function AI.planTurn()
    return {
        { type = "draw" },
        { type = "planSummons" },   -- lazy: evaluated after draw so drawn card is included
        { type = "startAttack" },
        { type = "planStrategy" },  -- lazy: before attacks exhaust strikers
        { type = "planAttacks" },   -- lazy: one attack at a time, reacts to live pitch state
        { type = "endTurn" },
    }
end

-- Returns (done, extraActions, attackErr); attackErr is set when an attack was refused.
-- During a half-time break the AI does nothing (the store would refuse anyway).
function AI.executeAction(store, action)
    if store.match and store.match.halfTimeBreak then return false, nil, "half-time" end
    local difficulty = store.aiDifficulty or "medium"

    if action.type == "draw" then
        store:drawPhase()

    elseif action.type == "planSummons" then
        -- Evaluated NOW so the drawn card is included.
        local summons = AI._planSummons(store.match)
        return false, summons

    elseif action.type == "summon" then
        store:summonCard(action.cardId, action.slotType, action.slotIndex, action.mode)

    elseif action.type == "flip" then
        -- Face-up defence -> attack mode (Phases.changeMode). Refused: tag the card so
        -- _planFlips doesn't plan the same flip again this turn.
        local ok, err = store:changeMode(action.slotType, action.slotIndex)
        if not ok then
            local card = Phases._getSlot(store.match.players.opponent.pitch,
                                         { type = action.slotType, index = action.slotIndex })
            if card then card.aiRefusedFlipTag = AI.planTag(store.match) end
            return false, nil, err or "flip refused"
        end

    elseif action.type == "setTrap" then
        store:summonCard(action.cardId, "trap", 0, "defense")

    elseif action.type == "playStrategy" then
        store:playStrategy(action.cardId)

    elseif action.type == "startAttack" then
        store:startAttackPhase()

    elseif action.type == "planStrategy" then
        local strat = AI._pickStrategy(store.match, difficulty)
        return false, strat and { strat } or {}

    elseif action.type == "planAttacks" then
        -- Plan ONE attack at a time so each attacker reacts to the actual pitch state
        -- (e.g. second striker targets exposed keeper after first striker cleared a defender).
        local atk = AI._planNextAttack(store.match, difficulty)
        if atk then
            -- Inject: execute this attack, then replan again
            return false, { atk, { type = "planAttacks" } }
        end
        return false, {}

    elseif action.type == "attack" then
        local _, err = store:declareAttack(action.attackerSlot, action.defenderSlot)
        if err then
            -- Refused: don't plan this attacker again this turn (planAttacks would
            -- otherwise pick the same attack forever).
            local card = Phases._getSlot(store.match.players.opponent.pitch, action.attackerSlot)
            if card then card.aiRefusedTag = AI.planTag(store.match) end
            return false, nil, err
        end

    elseif action.type == "endTurn" then
        store:endTurn()
        return true, nil
    end
    return false, nil
end

-- ── Cover decision ────────────────────────────────────────────────────────────

-- What letting this attack through would cost the defending side (defenderId): the LP of
-- the goal it scores, or of the fight it wins at the next occupied line, and whether that
-- fight costs a card. The defending side knows its own face-down cards.
-- Returns lp, losesCard.
function AI.letThroughCost(match, defenderId, attackerSlot, emptySlot)
    local aPitch   = match.players[State.other(defenderId)].pitch
    local dPitch   = match.players[defenderId].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if not attacker then return 0, false end
    local nextSlot = Phases._nextOccupiedLine(dPitch, emptySlot)
    if not nextSlot or nextSlot.type == "keeper" then
        if attackerSlot.type == "midfielder" then return 0, false end   -- can't shoot
        local r = Combat.resolveShot(attacker, dPitch.keeper, dPitch, aPitch, false, attackerSlot.type)
        return r.damage or 0, false
    end
    local target = Phases._getSlot(dPitch, nextSlot)
    local r = Combat.resolve(attacker, target, attackerSlot.type, nextSlot.type, aPitch, dPitch)
    if r.outcome == "defender_destroyed" then
        return target.mode == "defense" and 0 or r.margin, true
    elseif r.outcome == "tie" then
        return 0, not Resolver.survivesTie(target)
    end
    return 0, false
end

-- Cover decision. Easy never covers. Medium and hard cover when a coverer wins the fight,
-- or when letting the attack through would cost LP or a card: a lost cover is a last-ditch
-- tackle (the coverer is only exhausted and the attack stops). Coverer preference:
--   1. one that wins (an Immovable tie counts);  2. a loser covering doesn't lock (Sweeper,
--   Off the line);  3. the lowest-value loser (ATK + DEF);  4. a tie that trades cards.
-- The Off the line keeper covers only when no other card can.
function AI.decideCover(store)
    local cw = store.coverWindow
    if not cw or #cw.eligibleCoverers == 0 then return nil end

    local match      = store.match
    local activeId   = match.activePlayer
    local defenderId = State.other(activeId)
    if match.coverUsed[defenderId] then return nil end

    local difficulty = store.aiDifficulty or "medium"
    if difficulty == "easy" then return nil end

    local aPitch   = match.players[activeId].pitch
    local ownPitch = match.players[defenderId].pitch
    local attacker = Phases._getSlot(aPitch, cw.attackerSlot)
    if not attacker then return nil end

    local fieldCoverers = false
    for _, cov in ipairs(cw.eligibleCoverers) do
        if cov.type ~= "keeper" then fieldCoverers = true end
    end

    local function value(card)
        local st = card.definition.stats or {}
        return (st.atk or 0) + (st.def or 0)
    end

    local best, bestRank, bestValue
    for _, cov in ipairs(cw.eligibleCoverers) do
        if cov.type ~= "keeper" or not fieldCoverers then
            local r = Combat.resolve(attacker, cov.card, cw.attackerSlot.type, cov.type,
                                     aPitch, ownPitch, { covering = true })
            local rank
            if r.outcome == "attacker_exhausted"
               or (r.outcome == "tie" and Resolver.survivesTie(cov.card)) then rank = 1
            elseif r.outcome == "defender_destroyed" then          -- last-ditch tackle
                rank = Resolver.coverLocks(cov.card) and 3 or 2
            else rank = 4 end                                       -- a tie: both destroyed
            local v = value(cov.card)
            if not best or rank < bestRank or (rank == bestRank and v < bestValue) then
                best, bestRank, bestValue = cov, rank, v
            end
        end
    end
    if not best then return nil end

    if bestRank > 1 then
        local lp, losesCard = AI.letThroughCost(match, defenderId, cw.attackerSlot, cw.emptySlot)
        if lp <= 0 and not losesCard then return nil end
    end
    return { type = best.type, index = best.index }
end

-- ── Summon planning ───────────────────────────────────────────────────────────

function AI._planSummons(match)
    local player     = match.players.opponent
    local pitch      = player.pitch
    -- Real limit (Time Wasting sets 1) minus the summons already made this turn
    local limit      = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                     + (match.bonusSummons or 0)   -- Metronome
    local summonLeft = limit - (match.summonCount or 0)
    local actions = {}

    local used = {
        keeper     = pitch.keeper ~= nil,
        defenders  = {},
        midfielder = pitch.midfielder ~= nil,
        strikers   = {},
    }
    for i = 1, C.PITCH.MAX_DEFENDERS do used.defenders[i] = pitch.defenders[i] ~= nil end
    for i = 1, C.PITCH.MAX_STRIKERS  do used.strikers[i]  = pitch.strikers[i]  ~= nil end
    -- Cover bookkeeping for _pickBestSlot / _planFlips: does a ready face-up card already
    -- cover an empty defender slot?
    used.coverer = AI._hasDefenderCoverer(pitch)

    -- Separate hand into groups
    local hand = {}
    for _, c in ipairs(player.hand) do table.insert(hand, c) end

    -- Press: with a face-up enemy defender to press, a Press card goes first in its group.
    local pressBoost = false
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = match.players.player.pitch.defenders[i]
        if d and (d.mode == "attack" or d.revealed) then pressBoost = true end
    end
    local function value(c)
        local v = (c.type == "striker" or c.type == "midfielder")
                  and (c.stats and c.stats.atk or 0)
                   or (c.stats and c.stats.def or 0)
        if pressBoost and c.keyword == "PRESS" then v = v + 10000 end
        return v
    end

    -- Priority: keeper > striker (by ATK) > midfielder (by ATK) > defender (by DEF) > others
    local typePri = { keeper=5, striker=4, midfielder=3, defender=2, trap=1, strategy=0 }
    table.sort(hand, function(a, b)
        local ap = typePri[a.type] or 0
        local bp = typePri[b.type] or 0
        if ap ~= bp then return ap > bp end
        return value(a) > value(b)
    end)

    -- Set traps first (free, no summon cost)
    local trapSlotsUsed = #pitch.traps
    for _, cardDef in ipairs(hand) do
        if cardDef.type == "trap" and trapSlotsUsed < C.PITCH.MAX_TRAPS then
            table.insert(actions, { type = "setTrap", cardId = cardDef.id })
            trapSlotsUsed = trapSlotsUsed + 1
        end
    end

    -- Place field cards
    for _, cardDef in ipairs(hand) do
        if summonLeft <= 0 then break end
        if cardDef.type == "trap" or cardDef.type == "strategy" then goto continue end

        if cardDef.type == "keeper" then
            if not used.keeper then
                table.insert(actions, {
                    type = "summon", cardId = cardDef.id,
                    slotType = "keeper", slotIndex = 0, mode = "defense",
                })
                used.keeper = true
                summonLeft  = summonLeft - 1
            end
        else
            local slot, mode = AI._pickBestSlot(cardDef, used)
            if slot then
                table.insert(actions, {
                    type = "summon", cardId = cardDef.id,
                    slotType = slot.slotType, slotIndex = slot.slotIndex, mode = mode,
                })
                if slot.slotType == "striker"    then used.strikers[slot.slotIndex]  = true
                elseif slot.slotType == "midfielder" then used.midfielder              = true
                elseif slot.slotType == "defender"   then used.defenders[slot.slotIndex] = true
                end
                if (mode == "attack" and (slot.slotType == "midfielder"
                   or (slot.slotType == "defender" and AI._coverSpecialist(cardDef))))
                   or (slot.slotType == "defender" and cardDef.keyword == "INTERCEPT") then
                    used.coverer = true   -- Intercept covers face-down too
                end
                summonLeft = summonLeft - 1
            end
        end

        ::continue::
    end

    -- Keeper substitution with a summon to spare, after the normal priorities.
    if summonLeft > 0 and pitch.keeper then
        local swap = AI._planKeeperSwap(match)
        if swap then
            table.insert(actions, swap)
            summonLeft = summonLeft - 1
        end
    end

    -- Flips after the summons, so they see the slots this turn's summons fill.
    for _, f in ipairs(AI._planFlips(match, used)) do table.insert(actions, f) end

    return actions
end

-- Keeper substitution heuristic. A keeper's value for this match:
--   base DEF, +FORTRESS_VS_PENALTY when it has Fortress and the enemy has played a Penalty
--   this match (from the log: the only Penalty evidence the AI can see), and for the
--   keeper in goal +SAFE_HANDS_SAVE per Safe hands save it already made (lost on a swap).
-- Swap for the best keeper in hand when it beats the current one by KEEPER_SWAP_MARGIN.
AI.KEEPER_SWAP_MARGIN   = 100
AI.FORTRESS_VS_PENALTY  = 200
AI.SAFE_HANDS_SAVE      = 100

function AI._keeperValue(def, enemyPenalties, saves)
    local v = def.stats and def.stats.def or 0
    if def.keyword == "FORTRESS" and enemyPenalties > 0 then v = v + AI.FORTRESS_VS_PENALTY end
    if def.keyword == "SAFE_HANDS" then v = v + AI.SAFE_HANDS_SAVE * (saves or 0) end
    return v
end

-- The keeper-swap summon action, or nil. Only when a keeper is in goal and the engine would
-- accept it (Phases.canKeeperSwap).
function AI._planKeeperSwap(match)
    local player = match.players.opponent
    local cur    = player.pitch.keeper
    if not cur then return nil end
    local enemyPenalties = 0
    for _, e in ipairs(match.log or {}) do
        local p = e.payload
        if e.type == "strategy_played" and p and p.ability == "PENALTY"
           and p.player ~= match.activePlayer then
            enemyPenalties = enemyPenalties + 1
        end
    end
    local best, bestV
    for _, c in ipairs(player.hand) do
        if c.type == "keeper" then
            local v = AI._keeperValue(c, enemyPenalties)
            if not best or v > bestV then best, bestV = c, v end
        end
    end
    if not best or not Phases.canKeeperSwap(match, best) then return nil end
    local curV = AI._keeperValue(cur.definition, enemyPenalties, cur.saves)
    if bestV - curV < AI.KEEPER_SWAP_MARGIN then return nil end
    return { type = "summon", cardId = best.id, slotType = "keeper", slotIndex = 0, mode = "defense" }
end

-- Cover specialists: Sweeper (Libero) and Intercept (Pressing Back) cover an empty defender
-- slot from a defender slot. Sweeper needs attack mode; Intercept covers face-down too.
-- cardDef: a hand card or a pitched card.
function AI._coverSpecialist(cardDef)
    local kw = cardDef.keyword or (cardDef.definition and cardDef.definition.keyword)
    return kw == "SWEEPER" or kw == "INTERCEPT"
end

-- True when a defender slot is empty in `used` (see _planSummons).
function AI._defenderGap(used)
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not used.defenders[i] then return true end
    end
    return false
end

-- True when a ready card on pitch can cover an empty defender slot (Phases._eligibleCoverers):
-- an attack-mode midfielder, an attack-mode Sweeper defender, an Intercept defender in any
-- mode, an Off the line keeper.
function AI._hasDefenderCoverer(pitch)
    local function ready(c) return c and not c.exhausted and not c.cannotActNextTurn end
    local mid = pitch.midfielder
    if ready(mid) and mid.mode == "attack" then return true end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = pitch.defenders[i]
        if ready(d) and (d.mode == "attack" or Resolver.coversInDefense(d, "defender", "defender"))
           and Resolver.canCoverSlot(d, "defender", "defender") then
            return true
        end
    end
    local k = pitch.keeper
    return ready(k) and Resolver.canCoverSlot(k, "keeper", "defender") or false
end

-- May the AI flip this card of its own now? Mirrors Card.canFlip (ui/card.lua) and the
-- checks of Phases.changeMode: summon phase, never a keeper or trap, defense mode, not
-- exhausted, not summoned or already flipped this turn, not refused this turn.
function AI.canFlip(match, card, slotType)
    if not card or match.phase ~= "summon" then return false end
    if slotType == "keeper" or slotType == "trap" then return false end
    if card.mode ~= "defense" or card.exhausted then return false end
    if card.summonedThisTurn or card.modeChanged then return false end
    return card.aiRefusedFlipTag ~= AI.planTag(match)
end

-- Pick the slot for a field card and the mode to play it in. Defender- and
-- midfielder-type cards never go into striker slots (they would waste attacks there).
function AI._pickBestSlot(cardDef, used)
    local stats = cardDef.stats or {}
    local atk   = stats.atk or 0
    local def   = stats.def or 0
    local ctype = cardDef.type

    local function freeDefender()
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not used.defenders[i] then return { slotType = "defender", slotIndex = i } end
        end
        return nil
    end
    local function freeStriker()
        for i = 1, C.PITCH.MAX_STRIKERS do
            if not used.strikers[i] then return { slotType = "striker", slotIndex = i } end
        end
        return nil
    end
    local mid = (not used.midfielder) and { slotType = "midfielder", slotIndex = 0 } or nil

    -- Cover heuristic: a face-down card can't cover (Intercept excepted). A card in the
    -- midfielder slot goes in face-up when a defender slot is open and no card covers it yet;
    -- a Sweeper defender always goes in face-up (its ability is covering). Intercept covers
    -- face-down, so a Pressing Back goes in face-down like any defender.
    local specialist = AI._coverSpecialist(cardDef)
    local needCover  = used.defenders ~= nil and AI._defenderGap(used) and not used.coverer
    local midMode    = (atk >= def or needCover or specialist) and "attack" or "defense"
    local defMode    = (specialist and cardDef.keyword ~= "INTERCEPT") and "attack" or "defense"

    if ctype == "striker" then
        local s = freeStriker()
        if s then return s, "attack" end
        if mid then return mid, "attack" end
        local d = freeDefender()
        if d then return d, "defense" end
    elseif ctype == "midfielder" then
        if mid then return mid, midMode end
        local d = freeDefender()
        if d then return d, "defense" end
    elseif ctype == "defender" then
        local d = freeDefender()
        if d then return d, defMode end
        if mid then return mid, midMode end
    end
    return nil, nil
end

-- ── Attack planning (one at a time) ──────────────────────────────────────────

-- Evaluate a fight between atkStat and a defending card in slotType on dPitch, with the
-- bonuses the AI can see (Combat.defendStat, visible only).
-- Returns "win", "tie", "loss", "facedown" (unknown), or "empty".
local function evalFight(atkStat, defCard, slotType, dPitch)
    if not defCard then return "empty" end
    if defCard.mode == "defense" and not defCard.revealed then return "facedown" end
    local d = Combat.defendStat(defCard, slotType, dPitch, false, true)
    if atkStat > d then return "win"
    elseif atkStat == d then return "tie"
    else return "loss"
    end
end

-- Flips planned for this summon phase (see _planSummons; `used` holds the slots filled by
-- this turn's summons). Only revealed cards flip (a face-down card keeps its secret). A
-- revealed defence-mode card flips to attack mode when either
--   cover:  a defender slot stays empty, no face-up card covers it, and this card could
--           (the midfielder, or a Sweeper defender; Intercept covers face-down); or
--   attack: it wins a fight now against a face-up target it may attack (a defender-slot
--           card against an enemy striker, the midfielder against the enemy midfielder).
function AI._planFlips(match, used)
    local pitch  = match.players.opponent.pitch
    local ePitch = match.players.player.pitch
    local out    = {}
    local canAttack = not State.isOpeningTurn(match)

    local function wins(card, slotType)
        if not canAttack then return false end
        local atk = Combat.attackStat(card, slotType, pitch, ePitch)
        if slotType == "midfielder" then
            return evalFight(atk, ePitch.midfielder, "midfielder", ePitch) == "win"
        end
        for i = 1, C.PITCH.MAX_STRIKERS do
            if evalFight(atk, ePitch.strikers[i], "striker", ePitch) == "win" then return true end
        end
        return false
    end

    local function consider(card, slotType, slotIndex)
        if not card or not card.revealed or not AI.canFlip(match, card, slotType) then return end
        if card.cannotActNextTurn then return end   -- locked: it can neither cover nor attack
        local covers = AI._defenderGap(used) and not used.coverer
                       and (slotType == "midfielder"
                            or (Resolver.canCoverSlot(card, "defender", "defender")
                                and not Resolver.coversInDefense(card, "defender", "defender")))
        if covers or wins(card, slotType) then
            table.insert(out, { type = "flip", slotType = slotType, slotIndex = slotIndex })
            if covers then used.coverer = true end
        end
    end

    consider(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do consider(pitch.defenders[i], "defender", i) end
    return out
end

-- Priority rank for fight outcomes (lower = more desirable).
local OUTCOME_RANK = { win = 1, facedown = 2, tie = 3, loss = 4, empty = 0 }

-- True when at least one of the enemy's defender slots is empty.
local function enemyHasGap(ePitch)
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not ePitch.defenders[i] then return true end
    end
    return false
end

-- Can an AI card in attackerType's slot target `target` on the enemy pitch? The same
-- table the human gets (scenes/match.lua getAttackTargetSlots, rules.md "Who Can
-- Attack What"). ownPitch (optional): the AI's pitch, for Through ball.
function AI.isLegalTarget(ePitch, attackerType, target, ownPitch)
    if not target then return false end
    if attackerType == "striker" then
        if target.type == "defender" then return true end
        if target.type == "keeper" then
            return enemyHasGap(ePitch) or (ownPitch ~= nil and Resolver.throughBall(ownPitch) ~= nil)
        end
        if target.type == "midfielder" then
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if ePitch.defenders[i] then return false end
            end
            return true
        end
        return false
    elseif attackerType == "midfielder" then
        return target.type == "midfielder" and ePitch.midfielder ~= nil
    elseif attackerType == "defender" then
        return target.type == "striker"
    end
    return false
end

-- Returns a single attack action, trying attackers highest-ATK first.
-- Skips attackers that only have clearly losing targets (on medium/hard).
function AI._planNextAttack(match, difficulty)
    -- No attacks on the opening turn of a half (engine rule).
    if State.isOpeningTurn(match) then return nil end
    local pitch  = match.players.opponent.pitch
    local ePitch = match.players.player.pitch

    -- Every card that may attack now (Phases.canAttackNow: Pace included) and was not
    -- already refused by the store this turn, with its fight ATK (midfielder card and
    -- ability bonuses via Combat.attackStat).
    local tag = AI.planTag(match)
    local function ready(c)
        return Phases.canAttackNow(c) and c.aiRefusedTag ~= tag
    end
    local attackers = {}
    local function add(c, slotType, slotIndex)
        if ready(c) then
            table.insert(attackers, { slotType = slotType, slotIndex = slotIndex, card = c,
                                      atk = Combat.attackStat(c, slotType, pitch, ePitch) })
        end
    end
    for i = 1, C.PITCH.MAX_STRIKERS do add(pitch.strikers[i], "striker", i) end
    add(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do add(pitch.defenders[i], "defender", i) end

    if #attackers == 0 then return nil end
    table.sort(attackers, function(a, b) return a.atk > b.atk end)

    -- Open goal: the human's keeper slot is empty and a defender slot is open, so a
    -- striker-slot shot scores its full ATK. Always the best move; the highest ATK shoots.
    -- Checked from the AI's own view only (not Phases.validateAttack, which reads
    -- match.activePlayer and so the wrong sides in the simulator's mirrored view).
    if not ePitch.keeper and enemyHasGap(ePitch) then
        for _, a in ipairs(attackers) do
            if a.slotType == "striker" then
                return { type = "attack", attackerSlot = { type = "striker", index = a.slotIndex },
                         defenderSlot = { type = "keeper", index = 0 } }
            end
        end
    end

    -- Try each attacker until one finds a valid target
    for _, best in ipairs(attackers) do
        local target = AI._pickTarget(match, best, difficulty)
        if target and AI.isLegalTarget(ePitch, best.slotType, target, pitch) then
            return {
                type         = "attack",
                attackerSlot = { type = best.slotType, index = best.slotIndex },
                defenderSlot = target,
            }
        end
    end
    return nil
end

function AI._pickTarget(match, attacker, difficulty)
    local dPitch  = match.players.player.pitch
    local oPitch  = match.players.opponent.pitch
    local atkStat = attacker.atk

    -- ── Defenders: attack opposing strikers to remove threats ─────────────────
    if attacker.slotType == "defender" then
        local candidates = {}
        for i = 1, C.PITCH.MAX_STRIKERS do
            local s = dPitch.strikers[i]
            if s then
                local ev  = evalFight(atkStat, s, "striker", dPitch)
                local atk = s.definition.stats and s.definition.stats.atk or 0
                table.insert(candidates, { type = "striker", index = i, ev = ev, threatAtk = atk })
            end
        end
        if #candidates == 0 then return nil end

        if difficulty == "easy" then
            return { type = candidates[math.random(#candidates)].type,
                     index = candidates[math.random(#candidates)].index }
        end

        -- Medium/Hard: prefer winning fights; on hard also consider biggest threat first
        table.sort(candidates, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            -- Tiebreak: hard targets biggest threat; medium targets easiest win
            if difficulty == "hard" then return a.threatAtk > b.threatAtk end
            return (Combat.getStat(dPitch.strikers[a.index], "defend"))
                 < (Combat.getStat(dPitch.strikers[b.index], "defend"))
        end)
        local pick = candidates[1]
        -- Medium: skip if best option is a clear loss against a face-up card
        if difficulty == "medium" and pick.ev == "loss" then return nil end
        return { type = pick.type, index = pick.index }
    end

    -- ── Midfielder: only attacks an occupied opposing midfielder ──────────────
    if attacker.slotType == "midfielder" then
        local oMid = dPitch.midfielder
        if not oMid then return nil end
        local ev = evalFight(atkStat, oMid, "midfielder", dPitch)
        -- Medium/Hard: don't attack if it's a face-up losing fight
        if difficulty ~= "easy" and ev == "loss" then return nil end
        return { type = "midfielder", index = 0 }
    end

    -- ── Strikers: advance toward keeper, clearing the path ────────────────────
    local defenders = {}
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = dPitch.defenders[i]
        if d then
            local ev  = evalFight(atkStat, d, "defender", dPitch)
            local def = (d.mode ~= "defense" or d.revealed)
                        and Combat.defendStat(d, "defender", dPitch, false, true) or 0
            table.insert(defenders, { type = "defender", index = i, ev = ev, def = def })
        end
    end

    if difficulty == "easy" then
        if #defenders > 0 then
            local pick = defenders[math.random(#defenders)]
            return { type = pick.type, index = pick.index }
        end
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not dPitch.defenders[i] then return { type = "defender", index = i } end
        end
        return nil
    end

    -- Medium/Hard: prefer winning or unknown fights; route through empty slots
    -- when no winning attack is available rather than suiciding into a stronger defender.
    local winning = {}
    local empty   = {}
    for _, d in ipairs(defenders) do
        if d.ev == "win" or d.ev == "facedown" then table.insert(winning, d) end
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not dPitch.defenders[i] then table.insert(empty, i) end
    end

    -- This attacker's shot from here: its shot ATK against the keeper's visible DEF
    -- (an empty keeper slot always scores). oneOnOne: a Through ball shot faces the
    -- keeper's penalty DEF (base DEF; Fortress: full DEF).
    -- Same numbers as Combat.resolveShot, a Clinical tie included.
    local function shotScores(oneOnOne)
        if not attacker.card then return false end
        local k   = dPitch.keeper
        local atk = Combat.attackStat(attacker.card, attacker.slotType, oPitch, dPitch, { keeper = k })
        if not k then return true end
        local def = Combat.keeperDef(k, dPitch, oneOnOne, true)
        return atk > def or (atk == def and Resolver.clinical(attacker.card) and true or false)
    end

    -- Through ball: past a full defence, straight at the keeper when the one-on-one
    -- scores. AI.isLegalTarget allows it (Resolver.throughBall, once per turn).
    local throughBall = #empty == 0 and attacker.slotType == "striker"
                        and Resolver.throughBall(oPitch) ~= nil and shotScores(true)

    -- Beat the man: an empty slot can't be covered, so going through it is a clean shot.
    if #empty > 0 and attacker.card and Resolver.uncoverable(attacker.card) and shotScores() then
        return { type = "defender", index = empty[1] }
    end

    if #winning > 0 then
        -- Attack the best candidate: wins sorted by lowest DEF (easiest to clear)
        table.sort(winning, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        -- A known win first; a scoring one-on-one beats a gamble on a face-down defender.
        if winning[1].ev == "facedown" and throughBall then return { type = "keeper", index = 0 } end
        return { type = winning[1].type, index = winning[1].index }
    end

    if throughBall then return { type = "keeper", index = 0 } end

    -- No winning attack — advance through an empty slot instead
    if #empty > 0 then
        return { type = "defender", index = empty[1] }
    end

    -- All defender slots occupied and we'd lose every fight.
    -- Hard will still attack (force cover / trade resources); medium skips.
    if difficulty == "hard" and #defenders > 0 then
        table.sort(defenders, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        return { type = defenders[1].type, index = defenders[1].index }
    end

    -- Every defender slot is filled, no fight is worth taking and no Through ball: no attack.
    return nil
end

-- ── Strategy planning ─────────────────────────────────────────────────────────

function AI._pickStrategy(match, difficulty)
    if match.strategyPlayedThisTurn then return nil end
    local player   = match.players.opponent
    local opponent = match.players.player
    local opening  = State.isOpeningTurn(match)   -- no shots on the opening turn

    for _, c in ipairs(player.hand) do
        if c.type == "strategy" then
            local ability = c.ability

            if ability == "DIRECT_FREE_KICK" and not opening then
                local keeper = opponent.pitch.keeper
                if keeper then
                    local best = Phases._bestStriker(player.pitch)
                    if best then
                        local atk = Combat.attackStat(best, "striker", player.pitch, opponent.pitch,
                                                      { keeper = keeper })
                        local def = Combat.keeperEffectiveDef(keeper, opponent.pitch)
                        if atk > def or difficulty == "hard" then
                            return { type = "playStrategy", cardId = c.id }
                        end
                    end
                end

            elseif ability == "PENALTY" and not opening then
                if Phases._bestStriker(player.pitch) and opponent.pitch.keeper then
                    return { type = "playStrategy", cardId = c.id }
                end

            elseif ability == "TIME_WASTING" then
                -- Use if winning by a meaningful margin, or hard mode uses it even at +1
                local margin = player.lp - opponent.lp
                local threshold = difficulty == "hard" and 1 or 500
                if margin >= threshold then
                    return { type = "playStrategy", cardId = c.id }
                end

            end
        end
    end
    return nil
end

-- ── Trap discipline ─────────────────────────────────────────────────────────
-- The AI's traps fire automatically in store/match.lua; these decide when.

AI.OFFSIDE_MIN_DAMAGE = 300    -- Offside only against attacks worth at least this much LP
AI.RED_CARD_MIN_ATK   = 2000   -- Red Card only against attackers at least this strong

-- LP the defending side (ownerId) would lose if this attack resolved as declared.
-- 0 when it would only cost a card or bounce off; an open goal is the full ATK.
function AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot)
    local aPitch   = match.players[State.other(ownerId)].pitch
    local dPitch   = match.players[ownerId].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if not attacker then return 0 end
    local target = Phases._getSlot(dPitch, defenderSlot)
    if defenderSlot.type == "keeper" then
        local atk = Combat.attackStat(attacker, attackerSlot.type, aPitch, dPitch, { keeper = target })
        if not target then return atk end
        local oneOnOne = Phases._throughBallFor(match, attackerSlot, defenderSlot) ~= nil
        return math.max(0, atk - (Combat.keeperDef(target, dPitch, oneOnOne)))
    end
    if not target or target.mode == "defense" then return 0 end
    local atk = Combat.attackStat(attacker, attackerSlot.type, aPitch, dPitch)
    local def = Combat.defendStat(target, defenderSlot.type, dPitch)
    return math.max(0, atk - def)
end

-- Should ownerId's Offside cancel this striker attack? Never against Aerial (it can't be
-- activated anyway). Yes when it would cost at least OFFSIDE_MIN_DAMAGE LP, or when it goes
-- into an empty slot the owner can't cover (a Beat the man attack can't be covered).
function AI.wantsOffside(match, ownerId, attackerSlot, defenderSlot)
    local aPitch   = match.players[State.other(ownerId)].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if Resolver.immuneToOffside(attacker) then return false end
    local dPitch = match.players[ownerId].pitch
    if defenderSlot.type ~= "striker" and not Phases._getSlot(dPitch, defenderSlot) then
        local canCover = not match.coverUsed[ownerId]
                         and #Phases._eligibleCoverers(dPitch, defenderSlot) > 0
                         and not Resolver.uncoverable(attacker)
        return not canCover
    end
    return AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot) >= AI.OFFSIDE_MIN_DAMAGE
end

-- Should the AI's Red Card punish an attacker with this (effective) ATK?
function AI.wantsRedCard(attackerAtk)
    return (attackerAtk or 0) >= AI.RED_CARD_MIN_ATK
end

-- ── Half-time swap ──────────────────────────────────────────────────────────

-- Traps and strategies the AI keeps in its half-time hand; the rest go back.
AI.MULLIGAN_KEEP_SPECIALS = 2

-- Card ids playerId sends back at a half-time break (for State.mulligan): traps and
-- strategies beyond the first AI.MULLIGAN_KEEP_SPECIALS in hand order, then any keeper
-- after the first; at most C.MATCH.MULLIGAN_MAX cards.
function AI.mulliganChoice(match, playerId)
    local specials, keepers, out = 0, 0, {}
    local extraKeepers = {}
    for _, c in ipairs(match.players[playerId].hand) do
        if c.type == "trap" or c.type == "strategy" then
            specials = specials + 1
            if specials > AI.MULLIGAN_KEEP_SPECIALS then out[#out + 1] = c.id end
        elseif c.type == "keeper" then
            keepers = keepers + 1
            if keepers > 1 then extraKeepers[#extraKeepers + 1] = c.id end
        end
    end
    for _, id in ipairs(extraKeepers) do out[#out + 1] = id end
    while #out > C.MATCH.MULLIGAN_MAX do table.remove(out) end
    return out
end

-- ── Plan bookkeeping ────────────────────────────────────────────────────────

-- The turn a plan was made for. scenes/match.lua (and tools/sim) drop a plan whose tag
-- no longer matches, e.g. when the AI won the half in the middle of its turn.
function AI.planTag(match)
    return tostring(match.half) .. ":" .. tostring(match.turn)
end

return AI
