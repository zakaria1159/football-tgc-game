# Football TCG — Rules

This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update,
the 2026-09-24 card abilities and the 2026-09-24 card modes & stamina).
Where a card text or an older document disagrees, this file and the code win.

## At a glance

- Two players, 40-card decks, 4000 LP per half.
- Win two halves to win the match. At 1–1 the match goes to **Extra Time**.
- A half ends when a player reaches 0 LP, or after **14 rounds** (Extra Time: **6 rounds**).
- Kick-off alternates: **you** kick off half 1, **the opponent** kicks off half 2, and a
  **coin toss** decides who kicks off Extra Time.
- You choose each card's mode on its slot and may switch positions once per turn.
- Field cards tire: at **0 stamina** a card is **Tired** (−300 ATK / −300 DEF). You have
  **3 substitutions** per half.

---

## Match Structure

- Each half starts with **4000 LP** for both players.
- A half ends as soon as a player's LP is **0 or less**; the other player wins it.
- **Kick-off.** The player who kicks off a half plays its first turn. **You** kick off half 1,
  **the opponent** kicks off half 2, and Extra Time's kick-off is a **coin toss** (50/50). The
  half-time screen shows who kicks off next (for Extra Time, the coin toss result), and so does
  the SECOND HALF / EXTRA TIME banner. When the opponent kicks off, play resumes with its turn.
- **Half limit.** A *round* is one turn of each player, starting with the player who kicked
  off. If nobody is at 0 LP after
  **14 rounds**, the half ends and its winner is:
  1. the player with **more LP**;
  2. if level, the player who dealt **more LP damage this half**;
  3. if still level, the player who went **second** this half (the one who did not kick off).

| Result after two halves | Scoreline |
|---|---|
| Same player wins both halves | **2-0 — match won** |
| Each player wins one half | **1-1 — Extra Time** |
| Extra Time winner | **2-1 — match won** |

- **Extra Time** lasts **6 rounds**. If nobody reaches 0 LP, the winner is: more LP in Extra
  Time → more damage dealt **during Extra Time** → the player who went **second** in Extra Time.
- **Between halves** LP resets to 4000, and every card that is still in play (hand, pitch,
  set traps, deck) is shuffled together and a new hand of 5 is dealt (a keeper is guaranteed
  in that hand if the player has one left). Destroyed cards and used strategy / trap cards
  stay out for the rest of the match.
