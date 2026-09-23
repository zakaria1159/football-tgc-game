# Arcade Redesign — Plan A: Cleanup, Assets & Design System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Gwent mode, add the arcade fonts/icons, build the shared `ui/kit/` design system, and replace the card renderer with the Clash-portrait card — leaving the game fully playable with the new cards inside the old layout.

**Architecture:** New arcade tokens are *added* to `ui/theme.lua` next to the legacy tokens (legacy is removed in Plan C once no screen uses it). All drawing primitives live in `ui/kit/` and never use scissor or stencil (the whole scene renders inside a moonshine canvas without a stencil buffer, and the hand will be rotated in Plan B) — rounded gradients and cropped portraits are drawn as triangle-fan meshes instead. `ui/card.lua` is rewritten but keeps its public API (`drawPitched`, `drawInHand`, `drawTooltip`, `drawLarge`) so existing callers keep working.

**Tech Stack:** LÖVE 11.4 (LuaJIT / Lua 5.1 semantics — no `//`, use `table.unpack or unpack`), `lib/flux.lua` for tweens, plain `lua` 5.5 (`/opt/homebrew/bin/lua`) for unit tests of pure logic.

**Spec:** `docs/superpowers/specs/2026-09-23-arcade-redesign-design.md` (§0, §1, §5 phases 1–2, §6).
**Branch:** `feat/arcade-redesign` (already checked out).

**Deviations from spec (intentional):**
- Spec §1 says `theme.lua` is "rewritten"; here new tokens are added and legacy tokens stay until Plan C, so un-migrated screens keep working.
- Card data has a 4th rarity, `legendary`, not in the spec — it gets color `#ff5ec8` and the same glow as rare.
- A reusable snapshot harness is committed under `tools/snapshot/` (spec §6 described it as a scratchpad copy; committing it lets every plan reuse it). Output goes to `.snapshots/` (gitignored).

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `tests/t.lua` | create | Tiny test framework (test/eq/near/ok/report) |
| `tests/run.lua` | create | Discovers and runs `tests/test_*.lua` |
| `tests/test_theme.lua` | create | Theme hex + token coverage |
| `tests/test_draw.lua` | create | Pure geometry helpers in kit/draw |
| `tests/test_icons.lua` | create | Type→icon mapping |
| `tests/test_button.lua` | create | Button hit/hover/press logic |
| `tests/test_tween.lua` | create | Tween helpers drive values via flux |
| `tests/test_card_layout.lua` | create | Card.layout geometry |
| `tools/snapshot/snap.sh` | create | Copies project to temp dir, runs a scenario, writes PNGs |
| `tools/snapshot/wrapper.lua` | create | Replacement `main.lua` that drives scenarios |
| `tools/snapshot/scenarios.lua` | create | Named, timed input/screenshot scripts |
| `tools/snapshot/card_gallery.lua` | create | Dev screen rendering every card size/state |
| `.gitignore` | modify | Ignore `.snapshots/` |
| `main.lua` | modify | Drop Gwent wiring |
| `scenes/home.lua` | modify | Drop mode step + Gwent deck list |
| Gwent files (11) | delete | See Task 2 |
| `assets/fonts/LilitaOne-Regular.ttf`, `Nunito-Black.ttf` | add | New fonts (OFL) |
| `assets/fonts/Anton-Regular.ttf`, `BebasNeue-Regular.ttf`, `m6x11.ttf` | delete | Old fonts |
| `assets/icons/*.png` (8) | add | game-icons.net icons (CC BY 3.0) |
| `README.md` | modify | Credits for fonts + icons |
| `ui/theme.lua` | modify | Add arcade tokens |
| `ui/fonts.lua` | rewrite | Lilita (display) + Nunito (body) |
| `ui/kit/draw.lua` | create | Sticker shapes, gradients, badges, ribbons, text |
| `ui/kit/icons.lua` | create | Load/draw tinted icons |
| `ui/kit/button.lua` | create | Chunky 3D button |
| `ui/kit/tween.lua` | create | popIn / bounce / squash / countTo |
| `ui/card.lua` | rewrite | Clash-portrait card renderer |

---

### Task 1: Test runner and snapshot harness

**Files:**
- Create: `tests/t.lua`, `tests/run.lua`
- Create: `tools/snapshot/snap.sh`, `tools/snapshot/wrapper.lua`, `tools/snapshot/scenarios.lua`
- Modify: `.gitignore`

- [ ] **Step 1: Create `tests/t.lua`**

```lua
-- Minimal test framework for pure-Lua modules. Run via: lua tests/run.lua
local T = { passed = 0, failed = 0, current = "?" }

function T.test(name, fn)
    T.current = name
    local ok, err = pcall(fn)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        print("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end

local function fmt(v)
    if type(v) == "table" then
        local parts = {}
        for i, x in ipairs(v) do parts[i] = tostring(x) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "eq") .. ": expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.near(actual, expected, eps, msg)
    eps = eps or 1e-6
    if type(actual) ~= "number" or math.abs(actual - expected) > eps then
        error((msg or "near") .. ": expected ~" .. fmt(expected) .. ", got " .. fmt(actual), 2)
    end
end

function T.ok(v, msg)
    if not v then error(msg or "expected truthy value", 2) end
end

function T.report()
    print(string.format("%d passed, %d failed", T.passed, T.failed))
    if T.failed > 0 then os.exit(1) end
end

return T
```

- [ ] **Step 2: Create `tests/run.lua`**

```lua
-- Runs every tests/test_*.lua file with plain Lua (no LÖVE).
-- Usage (from repo root): lua tests/run.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.t")
local p = io.popen("ls tests/test_*.lua 2>/dev/null")
local files = {}
for line in p:lines() do files[#files + 1] = line end
p:close()
table.sort(files)

for _, path in ipairs(files) do
    local mod = path:gsub("%.lua$", ""):gsub("/", ".")
    require(mod)
end
T.report()
```

- [ ] **Step 3: Run it to verify the runner works with zero tests**

Run: `lua tests/run.lua`
Expected: `0 passed, 0 failed`

- [ ] **Step 4: Create `tools/snapshot/snap.sh`**

```sh
#!/bin/sh
# Dev-only: run the game in a temp copy with a scripted scenario and save screenshots.
# Usage: tools/snapshot/snap.sh <scenario> [outdir]
# Scenarios are defined in tools/snapshot/scenarios.lua. PNGs land in <outdir>/<scenario>_<label>.png
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCEN="${1:?usage: snap.sh <scenario> [outdir]}"
OUT="${2:-$ROOT/.snapshots}"
TMP="$(mktemp -d)"
rsync -a --exclude .git --exclude .snapshots --exclude .superpowers "$ROOT/" "$TMP/"
mv "$TMP/main.lua" "$TMP/real_main.lua"
cp "$ROOT/tools/snapshot/wrapper.lua" "$TMP/main.lua"
mkdir -p "$OUT"
rm -f "$OUT/${SCEN}"_*.png
SNAP_OUT="$OUT" SNAP_SCENARIO="$SCEN" love "$TMP"
rm -rf "$TMP"
ls "$OUT/${SCEN}"_*.png
```

Then: `chmod +x tools/snapshot/snap.sh`

- [ ] **Step 5: Create `tools/snapshot/wrapper.lua`**

```lua
-- Dev-only snapshot driver. snap.sh copies the project to a temp dir, renames the
-- real main.lua to real_main.lua and installs this file as main.lua.
require("real_main")

local scenarios = require("tools.snapshot.scenarios")
local out   = assert(os.getenv("SNAP_OUT"), "SNAP_OUT not set")
local name  = os.getenv("SNAP_SCENARIO") or "home"
local steps = assert(scenarios[name], "unknown scenario: " .. name)

local ctx = {}
function ctx.snap(label)
    love.graphics.captureScreenshot(function(img)
        local f = assert(io.open(out .. "/" .. name .. "_" .. label .. ".png", "wb"))
        f:write(img:encode("png"):getString())
        f:close()
    end)
end
function ctx.quit() love.event.quit() end

local t, i = 0, 1
local baseUpdate = love.update
function love.update(dt)
    if baseUpdate then baseUpdate(dt) end
    t = t + dt
    while steps[i] and t >= steps[i][1] do
        steps[i][2](ctx)
        i = i + 1
    end
end
```

- [ ] **Step 6: Create `tools/snapshot/scenarios.lua`**

```lua
-- Timed scripts for tools/snapshot/snap.sh. Each step: { seconds, function(ctx) ... end }.
-- ctx.snap(label) saves a screenshot; ctx.quit() exits. Every scenario must end with ctx.quit().
local S = {}

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
    { 0.5, function() love.keypressed("return") end },       -- start with the first deck
    { 3.0, function(c) c.snap("start") end },
    { 9.0, function(c) c.snap("later") end },
    { 9.5, function(c) c.quit() end },
}

return S
```

- [ ] **Step 7: Ignore snapshot output**

Append to `.gitignore`:

```
.snapshots/
```

- [ ] **Step 8: Run the harness to capture a baseline**

