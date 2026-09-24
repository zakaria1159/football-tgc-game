-- Combat overlay timeline and effects. Pure (unit-tested): time → pose, outcome styling,
-- card views built from combat snapshots, shatter pieces. ui/overlay/combat.lua draws
-- from these; scenes/match.lua advances the time and fires the LP banner at CLASH.
local Theme = require("ui.theme")
local Resolver = require("engine.cards.resolver")

local Fx = {}

-- Timeline marks (seconds since the overlay opened)
Fx.SLIDE       = 0.30   -- cards slide in from both sides
Fx.SQUASH      = 0.22   -- landing squash after SLIDE
Fx.FLIP        = 0.24   -- a face-down defender turns edge-on around CLASH
Fx.CLASH       = 0.55   -- starburst, shake, reveal (LP damage banner fires here)
Fx.CLASH_DUR   = 0.30
Fx.COUNT       = 0.70   -- ATK/DEF badges grow and count up
Fx.COUNT_DUR   = 0.50
Fx.RESULT      = 1.30   -- result ribbon; a destroyed card shatters
Fx.RESULT_DUR  = 0.30
Fx.SHATTER_DUR = 0.80
Fx.HINT        = 1.70   -- "CLICK OR SPACE" pill
Fx.SLIDE_DIST  = 700
Fx.SHAKE       = 10
Fx.LUNGE       = 70     -- px the attacker lunges toward the defender at CLASH
Fx.LUNGE_IN    = 0.12   -- ramp up before CLASH
Fx.LUNGE_OUT   = 0.30   -- settle back after CLASH

-- Card centres: the player's card is always on the left (your side of the pitch).
Fx.SIDE_X = { left = 390, right = 890 }

-- ── Easing ────────────────────────────────────────────────────────────────────

function Fx.progress(t, start, dur)
    return math.max(0, math.min(1, (t - start) / dur))
end

function Fx.backout(x)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function Fx.quadout(x) return 1 - (1 - x) * (1 - x) end

-- ── Timeline ──────────────────────────────────────────────────────────────────

-- Squash-and-stretch for k in [0, 1]: starts wide and short, springs back to 1, 1.
function Fx.squash(k)
    if k >= 1 then return 1, 1 end
    local amp = 0.2 * (1 - k) * (1 - k)
    local w = math.cos(k * math.pi * 3)
    return 1 + amp * w, 1 - amp * w
end

-- Width factor of a face-down card flipping around CLASH (0 = edge-on).
function Fx.flip(t)
    local k = Fx.progress(t, Fx.CLASH - Fx.FLIP / 2, Fx.FLIP)
    return math.abs(math.cos(k * math.pi))
end

-- Horizontal shake (px): decays over CLASH_DUR after CLASH, 0 elsewhere.
function Fx.shake(t)
    if t < Fx.CLASH or t > Fx.CLASH + Fx.CLASH_DUR then return 0 end
    local k = (t - Fx.CLASH) / Fx.CLASH_DUR
    return Fx.SHAKE * (1 - k) * (1 - k) * math.sin(k * math.pi * 8)
end

-- Attacker lunge in [0, 1]: ramps up into CLASH, then settles back.
function Fx.lunge(t)
    if t < Fx.CLASH - Fx.LUNGE_IN or t > Fx.CLASH + Fx.LUNGE_OUT then return 0 end
    if t <= Fx.CLASH then
        local k = Fx.progress(t, Fx.CLASH - Fx.LUNGE_IN, Fx.LUNGE_IN)
        return k * k
    end
    return 1 - Fx.quadout(Fx.progress(t, Fx.CLASH, Fx.LUNGE_OUT))
end

-- Which side each combatant is drawn on. The player's card is always on the left, so
-- when the opponent attacks the attacker is on the right. dir: +1 = moves right.
--   → { atk = { side, cx, dir }, def = { side, cx, dir } }
function Fx.sides(activePlayer)
    local atkSide = activePlayer == "opponent" and "right" or "left"
    local defSide = atkSide == "left" and "right" or "left"
    local function entry(side)
        return { side = side, cx = Fx.SIDE_X[side], dir = side == "left" and 1 or -1 }
    end
    return { atk = entry(atkSide), def = entry(defSide) }
end

