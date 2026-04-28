# Football TCG — Engine V3 Rules

## Core Philosophy

Every rule must create a decision, not a calculation.
Card abilities are where excitement lives — the engine is just the stage.
Position determines role. Stats determine power. Mode determines visibility.

---

## Match Structure

- Each player starts with **4000 LP**
- Match is divided into **two halves**
- A half ends when one player's LP reaches **0**
- The player who drained the opponent wins that half

| Result after two halves | Scoreline |
|---|---|
| Same player wins both halves | **2-0 — full win** |
| Each player wins one half | **1-1 — Extra Time** |
| Extra Time winner | **2-1 — win** |

If Extra Time LP are equal after 6 turns → player who dealt the most total LP damage wins. If still tied, the human player wins.

At the start of each half, LP resets to 4000 and all cards (except permanently destroyed ones) are reshuffled and redealt.

---

## Deck

- **30 cards** per deck
- Starting hand: **5 cards** (at least one Keeper is guaranteed in your opening hand)
- Draw per turn: **1 card**

---

## The Pitch

Cards are placed in lines from front to back:

```
[ Striker ] → [ Midfielder ] → [ Defender ] → [ Keeper ]
```

Slot counts per player:

| Line | Slots |
|---|---|
| Striker | 2 |
| Midfielder | 1 |
| Defender | 2 |
| Keeper | 1 |
| Trap zone | 2 |

The keeper slot holds exactly one card. All other slots can be empty.

---

## Card Modes

When placing a card you choose one of two modes:

**Attack Mode** — placed face up
- Card can attack
- Card can cover empty slots
- Opponent can see which card it is

**Defense Mode** — placed face down
- Card cannot attack
- Card **cannot cover** empty slots
- Opponent cannot see which card it is until revealed
- Revealed when directly attacked

Mode determines **visibility, ability to attack, and ability to cover** — not which stat is used in combat.
A card in attack mode still defends with DEF when attacked.

---

## Flipping to Attack Mode

During your **summon phase**, you can flip one of your face-down pitch cards to attack mode. This does not cost a summon.

Restrictions:
- The card must not have been summoned this turn
- Each card can only flip once per turn

---

## Attacking a Face Down Card

Attacking a face down card is a gamble — the attacker does not know what DEF they are facing.

- Face down card is revealed when attacked
- Combat resolves normally using ATK vs DEF
- If the attacker **wins** → defender is destroyed; **no LP damage is dealt** (the uncertainty is the tradeoff)
- If the attacker **loses** → attacker is **destroyed** AND the LP difference is dealt to the attacker's owner

```
LP penalty = Defender DEF − Attacker ATK
```

Bluffing a high-DEF card face-down protects your LP and punishes reckless attackers.

**The tradeoff for each mode:**

| | Attack Mode | Defense Mode |
|---|---|---|
| Can attack | Yes | No |
| Can cover empty slots | Yes | No |
| Identity visible | Yes | No |
| LP reward when your card is destroyed | Yes (opponent loses ATK−DEF) | No (no LP reward) |
| LP risk when attacking face-down | No | Yes — attacker loses DEF−ATK if it loses |

---

## Stats

Every card has two stats:

| Stat | Used when |
|---|---|
| ATK | Card is initiating an attack |
| DEF | Card is being attacked |

This applies regardless of mode.

Positions determine the stat balance:

| Position | ATK | DEF |
|---|---|---|
| Striker | High | Low |
| Midfielder | Balanced | Balanced |
| Defender | Low | High |
| Keeper | Very Low | Very High |

---

## Slot Roles

The **slot** determines what a card can do — not the card type itself:

| Slot | Can attack | Can score | Attacks who |
|---|---|---|---|
| Striker slot | Yes | Yes | Advances toward keeper |
| Midfielder slot | Yes | No | Attacks opposing midfielder only |
| Defender slot | Yes | No | Attacks opposing striker slot cards |
| Keeper slot | No | No | Never attacks |

Any card can be placed in any slot. No stat penalty for being out of position.

**Note:** A midfielder can only attack if the opposing midfielder slot is **occupied**. Attacking an empty midfielder slot wastes the attack and exhausts the attacker.

---

## Midfielder Card Bonus

Midfielder **cards** (a card with the midfielder type, placed in the midfielder slot) have a passive ability based on their mode:

**Attack mode** → all friendly striker slot cards gain **+200 ATK**

**Defense mode** → all friendly defender slot cards gain **+200 DEF**

A non-midfielder card placed in the midfielder slot attacks normally but provides **no bonus**.

---

## Combat Resolution

Every attack is always **ATK vs DEF**:

- **Attacking card** always uses its **ATK stat**
- **Defending card** always uses its **DEF stat**

```
margin = Attacker ATK − Defender DEF
```

### Field Combat (non-keeper)