- **Half-time break.** Before the new half's Kick Off, each player may once **swap up to 3**
  cards from their new hand: the chosen cards go back into the deck, it is reshuffled, and that
  many new cards are drawn (no keeper guarantee on a swap). **The AI** swaps as soon as the
  break starts, sending back any traps/strategies beyond the first 2 in its hand, then any
  keeper beyond the first, up to 3 cards. **You** pick from the half-time screen (swapping is
  optional); when you press **Kick Off** the break ends and the new half's first turn begins
  (the opponent's turn in half 2, and in Extra Time when it wins the coin toss).

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
2. **Summon** — place up to **2** field cards (+1 with **Metronome**; 1 if the opponent played
   Time Wasting): drop a card on a slot, then choose **ATTACK** (face-up) or **DEFEND**
   (face-down); set trap cards (free, at most 2 on the field); **switch** your cards' positions
   (free, see **Card Modes**); **substitute** (below); play Substitution.
3. **Attack** — each of your cards may attack **once**, except a card summoned this turn: it
   attacks from your next turn (**Pace** excepted; this also applies to the Direct Free Kick and
   Penalty shooter). You may play **1** strategy card (Direct Free Kick, Penalty, Scout Report,
   Time Wasting).
4. **End** — your exhausted cards recover, and each of your field cards loses 1 stamina
   (see **Stamina**).

### Substitutions

During your summon phase you may **substitute**: drop a card from your hand on one of your
**occupied** slots. Your **keeper slot** takes keeper cards only (a **keeper swap**); any other
slot takes any field card, as summoning does.

- It **uses one summon** and one of your **3 substitutions per half**. Keeper swaps count too.
  The bottom bar shows **SUBS n / 3**. The count resets at half-time, and Extra Time gets 3 as
  well.
- It is allowed on any turn, the opening turn of a half included. It is not allowed during the
  half-time break, once the summon limit is reached, or as the Substitution card's free
  placement.
- The card that was there goes back to your **hand** (not the deck). It comes back as a fresh
  card: full stamina, with its per-half counters (e.g. **Safe hands** saves) and flags gone.
- The incoming card enters fully rested in the mode you pick. Like any summon, it can't attack
  until your next turn (**Pace** excepted) and can't switch position this turn. A keeper's mode
  is for good, because keepers never switch.
- On the match screen, select a card in your hand. The occupied slots it may replace glow along
  with the empty ones. Click one, then choose ATTACK or DEFEND.
- **The AI** substitutes a Tired card, or a striker-slot card at 1 stamina, when it holds a card
  of the same line and has a summon and a substitution left. It fills empty slots first. With
  the Substitution card in hand it uses that instead. It swaps keepers only within the same
  budget.

### First turn of a half

The player who **kicks off** a half (Extra Time included: you in half 1, the opponent in half 2,
the coin toss winner in Extra Time) may **not attack** and may **not play Direct Free Kick or
Penalty** on their first turn of that half. The other player may attack on its own first turn. They may still summon, set
traps, switch or substitute cards and play Scout Report, Time Wasting or Substitution. The attack phase can
still be entered; the match screen shows a hint instead of attack targets.

---

## Card Modes

**Choosing the mode.** Select a card in your hand and click a slot. A small picker opens on the
slot: **ATTACK** (key `A`) plays the card face-up and **DEFEND** (key `D`) plays it face-down.
`Esc`, or a click outside the picker, cancels, and the card stays selected. Traps skip the picker
(they are always set face-down). Keepers choose too, but keepers never switch later, so the
picker says the choice is permanent. Substitutions use the same picker.

**Attack mode** (face up)
- Can attack and can cover empty slots.
- Visible to both players.

**Defense mode** (face down)
- Cannot attack and cannot cover (exceptions: an **Intercept** defender covering an empty
  defender slot, and the **Off the line** keeper).
- Hidden from the opponent.
- When it is destroyed, its owner loses **no LP**; an attacker that loses against it pays the
  difference (the **bluff**).

**Revealed** — a face-down card that is attacked and survives, is shot at (a keeper), or is
scouted becomes **revealed**. So does an attack-mode card switched to defense. A revealed card
is shown **face up to both players with a DEF marker, but stays in defense mode**. It still
cannot attack or cover, still gives up no LP when destroyed, and keeps defense-mode bonuses (a
revealed midfielder card still gives +200 DEF to your defenders).

**Switching positions.** Once per turn per card, during your summon phase, you may switch one of
your cards. It is free.
- **Defense → attack:** a face-down card flips up (**FLIP UP**); a revealed card goes back to
  attack (**TO ATTACK**).
- **Attack → defense** (**TO DEFENSE ▼**): the card becomes a **face-up defense** card, revealed
  because the opponent has already seen it. From then on it plays like any revealed card: it
  keeps defense bonuses, gives up no LP when destroyed, and can't attack or cover unless an
  ability allows it.

Switching is not allowed:
- on the turn the card was played or substituted in;
- after it attacked this turn;
- while it is exhausted;
- for traps, or for **keepers** (never, revealed or not);
- during the half-time break;
- on the opponent's turn.

Click your card to switch it. Its ribbon shows only when the switch is legal. **The AI** switches
too:
- it flips revealed cards up to cover an open defender slot or to win a fight;
- it pulls a weak or Tired attack-mode card back to defense when an enemy card would beat it next
  turn (never the only card covering an open defender slot).

---

## Stamina

Every field card enters the pitch with full stamina. Stamina goes by card type, whatever the
slot:
- strikers **4**;
- midfielders **5**;
- defenders **6**;
- **Box-to-Box (Engine) 7**.

**Keepers never tire.**

| Drain | Stamina |
|---|---|
| End of its owner's turn (every field card on that pitch, one summoned this turn included) | −1 |
| It attacks, when the attack resolves: a fight, a shot (Through ball, Direct Free Kick and Penalty included) or a wasted attack | −1 |
| It covers, win or lose (a last-ditch tackle included) | −1 |
| **Press** fires when it is summoned; **Counter-press** fires when it covers | −1 more |

An attack cancelled by Offside never resolves, so it costs nothing. A destroyed card has left the
pitch. Stamina never goes below 0.

**Tired.** At **0** stamina a card is **Tired**: **−300 ATK and −300 DEF** in every fight, shot and
cover. A non-keeper card in your keeper slot also loses 300 of its keeper DEF. A Tired card still
counts toward your keeper's line bonus, and midfield control still uses its printed stats.

On the match screen, Tired shows as:
- a sweat drop, a red **TIRED** pill and red numbers on the card;
- the lower numbers on its badges;
- a **TIRED -300** tag in the combat overlay.

**Rest.** Substitute a tired card: it goes back to your hand and comes back fully rested. At
half-time (and before Extra Time) every card is reshuffled, so all stamina refills.

**Hidden information.** You see the stamina pips of your own cards and of the opponent's face-up
cards. The opponent's face-down cards show none.

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

A non-midfielder card in the midfielder slot gives no bonus. **Engine** and **Overlap** change
this bonus (see **Abilities**).

On the match screen the opponent's defenders show no +DEF badge while their midfielder slot
holds a face-down card that has not been revealed — you can't tell from the board what that
card is. The bonus still applies in combat.

### Field combat

| Result | Attacker | Defender | LP |
|---|---|---|---|
| ATK > DEF vs an **attack-mode** card | Exhausted | Destroyed | Defender's owner loses ATK − DEF |
| ATK > DEF vs a **defense-mode** card (face-down or revealed) | Exhausted | Destroyed | None |
| ATK = DEF | Destroyed | Destroyed | None |
| ATK < DEF | Destroyed | Survives (revealed if face-down) | Attacker's owner loses DEF − ATK |

Destroyed cards are gone for the rest of the match. Abilities can change these numbers and
results (for example **Immovable** on a tie); see **Abilities**. A **cover** that loses is a
**last-ditch tackle** instead (see **Empty Slots**).

**Exhaustion.** A card that attacked is exhausted until the end of its owner's turn, so each
card attacks once per turn. A card that **covered** cannot act on its owner's next turn (not a
**Sweeper** or an **Off the line** keeper). **Hard tackle** and **Punch clear** can also stop an
attacker acting on its owner's next turn.

