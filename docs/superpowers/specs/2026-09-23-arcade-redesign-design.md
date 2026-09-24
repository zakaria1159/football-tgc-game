# Arcade Redesign — Design Spec
Date: 2026-09-23
Branch: `feat/arcade-redesign` (off `feat/midfield-control`)

## Summary

Replace the current dark-maroon "Balatro pixel" look (see `2026-04-20-visual-overhaul-design.md`) with a
**bright arcade / mobile-game style** (Clash Royale / Brawl Stars energy): saturated blue→violet background,
chunky rounded shapes, white outlines, hard navy drop shadows, pressable 3D buttons, bouncy motion.

At the same time:
- The match screen moves to a **landscape pitch** (left = you, right = opponent) so cards can be drawn much larger.
- Cards use a **Clash-portrait** design with support for per-card **player portraits** (the "monsters" of this game), falling back to type icons.
- **Gwent mode is removed** entirely.

Scope: every screen except Gwent (which is deleted) — design system, match screen, home/deck select, pause
menu, card library, and all match overlays. **No gameplay changes**: nothing under `engine/`, `store/` or
`ai/` changes except deleting Gwent files.

Window stays 1280×800, non-resizable.

---

## 0. Gwent removal

Delete:
- `scenes/gwent_match.lua`, `store/gwent.lua`, `ai/gwent_opponent.lua`, `data/gwent_decks.lua`
- `engine/gwent/` (abilities, constants, phases, state)
- `engine/cards/definitions/gwent_gegenpresse.lua`, `gwent_monsters.lua`, `gwent_northern_realms.lua`, `gwent_tiki_taka.lua`
- `football_tcg_gwent_mode_rules.md`

Edit:
- `main.lua` — remove `GwentMatch`/`GwentStore` requires, `startGwentMatch`, and all `gwent_match` scene branches.
- `scenes/home.lua` — remove the mode-select step and `gwentDeckList` (rewritten anyway in §3).

Keep: historical Gwent specs/plans under `docs/superpowers/` (history only).

---

## 1. Design system

Existing modules are rewritten in place (no parallel old/new styles). New shared primitives live in `ui/kit/`.

### `ui/theme.lua` (rewritten)
Palette and layout constants.

| Token | Value |
|---|---|
| Background gradient | top `#3d7cff` → bottom `#6b4dff` |
| Ink (outlines, drop shadows, dark text) | `#1d1d59` |
| Ink text on white | `#2b2b6b` |
| White | `#ffffff` |
| ATK | `#ff6a6a` → `#e0243a` |
| DEF | `#6ac8ff` → `#1f78e0` |
| LP (you) | `#7dff8a` → `#2ec44a` |
| LP (opponent) | `#ff8a8a` → `#e0243a` |
| Highlight — selected | `#ffe14a` |
| Highlight — attack target | `#ff4a4a` |
| Primary button (yellow) | `#ffd23a` → `#ff9a1a`, text `#5a2a00`, shadow `#a14e00` |
| Go button (green) | `#7dff8a` → `#22b347` |
| Danger button (red) | `#ff8a8a` → `#e0243a` |

Card type gradients (top-left → bottom-right):

| Type | Gradient |
|---|---|
| striker | `#ff7a59` → `#e8344a` |
| defender | `#4fb8ff` → `#2563eb` |
| midfielder | `#6ee7a0` → `#16a34a` |
| keeper | `#ffc15a` → `#ea7a0c` |
| trap | `#c77dff` → `#7b2cbf` |
| strategy | `#5eead4` → `#0f9488` |
| formation | `#ffe08a` → `#d4a017` |

Rarity: common `#cfd6e6`, uncommon `#5eead4`, rare `#ffc93a` (rare cards also get a gold outer glow).

Card sizes: pitch **108×148**, hand **120×165**, zoom **300×410**.

### `ui/fonts.lua` (rewritten)
- **Lilita One** (SIL OFL) — headings, numbers, buttons, card names.
- **Nunito Black** (SIL OFL) — small body text (ability text, toasts, hints).
- Files added to `assets/fonts/`. Anton, Bebas Neue and m6x11 are removed once nothing references them.
- API keeps `Fonts.get(size)` / `Fonts.with(size, fn)`, plus `Fonts.body(size)` for Nunito.
- Fixes the missing-glyph boxes under the current title.

### `ui/kit/draw.lua` (new)
Shared drawing primitives:
- `sticker(x, y, w, h, r, fill, opts)` — rounded shape with white border (default 3–4px) and hard navy drop shadow offset (0, 4–5px). `fill` may be a flat color or a two-stop gradient.
- `vgradient` / `diagGradient` helpers (mesh-based).
- `pill(x, y, w, h, fill, text)`.
- `atkBadge(cx, cy, size, value)` — red circle; `defBadge(cx, cy, size, value, bonus)` — blue shield with optional green `+N` tag.
- `outlinedText(text, x, y, w, align, color, outlineColor, shadow)`.
- `ribbon(x, y, w, text, color)` — banner ribbon used for titles/results.

