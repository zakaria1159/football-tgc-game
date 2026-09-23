# #1 — Card Abilities — Design Spec
Date: 2026-09-24
Branch: `feat/card-abilities` (on top of `feat/halftime-ux`)
Roadmap: project #1 of 6 (abilities → tactics → lanes → fouls → stamina → possession).

## Summary
Every field card (strikers, midfielders, defenders, keepers) gets exactly one real ability, replacing the
flavour-only `abilityText`. Abilities are implemented through a single keyword system in the engine
(`engine/cards/resolver.lua`, rewritten — its current v2 hooks are dead code). Traps and strategy cards
are unchanged. The owner approved this exact list.

## 1. Ability list (owner-approved)

Each field card gets `keyword` (id, e.g. `"CLINICAL"`), `keywordName` (display, e.g. "Clinical") and a
rewritten `abilityText` (rules text). The existing `ability` field stays reserved for traps/strategies.

### Strikers
| Card | Keyword | Rule |
|---|---|---|
| Clinical Finisher | CLINICAL — "Clinical" | A shot that exactly ties the keeper's effective DEF scores 300 damage (goal) instead of a tie. |
| The Target Man | AERIAL — "Aerial" | Offside cannot be activated against its attacks. |
| Speed Demon | PACE — "Pace" | May attack on the turn it is summoned (attack mode only). |
| Complete Forward | LINK_UP — "Link-up" | While on the pitch, your *other* striker-slot card gets +150 ATK. |
| Fox in the Box | INSTINCT — "Instinct" | +300 ATK on shots when the defending keeper is exhausted. |
| The Poacher | OPPORTUNIST — "Opportunist" | +400 ATK on shots when at least one enemy defender slot is empty. |
| Pressing Forward | PRESS — "Press" | When summoned (attack or defense mode), exhaust one enemy defender card (chosen: highest DEF face-up, else any). It cannot cover this turn. |
| Pacy Winger | BEAT_THE_MAN — "Beat the man" | Its attacks into empty slots cannot be covered. |

### Midfielders
| Card | Keyword | Rule |
|---|---|---|
| Box-to-Box | ENGINE — "Engine" | Instead of the normal mode-dependent bonus, gives +100 ATK to your strikers **and** +100 DEF to your defenders, in either mode. |
| Deep-Lying Playmaker | METRONOME — "Metronome" | When you control midfield at the start of your turn, you also get +1 summon that turn (in addition to the draw). |
| Pressing Monster | COUNTER_PRESS — "Counter-press" | +300 DEF when it covers. |
| Creative Playmaker | THROUGH_BALL — "Through ball" | Once per turn, one of your striker-slot cards may target the enemy keeper slot even when both enemy defender slots are filled (a normal shot vs full effective DEF). |
| Direct Support | OVERLAP — "Overlap" | Its attack-mode striker bonus is +300 instead of +200. |

### Defenders
| Card | Keyword | Rule |
|---|---|---|
| The Rock | IMMOVABLE — "Immovable" | On a tie (as attacker or defender), The Rock survives; only the other card is destroyed. |
| The Stopper | LAST_MAN — "Last man" | +300 DEF while it is its owner's only card in the defender slots. |
| Catenaccio Anchor | BOLT — "Bolt" | Counts +500 (instead of +300) toward its keeper's effective DEF. |
| The Destroyer | HARD_TACKLE — "Hard tackle" | When a card attacks The Destroyer and that attacker is **not destroyed** (it beat The Destroyer, or the attack was cancelled), the attacker cannot act on its owner's next turn. (An attacker that loses is destroyed anyway, per normal combat.) |
| Pressing Back | INTERCEPT — "Intercept" | May cover an empty **defender** slot (normally only the midfielder can), under the normal cover rules. |
| Ball-Playing Defender | BUILD_UP — "Build-up" | When it wins a fight (destroys the other card and survives), its owner draws 1 card. |
| Libero | SWEEPER — "Sweeper" | May cover an empty defender **or** midfielder slot; covering does not set "cannot act next turn". |

