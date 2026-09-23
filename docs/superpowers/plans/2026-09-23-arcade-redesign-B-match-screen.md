# Arcade Redesign, Plan B: Match Screen (Landscape)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the match screen as a landscape arcade layout. You play on the left and the opponent is mirrored on the right, with pitch-size cards. There is a top bar (avatars, draining LP bars, phase pill, icon buttons), a bottom area (portrait, deck pile, toasts, fanned hand, summons/mode/END TURN controls), hover card zoom, and juice (squash-pop, ribbon banners, confetti, re-targeted draw animation). Every interaction and keyboard shortcut keeps working, and there are no gameplay changes.

**Architecture:** One pure layout module (`ui/match/layout.lua`) owns every rect on the 1280×800 screen. Drawing and hit-testing both read from it, so they can't drift apart. Small pure-logic modules hold the hand fan geometry, LP drain, toast queue, hover delay and zoom placement, banner timing, and board stats, all unit-tested with plain Lua. Thin LÖVE drawing modules sit on top: `ui/match/topbar.lua`, `ui/match/bottombar.lua`, `ui/match/zoom.lua`, `ui/match/confetti.lua` and `ui/match/debuglog.lua`, plus rewritten `ui/pitch.lua` and `ui/hand.lua`. `scenes/match.lua` keeps its state machine, AI playback and input flow; only its drawing and hit-testing are rewired. The old side panels (`ui/hud.lua`, `ui/card_detail.lua`) and the dead `ui/log.lua` are deleted.

**Tech Stack:** LÖVE 11.4 (LuaJIT / Lua 5.1 semantics: no `//`, no `goto`, use `table.unpack or unpack`), `lib/flux.lua` for tweens, plain `lua` 5.5 (`/opt/homebrew/bin/lua`) for unit tests, `luac -p` for syntax checks of LÖVE-only files, `tools/snapshot/snap.sh` for screenshots.

**Spec:** `docs/superpowers/specs/2026-09-23-arcade-redesign-design.md` (§2 Match screen, §5 phase 3, §6 verification).
**Branch:** `feat/arcade-redesign` (already checked out; Plan A is fully merged on it).

**Conventions (apply to every task):**
- Run all commands from the repo root: `/Users/mac/Documents/football-tcg-lua`.
- Every commit message ends with a blank line followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Use `git commit -m "<subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`. The commit steps below show only the subject.
- Snapshot PNGs are captured at highdpi (2560×1600). Logical coordinates in the checklists are ×2 in the image.
- Nothing under `engine/`, `store/` or `ai/` is modified.

**Deviations from spec (intentional):**
1. **Opponent avatar:** there is no opponent character art, so it is a red sticker circle with the `soccer-kick` icon.
2. **Pause / music / log icons** are drawn with primitives (two bars, a note with a mute slash, three lines). `assets/icons/` has no such PNGs, and drawing them avoids another download approval.
3. **Toasts skip `card_drawn` and `turn_end`.** The draw animation and the turn chip already show them, and with only 3 slots they would push out real events.
4. **Card zoom:**
   - The playstyle and foul-tendency lines appear only when a card definition carries `playstyle` / `foulTendency`. No current card does.
   - Opponent face-down cards and traps never zoom, because zooming would leak hidden information.
5. **Mode toggle:** clicking a half of the ATTACK/DEFENSE segment selects that mode. Before, one button flipped it. `M` still toggles.
6. **Top-bar icon buttons work on the opponent's turn too.** Before, MUSIC only worked on your turn.
7. **Hand position:** the hand is centred at x = 700, not 640, so the portrait, deck and toast cluster fits on the left.
8. **Trap slots** sit in the bottom corner under each keeper, at 54×74, face-down. Your own traps keep the "TRAP" label as before.
9. **LP damage feedback:**
   - The full-screen LP flash (moonshine glow) is replaced by a ribbon banner plus confetti.
   - The banner says `GOAL!` / `OPPONENT SCORES!` only for keeper shots (combat outcome `"damage"`). Other LP damage keeps `LP DAMAGE DEALT!` / `LP DAMAGE TAKEN!`.
10. **Debug log and AI-hand panels** are restyled here, not in Plan C, because the new top-bar log button opens them.
11. **`Match.debugStore()`** is added as a dev hook so snapshot scenarios can read the hand. Match scenarios call `math.randomseed(7)` so the dealt hands are reproducible.
12. **`ui/log.lua`** was never required anywhere (dead code) and is deleted together with `ui/hud.lua` and `ui/card_detail.lua`.

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `ui/match/layout.lua` | create | Every rect on the match screen + `buttonAt` hit mapping (pure) |
| `ui/match/stats.lua` | create | Midfield crown owner, summons counter (pure) |
| `ui/match/handfan.lua` | create | Fan positions / rotation / dock magnification / hit test (pure) |
| `ui/match/lpbar.lua` | create | LP drain state machine (pure) + bar drawing |
| `ui/match/toasts.lua` | create | Toast queue, log-event text (pure) + drawing |
| `ui/match/hover.lua` | create | Hover delay (pure) |
| `ui/match/zoom.lua` | create | Zoom placement clamp + status lines (pure) + zoom drawing |
| `ui/match/banner.lua` | create | Ribbon banner timing (pure) + drawing |
| `ui/match/confetti.lua` | create | Multicolor confetti particle bursts |
| `ui/match/topbar.lua` | create | Avatars, LP bars, pips, phase pill, turn chip, icon buttons |
| `ui/match/bottombar.lua` | create | Portrait, deck pile, toasts, summons pill, mode toggle, START ATTACK / END TURN, hint |
| `ui/match/debuglog.lua` | create | Full match log + AI-hand debug sticker panels |
| `ui/pitch.lua` | rewrite | Landscape pitch, slots, trap slots, crown, pop animation, hitboxes |
| `ui/hand.lua` | rewrite | Fanned hand drawn with transforms; `Hand.hit`, `Hand.rectOf` |
| `ui/card.lua` | modify | `Card.bonuses` (keeper effective DEF), `Card.drawInfo` extra height |
| `ui/character.lua` | modify | `drawPortrait`, `drawAvatar` |
| `ui/kit/draw.lua` | modify | `Draw.starPoints`, `Draw.star` |
| `scenes/match.lua` | modify | Rewire draw/input to the new modules; banners, zoom, juice |
| `main.lua` | modify | Remove moonshine vignette (camera shake kept) |
| `ui/hud.lua`, `ui/card_detail.lua`, `ui/log.lua` | delete | Replaced by top bar / bottom bar / zoom |
| `tools/snapshot/scenarios.lua` | modify | Seeded match scenarios: `summon`, `juice`, `debug` |
| `tests/test_match_layout.lua` | create | Layout geometry + button mapping |
| `tests/test_card_bonuses.lua` | create | `Card.bonuses` |
| `tests/test_match_stats.lua` | create | Crown + summons |
| `tests/test_handfan.lua` | create | Fan geometry + hit test |
| `tests/test_lpbar.lua` | create | LP drain |
| `tests/test_toasts.lua` | create | Toast queue + describe |
| `tests/test_hover.lua` | create | Hover delay |
| `tests/test_zoom.lua` | create | Zoom placement + status lines |
| `tests/test_banner.lua` | create | Banner timing |
| `tests/test_draw.lua` | modify | `Draw.starPoints` |

Test count: 30 at the start, 79 at the end.

---

### Task 1: Match layout module

**Files:**
- Create: `ui/match/layout.lua`
- Test: `tests/test_match_layout.lua`

- [ ] **Step 1: Write the failing test `tests/test_match_layout.lua`**

```lua
local T      = require("tests.t")
local Layout = require("ui.match.layout")

local function inside(r, box)
    return r.x >= box.x and r.y >= box.y and r.x + r.w <= box.x + box.w and r.y + r.h <= box.y + box.h
end
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function all()
    local list = Layout.slots()
    for _, t in ipairs(Layout.trapSlots()) do list[#list + 1] = t end
    return list
end

T.test("every slot and trap slot sits inside the pitch", function()
    for _, s in ipairs(all()) do
        T.ok(inside(s, Layout.pitch), s.owner .. " " .. s.slotType .. " " .. s.slotIndex .. " outside pitch")
    end
    T.eq(#Layout.slots(), 12); T.eq(#Layout.trapSlots(), 4)
end)

T.test("opponent slots mirror player slots around x=640", function()
    for _, s in ipairs(Layout.slots()) do
        if s.owner == "player" then
            local o = Layout.slot("opponent", s.slotType, s.slotIndex)
            T.near(o.x + o.w / 2, 1280 - (s.x + s.w / 2)); T.eq(o.y, s.y)
        end
    end
    for i = 1, 2 do
        local p, o = Layout.trapSlot("player", i), Layout.trapSlot("opponent", i)
        T.near(o.x + o.w / 2, 1280 - (p.x + p.w / 2)); T.eq(o.y, p.y)
    end
end)

T.test("two-card columns stack, single-card columns are centred", function()
    local d1, d2 = Layout.slot("player", "defender", 1), Layout.slot("player", "defender", 2)
    T.eq(d1.x, d2.x); T.ok(d2.y >= d1.y + d1.h + 20, "stack gap leaves room for badges")
    local k = Layout.slot("player", "keeper", 0)
    T.near(k.y + k.h / 2, Layout.pitch.y + Layout.pitch.h / 2)
    T.eq(k.w, 108); T.eq(k.h, 148)
end)

T.test("no two slots overlap", function()
    local list = all()
    for i = 1, #list do
        for j = i + 1, #list do
            T.ok(not overlap(list[i], list[j]), "overlap " .. i .. " / " .. j)
        end
    end
end)

T.test("top bar and bottom area rects are on screen and disjoint", function()
    local T0, B = Layout.top, Layout.bottom
    local rects = { T0.youBar, T0.oppBar, T0.phasePill, T0.turnChip, T0.pause, T0.music, T0.log, T0.oppDeck,
        B.portrait, B.deck, B.deckCount, B.summons, B.toggle, B.startAttack, B.endTurn, B.hint, B.hand,
        Layout.toastRect(1), Layout.toastRect(2), Layout.toastRect(3) }
    local screen = { x = 0, y = 0, w = 1280, h = 800 }
    for i = 1, #rects do
        T.ok(inside(rects[i], screen), "rect " .. i .. " off screen")
        for j = i + 1, #rects do T.ok(not overlap(rects[i], rects[j]), "overlap " .. i .. " / " .. j) end
    end
end)

T.test("buttonAt maps clicks to actions", function()
    local function c(r) return r.x + r.w / 2, r.y + r.h / 2 end
    local B, T0 = Layout.bottom, Layout.top
    local x, y = c(B.endTurn);     T.eq(Layout.buttonAt(x, y, "attack"), "endTurn")
    x, y = c(B.startAttack);       T.eq(Layout.buttonAt(x, y, "summon"), "startAttack")
    T.eq(Layout.buttonAt(x, y, "attack"), nil)
    x, y = c(Layout.toggleHalf("attack"));  T.eq(Layout.buttonAt(x, y, "summon"), "modeAttack")
    x, y = c(Layout.toggleHalf("defense")); T.eq(Layout.buttonAt(x, y, "summon"), "modeDefense")
    x, y = c(T0.pause); T.eq(Layout.buttonAt(x, y, "summon"), "pause")
    x, y = c(T0.music); T.eq(Layout.buttonAt(x, y, "summon"), "music")
    x, y = c(T0.log);   T.eq(Layout.buttonAt(x, y, "summon"), "log")
    T.eq(Layout.buttonAt(640, 300, "summon"), nil)
end)

T.test("toast rects stack upward from the newest", function()
    T.eq(Layout.toastRect(1).y, 640); T.eq(Layout.toastRect(2).y, 606); T.eq(Layout.toastRect(3).y, 572)
end)

T.test("slot returns nil for unknown slots", function()
    T.eq(Layout.slot("player", "defender", 3), nil)
    T.eq(Layout.slot("player", "trap", 1), nil)
    T.eq(Layout.trapSlot("player", 3), nil)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_match_layout.lua (load error)` with `module 'ui.match.layout' not found`, then `30 passed, 1 failed`.

- [ ] **Step 3: Create `ui/match/layout.lua`**

```lua
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
    hand        = { x = 444, y = 540, w = 512, h = 260, cx = 700, baseY = 782 },
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `38 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/match/layout.lua tests/test_match_layout.lua
git commit -m "Add match screen layout module"
```

---

### Task 2: Card stat bonuses (keeper effective DEF) and board stats

**Files:**
- Modify: `ui/card.lua` (add `Card.bonuses` above `Card.drawPitched`; replace the bonus block inside `Card.drawPitched`)
- Create: `ui/match/stats.lua`
- Test: `tests/test_card_bonuses.lua`, `tests/test_match_stats.lua`

- [ ] **Step 1: Write the failing tests**

`tests/test_card_bonuses.lua`:

```lua
local T    = require("tests.t")
local Card = require("ui.card")

local function card(ctype, atk, def, slotType, mode)
    return { definition = { type = ctype, stats = { atk = atk, def = def } },
             slotType = slotType or ctype, mode = mode or "attack" }
end

T.test("keeper bonus is effective DEF minus base DEF", function()
    local k = card("keeper", 0, 1000)
    local pitch = { keeper = k, defenders = { card("defender", 800, 1200) },
                    midfielder = card("midfielder", 1500, 900), strikers = {} }
    local a, d = Card.bonuses(k, pitch)
    T.eq(a, 0); T.eq(d, 450)   -- +300 defender, +150 midfielder
end)

T.test("midfielder boosts strikers in attack mode and defenders in defense mode", function()
    local atkPitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900, nil, "attack") }
    local defPitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900, nil, "defense") }
    local s, d = card("striker", 2000, 500), card("defender", 800, 1200)
    local a1, d1 = Card.bonuses(s, atkPitch); T.eq(a1, 200); T.eq(d1, 0)
    local a2, d2 = Card.bonuses(d, atkPitch); T.eq(a2, 0);   T.eq(d2, 0)
    local a3, d3 = Card.bonuses(d, defPitch); T.eq(a3, 0);   T.eq(d3, 200)
end)

T.test("no pitch or a trap gives no bonus", function()
    local a, d = Card.bonuses(card("striker", 2000, 500), nil); T.eq(a, 0); T.eq(d, 0)
    local pitch = { defenders = {}, strikers = {}, midfielder = card("midfielder", 1500, 900) }
    a, d = Card.bonuses(card("trap", 0, 0, "trap", "defense"), pitch); T.eq(a, 0); T.eq(d, 0)
end)
```

`tests/test_match_stats.lua`:

```lua
local T     = require("tests.t")
local Stats = require("ui.match.stats")

local function mid(mode, atk, def, ctype)
    return { definition = { type = ctype or "midfielder", stats = { atk = atk, def = def } }, mode = mode }
end
local function match(pMid, oMid)
    return { summonCount = 0, players = {
        player   = { pitch = { midfielder = pMid, defenders = {}, strikers = {}, traps = {} } },
        opponent = { pitch = { midfielder = oMid, defenders = {}, strikers = {}, traps = {} } },
    } }
end

T.test("crown goes to the midfielder with more power", function()
    T.eq(Stats.crownOwner(match(mid("attack", 1500, 800), mid("defense", 700, 1200))), "player")
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 800), mid("defense", 700, 1200))), "opponent")
end)

T.test("no crown on a tie or without real midfielders", function()
    T.eq(Stats.crownOwner(match(nil, nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0, "striker"), nil)), nil)
    T.eq(Stats.crownOwner(match(mid("attack", 1000, 0), mid("attack", 1000, 0))), nil)
end)

T.test("summons reads the player's limit and flags the midfield bonus", function()
    local m = match(nil, nil)
    m.summonCount = 1
    m.players.player.nextTurnSummonLimit = 3
    local used, max, bonus = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 3); T.eq(bonus, true)
    m.players.player.nextTurnSummonLimit = nil
    used, max, bonus = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 2); T.eq(bonus, false)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: FAIL lines for `Card.bonuses` (`attempt to call a nil value (field 'bonuses')`) and a load error for `ui.match.stats`; exit code 1.

