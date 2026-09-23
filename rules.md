# Football TCG — Rules

This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update).
Where a card text or an older document disagrees, this file and the code win.

## At a glance

- Two players, 40-card decks, 4000 LP per half.
- Win two halves to win the match. At 1–1 the match goes to **Extra Time**.
- A half ends when a player reaches 0 LP, or after **14 rounds** (Extra Time: **6 rounds**).
- The human player kicks off every half, Extra Time included.

---

## Match Structure

- Each half starts with **4000 LP** for both players.
- A half ends as soon as a player's LP is **0 or less**; the other player wins it.
- **Half limit.** A *round* is one turn of each player. If nobody is at 0 LP after
  **14 rounds**, the half ends and its winner is:
  1. the player with **more LP**;
  2. if level, the player who dealt **more LP damage this half**;
  3. if still level, the player who went **second** this half.

| Result after two halves | Scoreline |
|---|---|
| Same player wins both halves | **2-0 — match won** |
| Each player wins one half | **1-1 — Extra Time** |
| Extra Time winner | **2-1 — match won** |

- **Extra Time** lasts **6 rounds**. If nobody reaches 0 LP, the winner is: more LP in Extra
  Time → more damage dealt **during Extra Time** → the player who went **second** in Extra Time.
- **Between halves** LP resets to 4000, and every card that is still in play (hand, pitch,
  set traps, deck) is shuffled together and a new hand of 5 is dealt. Destroyed cards and used
  strategy / trap cards stay out for the rest of the match.

---

## Deck and Hand

- **40 cards** per deck (the three preset decks).
- Opening hand: **5 cards**, with at least one keeper guaranteed if the deck has one.
- Draw **1 card** at the start of each turn — except both players' **first turn of halves 1
  and 2**. In Extra Time both players draw on turn 1.
- An empty deck just means no draw. There is no hand limit.

---

## The Pitch

```
You:       [ Keeper ] [ Defender ×2 ] [ Midfielder ] [ Striker ×2 ]
Opponent:  [ Striker ×2 ] [ Midfielder ] [ Defender ×2 ] [ Keeper ]
```

| Line | Slots |
|---|---|
| Keeper | 1 |
| Defender | 2 |
| Midfielder | 1 |
| Striker | 2 |
| Trap zone | 2 |

Any card can go in any slot, with no out-of-position penalty. Every slot may be empty —
including the keeper slot (see **Open goal**).

---

## Turn Structure

1. **Draw** — 1 card (see above), then the **midfield control** card if you control midfield.
2. **Summon** — place up to **2** field cards in attack or defense mode (1 if the opponent played
   Time Wasting); set trap cards (free, at most 2 on the field); flip your face-down cards to
   attack mode (free); play Substitution.
3. **Attack** — each of your cards may attack **once**; you may play **1** strategy card
   (Direct Free Kick, Penalty, Scout Report, Time Wasting).
4. **End** — your exhausted cards recover.

### First turn of a half

The player who **starts** a half (Extra Time included) may **not attack** and may **not play
Direct Free Kick or Penalty** on their first turn of that half. They may still summon, set
traps, flip cards and play Scout Report, Time Wasting or Substitution. The attack phase can
still be entered; the match screen shows a hint instead of attack targets.

---

## Card Modes

**Attack mode** (face up)
- Can attack and can cover empty slots.
- Visible to both players.

**Defense mode** (face down)
- Cannot attack and cannot cover.
- Hidden from the opponent.
- When it is destroyed, its owner loses **no LP**; an attacker that loses against it pays the
  difference (the **bluff**).

**Revealed** — a face-down card that is attacked and survives, is shot at (a keeper), or is
scouted becomes **revealed**: it is shown **face up to both players with a DEF marker, but stays
in defense mode**. It still cannot attack or cover, still gives up no LP when destroyed, and
keeps defense-mode bonuses (a revealed midfielder card still gives +200 DEF to your defenders).

**Flipping.** During your summon phase you may flip a face-down or revealed card of yours to
attack mode. It is free, but not for a card summoned this turn, and at most once per card per
turn. There is no way back to defense mode.

---

## Stats and Combat

Every attack is **ATK vs DEF**: the attacker uses its **ATK**, the defending card always uses
its **DEF** (whatever its mode).

```
margin = Attacker ATK − Defender DEF
```

**Midfielder card bonus** (a midfielder-type card in your midfielder slot):
- in **attack mode**: your striker-slot cards get **+200 ATK** (in fights and on every shot);
- in **defense mode** (face-down or revealed): your defender-slot cards get **+200 DEF**.

A non-midfielder card in the midfielder slot gives no bonus.

### Field combat

