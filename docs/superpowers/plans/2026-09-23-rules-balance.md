# Rules & Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the rules and balance update:
- **Stalls:** stop games stalling with a 14-round half limit, an open goal when the keeper slot is empty, and no attacks on the starter's first turn.
- **Rules that felt arbitrary:** fix keeper-bonus timing, revealed cards, the Extra Time decider and keeper-as-shot.
- **Midfield control:** it now draws a card instead of giving a summon.
- **Balance:** new striker and keeper stats, and a new Tiki-Taka list.
- **Bugs:** fix the store trap bugs and the AI bugs.
- **Docs and tools:** bring `rules.md` in line with the code, and add a headless balance simulator under `tools/sim/`.

**Architecture:**
- **Engine:** the rule changes live in the engine.
  - `engine/state.lua` gets half bookkeeping: who started the half, damage this half, the on-time decider, and the damage helpers.
  - `engine/phases.lua` gets attack validation, shots/open goal, reveal, midfield draw, and flag clearing.
  - `engine/combat.lua` gets open-goal shots.
- **`store/match.lua`:** one helper, `_afterCombatTraps`, now runs the post-combat trap checks (Red Card / VAR) after every kind of resolved attack.
- **`ai/opponent.lua`:**
  - AI trap policy: `wantsOffside`, `wantsRedCard`.
  - Slot placement.
  - A plan tag, used to drop stale plans.
- **UI:** each UI change adds a small pure function that is unit-tested (`Card.showsFace`, `Hover.zoomable`, `Stats.summons`, `Zoom.statusLines`, `Toasts.describe`). LÖVE drawing code only calls them.
- **Simulator:** `tools/sim/sim.lua` plays seeded AI-vs-AI matches on the real engine and prints stats plus a PASS/FAIL acceptance block.

**Tech Stack:**
- LÖVE 11.4 with LuaJIT / Lua 5.1 semantics for game code:
  - no `//`;
  - no `goto` in new code;
  - use `table.unpack or unpack`;
  - never assign to a `for` loop variable.
- Plain Lua 5.5 (`/opt/homebrew/bin/lua`) for unit tests (`lua tests/run.lua`) and the simulator.
- `luac -p` for syntax checks of LÖVE-only files.
- `tools/snapshot/snap.sh <scenario>` for screenshots.

**Spec:** `docs/superpowers/specs/2026-09-23-rules-balance-design.md` (all sections).
**Branch:** `feat/rules-balance`, already checked out. The spec commit is `71a0fff`.

**Conventions (apply to every task):**
- **Working directory:** run every command from the repo root, `/Users/mac/Documents/football-tcg-lua`.
- **Commit messages:**
  - Every commit message ends with a blank line followed by `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Use `git commit -m "<subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`. The commit steps below show the full command.
- **No `luac.out`:**
  - Only ever run `luac -p` (parse only, writes nothing).
  - Before each commit, `ls luac.out` must print `ls: luac.out: No such file or directory`.
- **Snapshots:**
  - PNGs land in `.snapshots/` (gitignored) and are captured at highdpi (2560×1600).
  - Review each listed PNG with the Read tool. If it does not match its checklist, fix and re-run before committing.
- **Tests:**
  - Test files that drive the engine use `tests/helpers.lua` (Task 1).
  - The test count is **143** at the start and **216** at the end.
- **Balance:** never change a card stat or deck list beyond spec §2. If the simulator fails acceptance, report the numbers and stop (Task 11).

**Intentional deviations and clarifications (read before starting):**
1. **Who starts a half:**
   - `matchState.halfStarter` is always `"player"`, as today: the human kicks off every half and Extra Time.
   - The rules are written against `halfStarter`, so "the player who went second" is always derived from it.
2. **Open-goal ATK:**
   - An open goal scores the same ATK a shot uses, including the +200 from an attack-mode midfielder card.
   - The shot code already adds that bonus; `Combat.resolveShot` handles `keeper == nil`.
3. **Midfielder slot and shots:**
   - The existing rule "the midfielder **slot** can't shoot" (attack wasted) is kept.
   - The "wasted" check for an attack that advances used to look at the **card type**. It now looks at the **slot**, the same as a direct shot.
   - So, per spec §1.6, a midfielder- or defender-type card in a striker slot now shoots when it advances.
4. **Attack validation:**
   - `Phases.validateAttack` runs **before** any trap window. It checks the first-turn rule, the keeper needing a gap, and whether the attacker is exhausted or in defense mode.
   - So illegal attacks never spend a trap.
   - An empty keeper slot behind a full defender line now returns "keeper protected — clear a defender first" (before, the attack was silently wasted).
5. **`half_end` log reason:** the payload gains `reason = "lp" | "time"`, which the simulator uses. Toasts are unchanged.
6. **Damage helpers:**
   - All LP damage goes through `State.dealDamage`. It updates `lp`, `totalDamageDealt` and the new `halfDamageDealt`.
   - VAR uses `State.refundDamage`, so an overturned goal no longer counts as damage dealt. This also affects the match-end "LP DAMAGE" row.
7. **Deterministic half reset:** `State._resetHalf` now walks the players in a fixed order (`player`, then `opponent`) instead of `pairs()`, so seeded simulator runs are reproducible.
8. **Scout Report:**
   - It marks its target `revealed`, per spec §1.4 "revealed by any effect".
   - Its card text drops "returns to face-down" and the trap-scouting clause. Trap scouting is not implemented and is out of scope.
9. **AI and revealed cards:** the AI reads a revealed card's DEF instead of treating it as an unknown face-down card. Otherwise it would keep bouncing off known walls.
10. **Wider trap coverage:**
    - VAR and Red Card also get their chance after an attack that was waiting on an Offside window: the human passes, or Manager's Challenge overrules. This is the same bug class as spec §3.2.
    - VAR returns the shooter from whatever slot it attacked from (before: striker slot only).
11. **AI summon count:** the AI's summon count is now `limit − summonCount` (it was `min(2 − count, limit)`).
12. **Strategy-shot combat overlay:** it is snapshotted **before** the shot, so it shows the right striker, its +200 bonus, and the keeper's base DEF for a Penalty.
13. **Attack errors:** a refused attack from a click (for example on the first turn) flashes its reason in the banner.
14. **README:** fixes "30-card deck" → 40, and lists `tools/sim`.
15. **Simulator scope:**
    - Kept: seeded N-per-matchup runs, the stats table, the stall cap.
    - New: an acceptance block.
    - Dropped: `cardvalue.sh`, `stats.lua`, variants, tweaks, turtle and trace.
16. **Found during planning, NOT fixed (outside the spec; listed in the final report for the owner):**
    - **`recoverPitch` and slot holes.**
      - `Phases.endTurn`'s `recoverPitch` walks `pitch.defenders` / `pitch.strikers` with `ipairs`, which stops at the first empty slot.
      - Result: a card in slot 2 behind an empty slot 1 never loses `exhausted`, `cannotActNextTurn` or `summonedThisTurn`.
    - **Keeper guarantee corrupts decks.**
      - `State.newPlayerState` / `State._resetHalf` swap the keeper with `shuffled[math.random(...)]` on both sides of one assignment.
      - That is two different random indices, so one card is duplicated and another is lost whenever the keeper wasn't in the opening hand.

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `engine/constants.lua` | modify | `HALF_ROUND_LIMIT = 14`; `MIDFIELD_CONTROL_BONUS` → `MIDFIELD_CONTROL_DRAW = 1` |
| `engine/state.lua` | modify | `halfStarter`, `halfDamageDealt`, `other`, `isOpeningTurn`, `dealDamage`, `refundDamage`, `decideOnTime`, half limit, Extra Time decider, `revealed` field, fixed reset order |
| `engine/combat.lua` | modify | `resolveShot` open goal; keeper-bonus comment |
| `engine/phases.lua` | modify | `validateAttack`, `attack`, `_shootAtGoal`, `_advanceThrough`, `_goalAttempt`, strategy shots, reveal-stays-defense, `_clearAttackerFlags`, midfield draw |
| `engine/cards/definitions/strikers.lua`, `keepers.lua`, `strategies.lua` | modify | §2 stats; Scout Report text |
| `data/presetDecks.lua` | modify | Tiki-Taka list |
| `store/match.lua` | modify / rewrite (Task 8) | Validation before traps; `_afterCombatTraps`, `_resumeAttack`, Last Defender Foul fix; strategy-shot snapshot; VAR refund; AI trap policy hooks |
| `ai/opponent.lua` | modify | First-turn guard, revealed-aware fights, slot placement, summon limit, `wantsOffside` / `wantsRedCard` / `estimateAttackDamage`, `planTag` |
| `scenes/match.lua` | modify | First-turn hint/targets, attack error flash, zoom rule, scout targets, midfield banner, stale `aiPlan` |
| `ui/card.lua` | modify | `Card.showsFace`; revealed card face + DEF marker |
| `ui/pitch.lua` | modify | Opponent face-down = not `showsFace` |
| `ui/match/hover.lua` | modify | `Hover.zoomable` (pure) |
| `ui/match/stats.lua` | modify | Crown uses revealed midfielder; `summons` has no bonus |
| `ui/match/bottombar.lua` | modify | SUMMONS pill without ★ / bonus fill |
| `ui/match/toasts.lua` | modify | "midfield +1 card" |
| `ui/match/zoom.lua` | modify | "Mode: DEFENSE (revealed)" |
| `tools/snapshot/scenarios.lua` | modify | Juice banner text; new `revealed` and `midfield` scenarios |
| `tools/sim/sim.lua` | create | Headless simulator + acceptance block |
| `rules.md` | rewrite | Rules as implemented |
| `README.md` | modify | 40-card deck; `tools/` line |
| `tests/helpers.lua` | create | Builders for engine/store/AI tests (not auto-run) |
| `tests/test_helpers.lua` | create | Helper sanity tests |
| `tests/test_rules_keeper_shot.lua`, `test_rules_open_goal.lua`, `test_rules_first_turn.lua`, `test_rules_half_limit.lua`, `test_rules_extra_time.lua`, `test_rules_keeper_bonus.lua`, `test_rules_revealed.lua`, `test_rules_midfield.lua` | create | One file per rule area |
| `tests/test_revealed_ui.lua` | create | Revealed-card UI rules |
| `tests/test_store_traps.lua` | create | Spec §3 bug fixes |
| `tests/test_ai.lua` | create | Spec §4 AI fixes |
| `tests/test_balance_data.lua` | create | Spec §2 data |
| `tests/test_match_stats.lua`, `tests/test_toasts.lua` | modify | Midfield control no longer gives summons |

---

### Task 1: Test helpers for engine-driven tests

**Files:**
- Create: `tests/helpers.lua`
- Test: `tests/test_helpers.lua`

- [ ] **Step 1: Create `tests/helpers.lua`.** `tests/run.lua` only loads `tests/test_*.lua`, so this file is not run on its own.

```lua
-- Builders for rules tests: the real engine, store and AI with hand-placed boards.
-- Not a test file (tests/run.lua only loads tests/test_*.lua).
local State = require("engine.state")
local Store = require("store.match")

local H = {}

local DEFS = {}
for _, f in ipairs({ "keepers", "defenders", "midfielders", "strikers", "traps", "strategies" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do DEFS[d.id] = d end
end

-- Real card definition by id (traps, strategies).
function H.def(id) return assert(DEFS[id], "no card " .. id) end

local serial = 0
-- Field-card definition with exact stats, so rules tests don't depend on balance data.
function H.card(ctype, atk, def)
    serial = serial + 1
    return { id = "t-" .. ctype .. "-" .. serial, name = "Test " .. ctype .. " " .. serial,
             type = ctype, rarity = "common", stats = { atk = atk, def = def } }
end

-- n filler cards (distinct ids) for a deck.
function H.filler(n)
    local t = {}
    for i = 1, n do t[i] = H.card("defender", 100, 100) end
    return t
end

-- Match with empty boards and hands and a 10-card filler deck on each side.
-- opts: turn (2), half (1), phase ("attack"), active ("player").
function H.match(opts)
    opts = opts or {}
    local m = State.newMatch(H.filler(10), H.filler(10))
    for _, id in ipairs({ "player", "opponent" }) do
        m.players[id].hand = {}
        m.players[id].deck = H.filler(10)
    end
    m.turn         = opts.turn or 2
    m.half         = opts.half or 1
    m.phase        = opts.phase or "attack"
    m.activePlayer = opts.active or "player"
    return m
end

-- Put a pitched card on owner's board. slotType: keeper|defender|midfielder|striker|trap.
-- mode defaults to "attack" ("defense" for traps).
function H.place(m, owner, slotType, index, cardDef, mode)
    local pitch = m.players[owner].pitch
    local card  = State.newPitchedCard(cardDef, slotType,
        mode or (slotType == "trap" and "defense" or "attack"))
    if slotType == "keeper" then pitch.keeper = card
    elseif slotType == "midfielder" then pitch.midfielder = card
    elseif slotType == "defender" then pitch.defenders[index] = card
    elseif slotType == "striker" then pitch.strikers[index] = card
    elseif slotType == "trap" then table.insert(pitch.traps, card) end
    return card
end

-- Set a real trap (e.g. "trap-var") in owner's trap zone.
function H.trap(m, owner, id) return H.place(m, owner, "trap", nil, H.def(id), "defense") end

-- Put a card definition in owner's hand; returns it.
function H.give(m, owner, cardDef)
    table.insert(m.players[owner].hand, cardDef)
    return cardDef
end

-- Store around a prepared match (no startMatch shuffle).
function H.store(m)
    local s = Store.new()
    s.match = m
    return s
end

-- Log entries of one type, in order.
function H.events(m, eventType)
    local out = {}
    for _, e in ipairs(m.log) do if e.type == eventType then out[#out + 1] = e end end
    return out
end

-- Slot table shorthand: H.slot("striker", 1), H.slot("keeper").
function H.slot(slotType, index) return { type = slotType, index = index or 0 } end

return H
```

- [ ] **Step 2: Create `tests/test_helpers.lua`.**

```lua
local T = require("tests.t")
local H = require("tests.helpers")

T.test("helpers: H.match gives empty boards and hands in the requested phase", function()
    local m = H.match({ turn = 3, phase = "summon", active = "opponent" })
    T.eq(#m.players.player.hand, 0); T.eq(#m.players.opponent.deck, 10)
    T.eq(m.players.player.pitch.keeper, nil); T.eq(m.turn, 3)
    T.eq(m.phase, "summon"); T.eq(m.activePlayer, "opponent")
end)

T.test("helpers: a placed board drives a real store attack", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 500)
    T.eq(m.players.opponent.lp, 3500)
    T.eq(m.players.opponent.pitch.defenders[1], nil)
end)
```

- [ ] **Step 3: Run the tests**

Run: `lua tests/run.lua`
Expected: `145 passed, 0 failed`

- [ ] **Step 4: Commit**

```bash
ls luac.out
git add tests/helpers.lua tests/test_helpers.lua
git commit -m "Add engine test helpers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **145**.

---

### Task 2: Keeper-as-shot, open goal and the first-turn rule (spec §1.2, §1.6)

**Files:**
- Modify: `engine/state.lua`, `engine/combat.lua`, `engine/phases.lua`, `store/match.lua`, `ai/opponent.lua`, `scenes/match.lua`
- Test: `tests/test_rules_keeper_shot.lua`, `tests/test_rules_open_goal.lua`, `tests/test_rules_first_turn.lua`

- [ ] **Step 1: Write `tests/test_rules_keeper_shot.lua`.**

```lua
local T = require("tests.t")
local H = require("tests.helpers")

-- Player's striker slot holds `attackerDef`; opponent has only a face-down keeper (DEF 1600).
local function board(attackerDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, attackerDef)
    local keeper = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600), "defense")
    return m, keeper, H.store(m)
end

