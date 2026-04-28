-- scenes/gwent_match.lua
local flux   = require("lib.flux")
local Theme  = require("ui.theme")
local Fonts  = require("ui.fonts")
local AI     = require("ai.gwent_opponent")
local State  = require("engine.gwent.state")

local GM = {}

-- ── Layout ────────────────────────────────────────────────────────────────────
local L = {
    pitchX    = 200,
    pitchW    = 880,
    topBarH   = 36,
    rowH      = 100,
    scoreDivH = 20,
    passH     = 44,
    handH     = 100,
    leftW     = 200,
    rightW    = 200,
}
-- Row Y positions (top of each row)
L.rowY = {
    opp_defense  = L.topBarH,
    opp_midfield = L.topBarH + L.rowH,
    opp_attack   = L.topBarH + L.rowH * 2,
    scoreDiv     = L.topBarH + L.rowH * 3,
    pl_attack    = L.topBarH + L.rowH * 3 + L.scoreDivH,
    pl_midfield  = L.topBarH + L.rowH * 3 + L.scoreDivH + L.rowH,
    pl_defense   = L.topBarH + L.rowH * 3 + L.scoreDivH + L.rowH * 2,
    passStrip    = L.topBarH + L.rowH * 3 + L.scoreDivH + L.rowH * 3,
    hand         = L.topBarH + L.rowH * 3 + L.scoreDivH + L.rowH * 3 + L.passH,
}
-- Gwent pitched card size
local GCW, GCH = 52, 72

-- ── Scene state ───────────────────────────────────────────────────────────────
local store            = nil
local aiDifficulty     = "medium"
local selectedHandCard = nil   -- instanceId of selected hand card, or nil
local mulliganSelected = {}    -- instanceIds toggled for mulligan
local rowHitboxes      = {}    -- { row, playerId, x, y, w, h }
local cardHitboxes     = {}    -- pitched card hitboxes for targeting abilities
local handHitboxes     = {}    -- hand card hitboxes
local flashMsg         = nil
local flashTimer       = 0
local FLASH_DURATION   = 2.2
local aiTimer          = 0
local AI_DELAY         = 0.70
local logScroll        = 0   -- lines scrolled up from bottom (0 = newest visible)

-- ── Entry ─────────────────────────────────────────────────────────────────────

function GM.enter(gwentStore, difficulty)
    store          = gwentStore
    aiDifficulty   = difficulty or "medium"
    selectedHandCard = nil
    mulliganSelected = {}
    rowHitboxes    = {}
    cardHitboxes   = {}
    handHitboxes   = {}
    flashMsg       = nil
    flashTimer     = 0
    aiTimer        = 0
    logScroll      = 0
end

-- ── Update ────────────────────────────────────────────────────────────────────

function GM.update(dt)
    flux.update(dt)

    -- Flash message timer
    if flashMsg then
        flashTimer = flashTimer - dt
        if flashTimer <= 0 then flashMsg = nil end
    end

    if not store or not store.match then return end
    local match = store.match
    if match.winner then return end

    -- AI mulligan: auto-resolve after short delay
    if match.phase == "mulligan" and match.mulliganLeft.opponent > 0 then
        aiTimer = aiTimer - dt
        if aiTimer <= 0 then
            local action = AI.pickAction(store)
            if action and action.type == "mulligan" then
                store:resolveMulligan("opponent", action.instanceIds)
                aiTimer = AI_DELAY
            end
        end
        return
    end

    -- AI turn
    if match.phase == "play" and match.activePlayer == "opponent" then
        aiTimer = aiTimer - dt
        if aiTimer <= 0 then
            local action = AI.pickAction(store)
            if action then
                GM._executeAIAction(action)
                aiTimer = AI_DELAY
            end
        end
    end
end

function GM._executeAIAction(action)
    if not store or not store.match then return end
    if action.type == "card" then
        store:playCard(action.instanceId, action.row)
    elseif action.type == "special" then
        store:playSpecial(action.instanceId)
    elseif action.type == "leader" then
        store:activateLeader()
    elseif action.type == "pass" then
        store:pass()
    elseif action.type == "mulligan" then
        store:resolveMulligan("opponent", action.instanceIds)
    elseif action.type == "medic" then
        store:resolveMedic(action.graveyardIndex)
    elseif action.type == "decoy" then
        store:resolveDecoy(action.targetRow, action.targetIndex)
    elseif action.type == "agility" then
        store:resolveAgility(action.chosenRow)
    elseif action.type == "horn" then
        store:resolveHorn(action.chosenRow)
    end
end

-- ── Input ─────────────────────────────────────────────────────────────────────

function GM.keypressed(key)
    if key == "escape" then return "home" end
    return nil
end

function GM.wheelmoved(_x, y)
    logScroll = math.max(0, logScroll - y)
end

