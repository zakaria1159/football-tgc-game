local flux          = require("lib.flux")
local Draw          = require("ui.kit.draw")
local Pitch         = require("ui.pitch")
local Hand          = require("ui.hand")
local Card          = require("ui.card")
local CombatOverlay      = require("ui.overlay.combat")
local CombatFx           = require("ui.overlay.combatfx")
local TrapActivOverlay   = require("ui.overlay.trapactivation")
local Prompts            = require("ui.overlay.prompts")
local PromptPanel        = require("ui.overlay.promptpanel")
local Reveal             = require("ui.overlay.reveal")
local MatchEnd           = require("ui.overlay.matchend")
local AI            = require("ai.opponent")
local Audio         = require("ui.audio")
local Character     = require("ui.character")
local C             = require("engine.constants")
local State         = require("engine.state")
local PauseMenu     = require("ui.menu.pause")
local CardLibrary   = require("ui.menu.library")
local Layout        = require("ui.match.layout")
local TopBar        = require("ui.match.topbar")
local BottomBar     = require("ui.match.bottombar")
local Toasts        = require("ui.match.toasts")
local Banner        = require("ui.match.banner")
local Hover         = require("ui.match.hover")
local Zoom          = require("ui.match.zoom")
local Tween         = require("ui.kit.tween")
local Confetti      = require("ui.match.confetti")
local DebugLog      = require("ui.match.debuglog")

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
local trapActivT      = 0   -- seconds since the active trap overlay opened (ui/overlay/trapfx.lua)

-- Cover / trap prompt hitboxes
local coverHitboxes = {}
local trapHitboxes  = {}
local promptAnim    = { y = 0 }   -- bottom prompt panel slide offset
local promptWindow  = nil         -- the cover/trap window the panel is showing (slide-in trigger)

-- Flux animations
local flyingCards = {}
local drawAnims   = {}   -- card-draw flying animations
local pitchAnims  = { hidden = {}, pop = {} }   -- summon squash-pop state, read by Pitch.draw
local combatT     = 0   -- seconds since the active combat overlay opened (ui/overlay/combatfx.lua)

-- Toasts (log events) and ribbon banner (Match.flash)
local toasts = Toasts.new()
local banner = Banner.new()

-- Half-time ribbon (full width) and the match-end screen
local HALF_BANNER = { y = 318, w = 1400, h = 84, size = 46, hold = 2.4, slide = 1500 }
local halfBanner  = Banner.new(HALF_BANNER)
local pendingHalf = nil   -- half-time text waiting for the overlays to clear
local winT        = nil   -- seconds since the match-end screen appeared

-- Card zoom (hover any card ~0.3s)
local hover    = Hover.new()
local zoomKey  = nil
local zoomAnim = { scale = 1 }

-- Debug log panel
local debugLogOpen   = false
local debugLogScroll = 0  -- lines scrolled from bottom