T.test("keeper-as-shot: a defender card advancing from a striker slot shoots instead of fighting", function()
    local m, keeper, s = board(H.card("defender", 1800, 1500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)
    T.eq(m.players.opponent.lp, 3800)
    T.eq(m.players.opponent.pitch.keeper, keeper, "keeper never destroyed")
end)

T.test("keeper-as-shot: a losing shot is a save — no card destroyed, no LP lost", function()
    local m, keeper, s = board(H.card("defender", 1500, 1500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "save")
    T.ok(m.players.player.pitch.strikers[1] ~= nil, "attacker survives")
    T.eq(m.players.opponent.pitch.keeper, keeper)
    T.eq(m.players.player.lp, 4000); T.eq(m.players.opponent.lp, 4000)
end)

T.test("keeper-as-shot: a midfielder card in a striker slot shoots when it advances", function()
    local m, _, s = board(H.card("midfielder", 1800, 1500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "damage"); T.eq(m.players.opponent.lp, 3800)
end)

T.test("keeper-as-shot: the midfielder slot still can't shoot the keeper", function()
    local m = H.match()
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    local r = H.store(m):declareAttack(H.slot("midfielder"), H.slot("keeper"))
    T.eq(r.outcome, "wasted"); T.eq(r.reason, "midfielder_keeper")
    T.ok(m.players.opponent.pitch.keeper ~= nil)
end)
```

- [ ] **Step 2: Write `tests/test_rules_open_goal.lua`.**

```lua
local T = require("tests.t")
local H = require("tests.helpers")

-- Player striker (ATK 2100) against an opponent with no keeper and no defenders.
local function emptyGoal()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    return m, H.store(m)
end

T.test("open goal: a striker aimed at an empty keeper slot scores its full ATK", function()
    local m, s = emptyGoal()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 2100)
    T.eq(m.players.opponent.lp, 1900)
    T.eq(m.players.player.totalDamageDealt, 2100)
end)

T.test("open goal: advancing through an empty defence into an empty keeper slot scores", function()
    local m, s = emptyGoal()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 2))
    T.eq(r.outcome, "damage"); T.eq(m.players.opponent.lp, 1900)
    local dmg = H.events(m, "lp_damage")
    T.eq(dmg[#dmg].payload.source, "open_goal")
end)

T.test("open goal: the attack-mode midfielder card bonus counts", function()
    local m, s = emptyGoal()
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.damage, 2300)
end)

T.test("open goal: still needs a gap in the defender line", function()
    local m, s = emptyGoal()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
    T.eq(m.players.opponent.lp, 4000)
end)

local function shotWith(stratId)
    local m, s = emptyGoal()
    local card = H.give(m, "player", H.def(stratId))
    local r, err = s:playStrategy(card.id)
    return m, r, err
end

T.test("open goal: Direct Free Kick at an empty keeper slot scores full ATK", function()
    local m, r = shotWith("strat-direct-free-kick")
    T.ok(r, "played"); T.eq(r.outcome, "damage"); T.eq(r.damage, 2100)
    T.eq(m.players.opponent.lp, 1900)
end)

T.test("open goal: Penalty at an empty keeper slot scores full ATK", function()
    local m, r = shotWith("strat-penalty")
    T.ok(r, "played"); T.eq(r.outcome, "damage"); T.eq(m.players.opponent.lp, 1900)
end)

T.test("open goal: the AI's VAR still overturns it", function()
    local m, s = emptyGoal()
    H.trap(m, "opponent", "trap-var")
    s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(m.players.opponent.lp, 4000)
    T.eq(#m.players.opponent.pitch.traps, 0)
    T.eq(m.players.player.pitch.strikers[1], nil)
    local hand = m.players.player.hand
    T.eq(hand[#hand].type, "striker")
end)
```

- [ ] **Step 3: Write `tests/test_rules_first_turn.lua`.**

```lua
local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

-- Player striker vs a face-up opponent defender, on the given turn / half.
local function setup(opts)
    local m = H.match(opts)
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    return m, H.store(m)
end

T.test("first turn: the half's starter cannot attack on turn 1", function()
    local m, s = setup({ turn = 1 })
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "no attacks on the first turn of a half")
    T.ok(m.players.opponent.pitch.defenders[1] ~= nil)
    T.eq(m.players.opponent.lp, 4000)
end)

T.test("first turn: no Direct Free Kick or Penalty either; the card stays in hand", function()
    for _, id in ipairs({ "strat-direct-free-kick", "strat-penalty" }) do
        local m, s = setup({ turn = 1 })
        H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
        local card = H.give(m, "player", H.def(id))
        local r, err = s:playStrategy(card.id)
        T.ok(not r, id .. " refused"); T.eq(err, "no attacks on the first turn of a half")
        T.eq(#m.players.player.hand, 1); T.eq(m.strategyPlayedThisTurn, false)
        T.eq(m.players.opponent.lp, 4000)
    end
end)

T.test("first turn: the AI's Offside is not spent on a refused attack", function()
    local m, s = setup({ turn = 1 })
    H.trap(m, "opponent", "trap-offside")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(#m.players.opponent.pitch.traps, 1)
    T.eq(m.players.player.pitch.strikers[1].exhausted, false)
end)

T.test("first turn: the second player may attack on its turn 1", function()
    local m = H.match({ turn = 1, active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
end)

T.test("first turn: Extra Time's starter is blocked on its turn 1 too", function()
    local _, s = setup({ turn = 1, half = "extra" })
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "no attacks on the first turn of a half")
end)

T.test("first turn: the AI plans no attack and no shot on its opening turn", function()
    local m = H.match({ turn = 1, active = "opponent" })
    m.halfStarter = "opponent"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))
    H.give(m, "opponent", H.def("strat-penalty"))
    T.eq(AI._planNextAttack(m, "medium"), nil)
    T.eq(AI._pickStrategy(m, "medium"), nil)
end)
```

- [ ] **Step 4: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 15 `FAIL` lines.
- **`keeper-as-shot`:** the first three tests.
- **`open goal`:** all seven tests.
- **`first turn`:** every test except "the second player may attack on its turn 1".

The run ends with `147 passed, 15 failed`.

- [ ] **Step 5: `engine/state.lua` — half starter and helpers.**

In `State.newMatch`, directly after the line `        activePlayer = "player",` add:

```lua
        halfStarter  = "player",   -- who kicks off this half (the human, every half)
```

Directly after `function State.opponentState … end` add:

```lua
-- The other seat.
function State.other(playerId)
    return playerId == "player" and "opponent" or "player"
end

-- True on the first turn of a half (Extra Time included) for the player who started it:
-- that turn has no attacks and no attacking strategies (Direct Free Kick, Penalty).
function State.isOpeningTurn(matchState)
    return matchState.turn == 1 and matchState.activePlayer == (matchState.halfStarter or "player")
end

-- dealerId deals `amount` LP damage to the other seat.
function State.dealDamage(matchState, dealerId, amount)
    local dealer = matchState.players[dealerId]
    local victim = matchState.players[State.other(dealerId)]
    victim.lp = victim.lp - amount
    dealer.totalDamageDealt = dealer.totalDamageDealt + amount
end
```

In `State._resetHalf`, replace

```lua
    matchState.activePlayer = "player"
```

with

```lua
    matchState.halfStarter  = "player"
    matchState.activePlayer = matchState.halfStarter
```

- [ ] **Step 6: `engine/combat.lua` — open-goal shots.** Replace the whole `Combat.resolveShot` function with:

```lua
-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.
-- penaltyMode = true → keeper uses base DEF only (no active defender/midfielder bonuses).
-- Returns { outcome, damage, margin, openGoal }
-- outcome: "damage" | "tie" | "save"
function Combat.resolveShot(striker, keeper, oppPitch, strikerPitch, penaltyMode)
    local atkStat = Combat.getStat(striker, "attack")
                  + Combat.midfielderCardAtkBonus(strikerPitch)
    if not keeper then
        return { outcome = "damage", damage = atkStat, margin = atkStat, openGoal = true }
    end
    local defStat = penaltyMode
        and Combat.getStat(keeper, "defend")
        or  Combat.keeperEffectiveDef(keeper, oppPitch)
    local margin  = atkStat - defStat

    local outcome, damage
    if margin > 0 then
        outcome = "damage"
        damage  = margin
    elseif margin == 0 then
        outcome = "tie"
        damage  = 0
    else
        outcome = "save"
        damage  = 0
    end

    return { outcome = outcome, damage = damage, margin = margin }
end
```

- [ ] **Step 7: `engine/phases.lua` — strategy shots.**

In `Phases.playStrategy`, insert the following directly **above** the line `    -- Commit: discard the card`:

```lua
    -- First turn of a half: the starter may not shoot either.
    if (ability == "DIRECT_FREE_KICK" or ability == "PENALTY") and State.isOpeningTurn(matchState) then
        table.insert(player.hand, cardDef)
        return false, "no attacks on the first turn of a half"
    end

```

Then replace everything from the line `    -- ── DIRECT FREE KICK ──…` down to (but not including) the line `    -- ── TIME WASTING ──…` with:

```lua
    -- ── DIRECT FREE KICK / PENALTY ─────────────────────────────────────────────
    -- The best striker shoots at the keeper (Penalty: base DEF only). An empty keeper
    -- slot is an open goal for the striker's full ATK.
    if ability == "DIRECT_FREE_KICK" or ability == "PENALTY" then
        local best, bestSlot = Phases._bestStriker(player.pitch)
        if not best then
            table.remove(player.graveyard); table.insert(player.hand, cardDef)
            matchState.strategyPlayedThisTurn = false
            return false, ability == "PENALTY" and "Need an active striker on pitch to take a penalty"
                                               or  "Need an active striker on pitch to take a free kick"
        end
        local keeper = matchState.players[opponentId].pitch.keeper
        State.log(matchState, "strategy_played", { ability = ability, player = matchState.activePlayer })
        return Phases._goalAttempt(matchState, best, keeper, bestSlot, opponentId, ability == "PENALTY")

```

(The next line in the file is still `    -- ── TIME WASTING ──…` followed by `    elseif ability == "TIME_WASTING" then`.)

- [ ] **Step 8: `engine/phases.lua` — attack, advance and shot.** Replace the whole `function Phases.attack(matchState, attackerSlot, defenderSlot) … end` with:

```lua
-- Checks an attack before any trap or cover window opens. Returns true, or false + reason.
function Phases.validateAttack(matchState, attackerSlot, defenderSlot)
    if State.isOpeningTurn(matchState) then
        return false, "no attacks on the first turn of a half"
    end
    local attacker = Phases._getSlotForPlayer(matchState, matchState.activePlayer, attackerSlot)
    if not attacker then return false, "no attacker" end
    if attacker.exhausted then return false, "attacker exhausted" end
    if attacker.cannotActNextTurn then return false, "attacker cannot act" end
    if attacker.mode ~= "attack" then return false, "card is in defense mode" end
    if defenderSlot.type == "keeper" then
        -- Direct shots need a gap in the defender line (occupied or empty keeper slot).
        local oppPitch = matchState.players[State.other(matchState.activePlayer)].pitch
        local hasGap = false
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not oppPitch.defenders[i] then hasGap = true; break end
        end
        if not hasGap then return false, "keeper protected — clear a defender first" end
    end
    return true
end

function Phases.attack(matchState, attackerSlot, defenderSlot)
    local ok, err = Phases.validateAttack(matchState, attackerSlot, defenderSlot)
    if not ok then return nil, err end

    local attacker   = Phases._getSlotForPlayer(matchState, matchState.activePlayer, attackerSlot)
    local opponentId = State.other(matchState.activePlayer)
    local defender   = Phases._getSlotForPlayer(matchState, opponentId, defenderSlot)

    State.log(matchState, T.EventType.ATTACK_DECLARED,
        { attacker = attackerSlot, defender = defenderSlot })

    -- The keeper slot (occupied or empty) is always a shot, never card-vs-card combat.
    if defenderSlot.type == "keeper" then
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    end
    if defender then
        return Phases._doCombat(matchState, attacker, defender, attackerSlot, defenderSlot, opponentId)
    end
    -- Empty slot — check if covering is available
    return Phases._handleEmpty(matchState, attacker, attackerSlot, defenderSlot, opponentId)
end

-- An attack that reached the goal. The midfielder slot can't shoot (wasted); any other
-- card shoots at the keeper, or scores an open goal when the keeper slot is empty.
function Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    if attackerSlot.type == "midfielder" then
        attacker.exhausted = true
        State.log(matchState, "attack_wasted", { reason = "midfielder_keeper" })
        return { outcome = "wasted", reason = "midfielder_keeper" }
    end
    local keeper = matchState.players[opponentId].pitch.keeper
    return Phases._goalAttempt(matchState, attacker, keeper, attackerSlot, opponentId)
end
```

Replace the whole `function Phases._advanceThrough(…) … end` with:

```lua
-- Advance through empty lines until hitting an occupied card or the goal.
function Phases._advanceThrough(matchState, attacker, attackerSlot, fromSlot, opponentId)
    local oppPitch = matchState.players[opponentId].pitch
    local nextSlot = Phases._nextOccupiedLine(oppPitch, fromSlot)

    -- Nothing left before the goal (only the keeper, or an empty keeper slot): shot.
    if not nextSlot or nextSlot.type == "keeper" then
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    end

    local target = Phases._getSlot(oppPitch, nextSlot)
    return Phases._doCombat(matchState, attacker, target, attackerSlot, nextSlot, opponentId)
end
```

In `Phases._doCombat`, replace

```lua
            local dmg = result.margin
            matchState.players[opponentId].lp = matchState.players[opponentId].lp - dmg
            matchState.players[activeId].totalDamageDealt =
                matchState.players[activeId].totalDamageDealt + dmg
```

with

```lua
            local dmg = result.margin
            State.dealDamage(matchState, activeId, dmg)
```

and replace

```lua
        matchState.players[activeId].lp = matchState.players[activeId].lp - penalty
        matchState.players[opponentId].totalDamageDealt =
            matchState.players[opponentId].totalDamageDealt + penalty
```

with

```lua
        State.dealDamage(matchState, opponentId, penalty)
```

Replace the whole `function Phases._goalAttempt(…) … end`, including the two comment lines above it, with:

```lua
-- Shot at the goal: every attack that reaches the keeper ends here (the keeper is never
-- destroyed). keeper == nil → open goal for the shooter's full ATK.
-- penaltyMode = true → keeper uses base DEF only (no active defender bonuses).
function Phases._goalAttempt(matchState, striker, keeper, attackerSlot, opponentId, penaltyMode)
    local activeId = matchState.activePlayer
    local oppPitch = matchState.players[opponentId].pitch
    local atkPitch = matchState.players[activeId].pitch
    local result   = Combat.resolveShot(striker, keeper, oppPitch, atkPitch, penaltyMode)
    result.attackerSlot = attackerSlot

    -- Reveal a face-down keeper
    if keeper and keeper.mode == "defense" then keeper.mode = "attack" end

    striker.usedAsAttacker = true
    striker.exhausted      = true

    if result.outcome == "damage" then
        if keeper then keeper.exhausted = true end
        State.dealDamage(matchState, activeId, result.damage)
        State.log(matchState, T.EventType.LP_DAMAGE,
            { dealer = activeId, damage = result.damage,
              remainingLP = matchState.players[opponentId].lp,
              source = result.openGoal and "open_goal" or nil })

    elseif result.outcome == "tie" then
        keeper.exhausted  = true
        State.log(matchState, T.EventType.SHOT, { outcome = "tie", margin = 0 })

    else  -- save
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end

    return result
end
```

- [ ] **Step 9: `store/match.lua` — validation before traps; strategy-shot snapshot.**

Replace the first two lines

```lua
local State  = require("engine.state")
local Phases = require("engine.phases")
```

with

```lua
local State  = require("engine.state")
local Phases = require("engine.phases")
local Combat = require("engine.combat")
```

In `Store:declareAttack`, directly after the line `    local opponentId = activeId == "player" and "opponent" or "player"`, insert:

```lua

    -- Illegal attacks (first turn of a half, keeper protected, exhausted …) are refused
    -- before any trap window can open.
    local okAtk, whyNot = Phases.validateAttack(match, attackerSlot, defenderSlot)
    if not okAtk then return nil, whyNot end
```

Replace the whole `function Store:playStrategy(cardId, opts) … end` with:

```lua
-- Play a strategy card from hand.
function Store:playStrategy(cardId, opts)
    local match    = self.match
    local activeId = match.activePlayer

    -- Strategy shots are snapshotted before they resolve: the best striker and the keeper
    -- as they stand now (Penalty: the keeper's base DEF).
    local shotSnap
    for _, c in ipairs(match.players[activeId].hand) do
        if c.id == cardId and (c.ability == "DIRECT_FREE_KICK" or c.ability == "PENALTY") then
            local _, bestSlot = Phases._bestStriker(match.players[activeId].pitch)
            if bestSlot then
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 })
                local keeper = match.players[State.other(activeId)].pitch.keeper
                if c.ability == "PENALTY" and keeper and shotSnap.defender then
                    shotSnap.defender.def = Combat.getStat(keeper, "defend")
                end
            end
            break
        end
    end

    local result, err = Phases.playStrategy(match, cardId, opts)
    if result then
        local o = result.outcome
        if shotSnap and (o == "damage" or o == "tie" or o == "save") then
            self:_pushCombat(shotSnap, result)
        end
        self:_checkHalf()
        self:_notify()
    end
    return result, err
end
```

- [ ] **Step 10: `ai/opponent.lua` — no attacks or shots on the AI's opening turn.**

Replace the first three lines

```lua
local Combat = require("engine.combat")
local C      = require("engine.constants")
local Phases = require("engine.phases")
```

with

```lua
local Combat = require("engine.combat")
local C      = require("engine.constants")
local Phases = require("engine.phases")
local State  = require("engine.state")
```

In `AI._planNextAttack`, directly after the line `function AI._planNextAttack(match, difficulty)`, insert:

```lua
    -- No attacks on the opening turn of a half (engine rule).
    if State.isOpeningTurn(match) then return nil end
```

In `AI._pickStrategy`, directly after the line `    local opponent = match.players.player`, insert:

```lua
    local opening  = State.isOpeningTurn(match)   -- no shots on the opening turn
```

Then replace `            if ability == "DIRECT_FREE_KICK" then` with `            if ability == "DIRECT_FREE_KICK" and not opening then`. Replace `            elseif ability == "PENALTY" then` with `            elseif ability == "PENALTY" and not opening then`.

- [ ] **Step 11: `scenes/match.lua` — hint instead of targets; flash refused attacks.**

After the line `local C             = require("engine.constants")` add:

```lua
local State         = require("engine.state")
```

In `Match.hintText`, replace

```lua
        if scoutPending then
            return "SCOUT REPORT: click an opponent face-down card to reveal  ·  ESC to cancel"
        elseif selectedAttackerSlot then
```

with

```lua
        if scoutPending then
            return "SCOUT REPORT: click an opponent face-down card to reveal  ·  ESC to cancel"
        elseif State.isOpeningTurn(match) then
            return "First turn of the half: no attacks or shots  ·  END TURN when done"
        elseif selectedAttackerSlot then
```

In `Match.getAttackTargetSlots`, directly after the line `    if match.phase ~= "attack" or not selectedAttackerSlot then return {} end`, add:

```lua
    if State.isOpeningTurn(match) then return {} end   -- first turn of the half: hint, no targets
```

In `Match.mousepressed`, replace

```lua
                store:declareAttack(
                    selectedAttackerSlot,
                    { type=slot.slotType, index=slot.slotIndex }
                )
```

with

```lua
                local _, attackErr = store:declareAttack(
                    selectedAttackerSlot,
                    { type=slot.slotType, index=slot.slotIndex }
                )
                if attackErr then Match.flash(attackErr) end
```

- [ ] **Step 12: Run the tests and syntax checks**

Run: `luac -p engine/state.lua engine/combat.lua engine/phases.lua store/match.lua ai/opponent.lua scenes/match.lua && lua tests/run.lua`
Expected: no `luac` output; `162 passed, 0 failed`.

- [ ] **Step 13: Snapshot the first-turn hint**

Run: `tools/snapshot/snap.sh summon`
Expected: it lists the 8 `summon_*.png` files, with no Lua traceback.

Read `.snapshots/summon_attack.png`. Check:
- the field card you placed has the yellow selected ring;
- **no** opponent slot glows red;
- the hint line above the hand reads `First turn of the half: no attacks or shots · END TURN when done`.

Read `summon_aiturn.png` and `summon_myturn.png`: the AI takes its turn normally, and it may attack on its own turn 1.

- [ ] **Step 14: Commit**

```bash
ls luac.out
git add engine/state.lua engine/combat.lua engine/phases.lua store/match.lua ai/opponent.lua scenes/match.lua tests/test_rules_keeper_shot.lua tests/test_rules_open_goal.lua tests/test_rules_first_turn.lua
git commit -m "Keeper attacks are shots, open goal on an empty keeper slot, no attacks on the starter's first turn" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **162**.

---

### Task 3: 14-round half limit (spec §1.1)

**Files:**
- Modify: `engine/constants.lua`, `engine/state.lua`, `engine/phases.lua`, `store/match.lua`
- Test: `tests/test_rules_half_limit.lua`

- [ ] **Step 1: Write `tests/test_rules_half_limit.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")

-- The opponent (second player) is about to end round `turn`.
local function lastTurn(turn, pLP, oLP)
    local m = H.match({ turn = turn, active = "opponent", phase = "attack" })
    m.players.player.lp, m.players.opponent.lp = pLP, oLP
    return m
end

T.test("half limit: the half ends after round 14 and the LP leader wins it", function()
    local m = lastTurn(14, 3000, 2500)
    Phases.endTurn(m)
    T.eq(m.players.player.halvesWon, 1)
    T.eq(m.half, 2)
    local ends = H.events(m, "half_end")
    T.eq(ends[1].payload.winner, "player"); T.eq(ends[1].payload.reason, "time")
end)

T.test("half limit: round 14 is still played in full", function()
    local m = lastTurn(13, 3000, 2500)
    Phases.endTurn(m)
    T.eq(m.half, 1); T.eq(m.turn, 14); T.eq(m.activePlayer, "player")
end)

T.test("half limit: level on LP, more damage dealt this half wins", function()
    local m = lastTurn(14, 3000, 3000)
    m.players.player.halfDamageDealt   = 500
    m.players.opponent.halfDamageDealt = 800
    m.players.player.totalDamageDealt  = 9000   -- earlier halves don't count
    Phases.endTurn(m)
    T.eq(m.players.opponent.halvesWon, 1)
end)

T.test("half limit: level on LP and damage, the player who went second wins", function()
    local m = lastTurn(14, 3000, 3000)
    Phases.endTurn(m)
    T.eq(m.players.opponent.halvesWon, 1, "player started, so opponent went second")
    local m2 = lastTurn(14, 3000, 3000)
    m2.halfStarter = "opponent"
    T.eq(State.decideOnTime(m2), "player")
end)

T.test("half limit: damage this half resets at half time; the match total does not", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.players.player.halfDamageDealt, 500)
    State.endHalf(m, "player")
    T.eq(m.players.player.halfDamageDealt, 0)
    T.eq(m.players.player.totalDamageDealt, 500)
end)

T.test("half limit: a goal overturned by VAR no longer counts as damage dealt", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-var")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(m.players.opponent.lp, 4000)
    T.eq(m.players.player.totalDamageDealt, 0)
    T.eq(m.players.player.halfDamageDealt, 0)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 5 `FAIL` lines, one for each `half limit` test except "round 14 is still played in full". The run ends with `163 passed, 5 failed`.

- [ ] **Step 3: `engine/constants.lua`.** Replace

```lua
    EXTRA_TIME_TURNS          = 6,
```

with

```lua
    EXTRA_TIME_TURNS          = 6,    -- Extra Time rounds
    HALF_ROUND_LIMIT          = 14,   -- rounds per half (halves 1 and 2); a round = one turn each
```

- [ ] **Step 4: `engine/state.lua`.**

In `newPlayerState`, replace

```lua
        totalDamageDealt = 0,
```

with

```lua
        totalDamageDealt = 0,
        halfDamageDealt  = 0,       -- LP damage dealt this half (half-limit / Extra Time decider)
```

Replace `State.dealDamage` (added in Task 2) with:

```lua
-- dealerId deals `amount` LP damage to the other seat.
function State.dealDamage(matchState, dealerId, amount)
    local dealer = matchState.players[dealerId]
    local victim = matchState.players[State.other(dealerId)]
    victim.lp = victim.lp - amount
    dealer.totalDamageDealt = dealer.totalDamageDealt + amount
    dealer.halfDamageDealt  = (dealer.halfDamageDealt or 0) + amount
end

-- Undo damage (VAR): the victim gets the LP back and the dealer's totals drop.
function State.refundDamage(matchState, dealerId, amount)
    local dealer = matchState.players[dealerId]
    local victim = matchState.players[State.other(dealerId)]
    victim.lp = victim.lp + amount
    dealer.totalDamageDealt = dealer.totalDamageDealt - amount
    dealer.halfDamageDealt  = (dealer.halfDamageDealt or 0) - amount
end

-- Winner of a half that ran out of rounds: more LP → more damage dealt this half →
-- the player who went second this half.
function State.decideOnTime(matchState)
    local p = matchState.players.player
    local o = matchState.players.opponent
    if p.lp ~= o.lp then return p.lp > o.lp and "player" or "opponent" end
    local pd, od = p.halfDamageDealt or 0, o.halfDamageDealt or 0
    if pd ~= od then return pd > od and "player" or "opponent" end
    return State.other(matchState.halfStarter or "player")
end
```

Replace the whole `State.checkHalfEnd` function, including its comment line, with:

```lua
-- Check if a half has ended. Returns winnerId, reason ("lp" | "time"), or nil.
--   LP:   a player at 0 LP or less loses the half.
--   Time: halves 1 and 2 end after C.MATCH.HALF_ROUND_LIMIT rounds; Extra Time after
--         C.MATCH.EXTRA_TIME_TURNS rounds (extraTurnsLeft reaches 0).
function State.checkHalfEnd(matchState)
    local p = matchState.players.player
    local o = matchState.players.opponent
    if p.lp <= 0 then return "opponent", "lp" end
    if o.lp <= 0 then return "player", "lp" end
    if matchState.half == "extra" then
        if matchState.extraTurnsLeft <= 0 then
            -- Extra Time: whoever dealt more total LP damage wins
            if p.totalDamageDealt > o.totalDamageDealt then return "player", "time"
            elseif o.totalDamageDealt > p.totalDamageDealt then return "opponent", "time"
            else return "player", "time" end  -- tiebreak: player wins
        end
        return nil
    end
    if matchState.turn > C.MATCH.HALF_ROUND_LIMIT then
        return State.decideOnTime(matchState), "time"
    end
    return nil
end
```

In `State.endHalf`, replace the first two lines

```lua
function State.endHalf(matchState, halfWinner)
    State.log(matchState, "half_end", { half = matchState.half, winner = halfWinner })
```

with

```lua
function State.endHalf(matchState, halfWinner, reason)
    State.log(matchState, "half_end", { half = matchState.half, winner = halfWinner, reason = reason or "lp" })
```

In `State._resetHalf`, replace

```lua
    for _, ps in pairs(matchState.players) do
        ps.lp                  = C.MATCH.STARTING_LP
        ps.nextTurnSummonLimit = nil
```

with

```lua
    -- Fixed order (not pairs): the redeal consumes math.random, so seeded runs repeat.
    for _, seat in ipairs({ "player", "opponent" }) do
        local ps = matchState.players[seat]
        ps.lp                  = C.MATCH.STARTING_LP
        ps.halfDamageDealt     = 0
        ps.nextTurnSummonLimit = nil
```

- [ ] **Step 5: `engine/phases.lua` — pass the reason through.** In `Phases.endTurn`, replace

```lua
    -- Check if half ended
    local halfWinner = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner)
        return
    end
```

with

```lua
    -- Check if half ended
    local halfWinner, reason = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner, reason)
        return
    end
```

and replace

```lua
    -- Check half end again after turn increment (for Extra Time countdown)
    halfWinner = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner)
    end
