# Arcade Redesign, Plan C: Menus, Overlays & Cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every screen that still uses the old dark style into the bright arcade style:
- **Menus:** home menu, deck select, pause menu, card library.
- **Match overlays:** combat, trap activation, cover prompt, trap window, scout reveal, half-time ribbon, match-end screen.

Once nothing uses them, remove the legacy theme tokens and the dead modules. Gameplay, data contracts and inputs do not change.

**Architecture:**
- **Pure modules, unit-tested with plain Lua.** Every piece of logic lives in one:
  - menu focus and the home → deck select → library state machine;
  - home, deck-select, library and pause layouts, including hit-testing;
  - the choice of showcase cards for each deck;
  - the bottom prompt-panel layout and its hitboxes;
  - the combat, trap-activation and scout-reveal timelines, as time → pose functions;
  - the combat outcome styling;
  - the shatter piece generator;
  - the half-time text and the match-end layout and keys.
- **Thin LÖVE draw modules** sit on top in two folders:
  - `ui/menu/`: `home`, `deckselect`, `library`, `pause`, `backdrop`;
  - `ui/overlay/`: `combat`, `trapactivation`, `prompts`, `reveal`, `matchend`.
- **Overlay timing:** overlays are driven by a time value that `scenes/match.lua` advances (`combatT`, `trapActivT`, `scoutReveal.t`, `winT`). This replaces the flux tweens on `overlayAnim` / `trapActivAnim`.
- **`scenes/home.lua`** becomes a thin router over `ui/menu/*`.
- **`main.lua`** gains `Home.update` and `Home.mousemoved`, a `quit` action, and a restart with the same deck.
- **Cleanup:**
  - The old overlay and menu files are deleted as their replacements land.
  - The legacy theme tokens, `Card.drawTooltip`, the character's old `drawSide` / `draw`, and `lib/moonshine` are removed last.

**Tech Stack:**
- LÖVE 11.4 with LuaJIT / Lua 5.1 semantics: no `//`, no `goto`, use `table.unpack or unpack`, and never assign to a `for` loop variable.
- `lib/flux.lua` for the few remaining tweens (prompt slide, pause pop).
- Plain `lua` 5.5 (`/opt/homebrew/bin/lua`) for unit tests.
- `luac -p` for syntax checks of LÖVE-only files.
- `tools/snapshot/snap.sh` for screenshots.

**Spec:** `docs/superpowers/specs/2026-09-23-arcade-redesign-design.md`. This plan covers §1 (legacy removal), §3 Menus, §4 Overlays, §5 phases 4–5 and §6 verification.
**Branch:** `feat/arcade-redesign`, already checked out. Plans A and B are fully merged on it. The last Plan B commit is `54e39e1`.

**Conventions (apply to every task):**
- Run all commands from the repo root: `/Users/mac/Documents/football-tcg-lua`.
- **Commit messages:**
  - Every commit message ends with a blank line followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Use `git commit -m "<subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`.
  - The commit steps below show only the subject.
- **Snapshots:**
  - PNGs are captured at highdpi (2560×1600). Logical coordinates in the checklists are ×2 in the image.
  - If a PNG does not match its checklist, fix the code and re-run before committing.
- **Glyphs:** the fonts have no `▶ ◀ ✕ → ⚽` glyphs (checked with fontTools). These are drawn with primitives (`Draw.arrow`, `Draw.cross`). `·`, `–`, `—` and `×` exist and are used as text.
- **No gameplay changes:** nothing under `engine/`, `store/` or `ai/` is modified.
- **Test count:** 84 at the start, 142 at the end.

**Deviations from spec (intentional):**
1. **CARD LIBRARY button:** "neutral/blue" is a new `blue` button variant (`Theme.button.blue`).
2. **Deck showcase:** the fanned cards are the 3 rarest distinct field cards of each deck, with the rarest in the centre. They are drawn *behind* the tile, so only their tops peek out and their stat badges are hidden.
3. **Deck-select background:** it has no corner card backs, so they don't compete with the showcase fans. Home keeps them.
4. **Combat overlay:**
   - **Timing:**
     - The timeline is a pure function of `combatT`.
     - The LP-damage banner and confetti still fire at the clash, via `CombatFx.crossed`.
   - **Card faces:**
     - The combat snapshot has no card id, so faces are looked up by `name` + `type` in the card definitions. Unknown names fall back to a synthetic definition.
     - A keeper's `Eff. DEF` bonus = snapshot DEF − base DEF.
   - **Removed:** the side character portrait is dropped (`Character.drawSide` is removed).
   - **Result text for outcomes the spec doesn't name:**
     - A tie shows a grey `TIE` ribbon (the spec lists no tie colour).
     - `defender_destroyed` with LP damage reads `DESTROYED · LP -N`.
5. **Cover prompt and trap window:**
   - Your own coverers and traps are shown **face-up** in the panel (they are yours).
   - The attacking opponent card also pulses red on the pitch.
   - Clicking the small card works like its button.
   - A light navy dim (30%) keeps the panel readable while the pitch stays visible.
6. **Half-time ribbon:**
   - It waits until the combat and trap overlays are dismissed.
   - After half 2 it reads `FULL TIME · YOU 1 – 1 OPP · EXTRA TIME` when extra time follows.
   - It is not shown when the match ends.
7. **Match end:**
   - The screen appears after the final combat and trap overlays are dismissed.
   - **PLAY AGAIN** and `R` restart with the **same deck**. Before, `R` returned to the home screen.
   - `ESC` goes straight to the main menu. Before, it opened the pause menu.
   - The "happy pose" is the existing `attacking` character art.
8. **Extra keyboard support:**
   - The pause menu adds ↑/↓/Enter focus.
   - The library adds ←/→ to switch tabs; ↑/↓ scroll as before.
9. **Modules moved:**

   | Old | New |
   |---|---|
   | `ui/card_library.lua` | `ui/menu/library.lua` |
   | `ui/pause_menu.lua` | `ui/menu/pause.lua` |
   | `ui/combat_overlay.lua` | `ui/overlay/combat.lua` |
   | `ui/trap_activation_overlay.lua` | `ui/overlay/trapactivation.lua` |
   | `ui/cover_prompt.lua` + `Match.drawTrapWindow` | `ui/overlay/prompts.lua` |
   | `Match.drawScoutReveal` | `ui/overlay/reveal.lua` |
   | `Match.drawWinScreen` | `ui/overlay/matchend.lua` |

   `ui/trap_prompt.lua` was never required (dead code) and is deleted.
10. **Dev hooks:**
    - `Match.debugOverlay(kind, rec)` queues a synthetic overlay.
    - These are **harness-only** workarounds:
      - Snapshot scenarios also set store fields directly (`coverWindow`, `trapWindow`, LP, `halvesWon`, pitch cards).
      - They call `store:_checkHalf()`.
11. **`lib/moonshine`** is deleted. Nothing has required it since Plan B.

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `ui/menu/nav.lua` | create | Keyboard focus over a list: clamp or wrap (pure) |
| `ui/menu/flow.lua` | create | Home → deck select → match / library state machine (pure) |
| `ui/menu/backdrop.lua` | create | Menu background: gradient, scrolling stripes, faded card backs |
| `ui/menu/home.lua` | create | Bobbing logo + PLAY / CARD LIBRARY / QUIT (layout pure) |
| `ui/menu/deckselect.lua` | create | Deck tiles, showcase fans, BACK / KICK OFF (layout + showcase pure) |
| `ui/menu/library.lua` | create | Pill tabs, card grid, scroll, hover zoom (layout pure) |
| `ui/menu/pause.lua` | create | Pause panel pop-in, buttons, keys (layout + keys pure) |
| `ui/overlay/combatfx.lua` | create | Combat timeline, result styles, card views, shatter (pure) |
| `ui/overlay/combat.lua` | create | Combat overlay drawing |
| `ui/overlay/trapfx.lua` | create | Trap activation timeline, headline, dust puffs (pure) |
| `ui/overlay/trapactivation.lua` | create | Trap activation drawing |
| `ui/overlay/promptpanel.lua` | create | Bottom prompt panel layout + cover/trap hitboxes (pure) |
| `ui/overlay/prompts.lua` | create | Cover prompt + trap window drawing |
| `ui/overlay/reveal.lua` | create | Scout reveal pose (pure) + drawing |
| `ui/overlay/matchend.lua` | create | Half-time text, match-end layout/keys (pure) + drawing |
| `ui/theme.lua` | modify | `button.blue`, `outcome`, `deckFill`, `dim`; legacy tokens removed |
| `ui/kit/draw.lua` | modify | `burstPoints`, `burst`, `arrow`, `cross`, `hintPill` |
| `ui/match/banner.lua` | modify | Per-instance size/hold/slide, `half` style |
| `ui/character.lua` | modify | `drawPortrait` state override; `drawSide`, `draw` and the unused tables removed |
| `ui/card.lua` | modify | `Card.drawTooltip` removed |
| `scenes/home.lua` | rewrite | Router over `ui/menu/*` |
| `scenes/match.lua` | modify | New menus/overlays wiring, overlay timers, half-time, match end, dev hook |
| `main.lua` | modify | `Home.update` / `mousemoved`, quit, restart with the same deck, font cleanup |
| `ui/card_library.lua`, `ui/pause_menu.lua`, `ui/combat_overlay.lua`, `ui/trap_activation_overlay.lua`, `ui/cover_prompt.lua`, `ui/trap_prompt.lua` | delete | Replaced (see above) |
| `lib/moonshine/` | delete | Unused since Plan B |
| `tools/snapshot/scenarios.lua` | modify | `kickOff` helper; `home` / `library` rewritten; `pause`, `combat`, `trap`, `cover`, `trapwin`, `scout`, `halftime`, `victory`, `defeat` added |
| `tools/snapshot/card_gallery.lua` | modify | `Card.drawInfo` instead of `Card.drawTooltip` |
| `tests/test_draw.lua`, `tests/test_theme.lua`, `tests/test_banner.lua` | modify | New primitives, tokens, banner options, legacy-gone check |
| `tests/test_menu_nav.lua`, `tests/test_menu_flow.lua`, `tests/test_home_menu.lua`, `tests/test_deckselect.lua`, `tests/test_library.lua`, `tests/test_pause.lua`, `tests/test_combatfx.lua`, `tests/test_trapfx.lua`, `tests/test_promptpanel.lua`, `tests/test_reveal.lua`, `tests/test_matchend.lua` | create | Pure-logic tests |

---

### Task 1: Theme tokens and draw primitives for menus and overlays

**Files:**
- Modify: `ui/theme.lua`, `ui/kit/draw.lua`
- Test: `tests/test_theme.lua`, `tests/test_draw.lua`

- [ ] **Step 1: Write the failing tests.**

In `tests/test_theme.lua`, replace the line

```lua
    for _, v in ipairs({ "primary", "go", "danger", "neutral", "icon" }) do
```

with

```lua
    for _, v in ipairs({ "primary", "go", "danger", "neutral", "blue", "icon" }) do
```

and append at the end of the file:

```lua
T.test("overlay outcome colours and deck fills are two-stop gradients", function()
    for _, k in ipairs({ "red", "orange", "blue", "yellow", "grey", "purple" }) do
        local g = Theme.outcome[k]
        T.ok(g and g[1] and g[2], "missing outcome " .. k)
    end
    for _, k in ipairs({ "tikitaka", "longball", "catenaccio" }) do
        local g = Theme.deckFill[k]
        T.ok(g and g[1] and g[2], "missing deckFill " .. k)
    end
    T.near(Theme.dim[4], 0.72)
end)
```

Append at the end of `tests/test_draw.lua`:

```lua
T.test("burstPoints alternates outer and inner radius, first point on top", function()
    local p = Draw.burstPoints(100, 50, 40, 20, 12)
    T.eq(#p, 12 * 2 * 2)
    T.near(p[1], 100); T.near(p[2], 10)
    for i = 1, #p, 2 do
        local d = math.sqrt((p[i] - 100) ^ 2 + (p[i + 1] - 50) ^ 2)
        local want = (((i - 1) / 2) % 2 == 0) and 40 or 20
        T.near(d, want, 1e-9)
    end
end)

T.test("burstPoints rotation offsets the first point", function()
    local p = Draw.burstPoints(0, 0, 10, 5, 5, 0)
    T.near(p[1], 10); T.near(p[2], 0)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL` lines for "button variants have gradient…", "overlay outcome colours…" and both `burstPoints` tests, then `83 passed, 4 failed`.

- [ ] **Step 3: Add the tokens to `ui/theme.lua`.**

In the `Theme.button` table, add a line directly after the `neutral = …` line:

```lua
    blue    = { fill = { hex("6ac8ff"), hex("1f78e0") }, text = { 1, 1, 1, 1 }, shadow = hex("0f4a9a") },
```

Then insert directly **above** the line `-- ══ Legacy tokens ════…`:

```lua
-- Result ribbons, trap purple, match-end grey (overlays).
Theme.outcome = {
    red    = { hex("ff8a8a"), hex("e0243a") },
    orange = { hex("ffc15a"), hex("f07a0c") },
    blue   = { hex("6ac8ff"), hex("1f78e0") },
    yellow = { hex("ffd23a"), hex("ff9a1a") },
    grey   = { hex("d7dcea"), hex("8f99b5") },
    purple = { hex("c77dff"), hex("7b2cbf") },
}

-- Deck-select tiles (keys match data/presetDecks.lua).
Theme.deckFill = {
    tikitaka   = { hex("6ee7a0"), hex("16a34a") },
    longball   = { hex("ff7a59"), hex("e0243a") },
    catenaccio = { hex("4fb8ff"), hex("2563eb") },
}

-- Navy dim behind menus and overlays.
Theme.dim = hex("1d1d59", 0.72)

```

- [ ] **Step 4: Add the primitives to `ui/kit/draw.lua`.** Insert directly above the final `return Draw`:

```lua
-- ── Menus & overlays ──────────────────────────────────────────────────────────

-- n-spike burst outline {x1,y1,...}: alternating outer/inner radius, first point at
-- angle rot (default: straight up). Pure (unit-tested).
function Draw.burstPoints(cx, cy, rOuter, rInner, n, rot)
    rot = rot or -math.pi / 2
    local p = {}
    for i = 0, n * 2 - 1 do
        local a = rot + i * math.pi / n
        local rad = (i % 2 == 0) and rOuter or rInner
        p[#p + 1] = cx + math.cos(a) * rad
        p[#p + 1] = cy + math.sin(a) * rad
    end
    return p
end

-- Concave outline filled as a fan of triangles around (cx, cy).
local function fillFan(cx, cy, p)
    for i = 1, #p, 2 do
        local nx = i + 2
        if nx > #p then nx = 1 end
        love.graphics.polygon("fill", cx, cy, p[i], p[i + 1], p[nx], p[nx + 1])
    end
end

-- Starburst ("CLASH!") with a white rim and a hard ink shadow; rot spins it.
function Draw.burst(cx, cy, rOuter, rInner, n, color, alphaMul, rot)
    local sh = math.max(2, math.floor(rOuter * 0.06))
    Draw.setColor(Theme.ink, alphaMul)
    fillFan(cx, cy + sh, Draw.burstPoints(cx, cy + sh, rOuter + 5, rInner + 5, n, rot))
    Draw.setColor(Theme.white, alphaMul)
    fillFan(cx, cy, Draw.burstPoints(cx, cy, rOuter + 5, rInner + 5, n, rot))
    Draw.setColor(color or Theme.highlight.selected, alphaMul)
    fillFan(cx, cy, Draw.burstPoints(cx, cy, rOuter, rInner, n, rot))
end

-- Solid triangle arrow (the fonts have no ▶ / ◀). dir: 1 = right, -1 = left.
function Draw.arrow(cx, cy, size, dir, color, alphaMul)
    local h = size / 2
    Draw.setColor(color or Theme.white, alphaMul)
    love.graphics.polygon("fill", cx - dir * h * 0.8, cy - h, cx + dir * h, cy, cx - dir * h * 0.8, cy + h)
end

-- ✕ glyph (the fonts have none): two thick strokes.
function Draw.cross(cx, cy, size, color, width, alphaMul)
    local h = size / 2
    Draw.setColor(color or Theme.white, alphaMul)
    love.graphics.setLineWidth(width or math.max(3, size * 0.22))
    love.graphics.line(cx - h, cy - h, cx + h, cy + h)
    love.graphics.line(cx - h, cy + h, cx + h, cy - h)
    love.graphics.setLineWidth(1)
end

-- "CLICK OR SPACE ▶" style hint pill centred on cx; the arrow is drawn, not typed.
function Draw.hintPill(cx, y, text, alpha)
    local size, h = 18, 34
    local w = Fonts.get(size):getWidth(text) + 64
    local x = cx - w / 2
    Draw.sticker(x, y, w, h, { r = h / 2, fill = Theme.white, border = 2, shadow = 3, alpha = alpha })
    Draw.text(text, x + 18, y + (h - size) / 2 - 2, w - 58, "center", {
        size = size, color = Theme.inkText, alpha = alpha,
    })
    Draw.arrow(x + w - 24, y + h / 2, 14, 1, Theme.inkText, alpha)
end
```

- [ ] **Step 5: Run the tests**

Run: `luac -p ui/theme.lua ui/kit/draw.lua && lua tests/run.lua`
Expected: no `luac` output; `87 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add ui/theme.lua ui/kit/draw.lua tests/test_theme.lua tests/test_draw.lua
git commit -m "Add overlay colour tokens, blue button and burst/arrow/cross/hint primitives"
```

---

### Task 2: Menu focus and home flow state machine

**Files:**
- Create: `ui/menu/nav.lua`, `ui/menu/flow.lua`
- Test: `tests/test_menu_nav.lua`, `tests/test_menu_flow.lua`

- [ ] **Step 1: Write the failing test `tests/test_menu_nav.lua`**

```lua
local T   = require("tests.t")
local Nav = require("ui.menu.nav")

T.test("nav clamps at both ends by default", function()
    local n = Nav.new(3)
    T.eq(n.index, 1)
    n:move(-1); T.eq(n.index, 1)
    n:move(1); n:move(1); n:move(1); T.eq(n.index, 3)
end)

T.test("nav wraps when asked", function()
    local n = Nav.new(3, { wrap = true })
    n:move(-1); T.eq(n.index, 3)
    n:move(1);  T.eq(n.index, 1)
end)

T.test("set ignores out-of-range indices", function()
    local n = Nav.new(3, { index = 2 })
    T.eq(n:set(0), 2); T.eq(n:set(4), 2); T.eq(n:set(3), 3); T.eq(n:set(nil), 3)
end)
```

- [ ] **Step 2: Write the failing test `tests/test_menu_flow.lua`**

```lua
local T    = require("tests.t")
local Flow = require("ui.menu.flow")

T.test("flow starts on home with PLAY focused; Enter opens deck select", function()
    local f = Flow.new(3)
    T.eq(f.screen, "home"); T.eq(f.home.index, 1)
    T.eq(f:key("return"), nil); T.eq(f.screen, "decks")
end)

T.test("up/down wrap on home and Esc quits", function()
    local f = Flow.new(3)
    f:key("up");   T.eq(f.home.index, 3)
    f:key("down"); T.eq(f.home.index, 1)
    T.eq(f:key("escape"), "quit"); T.eq(f.screen, "home")
end)

T.test("CARD LIBRARY opens the library and closing returns home", function()
    local f = Flow.new(3)
    T.eq(f:activateHome(2), "openLibrary"); T.eq(f.screen, "library")
    T.eq(f:key("escape"), nil, "library keys belong to the library module")
    T.eq(f.screen, "library")
    f:closeLibrary(); T.eq(f.screen, "home")
end)

T.test("QUIT returns quit", function()
    local f = Flow.new(3)
    f:key("down"); f:key("down")
    T.eq(f:key("kpenter"), "quit")
end)

T.test("deck select: arrows clamp, Enter starts, Esc goes back home", function()
    local f = Flow.new(3)
    f:activateHome(1)
    f:key("left"); T.eq(f.decks.index, 1)
    f:key("right"); f:key("right"); f:key("right"); T.eq(f.decks.index, 3)
    local a, i = f:key("return"); T.eq(a, "start"); T.eq(i, 3)
    T.eq(f:key("escape"), nil); T.eq(f.screen, "home")
end)

T.test("clicking a deck selects it; clicking it again starts", function()
    local f = Flow.new(3)
    f:activateHome(1)
    T.eq(f:clickDeck(2), nil); T.eq(f.decks.index, 2)
    local a, i = f:clickDeck(2); T.eq(a, "start"); T.eq(i, 2)
    a, i = f:kickOff(); T.eq(a, "start"); T.eq(i, 2)
    f:back(); T.eq(f.screen, "home")
end)
```

- [ ] **Step 3: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: two `FAIL … (load error)` lines, for `test_menu_flow.lua` and `test_menu_nav.lua`, each with `module 'ui.menu.…' not found`; then `87 passed, 2 failed`.

- [ ] **Step 4: Create `ui/menu/nav.lua`**

```lua
-- Keyboard focus over a list of `count` items. Pure (unit-tested).
local Nav = {}
Nav.__index = Nav

-- opts: wrap (default false), index (default 1)
function Nav.new(count, opts)
    opts = opts or {}
    return setmetatable({ count = count, index = opts.index or 1, wrap = opts.wrap or false }, Nav)
end

function Nav:move(d)
    local i = self.index + d
    if self.wrap then
        i = (i - 1) % self.count + 1
    else
        i = math.max(1, math.min(self.count, i))
    end
    self.index = i
    return i
end

-- Focus item i if it exists. Returns the focused index.
function Nav:set(i)
    if i and i >= 1 and i <= self.count then self.index = i end
    return self.index
end

return Nav
```

- [ ] **Step 5: Create `ui/menu/flow.lua`**