| Result | Attacker | Defender | LP |
|---|---|---|---|
| ATK > DEF vs an **attack-mode** card | Exhausted | Destroyed | Defender's owner loses ATK − DEF |
| ATK > DEF vs a **defense-mode** card (face-down or revealed) | Exhausted | Destroyed | None |
| ATK = DEF | Destroyed | Destroyed | None |
| ATK < DEF | Destroyed | Survives (revealed if face-down) | Attacker's owner loses DEF − ATK |

Destroyed cards are gone for the rest of the match.

**Exhaustion.** A card that attacked is exhausted until the end of its owner's turn, so each
card attacks once per turn. A card that **covered** cannot act on its owner's next turn.

---

## Who Can Attack What (match screen)

| Your slot | May target |
|---|---|
| Striker | Any opponent defender slot (empty or not); the midfielder slot when the opponent has no defenders; the keeper slot when at least one opponent defender slot is empty |
| Midfielder | The opponent's midfielder, only when that slot is occupied |
| Defender | The opponent's striker slots |
| Keeper | Never attacks |

The engine itself only enforces: shooting at the keeper slot needs a gap in the defender line;
the midfielder slot never shoots; an attack on an empty striker slot is wasted. The AI follows
the table above.

---

## Empty Slots: Covering and Advancing

When you attack an **empty defender or midfielder slot**, the defending player may **cover**
(once per turn):
- an empty **defender** slot can be covered by their **midfielder**;
- an empty **midfielder** slot can be covered by any of their **defenders**;
- the coverer must be in attack mode, not exhausted, and not blocked by an earlier cover.

A cover is a normal fight against the coverer. The coverer cannot act on its owner's next turn.

If they **let it through** (or cannot cover), the attacker **advances**: from an empty
midfielder slot to their first defender, otherwise to the goal; from an empty defender slot
straight to the goal. A midfielder-slot card attacking an empty midfielder slot wastes its attack.

---

## Shots, the Keeper and the Open Goal

- **Every attack that reaches the keeper is a shot.** The keeper is **never destroyed**.
- **Shot ATK** = the shooter's ATK (+200 if your midfielder card is in attack mode) against the
  keeper's **effective DEF**.

| Shot result | Effect |
|---|---|
| ATK > effective DEF | **Goal**: the defender loses ATK − DEF LP; the keeper is exhausted |
| ATK = effective DEF | No damage; the keeper is exhausted |
| ATK < effective DEF | **Save**: no damage, nothing destroyed |

The shooter is exhausted either way.

- The **midfielder slot cannot shoot**: if its attack reaches the goal, the attack is wasted.
  Any other card shoots — a defender or midfielder card in a striker slot, or a defender-slot
  card aimed at the keeper.
- **Open goal.** If an attack reaches the goal and the **keeper slot is empty**, it is a goal for
  the attacker's **full shot ATK**. It still needs a gap in the defender line. Direct Free Kick
  and Penalty into an empty keeper slot also score full ATK. VAR can still overturn it.

### Keeper effective DEF

```
Effective DEF = Base DEF + 300 × (cards in your defender slots) + 150 × (card in your midfielder slot)
```

