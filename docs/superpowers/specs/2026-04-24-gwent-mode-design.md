# Gwent Mode — Design Spec
**Date:** 2026-04-24
**Cycle:** 1 of 2 (Tiki-Taka + Gegenpresse factions; remaining 4 factions in Cycle 2)

---

## Overview

Add a second game mode ("Gwent Mode") to Football TCG alongside the existing "Classic Mode". The two modes share only UI primitives (theme, fonts, card drawing). Everything else — engine, store, AI, card definitions, scene — is separate so neither mode can break the other.

---

## 1. Mode Selection

The home screen gains a two-step flow:

1. **Pick mode** — Classic or Gwent (two buttons, same style as existing deck buttons)
2. **Pick deck** — deck pool is mode-specific:
   - Classic: existing three decks (Tiki-Taka, Long Ball, Catenaccio)
   - Gwent: faction decks (Tiki-Taka, Gegenpresse in Cycle 1)
3. **Pick difficulty** — same three levels (easy / medium / hard), shown after deck

`main.lua` passes the chosen mode string into the store so the right scene and store are loaded. Classic flow is unchanged.

---

## 2. Engine — `engine/gwent/`

Four new files:

### `engine/gwent/constants.lua`
```
STARTING_HAND_SIZE    = 10
BETWEEN_HALF_DRAW     = 3
MULLIGAN_START        = 2   -- cards swappable before first half
MULLIGAN_BETWEEN      = 1   -- cards swappable between halves
MAX_TRAPS             = 2
MIN_POWER             = 0
```

### `engine/gwent/state.lua`

Match state shape:
```
{
  half          = 1 | 2 | "extra",
  activePlayer  = "player" | "opponent",
  phase         = "mulligan" | "play" | "half_end" | "match_end",
  winner        = nil | "player" | "opponent",
  halvesWon     = { player=0, opponent=0 },
  passed        = { player=false, opponent=false },
  leaderUsed    = { player=false, opponent=false },
  -- weather tracks which rows have active weather ON THEM (not who played it).
  -- e.g. player plays Heavy Pitch → match.weather.opponent.attack = "HEAVY_PITCH"
  weather       = { player={ attack=nil, midfield=nil, defense=nil },
                    opponent={ attack=nil, midfield=nil, defense=nil } },
  mulliganLeft       = { player=0, opponent=0 },
  pendingStrategies  = [],   -- strategies waiting for a trigger (e.g. COUNTER_PRESS)
  players = {
    player   = { hand, deck, graveyard, pitch, leader, faction },
    opponent = { hand, deck, graveyard, pitch, leader, faction },
  },
  log = [],
}
```

Pitch per player:
```
{
  attack   = [],   -- array of pitched cards
  midfield = [],
  defense  = [],
  traps    = [],   -- face-down trap cards (max 2)
}
```

Pitched card shape:
```
{
  definition    = cardDef,
  basePower     = number,
  boosts        = [],        -- list of integers (each boost tracked separately)
  reductions    = [],        -- list of integers (each reduction tracked separately)
  locked        = false,     -- cannot be boosted if true
  weatherLocked = false,     -- set to power 1 by weather; clears when weather clears
  immune        = false,     -- immune to reductions
}
```

Effective power formula:
```
effectivePower = max(0, basePower + sum(boosts) - sum(reductions))
-- if weatherLocked: effectivePower = 1 (overrides everything)
-- if immune: reductions are ignored
```

Player score = sum of effectivePower across all three rows.

### `engine/gwent/phases.lua`

Key functions:
- `Phases.startHalf(match)` — resets pass flags, applies between-half draw if half > 1, sets phase to "mulligan"
- `Phases.resolveMulligan(match, playerId, cardIds)` — swaps chosen cards back to deck, draws replacements, decrements mulliganLeft; when both players done → phase = "play"
- `Phases.playCard(match, cardId, row)` — removes from hand, creates pitched card, appends to row, fires play ability
- `Phases.playStrategy(match, cardId, opts)` — resolves strategy effect, discards card, does NOT advance turn for traps set face-down
- `Phases.setTrap(match, cardId)` — places face-down in trap zone (counts as turn action)
- `Phases.activateTrap(match, playerId, trapIndex, context)` — fires trap effect, discards
- `Phases.activateLeader(match, playerId, opts)` — fires leader ability, sets leaderUsed flag (free action)
- `Phases.pass(match)` — sets passed[activePlayer]=true, checks if both passed → endHalf
- `Phases.endHalf(match)` — determines half winner, discards pitch, carries hand, increments halvesWon, checks match win, starts next half or ends match
- `Phases.endTurn(match)` — switches active player, skips passed players

