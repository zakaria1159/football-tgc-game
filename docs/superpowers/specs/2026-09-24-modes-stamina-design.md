# Card Modes & Stamina / Substitutions — Design Spec
Date: 2026-09-24
Branch: `feat/modes-stamina` (on top of `feat/card-abilities`)
Roadmap: owner reordered — this is next (stamina = project #5 brought forward; fouls #4 next, then tactics
#2 and deck building + formations). All decisions below were confirmed by the owner.

## Part A — Card modes (do first)

### A1. Choose the mode on the slot
- Remove the global ATTACK/DEFENSE toggle from the bottom bar (and the `M` key).
- Summoning flow: select a hand card → click a valid slot → a small **mode picker** pops up anchored on that
  slot with two buttons: **ATTACK** (face-up) and **DEFEND** (face-down). Keys: `A` = attack, `D` = defend,
  `Esc` = cancel (card stays selected, nothing placed).
- Cards that have only one legal mode skip the picker: traps (always set face-down), keeper swaps / keepers
  may choose (keepers never flip later, so the choice is permanent — the picker says so).
- Substitutions (Part B) use the same picker for the incoming card.
- The bottom-bar space freed by the toggle can hold the SUBS counter (Part B).

### A2. Switch positions both ways, once per turn (Yu-Gi-Oh style)
- During your summon phase, once per turn per card, you may switch a card's position:
  - defense → attack (as today: FLIP UP / TO ATTACK);
  - **attack → defense (new)**: the card becomes **face-up defense** (`mode = "defense"`, `revealed = true`)
    — the opponent has already seen it. It then behaves like any revealed defense card (keeps defense
    bonuses, no LP loss when destroyed, can't attack or cover unless an ability allows).
- Not allowed: on the turn the card was played/substituted in, after it attacked this turn, for keepers,
  for traps, during the half-time break, or on the opponent's turn.
- UI: attack-mode cards eligible to switch show a small **"TO DEFENSE ▼"** ribbon (drawn arrow), revealed /
  face-down eligible cards keep "TO ATTACK" / "FLIP UP". One pure `canSwitch` rule shared by engine and UI.
- AI: may pull a weak or tired attack-mode card back to defense when it would otherwise be exposed (simple
  deterministic heuristic, tested), and may flip to attack as today.

## Part B — Stamina & substitutions

### B1. Stamina
- Every field card enters the pitch with full stamina: **strikers 4, midfielders 5, defenders 6**; keepers
  never tire. **Box-to-Box (Engine) +2** (7).
- Drain: at the end of its owner's turn, each field card on the owner's pitch loses **1**. Attacking or
  covering costs **1 extra** (applied when the action resolves). **Pressing Forward (Press) and Pressing
  Monster (Counter-press)** lose 1 extra when their ability triggers.
- At **0 stamina** the card is **Tired**: −300 ATK and −300 DEF (applied through the resolver like other
  modifiers; shown on badges and in combat tags as "TIRED −300"). Stamina never goes below 0.
- **Half-time** (and Extra Time) break: all stamina refills (cards are reshuffled anyway; any card entering
  the pitch later enters with full stamina).
- Stamina is visible for both players' face-up cards and for your own cards; opponent face-down cards show
  no stamina (hidden info).
- UI: compact stamina pips on the card (placement chosen so badges, name ribbon and keyword pill stay clear);
  tired cards get a sweat/"TIRED" marker and red stat numbers.

### B2. Substitutions
- During your summon phase you may substitute: pick a field card (or keeper) from hand and drop it onto one of
  your **occupied** slots of the matching line (striker slot ← any card allowed there today; same slot
  eligibility as summoning). The outgoing card returns to your **hand** (fully rested when played again).
- Cost: **uses one summon**, and counts toward **3 substitutions per half** (keeper swaps count too).
  The incoming card follows the normal rule: it cannot attack until your next turn (Pace excepted).
- The bottom bar shows **SUBS n / 3**. Resets at half-time; Extra Time gets 3 as well.
- **Substitution strategy card** becomes the special sub: it does **not** use a summon and does **not** count
  toward the 3, and the incoming card **may act immediately** (it ignores the "wait a turn" rule for that
  card). Its existing flow (return a card, then place the replacement for free) is kept; its card text is
  updated.
- AI: substitutes tired cards (stamina 0, or 1 for strikers about to attack) when it holds a same-line card
  in hand and has subs/summons left; keeps its keeper-swap heuristic within the 3-sub budget.

### B3. Interactions
- Keeper swap (already implemented) becomes a substitution: counts toward the 3.
- Last-ditch tackle, covers, abilities: covering costs the extra stamina point whether the cover wins or not.
- Hard tackle / Punch clear / cannot-act rules unchanged.

## Verification
- Unit tests for every rule (mode picker logic is pure; canSwitch; stamina drain/tired/refill; sub limits and
  costs; Substitution card exceptions; AI heuristics), driving the real engine via tests/helpers.lua.
- Snapshot scenarios: mode picker on a slot, TO DEFENSE switch, tired card visuals, a substitution with the
  SUBS counter, the Substitution card's immediate attacker.
- Simulator: report stamina stats (avg cards tired per match, subs per match per seat, Substitution-card use)
  and keep acceptance (9,000 games; decks 42–58%; 0 stalls; first seat 45–55%; no card outside 35–65%).
  If it fails, report to the owner — no tuning without approval.
- rules.md updated (modes, switching, stamina, substitutions, Substitution card).