Run: `tools/snapshot/snap.sh home`
Expected: prints `.../.snapshots/home_deck.png`. Open it with the Read tool — it shows the current (old) "CHOOSE MODE" screen. (Gwent is still present at this point; that's fine.)

- [ ] **Step 9: Commit**

```bash
git add tests/t.lua tests/run.lua tools/snapshot .gitignore
git commit -m "Add Lua test runner and snapshot harness"
```

---

### Task 2: Remove Gwent mode

**Files:**
- Delete: `scenes/gwent_match.lua`, `store/gwent.lua`, `ai/gwent_opponent.lua`, `data/gwent_decks.lua`, `engine/gwent/` (4 files), `engine/cards/definitions/gwent_gegenpresse.lua`, `engine/cards/definitions/gwent_monsters.lua`, `engine/cards/definitions/gwent_northern_realms.lua`, `engine/cards/definitions/gwent_tiki_taka.lua`, `football_tcg_gwent_mode_rules.md`
- Modify: `main.lua`, `scenes/home.lua`

- [ ] **Step 1: Delete the Gwent files**

```bash
git rm -q -r scenes/gwent_match.lua store/gwent.lua ai/gwent_opponent.lua data/gwent_decks.lua engine/gwent \
  engine/cards/definitions/gwent_gegenpresse.lua engine/cards/definitions/gwent_monsters.lua \
  engine/cards/definitions/gwent_northern_realms.lua engine/cards/definitions/gwent_tiki_taka.lua \
  football_tcg_gwent_mode_rules.md
```

- [ ] **Step 2: Replace `main.lua` entirely**

```lua
-- Football TCG — main.lua
math.randomseed(os.time())

local flux      = require("lib.flux")
local moonshine = require("lib.moonshine")
local Home      = require("scenes.home")
local Match     = require("scenes.match")
local Store     = require("store.match")
local Decks     = require("data.presetDecks")
local Audio     = require("ui.audio")

local currentScene = "home"
local store        = Store.new()
local fonts        = {}
local fxScene      = nil
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
    fxScene = moonshine(moonshine.effects.vignette)
    fxScene.vignette.radius   = 0.85
    fxScene.vignette.opacity  = 0.28
    fxScene.vignette.softness = 0.50
    Audio.load()
    Audio.playMusic("assets/audio/music/theme_home.ogg", 0.40)
end

function love.update(dt)
    flux.update(dt)
    if currentScene == "match" then Match.update(dt) end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(math.floor(camera.x), math.floor(camera.y))
    fxScene(function()
        love.graphics.clear(0.051, 0.008, 0.008, 1)
        if currentScene == "home" then
            Home.draw()
        elseif currentScene == "match" then
            Match.draw()
        end
    end)
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

- [ ] **Step 3: Edit `scenes/home.lua` — state and constants**

Replace the block from `-- Two-step flow: pick mode → pick deck` through the end of the `deckColors` table and the `MODE_BTN_*` constants (currently lines 9–38) with:

```lua
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
```

- [ ] **Step 4: Edit `scenes/home.lua` — replace `Home.draw` entirely**

```lua
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
```

- [ ] **Step 5: Edit `scenes/home.lua` — replace `Home.keypressed`, `Home.mousepressed`, `Home.reset` entirely**

```lua
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
```

- [ ] **Step 6: Confirm nothing references Gwent anymore**

Run: `grep -rni gwent --include='*.lua' .`
Expected: no output.

- [ ] **Step 7: Snapshot home, library and match**

Run: `tools/snapshot/snap.sh home && tools/snapshot/snap.sh library && tools/snapshot/snap.sh match`
Expected: all four PNGs are listed and no Lua error is printed. View each with the Read tool: home shows "CHOOSE YOUR FORMATION" with 3 decks (no mode screen); library shows the card grid; match shows the board with a hand.

- [ ] **Step 8: Commit**

```bash
git add -A main.lua scenes/home.lua
git commit -m "Remove Gwent mode"
```

(`git rm` in Step 1 already staged the deletions.)

---

### Task 3: Download fonts and icons (needs user approval)

**Files:**
- Add: `assets/fonts/LilitaOne-Regular.ttf`, `assets/fonts/Nunito-Black.ttf`
- Add: `assets/icons/soccer-kick.png`, `checked-shield.png`, `on-target.png`, `goal-keeper.png`, `wolf-trap.png`, `whistle.png`, `soccer-field.png`, `soccer-ball.png`
- Modify: `README.md`

- [ ] **Step 1: Ask the user to approve the downloads**

Present this list and wait for an explicit yes (the user's rules require approval for downloads):

| File | Source | License |
|---|---|---|
| `LilitaOne-Regular.ttf` | `https://github.com/google/fonts/raw/main/ofl/lilitaone/LilitaOne-Regular.ttf` | SIL OFL 1.1 |
| `Nunito-Black.ttf` | `https://cdn.jsdelivr.net/fontsource/fonts/nunito@latest/latin-900-normal.ttf` | SIL OFL 1.1 |
| 8 icon PNGs (512×512, white on transparent) | `https://game-icons.net/icons/ffffff/transparent/1x1/<author>/<name>.png` — `delapouite/soccer-kick`, `lorc/checked-shield`, `lorc/on-target`, `delapouite/goal-keeper`, `lorc/wolf-trap`, `delapouite/whistle`, `delapouite/soccer-field`, `delapouite/soccer-ball` | CC BY 3.0 (credit Delapouite & Lorc) |

- [ ] **Step 2: Download**

```bash
curl -sfL -o assets/fonts/LilitaOne-Regular.ttf https://github.com/google/fonts/raw/main/ofl/lilitaone/LilitaOne-Regular.ttf
curl -sfL -o assets/fonts/Nunito-Black.ttf https://cdn.jsdelivr.net/fontsource/fonts/nunito@latest/latin-900-normal.ttf
mkdir -p assets/icons
for p in delapouite/soccer-kick lorc/checked-shield lorc/on-target delapouite/goal-keeper lorc/wolf-trap delapouite/whistle delapouite/soccer-field delapouite/soccer-ball; do
  curl -sfL -o "assets/icons/$(basename $p).png" "https://game-icons.net/icons/ffffff/transparent/1x1/$p.png"
done
```

- [ ] **Step 3: Verify file types**

Run: `file assets/fonts/LilitaOne-Regular.ttf assets/fonts/Nunito-Black.ttf assets/icons/*.png`
Expected: both fonts report `TrueType Font data`; all 8 icons report `PNG image data, 512 x 512`. If any file is HTML or missing, stop and tell the user.

- [ ] **Step 4: Add credits to `README.md`** (append at the end)

```markdown

## Credits

- Fonts: [Lilita One](https://fonts.google.com/specimen/Lilita+One) by Juan Montoreano and [Nunito](https://fonts.google.com/specimen/Nunito) by Vernon Adams, Cyreal & Jacques Le Bailly — SIL Open Font License 1.1.
- Icons: [game-icons.net](https://game-icons.net) by Delapouite (soccer-kick, goal-keeper, whistle, soccer-field, soccer-ball) and Lorc (checked-shield, on-target, wolf-trap) — CC BY 3.0.
```

- [ ] **Step 5: Commit**

```bash
git add assets/fonts/LilitaOne-Regular.ttf assets/fonts/Nunito-Black.ttf assets/icons README.md
git commit -m "Add Lilita One / Nunito fonts and game-icons.net icons"
```

---

### Task 4: Arcade theme tokens

**Files:**
- Modify: `ui/theme.lua` (insert after `local Theme = {}` on line 2)
- Test: `tests/test_theme.lua`

- [ ] **Step 1: Write the failing test `tests/test_theme.lua`**

```lua
local T     = require("tests.t")
local Theme = require("ui.theme")

T.test("hex converts to 0..1 rgba", function()
    local c = Theme.hex("ff8000")
    T.near(c[1], 1); T.near(c[2], 128/255); T.near(c[3], 0); T.near(c[4], 1)
    T.near(Theme.hex("#000000", 0.5)[4], 0.5)
end)

T.test("every card type has a two-stop gradient and a label", function()
    for _, t in ipairs({ "striker", "defender", "midfielder", "keeper", "trap", "strategy", "formation" }) do
        local g = Theme.typeGrad[t]
        T.ok(g and g[1] and g[2], "missing typeGrad for " .. t)
        T.ok(Theme.typeLabel[t], "missing typeLabel for " .. t)
    end
end)

T.test("every rarity has a color", function()
    for _, r in ipairs({ "common", "uncommon", "rare", "legendary" }) do
        T.ok(Theme.rarityColors[r], "missing rarity " .. r)
    end
end)

T.test("card sizes match the spec", function()
    T.eq(Theme.cardSize.pitch.w, 108); T.eq(Theme.cardSize.pitch.h, 148)
    T.eq(Theme.cardSize.hand.w, 120);  T.eq(Theme.cardSize.hand.h, 165)
    T.eq(Theme.cardSize.zoom.w, 300);  T.eq(Theme.cardSize.zoom.h, 410)
end)

T.test("button variants have gradient, text and shadow colors", function()
    for _, v in ipairs({ "primary", "go", "danger", "neutral", "icon" }) do
        local b = Theme.button[v]
        T.ok(b and b.fill and b.text and b.shadow, "incomplete button variant " .. v)
    end
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL lines mentioning `attempt to call a nil value (field 'hex')` / nil `typeGrad`; exit code 1.

- [ ] **Step 3: Add the tokens to `ui/theme.lua`** — insert directly after `local Theme = {}`:

```lua
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `5 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/theme.lua tests/test_theme.lua
git commit -m "Add arcade theme tokens"
```

---

### Task 5: Fonts

**Files:**
- Rewrite: `ui/fonts.lua`
- Delete: `assets/fonts/Anton-Regular.ttf`, `assets/fonts/BebasNeue-Regular.ttf`, `assets/fonts/m6x11.ttf`

- [ ] **Step 1: Replace `ui/fonts.lua` entirely**

```lua
-- Font cache. Display = Lilita One (headings, numbers, buttons, card names).
-- Body = Nunito Black (ability text, toasts, hints).
local Fonts = {}

local DISPLAY = "assets/fonts/LilitaOne-Regular.ttf"
local BODY    = "assets/fonts/Nunito-Black.ttf"

local _display, _body = {}, {}

local function load(cache, path, size)
    size = math.max(6, math.floor(size + 0.5))
    if cache[size] then return cache[size] end
    local ok, f = pcall(love.graphics.newFont, path, size)
    if not ok then f = love.graphics.newFont(size) end
    f:setFilter("linear", "linear")
    cache[size] = f
    return f
end

function Fonts.get(size)  return load(_display, DISPLAY, size) end
function Fonts.body(size) return load(_body, BODY, size) end

local function with(font, fn)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    fn()
    love.graphics.setFont(prev)
end

function Fonts.with(size, fn)     with(Fonts.get(size), fn) end
function Fonts.withBody(size, fn) with(Fonts.body(size), fn) end

return Fonts
```

- [ ] **Step 2: Delete the old fonts**

```bash
git rm -q assets/fonts/Anton-Regular.ttf assets/fonts/BebasNeue-Regular.ttf assets/fonts/m6x11.ttf
grep -rn "Anton\|Bebas\|m6x11" --include='*.lua' .
```
Expected: grep prints nothing.

- [ ] **Step 3: Snapshot to confirm text renders in Lilita and the title glyph boxes are gone**

Run: `tools/snapshot/snap.sh home && tools/snapshot/snap.sh match`
Expected: no Lua errors. View PNGs: all text uses the rounded Lilita font; the row of `▯▯▯` boxes under the home title is gone (it was the `─` glyph missing from m6x11 — Lilita may also lack it; if boxes remain, remove the `Fonts.with(11, ...)` line-drawing block in `drawTitle()` of `scenes/home.lua`, since Plan C replaces this screen anyway).

- [ ] **Step 4: Commit**

```bash
git add ui/fonts.lua scenes/home.lua
git commit -m "Switch fonts to Lilita One and Nunito"
```

---

### Task 6: `ui/kit/draw.lua` — drawing primitives

**Files:**
- Create: `ui/kit/draw.lua`
- Test: `tests/test_draw.lua`

Pure helpers (`roundedRectPoints`, `lerpColor`, `gradientT`, `fitSize`, `clipLine`) are unit-tested; drawing functions are verified visually in Task 10.

- [ ] **Step 1: Write the failing test `tests/test_draw.lua`**

```lua
local T    = require("tests.t")
local Draw = require("ui.kit.draw")

T.test("roundedRectPoints stays inside the rect and touches all four sides", function()
    local pts = Draw.roundedRectPoints(10, 20, 100, 50, 8, 4)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #pts, 2 do
        minX = math.min(minX, pts[i]);   maxX = math.max(maxX, pts[i])
        minY = math.min(minY, pts[i+1]); maxY = math.max(maxY, pts[i+1])
    end
    T.near(minX, 10); T.near(maxX, 110); T.near(minY, 20); T.near(maxY, 70)
    T.eq(#pts, 4 * (4 + 1) * 2, "4 corners x (seg+1) points x 2 coords")
end)

T.test("roundedRectPoints clamps radius to half the short side", function()
    local pts = Draw.roundedRectPoints(0, 0, 20, 10, 50, 2)
    for i = 1, #pts, 2 do
        T.ok(pts[i] >= -1e-9 and pts[i] <= 20 + 1e-9)
        T.ok(pts[i+1] >= -1e-9 and pts[i+1] <= 10 + 1e-9)
    end
end)

T.test("lerpColor mixes channels", function()
    local c = Draw.lerpColor({ 0, 0, 0, 1 }, { 1, 0.5, 0, 0 }, 0.5)
    T.near(c[1], 0.5); T.near(c[2], 0.25); T.near(c[3], 0); T.near(c[4], 0.5)
end)

T.test("gradientT runs 0..1 for vertical and diagonal", function()
    T.near(Draw.gradientT("v", 0, 0, 100, 50, 30, 0), 0)
    T.near(Draw.gradientT("v", 0, 0, 100, 50, 30, 50), 1)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 0, 0), 0)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 100, 50), 1)
    T.near(Draw.gradientT("d", 0, 0, 100, 50, 50, 25), 0.5)
end)

T.test("fitSize shrinks until text fits, never below min", function()
    local measure = function(size, text) return #text * size * 0.5 end
    T.eq(Draw.fitSize("ABCDEFGHIJ", 60, 16, 8, measure), 12)   -- 10*12*0.5 = 60
    T.eq(Draw.fitSize("ABCDEFGHIJ", 10, 16, 8, measure), 8)
    T.eq(Draw.fitSize("AB", 100, 16, 8, measure), 16)
end)

T.test("clipLine clips a diagonal to the rect", function()
    local x1, y1, x2, y2 = Draw.clipLine(-10, -10, 110, 110, 0, 0, 100, 100)
    T.near(x1, 0); T.near(y1, 0); T.near(x2, 100); T.near(y2, 100)
    T.eq(Draw.clipLine(200, 0, 300, 50, 0, 0, 100, 100), nil, "fully outside")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `module 'ui.kit.draw' not found`.

- [ ] **Step 3: Create `ui/kit/draw.lua`**

```lua
-- Arcade drawing primitives. No scissor/stencil anywhere: rounded gradients and
-- cropped images are triangle-fan meshes, so everything works inside canvases
-- and under rotation transforms.
local Theme = require("ui.theme")
local Fonts = require("ui.fonts")

local Draw = {}
local unpack = table.unpack or unpack

-- ── Pure helpers (unit-tested) ────────────────────────────────────────────────

-- Flat {x1,y1,x2,y2,...} outline of a rounded rect, clockwise from top-left arc.
function Draw.roundedRectPoints(x, y, w, h, r, seg)
    seg = seg or 6
    r = math.max(0, math.min(r, w / 2, h / 2))
    local pts = {}
    local corners = {
        { x + w - r, y + r,     -math.pi / 2 },   -- top-right
        { x + w - r, y + h - r, 0 },              -- bottom-right
        { x + r,     y + h - r, math.pi / 2 },    -- bottom-left
        { x + r,     y + r,     math.pi },        -- top-left
    }
    for _, c in ipairs(corners) do
        for i = 0, seg do
            local a = c[3] + (math.pi / 2) * (i / seg)
            pts[#pts + 1] = c[1] + math.cos(a) * r
            pts[#pts + 1] = c[2] + math.sin(a) * r
        end
    end
    return pts
end

function Draw.lerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    }
end

-- Gradient parameter at point (px,py) inside rect: "v" top→bottom, "d" top-left→bottom-right.
function Draw.gradientT(dir, x, y, w, h, px, py)
    if dir == "d" then
        return math.max(0, math.min(1, ((px - x) / w + (py - y) / h) / 2))
    end
    return math.max(0, math.min(1, (py - y) / h))
end

-- Largest integer size in [minSize, size] where measure(size, text) <= maxW.
function Draw.fitSize(text, maxW, size, minSize, measure)
    size = math.floor(size)
    while size > minSize and measure(size, text) > maxW do size = size - 1 end
    return math.max(size, minSize)
end

-- Liang–Barsky: clip segment to rect; returns clipped coords or nil if outside.
function Draw.clipLine(x1, y1, x2, y2, rx, ry, rw, rh)
    local dx, dy = x2 - x1, y2 - y1
    local t0, t1 = 0, 1
    local p = { -dx, dx, -dy, dy }
    local q = { x1 - rx, rx + rw - x1, y1 - ry, ry + rh - y1 }
    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then return nil end
        else
            local t = q[i] / p[i]
            if p[i] < 0 then
                if t > t1 then return nil end
                if t > t0 then t0 = t end
            else
                if t < t0 then return nil end
                if t < t1 then t1 = t end
            end
        end
    end
    return x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy
end

-- ── Color / mesh helpers ──────────────────────────────────────────────────────

function Draw.setColor(c, alphaMul)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (alphaMul or 1))
end

local function isGradient(fill) return type(fill[1]) == "table" end

local _meshCache, _meshCount = {}, 0

-- Filled rounded rect with a gradient (or flat) fill; optional image = cover-cropped texture.
local function roundedMesh(x, y, w, h, r, c1, c2, dir, image)
    local key = table.concat({ w, h, r, dir or "v",
        c1[1], c1[2], c1[3], c1[4] or 1, c2[1], c2[2], c2[3], c2[4] or 1,
        image and tostring(image) or "-" }, "|")
    local mesh = _meshCache[key]
    if not mesh then
        local pts = Draw.roundedRectPoints(0, 0, w, h, r, 6)
        local iw, ih = 1, 1
        local u0, v0, us, vs = 0, 0, 1, 1
        if image then
            iw, ih = image:getDimensions()
            local scale = math.max(w / iw, h / ih)       -- cover
            us, vs = w / (iw * scale), h / (ih * scale)
            u0, v0 = (1 - us) / 2, (1 - vs) / 2
        end
        local function vert(px, py)
            local c = Draw.lerpColor(c1, c2, Draw.gradientT(dir, 0, 0, w, h, px, py))
            return { px, py, u0 + (px / w) * us, v0 + (py / h) * vs, c[1], c[2], c[3], c[4] }
        end
        local verts = { vert(w / 2, h / 2) }
        for i = 1, #pts, 2 do verts[#verts + 1] = vert(pts[i], pts[i + 1]) end
        verts[#verts + 1] = vert(pts[1], pts[2])
        mesh = love.graphics.newMesh(verts, "fan", "static")
        if image then mesh:setTexture(image) end
        if _meshCount > 600 then _meshCache, _meshCount = {}, 0 end
        _meshCache[key] = mesh
        _meshCount = _meshCount + 1
    end
    love.graphics.draw(mesh, x, y)
end

-- fill: a color {r,g,b,a} or a gradient {c1, c2}. dir: "v" (default) or "d".
function Draw.roundedFill(x, y, w, h, r, fill, dir, alphaMul)
    alphaMul = alphaMul or 1
    if isGradient(fill) then
        love.graphics.setColor(1, 1, 1, alphaMul)
        roundedMesh(x, y, w, h, r, fill[1], fill[2], dir)
    else
        Draw.setColor(fill, alphaMul)
        love.graphics.rectangle("fill", x, y, w, h, r, r, 8)
    end
end

-- Image cover-cropped into a rounded rect.
function Draw.roundedImage(image, x, y, w, h, r, alphaMul)
    love.graphics.setColor(1, 1, 1, alphaMul or 1)
    roundedMesh(x, y, w, h, r, { 1, 1, 1, 1 }, { 1, 1, 1, 1 }, "v", image)
end

-- ── Sticker (the core arcade shape) ───────────────────────────────────────────
-- opts: r, fill (color|gradient), dir, border (px), borderColor, shadow (px), shadowColor, alpha
function Draw.sticker(x, y, w, h, opts)
    opts = opts or {}
    local r      = opts.r or 12
    local b      = opts.border or 4
    local sh     = opts.shadow or 5
    local a      = opts.alpha or 1
    if sh > 0 then
        Draw.setColor(opts.shadowColor or Theme.ink, a)
        love.graphics.rectangle("fill", x, y + sh, w, h, r, r, 8)
    end
    if b > 0 then
        Draw.setColor(opts.borderColor or Theme.white, a)
        love.graphics.rectangle("fill", x, y, w, h, r, r, 8)
    end
    Draw.roundedFill(x + b, y + b, w - 2 * b, h - 2 * b, math.max(0, r - b),
        opts.fill or Theme.white, opts.dir, a)
end

-- Glow rings around a rounded rect (selection, rarity, targets).
function Draw.glow(x, y, w, h, r, color, strength, alphaMul)
    strength = strength or 1
    local a = alphaMul or 1
    for i = 3, 1, -1 do
        Draw.setColor(color, 0.16 * i * strength * a)
        love.graphics.setLineWidth(i * 3)
        love.graphics.rectangle("line", x - i * 2, y - i * 2, w + i * 4, h + i * 4, r + i * 2, r + i * 2, 8)
    end
    love.graphics.setLineWidth(1)
end

function Draw.ring(x, y, w, h, r, color, width, alphaMul)
    Draw.setColor(color, alphaMul)
    love.graphics.setLineWidth(width or 4)
    love.graphics.rectangle("line", x, y, w, h, r, r, 8)
    love.graphics.setLineWidth(1)
end

-- ── Text ──────────────────────────────────────────────────────────────────────

local function measureDisplay(size, text) return Fonts.get(size):getWidth(text) end
local function measureBody(size, text) return Fonts.body(size):getWidth(text) end

-- Text with a hard drop shadow (and optional outline). Auto-shrinks to fit w when opts.fit.
-- opts: size, color, shadowColor, shadowY, outline (px), outlineColor, body (bool), fit (bool), minSize
function Draw.text(text, x, y, w, align, opts)
    opts = opts or {}
    local size = opts.size or 16
    if opts.fit then
        size = Draw.fitSize(text, w, size, opts.minSize or 7, opts.body and measureBody or measureDisplay)
    end
    local font = opts.body and Fonts.body(size) or Fonts.get(size)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    local a = opts.alpha or 1
    local o = opts.outline or 0
    if o > 0 then
        Draw.setColor(opts.outlineColor or Theme.ink, a)
        for ox = -o, o, o do
            for oy = -o, o, o do
                if ox ~= 0 or oy ~= 0 then love.graphics.printf(text, x + ox, y + oy, w, align) end
            end
        end
    end
    local sy = opts.shadowY or 0
    if sy > 0 then
        Draw.setColor(opts.shadowColor or Theme.ink, a)
        love.graphics.printf(text, x, y + sy, w, align)
    end
    Draw.setColor(opts.color or Theme.white, a)
    love.graphics.printf(text, x, y, w, align)
    love.graphics.setFont(prev)
    return size, font
end

-- ── Pills, badges, ribbons ────────────────────────────────────────────────────

-- Pill with centered text. opts: fill, textColor, size, border, shadow, body, alpha
function Draw.pill(x, y, w, h, text, opts)
    opts = opts or {}
    Draw.sticker(x, y, w, h, {
        r = h / 2, fill = opts.fill or Theme.white, border = opts.border or 2,
        shadow = opts.shadow or 3, alpha = opts.alpha, dir = "v",
    })
    local size = opts.size or math.floor(h * 0.62)
    Draw.text(text, x + h * 0.3, y + (h - size) / 2 - size * 0.08, w - h * 0.6, "center", {
        size = size, color = opts.textColor or Theme.inkText, body = opts.body, fit = true,
        minSize = 6, alpha = opts.alpha,
    })
end

-- Shield outline points (flat top, pointed bottom) centered at cx,cy.
local function shieldPoints(cx, cy, s)
    local hw, top, mid, bot = s * 0.5, cy - s * 0.5, cy + s * 0.12, cy + s * 0.55
    return {
        cx - hw, top, cx + hw, top, cx + hw, mid,
        cx + hw * 0.55, cy + s * 0.38, cx, bot, cx - hw * 0.55, cy + s * 0.38, cx - hw, mid,
    }
end

local function badgeNumber(value, cx, cy, s, alpha)
    local str = tostring(value)
    local size = Draw.fitSize(str, s * 0.86, s * 0.40, 6, measureDisplay)
    Draw.text(str, cx - s, cy - size * 0.58, s * 2, "center", {
        size = size, color = Theme.white, shadowY = math.max(1, math.floor(s * 0.05)), alpha = alpha,
    })
end

-- Red ATK circle. s = diameter.
function Draw.atkBadge(cx, cy, s, value, alpha)
    alpha = alpha or 1
    local r = s / 2
    local sh = math.max(2, s * 0.08)
    Draw.setColor(Theme.ink, alpha);  love.graphics.circle("fill", cx, cy + sh, r, 24)
    Draw.setColor(Theme.white, alpha); love.graphics.circle("fill", cx, cy, r, 24)
    local b = math.max(2, s * 0.08)
    Draw.setColor(Theme.grad.atk[2], alpha); love.graphics.circle("fill", cx, cy, r - b, 24)
    Draw.setColor(Theme.grad.atk[1], alpha); love.graphics.circle("fill", cx, cy - (r - b) * 0.18, (r - b) * 0.82, 24)
    badgeNumber(value, cx, cy, s, alpha)
end

-- Blue DEF shield. s = width. bonus > 0 adds a green "+N" tag above it.
function Draw.defBadge(cx, cy, s, value, bonus, alpha)
    alpha = alpha or 1
    local sh = math.max(2, s * 0.08)
    local b  = math.max(2, s * 0.08)
    love.graphics.push()
    love.graphics.translate(0, sh)
    Draw.setColor(Theme.ink, alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    love.graphics.pop()
    Draw.setColor(Theme.white, alpha);       love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    Draw.setColor(Theme.grad.def[2], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s))
    Draw.setColor(Theme.grad.def[1], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy - s * 0.08, s * 0.8))
    badgeNumber(value, cx, cy, s, alpha)
    if bonus and bonus > 0 then
        local tw, th = s * 1.1, s * 0.42
        Draw.pill(cx - tw / 2, cy - s * 0.5 - th - 2, tw, th, "+" .. bonus, {
            fill = Theme.grad.bonus, textColor = Theme.white, border = 2, shadow = 2, alpha = alpha,
        })
    end
end

-- Green "+N" ATK bonus tag (for strikers boosted by a midfielder).
function Draw.bonusTag(cx, bottomY, s, bonus, alpha)
    local tw, th = s * 1.1, s * 0.42
    Draw.pill(cx - tw / 2, bottomY - th, tw, th, "+" .. bonus, {
        fill = Theme.grad.bonus, textColor = Theme.white, border = 2, shadow = 2, alpha = alpha,
    })
end

-- Banner ribbon centered on cx. opts: fill, textColor, size, alpha
function Draw.ribbon(cx, y, w, h, text, opts)
    opts = opts or {}
    local x = cx - w / 2
    local notch = h * 0.35
    local a = opts.alpha or 1
    -- tails
    Draw.setColor(Theme.ink, a)
    love.graphics.polygon("fill", x - notch, y + h * 0.25, x + notch, y + h * 0.25, x + notch, y + h * 1.15, x - notch, y + h * 1.15, x, y + h * 0.7)
    love.graphics.polygon("fill", x + w + notch, y + h * 0.25, x + w - notch, y + h * 0.25, x + w - notch, y + h * 1.15, x + w + notch, y + h * 1.15, x + w, y + h * 0.7)
    Draw.sticker(x, y, w, h, { r = h * 0.2, fill = opts.fill or Theme.white, border = 3, shadow = 4, alpha = a })
    local size = opts.size or math.floor(h * 0.6)
    Draw.text(text, x + 8, y + (h - size) / 2 - size * 0.08, w - 16, "center", {
        size = size, color = opts.textColor or Theme.inkText, fit = true, alpha = a,
        shadowY = opts.textShadow and 2 or 0,
    })
end

-- Diagonal stripes clipped to a rect (used for card backs and placeholders).
function Draw.stripes(x, y, w, h, spacing, width, color, alphaMul)
    Draw.setColor(color, alphaMul)
    love.graphics.setLineWidth(width)
    for o = -h, w, spacing do
        local x1, y1, x2, y2 = Draw.clipLine(x + o, y, x + o + h, y + h, x, y, w, h)
        if x1 then love.graphics.line(x1, y1, x2, y2) end
    end
    love.graphics.setLineWidth(1)
end

-- Full-screen vertical gradient background.
local _bgMesh
function Draw.background(W, H)
    if not _bgMesh then
        local t, b = Theme.bg.top, Theme.bg.bottom
        _bgMesh = love.graphics.newMesh({
            { 0, 0, 0, 0, t[1], t[2], t[3], 1 }, { W, 0, 1, 0, t[1], t[2], t[3], 1 },
            { W, H, 1, 1, b[1], b[2], b[3], 1 }, { 0, H, 0, 1, b[1], b[2], b[3], 1 },
        }, "fan", "static")
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(_bgMesh)
end

Draw._unpack = unpack
return Draw
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `11 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/kit/draw.lua tests/test_draw.lua
git commit -m "Add arcade drawing primitives (ui/kit/draw)"
```

---

### Task 7: `ui/kit/icons.lua`

**Files:**
- Create: `ui/kit/icons.lua`
- Test: `tests/test_icons.lua`

- [ ] **Step 1: Write the failing test `tests/test_icons.lua`**

```lua
local T     = require("tests.t")
local Icons = require("ui.kit.icons")

T.test("each card type maps to an icon file that exists", function()
    for _, t in ipairs({ "striker", "defender", "midfielder", "keeper", "trap", "strategy", "formation" }) do
        local name = Icons.forType(t)
        local f = io.open("assets/icons/" .. name .. ".png", "rb")
        T.ok(f, "missing assets/icons/" .. name .. ".png for " .. t)
        if f then f:close() end
    end
end)

T.test("unknown types fall back to the ball", function()
    T.eq(Icons.forType("banana"), "soccer-ball")
    T.eq(Icons.forType(nil), "soccer-ball")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `module 'ui.kit.icons' not found`.

- [ ] **Step 3: Create `ui/kit/icons.lua`**

```lua
-- Icons from game-icons.net (CC BY 3.0), white-on-transparent PNGs in assets/icons/.
local Theme = require("ui.theme")

local Icons = {}

local BY_TYPE = {
    striker    = "soccer-kick",
    defender   = "checked-shield",
    midfielder = "on-target",
    keeper     = "goal-keeper",
    trap       = "wolf-trap",
    strategy   = "whistle",
    formation  = "soccer-field",
}
local FALLBACK = "soccer-ball"

function Icons.forType(cardType)
    return BY_TYPE[cardType] or FALLBACK
end

local _cache = {}
function Icons.get(name)
    if _cache[name] ~= nil then return _cache[name] or nil end
    local ok, img = pcall(love.graphics.newImage, "assets/icons/" .. name .. ".png", { mipmaps = true })
    if ok then
        img:setFilter("linear", "linear")
        img:setMipmapFilter("linear")
        _cache[name] = img
        return img
    end
    _cache[name] = false
    return nil
end

-- Draw icon centered at cx,cy scaled to `size` px, tinted `color`, with a hard ink shadow.
function Icons.draw(name, cx, cy, size, color, shadowY, alpha)
    local img = Icons.get(name)
    if not img then return end
    alpha = alpha or 1
    local iw = img:getWidth()
    local s  = size / iw
    local ox = iw / 2
    shadowY = shadowY or math.max(1, math.floor(size * 0.05))
    if shadowY > 0 then
        love.graphics.setColor(Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.35 * alpha)
        love.graphics.draw(img, cx, cy + shadowY, 0, s, s, ox, ox)
    end
    local c = color or Theme.white
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
    love.graphics.draw(img, cx, cy, 0, s, s, ox, ox)
end

return Icons
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `13 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/kit/icons.lua tests/test_icons.lua
git commit -m "Add icon loader (ui/kit/icons)"
```

---

### Task 8: `ui/kit/button.lua`

**Files:**
- Create: `ui/kit/button.lua`
- Test: `tests/test_button.lua`

- [ ] **Step 1: Write the failing test `tests/test_button.lua`**

```lua
local T      = require("tests.t")
local Button = require("ui.kit.button")

local function mk(extra)
    local o = { label = "GO", x = 100, y = 50, w = 200, h = 60 }
    for k, v in pairs(extra or {}) do o[k] = v end
    return Button.new(o)
end

T.test("contains uses the button rect", function()
    local b = mk()
    T.ok(b:contains(100, 50)); T.ok(b:contains(300, 110))
    T.ok(not b:contains(99, 50)); T.ok(not b:contains(150, 111))
end)

T.test("hover and press follow the mouse", function()
    local b = mk()
    b:update(0.016, 150, 70, false)
    T.ok(b.hover and not b.pressed)
    b:update(0.016, 150, 70, true)
    T.ok(b.pressed)
    b:update(0.016, 10, 10, false)
    T.ok(not b.hover and not b.pressed)
end)

T.test("lift eases toward -2 on hover and +shadow on press", function()
    local b = mk()
    for _ = 1, 120 do b:update(1 / 60, 150, 70, false) end
    T.near(b.lift, -2, 0.05)
    for _ = 1, 120 do b:update(1 / 60, 150, 70, true) end
    T.near(b.lift, b.shadow, 0.05)
end)

T.test("disabled buttons ignore the mouse", function()
    local b = mk({ enabled = false })
    b:update(0.016, 150, 70, true)
    T.ok(not b.hover and not b.pressed)
    T.ok(not b:hit(150, 70))
end)

T.test("hit returns true only when enabled and inside", function()
    local b = mk()
    T.ok(b:hit(150, 70)); T.ok(not b:hit(0, 0))
end)

T.test("default variant is primary; shadow scales with height", function()
    local b = mk()
    T.eq(b.variant, "primary")
    T.eq(b.shadow, 6)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `module 'ui.kit.button' not found`.

- [ ] **Step 3: Create `ui/kit/button.lua`**

```lua
-- Chunky 3D arcade button. Logic (hover/press/lift) is pure; draw() uses LÖVE.
local Theme = require("ui.theme")

local Button = {}
Button.__index = Button

-- opts: label, x, y, w, h, variant ("primary"|"go"|"danger"|"neutral"|"icon"),
--       fontSize, icon (name in assets/icons), enabled (default true), id
function Button.new(opts)
    local b = setmetatable({}, Button)
    b.id       = opts.id
    b.label    = opts.label or ""
    b.x, b.y   = opts.x or 0, opts.y or 0
    b.w, b.h   = opts.w or 160, opts.h or 48
    b.variant  = opts.variant or "primary"
    b.fontSize = opts.fontSize
    b.icon     = opts.icon
    b.enabled  = opts.enabled ~= false
    b.focused  = false
    b.hover    = false
    b.pressed  = false
    b.lift     = 0
    b.shadow   = math.max(3, math.floor(b.h * 0.1))
    b.time     = 0
    return b
end

function Button:setRect(x, y, w, h)
    self.x, self.y = x, y
    if w then self.w = w end
    if h then self.h = h; self.shadow = math.max(3, math.floor(h * 0.1)) end
end

function Button:contains(mx, my)
    return mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function Button:hit(mx, my)
    return self.enabled and self:contains(mx, my)
end

function Button:update(dt, mx, my, mouseDown)
    self.time = self.time + dt
    local inside = self.enabled and self:contains(mx, my)
    self.hover   = inside
    self.pressed = inside and mouseDown or false
    local target = 0
    if self.pressed then target = self.shadow
    elseif self.hover or self.focused then target = -2 end
    self.lift = self.lift + (target - self.lift) * math.min(1, dt * 18)
end

function Button:draw()
    local Draw  = require("ui.kit.draw")
    local style = Theme.button[self.variant] or Theme.button.primary
    local alpha = self.enabled and 1 or 0.5
    local x, y, w, h = self.x, self.y + self.lift, self.w, self.h
    local r  = self.variant == "icon" and math.floor(h * 0.25) or math.floor(h * 0.28)
    local sh = math.max(0, self.shadow - self.lift)

    if self.focused and self.enabled then
        local pulse = 0.5 + 0.5 * math.sin(self.time * 5)
        Draw.glow(x, y, w, h, r, Theme.white, 0.6 + 0.4 * pulse)
    end

    Draw.sticker(x, y, w, h, {
        r = r, fill = style.fill, dir = "v",
        border = self.variant == "icon" and 2 or 3,
        borderColor = self.variant == "icon" and { 1, 1, 1, 0.55 } or Theme.white,
        shadow = sh, shadowColor = style.shadow, alpha = alpha,
    })
    -- glossy top highlight
    love.graphics.setColor(1, 1, 1, 0.22 * alpha)
    love.graphics.rectangle("fill", x + 6, y + 5, w - 12, h * 0.32, r * 0.6, r * 0.6, 8)

    local size = self.fontSize or math.floor(h * 0.42)
    local textX, textW = x + 8, w - 16
    if self.icon then
        local Icons = require("ui.kit.icons")
        local isz = math.floor(h * 0.5)
        if self.label == "" then
            Icons.draw(self.icon, x + w / 2, y + h / 2, isz, style.text, 1, alpha)
            return
        end
        Icons.draw(self.icon, x + 12 + isz / 2, y + h / 2, isz, style.text, 1, alpha)
        textX, textW = x + 16 + isz, w - 24 - isz
    end
    Draw.text(self.label, textX, y + (h - size) / 2 - size * 0.08, textW, "center", {
        size = size, color = style.text, fit = true, minSize = 8, alpha = alpha,
        shadowY = (self.variant == "primary" or self.variant == "neutral") and 0 or 2,
        shadowColor = style.shadow,
    })
end

return Button
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `19 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/kit/button.lua tests/test_button.lua
git commit -m "Add chunky 3D button (ui/kit/button)"
```

---

### Task 9: `ui/kit/tween.lua`

**Files:**
- Create: `ui/kit/tween.lua`
- Test: `tests/test_tween.lua`

- [ ] **Step 1: Write the failing test `tests/test_tween.lua`**

```lua
local T     = require("tests.t")
local flux  = require("lib.flux")
local Tween = require("ui.kit.tween")

local function run(seconds) for _ = 1, math.floor(seconds * 60) do flux.update(1 / 60) end end

T.test("popIn scales 0 -> 1", function()
    local o = {}
    Tween.popIn(o, 0.3)
    T.near(o.scale, 0)
    run(0.5)
    T.near(o.scale, 1, 1e-3)
end)

T.test("squash returns sx/sy to 1", function()
    local o = { sx = 1, sy = 1 }
    Tween.squash(o, 0.3)
    T.ok(o.sx ~= 1 or o.sy ~= 1, "squash starts deformed")
    run(0.6)
    T.near(o.sx, 1, 1e-3); T.near(o.sy, 1, 1e-3)
end)

T.test("bounce returns key to 0", function()
    local o = { y = 0 }
    Tween.bounce(o, "y", 12, 0.3)
    run(0.6)
    T.near(o.y, 0, 1e-3)
end)

T.test("countTo reaches the integer target", function()
    local o = { lp = 4000 }
    Tween.countTo(o, "lp", 3400, 0.4)
    run(0.6)
    T.eq(o.lp, 3400)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `module 'ui.kit.tween' not found`.

- [ ] **Step 3: Create `ui/kit/tween.lua`**

```lua
-- Bouncy motion helpers on top of lib/flux. All return the flux tween.
local flux = require("lib.flux")

local Tween = {}

-- obj.scale 0 → 1 with overshoot.
function Tween.popIn(obj, dur)
    obj.scale = 0
    return flux.to(obj, dur or 0.3, { scale = 1 }):ease("backout")
end

-- Squash then spring back: obj.sx / obj.sy → 1.
function Tween.squash(obj, dur)
    obj.sx, obj.sy = 1.18, 0.82
    return flux.to(obj, dur or 0.3, { sx = 1, sy = 1 }):ease("elasticout")
end

-- Kick obj[key] by `amount` then settle back to 0.
function Tween.bounce(obj, key, amount, dur)
    obj[key] = amount
    return flux.to(obj, dur or 0.3, { [key] = 0 }):ease("elasticout")
end

-- Animate obj[key] to target, rounding to integers on every step (for counters).
function Tween.countTo(obj, key, target, dur)
    local proxy = { v = obj[key] or 0 }
    return flux.to(proxy, dur or 0.4, { v = target }):ease("quadout")
        :onupdate(function() obj[key] = math.floor(proxy.v + 0.5) end)
        :oncomplete(function() obj[key] = target end)
end

return Tween
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `23 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add ui/kit/tween.lua tests/test_tween.lua
git commit -m "Add tween helpers (ui/kit/tween)"
```

---

### Task 10: Clash-portrait card renderer

**Files:**
- Rewrite: `ui/card.lua`
- Test: `tests/test_card_layout.lua`
- Create: `tools/snapshot/card_gallery.lua`
- Modify: `tools/snapshot/scenarios.lua`

- [ ] **Step 1: Write the failing test `tests/test_card_layout.lua`**

```lua
local T     = require("tests.t")
local Card  = require("ui.card")

T.test("layout at pitch size uses scale 1", function()
    local L = Card.layout(108, 148)
    T.near(L.s, 1)
    T.eq(L.border, 4)
    T.eq(L.r, 14)
end)

T.test("ribbon is wider than the card and sits above the badges", function()
    local L = Card.layout(108, 148)
    T.ok(L.ribbon.x < 0 and L.ribbon.x + L.ribbon.w > 108, "ribbon overhangs both sides")
    T.ok(L.ribbon.y + L.ribbon.h <= L.atk.cy - L.atk.size * 0.25, "ribbon above badge centers")
end)

T.test("badges sit on the bottom corners", function()
    local L = Card.layout(108, 148)
    T.ok(L.atk.cx < 20 and L.def.cx > 88)
    T.ok(L.atk.cy > 130 and L.def.cy > 130)
end)

T.test("art icon stays inside the card body", function()
    for _, sz in ipairs({ { 68, 80 }, { 84, 106 }, { 108, 148 }, { 120, 165 }, { 300, 410 } }) do
        local L = Card.layout(sz[1], sz[2])
        T.ok(L.icon.cy - L.icon.size / 2 >= 0, "icon top inside at " .. sz[1])
        T.ok(L.icon.cy + L.icon.size / 2 <= L.ribbon.y + 2, "icon above ribbon at " .. sz[1])
    end
end)

T.test("scale follows width", function()
    T.near(Card.layout(300, 410).s, 300 / 108)
    T.near(Card.layout(54, 74).s, 0.5)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `attempt to call a nil value (field 'layout')`.

- [ ] **Step 3: Replace `ui/card.lua` entirely**

```lua
-- Clash-portrait card renderer.
-- Public API (unchanged contract for existing callers):
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, canFlip, pitch, selected, target
--   Card.drawInHand(cardDef, x, y, opts)    opts: w, h, selected   → returns {x,y,w,h}
--   Card.drawTooltip(cardDef, x, y)
--   Card.drawLarge(cardDef, x, y, w)        → returns h
-- New:
--   Card.layout(w, h)                       pure geometry (unit-tested)
--   Card.drawFace(cardDef, x, y, w, h, opts) opts: stats, atkBonus, defBonus, exhausted, selected, target, alpha
--   Card.drawBack(x, y, w, h, opts)         opts: label, canFlip, selected, target, alpha
local Theme  = require("ui.theme")
local Combat = require("engine.combat")
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")

local Card = {}

local BASE_W = 108   -- design width; everything scales from here

-- ── Portrait cache (assets/cards/<id>.png|jpg) ────────────────────────────────

local _portraits = {}
local function getPortrait(cardDef)
    local id = cardDef and cardDef.id
    if not id then return nil end
    if _portraits[id] ~= nil then return _portraits[id] or nil end
    for _, ext in ipairs({ ".png", ".jpg" }) do
        local ok, img = pcall(love.graphics.newImage, "assets/cards/" .. id .. ext)
        if ok then
            img:setFilter("linear", "linear")
            _portraits[id] = img
            return img
        end
    end
    _portraits[id] = false
    return nil
end

-- ── Geometry ──────────────────────────────────────────────────────────────────

function Card.layout(w, h)
    local s = w / BASE_W
    local L = { w = w, h = h, s = s }
    L.border = math.max(2, math.floor(4 * s + 0.5))
    L.r      = math.floor(14 * s + 0.5)
    L.shadow = math.max(2, math.floor(5 * s + 0.5))

    local ribbonH = math.max(10, 20 * s)
    L.ribbon = { x = -6 * s, y = h * 0.66 - ribbonH / 2, w = w + 12 * s, h = ribbonH }

    local badge = math.max(16, 34 * s)
    L.atk = { cx = 8 * s,     cy = h - 6 * s, size = badge }
    L.def = { cx = w - 8 * s, cy = h - 6 * s, size = badge * 0.95 }

    L.tag = { cy = 0, h = math.max(9, 16 * s) }
    L.gem = { cx = w - 12 * s, cy = 12 * s, size = math.max(5, 9 * s) }

    local artTop, artBottom = L.border + 6 * s, L.ribbon.y - 2
    local iconSize = math.min(w * 0.56, (artBottom - artTop) * 0.92)
    L.icon = { cx = w / 2, cy = (artTop + artBottom) / 2, size = iconSize }
    return L
end

-- ── Pieces ────────────────────────────────────────────────────────────────────

local function drawTag(label, L, x, y, alpha)
    local size = math.max(7, math.floor(L.tag.h * 0.62))
    local tw = math.min(L.w - 8 * L.s, (#label * size * 0.62) + L.tag.h)
    Draw.pill(x + (L.w - tw) / 2, y + L.tag.cy - L.tag.h / 2, tw, L.tag.h, label, {
        fill = Theme.ink, textColor = Theme.white, border = math.max(1, math.floor(2 * L.s)),
        shadow = 0, size = size, alpha = alpha,
    })
end

local function drawGem(rarity, L, x, y, alpha)
    local c = Theme.rarityColors[rarity] or Theme.rarityColors.common
    local g = L.gem
    love.graphics.push()
    love.graphics.translate(x + g.cx, y + g.cy)
    love.graphics.rotate(math.pi / 4)
    Draw.setColor(Theme.white, alpha)
    love.graphics.rectangle("fill", -g.size / 2 - 2, -g.size / 2 - 2, g.size + 4, g.size + 4, 2)
    Draw.setColor(c, alpha)
    love.graphics.rectangle("fill", -g.size / 2, -g.size / 2, g.size, g.size, 1)
    love.graphics.pop()
end

local function drawRibbon(name, L, x, y, alpha)
    local rb = L.ribbon
    Draw.sticker(x + rb.x, y + rb.y, rb.w, rb.h, {
        r = math.max(3, 6 * L.s), fill = Theme.white, border = 0,
        shadow = math.max(1, math.floor(3 * L.s)), alpha = alpha,
    })
    local size = math.max(7, math.floor(rb.h * 0.62))
    Draw.text(name or "", x + rb.x + 4 * L.s, y + rb.y + (rb.h - size) / 2 - size * 0.06, rb.w - 8 * L.s, "center", {
        size = size, color = Theme.inkText, fit = true, minSize = 6, alpha = alpha,
    })
end

local function drawHighlights(L, x, y, opts, rarity)
    local a = opts.alpha or 1
    if rarity == "rare" or rarity == "legendary" then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.rarityColors[rarity], 0.9, a)
    end
    if opts.selected then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.highlight.selected, 1.4, a)
        Draw.ring(x - 3 * L.s, y - 3 * L.s, L.w + 6 * L.s, L.h + 6 * L.s, L.r + 3 * L.s,
            Theme.highlight.selected, math.max(2, 4 * L.s), a)
    elseif opts.target then
        Draw.glow(x, y, L.w, L.h, L.r, Theme.highlight.target, 1.4, a)
        Draw.ring(x - 3 * L.s, y - 3 * L.s, L.w + 6 * L.s, L.h + 6 * L.s, L.r + 3 * L.s,
            Theme.highlight.target, math.max(2, 4 * L.s), a)
    end
end

local function drawExhausted(L, x, y, alpha)
    Draw.roundedFill(x, y, L.w, L.h, L.r, { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.55 }, "v", alpha)
    local ph = math.max(10, 16 * L.s)
    local pw = ph * 2.4
    Draw.pill(x + (L.w - pw) / 2, y + L.h * 0.30, pw, ph, "zzz", {
        fill = Theme.white, textColor = Theme.inkText, border = 0, shadow = math.max(1, math.floor(2 * L.s)),
        alpha = alpha,
    })
end

-- ── Face ──────────────────────────────────────────────────────────────────────

function Card.drawFace(cardDef, x, y, w, h, opts)
    opts = opts or {}
    local L     = Card.layout(w, h)
    local a     = opts.alpha or 1
    local ctype = cardDef.type
    local grad  = Theme.typeGrad[ctype] or Theme.typeGrad.formation

    drawHighlights(L, x, y, opts, cardDef.rarity)

    Draw.sticker(x, y, w, h, { r = L.r, fill = grad, dir = "d", border = L.border, shadow = L.shadow, alpha = a })

    local inX, inY = x + L.border, y + L.border
    local inW, inH = w - 2 * L.border, h - 2 * L.border
    local portrait = getPortrait(cardDef)
    if portrait then
        Draw.roundedImage(portrait, inX, inY, inW, inH, math.max(0, L.r - L.border), a)
    else
        -- soft top highlight + big type icon
        Draw.roundedFill(inX, inY, inW, inH * 0.5, math.max(0, L.r - L.border), { 1, 1, 1, 0.16 }, "v", a)
        Icons.draw(Icons.forType(ctype), x + L.icon.cx, y + L.icon.cy, L.icon.size, Theme.white,
            math.max(1, math.floor(3 * L.s)), a)
    end

    drawTag(Theme.typeLabel[ctype] or string.upper(ctype or "?"), L, x, y, a)
    drawGem(cardDef.rarity, L, x, y, a)
    drawRibbon(cardDef.name, L, x, y, a)

    local stats = opts.stats or cardDef.stats or {}
    local hasStats = (ctype == "striker" or ctype == "defender" or ctype == "midfielder" or ctype == "keeper")
    if hasStats then
        Draw.atkBadge(x + L.atk.cx, y + L.atk.cy, L.atk.size, (stats.atk or 0) + (opts.atkBonus or 0), a)
        Draw.defBadge(x + L.def.cx, y + L.def.cy, L.def.size, (stats.def or 0) + (opts.defBonus or 0),
            opts.defBonus, a)
        if opts.atkBonus and opts.atkBonus > 0 then
            Draw.bonusTag(x + L.atk.cx, y + L.atk.cy - L.atk.size / 2 - 2, L.atk.size, opts.atkBonus, a)
        end
    end

    if opts.exhausted then drawExhausted(L, x, y, a) end
end

-- ── Back ──────────────────────────────────────────────────────────────────────

function Card.drawBack(x, y, w, h, opts)
    opts = opts or {}
    local L = Card.layout(w, h)
    local a = opts.alpha or 1
    drawHighlights(L, x, y, opts, nil)
    Draw.sticker(x, y, w, h, { r = L.r, fill = Theme.cardBack, dir = "v", border = L.border, shadow = L.shadow, alpha = a })
    local pad = L.border + 5 * L.s
    Draw.stripes(x + pad, y + pad, w - 2 * pad, h - 2 * pad, math.max(6, 12 * L.s), math.max(2, 4 * L.s),
        { 1, 1, 1, 0.06 }, a)
    Draw.ring(x + pad, y + pad, w - 2 * pad, h - 2 * pad, math.max(2, 6 * L.s), { 1, 1, 1, 0.25 },
        math.max(1, 2 * L.s), a)
    Icons.draw("soccer-ball", x + w / 2, y + h / 2, math.min(w, h) * 0.42, { 1, 1, 1, 0.9 },
        math.max(1, math.floor(3 * L.s)), a)

    if opts.label then
        local ph = math.max(10, 16 * L.s)
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + h - pad - ph - 2 * L.s, pw, ph, opts.label, {
            fill = Theme.grad.def, textColor = Theme.white, border = math.max(1, math.floor(2 * L.s)),
            shadow = 0, alpha = a,
        })
    end
    if opts.canFlip then
        local rh = math.max(12, 20 * L.s)
        Draw.ribbon(x + w / 2, y + h * 0.36, w * 0.9, rh, "FLIP UP", {
            fill = Theme.grad.bonus, textColor = Theme.white, alpha = a,
        })
    end