### `engine/gwent/abilities.lua`

Ability resolver keyed by ability enum string. Called by `phases.playCard` with `(match, pitchedCard, playerId, opts)`.

Implemented abilities for Cycle 1:

**Tiki-Taka:**
- `BOOST_SELF_PER_ATTACK_ROW` — Poacher: +1 per other attack row card
- `BOOST_LEFT_IN_ROW` — Raumdeuter: boost left neighbor in same row +2
- `MOVE_TO_MID_BOOST_ALL_MID` — False Nine: move self to midfield, boost all mid cards +1
- `BOOST_SELF_IF_MID_GTE_3` — Finisher: +2 if midfield has 3+ cards
- `BOOST_ALL_ATK_AND_MID` — Talisman: boost all attack + midfield cards +1
- `BOOST_TWO_MID` — Metronome: boost two other midfield cards +1 each
- `BOOST_TOP_ATTACK` — Playmaker: boost highest attack row card +2
- `BOOST_SELF_ON_HALF_SURVIVE` — Box to Box: gains +1 basePower for each half it was carried over in hand without being played. Tracked as a `halfsSurvived` counter on the card definition in hand; incremented in `startHalf` for any hand card with this ability. When played, basePower = 5 + halfsSurvived.
- `DRAW_CARD` — Conductor: draw 1 from deck
- `BOOST_ALL_FACTION_MID` — Engine: boost all Tiki-Taka midfield cards +1
- `BOOST_ALL_MID` — Deep Threat: boost all midfield cards +1
- `IMMUNE_MIN_2` — Sweeper: cannot be reduced below 2
- `BOOST_ALL_DEF` — Libero: boost all other defense row cards +1
- `IMMUNE_WEATHER` — Wall: immune to weather effects
- `BOOST_ON_WEATHER_PLAYED` — Keeper: +2 when opponent plays weather card (trigger)
- `BOOST_TWO_LOWEST_DEF` — Organizer: boost two lowest power defense row cards +1

**Gegenpresse:**
- `REDUCE_TOP_OPPONENT_ATK` — Hunter: reduce highest opponent attack card -2
- `REDUCE_ALL_OPPONENT_ATK_1` — Press Striker: reduce all opponent attack cards -1
- `BOOST_SELF_IF_REDUCTION_THIS_TURN` — Poacher: +2 if any opponent card was reduced this turn
- `REDUCE_ANY_OPPONENT_3` — Enforcer: reduce one opponent card in any row -3
- `REDUCE_ATK_MID_1_OR_2` — Blitzer: reduce all opponent attack+mid -1, or -2 if opponent leads
- `REDUCE_ONE_OPPONENT_MID_2` — Presser: reduce one opponent mid card -2
- `REDUCE_LOWEST_OPPONENT_MID_TO_1` — Ball Winner: reduce lowest opponent mid to 1
- `REDUCE_ALL_OPPONENT_MID_1` — Disruptor: reduce all opponent mid -1, reduce self -1 at half end
- `BOOST_SELF_ON_STRATEGY` — Interceptor: +2 when opponent plays strategy (trigger)
- `REDUCE_ONE_PER_ROW` — Dynamo: reduce one opponent card in each row -1
- `REDUCE_TOP_ANYWHERE_3` — Destroyer: reduce highest power card on opponent's pitch -3
- `REDUCE_OPPONENT_ATK_ON_PLAY` — Aggressive Keeper: reduce opponent's card -1 when they play to attack (trigger)
- `REDUCE_ONE_OPPONENT_DEF_2` — Sweeper: reduce one opponent defense card -2
- `LOCK_OPPONENT_CARD` — Marker: lock one opponent card (cannot be boosted)
- `REDUCE_ALL_OPPONENT_ATK_1_DEF` — Bruiser: reduce all opponent attack cards -1
- `REDUCE_TOP_OPPONENT_ATK_3` — Sweeper Keeper: reduce highest opponent attack card -3

