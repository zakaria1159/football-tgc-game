local flux          = require("lib.flux")
local Theme         = require("ui.theme")
local Fonts         = require("ui.fonts")
local Draw          = require("ui.kit.draw")
local Pitch         = require("ui.pitch")
local Hand          = require("ui.hand")
local Card          = require("ui.card")
local CombatOverlay      = require("ui.combat_overlay")
local TrapActivOverlay   = require("ui.trap_activation_overlay")
local CoverPrompt        = require("ui.cover_prompt")
local AI            = require("ai.opponent")
local Audio         = require("ui.audio")
local Character     = require("ui.character")
local C             = require("engine.constants")
local PauseMenu     = require("ui.pause_menu")
local CardLibrary   = require("ui.card_library")
local Layout        = require("ui.match.layout")
local TopBar        = require("ui.match.topbar")
local BottomBar     = require("ui.match.bottombar")
local Toasts        = require("ui.match.toasts")
local Banner        = require("ui.match.banner")
local Hover         = require("ui.match.hover")
local Zoom          = require("ui.match.zoom")
local Tween         = require("ui.kit.tween")
local Confetti      = require("ui.match.confetti")

local Match = {}

local store            = nil
local pitchHitboxes    = {}
local handHit          = { cards = {}, order = {}, defs = {} }   -- from Hand.draw

local selectedHandCard     = nil
local selectedAttackerSlot = nil
local selectedMode         = "attack"

-- Substitution two-step: after Substitution card returns a pitched card,
-- set this so the next summon is free and targets the freed slot.
local substitutionFreedSlot = nil

-- Scout Report two-step: waiting for player to click an opponent face-down card.
local scoutPending = false
local scoutReveal  = nil  -- { card = pitchedCard, timer = N } while overlay is shown

local mouseX, mouseY         = -1, -1    -- last mouse position (buttons, zoom)
local handMouseX, handMouseY = nil, nil  -- mouse for dock magnification (frozen during combat)
local aiDifficulty   = "medium"

local pauseOpen   = false
local libraryOpen = false
local lastLogLen  = 0
local aiHandDebug = false

-- Combat overlay queue
local combatQueue  = {}
local activeCombat = nil

-- Trap activation overlay queue
local trapActivQueue  = {}
local activeTrapActiv = nil
local trapActivAnim   = { slideY = 0, stampAlpha = 0, glowAlpha = 0, textAlpha = 0 }

-- Cover / trap prompt hitboxes
local coverHitboxes = {}
local trapHitboxes  = {}

-- Flux animations
local flyingCards = {}
local drawAnims   = {}   -- card-draw flying animations
local pitchAnims  = { hidden = {}, pop = {} }   -- summon squash-pop state, read by Pitch.draw
local overlayAnim = {
    panelY      = 0,    -- panel vertical offset (starts off-screen, tweens to 0)
    atkOffX     = 0,    -- attacker card horizontal offset (slides from left)
    defOffX     = 0,    -- defender card horizontal offset (slides from right)
    clashX      = 0,    -- clash intensity (0=calm, 1=full clash)
    resultAlpha = 0,    -- result text/pill fade-in
    shakeX      = 0,    -- horizontal shake at clash moment
}

-- Toasts (log events) and ribbon banner (Match.flash)
local toasts = Toasts.new()
local banner = Banner.new()

-- Card zoom (hover any card ~0.3s)
local hover    = Hover.new()
local zoomKey  = nil
local zoomAnim = { scale = 1 }

-- Debug log panel
local debugLogOpen   = false
local debugLogScroll = 0  -- lines scrolled from bottom

-- AI state machine
local aiPlan        = nil
local aiActionIndex = 0
local aiTimer       = 0
local AI_STEP_DELAY = 0.55

-- ── Entry ─────────────────────────────────────────────────────────────────────

function Match.enter(matchStore, difficulty)
    store               = matchStore
    aiDifficulty        = difficulty or "medium"
    store.aiDifficulty  = aiDifficulty
    selectedHandCard    = nil
    selectedAttackerSlot = nil
    selectedMode        = "attack"
    substitutionFreedSlot = nil
    scoutPending        = false
    scoutReveal         = nil
    combatQueue         = {}
    activeCombat        = nil
    trapActivQueue      = {}
    activeTrapActiv     = nil
    coverHitboxes       = {}
    flyingCards         = {}
    drawAnims           = {}
    pitchAnims          = { hidden = {}, pop = {} }
    trapHitboxes        = {}
    handHit             = { cards = {}, order = {}, defs = {} }
    aiPlan              = nil
    aiActionIndex       = 0
    aiTimer             = 0
    debugLogOpen        = false
    debugLogScroll      = 0
    lastLogLen          = 0
    mouseX, mouseY      = -1, -1
    handMouseX, handMouseY = nil, nil
    toasts              = Toasts.new()
    banner              = Banner.new()
    hover               = Hover.new()
    zoomKey             = nil
    Character.reset()
    TopBar.reset(store.match)
    BottomBar.reset()
end

-- ── Update ────────────────────────────────────────────────────────────────────