-- AI state machine
local aiPlan        = nil
local aiPlanTag     = nil   -- AI.planTag of the turn aiPlan was made for
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
    combatT             = 0
    trapActivQueue      = {}
    activeTrapActiv     = nil
    trapActivT          = 0
    coverHitboxes       = {}
    flyingCards         = {}
    drawAnims           = {}
    pitchAnims          = { hidden = {}, pop = {} }
    trapHitboxes        = {}
    promptAnim          = { y = 0 }
    promptWindow        = nil
    handHit             = { cards = {}, order = {}, defs = {} }
    aiPlan              = nil
    aiPlanTag           = nil
    aiActionIndex       = 0
    aiTimer             = 0
    debugLogOpen        = false
    debugLogScroll      = 0
    lastLogLen          = 0
    mouseX, mouseY      = -1, -1
    handMouseX, handMouseY = nil, nil
    toasts              = Toasts.new()
    banner              = Banner.new()
    halfBanner          = Banner.new(HALF_BANNER)
    pendingHalf         = nil
    winT                = nil
    Confetti.reset()
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

    if libraryOpen then CardLibrary.update(dt, mouseX, mouseY) end
    if pauseOpen and not libraryOpen then PauseMenu.update(dt, mouseX, mouseY) end

    Confetti.update(dt)
    Character.update(dt, match.players.player.lp)
    toasts:update(dt)
    banner:update(dt)
    -- Capped step, like the overlays: a stall must not skip the slide-in.
    halfBanner:update(math.min(dt, 1 / 30))
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
            Match.flash("MIDFIELD CONTROL +1 CARD", "good")
        elseif evt.type == "card_drawn" then
            Match.spawnDrawAnim(p.player == "player")
        elseif evt.type == "half_end" and not match.winner then
            pendingHalf = MatchEnd.halfText(p.half, match.players.player.halvesWon or 0,
                match.players.opponent.halvesWon or 0)
        end
        local text, kind = Toasts.describe(evt)
        if text then toasts:push(text, kind) end
    end
    lastLogLen = #log
    if scoutReveal then
        -- Capped step, like combatT/trapActivT: a stall (e.g. a snapshot capture) must
        -- not skip the flip or empty the timer in one frame.
        local step = math.min(dt, 1 / 30)
        scoutReveal.t     = (scoutReveal.t or 0) + step
        scoutReveal.timer = scoutReveal.timer - step
        if scoutReveal.timer <= 0 then scoutReveal = nil end
    end

    -- Bottom prompt panel slides up whenever a new cover/trap window opens for the player
    local win = (store.coverWindow and match.activePlayer == "opponent" and store.coverWindow) or store.trapWindow
    if win ~= promptWindow then
        promptWindow = win
        if win then
            promptAnim.y = PromptPanel.SLIDE
            flux.to(promptAnim, 0.32, { y = 0 }):ease("backout")
        end
    end

    -- Combat overlay: dequeue, then advance its timeline (ui/overlay/combatfx.lua).
    if not activeCombat and #combatQueue > 0 then
        activeCombat = table.remove(combatQueue, 1)
        combatT = 0
    end
    if activeCombat then
        local prevT = combatT
        -- Capped step: a first-draw hitch (fonts, canvases) must not skip the animation.
        combatT = combatT + math.min(dt, 1 / 30)
        -- LP damage: banner + confetti when the cards clash
        if CombatFx.crossed(prevT, combatT, CombatFx.CLASH)
           and activeCombat.damage and activeCombat.damage > 0 then
            Match.onLPDamage(match.activePlayer, activeCombat.outcome == "damage")
        end
    end

    -- Dequeue a trap activation overlay (only when no combat overlay is blocking)
    if not activeCombat and not activeTrapActiv and #trapActivQueue > 0 then
        activeTrapActiv = table.remove(trapActivQueue, 1)
        trapActivT = 0
        if activeTrapActiv.activator == "opponent" then
            Character.setState("worried")
        end
    end
    -- Capped step, like combatT: a first-draw hitch must not skip the animation.
    if activeTrapActiv and not activeCombat then trapActivT = trapActivT + math.min(dt, 1 / 30) end

    -- Half-time ribbon and match-end screen wait until the overlays are dismissed
    local overlaysClear = not activeCombat and not activeTrapActiv and #combatQueue == 0 and #trapActivQueue == 0
    if pendingHalf and overlaysClear then
        halfBanner:show(pendingHalf, "half")
        pendingHalf = nil
    end
    if match.winner and overlaysClear then
        local prevWin = winT
        -- Capped step, like the overlays: a stall must not skip the pop-in.
        winT = (winT or 0) + math.min(dt, 1 / 30)
        if match.winner == "player" and (not prevWin or math.floor(prevWin / 1.4) ~= math.floor(winT / 1.4)) then
            Confetti.burst(math.random(260, 1020), 180, 90)
        end
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
    if match.halfTimeBreak then store:kickOff() end -- TEMP until half-time screen

    if match.activePlayer == "player" and match.phase == "draw" then
        store:drawPhase()
        return
    end

    if match.activePlayer == "opponent" then
        -- A plan left over from the previous half (the AI won it mid-turn) is dropped, so
        -- the AI draws and summons on its first turn of the new half.
        if aiPlan and aiPlanTag ~= AI.planTag(match) then aiPlan = nil end
        if not aiPlan then
            aiPlan        = AI.planTurn()
            aiPlanTag     = AI.planTag(match)
            aiActionIndex = 1
            aiTimer       = AI_STEP_DELAY
        end

        aiTimer = aiTimer - dt
        if aiTimer > 0 then return end

        local action = aiPlan[aiActionIndex]
        if not action then aiPlan = nil; return end

        local done, extra, attackErr = AI.executeAction(store, action)
        if action.type == "attack" and not attackErr then Audio.play("attack") end
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
    -- The prompt panel / match-end screen covers the hand: no dock magnification poking out.
    local hmx, hmy = handMouseX, handMouseY
    if promptWindow or winT then hmx, hmy = nil, nil end
    handHit = Hand.draw(match.players.player.hand,
        selectedHandCard and selectedHandCard.id or nil, hmx, hmy)

    -- Confetti (drawn above the match-end screen instead, once it is up)
    if not winT then Confetti.draw() end

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
        if p.above then
            Zoom.drawInfoAbove(p.cardDef, p.src)
        else
            Zoom.draw({ cardDef = p.cardDef, pitched = p.pitched, pitch = p.pitch, hideHidden = p.hideHidden,
                        src = p.src, scale = zoomAnim.scale })
        end
    end

    -- Flash banner
    banner:draw()
    halfBanner:draw()

    -- Combat overlay — drawn directly (backdrop must cover full screen)
    if activeCombat then
        CombatOverlay.draw(activeCombat, combatT)
    end

    -- Trap activation overlay (cinematic reveal, shown after combat if both pending)
    if activeTrapActiv then
        TrapActivOverlay.draw(activeTrapActiv, trapActivT)
    end

    -- Scout Report reveal overlay
    if scoutReveal then
        Reveal.draw(scoutReveal.card, scoutReveal.t or 0, scoutReveal.timer)
    end

    -- Cover prompt (player defending against opponent attack)
    if store.coverWindow and not activeCombat and match.activePlayer == "opponent" then
        coverHitboxes = Prompts.drawCover(store.coverWindow, promptAnim.y, mouseX, mouseY)
    else
        coverHitboxes = {}
    end

    -- Trap window (player decides whether to activate their set trap)
    if store.trapWindow and not activeCombat then
        trapHitboxes = Prompts.drawTrapWindow(store.trapWindow, promptAnim.y, mouseX, mouseY)
    else
        trapHitboxes = {}
    end

    -- AI hand debug (TAB)
    if aiHandDebug then DebugLog.drawAIHand(match) end

    -- Full match log (log button / L)
    if debugLogOpen then debugLogScroll = DebugLog.draw(match, debugLogScroll) end

    if winT then
        MatchEnd.draw(match, winT, mouseX, mouseY)
        Confetti.draw()
    end

    -- Pause menu / card library (always on top of everything)
    if libraryOpen then CardLibrary.draw() end
    if pauseOpen and not libraryOpen then PauseMenu.draw() end
