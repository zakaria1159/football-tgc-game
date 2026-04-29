local Fonts = require("ui.fonts")
local Theme = require("ui.theme")

local CardLibrary = {}

local _scrollY    = 0
local _filter     = "all"
local _maxScrollY = 0
local _allCards   = nil

local TABS = {
    { key = "all",        label = "ALL"         },
    { key = "striker",    label = "STRIKERS"    },
    { key = "midfielder", label = "MIDFIELDERS" },
    { key = "defender",   label = "DEFENDERS"   },
    { key = "keeper",     label = "KEEPERS"     },
    { key = "trap",       label = "TRAPS"       },
    { key = "strategy",   label = "STRATEGIES"  },
}

local RARITY_COL = {
    common    = { 0.60, 0.60, 0.60, 1 },
    uncommon  = { 0.30, 0.80, 0.40, 1 },
    rare      = { 0.30, 0.60, 1.00, 1 },
    legendary = { 1.00, 0.75, 0.10, 1 },
}

local COLS      = 4
local TILE_W    = 280
local TILE_H    = 200
local TILE_GAP  = 16
local HEADER_H  = 60
local TABS_H    = 44
local PAD_X     = 40

local function loadCards()
    if _allCards then return _allCards end
    _allCards = {}
    local sources = {
        require("engine.cards.definitions.strikers"),
        require("engine.cards.definitions.midfielders"),
        require("engine.cards.definitions.defenders"),
        require("engine.cards.definitions.keepers"),
        require("engine.cards.definitions.traps"),
        require("engine.cards.definitions.strategies"),
    }
    for _, list in ipairs(sources) do
        for _, card in ipairs(list) do
            table.insert(_allCards, card)
        end
    end
    return _allCards
end

local function filteredCards()
    local all = loadCards()
    if _filter == "all" then return all end
    local out = {}
    for _, c in ipairs(all) do
        if c.type == _filter then table.insert(out, c) end
    end
    return out
end

-- Returns tab x positions for hit-testing (shared between draw and click)
local function tabLayout()
    local tabs = {}
    local tx = PAD_X
    for _, tab in ipairs(TABS) do
        local tw = math.max(80, #tab.label * 8 + 20)
        table.insert(tabs, { tab = tab, x = tx, w = tw })
        tx = tx + tw + 8
    end
    return tabs
end

local function drawTile(card, x, y)
    local base = Theme.cardColors[card.type]  or { 0.15, 0.15, 0.20, 1 }
    local acc  = Theme.cardAccents[card.type] or { 0.60, 0.60, 0.70, 1 }
    local r    = 6

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x+4, y+4, TILE_W, TILE_H, r)

    love.graphics.setColor(base[1]*0.55, base[2]*0.55, base[3]*0.55, 1)
    love.graphics.rectangle("fill", x, y, TILE_W, TILE_H, r)

    -- Header strip
    love.graphics.setColor(acc[1]*0.55, acc[2]*0.55, acc[3]*0.55, 1)
    love.graphics.rectangle("fill", x, y, TILE_W, 30, r)
    love.graphics.rectangle("fill", x, y+16, TILE_W, 14)

    love.graphics.setColor(acc[1], acc[2], acc[3], 0.40)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, TILE_W, TILE_H, r)

    -- Name
    Fonts.with(13, function()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.printf(card.name or "", x+7, y+8, TILE_W-14, "left")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(card.name or "", x+6, y+7, TILE_W-12, "left")
    end)

    -- Type + rarity row
    local badgeY = y + 34
    Fonts.with(9, function()
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.85)
        love.graphics.printf((card.type or ""):upper(), x+6, badgeY, TILE_W/2, "left")
        local rc = RARITY_COL[card.rarity or "common"] or { 0.6, 0.6, 0.6, 1 }
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.90)
        love.graphics.printf((card.rarity or ""):upper(), x+6, badgeY, TILE_W-6, "right")
    end)

    -- Stats row (field cards only)
    local textY = badgeY + 17
    if card.stats and (card.stats.atk or 0) + (card.stats.def or 0) > 0 then
        local atkC = Theme.atkColor
        local defC = Theme.defColor
        Fonts.with(11, function()
            love.graphics.setColor(atkC[1], atkC[2], atkC[3], 1)
            love.graphics.printf("ATK  " .. (card.stats.atk or 0), x+6, textY, TILE_W/2, "left")
            love.graphics.setColor(defC[1], defC[2], defC[3], 1)
            love.graphics.printf((card.stats.def or 0) .. "  DEF", x+6, textY, TILE_W-12, "right")
        end)
        textY = textY + 18
    end

    -- Ability text (clipped to tile bottom)
    local clipH = (y + TILE_H - 6) - textY
    if clipH > 8 and card.abilityText then
        love.graphics.setScissor(
            math.floor(x + 4),
            math.floor(textY),
            TILE_W - 8,
            math.ceil(clipH))
        Fonts.with(9, function()
            love.graphics.setColor(0.78, 0.72, 0.88, 0.88)
            love.graphics.printf(card.abilityText, x+6, textY + 3, TILE_W-12, "left")
        end)
        love.graphics.setScissor()
    end
