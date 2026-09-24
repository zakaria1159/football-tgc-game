# Card Modes & Stamina / Substitutions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the whole owner-confirmed spec. Part A (card modes) lands before Part B (stamina and substitutions).
- **Part A: modes.**
  - The global ATTACK/DEFENSE toggle and the `M` key go away.
  - Instead, a **mode picker** opens on the slot you drop a card on: ATTACK (`A`) or DEFEND (`D`), and `Esc` cancels.
  - Cards can switch position **both ways**, once per turn. Attack → defense makes a **face-up defense** card.
  - One pure rule, `Phases.canSwitch`, is shared by the engine, the card ribbons and the AI.
  - The AI can pull a weak or tired card back to defense.
- **Part B: stamina.**
  - Every field card has stamina: strikers 4, midfielders 5, defenders 6, Engine 7. Keepers never tire.
  - A card loses 1 at the end of its owner's turn, and 1 more for each attack or cover.
  - Press and Counter-press cost 1 more each time they fire.
  - At 0 stamina the card is **Tired**: −300 ATK and −300 DEF, applied through the resolver.
  - The UI shows pips, a sweat drop, a TIRED pill, red numbers, zoom lines and a `TIRED -300` combat tag.
- **Part B: substitutions.**
  - Dropping a card on an **occupied** slot substitutes it. That uses a summon and one of **3 subs per half**, and keeper swaps count.
  - The bottom bar shows **SUBS n / 3**.
  - The **Substitution** strategy card is the special sub: no summon, no sub used, and the new card may attack this turn.
  - The AI subs out tired cards.
- **Tools and docs:**
  - the simulator reports stamina and substitution stats;
  - `rules.md` is updated.

**Architecture:**
- **`engine/stamina.lua` (new, pure).** It depends only on `engine.constants`.
  - `Stamina.max(cardDef)`, `Stamina.tired`, `Stamina.spend` and `Stamina.visible`.
  - `State.newPitchedCard` sets `pitched.stamina`, so every card on the pitch, test boards included, starts full.
- **`engine/phases.lua`:**
  - `Phases.canSwitch(card, slotType, ctx)` is the pure position rule. It returns the target mode, or nil plus a reason.
  - `Phases.changeMode` goes through `canSwitch`.
  - `Phases._spend` is the single place that drains stamina and logs `card_tired`. It is called:
    - at the end of the owner's turn;
    - when an attack resolves (fight, shot, wasted attack);
    - when a cover resolves;
    - from `Phases._afterSummon` (Press);
    - from `_doCombat` (Counter-press).
  - `Phases.canSubstitute(matchState, playerId, cardDef, slotType, slotIndex)` generalises `canKeeperSwap`. It reads the seat it is given, so it is safe on the simulator's mirrored view.
  - `Phases.summon` treats an occupied slot as a substitution.
- **`engine/cards/resolver.lua`:** `R.tiredPart` adds a `TIRED` stat part in `R.atkBonus` and `R.defBonus`, and `Combat.keeperDef` uses it for a non-keeper in goal. Because of that, the numbers the engine uses are the same everywhere:
  - pitch badges (`Card.bonuses`);
  - zoom lines;
  - combat snapshot tags;
  - AI estimates.

  `R.logParts` never logs `TIRED`, because Tired is not an ability.
- **Substitution card:** `ps.subFreedSlot` holds the freed slot, and the engine enforces the free placement into it. The incoming card gets `actsImmediately`, which `Phases.canAttackNow` honours.
- **UI:** `ui/match/modepicker.lua` is pure apart from `draw`. `Card.switchLabel` handles the ribbons, and `Card.staminaView` and `L.stamina` / `L.sweat` handle the pips. `Stats.subs` and `Layout.bottom.subs` handle the SUBS counter.

**Tech Stack:**
- LÖVE 11.4 with LuaJIT / Lua 5.1 semantics for game code:
  - no `//`;
  - no `goto` in new code (the existing `goto continue` in `AI._planSummons` stays);
  - never assign to a `for` loop variable;
  - no identifier named `global`.
- Plain Lua 5.5 (`/opt/homebrew/bin/lua`) for `lua tests/run.lua` and `tools/sim/sim.lua`.
- `luac -p` for syntax checks of LÖVE-only files.
- `tools/snapshot/snap.sh <scenario>` for screenshots.

**Spec:** `docs/superpowers/specs/2026-09-24-modes-stamina-design.md` (all of it). Every decision in the spec is owner-confirmed.
**Branch:** `feat/modes-stamina`, already checked out. The spec commit is `e17517c`.

**Conventions (apply to every task):**
- **Working directory:** run every command from the repo root, `/Users/mac/Documents/football-tcg-lua`.
- **Commit messages:** `git commit -m "<subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`. The commit steps show the full command.
- **No `luac.out`:**
  - Only ever run `luac -p` (parse only).
  - Before each commit, `ls luac.out` must print `ls: luac.out: No such file or directory`.
- **Snapshots:**
  - PNGs land in `.snapshots/` (gitignored) at 2560×1600.
  - Review each listed PNG with the Read tool. If one does not match its checklist, fix it and re-run before committing.
  - The harness ignores the real cursor, runs one scripted step per frame and caps the clock at 1/30 s per frame. Steps that must run on different frames are at least 0.03 s apart.
- **Tests:**
  - Engine tests drive the real engine through `tests/helpers.lua`.
  - The count is **422** at the start and **483** at the end.
- **Smoke run:** every engine or AI task ends with `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`, so the game stays playable after each commit.
- **Balance:**
  - Never change a card stat, a deck list, a `C.ABILITY` / `C.STAMINA` number or an AI threshold beyond this plan.
  - If the simulator fails acceptance, stop and report (Task 12).
- **Editing:** when a step says "replace", the old text is quoted exactly and must match exactly once in the file. "Directly above / below the line that starts with …" names a unique line.

**Plan clarifications (inside the spec's wording; confirm them when the plan is reviewed):**
- **P1. canSwitch.**
  - The spec's refusals are:
    - keepers and traps;
    - a card played or substituted in this turn (`summonedThisTurn`);
    - a card already switched this turn (`modeChanged`);
    - a card that attacked this turn (`usedAsAttacker`);
    - the half-time break;
    - any phase other than the owner's own summon phase.
  - The plan adds one more: an **exhausted** card can't switch (the old `Card.canFlip` already said so).
  - A locked card (`cannotActNextTurn`) may switch, because switching is not acting.
- **P2. Stamina by card type.**
  - Stamina depends on the card type, not the slot. A keeper-type card never tires, even outside the keeper slot.
  - A non-keeper card in the keeper slot tires. When Tired it loses 300 of its keeper DEF, as its own DEF.
- **P3. The AI uses the Substitution card.**
  - The spec's simulator report asks for "Substitution-card use", but the AI never plays that card today.
  - The AI now spends its Substitution card first, on its most tired card, when it holds a same-line replacement. This is behind `AI.USE_SUBSTITUTION_CARD = true`.
  - If the owner rejects it, set the flag to `false`. The simulator then reports 0.
- **P4. What counts as attacking.**
  - "Attacking costs 1 extra" applies to every attack that **resolves**:
    - a fight;
    - a shot, including Through ball, Direct Free Kick and Penalty shooters;
    - a wasted attack.
  - An attack cancelled by Offside never resolves, so it costs nothing.
  - A destroyed card has left the pitch, so it pays nothing.
  - "Covering costs 1 extra whether it wins or not": the coverer pays whenever it is still on the pitch (a won cover or a last-ditch tackle). A coverer destroyed by a tie has left.
- **P5. What Tired changes.**
  - Tired changes only the card's own ATK and DEF (`R.atkBonus`, `R.defBonus`, keeper own DEF).
  - It does **not** change:
    - midfield control power (`Combat.midfielderPower` keeps printed stats);
    - the keeper line bonus the card gives (+300 / +150 / Bolt).
- **P6. End-of-turn drain.** Every field card on the owner's pitch loses 1 at the end of its owner's turn. That includes a card summoned that turn.
- **P7. The minus sign.**
  - The tag reads `TIRED -300` with an ASCII hyphen.
  - The display fonts have no U+2212, and the rest of the UI already writes `LP -500`.
- **P8. Switching and the picker.**
  - Clicking your own card in the summon phase switches it, as FLIP UP does today. A refused switch is flashed with the reason.
  - While the picker is open, any click outside it cancels, like `Esc`. A click inside the panel but not on a button does nothing.
- **P9. The Substitution card's free placement.**
  - Today only the scene enforces "the free placement goes into the freed slot". The engine now enforces it through `ps.subFreedSlot`.
  - The placement is allowed only into that slot, once, and in the same turn.
- **P10. Slot eligibility for a sub.**
  - An occupied keeper slot takes keeper cards only, as today.
  - Every other occupied slot takes any field card, keepers included, just as summoning does ("any card can go in any slot").
- **P11. "About to attack".** "1 for strikers about to attack" is read as a **striker-slot card at stamina ≤ 1** (`AI.SUB_STRIKER_AT = 1`). Its next attack would tire it.
- **P12. The tired badge.**
  - Red numbers on the red ATK badge would be unreadable.
  - A tired badge therefore gets a red rim, a pale interior and a red number.

**Hook map (where each rule plugs in):**

| Rule | Code point | Function |
|---|---|---|
| Position switch | `Store:changeMode` → `Phases.changeMode`; `Card.switchLabel` (ribbons); `AI.canSwitch` | `Phases.canSwitch` |
| Mode choice | scene click on a glowing slot → picker → `Match.placeCard` → `store:summonCard` / `store:freeSummon` | `ModePicker.*` |
| Stamina init | `State.newPitchedCard` | `Stamina.max` |
| End-of-turn drain | `Phases.endTurn`, after `recoverPitch` | `Phases._spend` |
| Attack drain | `Phases._doCombat` (end), `Phases._goalAttempt`, the three `attack_wasted` paths | `Phases._spend` |
| Cover drain | `Phases.resolveCover`, after `_doCombat` | `Phases._spend` |
| Press / Counter-press drain | `Phases._afterSummon` (`R.onSummon` returns true); `_doCombat` (`R.firedIn(defParts, "COUNTER_PRESS")`) | `Phases._spend` |
| Tired −300 | `R.atkBonus`, `R.defBonus`, `Combat.keeperDef` | `R.tiredPart` |
| Substitution | `Phases.summon` (occupied slot); scene highlights; `AI._planKeeperSwap`, AI subs | `Phases.canSubstitute` |
| Substitution card | `Phases.playStrategy` (sets `subFreedSlot`); `Phases.summon` (free placement); `Phases.canAttackNow`, `Phases.attack` | `actsImmediately` |

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `engine/constants.lua` | modify | `C.STAMINA`, `C.MATCH.SUBS_PER_HALF` |
| `engine/stamina.lua` | create | Pure stamina rules |
| `engine/state.lua` | modify | `pitched.stamina`, `ps.subsUsed`, `ps.subFreedSlot` (init and half reset) |
| `engine/phases.lua` | modify | `canSwitch`, `changeMode`, `_spend`, drains, `_afterSummon`, `canSubstitute`, `canKeeperSwap`, `summon` (subs, free placement), `canAttackNow`, `attack` (Pace trigger), `endTurn` |
| `engine/cards/resolver.lua` | modify | `R.onSummon` returns true, `R.firedIn`, `R.TIRED`, `R.partName`, `R.tiredPart`, Tired in `atkBonus` / `defBonus`, `logParts` skips Tired |
| `engine/combat.lua` | modify | Tired in `Combat.keeperDef` |
| `engine/cards/definitions/strategies.lua` | modify | Substitution text |
| `store/match.lua` | modify | Snapshot tag names (`partName`), `tired` flag |
| `ai/opponent.lua` | modify | `AI.canSwitch`, `_winsNow`, `_threatAgainst`, `_weak`, `_soleCoverer`, `_planSwitches`, the `toDefense` and `subCard` actions, sub planning, keeper swap within the budget |
| `scenes/match.lua` | modify | Switch click, picker flow, `slotAccepts` / `placeCard` / `confirmPlace`, no `M` key or toggle, sub highlights, hints |
| `ui/match/modepicker.lua` | create | Mode picker |
| `ui/card.lua` | modify | `switchLabel`, TO DEFENSE ribbon, `bonuses` for every slot, tired badges, `staminaView`, pips, sweat drop |
| `ui/kit/draw.lua` | modify | `arrowDown`, tired badge variant |
| `ui/theme.lua` | modify | `Theme.tired` |
| `ui/pitch.lua` | modify | `switchLabel`, `showStamina` |
| `ui/match/layout.lua` | modify | Toggle removed, `bottom.subs` |
| `ui/match/bottombar.lua` | modify | Toggle removed, SUBS pill |
| `ui/match/stats.lua` | modify | `Stats.subs` |
| `ui/match/toasts.lua` | modify | Switch-to-defense, substitution and tired toasts |
| `ui/match/zoom.lua` | modify | Signed stat lines, stamina line, substitute line |
| `ui/overlay/combatfx.lua` | modify | Signed `tagText`, `tired` in `cardView` |
| `ui/overlay/combat.lua` | modify | Negative bonuses, signed ATK label, tired badges |
| `tools/snapshot/scenarios.lua` | modify | `summon`, `juice` and `keeperswap` updated to use the picker; new `modes`, `stamina` and `subs` scenarios |
| `tools/snapshot/card_gallery.lua` | modify | Switch ribbons, pips, a tired card |
| `tools/sim/sim.lua` | modify | Stamina and substitution stats |
| `rules.md` | modify | Modes, switching, stamina, substitutions, Substitution card |
| `tests/test_modes_switch.lua`, `test_modepicker.lua`, `test_ai_switch.lua`, `test_stamina.lua`, `test_tired.lua`, `test_stamina_ui.lua`, `test_substitutions.lua`, `test_substitution_card.lua`, `test_ai_subs.lua` | create | One file per task |
| `tests/test_revealed_ui.lua`, `tests/test_match_layout.lua` | modify | `switchLabel`; toggle removed / SUBS rect |

---

### Task 1: Position switch both ways: the `canSwitch` rule, engine, ribbons (spec A2)

**Files:**
- Modify: `engine/phases.lua`, `ui/card.lua`, `ui/kit/draw.lua`, `ui/pitch.lua`, `ui/match/toasts.lua`, `ai/opponent.lua`, `scenes/match.lua`, `tools/snapshot/card_gallery.lua`, `tests/test_revealed_ui.lua`
- Test: `tests/test_modes_switch.lua` (create)

- [ ] **Step 1: Write `tests/test_modes_switch.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local Card   = require("ui.card")
local Toasts = require("ui.match.toasts")

local OWN = { isOwnTurn = true, phase = "summon" }

local function pc(mode, revealed)
    return { definition = { type = "defender", stats = { atk = 900, def = 1500 } },
             mode = mode, revealed = revealed, slotType = "defender" }
end

T.test("canSwitch: defense → attack and attack → defense in the owner's summon phase", function()
    T.eq(Phases.canSwitch(pc("defense"), "defender", OWN), "attack")
    T.eq(Phases.canSwitch(pc("defense", true), "defender", OWN), "attack")
    T.eq(Phases.canSwitch(pc("attack"), "defender", OWN), "defense")
    T.eq(Phases.canSwitch(pc("attack"), "striker", OWN), "defense")
    T.eq(Phases.canSwitch(pc("attack"), "midfielder", OWN), "defense")
end)

T.test("canSwitch: never keepers or traps, nor a card played, switched, attacking or exhausted this turn", function()
    T.eq(Phases.canSwitch(nil, "defender", OWN), nil)
    T.eq(Phases.canSwitch(pc("defense", true), "keeper", OWN), nil)
    T.eq(Phases.canSwitch(pc("attack"), "keeper", OWN), nil)
    local trap = pc("defense"); trap.slotType = "trap"
    T.eq(Phases.canSwitch(trap, "trap", OWN), nil)
    for _, flag in ipairs({ "summonedThisTurn", "modeChanged", "usedAsAttacker", "exhausted" }) do
        local c = pc("attack"); c[flag] = true
        local to, why = Phases.canSwitch(c, "defender", OWN)
        T.eq(to, nil, flag); T.ok(type(why) == "string", flag .. " reason")
    end
end)

T.test("canSwitch: only on the owner's own turn, in the summon phase, outside the break", function()
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = false, phase = "summon" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = true, phase = "attack" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender", { isOwnTurn = true, phase = "draw" }), nil)
    T.eq(Phases.canSwitch(pc("attack"), "defender",
        { isOwnTurn = true, phase = "summon", halfTimeBreak = true }), nil)
end)

T.test("switch attack → defense: face-up defense, logged, once per turn", function()
    local m = H.match({ phase = "summon" })
    local c = H.place(m, "player", "striker", 1, H.card("striker", 2000, 600))
    local s = H.store(m)
    T.eq(s:changeMode("striker", 1), true)
    T.eq(c.mode, "defense"); T.eq(c.revealed, true); T.eq(c.modeChanged, true)
    local e = H.events(m, "card_played")
    T.eq(#e, 1); T.eq(e[1].payload.action, "mode_change"); T.eq(e[1].payload.mode, "defense")
    local ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "already switched this turn")
    T.eq(c.mode, "defense")
end)

T.test("switched to defense: it can't attack, and it gives up no LP when destroyed", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1500))
    local s = H.store(m)
    T.eq(s:changeMode("defender", 1), true)
    m.phase = "attack"
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 600))
    local ok, err = Phases.validateAttack(m, H.slot("defender", 1), H.slot("striker", 1))
    T.eq(ok, false); T.eq(err, "card is in defense mode")
    -- The opponent's turn: its striker destroys the face-up defense card, no battle damage.
    m.activePlayer = "opponent"
    local lp = m.players.player.lp
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(m.players.player.lp, lp)
    T.eq(m.players.player.pitch.defenders[1], nil)
end)

T.test("switched to defense: its owner may flip it back to attack on their next turn", function()
    local m = H.match({ phase = "summon" })
    local c = H.place(m, "player", "midfielder", 0, H.card("midfielder", 1600, 1500))
    local s = H.store(m)
    T.eq(s:changeMode("midfielder", 0), true)
    Phases.endTurn(m)           -- the player's turn ends
    Phases.endTurn(m)           -- the opponent's turn ends
    m.phase = "summon"
    T.eq(c.modeChanged, false)
    T.eq(s:changeMode("midfielder", 0), true)
    T.eq(c.mode, "attack")
end)

T.test("switch refusals through the store: keeper, played this turn, wrong phase", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "attack")
    local s = H.store(m)
    local ok, err = s:changeMode("keeper", 0)
    T.eq(ok, false); T.eq(err, "keepers and traps never change position")
    local c = H.give(m, "player", H.card("striker", 2000, 600))
    T.eq(s:summonCard(c.id, "striker", 1, "attack"), true)
    ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "played this turn: switch it next turn")
    m.phase = "attack"
    ok, err = s:changeMode("striker", 1)
    T.eq(ok, false); T.eq(err, "wrong phase")
end)

T.test("switch ribbon: FLIP UP, TO ATTACK, TO DEFENSE — or nothing when the rule says no", function()
    T.eq(Card.switchLabel(pc("defense"), "defender", OWN), "FLIP UP")
    T.eq(Card.switchLabel(pc("defense", true), "defender", OWN), "TO ATTACK")
    T.eq(Card.switchLabel(pc("attack"), "defender", OWN), "TO DEFENSE")
    T.eq(Card.switchLabel(pc("defense", true), "keeper", OWN), nil)
    local fresh = pc("attack"); fresh.summonedThisTurn = true
    T.eq(Card.switchLabel(fresh, "striker", OWN), nil)
    T.eq(Card.switchLabel(pc("attack"), "striker", { isOwnTurn = false, phase = "summon" }), nil)
end)

T.test("toasts: a switch to defense says so", function()
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "player", action = "mode_change",
        mode = "defense" } })), "You switched a card to defense")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "opponent", action = "mode_change",
        mode = "attack" } })), "Opp flipped a card face-up")
end)
```

- [ ] **Step 2: `tests/test_revealed_ui.lua`: the ribbon test uses `Card.switchLabel`.** Replace the whole test from the line `T.test("revealed UI: canFlip mirrors the engine rule — never keepers, only the owner's own summon phase", function()` through the `end)` that closes it (the line before `T.test("revealed UI: the zoom says the card is revealed", function()`) with:

```lua
T.test("revealed UI: the switch ribbon mirrors the engine rule — never keepers, only the owner's own summon phase", function()
    local own = { isOwnTurn = true, phase = "summon" }
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", own), "FLIP UP")
    T.eq(Card.switchLabel(pc("defender", "defense", true), "defender", own), "TO ATTACK")
    -- Keepers never switch, even revealed and otherwise eligible.
    T.eq(Card.switchLabel(pc("keeper", "defense", true), "keeper", own), nil)
    -- Attack mode: it may go to face-up defense.
    T.eq(Card.switchLabel(pc("defender", "attack"), "defender", own), "TO DEFENSE")
    local exhausted = pc("defender", "defense"); exhausted.exhausted = true
    T.eq(Card.switchLabel(exhausted, "defender", own), nil)
    local fresh = pc("defender", "defense"); fresh.summonedThisTurn = true
    T.eq(Card.switchLabel(fresh, "defender", own), nil)
    local flipped = pc("defender", "defense"); flipped.modeChanged = true
    T.eq(Card.switchLabel(flipped, "defender", own), nil)
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", { isOwnTurn = true, phase = "attack" }), nil)
    T.eq(Card.switchLabel(pc("defender", "defense"), "defender", { isOwnTurn = false, phase = "summon" }), nil)
    T.eq(Card.switchLabel(pc("trap", "defense", false, "trap"), "trap", own), nil)
end)
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 10 `FAIL` lines: the 9 new `test_modes_switch.lua` tests and the rewritten `revealed UI` test (`Phases.canSwitch` and `Card.switchLabel` don't exist yet).
- The run ends with `421 passed, 10 failed`.

- [ ] **Step 4: `engine/phases.lua`: `canSwitch` and the new `changeMode`.** Replace the whole `Phases.changeMode` function (from `function Phases.changeMode(matchState, slotType, slotIndex)` through its closing `end`, the line before `-- True when a card can declare an attack right now`) with:

```lua
-- Position switch (spec A2): the one rule shared by the engine (Phases.changeMode), the UI
-- (Card.switchLabel) and the AI (AI.canSwitch). Pure: reads the card and ctx only.
--   ctx = { isOwnTurn, phase, halfTimeBreak } — isOwnTurn: the card's owner is the active player.
-- Once per turn per card, in its owner's summon phase: defense (face-down or revealed) →
-- attack, or attack → defense (face-up: revealed). Never keepers or traps; never on the turn
-- the card was played or substituted in, after it attacked this turn, while exhausted,
-- during the half-time break or on the opponent's turn.
-- Returns the mode the card would switch to ("attack" | "defense"), or nil + reason.
function Phases.canSwitch(card, slotType, ctx)
    ctx = ctx or {}
    if not card then return nil, "no card in slot" end
    if slotType == "keeper" or slotType == "trap" or card.slotType == "trap" then
        return nil, "keepers and traps never change position"
    end
    if ctx.halfTimeBreak then return nil, "half-time" end
    if not ctx.isOwnTurn or ctx.phase ~= "summon" then
        return nil, "switch positions in your summon phase"
    end
    if card.summonedThisTurn then return nil, "played this turn: switch it next turn" end
    if card.modeChanged then return nil, "already switched this turn" end
    if card.usedAsAttacker then return nil, "attacked this turn" end
    if card.exhausted then return nil, "exhausted" end
    return card.mode == "attack" and "defense" or "attack"
end

-- Switches the active player's card in a slot (Phases.canSwitch). attack → defense leaves it
-- face-up: revealed, because the opponent has already seen it. Returns true, or false + reason.
function Phases.changeMode(matchState, slotType, slotIndex)
    local activeId = matchState.activePlayer
    local card = Phases._getSlotForPlayer(matchState, activeId, { type = slotType, index = slotIndex })
    local toMode, why = Phases.canSwitch(card, slotType, {
        isOwnTurn = true, phase = matchState.phase, halfTimeBreak = matchState.halfTimeBreak,
    })
    if not toMode then return false, why end
    card.mode        = toMode
    card.modeChanged = true
    if toMode == "defense" then card.revealed = true end
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = activeId, slot = slotType, index = slotIndex, mode = toMode, action = "mode_change" })
    return true
end
```

- [ ] **Step 5: `ui/kit/draw.lua`: a drawn down arrow.** Directly below the `Draw.arrow` function (after the `end` that follows `love.graphics.polygon("fill", cx - dir * h * 0.8, cy - h, …)`), insert:

```lua

-- Solid downward triangle (the fonts have no ▼).
function Draw.arrowDown(cx, cy, size, color, alphaMul)
    local h = size / 2
    Draw.setColor(color or Theme.white, alphaMul)
    love.graphics.polygon("fill", cx - h, cy - h * 0.8, cx + h, cy - h * 0.8, cx, cy + h)
end
```

- [ ] **Step 6: `ui/card.lua`: `Card.switchLabel`, the TO DEFENSE ribbon and `drawPitched`.**

6a. In the header comment, replace

```lua
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, canFlip, pitch, hideHidden, selected, target
```

with

```lua
--   Card.drawPitched(pitched, x, y, opts)   opts: w, h, faceDown, switchLabel, pitch, hideHidden, selected, target
--   Card.switchLabel(pitched, slotType, ctx) position-switch ribbon text or nil (pure, unit-tested)
```

6b. Replace

```lua
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")
```

with

```lua
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")
local Phases = require("engine.phases")
```

6c. Directly above the line that starts with `-- ── Face ──`, insert:

```lua
-- "TO DEFENSE ▼" ribbon on an attack-mode card that may switch (the arrow is drawn: the fonts
-- have no ▼). Same place and size as the revealed card's TO ATTACK ribbon (L.flip).
local function drawToDefense(L, x, y)
    local fh = L.flip.h
    local rw = L.w * 0.9
    local rx = x + (L.w - rw) / 2
    local ry = y + L.flip.y
    Draw.sticker(rx, ry, rw, fh, { r = fh * 0.2, fill = Theme.grad.def, border = 3, shadow = 4 })
    local arrow = fh * 0.55
    local size  = math.floor(fh * 0.6)
    Draw.text("TO DEFENSE", rx + 6, ry + (fh - size) / 2 - size * 0.08, rw - 16 - arrow, "center", {
        size = size, color = Theme.white, fit = true, minSize = 6,
    })
    Draw.arrowDown(rx + rw - 6 - arrow / 2, ry + fh / 2, arrow, Theme.white)
