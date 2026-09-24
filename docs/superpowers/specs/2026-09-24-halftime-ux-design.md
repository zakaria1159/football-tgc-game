# #0 — VS Orientation & Half-Time Break — Design Spec
Date: 2026-09-24
Branch: `feat/halftime-ux` (on top of `feat/rules-balance`)
Origin: owner play-test feedback.

## 1. VS screen: your card always on the left

- In the combat overlay (`ui/overlay/combat.lua`), the **player's card is always drawn on the left** and the
  **opponent's card on the right**, whoever attacks — matching the pitch (your side is left).
- Who attacks is still shown by the top pill ("YOU ATTACK!" / "OPPONENT ATTACKS!") and by motion: the
  attacking card is the one that lunges toward the other at the clash; the shatter / fate animations apply to
  whichever card they belong to, on its own side.
- Badge labels follow the card: the attacker's big badge shows ATK, the defender's shows DEF / EFF. DEF, each
  under its own card (so when the opponent attacks, the ATK badge is on the right).
- Open goals (no defender card): the "EMPTY" placeholder sits on the defending side (right when you attack,
  left when the opponent attacks).
- Purely visual: combat data, timing and inputs are unchanged.

## 2. Half-time break

When a half ends and the match continues (after half 1, and before Extra Time), play stops on a
**half-time screen** instead of resuming immediately.

### Flow
1. The half ends (LP or round limit). Overlays (combat, trap activation) finish and are dismissed as today.
2. The existing half-time ribbon ("HALF TIME · YOU 1 – 0 OPP") plays, then the **half-time screen** opens.
   Before Extra Time the ribbon/screen say "FULL TIME · 1 – 1 · EXTRA TIME".
3. The engine has already reset the half (LP 4000, cards reshuffled, new hand of 5) — the screen shows the
   new hand.
4. The player may **send back up to 3 cards** from the new hand (click to toggle; selected cards lift and get
   a red "SWAP" tag). **SWAP n CARDS** replaces them: chosen cards go back into the deck, the deck is
   shuffled, and the same number are drawn. Only one swap per break.
5. **KICK OFF — 2ND HALF** (or **KICK OFF — EXTRA TIME**) closes the screen; a big "SECOND HALF" /
   "EXTRA TIME" banner plays over the pitch; the match continues exactly as today.
- Keyboard: Enter = kick off, S = swap selected, 1–5 toggle cards, Esc = open pause.

### Screen content
- Title ribbon: "HALF TIME" (or "FULL TIME — EXTRA TIME").
- Score: halves won, YOU x – y OPP.
- Stats for the half just played, YOU vs OPP: LP left, damage dealt, goals scored, cards lost.
- The new hand (hand-size cards, both badges visible), selectable.
- Buttons: SWAP (disabled until ≥ 1 card selected; greyed after use), KICK OFF.
- Uses the arcade kit (sticker panel, buttons, ribbon, navy dim) — no new visual language.

### Engine
- New `State.mulligan(matchState, playerId, cardIds)` → returns the number of cards swapped.
  Rules: at most 3 ids; only ids currently in that player's hand; only while the match is in a half-time
  break (see below); only once per break per player. Chosen cards go into the deck, the deck is shuffled,
  and the same number of cards are drawn. A keeper guarantee is not re-applied.
- `matchState.halfTimeBreak = true` is set when a half ends and the match continues; nothing can be played
  while it is true (the store refuses actions, the AI does not act). `State.kickOff(matchState)` clears it.
- Per-half stats needed by the screen are recorded before the reset: `matchState.lastHalfStats =
  { player = { lp, damage, goals, lost }, opponent = { ... } }`.
- The AI mulligans automatically at the break: it sends back traps/strategies beyond the first 2 and any
  second keeper, up to 3 cards.

### Simulator
- `tools/sim/sim.lua` treats the break as instant: both seats auto-mulligan with the AI rule, then kick off.
  Acceptance criteria (spec 2026-09-23 §6) must still pass.

## 3. Out of scope
- Tactics / team talk (project #2 will add a tactic picker to this screen).
- Bench / substitutes (project #5).

## 4. Verification
- Unit tests: `State.mulligan` rules (limit 3, hand-only, once per break, deck size preserved, card identity
  preserved), `halfTimeBreak` blocks actions, `kickOff`, `lastHalfStats`, AI mulligan choice, combat overlay
  side assignment (pure function: which snapshot goes left/right).
- Snapshot scenarios: `combat` (player attack and opponent attack — player card on the left in both),
  `halftime` (screen open, cards selected, after swap, second-half banner), `victory` / `defeat` unchanged.
- `lua tools/sim/sim.lua n=1000` acceptance still PASS.
