-- All colors and visual constants.
local Theme = {}

-- ══ Arcade tokens (redesign) ═════════════════════════════════════════════════
-- Everything below "Legacy tokens" is used by screens not yet migrated and is
-- removed at the end of the redesign.

local function hex(s, a)
    s = s:gsub("#", "")
    return {
        tonumber(s:sub(1, 2), 16) / 255,
        tonumber(s:sub(3, 4), 16) / 255,
        tonumber(s:sub(5, 6), 16) / 255,
        a or 1,
    }
end
Theme.hex = hex

Theme.ink     = hex("1d1d59")   -- outlines, hard drop shadows
Theme.inkText = hex("2b2b6b")   -- dark text on white
Theme.white   = { 1, 1, 1, 1 }

Theme.bg = { top = hex("3d7cff"), bottom = hex("6b4dff") }

Theme.grad = {
    atk   = { hex("ff6a6a"), hex("e0243a") },
    def   = { hex("6ac8ff"), hex("1f78e0") },
    lpYou = { hex("7dff8a"), hex("2ec44a") },
    lpOpp = { hex("ff8a8a"), hex("e0243a") },
    bonus = { hex("7dff8a"), hex("22b347") },
}

Theme.highlight = {
    selected = hex("ffe14a"),
    target   = hex("ff4a4a"),
    valid    = { 1, 1, 1, 1 },
}

Theme.button = {
    primary = { fill = { hex("ffd23a"), hex("ff9a1a") }, text = hex("5a2a00"), shadow = hex("a14e00") },
    go      = { fill = { hex("7dff8a"), hex("22b347") }, text = { 1, 1, 1, 1 }, shadow = hex("137a2e") },
    danger  = { fill = { hex("ff8a8a"), hex("e0243a") }, text = { 1, 1, 1, 1 }, shadow = hex("8f1026") },
    neutral = { fill = { hex("ffffff"), hex("dfe3f0") }, text = hex("2b2b6b"), shadow = hex("1d1d59") },
    icon    = { fill = { { 1, 1, 1, 0.18 }, { 1, 1, 1, 0.10 } }, text = { 1, 1, 1, 1 }, shadow = { 0.114, 0.114, 0.349, 0.6 } },
}

Theme.typeGrad = {
    striker    = { hex("ff7a59"), hex("e8344a") },
    defender   = { hex("4fb8ff"), hex("2563eb") },
    midfielder = { hex("6ee7a0"), hex("16a34a") },
    keeper     = { hex("ffc15a"), hex("ea7a0c") },
    trap       = { hex("c77dff"), hex("7b2cbf") },
    strategy   = { hex("5eead4"), hex("0f9488") },
    formation  = { hex("ffe08a"), hex("d4a017") },
}

Theme.typeLabel = {
    striker = "STRIKER", defender = "DEFENDER", midfielder = "MIDFIELD", keeper = "KEEPER",
    trap = "TRAP", strategy = "STRATEGY", formation = "FORMATION",
}

Theme.rarityColors = {
    common    = hex("cfd6e6"),
    uncommon  = hex("5eead4"),
    rare      = hex("ffc93a"),
    legendary = hex("ff5ec8"),
}

Theme.cardBack = { hex("35358a"), hex("22226a") }

Theme.cardSize = {
    pitch = { w = 108, h = 148 },
    hand  = { w = 120, h = 165 },
    zoom  = { w = 300, h = 410 },
}

-- ══ Legacy tokens ════════════════════════════════════════════════════════════

-- ── Card colors (base, from HTML template) ────────────────────────────────────

Theme.cardColors = {
    keeper     = { 0.486, 0.227, 0.000, 1 },  -- #7c3a00
    defender   = { 0.000, 0.227, 0.486, 1 },  -- #003a7c
    midfielder = { 0.000, 0.227, 0.102, 1 },  -- #003a1a
    striker    = { 0.486, 0.000, 0.063, 1 },  -- #7c0010
    trap       = { 0.227, 0.000, 0.486, 1 },  -- #3a007c
    formation  = { 0.486, 0.227, 0.000, 1 },
    strategy   = { 0.000, 0.227, 0.102, 1 },
}

-- Art zone colors (lighter / more saturated mid-tone)
Theme.cardArt = {
    keeper     = { 0.761, 0.416, 0.102, 1 },  -- #c26a1a
    defender   = { 0.133, 0.400, 0.722, 1 },  -- #2266b8
    midfielder = { 0.122, 0.478, 0.259, 1 },  -- #1f7a42
    striker    = { 0.722, 0.133, 0.227, 1 },  -- #b8223a
    trap       = { 0.416, 0.180, 0.761, 1 },  -- #6a2ec2
    formation  = { 0.761, 0.416, 0.102, 1 },
    strategy   = { 0.122, 0.478, 0.259, 1 },
}