end

```

6d. Replace the whole `Card.canFlip` function and its comment (from `-- True when a pitched card's flip (FLIP UP / TO ATTACK) ribbon may legally appear.` through the `end` of `function Card.canFlip`) with:

```lua
-- Position-switch ribbon for a pitched card: "FLIP UP" (face-down), "TO ATTACK" (revealed
-- defense), "TO DEFENSE" (attack mode), or nil when Phases.canSwitch refuses (the rule the
-- engine uses). ctx: { isOwnTurn, phase, halfTimeBreak }. Pure (unit-tested).
function Card.switchLabel(pitched, slotType, ctx)
    if not Phases.canSwitch(pitched, slotType, ctx) then return nil end
    if pitched.mode == "attack" then return "TO DEFENSE" end
    return pitched.revealed and "TO ATTACK" or "FLIP UP"
end
```

6e. Replace the whole `Card.drawPitched` function (from `function Card.drawPitched(pitched, x, y, opts)` through its closing `end`) with:

```lua
function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h

    if not Card.showsFace(pitched) then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and (pitched.slotType == "trap" and "TRAP" or "DEF") or nil,
            canFlip = opts.switchLabel ~= nil,
            selected = opts.selected, target = opts.target,
        })
        return
    end

    local atkBonus, defBonus = Card.bonuses(pitched, opts.pitch, opts.hideHidden)

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })

    local L = Card.layout(w, h)
    if pitched.mode == "defense" then
        -- Revealed defense-mode card: face-up for both players, with a DEF marker.
        local ph = L.defPill.h
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + L.defPill.y, pw, ph, "DEF", {
            fill = Theme.grad.def, textColor = Theme.white,
            border = math.max(1, math.floor(2 * L.s)), shadow = 0,
        })
        if opts.switchLabel then
            Draw.ribbon(x + w / 2, y + L.flip.y, w * 0.9, L.flip.h, opts.switchLabel, {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    elseif opts.switchLabel then
        drawToDefense(L, x, y)
    end
end
```

- [ ] **Step 7: `ui/pitch.lua`: the ribbon comes from `Card.switchLabel`.**

7a. Replace

```lua
        canFlip  = owner == "player" and
                   Card.canFlip(pitched, slotType, { isOwnTurn = st.activePlayer == "player", phase = st.phase }),
```

with

```lua
        -- Position-switch ribbon (Phases.canSwitch via Card.switchLabel), your cards only.
        switchLabel = owner == "player" and Card.switchLabel(pitched, slotType, {
                          isOwnTurn = st.activePlayer == "player", phase = st.phase,
                          halfTimeBreak = st.halfTimeBreak }) or nil,
```

7b. Replace

```lua
    st.activePlayer = match.activePlayer
```

with

```lua
    st.activePlayer  = match.activePlayer
    st.halfTimeBreak = match.halfTimeBreak
```

- [ ] **Step 8: `ui/match/toasts.lua`.** Replace

```lua
        if p.action == "mode_change" then return who .. " flipped a card face-up", "info" end
```

with

```lua
        if p.action == "mode_change" then
            if p.mode == "defense" then return who .. " switched a card to defense", "info" end
            return who .. " flipped a card face-up", "info"
        end
```

- [ ] **Step 9: `ai/opponent.lua`: the AI reads the same rule.**

9a. Replace the whole `AI.canFlip` function and its comment (from `-- May the AI flip this card of its own now? Mirrors Card.canFlip (ui/card.lua) and the` through the `end` of `function AI.canFlip`) with:

```lua
-- The position the AI may switch this card of its own to now ("attack" | "defense"), or nil:
-- Phases.canSwitch (the engine's rule) on the AI's own view, and not refused this turn.
function AI.canSwitch(match, card, slotType)
    if not card or card.aiRefusedFlipTag == AI.planTag(match) then return nil end
    return (Phases.canSwitch(card, slotType, { isOwnTurn = true, phase = match.phase,
                                                halfTimeBreak = match.halfTimeBreak }))
end
```

9b. In `AI._planFlips`, replace

```lua
        if not card or not card.revealed or not AI.canFlip(match, card, slotType) then return end
```

with

```lua
        if not card or not card.revealed or AI.canSwitch(match, card, slotType) ~= "attack" then return end
```

- [ ] **Step 10: `scenes/match.lua`: clicking your card switches it.** Replace

```lua
            -- Flip defense → attack (no hand card selected, own card in defense mode)
            if match.phase == "summon" and not selectedHandCard and slot.owner == "player" then
                local pitchCard = Match.getCardInSlot(match.players.player.pitch, slot)
                if pitchCard and pitchCard.mode == "defense" then
                    local ok, err = store:changeMode(slot.slotType, slot.slotIndex)
                    if not ok then Match.flash(err or "Cannot flip") end
                    return
                end
            end
```

with

```lua
            -- Switch position (no hand card selected, your own card): FLIP UP / TO ATTACK /
            -- TO DEFENSE, as Phases.canSwitch allows; a refusal says why.
            if match.phase == "summon" and not selectedHandCard and slot.owner == "player"
               and slot.slotType ~= "trap" then
                local pitchCard = Match.getCardInSlot(match.players.player.pitch, slot)
                if pitchCard then
                    local ok, err = store:changeMode(slot.slotType, slot.slotIndex)
                    if not ok then Match.flash(err or "Cannot switch") end
                    return
                end
            end
```

- [ ] **Step 11: `tools/snapshot/card_gallery.lua`: show both ribbons.**

11a. Replace

```lua
    Card.drawPitched({ definition = byId("def-libero"), mode = "defense", revealed = true,
                       slotType = "defender" }, 310, y, { canFlip = true })
```

with

```lua
    Card.drawPitched({ definition = byId("def-libero"), mode = "defense", revealed = true,
                       slotType = "defender" }, 310, y, { switchLabel = "TO ATTACK" })
```

11b. Directly below the line `    Card.drawFace(byId("mid-pressing-monster"), 440, y, 68, 80, {})`, insert:

```lua
    Card.drawPitched({ definition = byId("str-target-man"), mode = "attack", slotType = "striker" },
        530, y, { switchLabel = "TO DEFENSE" })
```

- [ ] **Step 12: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/phases.lua ui/card.lua ui/kit/draw.lua ui/pitch.lua ui/match/toasts.lua ai/opponent.lua scenes/match.lua tools/snapshot/card_gallery.lua && lua tests/run.lua`
Expected: no `luac` output; `431 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`, with no Lua error.

- [ ] **Step 13: Snapshots**

Run: `tools/snapshot/snap.sh keywords && tools/snapshot/snap.sh revealed`

Check with the Read tool:
- **`keywords_gallery`:**
  - the revealed Libero shows the green `TO ATTACK` ribbon;
  - the Target Man at x≈530 shows a blue `TO DEFENSE` ribbon with a drawn white down-arrow at its right end;
  - neither ribbon covers the keyword pill or the badges.
- **`revealed_board`:**
  - your revealed Rock shows `TO ATTACK`;
  - your face-down Stopper and midfielder show `FLIP UP`;
  - your revealed keeper and your exhausted revealed striker show no ribbon;
  - the opponent's cards show no ribbon.

- [ ] **Step 14: Commit**

```bash
ls luac.out
git add engine/phases.lua ui/card.lua ui/kit/draw.lua ui/pitch.lua ui/match/toasts.lua ai/opponent.lua scenes/match.lua tools/snapshot/card_gallery.lua tests/test_revealed_ui.lua tests/test_modes_switch.lua
git commit -m "Card modes: switch positions both ways once per turn through one canSwitch rule (TO DEFENSE ribbon)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **431**.

---

### Task 2: The mode picker replaces the toggle and the `M` key (spec A1)

**Files:**
- Create: `ui/match/modepicker.lua`
- Modify: `scenes/match.lua`, `ui/match/bottombar.lua`, `ui/match/layout.lua`, `tests/test_match_layout.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_modepicker.lua` (create)

- [ ] **Step 1: Write `tests/test_modepicker.lua`.**

```lua
local T          = require("tests.t")
local ModePicker = require("ui.match.modepicker")
local Layout     = require("ui.match.layout")

local function slot(slotType, index)
    local r = Layout.slot("player", slotType, index)
    return { x = r.x, y = r.y, w = r.w, h = r.h, slotType = slotType, slotIndex = index, owner = "player" }
end

T.test("mode picker: field cards and keepers choose; traps and strategies don't", function()
    T.eq(ModePicker.needsPicker({ type = "striker" }), true)
    T.eq(ModePicker.needsPicker({ type = "midfielder" }), true)
    T.eq(ModePicker.needsPicker({ type = "defender" }), true)
    T.eq(ModePicker.needsPicker({ type = "keeper" }), true)
    T.eq(ModePicker.needsPicker({ type = "trap" }), false)
    T.eq(ModePicker.needsPicker({ type = "strategy" }), false)
    T.eq(ModePicker.needsPicker(nil), false)
end)

T.test("mode picker: a keeper's choice is permanent and the picker says so", function()
    T.eq(ModePicker.open({ id = "k", type = "keeper" }, slot("keeper", 0)).note, "Keepers never flip later")
    T.eq(ModePicker.open({ id = "d", type = "defender" }, slot("keeper", 0)).note, "Keepers never flip later")
    T.eq(ModePicker.open({ id = "s", type = "striker" }, slot("striker", 1)).note, nil)
    local p = ModePicker.open({ id = "s", type = "striker" }, slot("striker", 1), true)
    T.eq(p.cardId, "s"); T.eq(p.free, true)
end)

T.test("mode picker: anchored on the slot, on screen, two stacked buttons inside the panel", function()
    for _, s in ipairs(Layout.slots()) do
        if s.owner == "player" then
            for _, def in ipairs({ { id = "x", type = "striker" }, { id = "k", type = "keeper" } }) do
                local r = ModePicker.rects(ModePicker.open(def, s))
                local P = r.panel
                T.ok(P.x >= 0 and P.y >= 0 and P.x + P.w <= Layout.W and P.y + P.h <= Layout.H, "on screen")
                T.near(P.x + P.w / 2, s.x + s.w / 2, 0.5, "centred on the slot")
                T.near(P.y + P.h / 2, s.y + s.h / 2, 0.5, "centred on the slot")
                for _, b in ipairs({ r.attack, r.defense }) do
                    T.ok(b.x >= P.x and b.y >= P.y and b.x + b.w <= P.x + P.w and b.y + b.h <= P.y + P.h,
                        "button inside the panel")
                end
                T.ok(r.defense.y >= r.attack.y + r.attack.h, "stacked, no overlap")
            end
        end
    end
end)

T.test("mode picker: clicks map to ATTACK, DEFEND, inside the panel, or outside", function()
    local p = ModePicker.open({ id = "x", type = "striker" }, slot("striker", 1))
    local r = ModePicker.rects(p)
    local function c(b) return b.x + b.w / 2, b.y + b.h / 2 end
    T.eq(ModePicker.actionAt(p, c(r.attack)), "attack")
    T.eq(ModePicker.actionAt(p, c(r.defense)), "defense")
    T.eq(ModePicker.actionAt(p, r.panel.x + 2, r.panel.y + 2), "inside")
    T.eq(ModePicker.actionAt(p, 5, 795), "outside")
end)

T.test("mode picker: A attacks, D defends, Esc cancels", function()
    T.eq(ModePicker.keyAction("a"), "attack")
    T.eq(ModePicker.keyAction("d"), "defense")
    T.eq(ModePicker.keyAction("escape"), "cancel")
    T.eq(ModePicker.keyAction("m"), nil)
end)
```

- [ ] **Step 2: `tests/test_match_layout.lua`: the toggle is gone.**

2a. Replace

```lua
        B.portrait, B.deck, B.deckCount, B.summons, B.toggle, B.startAttack, B.endTurn, B.hint, B.hand,
```

with

```lua
        B.portrait, B.deck, B.deckCount, B.summons, B.startAttack, B.endTurn, B.hint, B.hand,
```

2b. Replace

```lua
    x, y = c(Layout.toggleHalf("attack"));  T.eq(Layout.buttonAt(x, y, "summon"), "modeAttack")
    x, y = c(Layout.toggleHalf("defense")); T.eq(Layout.buttonAt(x, y, "summon"), "modeDefense")
```

with

```lua
    T.eq(Layout.bottom.toggle, nil, "the ATTACK/DEFENSE toggle is gone (mode picker)")
    T.eq(Layout.toggleHalf, nil)
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- `FAIL  tests/test_modepicker.lua (load error)`;
- `FAIL  buttonAt maps clicks to actions` (the toggle still exists);
- the run ends with `430 passed, 2 failed`.

- [ ] **Step 4: Create `ui/match/modepicker.lua`.**

```lua
-- Mode picker (spec A1): after a card from the hand is dropped on a slot, a small panel
-- anchored on that slot asks ATTACK (face-up) or DEFEND (face-down). Keys: A, D, Esc (cancel:
-- the card stays selected, nothing is placed). Traps skip it (always face-down). Keepers get
-- a note: they never flip later. Substitutions use the same picker. Everything except
-- ModePicker.draw is pure (unit-tested).
local Theme  = require("ui.theme")
local Draw   = require("ui.kit.draw")
local Layout = require("ui.match.layout")

local ModePicker = {}

ModePicker.W      = 164
ModePicker.BTN_H  = 44
ModePicker.PAD    = 10
ModePicker.GAP    = 8
ModePicker.NOTE_H = 30
ModePicker.MARGIN = 8
ModePicker.KEEPER_NOTE = "Keepers never flip later"

-- True when placing cardDef needs a mode choice: field cards and keepers; not traps (always
-- face-down) or strategies (never placed).
function ModePicker.needsPicker(cardDef)
    local t = cardDef and cardDef.type
    return t == "striker" or t == "midfielder" or t == "defender" or t == "keeper"
end

-- Note under the buttons, or nil. A keeper (card or slot) keeps its mode for good.
function ModePicker.note(cardDef, slotType)
    if (cardDef and cardDef.type == "keeper") or slotType == "keeper" then return ModePicker.KEEPER_NOTE end
    return nil
end

-- A picker for placing cardDef on slot (a pitch hitbox { x, y, w, h, slotType, slotIndex }).
-- free: the Substitution card's free placement (store:freeSummon).
function ModePicker.open(cardDef, slot, free)
    return { cardId = cardDef.id, cardDef = cardDef, slot = slot, free = free == true,
             note = ModePicker.note(cardDef, slot.slotType) }
end

-- { panel, attack, defense, note } rects: the panel centred on the slot, kept on screen.
function ModePicker.rects(p)
    local P = ModePicker
    local h = P.PAD * 2 + P.BTN_H * 2 + P.GAP + (p.note and P.NOTE_H or 0)
    local s = p.slot
    local x = s.x + s.w / 2 - P.W / 2
    local y = s.y + s.h / 2 - h / 2
    x = math.max(P.MARGIN, math.min(Layout.W - P.MARGIN - P.W, x))
    y = math.max(P.MARGIN, math.min(Layout.H - P.MARGIN - h, y))
    local bw = P.W - P.PAD * 2
    return {
        panel   = { x = x, y = y, w = P.W, h = h },
        attack  = { x = x + P.PAD, y = y + P.PAD, w = bw, h = P.BTN_H },
        defense = { x = x + P.PAD, y = y + P.PAD + P.BTN_H + P.GAP, w = bw, h = P.BTN_H },
        note    = p.note and { x = x + P.PAD, y = y + P.PAD + P.BTN_H * 2 + P.GAP, w = bw, h = P.NOTE_H }
                  or nil,
    }
end

-- "attack" | "defense" for a click on a button, "inside" elsewhere on the panel, "outside".
function ModePicker.actionAt(p, x, y)
    local r = ModePicker.rects(p)
    if Layout.inRect(x, y, r.attack) then return "attack" end
    if Layout.inRect(x, y, r.defense) then return "defense" end
    if Layout.inRect(x, y, r.panel) then return "inside" end
    return "outside"
end

-- "attack" (A) | "defense" (D) | "cancel" (Esc) | nil.
function ModePicker.keyAction(key)
    if key == "a" then return "attack" end
    if key == "d" then return "defense" end
    if key == "escape" then return "cancel" end
    return nil
end

local function button(r, label, sub, fill, hover)
    Draw.sticker(r.x, r.y, r.w, r.h, { r = 12, fill = fill, border = 3, shadow = hover and 5 or 3 })
    Draw.text(label, r.x, r.y + 5, r.w, "center", { size = 20, color = Theme.white, shadowY = 2 })
    Draw.text(sub, r.x, r.y + 27, r.w, "center", { size = 11, body = true, color = { 1, 1, 1, 0.9 } })
end

-- Draws the picker; mx, my: the mouse (the hovered button lifts).
function ModePicker.draw(p, mx, my)
    local r = ModePicker.rects(p)
    mx, my = mx or -1, my or -1
    Draw.sticker(r.panel.x, r.panel.y, r.panel.w, r.panel.h, { r = 16, fill = Theme.white, border = 4, shadow = 6 })
    button(r.attack, "ATTACK", "face-up  ·  A", Theme.grad.atk, Layout.inRect(mx, my, r.attack))
    button(r.defense, "DEFEND", "face-down  ·  D", Theme.grad.def, Layout.inRect(mx, my, r.defense))
    if r.note then
        Draw.text(p.note, r.note.x, r.note.y + 8, r.note.w, "center",
            { size = 12, body = true, color = Theme.inkText, fit = true, minSize = 9 })
    end
end

return ModePicker
```

- [ ] **Step 5: `ui/match/layout.lua`: remove the toggle.**

5a. Replace

```lua
    summons     = { x = 996, y = 552, w = 240, h = 34 },
    toggle      = { x = 996, y = 598, w = 240, h = 42 },
```

with

```lua
    summons     = { x = 996, y = 552, w = 240, h = 34 },
```

5b. Delete the whole `Layout.toggleHalf` function and its comment, from `-- One half of the ATTACK/DEFENSE segmented toggle.` through its closing `end`, plus the blank line after it.

5c. Replace

```lua
-- Button under (x, y): pause|music|log|endTurn|startAttack|modeAttack|modeDefense|nil.
```

with

```lua
-- Button under (x, y): pause|music|log|endTurn|startAttack|nil.
```

5d. Delete these two lines from `Layout.buttonAt`:

```lua
    if Layout.inRect(x, y, Layout.toggleHalf("attack"))  then return "modeAttack" end
    if Layout.inRect(x, y, Layout.toggleHalf("defense")) then return "modeDefense" end
```

- [ ] **Step 6: `ui/match/bottombar.lua`: remove the toggle.**

6a. Replace the first two comment lines

```lua
-- Match bottom area (y 540–800) except the hand: portrait, deck pile, toast stack,
-- SUMMONS pill, ATTACK/DEFENSE toggle, START ATTACK / END TURN and the hint line.
```

with

```lua
-- Match bottom area (y 540–800) except the hand: portrait, deck pile, toast stack,
-- SUMMONS pill, START ATTACK / END TURN and the hint line. (The mode is chosen on the slot:
-- ui/match/modepicker.lua.)
```

6b. Delete the whole `local function drawToggle(mode)` function, from that line through its closing `end`, plus the blank line after it.

6c. Replace

```lua
-- st = { mode = "attack"|"defense", toasts = Toasts instance, hint = string }
```

with

```lua
-- st = { toasts = Toasts instance, hint = string }
```

6d. Delete the line `    drawToggle(st.mode)`.

- [ ] **Step 7: `scenes/match.lua`: the picker flow.**

7a. Replace

```lua
local Zoom          = require("ui.match.zoom")
```

with

```lua
local Zoom          = require("ui.match.zoom")
local ModePicker    = require("ui.match.modepicker")
```

7b. Replace

```lua
local selectedHandCard     = nil
local selectedAttackerSlot = nil
local selectedMode         = "attack"
```

with

```lua
local selectedHandCard     = nil
local selectedAttackerSlot = nil

-- Mode picker (ui/match/modepicker.lua): open after a field card is dropped on a slot.
local picker = nil
```

7c. In `Match.enter`, replace `    selectedMode        = "attack"` with `    picker              = nil`.

7d. In `Match.draw`, replace

```lua
    BottomBar.draw(match, { mode = selectedMode, toasts = toasts, hint = Match.hintText(match) })
```

with

```lua
    BottomBar.draw(match, { toasts = toasts, hint = Match.hintText(match) })
```

and replace

```lua
    if promptWindow or winT or match.halfTimeBreak then hmx, hmy = nil, nil end
```

with

```lua
    if promptWindow or winT or match.halfTimeBreak or picker then hmx, hmy = nil, nil end
```

7e. In `Match.draw`, directly above the line `    -- Card zoom`, insert:

```lua
    -- Mode picker, on the slot the selected card was dropped on
    if picker then ModePicker.draw(picker, mouseX, mouseY) end

```

7f. In `Match.hoverTarget`, replace

```lua
       or match.winner or store.coverWindow or store.trapWindow or match.halfTimeBreak then
```

with

```lua
       or match.winner or store.coverWindow or store.trapWindow or match.halfTimeBreak or picker then
```

7g. In `Match.hintText`, replace the whole summon branch, from `    if match.phase == "summon" then` through `        return "Select a card  ·  M toggles ATTACK / DEFENSE  ·  START ATTACK or END TURN"`, with:

```lua
    if match.phase == "summon" then
        if picker then
            return "ATTACK (A) face-up  ·  DEFEND (D) face-down  ·  ESC to cancel"
        elseif selectedHandCard and selectedHandCard.ability == "SUBSTITUTION" then
            return "SUBSTITUTION: click a pitched card to return it to hand"
        elseif substitutionFreedSlot then
            return "SUBSTITUTION: select a card and place it in the freed slot (free)"
        elseif selectedHandCard and selectedHandCard.type == "trap" then
            return "Click a TRAP slot by your goal to set it face-down  ·  ESC to cancel"
        elseif selectedHandCard and Phases.canKeeperSwap(match, selectedHandCard) then
            return "Click your GK to bring this keeper on (uses a summon)"
        elseif selectedHandCard then
            return "Click a glowing slot, then choose ATTACK or DEFEND  ·  ESC to cancel"
        end
        return "Select a card  ·  Click your card to switch position  ·  START ATTACK or END TURN"
```

7h. In `Match.mousepressed`, replace

```lua
    local match = store and store.match
    if not match or match.winner then return end

    local btn = Layout.buttonAt(x, y, match.phase)
```

with

```lua
    local match = store and store.match
    if not match or match.winner then return end

    -- Mode picker open: a button places the card; a click outside cancels (the card stays
    -- selected, nothing is placed); a click elsewhere on the panel does nothing.
    if picker then
        local a = ModePicker.actionAt(picker, x, y)
        if a == "attack" or a == "defense" then Match.confirmPlace(a)
        elseif a == "outside" then picker = nil end
        return
    end

    local btn = Layout.buttonAt(x, y, match.phase)
```

7i. Delete these two lines:

```lua
    if btn == "modeAttack"  then selectedMode = "attack";  return end
    if btn == "modeDefense" then selectedMode = "defense"; return end
```

7j. Replace the whole placement block, from `            -- Summon: card flies from the hand, then squash-pops into its slot` through its closing `            end` (the line before `            -- Attack phase: select attacker`), with:

```lua
            -- Place a hand card on a glowing slot of yours: a trap goes straight in
            -- (face-down); a field card opens the mode picker on the slot.
            if match.phase == "summon" and selectedHandCard and slot.owner == "player" then
                if not Match.slotAccepts(match, slot) then return end
                if ModePicker.needsPicker(selectedHandCard) then
                    picker = ModePicker.open(selectedHandCard, slot, substitutionFreedSlot ~= nil)
                else
                    Match.placeCard(selectedHandCard, slot, "defense", false)
                end
                return
            end
```

7k. In `Match.keypressed`, replace

```lua
    if store and store.coverWindow then return nil end
```

with

```lua
    if store and store.coverWindow then return nil end

    -- Mode picker: A / D place the card, Esc cancels (the card stays selected).
    if picker then
        local a = ModePicker.keyAction(key)
        if a == "attack" or a == "defense" then Match.confirmPlace(a)
        elseif a == "cancel" then picker = nil end
        return nil
    end
```

and delete the line

```lua
    if key == "m"   then selectedMode = selectedMode == "attack" and "defense" or "attack"; return nil end
```

7l. In `Match.openHalfTime`, replace `    scoutPending          = false` with:

```lua
    scoutPending          = false
    picker                = nil
```

7m. Directly above the line `function Match.getCardInSlot(pitch, slot)`, insert:

```lua
-- True when the selected hand card may be placed on this slot of yours now (it glows).
function Match.slotAccepts(match, slot)
    for _, s in ipairs(Match.getHighlightedSlots(match)) do
        if s.owner == slot.owner and s.slotType == slot.slotType and s.slotIndex == slot.slotIndex then
            return true
        end
    end
    return false
end