-- Everything the overlay needs at time t. atkSide ("left" default | "right"): each card
-- slides in from its own side; the attacker lunges toward the defender at CLASH.
function Fx.pose(t, atkSide)
    local p = {}
    local slide = Fx.backout(Fx.progress(t, 0, Fx.SLIDE))
    local dir = atkSide == "right" and -1 or 1          -- attacker's direction toward the defender
    p.atkX = -dir * (1 - slide) * Fx.SLIDE_DIST + dir * Fx.LUNGE * Fx.lunge(t)
    p.defX =  dir * (1 - slide) * Fx.SLIDE_DIST
    if t < Fx.SLIDE then
        p.sx, p.sy = 1, 1
    else
        p.sx, p.sy = Fx.squash(Fx.progress(t, Fx.SLIDE, Fx.SQUASH))
    end
    p.flip    = Fx.flip(t)
    p.reveal  = t >= Fx.CLASH
    p.clash   = t < Fx.CLASH and 0 or Fx.backout(Fx.progress(t, Fx.CLASH, Fx.CLASH_DUR))
    p.shake   = Fx.shake(t)
    p.beam    = Fx.progress(t, Fx.CLASH - 0.05, 0.15)
    p.push    = Fx.quadout(Fx.progress(t, Fx.COUNT, Fx.COUNT_DUR + 0.3))
    p.badge   = t < Fx.COUNT and 0 or Fx.backout(Fx.progress(t, Fx.COUNT, 0.3))
    p.count   = Fx.quadout(Fx.progress(t, Fx.COUNT, Fx.COUNT_DUR))
    p.result  = t < Fx.RESULT and 0 or Fx.backout(Fx.progress(t, Fx.RESULT, Fx.RESULT_DUR))
    p.shatter = Fx.progress(t, Fx.RESULT, Fx.SHATTER_DUR)
    p.hint    = Fx.progress(t, Fx.HINT, 0.25)
    return p
end

function Fx.phase(t)
    if t < Fx.SLIDE then return "enter" end
    if t < Fx.CLASH then return "land" end
    if t < Fx.COUNT then return "clash" end
    if t < Fx.RESULT then return "count" end
    return "result"
end

-- True when a timeline mark is passed between prevT (exclusive) and t (inclusive).
function Fx.crossed(prevT, t, mark) return prevT < mark and t >= mark end

function Fx.countValue(target, k) return math.floor(target * k + 0.5) end

-- ── Outcomes ──────────────────────────────────────────────────────────────────

-- Result ribbon { text, fill, textColor, shadow } for an outcome.
function Fx.result(outcome, damage)
    damage = damage or 0
    local O, W = Theme.outcome, Theme.white
    if outcome == "damage" then
        return { text = "LP DAMAGE -" .. damage, fill = O.yellow, textColor = Theme.button.primary.text, shadow = false }
    elseif outcome == "defender_destroyed" then
        return { text = damage > 0 and ("DESTROYED · LP -" .. damage) or "DESTROYED",
                 fill = O.red, textColor = W, shadow = true }
    elseif outcome == "defender_exhausted" then
        return { text = "EXHAUSTED", fill = O.orange, textColor = W, shadow = true }
    elseif outcome == "attacker_exhausted" then
        return { text = "BLOCKED", fill = O.blue, textColor = W, shadow = true }
    elseif outcome == "tackled" then   -- a lost cover: the coverer survives, the attack stops
        return { text = "LAST-DITCH TACKLE", fill = O.blue, textColor = W, shadow = true }
    elseif outcome == "save" then
        return { text = "KEEPER SAVES", fill = O.blue, textColor = W, shadow = true }
    elseif outcome == "tie" then
        return { text = "TIE", fill = O.grey, textColor = Theme.inkText, shadow = false }
    end
    return { text = string.upper(tostring(outcome)), fill = O.grey, textColor = Theme.inkText, shadow = false }
end

-- Fate of each side: attackerFate, defenderFate ("destroyed" | "exhausted" | nil).
function Fx.fates(outcome)
    if outcome == "defender_destroyed" then return nil, "destroyed" end
    if outcome == "defender_exhausted" then return nil, "exhausted" end
    if outcome == "attacker_exhausted" then return "exhausted", nil end
    if outcome == "tie" or outcome == "tackled" then return "exhausted", "exhausted" end
    return nil, nil
end

-- ── Ability tags ──────────────────────────────────────────────────────────────

-- "LINK-UP +150" / "TIRED -300" for a stat tag { name, amount } (no number when amount is 0).
function Fx.tagText(tag)
    local s = string.upper(tag.name or tag.keyword or "?")
    local n = tag.amount or 0
    if n > 0 then s = s .. " +" .. n elseif n < 0 then s = s .. " -" .. (-n) end
    return s
end