- [ ] **Step 3: Add `Card.bonuses` to `ui/card.lua`** directly above `function Card.drawPitched`:

```lua
-- Bonuses shown on a pitched card's badges. Pure (unit-tested).
--   striker  → +ATK from an attack-mode midfielder card
--   defender → +DEF from a defense-mode midfielder card
--   keeper   → effective DEF (defenders + midfielder) minus base DEF
function Card.bonuses(pitched, pitch)
    if not pitch then return 0, 0 end
    local st = pitched.slotType
    if st == "striker"  then return Combat.midfielderCardAtkBonus(pitch) or 0, 0 end
    if st == "defender" then return 0, Combat.midfielderCardDefBonus(pitch) or 0 end
    if st == "keeper" then
        local base = (pitched.definition.stats and pitched.definition.stats.def) or 0
        return 0, Combat.keeperEffectiveDef(pitched, pitch) - base
    end
    return 0, 0
end
```

- [ ] **Step 4: Use it in `Card.drawPitched`.** Replace these lines inside `Card.drawPitched`:

```lua
    local atkBonus, defBonus = 0, 0
    if opts.pitch then
        if pitched.slotType == "striker"  then atkBonus = Combat.midfielderCardAtkBonus(opts.pitch) or 0 end
        if pitched.slotType == "defender" then defBonus = Combat.midfielderCardDefBonus(opts.pitch) or 0 end
    end
```

with:

```lua
    local atkBonus, defBonus = Card.bonuses(pitched, opts.pitch)
```

- [ ] **Step 5: Create `ui/match/stats.lua`**

```lua
-- Board facts shown in the match UI. Pure (unit-tested).
local Combat = require("engine.combat")
local C      = require("engine.constants")

local Stats = {}

-- "player" | "opponent" | nil — whose midfielder currently has more power (★ crown).
function Stats.crownOwner(match)
    local p = Combat.midfielderPower(match.players.player.pitch)
    local o = Combat.midfielderPower(match.players.opponent.pitch)
    if p > o then return "player" end
    if o > p then return "opponent" end
    return nil
end

-- used, max, bonus — same numbers the old HUD showed ("SUMMONS used / max ★").
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    return used, max, max > C.MATCH.MAX_SUMMONS_PER_TURN
end

return Stats
```

- [ ] **Step 6: Run tests**

Run: `lua tests/run.lua`
Expected: `44 passed, 0 failed`

- [ ] **Step 7: Snapshot to confirm the keeper badge still renders in the old layout**

Run: `tools/snapshot/snap.sh match`
Expected: PNGs listed, no Lua error. The board is unchanged (no keeper on the pitch yet at turn 1).

- [ ] **Step 8: Commit**

```bash
git add ui/card.lua ui/match/stats.lua tests/test_card_bonuses.lua tests/test_match_stats.lua
git commit -m "Show keeper effective DEF on its badge; add match board stats"
```

---

### Task 3: Hand fan geometry

**Files:**
- Create: `ui/match/handfan.lua`
- Test: `tests/test_handfan.lua`

- [ ] **Step 1: Write the failing test `tests/test_handfan.lua`**

```lua
local T       = require("tests.t")
local HandFan = require("ui.match.handfan")

local AREA = { x = 444, y = 540, w = 512, cx = 700, baseY = 782 }
local W, H = HandFan.CARD_W, HandFan.CARD_H

T.test("empty hand returns nothing", function()
    local cards, order = HandFan.layout(0, AREA)
    T.eq(#cards, 0); T.eq(#order, 0)
end)

T.test("cards are centred and symmetric at rest", function()
    local c = HandFan.layout(5, AREA)
    T.near(c[3].cx, 700); T.near(c[3].angle, 0)
    T.near(c[1].cx + c[5].cx, 1400)
    T.near(c[1].angle, -c[5].angle)
    T.ok(c[1].angle < 0 and c[5].angle > 0)
    T.ok(c[1].by > c[3].by, "edges droop along the arc")
end)

T.test("spacing shrinks so big hands fit the area", function()
    local c = HandFan.layout(9, AREA)
    T.ok(c[9].cx - c[1].cx + W <= AREA.w + 1e-9)
end)

T.test("hovered card grows, straightens, lifts and is drawn last", function()
    local rest = HandFan.layout(5, AREA)
    local c, order = HandFan.layout(5, AREA, rest[2].baseCx, 700)
    T.near(c[2].scale, 1 + HandFan.BOOST)
    T.near(c[2].angle, 0)
    T.near(c[2].by, AREA.baseY + HandFan.ARC_DROP - HandFan.LIFT)
    T.near(c[2].cx, rest[2].baseCx, 1e-6)
    T.eq(order[#order], 2)
end)

T.test("neighbours are pushed away from the hovered card", function()
    local rest = HandFan.layout(5, AREA)
    local c = HandFan.layout(5, AREA, rest[3].baseCx, 700)
    T.ok(c[2].cx < c[2].baseCx); T.ok(c[4].cx > c[4].baseCx)
    T.near(c[3].cx, c[3].baseCx)
end)

T.test("mouse above the hand area does not magnify", function()
    local c = HandFan.layout(5, AREA, 700, 400)
    for i = 1, 5 do T.near(c[i].scale, 1) end
end)

T.test("hit finds the rotated card under the point", function()
    local c, order = HandFan.layout(5, AREA)
    local px = c[1].cx + (H / 2) * math.sin(c[1].angle)
    local py = c[1].by - (H / 2) * math.cos(c[1].angle)
    T.eq(HandFan.hit(c, order, px, py), 1)
    T.eq(HandFan.hit(c, order, 0, 0), nil)
    local hc, horder = HandFan.layout(5, AREA, c[3].baseCx, 700)
    T.eq(HandFan.hit(hc, horder, c[3].baseCx, AREA.baseY - 60), 3)
end)

T.test("selected card lifts", function()
    local c = HandFan.layout(5, AREA, nil, nil, 2)
    T.near(c[2].by, AREA.baseY + HandFan.ARC_DROP - HandFan.SELECT_LIFT)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: load error `module 'ui.match.handfan' not found`; exit code 1.

- [ ] **Step 3: Create `ui/match/handfan.lua`**

```lua
-- Fanned-hand geometry with macOS-Dock-style magnification. Pure (unit-tested).
-- Each card is drawn as: translate(cx, by) · rotate(angle) · scale(scale) · card at (-W/2, -H).
local HandFan = {}

HandFan.CARD_W, HandFan.CARD_H = 120, 165   -- Theme.cardSize.hand
HandFan.MAX_SPACING = 84     -- centre-to-centre at rest
HandFan.ANGLE_STEP  = 0.06   -- radians between neighbours
HandFan.MAX_ANGLE   = 0.20   -- outermost card rotation cap
HandFan.ARC_DROP    = 2.5    -- px × (offset from centre)²
HandFan.BOOST       = 0.35   -- hovered card scale = 1 + BOOST
HandFan.RADIUS      = 110    -- px from a card centre where magnification fades out
HandFan.LIFT        = 28     -- hovered card rises this much
HandFan.SELECT_LIFT = 18

local function smoothstep(t) return t * t * (3 - 2 * t) end