-- Places cardDef from your hand on slot in mode: store:summonCard, or store:freeSummon for the
-- Substitution card's free placement. The card flies from the hand, then squash-pops into its
-- slot. A refusal is flashed. The hand selection is cleared either way. Returns true on success.
function Match.placeCard(cardDef, slot, mode, free)
    local match = store.match
    local r = Hand.rectOf(handHit, cardDef.id)
    local srcX = r and r.x or slot.x
    local srcY = r and r.y or slot.y
    local ok, err
    if free then
        ok, err = store:freeSummon(cardDef.id, slot.slotType, slot.slotIndex, mode)
        if ok then substitutionFreedSlot = nil end
    else
        ok, err = store:summonCard(cardDef.id, slot.slotType, slot.slotIndex, mode)
    end
    selectedHandCard = nil
    if not ok then
        if err then Match.flash(err) end
        return false
    end
    Audio.play("card_summon")
    -- Traps fill the first free trap slot, not necessarily the one clicked.
    local idx, dest = slot.slotIndex, slot
    if slot.slotType == "trap" then
        idx  = #match.players.player.pitch.traps
        dest = Layout.trapSlot("player", idx)
    end
    local key = Pitch.slotKey("player", slot.slotType, idx)
    pitchAnims.hidden[key] = true
    local fc = { cardDef = cardDef, x = srcX, y = srcY, w = dest.w, h = dest.h, mode = mode }
    flux.to(fc, 0.30, { x = dest.x, y = dest.y }):ease("quadout"):oncomplete(function()
        for ii, c in ipairs(flyingCards) do
            if c == fc then table.remove(flyingCards, ii); break end
        end
        pitchAnims.hidden[key] = nil
        local pop = { sx = 1, sy = 1 }
        pitchAnims.pop[key] = pop
        Tween.squash(pop, 0.35):oncomplete(function()
            if pitchAnims.pop[key] == pop then pitchAnims.pop[key] = nil end
        end)
    end)
    table.insert(flyingCards, fc)
    return true
end

-- The mode picker's choice: place the picked card in that mode.
function Match.confirmPlace(mode)
    local p = picker
    picker = nil
    if not p then return end
    Match.placeCard(p.cardDef, p.slot, mode, p.free)
end

```

- [ ] **Step 8: `tools/snapshot/scenarios.lua`: scenarios that placed cards now go through the picker.**

8a. In `S.summon`, replace the comment

```lua
-- Summon a keeper + one field card, start the attack phase, select an attacker,
-- end the turn and let the AI play.
```

with

```lua
-- Summon a keeper (picker: D) + one field card (picker: A), start the attack phase, select an
-- attacker, end the turn and let the AI play.
```

and replace

```lua
    { 2.7,  function() click(center(Layout.slot("player", "keeper", 0))) end },
```

with

```lua
    { 2.7,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 2.8,  function() love.keypressed("d") end },
```

and replace

```lua
    { 4.1,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
```

with

```lua
    { 4.1,  function() local r = fieldSlot(picked.field); if r then click(center(r)) end end },
    { 4.2,  function() if picked.field then love.keypressed("a") end end },
```

8b. In `S.juice`, replace

```lua
    { 4.0,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 4.05, function() move(640, 300) end },                  -- keep the zoom off the pop shot
```

with

```lua
    { 4.0,  function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 4.03, function() love.keypressed("d") end },            -- the mode picker
    { 4.06, function() move(640, 300) end },                  -- keep the zoom off the pop shot
```

8c. Replace the whole `S.keeperswap` table and its comment (from `-- Keeper substitution: Reliable Hands in goal (harness-only), The Wall in hand. Select it` through the closing `}` of `S.keeperswap`) with:

```lua
-- Keeper substitution: Reliable Hands in goal (harness-only), The Wall in hand. Select it
-- (your GK glows, hint), click the GK: the picker opens with the keeper note; D brings The
-- Wall on face-down, Reliable Hands goes to hand.
local swapGk
S.keeperswap = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local st = store()
        st.match.players.player.pitch.keeper = pitched("keeper-reliable-hands", "keeper", "defense")
        swapGk = defById("keeper-the-wall")
        table.insert(hand(), swapGk)
    end },
    { 1.8, function() move(handPoint(swapGk)) end },
    { 2.0, function() press(handPoint(swapGk)) end },
    { 2.2, function() move(640, 300) end },
    { 2.6, function(c) c.snap("before") end },
    { 2.7, function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 2.9, function(c) c.snap("picker") end },
    { 3.0, function() love.keypressed("d") end },
    { 3.1, function() move(640, 300) end },
    { 3.8, function(c) c.snap("after") end },
    { 4.0, function(c) c.quit() end },
}

-- Card modes (spec A1/A2): select a striker, click a striker slot: the mode picker opens on
-- the slot; A places it face-up. A harness-built attack-mode midfielder shows TO DEFENSE;
-- clicking it switches it to face-up defense (DEF pill, no ribbon). A keeper's picker shows
-- the note; Esc cancels and the keeper stays selected.
local modeCard, modeKeeper
S.modes = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        store().match.players.player.pitch.midfielder = pitched("mid-box-to-box", "midfielder")
        modeCard = defById("str-poacher")
        table.insert(hand(), modeCard)
        modeKeeper = firstOf({ "keeper" })
    end },
    { 1.8, function() move(handPoint(modeCard)) end },
    { 2.0, function() press(handPoint(modeCard)) end },
    { 2.2, function() click(center(Layout.slot("player", "striker", 1))) end },
    { 2.6, function(c) c.snap("picker") end },
    { 2.7, function() love.keypressed("a") end },
    { 2.8, function() move(640, 60) end },
    { 3.5, function(c) c.snap("placed") end },
    { 3.6, function() click(center(Layout.slot("player", "midfielder", 0))) end },
    { 3.7, function() move(640, 60) end },
    { 4.1, function(c) c.snap("switched") end },
    { 4.2, function() move(handPoint(modeKeeper)) end },
    { 4.4, function() press(handPoint(modeKeeper)) end },
    { 4.6, function() click(center(Layout.slot("player", "keeper", 0))) end },
    { 5.0, function(c) c.snap("keeper") end },
    { 5.1, function() love.keypressed("escape") end },
    { 5.2, function() move(640, 60) end },
    { 5.6, function(c) c.snap("cancel") end },
    { 5.8, function(c) c.quit() end },
}
```

- [ ] **Step 9: Run the tests, the syntax check and the smoke run**

Run: `luac -p ui/match/modepicker.lua ui/match/layout.lua ui/match/bottombar.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `436 passed, 0 failed`.

Run: `grep -n "selectedMode\|toggleHalf\|modeAttack\|modeDefense" scenes/match.lua ui/match/*.lua`
Expected: no output.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 10: Snapshots**

Run: `for s in modes summon juice keeperswap; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`

Check with the Read tool:
- **`modes_picker`:**
  - a white panel sits centred on your first striker slot, with a red ATTACK button ("face-up · A") above a blue DEFEND button ("face-down · D");
  - there is no note;
  - the bottom bar has no ATTACK/DEFENSE toggle;
  - the hint reads "ATTACK (A) face-up · DEFEND (D) face-down · ESC to cancel".
- **`modes_placed`:**
  - The Poacher is face-up in striker slot 1 with no ribbon (played this turn);
  - the Box-to-Box midfielder shows the blue `TO DEFENSE ▼` ribbon.
- **`modes_switched`:** the midfielder is face-up with the blue `DEF` pill and no ribbon; a toast reads "You switched a card to defense".
- **`modes_keeper`:** the picker sits on the GK slot with the note "Keepers never flip later" under the buttons, and nothing overlaps the screen edge.
- **`modes_cancel`:** the picker is gone, the keeper card is still selected (raised in the hand) and the GK slot still glows.
- **`summon_placed`:** your keeper is face-down in goal (DEF label).
- **`summon_two`:** the field card is face-up in its slot.
- **`juice_pop`:** the keeper back squash-pops into the GK slot.
- **`juice_popdone`:** the keeper back is settled in the GK slot.
- **`keeperswap_picker`:** the picker with the keeper note sits on the GK slot.
- **`keeperswap_after`:** The Wall is in goal face-down and Reliable Hands is in the hand.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add ui/match/modepicker.lua ui/match/layout.lua ui/match/bottombar.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_modepicker.lua tests/test_match_layout.lua
git commit -m "Card modes: choose ATTACK or DEFEND in a picker on the slot; remove the toggle and the M key" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **436**.

---

### Task 3: AI position switching (spec A2, AI)

**Files:**
- Modify: `ai/opponent.lua`
- Test: `tests/test_ai_switch.lua` (create)

- [ ] **Step 1: Write `tests/test_ai_switch.lua`.**

```lua
local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

local function switches(acts)
    local out = {}
    for _, a in ipairs(acts) do if a.type == "toDefense" then out[#out + 1] = a end end
    return out
end

-- The AI's summon phase with a keeper in goal and nothing in hand.
local function aiTurn()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    return m
end

T.test("AI switch: a weak midfielder the enemy midfielder would beat goes to face-up defense", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    local mid = H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1); T.eq(sw[1].slotType, "midfielder")
    AI.executeAction(H.store(m), sw[1])
    T.eq(mid.mode, "defense"); T.eq(mid.revealed, true)
end)

T.test("AI switch: a defender that can't beat any striker, facing a stronger one, pulls back", function()
    local m = aiTurn()
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 1000, 1600))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 1200))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1); T.eq(sw[1].slotType, "defender"); T.eq(sw[1].slotIndex, 1)
end)

T.test("AI switch: stays in attack when nothing beats it, when it wins a fight, and for strikers", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1200, 1000))
    T.eq(#switches(AI._planSummons(m)), 0, "not exposed")

    m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1700, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    T.eq(#switches(AI._planSummons(m)), 0, "it wins a fight this turn")

    m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 1500, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1900))
    T.eq(#switches(AI._planSummons(m)), 0, "a striker-slot card that isn't tired stays")
end)

T.test("AI switch: never pulls back the only card covering an open defender slot", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")   -- slot 2 open
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    T.eq(#switches(AI._planSummons(m)), 0)
end)

T.test("AI switch: a refused switch is not planned again this turn", function()
    local m = aiTurn()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1200, 1300))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1800, 1500))
    local sw = switches(AI._planSummons(m))
    T.eq(#sw, 1)
    m.phase = "attack"                      -- the store refuses outside the summon phase
    local _, _, err = AI.executeAction(H.store(m), sw[1])
    T.ok(err ~= nil)
    m.phase = "summon"
    T.eq(#switches(AI._planSummons(m)), 0)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 3 `FAIL` lines: `AI switch: a weak midfielder …`, `AI switch: a defender that can't beat …` and `AI switch: a refused switch …` (no `toDefense` action exists yet);
- the run ends with `438 passed, 3 failed`.

- [ ] **Step 3: `ai/opponent.lua`: execute both kinds of switch.** Replace

```lua
    elseif action.type == "flip" then
        -- Face-up defence -> attack mode (Phases.changeMode). Refused: tag the card so
        -- _planFlips doesn't plan the same flip again this turn.
```

with

```lua
    elseif action.type == "flip" or action.type == "toDefense" then
        -- A position switch (Phases.changeMode): defence → attack ("flip") or attack →
        -- face-up defence ("toDefense"). Refused: tag the card so the planners don't plan it
        -- again this turn.
```

- [ ] **Step 4: `ai/opponent.lua`: plan the switches after the flips.** Replace

```lua
    -- Flips after the summons, so they see the slots this turn's summons fill.
    for _, f in ipairs(AI._planFlips(match, used)) do table.insert(actions, f) end
```

with

```lua
    -- Flips after the summons, so they see the slots this turn's summons fill; then pulls
    -- back to defence (AI._planSwitches).
    for _, f in ipairs(AI._planFlips(match, used)) do table.insert(actions, f) end
    for _, sw in ipairs(AI._planSwitches(match, used)) do table.insert(actions, sw) end
```

- [ ] **Step 5: `ai/opponent.lua`: `AI._winsNow`, directly below the local `evalFight`.** Directly above the line `-- Flips planned for this summon phase (see _planSummons; `used` holds the slots filled by`, insert:

```lua
-- True when this AI card, attacking from slotType now, beats a face-up target it may attack
-- (a defender-slot card against an enemy striker, the midfielder against the enemy
-- midfielder). False on the opening turn of a half (no attacks) and for other slots.
function AI._winsNow(match, card, slotType)
    if State.isOpeningTurn(match) then return false end
    local pitch, ePitch = match.players.opponent.pitch, match.players.player.pitch
    local atk = Combat.attackStat(card, slotType, pitch, ePitch)
    if slotType == "midfielder" then
        return evalFight(atk, ePitch.midfielder, "midfielder", ePitch) == "win"
    end
    if slotType == "defender" then
        for i = 1, C.PITCH.MAX_STRIKERS do
            if evalFight(atk, ePitch.strikers[i], "striker", ePitch) == "win" then return true end
        end
    end
    return false
end

```

- [ ] **Step 6: `ai/opponent.lua`: `_planFlips` uses `_winsNow`.** Replace the whole `AI._planFlips` function (from `function AI._planFlips(match, used)` through its closing `end`) with:

```lua
function AI._planFlips(match, used)
    local pitch = match.players.opponent.pitch
    local out   = {}

    local function consider(card, slotType, slotIndex)
        if not card or not card.revealed or AI.canSwitch(match, card, slotType) ~= "attack" then return end
        if card.cannotActNextTurn then return end   -- locked: it can neither cover nor attack
        local covers = AI._defenderGap(used) and not used.coverer
                       and (slotType == "midfielder"
                            or (Resolver.canCoverSlot(card, "defender", "defender")
                                and not Resolver.coversInDefense(card, "defender", "defender")))
        if covers or AI._winsNow(match, card, slotType) then
            table.insert(out, { type = "flip", slotType = slotType, slotIndex = slotIndex })
            if covers then used.coverer = true end
        end
    end

    consider(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do consider(pitch.defenders[i], "defender", i) end
    return out
end

-- ── Position switches to defence (spec A2) ────────────────────────────────────

-- The strongest ATK the enemy's face-up, attack-mode cards could bring against the AI card in
-- slotType on the enemy's next turn, from the AI's view (visible bonuses). Enemy strikers
-- attack the defender slots (and the midfielder slot while the AI has no defender), the enemy
-- midfielder attacks the midfielder slot, enemy defenders attack the striker slots. Locked
-- cards (cannotActNextTurn) are left out. 0 when nothing threatens it.
function AI._threatAgainst(match, slotType)
    local pitch  = match.players.opponent.pitch
    local ePitch = match.players.player.pitch
    local best = 0
    local function consider(c, eSlot)
        if c and c.mode == "attack" and not c.cannotActNextTurn then
            local atk = Combat.attackStat(c, eSlot, ePitch, pitch, nil, true)
            if atk > best then best = atk end
        end
    end
    local hasDefender = false
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if pitch.defenders[i] then hasDefender = true end
    end
    if slotType == "defender" or (slotType == "midfielder" and not hasDefender) then
        for i = 1, C.PITCH.MAX_STRIKERS do consider(ePitch.strikers[i], "striker") end
    end
    if slotType == "midfielder" then consider(ePitch.midfielder, "midfielder") end
    if slotType == "striker" then
        for i = 1, C.PITCH.MAX_DEFENDERS do consider(ePitch.defenders[i], "defender") end
    end
    return best
end

-- Weak: no winning attack this turn. A striker-slot card is never weak here (it shoots or
-- clears defenders).
function AI._weak(match, card, slotType)
    if slotType == "striker" then return false end
    return not AI._winsNow(match, card, slotType)
end

-- True when `card` (in slotType) is the only ready card covering an empty defender slot (see
-- AI._hasDefenderCoverer): switching it to defence would leave the gap uncovered.
function AI._soleCoverer(pitch, card, slotType)
    local function ready(c) return c and not c.exhausted and not c.cannotActNextTurn end
    local function coversGap(c, st)
        if not ready(c) then return false end
        if st == "midfielder" then return c.mode == "attack" end
        if st == "defender" then
            return (c.mode == "attack" or Resolver.coversInDefense(c, "defender", "defender"))
                   and Resolver.canCoverSlot(c, "defender", "defender")
        end
        if st == "keeper" then return Resolver.canCoverSlot(c, "keeper", "defender") end
        return false
    end
    if not coversGap(card, slotType) then return false end
    if pitch.midfielder ~= card and coversGap(pitch.midfielder, "midfielder") then return false end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = pitch.defenders[i]
        if d ~= card and coversGap(d, "defender") then return false end
    end
    return not coversGap(pitch.keeper, "keeper")
end

-- Switches to defence planned for this summon phase. An attack-mode AI card (never a keeper)
-- goes to face-up defence when it may switch (AI.canSwitch) and both hold:
--   exposed: an enemy card could attack it next turn with more ATK than its DEF (it would be
--            destroyed; in defence mode that costs no LP);
--   weak:    AI._weak.
-- Never the card that alone covers an open defender slot.
function AI._planSwitches(match, used)
    local pitch = match.players.opponent.pitch
    local out = {}
    local function consider(card, slotType, slotIndex)
        if not card or card.mode ~= "attack" then return end
        if AI.canSwitch(match, card, slotType) ~= "defense" then return end
        local def = Combat.defendStat(card, slotType, pitch, false)
        if AI._threatAgainst(match, slotType) <= def then return end
        if not AI._weak(match, card, slotType) then return end
        if AI._defenderGap(used) and AI._soleCoverer(pitch, card, slotType) then return end
        table.insert(out, { type = "toDefense", slotType = slotType, slotIndex = slotIndex })
    end
    for i = 1, C.PITCH.MAX_STRIKERS do consider(pitch.strikers[i], "striker", i) end
    consider(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do consider(pitch.defenders[i], "defender", i) end
    return out
end
```

- [ ] **Step 7: Run the tests, the syntax check and the smoke run**

Run: `luac -p ai/opponent.lua && lua tests/run.lua`
Expected: no `luac` output; `441 passed, 0 failed` (every older `AI flip` test still passes).

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 8: Commit**

```bash
ls luac.out
git add ai/opponent.lua tests/test_ai_switch.lua
git commit -m "AI: pull a weak, exposed attack-mode card back to face-up defense" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **441**.

---

### Task 4: Stamina data and drain (spec B1, B3)

**Files:**
- Create: `engine/stamina.lua`
- Modify: `engine/constants.lua`, `engine/state.lua`, `engine/phases.lua`, `engine/cards/resolver.lua`
- Test: `tests/test_stamina.lua` (create)

- [ ] **Step 1: Write `tests/test_stamina.lua`.**

```lua
local T       = require("tests.t")
local H       = require("tests.helpers")
local State   = require("engine.state")
local Phases  = require("engine.phases")
local Stamina = require("engine.stamina")

T.test("stamina: full on entering the pitch — strikers 4, midfielders 5, defenders 6, Engine 7", function()
    local m = H.match({ phase = "summon" })
    T.eq(H.place(m, "player", "striker", 1, H.card("striker", 2000, 500)).stamina, 4)
    T.eq(H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500)).stamina, 5)
    T.eq(H.place(m, "player", "defender", 1, H.card("defender", 900, 1900)).stamina, 6)
    T.eq(H.place(m, "player", "defender", 2, H.kw("ENGINE", "midfielder", 1800, 1500)).stamina, 7)
    T.eq(H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense").stamina, nil)
    T.eq(Stamina.max({ type = "trap" }), nil)
    T.eq(Stamina.max(nil), nil)
    local c = H.give(m, "player", H.card("striker", 2100, 500))
    H.store(m):summonCard(c.id, "striker", 2, "defense")
    T.eq(m.players.player.pitch.strikers[2].stamina, 4)
end)

T.test("stamina: each field card on the owner's pitch loses 1 at the end of its owner's turn", function()
    local m = H.match({ phase = "summon" })
    local s  = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local k  = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local fd = H.place(m, "player", "defender", 1, H.card("defender", 900, 1900), "defense")
    local o  = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    Phases.endTurn(m)
    T.eq(s.stamina, 3); T.eq(fd.stamina, 5); T.eq(k.stamina, nil)
    T.eq(o.stamina, 4, "the other side keeps its stamina")
    Phases.endTurn(m)
    T.eq(o.stamina, 3); T.eq(s.stamina, 3)
end)

T.test("stamina: never below 0; card_tired is logged once, when the card reaches 0", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    s.stamina = 1
    Phases.endTurn(m); Phases.endTurn(m)
    T.eq(s.stamina, 0)
    Phases.endTurn(m); Phases.endTurn(m)
    T.eq(s.stamina, 0)
    local e = H.events(m, "card_tired")
    T.eq(#e, 1); T.eq(e[1].payload.player, "player"); T.eq(e[1].payload.card, s.definition.id)
    T.eq(e[1].payload.name, s.definition.name); T.eq(e[1].payload.hidden, false)
    T.ok(Stamina.tired(s))
end)

T.test("stamina: attacking costs 1 more when the attack resolves — a fight, a shot, a wasted attack", function()
    local m = H.match()
    local a   = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local b   = H.place(m, "player", "striker", 2, H.card("striker", 2400, 500))
    local mid = H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local s = H.store(m)
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "defender_destroyed")
    T.eq(a.stamina, 3, "fight")
    s:declareAttack(H.slot("striker", 2), H.slot("keeper"))
    T.eq(b.stamina, 3, "shot")
    local r = s:declareAttack(H.slot("midfielder"), H.slot("midfielder"))
    T.eq(r.outcome, "wasted"); T.eq(mid.stamina, 4, "wasted attack")
end)

T.test("stamina: covering costs the coverer 1, won or lost (last-ditch tackle); the attacker pays too", function()
    local m = H.match({ active = "opponent" })
    local atk = H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    local mid = H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    r = s:resolveCover({ type = "midfielder", index = 0 })
    T.eq(r.outcome, "tackled")
    T.eq(mid.stamina, 4, "lost cover")
    T.eq(atk.stamina, 3, "the attack resolved")

    local m2 = H.match({ active = "opponent" })
    H.place(m2, "opponent", "striker", 1, H.card("striker", 1400, 500))
    local mid2 = H.place(m2, "player", "midfielder", 0, H.card("midfielder", 1500, 1600))
    H.place(m2, "player", "defender", 2, H.card("defender", 900, 1900), "defense")
    local s2 = H.store(m2)
    s2:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    r = s2:resolveCover({ type = "midfielder", index = 0 })
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(mid2.stamina, 4, "won cover")
end)

T.test("stamina: Press costs its card 1 more when it fires, nothing when there is no target", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m):summonCard(c.id, "striker", 1, "attack")
    T.eq(m.players.player.pitch.strikers[1].stamina, 3)
    local m2 = H.match({ phase = "summon" })
    local c2 = H.give(m2, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m2):summonCard(c2.id, "striker", 1, "attack")
    T.eq(m2.players.player.pitch.strikers[1].stamina, 4)
end)

T.test("stamina: Counter-press costs its card 1 more when it fires (2 in all for that cover)", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 1500, 500))
    local cp = H.place(m, "player", "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 1900), "defense")
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    local r = s:resolveCover({ type = "midfielder", index = 0 })
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(cp.stamina, 3)
end)