end

-- ── Public API (existing contract) ────────────────────────────────────────────

function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h

    if pitched.mode == "defense" then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and "DEF" or nil, canFlip = opts.canFlip,
            selected = opts.selected, target = opts.target,
        })
        return
    end

    local atkBonus, defBonus = 0, 0
    if opts.pitch then
        if pitched.slotType == "striker"  then atkBonus = Combat.midfielderCardAtkBonus(opts.pitch) or 0 end
        if pitched.slotType == "defender" then defBonus = Combat.midfielderCardDefBonus(opts.pitch) or 0 end
    end

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })
end

function Card.drawInHand(cardDef, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.hand.w
    local h = opts.h or Theme.cardSize.hand.h
    Card.drawFace(cardDef, x, y, w, h, { selected = opts.selected })
    return { x = x, y = y, w = w, h = h }
end

-- Info sticker: name, type · rarity, ability text. Returns its height.
function Card.drawInfo(cardDef, x, y, w)
    local Fonts = require("ui.fonts")
    local pad = 12
    local body = Fonts.body(12)
    local _, lines = body:getWrap(cardDef.abilityText or "", w - pad * 2)
    local h = pad + 22 + 16 + #lines * body:getHeight() + pad
    Draw.sticker(x, y, w, h, { r = 12, fill = Theme.white, border = 0, shadow = 4 })
    Draw.text(cardDef.name or "", x + pad, y + pad, w - pad * 2, "left",
        { size = 18, color = Theme.inkText, fit = true })
    local rc = Theme.rarityColors[cardDef.rarity] or Theme.rarityColors.common
    Draw.text(((Theme.typeLabel[cardDef.type] or "") .. " · " .. string.upper(cardDef.rarity or "")),
        x + pad, y + pad + 22, w - pad * 2, "left",
        { size = 11, body = true, color = { rc[1] * 0.6, rc[2] * 0.6, rc[3] * 0.6, 1 } })
    Draw.text(cardDef.abilityText or "", x + pad, y + pad + 38, w - pad * 2, "left",
        { size = 12, body = true, color = { 0.35, 0.35, 0.54, 1 } })
    return h
end

function Card.drawTooltip(cardDef, x, y)
    local w = 230
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    if x + w > W - 8 then x = W - 8 - w end
    if x < 8 then x = 8 end
    if y < 8 then y = 8 end
    if y + 140 > H then y = H - 140 end
    Card.drawInfo(cardDef, x, y, w)
end

function Card.drawLarge(cardDef, x, y, w)
    local h = math.floor(w * 148 / 108)
    Card.drawFace(cardDef, x, y, w, h, {})
    return h
end

return Card
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `lua tests/run.lua`
Expected: `28 passed, 0 failed`. If the "art icon stays inside" test fails at 68×80, lower the `iconSize` factor `0.92` until it passes; don't loosen the test.

- [ ] **Step 5: Create `tools/snapshot/card_gallery.lua`**

```lua
-- Dev-only: renders the card renderer at every size and state on the arcade background.
local Card  = require("ui.card")
local Draw  = require("ui.kit.draw")
local Theme = require("ui.theme")

local defs = {}
for _, f in ipairs({ "strikers", "defenders", "midfielders", "keepers", "traps", "strategies" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do defs[#defs + 1] = d end
end
local function pick(pred) for _, d in ipairs(defs) do if pred(d) then return d end end end
local rare   = pick(function(d) return d.type == "striker" and d.rarity == "rare" end) or defs[1]
local def    = pick(function(d) return d.type == "defender" end)
local mid    = pick(function(d) return d.type == "midfielder" end)
local keeper = pick(function(d) return d.type == "keeper" end)
local trap   = pick(function(d) return d.type == "trap" end)
local strat  = pick(function(d) return d.type == "strategy" end)

local G = {}
function G.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    Draw.background(W, H)
    -- Row 1: pitch size, all types + states
    local x, y = 30, 40
    for _, d in ipairs({ rare, def, mid, keeper, trap, strat }) do
        Card.drawFace(d, x, y, 108, 148, {}); x = x + 130
    end
    Card.drawFace(rare, x, y, 108, 148, { selected = true }); x = x + 130
    Card.drawFace(def, x, y, 108, 148, { target = true }); x = x + 130
    Card.drawFace(rare, x, y, 108, 148, { exhausted = true, atkBonus = 200 })
    -- Row 2: backs, bonuses, hand size, legacy small sizes
    x, y = 30, 230
    Card.drawBack(x, y, 108, 148, { label = "DEF" }); x = x + 130
    Card.drawBack(x, y, 108, 148, { canFlip = true }); x = x + 130
    Card.drawFace(def, x, y, 108, 148, { defBonus = 300 }); x = x + 140
    Card.drawFace(rare, x, y, 120, 165, { selected = true }); x = x + 150
    Card.drawFace(keeper, x, y, 84, 106, {}); x = x + 110
    Card.drawFace(mid, x, y, 68, 80, {}); x = x + 90
    Card.drawTooltip(rare, x, y)
    -- Row 3: zoom size + info
    Card.drawFace(rare, 30, 430, 250, 342, {})
    Card.drawInfo(rare, 300, 430, 300)
    Draw.pill(640, 440, 180, 32, "SUMMONS 1 / 2", {})
    local Button = require("ui.kit.button")
    for i, v in ipairs({ "primary", "go", "danger", "neutral" }) do
        local b = Button.new({ label = string.upper(v), variant = v, x = 640 + ((i - 1) % 2) * 200, y = 500 + math.floor((i - 1) / 2) * 80, w = 180, h = 56 })
        b:draw()
    end
    local ib = Button.new({ icon = "whistle", variant = "icon", x = 1060, y = 500, w = 48, h = 48 }); ib:draw()
    Draw.ribbon(840, 680, 360, 48, "MIDFIELD CONTROL +1", { fill = Theme.button.primary.fill, textColor = Theme.button.primary.text })
end
return G
```

- [ ] **Step 6: Add the `cards` scenario** — in `tools/snapshot/scenarios.lua`, add before `return S`:

```lua
S.cards = {
    { 0.3, function() love.draw = require("tools.snapshot.card_gallery").draw end },
    { 1.0, function(c) c.snap("gallery") end },
    { 1.5, function(c) c.quit() end },
}
```

- [ ] **Step 7: Snapshot the gallery and review it**

Run: `tools/snapshot/snap.sh cards`
Expected: `.snapshots/cards_gallery.png`, no Lua errors. View it with the Read tool and check:
- Each type has its gradient color, a white type icon, a navy type tag on the top edge, a rarity gem, a white name ribbon overhanging both sides, red ATK circle and blue DEF shield on the bottom corners (traps/strategies have no badges).
- Rare striker has a gold glow; selected = yellow ring; target = red ring; exhausted = dark overlay + "zzz"; "+200"/"+300" green tags appear.
- Card backs: navy stripes + ball icon; "DEF" pill; green "FLIP UP" ribbon.
- Small sizes (84×106, 68×80) are still legible; text never spills out of ribbons/badges.
- Buttons show 4 variants + an icon button; pill and ribbon render.
Fix any visual defect in `ui/card.lua` / `ui/kit/draw.lua` and re-run until clean.

- [ ] **Step 8: Snapshot the real screens with the new cards**

Run: `tools/snapshot/snap.sh match && tools/snapshot/snap.sh library`
Expected: no Lua errors. The match board and hand show the new Clash cards (inside the old dark layout — that's expected until Plan B); the library grid tiles still render (their own tile style — replaced in Plan C).

- [ ] **Step 9: Play-test**

Run: `love .` — pick a deck, play at least 3 turns: summon a card in attack mode and one in defense mode, attack, end turn, let the AI act, open the pause menu (Esc) and the card library. Expected: no errors; hover tooltip shows the white info sticker; defense-mode cards show the navy back with "DEF".

- [ ] **Step 10: Commit**

```bash
git add ui/card.lua tests/test_card_layout.lua tools/snapshot/card_gallery.lua tools/snapshot/scenarios.lua
git commit -m "Replace card renderer with Clash-portrait arcade cards"
```

---

### Task 11: Final check for Plan A

- [ ] **Step 1: Full test run**

Run: `lua tests/run.lua`
Expected: `28 passed, 0 failed`

- [ ] **Step 2: Gameplay code untouched**

Run: `git diff --stat feat/midfield-control -- engine store ai`
Expected: only deletions of Gwent files (`engine/gwent/*`, `engine/cards/definitions/gwent_*`, `store/gwent.lua`, `ai/gwent_opponent.lua`).

- [ ] **Step 3: All scenarios run clean**

Run: `for s in home library match cards; do tools/snapshot/snap.sh $s || exit 1; done`
Expected: 5 PNGs listed, no errors.

- [ ] **Step 4: Report to the user** with the gallery and match screenshots attached (SendUserFile), and note that Plan B (match screen) is next.
