# Visual Overhaul — Design Spec
Date: 2026-04-20

## Summary

Full visual redesign of the Love2D football TCG from plain colored rectangles to a Balatro-inspired pixel aesthetic. Scope covers: layout restructure (three columns), card redesign (pixel borders, both stats), pitch reskin (casino felt), full-scene post-processing (moonshine), and "juice" effects (particles, screen shake, card shimmer).

---

## 1. Layout

### Three-column structure
Replace the current two-column layout (pitch 960px + HUD 320px) with three columns inside a 1280×800 window:

| Column | Width | Content |
|--------|-------|---------|
| Left panel | 200px | Selected card detail |
| Pitch | 680px | Game board |
| Right panel | 200px | Score, pressure, log, buttons |

Top bar spans full width (40px tall). Hand area spans full width below the columns (96px tall).

### Pitch row order
**Opponent side** (top of pitch, top → bottom):
1. Keeper
2. Defenders (up to 4)
3. Midfielder
4. Strikers ← closest to center line

**Player side** (bottom of pitch, top → bottom):
1. Strikers ← closest to center line
2. Midfielder
3. Defenders (up to 4)
4. Keeper ← closest to hand

This means opposing strikers face each other across the center line.

### Left panel — selected card detail
Shown when any card is clicked (pitched card or hand card). Contains:
- Card type tag + rarity label
- Card name (large pixel font)
- ATK value (red glow) + DEF value (blue glow), side by side
- Ability text (system font, small)
- Playstyle tags
- Foul tendency indicator
- Status (exhausted / yellow cards)

When nothing is selected: dim placeholder text "CLICK ANY CARD".

### Right panel
- Pressure pool value + pixel progress bar (segments fill left to right)
- Match stats: subs remaining, deck size, opponent deck size, active formation
- Action log (last ~8 events, color-coded by type)
- "NEXT PHASE →" button (green border)
- "END TURN ■" button (red border)

---

## 2. Visual Style — Balatro Pixel

### Font
Load `m6x11.ttf` (free, CC0) as the primary pixel font at sizes 8, 11, 16, 24. Fall back to Love2D default if file missing. Available at: https://managore.itch.io/m6x11

### Color palette
| Element | Color |
|---------|-------|
| Background | `#0d0202` (deep maroon-black) |
| Background gradient | radial from `#2a0808` at top to `#0d0202` |
| Pitch felt | `#0d2a14` with repeating 36px grid lines at 1% opacity |
| Panel background | `#0a0202` |
| Panel border | `#8b1a1a` (2px) |
| Phase pill | `#ffd700` bg, `#1a0808` text, `2px 2px 0 #8b4513` shadow |
| Score — player | `#00ff88` with glow |
| Score — opponent | `#ff4444` with glow |
| ATK stat | `#ff8080` |
| DEF stat | `#80aaff` |
| Selected border | `#ffd700` with box-shadow glow |
| Attack target border | `#ff4444` with box-shadow glow |

### Card backgrounds (flat, no gradients)
| Type | Background | Header |
|------|-----------|--------|
| Keeper | `#7c3a00` | `#9c4a00` |
| Defender | `#003a7c` | `#004a9c` |
| Midfielder | `#003a1a` | `#004a22` |
| Striker | `#7c0010` | `#9c0014` |
| Trap | `#3a007c` | `#4a009c` |
| Strategy | `#003a3a` | `#004a4a` |
| Formation | `#3a1a00` | `#4a2200` |

### Card borders
All cards use:
- `love.graphics.setLineWidth(2)` before drawing border rectangles
- `outline = 1px solid rgba(0,0,0,0.7)` (draw a slightly larger rectangle in near-black first)
- `box-shadow = 2px 2px 0 rgba(0,0,0,0.5)` (draw offset filled rect in near-black before card)

### Pitched card layout (52×52px)
```
┌─────────────────┐  ← 2px border
│ TYPE       (5px)│  ← header strip, darker bg, 14px tall
├─────────────────┤
│ A   [stat]      │  ← ATK row, 9px font, red
│ D   [stat]      │  ← DEF row, 9px font, blue
└─────────────────┘
```
Stats that are 0 or not applicable show `—` in dim color.

### Hand card layout (54×78px)
Same structure but taller — room for a name label at bottom.

### Screen post-processing (moonshine chain on full scene)
Apply a single moonshine chain to the entire game render each frame:
1. `moonshine.effects.scanlines` — subtle CRT lines (opacity ~0.09)
2. `moonshine.effects.vignette` — dark edges (radius 0.7, opacity 0.6)

The existing per-element `fxGoal` and `fxCombat` glow effects remain on top.

---

## 3. Juice Effects

### Screen shake (on goal scored + red card)
- Maintain a global `camera = { x=0, y=0 }` table
- On goal: `flux.to(camera, 0.35, {x=0}):ease("elasticout")` after setting `camera.x = 6`
- On red card: smaller shake, `camera.x = 3`, duration 0.2s
- Apply in `love.draw()` with `love.graphics.translate(camera.x, camera.y)` before drawing anything

### Particle burst (on goal scored)
- Create one `love.graphics.newParticleSystem` at startup (reused each goal)
- Particles: gold (`#ffd700`) and white squares, 4–6px, 60 particles
- Emit from center of pitch for 0.3s on goal
- `setSpeed(80, 200)`, `setLifetime(0.6, 1.2)`, `setLinearDamping(1)`
- `setColors`: gold → white → transparent fade

### Card shimmer on play (summon animation)
When a card is played from hand to pitch:
- Existing flux fly animation remains
- Add a shimmer: a white rectangle sweeps across the card face
- `shimmer = { x = -cardW }` → `flux.to(shimmer, 0.4, {x = cardW*1.5}):ease("quadout")`
- Draw as a skewed white rectangle with low alpha (~0.18) clipped to card bounds using a stencil

### Combat overlay slide-in
Already implemented (flux `backout` easing, 0.30s). Keep as-is.

### Goal flash
Already implemented (flux `quadout` fade, 1.8s). Keep as-is.

---

## 4. Files to Change

| File | Change |
|------|--------|
| `ui/theme.lua` | New palette, new card dimensions, add `layout.leftPanelW`, `layout.rightPanelW`, update `layout.pitchW` |
| `ui/card.lua` | Rewrite `drawPitched` and `drawInHand` for new visual style + both stats |
| `ui/pitch.lua` | New casino felt background, updated row order (player STR→MID→DEF→GK, opponent GK→DEF→MID→STR), new slot sizes |
| `ui/hud.lua` | Split into right panel only (score/log/buttons); left panel extracted to new file |
| `ui/card_detail.lua` | **New file** — draws the left panel selected card detail |
| `ui/combat_overlay.lua` | Update colors to match new palette |
| `ui/trap_prompt.lua` | Update colors to match new palette |
| `scenes/match.lua` | Add camera shake, particle system, shimmer; wire left panel; load pixel font |
| `main.lua` | Load m6x11 font; set window to 1280×800; apply full-scene moonshine chain |
| `conf.lua` | Update window width/height |

---

## 5. What Does NOT Change

- All engine files (`combat.lua`, `phases.lua`, `zones.lua`, etc.) — zero changes
- `store/match.lua` — zero changes
- `ai/opponent.lua` — zero changes
- Card definitions — zero changes
- Game rules — zero changes

---

## 6. Out of Scope

- Card art / illustrations (placeholder colors remain)
- Sound effects
- Animated pitch background
- Card flip animations for traps (beyond existing)
