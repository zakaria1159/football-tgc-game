local Combat = require("engine.combat")
local C      = require("engine.constants")
local Phases = require("engine.phases")
local State  = require("engine.state")

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

-- Returns (done, extraActions).
function AI.executeAction(store, action)
    local difficulty = store.aiDifficulty or "medium"

    if action.type == "draw" then
        store:drawPhase()

    elseif action.type == "planSummons" then
        -- Evaluated NOW so the drawn card is included.
        local summons = AI._planSummons(store.match)
        return false, summons

    elseif action.type == "summon" then
        store:summonCard(action.cardId, action.slotType, action.slotIndex, action.mode)

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
        store:declareAttack(action.attackerSlot, action.defenderSlot)

    elseif action.type == "endTurn" then
        store:endTurn()
        return true, nil
    end
    return false, nil
end

-- ── Cover decision ────────────────────────────────────────────────────────────

function AI.decideCover(store)
    local cw = store.coverWindow
    if not cw or #cw.eligibleCoverers == 0 then return nil end

    local match      = store.match
    local activeId   = match.activePlayer
    local defenderId = activeId == "player" and "opponent" or "player"
    if match.coverUsed[defenderId] then return nil end

    local difficulty = store.aiDifficulty or "medium"
    if difficulty == "easy" then return nil end

    local atkStat = cw.attackerSnap and (cw.attackerSnap.atk or 0) or 0

    local best, bestDef = nil, -1
    for _, cov in ipairs(cw.eligibleCoverers) do
        local d = Combat.getStat(cov.card, "defend")
        if d > bestDef then bestDef = d; best = cov end
    end
    if not best then return nil end

    if difficulty == "medium" then
        if atkStat - bestDef <= 0 then
            return { type = best.type, index = best.index }
        end
        return nil
    end

    -- Hard: always cover (even a losing cover blocks damage this turn)
    return { type = best.type, index = best.index }
end

-- ── Summon planning ───────────────────────────────────────────────────────────