T.test("stamina: an attack cancelled by Offside costs nothing; a Direct Free Kick shooter pays 1", function()
    local m = H.match()
    local a = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(a.stamina, 4)

    local m2 = H.match()
    local sh = H.place(m2, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m2, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local card = H.give(m2, "player", H.def("strat-direct-free-kick"))
    H.store(m2):playStrategy(card.id)
    T.eq(sh.stamina, 3)
end)

T.test("stamina: a new half starts with an empty pitch; cards entering later are fully rested", function()
    local m = H.match({ phase = "summon" })
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    s.stamina = 0
    State.endHalf(m, "player", "time")
    T.eq(m.players.player.pitch.strikers[1], nil)
    State.kickOff(m)
    m.activePlayer, m.phase = "player", "summon"
    local def = H.give(m, "player", s.definition)
    T.eq(H.store(m):summonCard(def.id, "striker", 1, "attack"), true)
    T.eq(m.players.player.pitch.strikers[1].stamina, 4)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- `FAIL  tests/test_stamina.lua (load error)` (`engine.stamina` doesn't exist yet);
- the run ends with `441 passed, 1 failed`.

- [ ] **Step 3: `engine/constants.lua`: the stamina numbers.**

3a. Replace

```lua
    SUMMONED_CAN_ATTACK       = false, -- false: a field card summoned this turn attacks from its owner's next turn (Pace excepted)
}
```

with

```lua
    SUMMONED_CAN_ATTACK       = false, -- false: a field card summoned this turn attacks from its owner's next turn (Pace excepted)
    SUBS_PER_HALF             = 3,    -- substitutions per half, keeper swaps included (Extra Time: 3 too)
}
```

3b. Directly above the line `-- Keeper effective DEF = base DEF + (active defenders × 300) + (active midfielder × 150)`, insert:

```lua
-- Stamina (engine/stamina.lua; spec B1). A field card enters with full stamina; keepers
-- never tire. At 0 a card is Tired.
C.STAMINA = {
    MAX          = { striker = 4, midfielder = 5, defender = 6 },   -- by card type
    ENGINE_BONUS = 2,     -- Box-to-Box (Engine): 7
    TURN_COST    = 1,     -- end of its owner's turn
    ACTION_COST  = 1,     -- attacking or covering, when the action resolves
    ABILITY_COST = 1,     -- Press, Counter-press: when the ability fires
    TIRED_ATK    = 300,   -- Tired: −300 ATK
    TIRED_DEF    = 300,   -- Tired: −300 DEF
}

```

- [ ] **Step 4: Create `engine/stamina.lua`.**

```lua
-- Stamina (docs/superpowers/specs/2026-09-24-modes-stamina-design.md, B1). Pure; depends only
-- on engine.constants, so engine.state can use it.
--   pitched.stamina: current stamina of a field card; nil for cards that never tire
--   (keepers, traps). Full on entering the pitch (State.newPitchedCard); drained by
--   engine/phases.lua (Phases._spend). At 0 the card is Tired: −300 ATK / −300 DEF through
--   engine/cards/resolver.lua (R.tiredPart).
local C = require("engine.constants")

local Stamina = {}

-- Full stamina for a card definition: strikers 4, midfielders 5, defenders 6, Engine +2;
-- nil for keepers, traps and strategies (they never tire).
function Stamina.max(cardDef)
    local base = cardDef and C.STAMINA.MAX[cardDef.type]
    if not base then return nil end
    if cardDef.keyword == "ENGINE" then base = base + C.STAMINA.ENGINE_BONUS end
    return base
end

-- True at 0 stamina (Tired).
function Stamina.tired(pitched)
    return pitched ~= nil and pitched.stamina ~= nil and pitched.stamina <= 0
end

-- Takes n (default 1) stamina from a pitched card; never below 0. Returns true when this
-- made the card Tired.
function Stamina.spend(pitched, n)
    if not pitched or pitched.stamina == nil or pitched.stamina <= 0 then return false end
    pitched.stamina = math.max(0, pitched.stamina - (n or 1))
    return pitched.stamina == 0
end

-- Whether a viewer sees this card's stamina: its owner always; the other player only while
-- the card is face-up (attack mode or revealed). Cards that never tire show none.
function Stamina.visible(pitched, isOwner)
    if not pitched or pitched.stamina == nil then return false end
    if isOwner then return true end
    return pitched.mode ~= "defense" or pitched.revealed == true
end

return Stamina
```

- [ ] **Step 5: `engine/state.lua`: full stamina on entering the pitch.**

5a. Replace

```lua
local C = require("engine.constants")

local State = {}
```

with

```lua
local C       = require("engine.constants")
local Stamina = require("engine.stamina")

local State = {}
```

5b. Replace

```lua
        slotType          = slotType or definition.type,
    }
end
```

with

```lua
        slotType          = slotType or definition.type,
        stamina           = Stamina.max(definition),  -- full; nil = never tires (keepers, traps)
    }
end
```

- [ ] **Step 6: `engine/cards/resolver.lua`: `R.onSummon` reports Press, and `R.firedIn`.**

6a. Replace the whole `R.onSummon` function and the comment above it (from `-- Summon hook (engine/phases.lua Phases.summon), after the card is on the pitch.` through the `end` of `function R.onSummon`) with:

```lua
-- Summon hook (engine/phases.lua Phases._afterSummon), after the card is on the pitch.
--   Press: exhaust one enemy defender-slot card (R.pressTarget) for this turn, so it can't
--   cover; pitched.pressed marks it and Phases.endTurn clears both flags at this turn's end.
-- Returns true when Press fired (it costs its card stamina: Phases._afterSummon).
function R.onSummon(matchState, ownerId, pitched)
    if not R.has(pitched, "PRESS") then return false end
    local oppPitch = matchState.players[State.other(ownerId)].pitch
    local i = R.pressTarget(oppPitch)
    if not i then return false end
    local target = oppPitch.defenders[i]
    target.exhausted = true
    target.pressed   = true
    R.trigger(matchState, ownerId, pitched, "PRESS", { target = { type = "defender", index = i } })
    return true
end
```

6b. Directly above the line that starts with `-- ── Stat bonuses`, insert:

```lua
-- True when a stat part list (R.atkBonus / R.defBonus parts) has this keyword.
function R.firedIn(parts, keyword)
    for _, p in ipairs(parts or {}) do
        if p.keyword == keyword then return true end
    end
    return false
end

```

- [ ] **Step 7: `engine/phases.lua`: `_spend`, `_afterSummon` and every drain point.**

7a. Replace

```lua
local Combat = require("engine.combat")
local Resolver = require("engine.cards.resolver")
```

with

```lua
local Combat = require("engine.combat")
local Resolver = require("engine.cards.resolver")
local Stamina = require("engine.stamina")
```

7b. In `Phases.summon`, replace

```lua
            Resolver.onSummon(matchState, matchState.activePlayer, pitched)
            return true
```

with

```lua
            Phases._afterSummon(matchState, matchState.activePlayer, pitched)
            return true
```

and replace

```lua
    Resolver.onSummon(matchState, matchState.activePlayer, pitched)   -- Press
    return true
```

with

```lua
    Phases._afterSummon(matchState, matchState.activePlayer, pitched)   -- Press
    return true
```

7c. Directly above the line `-- May the active player bring cardDef on as a keeper substitution now? A keeper card from`, insert:

```lua
-- Summon hooks once a card is on the pitch: Press, which costs its card
-- C.STAMINA.ABILITY_COST when it fires.
function Phases._afterSummon(matchState, ownerId, pitched)
    if Resolver.onSummon(matchState, ownerId, pitched) then
        Phases._spend(matchState, ownerId, pitched, C.STAMINA.ABILITY_COST)
    end
end

```

7d. Each wasted attack costs its attacker. There are exactly three lines starting with `        State.log(matchState, "attack_wasted", {` (one in `Phases._shootAtGoal`, two in `Phases._handleEmpty`). Directly above **each** of them, insert this line (8 spaces of indentation):

```lua
        Phases._spend(matchState, matchState.activePlayer, attacker, C.STAMINA.ACTION_COST)
```

7e. In `Phases.resolveCover`, replace

```lua
        local result  = Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot,
                                         opponentId, true)
        if keyword then Resolver.trigger(matchState, opponentId, coverer, keyword, nil, result) end
        return result
```

with

```lua
        local result  = Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot,
                                         opponentId, true)
        if keyword then Resolver.trigger(matchState, opponentId, coverer, keyword, nil, result) end
        -- Stamina: covering costs the coverer C.STAMINA.ACTION_COST, won or lost (a coverer
        -- destroyed on a tie has left the pitch).
        if not result.defenderDestroyed then
            Phases._spend(matchState, opponentId, coverer, C.STAMINA.ACTION_COST)
        end
        return result
```

7f. In `Phases._doCombat`, directly above the line `    -- Hard tackle, Build-up`, insert:

```lua
    -- Stamina: the attack costs its attacker C.STAMINA.ACTION_COST once it resolves (a
    -- destroyed card has left the pitch); the coverer's cost is paid in Phases.resolveCover.
    -- Counter-press costs its card C.STAMINA.ABILITY_COST more when it fired.
    if not result.attackerDestroyed then
        Phases._spend(matchState, activeId, attacker, C.STAMINA.ACTION_COST)
    end
    if not result.defenderDestroyed and Resolver.firedIn(result.defParts, "COUNTER_PRESS") then
        Phases._spend(matchState, opponentId, defender, C.STAMINA.ABILITY_COST)
    end

```

7g. In `Phases._goalAttempt`, replace

```lua
    striker.usedAsAttacker = true
    striker.exhausted      = true
```

with

```lua
    striker.usedAsAttacker = true
    striker.exhausted      = true
    Phases._spend(matchState, activeId, striker, C.STAMINA.ACTION_COST)   -- stamina: the shot
```

7h. In `Phases.endTurn`, replace

```lua
    recoverPitch(matchState.players[activeId].pitch)
```

with

```lua
    recoverPitch(matchState.players[activeId].pitch)
    -- Stamina: every field card on the active player's pitch spends C.STAMINA.TURN_COST.
    for _, e in ipairs(Resolver.fieldCards(matchState.players[activeId].pitch)) do
        Phases._spend(matchState, activeId, e.card, C.STAMINA.TURN_COST)
    end
```

7i. Directly below the `Phases._getSlotForPlayer` function (after its closing `end`), insert:

```lua

-- Stamina (spec B1): ownerId's card spends n (engine/stamina.lua). Logs `card_tired`
-- { player, card, name, hidden } when that makes it Tired.
function Phases._spend(matchState, ownerId, card, n)
    if Stamina.spend(card, n) then
        State.log(matchState, "card_tired", { player = ownerId, card = card.definition.id,
            name = card.definition.name, hidden = Resolver.hidden(card) })
    end
end
```

- [ ] **Step 8: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/constants.lua engine/stamina.lua engine/state.lua engine/phases.lua engine/cards/resolver.lua && lua tests/run.lua`
Expected: no `luac` output; `450 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 9: Commit**

```bash
ls luac.out
git add engine/constants.lua engine/stamina.lua engine/state.lua engine/phases.lua engine/cards/resolver.lua tests/test_stamina.lua
git commit -m "Stamina: full on entry, drains at turn end and on attacks, covers, Press and Counter-press" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **450**.

---

### Task 5: Tired −300 through the resolver, badges, combat tags, AI (spec B1)

**Files:**
- Modify: `engine/cards/resolver.lua`, `engine/combat.lua`, `store/match.lua`, `ui/card.lua`, `ui/kit/draw.lua`, `ui/theme.lua`, `ui/match/zoom.lua`, `ui/overlay/combatfx.lua`, `ui/overlay/combat.lua`, `ai/opponent.lua`
- Test: `tests/test_tired.lua` (create)

- [ ] **Step 1: Write `tests/test_tired.lua`.**

```lua
local T        = require("tests.t")
local H        = require("tests.helpers")
local Combat   = require("engine.combat")
local Resolver = require("engine.cards.resolver")
local Card     = require("ui.card")
local Zoom     = require("ui.match.zoom")
local Fx       = require("ui.overlay.combatfx")
local AI       = require("ai.opponent")

T.test("tired: −300 ATK for a tired attacker — the fight result changes; it is no ability", function()
    local m = H.match()
    local a = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    a.stamina = 0
    local atk, parts = Combat.attackStat(a, "striker", m.players.player.pitch, m.players.opponent.pitch)
    T.eq(atk, 1700)
    T.eq(#parts, 1); T.eq(parts[1].keyword, "TIRED"); T.eq(parts[1].amount, -300)
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(#H.triggers(m), 0, "Tired is not an ability: no ability_triggered")
end)

T.test("tired: −300 DEF for a tired defender; bonuses still add up (+200 − 300)", function()
    local m = H.match()
    local pitch = m.players.opponent.pitch
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800))
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    d.stamina = 0
    T.eq((Combat.defendStat(d, "defender", pitch)), 1700)
    H.place(m, "player", "striker", 1, H.card("striker", 1750, 500))
    T.eq(H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "defender_destroyed")
end)

T.test("tired: shots lose 300 too; a non-keeper in goal tires, a keeper never does", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    s.stamina = 0
    local atk = Combat.attackStat(s, "striker", m.players.player.pitch, m.players.opponent.pitch, { keeper = k })
    T.eq(atk, 1700)
    T.eq(k.stamina, nil); T.eq((Combat.keeperDef(k, m.players.opponent.pitch)), 1800)
    local m2 = H.match()
    local stand = H.place(m2, "opponent", "keeper", 0, H.card("defender", 900, 1900))
    stand.stamina = 0
    local def, parts = Combat.keeperDef(stand, m2.players.opponent.pitch, false)
    T.eq(def, 1600); T.eq(parts[1].keyword, "TIRED")
    T.eq((Combat.keeperDef(stand, m2.players.opponent.pitch, true)), 1600, "penalty: base DEF, still tired")
end)

T.test("tired: hidden from the opponent's view while face-down; badges show the malus", function()
    local m = H.match()
    local pitch = m.players.opponent.pitch
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    fd.stamina = 0
    T.eq((Combat.defendStat(fd, "defender", pitch, false, true)), 1800, "visible only")
    T.eq((Combat.defendStat(fd, "defender", pitch)), 1500)
    local own = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "midfielder", 0, H.card("midfielder", 1500, 1500))
    own.stamina = 0
    local atkB, defB, atkParts = Card.bonuses(own, m.players.player.pitch)
    T.eq(atkB, -100); T.eq(defB, -300)
    T.eq(atkParts[#atkParts].keyword, "TIRED")
end)

T.test("tired: combat snapshot tags read 'TIRED -300'; the AI's hidden tired card gets no tag", function()
    local m = H.match()
    local a  = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    a.stamina, fd.stamina = 0, 0
    local snap = H.store(m):_snapshotAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(snap.attacker.atk, 1700); T.eq(snap.attacker.tired, true)
    T.eq(Fx.tagText(snap.attacker.atkTags[1]), "TIRED -300")
    T.eq(snap.defender.def, 1500, "the total still counts it")
    T.eq(#snap.defender.defTags, 0); T.eq(snap.defender.tired, false)
    T.eq(Resolver.partName("TIRED"), "Tired")
end)

T.test("tired: the zoom's stat lines subtract it", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    s.stamina = 0
    local found = {}
    for _, l in ipairs(Zoom.statusLines(s.definition, s, m.players.player.pitch)) do found[l.text] = l.color end
    T.eq(found["ATK 2000 - 300 = 1700 (Tired -300)"], "bad")
    T.eq(found["DEF 500 - 300 = 200 (Tired -300)"], "bad")
end)

T.test("tired: the combat overlay keeps a negative bonus so the badge shows the real number", function()
    local v = Fx.cardView({ name = "X", type = "striker", atk = 1700, def = 500, atkBonus = -300,
                            defBonus = 0, tired = true, atkTags = { { name = "Tired", amount = -300 } } }, nil)
    T.eq(v.stats.atk, 2000); T.eq(v.atkBonus, -300); T.eq(v.atk, 1700)
    T.eq(v.tired, true); T.eq(v.atkTags[1], "TIRED -300")
end)

T.test("AI switch: a tired striker the enemy would beat goes to face-up defense", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local s = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 1, H.card("defender", 1200, 1900))
    s.stamina = 0
    local n = 0
    for _, a in ipairs(AI._planSummons(m)) do
        if a.type == "toDefense" and a.slotType == "striker" then n = n + 1 end
    end
    T.eq(n, 1)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- all 8 `tired:` / `AI switch: a tired striker …` tests `FAIL` (nothing applies Tired yet);
- the run ends with `450 passed, 8 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua`: the Tired part.**

3a. Replace

```lua
local C     = require("engine.constants")
local State = require("engine.state")
```

with

```lua
local C       = require("engine.constants")
local State   = require("engine.state")
local Stamina = require("engine.stamina")
```

3b. Directly above the line that starts with `-- ── Events`, insert:

```lua
-- ── Tired (stamina, spec B1) ─────────────────────────────────────────────────

R.TIRED = "TIRED"   -- stat-part keyword of the Tired malus (not an ability: never logged)

-- Labels of stat-part keywords that aren't abilities.
R.PART_LABELS = { TIRED = "Tired" }

-- Display name of a stat part's keyword: an ability name, "Tired", or the keyword itself.
function R.partName(keyword)
    return R.NAMES[keyword] or R.PART_LABELS[keyword] or keyword
end

-- Tired malus of a card: −amount and its part while the card is Tired (0 stamina), else 0.
-- visibleOnly: a face-down, unrevealed card's stamina is hidden information (no malus).
function R.tiredPart(pitched, amount, visibleOnly)
    if not Stamina.tired(pitched) or (visibleOnly and R.hidden(pitched)) then return 0, nil end
    return -amount, R.part(-amount, pitched, R.TIRED)
end

```

3c. In `R.logParts`, replace

```lua
        if p.keyword then
```

with

```lua
        if p.keyword and p.keyword ~= R.TIRED then   -- Tired is no ability
```

3d. In `R.atkBonus`, replace

```lua
            add(A.OPPORTUNIST_ATK, R.part(A.OPPORTUNIST_ATK, pitched, "OPPORTUNIST"))
        end
    end
    return total, parts
```

with

```lua
            add(A.OPPORTUNIST_ATK, R.part(A.OPPORTUNIST_ATK, pitched, "OPPORTUNIST"))
        end
    end
    add(R.tiredPart(pitched, C.STAMINA.TIRED_ATK, ctx.visibleOnly))   -- Tired (any slot)
    return total, parts
```

3e. In `R.defBonus`, replace

```lua
        add(A.COUNTER_PRESS_DEF, R.part(A.COUNTER_PRESS_DEF, pitched, "COUNTER_PRESS"))
    end
    return total, parts
```

with

```lua
        add(A.COUNTER_PRESS_DEF, R.part(A.COUNTER_PRESS_DEF, pitched, "COUNTER_PRESS"))
    end
    add(R.tiredPart(pitched, C.STAMINA.TIRED_DEF, ctx.visibleOnly))   -- Tired (any slot)
    return total, parts
```

3f. In the comment above `function R.atkBonus`, replace

```lua
--   exhausted) and Opportunist (+400 while an enemy defender slot is empty).
```

with

```lua
--   exhausted) and Opportunist (+400 while an enemy defender slot is empty).
--   any slot: Tired (−C.STAMINA.TIRED_ATK at 0 stamina, R.tiredPart; a TIRED part).
```

In the comment above `function R.defBonus`, replace

```lua
--   it is the only card in its owner's defender slots); covering: Counter-press (+300).
```

with

```lua
--   it is the only card in its owner's defender slots); covering: Counter-press (+300);
--   any slot: Tired (−C.STAMINA.TIRED_DEF at 0 stamina).
```

- [ ] **Step 4: `engine/combat.lua`: a tired non-keeper in goal.** In `Combat.keeperDef`, replace

```lua
    local base = Combat.getStat(keeper, "defend") + own
```

with

```lua
    -- Tired: a non-keeper card in the keeper slot at 0 stamina (keepers never tire). It is the
    -- card's own DEF, so it also counts against a Penalty.
    local tired, tiredPart = Resolver.tiredPart(keeper, C.STAMINA.TIRED_DEF, visibleOnly)
    if tiredPart then parts[#parts + 1] = tiredPart end
    local base = Combat.getStat(keeper, "defend") + own + tired
```

- [ ] **Step 5: `store/match.lua`: tag names and the `tired` flag in snapshots.**

5a. Replace

```lua
local Resolver = require("engine.cards.resolver")
local C      = require("engine.constants")
```

with

```lua
local Resolver = require("engine.cards.resolver")
local Stamina  = require("engine.stamina")
local C      = require("engine.constants")
```

5b. Replace

```lua
--              atkTags, defTags } — tags { keyword, name, amount } from ability parts.
```

with

```lua
--              atkTags, defTags, tired } — tags { keyword, name, amount } from stat parts
--              (abilities and Tired); tired: a Tired card whose stamina its opponent may see.
```

5c. Replace

```lua
                                  name = Resolver.NAMES[p.keyword] or p.keyword,
```

with

```lua
                                  name = Resolver.partName(p.keyword),
```

5d. Replace

```lua
    local function base(card, isKeeper)
        local d = card.definition
        return {
            name = d.name, type = d.type, mode = card.mode,
            wasHidden = (card.mode == "defense" and not card.revealed),
            atk = Combat.getStat(card, "attack"), def = Combat.getStat(card, "defend"),
            atkBonus = 0, defBonus = 0, isKeeper = isKeeper, atkTags = {}, defTags = {},
        }
    end
```

with

```lua
    local function base(card, isKeeper, ownerId)
        local d = card.definition
        return {
            name = d.name, type = d.type, mode = card.mode,
            wasHidden = (card.mode == "defense" and not card.revealed),
            atk = Combat.getStat(card, "attack"), def = Combat.getStat(card, "defend"),
            atkBonus = 0, defBonus = 0, isKeeper = isKeeper, atkTags = {}, defTags = {},
            tired = Stamina.tired(card) and not (ownerId == "opponent" and Resolver.hidden(card)),
        }
    end
```

5e. Replace `        attacker = base(atkCard, false)` with `        attacker = base(atkCard, false, activeId)`, and `        defender = base(defCard, isKeeper)` with `        defender = base(defCard, isKeeper, opponentId)`.

- [ ] **Step 6: `ui/theme.lua`: tired colours.** Directly above the line `-- Deck-select tiles (keys match data/presetDecks.lua).`, insert:

```lua
-- Tired cards (stamina 0): red rim, pale badge interior and red numbers, the TIRED pill, the
-- sweat drop, and the last stamina pip's warning colour.
Theme.tired = {
    number = hex("e0243a"),
    fill   = hex("f4f5fb"),
    pill   = { hex("ff8a8a"), hex("e0243a") },
    sweat  = hex("4fb8ff"),
    low    = hex("ffc15a"),
}

```

- [ ] **Step 7: `ui/kit/draw.lua`: tired badges.** Replace the three functions `badgeNumber`, `Draw.atkBadge` and `Draw.defBadge`, from `-- maxW: widest the number may be (circle interiors are narrower than shields).` through the `end` of `function Draw.defBadge`, with:

```lua
-- maxW: widest the number may be (circle interiors are narrower than shields).
-- color: number colour (default white, with a drop shadow).
local function badgeNumber(value, cx, cy, s, alpha, maxW, color)
    local str = tostring(value)
    local size = Draw.fitSize(str, maxW or s * 0.86, s * 0.40, 6, measureDisplay)
    Draw.text(str, cx - s, cy - size * 0.58, s * 2, "center", {
        size = size, color = color or Theme.white,
        shadowY = color and 0 or math.max(1, math.floor(s * 0.05)), alpha = alpha,
    })
end

-- Red ATK circle. s = diameter. tired: red rim, pale interior, red number.
function Draw.atkBadge(cx, cy, s, value, alpha, tired)
    alpha = alpha or 1
    local r = s / 2
    local sh = math.max(2, s * 0.08)
    Draw.setColor(Theme.ink, alpha);  love.graphics.circle("fill", cx, cy + sh, r, 24)
    Draw.setColor(tired and Theme.tired.number or Theme.white, alpha); love.graphics.circle("fill", cx, cy, r, 24)
    local b = math.max(2, s * 0.08)
    if tired then
        Draw.setColor(Theme.tired.fill, alpha); love.graphics.circle("fill", cx, cy, r - b, 24)
    else
        Draw.setColor(Theme.grad.atk[2], alpha); love.graphics.circle("fill", cx, cy, r - b, 24)
        Draw.setColor(Theme.grad.atk[1], alpha); love.graphics.circle("fill", cx, cy - (r - b) * 0.18, (r - b) * 0.82, 24)
    end
    badgeNumber(value, cx, cy, s, alpha, s * 0.72, tired and Theme.tired.number or nil)
end

-- Blue DEF shield. s = width. bonus > 0 adds a green "+N" tag above it. tired: red rim, pale
-- interior, red number.
function Draw.defBadge(cx, cy, s, value, bonus, alpha, tired)
    alpha = alpha or 1
    local sh = math.max(2, s * 0.08)
    local b  = math.max(2, s * 0.08)
    love.graphics.push()
    love.graphics.translate(0, sh)
    Draw.setColor(Theme.ink, alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    love.graphics.pop()
    Draw.setColor(tired and Theme.tired.number or Theme.white, alpha)
    love.graphics.polygon("fill", shieldPoints(cx, cy, s + b * 2))
    if tired then
        Draw.setColor(Theme.tired.fill, alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s))
    else
        Draw.setColor(Theme.grad.def[2], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy, s))
        Draw.setColor(Theme.grad.def[1], alpha); love.graphics.polygon("fill", shieldPoints(cx, cy - s * 0.08, s * 0.8))
    end
    badgeNumber(value, cx, cy, s, alpha, nil, tired and Theme.tired.number or nil)
    if bonus and bonus > 0 then
        local tw, th = s * 1.1, s * 0.42
        Draw.pill(cx - tw / 2, cy - s * 0.5 - th - 2, tw, th, "+" .. bonus, {
            fill = Theme.grad.bonus, textColor = Theme.white, border = 2, shadow = 2, alpha = alpha,
        })
    end
end
```

- [ ] **Step 8: `ui/card.lua`: bonuses for every slot, negative bonuses, red numbers.**

8a. Replace

```lua
local Draw   = require("ui.kit.draw")
local Icons  = require("ui.kit.icons")
local Phases = require("engine.phases")
```

with

```lua
local Draw    = require("ui.kit.draw")
local Icons   = require("ui.kit.icons")
local Phases  = require("engine.phases")
local Stamina = require("engine.stamina")
```

8b. In the header comment, replace

```lua
--   Card.drawFace(cardDef, x, y, w, h, opts) opts: stats, atkBonus, defBonus, exhausted, selected, target, alpha,
```

with

```lua
--   Card.drawFace(cardDef, x, y, w, h, opts) opts: stats, atkBonus, defBonus, exhausted, selected, target, alpha, tired,
```

8c. In `Card.drawBadges`, replace

```lua
    Draw.atkBadge(x + atkPos.cx, y + atkPos.cy, atkPos.size, (stats.atk or 0) + (opts.atkBonus or 0), a)
    Draw.defBadge(x + defPos.cx, y + defPos.cy, defPos.size, (stats.def or 0) + (opts.defBonus or 0),
        opts.defBonus, a)
```

with

```lua
    Draw.atkBadge(x + atkPos.cx, y + atkPos.cy, atkPos.size, (stats.atk or 0) + (opts.atkBonus or 0), a,
        opts.tired)
    Draw.defBadge(x + defPos.cx, y + defPos.cy, defPos.size, (stats.def or 0) + (opts.defBonus or 0),
        opts.defBonus, a, opts.tired)
```

8d. Replace the whole `Card.bonuses` function and its comment (from `-- Bonuses shown on a pitched card's badges: its always-on bonuses. Pure (unit-tested).` through the `end` of `function Card.bonuses`) with:

```lua
-- Bonuses shown on a pitched card's badges: its always-on bonuses and maluses. Pure
-- (unit-tested).
--   ATK: Combat.attackStat for its slot minus base ATK (striker slot: the midfielder card
--        bonus with Engine / Overlap, and Link-up; any slot: Tired −300)
--   DEF: keeper slot → effective DEF minus base DEF (line, Bolt, midfielder, Safe hands);
--        other slots → Combat.defendStat minus base DEF (defender slot: the midfielder card
--        bonus with Engine, and Last man; any slot: Tired −300)
-- Situational bonuses (Instinct, Opportunist, Counter-press) are not shown here.
-- hideHidden: the card is the opponent's; bonuses from their face-down, unrevealed cards
-- (a hidden midfielder's bonus, a hidden Link-up or Bolt card) are hidden information.
-- Returns atkBonus, defBonus (negative when Tired outweighs the bonuses), atkParts, defParts.
function Card.bonuses(pitched, pitch, hideHidden)
    if not pitch then return 0, 0, {}, {} end
    local st = pitched.slotType
    if st ~= "striker" and st ~= "defender" and st ~= "midfielder" and st ~= "keeper" then
        return 0, 0, {}, {}
    end
    local stats = pitched.definition.stats or {}
    local atk, atkParts = Combat.attackStat(pitched, st, pitch, nil, nil, hideHidden)
    local def, defParts
    if st == "keeper" then
        def, defParts = Combat.keeperDef(pitched, pitch, false, hideHidden)
    else
        def, defParts = Combat.defendStat(pitched, st, pitch, false, hideHidden)
    end
    return atk - (stats.atk or 0), def - (stats.def or 0), atkParts, defParts
end
```

8e. In `Card.drawPitched`, replace

```lua
    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus > 0 and atkBonus or nil,
        defBonus = defBonus > 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
    })
```

with

```lua
    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus ~= 0 and atkBonus or nil,
        defBonus = defBonus ~= 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
        tired = Stamina.tired(pitched),
    })
```

- [ ] **Step 9: `ui/match/zoom.lua`: signed stat lines and the tired face.**

9a. Replace

```lua
local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")
```

with

```lua
local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")
local Stamina  = require("engine.stamina")
```

9b. Replace the whole `Zoom.partsText` function and its comment (from `-- " (Link-up +150, Engine +100)" for a stat line; "" without keyword parts. Pure.` through its closing `end`) with:

```lua
-- " (Link-up +150, Tired -300)" for a stat line; "" without keyword parts. Pure.
function Zoom.partsText(parts)
    local out = {}
    for _, p in ipairs(parts or {}) do
        if p.keyword then
            local n = p.amount or 0
            out[#out + 1] = Resolver.partName(p.keyword) .. (n < 0 and (" -" .. (-n)) or (" +" .. n))
        end
    end
    if #out == 0 then return "" end
    return " (" .. table.concat(out, ", ") .. ")"
end

-- "ATK 2000 + 200 = 2200 (…)" / "DEF 500 - 300 = 200 (Tired -300)". Pure.
local function statLine(label, base, bonus, parts)
    local op = bonus >= 0 and (" + " .. bonus) or (" - " .. (-bonus))
    return label .. base .. op .. " = " .. (base + bonus) .. Zoom.partsText(parts)
end
```

9c. Replace

```lua
    if atkB > 0 then
        add("ATK " .. (st.atk or 0) .. " + " .. atkB .. " = " .. ((st.atk or 0) + atkB)
            .. Zoom.partsText(atkParts), "bonus")
    end
    if defB > 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(label .. (st.def or 0) .. " + " .. defB .. " = " .. ((st.def or 0) + defB)
            .. Zoom.partsText(defParts), "bonus")
    end
```

with

```lua
    if atkB ~= 0 then
        add(statLine("ATK ", st.atk or 0, atkB, atkParts), atkB > 0 and "bonus" or "bad")
    end
    if defB ~= 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(statLine(label, st.def or 0, defB, defParts), defB > 0 and "bonus" or "bad")
    end
```

9d. In `Zoom.draw`, replace

```lua
    Card.drawFace(z.cardDef, p.cardX, p.cardY, Zoom.W, Zoom.H, {
        atkBonus  = atkB > 0 and atkB or nil,
        defBonus  = defB > 0 and defB or nil,
        exhausted = z.pitched and z.pitched.exhausted or nil,
    })
```

with

```lua
    Card.drawFace(z.cardDef, p.cardX, p.cardY, Zoom.W, Zoom.H, {
        atkBonus  = atkB ~= 0 and atkB or nil,
        defBonus  = defB ~= 0 and defB or nil,
        exhausted = z.pitched and z.pitched.exhausted or nil,
        tired     = z.pitched and Stamina.tired(z.pitched) or nil,
    })
```

- [ ] **Step 10: `ui/overlay/combatfx.lua`: signed tags and the `tired` view.**

10a. Replace

```lua
-- "LINK-UP +150" for an ability tag { name, amount } (no number when amount is 0).
function Fx.tagText(tag)
    local s = string.upper(tag.name or tag.keyword or "?")
    if (tag.amount or 0) > 0 then s = s .. " +" .. tag.amount end
    return s
end
```

with

```lua
-- "LINK-UP +150" / "TIRED -300" for a stat tag { name, amount } (no number when amount is 0).
function Fx.tagText(tag)
    local s = string.upper(tag.name or tag.keyword or "?")
    local n = tag.amount or 0
    if n > 0 then s = s .. " +" .. n elseif n < 0 then s = s .. " -" .. (-n) end
    return s
end
```

10b. Replace

```lua
--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def, atkTags, defTags } | nil
```

with

```lua
--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def, atkTags, defTags, tired } | nil
```

and replace

```lua
        atkTags  = Fx.bonusTags(snap, "atk"),
        defTags  = Fx.bonusTags(snap, "def"),
    }
```

with

```lua
        atkTags  = Fx.bonusTags(snap, "atk"),
        defTags  = Fx.bonusTags(snap, "def"),
        tired    = snap.tired == true,
    }
```

- [ ] **Step 11: `ui/overlay/combat.lua`: negative bonuses and tired badges.**

11a. Replace

```lua
local function drawFace(view, x, y, exhausted)
    Card.drawFace(view.cardDef, x, y, CW, CH, {
        stats     = view.stats,
        atkBonus  = view.atkBonus > 0 and view.atkBonus or nil,
        defBonus  = view.defBonus > 0 and view.defBonus or nil,
        exhausted = exhausted or nil,
    })
end
```

with

```lua
local function drawFace(view, x, y, exhausted)
    Card.drawFace(view.cardDef, x, y, CW, CH, {
        stats     = view.stats,
        atkBonus  = view.atkBonus ~= 0 and view.atkBonus or nil,
        defBonus  = view.defBonus ~= 0 and view.defBonus or nil,
        exhausted = exhausted or nil,
        tired     = view.tired or nil,
    })
end

-- "ATK +200" / "ATK -300" / "ATK".
local function signedLabel(prefix, n)
    if n > 0 then return prefix .. " +" .. n end
    if n < 0 then return prefix .. " -" .. (-n) end
    return prefix
end
```

11b. Replace

```lua
        Draw.atkBadge(x, BADGE_Y, s, Fx.countValue(a.atk, p.count))
        Draw.pill(x - 60, labelY, 120, 28, a.atkBonus > 0 and ("ATK +" .. a.atkBonus) or "ATK", {
```

with

```lua
        Draw.atkBadge(x, BADGE_Y, s, Fx.countValue(a.atk, p.count), nil, a.tired)
        Draw.pill(x - 60, labelY, 120, 28, signedLabel("ATK", a.atkBonus), {
```

11c. Replace

```lua
        Draw.defBadge(x, BADGE_Y, s * 0.95, Fx.countValue(d.def, p.count), d.defBonus > 0 and d.defBonus or nil)
```

with

```lua
        Draw.defBadge(x, BADGE_Y, s * 0.95, Fx.countValue(d.def, p.count),
            d.defBonus > 0 and d.defBonus or nil, nil, d.tired)
```

- [ ] **Step 12: `ai/opponent.lua`: a tired card counts as weak.**

12a. Replace

```lua
local Resolver = require("engine.cards.resolver")

local AI = {}
```

with

```lua
local Resolver = require("engine.cards.resolver")
local Stamina  = require("engine.stamina")

local AI = {}
```

12b. Replace

```lua
-- Weak: no winning attack this turn. A striker-slot card is never weak here (it shoots or
-- clears defenders).
function AI._weak(match, card, slotType)
    if slotType == "striker" then return false end
    return not AI._winsNow(match, card, slotType)
end
```

with

```lua
-- Weak: Tired (any slot), or no winning attack this turn. A striker-slot card that isn't
-- tired is never weak (it shoots or clears defenders).
function AI._weak(match, card, slotType)
    if Stamina.tired(card) then return true end
    if slotType == "striker" then return false end
    return not AI._winsNow(match, card, slotType)
end
```

- [ ] **Step 13: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/cards/resolver.lua engine/combat.lua store/match.lua ui/card.lua ui/kit/draw.lua ui/theme.lua ui/match/zoom.lua ui/overlay/combatfx.lua ui/overlay/combat.lua ai/opponent.lua && lua tests/run.lua`
Expected: no `luac` output; `458 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 14: Snapshots**

Run: `for s in combat abilities cards; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`

Check with the Read tool:
- `combat_count`, `combat_save`, `abilities_tags` and `cards_gallery` look exactly as before (no card on those boards is tired).
- Badges keep their red / blue fills and white numbers.

- [ ] **Step 15: Commit**

```bash
ls luac.out
git add engine/cards/resolver.lua engine/combat.lua store/match.lua ui/card.lua ui/kit/draw.lua ui/theme.lua ui/match/zoom.lua ui/overlay/combatfx.lua ui/overlay/combat.lua ai/opponent.lua tests/test_tired.lua
git commit -m "Tired: -300 ATK/DEF through the resolver, red badges, TIRED -300 combat tags, AI pulls tired cards back" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **458**.

---

### Task 6: Stamina UI: pips, the tired marker, zoom and toasts (spec B1)

**Files:**
- Modify: `ui/card.lua`, `ui/pitch.lua`, `ui/match/zoom.lua`, `ui/match/toasts.lua`, `tools/snapshot/card_gallery.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_stamina_ui.lua` (create)

- [ ] **Step 1: Write `tests/test_stamina_ui.lua`.**

```lua
local T       = require("tests.t")
local H       = require("tests.helpers")
local Card    = require("ui.card")
local Zoom    = require("ui.match.zoom")
local Toasts  = require("ui.match.toasts")
local Stamina = require("engine.stamina")

T.test("stamina pips: between the badges and under the name ribbon; on a back, above the DEF label", function()
    local L  = Card.layout(108, 148)
    local st = L.stamina
    local rw = Card.staminaRowWidth(L, 7)          -- the longest row (Engine)
    T.ok(st.cy - st.h / 2 >= L.ribbon.y + L.ribbon.h, "under the name ribbon")
    T.ok(st.cx - rw / 2 >= L.atk.cx + L.atk.size / 2, "right of the ATK badge")
    T.ok(st.cx + rw / 2 <= L.def.cx - L.def.size / 2, "left of the DEF badge")
    T.ok(st.cy + st.h / 2 <= 148, "inside the card")
    T.ok(st.backCy - st.h / 2 >= 148 / 2 + math.min(108, 148) * 0.42 / 2, "back: below the ball")
    local pad = L.border + 5 * L.s
    T.ok(st.backCy + st.h / 2 <= 148 - pad - math.max(10, 16 * L.s) - 2 * L.s, "back: above the DEF label")
    local sw = L.sweat
    T.ok(sw.cy - sw.size / 2 >= L.tag.cy + L.tag.h / 2, "sweat drop below the type tag")
    T.ok(sw.cx + sw.size / 2 <= (108 - L.defPill.h * 2.6) / 2, "sweat drop left of the DEF pill")
    T.ok(sw.cy + sw.size / 2 <= L.flip.y, "sweat drop above the switch ribbon")
end)

T.test("stamina pips: filled / total, tired at 0, nothing for cards that never tire", function()
    local m = H.match()
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local v = Card.staminaView(s)
    T.eq(v.filled, 4); T.eq(v.total, 4); T.eq(v.tired, false)
    s.stamina = 0
    v = Card.staminaView(s)
    T.eq(v.filled, 0); T.eq(v.tired, true)
    local e = H.place(m, "player", "midfielder", 0, H.kw("ENGINE", "midfielder", 1800, 1500))
    T.eq(Card.staminaView(e).total, 7)
    T.eq(Card.staminaView(H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")), nil)
end)

T.test("stamina visibility: your own cards always; the opponent's only while face-up", function()
    local m = H.match()
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    local up = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    T.eq(Stamina.visible(fd, true), true)
    T.eq(Stamina.visible(fd, false), false)
    fd.revealed = true
    T.eq(Stamina.visible(fd, false), true)
    T.eq(Stamina.visible(up, false), true)
    T.eq(Stamina.visible(H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800)), true), false)
end)

T.test("zoom: stamina line, TIRED line, none for keepers", function()
    local m = H.match()
    local pitch = m.players.player.pitch
    local s = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local function has(lines, text)
        for _, l in ipairs(lines) do if l.text == text then return true end end
        return false
    end
    T.ok(has(Zoom.statusLines(s.definition, s, pitch), "Stamina 4 / 4"))
    s.stamina = 0
    T.ok(has(Zoom.statusLines(s.definition, s, pitch), "TIRED: -300 ATK / -300 DEF (stamina 0 / 4)"))
    local k = H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    for _, l in ipairs(Zoom.statusLines(k.definition, k, pitch)) do
        T.ok(not l.text:find("Stamina") and not l.text:find("TIRED"), l.text)
    end
end)

T.test("toasts: your tired card is named; the opponent's only while face-up", function()
    T.eq((Toasts.describe({ type = "card_tired", payload = { player = "player", name = "The Poacher" } })),
        "The Poacher is TIRED (-300)")
    T.eq((Toasts.describe({ type = "card_tired", payload = { player = "opponent", name = "Libero" } })),
        "Opp's Libero is TIRED")
    T.eq((Toasts.describe({ type = "card_tired",
        payload = { player = "opponent", name = "Libero", hidden = true } })), nil)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 4 `FAIL` lines: `stamina pips: between …`, `stamina pips: filled …`, `zoom: stamina line …` and `toasts: your tired card …`. `stamina visibility` already passes (`Stamina.visible` is from Task 4).
- The run ends with `459 passed, 4 failed`.

- [ ] **Step 3: `ui/card.lua`: layout, pips and the sweat drop.**

3a. In the header comment, replace

```lua
--   Card.switchLabel(pitched, slotType, ctx) position-switch ribbon text or nil (pure, unit-tested)
```

with

```lua
--   Card.switchLabel(pitched, slotType, ctx) position-switch ribbon text or nil (pure, unit-tested)
--   Card.staminaView(pitched)               { filled, total, tired } or nil (pure, unit-tested)
--   drawPitched opts.showStamina            pips (and the tired marker) on a pitched card
```

3b. In `Card.layout`, replace

```lua
    L.kw = { cx = w / 2, y = L.ribbon.y - kwH - math.max(1, 2 * s), h = kwH, maxW = w - 16 * s }
    return L
```

with

```lua
    L.kw = { cx = w / 2, y = L.ribbon.y - kwH - math.max(1, 2 * s), h = kwH, maxW = w - 16 * s }
    -- Stamina pips (pitched cards): a row centred between the ATK and DEF badges, under the
    -- name ribbon; on a card back it sits above the DEF label (backCy). The sweat drop (Tired)
    -- is top-left, clear of the type tag, the gem, the DEF pill and the switch ribbon.
    L.stamina = { cx = w / 2, cy = h - 13 * s, backCy = h - 36 * s, h = math.max(6, 9 * s),
                  pip = math.max(3, 5 * s), gap = math.max(1, 2 * s) }
    L.sweat   = { cx = 13 * s, cy = 28 * s, size = math.max(6, 11 * s) }
    return L
```

3c. Directly above the line that starts with `-- ── Face ──`, insert (after `drawToDefense`):

```lua
-- Sweat drop (Tired): a teardrop, drawn (the fonts have no emoji).
local function drawSweat(cx, cy, size)
    local r = size * 0.38
    Draw.setColor(Theme.ink)
    love.graphics.circle("fill", cx, cy + size * 0.18 + 1.5, r + 1.5, 16)
    Draw.setColor(Theme.tired.sweat)
    love.graphics.polygon("fill", cx, cy - size * 0.5, cx - r * 0.95, cy + size * 0.1, cx + r * 0.95, cy + size * 0.1)
    love.graphics.circle("fill", cx, cy + size * 0.18, r, 16)
    Draw.setColor(Theme.white, 0.8)
    love.graphics.circle("fill", cx - r * 0.35, cy + size * 0.1, r * 0.28, 8)
end

-- Stamina row for a staminaView: pips on a dark backing (the last pip turns orange), or, at 0,
-- a red TIRED pill plus the sweat drop. onBack: the card back's row position.
local function drawStamina(view, L, x, y, onBack)
    local st = L.stamina
    local cy = y + (onBack and st.backCy or st.cy)
    if view.tired then
        local pw = Card.staminaRowWidth(L, math.max(4, view.total))
        Draw.pill(x + st.cx - pw / 2, cy - st.h / 2 - 1, pw, st.h + 2, "TIRED", {
            fill = Theme.tired.pill, textColor = Theme.white, border = math.max(1, math.floor(L.s)),
            shadow = 0, size = math.max(6, math.floor(st.h * 0.9)),
        })
        drawSweat(x + L.sweat.cx, y + L.sweat.cy, L.sweat.size)
        return
    end
    local rw = Card.staminaRowWidth(L, view.total)
    local rx = x + st.cx - rw / 2
    Draw.roundedFill(rx, cy - st.h / 2, rw, st.h, st.h / 2, { Theme.ink[1], Theme.ink[2], Theme.ink[3], 0.6 })
    local low = view.filled <= 1
    for i = 1, view.total do
        local px = rx + st.h / 2 + (i - 1) * (st.pip + st.gap)
        if i <= view.filled then
            Draw.setColor(low and Theme.tired.low or Theme.grad.bonus[1])
        else
            Draw.setColor({ 1, 1, 1, 0.25 })
        end
        love.graphics.rectangle("fill", px, cy - st.pip / 2, st.pip, st.pip, st.pip * 0.3)
    end
end

```

3d. Directly above the line `-- Keyword pill text for a field card ("LINK-UP"), or nil (traps, strategies, no keyword).`, insert:

```lua
-- Stamina pips for a pitched card: { filled, total, tired }, or nil when it never tires.
-- Pure (unit-tested).
function Card.staminaView(pitched)
    if not pitched or pitched.stamina == nil then return nil end
    local total = Stamina.max(pitched.definition) or pitched.stamina
    return { filled = math.max(0, math.min(total, pitched.stamina)), total = total,
             tired = pitched.stamina <= 0 }
end

-- Width of a row of n stamina pips at layout L, backing included. Pure (unit-tested).
function Card.staminaRowWidth(L, n)
    local st = L.stamina
    return n * st.pip + (n - 1) * st.gap + st.h
end

```

3e. Replace the whole `Card.drawPitched` function (from `function Card.drawPitched(pitched, x, y, opts)` through its closing `end`) with:

```lua
function Card.drawPitched(pitched, x, y, opts)
    opts = opts or {}
    local w = opts.w or Theme.cardSize.pitch.w
    local h = opts.h or Theme.cardSize.pitch.h
    local L = Card.layout(w, h)
    local sv = opts.showStamina and Card.staminaView(pitched) or nil

    if not Card.showsFace(pitched) then
        Card.drawBack(x, y, w, h, {
            label = (not opts.faceDown) and (pitched.slotType == "trap" and "TRAP" or "DEF") or nil,
            canFlip = opts.switchLabel ~= nil,
            selected = opts.selected, target = opts.target,
        })
        if sv then drawStamina(sv, L, x, y, true) end
        return
    end

    local atkBonus, defBonus = Card.bonuses(pitched, opts.pitch, opts.hideHidden)

    Card.drawFace(pitched.definition, x, y, w, h, {
        atkBonus = atkBonus ~= 0 and atkBonus or nil,
        defBonus = defBonus ~= 0 and defBonus or nil,
        exhausted = pitched.exhausted, selected = opts.selected, target = opts.target,
        tired = Stamina.tired(pitched),
    })

    if pitched.mode == "defense" then
        -- Revealed defense-mode card: face-up for both players, with a DEF marker.
        local ph = L.defPill.h
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + L.defPill.y, pw, ph, "DEF", {
            fill = Theme.grad.def, textColor = Theme.white,
            border = math.max(1, math.floor(2 * L.s)), shadow = 0,
        })
        if opts.switchLabel then
            Draw.ribbon(x + w / 2, y + L.flip.y, w * 0.9, L.flip.h, opts.switchLabel, {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    elseif opts.switchLabel then
        drawToDefense(L, x, y)
    end
    if sv then drawStamina(sv, L, x, y, false) end
end
```

- [ ] **Step 4: `ui/pitch.lua`: stamina for the cards a viewer may see.**

4a. Replace

```lua
local Stats  = require("ui.match.stats")
```

with

```lua
local Stats  = require("ui.match.stats")
local Stamina = require("engine.stamina")
```

4b. Replace

```lua
        -- Position-switch ribbon (Phases.canSwitch via Card.switchLabel), your cards only.
```

with

```lua
        -- Stamina pips: your cards, and the opponent's face-up cards (hidden info otherwise).
        showStamina = slotType ~= "trap" and Stamina.visible(pitched, owner == "player"),
        -- Position-switch ribbon (Phases.canSwitch via Card.switchLabel), your cards only.
```

- [ ] **Step 5: `ui/match/zoom.lua`: the stamina line.** Replace

```lua
    add(modeText, "ink")
```

with

```lua
    add(modeText, "ink")
    -- Stamina: hidden on the opponent's face-down cards; keepers never tire.
    if Stamina.visible(pitched, not hideHidden) then
        local total = Stamina.max(cardDef) or pitched.stamina
        if Stamina.tired(pitched) then
            add("TIRED: -" .. C.STAMINA.TIRED_ATK .. " ATK / -" .. C.STAMINA.TIRED_DEF
                .. " DEF (stamina 0 / " .. total .. ")", "bad")
        else
            add("Stamina " .. pitched.stamina .. " / " .. total, pitched.stamina <= 1 and "warn" or "ink")
        end
    end
```

- [ ] **Step 6: `ui/match/toasts.lua`: tired toasts.** Replace

```lua
    if t == "card_played" then
```

with

```lua
    if t == "card_tired" then
        -- Stamina is hidden on the opponent's face-down cards: no toast for those.
        if mine then return tostring(p.name or "Your card") .. " is TIRED (-300)", "bad" end
        if p.hidden then return nil end
        return "Opp's " .. tostring(p.name or "card") .. " is TIRED", "good"
    end
    if t == "card_played" then
```

- [ ] **Step 7: `tools/snapshot/card_gallery.lua`: pips and a tired card.** Directly below the line added in Task 1 (`        530, y, { switchLabel = "TO DEFENSE" })`), insert:

```lua
    local flat = { defenders = {}, strikers = {} }
    Card.drawPitched({ definition = byId("str-poacher"), mode = "attack", slotType = "striker", stamina = 0 },
        660, y, { pitch = flat, showStamina = true })
    Card.drawPitched({ definition = byId("mid-box-to-box"), mode = "attack", slotType = "midfielder", stamina = 7 },
        790, y, { pitch = flat, showStamina = true })
```

- [ ] **Step 8: `tools/snapshot/scenarios.lua`: the `stamina` scenario.** Directly above the final line `return S`, insert:

```lua
-- Pitched card through the real engine (full stamina), optionally at a given stamina.
local function staminaCard(id, slotType, mode, stamina)
    local c = require("engine.state").newPitchedCard(defById(id), slotType, mode)
    if stamina then c.stamina = stamina end
    return c
end

-- Stamina (harness-only board): pips at 5/7, 2/6 and 1/4 (orange), a tired Poacher (sweat
-- drop, TIRED pill, red numbers), the opponent's face-up Stopper with pips and its face-down
-- Destroyer with none; the zoom's TIRED line; then the tired Poacher really attacks the
-- Stopper: "TIRED -300" beside Engine and Link-up in the overlay.
S.stamina = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local m = store().match
        local P, O = m.players.player.pitch, m.players.opponent.pitch
        P.strikers[1]  = staminaCard("str-poacher", "striker", "attack", 0)
        P.strikers[2]  = staminaCard("str-complete-forward", "striker", "attack", 1)
        P.midfielder   = staminaCard("mid-box-to-box", "midfielder", "attack", 5)
        P.defenders[1] = staminaCard("def-the-rock", "defender", "defense", 2)
        P.keeper       = staminaCard("keeper-the-wall", "keeper", "defense")
        O.defenders[1] = staminaCard("def-stopper", "defender", "attack", 3)
        O.defenders[2] = staminaCard("def-destroyer", "defender", "defense", 0)
        O.keeper       = staminaCard("keeper-iron-fists", "keeper", "defense")
        m.turn, m.phase = 2, "attack"
    end },
    { 1.9, function(c) c.snap("board") end },
    { 2.0, function() move(center(Layout.slot("player", "striker", 1))) end },
    { 2.6, function(c) c.snap("zoom") end },
    { 2.7, function()
        move(640, 60)
        local st = store()
        st:declareAttack({ type = "striker", index = 1 }, { type = "defender", index = 1 })
        require("scenes.match").debugOverlay("combat", st:popCombat())
    end },
    { 4.1, function(c) c.snap("tags") end },
    { 4.6, function(c) c.snap("result") end },
    { 4.8, function(c) c.quit() end },
}

```

- [ ] **Step 9: Run the tests, the syntax check and the smoke run**

Run: `luac -p ui/card.lua ui/pitch.lua ui/match/zoom.lua ui/match/toasts.lua tools/snapshot/card_gallery.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `463 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 10: Snapshots**

Run: `for s in stamina keywords summon; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`

Check with the Read tool:
- **`stamina_board`:**
  - The Poacher shows a red `TIRED` pill between its badges, a blue sweat drop top-left, and red numbers on pale badges with a red rim.
  - Its ATK badge reads `2050`: 2100, +100 Engine, +150 Link-up, −300 Tired.
  - Complete Forward shows 1 orange pip out of 4.
  - Box-to-Box shows 5 green pips out of 7.
  - The face-down Rock shows 2 of 6 pips above its DEF label.
  - The Wall shows no pips.
  - The opponent's Stopper shows 3 of 6 pips; the opponent's face-down Destroyer shows no pips and no TIRED pill.
  - No pip row overlaps a badge, the keyword pill or the name ribbon.
- **`stamina_zoom`:** the info sticker lists `ATK 2100 - 50 = 2050 (Engine +100, Link-up +150, Tired -300)` in red, and `TIRED: -300 ATK / -300 DEF (stamina 0 / 4)`.
- **`stamina_tags`:**
  - under your card, three tags: `ENGINE +100`, `LINK-UP +150`, `TIRED -300`;
  - the big ATK badge is red-rimmed and pale with a red number; its label reads `ATK -50`.
- **`stamina_result`:** `DESTROYED · LP -50`.
- **`keywords_gallery`:** at x≈660 the tired Poacher shows the TIRED pill, the sweat drop and `1800` in red; at x≈790 Box-to-Box shows 7 green pips.
- **`summon_myturn`:** your cards show pips; the AI's face-up cards show pips; the AI's face-down cards show none.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add ui/card.lua ui/pitch.lua ui/match/zoom.lua ui/match/toasts.lua tools/snapshot/card_gallery.lua tools/snapshot/scenarios.lua tests/test_stamina_ui.lua
git commit -m "Stamina UI: pips on cards, TIRED pill and sweat drop, zoom stamina line, tired toasts" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **463**.

---

### Task 7: Substitutions: generalised keeper swap, 3 per half, SUBS counter (spec B2, B3)

**Files:**
- Modify: `engine/state.lua`, `engine/phases.lua`, `ai/opponent.lua`, `scenes/match.lua`, `ui/match/stats.lua`, `ui/match/layout.lua`, `ui/match/bottombar.lua`, `ui/match/toasts.lua`, `tests/test_match_layout.lua`
- Test: `tests/test_substitutions.lua` (create)

- [ ] **Step 1: Write `tests/test_substitutions.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local C      = require("engine.constants")
local State  = require("engine.state")
local Phases = require("engine.phases")
local Stats  = require("ui.match.stats")
local Layout = require("ui.match.layout")
local Toasts = require("ui.match.toasts")

local function inHand(m, owner, def)
    for _, c in ipairs(m.players[owner].hand) do if c == def then return true end end
    return false
end

-- The player's summon phase: a striker on the pitch, another in hand.
local function subMatch()
    local m = H.match({ phase = "summon" })
    local out = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local inn = H.give(m, "player", H.card("striker", 2200, 600))
    return m, out, inn
end

T.test("substitution: onto an occupied slot — uses a summon and a sub; the old card goes back to hand", function()
    local m, out, inn = subMatch()
    local s = H.store(m)
    T.eq(s:summonCard(inn.id, "striker", 1, "attack"), true)
    T.eq(m.summonCount, 1); T.eq(m.players.player.subsUsed, 1)
    local now = m.players.player.pitch.strikers[1]
    T.eq(now.definition, inn); T.eq(now.mode, "attack")
    T.ok(inHand(m, "player", out.definition)); T.ok(not inHand(m, "player", inn))
    local e = H.events(m, "card_played")
    T.eq(#e, 1); T.eq(e[1].payload.action, "substitution")
    T.eq(e[1].payload.replaced, out.definition.id); T.eq(e[1].payload.name, inn.name)
end)

T.test("substitution: the incoming card waits a turn to attack (Pace excepted) and can't switch", function()
    local m, _, inn = subMatch()
    H.store(m):summonCard(inn.id, "striker", 1, "attack")
    local now = m.players.player.pitch.strikers[1]
    T.eq(Phases.canAttackNow(now), false)
    T.eq((Phases.canSwitch(now, "striker", { isOwnTurn = true, phase = "summon" })), nil)
    local m2 = H.match({ phase = "summon" })
    H.place(m2, "player", "striker", 1, H.card("striker", 2000, 500))
    local pace = H.give(m2, "player", H.kw("PACE", "striker", 2150, 550))
    H.store(m2):summonCard(pace.id, "striker", 1, "attack")
    T.eq(Phases.canAttackNow(m2.players.player.pitch.strikers[1]), true)
end)

T.test("substitution: the incoming card is fully rested; the outgoing one is too when it comes back", function()
    local m, out, inn = subMatch()
    out.stamina = 0
    local s = H.store(m)
    s:summonCard(inn.id, "striker", 1, "attack")
    T.eq(m.players.player.pitch.strikers[1].stamina, 4)
    T.eq(s:summonCard(out.definition.id, "striker", 2, "attack"), true)
    T.eq(m.players.player.pitch.strikers[2].stamina, 4)
end)

T.test("substitution: 3 per half, keeper swaps included; then refused", function()
    local m = H.match({ phase = "summon" })
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1700), "defense")
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local s = H.store(m)
    local k = H.give(m, "player", H.card("keeper", 300, 1900))
    T.eq(s:summonCard(k.id, "keeper", 0, "defense"), true)
    T.eq(m.players.player.subsUsed, 1)
    local a = H.give(m, "player", H.card("striker", 2100, 500))
    T.eq(s:summonCard(a.id, "striker", 1, "attack"), true)
    m.summonCount = 0                                  -- a new summon budget, same half
    local b = H.give(m, "player", H.card("striker", 2200, 500))
    T.eq(s:summonCard(b.id, "striker", 1, "attack"), true)
    T.eq(m.players.player.subsUsed, 3)
    local c = H.give(m, "player", H.card("striker", 2300, 500))
    local ok, err = s:summonCard(c.id, "striker", 1, "attack")
    T.eq(ok, false); T.eq(err, "no substitutions left this half")
    T.ok(inHand(m, "player", c)); T.eq(m.players.player.pitch.strikers[1].definition, b)
    T.eq(Phases.canKeeperSwap(m, H.give(m, "player", H.card("keeper", 300, 2000))), false)
end)

T.test("substitution: the summon limit applies; a sub is never a free placement", function()
    local m, out, inn = subMatch()
    m.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    local ok, err = H.store(m):summonCard(inn.id, "striker", 1, "attack")
    T.eq(ok, false); T.eq(err, "summon limit reached")
    T.eq(m.players.player.pitch.strikers[1], out); T.eq(m.players.player.subsUsed, 0)
    local m2, out2, inn2 = subMatch()
    T.eq(H.store(m2):freeSummon(inn2.id, "striker", 1, "attack"), false)
    T.eq(m2.players.player.pitch.strikers[1], out2)
end)

T.test("substitution: resets every half; Extra Time gets 3 too", function()
    local m = H.match({ phase = "summon" })
    m.players.player.subsUsed = 3
    m.players.opponent.subsUsed = 2
    State.endHalf(m, "player", "time")
    T.eq(m.players.player.subsUsed, 0); T.eq(m.players.opponent.subsUsed, 0)
    m.players.player.subsUsed = 3
    State.kickOff(m)
    State.endHalf(m, "opponent", "time")        -- 1-1: Extra Time
    T.eq(m.half, "extra"); T.eq(m.players.player.subsUsed, 0)
end)

T.test("substitution: refused for traps and strategies, a non-keeper in goal, an empty slot, the break, other phases", function()
    local m, out = subMatch()
    T.eq((Phases.canSubstitute(m, "player", H.def("trap-offside"), "striker", 1)), false)
    T.eq((Phases.canSubstitute(m, "player", H.def("strat-penalty"), "striker", 1)), false)
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    local ok, why = Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "keeper", 0)
    T.eq(ok, false); T.eq(why, "keeper slot occupied")
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 2)), false,
        "an empty slot is a summon")
    m.halfTimeBreak = true
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 1)), false)
    m.halfTimeBreak = false; m.phase = "attack"
    T.eq((Phases.canSubstitute(m, "player", H.card("striker", 2000, 500), "striker", 1)), false)
    T.eq(m.players.player.pitch.strikers[1], out)
end)

T.test("substitution: canSubstitute reads the seat it is given (the AI's mirrored view)", function()
    local m = H.match({ phase = "summon" })        -- the player is active
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    local card = H.card("striker", 2200, 500)
    T.eq((Phases.canSubstitute(m, "opponent", card, "striker", 1)), true)
    T.eq((Phases.canSubstitute(m, "player", card, "striker", 1)), false, "nothing on the player's slot")
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq((Phases.canSubstitute(m, "opponent", card, "striker", 1)), false)
end)

T.test("SUBS counter: n / 3 for your seat, in the bottom bar where the mode toggle was; toasts", function()
    local m = H.match()
    local used, max = Stats.subs(m)
    T.eq(used, 0); T.eq(max, 3)
    m.players.player.subsUsed = 2
    used, max = Stats.subs(m)
    T.eq(used, 2); T.eq(max, C.MATCH.SUBS_PER_HALF)
    local r, B = Layout.bottom.subs, Layout.bottom
    T.ok(r.y >= B.summons.y + B.summons.h and r.y + r.h <= B.startAttack.y, "between SUMMONS and START ATTACK")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "player", action = "substitution",
        name = "The Poacher", replacedName = "Speed Demon" } })), "You brought on The Poacher for Speed Demon")
    T.eq((Toasts.describe({ type = "card_played", payload = { player = "opponent", action = "substitution",
        name = "The Poacher" } })), "Opp made a substitution")
end)
```

- [ ] **Step 2: `tests/test_match_layout.lua`: the SUBS rect is on screen and disjoint.** Replace

```lua
        B.portrait, B.deck, B.deckCount, B.summons, B.startAttack, B.endTurn, B.hint, B.hand,
```

with

```lua
        B.portrait, B.deck, B.deckCount, B.summons, B.subs, B.startAttack, B.endTurn, B.hint, B.hand,
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- all 9 `substitution:` / `SUBS counter:` tests `FAIL`;
- the layout test `top bar and bottom area rects …` fails too (`B.subs` is nil);
- the run ends with `462 passed, 10 failed`.

- [ ] **Step 4: `engine/state.lua`: count substitutions per half.**

4a. Replace

```lua
        nextTurnSummonLimit = nil,  -- set by TIME_WASTING trap
    }
end
```

with

```lua
        nextTurnSummonLimit = nil,  -- set by TIME_WASTING trap
        subsUsed         = 0,       -- substitutions this half (keeper swaps included; spec B2)
    }
end
```

4b. In `State._resetHalf`, replace

```lua
        ps.nextTurnSummonLimit = nil
```

with

```lua
        ps.nextTurnSummonLimit = nil
        ps.subsUsed            = 0     -- 3 substitutions per half; Extra Time gets 3 too
```

- [ ] **Step 5: `engine/phases.lua`: `canSubstitute`, `canKeeperSwap` and the generalised `summon`.** Replace the whole `Phases.summon` function and its leading comment (from `-- Place a card from hand onto the pitch.` through its closing `end`), **and** the whole `Phases.canKeeperSwap` function and its comment (from `-- May the active player bring cardDef on as a keeper substitution now? A keeper card from` through its closing `end`). Keep `Phases._afterSummon` (added in Task 4) where it is, between the two. The new code is:

```lua
-- Place a card from hand onto the pitch.
-- mode: "attack" (face up) or "defense" (face down)
-- freeSummon = true skips the summon-count check and increment (used by Substitution).
-- An OCCUPIED slot is a substitution (spec B2; Phases.canSubstitute): the new card comes on
-- and the card that was there goes back to hand as a plain definition (fully rested when it
-- is played again). It uses a summon and one of the half's C.MATCH.SUBS_PER_HALF
-- substitutions; a keeper-slot substitution is logged as a keeper swap.
-- Returns true on success, or false + reason.
function Phases.summon(matchState, cardId, slotType, slotIndex, mode, freeSummon)
    local activeId = matchState.activePlayer
    local player   = State.activePlayerState(matchState)

    -- Strategy cards cannot be summoned
    if slotType ~= "trap" then
        local peek = nil
        for _, c in ipairs(player.hand) do if c.id == cardId then peek = c; break end end
        if peek and peek.type == "strategy" then
            return false, "strategy cards cannot be summoned"
        end
    end

    -- Summon limit (skip for trap cards which use a free set action; skip for free summons)
    if not freeSummon and slotType ~= "trap" then
        local limit = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                    + (matchState.bonusSummons or 0)   -- Metronome
        if matchState.summonCount >= limit then
            return false, "summon limit reached"
        end
    end

    local cardDef = State.removeFromHand(player, cardId)
    if not cardDef then return false, "card not in hand" end

    -- Trap card: goes face-down into the trap zone (always defense, never costs a summon)
    if cardDef.type == "trap" then
        if #player.pitch.traps >= C.PITCH.MAX_TRAPS then
            table.insert(player.hand, cardDef)
            return false, "trap zone full"
        end
        local trapCard = State.newPitchedCard(cardDef, "trap", "defense")
        table.insert(player.pitch.traps, trapCard)
        State.log(matchState, T.EventType.CARD_PLAYED,
            { player = activeId, card = cardId, slot = "trap", mode = "defense" })
        return true
    end

    mode = mode or "attack"
    if slotType ~= "keeper" and slotType ~= "defender" and slotType ~= "midfielder" and slotType ~= "striker" then
        table.insert(player.hand, cardDef)
        return false, "invalid slot"
    end
    if slotType == "defender" and (slotIndex < 1 or slotIndex > C.PITCH.MAX_DEFENDERS) then
        table.insert(player.hand, cardDef)
        return false, "defender slot out of range"
    end
    if slotType == "striker" and (slotIndex < 1 or slotIndex > C.PITCH.MAX_STRIKERS) then
        table.insert(player.hand, cardDef)
        return false, "striker slot out of range"
    end

    local slot    = { type = slotType, index = slotIndex }
    local pitched = State.newPitchedCard(cardDef, slotType, mode)
    pitched.summonedThisTurn = true   -- can't switch this turn; attacks next turn unless Pace (D1)

    local old = Phases._getSlot(player.pitch, slot)
    if old then
        -- Substitution. Never the free Substitution-card placement (it fills an empty slot).
        if freeSummon then
            table.insert(player.hand, cardDef)
            return false, slotType .. " slot occupied"
        end
        local ok, why = Phases.canSubstitute(matchState, activeId, cardDef, slotType, slotIndex)
        if not ok then
            table.insert(player.hand, cardDef)
            return false, why
        end
        Phases._setSlot(player.pitch, slot, pitched)
        table.insert(player.hand, old.definition)
        matchState.summonCount = matchState.summonCount + 1
        player.subsUsed = (player.subsUsed or 0) + 1
        State.log(matchState, T.EventType.CARD_PLAYED,
            { player = activeId, card = cardId, slot = slotType, index = slotIndex, mode = mode,
              action = slotType == "keeper" and "keeper_swap" or "substitution",
              name = cardDef.name, replaced = old.definition.id, replacedName = old.definition.name })
        Phases._afterSummon(matchState, activeId, pitched)
        return true
    end

    Phases._setSlot(player.pitch, slot, pitched)
    if not freeSummon then
        matchState.summonCount = matchState.summonCount + 1
    end
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = activeId, card = cardId, slot = slotType, index = slotIndex, mode = mode })
    Phases._afterSummon(matchState, activeId, pitched)   -- Press
    return true
end

-- Summon hooks once a card is on the pitch: Press, which costs its card
-- C.STAMINA.ABILITY_COST when it fires.
function Phases._afterSummon(matchState, ownerId, pitched)
    if Resolver.onSummon(matchState, ownerId, pitched) then
        Phases._spend(matchState, ownerId, pitched, C.STAMINA.ABILITY_COST)
    end
end

-- May playerId bring cardDef on for the card in (slotType, slotIndex) now? A substitution
-- (spec B2): a field card or keeper from hand onto one of playerId's OCCUPIED slots. The
-- keeper slot takes keeper cards only; any other slot takes any field card, as summoning
-- does. It must be the summon phase, outside the half-time break, with a summon left (it uses
-- one) and fewer than C.MATCH.SUBS_PER_HALF substitutions this half (keeper swaps included).
-- Reads matchState.players[playerId] (the AI passes its own seat on a mirrored view).
-- Returns true, or false + reason.
function Phases.canSubstitute(matchState, playerId, cardDef, slotType, slotIndex)
    local t = cardDef and cardDef.type
    if t ~= "striker" and t ~= "midfielder" and t ~= "defender" and t ~= "keeper" then
        return false, "only field cards and keepers come on as substitutes"
    end
    if matchState.halfTimeBreak then return false, "half-time" end
    if matchState.phase ~= "summon" then return false, "substitute in your summon phase" end
    local ps = matchState.players[playerId]
    if not Phases._getSlot(ps.pitch, { type = slotType, index = slotIndex }) then
        return false, "no card to substitute"
    end
    if slotType == "keeper" and t ~= "keeper" then return false, "keeper slot occupied" end
    local limit = (ps.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN) + (matchState.bonusSummons or 0)
    if matchState.summonCount >= limit then return false, "summon limit reached" end
    if (ps.subsUsed or 0) >= C.MATCH.SUBS_PER_HALF then return false, "no substitutions left this half" end
    return true
end

-- Keeper swap for the active player: a substitution onto its keeper slot. Boolean.
function Phases.canKeeperSwap(matchState, cardDef)
    return (Phases.canSubstitute(matchState, matchState.activePlayer, cardDef, "keeper", 0)) == true
end
```

- [ ] **Step 6: `ai/opponent.lua`: the keeper swap reads its own seat and stays in the budget.** In `AI._planKeeperSwap`, replace

```lua
    if not best or not Phases.canKeeperSwap(match, best) then return nil end
```

with

```lua
    -- Phases.canSubstitute on the AI's own seat: a summon and a substitution left (spec B2).
    if not best or not Phases.canSubstitute(match, "opponent", best, "keeper", 0) then return nil end
```

and replace the comment line

```lua
-- accept it (Phases.canKeeperSwap).
```

with

```lua
-- accept it (Phases.canSubstitute: within the summon and 3-per-half substitution budgets).
```

- [ ] **Step 7: `ui/match/stats.lua`: `Stats.subs`.** Directly above the final `return Stats`, insert:

```lua
-- used, max — "SUBS used / max": your substitutions this half (keeper swaps included).
function Stats.subs(match)
    return match.players.player.subsUsed or 0, C.MATCH.SUBS_PER_HALF
end

```

- [ ] **Step 8: `ui/match/layout.lua`: the SUBS rect.** Replace

```lua
    summons     = { x = 996, y = 552, w = 240, h = 34 },
```

with

```lua
    summons     = { x = 996, y = 552, w = 240, h = 34 },
    subs        = { x = 996, y = 602, w = 240, h = 34 },   -- SUBS n / 3 (where the mode toggle was)
```

- [ ] **Step 9: `ui/match/bottombar.lua`: the SUBS pill.**

9a. Replace

```lua
-- SUMMONS pill, START ATTACK / END TURN and the hint line. (The mode is chosen on the slot:
```

with

```lua
-- SUMMONS and SUBS pills, START ATTACK / END TURN and the hint line. (The mode is chosen on the slot:
```

9b. Directly above the line `-- st = { toasts = Toasts instance, hint = string }`, insert:

```lua
-- "SUBS n / 3": substitutions used this half (grey once they are all used).
local function drawSubs(match)
    local r = Layout.bottom.subs
    local used, max = Stats.subs(match)
    Draw.pill(r.x, r.y, r.w, r.h, "SUBS " .. used .. " / " .. max, {
        fill = used >= max and Theme.outcome.grey or Theme.white, textColor = Theme.inkText, size = 18,
    })
end

```

9c. Replace

```lua
    drawSummons(match)
```

with

```lua
    drawSummons(match)
    drawSubs(match)
```

- [ ] **Step 10: `ui/match/toasts.lua`: substitution toasts.** Replace

```lua
            return "Opp changed keeper", "info"
        end
```

with

```lua
            return "Opp changed keeper", "info"
        end
        if p.action == "substitution" then
            if mine then
                return "You brought on " .. tostring(p.name or "a sub") .. " for "
                    .. tostring(p.replacedName or "a card"), "info"
            end
            return "Opp made a substitution", "info"
        end
```

- [ ] **Step 11: `scenes/match.lua`: occupied slots glow for a sub.**

11a. In `Match.getHighlightedSlots`, replace

```lua
    -- Field card → only empty slots (summon phase only); a keeper card also targets your
    -- occupied GK slot (keeper substitution, Phases.canKeeperSwap).
    if match.phase ~= "summon" then return {} end
    if not pitch.keeper
       or (match.activePlayer == "player" and Phases.canKeeperSwap(match, selectedHandCard)) then
        table.insert(slots, { slotType="keeper", slotIndex=0, owner="player" })
    end
    if not pitch.midfielder then
        table.insert(slots, { slotType="midfielder", slotIndex=0, owner="player" })
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not pitch.defenders[i] then
            table.insert(slots, { slotType="defender", slotIndex=i, owner="player" })
        end
    end
    for i = 1, C.PITCH.MAX_STRIKERS do
        if not pitch.strikers[i] then
            table.insert(slots, { slotType="striker", slotIndex=i, owner="player" })
        end
    end
    return slots
```

with

```lua
    -- Field card (your summon phase): every empty slot, and every occupied slot it may
    -- substitute into (Phases.canSubstitute: keeper cards only onto your GK; a summon and a
    -- substitution left).
    if match.phase ~= "summon" or match.activePlayer ~= "player" then return {} end
    for _, s in ipairs(Layout.slots()) do
        if s.owner == "player" then
            local occupied = Match.getCardInSlot(pitch, s) ~= nil
            if not occupied
               or Phases.canSubstitute(match, "player", selectedHandCard, s.slotType, s.slotIndex) then
                table.insert(slots, { slotType = s.slotType, slotIndex = s.slotIndex, owner = "player" })
            end
        end
    end
    return slots
```

11b. In the placement block, replace

```lua
                if not Match.slotAccepts(match, slot) then return end
```

with

```lua
                if not Match.slotAccepts(match, slot) then
                    -- An occupied slot that won't take a substitute says why.
                    if Match.getCardInSlot(match.players.player.pitch, slot) then
                        local _, why = Phases.canSubstitute(match, "player", selectedHandCard,
                                                            slot.slotType, slot.slotIndex)
                        if why then Match.flash(why) end
                    end
                    return
                end
```

11c. In `Match.hintText`, replace

```lua
            return "Click your GK to bring this keeper on (uses a summon)"
        elseif selectedHandCard then
            return "Click a glowing slot, then choose ATTACK or DEFEND  ·  ESC to cancel"
```

with

```lua
            return "Click your GK to bring this keeper on (a summon and a sub)"
        elseif selectedHandCard then
            return "Click a glowing slot (an occupied one is a sub: a summon + 1 SUB), then ATTACK or DEFEND  ·  ESC to cancel"
```

- [ ] **Step 12: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/state.lua engine/phases.lua ai/opponent.lua scenes/match.lua ui/match/stats.lua ui/match/layout.lua ui/match/bottombar.lua ui/match/toasts.lua && lua tests/run.lua`
Expected: no `luac` output; `472 passed, 0 failed`. Every older `Keeper swap` test still passes.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 13: Snapshots**

Run: `for s in keeperswap summon match; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`

Check with the Read tool:
- **`keeperswap_before`:**
  - the bottom bar shows `SUMMONS 0 / 2` and, below it, `SUBS 0 / 3` in the old toggle's place;
  - your GK glows; the hint mentions "a summon and a sub".
- **`keeperswap_after`:**
  - `SUMMONS 1 / 2` and `SUBS 1 / 3`;
  - a toast reads "You brought on The Wall in goal".
- **`summon_two`:** `SUBS 0 / 3`; the pills don't overlap START ATTACK.
- **`match_start`:** the SUBS pill doesn't overlap the SUMMONS pill or START ATTACK.

- [ ] **Step 14: Commit**

```bash
ls luac.out
git add engine/state.lua engine/phases.lua ai/opponent.lua scenes/match.lua ui/match/stats.lua ui/match/layout.lua ui/match/bottombar.lua ui/match/toasts.lua tests/test_substitutions.lua tests/test_match_layout.lua
git commit -m "Substitutions: any occupied slot, a summon and one of 3 subs per half (keeper swaps count), SUBS counter" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **472**.

---

### Task 8: The Substitution card is the special sub (spec B2)

**Files:**
- Modify: `engine/state.lua`, `engine/phases.lua`, `engine/cards/definitions/strategies.lua`, `ui/match/zoom.lua`, `scenes/match.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_substitution_card.lua` (create)

- [ ] **Step 1: Write `tests/test_substitution_card.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- The player's summon phase: a striker on the pitch, the Substitution card and a replacement
-- striker in hand.
local function subCardMatch()
    local m = H.match({ phase = "summon" })
    local out  = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local card = H.give(m, "player", H.def("strat-substitution"))
    local inn  = H.give(m, "player", H.card("striker", 2200, 600))
    return m, H.store(m), card, out, inn
end

T.test("Substitution card: return a card, then place one in the freed slot — no summon, no sub", function()
    local m, s, card, out, inn = subCardMatch()
    local r = s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    T.eq(r.outcome, "substitution_done")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(s:freeSummon(inn.id, "striker", 1, "attack"), true)
    T.eq(m.summonCount, 0); T.eq(m.players.player.subsUsed, 0)
    T.eq(m.players.player.pitch.strikers[1].definition, inn)
    local back = false
    for _, c in ipairs(m.players.player.hand) do if c == out.definition then back = true end end
    T.ok(back)
end)

T.test("Substitution card: the incoming card may attack this turn (not a Pace trigger) but can't switch", function()
    local m, s, card, _, inn = subCardMatch()
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    s:freeSummon(inn.id, "striker", 1, "attack")
    local now = m.players.player.pitch.strikers[1]
    T.eq(now.actsImmediately, true)
    T.eq((Phases.canSwitch(now, "striker", { isOwnTurn = true, phase = "summon" })), nil)
    s:startAttackPhase()
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1800), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#H.triggers(m), 0, "no Pace trigger")
end)

T.test("Substitution card: the free placement only fills the freed slot, once", function()
    local m, s, card, _, inn = subCardMatch()
    local extra = H.give(m, "player", H.card("striker", 1900, 500))
    local ok, err = s:freeSummon(inn.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "no free placement pending")
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    ok, err = s:freeSummon(inn.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "place it in the freed slot")
    T.eq(s:freeSummon(inn.id, "striker", 1, "attack"), true)
    ok, err = s:freeSummon(extra.id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "no free placement pending")
end)

T.test("Substitution card: an unused free placement ends with the turn", function()
    local m, s, card = subCardMatch()
    s:playStrategy(card.id, { returnSlot = { type = "striker", index = 1 } })
    T.ok(m.players.player.subFreedSlot ~= nil)
    Phases.endTurn(m)
    T.eq(m.players.player.subFreedSlot, nil)
end)

T.test("Substitution card: its text states the special sub", function()
    local t = H.def("strat-substitution").abilityText
    T.ok(t:find("no summon", 1, true) ~= nil)
    T.ok(t:find("no substitution", 1, true) ~= nil)
    T.ok(t:find("may attack this turn", 1, true) ~= nil)
    T.ok(t:find("in response", 1, true) == nil, "the unimplemented response play is gone")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 4 `FAIL` lines: the `may attack this turn`, `only fills the freed slot`, `ends with the turn` and `its text` tests. The first test already passes, because the old free-summon flow works.
- The run ends with `473 passed, 4 failed`.

- [ ] **Step 3: `engine/state.lua`: the pending free placement.**

3a. Replace

```lua
        subsUsed         = 0,       -- substitutions this half (keeper swaps included; spec B2)
    }
end
```

with

```lua
        subsUsed         = 0,       -- substitutions this half (keeper swaps included; spec B2)
        subFreedSlot     = nil,     -- Substitution card: the slot its free placement fills this turn
    }
end
```

3b. Replace

```lua
        ps.subsUsed            = 0     -- 3 substitutions per half; Extra Time gets 3 too
```

with

```lua
        ps.subsUsed            = 0     -- 3 substitutions per half; Extra Time gets 3 too
        ps.subFreedSlot        = nil
```

- [ ] **Step 4: `engine/phases.lua`: the free placement rules.**

4a. In `Phases.summon`, replace

```lua
    -- Summon limit (skip for trap cards which use a free set action; skip for free summons)
```

with

```lua
    -- The Substitution card's free placement: only into the slot it freed, once, this turn.
    if freeSummon then
        local fs = player.subFreedSlot
        if not fs then return false, "no free placement pending" end
        if fs.type ~= slotType or (fs.index or 0) ~= (slotIndex or 0) then
            return false, "place it in the freed slot"
        end
    end

    -- Summon limit (skip for trap cards which use a free set action; skip for free summons)
```

4b. In `Phases.summon`, replace

```lua
    Phases._setSlot(player.pitch, slot, pitched)
    if not freeSummon then
        matchState.summonCount = matchState.summonCount + 1
    end
```

with

```lua
    Phases._setSlot(player.pitch, slot, pitched)
    if freeSummon then
        -- Substitution card: no summon, no substitution, and it may act at once (spec B2).
        player.subFreedSlot     = nil
        pitched.actsImmediately = true
    else
        matchState.summonCount = matchState.summonCount + 1
    end
```

4c. In `Phases.playStrategy`, replace

```lua
        Phases._setSlot(player.pitch, opts.returnSlot, nil)
        table.insert(player.hand, returnCard.definition)
```

with

```lua
        Phases._setSlot(player.pitch, opts.returnSlot, nil)
        table.insert(player.hand, returnCard.definition)
        -- The free placement (Phases.summon with freeSummon) fills this slot, this turn.
        player.subFreedSlot = { type = opts.returnSlot.type, index = opts.returnSlot.index or 0 }
```

4d. Replace the whole `Phases.canAttackNow` function and its comment (from `-- True when a card can declare an attack right now: attack mode, not exhausted, not locked,` through its closing `end`) with:

```lua
-- True when a card can declare an attack right now: attack mode, not exhausted, not locked,
-- and not summoned this turn — unless it has Pace, came on with the Substitution card
-- (actsImmediately), or C.MATCH.SUMMONED_CAN_ATTACK is on. Pure (engine, AI, scene).
function Phases.canAttackNow(card)
    if not card or card.exhausted or card.cannotActNextTurn or card.mode ~= "attack" then
        return false
    end
    if card.summonedThisTurn and not card.actsImmediately and not C.MATCH.SUMMONED_CAN_ATTACK
       and not Resolver.canAttackWhenSummoned(card) then
        return false
    end
    return true
end
```

4e. In `Phases.attack`, replace

```lua
    -- Pace: a card summoned this turn only gets this far with Pace.
    if attacker.summonedThisTurn and not C.MATCH.SUMMONED_CAN_ATTACK then
```

with

```lua
    -- Pace: a card summoned this turn only gets this far with Pace (or as the Substitution
    -- card's incoming card, which is no Pace trigger).
    if attacker.summonedThisTurn and not attacker.actsImmediately and not C.MATCH.SUMMONED_CAN_ATTACK then
```

4f. In `Phases.endTurn` (`recoverPitch`), replace

```lua
                c.summonedThisTurn  = false
                c.modeChanged       = false
```

with

```lua
                c.summonedThisTurn  = false
                c.modeChanged       = false
                c.actsImmediately   = nil
```

and replace

```lua
    matchState.players[activeId].pitch.throughBallUsed = nil   -- Through ball: once per turn
```

with

```lua
    matchState.players[activeId].pitch.throughBallUsed = nil   -- Through ball: once per turn
    matchState.players[activeId].subFreedSlot = nil            -- Substitution card: this turn only
```

- [ ] **Step 5: `engine/cards/definitions/strategies.lua`: the new card text.** Replace

```lua
        activationPhase = "summon_or_response",
        abilityText  = "Play during your summon phase, OR during your attack phase in response to an opponent targeting one of your cards. Return that card to your hand. Immediately summon one card from your hand to that slot — does not cost a summon. The returned card cannot be resummoned this turn.",
```

with

```lua
        activationPhase = "summon",
        abilityText  = "Play during your summon phase: return one of your pitch cards to your hand, then place a card from your hand in that slot. The placement costs no summon and no substitution (SUBS), and the new card may attack this turn.",
```

- [ ] **Step 6: `ui/match/zoom.lua`: the substitute's line.** Replace

```lua
    if pitched.summonedThisTurn and pitched.mode == "attack" and pitched.slotType ~= "keeper"
       and not C.MATCH.SUMMONED_CAN_ATTACK and not Resolver.canAttackWhenSummoned(pitched) then
        add("Just summoned: attacks next turn", "warn")
    end
```

with

```lua
    if pitched.summonedThisTurn and pitched.actsImmediately then
        add("Substitute: may attack this turn", "bonus")
    elseif pitched.summonedThisTurn and pitched.mode == "attack" and pitched.slotType ~= "keeper"
       and not C.MATCH.SUMMONED_CAN_ATTACK and not Resolver.canAttackWhenSummoned(pitched) then
        add("Just summoned: attacks next turn", "warn")
    end
```

- [ ] **Step 7: `scenes/match.lua`: the freed-slot hint.** Replace

```lua
            return "SUBSTITUTION: select a card and place it in the freed slot (free)"
```

with

```lua
            return "SUBSTITUTION: place a card in the freed slot — free, no SUB used, it may attack this turn"
```

- [ ] **Step 8: `tools/snapshot/scenarios.lua`: the `subs` scenario.** Directly above the final line `return S`, insert:

```lua
-- Substitutions (harness-only board, turn 2): a tired Poacher and a 1-stamina Complete
-- Forward up front, the Stopper facing them. Speed Demon replaces the Poacher through the
-- picker on the occupied slot (SUBS 1 / 3, the Poacher back in hand). Then the Substitution
-- card returns the Complete Forward and Clinical Finisher comes on free (SUBS still 1 / 3,
-- SUMMONS 1 / 2) and is selected as an attacker the same turn.
local subIn, subCardDef, subFree
S.subs = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local m = store().match
        local P, O = m.players.player.pitch, m.players.opponent.pitch
        P.strikers[1]  = staminaCard("str-poacher", "striker", "attack", 0)
        P.strikers[2]  = staminaCard("str-complete-forward", "striker", "attack", 1)
        O.defenders[1] = staminaCard("def-stopper", "defender", "attack")
        subIn      = defById("str-speed-demon")
        subCardDef = defById("strat-substitution")
        subFree    = defById("str-clinical-finisher")
        table.insert(hand(), subIn)
        table.insert(hand(), subCardDef)
        table.insert(hand(), subFree)
        m.turn = 2
    end },
    { 1.8, function() move(handPoint(subIn)) end },
    { 2.0, function() press(handPoint(subIn)) end },
    { 2.1, function() move(640, 60) end },
    { 2.4, function(c) c.snap("select") end },
    { 2.5, function() click(center(Layout.slot("player", "striker", 1))) end },
    { 2.8, function(c) c.snap("picker") end },
    { 2.9, function() love.keypressed("a") end },
    { 3.0, function() move(640, 60) end },
    { 3.7, function(c) c.snap("sub") end },
    { 3.8, function() press(handPoint(subCardDef)) end },
    { 4.0, function() click(center(Layout.slot("player", "striker", 2))) end },
    { 4.1, function() move(640, 60) end },
    { 4.4, function(c) c.snap("freed") end },
    { 4.5, function() press(handPoint(subFree)) end },
    { 4.7, function() click(center(Layout.slot("player", "striker", 2))) end },
    { 4.8, function() love.keypressed("a") end },
    { 4.9, function() move(640, 60) end },
    { 5.6, function(c) c.snap("subcard") end },
    { 5.7, function() click(center(Layout.bottom.startAttack)) end },
    { 5.9, function() click(center(Layout.slot("player", "striker", 2))) end },
    { 6.0, function() move(640, 60) end },
    { 6.4, function(c) c.snap("attacker") end },
    { 6.6, function(c) c.quit() end },
}

```

- [ ] **Step 9: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/state.lua engine/phases.lua engine/cards/definitions/strategies.lua ui/match/zoom.lua scenes/match.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `477 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 10: Snapshots**

Run: `tools/snapshot/snap.sh subs`

Check with the Read tool:
- **`subs_select`:** both of your occupied striker slots glow (sub targets) along with your empty slots, and the hint mentions "an occupied one is a sub".
- **`subs_picker`:** the picker sits on striker slot 1, over the tired Poacher.
- **`subs_sub`:**
  - Speed Demon is in striker slot 1 with 4 full pips;
  - the Poacher is back in the hand;
  - `SUMMONS 1 / 2` and `SUBS 1 / 3`;
  - a toast reads "You brought on Speed Demon for The Poacher".
- **`subs_freed`:** striker slot 2 is empty and glows alone, and the hint names the free placement.
- **`subs_subcard`:**
  - Clinical Finisher is in striker slot 2 with 4 pips;
  - `SUMMONS 1 / 2` and `SUBS 1 / 3` (unchanged);
  - Complete Forward is in the hand.
- **`subs_attacker`:**
  - Clinical Finisher is selected (yellow ring), not flashed "summoned this turn";
  - the opponent's defender slots and keeper slot glow red as targets.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add engine/state.lua engine/phases.lua engine/cards/definitions/strategies.lua ui/match/zoom.lua scenes/match.lua tools/snapshot/scenarios.lua tests/test_substitution_card.lua
git commit -m "Substitution card: free, no sub used, the incoming card may attack at once; engine enforces the freed slot" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **477**.

---

### Task 9: AI substitutions (spec B2, AI)

**Files:**
- Modify: `ai/opponent.lua`
- Test: `tests/test_ai_subs.lua` (create)

- [ ] **Step 1: Write `tests/test_ai_subs.lua`.**

```lua
local T  = require("tests.t")
local H  = require("tests.helpers")
local C  = require("engine.constants")
local AI = require("ai.opponent")

-- The AI's summon phase: keeper, both defender slots and the midfielder slot filled.
local function aiTurn()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800), "defense")
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900), "defense")
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1500, 1500), "defense")
    return m