---

## Who Can Attack What (match screen)

| Your slot | May target |
|---|---|
| Striker | Any opponent defender slot (empty or not); the midfielder slot when the opponent has no defenders; the keeper slot when at least one opponent defender slot is empty (or once per turn with **Through ball**) |
| Midfielder | The opponent's midfielder, only when that slot is occupied |
| Defender | The opponent's striker slots |
| Keeper | Never attacks |

The engine itself only enforces: shooting at the keeper slot needs a gap in the defender line;
the midfielder slot never shoots; an attack on an empty striker slot is wasted.

**The AI follows the same table.** Every target it picks is one you could pick in its place
(for example, its strikers never go for your midfielder while you have a defender on the
pitch). If an attack it declares is refused, it does not try that attacker again that turn.

---

## Empty Slots: Covering and Advancing

When you attack an **empty defender or midfielder slot**, the defending player may **cover**
(once per turn):
- an empty **defender** slot can be covered by their **midfielder**;
- an empty **midfielder** slot can be covered by any of their **defenders**;
- the coverer must be in attack mode, not exhausted, and not blocked by an earlier cover — except
  that an **Intercept** defender covering an empty defender slot, and the **Off the line**
  keeper, may cover in defense mode (face-down or revealed). A face-down coverer is **revealed**
  (face up, still in defense mode) and fights with its DEF.