end

-- Key + payload for the card under the mouse (nil when nothing zoomable).
-- The opponent's traps and unrevealed face-down cards are never zoomable (hidden information).
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
            if Hover.zoomable(s.owner, s.slotType, card) then
                return Pitch.slotKey(s.owner, s.slotType, s.slotIndex) .. ":" .. tostring(card.definition.id),
                    { cardDef = card.definition, pitched = card, pitch = pitch, src = s,
                      hideHidden = s.owner == "opponent" }
            end
            return nil
        end
    end
    return nil
end

-- One-line instruction shown between the pitch and the hand.
function Match.hintText(match)
    if activeCombat or (store and (store.coverWindow or store.trapWindow)) then return "" end
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
        elseif State.isOpeningTurn(match) then
            return "First turn of the half: no attacks or shots  ·  END TURN when done"
        elseif selectedAttackerSlot then
            return "Click an opponent slot to attack  ·  ESC to cancel"
        elseif not match.strategyPlayedThisTurn then
            return "Click your card to attack  ·  Click a STRATEGY card to play it  ·  END TURN"
        end
        return "Click your card (attack mode) to select an attacker  ·  END TURN when done"
    end
    return ""
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
            -- Scout targets: the opponent's face-down cards that are not revealed yet.
            local function hidden(c) return c and c.mode == "defense" and not c.revealed end
            if hidden(oppPitch.keeper) then
                table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
            end
            if hidden(oppPitch.midfielder) then
                table.insert(slots, { slotType="midfielder", slotIndex=0, owner="opponent" })
            end
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if hidden(oppPitch.defenders[i]) then
                    table.insert(slots, { slotType="defender", slotIndex=i, owner="opponent" })
                end
            end
            for i = 1, C.PITCH.MAX_STRIKERS do
                if hidden(oppPitch.strikers[i]) then
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
    if State.isOpeningTurn(match) then return {} end   -- first turn of the half: hint, no targets
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

local function openPause()
    pauseOpen = true
    PauseMenu.open()
end

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

    -- Match-end screen: PLAY AGAIN / MAIN MENU
    if winT then return MatchEnd.actionAt(x, y) end

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
    if btn == "pause" then openPause(); return end
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
                if oppCard and oppCard.mode == "defense" and not oppCard.revealed then
                    local result, err = store:playStrategy(selectedHandCard.id, {
                        targetSlot = { owner = "opponent", type = slot.slotType, index = slot.slotIndex }
                    })
                    if result then
                        Audio.play("card_play_strategy")
                        scoutReveal = { card = result.revealedCard, timer = 3.5, t = 0 }
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
                local _, attackErr = store:declareAttack(
                    selectedAttackerSlot,
                    { type=slot.slotType, index=slot.slotIndex }
                )
                if attackErr then
                    Match.flash(attackErr)
                else
                    -- Only an accepted attack gets the sound and the attack pose.
                    Audio.play("attack")
                    Character.setState("attacking")
                end
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

    if winT then return MatchEnd.keyAction(key) end

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
        else openPause() end
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

function Match.getCardInSlot(pitch, slot)
    if slot.slotType == "keeper"     then return pitch.keeper end
    if slot.slotType == "midfielder" then return pitch.midfielder end
    if slot.slotType == "defender"   then return pitch.defenders[slot.slotIndex] end
    if slot.slotType == "striker"    then return pitch.strikers[slot.slotIndex] end
    return nil
end

-- Dev hook for tools/snapshot scenarios.
function Match.debugStore() return store end

-- Dev hook for tools/snapshot scenarios: show a synthetic overlay.
--   kind = "combat" (store combat record) | "trap" (trap activation record) | "scout" (pitched card)
function Match.debugOverlay(kind, rec)
    if kind == "combat" then
        table.insert(combatQueue, rec)
    elseif kind == "trap" then
        table.insert(trapActivQueue, rec)
    elseif kind == "scout" then
        scoutReveal = { card = rec, timer = 3.5, t = 0 }
    end
end

function Match.inRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w
       and y >= rect.y and y <= rect.y + rect.h
end

return Match