```

with

```lua
    -- Check half end again after the round count moved on (half limit, Extra Time countdown)
    halfWinner, reason = State.checkHalfEnd(matchState)
    if halfWinner then
        State.endHalf(matchState, halfWinner, reason)
    end
```

- [ ] **Step 6: `store/match.lua` — reason and VAR refunds.**

Replace

```lua
function Store:_checkHalf()
    local hw = State.checkHalfEnd(self.match)
    if hw and not self.match.winner then
        State.endHalf(self.match, hw)
    end
end
```

with

```lua
function Store:_checkHalf()
    local hw, reason = State.checkHalfEnd(self.match)
    if hw and not self.match.winner then
        State.endHalf(self.match, hw, reason)
    end
end
```

Replace `            match.players.opponent.lp = match.players.opponent.lp + (result.damage or 0)` with `            State.refundDamage(match, "player", result.damage or 0)`.

Replace `            match.players.player.lp = match.players.player.lp + (tw.damage or 0)` with `            State.refundDamage(match, "opponent", tw.damage or 0)`.

- [ ] **Step 7: Run the tests**

Run: `luac -p engine/constants.lua engine/state.lua engine/phases.lua store/match.lua && lua tests/run.lua`
Expected: no `luac` output; `168 passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
ls luac.out
git add engine/constants.lua engine/state.lua engine/phases.lua store/match.lua tests/test_rules_half_limit.lua
git commit -m "End a half after 14 rounds: LP, then damage this half, then the second player" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **168**.

---

### Task 4: Extra Time decider (spec §1.5)

**Files:**
- Modify: `engine/state.lua`
- Test: `tests/test_rules_extra_time.lua`

- [ ] **Step 1: Write `tests/test_rules_extra_time.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local State  = require("engine.state")
local Phases = require("engine.phases")

-- Extra Time with its 6 rounds played, 1–1 in halves.
local function et(pLP, oLP)
    local m = H.match({ half = "extra", turn = 7, active = "player", phase = "draw" })
    m.extraTurnsLeft = 0
    m.players.player.halvesWon, m.players.opponent.halvesWon = 1, 1
    m.players.player.lp, m.players.opponent.lp = pLP, oLP
    return m
end

T.test("extra time: more LP in Extra Time wins, whatever the match damage", function()
    local m = et(3000, 2000)
    m.players.opponent.totalDamageDealt = 9000
    T.eq(State.checkHalfEnd(m), "player")
end)

T.test("extra time: level LP → more damage dealt during Extra Time wins", function()
    local m = et(2500, 2500)
    m.players.player.totalDamageDealt   = 9000
    m.players.player.halfDamageDealt    = 300
    m.players.opponent.halfDamageDealt  = 700
    T.eq(State.checkHalfEnd(m), "opponent")
end)

T.test("extra time: a full tie goes to the player who went second, not the human", function()
    T.eq(State.checkHalfEnd(et(2500, 2500)), "opponent")
end)

T.test("extra time: after the 6th round the decider ends the match", function()
    local m = H.match({ half = "extra", turn = 6, active = "opponent" })
    m.extraTurnsLeft = 1
    m.players.player.halvesWon, m.players.opponent.halvesWon = 1, 1
    m.players.player.lp, m.players.opponent.lp = 1000, 1500
    Phases.endTurn(m)
    T.eq(m.winner, "opponent")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 4 `FAIL` lines (every `extra time` test); `168 passed, 4 failed`.

- [ ] **Step 3: `engine/state.lua`.** In `State.checkHalfEnd`, replace

```lua
        if matchState.extraTurnsLeft <= 0 then
            -- Extra Time: whoever dealt more total LP damage wins
            if p.totalDamageDealt > o.totalDamageDealt then return "player", "time"
            elseif o.totalDamageDealt > p.totalDamageDealt then return "opponent", "time"
            else return "player", "time" end  -- tiebreak: player wins
        end
```

with

```lua
        if matchState.extraTurnsLeft <= 0 then
            -- Extra Time LP → Extra Time damage → the player who went second
            return State.decideOnTime(matchState), "time"
        end
```

- [ ] **Step 4: Run the tests**

Run: `luac -p engine/state.lua && lua tests/run.lua`
Expected: `172 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
ls luac.out
git add engine/state.lua tests/test_rules_extra_time.lua
git commit -m "Decide Extra Time on Extra Time LP, then Extra Time damage, then the second player" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **172**.

---

### Task 5: Keeper defender bonus timing (spec §1.3)

**Files:**
- Modify: `engine/phases.lua`, `engine/state.lua`, `engine/combat.lua`
- Test: `tests/test_rules_keeper_bonus.lua`

- [ ] **Step 1: Write `tests/test_rules_keeper_bonus.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")
local Phases = require("engine.phases")

-- Player: keeper 1500 + two defenders + a midfielder. Opponent: a striker and a midfielder.
local function setup()
    local m = H.match()
    local keeper = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))
    H.place(m, "player", "defender", 1, H.card("defender", 1600, 1500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 1500))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    return m, keeper, H.store(m)
end
local function keeperDef(m, keeper) return Combat.keeperEffectiveDef(keeper, m.players.player.pitch) end

T.test("keeper bonus: a defender that attacked stops counting during the opponent's turn", function()
    local m, keeper, s = setup()
    T.eq(keeperDef(m, keeper), 1500 + 600 + 150)
    s:declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    Phases.endTurn(m)
    T.eq(m.activePlayer, "opponent")
    T.eq(keeperDef(m, keeper), 1500 + 300 + 150)
end)

T.test("keeper bonus: ...and counts again from the start of its owner's next turn", function()
    local m, keeper, s = setup()
    s:declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    Phases.endTurn(m)
    Phases.endTurn(m)
    T.eq(m.activePlayer, "player")
    T.eq(keeperDef(m, keeper), 1500 + 600 + 150)
end)

T.test("keeper bonus: same timing for the midfielder's +150", function()
    local m, keeper, s = setup()
    s:declareAttack(H.slot("midfielder"), H.slot("midfielder"))
    Phases.endTurn(m)
    T.eq(keeperDef(m, keeper), 1500 + 600)
    Phases.endTurn(m)
    T.eq(keeperDef(m, keeper), 1500 + 600 + 150)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 2 `FAIL` lines: "…counts again from the start of its owner's next turn" and "same timing for the midfielder's +150". The run ends with `173 passed, 2 failed`.

- [ ] **Step 3: `engine/phases.lua`.**

In `Phases.endTurn`, replace

```lua
        if matchState.half == "extra" then
            matchState.extraTurnsLeft = matchState.extraTurnsLeft - 1
        end
    end
```

with

```lua
        if matchState.half == "extra" then
            matchState.extraTurnsLeft = matchState.extraTurnsLeft - 1
        end
    end

    -- Keeper bonus timing: the new active player's cards that attacked count toward
    -- their keeper's effective DEF again from now on.
    Phases._clearAttackerFlags(matchState.players[matchState.activePlayer].pitch)
```

Insert directly above the line `-- ─── Slot helpers ───…`:

```lua
-- Clears the "attacked" flag on every card of a pitch (start of its owner's turn).
-- Numeric loops: a slot may be empty in front of an occupied one.
function Phases._clearAttackerFlags(pitch)
    local function clear(c) if c then c.usedAsAttacker = false end end
    clear(pitch.keeper)
    clear(pitch.midfielder)
    for i = 1, C.PITCH.MAX_DEFENDERS do clear(pitch.defenders[i]) end
    for i = 1, C.PITCH.MAX_STRIKERS  do clear(pitch.strikers[i])  end
end

```

- [ ] **Step 4: Update the comments.**

In `engine/state.lua`, replace

```lua
        usedAsAttacker    = false,              -- set true permanently after card initiates an attack
```

with

```lua
        usedAsAttacker    = false,              -- set when it attacks; cleared at the start of its owner's turn
```

In `engine/combat.lua`, replace

```lua
-- Active = card exists and has not been used as an attacker this turn.
```

with

```lua
-- Active = card exists and has not attacked since the start of its owner's latest turn.
```

- [ ] **Step 5: Run the tests**

Run: `luac -p engine/phases.lua engine/state.lua engine/combat.lua && lua tests/run.lua`
Expected: `175 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
ls luac.out
git add engine/phases.lua engine/state.lua engine/combat.lua tests/test_rules_keeper_bonus.lua
git commit -m "Attacking defenders and midfielders rejoin the keeper bonus at their owner's next turn" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **175**.

---

### Task 6: Revealed cards stay in defense (spec §1.4), engine and UI

**Files:**
- Modify: `engine/state.lua`, `engine/phases.lua`, `engine/cards/definitions/strategies.lua`, `store/match.lua`, `ai/opponent.lua`, `ui/card.lua`, `ui/pitch.lua`, `ui/match/hover.lua`, `ui/match/stats.lua`, `ui/match/zoom.lua`, `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_rules_revealed.lua`, `tests/test_revealed_ui.lua`

- [ ] **Step 1: Write `tests/test_rules_revealed.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")
local AI     = require("ai.opponent")

T.test("revealed: a face-down defender that survives is revealed but stays in defense", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(d.mode, "defense"); T.eq(d.revealed, true)
    T.eq(m.players.opponent.pitch.defenders[1], d)
end)

T.test("revealed: it still gives up no battle damage when it later loses", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    H.place(m, "player", "striker", 2, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))    -- bounces off, reveals it
    local lp = m.players.opponent.lp
    local r = s:declareAttack(H.slot("striker", 2), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(m.players.opponent.lp, lp)
end)

T.test("revealed: a defense-mode midfielder keeps its +200 DEF bonus and DEF midfield power", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1700), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("midfielder"))
    local pitch = m.players.opponent.pitch
    T.eq(pitch.midfielder.revealed, true)
    T.eq(Combat.midfielderCardDefBonus(pitch), 200)
    T.eq(Combat.midfielderPower(pitch), 1700)
end)

T.test("revealed: a face-down keeper stays in defense after a shot", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600), "defense")
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(k.mode, "defense"); T.eq(k.revealed, true)
end)

T.test("revealed: Scout Report reveals its target for good", function()
    local m = H.match()
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    local card = H.give(m, "player", H.def("strat-scout-report"))
    local r = H.store(m):playStrategy(card.id,
        { targetSlot = { owner = "opponent", type = "defender", index = 1 } })
    T.eq(r.revealedCard, d); T.eq(d.revealed, true); T.eq(d.mode, "defense")
end)

T.test("revealed: its owner may still flip it to attack", function()
    local m = H.match({ phase = "summon" })
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local ok = H.store(m):changeMode("defender", 1)
    T.eq(ok, true); T.eq(d.mode, "attack")
end)

T.test("revealed: the combat snapshot shows it face-up", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local snap = H.store(m):_snapshotAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(snap.defender.wasHidden, false)
end)

T.test("revealed: the AI reads a revealed card's DEF instead of guessing", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 1800, 500))
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 2000), "defense")
    d.revealed = true
    local atk = AI._planNextAttack(m, "medium")
    T.eq(atk.defenderSlot.type, "defender"); T.eq(atk.defenderSlot.index, 2)
end)
```

- [ ] **Step 2: Write `tests/test_revealed_ui.lua`.**

```lua
local T     = require("tests.t")
local Card  = require("ui.card")
local Hover = require("ui.match.hover")
local Stats = require("ui.match.stats")
local Zoom  = require("ui.match.zoom")

local function pc(ctype, mode, revealed, slotType)
    return { definition = { type = ctype, stats = { atk = 1500, def = 1700 } }, mode = mode,
             revealed = revealed, slotType = slotType or ctype }
end

T.test("revealed UI: a revealed defense card shows its face; face-down cards and traps don't", function()
    T.eq(Card.showsFace(pc("defender", "attack")), true)
    T.eq(Card.showsFace(pc("defender", "defense")), false)
    T.eq(Card.showsFace(pc("defender", "defense", true)), true)
    T.eq(Card.showsFace(pc("trap", "defense", false, "trap")), false)
end)

T.test("revealed UI: the opponent's revealed cards are zoomable; hidden ones and traps are not", function()
    T.eq(Hover.zoomable("opponent", "defender", pc("defender", "defense", true)), true)
    T.eq(Hover.zoomable("opponent", "defender", pc("defender", "defense")), false)
    T.eq(Hover.zoomable("opponent", "trap", pc("trap", "defense", false, "trap")), false)
    T.eq(Hover.zoomable("player", "defender", pc("defender", "defense")), true)
    T.eq(Hover.zoomable("player", "trap", pc("trap", "defense", false, "trap")), true)
    T.eq(Hover.zoomable("opponent", "striker", nil), false)
end)

T.test("revealed UI: the crown uses the opponent's revealed defense-mode midfielder", function()
    local m = { players = {
        player   = { pitch = { midfielder = pc("midfielder", "attack"), defenders = {}, strikers = {}, traps = {} } },
        opponent = { pitch = { midfielder = pc("midfielder", "defense", true), defenders = {}, strikers = {}, traps = {} } },
    } }
    T.eq(Stats.crownOwner(m), "opponent")   -- 1700 DEF vs 1500 ATK
end)

T.test("revealed UI: the zoom says the card is revealed", function()
    local c = pc("defender", "defense", true)
    local lines = Zoom.statusLines(c.definition, c, { defenders = {}, strikers = {} })
    local found = false
    for _, l in ipairs(lines) do if l.text == "Mode: DEFENSE (revealed)" then found = true end end
    T.ok(found)
end)
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 11 `FAIL` lines.
- **`revealed:` tests:** every one except "its owner may still flip it to attack".
- **`revealed UI:` tests:** all four.

The run ends with `176 passed, 11 failed`.

- [ ] **Step 4: Engine: reveal instead of flipping.**

In `engine/state.lua` `State.newPitchedCard`, directly after the `usedAsAttacker` line add:

```lua
        revealed          = false,              -- face-down card seen by both players; still in defense mode
```

In `engine/phases.lua` `Phases._doCombat`, replace

```lua
    -- Reveal face-down cards after resolution
    if attacker.mode == "defense" then attacker.mode = "attack" end
    if defender.mode == "defense" then defender.mode = "attack" end
```

with

```lua
    -- A face-down defender is revealed but stays in defense mode (no battle damage,
    -- defense bonuses kept). Attackers are always in attack mode.
    if defender.mode == "defense" then defender.revealed = true end
```

In `Phases.resolveCover`, replace

```lua
        -- Reveal if face-down
        if coverer.mode == "defense" then
            coverer.mode = "attack"  -- revealed by covering
        end
```

with

```lua
        -- Coverers are attack-mode cards; mark defensively in case that ever changes
        if coverer.mode == "defense" then coverer.revealed = true end
```

In `Phases._goalAttempt`, replace

```lua
    -- Reveal a face-down keeper
    if keeper and keeper.mode == "defense" then keeper.mode = "attack" end
```

with

```lua
    -- A face-down keeper is revealed (it stays in defense mode)
    if keeper and keeper.mode == "defense" then keeper.revealed = true end
```

In the `SCOUT_REPORT` branch of `Phases.playStrategy`, replace

```lua
            revealedCard = Phases._getSlot(tPitch, opts.targetSlot)
```

with

```lua
            revealedCard = Phases._getSlot(tPitch, opts.targetSlot)
            -- Scouted face-down cards stay revealed (face-up, still in defense mode).
            if revealedCard and revealedCard.mode == "defense" then revealedCard.revealed = true end
```

In `engine/cards/definitions/strategies.lua`, replace the Scout Report `abilityText` line with:

```lua
        abilityText = "Reveal one opponent face-down card. It stays revealed — face-up for both players but still in defense mode. No combat or activations triggered.",
```

- [ ] **Step 5: Store snapshot and AI.**

In `store/match.lua` `_snapshotAttack`, replace `            wasHidden = (card.mode == "defense"),` with

```lua
            wasHidden = (card.mode == "defense" and not card.revealed),
```

In `ai/opponent.lua` `evalFight`, replace `    if defCard.mode == "defense" then return "facedown" end` with

```lua
    if defCard.mode == "defense" and not defCard.revealed then return "facedown" end
```

and in `AI._pickTarget` replace

```lua
            local def = d.mode ~= "defense" and Combat.getStat(d, "defend") or 0
```

with

```lua
            local def = (d.mode ~= "defense" or d.revealed) and Combat.getStat(d, "defend") or 0
```

- [ ] **Step 6: UI pure rules.**

In `ui/card.lua`:
- Replace the header line `--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, canFlip, pitch, selected, target` with the two lines

```lua
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, canFlip, pitch, selected, target
--   Card.showsFace(pitched)                 face-up? (attack mode or revealed; never traps) — pure
```

- Replace the whole `function Card.drawPitched(pitched, x, y, opts) … end` with:

```lua
-- True when a pitched card is drawn face-up: attack mode, or a revealed defense-mode
-- card (seen by both players). Traps and unrevealed face-down cards show their back.
-- Pure (unit-tested).
function Card.showsFace(pitched)
    if pitched.slotType == "trap" then return false end
    return pitched.mode ~= "defense" or pitched.revealed == true
end

function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h

    if not Card.showsFace(pitched) then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and (pitched.slotType == "trap" and "TRAP" or "DEF") or nil,
            canFlip = opts.canFlip,
            selected = opts.selected, target = opts.target,
        })
        return
    end

    local atkBonus, defBonus = Card.bonuses(pitched, opts.pitch)

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })

    -- Revealed defense-mode card: face-up for both players, with a DEF marker.
    if pitched.mode == "defense" then
        local L  = Card.layout(w, h)
        local ph = math.max(10, 16 * L.s)
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + h * 0.12, pw, ph, "DEF", {
            fill = Theme.grad.def, textColor = Theme.white,
            border = math.max(1, math.floor(2 * L.s)), shadow = 0,
        })
        if opts.canFlip then
            local rh = math.max(12, 20 * L.s)
            Draw.ribbon(x + w / 2, y + h * 0.40, w * 0.9, rh, "FLIP UP", {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    end
end
```

In `ui/pitch.lua` `drawOccupied`, replace

```lua
        faceDown = (owner == "opponent") and (slotType == "trap" or pitched.mode == "defense"),
```

with

```lua
        faceDown = (owner == "opponent") and not Card.showsFace(pitched),
```

In `ui/match/hover.lua`, insert directly above `return Hover`:

```lua
-- Whether a pitched card may be zoomed. The opponent's traps and unrevealed face-down
-- cards are hidden information; everything else (revealed cards included) is not.
-- Pure (unit-tested).
function Hover.zoomable(owner, slotType, card)
    if not card then return false end
    if owner ~= "opponent" then return true end
    if slotType == "trap" then return false end
    return card.mode ~= "defense" or card.revealed == true
end

```

In `ui/match/stats.lua` `Stats.crownOwner`, replace

```lua
    if oMid and oMid.definition.type == "midfielder" and oMid.mode == "defense" then
```

with

```lua
    if oMid and oMid.definition.type == "midfielder" and oMid.mode == "defense" and not oMid.revealed then
```

and replace the comment line `-- its power (and thus the crown) is unknown. The player's own face-down card still` with `-- its power (and thus the crown) is unknown unless it was revealed. The player's own face-down card still`.

In `ui/match/zoom.lua` `Zoom.statusLines`, replace

```lua
    add(pitched.mode == "defense" and "Mode: DEFENSE (face-down)" or "Mode: ATTACK", "ink")
```

with

```lua
    local modeText = "Mode: ATTACK"
    if pitched.mode == "defense" then
        modeText = pitched.revealed and "Mode: DEFENSE (revealed)" or "Mode: DEFENSE (face-down)"
    end
    add(modeText, "ink")
```

- [ ] **Step 7: `scenes/match.lua` — zoom rule and scout targets.**

In `Match.hoverTarget`, replace

```lua
-- Opponent face-down cards and traps are never zoomable (hidden information).
```

with

```lua
-- The opponent's traps and unrevealed face-down cards are never zoomable (hidden information).
```

and replace

```lua
            if card and not (s.owner == "opponent" and card.mode == "defense") then
```

with

```lua
            if Hover.zoomable(s.owner, s.slotType, card) then
```

In `Match.getHighlightedSlots`, replace the whole `if scoutPending then … end` block inside the strategy branch (from `        if scoutPending then` down to and including its `            return slots` and closing `        end`) with:

```lua
        if scoutPending then
            local oppPitch = match.players.opponent.pitch
            -- Scout targets: the opponent's face-down cards that are not revealed yet.
            local function hidden(c) return c and c.mode == "defense" and not c.revealed end
            if hidden(oppPitch.keeper) then
                table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
            end
            if hidden(oppPitch.midfielder) then
                table.insert(slots, { slotType="midfielder", slotIndex=0, owner="opponent" })
            end
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if hidden(oppPitch.defenders[i]) then
                    table.insert(slots, { slotType="defender", slotIndex=i, owner="opponent" })
                end
            end
            for i = 1, C.PITCH.MAX_STRIKERS do
                if hidden(oppPitch.strikers[i]) then
                    table.insert(slots, { slotType="striker", slotIndex=i, owner="opponent" })
                end
            end
            return slots
        end
```

In `Match.mousepressed` (Scout Report click), replace

```lua
                if oppCard and oppCard.mode == "defense" then
```

with

```lua
                if oppCard and oppCard.mode == "defense" and not oppCard.revealed then
```

- [ ] **Step 8: Snapshot scenario.** In `tools/snapshot/scenarios.lua`, insert directly above the final `return S`:

```lua
-- Revealed cards (harness-only board): revealed defense cards are face-up with a DEF marker
-- for both sides; the opponent's unrevealed face-down card and trap stay hidden; the
-- opponent's revealed card zooms, the hidden one doesn't; the crown reads the revealed MID.
S.revealed = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        local P, O = st.match.players.player.pitch, st.match.players.opponent.pitch
        local function revealed(id, slotType)
            local c = pitched(id, slotType, "defense")
            c.revealed = true
            return c
        end
        P.defenders[1] = revealed("def-the-rock", "defender")
        P.defenders[2] = pitched("def-stopper", "defender", "defense")
        P.midfielder   = pitched("mid-box-to-box", "midfielder", "defense")
        O.defenders[1] = revealed("def-destroyer", "defender")
        O.defenders[2] = pitched("def-libero", "defender", "defense")
        O.midfielder   = revealed("mid-deep-lying-playmaker", "midfielder")
        O.keeper       = revealed("keeper-iron-fists", "keeper")
        O.traps[1]     = pitched("trap-offside", "trap", "defense")
    end },
    { 1.9, function(c) c.snap("board") end },
    { 2.0, function() move(center(Layout.slot("opponent", "defender", 1))) end },
    { 2.6, function(c) c.snap("zoom") end },
    { 2.7, function() move(center(Layout.slot("opponent", "defender", 2))) end },
    { 3.3, function(c) c.snap("hidden") end },
    { 3.5, function(c) c.quit() end },
}