### Keepers
| Card | Keyword | Rule |
|---|---|---|
| The Wall | FORTRESS — "Fortress" | Penalties face its full effective DEF instead of base DEF. |
| Iron Fists | PUNCH_CLEAR — "Punch clear" | After it saves a shot, the shooter cannot act on its owner's next turn. |
| Sweeper Keeper | OFF_THE_LINE — "Off the line" | Once per turn, may cover an empty defender slot, fighting with its DEF. It is not exhausted/locked by covering and stays in goal. |
| Reliable Hands | SAFE_HANDS — "Safe hands" | +100 DEF for each save it made this half (max +300). |

**Clarifications**
- Only face-up or revealed cards' abilities are *visible* to the opponent; face-down cards' passive abilities
  still apply in the engine (hidden information is a UI concern), except abilities that require attacking
  (the card must be in attack mode to attack anyway).
- Bonuses stack additively with existing bonuses (midfielder card bonus, keeper line bonuses).
- The Destroyer's rule is simplified to: *when an attack against The Destroyer does not destroy the
  attacker, the attacker cannot act on its owner's next turn* (covers Destroyer being beaten, Offside, etc.).
- Keyword effects are logged (`ability_triggered` event with `{ player, card, keyword }`) so the UI can show
  a toast and the simulator can count triggers.

## 2. Engine design
- `engine/cards/resolver.lua` is rewritten as the single keyword module. It exposes small pure hooks the
  engine calls at fixed points, e.g.:
  - `Resolver.atkBonus(pitched, ctx)` / `Resolver.defBonus(pitched, ctx)` — stat modifiers (Link-up,
    Instinct, Opportunist, Last man, Counter-press, Safe hands, Engine/Overlap via midfielder bonus).
  - `Resolver.keeperLineBonus(pitched)` — Bolt.
  - `Resolver.canAttackWhenSummoned`, `Resolver.canCoverSlot(pitched, emptySlotType)`,
    `Resolver.immuneToOffside`, `Resolver.uncoverable`, `Resolver.throughBall` …
  - `Resolver.onSummon`, `Resolver.onShotResolved`, `Resolver.onFightResolved`, `Resolver.onMidfieldControl`.
  Exact names are fixed in the plan; every hook is unit-tested.
- Existing combat / keeper / cover / midfield code calls these hooks instead of hard-coding numbers.
- Card definitions get `keyword`, `keywordName`, new `abilityText`.

## 3. UI
- Field cards show a small keyword pill (keywordName) on the card face (hand, pitch, zoom, library, deck
  select fans) — placement chosen in the plan so it never covers badges or the name ribbon.
- Zoom / info sticker shows the full ability rules text.
- When an ability triggers, a short toast ("Pace: Speed Demon attacks at once", "Punch clear!") appears via
  the existing toasts; combat overlay shows bonus tags where stats changed.
- Card library can filter nothing new; it just shows the keywords.

## 4. AI
The AI understands abilities that change its decisions:
- Pace (attack with a fresh Speed Demon), Aerial (Offside policy ignores it; AI doesn't waste Offside on it),
  Beat the man / Through ball (target choice), Press (summon timing: prefer summoning Pressing Forward
  when the human has a face-up defender), cover abilities (Intercept, Sweeper, Off the line, Counter-press)
  in its cover decisions, stat bonuses via the resolver in its fight estimates.
- It must never plan an action the engine refuses (reuse the Task-9 refused-attack guard).

## 5. Balance & verification
- Unit tests: one per ability (trigger and non-trigger case), driving the real engine via tests/helpers.lua.
- Snapshot scenarios: a card gallery row with keyword pills; an `abilities` scenario showing a few triggers
  (toast visible, bonus tags).
- Simulator: `tools/sim/sim.lua` reports per-keyword trigger counts and per-card win-rate when played.
  Acceptance (unchanged): 9,000 games, every deck 42–58%, 0 stalls, first seat 45–55%.
  If a card is clearly over/under-powered (e.g. win-rate-when-played > 65% or < 35%), report numbers to the
  owner with proposed tweaks — do not tune without approval.
- rules.md gains an "Abilities" section with the table above.

## 6. Out of scope
Lanes (#3; some abilities may later become lane-aware), fouls (#4), stamina (#5), new cards.