-- Accent colors (bright glow / highlight per type)
Theme.cardAccents = {
    keeper     = { 1.000, 0.698, 0.353, 1 },  -- #ffb25a
    defender   = { 0.416, 0.757, 1.000, 1 },  -- #6ac1ff
    midfielder = { 0.369, 0.827, 0.573, 1 },  -- #5ed392
    striker    = { 1.000, 0.416, 0.478, 1 },  -- #ff6a7a
    trap       = { 0.698, 0.478, 1.000, 1 },  -- #b27aff
    formation  = { 1.000, 0.698, 0.353, 1 },
    strategy   = { 0.369, 0.827, 0.573, 1 },
}

-- Dim versions for exhausted cards (darken base by ~50%)
Theme.cardColorsDim = {
    keeper     = { 0.240, 0.113, 0.000, 1 },
    defender   = { 0.000, 0.113, 0.240, 1 },
    midfielder = { 0.000, 0.113, 0.051, 1 },
    striker    = { 0.240, 0.000, 0.031, 1 },
    trap       = { 0.113, 0.000, 0.240, 1 },
    formation  = { 0.240, 0.113, 0.000, 1 },
    strategy   = { 0.000, 0.113, 0.051, 1 },
}

-- Legacy alias (used by combat overlay)
Theme.cardHeaders = Theme.cardAccents

-- Global ATK / DEF colors
Theme.atkColor = { 1.000, 0.267, 0.329, 1 }  -- #ff4454
Theme.defColor = { 0.290, 0.639, 1.000, 1 }  -- #4aa3ff

-- ── Pitch ─────────────────────────────────────────────────────────────────────

Theme.pitch = {
    bg         = { 0.051, 0.165, 0.078, 1 },   -- #0d2a14 casino felt
    bgDark     = { 0.039, 0.118, 0.055, 1 },
    line       = { 0.180, 0.420, 0.220, 0.75 },
    centerLine = { 0.220, 0.500, 0.280, 0.90 },
    slot       = { 0.030, 0.100, 0.045, 0.92 },
    slotBorder = { 0.350, 0.650, 0.400, 0.80 },
    slotLabel  = { 0.550, 0.900, 0.600, 0.85 },
    slotHover  = { 0.180, 0.380, 0.220, 1 },
    gridLine   = { 0.180, 0.380, 0.220, 0.10 },
}

-- ── HUD (right panel) ────────────────────────────────────────────────────────

Theme.hud = {
    bg      = { 0.039, 0.008, 0.008, 1 },   -- #0a0202
    border  = { 0.545, 0.102, 0.102, 1 },   -- #8b1a1a
    text    = { 0.950, 0.950, 0.950, 1 },
    subtext = { 0.680, 0.620, 0.620, 1 },
    accent  = { 0.000, 1.000, 0.533, 1 },   -- #00ff88
    danger  = { 1.000, 0.267, 0.267, 1 },   -- #ff4444
    energy  = { 1.000, 0.843, 0.000, 1 },   -- #ffd700
}

-- Log event colors
Theme.logColors = {
    lp_damage        = { 1.00, 0.84, 0.00, 1 },
    half_end         = { 0.80, 0.80, 0.95, 1 },
    defender_destroy = { 1.00, 0.30, 0.20, 1 },
    defender_exhaust = { 1.00, 0.75, 0.15, 1 },
    cover            = { 0.75, 0.30, 1.00, 1 },
    shot             = { 0.30, 0.60, 1.00, 1 },
    card_played      = { 0.65, 0.85, 0.65, 1 },
    turn_end         = { 0.35, 0.35, 0.40, 1 },
    default          = { 0.55, 0.55, 0.60, 1 },
}

-- ── Phase colors ─────────────────────────────────────────────────────────────

Theme.phases = {
    draw    = { 0.50, 0.70, 0.90, 1 },
    summon  = { 0.40, 0.85, 0.55, 1 },
    attack  = { 1.00, 0.27, 0.27, 1 },
    ["end"] = { 0.70, 0.50, 0.85, 1 },
}

-- ── Card dimensions ───────────────────────────────────────────────────────────

-- Hand cards
Theme.card = {
    w      = 68,
    h      = 80,
    radius = 5,
    gap    = 8,
}

-- Pitched cards (portrait, fills 88×110 slot with 2px inset)
Theme.pitchCard = {
    w      = 84,
    h      = 106,
    radius = 6,
    gap    = 6,
}

-- Pitch slot (88×110, matches HTML design)
Theme.slot = {
    w      = 88,
    h      = 110,
    radius = 8,
    pad    = 2,
}

-- ── Layout (1280×800, three columns) ─────────────────────────────────────────

Theme.layout = {
    leftPanelX = 0,
    leftPanelW = 200,

    pitchX = 200,
    pitchW = 880,

    panelX = 1080,
    panelW = 200,

    topBarH = 36,
    handH   = 88,
}

-- ── Misc ──────────────────────────────────────────────────────────────────────

Theme.font = {
    small  = 8,
    normal = 11,
    large  = 16,
    title  = 24,
}

Theme.exhaustOverlay  = { 0.0, 0.0, 0.0, 0.60 }
Theme.settlingOverlay = { 0.5, 0.5, 0.0, 0.35 }

return Theme