```

- [ ] **Step 9: Run the tests and syntax checks**

Run: `luac -p engine/state.lua engine/phases.lua engine/cards/definitions/strategies.lua store/match.lua ai/opponent.lua ui/card.lua ui/pitch.lua ui/match/hover.lua ui/match/stats.lua ui/match/zoom.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `187 passed, 0 failed`.

- [ ] **Step 10: Snapshots**

Run: `tools/snapshot/snap.sh revealed && tools/snapshot/snap.sh scout && tools/snapshot/snap.sh combat`
Expected: `revealed_board.png`, `revealed_hidden.png` and `revealed_zoom.png` are listed, along with the `scout_*` and `combat_*` PNGs. No traceback.

Read the PNGs and check:
- **`revealed_board.png`, your side:**
  - Your DEF 1 (The Rock) shows its **face** with a blue `DEF` pill near the top and a `FLIP UP` ribbon.
  - Your DEF 2 and your MID are card backs with the `DEF` label and `FLIP UP`.
- **`revealed_board.png`, opponent's side:**
  - DEF 1 (The Destroyer), MID (Deep-Lying Playmaker) and GK (Iron Fists) show their faces with a `DEF` pill and no `FLIP UP`.
  - The opponent's DEF 2 is a plain card back with **no** label.
  - The opponent's trap slot shows a card back.
- **`revealed_board.png`, crown:** the ★ crown sits above the **opponent's** midfielder (1700 DEF vs your 1500 DEF).
- **`revealed_zoom.png`:** a zoom of The Destroyer, whose info sticker includes the line `Mode: DEFENSE (revealed)`.
- **`revealed_hidden.png`:** no zoom card is shown.
- **`scout_*` and `combat_*`:** they still match their Plan C checklists.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add engine/state.lua engine/phases.lua engine/cards/definitions/strategies.lua store/match.lua ai/opponent.lua ui/card.lua ui/pitch.lua ui/match/hover.lua ui/match/stats.lua ui/match/zoom.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_rules_revealed.lua tests/test_revealed_ui.lua
git commit -m "Revealed face-down cards stay in defense and are shown face-up to both players" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **187**.

---

### Task 7: Midfield control draws a card (spec §1.7), engine, UI and tests

**Files:**
- Modify: `engine/constants.lua`, `engine/phases.lua`, `ui/match/stats.lua`, `ui/match/bottombar.lua`, `ui/match/toasts.lua`, `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_rules_midfield.lua` (new); `tests/test_match_stats.lua` and `tests/test_toasts.lua`. These two encoded the old "+1 summon" behaviour and are updated here.

- [ ] **Step 1: Write `tests/test_rules_midfield.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- Start of turn 3 (draw phase). Midfielders given as { mode, atk, def } or nil.
local function setup(pMid, oMid, active)
    local m = H.match({ turn = 3, phase = "draw", active = active or "player" })
    if pMid then H.place(m, "player", "midfielder", 0, H.card("midfielder", pMid[2], pMid[3]), pMid[1]) end
    if oMid then H.place(m, "opponent", "midfielder", 0, H.card("midfielder", oMid[2], oMid[3]), oMid[1]) end
    return m, H.store(m)
end

T.test("midfield: the stronger midfielder draws 1 extra card after the normal draw", function()
    local m, s = setup({ "attack", 1800, 1500 }, { "attack", 1500, 1500 })
    s:drawPhase()
    T.eq(#m.players.player.hand, 2); T.eq(#m.players.player.deck, 8)
    local kinds = {}
    for _, e in ipairs(m.log) do
        if e.type == "card_drawn" or e.type == "midfield_control" then kinds[#kinds + 1] = e.type end
    end
    T.eq(table.concat(kinds, ","), "card_drawn,midfield_control,card_drawn")
    local mc = H.events(m, "midfield_control")[1].payload
    T.eq(mc.player, "player"); T.eq(mc.bonus, "draw"); T.eq(mc.myPow, 1800); T.eq(mc.oppPow, 1500)
end)

T.test("midfield: control no longer raises the summon limit", function()
    local m = H.match({ turn = 2, active = "opponent" })
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    Phases.endTurn(m)
    T.eq(m.players.player.nextTurnSummonLimit, nil)
end)

T.test("midfield: a face-down midfielder counts with its DEF", function()
    local m, s = setup({ "attack", 1800, 1500 }, { "defense", 1500, 1900 })
    s:drawPhase()
    T.eq(#m.players.player.hand, 1, "no extra card: 1900 DEF beats 1800 ATK")
    local m2, s2 = setup({ "attack", 1800, 1500 }, { "defense", 1500, 1900 }, "opponent")
    s2:drawPhase()
    T.eq(#m2.players.opponent.hand, 2, "the face-down side controls midfield")
end)

T.test("midfield: equal power or no midfielder gives no extra card", function()
    local m, s = setup({ "attack", 1500, 1500 }, { "attack", 1500, 1500 })
    s:drawPhase(); T.eq(#m.players.player.hand, 1)
    local m2, s2 = setup(nil, nil)
    s2:drawPhase(); T.eq(#m2.players.player.hand, 1)
    T.eq(#H.events(m2, "midfield_control"), 0)
end)

T.test("midfield: an empty deck just skips the extra card", function()
    local m, s = setup({ "attack", 1800, 1500 }, nil)
    m.players.player.deck = {}
    s:drawPhase()
    T.eq(#m.players.player.hand, 0)
    T.eq(#H.events(m, "midfield_control"), 1)
    T.eq(m.phase, "summon")
end)
```

- [ ] **Step 2: Update the two tests that encode the old rule.**

In `tests/test_match_stats.lua`, replace the whole last test (`T.test("summons reads the player's limit and flags the midfield bonus", … end)`) with:

```lua
T.test("summons reads the player's limit (Time Wasting) and has no midfield bonus", function()
    local m = match(nil, nil)
    m.summonCount = 1
    m.players.player.nextTurnSummonLimit = 1
    local used, max, extra = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 1); T.eq(extra, nil)
    m.players.player.nextTurnSummonLimit = nil
    used, max = Stats.summons(m)
    T.eq(used, 1); T.eq(max, 2)
end)
```

In `tests/test_toasts.lua`, test "traps, midfield control and summons", replace

```lua
    _, kind = Toasts.describe({ type = "midfield_control", payload = { player = "opponent" } })
    T.eq(kind, "bad")
```

with

```lua
    _, kind = Toasts.describe({ type = "midfield_control", payload = { player = "opponent" } })
    T.eq(kind, "bad")
    local mtxt, mkind = Toasts.describe({ type = "midfield_control", payload = { player = "player", bonus = "draw" } })
    T.eq(mtxt, "You control midfield +1 card"); T.eq(mkind, "good")
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 6 `FAIL` lines:
- the four `midfield:` tests other than "equal power or no midfielder gives no extra card";
- "summons reads the player's limit (Time Wasting) and has no midfield bonus";
- "traps, midfield control and summons".

The run ends with `186 passed, 6 failed`.

- [ ] **Step 4: `engine/constants.lua`.** Replace

```lua
    MIDFIELD_CONTROL_BONUS    = 1,   -- extra summons awarded for controlling midfield
```

with

```lua
    MIDFIELD_CONTROL_DRAW     = 1,    -- extra cards drawn at turn start by the player controlling midfield
```

- [ ] **Step 5: `engine/phases.lua`.**

Replace the whole `function Phases.draw(matchState) … end` with:

```lua
function Phases.draw(matchState)
    local id = matchState.activePlayer
    -- No normal draw on turn 1 of halves 1 and 2 (Extra Time draws on turn 1).
    if not (matchState.turn == 1 and matchState.half ~= "extra") then
        local card = State.drawCard(matchState, id)
        if card then
            State.log(matchState, T.EventType.CARD_DRAWN, { player = id, card = card.id })
        end
    end
    Phases._midfieldControl(matchState)
end

-- Midfield control: a player whose midfielder-type card has more power than the
-- opponent's (ATK in attack mode, DEF in defense mode; face-down cards count) draws
-- C.MATCH.MIDFIELD_CONTROL_DRAW extra card(s) after the normal draw.
function Phases._midfieldControl(matchState)
    local id     = matchState.activePlayer
    local myPow  = Combat.midfielderPower(matchState.players[id].pitch)
    local oppPow = Combat.midfielderPower(matchState.players[State.other(id)].pitch)
    if myPow <= oppPow then return end
    State.log(matchState, T.EventType.MIDFIELD_CONTROL,
        { player = id, myPow = myPow, oppPow = oppPow, bonus = "draw" })
    for _ = 1, C.MATCH.MIDFIELD_CONTROL_DRAW do
        local card = State.drawCard(matchState, id)
        if card then
            State.log(matchState, T.EventType.CARD_DRAWN,
                { player = id, card = card.id, source = "midfield_control" })
        end
    end
end
```

In `Phases.endTurn`, delete this whole block, from the comment down to the `end` of the `if myPow > oppPow then` block:

```lua
    -- Midfield control: award extra summon to new active player if their midfielder
    -- outpowers the opponent's. Only actual midfielder-type cards count (Option B).
    local newId  = matchState.activePlayer
    local oppId  = newId == "player" and "opponent" or "player"
    local myPow  = Combat.midfielderPower(matchState.players[newId].pitch)
    local oppPow = Combat.midfielderPower(matchState.players[oppId].pitch)
    if myPow > oppPow then
        local base = matchState.players[newId].nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
        matchState.players[newId].nextTurnSummonLimit = base + C.MATCH.MIDFIELD_CONTROL_BONUS
        State.log(matchState, T.EventType.MIDFIELD_CONTROL, {
            player = newId,
            myPow  = myPow,
            oppPow = oppPow,
        })
    end

```

- [ ] **Step 6: UI.**

In `ui/match/stats.lua`, replace the whole `Stats.summons` function and its comment with:

```lua
-- used, max — "SUMMONS used / max". max is 2, or 1 under the opponent's Time Wasting.
-- Midfield control gives a card, not a summon, so there is no bonus flag.
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    return used, max
end
```

In `ui/match/bottombar.lua`, replace the whole `local function drawSummons(match) … end` with:

```lua
local function drawSummons(match)
    local r = Layout.bottom.summons
    local used, max = Stats.summons(match)
    Draw.pill(r.x, r.y, r.w, r.h, "SUMMONS " .. used .. " / " .. max, {
        fill = Theme.white, textColor = Theme.inkText, size = 18,
    })
end
```

In `ui/match/toasts.lua`, replace

```lua
        return (mine and "You control" or "Opp controls") .. " midfield +1 summon", mine and "good" or "bad"
```

with

```lua
        return (mine and "You control" or "Opp controls") .. " midfield +1 card", mine and "good" or "bad"
```

In `scenes/match.lua`, replace `            Match.flash("MIDFIELD CONTROL +1 SUMMON", "good")` with `            Match.flash("MIDFIELD CONTROL +1 CARD", "good")`.

- [ ] **Step 7: Snapshots.**

In `tools/snapshot/scenarios.lua` (`S.juice`), replace `    { 3.0,  function() require("scenes.match").flash("MIDFIELD CONTROL +1 SUMMON", "good") end },` with

```lua
    { 3.0,  function() require("scenes.match").flash("MIDFIELD CONTROL +1 CARD", "good") end },
```

Insert directly above the final `return S`:

```lua
-- Midfield control through the real engine (harness-only board): your Box-to-Box (ATK 1800)
-- outpowers their Deep-Lying Playmaker (ATK 1500); re-running your draw phase on turn 2
-- draws the normal card plus the midfield card, with the banner and the toast.
S.midfield = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local m = store().match
        m.players.player.pitch.midfielder   = pitched("mid-box-to-box", "midfielder")
        m.players.opponent.pitch.midfielder = pitched("mid-deep-lying-playmaker", "midfielder")
        m.turn  = 2
        m.phase = "draw"      -- scenes/match.lua runs store:drawPhase() on the next update
    end },
    { 1.9, function(c) c.snap("banner") end },
    { 2.6, function(c) c.snap("toast") end },
    { 2.8, function(c) c.quit() end },
}