function Match.update(dt)
    if not store or not store.match then return end
    local match = store.match

    Confetti.update(dt)
    Character.update(dt, match.players.player.lp)
    toasts:update(dt)
    banner:update(dt)
    TopBar.update(dt, match, mouseX, mouseY)
    BottomBar.update(dt, match, mouseX, mouseY)

    local hKey, hPayload = Match.hoverTarget(match)
    if hover:update(dt, hKey, hPayload) then
        if zoomKey ~= hKey then
            zoomKey = hKey
            zoomAnim.scale = 0.85
            flux.to(zoomAnim, 0.18, { scale = 1 }):ease("backout")
        end
    else
        zoomKey = nil
    end

    -- Scan new log entries for notable events
    local log = match.log or {}
    for i = lastLogLen + 1, #log do
        local evt = log[i]
        local p   = evt.payload or {}
        if evt.type == "midfield_control" and p.player == "player" then
            Match.flash("MIDFIELD CONTROL +1 SUMMON", "good")
        elseif evt.type == "card_drawn" then
            Match.spawnDrawAnim(p.player == "player")
        end
        local text, kind = Toasts.describe(evt)
        if text then toasts:push(text, kind) end
    end
    lastLogLen = #log
    if scoutReveal then
        scoutReveal.timer = scoutReveal.timer - dt
        if scoutReveal.timer <= 0 then scoutReveal = nil end
    end

    if not activeCombat and #combatQueue > 0 then
        activeCombat = table.remove(combatQueue, 1)

        -- Phase 1: panel + cards slide in (0 → 0.35s)
        local H = love.graphics.getHeight()
        overlayAnim.panelY      = H * 0.55
        overlayAnim.atkOffX     = -380
        overlayAnim.defOffX     = 380
        overlayAnim.clashX      = 0
        overlayAnim.resultAlpha = 0
        overlayAnim.shakeX      = 0

        flux.to(overlayAnim, 0.32, { panelY = 0 }):ease("backout")
        flux.to(overlayAnim, 0.32, { atkOffX = 0 }):ease("quadout")
        flux.to(overlayAnim, 0.32, { defOffX = 0 }):ease("quadout")

        -- Phase 2: clash (0.38s → 0.62s) — cards surge toward center, screen shakes
        flux.to(overlayAnim, 0.22, { clashX = 1 }):delay(0.38):ease("quadout")
            :oncomplete(function()
                -- screen shake on clash
                overlayAnim.shakeX = 7
                flux.to(overlayAnim, 0.28, { shakeX = 0 }):ease("elasticout")
                -- LP damage: banner + confetti
                if activeCombat and activeCombat.damage and activeCombat.damage > 0 then
                    Match.onLPDamage(match.activePlayer, activeCombat.outcome == "damage")
                end
                -- Phase 3: clash recedes, result fades in (0.62s → 1.0s)
                flux.to(overlayAnim, 0.18, { clashX = 0.15 }):ease("quadin")
                flux.to(overlayAnim, 0.38, { resultAlpha = 1 }):ease("quadout")
            end)
    end

    -- Dequeue a trap activation overlay (only when no combat overlay is blocking)
    if not activeCombat and not activeTrapActiv and #trapActivQueue > 0 then
        activeTrapActiv = table.remove(trapActivQueue, 1)
        if activeTrapActiv.activator == "opponent" then
            Character.setState("worried")
        end
        local H = love.graphics.getHeight()
        trapActivAnim.slideY     = H * 0.38
        trapActivAnim.stampAlpha = 0
        trapActivAnim.glowAlpha  = 0
        trapActivAnim.textAlpha  = 0
        flux.to(trapActivAnim, 0.30, { slideY = 0 }):ease("backout")
        flux.to(trapActivAnim, 0.28, { glowAlpha = 1 }):ease("quadout")
        flux.to(trapActivAnim, 0.28, { stampAlpha = 1 }):delay(0.26):ease("backout")
        flux.to(trapActivAnim, 0.28, { textAlpha = 1 }):delay(0.50):ease("quadout")
    end

    if activeCombat then return end
    if activeTrapActiv then return end
    if store.coverWindow then
        if match.activePlayer == "player" then
            -- Player is attacking, AI defends — AI auto-decides immediately
            local covSlot = AI.decideCover(store)
            store:resolveCover(covSlot)
            while #store.combatQueue > 0 do
                table.insert(combatQueue, store:popCombat())
            end
            while #store.trapActivationQueue > 0 do
                table.insert(trapActivQueue, store:popTrapActivation())
            end
        end
        -- Opponent is attacking, player defends — UI handles it, just block the loop
        return
    end
    if match.winner then return end
    if store.trapWindow then return end  -- pause all game logic while any trap window is open

    if match.activePlayer == "player" and match.phase == "draw" then
        store:drawPhase()
        return
    end

    if match.activePlayer == "opponent" then
        if not aiPlan then
            aiPlan        = AI.planTurn()
            aiActionIndex = 1
            aiTimer       = AI_STEP_DELAY
        end

        aiTimer = aiTimer - dt
        if aiTimer > 0 then return end

        local action = aiPlan[aiActionIndex]
        if not action then aiPlan = nil; return end

        if action.type == "attack" then Audio.play("attack") end
        local done, extra = AI.executeAction(store, action)
        aiActionIndex = aiActionIndex + 1
        aiTimer       = AI_STEP_DELAY

        -- Inject dynamically computed actions (e.g. attacks planned post-summon)
        if extra and #extra > 0 then
            for i = #extra, 1, -1 do
                table.insert(aiPlan, aiActionIndex, extra[i])
            end
        end

        while #store.combatQueue > 0 do
            table.insert(combatQueue, store:popCombat())
        end
        while #store.trapActivationQueue > 0 do
            table.insert(trapActivQueue, store:popTrapActivation())
        end

        if done then aiPlan = nil end
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