### `ui/kit/button.lua` (new)
One button component for the whole game.
- Variants: `primary` (yellow), `go` (green), `danger` (red), `neutral` (white/ink), `icon` (small square, translucent).
- States: idle, hover (lifts 2px, shadow grows), pressed (sinks to shadow, shadow 0), disabled (desaturated, 50% alpha), focused (keyboard; pulsing).
- API: `Button.new{ id, label, variant, x, y, w, h }`, `:draw()`, `:hit(mx, my)`, `:setHover(bool)`, `:press()`.

### `ui/kit/icons.lua` (new)
- Loads PNG icons from `assets/icons/` (game-icons.net, CC BY 3.0). Credits added to `README.md`.
- Draws icons tinted white with a navy drop shadow: `Icons.draw(name, cx, cy, size)`.
- Initial set (~8): one per card type (striker, defender, midfielder, keeper, trap, strategy, formation) + card-back emblem. Exact files listed to the user for approval before download.

### `ui/kit/tween.lua` (new)
Small helpers built on existing `lib/flux.lua`: `popIn(obj)`, `bounce(obj)`, `squash(obj)`, `countTo(obj, key, target, dur)`.

### `ui/card.lua` (rewritten) — Clash-portrait card
Public API keeps its current shape so callers change minimally: `Card.drawPitched`, `Card.drawInHand`,
`Card.drawLarge` (zoom), `Card.drawTooltip` (replaced by zoom), plus `Card.drawBack(x, y, w, h)`.

Anatomy (all sizes, scaled):
- Body: rounded rect, full type gradient, 4px white border, navy drop shadow.
- Art area: **portrait** from `assets/cards/<card-id>.png` (existing lookup kept) if present, cropped to fill; else the **type icon** large and centered with a soft radial highlight.
- Type tag: navy pill with white border, straddling the top edge ("STRIKER").
- Rarity gem: small rotated square, top-right, rarity color.
- Name ribbon: white bar slightly wider than the card, ~20% from the bottom, ink text, auto-shrinks long names.
- ATK badge: red circle sticking out bottom-left. DEF badge: blue shield sticking out bottom-right. Traps/strategies/formations show no stat badges.
- Zoom size adds ability text, playstyle tags, foul tendency and status below the card on a white sticker panel.

States:
- Exhausted: desaturated + dim, "zzz" chip.
- Face-down: navy diagonal-striped back with center emblem.
- Selected: yellow ring + glow. Attack target: red ring + glow. Valid drop slot: pulsing white.
- Rare: gold outer glow.

---

## 2. Match screen (landscape)

### Background
Blue→violet gradient. The moonshine vignette in `main.lua` is removed (too dark for this style).

### Top bar (y 0–80)
- Left: player avatar circle (existing character art cropped) + green LP bar with number on it (`YOU · 3400`) + halves-won ⚽ pips.
- Right: mirrored for opponent (red bar) + opponent deck count.
- Center: phase pill `HALF 1 · TURN 3 · ATTACK` (phase word colored); under it a turn chip — `YOUR TURN` yellow / `OPP TURN` grey.
- Icon buttons: ⏸ pause, 🔊 music toggle, 📜 full log (opens the existing debug log restyled as a sticker panel).

### Pitch (≈ x 24–1256, y 90–520)
- Rounded rect, alternating vertical grass stripes (`#4fd06a` / `#46c460`), 4px white border, navy drop shadow; white halfway line, center circle, penalty boxes at left/right ends.
- 8 columns: **you** GK · DEF×2 · MID · STR×2 | STR×2 · MID · DEF×2 · GK **opponent**. Two-card columns stack vertically; single-card columns are vertically centered. Cards drawn at pitch size.
- Empty slots: dashed translucent white rounded rects labeled `DEF` / `STR` / etc. Valid targets pulse while placing.
- Keeper DEF badge shows **effective** DEF with a green `+N` tag for the defender/midfielder bonus (replaces the "Keeper DEF" HUD text).
- Midfield control: ★ crown on whichever midfielder currently has more power (`Combat.midfielderPower`).
- Traps: 2 small face-down slots in the corner by each side's own goal.

### Bottom area (y 540–800)
- Left: character portrait (existing `ui/character.lua` art and states), deck pile (card back + count, origin of the draw animation), and a **toast stack** of the 3 latest log events above it — slide in, fade after ~4s, color-coded by event type (replaces the HUD log panel).
- Center: hand, fanned with slight rotation, hand-size cards. Existing Dock magnification retained; hovered card lifts and straightens.
- Right: `SUMMONS 1 / 2` pill (green with ★ when the midfield bonus applies), ATTACK/DEFENSE segmented toggle, big yellow **END TURN**, green **START ATTACK** (summon phase only).

