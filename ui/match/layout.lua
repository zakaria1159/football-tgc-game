-- Every rect on the 1280×800 match screen. Pure (unit-tested): draw code and input
-- hit-testing both read from here so they can never drift apart.
local Layout = {}

Layout.W, Layout.H = 1280, 800
Layout.CARD_W, Layout.CARD_H = 108, 148   -- Theme.cardSize.pitch
Layout.TRAP_W, Layout.TRAP_H = 54, 74
Layout.midX = 640

-- ── Top bar (y 0–80) ──────────────────────────────────────────────────────────
Layout.top = {
    bar       = { x = 0,    y = 0,  w = 1280, h = 80 },
    youAvatar = { cx = 50,   cy = 40, r = 30 },
    youBar    = { x = 92,   y = 14, w = 260, h = 32 },
    youPips   = { x = 92,   y = 52, w = 46, h = 20, size = 20, gap = 6 },   -- left-aligned
    oppAvatar = { cx = 1230, cy = 40, r = 30 },
    oppBar    = { x = 928,  y = 14, w = 260, h = 32 },
    oppPips   = { x = 1188, y = 52, w = 46, h = 20, size = 20, gap = 6 },   -- x is the RIGHT edge
    oppDeck   = { x = 928,  y = 52, w = 96, h = 22 },
    phasePill = { x = 490,  y = 8,  w = 300, h = 34 },
    turnChip  = { x = 570,  y = 48, w = 140, h = 24 },
    pause     = { x = 804,  y = 10, w = 36, h = 36 },
    music     = { x = 844,  y = 10, w = 36, h = 36 },
    log       = { x = 884,  y = 10, w = 36, h = 36 },
}

-- ── Pitch (x 24–1256, y 90–520) ───────────────────────────────────────────────
Layout.pitch = { x = 24, y = 90, w = 1232, h = 430 }

local COL_X    = { keeper = 60, defender = 204, midfielder = 348, striker = 492 }  -- player side
local STACK_Y  = { 145, 317 }   -- two-card columns (24px gap leaves room for badges/tags)
local SINGLE_Y = 231            -- one-card columns, vertically centred
local TRAP_X   = { 48, 108 }    -- under the keeper, by your own goal
local TRAP_Y   = 432

-- ── Bottom area (y 540–800) ───────────────────────────────────────────────────
Layout.bottom = {
    portrait    = { x = 12,  y = 592, w = 184, h = 196 },
    deck        = { x = 212, y = 680, w = 76,  h = 104 },
    deckCount   = { x = 296, y = 740, w = 64,  h = 28 },
    toastX = 208, toastW = 224, toastH = 28, toastGap = 6, toastBottomY = 640,
    hand        = { x = 444, y = 540, w = 512, h = 260, cx = 700, baseY = 766, maxHoverX = 990 },
    summons     = { x = 996, y = 552, w = 240, h = 34 },
    toggle      = { x = 996, y = 598, w = 240, h = 42 },
    startAttack = { x = 996, y = 652, w = 240, h = 52 },
    endTurn     = { x = 996, y = 716, w = 240, h = 70 },
    hint        = { x = 300, y = 526, w = 680, h = 14 },
}

function Layout.inRect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function mirrorX(x, w) return Layout.W - x - w end

-- Rect of a card slot. slotType: keeper|defender|midfielder|striker (index 0 for keeper/mid).
function Layout.slot(owner, slotType, index)
    local x = COL_X[slotType]
    if not x then return nil end
    local y
    if slotType == "defender" or slotType == "striker" then
        y = STACK_Y[index]
        if not y then return nil end
    else
        y = SINGLE_Y
    end
    if owner == "opponent" then x = mirrorX(x, Layout.CARD_W) end
    return { x = x, y = y, w = Layout.CARD_W, h = Layout.CARD_H }
end

function Layout.trapSlot(owner, index)
    local x = TRAP_X[index]
    if not x then return nil end
    if owner == "opponent" then x = mirrorX(x, Layout.TRAP_W) end
    return { x = x, y = TRAP_Y, w = Layout.TRAP_W, h = Layout.TRAP_H }
end

local SLOT_ORDER = {
    { "keeper", 0 }, { "defender", 1 }, { "defender", 2 },
    { "midfielder", 0 }, { "striker", 1 }, { "striker", 2 },
}

-- All 12 card slots: { owner, slotType, slotIndex, x, y, w, h }.
function Layout.slots()
    local out = {}
    for _, owner in ipairs({ "player", "opponent" }) do
        for _, s in ipairs(SLOT_ORDER) do
            local r = Layout.slot(owner, s[1], s[2])
            out[#out + 1] = { owner = owner, slotType = s[1], slotIndex = s[2], x = r.x, y = r.y, w = r.w, h = r.h }
        end
    end
    return out
end

-- All 4 trap slots, same shape with slotType = "trap".
function Layout.trapSlots()
    local out = {}
    for _, owner in ipairs({ "player", "opponent" }) do
        for i = 1, 2 do
            local r = Layout.trapSlot(owner, i)
            out[#out + 1] = { owner = owner, slotType = "trap", slotIndex = i, x = r.x, y = r.y, w = r.w, h = r.h }
        end
    end
    return out
end

-- One half of the ATTACK/DEFENSE segmented toggle.
function Layout.toggleHalf(mode)
    local t = Layout.bottom.toggle
    local hw = t.w / 2
    if mode == "attack" then return { x = t.x, y = t.y, w = hw, h = t.h } end
    return { x = t.x + hw, y = t.y, w = hw, h = t.h }
end

-- Toast i (1 = newest, at the bottom of the stack).
function Layout.toastRect(i)
    local b = Layout.bottom
    return { x = b.toastX, y = b.toastBottomY - (i - 1) * (b.toastH + b.toastGap), w = b.toastW, h = b.toastH }
end

-- Button under (x, y): pause|music|log|endTurn|startAttack|modeAttack|modeDefense|nil.
-- START ATTACK only exists during the summon phase.
function Layout.buttonAt(x, y, phase)
    local T, B = Layout.top, Layout.bottom
    if Layout.inRect(x, y, T.pause) then return "pause" end
    if Layout.inRect(x, y, T.music) then return "music" end
    if Layout.inRect(x, y, T.log)   then return "log" end
    if Layout.inRect(x, y, B.endTurn) then return "endTurn" end
    if phase == "summon" and Layout.inRect(x, y, B.startAttack) then return "startAttack" end
    if Layout.inRect(x, y, Layout.toggleHalf("attack"))  then return "modeAttack" end
    if Layout.inRect(x, y, Layout.toggleHalf("defense")) then return "modeDefense" end
    return nil
end

return Layout