```lua
-- Home-scene state machine: home menu → deck select → match, plus the card library.
-- Pure (unit-tested). Methods return an action for scenes/home.lua:
--   "quit" | "start", deckIndex | "openLibrary" | nil
-- Library keys/clicks are handled by ui/menu/library.lua; call closeLibrary when it closes.
local Nav = require("ui.menu.nav")

local Flow = {}
Flow.__index = Flow

Flow.HOME_ITEMS = { "play", "library", "quit" }

local ENTER = { ["return"] = true, kpenter = true, space = true }

function Flow.new(deckCount)
    return setmetatable({
        screen = "home",
        home   = Nav.new(#Flow.HOME_ITEMS, { wrap = true }),
        decks  = Nav.new(deckCount or 3),
    }, Flow)
end

-- Activate home item i (click, or Enter on the focused item).
function Flow:activateHome(i)
    self.home:set(i)
    local item = Flow.HOME_ITEMS[self.home.index]
    if item == "play" then
        self.screen = "decks"
        return nil
    elseif item == "library" then
        self.screen = "library"
        return "openLibrary"
    end
    return "quit"
end

-- Deck tile click: the first click selects, a click on the selected tile starts.
function Flow:clickDeck(i)
    if self.decks.index == i then return "start", i end
    self.decks:set(i)
    return nil
end

function Flow:kickOff()      return "start", self.decks.index end
function Flow:back()         self.screen = "home"; return nil end
function Flow:closeLibrary() self.screen = "home"; return nil end

function Flow:key(key)
    if self.screen == "home" then
        if key == "up" then self.home:move(-1)
        elseif key == "down" then self.home:move(1)
        elseif ENTER[key] then return self:activateHome(self.home.index)
        elseif key == "escape" then return "quit" end
    elseif self.screen == "decks" then
        if key == "left" then self.decks:move(-1)
        elseif key == "right" then self.decks:move(1)
        elseif ENTER[key] then return self:kickOff()
        elseif key == "escape" or key == "backspace" then return self:back() end
    end
    return nil
end

return Flow
```

- [ ] **Step 6: Run the tests**

Run: `lua tests/run.lua`
Expected: `96 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add ui/menu/nav.lua ui/menu/flow.lua tests/test_menu_nav.lua tests/test_menu_flow.lua
git commit -m "Add menu focus and home flow state machine"
```

---

### Task 3: Menu backdrop and home menu module

**Files:**
- Create: `ui/menu/backdrop.lua`, `ui/menu/home.lua`
- Test: `tests/test_home_menu.lua`

- [ ] **Step 1: Write the failing test `tests/test_home_menu.lua`**

```lua
local T        = require("tests.t")
local HomeMenu = require("ui.menu.home")
local Backdrop = require("ui.menu.backdrop")

T.test("home buttons are centred, stacked below the logo and on screen", function()
    local prev
    for i = 1, #HomeMenu.ITEMS do
        local r = HomeMenu.buttonRect(i)
        T.near(r.x + r.w / 2, 640)
        T.ok(r.y >= 330 and r.y + r.h <= 700, "button " .. i .. " outside its band")
        if prev then T.ok(r.y >= prev.y + prev.h + 10, "buttons " .. (i - 1) .. "/" .. i .. " overlap") end
        prev = r
    end
    T.eq(HomeMenu.ITEMS[1].id, "play"); T.eq(HomeMenu.ITEMS[2].id, "library"); T.eq(HomeMenu.ITEMS[3].id, "quit")
    T.eq(HomeMenu.ITEMS[2].variant, "blue")
end)

T.test("buttonAt maps button centres and misses elsewhere", function()
    for i = 1, 3 do
        local r = HomeMenu.buttonRect(i)
        T.eq(HomeMenu.buttonAt(r.x + r.w / 2, r.y + r.h / 2), i)
    end
    T.eq(HomeMenu.buttonAt(100, 100), nil)
    T.eq(HomeMenu.buttonAt(640, 340), nil)
    local a, b = HomeMenu.buttonRect(1), HomeMenu.buttonRect(2)
    T.eq(HomeMenu.buttonAt(640, (a.y + a.h + b.y) / 2), nil)
end)

T.test("logo bob stays within 6px", function()
    for t = 0, 5, 0.1 do T.ok(math.abs(HomeMenu.bob(t)) <= 6 + 1e-9) end
end)

T.test("backdrop stripes scroll and wrap every stripe spacing", function()
    T.near(Backdrop.offset(0), 0)
    T.near(Backdrop.offset(1), Backdrop.STRIPE_SPEED)
    T.near(Backdrop.offset(Backdrop.STRIPE_SPACING / Backdrop.STRIPE_SPEED), 0, 1e-6)
    for t = 0, 20, 0.7 do
        local o = Backdrop.offset(t)
        T.ok(o >= 0 and o < Backdrop.STRIPE_SPACING)
    end
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_home_menu.lua (load error)` with `module 'ui.menu.home' not found`; then `96 passed, 1 failed`.

- [ ] **Step 3: Create `ui/menu/backdrop.lua`**

```lua
-- Menu background: arcade gradient, slow-scrolling soft diagonal stripes and big faded
-- card backs in the corners. Shared by home, deck select and the card library.
local Draw = require("ui.kit.draw")
local Card = require("ui.card")

local Backdrop = {}

Backdrop.STRIPE_SPACING = 90
Backdrop.STRIPE_SPEED   = 18     -- px per second

-- Stripe phase at time t, in [0, STRIPE_SPACING). Pure (unit-tested).
function Backdrop.offset(t)
    return (t * Backdrop.STRIPE_SPEED) % Backdrop.STRIPE_SPACING
end

-- Top-left corners of the 200×274 faded card backs (partly off-screen) and their tilt.
local CORNERS = {
    { x = -60,  y = -70, rot = -0.35 },
    { x = 1150, y = -90, rot = 0.30 },
    { x = -80,  y = 610, rot = 0.28 },
    { x = 1140, y = 600, rot = -0.32 },
}

-- t: seconds (drives the stripe scroll). cards == false hides the corner card backs.
function Backdrop.draw(t, W, H, cards)
    Draw.background(W, H)
    local sp = Backdrop.STRIPE_SPACING
    Draw.stripes(-sp + Backdrop.offset(t), 0, W + sp, H, sp, 34, { 1, 1, 1, 0.06 })
    if cards == false then return end
    for _, c in ipairs(CORNERS) do
        love.graphics.push()
        love.graphics.translate(c.x + 100, c.y + 137)
        love.graphics.rotate(c.rot)
        Card.drawBack(-100, -137, 200, 274, { alpha = 0.22 })
        love.graphics.pop()
    end
end

return Backdrop
```

- [ ] **Step 4: Create `ui/menu/home.lua`**

```lua
-- Home screen: bobbing FOOTBALL TCG logo with a football badge, and PLAY / CARD LIBRARY /
-- QUIT buttons. Layout is pure (unit-tested); update/draw use LÖVE.
-- Keyboard focus comes from ui/menu/flow.lua (passed into update).
local Theme    = require("ui.theme")
local Fonts    = require("ui.fonts")
local Draw     = require("ui.kit.draw")
local Icons    = require("ui.kit.icons")
local Button   = require("ui.kit.button")
local Backdrop = require("ui.menu.backdrop")

local HomeMenu = {}

HomeMenu.W, HomeMenu.H = 1280, 800
HomeMenu.BTN_W, HomeMenu.BTN_H, HomeMenu.BTN_GAP, HomeMenu.BTN_Y = 320, 72, 22, 352
HomeMenu.LOGO_Y, HomeMenu.LOGO_SIZE = 130, 92
HomeMenu.ITEMS = {
    { id = "play",    label = "PLAY",         variant = "primary", fontSize = 38 },
    { id = "library", label = "CARD LIBRARY", variant = "blue",    fontSize = 28 },
    { id = "quit",    label = "QUIT",         variant = "danger",  fontSize = 28 },
}

function HomeMenu.buttonRect(i)
    return {
        x = (HomeMenu.W - HomeMenu.BTN_W) / 2,
        y = HomeMenu.BTN_Y + (i - 1) * (HomeMenu.BTN_H + HomeMenu.BTN_GAP),
        w = HomeMenu.BTN_W, h = HomeMenu.BTN_H,
    }
end

-- Index of the button under (x, y), or nil.
function HomeMenu.buttonAt(x, y)
    for i = 1, #HomeMenu.ITEMS do
        local r = HomeMenu.buttonRect(i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

-- Logo vertical bob (px) at time t.
function HomeMenu.bob(t) return math.sin(t * 2.2) * 6 end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local buttons, time = nil, 0

local function ensure()
    if buttons then return end
    buttons = {}
    for i, it in ipairs(HomeMenu.ITEMS) do
        local r = HomeMenu.buttonRect(i)
        buttons[i] = Button.new({ id = it.id, label = it.label, variant = it.variant, fontSize = it.fontSize,
            x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

-- focus: index of the keyboard-focused button (pulsing glow).
function HomeMenu.update(dt, mx, my, focus)
    ensure()
    time = time + dt
    local down = love.mouse.isDown(1)
    for i, b in ipairs(buttons) do
        b.focused = (i == focus)
        b:update(dt, mx or -1, my or -1, down)
    end
end

-- Word shifted right so the football badge + word are centred as a group.
local function drawLogo(t)
    local W, size = HomeMenu.W, HomeMenu.LOGO_SIZE
    local y = HomeMenu.LOGO_Y + HomeMenu.bob(t)
    local text = "FOOTBALL TCG"
    local tw = Fonts.get(size):getWidth(text)
    local shift = 46
    -- navy drop shadow of the outlined word, then the yellow word with a white outline
    Draw.text(text, shift, y + 8, W, "center", { size = size, color = Theme.ink, outline = 5, outlineColor = Theme.ink })
    Draw.text(text, shift, y, W, "center", {
        size = size, color = Theme.highlight.selected, outline = 5, outlineColor = Theme.white,
    })
    local bx, by = W / 2 - tw / 2 - 8, y + size * 0.52
    Draw.setColor(Theme.ink);   love.graphics.circle("fill", bx, by + 6, 38, 40)
    Draw.setColor(Theme.white); love.graphics.circle("fill", bx, by, 38, 40)
    Icons.draw("soccer-ball", bx, by, 62, Theme.inkText, 0)
end

function HomeMenu.draw()
    ensure()
    local W, H = HomeMenu.W, HomeMenu.H
    Backdrop.draw(time, W, H)
    drawLogo(time)
    for _, b in ipairs(buttons) do b:draw() end
    Draw.text("ARROW KEYS + ENTER  ·  CLICK  ·  ESC TO QUIT", 0, H - 44, W, "center", {
        size = 14, body = true, color = { 1, 1, 1, 0.85 }, shadowY = 1,
    })
end

return HomeMenu
```

- [ ] **Step 5: Run the checks and tests**

Run: `luac -p ui/menu/backdrop.lua ui/menu/home.lua && lua tests/run.lua`
Expected: no `luac` output; `100 passed, 0 failed`. The home menu is wired and screenshotted in Task 6.

- [ ] **Step 6: Commit**

```bash
git add ui/menu/backdrop.lua ui/menu/home.lua tests/test_home_menu.lua
git commit -m "Add menu backdrop and home menu module"
```

---

### Task 4: Deck select module

**Files:**
- Create: `ui/menu/deckselect.lua`
- Test: `tests/test_deckselect.lua`

- [ ] **Step 1: Write the failing test `tests/test_deckselect.lua`**

```lua
local T          = require("tests.t")
local DeckSelect = require("ui.menu.deckselect")

T.test("deck tiles are equal, centred, evenly spaced and clear of title and buttons", function()
    local n = #DeckSelect.DECKS
    T.eq(n, 3)
    local first, last = DeckSelect.tileRect(1), DeckSelect.tileRect(n)
    T.near((first.x + last.x + last.w) / 2, 640)
    for i = 2, n do
        local a, b = DeckSelect.tileRect(i - 1), DeckSelect.tileRect(i)
        T.eq(b.w, a.w); T.near(b.x - (a.x + a.w), DeckSelect.GAP)
    end
    local F, Ti = DeckSelect.FAN, DeckSelect.TITLE
    for i = 1, n do
        local r = DeckSelect.tileRect(i)
        T.ok(r.y + r.h < DeckSelect.BACK.y - 40, "tile " .. i .. " too low")
        T.ok(r.y + F.bottom - F.h - DeckSelect.LIFT > Ti.y + Ti.h + 4, "fanned cards would hit the title")
    end
    T.ok(DeckSelect.BACK.x + DeckSelect.BACK.w < DeckSelect.KICKOFF.x)
    T.ok(DeckSelect.KICKOFF.x + DeckSelect.KICKOFF.w <= 1280 and DeckSelect.KICKOFF.y + DeckSelect.KICKOFF.h <= 800)
end)

T.test("hitAt maps tiles and buttons", function()
    for i = 1, 3 do
        local r = DeckSelect.tileRect(i)
        T.eq(DeckSelect.hitAt(r.x + r.w / 2, r.y + r.h / 2), i)
    end
    local b, k = DeckSelect.BACK, DeckSelect.KICKOFF
    T.eq(DeckSelect.hitAt(b.x + 5, b.y + 5), "back")
    T.eq(DeckSelect.hitAt(k.x + k.w - 5, k.y + k.h - 5), "kickoff")
    T.eq(DeckSelect.hitAt(640, 20), nil)
end)

T.test("showcase: three distinct field cards, rarest in the centre", function()
    local cards = {
        { id = "a", type = "striker",    rarity = "common" },
        { id = "t", type = "trap",       rarity = "legendary" },
        { id = "b", type = "keeper",     rarity = "rare" },
        { id = "b", type = "keeper",     rarity = "rare" },
        { id = "c", type = "defender",   rarity = "uncommon" },
        { id = "d", type = "midfielder", rarity = "common" },
    }
    local s = DeckSelect.showcase(cards)
    T.eq(#s, 3)
    T.eq(s[1].id, "c"); T.eq(s[2].id, "b"); T.eq(s[3].id, "a")
end)

T.test("every preset deck has a showcase of three distinct cards", function()
    local Decks = require("data.presetDecks")
    for _, d in ipairs(DeckSelect.DECKS) do
        local deck = Decks[d.key]
        T.ok(deck, "no preset deck " .. d.key)
        local s = DeckSelect.showcase(deck.cards)
        T.eq(#s, 3, d.key)
        T.ok(s[1].id ~= s[2].id and s[2].id ~= s[3].id and s[1].id ~= s[3].id, d.key .. " repeats a card")
    end
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_deckselect.lua (load error)`; then `100 passed, 1 failed`.

- [ ] **Step 3: Create `ui/menu/deckselect.lua`**

```lua
-- Deck select (after PLAY): three deck tiles, each with a fanned showcase of three real
-- cards peeking over its top; the selected tile lifts and scales with a yellow ring.
-- BACK bottom-left, KICK OFF bottom-right. Layout, hit-testing and the showcase pick are
-- pure (unit-tested); update/draw use LÖVE.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Backdrop = require("ui.menu.backdrop")

local DeckSelect = {}

DeckSelect.DECKS = {
    { key = "tikitaka",   label = "THE BEAUTIFUL GAME", sub = "TIKI-TAKA",  desc = "Possession & draw power" },
    { key = "longball",   label = "DIRECT FOOTBALL",    sub = "LONG BALL",  desc = "Raw striker power" },
    { key = "catenaccio", label = "THE WALL",           sub = "CATENACCIO", desc = "Defensive fortress" },
}
DeckSelect.TILE_W, DeckSelect.TILE_H, DeckSelect.GAP, DeckSelect.TILE_Y = 320, 300, 40, 250
DeckSelect.LIFT    = 18                                 -- selected tile rises (px)
DeckSelect.FAN     = { bottom = 56, w = 108, h = 148 }  -- showcase cards; bottom = px below the tile top
DeckSelect.TITLE   = { y = 44, h = 64 }
DeckSelect.BACK    = { x = 40,   y = 704, w = 210, h = 64 }
DeckSelect.KICKOFF = { x = 1010, y = 704, w = 230, h = 64 }

function DeckSelect.tileRect(i)
    local n = #DeckSelect.DECKS
    local total = n * DeckSelect.TILE_W + (n - 1) * DeckSelect.GAP
    local x0 = (1280 - total) / 2
    return { x = x0 + (i - 1) * (DeckSelect.TILE_W + DeckSelect.GAP), y = DeckSelect.TILE_Y,
             w = DeckSelect.TILE_W, h = DeckSelect.TILE_H }
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- "back" | "kickoff" | tile index | nil for a click at (x, y).
function DeckSelect.hitAt(x, y)
    if inRect(x, y, DeckSelect.BACK) then return "back" end
    if inRect(x, y, DeckSelect.KICKOFF) then return "kickoff" end
    for i = 1, #DeckSelect.DECKS do
        if inRect(x, y, DeckSelect.tileRect(i)) then return i end
    end
    return nil
end

local RANK  = { legendary = 4, rare = 3, uncommon = 2, common = 1 }
local FIELD = { striker = true, midfielder = true, defender = true, keeper = true }

-- Three distinct field cards to fan over a deck tile: rarest first (deck order breaks
-- ties), returned as { left, centre, right } with the rarest in the centre.
function DeckSelect.showcase(cards)
    local seen, pool = {}, {}
    for i, c in ipairs(cards) do
        if FIELD[c.type] and not seen[c.id] then
            seen[c.id] = true
            pool[#pool + 1] = { card = c, rank = RANK[c.rarity] or 0, order = i }
        end
    end
    table.sort(pool, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.order < b.order
    end)
    local out = {}
    if pool[2] then out[#out + 1] = pool[2].card end
    if pool[1] then out[#out + 1] = pool[1].card end
    if pool[3] then out[#out + 1] = pool[3].card end
    return out
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local buttons, showcases, counts = nil, nil, nil
local lifts, time = { 0, 0, 0 }, 0

local function ensure()
    if buttons then return end
    local B, K = DeckSelect.BACK, DeckSelect.KICKOFF
    buttons = {
        back    = Button.new({ id = "back", label = "BACK", variant = "neutral", fontSize = 26,
                               x = B.x, y = B.y, w = B.w, h = B.h }),
        kickoff = Button.new({ id = "kickoff", label = "KICK OFF", variant = "go", fontSize = 30,
                               x = K.x, y = K.y, w = K.w, h = K.h }),
    }
    local Decks = require("data.presetDecks")
    showcases, counts = {}, {}
    for i, d in ipairs(DeckSelect.DECKS) do
        showcases[i] = DeckSelect.showcase(Decks[d.key].cards)
        counts[i] = #Decks[d.key].cards
    end
end

function DeckSelect.update(dt, mx, my, selected)
    ensure()
    time = time + dt
    local down = love.mouse.isDown(1)
    buttons.back:update(dt, mx or -1, my or -1, down)
    buttons.kickoff:update(dt, mx or -1, my or -1, down)
    for i = 1, #DeckSelect.DECKS do
        local target = (i == selected) and 1 or 0
        lifts[i] = lifts[i] + (target - lifts[i]) * math.min(1, dt * 12)
    end
end

-- Three cards fanned around cx, bottoms at bottomY (sides first, centre on top).
local function drawFan(cards, cx, bottomY)
    local F = DeckSelect.FAN
    local angle = { -0.20, 0, 0.20 }
    local dx    = { -58, 0, 58 }
    for _, k in ipairs({ 1, 3, 2 }) do
        local c = cards[k]
        if c then
            love.graphics.push()
            love.graphics.translate(cx + dx[k], bottomY + (k == 2 and -10 or 0))
            love.graphics.rotate(angle[k])
            Card.drawFace(c, -F.w / 2, -F.h, F.w, F.h, {})
            love.graphics.pop()
        end
    end
end

local function drawTile(i, sel)
    local deck, lift = DeckSelect.DECKS[i], lifts[i]
    local r = DeckSelect.tileRect(i)
    local cx, cy = r.x + r.w / 2, r.y + r.h / 2
    local s = 1 + 0.05 * lift
    love.graphics.push()
    love.graphics.translate(cx, cy - DeckSelect.LIFT * lift)
    love.graphics.scale(s, s)
    love.graphics.translate(-cx, -cy)
    if sel then
        Draw.glow(r.x, r.y, r.w, r.h, 24, Theme.highlight.selected, 1.2)
        Draw.ring(r.x - 6, r.y - 6, r.w + 12, r.h + 12, 30, Theme.highlight.selected, 6)
    end
    drawFan(showcases[i], cx, r.y + DeckSelect.FAN.bottom)     -- behind the tile: only the tops peek out
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 24, fill = Theme.deckFill[deck.key], dir = "d", border = 5, shadow = 7 })
    Draw.text(deck.label, r.x + 16, r.y + 84, r.w - 32, "center", {
        size = 32, color = Theme.white, shadowY = 3, fit = true, minSize = 18,
    })
    Draw.pill(r.x + r.w / 2 - 80, r.y + 134, 160, 30, deck.sub, {
        fill = Theme.ink, textColor = Theme.white, size = 16, border = 2, shadow = 0,
    })
    Draw.text(deck.desc, r.x + 24, r.y + 184, r.w - 48, "center", {
        size = 18, body = true, color = Theme.white, shadowY = 2,
    })
    Draw.pill(r.x + r.w / 2 - 60, r.y + r.h - 50, 120, 30, counts[i] .. " CARDS", {
        fill = Theme.white, textColor = Theme.inkText, size = 16,
    })
    love.graphics.pop()
end

local function arrowOn(b, dir)
    local style = Theme.button[b.variant]
    local ax = dir < 0 and (b.x + 30) or (b.x + b.w - 30)
    Draw.arrow(ax, b.y + b.lift + b.h / 2, 22, dir, style.text)
end

function DeckSelect.draw(selected)
    ensure()
    local W, H = 1280, 800
    local T = DeckSelect.TITLE
    Backdrop.draw(time, W, H, false)
    Draw.ribbon(W / 2, T.y, 460, T.h, "CHOOSE YOUR DECK", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 36,
    })
    -- unselected tiles first so the lifted tile overlaps its neighbours
    for i = 1, #DeckSelect.DECKS do
        if i ~= selected then drawTile(i, false) end
    end
    drawTile(selected, true)
    buttons.back:draw();    arrowOn(buttons.back, -1)
    buttons.kickoff:draw(); arrowOn(buttons.kickoff, 1)
    Draw.text("LEFT / RIGHT TO CHOOSE  ·  ENTER TO KICK OFF  ·  ESC TO GO BACK", 0, 604, W, "center", {
        size = 15, body = true, color = { 1, 1, 1, 0.85 }, shadowY = 1,
    })
end

return DeckSelect
```

- [ ] **Step 4: Run the checks and tests**

Run: `luac -p ui/menu/deckselect.lua && lua tests/run.lua`
Expected: no `luac` output; `104 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add ui/menu/deckselect.lua tests/test_deckselect.lua
git commit -m "Add deck select module with showcase fans"
```

---

### Task 5: Card library module

**Files:**
- Create: `ui/menu/library.lua`
- Test: `tests/test_library.lua`

- [ ] **Step 1: Write the failing test `tests/test_library.lua`**