```

- [ ] **Step 8: Run the tests, syntax checks and a leftover check**

Run: `luac -p engine/constants.lua engine/phases.lua ui/match/stats.lua ui/match/bottombar.lua ui/match/toasts.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `192 passed, 0 failed`.

Run: `grep -rni 'MIDFIELD_CONTROL_BONUS\|+1 summon' --include='*.lua' .`
Expected: no output.

- [ ] **Step 9: Snapshots**

Run: `tools/snapshot/snap.sh midfield && tools/snapshot/snap.sh juice`
Expected: `midfield_banner.png`, `midfield_toast.png` and the 6 `juice_*.png` files are listed. No traceback.

Read and check:
- **`midfield_banner.png`:**
  - A green ribbon banner reads `MIDFIELD CONTROL +1 CARD`.
  - The ★ crown sits above **your** midfielder (Box-to-Box).
- **`midfield_toast.png`:**
  - The toast stack shows `You control midfield +1 card`.
  - The SUMMONS pill reads `SUMMONS 0 / 2` on white, with **no** star.
  - The hand holds 7 cards (5 at kick-off, plus the normal draw and the midfield draw).
- **`juice_banner.png`:** reads `MIDFIELD CONTROL +1 CARD`.

- [ ] **Step 10: Commit**

```bash
ls luac.out
git add engine/constants.lua engine/phases.lua ui/match/stats.lua ui/match/bottombar.lua ui/match/toasts.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_rules_midfield.lua tests/test_match_stats.lua tests/test_toasts.lua
git commit -m "Midfield control draws an extra card instead of giving a summon" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **192**.

---

### Task 8: Store trap bug fixes (spec §3.1–3.3)

**Files:**
- Rewrite: `store/match.lua`
- Test: `tests/test_store_traps.lua`

- [ ] **Step 1: Write `tests/test_store_traps.lua`.**

```lua
local T = require("tests.t")
local H = require("tests.helpers")

T.test("bug fix: the AI's Red Card does not fire on a tie", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.trap(m, "opponent", "trap-red-card")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "tie")
    T.eq(#m.players.opponent.pitch.traps, 1)
end)

T.test("bug fix: the human's Red Card window does not open on a tie", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    H.trap(m, "player", "trap-red-card")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(s.trapWindow, nil)
end)

-- Attacker: striker 2000. Defending side: keeper 1600 and an attack-mode midfielder that
-- can cover an empty defender slot.
local function coverBoard(attackerId)
    local defId = attackerId == "player" and "opponent" or "player"
    local m = H.match({ active = attackerId })
    H.place(m, attackerId, "striker", 1, H.card("striker", 2000, 500))
    H.place(m, defId, "keeper", 0, H.card("keeper", 300, 1600))
    H.place(m, defId, "midfielder", 0, H.card("midfielder", 1000, 1000))
    return m, H.store(m)
end

T.test("bug fix: after LET THROUGH, the AI's VAR overturns the goal", function()
    local m, s = coverBoard("player")
    H.trap(m, "opponent", "trap-var")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    s:resolveCover(nil)
    T.eq(m.players.opponent.lp, 4000)
    T.eq(#m.players.opponent.pitch.traps, 0)
    T.eq(m.players.player.pitch.strikers[1], nil)
end)

T.test("bug fix: after LET THROUGH, the human gets a VAR window for the AI's goal", function()
    local m, s = coverBoard("opponent")
    H.trap(m, "player", "trap-var")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    s:resolveCover(nil)
    T.ok(s.trapWindow, "window open"); T.eq(s.trapWindow.type, "post_damage")
    s:resolveTrap(1)
    T.eq(m.players.player.lp, 4000)
    T.eq(m.players.opponent.pitch.strikers[1], nil)
end)

T.test("bug fix: a cover that loses its card gives the human a Red Card window", function()
    local m, s = coverBoard("opponent")
    H.trap(m, "player", "trap-red-card")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    s:resolveCover(H.slot("midfielder"))
    T.ok(s.trapWindow, "window open"); T.eq(s.trapWindow.type, "post_destroy")
end)

T.test("bug fix: the AI's VAR also overturns a Direct Free Kick goal", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-var")
    local card = H.give(m, "player", H.def("strat-direct-free-kick"))
    local r = H.store(m):playStrategy(card.id)
    T.eq(r.outcome, "damage")
    T.eq(m.players.opponent.lp, 4000)
    T.eq(m.players.player.pitch.strikers[1], nil)
end)

T.test("bug fix: the human gets a VAR window after the AI's Penalty goal", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "player", "trap-var")
    local card = H.give(m, "opponent", H.def("strat-penalty"))
    local s = H.store(m)
    s:playStrategy(card.id)
    T.ok(s.trapWindow, "window open"); T.eq(s.trapWindow.type, "post_damage")
    T.eq(s.trapWindow.damage, 400)
end)

-- Player attacks a DEF 2000 defender with an 1800 striker (and loses).
local function ldfBoard(targetMode, otherMode)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000), targetMode)
    if otherMode then H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), otherMode) end
    H.trap(m, "player", "trap-last-defender-foul")
    return m, H.store(m)
end

T.test("bug fix: Last Defender Foul counts only face-up defenders", function()
    local _, s = ldfBoard("attack", "defense")
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.ok(s.trapWindow, "window open"); T.eq(s.trapWindow.type, "post_last_defender")
end)

T.test("bug fix: Last Defender Foul does not trigger on a tie", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2000))
    H.trap(m, "player", "trap-last-defender-foul")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(s.trapWindow, nil)
end)

T.test("bug fix: Last Defender Foul is not offered against a lone face-down defender", function()
    local _, s = ldfBoard("defense", nil)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(s.trapWindow, nil)
end)

T.test("bug fix: after the human passes Offside, the AI's goal still gets a VAR window", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "player", "trap-offside")
    H.trap(m, "player", "trap-var")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(s.trapWindow.type, "pre_attack")
    s:resolveTrap(nil)
    T.ok(s.trapWindow, "VAR window open"); T.eq(s.trapWindow.type, "post_damage")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 11 `FAIL` lines (every `bug fix:` test); `192 passed, 11 failed`.

- [ ] **Step 3: Replace `store/match.lua` with the complete file below.**
  - **Carried over from Tasks 2, 3 and 6:** validation, VAR refunds, `_checkHalf` reason and revealed snapshots.
  - **New:**
    - one post-combat trap path (`_afterCombatTraps`) used by every resolved attack or shot;
    - `_resumeAttack` for attacks that waited on a pre-attack window;
    - Red Card only on `defender_destroyed`;
    - Last Defender Foul judged on face-up defenders, not triggered by a tie.

```lua
local State  = require("engine.state")
local Phases = require("engine.phases")
local Combat = require("engine.combat")
local C      = require("engine.constants")

local Store = {}
Store.__index = Store

function Store.new()
    local s = setmetatable({}, Store)
    s.match                = nil
    s.onUpdate             = nil
    s.combatQueue          = {}
    s.trapActivationQueue  = {}
    s.coverWindow          = nil
    s.trapWindow           = nil   -- { type, attackerSlot, defenderSlot, traps, attackerSnap, defenderSnap }
    return s
end

function Store:startMatch(playerDeck, opponentDeck)
    self.match                = State.newMatch(playerDeck, opponentDeck)
    self.combatQueue          = {}
    self.trapActivationQueue  = {}
    self.coverWindow          = nil
    self.trapWindow           = nil
    self:_notify()
end

function Store:popTrapActivation()
    if #self.trapActivationQueue == 0 then return nil end
    return table.remove(self.trapActivationQueue, 1)
end

function Store:_pushTrapActivation(activatorId, trapDef, contextText)
    table.insert(self.trapActivationQueue, {
        activator   = activatorId,
        trapDef     = trapDef,
        contextText = contextText or "",
    })
end

function Store:drawPhase()
    if not self:_assertPhase("draw") then return end
    Phases.draw(self.match)
    self.match.phase = "summon"
    self:_notify()
end

function Store:summonCard(cardId, slotType, slotIndex, mode)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack")
    if ok then self:_notify() end
    return ok, err
end

-- Perform a free summon (Substitution replacement) — bypasses summon count.
function Store:freeSummon(cardId, slotType, slotIndex, mode)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.summon(self.match, cardId, slotType, slotIndex, mode or "attack", true)
    if ok then self:_notify() end
    return ok, err
end

function Store:changeMode(slotType, slotIndex)
    if not self:_assertPhase("summon") then return false, "wrong phase" end
    local ok, err = Phases.changeMode(self.match, slotType, slotIndex)
    if ok then self:_notify() end
    return ok, err
end

function Store:startAttackPhase()
    if not self:_assertPhase("summon") then return end
    self.match.phase = "attack"
    self:_notify()
end

-- Face-up for Last Defender Foul: attack mode, or revealed.
local function faceUp(card)
    return card ~= nil and (card.mode == "attack" or card.revealed == true)
end

-- True when defenderSlot holds the defending side's only face-up defender (checked on
-- the board before the attack resolves).
function Store:_isLastFaceUpDefender(defenderId, defenderSlot)
    if defenderSlot.type ~= "defender" then return false end
    local pitch = self.match.players[defenderId].pitch
    if not faceUp(pitch.defenders[defenderSlot.index]) then return false end
    local n = 0
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if faceUp(pitch.defenders[i]) then n = n + 1 end
    end
    return n == 1
end

function Store:declareAttack(attackerSlot, defenderSlot)
    if not self:_assertPhase("attack") then return nil, "wrong phase" end
    if self.match.winner then return nil, "match over" end

    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = State.other(activeId)

    -- Illegal attacks (first turn of a half, keeper protected, exhausted …) are refused
    -- before any trap window can open.
    local okAtk, whyNot = Phases.validateAttack(match, attackerSlot, defenderSlot)
    if not okAtk then return nil, whyNot end

    -- Resolve real snap target: if the declared slot is empty and no cover is possible,
    -- the attacker will advance to the next occupied line — snap that card instead.
    local snapDefSlot = defenderSlot
    do
        local oppPitch = match.players[opponentId].pitch
        local slotCard = Phases._getSlot(oppPitch, defenderSlot)
        if not slotCard and defenderSlot.type ~= "striker" then
            local coverUsed = match.coverUsed[opponentId]
            local coverers  = Phases._eligibleCoverers(oppPitch, defenderSlot)
            if coverUsed or #coverers == 0 then
                local nextSlot = Phases._nextOccupiedLine(oppPitch, defenderSlot)
                if nextSlot then snapDefSlot = nextSlot end
            end
        end
    end

    local snap = self:_snapshotAttack(attackerSlot, snapDefSlot)

    -- Last Defender Foul is judged on the board before the attack.
    local lastDefender = activeId == "player" and self:_isLastFaceUpDefender(opponentId, defenderSlot)

    -- ── Pre-attack trap check (OFFSIDE) ───────────────────────────────────────
    -- When AI attacks with striker: show player's OFFSIDE/MC window
    if activeId == "opponent" and attackerSlot.type == "striker" then
        local offsideTrap, offsideIdx = self:_findTrap(match.players.player.pitch, "OFFSIDE")
        if offsideTrap then
            local traps = { { card = offsideTrap, slotIndex = offsideIdx } }
            local mcTrap, mcIdx = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if mcTrap then table.insert(traps, { card = mcTrap, slotIndex = mcIdx }) end
            self.trapWindow = {
                type         = "pre_attack",
                attackerSlot = attackerSlot,
                defenderSlot = defenderSlot,
                traps        = traps,
                attackerSnap = snap.attacker,
                defenderSnap = snap.defender,
            }
            self:_notify()
            return { outcome = "trap_window" }, nil
        end
    end

    -- When player attacks with striker: AI OFFSIDE auto-fires (or player can counter with MC)
    if activeId == "player" and attackerSlot.type == "striker" then
        local aiOffside, aiOffsideIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
        if aiOffside then
            local mcTrap, mcIdx = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if mcTrap then
                -- Player can counter AI's OFFSIDE with MC
                self.trapWindow = {
                    type         = "counter_offside",
                    attackerSlot = attackerSlot,
                    defenderSlot = defenderSlot,
                    aiTrapCard   = aiOffside,
                    aiTrapIdx    = aiOffsideIdx,
                    traps        = { { card = mcTrap, slotIndex = mcIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_notify()
                return { outcome = "trap_window" }, nil
            else
                -- Auto-fire AI OFFSIDE
                local trapDef = Phases.activateTrap(match, "opponent", aiOffsideIdx)
                local attCard = Phases._getSlotForPlayer(match, "player", attackerSlot)
                if attCard then attCard.exhausted = true end
                local atkName = snap.attacker and snap.attacker.name or "Striker"
                self:_pushTrapActivation("opponent", trapDef or aiOffside.definition,
                    "Your " .. atkName .. " was caught offside!")
                self:_notify()
                return { outcome = "offside_cancelled" }, nil
            end
        end
    end

    local result, err = Phases.attack(match, attackerSlot, defenderSlot)
    if not result then return nil, err end

    if result.outcome == "cover_needed" then
        self.coverWindow = {
            attackerSlot     = attackerSlot,
            emptySlot        = defenderSlot,
            eligibleCoverers = result.eligibleCoverers,
            attackerSnap     = snap.attacker,
        }
        self:_notify()
        return result, nil
    end

    self:_pushCombat(snap, result)
    if self:_afterCombatTraps(snap, result, attackerSlot) then
        self:_notify()
        return result, nil
    end

    -- LAST_DEFENDER_FOUL: the player's attack on the opponent's last face-up defender
    -- was beaten (not a tie), so that defender is still standing.
    if lastDefender and result.outcome == "attacker_exhausted" then
        local ldfTrap, ldfIdx = self:_findTrap(match.players.player.pitch, "LAST_DEFENDER_FOUL")
        if ldfTrap then
            self.trapWindow = {
                type               = "post_last_defender",
                defenderSlot       = defenderSlot,
                defenderStillAlive = true,
                traps              = { { card = ldfTrap, slotIndex = ldfIdx } },
                attackerSnap       = snap.attacker,
                defenderSnap       = snap.defender,
            }
            self:_checkHalf()
            self:_notify()
            return result, nil
        end
    end

    self:_checkHalf()
    self:_notify()
    return result, nil
end

-- Red Card / VAR after any resolved attack or shot: declared attack, cover or
-- let-through, an attack resumed after a trap window, Direct Free Kick, Penalty.
-- Returns true when a trap window for the human is now open; the caller then returns
-- without _checkHalf (post_destroy / counter_red_card windows run it here, as before;
-- post_damage waits for the VAR decision).
function Store:_afterCombatTraps(snap, result, attackerSlot)
    local match    = self.match
    local activeId = match.activePlayer
    local outcome  = result and result.outcome

    if activeId == "opponent" then
        -- AI destroyed one of the player's cards (not a tie): player's RED_CARD window
        if outcome == "defender_destroyed" then
            local rcTrap, rcIdx = self:_findTrap(match.players.player.pitch, "RED_CARD")
            if rcTrap then
                self.trapWindow = {
                    type         = "post_destroy",
                    attackerSlot = attackerSlot,
                    traps        = { { card = rcTrap, slotIndex = rcIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_checkHalf()
                return true
            end
        -- AI scored: player's VAR window (_checkHalf waits for the decision)
        elseif outcome == "damage" then
            local varTrap, varIdx = self:_findTrap(match.players.player.pitch, "VAR")
            if varTrap then
                self.trapWindow = {
                    type         = "post_damage",
                    attackerSlot = attackerSlot,
                    traps        = { { card = varTrap, slotIndex = varIdx } },
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                    damage       = result.damage,
                }
                return true
            end
        end
        return false
    end

    -- Player won a fight (not a tie): AI RED_CARD; the player may counter with VAR or MC
    if outcome == "defender_destroyed" then
        local aiRedCard, aiRedIdx = self:_findTrap(match.players.opponent.pitch, "RED_CARD")
        if aiRedCard then
            local counters = {}
            local varTrap, varIdx = self:_findTrap(match.players.player.pitch, "VAR")
            local mcTrap,  mcIdx  = self:_findTrap(match.players.player.pitch, "MANAGERS_CHALLENGE")
            if varTrap then table.insert(counters, { card = varTrap, slotIndex = varIdx }) end
            if mcTrap  then table.insert(counters, { card = mcTrap,  slotIndex = mcIdx  }) end
            if #counters > 0 then
                self.trapWindow = {
                    type         = "counter_red_card",
                    attackerSlot = attackerSlot,
                    aiTrapCard   = aiRedCard,
                    aiTrapIdx    = aiRedIdx,
                    traps        = counters,
                    attackerSnap = snap.attacker,
                    defenderSnap = snap.defender,
                }
                self:_checkHalf()
                return true
            end
            -- Auto-fire AI RED_CARD
            local trapDef = Phases.activateTrap(match, "opponent", aiRedIdx)
            Phases._destroyCard(match, "player", attackerSlot.type, attackerSlot.index or 0)
            local atkName = snap.attacker and snap.attacker.name or "Attacker"
            self:_pushTrapActivation("opponent", trapDef or aiRedCard.definition,
                "Your " .. atkName .. " was sent off!")
        end
    -- Player scored: AI VAR auto-activates (LP back, the shooter returns to the player's hand)
    elseif outcome == "damage" then
        local varTrap, varIdx = self:_findTrap(match.players.opponent.pitch, "VAR")
        if varTrap then
            Phases.activateTrap(match, "opponent", varIdx)
            State.refundDamage(match, "player", result.damage or 0)
            local pitch   = match.players.player.pitch
            local shooter = Phases._getSlot(pitch, attackerSlot)
            if shooter then
                table.insert(match.players.player.hand, shooter.definition)
                Phases._setSlot(pitch, attackerSlot, nil)
            end
            local atkName = snap.attacker and snap.attacker.name or "Striker"
            self:_pushTrapActivation("opponent", varTrap.definition,
                "VAR overturns the goal! " .. atkName .. " returned to your hand.")
        end
    end
    return false
end

-- Runs an attack that was waiting on a pre-attack trap window (Offside passed, or
-- overruled by Manager's Challenge). Returns true when a cover or trap window opened.
function Store:_resumeAttack(tw)
    local snap   = { attacker = tw.attackerSnap, defender = tw.defenderSnap }
    local result = Phases.attack(self.match, tw.attackerSlot, tw.defenderSlot)
    if not result then return false end
    if result.outcome == "cover_needed" then
        self.coverWindow = {
            attackerSlot     = tw.attackerSlot,
            emptySlot        = tw.defenderSlot,
            eligibleCoverers = result.eligibleCoverers,
            attackerSnap     = tw.attackerSnap,
        }
        return true
    end
    self:_pushCombat(snap, result)
    return self:_afterCombatTraps(snap, result, tw.attackerSlot)
end

-- Called after the player decides to activate or pass a trap window.
-- trapSlotIndex = 1-based index within trapWindow.traps to activate, or nil to pass.
function Store:resolveTrap(trapSlotIndex)
    if not self.trapWindow then return end
    local tw = self.trapWindow
    self.trapWindow = nil

    local match      = self.match
    -- opponentId = the AI when it is the attacking player (pre_attack / post_destroy)
    local opponentId = match.activePlayer

    -- ── Counter windows (player is active, AI trap was about to auto-fire) ────

    if tw.type == "counter_offside" then
        local open = false
        if trapSlotIndex then
            -- Player uses MC to negate AI's OFFSIDE
            local entry   = tw.traps[trapSlotIndex]
            local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
            if not trapDef then self:_notify(); return end
            -- Consume AI's OFFSIDE trap and pay 1000 LP
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            match.players.player.lp = match.players.player.lp - 1000
            -- Attack now proceeds normally
            open = self:_resumeAttack(tw)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("player", trapDef,
                "Manager's Challenge! " .. atkName .. " onside — attack proceeds. (-1000 LP)")
        else
            -- Player passes — AI's OFFSIDE fires
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            local attCard = Phases._getSlotForPlayer(match, "player", tw.attackerSlot)
            if attCard then attCard.exhausted = true end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            self:_pushTrapActivation("opponent", tw.aiTrapCard.definition,
                "Your " .. atkName .. " was caught offside!")
        end
        if not open then self:_checkHalf() end
        self:_notify()
        return
    end

    if tw.type == "counter_red_card" then
        if trapSlotIndex then
            -- Player uses VAR or MC to negate AI's RED_CARD
            local entry   = tw.traps[trapSlotIndex]
            local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
            if not trapDef then self:_notify(); return end
            if trapDef.ability == "MANAGERS_CHALLENGE" then
                -- MC: also discard AI's RED_CARD and pay 1000 LP
                Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
                match.players.player.lp = match.players.player.lp - 1000
            end
            -- Attacker survives (already exhausted after winning, stays on pitch)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            self:_pushTrapActivation("player", trapDef,
                "Red Card overturned! " .. atkName .. " stays on the pitch.")
        else
            -- Player passes — AI's RED_CARD fires
            Phases.activateTrap(match, "opponent", tw.aiTrapIdx)
            Phases._destroyCard(match, "player", tw.attackerSlot.type, tw.attackerSlot.index or 0)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            self:_pushTrapActivation("opponent", tw.aiTrapCard.definition,
                "Your " .. atkName .. " was sent off!")
        end
        self:_checkHalf()
        self:_notify()
        return
    end

    -- ── Standard player-activated trap windows (AI is active) ─────────────────

    if trapSlotIndex then
        local entry   = tw.traps[trapSlotIndex]
        local trapDef = Phases.activateTrap(match, "player", entry.slotIndex)
        if not trapDef then self:_notify(); return end

        local ability = trapDef.ability
        local ctxText = ""

        if tw.type == "pre_attack" and ability == "OFFSIDE" then
            local attCard = Phases._getSlotForPlayer(match, opponentId, tw.attackerSlot)
            if attCard then attCard.exhausted = true end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            ctxText = atkName .. " blocked — offside!"

        elseif tw.type == "pre_attack" and ability == "MANAGERS_CHALLENGE" then
            -- MC lets the attack through + pay 1000 LP
            match.players.player.lp = match.players.player.lp - 1000
            -- Find and discard AI's OFFSIDE that was about to fire
            local aiOff, aiOffIdx = self:_findTrap(match.players.opponent.pitch, "OFFSIDE")
            if aiOff then Phases.activateTrap(match, "opponent", aiOffIdx) end
            local open = self:_resumeAttack(tw)
            self:_pushTrapActivation("player", trapDef, "Offside overruled by Manager's Challenge! (-1000 LP)")
            if not open then self:_checkHalf() end
            self:_notify()
            return

        elseif tw.type == "post_destroy" and ability == "RED_CARD" then
            Phases._destroyCard(match, opponentId, tw.attackerSlot.type, tw.attackerSlot.index or 0)
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Attacker"
            ctxText = atkName .. " sent off after winning combat"

        elseif tw.type == "post_damage" and ability == "VAR" then
            -- Undo LP damage, return the AI's shooter to its hand
            State.refundDamage(match, "opponent", tw.damage or 0)
            local oppPitch = match.players.opponent.pitch
            local shooter  = Phases._getSlot(oppPitch, tw.attackerSlot)
            if shooter then
                table.insert(match.players.opponent.hand, shooter.definition)
                Phases._setSlot(oppPitch, tw.attackerSlot, nil)
            end
            local atkName = tw.attackerSnap and tw.attackerSnap.name or "Striker"
            ctxText = "Goal overturned! " .. atkName .. " returned to opponent's hand."

        elseif tw.type == "post_last_defender" and ability == "LAST_DEFENDER_FOUL" then
            -- Destroy the last defender if it survived (attacker_exhausted case)
            if tw.defenderStillAlive then
                Phases._destroyCard(match, "opponent", tw.defenderSlot.type, tw.defenderSlot.index or 0)
            end
            -- Grant bypass covering for next striker attack this turn
            match.bypassCoverNextStrikerAttack = true
            local defName = tw.defenderSnap and tw.defenderSnap.name or "Defender"
            ctxText = defName .. " sent off! Last defender foul — next striker bypasses cover."
        end

        self:_pushTrapActivation("player", trapDef, ctxText)
    else
        -- Pass: a waiting attack goes ahead (and may open its own windows)
        if tw.type == "pre_attack" then
            local open = self:_resumeAttack(tw)
            if not open then self:_checkHalf() end
            self:_notify()
            return
        end
        -- post_destroy, post_damage, post_last_defender pass: no further action
    end

    self:_checkHalf()
    self:_notify()
end

-- Play a strategy card from hand.
function Store:playStrategy(cardId, opts)
    local match    = self.match
    local activeId = match.activePlayer

    -- Strategy shots are snapshotted before they resolve: the best striker and the keeper
    -- as they stand now (Penalty: the keeper's base DEF).
    local shotSnap
    for _, c in ipairs(match.players[activeId].hand) do
        if c.id == cardId and (c.ability == "DIRECT_FREE_KICK" or c.ability == "PENALTY") then
            local _, bestSlot = Phases._bestStriker(match.players[activeId].pitch)
            if bestSlot then
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 })
                local keeper = match.players[State.other(activeId)].pitch.keeper
                if c.ability == "PENALTY" and keeper and shotSnap.defender then
                    shotSnap.defender.def = Combat.getStat(keeper, "defend")
                end
            end
            break
        end
    end

    local result, err = Phases.playStrategy(match, cardId, opts)
    if result then
        local o = result.outcome
        if shotSnap and (o == "damage" or o == "tie" or o == "save") then
            self:_pushCombat(shotSnap, result)
            if self:_afterCombatTraps(shotSnap, result, result.attackerSlot) then
                self:_notify()
                return result, err
            end
        end
        self:_checkHalf()
        self:_notify()
    end
    return result, err
end

-- Called after the player decides to cover or let through.
function Store:resolveCover(covererSlot)
    if not self.coverWindow then return end

    local attackerSlot = self.coverWindow.attackerSlot
    local emptySlot    = self.coverWindow.emptySlot
    local match        = self.match
    local opponentId   = State.other(match.activePlayer)

    -- When the player passes (no cover), the attacker advances to the next occupied line.
    -- Snap that card instead of the empty slot so the combat overlay shows the real defender.
    local defSlotForSnap = covererSlot
    if not covererSlot then
        local nextSlot = Phases._nextOccupiedLine(match.players[opponentId].pitch, emptySlot)
        defSlotForSnap = nextSlot or emptySlot
    end
    local snap = self:_snapshotAttack(attackerSlot, defSlotForSnap)
    self.coverWindow = nil

    local result, err = Phases.resolveCover(self.match, attackerSlot, emptySlot, covererSlot)

    if result and result.outcome ~= "wasted" and result.outcome ~= "cover_needed" then
        self:_pushCombat(snap, result)
        if self:_afterCombatTraps(snap, result, attackerSlot) then
            self:_notify()
            return result, err
        end
    end

    self:_checkHalf()
    self:_notify()
    return result, err
end

function Store:endTurn()
    self.coverWindow = nil
    self.trapWindow  = nil
    Phases.endTurn(self.match)
    self:_notify()
end

function Store:popCombat()
    if #self.combatQueue == 0 then return nil end
    return table.remove(self.combatQueue, 1)
end

-- ── Private helpers ────────────────────────────────────────────────────────────

function Store:_checkHalf()
    local hw, reason = State.checkHalfEnd(self.match)
    if hw and not self.match.winner then
        State.endHalf(self.match, hw, reason)
    end
end

function Store:_pushCombat(snap, result)
    if result and result.outcome and result.outcome ~= "wasted" then
        table.insert(self.combatQueue, {
            attacker     = snap.attacker,
            defender     = snap.defender,
            outcome      = result.outcome,
            margin       = result.margin or 0,
            damage       = result.damage or 0,
            activePlayer = self.match and self.match.activePlayer or "player",
        })
    end
end

-- Returns (pitchedCard, trapSlotIndex) for the first trap in the zone matching ability, or nil.
function Store:_findTrap(pitch, ability)
    for i, trap in ipairs(pitch.traps) do
        if trap.definition.ability == ability then
            return trap, i
        end
    end
    return nil, nil
end

function Store:_snapshotAttack(attackerSlot, defenderSlot)
    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = State.other(activeId)

    local function getCard(pitch, slot)
        if not slot then return nil end
        if slot.type == "keeper"     then return pitch.keeper end
        if slot.type == "defender"   then return pitch.defenders[slot.index] end
        if slot.type == "midfielder" then return pitch.midfielder end
        if slot.type == "striker"    then return pitch.strikers[slot.index] end
        return nil
    end

    local atkCard = getCard(match.players[activeId].pitch,   attackerSlot)
    local defCard = getCard(match.players[opponentId].pitch, defenderSlot)

    local function snap(card, isKeeper, slotType)
        if not card then return nil end
        local d        = card.definition
        local oppPitch = match.players[opponentId].pitch
        local atkPitch = match.players[activeId].pitch

        local atkBonus = 0
        local defBonus = 0
        local defStat

        if isKeeper then
            defStat = Combat.keeperEffectiveDef(card, oppPitch)
        else
            defStat = Combat.getStat(card, "defend")
            if slotType == "defender" then
                defBonus = Combat.midfielderCardDefBonus(oppPitch)
                defStat  = defStat + defBonus
            end
        end

        local atkStat = Combat.getStat(card, "attack")
        if slotType == "striker" then
            atkBonus = Combat.midfielderCardAtkBonus(atkPitch)
            atkStat  = atkStat + atkBonus
        end

        return {
            name      = d.name,
            type      = d.type,
            mode      = card.mode,
            wasHidden = (card.mode == "defense" and not card.revealed),
            atk       = atkStat,
            def       = defStat,
            atkBonus  = atkBonus,
            defBonus  = defBonus,
            isKeeper  = isKeeper,
        }
    end

    local isKeeperShot = defenderSlot and defenderSlot.type == "keeper"
    return {
        attacker = snap(atkCard, false,         attackerSlot and attackerSlot.type),
        defender = snap(defCard, isKeeperShot,  defenderSlot and defenderSlot.type),
    }
end

function Store:_assertPhase(expected)
    return self.match and self.match.phase == expected
end

function Store:_notify()
    if self.onUpdate then self.onUpdate(self.match) end
end

return Store
```