- **Intercept**, **Sweeper** and **Off the line** add cover options; a **Beat the man** attack
  can't be covered.

A cover is a fight against the coverer, resolved as usual — except when the **coverer loses**:
that is a **last-ditch tackle**.

| Cover result | Attacker | Coverer | LP |
|---|---|---|---|
| Coverer loses (ATK > DEF) — **last-ditch tackle** | Exhausted; the attack **stops** (no advance, no shot) | **Exhausted, not destroyed** | None |
| Tie | Destroyed | Destroyed | None |
| Coverer wins (ATK < DEF) | Destroyed | Survives | Attacker's owner loses DEF − ATK |

Immovable, Hard tackle, Build-up and Counter-press work as in any fight (a tackled coverer
destroyed nothing, so Build-up doesn't draw). A tackle destroys no card and scores no goal, so
Red Card, VAR and Last Defender Foul don't fire. Whatever the result, the coverer cannot act on
its owner's next turn (not a Sweeper or an Off the line keeper).

If they **let it through** (or cannot cover), the attacker **advances**: from an empty
midfielder slot to their first defender, otherwise to the goal; from an empty defender slot
straight to the goal. A midfielder-slot card attacking an empty midfielder slot wastes its attack.

---

## Shots, the Keeper and the Open Goal

- **Every attack that reaches the keeper is a shot.** A shot never destroys the keeper (nor does
  a lost **Off the line** cover: that is a last-ditch tackle).
- **Shot ATK** = the shooter's ATK against the keeper's **effective DEF**. A **striker-slot**
  shooter adds +200 if your midfielder card is in attack mode; other shooters get no bonus.

| Shot result | Effect |
|---|---|
| ATK > effective DEF | **Goal**: the defender loses ATK − DEF LP; the keeper is exhausted |
| ATK = effective DEF | No damage; the keeper is exhausted |
| ATK < effective DEF | **Save**: no damage, nothing destroyed |

A **Through ball** shot (past a full defender line) is **one-on-one**: like a Penalty, it faces
the keeper's **base DEF** (plus Safe hands) — or its full effective DEF with **Fortress**.

The shooter is exhausted either way. Shot abilities: **Clinical**, **Instinct**, **Opportunist**,
**Punch clear**, **Safe hands**, **Fortress** (see **Abilities**).

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
**Bolt** counts +500 instead of +300; **Safe hands** adds up to +300.

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
midfield (hidden while the opponent's midfielder slot holds a face-down card that has not been
revealed, whatever its type), and the match shows **"MIDFIELD CONTROL +1 CARD"**. With
**Metronome** in your midfielder slot you also get **+1 summon** that turn. Tired doesn't change
midfield power.

---

## LP Damage Summary

| Situation | LP effect |
|---|---|
| You destroy an attack-mode card | Its owner loses ATK − DEF |
| You destroy a defense-mode card (face-down or revealed) | None |
| Your attacking card loses a fight | You lose DEF − ATK |
| Tie | None |
| A covering card loses (last-ditch tackle) | None — the coverer is exhausted, the attack stops |
| Goal | The defender loses ATK − keeper effective DEF |
| Through ball goal (one-on-one) | The defender loses ATK − keeper base DEF (effective DEF with Fortress) |
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
- **Substitution** — the special sub. Return one of your pitch cards to your hand, then place a
  card from your hand in that slot (through the mode picker). The placement costs **no summon**
  and **no substitution** (SUBS), and the new card **may attack this turn**: it ignores the
  wait-a-turn rule, but it can't switch position this turn. The freed slot takes exactly one
  free placement, this turn only. The AI plays it for its most tired card.

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
is cancelled; the attacker is exhausted but not destroyed. Not against an **Aerial** card.
Cancelling an attack on **The Destroyer** also triggers **Hard tackle**.

**Red Card** (uncommon, max 2) — when an opponent's attack **destroys** one of your cards (a win,
not a tie; a won cover fight is a last-ditch tackle and destroys nothing): the attacking card is
destroyed too.

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

