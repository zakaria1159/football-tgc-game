local Fonts       = require("ui.fonts")
local CardLibrary = require("ui.card_library")

local Home = {}

local libraryOpen = false

local selectedDeck = 1

local deckList = {
    { key = "tikitaka",   label = "THE BEAUTIFUL GAME", sub = "Tiki-Taka",  desc = "Possession & draw power" },
    { key = "longball",   label = "DIRECT FOOTBALL",    sub = "Long Ball",   desc = "Raw striker power" },
    { key = "catenaccio", label = "THE WALL",           sub = "Catenaccio",  desc = "Defensive fortress" },
}

local deckColors = {
    tikitaka   = { 0.08, 0.42, 0.22, 1 },
    longball   = { 0.62, 0.10, 0.14, 1 },
    catenaccio = { 0.10, 0.28, 0.62, 1 },
}

-- Shared layout constants — used by both draw and hit-detection to prevent drift
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

    Fonts.with(11, function()
        love.graphics.setColor(0.50, 0.45, 0.45, 1)
        love.graphics.printf("CHOOSE YOUR FORMATION", 0, H * 0.20, W, "center")
    end)

    drawDeckButtons(deckList, selectedDeck, H * 0.30)

    -- Card Library button
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

    Fonts.with(11, function()
        love.graphics.setColor(0.45, 0.42, 0.44, 1)
        love.graphics.printf("Arrow keys or click to select     ENTER to start     ESC to quit", 0, H * 0.72, W, "center")
    end)

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

    if key == "left" then
        selectedDeck = math.max(1, selectedDeck - 1)
    elseif key == "right" then
        selectedDeck = math.min(#deckList, selectedDeck + 1)
    elseif key == "return" or key == "kpenter" then
        return "start", deckList[selectedDeck].key
    elseif key == "escape" then
        love.event.quit()
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

    local totalW = #deckList * DECK_W + (#deckList - 1) * DECK_GAP
    local startX = (W - totalW) / 2
    local cardY  = H * 0.30
    for i, deck in ipairs(deckList) do
        local cx = startX + (i-1) * (DECK_W + DECK_GAP)
        if x >= cx and x <= cx + DECK_W and y >= cardY and y <= cardY + DECK_H then
            if selectedDeck == i then return "start", deck.key end
            selectedDeck = i
            return nil
        end
    end

    local libBtnW = 220
    local libBtnH = 36
    local libBtnX = (W - libBtnW) / 2
    local libBtnY = H * 0.65
    if x >= libBtnX and x <= libBtnX + libBtnW and y >= libBtnY and y <= libBtnY + libBtnH then
        libraryOpen = true
        CardLibrary.open()
    end
    return nil
end

function Home.wheelmoved(x, y)
    if libraryOpen then CardLibrary.wheelmoved(x, y) end
end

function Home.reset()
    selectedDeck = 1
    libraryOpen  = false
end

return Home