function GM.mousepressed(mx, my, button)
    if button ~= 1 then return nil end
    if not store or not store.match then return nil end
    local match = store.match

    -- End-of-match: click anywhere returns to home
    if match.winner then return "home" end

    -- Mulligan confirm button
    if match.phase == "mulligan" then
        GM._handleMulliganClick(mx, my)
        return nil
    end

    if match.phase ~= "play" then return nil end

    -- Handle pending interactive actions (Agility, Horn, Medic, Decoy)
    if match.pendingAction and match.pendingAction.pid == "player" then
        local pa = match.pendingAction
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        if pa.type == "agility_choose" or pa.type == "horn_choose" then
            local rows = { "attack", "midfield", "defense" }
            for i, row in ipairs(rows) do
                local bx = W * 0.5 - 120 + (i - 2) * 270
                local by = H * 0.48
                if mx >= bx and mx <= bx + 230 and my >= by and my <= by + 50 then
                    if pa.type == "agility_choose" then
                        store:resolveAgility(row)
                    else
                        store:resolveHorn(row)
                    end
                    return nil
                end
            end
        elseif pa.type == "decoy_choose" then
            -- Click on a player's non-hero pitched card to return it
            for _, cb in ipairs(cardHitboxes) do
                if cb.playerId == "player"
                and mx >= cb.x and mx <= cb.x + cb.w
                and my >= cb.y and my <= cb.y + cb.h then
                    store:resolveDecoy(cb.row, cb.index)
                    return nil
                end
            end
        elseif pa.type == "medic_choose" then
            local graveyard = match.players["player"].graveyard
            local nonHero = {}
            for i, def in ipairs(graveyard) do
                if not def.hero then table.insert(nonHero, { i = i, def = def }) end
            end
            local cardW, cardH, gap = 120, 160, 14
            local total = #nonHero
            local startX = W * 0.5 - (total * (cardW + gap)) * 0.5
            for k, entry in ipairs(nonHero) do
                local cx = startX + (k - 1) * (cardW + gap)
                local cy = H * 0.42
                if mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH then
                    store:resolveMedic(entry.i)
                    return nil
                end
            end
        end
        return nil  -- consume all clicks while pending
    end

    if match.activePlayer ~= "player" then return nil end

    -- Pass button
    local passY = L.rowY.passStrip
    if mx >= L.pitchX + 10 and mx <= L.pitchX + 200
    and my >= passY + 6 and my <= passY + L.passH - 6 then
        store:pass()
        selectedHandCard = nil
        return nil
    end

    -- Leader activate button (left panel, bottom area)
    if mx >= 8 and mx <= L.leftW - 8 and my >= 680 and my <= 700 then
        if not match.leaderUsed.player then
            store:activateLeader()
        end
        return nil
    end

    -- Hand card selection
    for _, hb in ipairs(handHitboxes) do
        if mx >= hb.x and mx <= hb.x + hb.w and my >= hb.y and my <= hb.y + hb.h then
            if selectedHandCard == hb.instanceId then
                selectedHandCard = nil  -- deselect
            else
                selectedHandCard = hb.instanceId
            end
            return nil
        end
    end

    -- Row click (play selected card to row)
    if selectedHandCard then
        for _, rb in ipairs(rowHitboxes) do
            if rb.playerId == "player"
            and mx >= rb.x and mx <= rb.x + rb.w
            and my >= rb.y and my <= rb.y + rb.h then
                GM._tryPlayCard(selectedHandCard, rb.row, mx, my)
                return nil
            end
        end

    end

    return nil
end

function GM._tryPlayCard(instanceId, row, _mx, _my)
    local match = store.match
    local hand  = match.players.player.hand
    local hc    = nil
    for _, c in ipairs(hand) do
        if c.instanceId == instanceId then hc = c; break end
    end
    if not hc then selectedHandCard = nil; return end

    local def = hc.definition

    -- Special cards (Decoy, Horn, Scorch, Weather, Clear Weather)
    if def.row == "special" then
        local ok, err = store:playSpecial(instanceId)
        if ok then selectedHandCard = nil
        else GM._flash(err or "Cannot play special") end
        return
    end

    -- Agility cards can go to any row
    if def.ability == "AGILITY" then
        local ok, err = store:playCard(instanceId, row)
        if ok then selectedHandCard = nil
        else GM._flash(err or "Cannot play card") end
        return
    end

    if def.row ~= row then
        GM._flash("This card belongs to the " .. def.row .. " row")
        return
    end

    local ok, err = store:playCard(instanceId, row)
    if ok then selectedHandCard = nil
    else GM._flash(err or "Cannot play card") end
end


function GM._handleMulliganClick(mx, my)
    local match = store.match
    if not match or match.phase ~= "mulligan" then return end
    if match.mulliganLeft.player <= 0 then return end

    -- Confirm button (centered, y=750, h=36)
    local W = love.graphics.getWidth()
    local btnW = 160
    local btnX = (W - btnW) / 2
    if mx >= btnX and mx <= btnX + btnW and my >= 750 and my <= 786 then
        store:resolveMulligan("player", mulliganSelected)
        mulliganSelected = {}
        return
    end

    -- Toggle hand cards
    for _, hb in ipairs(handHitboxes) do
        if mx >= hb.x and mx <= hb.x + hb.w and my >= hb.y and my <= hb.y + hb.h then
            local left = match.mulliganLeft.player
            local found = false
            for i, id in ipairs(mulliganSelected) do
                if id == hb.instanceId then
                    table.remove(mulliganSelected, i)
                    found = true
                    break
                end
            end
            if not found and #mulliganSelected < left then
                table.insert(mulliganSelected, hb.instanceId)
            end
            return
        end
    end
end

function GM._flash(msg)
    flashMsg   = msg
    flashTimer = FLASH_DURATION
end

-- ── Gwent card renderer ───────────────────────────────────────────────────────

-- rowType maps to Theme colors: "attack"→striker, "midfield"→midfielder, "defense"→defender
local rowTypeMap = { attack = "striker", midfield = "midfielder", defense = "defender" }