## Abilities

Every field card has exactly one ability. Its keyword is shown as a yellow pill on the card, and
hovering or zooming the card shows the rules text. Traps and strategy cards have no keyword.

- Passive abilities work in either mode, face-down included. Only face-up or revealed cards'
  abilities are **visible** to the opponent: bonus badges and toasts never give away the
  opponent's face-down cards.
- Bonuses add up with the midfielder card bonus and the keeper line bonus.
- "Can't act on its owner's next turn" works like the cover rule: the card can't attack or cover
  until the end of its owner's next turn.
- When an ability fires, a toast names it (always-on bonuses show on the card badges instead).
  The combat overlay shows ability bonus tags under the cards and names rule abilities above the
  result.

### Strikers

| Card | Ability | Rule |
|---|---|---|
| Clinical Finisher | **Clinical** | A shot that exactly ties the keeper's DEF (the DEF it faces, Penalty included) is a goal for **300** LP instead of a tie. |
| The Target Man | **Aerial** | Offside can't be activated against its attacks. |
| Speed Demon | **Pace** | Can attack on the turn it is summoned (attack mode only). |
| Complete Forward | **Link-up** | While it is on your pitch (any slot), your other striker-slot cards get **+150 ATK**. |
| Fox in the Box | **Instinct** | **+300 ATK** on its shots while the defending keeper is exhausted. |
| The Poacher | **Opportunist** | **+400 ATK** on its shots while an enemy defender slot is empty (open goals included). |
| Pressing Forward | **Press** | When summoned (either mode): exhaust one enemy defender-slot card — the face-up one with the highest DEF, else a face-down one. It can't cover this turn and recovers at the end of your turn. |
| Pacy Winger | **Beat the man** | Its attacks into empty slots can't be covered. |

### Midfielders

| Card | Ability | Rule |
|---|---|---|
| Box-to-Box | **Engine** | In your midfielder slot, in either mode: **+100 ATK** to your striker-slot cards and **+100 DEF** to your defender-slot cards, instead of the normal +200. |
| Deep-Lying Playmaker | **Metronome** | In your midfielder slot: when you control midfield at the start of your turn, you also get **+1 summon** that turn. |
| Pressing Monster | **Counter-press** | **+300 DEF** when it covers. |
| Creative Playmaker | **Through ball** | While it is on your pitch, once per turn one of your striker-slot cards may shoot at the keeper slot even when both enemy defender slots are filled. That shot is **one-on-one**: the keeper's base DEF, like a Penalty (Fortress: full DEF). |
| Direct Support | **Overlap** | In your midfielder slot in attack mode, your striker-slot cards get **+300 ATK** instead of +200. |

### Defenders

| Card | Ability | Rule |
|---|---|---|
| The Rock | **Immovable** | On a tie (attacking or defending) The Rock survives; only the other card is destroyed. |
| The Stopper | **Last man** | **+300 DEF** while it is your only card in the defender slots. |
| Catenaccio Anchor | **Bolt** | Counts **+500** (instead of +300) toward your keeper's effective DEF. |
| The Destroyer | **Hard tackle** | A card that attacks The Destroyer and is not destroyed (it won, survived a tie with Immovable, or Offside cancelled the attack) can't act on its owner's next turn. |
| Pressing Back | **Intercept** | May also cover an empty **defender** slot, even in defense mode: a face-down Pressing Back is revealed (stays in defense mode) and fights with its DEF. Last-ditch tackle and cover-lock rules apply as usual. |
| Ball-Playing Defender | **Build-up** | When it wins a fight (destroys the other card and survives), you draw 1 card. |
| Libero | **Sweeper** | May cover an empty defender or midfielder slot; covering doesn't stop it acting next turn. |

