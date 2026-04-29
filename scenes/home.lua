local Fonts       = require("ui.fonts")
local CardLibrary = require("ui.card_library")

local Home = {}

local libraryOpen = false

-- Two-step flow: pick mode → pick deck (→ difficulty is always "medium" for now)
local step         = "mode"   -- "mode" | "deck"
local selectedMode = "classic"
local selectedDeck = 1

local deckList = {
    { key = "tikitaka",   label = "THE BEAUTIFUL GAME", sub = "Tiki-Taka",  desc = "Possession & draw power" },
    { key = "longball",   label = "DIRECT FOOTBALL",    sub = "Long Ball",   desc = "Raw striker power" },
    { key = "catenaccio", label = "THE WALL",           sub = "Catenaccio",  desc = "Defensive fortress" },
}

local gwentDeckList = {
    { key = "northern_realms", label = "THE LIONS",  sub = "Northern Realms", desc = "Heroes, spies & bond combos" },
    { key = "monsters",        label = "THE WILDS",  sub = "Monsters",        desc = "Muster swarms & weather" },
}

local deckColors = {
    tikitaka     = { 0.08, 0.42, 0.22, 1 },
    longball     = { 0.62, 0.10, 0.14, 1 },
    catenaccio   = { 0.10, 0.28, 0.62, 1 },
    northern_realms = { 0.10, 0.28, 0.62, 1 },
    monsters        = { 0.42, 0.08, 0.08, 1 },
}

-- Shared layout constants — used by both draw and hit-detection to prevent drift
local MODE_BTN_W = 260
local MODE_BTN_H = 100
local MODE_GAP   = 40
local DECK_W     = 280
local DECK_H     = 180
local DECK_GAP   = 30

-- ── Draw helpers ──────────────────────────────────────────────────────────────

local function drawBackground()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    love.graphics.setColor(0.051, 0.008, 0.008, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    local stripeW = 60
    for i = 0, math.ceil(W / stripeW) do
        if i % 2 == 0 then
            love.graphics.setColor(0.055, 0.010, 0.010, 1)
            love.graphics.rectangle("fill", i * stripeW, 0, stripeW, H)
        end
    end
    love.graphics.setColor(0.10, 0.04, 0.04, 0.35)
    love.graphics.setLineWidth(1)
    for gy = 0, H, 48 do love.graphics.line(0, gy, W, gy) end
end

local function drawTitle()
    local W = love.graphics.getWidth()
    local titleY = love.graphics.getHeight() * 0.09
    love.graphics.setColor(0.55, 0.10, 0.10, 0.60)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, titleY - 2 + 52, W, titleY - 2 + 52)
    love.graphics.setLineWidth(1)
    Fonts.with(44, function()
        love.graphics.setColor(0.80, 0.10, 0.10, 0.25)
        love.graphics.printf("FOOTBALL TCG", 3, titleY + 3, W, "center")
        love.graphics.setColor(1, 0.92, 0.92, 1)
        love.graphics.printf("FOOTBALL TCG", 0, titleY, W, "center")
    end)
    Fonts.with(11, function()
        love.graphics.setColor(0.55, 0.10, 0.10, 1)
        love.graphics.printf("─────────────────────────────────────────", 0, titleY + 52, W, "center")
    end)
end