- [ ] **Step 4: Run the tests**

Run: `luac -p store/match.lua && lua tests/run.lua`
Expected: `203 passed, 0 failed`

- [ ] **Step 5: The trap prompts still work.**

Run: `for s in trapwin cover trap; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: the PNGs are listed; no `FAILED` line; no traceback.

- [ ] **Step 6: Commit**

```bash
ls luac.out
git add store/match.lua tests/test_store_traps.lua
git commit -m "Fix trap checks: no Red Card or Last Defender Foul on ties, VAR/Red Card after covers and strategy shots" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **203**.

---

### Task 9: AI fixes and the stale AI plan (spec §3.4, §4)

**Files:**
- Modify: `ai/opponent.lua`, `store/match.lua`, `scenes/match.lua`
- Test: `tests/test_ai.lua`

- [ ] **Step 1: Write `tests/test_ai.lua`.**

```lua
local T     = require("tests.t")
local H     = require("tests.helpers")
local AI    = require("ai.opponent")
local State = require("engine.state")

local function used(opts)
    local u = { keeper = false, defenders = { false, false }, midfielder = false, strikers = { false, false } }
    for k, v in pairs(opts or {}) do u[k] = v end
    return u
end

T.test("AI: a midfielder never overflows into a striker slot", function()
    local mid = H.card("midfielder", 1800, 1500)
    local slot, mode = AI._pickBestSlot(mid, used({ midfielder = true }))
    T.eq(slot.slotType, "defender"); T.eq(mode, "defense")
    slot = AI._pickBestSlot(mid, used({ midfielder = true, defenders = { true, true } }))
    T.eq(slot, nil)
end)

T.test("AI: a defender never goes into a striker slot", function()
    local d = H.card("defender", 900, 1900)
    T.eq(AI._pickBestSlot(d, used({ midfielder = true, defenders = { true, true } })), nil)
end)

T.test("AI: strikers fill striker slots, then the midfielder slot", function()
    local s = H.card("striker", 2000, 500)
    local slot, mode = AI._pickBestSlot(s, used())
    T.eq(slot.slotType, "striker"); T.eq(slot.slotIndex, 1); T.eq(mode, "attack")
    slot = AI._pickBestSlot(s, used({ strikers = { true, true } }))
    T.eq(slot.slotType, "midfielder")
end)

T.test("AI: summon planning counts summons already made against the Time Wasting limit", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    m.players.opponent.nextTurnSummonLimit = 1
    m.summonCount = 1
    H.give(m, "opponent", H.card("striker", 2000, 500))
    T.eq(#AI._planSummons(m), 0)
end)

T.test("AI trap discipline: Offside is kept against a small attack", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#m.players.opponent.pitch.traps, 1)
end)

T.test("AI trap discipline: Offside fires on an attack worth 300+ LP", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(m.players.opponent.lp, 4000)
end)

T.test("AI trap discipline: Offside on an empty slot only when the AI can't cover it", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1000, 1000))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    T.eq(#m.players.opponent.pitch.traps, 1)

    local m2 = H.match()
    H.place(m2, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m2, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m2, "opponent", "trap-offside")
    local r2 = H.store(m2):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r2.outcome, "offside_cancelled")
end)

T.test("AI trap discipline: Red Card only punishes attackers with 2000+ ATK", function()
    for _, case in ipairs({ { atk = 1900, fires = false }, { atk = 2100, fires = true } }) do
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", case.atk, 500))
        H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1000))
        H.trap(m, "opponent", "trap-red-card")
        H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
        T.eq(m.players.player.pitch.strikers[1] == nil, case.fires, "ATK " .. case.atk)
    end
end)

T.test("AI: the turn plan tag changes when the half changes", function()
    local m = H.match({ turn = 5, active = "opponent" })
    local before = AI.planTag(m)
    State.endHalf(m, "opponent")
    m.activePlayer = "opponent"   -- the AI's first turn of half 2 (turn 1)
    T.ok(AI.planTag(m) ~= before)
    T.eq(AI.planTag(m), "2:1")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 7 `FAIL` lines: every test in `tests/test_ai.lua` except "strikers fill striker slots…" and "Offside fires on an attack worth 300+ LP". The run ends with `205 passed, 7 failed`.

- [ ] **Step 3: `ai/opponent.lua` — summon limit and slots.**

In `AI._planSummons`, replace

```lua
    local summonLeft = C.MATCH.MAX_SUMMONS_PER_TURN - (match.summonCount or 0)
    -- Respect TIME_WASTING limit if active
    if player.nextTurnSummonLimit then
        summonLeft = math.min(summonLeft, player.nextTurnSummonLimit)
    end
```

with

```lua
    -- Real limit (Time Wasting sets 1) minus the summons already made this turn
    local limit      = player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    local summonLeft = limit - (match.summonCount or 0)
```

Replace the whole `AI._pickBestSlot` function and its comment with:

```lua
-- Pick the slot for a field card and the mode to play it in. Defender- and
-- midfielder-type cards never go into striker slots (they would waste attacks there).
function AI._pickBestSlot(cardDef, used)
    local stats = cardDef.stats or {}
    local atk   = stats.atk or 0
    local def   = stats.def or 0
    local ctype = cardDef.type

    local function freeDefender()
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not used.defenders[i] then return { slotType = "defender", slotIndex = i } end
        end
        return nil
    end
    local function freeStriker()
        for i = 1, C.PITCH.MAX_STRIKERS do
            if not used.strikers[i] then return { slotType = "striker", slotIndex = i } end
        end
        return nil
    end
    local mid = (not used.midfielder) and { slotType = "midfielder", slotIndex = 0 } or nil

    if ctype == "striker" then
        local s = freeStriker()
        if s then return s, "attack" end
        if mid then return mid, "attack" end
        local d = freeDefender()
        if d then return d, "defense" end
    elseif ctype == "midfielder" then
        if mid then return mid, (atk >= def and "attack" or "defense") end
        local d = freeDefender()
        if d then return d, "defense" end
    elseif ctype == "defender" then
        local d = freeDefender()
        if d then return d, "defense" end
        if mid then return mid, "defense" end
    end
    return nil, nil
end
```

- [ ] **Step 4: `ai/opponent.lua` — trap policy and plan tag.** Insert directly above the final `return AI`:

```lua
-- ── Trap discipline ─────────────────────────────────────────────────────────
-- The AI's traps fire automatically in store/match.lua; these decide when.

AI.OFFSIDE_MIN_DAMAGE = 300    -- Offside only against attacks worth at least this much LP
AI.RED_CARD_MIN_ATK   = 2000   -- Red Card only against attackers at least this strong

-- LP the defending side (ownerId) would lose if this attack resolved as declared.
-- 0 when it would only cost a card or bounce off; an open goal is the full ATK.
function AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot)
    local aPitch   = match.players[State.other(ownerId)].pitch
    local dPitch   = match.players[ownerId].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if not attacker then return 0 end
    local atk = Combat.getStat(attacker, "attack")
    if attackerSlot.type == "striker" then atk = atk + Combat.midfielderCardAtkBonus(aPitch) end
    local target = Phases._getSlot(dPitch, defenderSlot)
    if defenderSlot.type == "keeper" then
        if not target then return atk end
        return math.max(0, atk - Combat.keeperEffectiveDef(target, dPitch))
    end
    if not target or target.mode == "defense" then return 0 end
    local def = Combat.getStat(target, "defend")
    if defenderSlot.type == "defender" then def = def + Combat.midfielderCardDefBonus(dPitch) end
    return math.max(0, atk - def)
end

-- Should ownerId's Offside cancel this striker attack? Yes when it would cost at least
-- OFFSIDE_MIN_DAMAGE LP, or when it goes into an empty slot the owner can't cover.
function AI.wantsOffside(match, ownerId, attackerSlot, defenderSlot)
    local dPitch = match.players[ownerId].pitch
    if defenderSlot.type ~= "striker" and not Phases._getSlot(dPitch, defenderSlot) then
        local canCover = not match.coverUsed[ownerId]
                         and #Phases._eligibleCoverers(dPitch, defenderSlot) > 0
        return not canCover
    end
    return AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot) >= AI.OFFSIDE_MIN_DAMAGE
end

-- Should the AI's Red Card punish an attacker with this (effective) ATK?
function AI.wantsRedCard(attackerAtk)
    return (attackerAtk or 0) >= AI.RED_CARD_MIN_ATK
end

-- ── Plan bookkeeping ────────────────────────────────────────────────────────

-- The turn a plan was made for. scenes/match.lua (and tools/sim) drop a plan whose tag
-- no longer matches, e.g. when the AI won the half in the middle of its turn.
function AI.planTag(match)
    return tostring(match.half) .. ":" .. tostring(match.turn)
end

```

- [ ] **Step 5: `store/match.lua` — apply the AI trap policy.**

Directly after the line `local C      = require("engine.constants")` at the top, add:

```lua
local AI     = require("ai.opponent")
```

Replace `        if aiOffside then` with

```lua
        if aiOffside and AI.wantsOffside(match, "opponent", attackerSlot, defenderSlot) then