end

local function ofType(acts, t)
    local out = {}
    for _, a in ipairs(acts) do if a.type == t then out[#out + 1] = a end end
    return out
end

T.test("AI subs: a tired striker comes off for a striker from hand (a summon and a sub)", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    local inn = H.give(m, "opponent", H.card("striker", 2200, 600))
    H.give(m, "opponent", H.card("defender", 900, 2000))           -- not the same line
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1)
    T.eq(acts[1].cardId, inn.id); T.eq(acts[1].slotType, "striker"); T.eq(acts[1].slotIndex, 1)
    T.eq(acts[1].mode, "attack")
    AI.executeAction(H.store(m), acts[1])
    T.eq(m.players.opponent.pitch.strikers[1].definition, inn)
    T.eq(m.players.opponent.subsUsed, 1)
end)

T.test("AI subs: a striker at 1 stamina comes off; other lines only when tired", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 1
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    m.players.opponent.pitch.defenders[1].stamina = 1
    local s = H.give(m, "opponent", H.card("striker", 2200, 600))
    H.give(m, "opponent", H.card("defender", 900, 2000))
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1); T.eq(acts[1].cardId, s.id); T.eq(acts[1].slotIndex, 1)
end)

T.test("AI subs: none without a same-line card, a sub or a summon left", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    H.give(m, "opponent", H.card("midfielder", 1800, 1500))
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no striker in hand")
    H.give(m, "opponent", H.card("striker", 2200, 600))
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no subs left")
    m.players.opponent.subsUsed = 0
    m.summonCount = C.MATCH.MAX_SUMMONS_PER_TURN
    T.eq(#ofType(AI._planSummons(m), "summon"), 0, "no summons left")
end)

T.test("AI subs: the keeper swap stays within the 3-sub budget", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500), "defense")
    H.give(m, "opponent", H.card("keeper", 300, 2000))
    local function swaps()
        local n = 0
        for _, a in ipairs(AI._planSummons(m)) do
            if a.type == "summon" and a.slotType == "keeper" then n = n + 1 end
        end
        return n
    end
    T.eq(swaps(), 1)
    m.players.opponent.subsUsed = C.MATCH.SUBS_PER_HALF
    T.eq(swaps(), 0)