-- Tag texts for one side of a combat snapshot: which = "atk" (atkTags) or "def" (defTags).
function Fx.bonusTags(snap, which)
    local out = {}
    for _, t in ipairs(snap and snap[which .. "Tags"] or {}) do out[#out + 1] = Fx.tagText(t) end
    return out
end

-- Stat keywords are shown as badge tags, not in the ability line.
Fx.STAT_KEYWORDS = {
    LINK_UP = true, INSTINCT = true, OPPORTUNIST = true, LAST_MAN = true, COUNTER_PRESS = true,
    SAFE_HANDS = true, ENGINE = true, OVERLAP = true, BOLT = true, FORTRESS = true,
}

-- Rule abilities that fired during this attack, as one line ("CLINICAL!",
-- "IMMOVABLE · HARD TACKLE!"), each named once; nil when there are none.
function Fx.abilityLine(rec)
    local names, seen = {}, {}
    for _, kw in ipairs(rec and rec.abilities or {}) do
        if not Fx.STAT_KEYWORDS[kw] and not seen[kw] then
            seen[kw] = true
            names[#names + 1] = string.upper(Resolver.NAMES[kw] or kw)
        end
    end
    if #names == 0 then return nil end
    return table.concat(names, " · ") .. "!"
end

-- ── Card views ────────────────────────────────────────────────────────────────

local SOURCES = { "strikers", "midfielders", "defenders", "keepers", "traps", "strategies" }
local byKey = nil

-- Card definition by name + type (combat snapshots carry no id), or nil.
function Fx.lookup(name, ctype)
    if not byKey then
        byKey = {}
        for _, f in ipairs(SOURCES) do
            for _, c in ipairs(require("engine.cards.definitions." .. f)) do byKey[c.type .. "|" .. c.name] = c end
        end
    end
    return byKey[tostring(ctype) .. "|" .. tostring(name)]
end

-- Everything needed to draw a combat snapshot as a real card. Badge totals always equal
-- the snapshot's atk/def; a keeper's bonus is its effective DEF minus its base DEF.
--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def, atkTags, defTags, tired } | nil
function Fx.cardView(snap, lookup)
    if not snap then return nil end
    local def = lookup and lookup(snap.name, snap.type)
    local atkBonus = snap.atkBonus or 0
    local defBonus = snap.defBonus or 0
    if snap.isKeeper and def and def.stats then
        defBonus = math.max(0, (snap.def or 0) - (def.stats.def or 0))
    end
    local cardDef = def or { name = snap.name, type = snap.type, rarity = snap.rarity or "common",
                             stats = { atk = snap.atk, def = snap.def } }
    return {
        cardDef  = cardDef,
        stats    = { atk = (snap.atk or 0) - atkBonus, def = (snap.def or 0) - defBonus },
        atkBonus = atkBonus,
        defBonus = defBonus,
        hidden   = snap.wasHidden,
        atk      = snap.atk or 0,
        def      = snap.def or 0,
        atkTags  = Fx.bonusTags(snap, "atk"),
        defTags  = Fx.bonusTags(snap, "def"),
        tired    = snap.tired == true,
    }
end

-- ── Shatter ───────────────────────────────────────────────────────────────────

-- Split a w×h image into cols×rows pieces flying outward from its centre. Deterministic
-- for a seed (Park–Miller LCG, exact in doubles and integers). Each piece:
--   { sx, sy, w, h (source rect in the image), vx, vy (px/s), spin (rad/s) }
function Fx.shatterPieces(w, h, cols, rows, seed)
    local s = math.max(1, seed or 1)
    local function rnd()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
    local pieces = {}
    local pw, ph = w / cols, h / rows
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local cx, cy = (c + 0.5) * pw - w / 2, (r + 0.5) * ph - h / 2
            local len = math.sqrt(cx * cx + cy * cy)
            local nx, ny = 0, -1
            if len > 0 then nx, ny = cx / len, cy / len end
            local speed = 220 + 180 * rnd()
            pieces[#pieces + 1] = {
                sx = c * pw, sy = r * ph, w = pw, h = ph,
                vx = nx * speed, vy = ny * speed - 160,
                spin = (rnd() - 0.5) * 8,
            }
        end
    end
    return pieces
end

-- Offset, rotation and alpha of a piece at shatter progress k in [0, 1] (with gravity).
function Fx.piecePose(piece, k)
    local tt = k * Fx.SHATTER_DUR
    return piece.vx * tt, piece.vy * tt + 450 * tt * tt, piece.spin * tt, 1 - k
end

return Fx