| Scenario | Attacker outcome | Defender outcome | LP effect |
|---|---|---|---|
| ATK > DEF vs **face-up** defender | Exhausted | Destroyed | Opponent loses **ATK − DEF** LP |
| ATK > DEF vs **face-down** defender | Exhausted | Destroyed | No LP damage |
| ATK = DEF (tie) | **Destroyed** | **Destroyed** | No LP damage |
| ATK < DEF | **Destroyed** | Survives (revealed if face-down) | Attacker's owner loses **DEF − ATK** LP |

**Destroyed cards** are removed permanently — slot stays empty.
**Exhausted cards** recover at the start of their owner's next turn.

A keeper can **never be destroyed** — only exhausted (see Goal Shots below).

---

## One Attack Per Card Per Turn

Each card can only initiate **one attack per turn**.
After attacking, a card is exhausted until the start of its owner's next turn.

---

## Covering Empty Slots

When an attacker targets an empty slot the defending player must decide:

**Cover it** — use an adjacent card to intercept
- Only **attack-mode** (face-up) cards can cover — face-down cards cannot
- Combat resolves normally using ATK vs DEF
- Covering card **cannot act on the following turn** regardless of outcome

**Let it through** — attacker advances to the next occupied line automatically

Rules:
- Each player can cover **once per turn**
- Decision must be made before combat resolves
- Midfielder can cover an empty defender slot
- A defender can cover an empty midfielder slot

---

## Reaching the Keeper

A striker can only shoot the keeper when at least one defender slot is empty (there is a gap in the defensive line). If all defender slots are occupied the keeper is fully protected and cannot be directly attacked.

Midfielders **cannot shoot the keeper** — if a midfielder advances to the keeper line the attack is wasted and the midfielder is exhausted.

---

## Keeper Effective DEF

```
Keeper effective DEF = Base DEF + (non-attacking defenders × 300) + (non-attacking midfielder × 150)
```

"Non-attacking" means the card is present on the pitch and **has not initiated an attack this turn**. A defender that was attacked and survived still contributes — only defenders that have themselves attacked are excluded.

Clearing defenders (or forcing them to attack) directly weakens the keeper.

| Board state | Effective keeper DEF (Base 1800 example) |
|---|---|
| Full defense (2 defenders, 1 midfielder) | 1800 + 600 + 150 = **2550** |
| One defender cleared | 1800 + 300 + 150 = **2250** |
| Full defense cleared | 1800 + 0 + 0 = **1800** |

---

## LP Damage

LP is lost from two sources: **battle damage** (field combat) and **goal shots** (striker vs keeper).

### Battle Damage

Destroying a face-up card punishes the opponent. Losing any combat punishes you.

| Situation | LP effect |
|---|---|
| You destroy an opponent's **face-up** card | Opponent loses **ATK − DEF** LP |
| You destroy an opponent's **face-down** card | No LP damage |
| Your attacking card is destroyed | You lose **DEF − ATK** LP |
| Both cards destroyed (tie) | No LP damage |

### Goal Shots (striker vs keeper)

```
LP damage = Striker ATK − Keeper effective DEF
```

| Shot outcome | Result |
|---|---|
| ATK > effective DEF | Opponent loses that LP; keeper exhausted |
| ATK = effective DEF | No damage; both exhausted |
| ATK < effective DEF | No damage; striker exhausted |

---

## Turn Structure

1. **Draw** — draw 1 card (skip on turn 1 of each half)
2. **Summon** — place up to 2 cards in attack or defense mode; set trap cards face down freely; flip any eligible defense-mode cards to attack mode (free, once per card per turn)
3. **Attack** — each card gets one combat; play up to 1 strategy card during this phase
4. **End** — all exhausted cards recover; destroyed cards stay gone

---

## Action Limits Per Turn

| Action | Limit |
|---|---|
| Summon field cards | 2 per turn |
| Flip defense → attack | Once per card (cannot flip cards summoned this turn) |
| Strategy cards played | 1 per turn |
| Trap cards on field at once | 2 maximum |
| Attacks per card | 1 per turn |
| Covering per turn | 1 per turn |

---

## Strategy Cards

- Played openly during your **attack phase**
- Maximum **1 per turn**
- Goes to discard after use
- Does not count as a summon

**Exception:** Substitution is played during your **summon phase**.

---

## Trap Cards

- Set face down during your **summon phase**
- Activated during **opponent's turn** in response to their actions
- Maximum **2 set** on field at once
- Does not count as a summon
- Opponent knows a trap exists but not which one

---

## Win Condition

- Drain opponent LP to 0 → win the half
- Win both halves → **2-0, match over**
- Each player wins one half → **1-1 → Extra Time**
- Win Extra Time → **2-1, match over**
- Extra Time ends level after 6 turns → player with most total LP damage dealt wins

---

## What This Engine Does Not Have