end)

T.test("AI subs: the Substitution card goes first — free, no sub used, and the new striker attacks at once", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    H.place(m, "opponent", "striker", 2, H.card("striker", 2100, 500))
    local card = H.give(m, "opponent", H.def("strat-substitution"))
    local inn  = H.give(m, "opponent", H.card("striker", 2400, 600))
    local acts = AI._planSummons(m)
    local sc = ofType(acts, "subCard")
    T.eq(#sc, 1); T.eq(sc[1].cardId, card.id); T.eq(sc[1].inId, inn.id)
    T.eq(#ofType(acts, "summon"), 0)
    local s = H.store(m)
    AI.executeAction(s, sc[1])
    T.eq(m.players.opponent.pitch.strikers[1].definition, inn)
    T.eq(m.summonCount, 0); T.eq(m.players.opponent.subsUsed, 0)
    s:startAttackPhase()
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1800), "defense")
    local atk = AI._planNextAttack(m, "medium")
    T.ok(atk ~= nil and atk.attackerSlot.index == 1, "the substitute attacks this turn")
end)

T.test("AI subs: empty slots are filled before anyone is subbed", function()
    local m = aiTurn()
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500)).stamina = 0
    local inn = H.give(m, "opponent", H.card("striker", 2200, 600))
    local acts = ofType(AI._planSummons(m), "summon")
    T.eq(#acts, 1); T.eq(acts[1].cardId, inn.id); T.eq(acts[1].slotIndex, 2, "the empty striker slot")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 3 `FAIL` lines: `AI subs: a tired striker …`, `AI subs: a striker at 1 stamina …` and `AI subs: the Substitution card goes first …`;
- the other three already pass (no subs planned, the keeper swap budget from Task 7, empty slots first);
- the run ends with `480 passed, 3 failed`.

- [ ] **Step 3: `ai/opponent.lua`: execute the Substitution card.** Replace

```lua
    elseif action.type == "setTrap" then
```

with

```lua
    elseif action.type == "subCard" then
        -- The Substitution card: return the tired card, then the free placement in its slot.
        local r, err = store:playStrategy(action.cardId, { returnSlot = action.returnSlot })
        if not r or r.outcome ~= "substitution_done" then
            return false, nil, err or "substitution refused"
        end
        local ok, err2 = store:freeSummon(action.inId, action.returnSlot.type, action.returnSlot.index,
                                          action.mode)
        if not ok then return false, nil, err2 or "free placement refused" end

    elseif action.type == "setTrap" then
```

- [ ] **Step 4: `ai/opponent.lua`: sub helpers.** Directly above the line `-- Cover specialists: Sweeper (Libero) and Intercept (Pressing Back) cover an empty defender`, insert:

```lua
-- ── Substitutions (spec B2) ───────────────────────────────────────────────────

-- A field card needs a sub when it is Tired (stamina 0), or is a striker-slot card at
-- AI.SUB_STRIKER_AT or less (its next attack tires it).
AI.SUB_STRIKER_AT        = 1
-- Plan decision P3: tired subs use the Substitution card first (free, no sub used, the new
-- card may attack at once). false: the AI never plays it.
AI.USE_SUBSTITUTION_CARD = true

-- A hand card's value for its line: ATK for strikers and midfielders, DEF for defenders.
function AI._lineValue(cardDef)
    local st = cardDef.stats or {}
    if cardDef.type == "defender" then return st.def or 0 end
    return st.atk or 0
end

-- The mode a substitute comes on in (as AI._pickBestSlot places that card type).
function AI._subMode(cardDef, slotType)
    if slotType == "striker" then return "attack" end
    local st = cardDef.stats or {}
    if slotType == "midfielder" then return (st.atk or 0) >= (st.def or 0) and "attack" or "defense" end
    return (AI._coverSpecialist(cardDef) and cardDef.keyword ~= "INTERCEPT") and "attack" or "defense"
end

-- The AI's field cards that need a substitute (never keepers: they never tire), lowest
-- stamina first, then strikers, midfielder, defenders: { card, slotType, slotIndex }.
function AI._subTargets(match)
    local pitch = match.players.opponent.pitch
    local out = {}
    local function consider(c, slotType, slotIndex)
        if not c or c.stamina == nil then return end
        if Stamina.tired(c) or (slotType == "striker" and c.stamina <= AI.SUB_STRIKER_AT) then
            out[#out + 1] = { card = c, slotType = slotType, slotIndex = slotIndex, order = #out + 1 }
        end
    end
    for i = 1, C.PITCH.MAX_STRIKERS do consider(pitch.strikers[i], "striker", i) end
    consider(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do consider(pitch.defenders[i], "defender", i) end
    table.sort(out, function(a, b)
        if a.card.stamina ~= b.card.stamina then return a.card.stamina < b.card.stamina end
        return a.order < b.order
    end)
    return out
end

```

- [ ] **Step 5: `ai/opponent.lua`: the full `_planSummons`.** Replace the whole `AI._planSummons` function (from `function AI._planSummons(match)` through its closing `end`) with:

```lua
function AI._planSummons(match)
    local player     = match.players.opponent
    local pitch      = player.pitch
    -- Real limit (Time Wasting sets 1) minus the summons already made this turn
    local limit      = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                     + (match.bonusSummons or 0)   -- Metronome
    local summonLeft = limit - (match.summonCount or 0)
    local subsLeft   = C.MATCH.SUBS_PER_HALF - (player.subsUsed or 0)
    local actions = {}

    local used = {
        keeper     = pitch.keeper ~= nil,
        defenders  = {},
        midfielder = pitch.midfielder ~= nil,
        strikers   = {},
    }
    for i = 1, C.PITCH.MAX_DEFENDERS do used.defenders[i] = pitch.defenders[i] ~= nil end
    for i = 1, C.PITCH.MAX_STRIKERS  do used.strikers[i]  = pitch.strikers[i]  ~= nil end
    -- Cover bookkeeping for _pickBestSlot / _planFlips: does a ready face-up card already
    -- cover an empty defender slot?
    used.coverer = AI._hasDefenderCoverer(pitch)

    -- Separate hand into groups
    local hand = {}
    for _, c in ipairs(player.hand) do table.insert(hand, c) end
    local usedHand = {}   -- indices into `hand` already planned (copies share ids)

    -- Press: with a face-up enemy defender to press, a Press card goes first in its group.
    local pressBoost = false
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = match.players.player.pitch.defenders[i]
        if d and (d.mode == "attack" or d.revealed) then pressBoost = true end
    end
    local function value(c)
        local v = (c.type == "striker" or c.type == "midfielder")
                  and (c.stats and c.stats.atk or 0)
                   or (c.stats and c.stats.def or 0)
        if pressBoost and c.keyword == "PRESS" then v = v + 10000 end
        return v
    end

    -- Priority: keeper > striker (by ATK) > midfielder (by ATK) > defender (by DEF) > others
    local typePri = { keeper=5, striker=4, midfielder=3, defender=2, trap=1, strategy=0 }
    table.sort(hand, function(a, b)
        local ap = typePri[a.type] or 0
        local bp = typePri[b.type] or 0
        if ap ~= bp then return ap > bp end
        return value(a) > value(b)
    end)

    -- Set traps first (free, no summon cost)
    local trapSlotsUsed = #pitch.traps
    for hi, cardDef in ipairs(hand) do
        if cardDef.type == "trap" and trapSlotsUsed < C.PITCH.MAX_TRAPS then
            table.insert(actions, { type = "setTrap", cardId = cardDef.id })
            trapSlotsUsed = trapSlotsUsed + 1
            usedHand[hi] = true
        end
    end

    -- Place field cards
    for hi, cardDef in ipairs(hand) do
        if summonLeft <= 0 then break end
        if cardDef.type == "trap" or cardDef.type == "strategy" then goto continue end

        if cardDef.type == "keeper" then
            if not used.keeper then
                table.insert(actions, {
                    type = "summon", cardId = cardDef.id,
                    slotType = "keeper", slotIndex = 0, mode = "defense",
                })
                used.keeper = true
                usedHand[hi] = true
                summonLeft  = summonLeft - 1
            end
        else
            local slot, mode = AI._pickBestSlot(cardDef, used)
            if slot then
                table.insert(actions, {
                    type = "summon", cardId = cardDef.id,
                    slotType = slot.slotType, slotIndex = slot.slotIndex, mode = mode,
                })
                if slot.slotType == "striker"    then used.strikers[slot.slotIndex]  = true
                elseif slot.slotType == "midfielder" then used.midfielder              = true
                elseif slot.slotType == "defender"   then used.defenders[slot.slotIndex] = true
                end
                if (mode == "attack" and (slot.slotType == "midfielder"
                   or (slot.slotType == "defender" and AI._coverSpecialist(cardDef))))
                   or (slot.slotType == "defender" and cardDef.keyword == "INTERCEPT") then
                    used.coverer = true   -- Intercept covers face-down too
                end
                usedHand[hi] = true
                summonLeft = summonLeft - 1
            end
        end

        ::continue::
    end

    -- Substitutions for tired cards (spec B2), once the empty slots are filled: the best
    -- unused same-line card in hand comes on. The Substitution card goes first (P3); then
    -- normal subs while a summon and a substitution are left.
    local subbed = {}
    local subCardIdx = nil
    if AI.USE_SUBSTITUTION_CARD then
        for hi, c in ipairs(hand) do
            if c.ability == "SUBSTITUTION" and not usedHand[hi] then subCardIdx = hi; break end
        end
    end
    for _, t in ipairs(AI._subTargets(match)) do
        local bestIdx = nil
        for hi, c in ipairs(hand) do
            if not usedHand[hi] and c.type == t.slotType
               and (not bestIdx or AI._lineValue(c) > AI._lineValue(hand[bestIdx])) then
                bestIdx = hi
            end
        end
        if bestIdx then
            local inn  = hand[bestIdx]
            local slot = { type = t.slotType, index = t.slotIndex }
            local mode = AI._subMode(inn, t.slotType)
            if subCardIdx then
                table.insert(actions, { type = "subCard", cardId = hand[subCardIdx].id,
                                        returnSlot = slot, inId = inn.id, mode = mode })
                usedHand[subCardIdx], usedHand[bestIdx] = true, true
                subCardIdx = nil
                subbed[t.slotType .. ":" .. t.slotIndex] = true
            elseif summonLeft > 0 and subsLeft > 0 then
                table.insert(actions, { type = "summon", cardId = inn.id, slotType = t.slotType,
                                        slotIndex = t.slotIndex, mode = mode })
                usedHand[bestIdx] = true
                summonLeft = summonLeft - 1
                subsLeft   = subsLeft - 1
                subbed[t.slotType .. ":" .. t.slotIndex] = true
            end
        end
    end

    -- Keeper substitution within the summon and substitution budgets, after the rest.
    if summonLeft > 0 and subsLeft > 0 and pitch.keeper then
        local swap = AI._planKeeperSwap(match)
        if swap then
            table.insert(actions, swap)
            summonLeft = summonLeft - 1
            subsLeft   = subsLeft - 1
        end
    end

    -- Position switches after the summons (flips see the slots this turn's summons fill);
    -- never for a card that is being substituted.
    for _, f in ipairs(AI._planFlips(match, used)) do
        if not subbed[f.slotType .. ":" .. f.slotIndex] then table.insert(actions, f) end
    end
    for _, sw in ipairs(AI._planSwitches(match, used)) do
        if not subbed[sw.slotType .. ":" .. sw.slotIndex] then table.insert(actions, sw) end
    end

    return actions
end
```

- [ ] **Step 6: Run the tests, the syntax check and the smoke run**

Run: `luac -p ai/opponent.lua && lua tests/run.lua`
Expected: no `luac` output; `483 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: a line starting `games=18  stalls=0`.

- [ ] **Step 7: Commit**

```bash
ls luac.out
git add ai/opponent.lua tests/test_ai_subs.lua
git commit -m "AI: substitute tired cards (Substitution card first), keeper swaps within the 3-sub budget" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **483**.

---

### Task 10: Simulator stamina and substitution stats (spec, Verification)

**Files:**
- Modify: `tools/sim/sim.lua`

- [ ] **Step 1: Header.** Replace

```lua
-- (ABILITY REVIEW line); acceptance itself is unchanged.
```

with

```lua
-- (ABILITY REVIEW line); acceptance itself is unchanged.
--
-- Modes & stamina (2026-09-24 modes-stamina spec, Verification): cards tired per match
-- (card_tired events), substitutions per match per seat (card_played keeper_swap /
-- substitution) and Substitution-card use (strategy_played SUBSTITUTION). Acceptance is
-- unchanged.
```

- [ ] **Step 2: Counters.** Replace

```lua
    kw = {}, cardGames = {}, cardWins = {},
}
```

with

```lua
    kw = {}, cardGames = {}, cardWins = {},
    tired = 0, subs = { player = 0, opponent = 0 }, subCard = { player = 0, opponent = 0 },
}
```

- [ ] **Step 3: Record.** Replace

```lua
        elseif e.type == "ability_triggered" then
            inc(S.kw, p.keyword)
        end
```

with

```lua
        elseif e.type == "ability_triggered" then
            inc(S.kw, p.keyword)
        elseif e.type == "card_tired" then
            S.tired = S.tired + 1
        elseif e.type == "strategy_played" and p.ability == "SUBSTITUTION" then
            inc(S.subCard, p.player)
        end
        if e.type == "card_played" and (p.action == "keeper_swap" or p.action == "substitution") then
            inc(S.subs, p.player)
        end
```

- [ ] **Step 4: Report.** Replace

```lua
print(string.format("keeper swaps: %d (%.3f/match)", S.keeperSwaps, avg(S.keeperSwaps, S.games)))
```

with

```lua
print(string.format("keeper swaps: %d (%.3f/match)", S.keeperSwaps, avg(S.keeperSwaps, S.games)))
print("stamina & substitutions:")
print(string.format("  cards tired: %.2f/match", avg(S.tired, S.games)))
print(string.format("  substitutions/match: first seat %.2f  second seat %.2f  (keeper swaps included)",
    avg(S.subs.player, S.games), avg(S.subs.opponent, S.games)))
print(string.format("  Substitution card: %.3f/match  (first seat %d, second seat %d)",
    avg(S.subCard.player + S.subCard.opponent, S.games), S.subCard.player, S.subCard.opponent))
```

- [ ] **Step 5: Run**

Run: `luac -p tools/sim/sim.lua && lua tools/sim/sim.lua n=2 seed=1 | grep -A3 '^stamina & substitutions:'`
Expected: four lines, and every number is a plain decimal. On this tiny run, `cards tired` and `substitutions/match` should be greater than 0.

Run: `lua tests/run.lua`
Expected: `483 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
ls luac.out
git add tools/sim/sim.lua
git commit -m "Simulator: cards tired, substitutions per seat and Substitution-card use per match" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **483**.

---

### Task 11: `rules.md` (spec, Verification)

**Files:**
- Modify: `rules.md`

- [ ] **Step 1: Header.** Replace

```markdown
This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update
and the 2026-09-24 card abilities).
```

with

```markdown
This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update,
the 2026-09-24 card abilities and the 2026-09-24 card modes & stamina).
```

- [ ] **Step 2: At a glance.** Replace

```markdown
- Kick-off alternates: **you** kick off half 1, **the opponent** kicks off half 2, and a
  **coin toss** decides who kicks off Extra Time.
