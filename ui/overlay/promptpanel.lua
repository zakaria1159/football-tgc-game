-- Bottom prompt panel shared by the cover prompt and the trap window. It slides up
-- over the hand so the pitch stays visible. Layout and hitboxes are pure (unit-tested).
--   [attacking card] ▶ [info text] [option card + button] ×1..3 [PASS / LET THROUGH]
local Panel = {}

Panel.X, Panel.Y, Panel.W, Panel.H = 160, 548, 960, 240
Panel.SLIDE       = 280                                   -- start offset when it slides in
Panel.SRC         = { dx = 28, dy = 44, w = 120, h = 165 } -- attacking card (hand size)
Panel.INFO        = { dx = 172, dy = 44, w = 208 }
Panel.OPT_X       = 392
Panel.COL_W       = 132
Panel.OPT_CARD    = { w = 84, h = 115, dy = 40 }
Panel.OPT_BTN     = { w = 120, h = 40, dy = 180 }
Panel.PASS        = { w = 136, h = 56 }
Panel.MAX_OPTIONS = 3

function Panel.rect(slide)
    return { x = Panel.X, y = Panel.Y + (slide or 0), w = Panel.W, h = Panel.H }
end

-- { panel, source, info, options = { { card, button }, ... }, pass } for n options.
function Panel.layout(n, slide)
    local P = Panel.rect(slide)
    local L = { panel = P, options = {} }
    L.source = { x = P.x + Panel.SRC.dx, y = P.y + Panel.SRC.dy, w = Panel.SRC.w, h = Panel.SRC.h }
    L.info   = { x = P.x + Panel.INFO.dx, y = P.y + Panel.INFO.dy, w = Panel.INFO.w, h = Panel.SRC.h }
    for i = 1, math.min(n, Panel.MAX_OPTIONS) do
        local colX = P.x + Panel.OPT_X + (i - 1) * Panel.COL_W
        L.options[i] = {
            card   = { x = colX + (Panel.COL_W - Panel.OPT_CARD.w) / 2, y = P.y + Panel.OPT_CARD.dy,
                       w = Panel.OPT_CARD.w, h = Panel.OPT_CARD.h },
            button = { x = colX + (Panel.COL_W - Panel.OPT_BTN.w) / 2, y = P.y + Panel.OPT_BTN.dy,
                       w = Panel.OPT_BTN.w, h = Panel.OPT_BTN.h },
        }
    end
    L.pass = { x = P.x + P.w - 24 - Panel.PASS.w, y = P.y + (P.h - Panel.PASS.h) / 2,
               w = Panel.PASS.w, h = Panel.PASS.h }
    return L
end

local function box(t, r, extra)
    local b = { type = t, x = r.x, y = r.y, w = r.w, h = r.h }
    for k, v in pairs(extra or {}) do b[k] = v end
    return b
end

-- Same shape as before: { type = "cover", coverer = { type, index } } … { type = "letthrough" }.
function Panel.coverHitboxes(cw, slide)
    if not cw then return {} end
    local L = Panel.layout(#cw.eligibleCoverers, slide)
    local boxes = {}
    for i, cov in ipairs(cw.eligibleCoverers) do
        local o = L.options[i]
        if o then
            local extra = { coverer = { type = cov.type, index = cov.index } }
            boxes[#boxes + 1] = box("cover", o.button, extra)
            boxes[#boxes + 1] = box("cover", o.card, extra)
        end
    end
    boxes[#boxes + 1] = box("letthrough", L.pass)
    return boxes
end

-- Same shape as before: { type = "activate", trapIndex = i } … { type = "pass" }.
function Panel.trapHitboxes(tw, slide)
    if not tw then return {} end
    local L = Panel.layout(#tw.traps, slide)
    local boxes = {}
    for i = 1, #tw.traps do
        local o = L.options[i]
        if o then
            boxes[#boxes + 1] = box("activate", o.button, { trapIndex = i })
            boxes[#boxes + 1] = box("activate", o.card, { trapIndex = i })
        end
    end
    boxes[#boxes + 1] = box("pass", L.pass)
    return boxes
end

local TRAP_TITLES = {
    pre_attack         = "TRAP WINDOW · STRIKER ATTACKS",
    post_destroy       = "TRAP WINDOW · YOUR CARD DESTROYED",
    post_damage        = "TRAP WINDOW · OPPONENT SCORED",
    post_last_defender = "TRAP WINDOW · LAST DEFENDER",
    counter_offside    = "COUNTER TRAP · OFFSIDE INCOMING",
    counter_red_card   = "COUNTER TRAP · RED CARD INCOMING",
}

function Panel.trapTitle(twType) return TRAP_TITLES[twType] or "TRAP WINDOW" end

return Panel