- No energy system
- No xG, pressure pools, or probability tiers
- No zone control calculations
- No tag density tiers
- No out-of-position stat penalties
- No automatic covering — always the defender's active choice
- No multi-line chaining in a single attack
- No destroy thresholds — losing any combat means destroyed instantly


# Football TCG — Card Reference

## How to Read a Card

Every card entry follows this format:

**Card Name**
Type: Trap / Strategy
Rarity: rarity — max copies per deck
Activation: When this card can be played
Effect: What it does
Cost: What it costs beyond timing
Cannot activate: Situations where this card is invalid

---

## Trap Cards

Trap cards are set face down during the summon phase and activated during the opponent's turn in response to their actions. The opponent knows a trap exists but not which one.

---

**VAR**
Type: Trap
Rarity: Rare — maximum 1 copy per deck
Activation 1: When your keeper is attacked directly and LP damage is dealt
Effect 1: Negate the LP damage from this shot. The attacking striker is returned to the opponent's hand. Opponent must use one of their 2 summons next turn to resummon the returned striker.
Activation 2: When opponent activates Red Card
Effect 2: Negate the Red Card. The card that would have been destroyed survives. Red Card goes to discard.
Cost: None — timing is the cost for both activations.
Cannot activate: On shots through empty slots or covering situations — direct keeper attacks only.

---

**Offside**
Type: Trap
Rarity: Common — maximum 3 copies per deck
Activation: When an opponent's striker slot card declares an attack
Effect: That striker's attack is cancelled. They are exhausted but not destroyed. No other cards are affected this turn.
Cost: None — timing is the cost.
Cannot activate: Against midfielder slot attacks or covering actions.

---

**Red Card**
Type: Trap
Rarity: Uncommon — maximum 2 copies per deck
Activation: When an opponent's card destroys one of your cards in combat
Effect: The card that just destroyed yours is also destroyed and removed permanently.
Cost: None — you already lost a card to trigger it. One for one trade.
Note: Can be negated by VAR or Manager's Challenge.

---

**Last Defender Foul**
Type: Trap
Rarity: Rare — maximum 2 copies per deck
Activation: When your opponent's last active defender destroys your attacking card in combat
Effect: That defender receives a red card and is permanently destroyed. Your next striker attack this turn goes directly to the keeper — no covering allowed.
Cost: You already lost your attacking card to trigger it.
Cannot activate: If opponent has more than one active defender on the pitch. Can be negated by Manager's Challenge.
Strategy note: Most effective when used with a deliberately weak card in the striker slot as a sacrifice, freeing your strongest striker for a direct unprotected shot on keeper.

---

**Manager's Challenge**
Type: Trap
Rarity: Rare — maximum 1 copy per deck
Activation: When any opponent trap card is activated
Effect: Negate that trap card completely. It goes to discard with no effect.
Cost: 1000 LP paid immediately on activation.
Note: Can negate any trap including VAR and Red Card.

---

## Strategy Cards

Strategy cards are played openly during your attack phase. Maximum 1 per turn. Goes to discard after use.

---

**Direct Free Kick**
Type: Strategy
Rarity: Common — maximum 3 copies per deck
Activation: During your attack phase
Effect: Your highest ATK striker slot card attacks the keeper directly this turn regardless of defenders. Keeper effective DEF still includes active defender bonuses. Striker is exhausted after the shot regardless of outcome.
Cost: None — timing is the cost. One shot, one chance.

---

**Penalty**
Type: Strategy
Rarity: Rare — maximum 1 copy per deck
Activation: During your attack phase
Effect: Your highest ATK striker slot card attacks the keeper directly this turn. Keeper defends at base DEF only — active defender and midfielder bonuses do not apply. Striker is exhausted after the shot regardless of outcome.
Cost: None — rarity is the cost.

---

**Scout Report**
Type: Strategy
Rarity: Common — maximum 3 copies per deck
Activation: During your attack phase
Effect: Reveal one opponent face down card OR one opponent set trap card. No combat triggered, no activation triggered — information only. Revealed cards return to their face down state after being seen.
Cost: None — you gain information but take no action. Attack phase continues normally.

---

**Time Wasting**
Type: Strategy
Rarity: Rare — maximum 1 copy per deck
Activation: During your attack phase, only when your LP is higher than your opponent's LP
Effect: Opponent can only summon 1 card instead of 2 on their next turn.
Cost: None — timing and LP condition are the cost.

---

**Substitution**
Type: Strategy
Rarity: Uncommon — maximum 3 copies per deck
Activation: During your **summon phase**
Effect: Return one of your active pitch cards to your hand. Immediately summon one card from your hand to that slot — does not cost a summon. The returned card cannot be resummoned this turn.
Cost: None — the tempo loss of switching is the cost.

---

## Field Cards

Field cards are placed in slots on the pitch in either attack or defense mode.