```

Replace `        if aiRedCard then` with

```lua
        if aiRedCard and AI.wantsRedCard(snap.attacker and snap.attacker.atk or 0) then
```

- [ ] **Step 6: `scenes/match.lua` — drop a stale AI plan.**

Replace

```lua
local aiPlan        = nil
```

with

```lua
local aiPlan        = nil
local aiPlanTag     = nil   -- AI.planTag of the turn aiPlan was made for
```

In `Match.enter`, replace `    aiPlan              = nil` with

```lua
    aiPlan              = nil
    aiPlanTag           = nil
```

In `Match.update`, replace

```lua
    if match.activePlayer == "opponent" then
        if not aiPlan then
            aiPlan        = AI.planTurn()
            aiActionIndex = 1
            aiTimer       = AI_STEP_DELAY
        end
```

with

```lua
    if match.activePlayer == "opponent" then
        -- A plan left over from the previous half (the AI won it mid-turn) is dropped, so
        -- the AI draws and summons on its first turn of the new half.
        if aiPlan and aiPlanTag ~= AI.planTag(match) then aiPlan = nil end
        if not aiPlan then
            aiPlan        = AI.planTurn()
            aiPlanTag     = AI.planTag(match)
            aiActionIndex = 1
            aiTimer       = AI_STEP_DELAY
        end
```

- [ ] **Step 7: Run the tests**

Run: `luac -p ai/opponent.lua store/match.lua scenes/match.lua && lua tests/run.lua`
Expected: `212 passed, 0 failed`

- [ ] **Step 8: The AI still plays its turns.**

Run: `tools/snapshot/snap.sh summon && tools/snapshot/snap.sh match`
Expected: the PNGs are listed; no traceback. In `summon_aiturn.png` / `summon_myturn.png`, the AI has summoned cards. No AI midfielder or defender card sits in a striker slot.

- [ ] **Step 9: Commit**

```bash
ls luac.out
git add ai/opponent.lua store/match.lua scenes/match.lua tests/test_ai.lua
git commit -m "AI: keep defenders and midfielders out of striker slots, trap discipline, drop stale plans" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **212**.

---

### Task 10: Striker/keeper stats and the Tiki-Taka list (spec §2)

**Files:**
- Modify: `engine/cards/definitions/strikers.lua`, `engine/cards/definitions/keepers.lua`, `data/presetDecks.lua`
- Test: `tests/test_balance_data.lua`

- [ ] **Step 1: Write `tests/test_balance_data.lua`.**

```lua
local T     = require("tests.t")
local Decks = require("data.presetDecks")

local function byId(file)
    local t = {}
    for _, c in ipairs(require("engine.cards.definitions." .. file)) do t[c.id] = c end
    return t
end

T.test("balance: striker ATK curve", function()
    local s = byId("strikers")
    local want = {
        ["str-target-man"] = 2200, ["str-speed-demon"] = 2150, ["str-complete-forward"] = 2150,
        ["str-fox-in-the-box"] = 2150, ["str-poacher"] = 2100, ["str-pressing-forward"] = 2100,
        ["str-pacy-winger"] = 2050, ["str-clinical-finisher"] = 2300,
    }
    for id, atk in pairs(want) do T.eq(s[id].stats.atk, atk, id) end
end)

T.test("balance: keeper DEF rises with rarity", function()
    local k = byId("keepers")
    T.eq(k["keeper-reliable-hands"].stats.def, 1750)
    T.eq(k["keeper-sweeper-keeper"].stats.def, 1800)
    T.eq(k["keeper-iron-fists"].stats.def, 1900)
    T.eq(k["keeper-the-wall"].stats.def, 2000)
end)

local function count(deck)
    local n = {}
    for _, c in ipairs(deck.cards) do n[c.id] = (n[c.id] or 0) + 1 end
    return n
end

T.test("balance: Tiki-Taka swaps a Sweeper Keeper and two Deep-Lying Playmakers", function()
    local n = count(Decks.tikitaka)
    T.eq(n["keeper-sweeper-keeper"], 1); T.eq(n["keeper-iron-fists"], 1); T.eq(n["keeper-reliable-hands"], 1)
    T.eq(n["mid-deep-lying-playmaker"], 1)
    T.eq(n["str-complete-forward"], 3); T.eq(n["str-speed-demon"], 2)
end)

T.test("balance: every preset deck has 40 cards", function()
    for key, d in pairs(Decks) do T.eq(#d.cards, 40, key) end
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 3 `FAIL` lines (the striker curve, keeper DEF and Tiki-Taka tests); `213 passed, 3 failed`.

- [ ] **Step 3: `engine/cards/definitions/strikers.lua`.** Replace the whole file with:

```lua
return {
    { id="str-target-man",       name="The Target Man",      type="striker",    rarity="common",   stats={ atk=2200, def=600  }, abilityText="Powerhouse in the air. Hard to stop." },
    { id="str-poacher",          name="The Poacher",         type="striker",    rarity="common",   stats={ atk=2100, def=500  }, abilityText="Deadly in the box. Always in the right place." },
    { id="str-speed-demon",      name="Speed Demon",         type="striker",    rarity="common",   stats={ atk=2150, def=550  }, abilityText="Blistering pace. Impossible to track." },
    { id="str-clinical-finisher",name="Clinical Finisher",   type="striker",    rarity="rare",     stats={ atk=2300, def=600  }, abilityText="Ice in his veins. Never misses a clear chance." },
    { id="str-pacy-winger",      name="Pacy Winger",         type="striker",    rarity="common",   stats={ atk=2050, def=500  }, abilityText="Gets in behind. Creates havoc wide." },
    { id="str-fox-in-the-box",   name="Fox in the Box",      type="striker",    rarity="uncommon", stats={ atk=2150, def=650  }, abilityText="Reads the game. Scores the ugly ones." },
    { id="str-complete-forward", name="Complete Forward",    type="striker",    rarity="uncommon", stats={ atk=2150, def=900  }, abilityText="Holds up play. Brings others into the game." },
    { id="str-pressing-forward", name="Pressing Forward",    type="striker",    rarity="common",   stats={ atk=2100, def=700  }, abilityText="Never stops running. Presses from the front." },
}
```

- [ ] **Step 4: `engine/cards/definitions/keepers.lua`.** Replace the whole file with:

```lua
return {
    { id="keeper-the-wall",        name="The Wall",         type="keeper", rarity="legendary", stats={ atk=300, def=2000 }, abilityText="A fortress. Nothing gets past." },
    { id="keeper-iron-fists",      name="Iron Fists",       type="keeper", rarity="rare",      stats={ atk=300, def=1900 }, abilityText="Commands the box. Punches clear." },
    { id="keeper-sweeper-keeper",  name="Sweeper Keeper",   type="keeper", rarity="uncommon",  stats={ atk=400, def=1800 }, abilityText="Rushes off the line. Sweeps up danger." },
    { id="keeper-reliable-hands",  name="Reliable Hands",   type="keeper", rarity="common",    stats={ atk=300, def=1750 }, abilityText="No heroics. Just solid every week." },
}
```

- [ ] **Step 5: `data/presetDecks.lua`.** In `Decks.tikitaka`, replace the lines from `        -- Field (32)` down to `        rep(find(midfielders,"mid-pressing-monster"),      1),` with:

```lua
        -- Field (29)
        rep(find(keepers,    "keeper-sweeper-keeper"),    1),
        rep(find(keepers,    "keeper-iron-fists"),        1),
        rep(find(keepers,    "keeper-reliable-hands"),    1),
        rep(find(defenders,  "def-ball-playing"),         3),
        rep(find(defenders,  "def-the-rock"),             2),
        rep(find(defenders,  "def-libero"),               2),
        rep(find(defenders,  "def-pressing-back"),        2),
        rep(find(midfielders,"mid-creative-playmaker"),   2),
        rep(find(midfielders,"mid-deep-lying-playmaker"), 1),
        rep(find(midfielders,"mid-box-to-box"),           2),
        rep(find(strikers,   "str-poacher"),              3),
        rep(find(strikers,   "str-clinical-finisher"),    2),
        rep(find(strikers,   "str-complete-forward"),     3),
        rep(find(strikers,   "str-fox-in-the-box"),       1),
        rep(find(strikers,   "str-speed-demon"),          2),
        rep(find(midfielders,"mid-pressing-monster"),      1),
```

- [ ] **Step 6: Run the tests**

Run: `luac -p engine/cards/definitions/strikers.lua engine/cards/definitions/keepers.lua data/presetDecks.lua && lua tests/run.lua`
Expected: `216 passed, 0 failed`

- [ ] **Step 7: The card gallery shows the new numbers.**

Run: `tools/snapshot/snap.sh cards`
Expected: `cards_gallery.png` is listed. Read it: wherever the Target Man, Poacher or a keeper appears, its badges show the new values (for example Target Man ATK 2200, Iron Fists DEF 1900).

- [ ] **Step 8: Commit**

```bash
ls luac.out
git add engine/cards/definitions/strikers.lua engine/cards/definitions/keepers.lua data/presetDecks.lua tests/test_balance_data.lua
git commit -m "Compress the striker ATK curve, order keeper DEF by rarity, strengthen Tiki-Taka" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **216**.

---

### Task 11: Simulator in `tools/sim/` and the acceptance run (spec §6)

**Files:**
- Create: `tools/sim/sim.lua`

- [ ] **Step 1: Create `tools/sim/sim.lua`.**

```lua
-- Headless AI-vs-AI balance simulator (plain Lua, no LÖVE).
-- Plays seeded matches on the real engine, store and AI and prints a stats table to
-- stdout. It never writes files.
--
-- Usage, from the repo root:
--   lua tools/sim/sim.lua [n=1000] [seed=20260923] [diff=medium] [decks=a,b,c] [cap=60]
--     n      matches per ordered matchup (every deck pair in both seat orders, mirrors included)
--     seed   base seed: match i of ordered matchup k uses seed + k*100000 + i
--     diff   AI difficulty for both seats: easy | medium | hard
--     decks  comma-separated keys of data/presetDecks.lua (default: all three)
--     cap    safety cap: a half still running after this many rounds counts as a stall
--
-- Seat "player" is the first seat (it kicks off every half). The AI plays it through a
-- mirrored view of the match; its trap prompts are answered with the AI's own trap policy.
-- Acceptance (spec §6): n=1000 with the three decks = 9,000 games; every deck's overall
-- win rate 42–58%; 0 stalls; first-seat match win rate 45–55%.

package.path = "./?.lua;./?/init.lua;" .. package.path

local args = {}
for _, a in ipairs(arg or {}) do
    local k, v = a:match("^([%w_]+)=(.*)$")
    if k then args[k] = v end
end
local function num(k, d) return args[k] and tonumber(args[k]) or d end

local N    = num("n", 1000)
local SEED = num("seed", 20260923)
local DIFF = args.diff or "medium"
local CAP  = num("cap", 60)

local C     = require("engine.constants")
local Store = require("store.match")
local AI    = require("ai.opponent")
local Decks = require("data.presetDecks")

local deckNames = {}
for d in (args.decks or "tikitaka,longball,catenaccio"):gmatch("[^,]+") do
    assert(Decks[d], "unknown deck: " .. d)
    deckNames[#deckNames + 1] = d
end

-- ── Seats ─────────────────────────────────────────────────────────────────────

-- The AI always plays "opponent"; for the "player" seat it sees the match mirrored.
local function viewFor(match, seat)
    if seat == "opponent" then return match end
    return setmetatable({ players = { opponent = match.players.player, player = match.players.opponent } },
                        { __index = match })
end

local function proxyStore(store, seat)
    if seat == "opponent" then return store end
    return setmetatable({ match = viewFor(store.match, seat), aiDifficulty = store.aiDifficulty }, {
        __index = function(_, k)
            local v = store[k]
            if type(v) == "function" then
                return function(_, ...) return v(store, ...) end
            end
            return v
        end,
    })
end

-- The first seat's trap prompts, answered like the AI's automatic traps.
local function answerTrapWindow(store)
    local tw, m = store.trapWindow, store.match
    if tw.type == "pre_attack" then
        for i, e in ipairs(tw.traps) do
            if e.card.definition.ability == "OFFSIDE"
               and AI.wantsOffside(m, "player", tw.attackerSlot, tw.defenderSlot) then
                return store:resolveTrap(i)
            end
        end
    elseif tw.type == "post_destroy" then
        if AI.wantsRedCard(tw.attackerSnap and tw.attackerSnap.atk or 0) then
            return store:resolveTrap(1)
        end
    elseif tw.type == "post_damage" then
        return store:resolveTrap(1)
    end
    -- Counter windows and Last Defender Foul: the AI seat never has these, so pass.
    return store:resolveTrap(nil)
end

-- ── One match ─────────────────────────────────────────────────────────────────

local function playMatch(deckP, deckO, seed)
    math.randomseed(seed)
    local store = Store.new()
    store.aiDifficulty = DIFF
    store:startMatch(Decks[deckP].cards, Decks[deckO].cards)
    local m = store.match
    local plans, tags = {}, {}
    local steps, turnKey, turnSteps = 0, nil, 0
    local stall = false

    while not m.winner do
        steps = steps + 1
        if steps > 200000 or m.turn > CAP then stall = true; break end
        if store.coverWindow then
            store:resolveCover(AI.decideCover(store))
        elseif store.trapWindow then
            answerTrapWindow(store)
        else
            local seat = m.activePlayer
            local key  = tostring(m.half) .. ":" .. m.turn .. ":" .. seat
            if key ~= turnKey then turnKey, turnSteps = key, 0 end
            turnSteps = turnSteps + 1
            if turnSteps > 300 then stall = true; break end
            -- A plan left over from the previous half is dropped (as scenes/match.lua does).
            if plans[seat] and tags[seat] ~= AI.planTag(m) then plans[seat] = nil end
            if not plans[seat] then
                plans[seat] = { list = AI.planTurn(), idx = 1 }
                tags[seat]  = AI.planTag(m)
            end
            local p      = plans[seat]
            local action = p.list[p.idx]
            if not action then
                plans[seat] = nil
            else
                local done, extra = AI.executeAction(proxyStore(store, seat), action)
                p.idx = p.idx + 1
                if extra then
                    for i = #extra, 1, -1 do table.insert(p.list, p.idx, extra[i]) end
                end
                if done then plans[seat] = nil end
            end
        end
    end
    return m, stall
end

-- ── Stats ─────────────────────────────────────────────────────────────────────

local function inc(t, k, v) t[k] = (t[k] or 0) + (v or 1) end

local S = {
    games = 0, firstWins = 0, stalls = 0,
    deckGames = {}, deckWins = {}, mu = {},
    halves = 0, regHalves = 0, regHalvesFirst = 0, timeHalves = 0,
    extraTime = 0, twoNil = 0,
    rounds = {}, roundsN = {},
    mcTriggers = 0, mcGames = 0, mcLeaderWins = 0,
    openGoals = 0, trapSet = {}, trapAct = {},
}

local ROUND_CAP = { ["1"] = C.MATCH.HALF_ROUND_LIMIT, ["2"] = C.MATCH.HALF_ROUND_LIMIT,
                    extra = C.MATCH.EXTRA_TIME_TURNS }

local function record(m, stall, deckOf)
    local w = m.winner
    S.games = S.games + 1
    if stall then S.stalls = S.stalls + 1 end
    inc(S.deckGames, deckOf.player); inc(S.deckGames, deckOf.opponent)
    if w then
        inc(S.deckWins, deckOf[w])
        if w == "player" then S.firstWins = S.firstWins + 1 end
    end
    local key = deckOf.player .. " (1st) vs " .. deckOf.opponent
    S.mu[key] = S.mu[key] or { g = 0, w = 0 }
    S.mu[key].g = S.mu[key].g + 1
    if w == "player" then S.mu[key].w = S.mu[key].w + 1 end

    local mc, sawExtra = { player = 0, opponent = 0 }, false
    for _, e in ipairs(m.log) do
        local p = e.payload
        if e.type == "half_end" then
            local h = tostring(p.half)
            S.halves = S.halves + 1
            inc(S.rounds, h, math.min(e.turn, ROUND_CAP[h]))
            inc(S.roundsN, h)
            if p.reason == "time" then S.timeHalves = S.timeHalves + 1 end
            if h == "extra" then
                sawExtra = true
            else
                S.regHalves = S.regHalves + 1
                if p.winner == "player" then S.regHalvesFirst = S.regHalvesFirst + 1 end
            end
        elseif e.type == "midfield_control" then
            mc[p.player] = mc[p.player] + 1
            S.mcTriggers = S.mcTriggers + 1
        elseif e.type == "lp_damage" and p.source == "open_goal" then
            S.openGoals = S.openGoals + 1
        elseif e.type == "card_played" and p.slot == "trap" then
            inc(S.trapSet, p.card)
        elseif e.type == "trap_activated" then
            inc(S.trapAct, p.trap)
        end
    end
    if sawExtra then S.extraTime = S.extraTime + 1 elseif w then S.twoNil = S.twoNil + 1 end
    if mc.player ~= mc.opponent then
        S.mcGames = S.mcGames + 1
        local leader = mc.player > mc.opponent and "player" or "opponent"
        if w == leader then S.mcLeaderWins = S.mcLeaderWins + 1 end
    end
end

-- ── Run ───────────────────────────────────────────────────────────────────────

local k = 0
for _, a in ipairs(deckNames) do
    for _, b in ipairs(deckNames) do
        k = k + 1
        for i = 1, N do
            local m, stall = playMatch(a, b, SEED + k * 100000 + i)
            record(m, stall, { player = a, opponent = b })
        end
    end
end

-- ── Report ────────────────────────────────────────────────────────────────────

local function pct(a, b) return b > 0 and 100 * a / b or 0 end
local function avg(a, b) return b > 0 and a / b or 0 end
local function sortedKeys(t)
    local ks = {}
    for key in pairs(t) do ks[#ks + 1] = key end
    table.sort(ks)
    return ks
end

print(string.format("config: n=%d per ordered matchup  seed=%d  diff=%s  decks=%s  cap=%d rounds",
    N, SEED, DIFF, table.concat(deckNames, ","), CAP))
print("decks:")
for _, d in ipairs(deckNames) do
    local cards = Decks[d].cards
    local sN, sAtk, kN, kDef = 0, 0, 0, 0
    for _, c in ipairs(cards) do
        if c.type == "striker" then sN = sN + 1; sAtk = sAtk + c.stats.atk end
        if c.type == "keeper"  then kN = kN + 1; kDef = kDef + c.stats.def end
    end
    print(string.format("  %-11s %d cards  strikers %d (avg ATK %.0f)  keepers %d (avg DEF %.0f)",
        d, #cards, sN, avg(sAtk, sN), kN, avg(kDef, kN)))
end
print(string.format("games=%d  stalls=%d  first-seat match wins=%.1f%%",
    S.games, S.stalls, pct(S.firstWins, S.games)))
print(string.format("halves=%d  decided on time=%d  first seat won %.1f%% of halves 1-2  2-0=%.1f%%  extra time=%.1f%%",
    S.halves, S.timeHalves, pct(S.regHalvesFirst, S.regHalves), pct(S.twoNil, S.games),
    pct(S.extraTime, S.games)))
print(string.format("avg rounds: half 1=%.2f  half 2=%.2f  extra time=%.2f",
    avg(S.rounds["1"] or 0, S.roundsN["1"] or 0), avg(S.rounds["2"] or 0, S.roundsN["2"] or 0),
    avg(S.rounds.extra or 0, S.roundsN.extra or 0)))
print(string.format("midfield control: %.2f extra draws/match; the side with more control won %.1f%% of %d games",
    avg(S.mcTriggers, S.games), pct(S.mcLeaderWins, S.mcGames), S.mcGames))
print(string.format("open goals: %.2f/match", avg(S.openGoals, S.games)))
print("deck win rates:")
local deckRate = {}
for _, d in ipairs(deckNames) do
    deckRate[d] = pct(S.deckWins[d] or 0, S.deckGames[d] or 0)
    print(string.format("  %-11s %5.1f%%  (%d appearances)", d, deckRate[d], S.deckGames[d] or 0))
end
print("matchups (first-seat win rate):")
for _, key in ipairs(sortedKeys(S.mu)) do
    local v = S.mu[key]
    print(string.format("  %-34s %5.1f%%  (%d)", key, pct(v.w, v.g), v.g))
end
print("traps set / activated:")
for _, key in ipairs(sortedKeys(S.trapSet)) do
    print(string.format("  %-26s set=%6d  act=%6d  (%.1f%%)", key, S.trapSet[key], S.trapAct[key] or 0,
        pct(S.trapAct[key] or 0, S.trapSet[key])))
end

-- ── Acceptance (spec §6) ──────────────────────────────────────────────────────

local allPass = true
local function check(label, pass)
    print(string.format("  %-4s %s", pass and "PASS" or "FAIL", label))
    allPass = allPass and pass
end
print("acceptance (spec §6):")
check(string.format("games = 9000 (got %d)", S.games), S.games == 9000)
local lo, hi = 100, 0
for _, d in ipairs(deckNames) do
    lo = math.min(lo, deckRate[d])
    hi = math.max(hi, deckRate[d])
end
check(string.format("every deck's win rate within 42-58%% (min %.1f%%, max %.1f%%)", lo, hi),
    lo >= 42 and hi <= 58)
check(string.format("stalls = 0 (got %d)", S.stalls), S.stalls == 0)
local first = pct(S.firstWins, S.games)
check(string.format("first-seat match win rate within 45-55%% (got %.1f%%)", first),
    first >= 45 and first <= 55)
print("ACCEPTANCE: " .. (allPass and "PASS" or "FAIL"))
```