Any card in those slots counts, in either mode. A card that **attacked** stops counting from its
attack until the **start of your next turn** (so it is missing during the opponent's turn).

| Board (Iron Fists, base 1900) | Effective DEF |
|---|---|
| 2 defenders + midfielder | 1900 + 600 + 150 = **2650** |
| 1 defender + midfielder | 1900 + 300 + 150 = **2350** |
| Empty in front | **1900** |

---

## Midfield Control

At the start of your turn, after your normal draw, compare midfield power:
- power = your **midfielder-type card**'s ATK if it is in attack mode, DEF if in defense mode
  (face-down cards count); a non-midfielder card in the slot, or an empty slot, counts 0.

If yours is **higher**, you **draw 1 extra card**. The ★ crown on the pitch shows who controls
midfield (hidden while the opponent's midfielder is face-down and not revealed), and the match
shows **"MIDFIELD CONTROL +1 CARD"**.

---

## LP Damage Summary

| Situation | LP effect |
|---|---|
| You destroy an attack-mode card | Its owner loses ATK − DEF |
| You destroy a defense-mode card (face-down or revealed) | None |
| Your attacking card loses a fight | You lose DEF − ATK |
| Tie | None |
| Goal | The defender loses ATK − keeper effective DEF |
| Open goal | The defender loses the full shot ATK |

---

## Strategy Cards

Played openly during your **attack phase**, at most **1 per turn**, then discarded.
Substitution is played in your **summon phase** and does not count toward the limit.

- **Direct Free Kick** — your best striker-slot card (highest ATK, attack mode, able to act)
  shoots at the keeper, ignoring the defender line. The keeper's effective DEF applies. An empty
  keeper slot is an open goal.
- **Penalty** — as Direct Free Kick, but the keeper defends with its **base DEF** only.
- **Scout Report** — reveal one of the opponent's face-down cards. It stays revealed.
- **Time Wasting** — only while you have more LP: the opponent may summon only **1** card on
  their next turn.
- **Substitution** — return one of your pitch cards to your hand; your next summon into the
  freed slot is free.

---

## Trap Cards

- Set face down during your summon phase; free; at most **2** on the field.
- The opponent sees that a trap is set, not which one.
- **You (human)** get a prompt each time one of your traps can fire.
- **The AI's traps fire automatically:**
  - **Offside** — against a striker attack that would cost it at least **300 LP**, or that goes
    into an empty slot it cannot cover;
  - **Red Card** — when an attacker with at least **2000 ATK** destroys one of its cards;
  - **VAR** — on every goal against it.

  The AI sets Last Defender Foul and Manager's Challenge but never uses them.

**Offside** (common, max 3) — when an opponent's striker-slot card declares an attack: the attack
is cancelled; the attacker is exhausted but not destroyed.

**Red Card** (uncommon, max 2) — when an opponent's attack **destroys** one of your cards (a win,
not a tie — cover fights included): the attacking card is destroyed too.

**VAR** (rare, max 1) —
1. On **any goal** against you (shot, open goal, after a let-through, Direct Free Kick,
   Penalty): the LP damage is undone and the shooter returns to its owner's hand.
2. When the AI's Red Card would fire against your attacker: cancel it.

**Last Defender Foul** (rare, max 2; human only) — when your attack on the opponent's **only
face-up defender** is beaten (you lose the fight — not a tie): that defender is destroyed, and
your next striker attack this turn into an empty slot skips the cover window.

**Manager's Challenge** (rare, max 1; human only) — pay **1000 LP** to cancel the AI's Offside
against your attack (the attack goes ahead) or the AI's Red Card. It is also offered in your own
Offside window, where choosing it just lets the AI's attack through.

---

## Winning

- Drain the opponent to 0 LP, or lead when a half runs out of rounds → win the half.
- Two halves → **2-0**. One each → **Extra Time** → its winner wins **2-1**.

---

## Not Implemented Yet

- Fouls and yellow / red card fouls (`engine/fouls.lua` is unused).
- Formations.
- Card abilities — every field card's ability text is flavour only.
- Zones.
- Deck-out penalty.
- Scout Report on set traps.
- Substitution limits: the returned card can be summoned again the same turn, and Substitution
  cannot be played in response to an attack.
- Manager's Challenge against VAR.
- AI use of Last Defender Foul, Manager's Challenge, Scout Report, Substitution and mode flips.

---

# Card Reference

## Field Cards

**Strikers**

| Card | Rarity | ATK | DEF |
|---|---|---|---|
| Clinical Finisher | Rare | 2300 | 600 |
| The Target Man | Common | 2200 | 600 |
| Speed Demon | Common | 2150 | 550 |
| Complete Forward | Uncommon | 2150 | 900 |
| Fox in the Box | Uncommon | 2150 | 650 |
| The Poacher | Common | 2100 | 500 |
| Pressing Forward | Common | 2100 | 700 |
| Pacy Winger | Common | 2050 | 500 |

**Midfielders**

| Card | Rarity | ATK | DEF |
|---|---|---|---|
| Box-to-Box | Common | 1800 | 1500 |
| Pressing Monster | Common | 1700 | 1400 |
| Direct Support | Common | 1650 | 1450 |
| Creative Playmaker | Rare | 1600 | 1550 |
| Deep-Lying Playmaker | Common | 1500 | 1700 |

**Defenders**

| Card | Rarity | ATK | DEF |
|---|---|---|---|
| The Rock | Uncommon | 800 | 2100 |
| The Stopper | Uncommon | 850 | 2000 |
| Catenaccio Anchor | Uncommon | 750 | 1950 |
| The Destroyer | Common | 900 | 1900 |
| Pressing Back | Common | 950 | 1800 |
| Ball-Playing Defender | Common | 1400 | 1700 |
| Libero | Rare | 1600 | 1500 |

**Keepers**

| Card | Rarity | ATK | DEF |
|---|---|---|---|
| The Wall | Legendary | 300 | 2000 |
| Iron Fists | Rare | 300 | 1900 |
| Sweeper Keeper | Uncommon | 400 | 1800 |
| Reliable Hands | Common | 300 | 1750 |

## Preset Decks (40 cards each)

| Deck | Keepers | Defenders | Midfielders | Strikers | Traps | Strategies |
|---|---|---|---|---|---|---|
| The Beautiful Game (Tiki-Taka) | 3 | 9 | 6 | 11 | 6 | 5 |
| Direct Football (Long Ball) | 3 | 10 | 5 | 13 | 5 | 4 |
| The Wall (Catenaccio) | 4 | 12 | 7 | 8 | 6 | 3 |