-- n cards in area { x, y, w, cx, baseY }. hoverX/hoverY = mouse (nil = none).
-- Returns cards[i] = { index, baseCx, cx, by, angle, scale, t } and a draw order
-- (index order, with the most-magnified card last).
function HandFan.layout(n, area, hoverX, hoverY, selectedIndex)
    local cards, order = {}, {}
    if n <= 0 then return cards, order end
    local W = HandFan.CARD_W
    local sp, step = HandFan.MAX_SPACING, HandFan.ANGLE_STEP
    if n > 1 then
        sp   = math.min(sp, (area.w - W) / (n - 1))
        step = math.min(step, HandFan.MAX_ANGLE / ((n - 1) / 2))
    end
    local mid = (n + 1) / 2
    local hovering = hoverX ~= nil and hoverY ~= nil and hoverY >= area.y
    local hot, hotT = nil, 0

    for i = 1, n do
        local off = i - mid
        local baseCx = area.cx + off * sp
        local t = 0
        if hovering then
            local d = math.abs(hoverX - baseCx)
            if d < HandFan.RADIUS then t = smoothstep(1 - d / HandFan.RADIUS) end
        end
        if t > hotT then hot, hotT = i, t end
        local by = area.baseY + off * off * HandFan.ARC_DROP - HandFan.LIFT * t
        if i == selectedIndex then by = by - HandFan.SELECT_LIFT end
        cards[i] = {
            index = i, baseCx = baseCx, cx = baseCx, by = by, t = t,
            scale = 1 + HandFan.BOOST * t,
            angle = off * step * (1 - t),
        }
    end

    -- Each card grows equally to both sides: push the others away by half its growth.
    for i = 1, n do
        local shift = 0
        for j = 1, n do
            local grow = (cards[j].scale - 1) * W * 0.5
            if j < i then shift = shift + grow elseif j > i then shift = shift - grow end
        end
        cards[i].cx = cards[i].baseCx + shift
    end

    for i = 1, n do if i ~= hot then order[#order + 1] = i end end
    if hot then order[#order + 1] = hot end
    return cards, order
end

-- Index of the top-most card under (px, py), or nil. A few px below the card
-- bottom still counts so the screen edge is forgiving.
function HandFan.hit(cards, order, px, py)
    local W, H = HandFan.CARD_W, HandFan.CARD_H
    for k = #order, 1, -1 do
        local c = cards[order[k]]
        local dx, dy = px - c.cx, py - c.by
        local cs, sn = math.cos(-c.angle), math.sin(-c.angle)
        local lx = (dx * cs - dy * sn) / c.scale
        local ly = (dx * sn + dy * cs) / c.scale
        if lx >= -W / 2 and lx <= W / 2 and ly >= -H and ly <= 12 then return c.index end
    end
    return nil
end

-- Axis-aligned screen rect of a card (rotation ignored) — used as an animation origin.
function HandFan.rect(c)
    local w, h = HandFan.CARD_W * c.scale, HandFan.CARD_H * c.scale
    return { x = c.cx - w / 2, y = c.by - h, w = w, h = h }
end

return HandFan
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua`
Expected: `52 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/match/handfan.lua tests/test_handfan.lua
git commit -m "Add hand fan geometry with dock magnification"
```

---

### Task 4: LP bar drain

**Files:**
- Create: `ui/match/lpbar.lua`
- Test: `tests/test_lpbar.lua`

- [ ] **Step 1: Write the failing test `tests/test_lpbar.lua`**

```lua
local T     = require("tests.t")
local LPBar = require("ui.match.lpbar")

T.test("a new bar is settled", function()
    local b = LPBar.new(4000, 4000)
    T.eq(b.shown, 4000); T.eq(b.chunk, 4000)
    local f, c = b:ratios(); T.near(f, 1); T.near(c, 1)
end)

T.test("damage counts the number down to the target", function()
    local b = LPBar.new(4000, 4000)
    b:set(3000)
    b:update(0.3)
    T.ok(b.shown > 3000 and b.shown < 4000, "mid count-down: " .. b.shown)
    b:update(0.5)
    T.eq(b.shown, 3000)
end)

T.test("the white chunk lingers, then drains", function()
    local b = LPBar.new(4000, 4000)
    b:set(3000)
    b:update(0.3)
    T.near(b.chunk, 4000)
    b:update(0.7)
    T.near(b.chunk, 3000); T.eq(b.active, false)
end)

T.test("healing jumps instantly", function()
    local b = LPBar.new(3000, 4000)
    b:set(3500)
    T.eq(b.shown, 3500); T.near(b.chunk, 3500)
end)

T.test("a second hit mid-drain keeps the chunk where it was", function()
    local b = LPBar.new(4000, 4000)
    b:set(3000); b:update(0.5)
    local before = b.chunk
    b:set(2000)
    T.near(b.chunk, before); T.ok(b.chunk > 3000)
    b:update(2)
    T.eq(b.shown, 2000); T.near(b.chunk, 2000)
end)

T.test("ratios clamp to 0..1", function()
    local f, c = LPBar.new(-200, 4000):ratios()
    T.near(f, 0); T.near(c, 0)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: load error `module 'ui.match.lpbar' not found`; exit code 1.

- [ ] **Step 3: Create `ui/match/lpbar.lua`**

```lua
-- LP bar with count-down numbers and a trailing white "damage chunk".
-- State logic is pure (unit-tested); LPBar.draw uses LÖVE.
-- Fills are flat rounded rects (no gradient meshes) because their width animates.
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")

local LPBar = {}
LPBar.__index = LPBar

LPBar.COUNT_TIME  = 0.6    -- number + fill count down
LPBar.CHUNK_DELAY = 0.35   -- white chunk waits...
LPBar.CHUNK_TIME  = 0.45   -- ...then drains

function LPBar.new(value, max)
    return setmetatable({
        max = max or 4000, target = value, shown = value, chunk = value,
        from = value, chunkFrom = value, t = 0, active = false,
    }, LPBar)
end

function LPBar:set(value)
    if value == self.target then return end
    if value > self.target then          -- gains are instant
        self.target, self.shown, self.chunk = value, value, value
        self.active = false
        return
    end
    self.from      = self.shown
    self.chunkFrom = self.chunk
    self.target    = value
    self.t         = 0
    self.active    = true
end

function LPBar:update(dt)
    if not self.active then return end
    self.t = self.t + dt
    local k = math.min(1, self.t / LPBar.COUNT_TIME)
    k = 1 - (1 - k) * (1 - k)            -- ease-out
    self.shown = math.floor(self.from + (self.target - self.from) * k + 0.5)
    local ct = math.min(1, math.max(0, self.t - LPBar.CHUNK_DELAY) / LPBar.CHUNK_TIME)
    self.chunk = self.chunkFrom + (self.target - self.chunkFrom) * ct
    if k >= 1 and ct >= 1 then
        self.shown, self.chunk, self.active = self.target, self.target, false
    end
end

-- fill ratio, chunk ratio (chunk never smaller than fill), both clamped to 0..1.
function LPBar:ratios()
    local f = math.max(0, math.min(1, self.shown / self.max))
    local c = math.max(0, math.min(1, self.chunk / self.max))
    return f, math.max(f, c)
end

-- r: rect; grad: {top, bottom}; mirrored: fill anchored at the right edge (opponent).
function LPBar.draw(bar, r, grad, label, mirrored)
    Draw.sticker(r.x, r.y, r.w, r.h, {
        r = r.h / 2, fill = { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.6 }, border = 3, shadow = 4,
    })
    local inset = 5
    local ix, iy, iw, ih = r.x + inset, r.y + inset, r.w - inset * 2, r.h - inset * 2
    local f, c = bar:ratios()
    local fw, cw = math.floor(iw * f + 0.5), math.floor(iw * c + 0.5)
    local function left(w) return mirrored and (ix + iw - w) or ix end
    if cw > 0 then Draw.roundedFill(left(cw), iy, cw, ih, ih / 2, Theme.white) end
    if fw > 0 then
        Draw.roundedFill(left(fw), iy, fw, ih, ih / 2, grad[2])
        local gh = math.floor(ih * 0.55)
        Draw.roundedFill(left(fw), iy, fw, gh, gh / 2, grad[1])
    end
    Draw.text(label, r.x, r.y + (r.h - 18) / 2 - 2, r.w, "center", {
        size = 18, color = Theme.white, outline = 2, outlineColor = Theme.ink,
    })
end

return LPBar
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua`
Expected: `58 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/match/lpbar.lua tests/test_lpbar.lua
git commit -m "Add LP bar with count-down and trailing damage chunk"
```

---

### Task 5: Toast queue

**Files:**
- Create: `ui/match/toasts.lua`
- Test: `tests/test_toasts.lua`

- [ ] **Step 1: Write the failing test `tests/test_toasts.lua`**

```lua
local T      = require("tests.t")
local Toasts = require("ui.match.toasts")

T.test("push keeps the newest first and at most 3", function()
    local q = Toasts.new()
    for _, s in ipairs({ "a", "b", "c", "d" }) do q:push(s, "info") end
    T.eq(#q.items, 3); T.eq(q.items[1].text, "d"); T.eq(q.items[3].text, "b")
end)

T.test("toasts expire after LIFE seconds", function()
    local q = Toasts.new()
    q:push("x")
    q:update(Toasts.LIFE - 0.1); T.eq(#q.items, 1)
    q:update(0.2);               T.eq(#q.items, 0)
end)

T.test("pose slides in, holds, then fades", function()
    local s, a = Toasts.pose(0);   T.near(s, -40); T.near(a, 0)
    s, a = Toasts.pose(1);         T.near(s, 0);   T.near(a, 1)
    s, a = Toasts.pose(Toasts.LIFE - Toasts.FADE / 2); T.near(a, 0.5)
end)

T.test("lp_damage is good when you deal it, bad when you take it", function()
    local txt, kind = Toasts.describe({ type = "lp_damage", payload = { dealer = "player", damage = 400 } })
    T.eq(txt, "You dealt 400 LP"); T.eq(kind, "good")
    txt, kind = Toasts.describe({ type = "lp_damage", payload = { dealer = "opponent", damage = 400 } })
    T.eq(txt, "You took 400 LP"); T.eq(kind, "bad")
end)

T.test("card_drawn and turn_end are skipped", function()
    T.eq(Toasts.describe({ type = "card_drawn", payload = { player = "player" } }), nil)
    T.eq(Toasts.describe({ type = "turn_end", payload = { turn = 2 } }), nil)
end)

T.test("traps, midfield control and summons", function()
    local _, kind = Toasts.describe({ type = "trap_activated", payload = { player = "opponent", trap = "trap-offside" } })
    T.eq(kind, "trap")
    _, kind = Toasts.describe({ type = "midfield_control", payload = { player = "opponent" } })
    T.eq(kind, "bad")
    local txt = Toasts.describe({ type = "card_played", payload = { player = "player", slot = "striker" } })
    T.eq(txt, "You summoned a STRIKER")
end)

T.test("unknown events fall back to readable text", function()
    local txt, kind = Toasts.describe({ type = "foo_bar" })
    T.eq(txt, "foo bar"); T.eq(kind, "info")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: load error `module 'ui.match.toasts' not found`; exit code 1.

- [ ] **Step 3: Create `ui/match/toasts.lua`**

```lua
-- Toast stack for the 3 latest match-log events (replaces the HUD log panel).
-- Queue, timing and text are pure (unit-tested); Toasts:draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local Toasts = {}
Toasts.__index = Toasts

Toasts.LIFE  = 4.0
Toasts.FADE  = 0.5
Toasts.SLIDE = 0.25
Toasts.MAX   = 3

function Toasts.new() return setmetatable({ items = {} }, Toasts) end

function Toasts:push(text, kind)
    table.insert(self.items, 1, { text = text, kind = kind or "info", age = 0 })
    while #self.items > Toasts.MAX do table.remove(self.items) end
end

function Toasts:update(dt)
    for i = #self.items, 1, -1 do
        local it = self.items[i]
        it.age = it.age + dt
        if it.age >= Toasts.LIFE then table.remove(self.items, i) end
    end
end

-- x offset (slides in from the left) and alpha for a toast of this age.
function Toasts.pose(age)
    local slide, alpha = 0, 1
    if age < Toasts.SLIDE then
        local k = age / Toasts.SLIDE
        slide = -40 * (1 - k) * (1 - k)
        alpha = k
    end
    local fadeStart = Toasts.LIFE - Toasts.FADE
    if age > fadeStart then alpha = math.max(0, 1 - (age - fadeStart) / Toasts.FADE) end
    return slide, alpha
end

-- text, kind for a log entry (nil = no toast). kind: good | bad | trap | half | info
function Toasts.describe(entry)
    local t = entry.type or ""
    local p = entry.payload or {}
    local mine = p.player == "player"
    local who = mine and "You" or "Opp"

    if t == "card_drawn" or t == "turn_end" then return nil end
    if t == "lp_damage" then
        local you = p.dealer == "player"
        local txt = (you and "You dealt " or "You took ") .. tostring(p.damage or 0) .. " LP"
        if p.source == "facedown_penalty" then txt = txt .. " (bluff!)" end
        return txt, you and "good" or "bad"
    end
    if t == "half_end"  then return "Half " .. tostring(p.half or "?") .. " over", "half" end
    if t == "match_end" then return "FULL TIME", "half" end
    if t == "midfield_control" then
        return (mine and "You control" or "Opp controls") .. " midfield +1 summon", mine and "good" or "bad"
    end
    if t == "trap_activated" then
        local nm = (p.trap or "trap"):gsub("^trap%-", ""):gsub("%-", " ")
        return "TRAP! " .. string.upper(nm) .. " (" .. who .. ")", "trap"
    end
    if t == "card_played" then
        if p.action == "mode_change" then return who .. " flipped a card face-up", "info" end
        if p.slot == "trap" then return who .. " set a trap", "trap" end
        return who .. " summoned a " .. string.upper(tostring(p.slot or "card")), "info"
    end
    if t == "defender_destroy" then
        return string.upper(p.slot and p.slot.type or "card") .. " destroyed", "info"
    end
    if t == "cover" then
        return "COVER by " .. string.upper(p.coverer and p.coverer.type or "?"), "info"
    end
    if t == "shot" then
        if p.outcome == "save" then return "Keeper SAVES!", "info" end
        if p.outcome == "tie"  then return "Keeper blocks - tie", "info" end
        return "Shot: " .. tostring(p.outcome or "?"), "info"
    end
    if t == "attack_declared" then
        local a = p.attacker and p.attacker.type or "?"
        local d = p.defender and p.defender.type or "?"
        return string.upper(a) .. " attacks " .. string.upper(d), "info"
    end
    if t == "strategy_played" then
        local ab = string.lower(p.ability or "strategy"):gsub("_", " ")
        return who .. " played " .. ab, "info"
    end
    if t == "attack_wasted" then return "Attack wasted", "info" end
    local s = t:gsub("_", " ")
    return s, "info"
end

local FILLS = {
    good = Theme.grad.lpYou, bad = Theme.grad.lpOpp, trap = Theme.typeGrad.trap,
    half = Theme.button.primary.fill, info = Theme.white,
}
local TEXT = { info = Theme.inkText, half = Theme.button.primary.text }

function Toasts:draw()
    for i, it in ipairs(self.items) do
        local r = Layout.toastRect(i)
        local slide, a = Toasts.pose(it.age)
        local x = r.x + slide
        Draw.sticker(x, r.y, r.w, r.h, { r = 10, fill = FILLS[it.kind] or FILLS.info, border = 2, shadow = 3, alpha = a })
        Draw.text(it.text, x + 10, r.y + 6, r.w - 20, "left", {
            size = 13, body = true, color = TEXT[it.kind] or Theme.white, fit = true, minSize = 9, alpha = a,
        })
    end
end

return Toasts
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua`
Expected: `65 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/match/toasts.lua tests/test_toasts.lua
git commit -m "Add toast queue for match log events"
```

---

### Task 6: Hover delay and card zoom

**Files:**
- Create: `ui/match/hover.lua`, `ui/match/zoom.lua`
- Modify: `ui/card.lua` (`Card.drawInfo` gains an optional `extraH`)
- Test: `tests/test_hover.lua`, `tests/test_zoom.lua`

- [ ] **Step 1: Write the failing tests**

`tests/test_hover.lua`:

```lua
local T     = require("tests.t")
local Hover = require("ui.match.hover")

T.test("hover shows only after the delay", function()
    local h = Hover.new(0.3)
    T.eq(h:update(0.1, "a"), false)
    T.eq(h:update(0.2, "a"), false)
    T.eq(h:update(0.15, "a"), true)
    T.ok(h:shown())
end)

T.test("a new key restarts the timer", function()
    local h = Hover.new(0.3)
    h:update(0, "a"); h:update(0.4, "a")
    T.ok(h:shown())
    T.eq(h:update(0.1, "b"), false)
    T.ok(not h:shown())
    T.eq(h:update(0.31, "b"), true)
end)

T.test("nil key hides and stays hidden", function()
    local h = Hover.new(0.3)
    h:update(0, "a"); h:update(0.5, "a")
    T.eq(h:update(0.1, nil), false)
    T.eq(h:update(1.0, nil), false)
    T.ok(not h:shown())
end)
```

`tests/test_zoom.lua`:

```lua
local T    = require("tests.t")
local Zoom = require("ui.match.zoom")

T.test("zoom goes right of the source when it fits", function()
    local p = Zoom.place({ x = 100, y = 300, w = 108, h = 148 }, 200, 1280, 800)
    T.eq(p.cardX, 222); T.eq(p.infoX, 536); T.eq(p.cardY, 169); T.eq(p.infoY, 169)
end)

T.test("zoom flips left near the right edge (card next to the source)", function()
    local p = Zoom.place({ x = 1112, y = 231, w = 108, h = 148 }, 200, 1280, 800)
    T.eq(p.infoX, 534); T.eq(p.cardX, 798)
    T.ok(p.cardX + Zoom.W <= 1112)
end)

T.test("zoom clamps vertically, leaving room for tag and badges", function()
    T.eq(Zoom.place({ x = 640, y = 640, w = 120, h = 165 }, 200, 1280, 800).cardY, 332)
    T.eq(Zoom.place({ x = 100, y = 0, w = 10, h = 10 }, 200, 1280, 800).cardY, 32)
end)

T.test("zoom clamps horizontally when neither side fits", function()
    local p = Zoom.place({ x = 400, y = 300, w = 500, h = 100 }, 200, 1280, 800)
    T.eq(p.infoX, 8); T.eq(p.cardX, 272)
end)

local function has(lines, text)
    for _, l in ipairs(lines) do if l.text == text then return true end end
    return false
end

T.test("a plain hand card has no status lines", function()
    T.eq(#Zoom.statusLines({ type = "striker", stats = { atk = 1, def = 1 } }, nil, nil), 0)
end)

T.test("pitched striker shows bonus, mode, exhausted and yellow cards", function()
    local def = { type = "striker", stats = { atk = 2000, def = 500 } }
    local pitched = { definition = def, slotType = "striker", mode = "attack", exhausted = true, yellowCards = 1 }
    local pitch = { defenders = {}, strikers = {},
        midfielder = { definition = { type = "midfielder", stats = { atk = 1500, def = 900 } }, mode = "attack" } }
    local lines = Zoom.statusLines(def, pitched, pitch)
    T.ok(has(lines, "ATK 2000 + 200 = 2200"))
    T.ok(has(lines, "Mode: ATTACK"))
    T.ok(has(lines, "EXHAUSTED"))
    T.ok(has(lines, "Yellow cards: 1"))
end)

T.test("pitched keeper shows effective DEF", function()
    local def = { type = "keeper", stats = { atk = 0, def = 1000 } }
    local keeper = { definition = def, slotType = "keeper", mode = "defense" }
    local pitch = { keeper = keeper, strikers = {},
        defenders = { { definition = { type = "defender", stats = { atk = 1, def = 1 } }, mode = "attack" } } }
    local lines = Zoom.statusLines(def, keeper, pitch)
    T.ok(has(lines, "Effective DEF 1000 + 300 = 1300"))
    T.ok(has(lines, "Mode: DEFENSE (face-down)"))
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: load errors for `ui.match.hover` and `ui.match.zoom`; exit code 1.

- [ ] **Step 3: Create `ui/match/hover.lua`**

```lua
-- Hover-with-delay tracker. Pure (unit-tested).
local Hover = {}
Hover.__index = Hover
Hover.DELAY = 0.3

function Hover.new(delay)
    return setmetatable({ key = nil, t = 0, delay = delay or Hover.DELAY, payload = nil }, Hover)
end

-- key: stable id of the thing under the mouse (nil = nothing). Returns true once shown.
function Hover:update(dt, key, payload)
    if key ~= self.key then
        self.key, self.t, self.payload = key, 0, payload
        return false
    end
    if key == nil then return false end
    self.t = self.t + dt
    self.payload = payload
    return self.t >= self.delay
end

function Hover:shown() return self.key ~= nil and self.t >= self.delay end

function Hover:reset() self.key, self.t, self.payload = nil, 0, nil end

return Hover
```

- [ ] **Step 4: Let `Card.drawInfo` grow for extra lines.** In `ui/card.lua` replace:

```lua
function Card.drawInfo(cardDef, x, y, w)
    local pad = INFO_PAD
    local h = Card.infoHeight(cardDef, w)
```

with:

```lua
function Card.drawInfo(cardDef, x, y, w, extraH)
    local pad = INFO_PAD
    local h = Card.infoHeight(cardDef, w) + (extraH or 0)
```

- [ ] **Step 5: Create `ui/match/zoom.lua`**

```lua
-- Card zoom: zoom-size card + info sticker beside the hovered card, clamped on screen.
-- Zoom.place / Zoom.statusLines are pure (unit-tested); Zoom.draw uses LÖVE.
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")

local Zoom = {}
Zoom.W, Zoom.H    = 300, 410   -- Theme.cardSize.zoom
Zoom.INFO_W       = 250
Zoom.GAP          = 14
Zoom.MARGIN       = 8
Zoom.TOP_OVER     = 24         -- type tag sticks out above the card
Zoom.BOTTOM_OVER  = 50         -- ATK/DEF badges stick out below
Zoom.LINE_H       = 18

-- src: rect of the hovered card. Returns { cardX, cardY, infoX, infoY }.
-- Right of the source if it fits ([src][card][info]); else left ([info][card][src]);
-- else clamped to the screen.
function Zoom.place(src, infoH, W, H)
    local m  = Zoom.MARGIN
    local tw = Zoom.W + Zoom.GAP + Zoom.INFO_W
    local cardX, infoX
    local rightX = src.x + src.w + Zoom.GAP
    if rightX + tw <= W - m then
        cardX = rightX
        infoX = rightX + Zoom.W + Zoom.GAP
    else
        local x = src.x - Zoom.GAP - tw
        if x < m then x = math.max(m, math.min(W - m - tw, x)) end
        infoX = x
        cardX = x + Zoom.INFO_W + Zoom.GAP
    end
    local minY = m + Zoom.TOP_OVER
    local maxY = H - m - Zoom.BOTTOM_OVER - Zoom.H
    local cardY = math.max(minY, math.min(maxY, src.y + src.h / 2 - Zoom.H / 2))
    local infoY = math.max(m, math.min(H - m - infoH, cardY))
    return { cardX = cardX, cardY = cardY, infoX = infoX, infoY = infoY }
end

-- Extra lines under the ability text: { text, color = ink|bonus|bad|warn }.
function Zoom.statusLines(cardDef, pitched, pitch)
    local lines = {}
    local function add(text, color) lines[#lines + 1] = { text = text, color = color } end
    if cardDef.playstyle then
        local ps = cardDef.playstyle
        add("Style: " .. (type(ps) == "table" and table.concat(ps, " · ") or tostring(ps)), "ink")
    end
    if cardDef.foulTendency then add("Foul tendency: " .. string.upper(tostring(cardDef.foulTendency)), "ink") end
    if not pitched then return lines end

    local st = cardDef.stats or {}
    local atkB, defB = Card.bonuses(pitched, pitch)
    if atkB > 0 then
        add("ATK " .. (st.atk or 0) .. " + " .. atkB .. " = " .. ((st.atk or 0) + atkB), "bonus")
    end
    if defB > 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(label .. (st.def or 0) .. " + " .. defB .. " = " .. ((st.def or 0) + defB), "bonus")
    end
    add(pitched.mode == "defense" and "Mode: DEFENSE (face-down)" or "Mode: ATTACK", "ink")
    if pitched.exhausted then add("EXHAUSTED", "bad") end
    if pitched.cannotActNextTurn then add("Cannot act next turn", "bad") end
    if (pitched.yellowCards or 0) > 0 then add("Yellow cards: " .. pitched.yellowCards, "warn") end
    return lines
end

function Zoom.infoHeight(cardDef, lines)
    return Card.infoHeight(cardDef, Zoom.INFO_W) + (#lines > 0 and (#lines * Zoom.LINE_H + 6) or 0)
end

local LINE_COLORS = {
    ink = Theme.inkText, bonus = Theme.hex("16a34a"), bad = Theme.hex("e0243a"), warn = Theme.hex("c98a00"),
}

-- z = { cardDef, pitched (optional), pitch (optional), src = rect, scale (pop-in) }
function Zoom.draw(z)
    local lines = Zoom.statusLines(z.cardDef, z.pitched, z.pitch)
    local baseH = Card.infoHeight(z.cardDef, Zoom.INFO_W)
    local infoH = Zoom.infoHeight(z.cardDef, lines)
    local p = Zoom.place(z.src, infoH, love.graphics.getWidth(), love.graphics.getHeight())
    local s = z.scale or 1
    local ox, oy = p.cardX + Zoom.W / 2, p.cardY + Zoom.H / 2

    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(s, s)
    love.graphics.translate(-ox, -oy)

    local atkB, defB = 0, 0
    if z.pitched then atkB, defB = Card.bonuses(z.pitched, z.pitch) end
    Card.drawFace(z.cardDef, p.cardX, p.cardY, Zoom.W, Zoom.H, {
        atkBonus  = atkB > 0 and atkB or nil,
        defBonus  = defB > 0 and defB or nil,
        exhausted = z.pitched and z.pitched.exhausted or nil,
    })
    Card.drawInfo(z.cardDef, p.infoX, p.infoY, Zoom.INFO_W, infoH - baseH)
    local y = p.infoY + baseH - 6
    for _, ln in ipairs(lines) do
        Draw.text(ln.text, p.infoX + 12, y, Zoom.INFO_W - 24, "left", {
            size = 13, body = true, color = LINE_COLORS[ln.color] or Theme.inkText, fit = true, minSize = 9,
        })
        y = y + Zoom.LINE_H
    end
    love.graphics.pop()
end

return Zoom
```

- [ ] **Step 6: Run tests**

Run: `lua tests/run.lua`
Expected: `75 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add ui/match/hover.lua ui/match/zoom.lua ui/card.lua tests/test_hover.lua tests/test_zoom.lua
git commit -m "Add hover delay and card zoom placement"
```

---

### Task 7: Ribbon banner

**Files:**
- Create: `ui/match/banner.lua`
- Test: `tests/test_banner.lua`

- [ ] **Step 1: Write the failing test `tests/test_banner.lua`**

```lua
local T      = require("tests.t")
local Banner = require("ui.match.banner")

T.test("pose slides in from the left, holds, slides out right", function()
    local dx, a = Banner.pose(0);           T.near(dx, -Banner.SLIDE); T.near(a, 1)
    dx, a = Banner.pose(Banner.IN);         T.near(dx, 0);             T.near(a, 1)
    dx, a = Banner.pose(Banner.total());    T.near(dx, Banner.SLIDE, 1e-3); T.near(a, 0, 1e-6)
end)

T.test("a banner disappears after its total time", function()
    local b = Banner.new()
    b:show("X", "good")
    b:update(1.0); T.eq(b.text, "X")
    b:update(2.0); T.eq(b.text, nil)
end)

T.test("show restarts a running banner", function()
    local b = Banner.new()
    b:show("A"); b:update(1.0)
    b:show("B", "bad")
    T.eq(b.text, "B"); T.eq(b.kind, "bad"); T.near(b.t, 0)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: load error `module 'ui.match.banner' not found`; exit code 1.

- [ ] **Step 3: Create `ui/match/banner.lua`**

```lua
-- Ribbon banner for Match.flash messages (MIDFIELD CONTROL, GOAL!, errors).
-- Timing is pure (unit-tested); draw uses LÖVE.
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local Banner = {}
Banner.__index = Banner

Banner.IN, Banner.HOLD, Banner.OUT = 0.3, 1.6, 0.35
Banner.Y, Banner.W, Banner.H = 250, 560, 60
Banner.SLIDE = 900

local STYLES = {
    good  = { fill = Theme.button.go.fill,      text = Theme.white,               shadow = true },
    bad   = { fill = Theme.button.danger.fill,  text = Theme.white,               shadow = true },
    info  = { fill = Theme.button.primary.fill, text = Theme.button.primary.text, shadow = false },
    error = { fill = Theme.button.neutral.fill, text = Theme.inkText,             shadow = false },
}

function Banner.new() return setmetatable({ text = nil, kind = "info", t = 0 }, Banner) end

function Banner.total() return Banner.IN + Banner.HOLD + Banner.OUT end

function Banner:show(text, kind)
    self.text, self.kind, self.t = text, kind or "info", 0
end

function Banner:update(dt)
    if not self.text then return end
    self.t = self.t + dt
    if self.t >= Banner.total() then self.text = nil end
end

-- x offset and alpha at time t.
function Banner.pose(t)
    if t < Banner.IN then
        local k = 1 - t / Banner.IN
        return -Banner.SLIDE * k * k * k, 1
    elseif t < Banner.IN + Banner.HOLD then
        return 0, 1
    end
    local k = math.min(1, (t - Banner.IN - Banner.HOLD) / Banner.OUT)
    return Banner.SLIDE * k * k, 1 - k
end

function Banner:draw()
    if not self.text then return end
    local dx, a = Banner.pose(self.t)
    local st = STYLES[self.kind] or STYLES.info
    Draw.ribbon(Layout.midX + dx, Banner.Y, Banner.W, Banner.H, self.text, {
        fill = st.fill, textColor = st.text, size = 32, alpha = a, textShadow = st.shadow,
    })
end

return Banner
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua`
Expected: `78 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/match/banner.lua tests/test_banner.lua
git commit -m "Add ribbon banner for match flash messages"
```

---

### Task 8: Character portrait/avatar and confetti

**Files:**
- Modify: `ui/character.lua` (append before `return Character`)
- Create: `ui/match/confetti.lua`

These are LÖVE-only helpers. They are syntax-checked here and verified visually in Task 11 (portrait, avatar) and Task 13 (confetti).

- [ ] **Step 1: Append to `ui/character.lua`** (immediately above `return Character`)

```lua
-- ── Arcade match UI ───────────────────────────────────────────────────────────
-- Source-pixel regions in the 1408×768 character art.
local FACE    = { x = 490, y = 60, size = 320 }   -- square around the face (round avatar)
local BODY_CX = 585                               -- horizontal centre of the body (portrait crop)

-- Bottom-left portrait: art scaled to height h and cropped (quad, no scissor) to width w.
local _quads = {}
function Character.drawPortrait(x, y, w, h)
    if not loaded then return end
    local img = imgs[state] or imgs.thinking
    local iw, ih = img:getDimensions()
    local s = h / ih
    local srcW = math.min(iw, w / s)
    local srcX = math.max(0, math.min(iw - srcW, BODY_CX - srcW / 2))
    local key = math.floor(srcX) .. ":" .. math.floor(srcW) .. ":" .. iw
    local q = _quads[key]
    if not q then
        q = love.graphics.newQuad(srcX, 0, srcW, ih, iw, ih)
        _quads[key] = q
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, q, x, y + bounceY * 0.6, 0, s, s)
end

-- Round face avatar (top bar): textured unit-circle fan mesh, cached per image.
local _avatarMeshes = {}
function Character.drawAvatar(cx, cy, r)
    if not loaded then return end
    local img = imgs[state] or imgs.thinking
    local mesh = _avatarMeshes[img]
    if not mesh then
        local iw, ih = img:getDimensions()
        local fcx, fcy, fr = FACE.x + FACE.size / 2, FACE.y + FACE.size / 2, FACE.size / 2
        local verts = { { 0, 0, fcx / iw, fcy / ih, 1, 1, 1, 1 } }
        local seg = 40
        for i = 0, seg do
            local a = i / seg * math.pi * 2
            local ux, uy = math.cos(a), math.sin(a)
            verts[#verts + 1] = { ux, uy, (fcx + ux * fr) / iw, (fcy + uy * fr) / ih, 1, 1, 1, 1 }
        end
        mesh = love.graphics.newMesh(verts, "fan", "static")
        mesh:setTexture(img)
        _avatarMeshes[img] = mesh
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mesh, cx, cy, 0, r, r)
end
```

- [ ] **Step 2: Create `ui/match/confetti.lua`**

```lua
-- Multicolor confetti bursts (goal / LP damage). One particle system per color,
-- since a ParticleSystem's colors are shared by all its particles.
local Theme = require("ui.theme")

local Confetti = {}

local COLORS = { "ffd23a", "ff5ec8", "4fb8ff", "7dff8a", "ff7a59", "ffffff" }
local systems = nil

local function build()
    systems = {}
    local tex = love.graphics.newCanvas(8, 4)
    love.graphics.push("all")
    love.graphics.setCanvas(tex)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setCanvas()
    love.graphics.pop()
    for _, h in ipairs(COLORS) do
        local c = Theme.hex(h)
        local ps = love.graphics.newParticleSystem(tex, 60)
        ps:setParticleLifetime(1.0, 1.8)
        ps:setEmissionRate(0)
        ps:setDirection(-math.pi / 2)
        ps:setSpread(math.pi * 0.9)
        ps:setSpeed(260, 520)
        ps:setLinearAcceleration(0, 520, 0, 620)
        ps:setLinearDamping(0.8)
        ps:setSpin(-10, 10)
        ps:setRotation(0, math.pi * 2)
        ps:setSizes(1.2, 1.0)
        ps:setColors(c[1], c[2], c[3], 1, c[1], c[2], c[3], 1, c[1], c[2], c[3], 0)
        systems[#systems + 1] = ps
    end
end

-- Call from update (not while drawing): builds its texture on first use.
function Confetti.burst(x, y, n)
    if not systems then build() end
    local each = math.ceil((n or 60) / #systems)
    for _, ps in ipairs(systems) do
        ps:setPosition(x, y)
        ps:emit(each)
    end
end

function Confetti.update(dt)
    if not systems then return end
    for _, ps in ipairs(systems) do ps:update(dt) end
end

function Confetti.draw()
    if not systems then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, ps in ipairs(systems) do love.graphics.draw(ps) end
end

return Confetti
```

- [ ] **Step 3: Syntax check and tests**

Run: `luac -p ui/character.lua ui/match/confetti.lua && lua tests/run.lua`
Expected: no `luac` output; `78 passed, 0 failed`.

- [ ] **Step 4: Snapshot (nothing uses the new code yet — confirm nothing broke)**

Run: `tools/snapshot/snap.sh match`
Expected: PNGs listed, no Lua error.

- [ ] **Step 5: Commit**

```bash
git add ui/character.lua ui/match/confetti.lua
git commit -m "Add character portrait/avatar crops and confetti bursts"
```

---

### Task 9: Top bar module

**Files:**
- Create: `ui/match/topbar.lua`

Not wired in yet (Task 11 wires it and verifies it with snapshots).

- [ ] **Step 1: Create `ui/match/topbar.lua`**

```lua
-- Match top bar (y 0–80): avatars, draining LP bars, halves pips, opponent deck count,
-- phase pill, turn chip and the pause / music / log icon buttons.
-- Clicks are mapped by Layout.buttonAt; this module only draws and animates.
local Theme     = require("ui.theme")
local Fonts     = require("ui.fonts")
local Draw      = require("ui.kit.draw")
local Icons     = require("ui.kit.icons")
local Button    = require("ui.kit.button")
local Layout    = require("ui.match.layout")
local LPBar     = require("ui.match.lpbar")
local Character = require("ui.character")
local Audio     = require("ui.audio")
local C         = require("engine.constants")

local TopBar = {}

local bars, buttons = nil, nil
local ICON_IDS = { "pause", "music", "log" }

local PHASE_COLOR = {
    draw    = Theme.grad.def[2],
    summon  = Theme.grad.bonus[2],
    attack  = Theme.grad.atk[2],
    ["end"] = Theme.typeGrad.trap[2],
}
local OPP_CHIP = { Theme.hex("d7dcea"), Theme.hex("a3abc4") }

function TopBar.reset(match)
    local max = C.MATCH.STARTING_LP
    bars = {
        player   = LPBar.new(match.players.player.lp, max),
        opponent = LPBar.new(match.players.opponent.lp, max),
    }
    buttons = {}
    for _, id in ipairs(ICON_IDS) do
        local r = Layout.top[id]
        buttons[id] = Button.new({ id = id, variant = "icon", x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

function TopBar.update(dt, match, mx, my)
    if not bars then TopBar.reset(match) end
    bars.player:set(match.players.player.lp)
    bars.opponent:set(match.players.opponent.lp)
    bars.player:update(dt)
    bars.opponent:update(dt)
    local down = love.mouse.isDown(1)
    for _, id in ipairs(ICON_IDS) do buttons[id]:update(dt, mx or -1, my or -1, down) end
end

local function avatarFrame(a, fill)
    Draw.setColor(Theme.ink);   love.graphics.circle("fill", a.cx, a.cy + 4, a.r + 3, 40)
    Draw.setColor(Theme.white); love.graphics.circle("fill", a.cx, a.cy, a.r + 3, 40)
    Draw.setColor(fill);        love.graphics.circle("fill", a.cx, a.cy, a.r, 40)
end

-- Halves-won pips (⚽ when won). rightAligned: p.x is the right edge.
local function pips(p, won, rightAligned)
    local n = math.max(2, won)
    for i = 1, n do
        local off = (i - 1) * (p.size + p.gap) + p.size / 2
        local cx = rightAligned and (p.x - off) or (p.x + off)
        local cy = p.y + p.size / 2
        if i <= won then
            Draw.setColor(Theme.ink);   love.graphics.circle("fill", cx, cy + 2, p.size / 2 + 1, 24)
            Draw.setColor(Theme.white); love.graphics.circle("fill", cx, cy, p.size / 2 + 1, 24)
            Icons.draw("soccer-ball", cx, cy, p.size - 2, Theme.inkText, 0)
        else
            love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35)
            love.graphics.circle("fill", cx, cy, p.size / 2, 24)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, p.size / 2, 24)
            love.graphics.setLineWidth(1)
        end
    end
end

local function phasePill(match)
    local r = Layout.top.phasePill
    Draw.sticker(r.x, r.y, r.w, r.h, { r = r.h / 2, fill = Theme.white, border = 3, shadow = 4 })
    local half   = match.half == "extra" and "EXTRA TIME" or ("HALF " .. tostring(match.half))
    local prefix = half .. " · TURN " .. tostring(match.turn) .. " · "
    local word   = string.upper(match.phase or "")
    local font   = Fonts.get(18)
    local total  = font:getWidth(prefix) + font:getWidth(word)
    local x = math.floor(r.x + (r.w - total) / 2)
    local y = math.floor(r.y + (r.h - font:getHeight()) / 2)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    Draw.setColor(Theme.inkText)
    love.graphics.print(prefix, x, y)
    Draw.setColor(PHASE_COLOR[match.phase] or Theme.inkText)
    love.graphics.print(word, x + font:getWidth(prefix), y)
    love.graphics.setFont(prev)
end

local function turnChip(match)
    local c = Layout.top.turnChip
    if match.activePlayer == "player" then
        Draw.pill(c.x, c.y, c.w, c.h, "YOUR TURN", {
            fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 15 })
    else
        Draw.pill(c.x, c.y, c.w, c.h, "OPP TURN", { fill = OPP_CHIP, textColor = Theme.inkText, size = 15 })
    end
end

-- White glyphs drawn on top of the icon buttons (follow the button's lift).
local function glyph(id, b)
    local cx, cy = b.x + b.w / 2, b.y + b.lift + b.h / 2
    love.graphics.setColor(1, 1, 1, 1)
    if id == "pause" then
        love.graphics.rectangle("fill", cx - 8, cy - 9, 6, 18, 2, 2)
        love.graphics.rectangle("fill", cx + 2, cy - 9, 6, 18, 2, 2)
    elseif id == "music" then
        love.graphics.circle("fill", cx - 4, cy + 6, 5, 16)
        love.graphics.rectangle("fill", cx - 2, cy - 10, 3, 16)
        love.graphics.polygon("fill", cx + 1, cy - 10, cx + 8, cy - 6, cx + 1, cy - 3)
        if Audio.isMuted() then
            Draw.setColor(Theme.grad.atk[2])
            love.graphics.setLineWidth(4)
            love.graphics.line(b.x + 7, b.y + b.lift + 7, b.x + b.w - 7, b.y + b.lift + b.h - 7)
            love.graphics.setLineWidth(1)
        end
    else
        for i = -1, 1 do
            love.graphics.rectangle("fill", cx - 9, cy + i * 7 - 1.5, 18, 3, 1, 1)
        end
    end
end

function TopBar.draw(match)
    if not bars then TopBar.reset(match) end
    local T = Layout.top
    local p, o = match.players.player, match.players.opponent

    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.25)
    love.graphics.rectangle("fill", T.bar.x, T.bar.y, T.bar.w, T.bar.h)

    avatarFrame(T.youAvatar, Theme.bg.top)
    Character.drawAvatar(T.youAvatar.cx, T.youAvatar.cy, T.youAvatar.r)
    avatarFrame(T.oppAvatar, Theme.grad.lpOpp[2])
    Icons.draw("soccer-kick", T.oppAvatar.cx, T.oppAvatar.cy, T.oppAvatar.r * 1.3, Theme.white)

    LPBar.draw(bars.player,   T.youBar, Theme.grad.lpYou, "YOU · " .. bars.player.shown, false)
    LPBar.draw(bars.opponent, T.oppBar, Theme.grad.lpOpp, "OPP · " .. bars.opponent.shown, true)
    pips(T.youPips, p.halvesWon or 0, false)
    pips(T.oppPips, o.halvesWon or 0, true)
    Draw.pill(T.oppDeck.x, T.oppDeck.y, T.oppDeck.w, T.oppDeck.h, "DECK " .. #o.deck, {
        fill = Theme.white, textColor = Theme.inkText, size = 13, shadow = 2 })

    phasePill(match)
    turnChip(match)
    for _, id in ipairs(ICON_IDS) do
        buttons[id]:draw()
        glyph(id, buttons[id])
    end
end

return TopBar
```

- [ ] **Step 2: Syntax check and tests**

Run: `luac -p ui/match/topbar.lua && lua tests/run.lua`
Expected: no `luac` output; `78 passed, 0 failed`.

- [ ] **Step 3: Commit**

```bash
git add ui/match/topbar.lua
git commit -m "Add match top bar module"
```

---

### Task 10: Bottom bar module and star primitive

**Files:**
- Modify: `ui/kit/draw.lua` (add `Draw.starPoints`, `Draw.star` above `return Draw`)
- Modify: `tests/test_draw.lua` (append one test)
- Create: `ui/match/bottombar.lua`

- [ ] **Step 1: Append the failing test to `tests/test_draw.lua`**

```lua
T.test("starPoints has 10 points, the first at the top tip", function()
    local p = Draw.starPoints(50, 60, 20)
    T.eq(#p, 20)
    T.near(p[1], 50); T.near(p[2], 40)
    T.near(math.sqrt((p[3] - 50) ^ 2 + (p[4] - 60) ^ 2), 9)   -- inner radius 0.45 r
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  starPoints has 10 points...` (`attempt to call a nil value (field 'starPoints')`); exit code 1.

- [ ] **Step 3: Add to `ui/kit/draw.lua`** directly above `return Draw`:

```lua
-- Five-point star outline {x1,y1,...}, first point at the top tip. Pure (unit-tested).
function Draw.starPoints(cx, cy, r)
    local p = {}
    for i = 0, 9 do
        local a = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and r or r * 0.45
        p[#p + 1] = cx + math.cos(a) * rad
        p[#p + 1] = cy + math.sin(a) * rad
    end
    return p
end

-- Star is concave: fill it as a fan of triangles around its centre.
local function fillStar(cx, cy, r)
    local p = Draw.starPoints(cx, cy, r)
    for i = 1, #p, 2 do
        local nx = i + 2
        if nx > #p then nx = 1 end
        love.graphics.polygon("fill", cx, cy, p[i], p[i + 1], p[nx], p[nx + 1])
    end
end

-- Star with white outline + ink drop shadow (midfield crown, summons bonus).
function Draw.star(cx, cy, r, color, alphaMul)
    local sh = math.max(1, math.floor(r * 0.15))
    Draw.setColor(Theme.ink, alphaMul);   fillStar(cx, cy + sh, r + 2)
    Draw.setColor(Theme.white, alphaMul); fillStar(cx, cy, r + 2)
    Draw.setColor(color or Theme.highlight.selected, alphaMul); fillStar(cx, cy, r)
end
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua`
Expected: `79 passed, 0 failed`

- [ ] **Step 5: Create `ui/match/bottombar.lua`**

```lua
-- Match bottom area (y 540–800) except the hand: portrait, deck pile, toast stack,
-- SUMMONS pill, ATTACK/DEFENSE toggle, START ATTACK / END TURN and the hint line.
-- Clicks are mapped by Layout.buttonAt; this module only draws and animates.
local Theme     = require("ui.theme")
local Draw      = require("ui.kit.draw")
local Button    = require("ui.kit.button")
local Card      = require("ui.card")
local Layout    = require("ui.match.layout")
local Stats     = require("ui.match.stats")
local Character = require("ui.character")

local BottomBar = {}

local buttons = nil
local PORTRAIT_FILL = { Theme.hex("8fc2ff"), Theme.hex("5b63f0") }

function BottomBar.reset()
    local B = Layout.bottom
    buttons = {
        startAttack = Button.new({ id = "startAttack", label = "START ATTACK", variant = "go",
            x = B.startAttack.x, y = B.startAttack.y, w = B.startAttack.w, h = B.startAttack.h, fontSize = 24 }),
        endTurn = Button.new({ id = "endTurn", label = "END TURN", variant = "primary",
            x = B.endTurn.x, y = B.endTurn.y, w = B.endTurn.w, h = B.endTurn.h, fontSize = 32 }),
    }
end

function BottomBar.update(dt, match, mx, my)
    if not buttons then BottomBar.reset() end
    local myTurn = match.activePlayer == "player" and not match.winner
    buttons.endTurn.enabled     = myTurn
    buttons.startAttack.enabled = myTurn and match.phase == "summon"
    local down = love.mouse.isDown(1)
    buttons.endTurn:update(dt, mx or -1, my or -1, down)
    buttons.startAttack:update(dt, mx or -1, my or -1, down)
end

local function drawPortrait()
    local r = Layout.bottom.portrait
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 18, fill = PORTRAIT_FILL, border = 4, shadow = 5 })
    Character.drawPortrait(r.x + 4, r.y + 4, r.w - 8, r.h - 8)
end

local function drawDeck(count)
    local d, c = Layout.bottom.deck, Layout.bottom.deckCount
    if count > 1 then Card.drawBack(d.x + 5, d.y - 5, d.w, d.h) end
    if count > 0 then
        Card.drawBack(d.x, d.y, d.w, d.h)
    else
        Draw.roundedFill(d.x, d.y, d.w, d.h, 10, { 1, 1, 1, 0.15 })
    end
    Draw.text("DECK", c.x, c.y - 20, c.w, "center", { size = 14, shadowY = 2 })
    Draw.pill(c.x, c.y, c.w, c.h, tostring(count), { fill = Theme.white, textColor = Theme.inkText, size = 18 })
end

local function drawSummons(match)
    local r = Layout.bottom.summons
    local used, max, bonus = Stats.summons(match)
    Draw.pill(r.x, r.y, r.w, r.h, "SUMMONS " .. used .. " / " .. max, {
        fill = bonus and Theme.grad.bonus or Theme.white,
        textColor = bonus and Theme.white or Theme.inkText, size = 18,
    })
    if bonus then Draw.star(r.x + r.w - 22, r.y + r.h / 2, 11, Theme.highlight.selected) end
end

local function drawToggle(mode)
    local r = Layout.bottom.toggle
    Draw.sticker(r.x, r.y, r.w, r.h, {
        r = r.h / 2, fill = { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.55 }, border = 3, shadow = 4,
    })
    for _, m in ipairs({ "attack", "defense" }) do
        local h = Layout.toggleHalf(m)
        local active = mode == m
        if active then
            Draw.roundedFill(h.x + 4, h.y + 4, h.w - 8, h.h - 8, (h.h - 8) / 2,
                m == "attack" and Theme.grad.atk or Theme.grad.def, "v")
        end
        Draw.text(m == "attack" and "ATTACK" or "DEFENSE", h.x, h.y + (h.h - 18) / 2 - 2, h.w, "center", {
            size = 18, color = { 1, 1, 1, active and 1 or 0.55 }, shadowY = active and 2 or 0,
        })
    end
end

-- st = { mode = "attack"|"defense", toasts = Toasts instance, hint = string }
function BottomBar.draw(match, st)
    if not buttons then BottomBar.reset() end
    drawPortrait()
    drawDeck(#match.players.player.deck)
    if st.toasts then st.toasts:draw() end
    drawSummons(match)
    drawToggle(st.mode)
    if match.phase == "summon" and match.activePlayer == "player" then buttons.startAttack:draw() end
    buttons.endTurn:draw()
    if st.hint and st.hint ~= "" then
        local h = Layout.bottom.hint
        Draw.text(st.hint, h.x, h.y, h.w, "center", {
            size = 12, body = true, color = Theme.white, shadowY = 1, fit = true, minSize = 9,
        })
    end
end

return BottomBar
```

- [ ] **Step 6: Syntax check and tests**

Run: `luac -p ui/match/bottombar.lua ui/kit/draw.lua && lua tests/run.lua`
Expected: no `luac` output; `79 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add ui/kit/draw.lua tests/test_draw.lua ui/match/bottombar.lua
git commit -m "Add star primitive and match bottom bar module"
```

---

### Task 11: Switch the match screen to the landscape layout

**Files:**
- Rewrite: `ui/pitch.lua`, `ui/hand.lua`, `main.lua`
- Modify: `scenes/match.lua` (requires/state, `Match.enter`, top of `Match.update`, `Match.draw`, `Match.drawTopBar`/`Match.drawHint` → `Match.hintText`, input, helpers)
- Delete: `ui/hud.lua`, `ui/card_detail.lua`, `ui/log.lua`
- Modify: `tools/snapshot/scenarios.lua`

This is the one big switch. After it the game plays entirely in the new layout.

- [ ] **Step 1: Replace `ui/pitch.lua` entirely**

```lua
-- Landscape pitch: you on the left (GK · DEF×2 · MID · STR×2), opponent mirrored right.
-- Pitch.draw(match, st, anims) returns hitboxes { x, y, w, h, slotType, slotIndex, owner }
-- (card slots for both sides + your own trap slots).
--   st    = { highlightedSlots, attackTargetSlots, selectedAttackerSlot, phase }
--   anims = { hidden = { [slotKey] = true }, pop = { [slotKey] = { sx, sy } } }
local Theme  = require("ui.theme")
local Card   = require("ui.card")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")
local Stats  = require("ui.match.stats")

local Pitch = {}

local GRASS_A   = Theme.hex("46c460")
local GRASS_B   = Theme.hex("4fd06a")
local LINE      = { 1, 1, 1, 0.85 }
local TRAP_TINT = Theme.typeGrad.trap[1]
local LABEL     = { keeper = "GK", defender = "DEF", midfielder = "MID", striker = "STR" }

function Pitch.slotKey(owner, slotType, slotIndex)
    return owner .. ":" .. slotType .. ":" .. tostring(slotIndex)
end

local function listHas(list, owner, slotType, slotIndex)
    for _, s in ipairs(list or {}) do
        if s.owner == owner and s.slotType == slotType and s.slotIndex == slotIndex then return true end
    end
    return false
end

local function pulse(speed) return 0.5 + 0.5 * math.sin(love.timer.getTime() * (speed or 6)) end

local function cardIn(pitch, slotType, idx)
    if slotType == "keeper"     then return pitch.keeper end
    if slotType == "midfielder" then return pitch.midfielder end
    if slotType == "defender"   then return pitch.defenders[idx] end
    if slotType == "striker"    then return pitch.strikers[idx] end
    if slotType == "trap"       then return pitch.traps[idx] end
    return nil
end

-- Dashed outline following a rounded rect (dash 8, gap 6).
local function dashedRounded(x, y, w, h, r, color, alpha)
    local pts = Draw.roundedRectPoints(x, y, w, h, r, 4)
    pts[#pts + 1] = pts[1]; pts[#pts + 1] = pts[2]
    Draw.setColor(color, alpha)
    love.graphics.setLineWidth(2)
    local on, left = true, 8
    for i = 1, #pts - 2, 2 do
        local x1, y1, x2, y2 = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        local pos = 0
        while pos < len do
            local step = math.min(left, len - pos)
            if on then
                local a, b = pos / len, (pos + step) / len
                love.graphics.line(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)
            end
            pos, left = pos + step, left - step
            if left <= 0 then
                on = not on
                left = on and 8 or 6
            end
        end
    end
    love.graphics.setLineWidth(1)
end

local function drawGoals(P)
    local cy = P.y + P.h / 2
    Draw.sticker(P.x - 14, cy - 50, 22, 100, { r = 5, fill = Theme.white, border = 0, shadow = 3 })
    Draw.sticker(P.x + P.w - 8, cy - 50, 22, 100, { r = 5, fill = Theme.white, border = 0, shadow = 3 })
end

local function drawGrass(P)
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 22, fill = GRASS_A, border = 4, shadow = 6 })
    local ix, iy, iw, ih = P.x + 4, P.y + 4, P.w - 8, P.h - 8
    local n = 17                       -- first and last stripes are base colour (rounded corners)
    local sw = iw / n
    Draw.setColor(GRASS_B)
    for i = 1, n - 2, 2 do love.graphics.rectangle("fill", ix + i * sw, iy, sw, ih) end
end

local function drawMarkings(P)
    local cx, cy = Layout.midX, P.y + P.h / 2
    local x0, x1 = P.x + 4, P.x + P.w - 4
    Draw.setColor(LINE)
    love.graphics.setLineWidth(4)
    love.graphics.line(cx, P.y + 4, cx, P.y + P.h - 4)
    love.graphics.circle("line", cx, cy, 70, 48)
    love.graphics.circle("fill", cx, cy, 6, 16)
    for _, side in ipairs({ { x0, 1 }, { x1, -1 } }) do
        local gx, dir = side[1], side[2]
        local bx, gax = gx + dir * 196, gx + dir * 70
        love.graphics.line(gx, cy - 150, bx, cy - 150, bx, cy + 150, gx, cy + 150)   -- penalty box
        love.graphics.line(gx, cy - 75, gax, cy - 75, gax, cy + 75, gx, cy + 75)     -- goal area
        love.graphics.circle("fill", gx + dir * 140, cy, 4, 12)                       -- penalty spot
    end
    love.graphics.setLineWidth(1)
end

-- style: "valid" (pulsing white) | "target" (red) | nil
local function drawEmpty(r, label, style, isTrap)
    local rad  = r.w < 80 and 9 or 14
    local tint = isTrap and TRAP_TINT or Theme.white
    Draw.roundedFill(r.x, r.y, r.w, r.h, rad, { tint[1], tint[2], tint[3], 0.16 })
    local a = 0.55
    if style == "valid" then
        local p = pulse(6)
        Draw.glow(r.x, r.y, r.w, r.h, rad, Theme.highlight.valid, 0.5 + 0.6 * p)
        a = 0.7 + 0.3 * p
    elseif style == "target" then
        Draw.glow(r.x, r.y, r.w, r.h, rad, Theme.highlight.target, 0.6 + 0.6 * pulse(5))
        Draw.ring(r.x, r.y, r.w, r.h, rad, Theme.highlight.target, 3)
    end
    dashedRounded(r.x + 3, r.y + 3, r.w - 6, r.h - 6, rad - 2, tint, a)
    local small = r.w < 80
    Draw.text(label, r.x, r.y + r.h / 2 - (small and 7 or 11), r.w, "center", {
        size = small and 12 or 20, color = { 1, 1, 1, a },
    })
end

local function drawOccupied(pitched, r, owner, slotType, slotIndex, st, pitch, pop, highlight)
    local sa = st.selectedAttackerSlot
    local opts = {
        w = r.w, h = r.h, pitch = pitch,
        faceDown = (owner == "opponent") and (slotType == "trap" or pitched.mode == "defense"),
        canFlip  = owner == "player" and slotType ~= "trap" and st.phase == "summon"
                   and pitched.mode == "defense" and not pitched.summonedThisTurn and not pitched.modeChanged,
        selected = owner == "player" and sa ~= nil and sa.type == slotType and sa.index == slotIndex,
        target   = sa ~= nil and listHas(st.attackTargetSlots, owner, slotType, slotIndex),
    }
    if pop then
        local px, py = r.x + r.w / 2, r.y + r.h
        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.scale(pop.sx, pop.sy)
        love.graphics.translate(-px, -py)
    end
    if highlight then Draw.glow(r.x, r.y, r.w, r.h, 14, Theme.highlight.valid, 0.5 + 0.6 * pulse(6)) end
    Card.drawPitched(pitched, r.x, r.y, opts)
    if pop then love.graphics.pop() end
end

function Pitch.draw(match, st, anims)
    if not match then return {} end
    st = st or {}
    anims = anims or {}
    local hidden, pops = anims.hidden or {}, anims.pop or {}
    local P = Layout.pitch

    drawGoals(P)
    drawGrass(P)
    drawMarkings(P)

    local crown = Stats.crownOwner(match)
    local hitboxes = {}

    for _, s in ipairs(Layout.slots()) do
        local pitch = match.players[s.owner].pitch
        local card  = cardIn(pitch, s.slotType, s.slotIndex)
        local key   = Pitch.slotKey(s.owner, s.slotType, s.slotIndex)
        local valid  = listHas(st.highlightedSlots, s.owner, s.slotType, s.slotIndex)
        local target = st.selectedAttackerSlot ~= nil and listHas(st.attackTargetSlots, s.owner, s.slotType, s.slotIndex)
        if card and not hidden[key] then
            drawOccupied(card, s, s.owner, s.slotType, s.slotIndex, st, pitch, pops[key], valid)
            if crown == s.owner and s.slotType == "midfielder" then
                Draw.star(s.x + s.w / 2, s.y - 26, 15, Theme.highlight.selected)
            end
        else
            drawEmpty(s, LABEL[s.slotType], target and "target" or (valid and "valid" or nil), false)
        end
        hitboxes[#hitboxes + 1] = { x = s.x, y = s.y, w = s.w, h = s.h,
            slotType = s.slotType, slotIndex = s.slotIndex, owner = s.owner }
    end

    for _, s in ipairs(Layout.trapSlots()) do
        local card  = match.players[s.owner].pitch.traps[s.slotIndex]
        local key   = Pitch.slotKey(s.owner, "trap", s.slotIndex)
        local valid = listHas(st.highlightedSlots, s.owner, "trap", s.slotIndex)
        if card and not hidden[key] then
            drawOccupied(card, s, s.owner, "trap", s.slotIndex, st, nil, pops[key], false)
        else
            drawEmpty(s, "TRAP", valid and "valid" or nil, true)
        end
        if s.owner == "player" then     -- only your own trap zone is clickable
            hitboxes[#hitboxes + 1] = { x = s.x, y = s.y, w = s.w, h = s.h,
                slotType = "trap", slotIndex = s.slotIndex, owner = s.owner }
        end
    end

    return hitboxes
end

return Pitch
```

- [ ] **Step 2: Replace `ui/hand.lua` entirely**

```lua
-- Player hand: fanned, rotated hand-size cards with Dock magnification.
-- Card size never changes (scale/rotate transforms only) so card meshes stay cached.
-- Hand.draw returns a hit structure { cards, order, defs } for Hand.hit / Hand.rectOf.
local Card    = require("ui.card")
local HandFan = require("ui.match.handfan")
local Layout  = require("ui.match.layout")

local Hand = {}

function Hand.draw(hand, selectedCardId, mouseX, mouseY)
    local hb = { cards = {}, order = {}, defs = hand or {} }
    if not hand or #hand == 0 then return hb end
    local sel = nil
    for i, c in ipairs(hand) do
        if selectedCardId and c.id == selectedCardId then sel = i; break end
    end
    local cards, order = HandFan.layout(#hand, Layout.bottom.hand, mouseX, mouseY, sel)
    local W, H = HandFan.CARD_W, HandFan.CARD_H
    for _, i in ipairs(order) do
        local c = cards[i]
        love.graphics.push()
        love.graphics.translate(c.cx, c.by)
        love.graphics.rotate(c.angle)
        love.graphics.scale(c.scale, c.scale)
        Card.drawFace(hand[i], -W / 2, -H, W, H, { selected = (i == sel) })
        love.graphics.pop()
    end
    hb.cards, hb.order = cards, order
    return hb
end

-- cardDef, index, screen rect of the top-most hand card under (x, y); nil if none.
function Hand.hit(hb, x, y)
    if not hb or not hb.cards or #hb.cards == 0 then return nil end
    local i = HandFan.hit(hb.cards, hb.order, x, y)
    if not i then return nil end
    return hb.defs[i], i, HandFan.rect(hb.cards[i])
end

-- Screen rect of the first hand card with this id (animation origin), or nil.
function Hand.rectOf(hb, cardId)
    if not hb or not hb.defs then return nil end
    for i, d in ipairs(hb.defs) do
        if d.id == cardId and hb.cards[i] then return HandFan.rect(hb.cards[i]) end
    end
    return nil
end

return Hand
```

- [ ] **Step 3: `scenes/match.lua` — replace the requires and state block.** Replace everything from line 1 through `local AI_STEP_DELAY = 0.55` (currently lines 1–100) with:

```lua
local flux          = require("lib.flux")
local moonshine     = require("lib.moonshine")
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

-- Last pitched card clicked (kept for the existing input flow)
local selectedPitchedCard = nil

-- Goal/LP flash
local lpFlash  = { alpha = 0 }
local lpDealer = nil

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
local shimmers    = {}

-- Moonshine effects
local fxGoal   = nil
local fxCombat = nil

-- Particles
local goalParticles = nil

-- Toasts (log events) and ribbon banner (Match.flash)
local toasts = Toasts.new()
local banner = Banner.new()

-- Debug log panel
local debugLogOpen   = false
local debugLogScroll = 0  -- lines scrolled from bottom

-- AI state machine
local aiPlan        = nil
local aiActionIndex = 0
local aiTimer       = 0
local AI_STEP_DELAY = 0.55
```

- [ ] **Step 4: Replace `Match.enter` entirely**

```lua
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
    selectedPitchedCard = nil
    lpFlash.alpha       = 0
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
    shimmers            = {}
    debugLogOpen        = false
    debugLogScroll      = 0
    lastLogLen          = 0
    mouseX, mouseY      = -1, -1
    handMouseX, handMouseY = nil, nil
    toasts              = Toasts.new()
    banner              = Banner.new()
    Character.reset()
    TopBar.reset(store.match)
    BottomBar.reset()

    if not fxGoal then
        fxGoal   = moonshine(moonshine.effects.glow)
        fxCombat = moonshine(moonshine.effects.glow)
    end
    if not goalParticles then
        local img = love.graphics.newCanvas(4, 4)
        love.graphics.setCanvas(img)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, 4, 4)
        love.graphics.setCanvas()
        goalParticles = love.graphics.newParticleSystem(img, 120)
        goalParticles:setParticleLifetime(0.6, 1.4)
        goalParticles:setEmissionRate(0)
        goalParticles:setSpeed(80, 220)
        goalParticles:setLinearDamping(1.0)
        goalParticles:setSpread(math.pi * 2)
        goalParticles:setSizes(1.0, 0.4)
        goalParticles:setColors(1, 0.84, 0, 1,  1, 1, 1, 0.8,  1, 1, 1, 0)
    end
end
```

- [ ] **Step 5: Replace the top of `Match.update`.** Replace from `function Match.update(dt)` down to and including the `if flashTimer > 0 then ... end` block (everything before `if not activeCombat and #combatQueue > 0 then`) with:

```lua
function Match.update(dt)
    if not store or not store.match then return end
    local match = store.match

    if goalParticles then goalParticles:update(dt) end
    Character.update(dt, match.players.player.lp)
    toasts:update(dt)
    banner:update(dt)
    TopBar.update(dt, match, mouseX, mouseY)
    BottomBar.update(dt, match, mouseX, mouseY)

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

```

The rest of `Match.update` (from `if not activeCombat and #combatQueue > 0 then` to its `end`) is unchanged.

- [ ] **Step 6: Replace `Match.draw` entirely, and delete `Match.drawTopBar` and `Match.drawHint`.** Replace `Match.draw`, `Match.drawTopBar` and `Match.drawHint` (the three consecutive functions) with:

```lua
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

    -- Summon shimmer
    for _, sh in ipairs(shimmers) do
        local sw = 12
        love.graphics.setScissor(sh.x, sh.y, sh.w, sh.h)
        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.polygon("fill",
            sh.x + sh.shimX, sh.y,
            sh.x + sh.shimX + sw, sh.y,
            sh.x + sh.shimX + sw * 2, sh.y + sh.h,
            sh.x + sh.shimX + sw, sh.y + sh.h)
        love.graphics.setScissor()
    end

    -- Goal particles
    if goalParticles then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(goalParticles)
    end

    -- Card-draw animations
    for _, da in ipairs(drawAnims) do
        if da.alpha > 0 then
            local dw, dh = 44, 62
            local dx, dy = math.floor(da.x), math.floor(da.y)
            love.graphics.setColor(0, 0, 0, 0.45 * da.alpha)
            love.graphics.rectangle("fill", dx+3, dy+3, dw, dh, 5)
            love.graphics.setColor(0.08, 0.06, 0.18, da.alpha)
            love.graphics.rectangle("fill", dx, dy, dw, dh, 5)
            love.graphics.setColor(0.45, 0.30, 0.80, da.alpha * 0.90)
            love.graphics.setLineWidth(1.5)
            love.graphics.rectangle("line", dx, dy, dw, dh, 5)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.25, 0.18, 0.45, da.alpha * 0.55)
            love.graphics.line(dx+6, dy+6, dx+dw-6, dy+dh-6)
            love.graphics.line(dx+dw-6, dy+6, dx+6, dy+dh-6)
            love.graphics.setColor(0.55, 0.40, 0.90, da.alpha * 0.80)
            love.graphics.circle("fill", dx+dw/2, dy+dh/2, 4)
        end
    end

    -- Flying cards (summon)
    for _, fc in ipairs(flyingCards) do
        Card.drawPitched({
            definition = fc.cardDef, exhausted = false, mode = fc.mode or "attack",
            slotType   = (fc.cardDef.type == "trap") and "trap" or fc.cardDef.type,
        }, fc.x, fc.y, { w = fc.w, h = fc.h })
    end

    -- Flash banner
    banner:draw()

    -- LP damage flash
    if lpFlash.alpha > 0 then
        local r = lpDealer == "player" and 0.05 or 0.85
        local g = lpDealer == "player" and 0.85 or 0.05
        local b = 0.05
        local drawFlash = function()
            love.graphics.setColor(r, g, b, lpFlash.alpha * 0.28)
            love.graphics.rectangle("fill", 0, 0, W, H)
            Fonts.with(33, function()
                love.graphics.setColor(1, 1, 1, lpFlash.alpha)
                love.graphics.printf(
                    lpDealer == "player" and "LP DAMAGE DEALT!" or "LP DAMAGE TAKEN!",
                    0, H / 2 - 20, W, "center")
            end)
        end
        if fxGoal then fxGoal(drawFlash) else drawFlash() end
    end

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
```

- [ ] **Step 7: `Match.mousepressed` — buttons and hand clicks.** Replace from `local match = store and store.match` (just after the cover-prompt block) through the end of the `-- Hand card clicks` block (the `end` closing `if match.phase == "summon" or match.phase == "attack" then`) with:

```lua
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
```

- [ ] **Step 8: `Match.mousepressed` — summon placement.** Replace the whole `-- Summon: place card into slot` block (from `if match.phase == "summon" and selectedHandCard and slot.owner == "player" then` to its closing `end` after `return`) with:

```lua
            -- Summon: place card into slot
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
                    local fc = { cardDef = cardDefCopy, x = srcX, y = srcY, w = slot.w, h = slot.h, mode = mode }
                    flux.to(fc, 0.35, { x = slot.x, y = slot.y })
                        :ease("quadout")
                        :oncomplete(function()
                            for ii, c in ipairs(flyingCards) do
                                if c == fc then table.remove(flyingCards, ii); break end
                            end
                        end)
                    table.insert(flyingCards, fc)

                    local sh = { x = slot.x, y = slot.y, w = slot.w, h = slot.h, shimX = -slot.w }
                    flux.to(sh, 0.40, { shimX = slot.w * 1.5 }):ease("quadout")
                        :oncomplete(function()
                            for ii, s in ipairs(shimmers) do
                                if s == sh then table.remove(shimmers, ii); break end
                            end
                        end)
                    table.insert(shimmers, sh)
                end
                selectedHandCard = nil
                return
            end
```

- [ ] **Step 9: Keyboard, mouse-move, helpers.**

In `Match.keypressed` replace:

```lua
    if key == "tab" then HUD.debugAIHand = not HUD.debugAIHand; return nil end
```

with:

```lua
    if key == "tab" then aiHandDebug = not aiHandDebug; return nil end
```

Replace `Match.mousemoved` entirely:

```lua
function Match.mousemoved(x, y)
    mouseX, mouseY = x, y
    if activeCombat then return end
    handMouseX, handMouseY = x, y
end
```

In `Match.onLPDamage` replace:

```lua
        local L  = Theme.layout
        local cx = L.pitchX + L.pitchW / 2
        local cy = love.graphics.getHeight() / 2
```

with:

```lua
        local cx = Layout.midX
        local cy = Layout.pitch.y + Layout.pitch.h / 2
```

Replace `Match.flash` entirely:

```lua
function Match.flash(msg, kind)
    banner:show(string.upper(tostring(msg)), kind or "error")
end
```

In `Match.drawAIHandDebug` replace `local W   = Theme.layout.pitchW` with `local W   = Layout.W`.

Add directly above `function Match.inRect`:

```lua
-- Dev hook for tools/snapshot scenarios.
function Match.debugStore() return store end
```

- [ ] **Step 10: Replace `main.lua` entirely** (vignette removed, camera shake kept)

```lua
-- Football TCG — main.lua
math.randomseed(os.time())

local flux      = require("lib.flux")
local Theme     = require("ui.theme")
local Home      = require("scenes.home")
local Match     = require("scenes.match")
local Store     = require("store.match")
local Decks     = require("data.presetDecks")
local Audio     = require("ui.audio")

local currentScene = "home"
local store        = Store.new()
local fonts        = {}
local camera       = { x = 0, y = 0 }
Match._camera      = camera

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function startMatch(deckKey)
    local playerData   = Decks[deckKey]
    local opponentData = Decks.tikitaka
    store:startMatch(playerData.cards, opponentData.cards)
    store.onUpdate = function(match)
        if match and match.log and #match.log > 0 then
            local last = match.log[#match.log]
            if last.type == "lp_damage" then
                camera.x = 6; flux.to(camera, 0.35, { x = 0 }):ease("elasticout")
            elseif last.type == "defender_destroy" then
                camera.x = 3; flux.to(camera, 0.20, { x = 0 }):ease("elasticout")
                Audio.play("destroy")
            end
        end
    end
    Match.enter(store, "medium")
    Audio.playMusic("assets/audio/music/theme_match.ogg", 0.45)
    currentScene = "match"
end

local function goHome()
    Home.reset(); currentScene = "home"
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

-- ── Love2D callbacks ──────────────────────────────────────────────────────────

function love.load()
    local Fonts = require("ui.fonts")
    fonts.tiny   = Fonts.get(9)
    fonts.small  = Fonts.get(11)
    fonts.normal = Fonts.get(16)
    fonts.large  = Fonts.get(22)
    fonts.title  = Fonts.get(33)
    love.graphics.setFont(fonts.normal)
    Audio.load()
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

function love.update(dt)
    flux.update(dt)
    if currentScene == "match" then Match.update(dt) end
end

function love.draw()
    love.graphics.clear(Theme.ink[1], Theme.ink[2], Theme.ink[3], 1)
    love.graphics.push()
    love.graphics.translate(math.floor(camera.x), math.floor(camera.y))
    if currentScene == "home" then
        Home.draw()
    elseif currentScene == "match" then
        Match.draw()
    end
    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    local cx = x - math.floor(camera.x)
    local cy = y - math.floor(camera.y)
    if currentScene == "home" then
        local action, deckKey = Home.mousepressed(cx, cy, button)
        if action == "start" then startMatch(deckKey) end
    elseif currentScene == "match" then
        if Match.mousepressed(cx, cy, button) == "home" then goHome() end
    end
end

function love.mousemoved(x, y)
    if currentScene == "match" then
        Match.mousemoved(x - math.floor(camera.x), y - math.floor(camera.y))
    end
end

function love.wheelmoved(x, y)
    if currentScene == "home" then Home.wheelmoved(x, y)
    elseif currentScene == "match" then Match.wheelmoved(x, y) end
end

function love.keypressed(key)
    if currentScene == "home" then
        local action, deckKey = Home.keypressed(key)
        if action == "start" then startMatch(deckKey) end
    elseif currentScene == "match" then
        local action = Match.keypressed(key)
        if action == "home" or action == "restart" then goHome() end
    end
end
```

- [ ] **Step 11: Delete the replaced panels and check for leftovers**

```bash
git rm -q ui/hud.lua ui/card_detail.lua ui/log.lua
grep -rn 'ui\.hud\|ui\.card_detail\|ui\.log"\|HUD\.\|CardDetail\|hoveredCard\|handHitboxes\|flashMsg\|flashTimer\|drawTopBar\|drawHint\|fxScene' --include='*.lua' .
```

Expected: grep prints nothing.

- [ ] **Step 12: Syntax check and tests**

Run: `luac -p scenes/match.lua ui/pitch.lua ui/hand.lua main.lua && lua tests/run.lua`
Expected: no `luac` output; `79 passed, 0 failed`.

- [ ] **Step 13: Replace `tools/snapshot/scenarios.lua` entirely** (seeded match scenarios that drive the new layout)

```lua
-- Timed scripts for tools/snapshot/snap.sh. Each step: { seconds, function(ctx) ... end }.
-- ctx.snap(label) saves a screenshot; ctx.quit() exits. Every scenario must end with ctx.quit().
-- Match scenarios seed math.random so the dealt hands are identical on every run, and read
-- click positions from ui/match/layout.lua + ui/match/handfan.lua so they follow the layout.
local Layout  = require("ui.match.layout")
local HandFan = require("ui.match.handfan")

local S = {}

local function store() return require("scenes.match").debugStore() end
local function hand() return store().match.players.player.hand end
local function center(r) return r.x + r.w / 2, r.y + r.h / 2 end
local function move(x, y) love.mousemoved(x, y, 0, 0) end
local function press(x, y) love.mousepressed(x, y, 1) end
local function click(x, y) move(x, y); press(x, y) end

local function firstOf(types)
    for _, t in ipairs(types) do
        for _, c in ipairs(hand()) do
            if c.type == t then return c end
        end
    end
    return nil
end

-- Point 70px above the bottom of a hand card at rest (inside it despite rotation).
local function handPoint(card)
    local h = hand()
    for i, c in ipairs(h) do
        if c == card then
            local cards = HandFan.layout(#h, Layout.bottom.hand)
            return cards[i].cx, cards[i].by - 70
        end
    end
    return nil
end

local FIELD_SLOT = { striker = { "striker", 1 }, defender = { "defender", 1 }, midfielder = { "midfielder", 0 } }
local function fieldSlot(card)
    local s = card and FIELD_SLOT[card.type]
    return s and Layout.slot("player", s[1], s[2]) or nil
end

-- Unblock the AI: let attacks through, dismiss combat / trap-activation overlays.
local function advance()
    local st = store()
    if not st or not st.match then return end
    if st.coverWindow and st.match.activePlayer == "opponent" then
        for _, hb in ipairs(require("ui.cover_prompt").getHitboxes(st.coverWindow)) do
            if hb.type == "letthrough" then press(hb.x + hb.w / 2, hb.y + hb.h / 2); return end
        end
    end
    love.keypressed("space")
end

local function byTime(steps)
    table.sort(steps, function(a, b) return a[1] < b[1] end)
    return steps
end

S.home = {
    { 1.0, function(c) c.snap("deck") end },
    { 1.5, function(c) c.quit() end },
}

S.library = {
    { 0.5, function() love.mousepressed(640, 538, 1) end },  -- CARD LIBRARY button (scenes/home.lua)
    { 1.5, function(c) c.snap("grid") end },
    { 2.0, function(c) c.quit() end },
}

S.match = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, function() love.keypressed("return") end },       -- start with the first deck
    { 3.0, function(c) c.snap("start") end },
    { 9.0, function(c) c.snap("later") end },
    { 9.5, function(c) c.quit() end },
}

S.cards = {
    { 0.3, function() love.draw = require("tools.snapshot.card_gallery").draw end },
    { 1.0, function(c) c.snap("gallery") end },
    { 1.5, function(c) c.quit() end },
}

-- Summon a keeper + one field card, start the attack phase, select an attacker,
-- end the turn and let the AI play.
local picked = {}
S.summon = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  function() love.keypressed("return") end },
    { 1.5,  function()
        picked.keeper = firstOf({ "keeper" })
        picked.field  = firstOf({ "striker", "defender", "midfielder" })
        move(handPoint(picked.keeper))
    end },
    { 2.0,  function(c) c.snap("hover") end },
    { 2.1,  function() press(handPoint(picked.keeper)) end },
    { 2.3,  function() move(640, 300) end },
    { 2.6,  function(c) c.snap("selected") end },
    { 2.7,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 3.5,  function(c) c.snap("placed") end },
    { 3.6,  function() if picked.field then move(handPoint(picked.field)) end end },
    { 3.9,  function() if picked.field then press(handPoint(picked.field)) end end },
    { 4.1,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
    { 4.8,  function(c) c.snap("two") end },
    { 4.9,  function() click(center(Layout.bottom.startAttack)) end },
    { 5.2,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
    { 5.4,  function() move(640, 60) end },
    { 5.8,  function(c) c.snap("attack") end },
    { 5.9,  function() if picked.field then love.keypressed("escape") end end },
    { 6.0,  function() click(center(Layout.bottom.endTurn)) end },
    { 8.25, function(c) c.snap("aiturn") end },
    { 14.25, function(c) c.snap("myturn") end },
    { 14.5, function(c) c.quit() end },
}
for t = 6.5, 14.0, 0.5 do S.summon[#S.summon + 1] = { t, advance } end
byTime(S.summon)

return S
```

- [ ] **Step 14: Run the snapshots**

Run: `tools/snapshot/snap.sh home && tools/snapshot/snap.sh match && tools/snapshot/snap.sh summon`
Expected: PNGs listed (`home_deck`, `match_start`, `match_later`, `summon_hover`, `summon_selected`, `summon_placed`, `summon_two`, `summon_attack`, `summon_aiturn`, `summon_myturn`) and no Lua error on stderr.

- [ ] **Step 15: Review the PNGs with the Read tool.** For every item below, confirm it is visible:

- `match_start.png`:
  - **Background:** blue→violet gradient, no dark vignette, no left or right dark panels.
  - **Top bar:**
    - Round face avatar at the top-left; green bar "YOU · 4000"; 2 empty pips under it.
    - White pill "HALF 1 · TURN 1 · SUMMON" with SUMMON in green; yellow "YOUR TURN" chip under it.
    - 3 translucent icon buttons (pause bars, music note, list).
    - Red bar "OPP · 4000"; red avatar with kick icon; "DECK N" pill.
  - **Pitch:**
    - Rounded, striped green, white border, navy shadow.
    - Halfway line, centre circle, penalty boxes and goal areas at both ends, white goal posts poking out at both sides.
    - 12 dashed empty slots labelled GK / DEF / DEF / MID / STR / STR, mirrored.
    - 4 small purple dashed TRAP slots under each keeper.
  - **Bottom:**
    - Portrait sticker with the character.
    - Deck pile of card backs with a "DECK" count pill.
    - 5 hand cards fanned with slight rotation, centred at x ≈ 700.
    - White "SUMMONS 0 / 2" pill; ATTACK/DEFENSE toggle with ATTACK red-active; green START ATTACK; big yellow END TURN.
    - White hint line between the pitch and the hand.
- `summon_hover.png`: the keeper hand card is bigger, upright and lifted, with its neighbours pushed apart.
- `summon_selected.png`: the keeper hand card has a yellow ring and is lifted. Your empty slots glow and pulse white. The hint reads "Mode: ATTACK · Click an empty slot…".
- `summon_placed.png`: a keeper card sits in your GK slot (108×148) and "SUMMONS 1 / 2" is shown. The toast "You summoned a KEEPER" is in the toast stack.
- `summon_two.png`:
  - A second card is in its column and SUMMONS reads 2 / 2.
  - If it is a defender, the keeper's DEF badge shows a green `+300` tag.
  - If it is a midfielder, a ★ crown floats above it.
  - If no second card was placed, the seeded hand had no field player: change `math.randomseed(7)` in `S.summon` to `11` and re-run.
- `summon_attack.png`: the phase pill reads ATTACK (red). START ATTACK is hidden. Your attacker has a yellow ring and the opponent's target slots glow red.
- `summon_aiturn.png`: the chip reads "OPP TURN" (grey) and END TURN looks disabled (faded). Opponent cards appear on the right, face-down ones as navy backs. Toasts show opponent actions.
- `summon_myturn.png`: "YOUR TURN" again, turn counter advanced, one more card in the hand, deck count decreased.

If any item is missing or overlapping, fix the relevant module and re-run the snapshot before committing.

- [ ] **Step 16: Commit**

```bash
git add -A ui/pitch.lua ui/hand.lua scenes/match.lua main.lua tools/snapshot/scenarios.lua
git commit -m "Switch match screen to landscape arcade layout"
```

(`git rm` in Step 11 already staged the deletions.)

---

### Task 12: Card zoom on hover

**Files:**
- Modify: `scenes/match.lua`

- [ ] **Step 1: Requires and state.** Add after `local Banner = require("ui.match.banner")`:

```lua
local Hover         = require("ui.match.hover")
local Zoom          = require("ui.match.zoom")
```

Add after `local banner = Banner.new()`:

```lua
-- Card zoom (hover any card ~0.3s)
local hover    = Hover.new()
local zoomKey  = nil
local zoomAnim = { scale = 1 }
```

- [ ] **Step 2: Reset in `Match.enter`.** Add after the line `banner = Banner.new()` inside `Match.enter`:

```lua
    hover               = Hover.new()
    zoomKey             = nil
```

- [ ] **Step 3: Track hover in `Match.update`.** Add directly after `BottomBar.update(dt, match, mouseX, mouseY)`:

```lua
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
```

- [ ] **Step 4: Add `Match.hoverTarget`** directly above `function Match.hintText`:

```lua
-- Key + payload for the card under the mouse (nil when nothing zoomable).
-- Opponent face-down cards and traps are never zoomable (hidden information).
function Match.hoverTarget(match)
    if activeCombat or activeTrapActiv or scoutReveal or pauseOpen or libraryOpen or debugLogOpen
       or match.winner or store.coverWindow or store.trapWindow then
        return nil
    end
    local def, i, r = Hand.hit(handHit, mouseX, mouseY)
    if def then
        return "hand:" .. i .. ":" .. tostring(def.id), { cardDef = def, src = r }
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
```

- [ ] **Step 5: Draw the zoom.** In `Match.draw`, insert directly above `-- Flash banner`:

```lua
    -- Card zoom
    if zoomKey and hover.payload then
        local p = hover.payload
        Zoom.draw({ cardDef = p.cardDef, pitched = p.pitched, pitch = p.pitch, src = p.src, scale = zoomAnim.scale })
    end

```

- [ ] **Step 6: Syntax check and tests**

Run: `luac -p scenes/match.lua && lua tests/run.lua`
Expected: no `luac` output; `79 passed, 0 failed`.

- [ ] **Step 7: Snapshot**

Run: `tools/snapshot/snap.sh summon`
Expected: the same 7 PNGs, no Lua error.

- [ ] **Step 8: Review with the Read tool:**

- `summon_hover.png`:
  - A 300×410 zoomed keeper card appears to the LEFT of the hovered hand card, with a white info sticker (name, "KEEPER · RARITY", ability text) further left.
  - Both are fully on screen: the tag isn't cut at the top and the ATK/DEF badges aren't cut at the bottom.
- `summon_placed.png`: a zoom of the placed keeper appears to the RIGHT of the GK slot. The info sticker ends with a "Mode: ATTACK" line.
- `summon_selected.png`, `summon_attack.png`: no zoom (the mouse is on empty pitch / top bar).

- [ ] **Step 9: Commit**

```bash
git add scenes/match.lua
git commit -m "Add hover card zoom to the match screen"
```

---

### Task 13: Juice — LP banners, confetti, squash-pop summon, re-targeted draw animation

**Files:**
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`

- [ ] **Step 1: Requires.** Delete the line `local moonshine     = require("lib.moonshine")` and add after `local Zoom = require("ui.match.zoom")`:

```lua
local Tween         = require("ui.kit.tween")
local Confetti      = require("ui.match.confetti")
```

- [ ] **Step 2: State.** Delete these state lines (with their comment lines):

```lua
-- Goal/LP flash
local lpFlash  = { alpha = 0 }
local lpDealer = nil
```
```lua
local shimmers    = {}
```
```lua
-- Moonshine effects
local fxGoal   = nil
local fxCombat = nil

-- Particles
local goalParticles = nil
```

- [ ] **Step 3: `Match.enter`.** Delete the lines `lpFlash.alpha       = 0` and `shimmers            = {}`, and delete both blocks `if not fxGoal then ... end` and `if not goalParticles then ... end` at the end of `Match.enter`.

- [ ] **Step 4: `Match.update`.**

Replace `if goalParticles then goalParticles:update(dt) end` with:

```lua
    Confetti.update(dt)
```

In the combat clash `oncomplete`, replace:

```lua
                if activeCombat and activeCombat.damage and activeCombat.damage > 0 then
                    Match.onLPDamage(match.activePlayer)
                end
```

with:

```lua
                if activeCombat and activeCombat.damage and activeCombat.damage > 0 then
                    Match.onLPDamage(match.activePlayer, activeCombat.outcome == "damage")
                end
```

- [ ] **Step 5: `Match.draw`.**
  - Delete the whole `-- Summon shimmer` block (the `for _, sh in ipairs(shimmers)` loop).
  - Delete the whole `-- LP damage flash` block (`if lpFlash.alpha > 0 then ... end`).
  - Replace the `-- Goal particles` block with:

```lua
    -- Confetti
    Confetti.draw()
```

Replace the whole `-- Card-draw animations` block with:

```lua
    -- Card-draw animations (card back from the deck pile; scaled, never resized)
    local dk = Layout.bottom.deck
    for _, da in ipairs(drawAnims) do
        love.graphics.push()
        love.graphics.translate(da.x + dk.w / 2, da.y + dk.h / 2)
        love.graphics.scale(da.s, da.s)
        Card.drawBack(-dk.w / 2, -dk.h / 2, dk.w, dk.h)
        love.graphics.pop()
    end
```

- [ ] **Step 6: Squash-pop summon.** Replace the whole `-- Summon: place card into slot` block (as written in Task 11 Step 8) with:

```lua
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
```

- [ ] **Step 7: Replace `Match.onLPDamage` and `Match.spawnDrawAnim` entirely**

```lua
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
```

```lua
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
```

- [ ] **Step 8: Check for leftovers**

Run: `grep -n 'lpFlash\|lpDealer\|shimmers\|fxGoal\|fxCombat\|goalParticles\|moonshine\|Theme.layout' scenes/match.lua`
Expected: no output.

- [ ] **Step 9: Add the `juice` scenario.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Juice: LP drain + GOAL banner + confetti, midfield banner, draw animation, summon pop.
-- (Setting opponent LP directly is harness-only; it just feeds the LP bar.)
S.juice = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  function() love.keypressed("return") end },
    { 1.5,  function()
        store().match.players.opponent.lp = 3200
        require("scenes.match").onLPDamage("player", true)
    end },
    { 1.85, function(c) c.snap("drain") end },
    { 2.9,  function(c) c.snap("settled") end },
    { 3.0,  function() require("scenes.match").flash("MIDFIELD CONTROL +1 SUMMON", "good") end },
    { 3.4,  function(c) c.snap("banner") end },
    { 3.5,  function() require("scenes.match").spawnDrawAnim(true) end },
    { 3.7,  function(c) c.snap("drawanim") end },
    { 3.8,  function() press(handPoint(firstOf({ "keeper" }))) end },
    { 4.0,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 4.38, function(c) c.snap("pop") end },
    { 5.0,  function(c) c.quit() end },
}
```

- [ ] **Step 10: Syntax check, tests, snapshots**

Run: `luac -p scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && tools/snapshot/snap.sh juice && tools/snapshot/snap.sh summon`
Expected: no `luac` output; `79 passed, 0 failed`; `juice_drain`, `juice_settled`, `juice_banner`, `juice_drawanim`, `juice_pop` and the 7 `summon_*` PNGs listed; no Lua error.

- [ ] **Step 11: Review with the Read tool:**

- `juice_drain.png`:
  - The opponent LP bar is partially drained. Its red fill is shorter than a white trailing chunk.
  - The number reads between 3200 and 4000.
  - A green "GOAL!" ribbon is across the pitch middle.
  - Multicolor confetti is flying near the right goal.
- `juice_settled.png`: the opponent bar reads "OPP · 3200" and the white chunk is gone.
- `juice_banner.png`: a green "MIDFIELD CONTROL +1 SUMMON" ribbon.
- `juice_drawanim.png`: a card back, larger than the deck pile, is between the deck pile and the hand.
- `juice_pop.png`: the keeper in the GK slot is visibly squashed (wider and shorter, anchored at its bottom edge).
- `summon_*.png`: same checklist as Task 11/12 still holds, with no shimmer artifacts.

- [ ] **Step 12: Commit**

```bash
git add scenes/match.lua tools/snapshot/scenarios.lua
git commit -m "Add match juice: LP banners, confetti, summon pop, new draw animation"
```

---

### Task 14: Debug log and AI-hand sticker panels

**Files:**
- Create: `ui/match/debuglog.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`

- [ ] **Step 1: Create `ui/match/debuglog.lua`**

```lua
-- Full match log (log button / L) and AI-hand debug (TAB) as white sticker panels.
local Theme  = require("ui.theme")
local Fonts  = require("ui.fonts")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local DebugLog = {}

local ORDER = { "player", "ability", "name", "cardName", "slot", "slotType", "slotIndex", "outcome",
                "damage", "half", "winner", "turn", "reason", "unimplemented" }

local function fmtValue(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, vv in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(vv) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function fmtPayload(p)
    if not p then return "" end
    local parts, seen = {}, {}
    for _, k in ipairs(ORDER) do
        if p[k] ~= nil then
            parts[#parts + 1] = k .. "=" .. fmtValue(p[k])
            seen[k] = true
        end
    end
    for k, v in pairs(p) do
        if not seen[k] then
            parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and "{...}" or tostring(v))
        end
    end
    return table.concat(parts, "  ")
end

-- Dark enough to read on white.
local function lineColor(t)
    if t == "card_played" or t == "card_drawn"    then return { 0.10, 0.55, 0.20 } end
    if t == "strategy_played"                     then return { 0.05, 0.50, 0.60 } end
    if t == "trap_activated"                      then return { 0.48, 0.17, 0.75 } end
    if t == "attack_declared" or t == "cover"     then return { 0.75, 0.45, 0.00 } end
    if t == "lp_damage"                           then return { 0.85, 0.10, 0.20 } end
    if t == "defender_destroy"                    then return { 0.85, 0.35, 0.05 } end
    if t == "shot"                                then return { 0.10, 0.40, 0.85 } end
    if t == "turn_end"                            then return { 0.45, 0.45, 0.55 } end
    if t == "half_end"                            then return { 0.70, 0.55, 0.00 } end
    if t == "attack_wasted"                       then return { 0.50, 0.50, 0.50 } end
    return { Theme.inkText[1], Theme.inkText[2], Theme.inkText[3] }
end

-- scroll = lines scrolled up from the newest. Returns the clamped scroll.
function DebugLog.draw(match, scroll)
    local W, H = Layout.W, Layout.H
    local panW, panH = 680, H - 140
    local panX, panY = (W - panW) / 2, 100

    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H)
    Draw.sticker(panX, panY, panW, panH, { r = 18, fill = Theme.white, border = 0, shadow = 6 })
    Draw.ribbon(panX + panW / 2, panY - 24, 300, 46, "MATCH LOG", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text })
    Draw.text(#match.log .. " events  ·  mouse wheel to scroll  ·  L or the log button to close",
        panX, panY + 34, panW, "center", { size = 12, body = true, color = Theme.inkText })

    local lineH, padX = 17, 18
    local innerY, innerH = panY + 58, panH - 70
    local maxLines  = math.floor(innerH / lineH)
    local total     = #match.log
    local maxScroll = math.max(0, total - maxLines)
    scroll = math.max(0, math.min(scroll or 0, maxScroll))
    local startIdx = math.max(1, total - maxLines - scroll + 1)
    local endIdx   = total - scroll

    local prev = love.graphics.getFont()
    love.graphics.setFont(Fonts.body(11))
    love.graphics.setScissor(panX + padX, innerY, panW - padX * 2, innerH)
    local y = innerY
    for i = startIdx, endIdx do
        local e = match.log[i]
        local col = lineColor(e.type)
        local prefix = string.format("[H%s T%02d %s] %s", tostring(e.half), e.turn or 0,
            string.upper(tostring(e.phase or ""):sub(1, 3)), tostring(e.type))
        love.graphics.setColor(col[1], col[2], col[3], 0.75)
        love.graphics.print(prefix, panX + padX, y)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.print(fmtPayload(e.payload), panX + padX + 250, y)
        y = y + lineH
    end
    love.graphics.setScissor()
    love.graphics.setFont(prev)

    if maxScroll > 0 then
        local trackH = innerH - 4
        local thumbH = math.max(20, trackH * maxLines / total)
        local thumbY = innerY + 2 + ((maxScroll - scroll) / maxScroll) * (trackH - thumbH)
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.15)
        love.graphics.rectangle("fill", panX + panW - 12, innerY, 6, trackH, 3, 3)
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.6)
        love.graphics.rectangle("fill", panX + panW - 12, thumbY, 6, thumbH, 3, 3)
    end
    return scroll
end

function DebugLog.drawAIHand(match)
    local o = match.players.opponent
    local panW = 360
    local panH = math.min(Layout.H - 120, 48 + #o.hand * 22 + 12)
    local panX, panY = (Layout.W - panW) / 2, 100
    Draw.sticker(panX, panY, panW, panH, { r = 16, fill = Theme.white, border = 0, shadow = 6 })
    Draw.text("AI HAND (" .. #o.hand .. " cards)", panX, panY + 12, panW, "center",
        { size = 18, color = Theme.inkText })
    local y = panY + 44
    for _, card in ipairs(o.hand) do
        if y > panY + panH - 22 then
            Draw.text("...", panX + 14, y, panW - 28, "left", { size = 13, body = true, color = Theme.inkText })
            break
        end
        local g = Theme.typeGrad[card.type]
        local stat = card.stats and ("  A" .. (card.stats.atk or 0) .. "/D" .. (card.stats.def or 0)) or ""
        Draw.text("[" .. string.upper(card.type:sub(1, 3)) .. "] " .. card.name .. stat,
            panX + 14, y, panW - 28, "left",
            { size = 13, body = true, color = g and g[2] or Theme.inkText, fit = true, minSize = 9 })
        y = y + 22
    end
end

return DebugLog
```

- [ ] **Step 2: Wire it into `scenes/match.lua`.**
  - Add after `local Confetti = require("ui.match.confetti")`:

```lua
local DebugLog      = require("ui.match.debuglog")
```

  - Delete these from `scenes/match.lua`: the whole `-- ── Debug log panel` section (`local function fmtPayload`, `local function logLineColor`, `function Match.drawDebugLog`) and `function Match.drawAIHandDebug`.
  - In `Match.draw` replace:

```lua
    -- AI hand debug
    if aiHandDebug then Match.drawAIHandDebug(match) end

    -- Debug log panel (overlay, drawn last so it's on top)
    if debugLogOpen then Match.drawDebugLog(match) end
```

with:

```lua
    -- AI hand debug (TAB)
    if aiHandDebug then DebugLog.drawAIHand(match) end

    -- Full match log (log button / L)
    if debugLogOpen then debugLogScroll = DebugLog.draw(match, debugLogScroll) end
```

- [ ] **Step 3: Add the `debug` scenario.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Top-bar icons: log panel, AI hand (TAB), pause menu.
S.debug = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, function() love.keypressed("return") end },
    { 1.5, function() click(center(Layout.top.log)) end },
    { 2.0, function(c) c.snap("log") end },
    { 2.1, function() love.keypressed("l") end },
    { 2.2, function() love.keypressed("tab") end },
    { 2.6, function(c) c.snap("aihand") end },
    { 2.7, function() love.keypressed("tab") end },
    { 2.8, function() click(center(Layout.top.pause)) end },
    { 3.2, function(c) c.snap("pause") end },
    { 3.3, function() love.keypressed("escape") end },
    { 3.6, function(c) c.snap("resumed") end },
    { 4.0, function(c) c.quit() end },
}
```

- [ ] **Step 4: Checks, tests, snapshots**

Run: `grep -n 'fmtPayload\|logLineColor\|drawDebugLog\|drawAIHandDebug' scenes/match.lua; luac -p scenes/match.lua ui/match/debuglog.lua && lua tests/run.lua && tools/snapshot/snap.sh debug`
Expected: grep prints nothing; no `luac` output; `79 passed, 0 failed`; `debug_log`, `debug_aihand`, `debug_pause`, `debug_resumed` listed; no Lua error.

- [ ] **Step 5: Review with the Read tool:**

- `debug_log.png`: a navy dim over the match with a white sticker panel, a yellow "MATCH LOG" ribbon on top, a subtitle line, and colored log lines (at least the opening events).
- `debug_aihand.png`: a white "AI HAND (N cards)" panel listing the opponent's cards in type colors.
- `debug_pause.png`: the (legacy-styled) pause menu over the new layout.
- `debug_resumed.png`: the pause menu is closed and the match screen is normal.

- [ ] **Step 6: Commit**

```bash
git add ui/match/debuglog.lua scenes/match.lua tools/snapshot/scenarios.lua
git commit -m "Restyle match log and AI hand debug as sticker panels"
```

---

### Task 15: Final check

**Files:** none (verification only)

- [ ] **Step 1: Unit tests**

Run: `lua tests/run.lua`
Expected: `79 passed, 0 failed`

- [ ] **Step 2: No gameplay changes**

Run: `git diff --stat f44de4f -- engine store ai`
Expected: no output. (`f44de4f` is the last Plan A commit, "Fix card renderer caller regressions".)

- [ ] **Step 3: No references to removed modules or legacy layout in the match code**

Run: `grep -rn 'ui\.hud\|ui\.card_detail\|ui\.log"\|Theme\.layout\|Theme\.pitchCard\|Theme\.slot\b' --include='*.lua' scenes ui main.lua`
Expected: no output. (Legacy tokens still exist in `ui/theme.lua` until Plan C; nothing here should read them.)

- [ ] **Step 4: Every scenario runs clean**

Run: `for s in home library match cards summon juice debug; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback on stderr.

- [ ] **Step 5: Review every PNG with the Read tool** against the checklists in Tasks 11–14, plus:
  - `home_deck.png` and `library_grid.png` still render (legacy style, no vignette), with no Lua error.
  - `cards_gallery.png` is unchanged from Plan A.

- [ ] **Step 6: Report to the user.** Summarize what changed, and attach or show `match_start`, `summon_two`, `summon_attack`, `summon_hover`, `juice_drain` and `debug_log`. List the intentional deviations from this plan's header.

  Tell the user that an **interactive play-test is required** and cannot be done by the harness. They should play a full match vs. the AI to completion and check the following:
  - Hand hover, magnification and click-selection feel right, including with 7+ cards.
  - Summoning into every slot type, including traps and the Substitution / free-summon flow.
  - The mode toggle by click and by `M`.
  - START ATTACK, attacker selection, attack targeting and `ESC` cancel.
  - A strategy card play and Scout Report targeting.
  - The cover prompt and trap window when defending.
  - Combat and trap-activation overlays dismissed by click, `Space` and `Enter`.
  - Pause via `ESC` and the ⏸ button; music via the button; log via `L` and the button, with wheel scrolling; the AI hand via `TAB`.
  - Half-time, and the win screen with `R` / `ESC`.

---

## Self-review: spec §2 coverage

| Spec §2 item | Task |
|---|---|
| Background gradient, vignette removed, camera shake kept | 11 (`Draw.background`, `main.lua`) |
| Top bar: avatar, green LP bar with number, halves ⚽ pips | 8 (avatar), 9, 11 |
| Top bar: opponent mirrored red bar + deck count | 9 |
| Phase pill `HALF 1 · TURN 3 · ATTACK` (phase word colored) + YOUR/OPP TURN chip | 9 |
| Icon buttons pause / music / full log | 1 (`buttonAt`), 9, 11 (input), 14 (log panel) |
| Pitch x 24–1256, y 90–520, stripes, white border, shadow, lines, circle, boxes | 1, 11 (`ui/pitch.lua`) |
| 8 columns mirrored; two-card columns stacked, singles centred; pitch-size cards | 1, 11 |
| Empty slots dashed with labels; valid targets pulse | 11 |
| Keeper DEF badge = effective DEF with green +N | 2 |
| Midfield ★ crown | 2 (`Stats.crownOwner`), 10 (`Draw.star`), 11 |
| Traps: 2 small face-down slots by own goal | 1, 11 |
| Bottom-left: portrait, deck pile (draw origin), toast stack (3, slide, fade, color-coded) | 5, 8, 10, 11, 13 |
| Hand: fanned with rotation, dock magnification via transforms, hovered lifts + straightens | 3, 11 |
| Right: SUMMONS pill (green + ★), ATTACK/DEFENSE toggle, END TURN, START ATTACK (summon only) | 1, 2, 10, 11 |
| Card zoom after ~0.3s beside card, clamped; ability/tags/foul/status; click still selects | 6, 12 |
| Squash-pop summon | 13 |
| LP bars drain with white chunk, numbers count down | 4, 9 |
| `Match.flash` → ribbon banners | 7, 11, 13 |
| Screen shake kept; goal particles → confetti | 8, 11, 13 |
| Card-draw animation uses the new card back and deck position | 13 |
| Overlays keep working on top | 11 (draw order unchanged), 14, 15 |
| No engine/store/ai changes; §6 verification | 15 |

### Critical Files for Implementation
- /Users/mac/Documents/football-tcg-lua/scenes/match.lua
- /Users/mac/Documents/football-tcg-lua/ui/match/layout.lua (new)
- /Users/mac/Documents/football-tcg-lua/ui/pitch.lua
- /Users/mac/Documents/football-tcg-lua/ui/hand.lua
- /Users/mac/Documents/football-tcg-lua/tools/snapshot/scenarios.lua
