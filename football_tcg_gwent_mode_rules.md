# Football TCG — Gwent Mode Rules
## Implementation Document for Claude Code

---

## Overview

Football TCG Gwent Mode is a card game where two players build decks around football factions and compete across three halves. Victory is determined by total card power on the pitch — not combat. Cards are never destroyed through fighting. Instead players boost their own cards and reduce opponent cards through abilities, strategy cards and trap cards.

---

## Match Structure

- Match is divided into three potential halves: First Half, Second Half, Extra Time
- First player to win **2 halves** wins the match
- A half ends when **both players have passed** their turn
- Whoever has the **highest total power score** on the pitch when the half ends wins that half
- If both players have equal total power at end of half — the half is a draw, neither player wins it. Play continues to next half.

---

## The Pitch

Three rows per player:

```
[ ATTACK ROW    ] — striker cards
[ MIDFIELD ROW  ] — midfielder cards  
[ DEFENSE ROW   ] — defender and keeper cards
```

- Cards are placed face up in their designated row
- No limit on how many cards can be in a row
- Cards placed in a row stay there for the entire half
- Cards cannot be moved between rows once placed unless a card ability specifically allows it

---

## Deck Rules

- Minimum **25 cards** per deck
- Each deck belongs to exactly **one faction**
- Each deck has exactly **one leader card** — sits outside the deck, always available
- Maximum **2 copies** of any single card per deck
- Exception: Legendary cards — maximum **1 copy** per deck

---

## Hand and Drawing

### Match Start
- Each player draws **10 cards** from their shuffled deck
- Each player may **mulligan** — return up to 2 cards to the deck, shuffle, draw replacements
- Mulligan happens once before the first half begins

### Between Halves
- Cards played during the half are **discarded** — gone for the rest of the match
- Cards in hand that were not played **carry over** to the next half
- Each player draws **3 new cards** from their deck
- Each player may **mulligan 1 card** — return it to deck, draw replacement
- If deck is empty player draws no cards but keeps their remaining hand

### During a Half
- **No drawing** during a half
- Hand is fixed — manage it carefully

---

## Turn Structure

Each turn a player must do exactly one of the following:

**1. Play a card**
- Place a player card face up in its designated row
- OR play a strategy card for its immediate effect
- OR activate a set trap card in response to opponent action (see Trap Cards)

**2. Pass**
- Declare pass — take no action this turn
- Cards remaining in hand are saved for next half
- Once you pass you cannot un-pass this half
- If both players pass on consecutive turns — half ends immediately

### Turn Order
- Coin flip determines who goes first in first half
- Loser of previous half goes first in next half
- If half was a draw — same player who went first goes first again

---

## Scoring

```
Player score = Sum of all card power values currently on their pitch
```

- Score updates immediately whenever a card is played or a power value changes
- Both players can always see both scores
- Both players can always see how many cards opponent has in hand (count only, not which cards)

---

## Winning a Half

- Half ends when both players have passed
- Player with higher total pitch power wins the half
- Cards on pitch are discarded at end of half
- Hand carries over to next half

---

## Card Types

### Player Cards
- Have a **power value** (1-10)
- Belong to a **row** (Attack / Midfield / Defense)
- Belong to a **faction**
- Most have a **special ability** that triggers when played or while on pitch
- Placed face up in their row, stay for the entire half

### Strategy Cards
- Played immediately during your turn for an instant effect
- Never placed on the pitch
- Discarded after use
- Count as your action for that turn

### Trap Cards
- Set face down during your turn (counts as your action)
- Activated during **opponent's turn** in response to specific triggers
- Opponent can see a trap is set but not which one
- Maximum **2 trap cards** set on field at once
- Discarded after activation

### Leader Card
- One per deck, sits outside the deck
- Never drawn — always available
- Activated **once per match** anytime during your turn
- Does not count as your turn action — free activation
- Cannot be used after match is decided

---

## Power Modifications

Cards can have their power boosted or reduced by abilities, strategy cards and trap cards.

### Boosting
```
Card power = Base power + all boost effects applied
```

### Reducing
```
Card power = Base power - all reduction effects applied (minimum 0)
```