**Weather effects** (stored as row-level flags on opponent's pitch):
- `WEATHER_HEAVY_PITCH` — sets opponent attack row weather; all cards in row → effectivePower = 1
- `WEATHER_POOR_VISIBILITY` — opponent midfield row
- `WEATHER_WATERLOGGED` — opponent defense row
- `WEATHER_CLEARED` — clears all weather flags on all rows

**Strategy abilities:**
- `ONE_TOUCH` — boost all cards in one of your rows +1
- `TIKI_TAKA_PRESS` — look at opponent hand, choose one card to discard
- `POSITIONAL_PLAY` — move one of your cards to any row, keeps power
- `HIGH_PRESS` — reduce all opponent cards in one row -2
- `COUNTER_PRESS` — played as your turn action; stored in a `pendingStrategies` list on the match state (not face-down, not a trap). When opponent passes their turn, fires: reduce all cards in one chosen row -1, then discards. If both players pass simultaneously, fires before half-end scoring.
- `INTENSITY` — all Gegenpresse cards +1 this half; all cards -1 at start of next half

**Trap abilities:**
- `INTERCEPTION` — trigger: opponent plays to midfield; effect: reduce that card -2
- `PRESS_RESISTANCE` — trigger: opponent reduces any of your cards; effect: restore that card to base power
- `PRESS_TRIGGER` — trigger: opponent plays any card; effect: reduce it -2
- `COLLECTIVE_PRESS` — trigger: opponent plays their 3rd card in one row; effect: reduce all cards in that row -1

**Leader abilities:**
- `EL_MAESTRO` — boost all own midfield cards +2
- `THE_PRESSER_LEADER` — reduce all opponent cards in one chosen row -2

---

## 3. Card Definitions

### `engine/cards/definitions/gwent_tiki_taka.lua`

28-card preset deck (2× commons/uncommons where allowed, 1× rares, 1× legendary):

| Card | Row | Power | Rarity | Copies |
|---|---|---|---|---|
| The Poacher | attack | 4 | uncommon | 2 |
| The Raumdeuter | attack | 3 | common | 2 |
| The False Nine | attack | 2 | common | 2 |
| The Finisher | attack | 6 | uncommon | 2 |
| The Talisman | attack | 10 | legendary | 1 |
| The Metronome | midfield | 3 | common | 2 |
| The Playmaker | midfield | 4 | uncommon | 2 |
| The Box to Box | midfield | 5 | uncommon | 1 |
| The Conductor | midfield | 2 | common | 1 |
| The Engine | midfield | 3 | common | 1 |
| The Deep Threat | midfield | 7 | rare | 1 |
| The Sweeper | defense | 4 | uncommon | 1 |
| The Libero | defense | 3 | common | 2 |
| The Wall | defense | 6 | uncommon | 1 |
| The Keeper | defense | 5 | uncommon | 1 |
| The Organizer | defense | 2 | common | 1 |
| One Touch | strategy | — | — | 1 |
| Tiki-Taka Press | strategy | — | — | 1 |
| Positional Play | strategy | — | — | 1 |
| Interception | trap | — | — | 1 |
| Press Resistance | trap | — | — | 1 |

Leader: **El Maestro** (outside deck)

### `engine/cards/definitions/gwent_gegenpresse.lua`

28-card preset deck:

| Card | Row | Power | Rarity | Copies |
|---|---|---|---|---|
| The Hunter | attack | 5 | uncommon | 2 |
| The Press Striker | attack | 4 | common | 2 |
| The Poacher (GG) | attack | 3 | common | 2 |
| The Enforcer | attack | 7 | rare | 1 |
| The Blitzer | attack | 10 | legendary | 1 |
| The Presser | midfield | 4 | common | 2 |
| The Ball Winner | midfield | 3 | common | 2 |
| The Disruptor | midfield | 5 | uncommon | 1 |
| The Interceptor | midfield | 2 | common | 1 |
| The Dynamo | midfield | 6 | uncommon | 1 |
| The Destroyer | midfield | 8 | rare | 1 |
| The Aggressive Keeper | defense | 5 | uncommon | 1 |
| The Sweeper (GG) | defense | 4 | common | 2 |
| The Marker | defense | 3 | common | 1 |
| The Bruiser | defense | 6 | uncommon | 1 |
| The Sweeper Keeper | defense | 7 | rare | 1 |
| High Press | strategy | — | — | 1 |
| Counter Press | strategy | — | — | 1 |
| Intensity | strategy | — | — | 1 |
| Press Trigger | trap | — | — | 1 |
| Collective Press | trap | — | — | 1 |

Leader: **The Presser** (outside deck)

---

## 4. Store — `store/gwent.lua`

Reactive wrapper around the gwent engine. Public API:

```
Store:startMatch(playerFaction, opponentFaction, difficulty)
Store:resolveMulligan(cardIds)       -- cardIds to swap back
Store:playCard(cardId, row)
Store:playStrategy(cardId, opts)     -- opts: { targetRow, targetCardIndex, targetPlayer }
Store:setTrap(cardId)
Store:resolveTrap(trapIndex)
Store:activateLeader(opts)
Store:pass()
Store:popAbilityEvent()             -- for ability animation queue
```

Internal:
- `Store:_notify()` — triggers `onUpdate` callback (same pattern as Classic store)
- `Store:_checkHalfEnd()` — called after every action; fires endHalf if both passed
- `Store:_autoResolveTriggers(context)` — checks all set traps for trigger conditions after opponent action

No combat queue, no cover window. Instead: `abilityQueue` — list of `{ type, card, value, row }` events consumed by the scene for sequential boost/reduce animations.

---

## 5. UI — `scenes/gwent_match.lua`

Shared UI primitives: `ui/theme.lua`, `ui/fonts.lua`, `ui/card.lua` (draw functions only).

New UI functions within the scene (not separate files):

### Pitch Rows
- Each of the 6 rows (3 per player) renders as a horizontal strip
- Cards are drawn smaller (approx 52×72px vs current 70×96px) to fit multiples
- Row label on left edge: ATTACK / MID / DEF
- Row power subtotal on right edge (sum of all cards in that row)
- Weather indicator on row if active (color tint + icon)
- Opponent rows at top, player rows at bottom — same orientation as Classic

### Score Display
- Center divider between the two sets of rows
- Opponent score (top), player score (bottom), both large (~28px font)
- Score color: green if winning, red if losing, white if tied

### Left Panel
- Leader card always displayed (full card art, name, ability text)
- **ACTIVATE** button below — disabled (greyed) once used
- Opponent's leader shown when it's their panel context (no button)

### Pass Button
- Prominent button above the hand row
- Disabled on opponent's turn
- Subtle pulse animation when player is winning (score > opponent score)
- Shows "PASSED" label (greyed, no interaction) once player has passed this half

### Mulligan Overlay
- Full-screen semi-transparent modal
- Hand cards displayed, clickable to toggle selection
- Counter: "Swap X remaining"
- **Confirm** button — resolves swaps and closes overlay

### Top Bar
- Half indicator, active player, both hand counts (number only)
- Same visual style as Classic top bar

### Hand
- Same hand rendering as Classic (`ui/hand.lua` reused)
- Row selection: after clicking a card from hand, valid rows highlight for placement

---

## 6. AI — `ai/gwent_opponent.lua`

### Easy
- Plays a random card from hand each turn
- Never uses leader
- Passes only when hand is empty

### Medium
- Plays highest effective-power card each turn
- Ability targeting: reduces opponent's highest power card, boosts own lowest power card
- Uses leader when score gap exceeds 3 in opponent's favor
- Passes when ahead and remaining hand cards total power < opponent's likely response

### Hard
- Tracks opponent hand count to estimate remaining threat
- Plays weather cards when opponent has 3+ cards in a targeted row
- Pass timing: passes first when ahead by enough to win even if opponent plays all remaining cards
- Leader timing: activates at the moment it swings the half result
- Trap activation: always fires traps immediately when triggered

---

## 7. File Structure Summary

```
engine/gwent/
  constants.lua
  state.lua
  phases.lua
  abilities.lua

engine/cards/definitions/
  gwent_tiki_taka.lua
  gwent_gegenpresse.lua

data/
  gwent_decks.lua       -- preset deck definitions (like presetDecks.lua)

store/
  gwent.lua

scenes/
  gwent_match.lua

ai/
  gwent_opponent.lua
```

Modified files:
- `scenes/home.lua` — mode + deck selection flow
- `main.lua` — route to correct scene/store based on mode

Untouched: all Classic engine, store, scene, AI files.

---

## 8. Out of Scope (Cycle 2)

- Catenaccio, Total Football, Counter Attack, Park the Bus factions
- Card collection / deck builder
- Online multiplayer