function AI._planSummons(match)
    local player     = match.players.opponent
    local pitch      = player.pitch
    local summonLeft = C.MATCH.MAX_SUMMONS_PER_TURN - (match.summonCount or 0)
    -- Respect TIME_WASTING limit if active
    if player.nextTurnSummonLimit then
        summonLeft = math.min(summonLeft, player.nextTurnSummonLimit)
    end
    local actions = {}

    local used = {
        keeper     = pitch.keeper ~= nil,
        defenders  = {},
        midfielder = pitch.midfielder ~= nil,
        strikers   = {},
    }
    for i = 1, C.PITCH.MAX_DEFENDERS do used.defenders[i] = pitch.defenders[i] ~= nil end
    for i = 1, C.PITCH.MAX_STRIKERS  do used.strikers[i]  = pitch.strikers[i]  ~= nil end

    -- Separate hand into groups
    local hand = {}
    for _, c in ipairs(player.hand) do table.insert(hand, c) end

    -- Priority: keeper > striker (by ATK) > midfielder (by ATK) > defender (by DEF) > others
    local typePri = { keeper=5, striker=4, midfielder=3, defender=2, trap=1, strategy=0 }
    table.sort(hand, function(a, b)
        local ap = typePri[a.type] or 0
        local bp = typePri[b.type] or 0
        if ap ~= bp then return ap > bp end
        local aVal = (a.type == "striker" or a.type == "midfielder")
                     and (a.stats and a.stats.atk or 0)
                      or (a.stats and a.stats.def or 0)
        local bVal = (b.type == "striker" or b.type == "midfielder")
                     and (b.stats and b.stats.atk or 0)
                      or (b.stats and b.stats.def or 0)
        return aVal > bVal
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
                summonLeft = summonLeft - 1
            end
        end

        ::continue::
    end

    return actions
end

-- Pick best available slot for a card and return the mode it should play in.
function AI._pickBestSlot(cardDef, used)
    local stats  = cardDef.stats or {}
    local atk    = stats.atk or 0
    local def    = stats.def or 0
    local ctype  = cardDef.type

    -- Natural slot first
    if ctype == "striker" then
        for i = 1, C.PITCH.MAX_STRIKERS do
            if not used.strikers[i] then
                return { slotType = "striker", slotIndex = i }, "attack"
            end
        end
        -- Overflow into midfielder
        if not used.midfielder then
            return { slotType = "midfielder", slotIndex = 0 }, "attack"
        end
    elseif ctype == "midfielder" then
        if not used.midfielder then
            return { slotType = "midfielder", slotIndex = 0 }, (atk >= def and "attack" or "defense")
        end
        -- Overflow into striker slot
        for i = 1, C.PITCH.MAX_STRIKERS do
            if not used.strikers[i] then
                return { slotType = "striker", slotIndex = i }, "attack"
            end
        end
    elseif ctype == "defender" then
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not used.defenders[i] then
                return { slotType = "defender", slotIndex = i }, "defense"
            end
        end
        -- Overflow into midfielder
        if not used.midfielder then
            return { slotType = "midfielder", slotIndex = 0 }, "defense"
        end
    end

    -- Last resort: any open slot
    for i = 1, C.PITCH.MAX_STRIKERS do
        if not used.strikers[i] then return { slotType = "striker", slotIndex = i }, (atk >= def and "attack" or "defense") end
    end
    if not used.midfielder then return { slotType = "midfielder", slotIndex = 0 }, (atk >= def and "attack" or "defense") end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not used.defenders[i] then return { slotType = "defender", slotIndex = i }, "defense" end
    end

    return nil, nil
end

-- ── Attack planning (one at a time) ──────────────────────────────────────────

-- Evaluate the outcome of a fight between atkStat and a defender card.
-- Returns "win", "tie", "loss", "facedown" (unknown), or "empty".
local function evalFight(atkStat, defCard)
    if not defCard then return "empty" end
    if defCard.mode == "defense" then return "facedown" end
    local d = Combat.getStat(defCard, "defend")
    if atkStat > d then return "win"
    elseif atkStat == d then return "tie"
    else return "loss"
    end
end

-- Priority rank for fight outcomes (lower = more desirable).
local OUTCOME_RANK = { win = 1, facedown = 2, tie = 3, loss = 4, empty = 0 }

-- Returns a single attack action, trying attackers highest-ATK first.
-- Skips attackers that only have clearly losing targets (on medium/hard).
function AI._planNextAttack(match, difficulty)
    -- No attacks on the opening turn of a half (engine rule).
    if State.isOpeningTurn(match) then return nil end
    local pitch       = match.players.opponent.pitch
    local midAtkBonus = Combat.midfielderCardAtkBonus(pitch)

    -- Collect all eligible attackers with accurate ATK (including midfielder bonus for strikers)
    local attackers = {}
    for i = 1, C.PITCH.MAX_STRIKERS do
        local c = pitch.strikers[i]
        if c and not c.exhausted and not c.cannotActNextTurn and c.mode == "attack" then
            local atk = (c.definition.stats and c.definition.stats.atk or 0) + midAtkBonus
            table.insert(attackers, { slotType = "striker", slotIndex = i, atk = atk })
        end
    end
    local mid = pitch.midfielder
    if mid and not mid.exhausted and not mid.cannotActNextTurn and mid.mode == "attack" then
        local atk = mid.definition.stats and mid.definition.stats.atk or 0
        table.insert(attackers, { slotType = "midfielder", slotIndex = 0, atk = atk })
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders[i]
        if c and not c.exhausted and not c.cannotActNextTurn and c.mode == "attack" then
            local atk = c.definition.stats and c.definition.stats.atk or 0
            table.insert(attackers, { slotType = "defender", slotIndex = i, atk = atk })
        end
    end

    if #attackers == 0 then return nil end
    table.sort(attackers, function(a, b) return a.atk > b.atk end)

    -- Try each attacker until one finds a valid target
    for _, best in ipairs(attackers) do
        local target = AI._pickTarget(match, best, difficulty)
        if target then
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
                local ev  = evalFight(atkStat, s)
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
        local ev = evalFight(atkStat, oMid)
        -- Medium/Hard: don't attack if it's a face-up losing fight
        if difficulty ~= "easy" and ev == "loss" then return nil end
        return { type = "midfielder", index = 0 }
    end

    -- ── Strikers: advance toward keeper, clearing the path ────────────────────
    -- Build defender list with fight evaluations
    local defenders = {}
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = dPitch.defenders[i]
        if d then
            local ev  = evalFight(atkStat, d)
            local def = d.mode ~= "defense" and Combat.getStat(d, "defend") or 0
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

    if #winning > 0 then
        -- Attack the best candidate: wins sorted by lowest DEF (easiest to clear)
        table.sort(winning, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        return { type = winning[1].type, index = winning[1].index }
    end

    -- No winning attack — advance through an empty slot instead
    if #empty > 0 then
        return { type = "defender", index = empty[1] }
    end

    -- All defender slots occupied and we'd lose every fight.
    -- Hard will still attack (force cover / trade resources); medium skips.
    if difficulty == "hard" and #defenders > 0 then
        -- Pick tie first; otherwise take the least-bad loss (lowest DEF)
        table.sort(defenders, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        return { type = defenders[1].type, index = defenders[1].index }
    end

    -- No defenders left — go for midfielder or keeper
    if dPitch.midfielder then
        local ev = evalFight(atkStat, dPitch.midfielder)
        if difficulty == "medium" and ev == "loss" then
            -- Skip midfielder; try keeper directly if a defender slot is open
            local hasGap = false
            for i = 1, C.PITCH.MAX_DEFENDERS do if not dPitch.defenders[i] then hasGap = true; break end end
            if hasGap and dPitch.keeper then return { type = "keeper", index = 0 } end
            return nil
        end
        return { type = "midfielder", index = 0 }
    end

    if dPitch.keeper then
        local hasGap = false
        for i = 1, C.PITCH.MAX_DEFENDERS do if not dPitch.defenders[i] then hasGap = true; break end end
        if hasGap then return { type = "keeper", index = 0 } end
    end

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
                        local atk = Combat.getStat(best, "attack")
                                  + Combat.midfielderCardAtkBonus(player.pitch)
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

return AI