-- effPower: precomputed effective power (pass from drawRow for correct context)
function GM.drawGwentCard(pc, x, y, w, h, highlighted, effPower)
    w = w or GCW; h = h or GCH
    local def      = pc.definition
    local rtype    = rowTypeMap[def.row] or "midfielder"
    local baseCol  = Theme.cardColors[rtype]    or {0.2, 0.2, 0.25, 1}
    local accCol   = Theme.cardAccents[rtype]   or {0.5, 0.5, 0.7, 1}
    local power    = effPower or pc.basePower
    local basePow  = pc.basePower
    local weathered = effPower and not def.hero and effPower == 1 and basePow > 1

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 3, y + 3, w, h, 4)

    -- Body
    if weathered then
        love.graphics.setColor(0.15, 0.12, 0.05, 1)
    else
        love.graphics.setColor(baseCol[1] * 0.45, baseCol[2] * 0.45, baseCol[3] * 0.45, 1)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4)

    -- Header strip
    love.graphics.setColor(baseCol[1] * 0.80, baseCol[2] * 0.80, baseCol[3] * 0.80, 1)
    love.graphics.rectangle("fill", x, y, w, 16, 4)
    love.graphics.rectangle("fill", x, y + 10, w, 6)

    -- Border
    if highlighted then
        love.graphics.setColor(1, 1, 0.4, 0.90)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(accCol[1], accCol[2], accCol[3], 0.55)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, w, h, 4)
    love.graphics.setLineWidth(1)

    -- Power number (large, centered)
    local powerColor
    if weathered then
        powerColor = {0.7, 0.5, 0.2, 1}
    elseif power > basePow then
        powerColor = {0.3, 1, 0.5, 1}
    elseif power < basePow then
        powerColor = {1, 0.3, 0.3, 1}
    else
        powerColor = {1, 1, 1, 1}
    end
    Fonts.with(20, function()
        love.graphics.setColor(powerColor)
        love.graphics.printf(tostring(power), x, y + 20, w, "center")
    end)

    -- Hero indicator
    if def.hero then
        Fonts.with(7, function()
            love.graphics.setColor(1, 0.85, 0.2, 0.9)
            love.graphics.printf("H", x, y + 2, w, "center")
        end)
    end

    -- Card name (tiny, truncated)
    local shortName = (def.name or ""):gsub("^The ", "")
    Fonts.with(7, function()
        love.graphics.setColor(0.75, 0.75, 0.80, 1)
        love.graphics.printf(shortName, x + 2, y + h - 14, w - 4, "center")
    end)
end

-- ── Draw (skeleton — rows/HUD added in following tasks) ──────────────────────