end

function CardLibrary.open()
    _scrollY = 0
    _filter  = "all"
end

function CardLibrary.draw()
    local W      = love.graphics.getWidth()
    local H      = love.graphics.getHeight()
    local cards  = filteredCards()
    local tabs   = tabLayout()

    -- Backdrop
    love.graphics.setColor(0.02, 0.01, 0.06, 0.96)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Header bar
    love.graphics.setColor(0.06, 0.04, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, W, HEADER_H)
    love.graphics.setColor(0.35, 0.25, 0.55, 0.70)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, HEADER_H, W, HEADER_H)

    Fonts.with(22, function()
        love.graphics.setColor(0.80, 0.70, 1.00, 1)
        love.graphics.printf("CARD LIBRARY", 0, 16, W - 24, "right")
    end)
    Fonts.with(9, function()
        love.graphics.setColor(0.45, 0.38, 0.60, 1)
        love.graphics.printf("ESC  TO  CLOSE", PAD_X, 24, 200, "left")
    end)

    -- Tabs
    local tabBarY = HEADER_H + 4
    local tabH    = TABS_H - 8
    for _, t in ipairs(tabs) do
        local active = (_filter == t.tab.key)
        if active then
            love.graphics.setColor(0.28, 0.16, 0.50, 1)
            love.graphics.rectangle("fill", t.x, tabBarY, t.w, tabH, 4)
        end
        love.graphics.setColor(active and 0.70 or 0.30, active and 0.55 or 0.24, active and 0.90 or 0.48, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", t.x, tabBarY, t.w, tabH, 4)
        Fonts.with(9, function()
            love.graphics.setColor(active and 1.0 or 0.60,
                                   active and 0.92 or 0.55,
                                   active and 1.0 or 0.75, 1)
            love.graphics.printf(t.tab.label, t.x, tabBarY + tabH/2 - 6, t.w, "center")
        end)
    end

    love.graphics.setColor(0.20, 0.15, 0.35, 0.50)
    love.graphics.line(0, HEADER_H + TABS_H, W, HEADER_H + TABS_H)

    -- Card grid (scrollable)
    local gridTop = HEADER_H + TABS_H + 12
    local gridH   = H - gridTop - 8
    local totalW  = COLS * TILE_W + (COLS-1) * TILE_GAP
    local startX  = math.floor((W - totalW) / 2)

    local rows = math.ceil(#cards / COLS)
    _maxScrollY = math.max(0, rows * (TILE_H + TILE_GAP) - gridH + TILE_GAP)
    _scrollY    = math.min(_scrollY, _maxScrollY)

    love.graphics.setScissor(0, gridTop, W, gridH)

    for i, card in ipairs(cards) do
        local col = (i-1) % COLS
        local row = math.floor((i-1) / COLS)
        local cx  = startX + col * (TILE_W + TILE_GAP)
        local cy  = gridTop + row * (TILE_H + TILE_GAP) - _scrollY
        if cy + TILE_H > gridTop - 10 and cy < gridTop + gridH + 10 then
            drawTile(card, cx, cy)
        end
    end

    if #cards == 0 then
        Fonts.with(16, function()
            love.graphics.setColor(0.40, 0.35, 0.55, 0.80)
            love.graphics.printf("No cards in this category.", 0, gridTop + gridH/2 - 12, W, "center")
        end)
    end

    love.graphics.setScissor()

    -- Scrollbar
    if _maxScrollY > 0 then
        local sbH = math.max(30, gridH * gridH / (rows * (TILE_H + TILE_GAP)))
        local sbY = gridTop + (_scrollY / _maxScrollY) * (gridH - sbH)
        love.graphics.setColor(0.25, 0.18, 0.40, 0.50)
        love.graphics.rectangle("fill", W-7, gridTop, 4, gridH, 2)
        love.graphics.setColor(0.65, 0.50, 0.90, 0.85)
        love.graphics.rectangle("fill", W-7, sbY, 4, sbH, 2)
    end
end

function CardLibrary.keypressed(key)
    if key == "escape" then return "close" end
    if key == "down"   then _scrollY = math.min(_maxScrollY, _scrollY + 60) end
    if key == "up"     then _scrollY = math.max(0, _scrollY - 60) end
    return nil
end

function CardLibrary.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    local tabBarY = HEADER_H + 4
    local tabH    = TABS_H - 8
    for _, t in ipairs(tabLayout()) do
        if x >= t.x and x <= t.x + t.w and y >= tabBarY and y <= tabBarY + tabH then
            _filter  = t.tab.key
            _scrollY = 0
            return nil
        end
    end
    return nil
end

function CardLibrary.wheelmoved(_, dy)
    _scrollY = math.max(0, math.min(_maxScrollY, _scrollY - dy * 55))
end

return CardLibrary