### Keepers

| Card | Ability | Rule |
|---|---|---|
| The Wall | **Fortress** | Penalties face its full effective DEF instead of its base DEF. |
| Iron Fists | **Punch clear** | After it saves a shot, the shooter can't act on its owner's next turn. |
| Sweeper Keeper | **Off the line** | May cover an empty defender slot (your one cover this turn) in either mode, fighting with its own DEF (no line bonuses). It isn't locked by covering and stays in goal. If it loses the cover fight it is a last-ditch tackle: the keeper is only exhausted and the attack stops. |
| Reliable Hands | **Safe hands** | **+100 DEF** for each save it made this half (max +300), Penalties included. |

---

## Winning

- Drain the opponent to 0 LP, or lead when a half runs out of rounds → win the half.
- Two halves → **2-0**. One each → **Extra Time** → its winner wins **2-1**.

---

## Not Implemented Yet

- Fouls and yellow / red card fouls (`engine/fouls.lua` is unused).
- Formations.
- Zones.
- Deck-out penalty.
- Scout Report on set traps.
- Substitution played in response to an attack (it is a summon-phase card).
- Manager's Challenge against VAR.
- AI use of Last Defender Foul, Manager's Challenge and Scout Report.

---

# Card Reference

## Field Cards

**Strikers**

| Card | Rarity | ATK | DEF | Ability |
|---|---|---|---|---|
| Clinical Finisher | Rare | 2300 | 600 | Clinical |
| The Target Man | Common | 2200 | 600 | Aerial |
| Speed Demon | Common | 2150 | 550 | Pace |
| Complete Forward | Uncommon | 2150 | 900 | Link-up |
| Fox in the Box | Uncommon | 2150 | 650 | Instinct |
| The Poacher | Common | 2100 | 500 | Opportunist |
| Pressing Forward | Common | 2100 | 700 | Press |
| Pacy Winger | Common | 2050 | 500 | Beat the man |

**Midfielders**

| Card | Rarity | ATK | DEF | Ability |
|---|---|---|---|---|
| Box-to-Box | Common | 1800 | 1500 | Engine |
| Pressing Monster | Common | 1700 | 1400 | Counter-press |
| Direct Support | Common | 1650 | 1450 | Overlap |
| Creative Playmaker | Rare | 1600 | 1550 | Through ball |
| Deep-Lying Playmaker | Common | 1500 | 1700 | Metronome |

**Defenders**

| Card | Rarity | ATK | DEF | Ability |
|---|---|---|---|---|
| The Rock | Uncommon | 800 | 2100 | Immovable |
| The Stopper | Uncommon | 850 | 2000 | Last man |
| Catenaccio Anchor | Uncommon | 750 | 1950 | Bolt |
| The Destroyer | Common | 900 | 1900 | Hard tackle |
| Pressing Back | Common | 950 | 1800 | Intercept |
| Ball-Playing Defender | Common | 1400 | 1700 | Build-up |
| Libero | Rare | 1600 | 1500 | Sweeper |

**Keepers**

| Card | Rarity | ATK | DEF | Ability |
|---|---|---|---|---|
| The Wall | Legendary | 300 | 2000 | Fortress |
| Iron Fists | Rare | 300 | 1900 | Punch clear |
| Sweeper Keeper | Uncommon | 400 | 1800 | Off the line |
| Reliable Hands | Common | 300 | 1750 | Safe hands |

## Preset Decks (40 cards each)

| Deck | Keepers | Defenders | Midfielders | Strikers | Traps | Strategies |
|---|---|---|---|---|---|---|
| The Beautiful Game (Tiki-Taka) | 3 | 9 | 6 | 11 | 6 | 5 |
| Direct Football (Long Ball) | 3 | 10 | 5 | 13 | 5 | 4 |
| The Wall (Catenaccio) | 4 | 12 | 7 | 8 | 6 | 3 |