```lua
local T       = require("tests.t")
local Library = require("ui.menu.library")

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

T.test("tabs run left to right without overlapping the close button or the grid", function()
    local tabs = Library.tabRects()
    T.eq(#tabs, 7); T.eq(tabs[1].key, "all"); T.eq(tabs[7].key, "strategy")
    for i = 2, #tabs do
        T.ok(tabs[i].x >= tabs[i - 1].x + tabs[i - 1].w + Library.TAB_GAP - 1e-9)
    end
    for _, t in ipairs(tabs) do
        T.ok(not overlap(t, Library.CLOSE)); T.ok(t.y + t.h <= Library.VIEW.y)
    end
end)

T.test("tabAt maps tab centres", function()
    for _, t in ipairs(Library.tabRects()) do
        T.eq(Library.tabAt(t.x + t.w / 2, t.y + t.h / 2), t.key)
    end
    T.eq(Library.tabAt(640, 400), nil)
end)

T.test("grid cells: 7 columns of hand-size cards, rows 212px apart", function()
    local a = Library.cellRect(1, 0)
    T.eq(a.x, 100); T.eq(a.y, 166); T.eq(a.w, 120); T.eq(a.h, 165)
    T.eq(Library.cellRect(7, 0).x, 1060)
    local b = Library.cellRect(8, 0); T.eq(b.x, 100); T.eq(b.y, 378)
    T.eq(Library.cellRect(8, 100).y, 278)
    T.ok(Library.cellRect(7, 0).x + 120 <= 1280 - 40)
end)

T.test("maxScroll / clampScroll", function()
    T.eq(Library.maxScroll(0), 0); T.eq(Library.maxScroll(7), 0)
    T.eq(Library.maxScroll(40), 638)
    T.eq(Library.clampScroll(-50, 40), 0)
    T.eq(Library.clampScroll(9999, 40), 638)
    T.eq(Library.clampScroll(300, 40), 300)
end)

T.test("cardAt only hits cards inside the grid viewport", function()
    T.eq(Library.cardAt(160, 250, 10, 0), 1)
    T.eq(Library.cardAt(260, 250, 10, 0), 2)
    T.eq(Library.cardAt(240, 250, 10, 0), nil)     -- gap between columns
    T.eq(Library.cardAt(160, 250, 0, 0), nil)
    T.eq(Library.cardAt(160, 160, 10, 80), 1)      -- visible part of a card scrolled half out
    T.eq(Library.cardAt(160, 140, 10, 80), nil)    -- same card, above the viewport
end)

T.test("filter keeps one card type", function()
    local cards = { { type = "striker" }, { type = "trap" }, { type = "striker" } }
    T.eq(#Library.filter(cards, "all"), 3)
    T.eq(#Library.filter(cards, "striker"), 2)
    T.eq(#Library.filter(cards, "keeper"), 0)
end)

T.test("input: wheel clamps, arrows cycle tabs, Esc and the close button close", function()
    Library.open()
    local f, s = Library.state(); T.eq(f, "all"); T.eq(s, 0)
    Library.wheelmoved(0, -1000)
    f, s = Library.state(); T.ok(s > 0, "all cards need scrolling")
    Library.wheelmoved(0, 1000)
    f, s = Library.state(); T.eq(s, 0)
    Library.keypressed("right"); f = Library.state(); T.eq(f, "striker")
    Library.keypressed("left"); Library.keypressed("left"); f = Library.state(); T.eq(f, "strategy")
    T.eq(Library.keypressed("escape"), "close")
    local C = Library.CLOSE
    T.eq(Library.mousepressed(C.x + 10, C.y + 10, 1), "close")
    local tab = Library.tabRects()[6]
    T.eq(Library.mousepressed(tab.x + 5, tab.y + 5, 1), nil)
    T.eq(Library.state(), "trap")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_library.lua (load error)`; then `104 passed, 1 failed`.

- [ ] **Step 3: Create `ui/menu/library.lua`**

```lua
-- Card library: pill tabs per card type, a scrollable grid of hand-size cards drawn with
-- the real card renderer, and the card zoom on hover (ui/match/zoom.lua). Layout,
-- filtering and scrolling are pure (unit-tested); update/draw use LÖVE.
-- Opened full-screen from the home menu and from the pause menu.
-- keypressed / mousepressed return "close" when the library should close.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Hover    = require("ui.match.hover")
local Zoom     = require("ui.match.zoom")
local Backdrop = require("ui.menu.backdrop")

local Library = {}

Library.TABS = {
    { key = "all",        label = "ALL"         },
    { key = "striker",    label = "STRIKERS"    },
    { key = "midfielder", label = "MIDFIELDERS" },
    { key = "defender",   label = "DEFENDERS"   },
    { key = "keeper",     label = "KEEPERS"     },
    { key = "trap",       label = "TRAPS"       },
    { key = "strategy",   label = "STRATEGIES"  },
}
Library.TAB_X, Library.TAB_Y, Library.TAB_H, Library.TAB_GAP = 40, 92, 40, 10
Library.COLS, Library.CARD_W, Library.CARD_H = 7, 120, 165
Library.COL_W, Library.ROW_H, Library.GRID_X = 160, 212, 100
Library.VIEW        = { x = 0, y = 150, w = 1280, h = 650 }
Library.TOP_PAD     = 16          -- room for the type tag above the first row
Library.CLOSE       = { x = 1196, y = 24, w = 52, h = 52 }
Library.SCROLL_STEP = 60

-- ── Pure layout ───────────────────────────────────────────────────────────────

function Library.tabRects()
    local out, x = {}, Library.TAB_X
    for i, t in ipairs(Library.TABS) do
        local w = 28 + 12 * #t.label
        out[i] = { x = x, y = Library.TAB_Y, w = w, h = Library.TAB_H, key = t.key, label = t.label }
        x = x + w + Library.TAB_GAP
    end
    return out
end

function Library.tabAt(x, y)
    for _, r in ipairs(Library.tabRects()) do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return r.key end
    end
    return nil
end

-- Screen rect of card i (1-based) at the given scroll offset.
function Library.cellRect(i, scroll)
    local col = (i - 1) % Library.COLS
    local row = math.floor((i - 1) / Library.COLS)
    return {
        x = Library.GRID_X + col * Library.COL_W,
        y = Library.VIEW.y + Library.TOP_PAD + row * Library.ROW_H - (scroll or 0),
        w = Library.CARD_W, h = Library.CARD_H,
    }
end

function Library.maxScroll(n)
    local rows = math.ceil(n / Library.COLS)
    return math.max(0, Library.TOP_PAD + rows * Library.ROW_H - Library.VIEW.h)
end

function Library.clampScroll(s, n)
    return math.max(0, math.min(Library.maxScroll(n), s))
end

-- Index of the card under (x, y); only inside the grid viewport.
function Library.cardAt(x, y, n, scroll)
    local V = Library.VIEW
    if y < V.y or y > V.y + V.h then return nil end
    for i = 1, n do
        local r = Library.cellRect(i, scroll)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

function Library.filter(cards, key)
    if key == "all" then return cards end
    local out = {}
    for _, c in ipairs(cards) do
        if c.type == key then out[#out + 1] = c end
    end
    return out
end

-- ── State ─────────────────────────────────────────────────────────────────────

local SOURCES = { "strikers", "midfielders", "defenders", "keepers", "traps", "strategies" }
local allDefs, filter, scroll = nil, "all", 0
local hover    = Hover.new()
local closeBtn = nil

local function allCards()
    if allDefs then return allDefs end
    allDefs = {}
    for _, f in ipairs(SOURCES) do
        for _, c in ipairs(require("engine.cards.definitions." .. f)) do allDefs[#allDefs + 1] = c end
    end
    return allDefs
end

local function visible() return Library.filter(allCards(), filter) end

local function setFilter(key)
    filter, scroll = key, 0
    hover:reset()
end

function Library.open() setFilter("all") end

-- Current tab key and scroll offset (tests, snapshot scenarios).
function Library.state() return filter, scroll end

-- ── Input ─────────────────────────────────────────────────────────────────────

function Library.keypressed(key)
    if key == "escape" then return "close" end
    local n = #visible()
    if key == "down" then
        scroll = Library.clampScroll(scroll + Library.SCROLL_STEP, n)
    elseif key == "up" then
        scroll = Library.clampScroll(scroll - Library.SCROLL_STEP, n)
    elseif key == "left" or key == "right" then
        local idx = 1
        for i, t in ipairs(Library.TABS) do
            if t.key == filter then idx = i end
        end
        idx = (idx - 1 + (key == "right" and 1 or -1)) % #Library.TABS + 1
        setFilter(Library.TABS[idx].key)
    end
    return nil
end

function Library.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    local C = Library.CLOSE
    if x >= C.x and x <= C.x + C.w and y >= C.y and y <= C.y + C.h then return "close" end
    local key = Library.tabAt(x, y)
    if key then setFilter(key) end
    return nil
end

function Library.wheelmoved(_, dy)
    scroll = Library.clampScroll(scroll - dy * Library.SCROLL_STEP, #visible())
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

function Library.update(dt, mx, my)
    if not closeBtn then
        local C = Library.CLOSE
        closeBtn = Button.new({ id = "close", label = "", variant = "danger", x = C.x, y = C.y, w = C.w, h = C.h })
    end
    mx, my = mx or -1, my or -1
    closeBtn:update(dt, mx, my, love.mouse.isDown(1))
    local cards = visible()
    local i = Library.cardAt(mx, my, #cards, scroll)
    if i then
        hover:update(dt, filter .. ":" .. i, { cardDef = cards[i], src = Library.cellRect(i, scroll) })
    else
        hover:update(dt, nil, nil)
    end
end

local function drawScrollbar(n)
    local maxS = Library.maxScroll(n)
    if maxS <= 0 then return end
    local V = Library.VIEW
    local trackX, trackY, trackH = 1262, V.y + 8, V.h - 16
    local thumbH = math.max(40, trackH * V.h / (V.h + maxS))
    local thumbY = trackY + (scroll / maxS) * (trackH - thumbH)
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35)
    love.graphics.rectangle("fill", trackX, trackY, 8, trackH, 4, 4)
    Draw.setColor(Theme.white)
    love.graphics.rectangle("fill", trackX, thumbY, 8, thumbH, 4, 4)
end

function Library.draw()
    local W, H = 1280, 800
    local cards = visible()
    Backdrop.draw(love.timer.getTime(), W, H, false)

    -- Header
    Draw.text("CARD LIBRARY", 40, 16, 700, "left", {
        size = 40, color = Theme.white, outline = 3, outlineColor = Theme.ink, shadowY = 4,
    })
    Draw.text("ESC TO CLOSE  ·  MOUSE WHEEL OR UP / DOWN TO SCROLL  ·  LEFT / RIGHT TO SWITCH TABS",
        40, 66, 900, "left", { size = 12, body = true, color = { 1, 1, 1, 0.85 } })
    Draw.pill(1040, 33, 140, 34, #cards .. " CARDS", { fill = Theme.white, textColor = Theme.inkText, size = 18 })

    -- Tabs (active one filled yellow)
    for _, r in ipairs(Library.tabRects()) do
        local active = r.key == filter
        Draw.pill(r.x, r.y, r.w, r.h, r.label, {
            fill = active and Theme.button.primary.fill or { 1, 1, 1, 0.18 },
            textColor = active and Theme.button.primary.text or Theme.white,
            size = 18, border = 3, shadow = active and 4 or 3,
        })
    end

    -- Grid (clipped to the viewport)
    local V = Library.VIEW
    local shownKey = hover:shown() and hover.key or nil
    love.graphics.setScissor(V.x, V.y, V.w, V.h)
    for i, c in ipairs(cards) do
        local r = Library.cellRect(i, scroll)
        if r.y + r.h + 30 > V.y and r.y - 30 < V.y + V.h then
            Card.drawFace(c, r.x, r.y, r.w, r.h, { selected = shownKey == (filter .. ":" .. i) })
        end
    end
    love.graphics.setScissor()
    if #cards == 0 then
        Draw.text("No cards in this category.", 0, 440, W, "center", { size = 24, shadowY = 2 })
    end
    drawScrollbar(#cards)

    -- Close button with a drawn ✕
    if closeBtn then
        closeBtn:draw()
        Draw.cross(closeBtn.x + closeBtn.w / 2, closeBtn.y + closeBtn.lift + closeBtn.h / 2, 20, Theme.white, 5)
    end

    -- Hover zoom
    if hover:shown() and hover.payload then
        Zoom.draw({ cardDef = hover.payload.cardDef, src = hover.payload.src, scale = 1 })
    end
end

return Library
```

- [ ] **Step 4: Run the checks and tests**

Run: `luac -p ui/menu/library.lua && lua tests/run.lua`
Expected: no `luac` output; `111 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add ui/menu/library.lua tests/test_library.lua
git commit -m "Add arcade card library module"
```

---

### Task 6: Wire the home scene, deck select and library