- A card's power can never go below **0**
- Some cards are immune to reduction — specified in their ability text
- Reductions and boosts are permanent for the rest of the half unless specified otherwise

---

## Weather Cards

Weather cards are special strategy cards that affect entire rows for the rest of the half. Only one weather effect can be active per row at a time. A new weather card on the same row replaces the previous one.

| Card | Effect |
|---|---|
| **Heavy Pitch** | All cards currently in opponent's attack row and all cards played to that row this half are set to power 1 |
| **Poor Visibility** | All cards currently in opponent's midfield row and all cards played to that row this half are set to power 1 |
| **Waterlogged Pitch** | All cards currently in opponent's defense row and all cards played to that row this half are set to power 1 |
| **Pitch Cleared** | Remove all active weather effects from all rows immediately |

Weather effects apply to opponent's rows only. Weather affects cards played after the weather card as well as cards already in the row.

---

## Leader Abilities

Each faction has one leader card with a unique once-per-match ability.

| Leader | Faction | Ability |
|---|---|---|
| **El Maestro** | Tiki-Taka | Boost all cards in your midfield row by +2 |
| **The Presser** | Gegenpresse | Reduce all opponent cards in one chosen row by 2 |
| **Il Muro** | Catenaccio | All your defense row cards cannot have their power reduced for the rest of this half |
| **The Architect** | Total Football | Move any two of your cards to any rows instantly. They keep their full power value |
| **The Poacher** | Counter Attack | Copy the highest power card in opponent's attack row and add a copy to your attack row |
| **The Lockdown** | Park the Bus | Reduce all opponent attack row cards to their minimum power value for the rest of this half |

---

## Factions

### Tiki-Taka
Signature mechanic — **Passing**: cards boost adjacent or same row cards when played.
Identity: Weak individually, powerful as a unit. Rewards patience and chain building.

### Gegenpresse
Signature mechanic — **Press**: reduces opponent card power aggressively.
Identity: High intensity, dominant early, burns resources fast.

### Catenaccio
Signature mechanic — **Shield**: cards that cannot be reduced below a minimum power value.
Identity: Defensive fortress, hard to break down, wins on narrow margins.

### Total Football
Signature mechanic — **Fluid**: cards gain bonus power when played out of their natural row.
Identity: Flexible and unpredictable, strong positional switching.

### Counter Attack
Signature mechanic — **React**: cards gain power in response to opponent actions.
Identity: Absorb pressure early, devastating on the counter late.

### Park the Bus
Signature mechanic — **Bunker**: defense row gets massive power boosts, attack row is deliberately weak.
Identity: Near impossible to outscore defensively, wins on the narrowest of margins.

---

## Power and Rarity

| Power Value | Rarity |
|---|---|
| 1-3 | Common |
| 4-6 | Uncommon |
| 7-9 | Rare |
| 10 | Legendary — maximum 1 copy per deck |

---

## Tiki-Taka Card List

### Attack Row

**The Poacher** — Power 4 — Uncommon
Boost self by +1 for each other card in your attack row.

**The Raumdeuter** — Power 3 — Common
When played, boost the card to your left in the attack row by +2.

**The False Nine** — Power 2 — Common
When played, move to your midfield row and boost all midfield cards by +1.

**The Finisher** — Power 6 — Uncommon
Boost self by +2 if you have at least 3 cards in your midfield row.

**The Talisman** — Power 10 — Legendary
Boost all cards in your attack and midfield rows by +1.

### Midfield Row

**The Metronome** — Power 3 — Common
When played, boost two other cards in your midfield row by +1 each.

**The Playmaker** — Power 4 — Uncommon
When played, boost the highest power card in your attack row by +2.

**The Box to Box** — Power 5 — Uncommon
Boost self by +1 at the start of each half this card survives into.

**The Conductor** — Power 2 — Common
When played, draw 1 card from your deck.

**The Engine** — Power 3 — Common
Boost all Tiki-Taka cards in your midfield row by +1.

**The Deep Threat** — Power 7 — Rare
When played, boost all cards in your midfield row by +1.

### Defense Row

**The Sweeper** — Power 4 — Uncommon
Cannot be reduced below 2 power by any opponent ability.