function GM.draw()
    if not store or not store.match then return end
    local match = store.match

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Background
    love.graphics.setColor(0.035, 0.055, 0.045, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Pitch area background
    love.graphics.setColor(0.040, 0.070, 0.052, 1)
    love.graphics.rectangle("fill", L.pitchX, 0, L.pitchW, H)

    GM.drawTopBar(match)
    GM.drawRows(match)
    GM.drawScoreBar(match)
    GM.drawLeaderPanel(match)
    GM.drawPassButton(match)
    GM.drawHand(match)

    if match.phase == "mulligan" then
        GM.drawMulliganOverlay(match)
    end

    if match.winner then
        GM.drawEndScreen(match)
    end

    if match.pendingAction and match.pendingAction.pid == "player" then
        GM.drawPendingOverlay(match)
    end

    -- Flash message
    if flashMsg then
        local alpha = math.min(1, flashTimer / 0.4)
        Fonts.with(13, function()
            love.graphics.setColor(1, 0.85, 0.3, alpha)
            love.graphics.printf(flashMsg, L.pitchX, H / 2 - 14, L.pitchW, "center")
        end)
    end
end

-- Stub functions — filled in subsequent tasks
function GM.drawTopBar(match)
    local W = love.graphics.getWidth()
    love.graphics.setColor(0.02, 0.03, 0.025, 1)
    love.graphics.rectangle("fill", 0, 0, W, L.topBarH)

    -- Half indicator
    local halfStr = "HALF " .. tostring(match.half):upper()
    Fonts.with(11, function()
        love.graphics.setColor(0.55, 0.85, 0.65, 1)
        love.graphics.printf(halfStr, L.pitchX, 10, L.pitchW, "center")
    end)

    -- Hand counts
    local ph  = #match.players.player.hand
    local oh  = #match.players.opponent.hand
    Fonts.with(9, function()
        love.graphics.setColor(0.60, 0.60, 0.65, 1)
        love.graphics.print("OPP HAND: " .. oh, L.pitchX + 8, 12)
        love.graphics.print("YOUR HAND: " .. ph, L.pitchX + L.pitchW - 100, 12)
    end)

    -- Active player indicator
    local turn = match.activePlayer == "player" and "YOUR TURN" or "OPPONENT"
    local tc   = match.activePlayer == "player" and {0.3, 1, 0.5, 1} or {1, 0.5, 0.3, 1}
    Fonts.with(9, function()
        love.graphics.setColor(tc)
        love.graphics.printf(turn, L.pitchX, 22, L.pitchW, "center")
    end)
end
function GM.drawRows(match)
    rowHitboxes  = {}
    cardHitboxes = {}

    -- Each row: { side, rowKey, label, pitchKey }
    local rows = {
        { side = "opponent", key = "defense",  label = "DEF", y = L.rowY.opp_defense  },
        { side = "opponent", key = "midfield", label = "MID", y = L.rowY.opp_midfield },
        { side = "opponent", key = "attack",   label = "ATK", y = L.rowY.opp_attack   },
        { side = "player",   key = "attack",   label = "ATK", y = L.rowY.pl_attack    },
        { side = "player",   key = "midfield", label = "MID", y = L.rowY.pl_midfield  },
        { side = "player",   key = "defense",  label = "DEF", y = L.rowY.pl_defense   },
    }

    for _, r in ipairs(rows) do
        GM.drawRow(match, r.side, r.key, r.label, r.y)
    end
end

function GM.drawRow(match, side, rowKey, label, rowY)
    local isPlayer    = side == "player"
    local cards       = match.players[side].pitch[rowKey]
    local isWeathered = match.weather[rowKey] ~= nil
    local isHorned    = match.hornRows[side] and match.hornRows[side][rowKey] or false
    local rowX        = L.pitchX
    local rowW        = L.pitchW

    -- Row background
    local alpha = 0.25
    if isWeathered then alpha = 0.40 end
    love.graphics.setColor(0.05, 0.09, 0.06, alpha)
    love.graphics.rectangle("fill", rowX, rowY, rowW, L.rowH)

    -- Weather tint
    if isWeathered then
        love.graphics.setColor(0.3, 0.15, 0.05, 0.22)
        love.graphics.rectangle("fill", rowX, rowY, rowW, L.rowH)
    end

    -- Row label (left edge)
    Fonts.with(9, function()
        love.graphics.setColor(0.50, 0.80, 0.60, 0.75)
        love.graphics.print(label, rowX + 4, rowY + (L.rowH - 11) / 2)
    end)

    -- Weather / Horn indicators
    Fonts.with(8, function()
        local indX = rowX + 4
        local indY = rowY + 2
        if isWeathered then
            local wt = match.weather[rowKey]
            local wlabel = wt == "FROST" and "ICE" or wt == "FOG" and "FOG" or wt == "RAIN" and "RAIN" or "WX"
            love.graphics.setColor(0.3, 0.6, 1, 0.9)
            love.graphics.print(wlabel, indX, indY)
            indX = indX + 28
        end
        if isHorned then
            love.graphics.setColor(1, 0.8, 0.1, 0.9)
            love.graphics.print("HORN", indX, indY)
        end
    end)

    -- Highlight if valid drop target (player's own row, card selected)
    local isTarget = isPlayer and selectedHandCard ~= nil
    if isTarget then
        local hand = match.players.player.hand
        for _, hc in ipairs(hand) do
            if hc.instanceId == selectedHandCard then
                local def = hc.definition
                if def.row == rowKey or def.ability == "AGILITY" then
                    love.graphics.setColor(0.3, 0.7, 0.4, 0.14)
                    love.graphics.rectangle("fill", rowX + 20, rowY + 4, rowW - 24, L.rowH - 8, 6)
                    love.graphics.setColor(0.3, 0.8, 0.4, 0.55)
                    love.graphics.setLineWidth(1.5)
                    love.graphics.rectangle("line", rowX + 20, rowY + 4, rowW - 24, L.rowH - 8, 6)
                    love.graphics.setLineWidth(1)
                end
                break
            end
        end
        table.insert(rowHitboxes, {
            row = rowKey, playerId = side,
            x = rowX + 20, y = rowY + 4, w = rowW - 24, h = L.rowH - 8,
        })
    end

    -- Draw cards
    local cardPad  = 4
    local startX   = rowX + 28
    local cy       = rowY + (L.rowH - GCH) / 2
    local rowPower = 0

    for i, pc in ipairs(cards) do
        local cx = startX + (i - 1) * (GCW + cardPad)
        if cx + GCW <= rowX + rowW - 40 then
            local effP = State.effectivePower(pc, cards, isWeathered, isHorned)
            GM.drawGwentCard(pc, cx, cy, GCW, GCH, false, effP)
            table.insert(cardHitboxes, {
                playerId = side, row = rowKey, index = i,
                instanceId = pc.instanceId,
                x = cx, y = cy, w = GCW, h = GCH,
            })
        end
        rowPower = rowPower + State.effectivePower(pc, cards, isWeathered, isHorned)
    end

    -- Row power total (right edge)
    Fonts.with(14, function()
        love.graphics.setColor(0.85, 0.95, 0.85, 0.90)
        love.graphics.print(tostring(rowPower), rowX + rowW - 36, rowY + (L.rowH - 16) / 2)
    end)

    -- Row border line
    love.graphics.setColor(0.15, 0.30, 0.20, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.line(rowX, rowY, rowX + rowW, rowY)
    love.graphics.line(rowX, rowY + L.rowH, rowX + rowW, rowY + L.rowH)
end
function GM.drawScoreBar(match)
    local rowX  = L.pitchX
    local rowW  = L.pitchW
    local divY  = L.rowY.scoreDiv
    local ps    = State.score(match.players.player,   match, "player")
    local os    = State.score(match.players.opponent, match, "opponent")

    -- Divider background
    love.graphics.setColor(0.03, 0.05, 0.04, 1)
    love.graphics.rectangle("fill", rowX, divY, rowW, L.scoreDivH)

    -- Scores
    local function scoreColor(mine, theirs)
        if mine > theirs  then return {0.3, 1, 0.5, 1}
        elseif mine < theirs then return {1, 0.35, 0.35, 1}
        else return {0.85, 0.85, 0.85, 1} end
    end

    Fonts.with(13, function()
        -- Opponent score (left side of divider)
        love.graphics.setColor(scoreColor(os, ps))
        love.graphics.printf("OPP  " .. tostring(os), rowX, divY + 2, rowW / 2 - 10, "right")
        -- Player score (right side)
        love.graphics.setColor(scoreColor(ps, os))
        love.graphics.printf(tostring(ps) .. "  YOU", rowX + rowW / 2 + 10, divY + 2, rowW / 2 - 10, "left")
    end)

    -- Halves won dots (two half-slots, OPP above / YOU below)
    local dotR = 3
    local dotY = divY + L.scoreDivH / 2
    for i = 1, 2 do
        local dotX = rowX + rowW / 2 - 10 + (i - 1) * 12
        -- Opponent half dot (above divider center)
        if match.halvesWon.opponent >= i then
            love.graphics.setColor(1, 0.35, 0.35, 1)
        else
            love.graphics.setColor(0.25, 0.25, 0.25, 1)
        end
        love.graphics.circle("fill", dotX, dotY - 5, dotR)
        -- Player half dot (below divider center)
        if match.halvesWon.player >= i then
            love.graphics.setColor(0.3, 1, 0.5, 1)
        else
            love.graphics.setColor(0.25, 0.25, 0.25, 1)
        end
        love.graphics.circle("fill", dotX, dotY + 5, dotR)
    end
end
function GM.drawLeaderPanel(match)
    local H = love.graphics.getHeight()

    -- Panel background
    love.graphics.setColor(0.025, 0.025, 0.030, 1)
    love.graphics.rectangle("fill", 0, 0, L.leftW, H)
    love.graphics.setColor(0.12, 0.22, 0.15, 0.60)
    love.graphics.setLineWidth(1)
    love.graphics.line(L.leftW - 1, 0, L.leftW - 1, H)

    -- "LEADERS" header
    Fonts.with(9, function()
        love.graphics.setColor(0.50, 0.75, 0.55, 0.80)
        love.graphics.printf("LEADERS", 0, 8, L.leftW, "center")
    end)

    -- Helper: draw a leader card block
    local function drawLeader(pid, labelY, btnY)
        local p      = match.players[pid]
        local leader = p.leader
        if not leader then return end
        local used   = match.leaderUsed[pid]

        -- Card background
        local bcol = pid == "player" and {0.08, 0.22, 0.12, 1} or {0.22, 0.08, 0.08, 1}
        if used then bcol = {0.08, 0.08, 0.10, 1} end
        love.graphics.setColor(bcol)
        love.graphics.rectangle("fill", 8, labelY, L.leftW - 16, 80, 6)
        love.graphics.setColor(used and {0.2,0.2,0.2,0.5} or {0.3,0.6,0.35,0.7})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 8, labelY, L.leftW - 16, 80, 6)

        -- Leader name
        Fonts.with(10, function()
            love.graphics.setColor(used and {0.4,0.4,0.4,1} or {0.9,0.95,0.9,1})
            love.graphics.printf(leader.name, 10, labelY + 6, L.leftW - 20, "center")
        end)

        -- Ability text
        Fonts.with(7, function()
            love.graphics.setColor(used and {0.3,0.3,0.3,1} or {0.55,0.80,0.60,1})
            love.graphics.printf(leader.abilityText or "", 10, labelY + 22, L.leftW - 20, "center")
        end)

        -- Activate button (player only)
        if pid == "player" then
            if used then
                love.graphics.setColor(0.15, 0.15, 0.15, 1)
                love.graphics.rectangle("fill", 16, btnY, L.leftW - 32, 22, 4)
                Fonts.with(8, function()
                    love.graphics.setColor(0.35, 0.35, 0.35, 1)
                    love.graphics.printf("USED", 0, btnY + 5, L.leftW, "center")
                end)
            else
                love.graphics.setColor(0.12, 0.42, 0.22, 1)
                love.graphics.rectangle("fill", 16, btnY, L.leftW - 32, 22, 4)
                love.graphics.setColor(0.3, 0.8, 0.4, 0.8)
                love.graphics.setLineWidth(1.5)
                love.graphics.rectangle("line", 16, btnY, L.leftW - 32, 22, 4)
                love.graphics.setLineWidth(1)
                Fonts.with(8, function()
                    love.graphics.setColor(0.8, 1, 0.85, 1)
                    love.graphics.printf("ACTIVATE", 0, btnY + 5, L.leftW, "center")
                end)
            end
        end
    end

    -- Opponent leader (top)
    drawLeader("opponent", 26, 114)
    -- Player leader (bottom of panel, above hand area)
    drawLeader("player", 620, 708)

    -- Faction labels
    Fonts.with(8, function()
        love.graphics.setColor(0.40, 0.60, 0.45, 0.70)
        local pf = (match.players.player.faction or ""):gsub("_", " "):upper()
        local of = (match.players.opponent.faction or ""):gsub("_", " "):upper()
        love.graphics.printf(of, 0, 110, L.leftW, "center")
        love.graphics.printf(pf, 0, 608, L.leftW, "center")
    end)

    -- Right panel — event log
    local rpx = L.pitchX + L.pitchW
    love.graphics.setColor(0.020, 0.022, 0.025, 1)
    love.graphics.rectangle("fill", rpx, 0, L.rightW, H)
    love.graphics.setColor(0.12, 0.22, 0.15, 0.60)
    love.graphics.line(rpx, 0, rpx, H)

    GM.drawEventLog(match, rpx, 0, L.rightW, H)
end

-- ── Event log (right panel) ───────────────────────────────────────────────────

local function fmtLogEntry(e)
    local who = e.player == "player" and "YOU" or e.player == "opponent" and "OPP" or nil
    if e.type == "play_card" then
        local name = (e.card or "?"):gsub("^The ", "")
        return who .. " played " .. name .. " (" .. (e.row or "") .. ")", {0.45, 0.90, 0.55}
    elseif e.type == "play_strategy" then
        return who .. " strategy: " .. (e.card or "?"), {0.40, 0.80, 1.00}
    elseif e.type == "set_trap" then
        return who .. " set a trap", {0.85, 0.55, 1.00}
    elseif e.type == "trap_activated" then
        local name = (e.card or "?"):gsub("^The ", ""):gsub("^Press ", "")
        return "TRAP fired: " .. name, {1.00, 0.45, 0.85}
    elseif e.type == "leader_activated" then
        return who .. " used leader", {1.00, 0.85, 0.30}
    elseif e.type == "boost" then
        return "  +" .. (e.amount or "?") .. "  " .. ((e.card or "?"):gsub("^The ", "")), {0.35, 1.00, 0.55}
    elseif e.type == "reduce" then
        return "  -" .. (e.amount or "?") .. "  " .. ((e.card or "?"):gsub("^The ", "")), {1.00, 0.40, 0.40}
    elseif e.type == "lock" then
        return "  LOCKED: " .. ((e.card or "?"):gsub("^The ", "")), {0.85, 0.65, 1.00}
    elseif e.type == "pass" then
        return who .. " passed", {0.55, 0.55, 0.65}
    elseif e.type == "half_end" then
        local w = e.winner == "player" and "YOU" or e.winner == "opponent" and "OPP" or "DRAW"
        return "── Half " .. (e.half or "?") .. " → " .. w .. " ──", {1.00, 0.85, 0.25}
    elseif e.type == "half_start" then
        return "── Half " .. (e.half or "?") .. " begins ──", {0.55, 0.75, 1.00}
    elseif e.type == "draw" then
        return who .. " drew a card", {0.60, 0.60, 0.75}
    elseif e.type == "move_card" then
        return "  moved to " .. (e.to or "?"), {0.65, 0.85, 0.65}
    elseif e.type == "counter_press_fired" then
        return "Counter Press fires!", {1.00, 0.55, 0.30}
    elseif e.type == "discard_opponent" then
        return "  discarded: " .. ((e.card or "?"):gsub("^The ", "")), {1.00, 0.55, 0.30}
    end
    return nil, nil
end

function GM.drawEventLog(match, px, py, pw, ph)
    local lineH  = 15
    local padX   = 6
    local headerH = 28
    local innerH  = ph - headerH - 4
    local maxLines = math.floor(innerH / lineH)

    -- Build lines from match.log
    local lines = {}
    for _, e in ipairs(match.log) do
        local txt, col = fmtLogEntry(e)
        if txt then
            table.insert(lines, { txt = txt, col = col or {0.65, 0.65, 0.70} })
        end
    end

    -- Header
    Fonts.with(9, function()
        love.graphics.setColor(0.35, 0.60, 0.42, 0.90)
        love.graphics.printf("EVENT LOG", px, py + 8, pw, "center")
        love.graphics.setColor(0.15, 0.25, 0.18, 1)
        love.graphics.line(px + 6, py + headerH - 1, px + pw - 6, py + headerH - 1)
    end)

    -- Clamp scroll
    local total = #lines
    local maxScroll = math.max(0, total - maxLines)
    logScroll = math.max(0, math.min(logScroll, maxScroll))

    -- Draw lines (newest at bottom)
    local endIdx   = math.max(0, total - logScroll)
    local startIdx = math.max(1, endIdx - maxLines + 1)
    local drawY    = py + headerH + 2

    Fonts.with(9, function()
        for i = startIdx, endIdx do
            local ln = lines[i]
            love.graphics.setColor(ln.col[1], ln.col[2], ln.col[3], 0.90)
            love.graphics.printf(ln.txt, px + padX, drawY, pw - padX * 2, "left")
            drawY = drawY + lineH
        end
    end)

    -- Scroll hint when there's overflow
    if maxScroll > 0 then
        Fonts.with(8, function()
            love.graphics.setColor(0.35, 0.35, 0.40, 0.70)
            love.graphics.printf("scroll: mouse wheel", px, py + ph - 14, pw, "center")
        end)
    end
end
function GM.drawPassButton(match)
    local passY    = L.rowY.passStrip
    local isPlayer = match.activePlayer == "player"
    local hasPassed = match.passed.player
    local W        = love.graphics.getWidth()

    love.graphics.setColor(0.02, 0.03, 0.025, 1)
    love.graphics.rectangle("fill", L.pitchX, passY, L.pitchW, L.passH)

    if hasPassed then
        love.graphics.setColor(0.20, 0.20, 0.22, 1)
        love.graphics.rectangle("fill", L.pitchX + 10, passY + 6, 190, L.passH - 12, 6)
        Fonts.with(10, function()
            love.graphics.setColor(0.35, 0.35, 0.35, 1)
            love.graphics.printf("PASSED", L.pitchX, passY + 12, 210, "center")
        end)
    elseif not isPlayer then
        love.graphics.setColor(0.10, 0.10, 0.12, 1)
        love.graphics.rectangle("fill", L.pitchX + 10, passY + 6, 190, L.passH - 12, 6)
        Fonts.with(10, function()
            love.graphics.setColor(0.25, 0.25, 0.28, 1)
            love.graphics.printf("PASS", L.pitchX, passY + 12, 210, "center")
        end)
    else
        local ps = State.score(match.players.player,   match, "player")
        local os = State.score(match.players.opponent, match, "opponent")
        local winning = ps > os
        local bcol = winning and {0.08, 0.30, 0.14, 1} or {0.12, 0.12, 0.14, 1}
        local lcol = winning and {0.25, 0.75, 0.40, 0.80} or {0.28, 0.28, 0.32, 0.70}
        love.graphics.setColor(bcol)
        love.graphics.rectangle("fill", L.pitchX + 10, passY + 6, 190, L.passH - 12, 6)
        love.graphics.setColor(lcol)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", L.pitchX + 10, passY + 6, 190, L.passH - 12, 6)
        love.graphics.setLineWidth(1)
        Fonts.with(11, function()
            love.graphics.setColor(0.85, 1, 0.88, 1)
            love.graphics.printf("PASS", L.pitchX, passY + 12, 210, "center")
        end)
    end

    -- Phase text
    Fonts.with(8, function()
        love.graphics.setColor(0.35, 0.55, 0.42, 0.75)
        local phaseStr = match.phase == "mulligan" and "MULLIGAN" or
                         (match.activePlayer == "player" and "YOUR TURN" or "WAITING...")
        love.graphics.printf(phaseStr, L.pitchX + 220, passY + 14, L.pitchW - 220, "left")
    end)
end
function GM.drawHand(match)
    handHitboxes = {}
    local hand   = match.players.player.hand
    local W      = love.graphics.getWidth()
    local handY  = L.rowY.hand
    local GAP    = 6
    local CW     = GCW + 4   -- hand cards slightly wider
    local CH     = GCH + 8

    -- Background
    love.graphics.setColor(0.020, 0.028, 0.022, 1)
    love.graphics.rectangle("fill", L.pitchX, handY, L.pitchW, L.handH)
    love.graphics.setColor(0.18, 0.32, 0.22, 0.35)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(L.pitchX, handY, L.pitchX + L.pitchW, handY)
    love.graphics.setLineWidth(1)

    Fonts.with(8, function()
        love.graphics.setColor(0.38, 0.55, 0.42, 0.75)
        love.graphics.print("YOUR HAND", L.pitchX + 6, handY + 4)
    end)

    if #hand == 0 then
        Fonts.with(10, function()
            love.graphics.setColor(0.3, 0.3, 0.35, 1)
            love.graphics.printf("— empty —", L.pitchX, handY + 40, L.pitchW, "center")
        end)
        return
    end

    local totalW  = #hand * (CW + GAP) - GAP
    local startX  = L.pitchX + (L.pitchW - totalW) / 2
    local cardY   = handY + (L.handH - CH) / 2

    for i, hc in ipairs(hand) do
        local cx  = startX + (i - 1) * (CW + GAP)
        local def = hc.definition
        local sel = selectedHandCard == hc.instanceId

        -- Determine base color by card type
        local rtype = rowTypeMap[def.row] or "midfielder"
        local baseCol = Theme.cardColors[rtype]   or {0.2, 0.2, 0.25, 1}
        local accCol  = Theme.cardAccents[rtype]  or {0.5, 0.5, 0.7, 1}

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.50)
        love.graphics.rectangle("fill", cx + 3, cardY + 3, CW, CH, 4)

        -- Body
        local bodyBright = sel and 0.65 or 0.38
        love.graphics.setColor(baseCol[1] * bodyBright, baseCol[2] * bodyBright, baseCol[3] * bodyBright, 1)
        love.graphics.rectangle("fill", cx, cardY, CW, CH, 4)

        -- Header strip
        love.graphics.setColor(baseCol[1] * 0.85, baseCol[2] * 0.85, baseCol[3] * 0.85, 1)
        love.graphics.rectangle("fill", cx, cardY, CW, 16, 4)
        love.graphics.rectangle("fill", cx, cardY + 10, CW, 6)

        -- Border
        if sel then
            love.graphics.setColor(1, 1, 0.3, 1)
            love.graphics.setLineWidth(2.5)
        else
            love.graphics.setColor(accCol[1], accCol[2], accCol[3], 0.65)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cx, cardY, CW, CH, 4)
        love.graphics.setLineWidth(1)

        -- Power or type label in header
        if def.power then
            Fonts.with(10, function()
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.printf(tostring(def.power), cx, cardY + 2, CW, "center")
            end)
        else
            Fonts.with(7, function()
                love.graphics.setColor(0.85, 0.85, 0.90, 0.85)
                love.graphics.printf("SPEC", cx, cardY + 4, CW, "center")
            end)
        end

        -- Card name
        local shortName = (def.name or ""):gsub("^The ", "")
        Fonts.with(7, function()
            love.graphics.setColor(sel and {1,1,1,1} or {0.70, 0.72, 0.75, 1})
            love.graphics.printf(shortName, cx + 2, cardY + 18, CW - 4, "center")
        end)

        -- Ability text (tiny, multi-line)
        Fonts.with(6, function()
            love.graphics.setColor(sel and {0.80,0.90,0.82,1} or {0.45,0.50,0.48,1})
            love.graphics.printf(def.abilityText or "", cx + 2, cardY + 34, CW - 4, "center")
        end)

        -- Register hitbox
        table.insert(handHitboxes, {
            instanceId = hc.instanceId,
            x = cx, y = cardY, w = CW, h = CH,
        })
    end