function Match.draw()
    if not store or not store.match then return end
    local match = store.match
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    Draw.background(W, H)

    local interactionState = {
        selectedHandCard     = selectedHandCard,
        selectedAttackerSlot = selectedAttackerSlot,
        highlightedSlots     = Match.getHighlightedSlots(match),
        attackTargetSlots    = Match.getAttackTargetSlots(match),
        phase                = match.phase,
    }
    pitchHitboxes = Pitch.draw(match, interactionState, pitchAnims)
    TopBar.draw(match)
    BottomBar.draw(match, { mode = selectedMode, toasts = toasts, hint = Match.hintText(match) })
    handHit = Hand.draw(match.players.player.hand,
        selectedHandCard and selectedHandCard.id or nil, handMouseX, handMouseY)

    -- Confetti
    Confetti.draw()

    -- Card-draw animations (card back from the deck pile; scaled, never resized)
    local dk = Layout.bottom.deck
    for _, da in ipairs(drawAnims) do
        love.graphics.push()
        love.graphics.translate(da.x + dk.w / 2, da.y + dk.h / 2)
        love.graphics.scale(da.s, da.s)
        Card.drawBack(-dk.w / 2, -dk.h / 2, dk.w, dk.h)
        love.graphics.pop()
    end

    -- Flying cards (summon)
    for _, fc in ipairs(flyingCards) do
        Card.drawPitched({
            definition = fc.cardDef, exhausted = false, mode = fc.mode or "attack",
            slotType   = (fc.cardDef.type == "trap") and "trap" or fc.cardDef.type,
        }, fc.x, fc.y, { w = fc.w, h = fc.h })
    end

    -- Card zoom
    if zoomKey and hover.payload then
        local p = hover.payload
        Zoom.draw({ cardDef = p.cardDef, pitched = p.pitched, pitch = p.pitch, src = p.src, scale = zoomAnim.scale, above = p.above })
    end

    -- Flash banner
    banner:draw()

    -- Combat overlay — drawn directly (backdrop must cover full screen)
    if activeCombat then
        CombatOverlay.draw(activeCombat, overlayAnim)
    end

    -- Trap activation overlay (cinematic reveal, shown after combat if both pending)
    if activeTrapActiv then
        TrapActivOverlay.draw(activeTrapActiv, trapActivAnim)
    end

    -- Scout Report reveal overlay
    if scoutReveal then
        Match.drawScoutReveal(scoutReveal.card)
    end

    -- Cover prompt (player defending against opponent attack)
    if store.coverWindow and not activeCombat and match.activePlayer == "opponent" then
        CoverPrompt.draw(store.coverWindow)
        coverHitboxes = CoverPrompt.getHitboxes(store.coverWindow)
    else
        coverHitboxes = {}
    end

    -- Trap window (player decides whether to activate their set trap)
    if store.trapWindow and not activeCombat then
        trapHitboxes = Match.drawTrapWindow(store.trapWindow)
    else
        trapHitboxes = {}
    end

    -- AI hand debug
    if aiHandDebug then Match.drawAIHandDebug(match) end

    -- Debug log panel (overlay, drawn last so it's on top)
    if debugLogOpen then Match.drawDebugLog(match) end

    if match.winner then Match.drawWinScreen(match) end

    -- Pause menu / card library (always on top of everything)
    if libraryOpen then CardLibrary.draw() end
    if pauseOpen and not libraryOpen then PauseMenu.draw() end
end

-- Key + payload for the card under the mouse (nil when nothing zoomable).
-- Opponent face-down cards and traps are never zoomable (hidden information).
function Match.hoverTarget(match)
    if activeCombat or activeTrapActiv or scoutReveal or pauseOpen or libraryOpen or debugLogOpen
       or match.winner or store.coverWindow or store.trapWindow then
        return nil
    end
    local def, i, r = Hand.hit(handHit, mouseX, mouseY)
    if def then
        return "hand:" .. i .. ":" .. tostring(def.id), { cardDef = def, src = r, above = true }
    end
    for k = #pitchHitboxes, 1, -1 do
        local s = pitchHitboxes[k]
        if Match.inRect(mouseX, mouseY, s) then
            local pitch = match.players[s.owner].pitch
            local card
            if s.slotType == "trap" then card = pitch.traps[s.slotIndex]
            else card = Match.getCardInSlot(pitch, s) end
            if card and not (s.owner == "opponent" and card.mode == "defense") then
                return Pitch.slotKey(s.owner, s.slotType, s.slotIndex) .. ":" .. tostring(card.definition.id),
                    { cardDef = card.definition, pitched = card, pitch = pitch, src = s }
            end
            return nil
        end
    end
    return nil
end

-- One-line instruction shown between the pitch and the hand.
function Match.hintText(match)
    if activeCombat or (store and store.coverWindow) then return "" end
    if match.activePlayer == "opponent" then return "Opponent is thinking..." end
    if match.phase == "summon" then
        if selectedHandCard and selectedHandCard.ability == "SUBSTITUTION" then
            return "SUBSTITUTION: click a pitched card to return it to hand"
        elseif substitutionFreedSlot then
            return "SUBSTITUTION: select a card and place it in the freed slot (free)"
        elseif selectedHandCard and selectedHandCard.type == "trap" then
            return "Click a TRAP slot by your goal to set it face-down  ·  ESC to cancel"
        elseif selectedHandCard then
            return "Mode: " .. selectedMode:upper() .. "  ·  Click an empty slot to place  ·  ESC to cancel"
        end
        return "Select a card  ·  M toggles ATTACK / DEFENSE  ·  START ATTACK or END TURN"
    elseif match.phase == "attack" then
        if scoutPending then
            return "SCOUT REPORT: click an opponent face-down card to reveal  ·  ESC to cancel"
        elseif selectedAttackerSlot then
            return "Click an opponent slot to attack  ·  ESC to cancel"
        elseif not match.strategyPlayedThisTurn then
            return "Click your card to attack  ·  Click a STRATEGY card to play it  ·  END TURN"
        end
        return "Click your card (attack mode) to select an attacker  ·  END TURN when done"
    end
    return ""
end

function Match.drawWinScreen(match)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local won = match.winner == "player"
    local mainCol = won and { 0.15, 1.0, 0.50, 1 } or { 1.0, 0.25, 0.25, 1 }

    -- Result glow
    love.graphics.setColor(mainCol[1], mainCol[2], mainCol[3], 0.10)
    love.graphics.rectangle("fill", W/2 - 260, H * 0.22, 520, 80, 8)
    love.graphics.setColor(mainCol[1], mainCol[2], mainCol[3], 0.40)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", W/2 - 260, H * 0.22, 520, 80, 8)
    love.graphics.setLineWidth(1)

    Fonts.with(44, function()
        love.graphics.setColor(mainCol)
        love.graphics.printf(won and "VICTORY" or "DEFEAT", 0, H * 0.25, W, "center")
    end)

    local p, o = match.players.player, match.players.opponent
    Fonts.with(16, function()
        love.graphics.setColor(0.80, 0.80, 0.85, 1)
        love.graphics.printf(
            "Halves: You " .. p.halvesWon .. "  —  Opp " .. o.halvesWon,
            0, H * 0.43, W, "center")
        love.graphics.printf(
            "LP Damage: You " .. p.totalDamageDealt .. "  —  Opp " .. o.totalDamageDealt,
            0, H * 0.52, W, "center")
    end)
    Fonts.with(11, function()
        love.graphics.setColor(0.50, 0.50, 0.58, 1)
        love.graphics.printf("R to restart  |  ESC for menu", 0, H * 0.65, W, "center")
    end)
end

-- ── Trap Window ──────────────────────────────────────────────────────────────

function Match.drawTrapWindow(tw)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local panW = 500
    local rows = #tw.traps
    local panH = 80 + rows * 58 + 50
    local panX = (W - panW) / 2
    local panY = H / 2 - panH / 2

    -- Backdrop
    love.graphics.setColor(0, 0, 0, 0.70)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Panel
    love.graphics.setColor(0.07, 0.02, 0.14, 1)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 10)
    love.graphics.setColor(0.60, 0.25, 1.00, 0.80)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    local label = tw.type == "pre_attack"          and "TRAP WINDOW  ·  STRIKER ATTACKS"
               or tw.type == "post_destroy"         and "TRAP WINDOW  ·  YOUR CARD DESTROYED"
               or tw.type == "post_damage"          and "TRAP WINDOW  ·  OPPONENT SCORED"
               or tw.type == "post_last_defender"   and "TRAP WINDOW  ·  LAST DEFENDER"
               or tw.type == "counter_offside"      and "COUNTER TRAP  ·  OFFSIDE INCOMING"
               or tw.type == "counter_red_card"     and "COUNTER TRAP  ·  RED CARD INCOMING"
               or "TRAP WINDOW"
    Fonts.with(14, function()
        love.graphics.setColor(0.78, 0.50, 1.00, 1)
        love.graphics.printf(label, panX, panY + 12, panW, "center")
    end)

    -- Attack summary
    local atkName = tw.attackerSnap and tw.attackerSnap.name or "?"
    local defName = tw.defenderSnap and tw.defenderSnap.name or "?"
    Fonts.with(9, function()
        love.graphics.setColor(0.75, 0.75, 0.80, 1)
        love.graphics.printf(atkName .. "  →  " .. defName, panX + 10, panY + 34, panW - 20, "center")
    end)

    local hitboxes = {}
    local y = panY + 58

    for i, entry in ipairs(tw.traps) do
        local def = entry.card.definition

        -- Trap row
        love.graphics.setColor(0.40, 0.12, 0.65, 1)
        love.graphics.rectangle("fill", panX + 12, y, panW - 24, 48, 6)
        love.graphics.setColor(0.68, 0.38, 1.00, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", panX + 12, y, panW - 24, 48, 6)
        love.graphics.setLineWidth(1)

        Fonts.with(11, function()
            love.graphics.setColor(1, 0.92, 1, 1)
            love.graphics.print(def.name, panX + 20, y + 6)
        end)
        Fonts.with(8, function()
            love.graphics.setColor(0.78, 0.65, 0.85, 1)
            love.graphics.printf(def.abilityText and def.abilityText:sub(1, 60) or "", panX + 20, y + 22, panW - 120, "left")
        end)

        -- Activate button
        local btnX = panX + panW - 100
        local btnY = y + 10
        love.graphics.setColor(0.65, 0.15, 0.90, 1)
        love.graphics.rectangle("fill", btnX, btnY, 82, 28, 5)
        Fonts.with(9, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("ACTIVATE", btnX, btnY + 8, 82, "center")
        end)
        table.insert(hitboxes, { type="activate", trapIndex=i, x=btnX, y=btnY, w=82, h=28 })

        y = y + 58
    end

    -- Pass button
    local passX = panX + panW / 2 - 75
    love.graphics.setColor(0.22, 0.22, 0.30, 1)
    love.graphics.rectangle("fill", passX, y + 8, 150, 34, 6)
    love.graphics.setColor(0.55, 0.55, 0.65, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", passX, y + 8, 150, 34, 6)
    Fonts.with(11, function()
        love.graphics.setColor(0.70, 0.70, 0.78, 1)
        love.graphics.printf("PASS", panX, y + 16, panW, "center")
    end)
    table.insert(hitboxes, { type="pass", x=passX, y=y+8, w=150, h=34 })

    return hitboxes
end

-- ── Highlight helpers ────────────────────────────────────────────────────────

function Match.getHighlightedSlots(match)
    if not selectedHandCard then return {} end
    local pitch = match.players.player.pitch
    local slots = {}

    -- Trap card → highlight empty trap zone slots (summon phase only)
    if selectedHandCard.type == "trap" and match.phase == "summon" then
        for i = 1, C.PITCH.MAX_TRAPS do
            if not pitch.traps[i] then
                table.insert(slots, { slotType="trap", slotIndex=i, owner="player" })
            end
        end
        return slots
    end

    -- Strategy card → highlight scout targets if pending, otherwise nothing
    if selectedHandCard.type == "strategy" then
        if scoutPending then
            local oppPitch = match.players.opponent.pitch
            if oppPitch.keeper and oppPitch.keeper.mode == "defense" then
                table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
            end
            if oppPitch.midfielder and oppPitch.midfielder.mode == "defense" then
                table.insert(slots, { slotType="midfielder", slotIndex=0, owner="opponent" })
            end
            for i = 1, C.PITCH.MAX_DEFENDERS do
                local c = oppPitch.defenders[i]
                if c and c.mode == "defense" then
                    table.insert(slots, { slotType="defender", slotIndex=i, owner="opponent" })
                end
            end
            for i = 1, C.PITCH.MAX_STRIKERS do
                local c = oppPitch.strikers[i]
                if c and c.mode == "defense" then
                    table.insert(slots, { slotType="striker", slotIndex=i, owner="opponent" })
                end
            end
            return slots
        end
        return {}
    end

    -- Substitution freed slot: highlight only that one slot (free summon target)
    if substitutionFreedSlot and match.phase == "summon" then
        table.insert(slots, {
            slotType  = substitutionFreedSlot.type,
            slotIndex = substitutionFreedSlot.index or substitutionFreedSlot.slotIndex or 0,
            owner     = "player",
        })
        return slots
    end

    -- Field card → only empty slots (summon phase only)
    if match.phase ~= "summon" then return {} end
    if not pitch.keeper then
        table.insert(slots, { slotType="keeper", slotIndex=0, owner="player" })
    end
    if not pitch.midfielder then
        table.insert(slots, { slotType="midfielder", slotIndex=0, owner="player" })
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not pitch.defenders[i] then
            table.insert(slots, { slotType="defender", slotIndex=i, owner="player" })
        end
    end
    for i = 1, C.PITCH.MAX_STRIKERS do
        if not pitch.strikers[i] then
            table.insert(slots, { slotType="striker", slotIndex=i, owner="player" })
        end
    end
    return slots
end

function Match.getAttackTargetSlots(match)
    if match.phase ~= "attack" or not selectedAttackerSlot then return {} end
    local slots      = {}
    local oPitch     = match.players.opponent.pitch
    local slotType   = selectedAttackerSlot.type

    if slotType == "striker" then
        -- Advances toward keeper: defender slots → midfielder → keeper
        for i = 1, C.PITCH.MAX_DEFENDERS do
            table.insert(slots, { slotType="defender", slotIndex=i, owner="opponent" })
        end
        local hasDefender = false
        for i = 1, C.PITCH.MAX_DEFENDERS do if oPitch.defenders[i] then hasDefender = true; break end end
        if not hasDefender then
            table.insert(slots, { slotType="midfielder", slotIndex=0, owner="opponent" })
        end
        local hasGap = false
        for i = 1, C.PITCH.MAX_DEFENDERS do if not oPitch.defenders[i] then hasGap = true; break end end
        if hasGap then
            table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
        end

    elseif slotType == "midfielder" then
        -- Attacks opposing midfielder slot only if occupied
        if oPitch.midfielder then
            table.insert(slots, { slotType="midfielder", slotIndex=0, owner="opponent" })
        end

    elseif slotType == "defender" then
        -- Attacks opposing striker slots only
        for i = 1, C.PITCH.MAX_STRIKERS do
            table.insert(slots, { slotType="striker", slotIndex=i, owner="opponent" })
        end
    end

    return slots
end

-- ── Input ────────────────────────────────────────────────────────────────────

function Match.mousepressed(x, y, button)
    -- Card library takes full input priority
    if libraryOpen then
        local r = CardLibrary.mousepressed(x, y, button)
        if r == "close" then libraryOpen = false end
        return nil
    end

    -- Pause menu takes next priority
    if pauseOpen then
        local r = PauseMenu.mousepressed(x, y, button)
        if r == "resume"  then pauseOpen = false
        elseif r == "library" then libraryOpen = true; CardLibrary.open()
        elseif r == "home"    then pauseOpen = false; return "home" end
        return nil
    end

    if button ~= 1 then return end

    -- Dismiss scout reveal overlay
    if scoutReveal then
        scoutReveal = nil
        return
    end

    -- Dismiss trap activation overlay
    if activeTrapActiv then
        activeTrapActiv = nil
        return
    end

    -- Dismiss combat overlay
    if activeCombat then
        activeCombat = nil
        return
    end

    -- Handle trap window
    if store and store.trapWindow then
        for _, hbox in ipairs(trapHitboxes) do
            if Match.inRect(x, y, hbox) then
                if hbox.type == "activate" then
                    store:resolveTrap(hbox.trapIndex)
                else
                    store:resolveTrap(nil)  -- pass
                end
                while #store.combatQueue > 0 do
                    table.insert(combatQueue, store:popCombat())
                end
                while #store.trapActivationQueue > 0 do
                    table.insert(trapActivQueue, store:popTrapActivation())
                end
                return
            end
        end
        return
    end

    -- Handle cover prompt (player deciding to cover opponent's attack)
    if store and store.coverWindow and store.match.activePlayer == "opponent" then
        for _, hbox in ipairs(coverHitboxes) do
            if Match.inRect(x, y, hbox) then
                if hbox.type == "cover" then
                    store:resolveCover(hbox.coverer)
                else
                    store:resolveCover(nil)
                end
                while #store.combatQueue > 0 do
                    table.insert(combatQueue, store:popCombat())
                end
                while #store.trapActivationQueue > 0 do
                    table.insert(trapActivQueue, store:popTrapActivation())
                end
                return
            end
        end
        return
    end

    local match = store and store.match
    if not match or match.winner then return end

    local btn = Layout.buttonAt(x, y, match.phase)
    if btn == "pause" then pauseOpen = true; return end
    if btn == "music" then Audio.toggleMute(); return end
    if btn == "log" then
        debugLogOpen = not debugLogOpen
        if debugLogOpen then debugLogScroll = 0 end
        return
    end

    if match.activePlayer ~= "player" then return end

    if btn == "endTurn" then
        selectedHandCard      = nil
        selectedAttackerSlot  = nil
        substitutionFreedSlot = nil
        store:endTurn()
        return
    end
    if btn == "startAttack" then
        selectedHandCard = nil
        store:startAttackPhase()
        Character.setState("attacking")
        return
    end
    if btn == "modeAttack"  then selectedMode = "attack";  return end
    if btn == "modeDefense" then selectedMode = "defense"; return end

    -- Hand card clicks
    if match.phase == "summon" or match.phase == "attack" then
        local card = Hand.hit(handHit, x, y)
        if card then
            -- Strategy card in attack phase
            if card.type == "strategy" and match.phase == "attack"
               and not match.strategyPlayedThisTurn then
                -- Scout Report needs target selection before playing
                if card.ability == "SCOUT_REPORT" then
                    scoutPending     = true
                    selectedHandCard = card
                    return
                end
                local result, err = store:playStrategy(card.id)
                if result then
                    Audio.play("card_play_strategy")
                    while #store.combatQueue > 0 do
                        table.insert(combatQueue, store:popCombat())
                    end
                    while #store.trapActivationQueue > 0 do
                        table.insert(trapActivQueue, store:popTrapActivation())
                    end
                elseif err then
                    Match.flash(err)
                end
                selectedHandCard = nil
                return
            end

            -- Substitution in summon phase: special two-step flow
            if card.ability == "SUBSTITUTION" and match.phase == "summon" then
                selectedHandCard = (selectedHandCard and selectedHandCard.id == card.id)
                    and nil or card
                return
            end

            -- Trap / field card: select for placement
            if match.phase == "summon" then
                selectedHandCard = (selectedHandCard and selectedHandCard.id == card.id)
                    and nil or card
            end
            return
        end
    end

    -- Pitch slot clicks (reverse order: last-drawn slot wins when slots overlap)
    for i = #pitchHitboxes, 1, -1 do
        local slot = pitchHitboxes[i]
        if Match.inRect(x, y, slot) then

            -- Scout Report: resolve target when player clicks an opponent face-down slot
            if scoutPending and slot.owner == "opponent" then
                local oppCard = Match.getCardInSlot(match.players.opponent.pitch, slot)
                if oppCard and oppCard.mode == "defense" then
                    local result, err = store:playStrategy(selectedHandCard.id, {
                        targetSlot = { owner = "opponent", type = slot.slotType, index = slot.slotIndex }
                    })
                    if result then
                        Audio.play("card_play_strategy")
                        scoutReveal = { card = result.revealedCard, timer = 3.5 }
                    elseif err then
                        Match.flash(err)
                    end
                end
                scoutPending     = false
                selectedHandCard = nil
                return
            end

            -- Substitution: pick the pitch card to return
            if match.phase == "summon" and selectedHandCard
               and selectedHandCard.ability == "SUBSTITUTION" and slot.owner == "player" then
                local pitchCard = Match.getCardInSlot(match.players.player.pitch, slot)
                if pitchCard then
                    local result = store:playStrategy(
                        selectedHandCard.id,
                        { returnSlot = { type = slot.slotType, index = slot.slotIndex } }
                    )
                    if result and result.outcome == "substitution_done" then
                        substitutionFreedSlot = result.freedSlot
                    end
                    selectedHandCard = nil
                end
                return
            end

            -- Flip defense → attack (no hand card selected, own card in defense mode)
            if match.phase == "summon" and not selectedHandCard and slot.owner == "player" then
                local pitchCard = Match.getCardInSlot(match.players.player.pitch, slot)
                if pitchCard and pitchCard.mode == "defense" then
                    local ok, err = store:changeMode(slot.slotType, slot.slotIndex)
                    if not ok then Match.flash(err or "Cannot flip") end
                    return
                end
            end

            -- Summon: card flies from the hand, then squash-pops into its slot
            if match.phase == "summon" and selectedHandCard and slot.owner == "player" then
                local r = Hand.rectOf(handHit, selectedHandCard.id)
                local srcX = r and r.x or (x - slot.w / 2)
                local srcY = r and r.y or (y - slot.h / 2)
                local cardDefCopy = selectedHandCard
                local mode = (selectedHandCard.type == "trap") and "defense" or selectedMode

                local ok
                if substitutionFreedSlot then
                    -- Free summon for substitution replacement
                    ok = store:freeSummon(selectedHandCard.id, slot.slotType, slot.slotIndex, mode)
                    if ok then substitutionFreedSlot = nil end
                else
                    ok = store:summonCard(selectedHandCard.id, slot.slotType, slot.slotIndex, mode)
                end

                if ok then
                    Audio.play("card_summon")
                    -- Traps fill the first free trap slot, not necessarily the one clicked.
                    local idx, dest = slot.slotIndex, slot
                    if slot.slotType == "trap" then
                        idx  = #match.players.player.pitch.traps
                        dest = Layout.trapSlot("player", idx)
                    end
                    local key = Pitch.slotKey("player", slot.slotType, idx)
                    pitchAnims.hidden[key] = true
                    local fc = { cardDef = cardDefCopy, x = srcX, y = srcY, w = dest.w, h = dest.h, mode = mode }
                    flux.to(fc, 0.30, { x = dest.x, y = dest.y }):ease("quadout"):oncomplete(function()
                        for ii, c in ipairs(flyingCards) do
                            if c == fc then table.remove(flyingCards, ii); break end
                        end
                        pitchAnims.hidden[key] = nil
                        local pop = { sx = 1, sy = 1 }
                        pitchAnims.pop[key] = pop
                        Tween.squash(pop, 0.35):oncomplete(function()
                            if pitchAnims.pop[key] == pop then pitchAnims.pop[key] = nil end
                        end)
                    end)
                    table.insert(flyingCards, fc)
                end
                selectedHandCard = nil
                return
            end

            -- Attack phase: select attacker
            if match.phase == "attack" and slot.owner == "player" then
                local pitch = match.players.player.pitch
                local card  = Match.getCardInSlot(pitch, slot)
                if card then
                    -- Striker, midfielder, and defender slots can all attack
                    local canAttack = slot.slotType == "striker"
                                   or slot.slotType == "midfielder"
                                   or slot.slotType == "defender"
                    if not card.exhausted and not card.cannotActNextTurn
                       and card.mode == "attack" and canAttack then
                        if selectedAttackerSlot
                            and selectedAttackerSlot.type == slot.slotType
                            and selectedAttackerSlot.index == slot.slotIndex then
                            selectedAttackerSlot = nil
                        else
                            selectedAttackerSlot = { type=slot.slotType, index=slot.slotIndex }
                        end
                    end
                end
                return
            end

            -- Attack phase: declare attack against opponent slot
            if match.phase == "attack" and slot.owner == "opponent" and selectedAttackerSlot then
                Audio.play("attack")
                Character.setState("attacking")
                store:declareAttack(
                    selectedAttackerSlot,
                    { type=slot.slotType, index=slot.slotIndex }
                )
                while #store.combatQueue > 0 do
                    table.insert(combatQueue, store:popCombat())
                end
                while #store.trapActivationQueue > 0 do
                    table.insert(trapActivQueue, store:popTrapActivation())
                end
                selectedAttackerSlot = nil
                return
            end

            return
        end
    end
end

function Match.keypressed(key)
    -- Card library takes full input priority
    if libraryOpen then
        local r = CardLibrary.keypressed(key)
        if r == "close" then libraryOpen = false end
        return nil
    end

    -- Pause menu takes next priority
    if pauseOpen then
        local r = PauseMenu.keypressed(key)
        if r == "resume"  then pauseOpen = false
        elseif r == "library" then libraryOpen = true; CardLibrary.open()
        elseif r == "home"    then pauseOpen = false; return "home" end
        return nil
    end

    if activeTrapActiv then
        if key == "space" or key == "return" then activeTrapActiv = nil end
        return nil
    end
    if activeCombat then
        if key == "space" or key == "return" then activeCombat = nil end
        return nil
    end
    if store and store.coverWindow then return nil end

    if key == "tab" then aiHandDebug = not aiHandDebug; return nil end
    if key == "l"   then debugLogOpen = not debugLogOpen; if debugLogOpen then debugLogScroll = 0 end; return nil end
    if key == "m"   then selectedMode = selectedMode == "attack" and "defense" or "attack"; return nil end

    if key == "escape" then
        if scoutPending              then scoutPending = false; selectedHandCard = nil
        elseif selectedAttackerSlot  then selectedAttackerSlot  = nil
        elseif substitutionFreedSlot then substitutionFreedSlot = nil
        elseif selectedHandCard      then selectedHandCard      = nil
        else pauseOpen = true end
    elseif key == "r" and store.match and store.match.winner then
        return "restart"
    end
    return nil
end

function Match.wheelmoved(x, y)
    if libraryOpen then
        CardLibrary.wheelmoved(x, y)
        return
    end
    if debugLogOpen then
        debugLogScroll = debugLogScroll + (y > 0 and 3 or -3)
        if debugLogScroll < 0 then debugLogScroll = 0 end
    end
end

function Match.mousemoved(x, y)
    mouseX, mouseY = x, y
    if activeCombat then return end
    handMouseX, handMouseY = x, y
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- LP damage: ribbon banner + confetti at the goal that was hit. isGoal = keeper shot.
function Match.onLPDamage(dealer, isGoal)
    local P  = Layout.pitch
    local cy = P.y + P.h / 2
    if dealer == "player" then
        Character.setState("attacking")
        banner:show(isGoal and "GOAL!" or "LP DAMAGE DEALT!", "good")
        Confetti.burst(P.x + P.w - 40, cy, 90)
    else
        Character.setState("worried")
        banner:show(isGoal and "OPPONENT SCORES!" or "LP DAMAGE TAKEN!", "bad")
        Confetti.burst(P.x + 40, cy, 60)
    end
end

function Match.flash(msg, kind)
    banner:show(string.upper(tostring(msg)), kind or "error")
end

-- Card back flies from your deck pile into the hand, or from the opponent's deck
-- pill up into their avatar.
function Match.spawnDrawAnim(isPlayer)
    local dk = Layout.bottom.deck
    local da
    local function remove()
        for ii, d in ipairs(drawAnims) do
            if d == da then table.remove(drawAnims, ii); break end
        end
    end
    if isPlayer then
        local h = Layout.bottom.hand
        da = { x = dk.x, y = dk.y, s = 1 }
        flux.to(da, 0.40, { x = h.cx - dk.w / 2, y = h.baseY - dk.h - 30, s = 1.5 })
            :ease("quadout"):oncomplete(remove)
    else
        local o, av = Layout.top.oppDeck, Layout.top.oppAvatar
        da = { x = o.x + o.w / 2 - dk.w / 2, y = o.y + o.h + 4, s = 0.6 }
        flux.to(da, 0.35, { x = av.cx - dk.w / 2, y = av.cy - dk.h / 2, s = 0.15 })
            :ease("quadin"):oncomplete(remove)
    end
    Audio.play("card_summon", 0.35)
    table.insert(drawAnims, da)
end

function Match.drawScoutReveal(pitchedCard)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local pw, ph = 260, 340
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2)
    love.graphics.setColor(0.06, 0.03, 0.12, 1)
    love.graphics.rectangle("fill", px, py, pw, ph, 8)
    love.graphics.setColor(0.30, 0.55, 1.0, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 8)
    love.graphics.setLineWidth(1)

    Fonts.with(11, function()
        love.graphics.setColor(0.30, 0.75, 1.0, 1)
        love.graphics.printf("SCOUT REPORT", px, py + 13, pw, "center")
    end)

    if pitchedCard then
        local cw, ch = 110, 148
        local cx = px + math.floor((pw - cw) / 2)
        local cy = py + 42
        Card.drawFace(pitchedCard.definition, cx, cy, cw, ch, {})
        local d     = pitchedCard.definition
        local stats = d.stats or {}
        Fonts.with(11, function()
            love.graphics.setColor(0.957, 0.914, 0.824, 1)
            love.graphics.printf(d.name or "", px + 8, cy + ch + 10, pw - 16, "center")
        end)
        Fonts.with(9, function()
            love.graphics.setColor(Theme.atkColor)
            love.graphics.printf("ATK " .. tostring(stats.atk or 0), px + 8, cy + ch + 28, pw/2 - 8, "center")
            love.graphics.setColor(Theme.defColor)
            love.graphics.printf("DEF " .. tostring(stats.def or 0), px + pw/2, cy + ch + 28, pw/2 - 8, "center")
        end)
    else
        Fonts.with(11, function()
            love.graphics.setColor(0.55, 0.55, 0.60, 1)
            love.graphics.printf("No card in that slot", px + 10, py + ph/2 - 8, pw - 20, "center")
        end)
    end

    Fonts.with(9, function()
        love.graphics.setColor(0.38, 0.38, 0.42, 0.85)
        love.graphics.printf("Click to dismiss", px, py + ph - 20, pw, "center")
    end)
end

-- ── Debug log panel ──────────────────────────────────────────────────────────

local function fmtPayload(p)
    if not p then return "" end
    local parts = {}
    local order = { "player","ability","name","cardName","slot","slotType","slotIndex","outcome",
                    "damage","half","winner","turn","reason","unimplemented" }
    local seen = {}
    for _, k in ipairs(order) do
        if p[k] ~= nil then
            local v = p[k]
            if type(v) == "table" then v = "{"..table.concat((function()
                local t={}; for kk,vv in pairs(v) do table.insert(t,kk.."="..tostring(vv)) end; return t
            end)(), ",").."}" end
            table.insert(parts, k.."="..tostring(v)); seen[k] = true
        end
    end
    for k, v in pairs(p) do
        if not seen[k] then
            if type(v) == "table" then v = "{...}" end
            table.insert(parts, k.."="..tostring(v))
        end
    end
    return table.concat(parts, "  ")
end

local function logLineColor(evType)
    if evType == "card_played" or evType == "card_drawn" then return {0.55, 0.90, 0.55} end
    if evType == "strategy_played"                       then return {0.40, 0.85, 1.00} end
    if evType == "trap_activated"                        then return {0.90, 0.55, 1.00} end
    if evType == "attack_declared" or evType == "cover"  then return {1.00, 0.80, 0.30} end
    if evType == "lp_damage"                             then return {1.00, 0.35, 0.35} end
    if evType == "defender_destroy"                      then return {1.00, 0.55, 0.20} end
    if evType == "shot"                                  then return {0.30, 0.80, 1.00} end
    if evType == "turn_end"                              then return {0.50, 0.50, 0.60} end
    if evType == "half_end"                              then return {1.00, 0.85, 0.20} end
    if evType == "attack_wasted"                         then return {0.55, 0.55, 0.55} end
    return {0.75, 0.75, 0.80}
end

function Match.drawDebugLog(match)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local panW = 520
    local panH = H - 48
    local panX = (W - panW) / 2
    local panY = 28

    -- Background
    love.graphics.setColor(0.04, 0.04, 0.10, 0.96)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 8)
    love.graphics.setColor(0.30, 0.55, 1.00, 0.70)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", panX, panY, panW, panH, 8)
    love.graphics.setLineWidth(1)

    -- Title
    Fonts.with(11, function()
        love.graphics.setColor(0.50, 0.75, 1.00, 1)
        love.graphics.printf("DEBUG LOG  ·  " .. #match.log .. " events  (scroll: wheel,  close: L)",
            panX, panY + 7, panW, "center")
    end)

    local lineH    = 17
    local padX     = 12
    local innerY   = panY + 28
    local innerH   = panH - 36
    local maxLines = math.floor(innerH / lineH)

    -- Build display lines (newest at bottom)
    local lines = {}
    for _, entry in ipairs(match.log) do
        local prefix = string.format("[H%s T%02d %s] %-20s",
            tostring(entry.half), entry.turn, entry.phase:sub(1,3):upper(), entry.type)
        local detail = fmtPayload(entry.payload)
        table.insert(lines, { prefix = prefix, detail = detail, evType = entry.type })
    end

    local total   = #lines
    local maxScroll = math.max(0, total - maxLines)
    debugLogScroll  = math.max(0, math.min(debugLogScroll, maxScroll))

    local startIdx = math.max(1, total - maxLines - debugLogScroll + 1)
    local endIdx   = total - debugLogScroll   -- empty log: loop runs zero times

    love.graphics.setScissor(panX + padX, innerY, panW - padX*2, innerH)
    local y = innerY
    for i = startIdx, endIdx do
        local ln  = lines[i]
        local col = logLineColor(ln.evType)
        Fonts.with(8, function()
            love.graphics.setColor(col[1] * 0.65, col[2] * 0.65, col[3] * 0.65, 1)
            love.graphics.print(ln.prefix, panX + padX, y)
            love.graphics.setColor(col[1], col[2], col[3], 1)
            love.graphics.print(ln.detail, panX + padX + 210, y)
        end)
        y = y + lineH
    end
    love.graphics.setScissor()

    -- Scroll indicator
    if maxScroll > 0 then
        local trackH = innerH - 4
        local thumbH = math.max(20, trackH * maxLines / total)
        local thumbT = (maxScroll - debugLogScroll) / maxScroll
        local thumbY = innerY + 2 + thumbT * (trackH - thumbH)
        love.graphics.setColor(0.30, 0.55, 1.00, 0.40)
        love.graphics.rectangle("fill", panX + panW - 8, innerY, 5, trackH, 2)
        love.graphics.setColor(0.50, 0.75, 1.00, 0.90)
        love.graphics.rectangle("fill", panX + panW - 8, thumbY, 5, thumbH, 2)
    end
end

function Match.getCardInSlot(pitch, slot)
    if slot.slotType == "keeper"     then return pitch.keeper end
    if slot.slotType == "midfielder" then return pitch.midfielder end
    if slot.slotType == "defender"   then return pitch.defenders[slot.slotIndex] end
    if slot.slotType == "striker"    then return pitch.strikers[slot.slotIndex] end
    return nil
end

function Match.drawAIHandDebug(match)
    local o   = match.players.opponent
    local W   = Layout.W
    local H   = love.graphics.getHeight()
    local panW = 340
    local panH = math.min(H - 80, 20 + #o.hand * 22 + 16)
    local panX = (W - panW) / 2
    local panY = 96

    love.graphics.setColor(0.05, 0.05, 0.12, 0.94)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 8)
    love.graphics.setColor(0.85, 0.65, 0.15, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.85, 0.65, 0.15, 1)
    love.graphics.printf("AI HAND  (" .. #o.hand .. " cards)", panX, panY + 6, panW, "center")

    local y = panY + 26
    for _, card in ipairs(o.hand) do
        if y > panY + panH - 18 then
            love.graphics.setColor(0.55, 0.55, 0.60, 1)
            love.graphics.printf("...", panX + 10, y, panW - 20, "left")
            break
        end
        local col = Theme.cardColors[card.type]
        if col then love.graphics.setColor(col[1], col[2], col[3], 1)
        else         love.graphics.setColor(0.7, 0.7, 0.7, 1) end
        local stat = ""
        if card.stats then
            stat = "  A" .. (card.stats.atk or 0) .. "/D" .. (card.stats.def or 0)
        end
        love.graphics.printf("[" .. card.type:sub(1,3):upper() .. "] " .. card.name .. stat,
            panX + 10, y, panW - 20, "left")
        y = y + 20
    end
end

-- Dev hook for tools/snapshot scenarios.
function Match.debugStore() return store end

function Match.inRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w
       and y >= rect.y and y <= rect.y + rect.h
end

return Match
