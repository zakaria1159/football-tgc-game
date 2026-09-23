# Rules & Balance — Design Spec
Date: 2026-09-23
Branch: `feat/rules-balance` (on top of `feat/arcade-redesign`)
Source: balance review (9,000+ simulated AI-vs-AI matches), decisions confirmed with the owner.

## Summary

Fix the rules that make the game stall or feel arbitrary, rebalance striker/keeper stats and the Tiki-Taka
deck, turn midfield control into a mechanic that matters, fix engine/AI bugs that distort balance, and bring
`rules.md` in line with the code. Add a headless simulator to the repo so balance can be re-checked after
any change.

Out of scope: new card abilities, formations, deck-out rule, Manager's Challenge rework, Scout Report on
traps, Substitution rule enforcement, slot-role targeting restrictions (owner chose to keep free targeting).

---

## 1. Rule changes

### 1.1 Half round limit
- A half ends after **14 rounds** (a round = both players have taken a turn) if no one has reached 0 LP.
- At the limit, the half winner is: more LP → else more damage dealt **this half** → else the player who
  went **second** that half.
- Extra Time keeps its own 6-round limit (1.5).
- Constant: `C.MATCH.HALF_ROUND_LIMIT = 14`.

### 1.2 Open goal + no first-turn attacks
- Wherever an attack would reach the keeper (same reach rules as today) and the defending keeper slot is
  **empty**, the attack is a goal for the attacker's **full ATK**. Traps that react to goals (VAR) still apply.
- Strategy shots (Direct Free Kick, Penalty) at an empty keeper slot also score full ATK instead of refusing.
- The player who **starts** a half (including Extra Time) cannot declare attacks or play attacking
  strategies on their first turn of that half. The attack phase is still entered/skipped normally; the UI
  shows a hint instead of attack targets.

### 1.3 Keeper defender bonus
- A defender that attacked stops counting toward its keeper's effective DEF (+300) **until the start of its
  owner's next turn**, then counts again. Same for the midfielder's +150.
- Implementation: the "used as attacker" flag is cleared at the start of the owner's turn instead of never.

### 1.4 Revealed cards stay in defense
- When a face-down (defense-mode) card is attacked and survives — or is revealed by any effect — it becomes
  **face-up but stays in defense mode** (`revealed = true`).
- Revealed defense cards: visible to both players (UI draws their face with a "DEF" marker), keep defense
  bonuses (midfielder in defense still gives +200 DEF to defenders), do not give up battle damage when they
  lose, may be flipped to attack by their owner as today.
- Midfield power uses the card's actual mode (defense → DEF).

### 1.5 Extra Time decider
- After Extra Time's 6 rounds: more LP **in Extra Time** wins → else more damage dealt **during Extra Time**
  → else the player who went **second** in Extra Time. The human no longer wins ties by default.

### 1.6 Keeper can't be destroyed
- Targeting stays free (any card may attack any slot the code allows today).
- Any attack that reaches the keeper resolves as a **shot** (goal / save / tie), never as card-vs-card
  combat. A non-striker card advancing into the keeper shoots. Keepers are never destroyed.

### 1.7 Midfield control → +1 card
- At the start of a turn, a player whose midfielder-type card has more power than the opponent's (ATK in
  attack mode, DEF in defense mode) **draws 1 extra card** (after the normal draw). No summon bonus.
- The opponent's face-down midfielder counts for the engine rule (hidden information is only a UI concern).
- Log event `midfield_control` stays, payload gains `bonus = "draw"`.
- UI: banner text "MIDFIELD CONTROL +1 CARD"; the SUMMONS pill no longer shows ★/extra max; toast text
  "You control midfield +1 card". `C.MATCH.MIDFIELD_CONTROL_BONUS` becomes `MIDFIELD_CONTROL_DRAW = 1`.

---

## 2. Balance changes

### 2.1 Striker ATK
| Card | ATK before → after |
|---|---|
| The Target Man (common) | 2400 → **2200** |
| Speed Demon | 2200 → **2150** |
| Complete Forward | 2100 → **2150** |
| Fox in the Box | 1950 → **2150** |
| The Poacher | 2000 → **2100** |
| Pressing Forward | 2000 → **2100** |
| Pacy Winger | 1900 → **2050** |
| Clinical Finisher (rare) | 2300 (unchanged) |

### 2.2 Keeper DEF (by rarity)
| Card | DEF before → after |
|---|---|
| Reliable Hands (common) | 1700 → **1750** |
| Sweeper Keeper (uncommon) | 1600 → **1800** |
| Iron Fists (rare) | 1800 → **1900** |
| The Wall (legendary) | 2000 (unchanged) |

### 2.3 Tiki-Taka deck
- 1× Sweeper Keeper → 1× Iron Fists.
- 2× Deep-Lying Playmaker → 1× Complete Forward + 1× Speed Demon.
- Deck stays 40 cards.

---

## 3. Bug fixes (engine / store)
1. Red Card does not fire on a **tie** (attacker already destroyed).
2. VAR / Red Card also get their chance after `resolveCover` ("let through") outcomes and after strategy
   shots (Direct Free Kick, Penalty).
3. Last Defender Foul counts only **face-up** defenders and does not trigger on a tie.
4. `scenes/match.lua`: a leftover AI plan is discarded when the half changes (AI no longer skips its
   draw/summon on the first turn of a new half).

## 4. AI fixes
1. Never place defender- or midfielder-type cards in striker slots.
2. Trap discipline: Offside only against attacks worth ≥ ~300 damage or into an empty slot the AI can't
   cover; Red Card only against attackers with ATK ≥ 2000.
3. Respect the no-first-turn-attack rule and the new midfield-control draw (no special handling needed
   beyond not planning attacks on turn 1).

## 5. Documentation
- Rewrite `rules.md` to match the code: 40-card decks, half limit, open goal, first-turn rule, keeper bonus
  timing, revealed cards, Extra Time decider, keeper-as-shot, midfield control, trap behaviour, and a note
  that fouls / formations / card abilities are not implemented yet.

## 6. Verification
- **Unit tests** (plain Lua, `tests/`): one test file per rule area driving the real engine (`engine/`,
  `store/match.lua`) with constructed match states — half limit + tiebreaks, open goal, first-turn attack
  block, keeper bonus timing, revealed stays defense, Extra Time decider, keeper-as-shot, midfield draw,
  each bug fix, AI slot placement.
- **Simulator**: move the analyst's headless AI-vs-AI simulator into `tools/sim/` (runs with plain Lua,
  writes nothing into the repo). Acceptance on 9,000 seeded games (1,000 per ordered matchup, medium AI):
  - every deck's overall win rate within **42–58%**;
  - **0** games hit the safety cap / stall;
  - first-seat match win rate within **45–55%**.
- **UI**: snapshot scenarios still pass; summons pill / banner / toasts reflect the new midfield rule.
- Gameplay changes are expected under `engine/`, `store/`, `ai/`, `data/` for this branch.