- [ ] **Step 2: Smoke run**

Run: `lua tools/sim/sim.lua n=2 seed=1`
Expected:
- It finishes in a few seconds and prints the `config:` line.
- The `decks:` block shows:

```
  tikitaka    40 cards  strikers 11 (avg ATK 2164)  keepers 3 (avg DEF 1817)
  longball    40 cards  strikers 13 (avg ATK 2154)  keepers 3 (avg DEF 1800)
  catenaccio  40 cards  strikers 8 (avg ATK 2169)  keepers 4 (avg DEF 1888)
```

- It prints `games=18  stalls=0`.
- The acceptance block ends with `ACCEPTANCE: FAIL`. That is expected here, because `games = 9000` fails with only 18 games.
- There are no Lua errors.

- [ ] **Step 3: Nothing is written into the repo**

Run: `git status --porcelain`
Expected: only `?? tools/sim/` (the new, uncommitted file). Nothing else.

- [ ] **Step 4: Commit the simulator**

```bash
ls luac.out
git add tools/sim/sim.lua
git commit -m "Add a headless AI-vs-AI balance simulator under tools/sim" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Acceptance run (9,000 games).** This takes about a minute or two. Give the command a 10-minute timeout, or run it in the background and wait for it to finish.

Run: `lua tools/sim/sim.lua n=1000 seed=20260923 diff=medium`
Expected: the last five lines are

```
  PASS games = 9000 (got 9000)
  PASS every deck's win rate within 42-58% (min …, max …)
  PASS stalls = 0 (got 0)
  PASS first-seat match win rate within 45-55% (got …%)
ACCEPTANCE: PASS
```

- [ ] **Step 6: If any line reads `FAIL`:**
  1. Stop, and report the **full** simulator output to the user.
  2. Point out the failing criteria and the numbers involved:
     - the deck win rates;
     - the first-seat rate;
     - the stall count.

     For reference, the analyst's closest configuration was Tiki-Taka 44.4%, Long Ball 54.2%, Catenaccio 51.5%, first seat 48.5%.
  3. **Do not** change any card stat, deck list, constant, or AI threshold to make it pass. Changes need the owner's approval.
  4. A non-zero stall count points to a correctness bug (a loop), not balance. Report it the same way and do not fix it without approval.
  5. Continue to Task 12 only after the user says how to proceed.

Nothing to commit in Steps 5–6. Cumulative tests: **216**.

---

### Task 12: Rewrite `rules.md` (spec §5)

**Files:**
- Rewrite: `rules.md`
- Modify: `README.md`

- [ ] **Step 1: Replace `rules.md` entirely with:**

````markdown
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
````

- [ ] **Step 2: `README.md`.**

Replace `- Each player starts with **4000 LP** and a 30-card deck` with

```markdown
- Each player starts with **4000 LP** per half and a 40-card deck
```

In the project-structure block, replace

```
rules.md          — full engine rules reference
```

with

```
tools/            — dev tools: snapshot harness (tools/snapshot), balance simulator (lua tools/sim/sim.lua)
rules.md          — full engine rules reference
```

- [ ] **Step 3: Check the docs against the code.**

Run: `grep -n "30-card\|30 cards\|+1 summon\|human player wins\|return to their face down" rules.md README.md`
Expected: no output.

Run: `lua tests/run.lua`
Expected: `216 passed, 0 failed`

- [ ] **Step 4: Commit**

```bash
ls luac.out
git add rules.md README.md
git commit -m "Rewrite rules.md to match the code" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **216**.

---

### Task 13: Final check

**Files:** none (verification only)

- [ ] **Step 1: Unit tests**

Run: `lua tests/run.lua`
Expected: `216 passed, 0 failed`

- [ ] **Step 2: Syntax of every changed LÖVE file, and no `luac.out`**

Run: `luac -p engine/*.lua engine/cards/definitions/*.lua store/match.lua ai/opponent.lua data/presetDecks.lua scenes/match.lua ui/card.lua ui/pitch.lua ui/match/*.lua tools/snapshot/scenarios.lua tools/sim/sim.lua && ls luac.out`
Expected: no `luac` output, then `ls: luac.out: No such file or directory`.

- [ ] **Step 3: Every scenario runs clean**

Run: `for s in home library match cards summon juice debug pause combat trap cover trapwin scout halftime victory defeat revealed midfield; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback on stderr.

- [ ] **Step 4: Review the PNGs** with the Read tool against the checklists:
  - **Tasks 2, 6, 7, 9 and 10:** `summon_attack`, `revealed_*`, `midfield_*`, `juice_banner`, `summon_aiturn`, `cards_gallery`.
  - **Other scenarios:** they must still match their Plan B and Plan C checklists.
  - **Everywhere:** no screen may show a SUMMONS ★ or a "+1 SUMMON" text.

- [ ] **Step 5: Simulator acceptance**

Run: `lua tools/sim/sim.lua n=1000 seed=20260923 diff=medium`
Expected: the last line is `ACCEPTANCE: PASS`. (If it isn't, follow Task 11 Step 6.)

Run: `git status --porcelain`
Expected: no output.

- [ ] **Step 6: Only the expected areas changed**

Run: `git diff --name-only 71a0fff -- . ':(exclude)docs'`
Expected exactly:

```
README.md
ai/opponent.lua
data/presetDecks.lua
engine/cards/definitions/keepers.lua
engine/cards/definitions/strategies.lua
engine/cards/definitions/strikers.lua
engine/combat.lua
engine/constants.lua
engine/phases.lua
engine/state.lua
rules.md
scenes/match.lua
store/match.lua
tests/helpers.lua
tests/test_ai.lua
tests/test_balance_data.lua
tests/test_helpers.lua
tests/test_match_stats.lua
tests/test_revealed_ui.lua
tests/test_rules_extra_time.lua
tests/test_rules_first_turn.lua
tests/test_rules_half_limit.lua
tests/test_rules_keeper_bonus.lua
tests/test_rules_keeper_shot.lua
tests/test_rules_midfield.lua
tests/test_rules_open_goal.lua
tests/test_rules_revealed.lua
tests/test_store_traps.lua
tests/test_toasts.lua
tools/sim/sim.lua
tools/snapshot/scenarios.lua
ui/card.lua
ui/match/bottombar.lua
ui/match/hover.lua
ui/match/stats.lua
ui/match/toasts.lua
ui/match/zoom.lua
ui/pitch.lua
```

Run: `git diff --stat 71a0fff -- . ':(exclude)docs' | tail -1`
Expected: `38 files changed, …`

- [ ] **Step 7: Report to the user.**
  - **What changed:** summarize the changes per spec section.
  - **Simulator:** paste the simulator's deck win rates, matchups and acceptance block.
  - **Screenshots:** show `summon_attack`, `revealed_board`, `revealed_zoom`, `midfield_banner` and `midfield_toast`.
  - **Deviations:** list the intentional deviations from this plan's header.
  - **Found but not fixed:** list both bugs from deviation 16, and ask whether to fix them:
    - the `ipairs` holes in `recoverPitch`;
    - the keeper-guarantee swap that duplicates or loses a card.

  Tell the user an **interactive play-test is required**, because the harness can't do it. They should play at least one full match against the AI with each deck and check:
  - **First turn:**
    - On your first turn of each half (and Extra Time), START ATTACK shows the hint "First turn of the half: no attacks or shots" and no red targets.
    - Clicking an opponent slot flashes "NO ATTACKS ON THE FIRST TURN OF A HALF".
    - Direct Free Kick and Penalty are refused and stay in your hand.
    - The AI does attack on its turn 1.
  - **Open goal:**
    - Leave your keeper slot empty on purpose: the AI scores its striker's full ATK.
    - Attack an empty enemy keeper slot through a defender gap: "GOAL!" for full ATK.
    - With both enemy defender slots filled, the keeper slot is refused ("keeper protected").
  - **Keeper-as-shot:** no keeper is ever destroyed. A losing shot shows KEEPER SAVES and your card stays on the pitch.
  - **Half limit:**
    - The top bar's TURN counter reaches 14. After the AI's 14th turn, the half-time ribbon appears.
    - The LP leader wins the half. Check the tie-breaks if you can arrange them.
  - **Extra Time:** after 6 rounds the LP leader wins, not whoever dealt more damage earlier in the match.
  - **Keeper bonus:**
    - Attack with a defender, then hover your keeper during the AI's turn: its Effective DEF is 300 lower.
    - On your next turn it is back.
  - **Revealed cards:**
    - Attack an AI face-down card and lose. It stays on the pitch face-up with a DEF pill, and hovering it zooms with "Mode: DEFENSE (revealed)".
    - Destroying it later gives no LP damage.
    - Your own revealed cards show FLIP UP in your summon phase and can be flipped.
    - The AI's unrevealed face-down cards and its traps still can't be zoomed.
  - **Scout Report:** the scouted card stays revealed after the overlay closes.
  - **Midfield control:**
    - With the stronger midfielder, your turn starts with two card-draw animations, the banner "MIDFIELD CONTROL +1 CARD" and the toast "You control midfield +1 card".
    - The SUMMONS pill always reads "/ 2" (or "/ 1" under Time Wasting) and never shows a star.
  - **Traps:**
    - A tie never triggers your or the AI's Red Card, and never triggers Last Defender Foul.
    - After LET THROUGH on an AI attack that scores, the VAR prompt appears.
    - The AI's VAR overturns your Direct Free Kick goal.
    - The AI's Offside no longer fires on weak attacks, and its Red Card ignores attackers under 2000 ATK.
  - **AI:**
    - The AI never puts a defender or midfielder card in a striker slot.
    - When the AI wins a half during its own turn, it draws and summons normally on its first turn of the next half.
  - **Balance feel:** Tiki-Taka no longer feels outclassed by Long Ball.

---

## Self-review

### Spec coverage

| Spec item | Task |
|---|---|
| §1.1 Half ends after 14 rounds; `C.MATCH.HALF_ROUND_LIMIT = 14` | 3 (`HALF_ROUND_LIMIT`, `checkHalfEnd`) |
| §1.1 Winner: more LP → more damage this half → the second player that half | 3 (`decideOnTime`, `halfDamageDealt`, `dealDamage`) |
| §1.1 Extra Time keeps its 6-round limit | 3, 4 (`extraTurnsLeft` unchanged) |
| §1.2 Open goal for full ATK where an attack reaches the keeper and the slot is empty | 2 (`resolveShot` nil keeper, `_shootAtGoal`, `_advanceThrough`) |
| §1.2 VAR still applies to open goals | 2 (test), 8 (`_afterCombatTraps`) |
| §1.2 Direct Free Kick / Penalty at an empty keeper score full ATK | 2 (`playStrategy`) |
| §1.2 Starter can't attack or play attacking strategies on turn 1 (incl. Extra Time) | 2 (`isOpeningTurn`, `validateAttack`, strategy check) |
| §1.2 Attack phase still entered; UI shows a hint instead of targets | 2 (`hintText`, `getAttackTargetSlots`) |
| §1.3 Attacked defender/midfielder counts again at the owner's next turn | 5 (`_clearAttackerFlags`) |
| §1.4 A surviving or revealed-by-effect face-down card stays in defense (`revealed = true`) | 6 (`_doCombat`, `_goalAttempt`, `resolveCover`, Scout Report) |
| §1.4 Revealed: visible to both, DEF marker, keeps bonuses, no battle damage, can flip | 6 (`Card.showsFace`, `drawPitched`, `pitch.lua`, tests) |
| §1.4 Midfield power uses the actual mode | 6 (test), 7 |
| §1.4 (plan) Opponent's revealed cards zoomable; hidden ones and traps not | 6 (`Hover.zoomable`, `hoverTarget`) |
| §1.5 Extra Time: ET LP → ET damage → second player; no human default | 4 |
| §1.6 Targeting unchanged; every keeper hit is a shot; keeper never destroyed | 2 (`_shootAtGoal`, keeper-shot tests) |
| §1.7 Stronger midfielder draws 1 extra card after the normal draw; no summon bonus | 7 (`_midfieldControl`, endTurn block removed) |
| §1.7 Face-down midfielder counts for the engine rule | 7 (test) |
| §1.7 `midfield_control` payload gains `bonus = "draw"` | 7 |
| §1.7 UI: banner "+1 CARD", no ★ on the SUMMONS pill, toast "+1 card", constant renamed | 7 |
| §2.1 Striker ATK table | 10 |
| §2.2 Keeper DEF table | 10 |
| §2.3 Tiki-Taka list, still 40 cards | 10 |
| §3.1 Red Card not on a tie | 8 |
| §3.2 VAR / Red Card after `resolveCover` and strategy shots | 8 (`_afterCombatTraps`, `resolveCover`, `playStrategy`) |
| §3.3 Last Defender Foul counts face-up defenders only; no tie trigger | 8 (`_isLastFaceUpDefender`) |
| §3.4 Stale AI plan discarded on half change | 9 (`AI.planTag`, `aiPlanTag`) |
| §4.1 No defender/midfielder cards in striker slots | 9 (`_pickBestSlot`) |
| §4.2 Offside ≥ ~300 or uncoverable empty slot; Red Card ≥ 2000 ATK | 9 (`wantsOffside`, `wantsRedCard`, store hooks) |
| §4.3 No attacks on the AI's opening turn; midfield draw needs no AI handling | 2 (`_planNextAttack`, `_pickStrategy`), 7 |
| §5 `rules.md` rewrite (all listed topics) | 12 |
| §6 One test file per rule area driving the real engine/store | 2–10 (`tests/test_rules_*.lua`, `test_store_traps`, `test_ai`, `test_balance_data`) |
| §6 Simulator in `tools/sim/`, writes nothing; 9,000 games; 42–58%; 0 stalls; first seat 45–55% | 11 (acceptance block), 13 |
| §6 Snapshot scenarios pass; pill/banner/toasts reflect the new midfield rule | 7, 13 |
| §6 Changes under `engine/`, `store/`, `ai/`, `data/` | 13 Step 6 |

### Placeholder scan

Every code step has complete code. Every edit names the exact old text and gives the full new text. There is no "TBD", "similar to" or "add appropriate …".

### Name and signature consistency

| Name | Signature | Defined | Used |
|---|---|---|---|
| `State.other` | `(playerId)` → id | 2 | 2, 3, 7, 8, 9 |
| `State.isOpeningTurn` | `(matchState)` → bool | 2 | 2 (phases, AI, scene) |
| `State.dealDamage` / `State.refundDamage` | `(matchState, dealerId, amount)` | 2 / 3 | 2, 3, 8 |
| `State.decideOnTime` | `(matchState)` → id | 3 | 3, 4 |
| `State.checkHalfEnd` | `(matchState)` → id, reason | 3 | phases, store |
| `State.endHalf` | `(matchState, winner, reason)` | 3 | phases, store, tests |
| `Phases.validateAttack` | `(matchState, attackerSlot, defenderSlot)` → ok, err | 2 | phases, store |
| `Phases._shootAtGoal` | `(matchState, attacker, attackerSlot, opponentId)` | 2 | `attack`, `_advanceThrough` |
| `Phases._goalAttempt` | `(matchState, striker, keeper|nil, attackerSlot, opponentId, penaltyMode)` → result with `attackerSlot`, `openGoal` | 2 | 2, 6 |
| `Phases._clearAttackerFlags` | `(pitch)` | 5 | `endTurn` |
| `Phases._midfieldControl` | `(matchState)` | 7 | `draw` |
| `Combat.resolveShot` | `(striker, keeper|nil, oppPitch, strikerPitch, penaltyMode)` | 2 | `_goalAttempt` |
| `Store:_afterCombatTraps` | `(snap, result, attackerSlot)` → bool | 8 | `declareAttack`, `resolveCover`, `playStrategy`, `_resumeAttack` |
| `Store:_resumeAttack` | `(tw)` → bool | 8 | `resolveTrap` |
| `Store:_isLastFaceUpDefender` | `(defenderId, defenderSlot)` → bool | 8 | `declareAttack` |
| `AI.wantsOffside` | `(match, ownerId, attackerSlot, defenderSlot)` → bool | 9 | store, `tools/sim` |
| `AI.wantsRedCard` | `(attackerAtk)` → bool | 9 | store, `tools/sim` |
| `AI.estimateAttackDamage` | `(match, ownerId, attackerSlot, defenderSlot)` → number | 9 | `wantsOffside` |
| `AI.planTag` | `(match)` → "half:turn" | 9 | scene, `tools/sim` |
| `Card.showsFace` | `(pitched)` → bool | 6 | `drawPitched`, `pitch.lua` |
| `Hover.zoomable` | `(owner, slotType, card)` → bool | 6 | `Match.hoverTarget` |
| `Stats.summons` | `(match)` → used, max | 7 | `bottombar` |

- **Log fields:** `half_end.reason` (Task 3), `midfield_control.bonus` (Task 7) and `lp_damage.source = "open_goal"` (Task 2) are the fields the simulator reads in Task 11.
- **Snapshot helpers:** the scenario helpers `kickOff`, `pitched`, `store`, `move`, `center` and `Layout` already exist in `tools/snapshot/scenarios.lua` above where the new `revealed` and `midfield` scenarios are inserted.

### Critical Files for Implementation
- /Users/mac/Documents/football-tcg-lua/engine/phases.lua
- /Users/mac/Documents/football-tcg-lua/store/match.lua
- /Users/mac/Documents/football-tcg-lua/engine/state.lua
- /Users/mac/Documents/football-tcg-lua/ai/opponent.lua
- /Users/mac/Documents/football-tcg-lua/tools/sim/sim.lua (new)