```

with

```markdown
- Kick-off alternates: **you** kick off half 1, **the opponent** kicks off half 2, and a
  **coin toss** decides who kicks off Extra Time.
- You choose each card's mode on its slot and may switch positions once per turn.
- Field cards tire: at **0 stamina** a card is **Tired** (−300 ATK / −300 DEF). You have
  **3 substitutions** per half.
```

- [ ] **Step 3: Turn Structure.** Replace

```markdown
2. **Summon** — place up to **2** field cards (+1 with **Metronome**) in attack or defense mode
   (1 if the opponent played Time Wasting); set trap cards (free, at most 2 on the field); flip
   your face-down cards to attack mode (free); play Substitution; bring on a new keeper
   (**keeper substitution**, below).
```

with

```markdown
2. **Summon** — place up to **2** field cards (+1 with **Metronome**; 1 if the opponent played
   Time Wasting): drop a card on a slot, then choose **ATTACK** (face-up) or **DEFEND**
   (face-down); set trap cards (free, at most 2 on the field); **switch** your cards' positions
   (free, see **Card Modes**); **substitute** (below); play Substitution.
```

and replace

```markdown
4. **End** — your exhausted cards recover.
```

with

```markdown
4. **End** — your exhausted cards recover, and each of your field cards loses 1 stamina
   (see **Stamina**).