**The Libero** — Power 3 — Common
When played, boost all other cards in your defense row by +1.

**The Wall** — Power 6 — Uncommon
Immune to weather card effects.

**The Keeper** — Power 5 — Uncommon
When opponent plays a weather card, boost self by +2.

**The Organizer** — Power 2 — Common
When played, boost the two lowest power cards in your defense row by +1 each.

### Strategy Cards

**One Touch**
Boost all cards in one of your rows by +1 this half.

**Tiki-Taka Press**
Look at opponent's hand. Choose one card — they must discard it.

**Positional Play**
Move one of your cards to any row. It keeps its full power value.

### Trap Cards

**Interception**
Activation: When opponent plays a card to their midfield row.
Effect: Reduce that card's power by 2.

**Press Resistance**
Activation: When opponent reduces any of your card's power.
Effect: Restore that card to its original power value.

---

## Gegenpresse Card List

### Attack Row

**The Hunter** — Power 5 — Uncommon
When played, reduce the highest power card in opponent's attack row by 2.

**The Press Striker** — Power 4 — Common
When played, reduce all opponent attack row cards by 1.

**The Poacher** — Power 3 — Common
Boost self by +2 if any opponent card was reduced this turn.

**The Enforcer** — Power 7 — Rare
When played, reduce one opponent card in any row by 3.

**The Blitzer** — Power 10 — Legendary
Reduce all opponent cards in attack and midfield rows by 1. If opponent has more total power than you, reduce by 2 instead.

### Midfield Row

**The Presser** — Power 4 — Common
When played, reduce one opponent midfield row card by 2.

**The Ball Winner** — Power 3 — Common
When played, reduce the lowest power card in opponent's midfield row to 1.

**The Disruptor** — Power 5 — Uncommon
Reduce all opponent midfield cards by 1 when played. Reduce self by 1 at end of half.

**The Interceptor** — Power 2 — Common
When opponent plays a strategy card, boost self by +2.

**The Dynamo** — Power 6 — Uncommon
When played, reduce one opponent card by 1 in each row.

**The Destroyer** — Power 8 — Rare
Reduce the highest power card on opponent's pitch by 3.

### Defense Row

**The Aggressive Keeper** — Power 5 — Uncommon
When opponent plays a card to their attack row, reduce it by 1.

**The Sweeper** — Power 4 — Common
When played, reduce one opponent defense row card by 2.

**The Marker** — Power 3 — Common
Lock one opponent card — its power cannot be boosted this half.

**The Bruiser** — Power 6 — Uncommon
When played, reduce all opponent attack row cards by 1.

**The Sweeper Keeper** — Power 7 — Rare
When played, reduce the highest power card in opponent's attack row by 3.

### Strategy Cards

**High Press**
Reduce all opponent cards in one row by 2 this turn.

**Counter Press**
When opponent passes their turn, reduce all their cards in one row by 1.

**Intensity**
All your Gegenpresse cards gain +1 power this half. All your cards lose 1 power at start of next half.

### Trap Cards

**Press Trigger**
Activation: When opponent plays any card.
Effect: Reduce that card's power by 2 immediately.

**Collective Press**
Activation: When opponent plays their third card in one row.
Effect: Reduce all cards in that row by 1.

---

## Win Condition

- Win 2 halves → match over
- First Half + Second Half → same player wins both → 2-0 match win
- First Half + Second Half → different players win each → Extra Time
- Extra Time → winner takes the match 2-1
- Extra Time ends level → player with highest total power across all three halves combined wins

---

## Implementation Notes for Claude Code

- Track power values as integers, minimum 0
- Track boost and reduction effects separately so they can be reversed by specific card abilities
- Weather effects should be stored as row-level flags that modify all cards in that row
- Leader ability should be a boolean flag — used or not used
- Hand count should be visible to both players at all times
- Actual hand contents are hidden from opponent
- Pass state should be tracked per player per half — once passed cannot un-pass
- Half ends trigger when both players have passed flag set to true
- Score updates in real time as power values change
- Mulligan should happen as a pre-game phase before first half begins
- Between halves: clear pitch, carry hand, draw 3, offer mulligan 1, then start next half