local function drawDeckButtons(list, selected, cardY)
    local W     = love.graphics.getWidth()
    local H     = love.graphics.getHeight()
    local totalW = #list * DECK_W + (#list - 1) * DECK_GAP
    local startX = (W - totalW) / 2

    for i, deck in ipairs(list) do
        local x   = startX + (i - 1) * (DECK_W + DECK_GAP)
        local sel = (i == selected)
        local dcol = deckColors[deck.key] or {0.3, 0.3, 0.3, 1}

        love.graphics.setColor(0, 0, 0, 0.60)
        love.graphics.rectangle("fill", x + 5, cardY + 5, DECK_W, DECK_H, 10)

        if sel then love.graphics.setColor(dcol[1]*0.55, dcol[2]*0.55, dcol[3]*0.55, 1)
        else        love.graphics.setColor(dcol[1]*0.25, dcol[2]*0.25, dcol[3]*0.25, 1) end
        love.graphics.rectangle("fill", x, cardY, DECK_W, DECK_H, 10)

        love.graphics.setColor(dcol[1]*0.80, dcol[2]*0.80, dcol[3]*0.80, sel and 1 or 0.55)
        love.graphics.rectangle("fill", x, cardY, DECK_W, 30, 10)
        love.graphics.rectangle("fill", x, cardY + 18, DECK_W, 12)

        if sel then
            for ring = 3, 1, -1 do
                love.graphics.setColor(dcol[1], dcol[2], dcol[3], 0.12 * ring)
                love.graphics.setLineWidth(ring * 2.5)
                love.graphics.rectangle("line", x-ring*2, cardY-ring*2, DECK_W+ring*4, DECK_H+ring*4, 10+ring*2)
            end
            love.graphics.setColor(dcol[1], dcol[2], dcol[3], 1)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", x, cardY, DECK_W, DECK_H, 10)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(dcol[1]*0.60, dcol[2]*0.60, dcol[3]*0.60, 0.70)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", x, cardY, DECK_W, DECK_H, 10)
            love.graphics.setLineWidth(1)
        end

        Fonts.with(9, function()
            love.graphics.setColor(1, 1, 1, sel and 0.95 or 0.65)
            love.graphics.printf(deck.sub:upper(), x+8, cardY+8, DECK_W-16, "left")
        end)
        Fonts.with(16, function()
            love.graphics.setColor(sel and {1,1,1,1} or {0.65,0.65,0.65,1})
            love.graphics.printf(deck.label, x+10, cardY+42, DECK_W-20, "center")
        end)
        Fonts.with(11, function()
            love.graphics.setColor(sel and {dcol[1]*1.4, dcol[2]*1.4, dcol[3]*1.4, 1} or {0.45,0.45,0.45,1})
            love.graphics.printf(deck.desc, x+10, cardY+80, DECK_W-20, "center")
        end)

        if sel then
            love.graphics.setColor(dcol[1], dcol[2], dcol[3], 0.20)
            love.graphics.rectangle("fill", x+60, cardY+DECK_H-36, DECK_W-120, 24, 4)
            love.graphics.setColor(dcol[1], dcol[2], dcol[3], 0.80)
            love.graphics.rectangle("line", x+60, cardY+DECK_H-36, DECK_W-120, 24, 4)
            Fonts.with(9, function()
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.printf("SELECTED", x, cardY+DECK_H-30, DECK_W, "center")
            end)
        end
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

function Home.draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    drawBackground()
    drawTitle()

    if step == "mode" then
        Fonts.with(11, function()
            love.graphics.setColor(0.50, 0.45, 0.45, 1)
            love.graphics.printf("CHOOSE MODE", 0, H * 0.20, W, "center")
        end)

        -- Two mode buttons
        local totalW = 2 * MODE_BTN_W + MODE_GAP
        local startX = (W - totalW) / 2
        local btnY   = H * 0.32

        local modes = {
            { key = "classic", label = "CLASSIC MODE",  sub = "ATK vs DEF combat" },
            { key = "gwent",   label = "GWENT MODE",    sub = "Power & scoring" },
        }
        for i, m in ipairs(modes) do
            local bx  = startX + (i-1) * (MODE_BTN_W + MODE_GAP)
            local sel = selectedMode == m.key
            local col = { 0.50, 0.12, 0.12, 1 }
            if m.key == "gwent" then col = { 0.12, 0.40, 0.22, 1 } end

            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", bx+4, btnY+4, MODE_BTN_W, MODE_BTN_H, 8)
            love.graphics.setColor(col[1]*(sel and 0.55 or 0.25), col[2]*(sel and 0.55 or 0.25), col[3]*(sel and 0.55 or 0.25), 1)
            love.graphics.rectangle("fill", bx, btnY, MODE_BTN_W, MODE_BTN_H, 8)

            if sel then
                love.graphics.setColor(col[1], col[2], col[3], 1)
                love.graphics.setLineWidth(2.5)
            else
                love.graphics.setColor(col[1]*0.6, col[2]*0.6, col[3]*0.6, 0.7)
                love.graphics.setLineWidth(1.5)
            end
            love.graphics.rectangle("line", bx, btnY, MODE_BTN_W, MODE_BTN_H, 8)
            love.graphics.setLineWidth(1)

            Fonts.with(16, function()
                love.graphics.setColor(sel and {1,1,1,1} or {0.65,0.65,0.65,1})
                love.graphics.printf(m.label, bx, btnY + 22, MODE_BTN_W, "center")
            end)
            Fonts.with(10, function()
                love.graphics.setColor(sel and {0.75,0.85,0.78,1} or {0.45,0.45,0.45,1})
                love.graphics.printf(m.sub, bx, btnY + 50, MODE_BTN_W, "center")
            end)
        end

        Fonts.with(11, function()
            love.graphics.setColor(0.45, 0.42, 0.44, 1)
            love.graphics.printf("Arrow keys or click to select     ENTER to continue", 0, H * 0.72, W, "center")
        end)

    else  -- step == "deck"
        local list  = selectedMode == "gwent" and gwentDeckList or deckList
        local label = selectedMode == "gwent" and "CHOOSE FACTION" or "CHOOSE YOUR FORMATION"
        Fonts.with(11, function()
            love.graphics.setColor(0.50, 0.45, 0.45, 1)
            love.graphics.printf(label, 0, H * 0.20, W, "center")
        end)

        drawDeckButtons(list, selectedDeck, H * 0.30)

        -- Card Library button (classic mode only)
        if selectedMode == "classic" then
            local libBtnW = 220
            local libBtnH = 36
            local libBtnX = (W - libBtnW) / 2
            local libBtnY = H * 0.65
            local mx, my  = love.mouse.getPosition()
            local hov = mx >= libBtnX and mx <= libBtnX + libBtnW
                    and my >= libBtnY and my <= libBtnY + libBtnH
            love.graphics.setColor(hov and 0.18 or 0.10, hov and 0.12 or 0.07, hov and 0.30 or 0.18, 1)
            love.graphics.rectangle("fill", libBtnX, libBtnY, libBtnW, libBtnH, 5)
            love.graphics.setColor(0.50, 0.38, 0.78, hov and 0.90 or 0.55)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", libBtnX, libBtnY, libBtnW, libBtnH, 5)
            love.graphics.setLineWidth(1)
            Fonts.with(11, function()
                love.graphics.setColor(hov and 1.0 or 0.70, hov and 0.92 or 0.62, hov and 1.0 or 0.88, 1)
                love.graphics.printf("CARD LIBRARY", libBtnX, libBtnY + libBtnH/2 - 7, libBtnW, "center")
            end)
        end

        Fonts.with(11, function()
            love.graphics.setColor(0.45, 0.42, 0.44, 1)
            love.graphics.printf("Arrow keys or click to select     ENTER to start     ESC to go back", 0, H * 0.72, W, "center")
        end)
    end

    Fonts.with(9, function()
        love.graphics.setColor(0.28, 0.26, 0.28, 1)
        love.graphics.printf("FOOTBALL TCG  v0.1", 0, H - 22, W, "center")
    end)

    -- Card library overlay (on top of everything)
    if libraryOpen then CardLibrary.draw() end