```

- [ ] **Step 4: Substitutions.** Replace everything from the line `### Keeper substitution` through the line `- On the match screen, select a keeper card in your hand: your GK slot glows; click it.` (inclusive) with:

```markdown
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
```

- [ ] **Step 5: First turn of a half.** Replace

```markdown
traps, flip cards and play Scout Report, Time Wasting or Substitution. The attack phase can
```

with

```markdown
traps, switch or substitute cards and play Scout Report, Time Wasting or Substitution. The attack phase can
```

- [ ] **Step 6: Card Modes and the new Stamina section.** Replace everything from the line `## Card Modes` through the line `mode for the whole match, revealed or not.` (inclusive) with:

```markdown
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
```

- [ ] **Step 7: Midfield control.** Replace

```markdown
**Metronome** in your midfielder slot you also get **+1 summon** that turn.
```

with

```markdown
**Metronome** in your midfielder slot you also get **+1 summon** that turn. Tired doesn't change
midfield power.
```

- [ ] **Step 8: Strategy Cards.** Replace

```markdown
- **Substitution** — return one of your pitch cards to your hand; your next summon into the
  freed slot is free.
```

with

```markdown
- **Substitution** — the special sub. Return one of your pitch cards to your hand, then place a
  card from your hand in that slot (through the mode picker). The placement costs **no summon**
  and **no substitution** (SUBS), and the new card **may attack this turn**: it ignores the
  wait-a-turn rule, but it can't switch position this turn. The freed slot takes exactly one
  free placement, this turn only. The AI plays it for its most tired card.
```

- [ ] **Step 9: Not Implemented Yet.** Replace

```markdown
- Substitution limits: the returned card can be summoned again the same turn, and Substitution
  cannot be played in response to an attack.
- Manager's Challenge against VAR.
- AI use of Last Defender Foul, Manager's Challenge, Scout Report, Substitution and mode flips.
```

with

```markdown
- Substitution played in response to an attack (it is a summon-phase card).
- Manager's Challenge against VAR.
- AI use of Last Defender Foul, Manager's Challenge and Scout Report.
```

- [ ] **Step 10: Check**

Run: `grep -n "Keeper substitution\|M toggles\|keeper substitution\*\*" rules.md`
Expected: no output.

Run: `grep -c "Stamina\|SUBS\|TO DEFENSE" rules.md`
Expected: a number of at least 6.

- [ ] **Step 11: Commit**

```bash
git add rules.md
git commit -m "rules.md: mode picker, switching positions, stamina, substitutions and the Substitution card" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **483**.

---

### Task 12: Acceptance run (spec, Verification)

**Files:** none (verification only)

- [ ] **Step 1: Full run (9,000 games).** This takes a few minutes. Give the command a 10-minute timeout, or run it in the background and wait for it to finish.

Run: `lua tools/sim/sim.lua n=1000 seed=20260923 diff=medium`
Expected: the last six lines are

```
  PASS games = 9000 (got 9000)
  PASS every deck's win rate within 42-58% (min …, max …)
  PASS stalls = 0 (got 0)
  PASS first-seat match win rate within 45-55% (got …%)
ACCEPTANCE: PASS
ABILITY REVIEW: OK
```

`ABILITY REVIEW: OK` means no card is outside 35–65%, which is the spec's "no card outside 35–65%".

- [ ] **Step 2: If any line reads `FAIL`, or `ABILITY REVIEW` is not `OK`: STOP.**
  1. Report the **full** simulator output to the user, in particular:
     - the deck win rates and the first-seat rate;
     - the stall count;
     - the `stamina & substitutions` block;
     - the `ability triggers` block;
     - every `<-- REVIEW` row.
  2. Propose tweaks for the owner **without applying any of them**. Name the constant and the value for each. Examples:
     - games run too long or too short because cards tire too fast or too slowly: step `C.STAMINA.MAX` by type ±1, or `C.STAMINA.TURN_COST`;
     - Tired is too punishing or too weak: `C.STAMINA.TIRED_ATK` / `TIRED_DEF` 300 → 200 or 400;
     - too many or too few subs: `C.MATCH.SUBS_PER_HALF`, `AI.SUB_STRIKER_AT` 1 → 0;
     - a deck swings on the Substitution card: `AI.USE_SUBSTITUTION_CARD = false` (plan decision P3);
     - a card above 65% or below 35%: its `C.ABILITY` number one notch.
  3. **Do not** change any constant, card stat, deck list or AI threshold, and do not run what-if variants from a modified tree. Tuning needs the owner's approval.
  4. A non-zero stall count points to a correctness bug (a loop), not to balance. Report it the same way and do not fix it without approval.
  5. Continue to Task 13 only after the user says how to proceed.

Nothing to commit. Cumulative tests: **483**.

---

### Task 13: Final check

**Files:** none (verification only)

- [ ] **Step 1: Unit tests**

Run: `lua tests/run.lua`
Expected: `483 passed, 0 failed`

- [ ] **Step 2: Syntax of every changed file, and no `luac.out`**

Run: `luac -p engine/*.lua engine/cards/*.lua engine/cards/definitions/*.lua store/match.lua ai/opponent.lua scenes/match.lua ui/card.lua ui/theme.lua ui/pitch.lua ui/kit/draw.lua ui/match/*.lua ui/overlay/*.lua tools/snapshot/*.lua tools/sim/sim.lua && ls luac.out`
Expected: no `luac` output, then `ls: luac.out: No such file or directory`.

- [ ] **Step 3: Every scenario runs clean**

Run: `for s in home library match cards summon juice debug pause combat trap cover trapwin scout halftime victory defeat revealed midfield keywords abilities keeperswap modes stamina subs; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback on stderr.

- [ ] **Step 4: Review the PNGs** with the Read tool:
  - **Tasks 2, 6, 7 and 8 checklists:** every `modes_*`, `stamina_*` and `subs_*`, plus `keeperswap_picker`, `keeperswap_after`, `keywords_gallery` and `summon_myturn`.
  - **Every other scenario still matches its earlier checklist, with these expected differences:**
    - no ATTACK/DEFENSE toggle, and a `SUBS n / 3` pill under SUMMONS;
    - pips on real-engine cards;
    - `TO DEFENSE ▼` on your eligible attack-mode cards during your summon phase.

- [ ] **Step 5: Simulator acceptance**

Run: `lua tools/sim/sim.lua n=1000 seed=20260923 diff=medium`
Expected: the last two lines are `ACCEPTANCE: PASS` and `ABILITY REVIEW: OK`, or the owner-approved outcome from Task 12.

Run: `git status --porcelain`
Expected: no output.

- [ ] **Step 6: Only the expected areas changed**

Run: `git diff --name-only e17517c -- . ':(exclude)docs'`
Expected exactly:

```
ai/opponent.lua
engine/cards/definitions/strategies.lua
engine/cards/resolver.lua
engine/combat.lua
engine/constants.lua
engine/phases.lua
engine/stamina.lua
engine/state.lua
rules.md
scenes/match.lua
store/match.lua
tests/test_ai_subs.lua
tests/test_ai_switch.lua
tests/test_match_layout.lua
tests/test_modepicker.lua
tests/test_modes_switch.lua
tests/test_revealed_ui.lua
tests/test_stamina.lua
tests/test_stamina_ui.lua
tests/test_substitution_card.lua
tests/test_substitutions.lua
tests/test_tired.lua
tools/sim/sim.lua
tools/snapshot/card_gallery.lua
tools/snapshot/scenarios.lua
ui/card.lua
ui/kit/draw.lua
ui/match/bottombar.lua
ui/match/layout.lua
ui/match/modepicker.lua
ui/match/stats.lua
ui/match/toasts.lua
ui/match/zoom.lua
ui/overlay/combat.lua
ui/overlay/combatfx.lua
ui/pitch.lua
ui/theme.lua
```

Run: `git diff --stat e17517c -- . ':(exclude)docs' | tail -1`
Expected: `37 files changed, …`

- [ ] **Step 7: Report to the user.**
  - **What changed:** summarise per spec part:
    - A1 picker;
    - A2 switching and AI;
    - B1 stamina, Tired and UI;
    - B2 substitutions, the Substitution card and AI subs;
    - B3 interactions;
    - Verification.
  - **Simulator:** paste:
    - the deck win rates;
    - the `stamina & substitutions` block (cards tired per match, subs per match per seat, Substitution-card use);
    - the acceptance block.
  - **Screenshots:** show `modes_picker`, `modes_switched`, `stamina_board`, `stamina_tags`, `subs_sub` and `subs_attacker`.
  - **Plan clarifications:** restate P1–P12, especially:
    - P3 (the AI plays the Substitution card; switch: `AI.USE_SUBSTITUTION_CARD`);
    - P4 (Offside-cancelled attacks are free);
    - P5 (Tired doesn't change midfield power or the keeper line bonus);
    - P9 (the engine now enforces the Substitution card's freed slot).
  - **Fixed along the way:** the AI's keeper-swap check used to read `matchState.activePlayer`, which is the wrong seat on the simulator's mirrored view. It now reads its own seat through `Phases.canSubstitute(match, "opponent", …)`.
  - **Found, not fixed:** the human can still play a keeper face-up. The spec lets keepers choose, and the picker warns that the choice is permanent.

  Tell the user an **interactive play-test is required**, because the harness can't do it. They should play at least one full match with each deck and check:
  - **Picker:**
    - every field card and keeper placement opens it on the slot;
    - `A` / `D` / `Esc` work;
    - a click outside cancels and the card stays selected;
    - traps go straight in;
    - `M` does nothing.
  - **Switching:**
    - `TO DEFENSE ▼` appears only on your eligible attack-mode cards in your summon phase;
    - a switched card is face-up with DEF, costs no LP when destroyed, and can flip back next turn;
    - a refusal is flashed.
  - **Stamina:**
    - pips drop at your turn end and after attacks and covers;
    - a card at 0 shows TIRED, red numbers and `TIRED -300` in combat;
    - the AI's face-down cards show no pips;
    - half-time refills everything.
  - **Subs:**
    - occupied slots glow for a selected card;
    - a sub uses a summon and a SUB; after 3, subs are refused with the reason;
    - keeper swaps count;
    - SUBS resets at half-time and in Extra Time.
  - **Substitution card:** the placement is free, SUBS doesn't move, and the new card can attack at once.
  - **AI:**
    - it subs out tired cards;
    - it sometimes pulls a card back to defense;
    - it never stalls.

---

## Self-review

### Spec coverage: every bullet

| Spec bullet | Implemented (task: code) | Tests / snapshots |
|---|---|---|
| A1 Remove the bottom-bar toggle and the `M` key | 2: `Layout` / `BottomBar` / scene | 2: layout test (`bottom.toggle == nil`), grep; `modes_picker` |
| A1 Select a hand card → click a slot → picker with ATTACK (face-up) and DEFEND (face-down); keys A / D / Esc (card stays selected) | 2: `ModePicker`, `Match.placeCard` / `confirmPlace`, key and click handling | 2: `test_modepicker` (5); `modes_picker`, `modes_cancel` |
| A1 Traps skip the picker; keepers choose and the picker says the choice is permanent | 2: `needsPicker`, `note` | 2: tests 1–2; `modes_keeper`, `keeperswap_picker` |
| A1 Substitutions use the same picker | 2 + 7: an occupied glowing slot opens the picker | `subs_picker` |
| A1 The freed bottom-bar space holds the SUBS counter | 7: `Layout.bottom.subs`, `drawSubs`, `Stats.subs` | 7: test 9; `keeperswap_*`, `subs_sub` |
| A2 Switch once per turn per card in your summon phase: defense → attack | 1: `canSwitch` / `changeMode` | 1: tests 1, 6 |
| A2 Attack → defense makes a face-up defense card (revealed, keeps defense bonuses, no LP loss, can't attack or cover) | 1: `changeMode` sets `revealed` | 1: tests 4–5 |
| A2 Not allowed: the turn it was played or substituted in, after it attacked, keepers, traps, the break, the opponent's turn | 1: `canSwitch` (plus exhausted, P1) | 1: tests 2, 3, 7; 7: test 2; 8: test 2 |
| A2 UI: `TO DEFENSE ▼` (drawn arrow); FLIP UP / TO ATTACK kept; one pure `canSwitch` for engine and UI | 1: `Card.switchLabel` → `Phases.canSwitch`, `drawToDefense`, `Draw.arrowDown` | 1: test 8 and the `revealed UI` rewrite; `keywords_gallery`, `modes_placed` |
| A2 AI pulls a weak or tired exposed card back to defense (deterministic, tested); flips as today | 3: `_planSwitches` / `_threatAgainst` / `_weak` / `_soleCoverer`; 5: tired counts as weak | 3: `test_ai_switch` (5); 5: test 8; the older `AI flip` tests still pass |
| B1 Full stamina: strikers 4, midfielders 5, defenders 6; keepers never tire; Engine +2 | 4: `C.STAMINA`, `Stamina.max`, `newPitchedCard` | 4: test 1 |
| B1 Drain 1 at the end of the owner's turn | 4: `endTurn` | 4: tests 2–3 |
| B1 Attacking or covering costs 1 extra when the action resolves | 4: `_doCombat`, `_goalAttempt`, wasted paths, `resolveCover` | 4: tests 4, 5, 8 |
| B1 Press and Counter-press cost 1 extra when they trigger | 4: `_afterSummon` + `R.onSummon` returns true; `R.firedIn` in `_doCombat` | 4: tests 6–7 |
| B1 Tired at 0: −300 ATK and −300 DEF through the resolver; badges and "TIRED −300" combat tags; never below 0 | 5: `R.tiredPart` in `atkBonus` / `defBonus` / `keeperDef`, `partName`, store tags, `Fx.tagText`, badges; 4: `Stamina.spend` floor | 5: tests 1–7; 4: test 3; `stamina_tags` |
| B1 Half-time and Extra Time break: all stamina refills; later entries are full | 4: new pitch in `_resetHalf` + `newPitchedCard` | 4: test 9 |
| B1 Stamina visible for face-up cards and your own; none on the opponent's face-down cards | 4: `Stamina.visible`; 6: pitch `showStamina`, zoom; 5: `visibleOnly` hides Tired | 6: tests 3–4; 5: tests 4–5; `stamina_board` |
| B1 UI: compact pips clear of badges, name ribbon and keyword pill; sweat / TIRED marker and red numbers | 6: `L.stamina`, `L.sweat`, `drawStamina`, `drawSweat`; 5: tired badges | 6: tests 1–2; `stamina_board`, `keywords_gallery` |
| B2 Sub onto an occupied slot of the matching line (same eligibility as summoning); the outgoing card returns to hand, rested | 7: `canSubstitute`, `summon` occupied branch | 7: tests 1, 3, 7 |
| B2 Uses a summon; 3 per half, keeper swaps included; the incoming card waits a turn (Pace excepted) | 7 | 7: tests 1, 2, 4, 5 |
| B2 SUBS n / 3; resets at half-time; Extra Time gets 3 | 7: `Stats.subs`, `_resetHalf` | 7: tests 6, 9 |
| B2 Substitution card: no summon, not counted, the incoming card may act immediately; flow kept; text updated | 8: `subFreedSlot`, `actsImmediately`, `canAttackNow`, strategy text | 8: `test_substitution_card` (5); `subs_subcard`, `subs_attacker` |
| B2 AI subs tired cards (0, or 1 for strikers) with a same-line card and subs / summons left; keeper swap within the 3 | 9: `_subTargets`, `_planSummons`, `subCard`; 7: `_planKeeperSwap` via `canSubstitute` | 9: `test_ai_subs` (6) |
| B3 Keeper swap is a substitution and counts toward the 3 | 7 | 7: test 4; the `Keeper swap` tests |
| B3 Covering costs the extra point whether the cover wins or not | 4: `resolveCover` | 4: test 5 |
| B3 Hard tackle, Punch clear and cannot-act rules unchanged | not touched (`lockedNextTurn` path intact) | the older `test_abilities_rules` suite passes |
| Verification: unit tests for every rule, on the real engine | 1–9 | 61 new tests (422 → 483) |
| Verification: snapshots (picker, TO DEFENSE, tired visuals, sub with SUBS, the Substitution card's immediate attacker) | 2, 6, 8 | `modes_*`, `stamina_*`, `subs_*` |
| Verification: simulator stamina stats; acceptance kept; STOP rule on failure | 10, 12 | Task 12 |
| Verification: rules.md updated | 11 | Task 11 check |

### Placeholder scan

- Every code step has complete code, and every edit names the exact old text (or a unique anchor line) and gives the full new text.
- There is no "TBD", "similar to" or "add appropriate …".
- Functions that change in several tasks are replaced whole in the later task:
  - `Card.drawPitched` (Tasks 1, 6);
  - `Phases.summon` (Task 7);
  - `AI._planSummons` (Task 9);
  - `AI._planFlips` (Task 3).

  Small edits to them in between use anchors that exist in the earlier task's version.

### Name and signature consistency

| Name | Signature | Defined | Used |
|---|---|---|---|
| `Phases.canSwitch` | `(card, slotType, ctx)` → `"attack"`\|`"defense"` or nil, reason | 1 | `changeMode`, `Card.switchLabel`, `AI.canSwitch`, tests |
| `Phases.changeMode` | `(matchState, slotType, slotIndex)` → true or false, reason | 1 | `Store:changeMode` |
| `Card.switchLabel` | `(pitched, slotType, ctx)` → string or nil | 1 | `ui/pitch.lua` |
| `AI.canSwitch` | `(match, card, slotType)` → mode or nil | 1 | `_planFlips`, `_planSwitches` |
| `ModePicker.needsPicker` / `note` / `open` / `rects` / `actionAt` / `keyAction` / `draw` | `(cardDef)` / `(cardDef, slotType)` / `(cardDef, slot, free)` / `(p)` / `(p, x, y)` / `(key)` / `(p, mx, my)` | 2 | scene, tests |
| `Match.slotAccepts` / `placeCard` / `confirmPlace` | `(match, slot)` / `(cardDef, slot, mode, free)` / `(mode)` | 2 | scene |
| `AI._winsNow` / `_threatAgainst` / `_weak` / `_soleCoverer` / `_planSwitches` | `(match, card, slotType)` / `(match, slotType)` / `(match, card, slotType)` / `(pitch, card, slotType)` / `(match, used)` | 3 (`_weak` updated in 5) | `_planSummons` |
| `Stamina.max` / `tired` / `spend` / `visible` | `(cardDef)` / `(pitched)` / `(pitched, n)` → became Tired / `(pitched, isOwner)` | 4 | state, phases, resolver, UI, AI |
| `Phases._spend` | `(matchState, ownerId, card, n)` | 4 | `endTurn`, `_doCombat`, `_goalAttempt`, wasted paths, `resolveCover`, `_afterSummon` |
| `Phases._afterSummon` | `(matchState, ownerId, pitched)` | 4 | `Phases.summon` |
| `R.onSummon` | `(matchState, ownerId, pitched)` → bool | 4 | `_afterSummon` |
| `R.firedIn` | `(parts, keyword)` → bool | 4 | `_doCombat` |
| `R.TIRED` / `R.PART_LABELS` / `R.partName` / `R.tiredPart` | `"TIRED"` / table / `(keyword)` / `(pitched, amount, visibleOnly)` → amount, part | 5 | resolver, combat, store, zoom |
| `Card.bonuses` | `(pitched, pitch, hideHidden)` → atkBonus, defBonus (may be negative), atkParts, defParts | 5 | pitch, zoom |
| `Draw.atkBadge` / `Draw.defBadge` | `(cx, cy, s, value, alpha, tired)` / `(cx, cy, s, value, bonus, alpha, tired)` | 5 | card, combat overlay |
| `Card.staminaView` / `Card.staminaRowWidth` | `(pitched)` → { filled, total, tired } or nil / `(L, n)` | 6 | card, tests |
| `Phases.canSubstitute` | `(matchState, playerId, cardDef, slotType, slotIndex)` → true or false, reason | 7 | `summon`, `canKeeperSwap`, scene, AI |
| `Phases.canKeeperSwap` | `(matchState, cardDef)` → bool | 7 (wrapper) | scene hint, tests |
| `Stats.subs` | `(match)` → used, max | 7 | bottom bar |
| `AI._lineValue` / `_subMode` / `_subTargets` | `(cardDef)` / `(cardDef, slotType)` / `(match)` | 9 | `_planSummons` |

- **State fields:**
  - `pitched.stamina` (4);
  - `pitched.actsImmediately` (8; cleared in `recoverPitch`);
  - `ps.subsUsed` (7);
  - `ps.subFreedSlot` (8; cleared in `endTurn` and `_resetHalf`).
- **Log events and payloads:**
  - `card_tired` { player, card, name, hidden } (4);
  - `card_played` with `action = "substitution"` { name, replaced, replacedName } or `"keeper_swap"` (7);
  - `card_played` with `action = "mode_change"` and `mode` (1).
- **AI actions:**
  - `toDefense` { slotType, slotIndex } (3);
  - `subCard` { cardId, returnSlot, inId, mode } (9).
- **Snapshot record fields:** `tired` on each side (5); `Fx.cardView(...).tired` (5).

### Critical Files for Implementation
- /Users/mac/Documents/football-tcg-lua/engine/phases.lua
- /Users/mac/Documents/football-tcg-lua/engine/cards/resolver.lua
- /Users/mac/Documents/football-tcg-lua/ai/opponent.lua
- /Users/mac/Documents/football-tcg-lua/scenes/match.lua
- /Users/mac/Documents/football-tcg-lua/ui/card.lua
