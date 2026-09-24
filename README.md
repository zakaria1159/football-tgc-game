# Football TCG

A football-themed trading card game built with [LÖVE2D](https://love2d.org/) (Lua). Play cards representing strikers, midfielders, defenders and keepers, manage LP, trigger traps, and outsmart an AI opponent across two halves.

---

## Prerequisites

- **LÖVE2D 11.4** — the only dependency. Everything else is bundled.

---

## Install LÖVE2D

### macOS
```bash
brew install --cask love
```
Or download the `.dmg` from https://love2d.org and drag `love` to `/Applications`.

### Windows
Download the 64-bit installer from https://love2d.org and run it.  
After install, `love.exe` will be at `C:\Program Files\LOVE\love.exe`.

### Linux (Ubuntu / Debian)
```bash
sudo apt install love
```
Or check https://love2d.org for other distros.

---

## Run the game

### macOS / Linux
```bash
git clone https://github.com/zakaria1159/football-tgc-game.git
cd football-tgc-game
love .
```

### Windows
```bash
git clone https://github.com/zakaria1159/football-tgc-game.git
cd football-tgc-game
"C:\Program Files\LOVE\love.exe" .
```

That's it — no build step, no package manager, no compilation.

---

## Controls

| Action | Input |
|---|---|
| Select / place card | Left click |
| Select attack target | Left click on highlighted slot |
| Toggle summon mode (Attack / Defense) | Click **MODE** button (right panel) |
| Start attack phase | Click **START ATTACK** |
| End turn | Click **END TURN** |
| Mute / unmute music | Click **MUSIC** button (bottom of right panel) |

---

## Project structure

```
main.lua          — entry point
conf.lua          — window config (1280×800, LÖVE 11.4)
engine/           — combat, rules, AI logic
scenes/           — match scene
store/            — game state management
ui/               — rendering (pitch, hand, HUD, overlays, character)
ai/               — opponent AI
assets/           — fonts, audio, card art, character sprites
data/             — card definitions
tools/            — dev tools: snapshot harness (tools/snapshot), balance simulator (lua tools/sim/sim.lua)
rules.md          — full engine rules reference
```

---

## Game overview

- Each player starts with **4000 LP** per half and a 40-card deck
- Match is two halves — drain opponent LP to win a half
- Win both halves → **2-0**. Split → **Extra Time**
- Cards are placed in slots: Striker → Midfielder → Defender → Keeper
- Combat is always **ATK vs DEF** with LP battle damage
- Trap cards, strategy cards, covering, and keeper DEF bonuses create decisions every turn

## Credits

- Fonts: [Lilita One](https://fonts.google.com/specimen/Lilita+One) by Juan Montoreano and [Nunito](https://fonts.google.com/specimen/Nunito) by Vernon Adams, Cyreal & Jacques Le Bailly — SIL Open Font License 1.1.
- Icons: [game-icons.net](https://game-icons.net) by Delapouite (soccer-kick, goal-keeper, whistle, soccer-field, soccer-ball) and Lorc (checked-shield, on-target, wolf-trap) — CC BY 3.0.