### Card zoom (replaces left detail panel)
Hovering any card (hand, pitch, trap you own) for ~0.3s shows a zoom-size card beside it (clamped on-screen) with ability text, playstyle tags, foul tendency, and status (exhausted, yellow cards). Clicking still selects.

### Juice
- Summoned cards squash-pop into their slots.
- LP bars drain with a trailing white "damage chunk"; numbers count down.
- `Match.flash` messages (e.g. `MIDFIELD CONTROL +1 SUMMON`, `GOAL!`) become ribbon banners that slide in.
- Screen shake kept; goal particles recolored as multicolor confetti.
- Card-draw animation (from `feat/midfield-control`) uses the new card back and the new deck position.

---

## 3. Menus

### Home
- Logo "FOOTBALL TCG" in Lilita with white outline + navy shadow, gentle bob, football icon beside it.
- Background: slow-scrolling soft diagonal stripes + a few large faded card backs in corners.
- Buttons (vertical, centered): **PLAY** (primary), **CARD LIBRARY** (neutral/blue), **QUIT** (danger). Keyboard (↑/↓/Enter/Esc) and mouse.

### Deck select (after PLAY)
- Three large deck tiles: The Beautiful Game (green), Direct Football (red), The Wall (blue) — name, style subtitle, description, and a fanned stack of 3 real cards from that deck peeking over the top.
- Selected tile lifts/scales with yellow ring.
- **◀ BACK** bottom-left, **KICK OFF ▶** bottom-right. ←/→/Enter/Esc.

### Pause menu
Navy dim; white sticker panel pops in with bounce; "PAUSED" ribbon; RESUME / CARD LIBRARY / QUIT TO MENU buttons.

### Card library
Category filters as chunky pill tabs (active filled). Grid of hand-size cards via the new renderer; mouse-wheel scroll; hover shows the zoom card. Esc or ✕ button closes.

---

## 4. Overlays

Behavior and inputs are unchanged (click / Space to continue, same data contracts); only visuals change.

- **Combat** (`ui/combat_overlay.lua`): navy dim; attacker zoom card slides in from left, defender from right, each with squash-bounce; "CLASH!" starburst + shake; ATK/DEF badges grow and count up; existing beam sprites kept but tinted; result ribbon — DESTROYED red, EXHAUSTED orange, BLOCKED / KEEPER SAVES blue, LP DAMAGE -N yellow; destroyed card shatters into a few pieces; Eff. DEF shows bonus tag. "CLICK OR SPACE ▶" pill.
- **Trap activation** (`ui/trap_activation_overlay.lua`): purple flash, trap card flips face-up center with spin + scale; "TRAP ACTIVATED!" stamp slams with bounce and dust puff; ribbon "YOU ACTIVATED A TRAP" / "OPPONENT TRAP" + context text.
- **Cover prompt** (`ui/cover_prompt.lua`): compact sticker panel slides up from the bottom (pitch stays visible); attacking card on the left; eligible coverers pulse on the pitch and appear as small cards in the panel; **COVER** (go) / **LET THROUGH** (neutral).
- **Trap window** (`ui/trap_prompt.lua`): same bottom panel; face-down traps each with **ACTIVATE**; **PASS** button.
- **Scout reveal** (`Match.drawScoutReveal`): card flips up at zoom size with "SCOUTED" ribbon, shrinks away when the timer ends.
- **Half end**: full-width ribbon "HALF TIME · YOU 1 – 0 OPP" slides across.
- **Match end** (`Match.drawWinScreen`): win — gold "VICTORY!" + confetti + character happy pose; loss — grey-blue "DEFEAT" + worried pose. Final LP and halves; **PLAY AGAIN** / **MAIN MENU** buttons.

---

## 5. Build order

Each phase leaves the game fully playable.

1. **Cleanup & assets** — remove Gwent; add Lilita One + Nunito fonts; add icon PNGs (after user approves the list).
2. **Design system** — `theme.lua`, `fonts.lua`, `ui/kit/*`, new `card.lua`.
3. **Match screen** — landscape layout, pitch, hand, top bar, bottom area, toasts, zoom, juice.
4. **Menus** — home, deck select, pause, library.
5. **Overlays** — combat, trap activation, cover/trap prompts, scout, half/match end.

## 6. Verification

No automated test suite exists. After each phase:
- Run the auto-screenshot harness (a scratchpad copy of the project with a wrapper `main.lua` that drives key presses and calls `love.graphics.captureScreenshot`) across every screen and overlay; review the images.
- Play a full match vs. the AI to completion; check every overlay appears and every button/keyboard shortcut still works.
- `git diff --stat` must show no changes under `engine/`, `store/`, `ai/` other than Gwent deletions.

## Out of scope
- Gameplay/rules changes, AI changes, new cards.
- Drawing player portraits (the renderer supports them; art is a separate effort).
- Window resizing / other resolutions.
- Sound changes.