**Files:**
- Rewrite: `scenes/home.lua`
- Modify: `main.lua`, `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Delete: `ui/card_library.lua`

- [ ] **Step 1: Replace `scenes/home.lua` entirely**

```lua
-- Home scene router: home menu → deck select → match, plus the card library.
-- All layout and drawing lives in ui/menu/*; the state machine is ui/menu/flow.lua.
-- keypressed / mousepressed return "start", deckKey | "quit" | nil (see main.lua).
local Flow       = require("ui.menu.flow")
local HomeMenu   = require("ui.menu.home")
local DeckSelect = require("ui.menu.deckselect")
local Library    = require("ui.menu.library")

local Home = {}

local flow = Flow.new(#DeckSelect.DECKS)
local mouseX, mouseY = -1, -1
local lastHover = nil

-- Map a Flow action to main.lua's contract.
local function result(action, arg)
    if action == "start" then return "start", DeckSelect.DECKS[arg].key end
    if action == "quit" then return "quit" end
    if action == "openLibrary" then Library.open() end
    return nil
end

function Home.reset()
    flow = Flow.new(#DeckSelect.DECKS)
    lastHover = nil
end

function Home.update(dt)
    if flow.screen == "home" then
        -- hovering a button moves the keyboard focus to it
        local i = HomeMenu.buttonAt(mouseX, mouseY)
        if i ~= lastHover then
            lastHover = i
            if i then flow.home:set(i) end
        end
        HomeMenu.update(dt, mouseX, mouseY, flow.home.index)
    elseif flow.screen == "decks" then
        DeckSelect.update(dt, mouseX, mouseY, flow.decks.index)
    else
        Library.update(dt, mouseX, mouseY)
    end
end

function Home.draw()
    if flow.screen == "home" then
        HomeMenu.draw()
    elseif flow.screen == "decks" then
        DeckSelect.draw(flow.decks.index)
    else
        Library.draw()
    end
end

function Home.keypressed(key)
    if flow.screen == "library" then
        if Library.keypressed(key) == "close" then flow:closeLibrary() end
        return nil
    end
    return result(flow:key(key))
end

function Home.mousepressed(x, y, button)
    if flow.screen == "library" then
        if Library.mousepressed(x, y, button) == "close" then flow:closeLibrary() end
        return nil
    end
    if button ~= 1 then return nil end
    if flow.screen == "home" then
        local i = HomeMenu.buttonAt(x, y)
        if i then return result(flow:activateHome(i)) end
        return nil
    end
    local hit = DeckSelect.hitAt(x, y)
    if hit == "back" then return result(flow:back()) end
    if hit == "kickoff" then return result(flow:kickOff()) end
    if hit then return result(flow:clickDeck(hit)) end
    return nil
end

function Home.mousemoved(x, y) mouseX, mouseY = x, y end

function Home.wheelmoved(x, y)
    if flow.screen == "library" then Library.wheelmoved(x, y) end
end

return Home
```

- [ ] **Step 2: Replace `main.lua` entirely**

```lua
-- Football TCG — main.lua
math.randomseed(os.time())

local flux      = require("lib.flux")
local Theme     = require("ui.theme")
local Fonts     = require("ui.fonts")
local Home      = require("scenes.home")
local Match     = require("scenes.match")
local Store     = require("store.match")
local Decks     = require("data.presetDecks")
local Audio     = require("ui.audio")

local currentScene = "home"
local store        = Store.new()
local camera       = { x = 0, y = 0 }
local lastDeckKey  = nil        -- PLAY AGAIN restarts with the same deck
Match._camera      = camera

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function startMatch(deckKey)
    lastDeckKey = deckKey
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

-- Home scene result: "start", deckKey | "quit" | nil
local function onHome(action, deckKey)
    if action == "start" then startMatch(deckKey)
    elseif action == "quit" then love.event.quit() end
end

-- Match scene result: "home" | "restart" | nil
local function onMatch(action)
    if action == "home" then
        goHome()
    elseif action == "restart" then
        if lastDeckKey then startMatch(lastDeckKey) else goHome() end
    end
end

-- ── Love2D callbacks ──────────────────────────────────────────────────────────

function love.load()
    love.graphics.setFont(Fonts.get(16))
    Audio.load()
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

function love.update(dt)
    flux.update(dt)
    if currentScene == "home" then
        Home.update(dt)
    elseif currentScene == "match" then
        Match.update(dt)
    end
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
        onHome(Home.mousepressed(cx, cy, button))
    elseif currentScene == "match" then
        onMatch(Match.mousepressed(cx, cy, button))
    end
end

function love.mousemoved(x, y)
    local cx = x - math.floor(camera.x)
    local cy = y - math.floor(camera.y)
    if currentScene == "home" then
        Home.mousemoved(cx, cy)
    elseif currentScene == "match" then
        Match.mousemoved(cx, cy)
    end
end

function love.wheelmoved(x, y)
    if currentScene == "home" then Home.wheelmoved(x, y)
    elseif currentScene == "match" then Match.wheelmoved(x, y) end
end

function love.keypressed(key)
    if currentScene == "home" then
        onHome(Home.keypressed(key))
    elseif currentScene == "match" then
        onMatch(Match.keypressed(key))
    end
end
```

- [ ] **Step 3: Point the match scene at the new library.** In `scenes/match.lua`:
  - Replace `local CardLibrary   = require("ui.card_library")` with:

```lua
local CardLibrary   = require("ui.menu.library")
```

  - Replace the start of `Match.update`:

```lua
function Match.update(dt)
    if not store or not store.match then return end
    local match = store.match

```

with:

```lua
function Match.update(dt)
    if not store or not store.match then return end
    local match = store.match

    if libraryOpen then CardLibrary.update(dt, mouseX, mouseY) end

```

- [ ] **Step 4: Delete the old library**

Run: `grep -rn 'ui\.card_library' --include='*.lua' .`
Expected: no output.
Run: `git rm -q ui/card_library.lua`

- [ ] **Step 5: Update the snapshot scenarios.** In `tools/snapshot/scenarios.lua`:

Insert directly after the line `local function click(x, y) move(x, y); press(x, y) end`:

```lua

-- Home → PLAY → deck select → KICK OFF with the first deck (The Beautiful Game).
local function kickOff()
    love.keypressed("return")
    love.keypressed("return")
end
```

Replace the whole `S.home = { … }` and `S.library = { … }` blocks with:

```lua
-- Home menu, keyboard focus, deck select (two selections), back to home.
S.home = {
    { 1.0, function(c) c.snap("menu") end },
    { 1.1, function() love.keypressed("down") end },
    { 1.5, function(c) c.snap("focus") end },
    { 1.6, function() love.keypressed("up"); love.keypressed("return") end },
    { 2.2, function(c) c.snap("deck") end },
    { 2.3, function() love.keypressed("right") end },
    { 2.8, function(c) c.snap("deck2") end },
    { 2.9, function() love.keypressed("escape") end },
    { 3.2, function(c) c.snap("back") end },
    { 3.5, function(c) c.quit() end },
}

-- Card library from the home menu: grid, hover zoom, TRAPS tab, scrolled, closed.
S.library = {
    { 0.5, function() click(center(require("ui.menu.home").buttonRect(2))) end },
    { 1.2, function(c) c.snap("grid") end },
    { 1.3, function() move(center(require("ui.menu.library").cellRect(2, 0))) end },
    { 1.9, function(c) c.snap("hover") end },
    { 2.0, function() click(center(require("ui.menu.library").tabRects()[6])) end },
    { 2.5, function(c) c.snap("traps") end },
    { 2.6, function() for _ = 1, 5 do love.keypressed("left") end end },   -- back to ALL
    { 2.7, function() love.wheelmoved(0, -20) end },
    { 3.2, function(c) c.snap("scrolled") end },
    { 3.3, function() love.keypressed("escape") end },
    { 3.6, function(c) c.snap("closed") end },
    { 4.0, function(c) c.quit() end },
}
```

In `S.match`, `S.summon`, `S.juice` and `S.debug`, replace the step that presses `return` once with `{ 0.5, kickOff },`. The old step is `{ 0.5, function() love.keypressed("return") end },`; in `S.match` it ends with the comment `-- start with the first deck`.

Run: `grep -n 'keypressed("return")' tools/snapshot/scenarios.lua`
Expected: only the two lines inside `kickOff`.

- [ ] **Step 6: Syntax check, tests, snapshots**

Run: `luac -p scenes/home.lua main.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && for s in home library match summon; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected:
- no `luac` output;
- `111 passed, 0 failed`;
- PNGs listed: `home_back`, `home_deck`, `home_deck2`, `home_focus`, `home_menu`; `library_closed`, `library_grid`, `library_hover`, `library_scrolled`, `library_traps`; `match_start`, `match_later`; the 7 `summon_*`;
- no `FAILED` line and no Lua traceback.

- [ ] **Step 7: Review with the Read tool:**

- `home_menu.png`:
  - Blue→violet gradient with faint diagonal stripes.
  - Four faded, tilted card backs in the corners.
  - A yellow "FOOTBALL TCG" logo with a white outline and navy shadow, with a white circle holding a football icon to its left. The whole group is centred.
  - Three stacked buttons centred at x≈640 (×2 = 1280), y≈352–612: PLAY (yellow), CARD LIBRARY (blue, white text), QUIT (red).
  - A footer hint line near the bottom.
- `home_focus.png`: CARD LIBRARY has a white pulsing glow ring; PLAY has none.
- `home_deck.png`:
  - A yellow "CHOOSE YOUR DECK" ribbon at the top.
  - Three tiles: green "THE BEAUTIFUL GAME", red "DIRECT FOOTBALL", blue "THE WALL". Each has a navy subtitle pill, a description and a "40 CARDS" pill.
  - Three real cards fan above each tile, and only their tops are visible.
  - The left tile is lifted, slightly larger, with a yellow ring.
  - A white BACK button with a left triangle at the bottom-left; a green KICK OFF button with a right triangle at the bottom-right. There are no box glyphs.
- `home_deck2.png`: the middle (red) tile is now lifted with the yellow ring.
- `home_back.png`: the home menu again.
- `library_grid.png`:
  - "CARD LIBRARY" title top-left and a "34 CARDS" pill.
  - A red square close button with a white ✕ at the top-right.
  - Seven pill tabs, with ALL filled yellow.
  - A 7-column grid of real hand-size cards and a scrollbar on the right edge.
- `library_hover.png`: the second card has a yellow ring. A zoom card plus a white info sticker sits beside it, fully on screen.
- `library_traps.png`: the TRAPS tab is filled and only purple trap cards are shown.
- `library_scrolled.png`: ALL is active again and the grid is scrolled (the first row partly or fully gone, the scroll thumb moved down).
- `library_closed.png`: the home menu.
- `match_start.png`, `summon_*.png`: the match starts with the first deck exactly as before (same hand as the Plan B screenshots).

- [ ] **Step 8: Commit**

```bash
git add scenes/home.lua main.lua scenes/match.lua tools/snapshot/scenarios.lua
git commit -m "Wire arcade home menu, deck select and card library"
```

---

### Task 7: Pause menu

**Files:**
- Create: `ui/menu/pause.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Delete: `ui/pause_menu.lua`
- Test: `tests/test_pause.lua`

- [ ] **Step 1: Write the failing test `tests/test_pause.lua`**

```lua
local T     = require("tests.t")
local Pause = require("ui.menu.pause")

T.test("pause buttons sit centred inside the panel without overlapping", function()
    local P = Pause.PANEL
    local prev
    for i = 1, #Pause.ITEMS do
        local r = Pause.buttonRect(i)
        T.ok(r.x >= P.x and r.x + r.w <= P.x + P.w and r.y >= P.y and r.y + r.h <= P.y + P.h)
        T.near(r.x + r.w / 2, P.x + P.w / 2)
        if prev then T.ok(r.y >= prev.y + prev.h) end
        prev = r
    end
    T.near(P.x + P.w / 2, 640); T.near(P.y + P.h / 2, 400)
end)

T.test("actionAt maps button centres to actions", function()
    local want = { "resume", "library", "home" }
    for i = 1, 3 do
        local r = Pause.buttonRect(i)
        T.eq(Pause.actionAt(r.x + r.w / 2, r.y + r.h / 2), want[i])
    end
    T.eq(Pause.actionAt(10, 10), nil)
    T.eq(Pause.mousepressed(10, 10, 1), nil)
end)

T.test("keyboard: Esc resumes, arrows move focus (wrapping), Enter activates", function()
    Pause.open()
    T.eq(Pause.keypressed("escape"), "resume")
    T.eq(Pause.focus(), 1)
    Pause.keypressed("down"); T.eq(Pause.keypressed("return"), "library")
    Pause.keypressed("up"); Pause.keypressed("up"); T.eq(Pause.focus(), 3)
    T.eq(Pause.keypressed("kpenter"), "home")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_pause.lua (load error)`; then `111 passed, 1 failed`.

- [ ] **Step 3: Create `ui/menu/pause.lua`**

```lua
-- Pause menu: navy dim, a white sticker panel that pops in with a bounce, a PAUSED ribbon,
-- and RESUME / CARD LIBRARY / QUIT TO MENU. Layout, focus and input mapping are pure
-- (unit-tested); update/draw use LÖVE. Actions: "resume" | "library" | "home".
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Button = require("ui.kit.button")
local Tween  = require("ui.kit.tween")
local Nav    = require("ui.menu.nav")

local Pause = {}

Pause.ITEMS = {
    { action = "resume",  label = "RESUME",       variant = "go"     },
    { action = "library", label = "CARD LIBRARY", variant = "blue"   },
    { action = "home",    label = "QUIT TO MENU", variant = "danger" },
}
Pause.PANEL = { x = 440, y = 232, w = 400, h = 336 }
Pause.BTN_W, Pause.BTN_H, Pause.BTN_GAP, Pause.BTN_TOP = 300, 64, 20, 64

function Pause.buttonRect(i)
    local P = Pause.PANEL
    return { x = P.x + (P.w - Pause.BTN_W) / 2, y = P.y + Pause.BTN_TOP + (i - 1) * (Pause.BTN_H + Pause.BTN_GAP),
             w = Pause.BTN_W, h = Pause.BTN_H }
end

function Pause.indexAt(x, y)
    for i = 1, #Pause.ITEMS do
        local r = Pause.buttonRect(i)
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return i end
    end
    return nil
end

function Pause.actionAt(x, y)
    local i = Pause.indexAt(x, y)
    return i and Pause.ITEMS[i].action or nil
end

local nav       = Nav.new(#Pause.ITEMS, { wrap = true })
local pop       = { scale = 1 }
local buttons   = nil
local lastHover = nil

-- Call whenever the menu opens: resets focus and replays the pop-in.
function Pause.open()
    nav = Nav.new(#Pause.ITEMS, { wrap = true })
    lastHover = nil
    Tween.popIn(pop, 0.35)
end

function Pause.focus() return nav.index end

function Pause.keypressed(key)
    if key == "escape" then return "resume" end
    if key == "up" then
        nav:move(-1)
    elseif key == "down" then
        nav:move(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        return Pause.ITEMS[nav.index].action
    end
    return nil
end

function Pause.mousepressed(x, y, button)
    if button ~= 1 then return nil end
    return Pause.actionAt(x, y)
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local function ensure()
    if buttons then return end
    buttons = {}
    for i, it in ipairs(Pause.ITEMS) do
        local r = Pause.buttonRect(i)
        buttons[i] = Button.new({ id = it.action, label = it.label, variant = it.variant, fontSize = 28,
            x = r.x, y = r.y, w = r.w, h = r.h })
    end
end

function Pause.update(dt, mx, my)
    ensure()
    local hovered = Pause.indexAt(mx or -1, my or -1)
    if hovered ~= lastHover then
        lastHover = hovered
        if hovered then nav:set(hovered) end
    end
    local down = love.mouse.isDown(1)
    for i, b in ipairs(buttons) do
        b.focused = (i == nav.index)
        b:update(dt, mx or -1, my or -1, down)
    end
end

function Pause.draw()
    ensure()
    local P = Pause.PANEL
    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, 1280, 800)
    local cx, cy = P.x + P.w / 2, P.y + P.h / 2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(pop.scale, pop.scale)
    love.graphics.translate(-cx, -cy)
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 26, fill = Theme.white, border = 0, shadow = 8 })
    Draw.ribbon(cx, P.y - 30, 280, 60, "PAUSED", {
        fill = Theme.button.primary.fill, textColor = Theme.button.primary.text, size = 38,
    })
    for _, b in ipairs(buttons) do b:draw() end
    love.graphics.pop()
    Draw.text("ESC TO RESUME", 0, P.y + P.h + 22, 1280, "center", {
        size = 14, body = true, color = Theme.white, shadowY = 1,
    })
end

return Pause
```

- [ ] **Step 4: Wire it into `scenes/match.lua`.**
  - Replace `local PauseMenu     = require("ui.pause_menu")` with:

```lua
local PauseMenu     = require("ui.menu.pause")
```

  - In `Match.update`, replace:

```lua
    if libraryOpen then CardLibrary.update(dt, mouseX, mouseY) end
```

with:

```lua
    if libraryOpen then CardLibrary.update(dt, mouseX, mouseY) end
    if pauseOpen and not libraryOpen then PauseMenu.update(dt, mouseX, mouseY) end
```

  - Insert directly above the line `function Match.mousepressed(x, y, button)`:

```lua
local function openPause()
    pauseOpen = true
    PauseMenu.open()
end

```

  - In `Match.mousepressed`, replace `    if btn == "pause" then pauseOpen = true; return end` with:

```lua
    if btn == "pause" then openPause(); return end
```

  - In `Match.keypressed`, replace `        else pauseOpen = true end` with:

```lua
        else openPause() end
```

- [ ] **Step 5: Delete the old pause menu**

Run: `grep -rn 'ui\.pause_menu' --include='*.lua' .`
Expected: no output.
Run: `git rm -q ui/pause_menu.lua`

- [ ] **Step 6: Add the `pause` scenario.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Pause menu: pop-in, keyboard focus, CARD LIBRARY from pause, back, RESUME by click.
S.pause = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function() love.keypressed("escape") end },
    { 1.6, function(c) c.snap("pop") end },
    { 2.1, function(c) c.snap("menu") end },
    { 2.2, function() love.keypressed("down") end },
    { 2.5, function(c) c.snap("focus") end },
    { 2.6, function() love.keypressed("return") end },       -- CARD LIBRARY
    { 3.2, function(c) c.snap("library") end },
    { 3.3, function() love.keypressed("escape") end },       -- back to the pause menu
    { 3.6, function(c) c.snap("back") end },
    { 3.7, function() click(center(require("ui.menu.pause").buttonRect(1))) end },   -- RESUME
    { 4.1, function(c) c.snap("resumed") end },
    { 4.5, function(c) c.quit() end },
}
```

- [ ] **Step 7: Syntax check, tests, snapshots**

Run: `luac -p ui/menu/pause.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && tools/snapshot/snap.sh pause && tools/snapshot/snap.sh debug`
Expected: no `luac` output; `114 passed, 0 failed`; `pause_back`, `pause_focus`, `pause_library`, `pause_menu`, `pause_pop`, `pause_resumed` and the 4 `debug_*` PNGs listed; no Lua error.

- [ ] **Step 8: Review with the Read tool:**

- `pause_pop.png`: navy dim over the match, and a white panel that is visibly smaller than full size (popping in).
- `pause_menu.png`:
  - A white panel centred on screen, 400×336 (×2 = 800×672).
  - A yellow "PAUSED" ribbon straddling its top edge.
  - Green RESUME (focused, with a white glow), blue CARD LIBRARY, red QUIT TO MENU.
  - "ESC TO RESUME" under the panel.
- `pause_focus.png`: the glow has moved to CARD LIBRARY.
- `pause_library.png`: the arcade card library, full screen, covering the match.
- `pause_back.png`: the pause menu again.
- `pause_resumed.png`: the match screen with no dim.
- `debug_pause.png`: the new pause menu. `debug_resumed.png` shows the plain match.

- [ ] **Step 9: Commit**

```bash
git add ui/menu/pause.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_pause.lua
git commit -m "Restyle pause menu as a pop-in sticker panel"
```

---

### Task 8: Combat overlay timeline and effects (pure)

**Files:**
- Create: `ui/overlay/combatfx.lua`
- Test: `tests/test_combatfx.lua`

- [ ] **Step 1: Write the failing test `tests/test_combatfx.lua`**

```lua
local T  = require("tests.t")
local Fx = require("ui.overlay.combatfx")

T.test("cards slide in from both sides and land with a squash", function()
    local p = Fx.pose(0)
    T.near(p.atkX, -Fx.SLIDE_DIST); T.near(p.defX, Fx.SLIDE_DIST); T.eq(p.sx, 1); T.eq(p.sy, 1)
    p = Fx.pose(Fx.SLIDE)
    T.near(p.atkX, 0); T.near(p.defX, 0)
    T.ok(p.sx > 1.1 and p.sy < 0.9, "squashed on landing")
    p = Fx.pose(Fx.SLIDE + Fx.SQUASH + 0.01)
    T.near(p.sx, 1); T.near(p.sy, 1)
end)

T.test("defender flips and the clash starts at CLASH, with a decaying shake", function()
    T.ok(not Fx.pose(Fx.CLASH - 0.01).reveal); T.ok(Fx.pose(Fx.CLASH).reveal)
    T.eq(Fx.pose(Fx.CLASH - 0.01).clash, 0)
    T.near(Fx.flip(0), 1); T.near(Fx.flip(Fx.CLASH), 0, 1e-9); T.near(Fx.flip(Fx.CLASH + Fx.FLIP), 1)
    T.eq(Fx.shake(Fx.CLASH - 0.01), 0); T.eq(Fx.shake(Fx.CLASH + Fx.CLASH_DUR + 0.01), 0)
    local peak = 0
    for t = Fx.CLASH, Fx.CLASH + Fx.CLASH_DUR, 0.005 do peak = math.max(peak, math.abs(Fx.shake(t))) end
    T.ok(peak > 3 and peak <= Fx.SHAKE, "shake peak " .. peak)
end)

T.test("badges count up, then the result, then the hint", function()
    local p = Fx.pose(Fx.COUNT - 0.01)
    T.eq(p.badge, 0); T.near(p.count, 0)
    p = Fx.pose(Fx.COUNT + Fx.COUNT_DUR)
    T.near(p.count, 1); T.ok(p.badge > 0.9)
    T.eq(Fx.pose(Fx.RESULT - 0.01).result, 0); T.near(Fx.pose(Fx.RESULT + Fx.RESULT_DUR).result, 1)
    T.near(Fx.pose(Fx.HINT - 0.01).hint, 0); T.near(Fx.pose(Fx.HINT + 0.25).hint, 1)
    T.ok(Fx.SLIDE < Fx.CLASH and Fx.CLASH < Fx.COUNT and Fx.COUNT < Fx.RESULT and Fx.RESULT < Fx.HINT)
    T.eq(Fx.countValue(2300, 0), 0); T.eq(Fx.countValue(2300, 0.5), 1150); T.eq(Fx.countValue(2300, 1), 2300)
end)

T.test("phase names and crossed marks", function()
    T.eq(Fx.phase(0), "enter"); T.eq(Fx.phase(Fx.SLIDE + 0.01), "land"); T.eq(Fx.phase(Fx.CLASH), "clash")
    T.eq(Fx.phase(Fx.COUNT), "count"); T.eq(Fx.phase(Fx.RESULT), "result")
    T.ok(Fx.crossed(0.5, 0.6, 0.55)); T.ok(Fx.crossed(0.5, 0.55, 0.55))
    T.ok(not Fx.crossed(0.55, 0.6, 0.55)); T.ok(not Fx.crossed(0.1, 0.2, 0.55))
end)

T.test("result ribbons are colour-coded by outcome", function()
    local O = require("ui.theme").outcome
    local r = Fx.result("defender_destroyed", 0); T.eq(r.text, "DESTROYED"); T.eq(r.fill, O.red)
    T.eq(Fx.result("defender_destroyed", 300).text, "DESTROYED · LP -300")
    r = Fx.result("defender_exhausted"); T.eq(r.text, "EXHAUSTED");    T.eq(r.fill, O.orange)
    r = Fx.result("attacker_exhausted"); T.eq(r.text, "BLOCKED");      T.eq(r.fill, O.blue)
    r = Fx.result("save");               T.eq(r.text, "KEEPER SAVES"); T.eq(r.fill, O.blue)
    r = Fx.result("damage", 500);        T.eq(r.text, "LP DAMAGE -500"); T.eq(r.fill, O.yellow)
    r = Fx.result("tie");                T.eq(r.text, "TIE");          T.eq(r.fill, O.grey)
    T.eq(Fx.result("weird").text, "WEIRD")
end)

T.test("fates: who is destroyed or exhausted", function()
    local a, d = Fx.fates("defender_destroyed"); T.eq(a, nil); T.eq(d, "destroyed")
    a, d = Fx.fates("defender_exhausted"); T.eq(d, "exhausted")
    a, d = Fx.fates("attacker_exhausted"); T.eq(a, "exhausted"); T.eq(d, nil)
    a, d = Fx.fates("tie"); T.eq(a, "exhausted"); T.eq(d, "exhausted")
    a, d = Fx.fates("damage"); T.eq(a, nil); T.eq(d, nil)
end)

T.test("cardView: badge totals equal the snapshot; keeper shows its effective-DEF bonus", function()
    local keeper = { id = "k", name = "Iron Fists", type = "keeper", rarity = "rare", stats = { atk = 300, def = 1800 } }
    local function lookup(name, t) if name == "Iron Fists" and t == "keeper" then return keeper end end
    local v = Fx.cardView({ name = "Iron Fists", type = "keeper", atk = 300, def = 2250,
                            atkBonus = 0, defBonus = 0, isKeeper = true }, lookup)
    T.eq(v.cardDef, keeper); T.eq(v.defBonus, 450); T.eq(v.stats.def, 1800); T.eq(v.def, 2250)
    v = Fx.cardView({ name = "X", type = "striker", atk = 2500, def = 600, atkBonus = 200, defBonus = 0 }, lookup)
    T.eq(v.cardDef.name, "X"); T.eq(v.stats.atk, 2300); T.eq(v.atkBonus, 200)
    T.eq(Fx.cardView(nil, lookup), nil)
    T.eq(Fx.lookup("Iron Fists", "keeper").id, "keeper-iron-fists")
end)

T.test("shatter pieces tile the card exactly and are deterministic", function()
    local ps = Fx.shatterPieces(280, 354, 3, 2, 7)
    T.eq(#ps, 6)
    local area = 0
    for _, p in ipairs(ps) do
        area = area + p.w * p.h
        T.ok(p.sx >= 0 and p.sy >= 0 and p.sx + p.w <= 280 + 1e-9 and p.sy + p.h <= 354 + 1e-9)
    end
    T.near(area, 280 * 354, 1e-6)
    local again = Fx.shatterPieces(280, 354, 3, 2, 7)
    for i, p in ipairs(ps) do T.eq(again[i].vx, p.vx); T.eq(again[i].spin, p.spin) end
end)

T.test("shatter pieces fly outward and fade", function()
    local ps = Fx.shatterPieces(300, 200, 3, 2, 3)
    T.ok(ps[1].vx < 0 and ps[3].vx > 0, "left/right pieces fly left/right")
    T.ok(ps[1].vy < 0, "everything pops upward first")
    local dx, dy, rot, a = Fx.piecePose(ps[1], 0)
    T.eq(dx, 0); T.eq(dy, 0); T.eq(rot, 0); T.eq(a, 1)
    dx, dy, rot, a = Fx.piecePose(ps[1], 1)
    T.ok(dx < 0); T.eq(a, 0)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_combatfx.lua (load error)`; then `114 passed, 1 failed`.

- [ ] **Step 3: Create `ui/overlay/combatfx.lua`**

```lua
-- Combat overlay timeline and effects. Pure (unit-tested): time → pose, outcome styling,
-- card views built from combat snapshots, shatter pieces. ui/overlay/combat.lua draws
-- from these; scenes/match.lua advances the time and fires the LP banner at CLASH.
local Theme = require("ui.theme")

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

-- Everything the overlay needs at time t.
function Fx.pose(t)
    local p = {}
    local slide = Fx.backout(Fx.progress(t, 0, Fx.SLIDE))
    p.atkX = -(1 - slide) * Fx.SLIDE_DIST
    p.defX =  (1 - slide) * Fx.SLIDE_DIST
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
    if outcome == "tie" then return "exhausted", "exhausted" end
    return nil, nil
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
--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def } | nil
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
```

- [ ] **Step 4: Run the tests**

Run: `lua tests/run.lua`
Expected: `123 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add ui/overlay/combatfx.lua tests/test_combatfx.lua
git commit -m "Add combat overlay timeline, outcome styles and shatter pieces"
```

---

### Task 9: Arcade combat overlay

**Files:**
- Create: `ui/overlay/combat.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Delete: `ui/combat_overlay.lua`

- [ ] **Step 1: Create `ui/overlay/combat.lua`**

```lua
-- Combat overlay (arcade). Behaviour and data contract unchanged:
--   rec = { attacker, defender, outcome, margin, damage, activePlayer }   (store:_pushCombat)
--   attacker / defender = { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper }
-- CombatOverlay.draw(rec, t): t = seconds since the overlay opened. All timing lives in
-- ui/overlay/combatfx.lua (pure, unit-tested).
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local Fx    = require("ui.overlay.combatfx")

local CombatOverlay = {}

local W, H      = 1280, 800
local CW, CH    = 200, 274          -- zoom card size (ui/match/zoom.lua)
local CARD_Y    = 150
local ATK_CX    = 390
local DEF_CX    = 890
local BADGE_Y   = 540
local BADGE_S   = 96
local PAD       = 40                -- canvas margin (tag, badges, glow) for the shatter
local BEAM_TINT = Theme.hex("ffe14a")

local beams = nil
local function loadBeams()
    if beams then return end
    beams = {}
    for i = 1, 4 do
        local ok, img = pcall(love.graphics.newImage, "assets/beams/beam" .. i .. ".png")
        if ok then beams[#beams + 1] = img end
    end
end

local cache   = { rec = nil }       -- card views for the current record
local shatter = { view = nil }      -- canvas + pieces for the destroyed card

local function drawFace(view, x, y, exhausted)
    Card.drawFace(view.cardDef, x, y, CW, CH, {
        stats     = view.stats,
        atkBonus  = view.atkBonus > 0 and view.atkBonus or nil,
        defBonus  = view.defBonus > 0 and view.defBonus or nil,
        exhausted = exhausted or nil,
    })
end

-- Render the card once into a canvas and cut it into pieces.
local function buildShatter(view)
    if shatter.canvas then shatter.canvas:release() end
    local cw, ch = CW + PAD * 2, CH + PAD * 2
    local canvas = love.graphics.newCanvas(cw, ch)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    drawFace(view, PAD, PAD, false)
    love.graphics.setCanvas()
    love.graphics.pop()
    shatter.view, shatter.canvas = view, canvas
    shatter.pieces = Fx.shatterPieces(cw, ch, 3, 2, 7)
    shatter.quads = {}
    for i, pc in ipairs(shatter.pieces) do
        shatter.quads[i] = love.graphics.newQuad(pc.sx, pc.sy, pc.w, pc.h, cw, ch)
    end
end

local function drawShatter(view, cx, k)
    if shatter.view ~= view then buildShatter(view) end
    local ox, oy = cx - CW / 2 - PAD, CARD_Y - PAD
    love.graphics.setBlendMode("alpha", "premultiplied")
    for i, pc in ipairs(shatter.pieces) do
        local dx, dy, rot, a = Fx.piecePose(pc, k)
        love.graphics.setColor(a, a, a, a)
        love.graphics.draw(shatter.canvas, shatter.quads[i],
            ox + pc.sx + pc.w / 2 + dx, oy + pc.sy + pc.h / 2 + dy, rot, 1, 1, pc.w / 2, pc.h / 2)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

-- One combatant centred on cx. fate: "destroyed" | "exhausted" | nil.
local function drawSide(view, cx, p, fate)
    local x, y = cx - CW / 2, CARD_Y
    if not view then
        Draw.roundedFill(x, y, CW, CH, 24, { 1, 1, 1, 0.12 })
        Draw.text("EMPTY", x, y + CH / 2 - 16, CW, "center", { size = 28, color = { 1, 1, 1, 0.6 } })
        return
    end
    if fate == "destroyed" and p.shatter > 0 then
        drawShatter(view, cx, p.shatter)
        return
    end
    local flip = view.hidden and p.flip or 1
    love.graphics.push()
    love.graphics.translate(cx, y + CH)              -- squash / flip anchored at the bottom centre
    love.graphics.scale(p.sx * flip, p.sy)
    love.graphics.translate(-cx, -(y + CH))
    if view.hidden and not p.reveal then
        Card.drawBack(x, y, CW, CH, { label = "DEF" })
    else
        drawFace(view, x, y, fate == "exhausted" and p.result > 0)
    end
    love.graphics.pop()
end

-- Tinted beam sprite between the two card centres (the cards cover its ends).
local function drawBeam(rec, p, ax, dx)
    if p.beam <= 0 or not rec.attacker or not rec.defender then return end
    loadBeams()
    if #beams == 0 then return end
    local img = beams[math.floor(love.timer.getTime() * 12) % #beams + 1]
    local iw, ih = img:getDimensions()
    local span = dx - ax
    local s = span / iw
    local atk, def = rec.attacker.atk or 0, rec.defender.def or 0
    local push = (atk - def) / math.max(atk + def, 1) * span * 0.18 * p.push
    love.graphics.setScissor(ax, 0, span, H)
    love.graphics.setBlendMode("add")
    Draw.setColor(BEAM_TINT, p.beam)
    love.graphics.draw(img, ax + push, CARD_Y + CH / 2 - ih * s / 2, 0, s, s)
    love.graphics.setBlendMode("alpha")
    love.graphics.setScissor()
end

-- VS badge before the clash, then the CLASH! starburst.
local function drawClash(p)
    local cx, cy = W / 2 + p.shake, CARD_Y + CH / 2
    if not p.reveal then
        Draw.setColor(Theme.ink);   love.graphics.circle("fill", cx, cy + 5, 42, 40)
        Draw.setColor(Theme.white); love.graphics.circle("fill", cx, cy, 42, 40)
        Draw.text("VS", cx - 42, cy - 21, 84, "center", { size = 38, color = Theme.inkText })
        return
    end
    local s = p.clash
    if s <= 0 then return end
    Draw.burst(cx, cy, 118 * s, 76 * s, 14, Theme.highlight.selected, 1, love.timer.getTime() * 0.5)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-0.08)
    love.graphics.scale(s, s)
    Draw.text("CLASH!", -130, -28, 260, "center", {
        size = 52, color = Theme.white, outline = 3, outlineColor = Theme.ink, shadowY = 4,
    })
    love.graphics.pop()
end

-- Big ATK / DEF badges that grow and count up, with their labels.
local function drawBadges(rec, p)
    if p.badge <= 0 then return end
    local s = BADGE_S * p.badge
    local labelY = BADGE_Y + BADGE_S / 2 + 12
    local a, d = cache.atk, cache.def
    if a then
        local x = ATK_CX + p.shake
        Draw.atkBadge(x, BADGE_Y, s, Fx.countValue(a.atk, p.count))
        Draw.pill(x - 60, labelY, 120, 28, a.atkBonus > 0 and ("ATK +" .. a.atkBonus .. " MID") or "ATK", {
            fill = Theme.white, textColor = Theme.grad.atk[2], size = 16, border = 2, shadow = 3,
        })
    end
    if d then
        local x = DEF_CX + p.shake
        Draw.defBadge(x, BADGE_Y, s * 0.95, Fx.countValue(d.def, p.count), d.defBonus > 0 and d.defBonus or nil)
        Draw.pill(x - 60, labelY, 120, 28, rec.defender.isKeeper and "EFF. DEF" or "DEF", {
            fill = Theme.white, textColor = Theme.grad.def[2], size = 16, border = 2, shadow = 3,
        })
    end
end

function CombatOverlay.draw(rec, t)
    if not rec then return end
    if cache.rec ~= rec then
        cache = { rec = rec, atk = Fx.cardView(rec.attacker, Fx.lookup), def = Fx.cardView(rec.defender, Fx.lookup) }
    end
    local p = Fx.pose(t or 0)
    local atkFate, defFate = Fx.fates(rec.outcome)

    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local mine = rec.activePlayer ~= "opponent"
    Draw.pill(W / 2 - 160, 44, 320, 46, mine and "YOU ATTACK!" or "OPPONENT ATTACKS!", {
        fill = mine and Theme.button.primary.fill or Theme.outcome.red,
        textColor = mine and Theme.button.primary.text or Theme.white, size = 26, border = 3, shadow = 4,
    })

    local ax = ATK_CX + p.atkX + p.shake
    local dx = DEF_CX + p.defX + p.shake
    drawBeam(rec, p, ax, dx)
    drawSide(cache.atk, ax, p, atkFate)
    drawSide(cache.def, dx, p, defFate)
    drawClash(p)
    drawBadges(rec, p)

    if p.result > 0 then
        local st = Fx.result(rec.outcome, rec.damage)
        local cy = 682
        love.graphics.push()
        love.graphics.translate(W / 2, cy)
        love.graphics.scale(p.result, p.result)
        love.graphics.translate(-W / 2, -cy)
        Draw.ribbon(W / 2, cy - 32, 540, 64, st.text, {
            fill = st.fill, textColor = st.textColor, size = 38, textShadow = st.shadow,
        })
        love.graphics.pop()
    end
    if p.hint > 0 then Draw.hintPill(W / 2, 744, "CLICK OR SPACE", p.hint) end
end

return CombatOverlay
```

- [ ] **Step 2: Wire it into `scenes/match.lua`.**
  - Replace `local CombatOverlay      = require("ui.combat_overlay")` with:

```lua
local CombatOverlay      = require("ui.overlay.combat")
local CombatFx           = require("ui.overlay.combatfx")
```

  - Replace the whole `local overlayAnim = { … }` table (from `local overlayAnim = {` through its closing `}`) with:

```lua
local combatT     = 0   -- seconds since the active combat overlay opened (ui/overlay/combatfx.lua)
```

  - In `Match.enter`, directly after `    activeCombat        = nil`, add:

```lua
    combatT             = 0
```

  - In `Match.update`, replace the whole block that starts with `    if not activeCombat and #combatQueue > 0 then` and ends with the `    end` directly above `    -- Dequeue a trap activation overlay (only when no combat overlay is blocking)`. That block is the one containing the `-- Phase 1`, `-- Phase 2` and `-- Phase 3` flux tweens. Replace it with:

```lua
    -- Combat overlay: dequeue, then advance its timeline (ui/overlay/combatfx.lua).
    if not activeCombat and #combatQueue > 0 then
        activeCombat = table.remove(combatQueue, 1)
        combatT = 0
    end
    if activeCombat then
        local prevT = combatT
        combatT = combatT + dt
        -- LP damage: banner + confetti when the cards clash
        if CombatFx.crossed(prevT, combatT, CombatFx.CLASH)
           and activeCombat.damage and activeCombat.damage > 0 then
            Match.onLPDamage(match.activePlayer, activeCombat.outcome == "damage")
        end
    end

```

  - In `Match.draw`, replace `        CombatOverlay.draw(activeCombat, overlayAnim)` with:

```lua
        CombatOverlay.draw(activeCombat, combatT)
```

  - Directly after `function Match.debugStore() return store end`, add:

```lua

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
```

- [ ] **Step 3: Delete the old overlay**

Run: `grep -rn 'overlayAnim\|ui\.combat_overlay\|CombatOverlay\.snapshot' --include='*.lua' . | grep -v '^./ui/combat_overlay.lua'`
Expected: no output.
Run: `git rm -q ui/combat_overlay.lua`

- [ ] **Step 4: Add the scenario helpers and the `combat` scenario.** In `tools/snapshot/scenarios.lua`, insert directly after the `firstOf` function:

```lua

-- Card definition by id (synthetic overlay records).
local function defById(id)
    for _, f in ipairs({ "strikers", "midfielders", "defenders", "keepers", "traps", "strategies" }) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do
            if d.id == id then return d end
        end
    end
    error("no card " .. id)
end

-- Combat snapshot like store:_snapshotAttack, from a card id plus overrides.
local function snapFrom(id, over)
    local d = defById(id)
    local s = { name = d.name, type = d.type, mode = "attack", wasHidden = false,
                atk = d.stats.atk, def = d.stats.def, atkBonus = 0, defBonus = 0, isKeeper = false }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end
```

and directly above `return S`:

```lua
-- Combat overlay: destroyed (face-down defender flips, shatter), keeper save (Eff. DEF
-- bonus tag), LP damage. Synthetic records via Match.debugOverlay (harness-only).
local function combat(rec) return function() require("scenes.match").debugOverlay("combat", rec) end end
S.combat = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, combat({
        attacker = snapFrom("str-clinical-finisher", { atk = 2500, atkBonus = 200 }),
        defender = snapFrom("def-destroyer", { mode = "defense", wasHidden = true }),
        outcome = "defender_destroyed", margin = 600, damage = 0, activePlayer = "player" }) },
    { 1.65, function(c) c.snap("slide") end },
    { 2.2,  function(c) c.snap("clash") end },
    { 2.5,  function(c) c.snap("count") end },
    { 3.0,  function(c) c.snap("shatter") end },
    { 3.6,  function(c) c.snap("destroyed") end },
    { 3.7,  function() love.keypressed("space") end },
    { 3.8,  combat({
        attacker = snapFrom("str-poacher"),
        defender = snapFrom("keeper-iron-fists", { def = 2250, isKeeper = true }),
        outcome = "save", margin = -250, damage = 0, activePlayer = "opponent" }) },
    { 5.9,  function(c) c.snap("save") end },
    { 6.0,  function() love.keypressed("space") end },
    { 6.1,  combat({
        attacker = snapFrom("str-speed-demon"),
        defender = snapFrom("keeper-reliable-hands", { isKeeper = true }),
        outcome = "damage", margin = 500, damage = 500, activePlayer = "player" }) },
    { 8.2,  function(c) c.snap("damage") end },
    { 8.3,  function() love.keypressed("space") end },
    { 8.6,  function(c) c.snap("dismissed") end },
    { 8.9,  function(c) c.quit() end },
}
```

- [ ] **Step 5: Syntax check, tests, snapshots**

Run: `luac -p ui/overlay/combat.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && tools/snapshot/snap.sh combat && tools/snapshot/snap.sh summon`
Expected: no `luac` output; `123 passed, 0 failed`; the 8 `combat_*` PNGs and the 7 `summon_*` PNGs listed; no Lua error.

- [ ] **Step 6: Review with the Read tool:**

- `combat_slide.png`:
  - A navy dim over the match and a yellow "YOU ATTACK!" pill at the top.
  - Two zoom-size cards partway in from the left and right edges.
  - A white "VS" circle in the centre.
- `combat_clash.png`:
  - Attacker "Clinical Finisher" (red striker card) at x≈390 (×2 = 780), with a +200 bonus tag on its ATK badge.
  - The defender is mid-flip (narrow) or already showing "The Destroyer".
  - A yellow starburst with a white rim and "CLASH!" in the middle.
  - A yellow-tinted beam between the cards, behind them.
- `combat_count.png`:
  - A red ATK circle and a blue DEF shield under the cards, with numbers partway up (below 2500 / 1900).
  - An "ATK +200 MID" label and a "DEF" label.
- `combat_shatter.png`:
  - The defender card is broken into about 6 pieces flying apart and fading.
  - A red "DESTROYED" ribbon, and the badges read 2500 / 1900.
- `combat_destroyed.png`: the defender pieces are gone (or nearly transparent), and a white "CLICK OR SPACE" pill with a drawn right triangle sits at the bottom.
- `combat_save.png`:
  - A red "OPPONENT ATTACKS!" pill.
  - The keeper "Iron Fists" card shows a green "+450" tag on its DEF badge.
  - The big DEF shield reads 2250 with a green "+450" tag above it and an "EFF. DEF" label.
  - A blue "KEEPER SAVES" ribbon.
- `combat_damage.png`: a yellow "LP DAMAGE -500" ribbon with dark-brown text.
- `combat_dismissed.png`: the plain match, with the green "GOAL!" banner still visible or fading.
- `summon_aiturn.png` / `summon_myturn.png`: AI combats were dismissed by `advance()` (no overlay stuck on screen).

- [ ] **Step 7: Commit**

```bash
git add ui/overlay/combat.lua scenes/match.lua tools/snapshot/scenarios.lua
git commit -m "Restyle combat overlay: slide-in cards, CLASH burst, count-up badges, shatter"
```

---

### Task 10: Trap activation overlay

**Files:**
- Create: `ui/overlay/trapfx.lua`, `ui/overlay/trapactivation.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Delete: `ui/trap_activation_overlay.lua`
- Test: `tests/test_trapfx.lua`

- [ ] **Step 1: Write the failing test `tests/test_trapfx.lua`**

```lua
local T  = require("tests.t")
local Fx = require("ui.overlay.trapfx")

T.test("purple flash fades while the card spins in and flips face-up", function()
    local p = Fx.pose(0)
    T.near(p.flash, 1); T.eq(p.scale, 0)
    p = Fx.pose(Fx.FLASH_DUR); T.near(p.flash, 0)
    p = Fx.pose(Fx.FLIP + Fx.FLIP_DUR * 0.25); T.ok(not p.faceUp); T.ok(p.spin < 0)
    p = Fx.pose(Fx.FLIP + Fx.FLIP_DUR * 0.75); T.ok(p.faceUp)
    p = Fx.pose(Fx.FLIP + Fx.FLIP_DUR)
    T.near(p.scale, 1); T.near(p.spin, 0); T.near(p.flipX, 1)
end)

T.test("the stamp slams from big to its resting size", function()
    T.eq(Fx.pose(Fx.STAMP - 0.01).stamp, 0)
    T.near(Fx.pose(Fx.STAMP).stampScale, Fx.STAMP_FROM)
    local p = Fx.pose(Fx.STAMP + Fx.STAMP_DUR)
    T.near(p.stampScale, 1); T.near(p.stampAlpha, 1)
end)

T.test("dust, ribbon, text and hint follow the stamp in order", function()
    T.ok(Fx.STAMP < Fx.DUST and Fx.DUST < Fx.RIBBON and Fx.RIBBON < Fx.TEXT and Fx.TEXT < Fx.HINT)
    T.eq(Fx.pose(Fx.DUST - 0.01).dust, 0)
    T.eq(Fx.pose(Fx.RIBBON - 0.01).ribbon, 0); T.near(Fx.pose(Fx.RIBBON + Fx.RIBBON_DUR).ribbon, 1)
    T.near(Fx.pose(Fx.TEXT - 0.01).text, 0);   T.near(Fx.pose(Fx.TEXT + Fx.TEXT_DUR).text, 1)
    T.near(Fx.pose(Fx.HINT + 0.25).hint, 1)
end)

T.test("headline and effect text", function()
    T.eq(Fx.headline("player"), "YOU ACTIVATED A TRAP")
    T.eq(Fx.headline("opponent"), "OPPONENT TRAP")
    T.eq(Fx.effectText({ ability = "OFFSIDE", abilityText = "x" }), "Striker attack cancelled — caught offside!")
    T.eq(Fx.effectText({ ability = "NEW", abilityText = "Does things." }), "Does things.")
    T.eq(Fx.effectText(nil), "")
end)

T.test("dust puffs spread out and fade", function()
    local a, b = Fx.dustPuffs(0.1, 8), Fx.dustPuffs(0.9, 8)
    T.eq(#a, 8)
    T.ok(math.abs(b[1].dx) > math.abs(a[1].dx)); T.ok(b[1].r > a[1].r); T.ok(b[1].a < a[1].a)
    T.ok(a[1].dx > 0 and a[8].dx < 0, "puffs go both ways")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_trapfx.lua (load error)`; then `123 passed, 1 failed`.

- [ ] **Step 3: Create `ui/overlay/trapfx.lua`**

```lua
-- Trap activation timeline. Pure (unit-tested); ui/overlay/trapactivation.lua draws from it.
local C = require("ui.overlay.combatfx")   -- progress / backout / quadout

local Fx = {}

Fx.FLASH_DUR  = 0.35   -- purple full-screen flash fades out
Fx.FLIP       = 0.10   -- trap card spins in and flips face-up
Fx.FLIP_DUR   = 0.50
Fx.STAMP      = 0.65   -- "TRAP ACTIVATED!" stamp slams down
Fx.STAMP_DUR  = 0.25
Fx.STAMP_FROM = 2.6    -- stamp starting scale
Fx.DUST       = 0.80   -- dust puff where the stamp lands
Fx.DUST_DUR   = 0.55
Fx.RIBBON     = 0.95   -- "YOU ACTIVATED A TRAP" / "OPPONENT TRAP"
Fx.RIBBON_DUR = 0.30
Fx.TEXT       = 1.15   -- trap name, effect and context
Fx.TEXT_DUR   = 0.25
Fx.HINT       = 1.45

local EFFECT = {
    OFFSIDE            = "Striker attack cancelled — caught offside!",
    RED_CARD           = "Winning attacker sent off!",
    VAR                = "VAR Review in progress",
    LAST_DEFENDER_FOUL = "Last defender fouled — direct free shot awarded!",
    MANAGERS_CHALLENGE = "Opposing trap negated — challenge upheld!",
}

function Fx.pose(t)
    local p = {}
    p.flash = 1 - C.progress(t, 0, Fx.FLASH_DUR)
    local f = C.progress(t, Fx.FLIP, Fx.FLIP_DUR)
    p.scale  = t < Fx.FLIP and 0 or 0.3 + 0.7 * C.backout(f)
    p.spin   = -(1 - C.quadout(f)) * math.pi * 1.5
    p.flipX  = math.abs(math.cos(f * math.pi))
    p.faceUp = f >= 0.5
    p.stamp  = C.progress(t, Fx.STAMP, Fx.STAMP_DUR)
    p.stampScale = Fx.STAMP_FROM - (Fx.STAMP_FROM - 1) * C.backout(p.stamp)
    p.stampAlpha = math.min(1, p.stamp * 4)
    p.dust   = C.progress(t, Fx.DUST, Fx.DUST_DUR)
    p.ribbon = t < Fx.RIBBON and 0 or C.backout(C.progress(t, Fx.RIBBON, Fx.RIBBON_DUR))
    p.text   = C.progress(t, Fx.TEXT, Fx.TEXT_DUR)
    p.hint   = C.progress(t, Fx.HINT, 0.25)
    return p
end

function Fx.headline(activator)
    if activator == "player" then return "YOU ACTIVATED A TRAP" end
    return "OPPONENT TRAP"
end

function Fx.effectText(trapDef)
    if not trapDef then return "" end
    return EFFECT[trapDef.ability] or trapDef.abilityText or ""
end

-- n dust puffs at progress k: spread sideways and slightly down from the stamp's
-- bottom edge, growing and fading. Each: { dx, dy, r, a }.
function Fx.dustPuffs(k, n)
    local out = {}
    local d = 30 + 110 * C.quadout(k)
    for i = 1, n do
        local ang = math.pi * (i - 0.5) / n
        out[i] = { dx = math.cos(ang) * d * 1.6, dy = math.sin(ang) * d * 0.35, r = 10 + 18 * k, a = 0.85 * (1 - k) }
    end
    return out
end

return Fx
```

- [ ] **Step 4: Create `ui/overlay/trapactivation.lua`**

```lua
-- Trap activation overlay (arcade). Behaviour and data contract unchanged:
--   rec = { activator = "player" | "opponent", trapDef, contextText }   (store:_pushTrapActivation)
-- TrapActivation.draw(rec, t): t = seconds since it opened (ui/overlay/trapfx.lua).
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local Fx    = require("ui.overlay.trapfx")

local TrapActivation = {}

local W, H    = 1280, 800
local CW, CH  = 200, 274
local CX, CY  = 640, 290       -- card centre
local STAMP_Y = 350

function TrapActivation.draw(rec, t)
    if not rec then return end
    local p = Fx.pose(t or 0)
    local purple = Theme.outcome.purple

    Draw.setColor(Theme.dim)
    love.graphics.rectangle("fill", 0, 0, W, H)
    if p.flash > 0 then
        Draw.setColor(purple[1], p.flash * 0.7)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    Draw.setColor(purple[1], 0.35)
    love.graphics.circle("fill", CX, CY, 230, 64)

    -- Card: spins in, scales up, flips face-up
    if p.scale > 0 then
        love.graphics.push()
        love.graphics.translate(CX, CY)
        love.graphics.rotate(p.spin)
        love.graphics.scale(p.scale * p.flipX, p.scale)
        if p.faceUp and rec.trapDef then
            Card.drawFace(rec.trapDef, -CW / 2, -CH / 2, CW, CH, {})
        else
            Card.drawBack(-CW / 2, -CH / 2, CW, CH, { label = "TRAP" })
        end
        love.graphics.pop()
    end

    -- Dust puff where the stamp lands
    if p.dust > 0 and p.dust < 1 then
        for _, d in ipairs(Fx.dustPuffs(p.dust, 8)) do
            love.graphics.setColor(1, 1, 1, d.a)
            love.graphics.circle("fill", CX + d.dx, STAMP_Y + 34 + d.dy, d.r, 24)
        end
    end

    -- "TRAP ACTIVATED!" stamp
    if p.stamp > 0 then
        love.graphics.push()
        love.graphics.translate(CX, STAMP_Y)
        love.graphics.rotate(-0.12)
        love.graphics.scale(p.stampScale, p.stampScale)
        Draw.sticker(-190, -34, 380, 68, { r = 14, fill = purple, border = 4, shadow = 6, alpha = p.stampAlpha })
        Draw.text("TRAP ACTIVATED!", -180, -24, 360, "center", {
            size = 42, color = Theme.white, shadowY = 3, alpha = p.stampAlpha, fit = true,
        })
        love.graphics.pop()
    end

    -- Who activated it
    if p.ribbon > 0 then
        local mine = rec.activator == "player"
        local ry = 500
        love.graphics.push()
        love.graphics.translate(CX, ry + 30)
        love.graphics.scale(p.ribbon, p.ribbon)
        love.graphics.translate(-CX, -(ry + 30))
        Draw.ribbon(CX, ry, 520, 60, Fx.headline(rec.activator), {
            fill = mine and Theme.button.primary.fill or Theme.outcome.red,
            textColor = mine and Theme.button.primary.text or Theme.white, size = 34, textShadow = not mine,
        })
        love.graphics.pop()
    end

    -- Trap name, effect and context
    if p.text > 0 then
        local a = p.text
        local px, py, pw, ph = CX - 300, 584, 600, 124
        Draw.sticker(px, py, pw, ph, { r = 18, fill = Theme.white, border = 0, shadow = 5, alpha = a })
        Draw.text(rec.trapDef and rec.trapDef.name or "TRAP", px + 16, py + 10, pw - 32, "center", {
            size = 24, color = Theme.typeGrad.trap[2], alpha = a, fit = true,
        })
        Draw.text(Fx.effectText(rec.trapDef), px + 16, py + 44, pw - 32, "center", {
            size = 15, body = true, color = Theme.inkText, alpha = a,
        })
        Draw.text(rec.contextText or "", px + 16, py + 88, pw - 32, "center", {
            size = 14, body = true, color = { 0.42, 0.42, 0.6, 1 }, alpha = a,
        })
    end

    if p.hint > 0 then Draw.hintPill(CX, 744, "CLICK OR SPACE", p.hint) end
end

return TrapActivation
```

- [ ] **Step 5: Wire it into `scenes/match.lua`.**
  - Replace `local TrapActivOverlay   = require("ui.trap_activation_overlay")` with:

```lua
local TrapActivOverlay   = require("ui.overlay.trapactivation")
```

  - Replace `local trapActivAnim   = { slideY = 0, stampAlpha = 0, glowAlpha = 0, textAlpha = 0 }` with:

```lua
local trapActivT      = 0   -- seconds since the active trap overlay opened (ui/overlay/trapfx.lua)
```

  - In `Match.enter`, directly after `    activeTrapActiv     = nil`, add:

```lua
    trapActivT          = 0
```

  - In `Match.update`, replace the whole block:

```lua
    -- Dequeue a trap activation overlay (only when no combat overlay is blocking)
    if not activeCombat and not activeTrapActiv and #trapActivQueue > 0 then
        activeTrapActiv = table.remove(trapActivQueue, 1)
        if activeTrapActiv.activator == "opponent" then
            Character.setState("worried")
        end
        local H = love.graphics.getHeight()
        trapActivAnim.slideY     = H * 0.38
        trapActivAnim.stampAlpha = 0
        trapActivAnim.glowAlpha  = 0
        trapActivAnim.textAlpha  = 0
        flux.to(trapActivAnim, 0.30, { slideY = 0 }):ease("backout")
        flux.to(trapActivAnim, 0.28, { glowAlpha = 1 }):ease("quadout")
        flux.to(trapActivAnim, 0.28, { stampAlpha = 1 }):delay(0.26):ease("backout")
        flux.to(trapActivAnim, 0.28, { textAlpha = 1 }):delay(0.50):ease("quadout")
    end
```

with:

```lua
    -- Dequeue a trap activation overlay (only when no combat overlay is blocking)
    if not activeCombat and not activeTrapActiv and #trapActivQueue > 0 then
        activeTrapActiv = table.remove(trapActivQueue, 1)
        trapActivT = 0
        if activeTrapActiv.activator == "opponent" then
            Character.setState("worried")
        end
    end
    if activeTrapActiv and not activeCombat then trapActivT = trapActivT + dt end
```

  - In `Match.draw`, replace `        TrapActivOverlay.draw(activeTrapActiv, trapActivAnim)` with:

```lua
        TrapActivOverlay.draw(activeTrapActiv, trapActivT)
```

- [ ] **Step 6: Delete the old overlay**

Run: `grep -rn 'trapActivAnim\|ui\.trap_activation_overlay' --include='*.lua' . | grep -v '^./ui/trap_activation_overlay.lua'`
Expected: no output.
Run: `git rm -q ui/trap_activation_overlay.lua`

- [ ] **Step 7: Add the `trap` scenario.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Trap activation: flash, flip, stamp, dust, full; then an opponent trap.
local function trapRec(rec) return function() require("scenes.match").debugOverlay("trap", rec) end end
S.trap = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  trapRec({ activator = "player", trapDef = defById("trap-offside"),
                      contextText = "The Poacher was caught offside!" }) },
    { 1.62, function(c) c.snap("flash") end },
    { 1.9,  function(c) c.snap("flip") end },
    { 2.2,  function(c) c.snap("stamp") end },
    { 2.45, function(c) c.snap("dust") end },
    { 3.3,  function(c) c.snap("full") end },
    { 3.4,  function() love.keypressed("space") end },
    { 3.5,  trapRec({ activator = "opponent", trapDef = defById("trap-red-card"),
                      contextText = "Your The Poacher was sent off!" }) },
    { 5.4,  function(c) c.snap("opponent") end },
    { 5.5,  function() love.keypressed("space") end },
    { 5.8,  function(c) c.snap("dismissed") end },
    { 6.0,  function(c) c.quit() end },
}
```

- [ ] **Step 8: Syntax check, tests, snapshots**

Run: `luac -p ui/overlay/trapfx.lua ui/overlay/trapactivation.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && tools/snapshot/snap.sh trap`
Expected: no `luac` output; `128 passed, 0 failed`; `trap_dismissed`, `trap_dust`, `trap_flash`, `trap_flip`, `trap_full`, `trap_opponent`, `trap_stamp` listed; no Lua error.

- [ ] **Step 9: Review with the Read tool:**

- `trap_flash.png`: a strong purple wash over the whole screen, and a small, rotated card back starting to appear at centre (640, 290 → ×2 = 1280, 580).
- `trap_flip.png`: the card is narrow (mid-flip), less rotated and larger. The purple flash is gone and a soft purple circle sits behind the card.
- `trap_stamp.png`: a large purple "TRAP ACTIVATED!" sticker, tilted, much bigger than the card and shrinking.
- `trap_dust.png`: the stamp is at rest over the card's lower half, and white dust puffs spread left and right under it.
- `trap_full.png`:
  - The OFFSIDE trap card face-up (purple).
  - A yellow ribbon "YOU ACTIVATED A TRAP".
  - A white panel with "Offside" in purple, the line "Striker attack cancelled — caught offside!" (the em dash renders, no box), and the context line.
  - A "CLICK OR SPACE" pill with a drawn triangle.
- `trap_opponent.png`: a red ribbon "OPPONENT TRAP", the Red Card trap face-up, and "Your The Poacher was sent off!".
- `trap_dismissed.png`: the plain match.

- [ ] **Step 10: Commit**

```bash
git add ui/overlay/trapfx.lua ui/overlay/trapactivation.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_trapfx.lua
git commit -m "Restyle trap activation: purple flash, spinning flip, slam stamp, dust"
```

---

### Task 11: Bottom prompt panel — cover prompt and trap window

**Files:**
- Create: `ui/overlay/promptpanel.lua`, `ui/overlay/prompts.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Delete: `ui/cover_prompt.lua`, `ui/trap_prompt.lua`
- Test: `tests/test_promptpanel.lua`

- [ ] **Step 1: Write the failing test `tests/test_promptpanel.lua`**

```lua
local T     = require("tests.t")
local Panel = require("ui.overlay.promptpanel")

local function inside(r, box)
    return r.x >= box.x and r.y >= box.y and r.x + r.w <= box.x + box.w and r.y + r.h <= box.y + box.h
end
local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

T.test("panel layout fits 1 to 3 options without overlaps and keeps the pitch visible", function()
    for n = 1, 3 do
        local L = Panel.layout(n, 0)
        local rects = { L.source, L.info, L.pass }
        for _, o in ipairs(L.options) do rects[#rects + 1] = o.card; rects[#rects + 1] = o.button end
        T.eq(#L.options, n)
        for i = 1, #rects do
            T.ok(inside(rects[i], L.panel), "n=" .. n .. " rect " .. i .. " outside the panel")
            for j = i + 1, #rects do
                T.ok(not overlap(rects[i], rects[j]), "n=" .. n .. " overlap " .. i .. "/" .. j)
            end
        end
        T.ok(L.panel.y + L.panel.h <= 800 - 6, "panel + shadow on screen")
        T.ok(L.panel.y >= 540, "pitch (y < 520) stays visible")
    end
    T.eq(#Panel.layout(5, 0).options, Panel.MAX_OPTIONS)
end)

T.test("sliding moves every rect by the same offset", function()
    local a, b = Panel.layout(2, 0), Panel.layout(2, 100)
    T.eq(b.panel.y - a.panel.y, 100); T.eq(b.pass.y - a.pass.y, 100)
    T.eq(b.options[2].button.y - a.options[2].button.y, 100); T.eq(b.source.x, a.source.x)
end)

T.test("cover hitboxes: a COVER per coverer (button and card), LET THROUGH last", function()
    local cw = { eligibleCoverers = { { type = "defender", index = 1, card = {} },
                                      { type = "defender", index = 2, card = {} } } }
    local boxes = Panel.coverHitboxes(cw, 0)
    local L = Panel.layout(2, 0)
    T.eq(#boxes, 5)
    T.eq(boxes[1].type, "cover"); T.eq(boxes[1].coverer.type, "defender"); T.eq(boxes[1].coverer.index, 1)
    T.eq(boxes[1].x, L.options[1].button.x); T.eq(boxes[2].x, L.options[1].card.x)
    T.eq(boxes[3].coverer.index, 2)
    T.eq(boxes[5].type, "letthrough"); T.eq(boxes[5].x, L.pass.x)
end)

T.test("trap hitboxes: ACTIVATE per trap (button and card) with its index, PASS last", function()
    local tw = { traps = { { card = {}, slotIndex = 2 } } }
    local boxes = Panel.trapHitboxes(tw, 10)
    T.eq(#boxes, 3)
    T.eq(boxes[1].type, "activate"); T.eq(boxes[1].trapIndex, 1)
    T.eq(boxes[2].trapIndex, 1)
    T.eq(boxes[3].type, "pass"); T.eq(boxes[3].y, Panel.layout(1, 10).pass.y)
end)

T.test("no window, no hitboxes", function()
    T.eq(#Panel.coverHitboxes(nil, 0), 0); T.eq(#Panel.trapHitboxes(nil, 0), 0)
end)

T.test("trap window titles", function()
    T.eq(Panel.trapTitle("pre_attack"), "TRAP WINDOW · STRIKER ATTACKS")
    T.eq(Panel.trapTitle("counter_red_card"), "COUNTER TRAP · RED CARD INCOMING")
    T.eq(Panel.trapTitle("??"), "TRAP WINDOW")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_promptpanel.lua (load error)`; then `128 passed, 1 failed`.

- [ ] **Step 3: Create `ui/overlay/promptpanel.lua`**

```lua
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
```

- [ ] **Step 4: Create `ui/overlay/prompts.lua`**

```lua
-- Cover prompt and trap window as the bottom sticker panel (ui/overlay/promptpanel.lua),
-- with the relevant pitch slots pulsing above a light dim. Data contracts unchanged:
--   coverWindow = { attackerSnap, attackerSlot, emptySlot, eligibleCoverers = { { type, index, card } } }
--   trapWindow  = { type, attackerSnap, defenderSnap, aiTrapCard?, traps = { { card, slotIndex } } }
-- Both draw functions return the hitboxes Match.mousepressed tests clicks against.
local Theme    = require("ui.theme")
local Draw     = require("ui.kit.draw")
local Button   = require("ui.kit.button")
local Card     = require("ui.card")
local Layout   = require("ui.match.layout")
local Panel    = require("ui.overlay.promptpanel")
local CombatFx = require("ui.overlay.combatfx")

local Prompts = {}

local buttons = {}

-- Cached kit button placed at r, updated with the match mouse, drawn.
local function button(id, label, variant, r, mx, my)
    local b = buttons[id]
    if not b then
        b = Button.new({ id = id, label = label, variant = variant, fontSize = 20 })
        buttons[id] = b
    end
    b.label = label
    b:setRect(r.x, r.y, r.w, r.h)
    b:update(love.timer.getDelta(), mx or -1, my or -1, love.mouse.isDown(1))
    b:draw()
end

local function pulseRect(r, color)
    if not r then return end
    local k = 0.5 + 0.5 * math.sin(love.timer.getTime() * 6)
    Draw.glow(r.x, r.y, r.w, r.h, 14, color, 0.6 + 0.8 * k)
    Draw.ring(r.x - 4, r.y - 4, r.w + 8, r.h + 8, 16, color, 4, 0.6 + 0.4 * k)
end

local function dim()
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.30)
    love.graphics.rectangle("fill", 0, 0, Layout.W, Layout.H)
end

local function panel(L, title, fill, textColor)
    local P = L.panel
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 24, fill = Theme.white, border = 0, shadow = 7 })
    Draw.ribbon(P.x + P.w / 2, P.y - 22, 400, 46, title, {
        fill = fill, textColor = textColor, size = 26, textShadow = textColor == Theme.white,
    })
end

-- Attacking card (hand size) with an arrow toward the info column.
local function source(L, snap)
    local v = CombatFx.cardView(snap, CombatFx.lookup)
    if not v then return end
    local r = L.source
    Card.drawFace(v.cardDef, r.x, r.y, r.w, r.h, {
        stats = v.stats, atkBonus = v.atkBonus > 0 and v.atkBonus or nil,
    })
    Draw.arrow(r.x + r.w + 12, r.y + r.h / 2, 18, 1, Theme.inkText)
end

local function info(L, heading, body, note)
    local r = L.info
    Draw.text(heading, r.x, r.y + 6, r.w, "left", { size = 22, color = Theme.inkText, fit = true, minSize = 14 })
    Draw.text(body, r.x, r.y + 40, r.w, "left", { size = 15, body = true, color = Theme.inkText })
    if note then
        Draw.text(note, r.x, r.y + 118, r.w, "left", { size = 13, body = true, color = { 0.42, 0.42, 0.6, 1 } })
    end
end

local function snapLine(snap, stat)
    if not snap then return "an empty slot" end
    return snap.name .. " (" .. string.upper(stat) .. " " .. tostring(snap[stat] or 0) .. ")"
end

function Prompts.drawCover(cw, slide, mx, my)
    local L = Panel.layout(#cw.eligibleCoverers, slide)
    dim()
    local a = cw.attackerSlot
    if a then pulseRect(Layout.slot("opponent", a.type, a.index or 0), Theme.highlight.target) end
    for _, cov in ipairs(cw.eligibleCoverers) do
        pulseRect(Layout.slot("player", cov.type, cov.index or 0), Theme.highlight.selected)
    end
    panel(L, "COVER?", Theme.button.primary.fill, Theme.button.primary.text)
    source(L, cw.attackerSnap)
    local es = cw.emptySlot or {}
    local slotName = Theme.typeLabel[es.type] or string.upper(tostring(es.type or "?"))
    info(L, "INCOMING ATTACK",
        snapLine(cw.attackerSnap, "atk") .. " is attacking your empty " .. slotName .. " slot.",
        "A covering card can't act next turn.")
    for i, cov in ipairs(cw.eligibleCoverers) do
        local o = L.options[i]
        if o then
            Card.drawFace(cov.card.definition, o.card.x, o.card.y, o.card.w, o.card.h, {})
            button("cover" .. i, "COVER", "go", o.button, mx, my)
        end
    end
    button("letthrough", "LET THROUGH", "neutral", L.pass, mx, my)
    return Panel.coverHitboxes(cw, slide)
end

function Prompts.drawTrapWindow(tw, slide, mx, my)
    local L = Panel.layout(#tw.traps, slide)
    dim()
    for _, e in ipairs(tw.traps) do
        pulseRect(Layout.trapSlot("player", e.slotIndex), Theme.typeGrad.trap[1])
    end
    panel(L, Panel.trapTitle(tw.type), Theme.outcome.purple, Theme.white)
    source(L, tw.attackerSnap)
    local note = "Activate a trap, or pass."
    if tw.aiTrapCard and tw.aiTrapCard.definition then
        note = "Opponent plays " .. tw.aiTrapCard.definition.name .. ". Counter it?"
    end
    info(L, "YOUR TRAPS ARE READY",
        snapLine(tw.attackerSnap, "atk") .. " vs " .. snapLine(tw.defenderSnap, "def") .. ".", note)
    for i, e in ipairs(tw.traps) do
        local o = L.options[i]
        if o then
            Card.drawFace(e.card.definition, o.card.x, o.card.y, o.card.w, o.card.h, {})
            button("activate" .. i, "ACTIVATE", "go", o.button, mx, my)
        end
    end
    button("pass", "PASS", "neutral", L.pass, mx, my)
    return Panel.trapHitboxes(tw, slide)
end

return Prompts
```

- [ ] **Step 5: Wire it into `scenes/match.lua`.**
  - Replace `local CoverPrompt        = require("ui.cover_prompt")` with:

```lua
local Prompts            = require("ui.overlay.prompts")
local PromptPanel        = require("ui.overlay.promptpanel")
```

  - Directly after `local trapHitboxes  = {}`, add:

```lua
local promptAnim    = { y = 0 }   -- bottom prompt panel slide offset
local promptWindow  = nil         -- the cover/trap window the panel is showing (slide-in trigger)
```

  - In `Match.enter`, directly after `    trapHitboxes        = {}`, add:

```lua
    promptAnim          = { y = 0 }
    promptWindow        = nil
```

  - In `Match.update`, insert directly above the line `    -- Combat overlay: dequeue, then advance its timeline (ui/overlay/combatfx.lua).`:

```lua
    -- Bottom prompt panel slides up whenever a new cover/trap window opens for the player
    local win = (store.coverWindow and match.activePlayer == "opponent" and store.coverWindow) or store.trapWindow
    if win ~= promptWindow then
        promptWindow = win
        if win then
            promptAnim.y = PromptPanel.SLIDE
            flux.to(promptAnim, 0.32, { y = 0 }):ease("backout")
        end
    end

```

  - In `Match.draw`, replace:

```lua
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
```

with:

```lua
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
```

  - Delete the whole `-- ── Trap Window ───…` section: the header comment line and `function Match.drawTrapWindow(tw)` through its closing `end`, which is directly above `-- ── Highlight helpers ───…`.

- [ ] **Step 6: Update `advance()` in `tools/snapshot/scenarios.lua`.** Replace:

```lua
        for _, hb in ipairs(require("ui.cover_prompt").getHitboxes(st.coverWindow)) do
```

with:

```lua
        for _, hb in ipairs(require("ui.overlay.promptpanel").coverHitboxes(st.coverWindow, 0)) do
```

- [ ] **Step 7: Delete the old prompt modules**

Run: `grep -rn 'ui\.cover_prompt\|ui\.trap_prompt\|CoverPrompt\|TrapPrompt\|drawTrapWindow' --include='*.lua' . | grep -v '^./ui/cover_prompt.lua\|^./ui/trap_prompt.lua'`
Expected: no output.
Run: `git rm -q ui/cover_prompt.lua ui/trap_prompt.lua`

- [ ] **Step 8: Add the `cover` and `trapwin` scenarios.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Pitched card for harness-built boards.
local function pitched(id, slotType, mode)
    return { definition = defById(id), mode = mode or "attack", exhausted = false, slotType = slotType }
end

-- Cover prompt (synthetic window, harness-only): the opponent striker attacks your empty
-- DEF slot; your midfielder can cover.
S.cover = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        local P, O = st.match.players.player.pitch, st.match.players.opponent.pitch
        P.midfielder = pitched("mid-box-to-box", "midfielder")
        O.strikers[1] = pitched("str-speed-demon", "striker")
        st.match.activePlayer = "opponent"
        st.coverWindow = {
            attackerSlot     = { type = "striker", index = 1 },
            emptySlot        = { type = "defender", index = 1 },
            eligibleCoverers = { { type = "midfielder", index = 0, card = P.midfielder } },
            attackerSnap     = snapFrom("str-speed-demon"),
        }
    end },
    { 1.62, function(c) c.snap("slide") end },
    { 2.0,  function()
        local hb = require("ui.overlay.promptpanel").coverHitboxes(store().coverWindow, 0)[1]
        move(hb.x + hb.w / 2, hb.y + hb.h / 2)
    end },
    { 2.4,  function(c) c.snap("panel") end },
    { 2.6,  function(c) c.quit() end },
}

-- Trap window (synthetic, harness-only): pre-attack with OFFSIDE + MANAGER'S CHALLENGE set.
S.trapwin = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        local P = st.match.players.player.pitch
        P.traps[1] = pitched("trap-offside", "trap", "defense")
        P.traps[2] = pitched("trap-managers-challenge", "trap", "defense")
        st.trapWindow = {
            type         = "pre_attack",
            attackerSlot = { type = "striker", index = 1 },
            defenderSlot = { type = "defender", index = 1 },
            traps        = { { card = P.traps[1], slotIndex = 1 }, { card = P.traps[2], slotIndex = 2 } },
            attackerSnap = snapFrom("str-poacher"),
            defenderSnap = snapFrom("def-the-rock"),
        }
    end },
    { 1.62, function(c) c.snap("slide") end },
    { 2.0,  function()
        local hb = require("ui.overlay.promptpanel").trapHitboxes(store().trapWindow, 0)[1]
        move(hb.x + hb.w / 2, hb.y + hb.h / 2)
    end },
    { 2.4,  function(c) c.snap("panel") end },
    { 2.6,  function(c) c.quit() end },
}
```

- [ ] **Step 9: Syntax check, tests, snapshots**

Run: `luac -p ui/overlay/promptpanel.lua ui/overlay/prompts.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && for s in cover trapwin summon; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: no `luac` output; `134 passed, 0 failed`; `cover_panel`, `cover_slide`, `trapwin_panel`, `trapwin_slide` and the 7 `summon_*` PNGs listed; no `FAILED`, no Lua error.

- [ ] **Step 10: Review with the Read tool:**

- `cover_slide.png`: a white panel partly below the bottom edge (sliding up), with the pitch fully visible above it and lightly dimmed.
- `cover_panel.png`:
  - A white panel at y 548–788 (×2 = 1096–1576), x 160–1120.
  - A yellow "COVER?" ribbon straddles the panel top.
  - On the left is the red "Speed Demon" card (hand size), with an ink triangle arrow pointing right.
  - "INCOMING ATTACK" heading, the line "Speed Demon (ATK 2200) is attacking your empty DEFENDER slot." and the grey note.
  - One small "Box-to-Box" midfielder card with a green COVER button under it. The button is lifted, because the mouse hovers it.
  - A white LET THROUGH button on the right.
  - On the pitch, your MID slot pulses with a yellow glow and ring, and the opponent striker in STR 1 pulses red.
- `trapwin_slide.png`: the panel is sliding in with a purple ribbon.
- `trapwin_panel.png`:
  - A purple ribbon "TRAP WINDOW · STRIKER ATTACKS" and "The Poacher" on the left.
  - "YOUR TRAPS ARE READY", then "The Poacher (ATK 2000) vs The Rock (DEF 2100)." and the note "Activate a trap, or pass.".
  - Two face-up trap cards (Offside, Manager's Challenge), each with a green ACTIVATE button. The first button is hovered.
  - A white PASS button.
  - Both of your trap slots by your goal pulse purple.
- `summon_*.png`: during the AI turn, any cover prompt was answered by `advance()` (no panel stuck in `summon_myturn`).

- [ ] **Step 11: Commit**

```bash
git add ui/overlay/promptpanel.lua ui/overlay/prompts.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_promptpanel.lua
git commit -m "Restyle cover prompt and trap window as a sliding bottom panel"
```

---

### Task 12: Scout reveal

**Files:**
- Create: `ui/overlay/reveal.lua`
- Modify: `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_reveal.lua`

- [ ] **Step 1: Write the failing test `tests/test_reveal.lua`**

```lua
local T      = require("tests.t")
local Reveal = require("ui.overlay.reveal")

T.test("scout card starts face-down, turns edge-on, lands face-up", function()
    local p = Reveal.pose(0, 3.5)
    T.ok(not p.faceUp); T.near(p.flipX, 1)
    p = Reveal.pose(Reveal.FLIP_DUR / 2, 3.2); T.near(p.flipX, 0, 1e-9)
    p = Reveal.pose(Reveal.FLIP_DUR, 3.0); T.ok(p.faceUp); T.near(p.flipX, 1); T.near(p.scale, 1)
end)

T.test("scout card shrinks away during the last OUT_DUR seconds", function()
    local p = Reveal.pose(2.0, 1.0); T.near(p.scale, 1); T.near(p.alpha, 1)
    p = Reveal.pose(3.35, Reveal.OUT_DUR / 2); T.near(p.scale, 0.5); T.near(p.alpha, 0.5)
    p = Reveal.pose(3.5, 0); T.near(p.scale, 0); T.near(p.alpha, 0)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL  tests/test_reveal.lua (load error)`; then `134 passed, 1 failed`.

- [ ] **Step 3: Create `ui/overlay/reveal.lua`**

```lua
-- Scout Report reveal: the card flips up at zoom size under a SCOUTED ribbon and shrinks
-- away as the timer runs out. Reveal.pose is pure (unit-tested); draw uses LÖVE.
-- Input is unchanged: a click dismisses (scenes/match.lua).
local Theme = require("ui.theme")
local Draw  = require("ui.kit.draw")
local Card  = require("ui.card")
local C     = require("ui.overlay.combatfx")   -- progress / backout

local Reveal = {}
Reveal.FLIP_DUR = 0.45
Reveal.OUT_DUR  = 0.30

local W, H   = 1280, 800
local CW, CH = 200, 274
local CX, CY = 640, 390

-- elapsed: seconds since shown; remaining: seconds left on the timer.
function Reveal.pose(elapsed, remaining)
    local f   = C.progress(elapsed, 0, Reveal.FLIP_DUR)
    local out = 1 - C.progress(remaining, 0, Reveal.OUT_DUR)
    return {
        flipX  = math.abs(math.cos(f * math.pi)),
        faceUp = f >= 0.5,
        scale  = (0.8 + 0.2 * f) * (1 - out),
        alpha  = 1 - out,
        ribbon = C.backout(C.progress(elapsed, 0.3, 0.25)) * (1 - out),
        hint   = C.progress(elapsed, 0.6, 0.25) * (1 - out),
    }
end

function Reveal.draw(pitched, elapsed, remaining)
    local p = Reveal.pose(elapsed, remaining)
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.72 * p.alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local def = pitched and pitched.definition
    if def then
        love.graphics.push()
        love.graphics.translate(CX, CY)
        love.graphics.scale(p.scale * p.flipX, p.scale)
        if p.faceUp then
            Card.drawFace(def, -CW / 2, -CH / 2, CW, CH, {})
        else
            Card.drawBack(-CW / 2, -CH / 2, CW, CH, { label = "DEF" })
        end
        love.graphics.pop()
    else
        Draw.text("NO CARD IN THAT SLOT", 0, CY - 20, W, "center", {
            size = 32, color = Theme.white, shadowY = 3, alpha = p.alpha,
        })
    end

    if p.ribbon > 0 then
        local ry = CY - CH / 2 - 84
        love.graphics.push()
        love.graphics.translate(CX, ry + 30)
        love.graphics.scale(p.ribbon, p.ribbon)
        love.graphics.translate(-CX, -(ry + 30))
        Draw.ribbon(CX, ry, 340, 60, "SCOUTED", {
            fill = Theme.outcome.blue, textColor = Theme.white, size = 38, textShadow = true,
        })
        love.graphics.pop()
    end
    if p.hint > 0 then Draw.hintPill(CX, CY + CH / 2 + 48, "CLICK TO DISMISS", p.hint) end
end

return Reveal
```

- [ ] **Step 4: Wire it into `scenes/match.lua`.**
  - Add after `local PromptPanel        = require("ui.overlay.promptpanel")`:

```lua
local Reveal             = require("ui.overlay.reveal")
```

  - In `Match.update`, replace:

```lua
    if scoutReveal then
        scoutReveal.timer = scoutReveal.timer - dt
        if scoutReveal.timer <= 0 then scoutReveal = nil end
    end
```

with:

```lua
    if scoutReveal then
        scoutReveal.t     = (scoutReveal.t or 0) + dt
        scoutReveal.timer = scoutReveal.timer - dt
        if scoutReveal.timer <= 0 then scoutReveal = nil end
    end
```

  - In `Match.mousepressed`, replace `                        scoutReveal = { card = result.revealedCard, timer = 3.5 }` with:

```lua
                        scoutReveal = { card = result.revealedCard, timer = 3.5, t = 0 }
```

  - In `Match.draw`, replace `        Match.drawScoutReveal(scoutReveal.card)` with:

```lua
        Reveal.draw(scoutReveal.card, scoutReveal.t or 0, scoutReveal.timer)
```

  - Delete the whole `function Match.drawScoutReveal(pitchedCard)` through its closing `end`, which is directly above `function Match.getCardInSlot(pitch, slot)`.

Run: `grep -n 'drawScoutReveal\|Theme.atkColor\|Theme.defColor' scenes/match.lua`
Expected: no output.

- [ ] **Step 5: Add the `scout` scenario.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Scout reveal (synthetic, harness-only): flip, shown, shrinking, gone.
S.scout = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        require("scenes.match").debugOverlay("scout", pitched("keeper-iron-fists", "keeper", "defense"))
    end },
    { 1.75, function(c) c.snap("flip") end },
    { 2.4,  function(c) c.snap("shown") end },
    { 4.85, function(c) c.snap("shrink") end },
    { 5.2,  function(c) c.snap("gone") end },
    { 5.5,  function(c) c.quit() end },
}
```

- [ ] **Step 6: Syntax check, tests, snapshots**

Run: `luac -p ui/overlay/reveal.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && tools/snapshot/snap.sh scout`
Expected: no `luac` output; `136 passed, 0 failed`; `scout_flip`, `scout_gone`, `scout_shown`, `scout_shrink` listed; no Lua error.

- [ ] **Step 7: Review with the Read tool:**

- `scout_flip.png`: a navy dim, and a very narrow card at centre (640, 390 → ×2 = 1280, 780), mid-flip.
- `scout_shown.png`:
  - A full-size "Iron Fists" keeper card face-up, with its rare gold glow.
  - A blue "SCOUTED" ribbon above it.
  - A white "CLICK TO DISMISS" pill with a triangle below it.
- `scout_shrink.png`: the card, ribbon and pill are clearly smaller (about half size), and the dim is lighter.
- `scout_gone.png`: the plain match.

- [ ] **Step 8: Commit**

```bash
git add ui/overlay/reveal.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_reveal.lua
git commit -m "Restyle scout reveal: flip-up zoom card with SCOUTED ribbon"
```

---

### Task 13: Half-time ribbon and match-end screen

**Files:**
- Create: `ui/overlay/matchend.lua`
- Modify: `ui/match/banner.lua`, `ui/character.lua`, `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_banner.lua`, `tests/test_matchend.lua`

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_banner.lua`:

```lua
T.test("wide banners carry their own size and hold time", function()
    local b = Banner.new({ w = 1400, h = 84, y = 330, size = 46, hold = 2.4, slide = 1500 })
    T.eq(b.w, 1400); T.eq(b.y, 330); T.eq(b.size, 46)
    b:show("HALF TIME", "half")
    b:update(2.5); T.eq(b.text, "HALF TIME")
    b:update(0.6); T.eq(b.text, nil)
    local d = Banner.new(); T.eq(d.w, Banner.W); T.eq(d.hold, Banner.HOLD)
end)

T.test("pose honours a custom hold and slide", function()
    local dx = Banner.pose(Banner.IN + 2.3, 2.4, 1500); T.near(dx, 0)
    dx = Banner.pose(0, 2.4, 1500); T.near(dx, -1500)
    local _, a = Banner.pose(Banner.total(2.4), 2.4, 1500); T.near(a, 0, 1e-6)
end)
```

Create `tests/test_matchend.lua`:

```lua
local T        = require("tests.t")
local MatchEnd = require("ui.overlay.matchend")

T.test("half-time ribbon text", function()
    T.eq(MatchEnd.halfText(1, 1, 0), "HALF TIME · YOU 1 – 0 OPP")
    T.eq(MatchEnd.halfText(2, 1, 1), "FULL TIME · YOU 1 – 1 OPP · EXTRA TIME")
    T.eq(MatchEnd.halfText("extra", 2, 1), "EXTRA TIME OVER · YOU 2 – 1 OPP")
end)

T.test("match-end buttons and keys", function()
    local a, b = MatchEnd.PLAY_AGAIN, MatchEnd.MAIN_MENU
    T.eq(MatchEnd.actionAt(a.x + a.w / 2, a.y + a.h / 2), "restart")
    T.eq(MatchEnd.actionAt(b.x + b.w / 2, b.y + b.h / 2), "home")
    T.eq(MatchEnd.actionAt(640, 100), nil)
    T.ok(a.x + a.w < b.x); T.near((a.x + b.x + b.w) / 2, 640)
    T.eq(MatchEnd.keyAction("r"), "restart"); T.eq(MatchEnd.keyAction("escape"), "home")
    T.eq(MatchEnd.keyAction("space"), nil)
end)

T.test("title and summary rows", function()
    T.eq((MatchEnd.title("player")), "VICTORY!"); T.eq((MatchEnd.title("opponent")), "DEFEAT")
    local m = { players = { player   = { lp = 1200, halvesWon = 2, totalDamageDealt = 5400 },
                            opponent = { lp = -300, halvesWon = 1, totalDamageDealt = 3100 } } }
    local rows = MatchEnd.rows(m)
    T.eq(#rows, 3)
    T.eq(rows[1].label, "FINAL LP"); T.eq(rows[1].you, 1200); T.eq(rows[1].opp, 0)
    T.eq(rows[2].you, 2); T.eq(rows[2].opp, 1)
    T.eq(rows[3].you, 5400); T.eq(rows[3].opp, 3100)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: `FAIL` for both new banner tests and `FAIL  tests/test_matchend.lua (load error)`; then `136 passed, 3 failed`.

- [ ] **Step 3: Extend `ui/match/banner.lua`.**
  - In the `STYLES` table, add a line after the `error = …` line:

```lua
    half  = { fill = Theme.outcome.blue,        text = Theme.white,               shadow = true },
```

  - Replace everything from `function Banner.new()` down to the end of `function Banner:draw() … end` with:

```lua
-- opts (all optional): y, w, h, size, hold, slide. Defaults are the flash banner.
function Banner.new(opts)
    opts = opts or {}
    return setmetatable({
        text = nil, kind = "info", t = 0,
        y = opts.y or Banner.Y, w = opts.w or Banner.W, h = opts.h or Banner.H,
        size = opts.size or 32, hold = opts.hold or Banner.HOLD, slide = opts.slide or Banner.SLIDE,
    }, Banner)
end

function Banner.total(hold) return Banner.IN + (hold or Banner.HOLD) + Banner.OUT end

function Banner:show(text, kind)
    self.text, self.kind, self.t = text, kind or "info", 0
end

function Banner:update(dt)
    if not self.text then return end
    self.t = self.t + dt
    if self.t >= Banner.total(self.hold) then self.text = nil end
end

-- x offset and alpha at time t (hold/slide default to the flash banner's).
function Banner.pose(t, hold, slide)
    hold, slide = hold or Banner.HOLD, slide or Banner.SLIDE
    if t < Banner.IN then
        local k = 1 - t / Banner.IN
        return -slide * k * k * k, 1
    elseif t < Banner.IN + hold then
        return 0, 1
    end
    local k = math.min(1, (t - Banner.IN - hold) / Banner.OUT)
    return slide * k * k, 1 - k
end

function Banner:draw()
    if not self.text then return end
    local dx, a = Banner.pose(self.t, self.hold, self.slide)
    local st = STYLES[self.kind] or STYLES.info
    Draw.ribbon(Layout.midX + dx, self.y, self.w, self.h, self.text, {
        fill = st.fill, textColor = st.text, size = self.size, alpha = a, textShadow = st.shadow,
    })
end
```

- [ ] **Step 4: Let `Character.drawPortrait` take a state override.** In `ui/character.lua`, replace:

```lua
function Character.drawPortrait(x, y, w, h)
    if not loaded then return end
    local img = imgs[state] or imgs.thinking
```

with:

```lua
-- stateOverride forces an expression for this draw only (match-end screen).
function Character.drawPortrait(x, y, w, h, stateOverride)
    if not loaded then return end
    local img = imgs[stateOverride or state] or imgs.thinking
```

- [ ] **Step 5: Create `ui/overlay/matchend.lua`**

```lua
-- Half-time ribbon text and the match-end screen. Win: gold VICTORY! with the happy
-- (attacking) pose and confetti (scenes/match.lua bursts it). Loss: grey-blue DEFEAT with
-- the worried pose. Final LP, halves and LP damage; PLAY AGAIN / MAIN MENU.
-- Text, layout and input mapping are pure (unit-tested); draw uses LÖVE.
-- Actions: "restart" (same deck) | "home".
local Theme     = require("ui.theme")
local Draw      = require("ui.kit.draw")
local Button    = require("ui.kit.button")
local Character = require("ui.character")
local C         = require("ui.overlay.combatfx")   -- progress / backout

local MatchEnd = {}

MatchEnd.PLAY_AGAIN = { x = 395, y = 628, w = 230, h = 68 }
MatchEnd.MAIN_MENU  = { x = 655, y = 628, w = 230, h = 68 }
MatchEnd.PORTRAIT   = { x = 250, y = 240, w = 280, h = 340 }
MatchEnd.STATS      = { x = 570, y = 260, w = 460, h = 300 }

-- Ribbon text when a half ends without a winner. you/opp = halves won so far.
function MatchEnd.halfText(half, you, opp)
    local score = "YOU " .. you .. " – " .. opp .. " OPP"
    if half == 1 then return "HALF TIME · " .. score end
    if half == 2 then return "FULL TIME · " .. score .. " · EXTRA TIME" end
    return "EXTRA TIME OVER · " .. score
end

function MatchEnd.title(winner)
    if winner == "player" then return "VICTORY!", "win" end
    return "DEFEAT", "loss"
end

function MatchEnd.rows(match)
    local p, o = match.players.player, match.players.opponent
    return {
        { label = "FINAL LP",  you = math.max(0, p.lp),        opp = math.max(0, o.lp) },
        { label = "HALVES",    you = p.halvesWon or 0,         opp = o.halvesWon or 0 },
        { label = "LP DAMAGE", you = p.totalDamageDealt or 0,  opp = o.totalDamageDealt or 0 },
    }
end

local function inRect(x, y, r) return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

function MatchEnd.actionAt(x, y)
    if inRect(x, y, MatchEnd.PLAY_AGAIN) then return "restart" end
    if inRect(x, y, MatchEnd.MAIN_MENU) then return "home" end
    return nil
end

function MatchEnd.keyAction(key)
    if key == "r" then return "restart" end
    if key == "escape" then return "home" end
    return nil
end

-- ── LÖVE ──────────────────────────────────────────────────────────────────────

local WIN_FILL  = { Theme.hex("ffe08a"), Theme.hex("ffb43a") }
local LOSS_FILL = { Theme.hex("aab4cf"), Theme.hex("6b7896") }
local buttons = nil

-- t: seconds since the screen appeared; mx, my: match mouse.
function MatchEnd.draw(match, t, mx, my)
    if not buttons then
        local A, M = MatchEnd.PLAY_AGAIN, MatchEnd.MAIN_MENU
        buttons = {
            Button.new({ id = "restart", label = "PLAY AGAIN", variant = "go", fontSize = 28,
                         x = A.x, y = A.y, w = A.w, h = A.h }),
            Button.new({ id = "home", label = "MAIN MENU", variant = "neutral", fontSize = 28,
                         x = M.x, y = M.y, w = M.w, h = M.h }),
        }
    end
    local won = match.winner == "player"
    love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.78 * C.progress(t, 0, 0.3))
    love.graphics.rectangle("fill", 0, 0, 1280, 800)

    local pop = C.backout(C.progress(t, 0.05, 0.4))
    love.graphics.push()
    love.graphics.translate(640, 152)
    love.graphics.scale(pop, pop)
    love.graphics.translate(-640, -152)
    Draw.ribbon(640, 104, 560, 96, (MatchEnd.title(match.winner)), {
        fill = won and Theme.outcome.yellow or Theme.outcome.grey,
        textColor = won and Theme.button.primary.text or Theme.white, size = 72, textShadow = not won,
    })
    love.graphics.pop()

    local P = MatchEnd.PORTRAIT
    Draw.sticker(P.x, P.y, P.w, P.h, { r = 24, fill = won and WIN_FILL or LOSS_FILL, border = 5, shadow = 7 })
    Character.drawPortrait(P.x + 5, P.y + 5, P.w - 10, P.h - 10, won and "attacking" or "worried")

    local S = MatchEnd.STATS
    Draw.sticker(S.x, S.y, S.w, S.h, { r = 24, fill = Theme.white, border = 0, shadow = 7 })
    Draw.text("YOU", S.x + 200, S.y + 22, 110, "center", { size = 22, color = Theme.grad.lpYou[2] })
    Draw.text("OPP", S.x + 320, S.y + 22, 110, "center", { size = 22, color = Theme.grad.lpOpp[2] })
    for i, row in ipairs(MatchEnd.rows(match)) do
        local y = S.y + 64 + (i - 1) * 72
        Draw.text(row.label, S.x + 24, y + 12, 170, "left", { size = 22, color = Theme.inkText, fit = true })
        Draw.pill(S.x + 200, y, 110, 48, tostring(row.you), { fill = Theme.grad.lpYou, textColor = Theme.white, size = 26 })
        Draw.pill(S.x + 320, y, 110, 48, tostring(row.opp), { fill = Theme.grad.lpOpp, textColor = Theme.white, size = 26 })
    end

    local dt, down = love.timer.getDelta(), love.mouse.isDown(1)
    for _, b in ipairs(buttons) do
        b:update(dt, mx or -1, my or -1, down)
        b:draw()
    end
    Draw.text("R  PLAY AGAIN   ·   ESC  MAIN MENU", 0, 716, 1280, "center", {
        size = 14, body = true, color = Theme.white, shadowY = 1,
    })
end

return MatchEnd
```

- [ ] **Step 6: Wire it into `scenes/match.lua`.**
  - Add after `local Reveal             = require("ui.overlay.reveal")`:

```lua
local MatchEnd           = require("ui.overlay.matchend")
```

  - Replace:

```lua
local toasts = Toasts.new()
local banner = Banner.new()
```

with:

```lua
local toasts = Toasts.new()
local banner = Banner.new()

-- Half-time ribbon (full width) and the match-end screen
local HALF_BANNER = { y = 318, w = 1400, h = 84, size = 46, hold = 2.4, slide = 1500 }
local halfBanner  = Banner.new(HALF_BANNER)
local pendingHalf = nil   -- half-time text waiting for the overlays to clear
local winT        = nil   -- seconds since the match-end screen appeared
```

  - In `Match.enter`, directly after `    banner              = Banner.new()`, add:

```lua
    halfBanner          = Banner.new(HALF_BANNER)
    pendingHalf         = nil
    winT                = nil
```

  - In `Match.update`, replace `    banner:update(dt)` with:

```lua
    banner:update(dt)
    halfBanner:update(dt)
```

  - In the log scan in `Match.update`, replace:

```lua
        elseif evt.type == "card_drawn" then
            Match.spawnDrawAnim(p.player == "player")
        end
```

with:

```lua
        elseif evt.type == "card_drawn" then
            Match.spawnDrawAnim(p.player == "player")
        elseif evt.type == "half_end" and not match.winner then
            pendingHalf = MatchEnd.halfText(p.half, match.players.player.halvesWon or 0,
                match.players.opponent.halvesWon or 0)
        end
```

  - In `Match.update`, insert directly above the line `    if activeCombat then return end` (the one followed by `    if activeTrapActiv then return end`):

```lua
    -- Half-time ribbon and match-end screen wait until the overlays are dismissed
    local overlaysClear = not activeCombat and not activeTrapActiv and #combatQueue == 0 and #trapActivQueue == 0
    if pendingHalf and overlaysClear then
        halfBanner:show(pendingHalf, "half")
        pendingHalf = nil
    end
    if match.winner and overlaysClear then
        local prevWin = winT
        winT = (winT or 0) + dt
        if match.winner == "player" and (not prevWin or math.floor(prevWin / 1.4) ~= math.floor(winT / 1.4)) then
            Confetti.burst(math.random(260, 1020), 180, 90)
        end
    end

```

  - In `Match.draw`, replace:

```lua
    -- Confetti
    Confetti.draw()
```

with:

```lua
    -- Confetti (drawn above the match-end screen instead, once it is up)
    if not winT then Confetti.draw() end
```

  - In `Match.draw`, replace `    banner:draw()` with:

```lua
    banner:draw()
    halfBanner:draw()
```

  - In `Match.draw`, replace `    if match.winner then Match.drawWinScreen(match) end` with:

```lua
    if winT then
        MatchEnd.draw(match, winT, mouseX, mouseY)
        Confetti.draw()
    end
```

  - Delete the whole `function Match.drawWinScreen(match)` through its closing `end`.
  - In `Match.mousepressed`, replace:

```lua
    if button ~= 1 then return end

    -- Dismiss scout reveal overlay
```

with:

```lua
    if button ~= 1 then return end

    -- Match-end screen: PLAY AGAIN / MAIN MENU
    if winT then return MatchEnd.actionAt(x, y) end

    -- Dismiss scout reveal overlay
```

  - In `Match.keypressed`, insert directly above `    if activeTrapActiv then`:

```lua
    if winT then return MatchEnd.keyAction(key) end

```

  - In `Match.keypressed`, delete these two lines:

```lua
    elseif key == "r" and store.match and store.match.winner then
        return "restart"
```

Run: `grep -n 'drawWinScreen\|key == "r"' scenes/match.lua`
Expected: no output.

- [ ] **Step 7: Add the `halftime`, `victory` and `defeat` scenarios.** In `tools/snapshot/scenarios.lua`, insert directly above `return S`:

```lua
-- Half time (harness-only: zero the opponent's LP and let the store end the half).
S.halftime = {
    { 0.3,  function() math.randomseed(7) end },
    { 0.5,  kickOff },
    { 1.5,  function()
        local st = store()
        st.match.players.opponent.lp = 0
        st:_checkHalf()
    end },
    { 1.72, function(c) c.snap("slide") end },
    { 2.4,  function(c) c.snap("ribbon") end },
    { 4.9,  function(c) c.snap("after") end },
    { 5.2,  function(c) c.quit() end },
}

-- Victory (harness-only: you already won a half; win the second), then R to play again.
S.victory = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        st.match.players.player.halvesWon = 1
        st.match.players.player.totalDamageDealt = 4000
        st.match.players.opponent.lp = 0
        st:_checkHalf()
    end },
    { 1.62, function(c) c.snap("pop") end },
    { 2.6,  function(c) c.snap("win") end },
    { 2.7,  function() move(center(require("ui.overlay.matchend").PLAY_AGAIN)) end },
    { 3.0,  function(c) c.snap("hover") end },
    { 3.1,  function() love.keypressed("r") end },
    { 3.6,  function(c) c.snap("again") end },
    { 3.8,  function(c) c.quit() end },
}

-- Defeat (harness-only), then ESC to the main menu.
S.defeat = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        st.match.players.opponent.halvesWon = 1
        st.match.players.player.lp = 0
        st:_checkHalf()
    end },
    { 2.6, function(c) c.snap("loss") end },
    { 2.7, function() love.keypressed("escape") end },
    { 3.1, function(c) c.snap("home") end },
    { 3.3, function(c) c.quit() end },
}
```

- [ ] **Step 8: Syntax check, tests, snapshots**

Run: `luac -p ui/match/banner.lua ui/character.lua ui/overlay/matchend.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua && for s in halftime victory defeat juice; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected:
- no `luac` output;
- `141 passed, 0 failed`;
- PNGs listed: `halftime_after`, `halftime_ribbon`, `halftime_slide`; `victory_again`, `victory_hover`, `victory_pop`, `victory_win`; `defeat_home`, `defeat_loss`; the `juice_*` PNGs;
- no `FAILED`, no Lua error.

- [ ] **Step 9: Review with the Read tool:**

- `halftime_slide.png`: a blue ribbon wider than the screen, partly slid in from the left, at y≈318 (×2 = 636).
- `halftime_ribbon.png`:
  - The blue ribbon spans the full width, reading "HALF TIME · YOU 1 – 0 OPP". The en dash renders; there are no box glyphs.
  - The top bar shows one filled ⚽ pip for you.
- `halftime_after.png`:
  - The ribbon is gone.
  - The phase pill reads "HALF 2 · TURN 1 · …" and both LP bars are full again.
- `victory_pop.png`: a navy dim fading in, and a gold "VICTORY!" ribbon that is small or growing, with confetti.
- `victory_win.png`:
  - A gold "VICTORY!" ribbon (dark-brown text) at the top.
  - A gold portrait sticker with the attacking character art on the left.
  - A white stats panel with YOU (green) / OPP (red) columns: FINAL LP 4000 / 0, HALVES 2 / 0, LP DAMAGE 4000 / 0.
  - A green PLAY AGAIN button and a white MAIN MENU button, and a key hint line.
  - Confetti above the dim.
- `victory_hover.png`: the PLAY AGAIN button is lifted (hover).
- `victory_again.png`:
  - A fresh match: turn 1, full LP bars, no pips, no match-end screen.
  - The same deck (The Beautiful Game): the hand renders as in `match_start`.
- `defeat_loss.png`:
  - A grey-blue "DEFEAT" ribbon with white text.
  - A grey-blue portrait sticker with the worried art.
  - FINAL LP 0 / 4000 and HALVES 0 / 2.
  - No confetti.
- `defeat_home.png`: the arcade home menu.
- `juice_*.png`: unchanged from Plan B (the flash banner still works with the new `Banner.new`).

- [ ] **Step 10: Commit**

```bash
git add ui/match/banner.lua ui/character.lua ui/overlay/matchend.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_banner.lua tests/test_matchend.lua
git commit -m "Add half-time ribbon and arcade victory/defeat screen"
```

---

### Task 14: Remove legacy tokens and dead code

**Files:**
- Modify: `ui/theme.lua`, `ui/card.lua`, `ui/character.lua`, `scenes/match.lua`, `tools/snapshot/card_gallery.lua`, `tests/test_theme.lua`
- Delete: `lib/moonshine/`

- [ ] **Step 1: Write the failing test.** Append to `tests/test_theme.lua`:

```lua
T.test("legacy tokens are gone", function()
    for _, k in ipairs({ "cardColors", "cardArt", "cardAccents", "cardColorsDim", "cardHeaders", "atkColor",
        "defColor", "pitch", "hud", "logColors", "phases", "card", "pitchCard", "slot", "layout", "font",
        "exhaustOverlay", "settlingOverlay" }) do
        T.eq(Theme[k], nil, "Theme." .. k .. " still exists")
    end
end)
```

Run: `lua tests/run.lua`
Expected: `FAIL  legacy tokens are gone`; then `141 passed, 1 failed`.

- [ ] **Step 2: Prove nothing reads the legacy tokens**

Run: `grep -rnE 'Theme\.(cardColors|cardArt|cardAccents|cardColorsDim|cardHeaders|atkColor|defColor|pitch|hud|logColors|phases|card|pitchCard|slot|layout|font|exhaustOverlay|settlingOverlay)([^A-Za-z]|$)' --include='*.lua' . | grep -v '^./ui/theme.lua'`
Expected: no output. If anything prints, migrate that caller to arcade tokens before continuing.

- [ ] **Step 3: Replace `ui/theme.lua` entirely**

```lua
-- All colors and visual constants (arcade style).
local Theme = {}

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
    blue    = { fill = { hex("6ac8ff"), hex("1f78e0") }, text = { 1, 1, 1, 1 }, shadow = hex("0f4a9a") },
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

-- Result ribbons, trap purple, match-end grey (overlays).
Theme.outcome = {
    red    = { hex("ff8a8a"), hex("e0243a") },
    orange = { hex("ffc15a"), hex("f07a0c") },
    blue   = { hex("6ac8ff"), hex("1f78e0") },
    yellow = { hex("ffd23a"), hex("ff9a1a") },
    grey   = { hex("d7dcea"), hex("8f99b5") },
    purple = { hex("c77dff"), hex("7b2cbf") },
}

-- Deck-select tiles (keys match data/presetDecks.lua).
Theme.deckFill = {
    tikitaka   = { hex("6ee7a0"), hex("16a34a") },
    longball   = { hex("ff7a59"), hex("e0243a") },
    catenaccio = { hex("4fb8ff"), hex("2563eb") },
}

-- Navy dim behind menus and overlays.
Theme.dim = hex("1d1d59", 0.72)

return Theme
```

- [ ] **Step 4: Remove `Card.drawTooltip`**

Run: `grep -rn 'drawTooltip' --include='*.lua' .`
Expected: only `ui/card.lua` (the header comment and the function) and `tools/snapshot/card_gallery.lua`.

- In `ui/card.lua`, delete the header line `--   Card.drawTooltip(cardDef, x, y)`. Also delete the whole `function Card.drawTooltip(cardDef, x, y)` through its closing `end`, which is directly above the `-- Big card face with the info sticker …` comment.
- In `tools/snapshot/card_gallery.lua`, replace `    Card.drawTooltip(rare, x, y)` with:

```lua
    Card.drawInfo(rare, x, y, 230)
```

Run: `grep -rn 'drawTooltip' --include='*.lua' .`
Expected: no output.

- [ ] **Step 5: Remove the dead character code**

Run: `grep -rn 'Character\.drawSide\|Character\.draw(' --include='*.lua' . | grep -v '^./ui/character.lua'`
Expected: no output.

In `ui/character.lua`:
- Delete the line `local Fonts = require("ui.fonts")`.
- Delete the whole `local LABEL = { … }` table and the whole `local COLOR = { … }` table.
- Delete `function Character.drawSide(side, screenW, screenH, overrideState)` and its comment block through its closing `end`.
- Delete `function Character.draw(screenW, screenH)` through its closing `end`.
- Add at the top of the file:

```lua
-- Player character art (assets/characters/1_*.png): expression state machine plus the
-- bottom-left portrait and the round top-bar avatar.
```

Run: `grep -n 'Fonts\|LABEL\|COLOR\|drawSide\|setScissor' ui/character.lua`
Expected: no output.

- [ ] **Step 6: Drop unused requires in `scenes/match.lua`**

Run: `grep -c 'Theme\.' scenes/match.lua; grep -c 'Fonts\.' scenes/match.lua`
Expected: `0` and `0`. If both are 0, delete the lines `local Theme         = require("ui.theme")` and `local Fonts         = require("ui.fonts")`. If either is not 0, keep that require.

- [ ] **Step 7: Delete `lib/moonshine`**

Run: `grep -rn 'moonshine' --include='*.lua' . | grep -v '^./lib/moonshine/'`
Expected: no output.
Run: `git rm -r -q lib/moonshine`

- [ ] **Step 8: Syntax check, tests, snapshots**

Run: `luac -p ui/theme.lua ui/card.lua ui/character.lua scenes/match.lua tools/snapshot/card_gallery.lua && lua tests/run.lua && for s in cards match victory; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: no `luac` output; `142 passed, 0 failed`; `cards_gallery`, `match_start`, `match_later` and the 4 `victory_*` PNGs listed; no `FAILED`, no Lua error.

- [ ] **Step 9: Review with the Read tool:**

- `cards_gallery.png`: identical to Plan A, except that the row-2 tooltip slot now shows the same white info sticker drawn by `Card.drawInfo`.
- `match_start.png` and `victory_win.png`: unchanged from Tasks 6 and 13.

- [ ] **Step 10: Commit**

```bash
git add -A ui/theme.lua ui/card.lua ui/character.lua scenes/match.lua tools/snapshot/card_gallery.lua tests/test_theme.lua lib
git commit -m "Remove legacy theme tokens, drawTooltip, old character draws and moonshine"
```

---

### Task 15: Final check

**Files:** none (verification only)

- [ ] **Step 1: Unit tests**

Run: `lua tests/run.lua`
Expected: `142 passed, 0 failed`

- [ ] **Step 2: No gameplay changes**

Run: `git diff --stat 54e39e1 -- engine store ai`
Expected: no output. (`54e39e1` is the last Plan B commit.)

- [ ] **Step 3: Legacy tokens and removed modules are gone**

Run: `grep -rnE 'Theme\.(cardColors|cardArt|cardAccents|cardColorsDim|cardHeaders|atkColor|defColor|pitch|hud|logColors|phases|card|pitchCard|slot|layout|font|exhaustOverlay|settlingOverlay)([^A-Za-z]|$)' --include='*.lua' .; grep -n 'Legacy' ui/theme.lua`
Expected: no output.

Run: `grep -rn 'ui\.card_library\|ui\.pause_menu\|ui\.combat_overlay\|ui\.trap_activation_overlay\|ui\.cover_prompt\|ui\.trap_prompt\|lib\.moonshine\|drawTooltip\|drawSide\|drawTrapWindow\|drawScoutReveal\|drawWinScreen\|overlayAnim\|trapActivAnim' --include='*.lua' .`
Expected: no output.

Run: `ls ui/card_library.lua ui/pause_menu.lua ui/combat_overlay.lua ui/trap_activation_overlay.lua ui/cover_prompt.lua ui/trap_prompt.lua lib/moonshine 2>&1 | grep -c 'No such file'`
Expected: `7`

- [ ] **Step 4: Every scenario runs clean**

Run: `for s in home library match cards summon juice debug pause combat trap cover trapwin scout halftime victory defeat; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback on stderr.

- [ ] **Step 5: Review every PNG with the Read tool** against the checklists in Tasks 6, 7 and 9–14, plus:
  - `summon_*`, `juice_*` and `debug_*` still match the Plan B checklists. `debug_pause` now shows the arcade pause menu.
  - No PNG shows a box glyph (▯) anywhere.
  - No screen shows any of the old dark-maroon or purple panels.

- [ ] **Step 6: Report to the user.**
  - Summarize what changed.
  - Show these screenshots: `home_menu`, `home_deck`, `library_hover`, `pause_menu`, `combat_shatter`, `combat_save`, `trap_full`, `cover_panel`, `trapwin_panel`, `scout_shown`, `halftime_ribbon`, `victory_win`, `defeat_loss`.
  - List the intentional deviations from this plan's header.

  Tell the user that an **interactive play-test is required**, because the harness cannot do it. They should play at least one full match vs. the AI to completion and check the following:
  - **Home:**
    - ↑/↓ moves focus (wrapping); Enter activates; mouse hover moves the focus; Esc quits the game.
    - PLAY opens deck select. CARD LIBRARY opens the library. QUIT exits.
  - **Deck select:**
    - ←/→ changes the lifted tile; Enter or KICK OFF starts with that deck.
    - Clicking a tile selects it, and clicking it again starts.
    - BACK and Esc return home.
    - Try all three decks.
  - **Library (from home and from pause):**
    - Tab clicks and ←/→; wheel and ↑/↓ scrolling stops at both ends.
    - The hover zoom stays on screen near the right edge and the bottom rows.
    - Esc and ✕ close it and return to the right place (home, or the pause menu).
  - **Pause:**
    - Opens via `ESC` and via ⏸, with the bounce.
    - ↑/↓/Enter and clicks; RESUME; CARD LIBRARY; QUIT TO MENU.
  - **Combat overlay:**
    - Your attacks and AI attacks each dismiss by click, `Space` and `Enter`.
    - A face-down defender flips at the clash; a destroyed card shatters.
    - The GOAL / LP banner and confetti appear at the clash.
    - The keeper Eff. DEF bonus tag is shown.
  - **Trap activation:** trigger OFFSIDE / RED CARD / VAR from both sides and dismiss each by click or `Space`.
  - **Cover prompt:**
    - When the AI attacks an empty slot, the panel slides up and the pitch stays visible.
    - COVER on each coverer (button and card) and LET THROUGH both resolve correctly.
  - **Trap window:** ACTIVATE (button and card) and PASS, including a counter window (Manager's Challenge vs OFFSIDE).
  - **Scout Report:** the card flips up, the reveal auto-hides after about 3.5s, and a click dismisses it early.
  - **Half time:**
    - The ribbon appears after the half-ending combat is dismissed, with the right score.
    - If both of you reach 1–1, the extra-time text appears.
  - **Match end:**
    - VICTORY and DEFEAT screens with the right numbers.
    - PLAY AGAIN and `R` restart with the same deck; MAIN MENU and `ESC` go home.

---

## Self-review: spec §3, §4 and §1 cleanup coverage

| Spec item | Task |
|---|---|
| §3 Home: Lilita logo, white outline, navy shadow, gentle bob, football icon | 3 (`drawLogo`, `HomeMenu.bob`), 6 |
| §3 Home: slow-scrolling soft diagonal stripes + faded card backs in the corners | 3 (`ui/menu/backdrop.lua`), 6 |
| §3 Home: PLAY (primary) / CARD LIBRARY (neutral/blue) / QUIT (danger), ↑/↓/Enter/Esc + mouse | 1 (`button.blue`), 2 (`Flow`), 3, 6 |
| §3 Deck select: 3 tiles green/red/blue with name, subtitle, description | 1 (`deckFill`), 4, 6 |
| §3 Deck select: fanned stack of 3 real cards peeking over the top | 4 (`DeckSelect.showcase`, `drawFan`) |
| §3 Deck select: selected tile lifts/scales with a yellow ring | 4 (`lifts`, `LIFT`) |
| §3 Deck select: BACK / KICK OFF, ←/→/Enter/Esc (Esc → home) | 2, 4, 6 |
| §3 Pause: navy dim, white panel pops in with bounce, PAUSED ribbon, 3 buttons | 7 |
| §3 Library: pill tabs (active filled), hand-size real cards, wheel scroll | 5, 6 |
| §3 Library: hover zoom (`ui/match/zoom`), Esc or ✕ closes | 1 (`Draw.cross`), 5, 6, 7 |
| §4 Behaviour, data contracts and inputs unchanged | 9–12 (same records/hitbox shapes, click/Space/Enter), 15 |
| §4 Combat: navy dim, zoom cards slide in L/R with squash-bounce | 8 (`pose`, `squash`), 9 |
| §4 Combat: CLASH! starburst + shake | 1 (`Draw.burst`), 8 (`shake`), 9 |
| §4 Combat: ATK/DEF badges grow and count up | 8 (`badge`, `count`, `countValue`), 9 |
| §4 Combat: beam sprites kept, tinted | 9 (`drawBeam`) |
| §4 Combat: result ribbon colours (red / orange / blue / yellow) | 1 (`Theme.outcome`), 8 (`Fx.result`), 9 |
| §4 Combat: destroyed card shatters | 8 (`shatterPieces`, `piecePose`), 9 |
| §4 Combat: Eff. DEF bonus tag | 8 (`cardView`), 9 (`drawBadges`) |
| §4 Combat: "CLICK OR SPACE ▶" pill | 1 (`Draw.hintPill`), 9 |
| §4 Trap activation: purple flash, flip with spin + scale | 10 |
| §4 Trap activation: stamp slams with bounce + dust puff | 10 (`stampScale`, `dustPuffs`) |
| §4 Trap activation: ribbon "YOU ACTIVATED A TRAP" / "OPPONENT TRAP" + context | 10 (`headline`, `effectText`) |
| §4 Cover prompt: bottom panel slides up, pitch visible | 11 (`PromptPanel.layout`, `promptAnim`) |
| §4 Cover prompt: attacker card left, coverers pulse on pitch + small cards | 11 (`Prompts.drawCover`) |
| §4 Cover prompt: COVER (go) / LET THROUGH (neutral) | 11 |
| §4 Trap window: same panel, ACTIVATE per trap, PASS | 11 (`Prompts.drawTrapWindow`, `trapHitboxes`) |
| §4 Scout reveal: flip up at zoom size, SCOUTED ribbon, shrinks at timer end | 12 |
| §4 Half end: full-width ribbon "HALF TIME · YOU 1 – 0 OPP" slides across | 13 (`Banner` options, `MatchEnd.halfText`) |
| §4 Match end: gold VICTORY! + confetti + happy pose / grey-blue DEFEAT + worried pose | 13 (`MatchEnd.draw`, `drawPortrait` override) |
| §4 Match end: final LP and halves; PLAY AGAIN / MAIN MENU | 6 (`main.lua` restart), 13 |
| §1 Legacy tokens removed once unused | 14 |
| Dead modules/functions: `drawTooltip`, `drawSide`/`draw`, `trap_prompt`, `moonshine` | 11, 14 |
| §5 phases 4–5 keep the game playable after every commit | Task order 1–14 (each task wires only complete replacements) |
| §6 Verification: harness screenshots of every screen, no engine/store/ai diff, play-test | 6, 7, 9–14, 15 |

**Placeholder scan:** every code step contains complete code. There are no "TBD", "similar to" or "add appropriate …" steps. Deletions name exact first and last lines and are followed by a grep.

**Name and signature consistency:**

| Name | Signature | Tasks |
|---|---|---|
| `Match.debugOverlay` | `(kind, rec)` | defined in 9; used in 9, 10, 12 |
| `CombatOverlay.draw` | `(rec, t)` | 9 |
| `TrapActivOverlay.draw` | `(rec, t)` | 10 |
| `Prompts.drawCover` / `Prompts.drawTrapWindow` | `(window, slide, mx, my)` → hitboxes | 11 |
| `PromptPanel.coverHitboxes` / `PromptPanel.trapHitboxes` | `(window, slide)` | 11; `coverHitboxes` also used by `advance()` |
| `Reveal.draw` | `(pitched, elapsed, remaining)` | 12 |
| `MatchEnd.draw` | `(match, t, mx, my)` | 13 |
| `Banner.new` | `(opts)` | 13 |
| `Banner.pose` | `(t, hold, slide)` | 13 |
| `Library.update` | `(dt, mx, my)` | 5; used in 6 |
| `Pause.update` | `(dt, mx, my)` | 7 |
| `HomeMenu.update` | `(dt, mx, my, focus)` | 3; used in 6 |
| `DeckSelect.update` | `(dt, mx, my, selected)` | 4; used in 6 |
| `DeckSelect.draw` | `(selected)` | 4; used in 6 |

The scenario helpers `kickOff` (Task 6), `defById` and `snapFrom` (Task 9) and `pitched` (Task 11) are each defined before the first scenario that uses them.

### Critical Files for Implementation
- /Users/mac/Documents/football-tcg-lua/scenes/match.lua
- /Users/mac/Documents/football-tcg-lua/scenes/home.lua
- /Users/mac/Documents/football-tcg-lua/ui/overlay/combat.lua (new)
- /Users/mac/Documents/football-tcg-lua/ui/overlay/prompts.lua (new)
- /Users/mac/Documents/football-tcg-lua/tools/snapshot/scenarios.lua