end

-- ── Input ─────────────────────────────────────────────────────────────────────

function Home.keypressed(key)
    if libraryOpen then
        local r = CardLibrary.keypressed(key)
        if r == "close" then libraryOpen = false end
        return nil
    end

    local list = selectedMode == "gwent" and gwentDeckList or deckList

    if step == "mode" then
        if key == "left" or key == "right" then
            selectedMode = selectedMode == "classic" and "gwent" or "classic"
            selectedDeck = 1
        elseif key == "return" or key == "kpenter" then
            selectedDeck = math.min(selectedDeck, #list)
            step = "deck"
        elseif key == "escape" then
            love.event.quit()
        end

    else  -- deck step
        if key == "left" then
            selectedDeck = math.max(1, selectedDeck - 1)
        elseif key == "right" then
            selectedDeck = math.min(#list, selectedDeck + 1)
        elseif key == "return" or key == "kpenter" then
            return "start", selectedMode, list[selectedDeck].key
        elseif key == "escape" then
            step = "mode"
        end
    end
    return nil
end

function Home.mousepressed(x, y, button)
    if libraryOpen then
        local r = CardLibrary.mousepressed(x, y, button)
        if r == "close" then libraryOpen = false end
        return nil
    end

    if button ~= 1 then return nil end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    if step == "mode" then
        local totalW = 2 * MODE_BTN_W + MODE_GAP
        local startX = (W - totalW) / 2
        local btnY   = H * 0.32
        local modeKeys = {"classic", "gwent"}
        for i, mk in ipairs(modeKeys) do
            local bx = startX + (i-1) * (MODE_BTN_W + MODE_GAP)
            if x >= bx and x <= bx + MODE_BTN_W and y >= btnY and y <= btnY + MODE_BTN_H then
                if selectedMode == mk then
                    step = "deck"; selectedDeck = 1
                else
                    selectedMode = mk; selectedDeck = 1
                end
                return nil
            end
        end
    else
        local list   = selectedMode == "gwent" and gwentDeckList or deckList
        local totalW = #list * DECK_W + (#list - 1) * DECK_GAP
        local startX = (W - totalW) / 2
        local cardY  = H * 0.30
        for i, _ in ipairs(list) do
            local cx = startX + (i-1) * (DECK_W + DECK_GAP)
            if x >= cx and x <= cx + DECK_W and y >= cardY and y <= cardY + DECK_H then
                if selectedDeck == i then
                    return "start", selectedMode, list[i].key
                else
                    selectedDeck = i
                end
                return nil
            end
        end

        -- Card Library button (classic mode only)
        if selectedMode == "classic" then
            local libBtnW = 220
            local libBtnH = 36
            local libBtnX = (W - libBtnW) / 2
            local libBtnY = H * 0.65
            if x >= libBtnX and x <= libBtnX + libBtnW and y >= libBtnY and y <= libBtnY + libBtnH then
                libraryOpen = true
                CardLibrary.open()
                return nil
            end
        end
    end
    return nil
end

function Home.wheelmoved(x, y)
    if libraryOpen then CardLibrary.wheelmoved(x, y) end
end

function Home.reset()
    step         = "mode"
    selectedMode = "classic"
    selectedDeck = 1
    libraryOpen  = false
end

return Home