end
function GM.drawMulliganOverlay(match)
    handHitboxes = {}   -- replace play-phase hitboxes with mulligan-panel positions
    local W    = love.graphics.getWidth()
    local H    = love.graphics.getHeight()
    local left = match.mulliganLeft.player

    -- Semi-transparent backdrop
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Panel
    local panW, panH = 760, 340
    local panX = (W - panW) / 2
    local panY = (H - panH) / 2 - 20
    love.graphics.setColor(0.04, 0.07, 0.05, 1)
    love.graphics.rectangle("fill", panX, panY, panW, panH, 10)
    love.graphics.setColor(0.25, 0.55, 0.35, 0.70)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panX, panY, panW, panH, 10)
    love.graphics.setLineWidth(1)

    -- Title
    Fonts.with(18, function()
        love.graphics.setColor(0.80, 0.95, 0.84, 1)
        love.graphics.printf("MULLIGAN", 0, panY + 14, W, "center")
    end)

    -- Swap counter
    Fonts.with(11, function()
        love.graphics.setColor(0.55, 0.80, 0.60, 1)
        love.graphics.printf("Swap up to " .. left .. " card" .. (left == 1 and "" or "s"),
                             0, panY + 42, W, "center")
    end)

    -- Cards
    local hand   = match.players.player.hand
    local GAP    = 10
    local CW, CH = GCW + 6, GCH + 10
    local totalW = #hand * (CW + GAP) - GAP
    local startX = (W - totalW) / 2
    local cy     = panY + 72

    for i, hc in ipairs(hand) do
        local cx  = startX + (i - 1) * (CW + GAP)
        local def = hc.definition
        local isSelected = false
        for _, id in ipairs(mulliganSelected) do
            if id == hc.instanceId then isSelected = true; break end
        end

        local rtype   = rowTypeMap[def.row] or "midfielder"
        local baseCol = Theme.cardColors[rtype] or {0.2, 0.2, 0.25, 1}
        local accCol  = Theme.cardAccents[rtype] or {0.5, 0.5, 0.7, 1}
        local bright  = isSelected and 0.7 or 0.4

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", cx + 3, cy + 3, CW, CH, 4)

        -- Body
        love.graphics.setColor(baseCol[1] * bright, baseCol[2] * bright, baseCol[3] * bright, 1)
        love.graphics.rectangle("fill", cx, cy, CW, CH, 4)

        -- Header
        love.graphics.setColor(baseCol[1] * 0.85, baseCol[2] * 0.85, baseCol[3] * 0.85, 1)
        love.graphics.rectangle("fill", cx, cy, CW, 16, 4)
        love.graphics.rectangle("fill", cx, cy + 10, CW, 6)

        -- Border
        if isSelected then
            love.graphics.setColor(1, 0.25, 0.25, 1)
            love.graphics.setLineWidth(2.5)
        else
            love.graphics.setColor(accCol[1], accCol[2], accCol[3], 0.65)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", cx, cy, CW, CH, 4)
        love.graphics.setLineWidth(1)

        -- Power
        if def.power then
            Fonts.with(10, function()
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.printf(tostring(def.power), cx, cy + 2, CW, "center")
            end)
        end

        -- Name
        local shortName = (def.name or ""):gsub("^The ", "")
        Fonts.with(7, function()
            love.graphics.setColor(isSelected and {1,0.5,0.5,1} or {0.70, 0.72, 0.75, 1})
            love.graphics.printf(shortName, cx + 2, cy + 18, CW - 4, "center")
        end)

        -- "SWAP" label if selected
        if isSelected then
            Fonts.with(7, function()
                love.graphics.setColor(1, 0.3, 0.3, 1)
                love.graphics.printf("SWAP", cx, cy + CH - 14, CW, "center")
            end)
        end

        -- Register hitbox (reusing handHitboxes during mulligan phase)
        table.insert(handHitboxes, {
            instanceId = hc.instanceId,
            x = cx, y = cy, w = CW, h = CH,
        })
    end

    -- Confirm button
    local btnW = 160
    local btnX = (W - btnW) / 2
    local btnY = 750
    love.graphics.setColor(0.10, 0.38, 0.18, 1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, 36, 6)
    love.graphics.setColor(0.30, 0.80, 0.42, 0.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", btnX, btnY, btnW, 36, 6)
    love.graphics.setLineWidth(1)
    Fonts.with(13, function()
        love.graphics.setColor(0.82, 1, 0.87, 1)
        love.graphics.printf("CONFIRM  (" .. #mulliganSelected .. "/" .. left .. ")",
                             0, btnY + 9, W, "center")
    end)

    -- Opponent mulligan status
    if match.mulliganLeft.opponent > 0 then
        Fonts.with(9, function()
            love.graphics.setColor(0.45, 0.45, 0.50, 1)
            love.graphics.printf("Opponent is choosing...", 0, panY + panH + 10, W, "center")
        end)
    end
end
function GM.drawEndScreen(match)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local winner = match.winner
    local msg    = winner == "player" and "YOU WIN!" or
                   winner == "opponent" and "OPPONENT WINS" or "DRAW"
    local col    = winner == "player" and {0.3, 1, 0.5, 1} or
                   winner == "opponent" and {1, 0.35, 0.35, 1} or {0.8, 0.8, 0.8, 1}

    Fonts.with(40, function()
        love.graphics.setColor(col)
        love.graphics.printf(msg, 0, H / 2 - 40, W, "center")
    end)
    Fonts.with(13, function()
        love.graphics.setColor(0.65, 0.65, 0.70, 1)
        love.graphics.printf("Click anywhere to return to menu", 0, H / 2 + 20, W, "center")
    end)
end

function GM.drawPendingOverlay(match)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local pa   = match.pendingAction

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)

    if pa.type == "agility_choose" or pa.type == "horn_choose" then
        local title = pa.type == "agility_choose"
            and "AGILITY — Choose a row to place your card:"
            or  "COMMANDER'S HORN — Choose a row to double:"
        Fonts.with(14, function()
            love.graphics.setColor(1, 0.85, 0.3, 1)
            love.graphics.printf(title, 0, H * 0.38, W, "center")
        end)
        local rows   = { "attack", "midfield", "defense" }
        local labels = { "ATTACK ROW", "MIDFIELD ROW", "DEFENSE ROW" }
        local isHorn = pa.type == "horn_choose"
        for i, _ in ipairs(rows) do
            local bx = W * 0.5 - 120 + (i - 2) * 270
            local by = H * 0.48
            if isHorn then
                love.graphics.setColor(0.25, 0.18, 0.05, 0.9)
            else
                love.graphics.setColor(0.15, 0.15, 0.35, 0.9)
            end
            love.graphics.rectangle("fill", bx, by, 230, 50, 6)
            love.graphics.setColor(isHorn and {1, 0.7, 0.1, 1} or {0.5, 0.7, 1, 1})
            love.graphics.rectangle("line", bx, by, 230, 50, 6)
            love.graphics.setColor(1, 1, 1, 1)
            Fonts.with(12, function()
                love.graphics.printf(labels[i], bx, by + 16, 230, "center")
            end)
        end

    elseif pa.type == "medic_choose" then
        Fonts.with(14, function()
            love.graphics.setColor(1, 0.85, 0.3, 1)
            love.graphics.printf("MEDIC — Choose a card to resurrect:", 0, H * 0.34, W, "center")
        end)
        local graveyard = match.players["player"].graveyard
        local nonHero = {}
        for i, def in ipairs(graveyard) do
            if not def.hero then table.insert(nonHero, { i = i, def = def }) end
        end
        local cardW, cardH, gap = 120, 160, 14
        local total  = #nonHero
        local startX = W * 0.5 - (total * (cardW + gap)) * 0.5
        for k, entry in ipairs(nonHero) do
            local cx = startX + (k - 1) * (cardW + gap)
            local cy = H * 0.42
            love.graphics.setColor(0.12, 0.18, 0.12, 0.95)
            love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6)
            love.graphics.setColor(0.3, 0.7, 0.3, 1)
            love.graphics.rectangle("line", cx, cy, cardW, cardH, 6)
            Fonts.with(10, function()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.printf(entry.def.name, cx + 4, cy + 8, cardW - 8, "center")
            end)
            Fonts.with(18, function()
                love.graphics.setColor(0.8, 1, 0.8, 1)
                love.graphics.printf(tostring(entry.def.power or "?"), cx + 4, cy + cardH - 36, cardW - 8, "center")
            end)
        end

    elseif pa.type == "decoy_choose" then
        Fonts.with(14, function()
            love.graphics.setColor(1, 0.85, 0.3, 1)
            love.graphics.printf("DECOY — Choose a card to return to hand:", 0, H * 0.38, W, "center")
        end)
        Fonts.with(11, function()
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.printf("(Click any of your non-hero pitched cards on the board)", 0, H * 0.44, W, "center")
        end)
    end
end

return GM
