# Card Abilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every field card exactly one real ability, as the owner approved in the spec:
- **Data:** the 24 field cards get `keyword`, `keywordName` and new rules text in `abilityText`. Traps and strategies keep their `ability` field and get no keyword.
- **Engine:** `engine/cards/resolver.lua` is rewritten as the single keyword module. Combat, shots, keeper DEF, covering, midfield control, summon, the Offside windows and attack validation call its hooks. None of them hard-code ability numbers.
- **Events:** each ability that fires logs `ability_triggered { player, card, name, keyword, hidden, … }`.
- **UI:**
  - a keyword pill on every field-card face, at every size;
  - the rules text in the zoom and info sticker;
  - toasts;
  - bonus tags and an ability line in the combat overlay.
- **AI:** it understands the abilities that change its decisions.
- **Tools and docs:**
  - the simulator reports trigger counts per keyword and each card's win rate when played;
  - `rules.md` gets an Abilities section.

**Architecture:**
- **`engine/cards/resolver.lua` (rewritten).** It depends only on `engine.constants` and `engine.state`. It has two kinds of hooks:
  - **Pure hooks** read pitched cards and pitches, never `matchState.activePlayer`. The AI can call them on the simulator's mirrored view. They are `R.atkBonus`, `R.defBonus`, `R.midfieldAtkBonus`, `R.midfieldDefBonus`, `R.keeperLineBonus`, `R.keeperOwnBonus`, `R.penaltyFullDef`, `R.clinical`, `R.survivesTie`, `R.canAttackWhenSummoned`, `R.throughBall`, `R.immuneToOffside`, `R.uncoverable`, `R.canCoverSlot`, `R.coverLocks`, `R.coverKeyword` and `R.pressTarget`.
  - **`on*` hooks** change the match and log through `R.trigger`. They are `R.onSummon`, `R.onShotResolved`, `R.onFightResolved`, `R.onAttackCancelled` and `R.onMidfieldControl`.
- **`engine/combat.lua`.** It works out every number through `Combat.attackStat`, `Combat.defendStat` and `Combat.keeperDef`. Each returns the total plus the keyword parts. The engine logs the parts, and the combat snapshot turns them into overlay tags. The same functions feed the pitch badges (`Card.bonuses`) and the AI's estimates, so every screen shows the number the engine uses.
- **Lock mechanism:**
  - Hard tackle and Punch clear set `pitched.lockedNextTurn` during the attacker's own turn.
  - `Phases.endTurn` then turns it into `cannotActNextTurn`. That is the same flag a cover sets, and it is cleared at the end of the owner's next turn.

**Tech Stack:**
- LÖVE 11.4 with LuaJIT / Lua 5.1 semantics for game code:
  - no `//`;
  - no `goto` in new code;
  - never assign to a `for` loop variable;
  - no identifier named `global`.
- Plain Lua 5.5 (`/opt/homebrew/bin/lua`) for `lua tests/run.lua` and `tools/sim/sim.lua`.
- `luac -p` for syntax checks of LÖVE-only files.
- `tools/snapshot/snap.sh <scenario>` for screenshots.

**Spec:** `docs/superpowers/specs/2026-09-24-card-abilities-design.md` (all sections).
**Branch:** `feat/card-abilities`, already checked out. The spec commit is `d4191e0`.

**Conventions (apply to every task):**
- **Working directory:** run every command from the repo root, `/Users/mac/Documents/football-tcg-lua`.
- **Commit messages:** use `git commit -m "<subject>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`. The commit steps below show the full command.
- **No `luac.out`:**
  - Only ever run `luac -p` (parse only).
  - Before each commit, `ls luac.out` must print `ls: luac.out: No such file or directory`.
- **Snapshots:**
  - PNGs land in `.snapshots/` (gitignored) at 2560×1600.
  - Review each listed PNG with the Read tool. If one does not match its checklist, fix it and re-run before committing.
- **Tests:**
  - Engine tests drive the real engine through `tests/helpers.lua`.
  - The count is **279** at the start and **365** at the end.
- **Smoke run:** every engine task ends with a short headless AI-vs-AI run (`lua tools/sim/sim.lua n=2 seed=1`). It keeps the game playable after each commit.
- **Balance:**
  - Never change a card stat, a deck list, a `C.ABILITY` number or an AI threshold beyond this plan.
  - If the simulator fails acceptance, or flags a card, stop and report (Task 13).

**Owner decisions this plan implements (confirm them when the plan is reviewed):**
- **D1. A card summoned this turn cannot attack until its owner's next turn.**
  - **Why:** today any card summoned in attack mode may attack at once (`Phases.validateAttack` never looks at `summonedThisTurn`, and `rules.md` allows it). Without this rule, **Pace** (a card the owner approved) would do nothing.
  - **What changes:**
    - `Phases.summon` now sets `summonedThisTurn` for every field summon, not only defense-mode ones.
    - `Phases.canAttackNow` refuses a card summoned this turn unless it has Pace.
    - The same rule applies to the Direct Free Kick / Penalty shooter (`_bestStriker`).
  - **Switch:** the rule is behind `C.MATCH.SUMMONED_CAN_ATTACK = false`. If the owner rejects D1, set it to `true`: every card may attack at once again, and Pace has no effect until the owner rewords it.
  - **Balance:** this changes how fast games play. Task 13 measures it.
- **D2. `recoverPitch` switches to numeric loops.**
  - This is the bug found in the rules-balance plan (deviation 16): a card in slot 2 behind an empty slot 1 never recovers.
  - It becomes blocking here: without the fix, a card in slot 2 would keep `summonedThisTurn` (D1) or `lockedNextTurn` forever.
- **D3. Off the line:**
  - The Sweeper Keeper covers in either mode (keepers never flip), fighting with its own DEF and no line bonuses.
  - "Once per turn" is the existing rule that a side covers at most once per turn (`coverUsed`).
  - A keeper that loses the cover fight is destroyed like any coverer. The "keeper is never destroyed" rule stays true for shots.

**Clarifications (inside the approved list; no rule changes):**
1. **Link-up and Through ball** count their source card anywhere on the owner's pitch, in either mode.
2. **Engine, Overlap and Metronome** work only from the midfielder slot. They change or ride on the midfielder-slot bonus and midfield control.
3. **Press:**
   - It targets a card in an enemy **defender slot**: the face-up (attack or revealed) one with the highest DEF, otherwise the first face-down one.
   - The target gets `exhausted = true` plus `pressed = true`. `Phases.endTurn` clears both at the end of the Press owner's turn, so the target can't cover this turn but acts normally on its own turn.
4. **Instinct and Opportunist** apply to every shot by that card: any slot, Direct Free Kick and Penalty included, and open goals for Opportunist.
5. **Clinical** applies to any shot tie, including a Penalty against base DEF.
6. **Safe hands:**
   - It is the keeper's own DEF, so it also counts against a Penalty.
   - Saves are counted on the pitched keeper (`pitched.saves`, one per `save` outcome). A new half means a new pitch. A keeper taken off with Substitution and brought back starts again at 0.
7. **Hard tackle:**
   - It also fires when an Immovable attacker survives a tie against The Destroyer.
   - Offside counts when the declared target slot holds The Destroyer.
8. **Build-up** fires only when a card was actually drawn (an empty deck means no draw and no event).
9. **Metronome** fires whenever you control midfield, even with an empty deck (the extra card is skipped, the summon is not). `matchState.bonusSummons` resets every turn.
10. **Aerial** logs a trigger only when the defending side has an Offside set.
11. **Beat the man** logs a trigger only when a cover was actually possible. It is checked before the Last Defender Foul bypass, so that bypass is not used up.
12. **Toasts:**
    - The always-on stat keywords (Link-up, Engine, Overlap, Last man, Bolt, Safe hands) stay quiet in the toasts (`Toasts.QUIET`). They show as pitch badges and combat-overlay tags, and they are still logged for the simulator.
    - Toasts never name an opponent's face-down card. It shows as "a face-down card".
13. **Hidden information:**
    - Pitch badges and zoom lines leave out bonuses that come from the opponent's face-down cards (`visibleOnly`), as the midfielder DEF bonus already did.
    - Combat-overlay tags leave out tags sourced from the AI's face-down cards; the totals still include them.
    - AI fight estimates use visible bonuses only.
14. **Combat overlay:** the ATK label reads `ATK +N` (the old `MID` suffix is dropped). Ability tags sit under the cards (at most 3 per side), and rule abilities are named in a pill under the "YOU ATTACK!" banner.
15. **Card layout:** the revealed card's `TO ATTACK` ribbon moves from `0.40·h` to `0.26·h` to make room for the keyword pill. The zzz pill, the revealed DEF pill and the flip ribbon now read their positions from `Card.layout` (`L.zzz`, `L.defPill`, `L.flip`).
16. **Cover prompt note:** it now reads "A covering card can't act next turn (Sweeper and Off the line excepted)."
17. **Simulator win rate when played:** a seat "played" a card when it summoned it at least once in that match. Cards are flagged only with ≥ 200 games (`cardmin`).
18. **Found, not fixed:**
    - The human can summon a keeper in attack mode (the engine allows it, the AI never does).
    - The match log (debug panel) shows AI card ids and names.

**Hook map (where each ability plugs in):**

| Ability | Engine point | Resolver hook |
|---|---|---|
| Link-up, Instinct, Opportunist | `Combat.attackStat` ← `Combat.resolve`, `Combat.resolveShot`, `Store:_snapshotAttack`, `Card.bonuses`, AI | `R.atkBonus` |
| Engine, Overlap | `Combat.attackStat` / `defendStat`, `Combat.midfielderCardAtkBonus` / `DefBonus` | `R.midfieldAtkBonus`, `R.midfieldDefBonus` |
| Last man, Counter-press | `Combat.defendStat` ← `Combat.resolve` (`opts.covering` from `Phases.resolveCover`) | `R.defBonus` |
| Bolt, Safe hands, Fortress | `Combat.keeperDef` ← `resolveShot`, `keeperEffectiveDef`, snapshot, `Card.bonuses` | `R.keeperLineBonus`, `R.keeperOwnBonus`, `R.penaltyFullDef` |
| Clinical | `Combat.resolveShot` (tie branch) → `Phases._goalAttempt` | `R.clinical`, `R.onShotResolved` |
| Punch clear | `Phases._goalAttempt` after the outcome | `R.onShotResolved` |
| Immovable | `Phases._doCombat` tie branch | `R.survivesTie` |
| Hard tackle | `Phases._doCombat` end; `Phases.cancelAttack` ← the three Offside paths in `store/match.lua` | `R.onFightResolved`, `R.onAttackCancelled` |
| Build-up | `Phases._doCombat` end | `R.onFightResolved` |
| Pace | `Phases.summon` (flag), `Phases.canAttackNow` ← `validateAttack`, `_bestStriker`, AI, scene; trigger in `Phases.attack` | `R.canAttackWhenSummoned` |
| Through ball | `Phases.validateAttack` / `Phases.attack` (`_throughBallFor`), `endTurn` reset, scene targets, AI | `R.throughBall` |
| Aerial | `Store:declareAttack` (both Offside branches), `AI.wantsOffside` | `R.immuneToOffside` |
| Beat the man | `Phases._handleEmpty`, store snapshot target, `AI.wantsOffside`, AI targeting | `R.uncoverable` |
| Press | `Phases.summon` after placing; `Phases.endTurn` → `_clearPressed` | `R.onSummon`, `R.pressTarget` |
| Metronome | `Phases._midfieldControl`; summon limit (`matchState.bonusSummons`) | `R.onMidfieldControl` |
| Intercept, Sweeper, Off the line | `Phases._eligibleCoverers`, `Phases.resolveCover` | `R.canCoverSlot`, `R.coverLocks`, `R.coverKeyword` |

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `engine/constants.lua` | modify | `C.ABILITY` numbers; `C.MATCH.SUMMONED_CAN_ATTACK` (D1) |
| `engine/cards/definitions/strikers.lua`, `midfielders.lua`, `defenders.lua`, `keepers.lua` | rewrite | `keyword`, `keywordName`, rules text |
| `engine/cards/resolver.lua` | rewrite | The keyword module (all hooks above) |
| `engine/combat.lua` | rewrite (Task 2), modify | `attackStat`, `defendStat`, `keeperDef`, `resolve(opts)`, `resolveShot` (Clinical) |
| `engine/phases.lua` | modify | Parts logging, cover flag, tie/Immovable, fight/shot hooks, `cancelAttack`, `canAttackNow`, `_throughBallFor`, `_handleEmpty`, `_eligibleCoverers`, `resolveCover`, Press/Metronome, `recoverPitch` (D2) |
| `engine/state.lua` | modify | `bonusSummons` |
| `store/match.lua` | modify | Snapshot rewrite (tags, penalty, covering, fight), `abilities` on combat records, Aerial, Beat-the-man snap target, Offside → `Phases.cancelAttack` |
| `ai/opponent.lua` | modify | `ready` via `canAttackNow`, summon limit, Press priority, resolver-based fights/shots, Beat the man, Through ball, cover choice, Aerial Offside policy |
| `scenes/match.lua` | modify | Attacker selection (D1 / Pace), Through-ball keeper target |
| `ui/card.lua` | modify | `Card.bonuses` via Combat (+parts), `Card.keywordLabel`, keyword pill, `L.kw` / `L.zzz` / `L.defPill` / `L.flip`, info heading |
| `ui/theme.lua` | modify | `Theme.grad.keyword` |
| `ui/match/zoom.lua` | modify | `Zoom.partsText`, ability parts on stat lines, lock / just-summoned lines |
| `ui/match/toasts.lua` | modify | `ability_triggered` toasts, `Toasts.QUIET` |
| `ui/match/stats.lua` | modify | SUMMONS max includes Metronome |
| `ui/overlay/combatfx.lua` | modify | `Fx.tagText`, `Fx.bonusTags`, `Fx.abilityLine`, tags in `cardView` |
| `ui/overlay/combat.lua` | modify | Tag row, `ATK +N` label, ability pill |
| `ui/overlay/prompts.lua` | modify | Cover note |
| `tools/snapshot/card_gallery.lua`, `tools/snapshot/scenarios.lua` | modify | `keywords` gallery, `abilities` scenario |
| `tools/sim/sim.lua` | modify | Keyword trigger counts, per-card win rate when played, ABILITY REVIEW line |
| `rules.md` | modify | Abilities section and cross-references |
| `tests/helpers.lua` | modify | `H.kw`, `H.triggers` |
| `tests/test_abilities_data.lua`, `test_resolver.lua`, `test_abilities_fight.lua`, `test_abilities_shots.lua`, `test_abilities_rules.lua`, `test_abilities_attack.lua`, `test_abilities_turn.lua`, `test_abilities_cover.lua`, `test_ability_toasts.lua`, `test_abilities_ui.lua`, `test_ai_abilities.lua` | create | One file per task |

---

### Task 1: Keyword data and the resolver skeleton (spec §1, §2)

**Files:**
- Modify: `engine/constants.lua`, `tests/helpers.lua`
- Rewrite: `engine/cards/definitions/strikers.lua`, `midfielders.lua`, `defenders.lua`, `keepers.lua`, `engine/cards/resolver.lua`
- Test: `tests/test_abilities_data.lua`, `tests/test_resolver.lua`

- [ ] **Step 1: Write `tests/test_abilities_data.lua`.**

```lua
local T        = require("tests.t")
local Resolver = require("engine.cards.resolver")

local FIELD = { "strikers", "midfielders", "defenders", "keepers" }
local function all()
    local out = {}
    for _, f in ipairs(FIELD) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do out[#out + 1] = d end
    end
    return out
end

-- Spec §1 (owner-approved): card id → keyword.
local WANT = {
    ["str-clinical-finisher"] = "CLINICAL", ["str-target-man"] = "AERIAL",
    ["str-speed-demon"] = "PACE", ["str-complete-forward"] = "LINK_UP",
    ["str-fox-in-the-box"] = "INSTINCT", ["str-poacher"] = "OPPORTUNIST",
    ["str-pressing-forward"] = "PRESS", ["str-pacy-winger"] = "BEAT_THE_MAN",
    ["mid-box-to-box"] = "ENGINE", ["mid-deep-lying-playmaker"] = "METRONOME",
    ["mid-pressing-monster"] = "COUNTER_PRESS", ["mid-creative-playmaker"] = "THROUGH_BALL",
    ["mid-direct-support"] = "OVERLAP",
    ["def-the-rock"] = "IMMOVABLE", ["def-stopper"] = "LAST_MAN",
    ["def-catenaccio-anchor"] = "BOLT", ["def-destroyer"] = "HARD_TACKLE",
    ["def-pressing-back"] = "INTERCEPT", ["def-ball-playing"] = "BUILD_UP",
    ["def-libero"] = "SWEEPER",
    ["keeper-the-wall"] = "FORTRESS", ["keeper-iron-fists"] = "PUNCH_CLEAR",
    ["keeper-sweeper-keeper"] = "OFF_THE_LINE", ["keeper-reliable-hands"] = "SAFE_HANDS",
}

T.test("abilities data: every field card has its owner-approved keyword", function()
    local n = 0
    for _, d in ipairs(all()) do
        n = n + 1
        T.eq(d.keyword, WANT[d.id], d.id)
    end
    T.eq(n, 24)
end)

T.test("abilities data: display names and rules text", function()
    for _, d in ipairs(all()) do
        T.eq(d.keywordName, Resolver.NAMES[d.keyword], d.id .. " keywordName")
        T.ok(type(d.abilityText) == "string" and #d.abilityText >= 30, d.id .. " rules text")
    end
end)

T.test("abilities data: 24 distinct keywords, all in Resolver.ORDER", function()
    local seen = {}
    for _, d in ipairs(all()) do
        T.ok(not seen[d.keyword], "duplicate " .. tostring(d.keyword))
        seen[d.keyword] = true
    end
    local n = 0
    for _, kw in ipairs(Resolver.ORDER) do
        n = n + 1
        T.ok(seen[kw], "unused " .. kw)
    end
    T.eq(n, 24)
end)

T.test("abilities data: traps and strategies keep `ability` and get no keyword", function()
    for _, f in ipairs({ "traps", "strategies" }) do
        for _, d in ipairs(require("engine.cards.definitions." .. f)) do
            T.eq(d.keyword, nil, d.id)
            T.ok(d.ability ~= nil, d.id .. " ability")
        end
    end
end)
```

- [ ] **Step 2: Write `tests/test_resolver.lua`.**

```lua
local T        = require("tests.t")
local H        = require("tests.helpers")
local Resolver = require("engine.cards.resolver")

T.test("resolver: keyword, has and hidden read pitched cards safely", function()
    local m = H.match()
    local c = H.place(m, "player", "striker", 1, H.kw("PACE", "striker", 2000, 500))
    T.eq(Resolver.keyword(c), "PACE")
    T.ok(Resolver.has(c, "PACE")); T.ok(not Resolver.has(c, "AERIAL"))
    T.eq(Resolver.keyword(nil), nil); T.ok(not Resolver.has(nil, "PACE"))
    local plain = H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    T.eq(Resolver.keyword(plain), nil)
    local fd = H.place(m, "player", "defender", 1, H.card("defender", 900, 1900), "defense")
    T.ok(Resolver.hidden(fd)); T.ok(not Resolver.hidden(c)); T.ok(not Resolver.hidden(nil))
    fd.revealed = true
    T.ok(not Resolver.hidden(fd))
end)

T.test("resolver: fieldCards walks every slot, holes included", function()
    local m = H.match()
    H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 1900))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1800))
    local list = Resolver.fieldCards(m.players.player.pitch)
    T.eq(#list, 3)
    T.eq(list[1].slotType, "keeper")
    T.eq(list[2].slotType, "defender"); T.eq(list[2].index, 2)
    T.eq(list[3].slotType, "striker");  T.eq(list[3].index, 2)
    T.eq(#Resolver.fieldCards(nil), 0)
end)

T.test("resolver: trigger logs ability_triggered and collects the keyword on the result", function()
    local m = H.match()
    local c = H.place(m, "opponent", "defender", 1, H.kw("BOLT", "defender", 750, 1950), "defense")
    local result = {}
    Resolver.trigger(m, "opponent", c, "BOLT", { amount = 500 }, result)
    local t = H.triggers(m)
    T.eq(#t, 1)
    T.eq(t[1].player, "opponent"); T.eq(t[1].card, c.definition.id); T.eq(t[1].name, c.definition.name)
    T.eq(t[1].keyword, "BOLT"); T.eq(t[1].amount, 500); T.eq(t[1].hidden, true)
    T.eq(result.abilities[1], "BOLT")
end)
```

- [ ] **Step 3: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 6 `FAIL` lines:
  - `abilities data`: the first three tests;
  - `resolver`: all three (`H.kw`, `Resolver.fieldCards` and `H.triggers` don't exist yet).
- `abilities data: traps and strategies …` already passes.
- The run ends with `280 passed, 6 failed`.

- [ ] **Step 4: `engine/constants.lua` — ability numbers.** Directly **above** the line `-- Keeper effective DEF = base DEF + (active defenders × 300) + (active midfielder × 150)`, insert:

```lua
-- Card abilities (engine/cards/resolver.lua). One number per ability rule.
C.ABILITY = {
    LINK_UP_ATK         = 150,  -- Link-up: to each other striker-slot card
    INSTINCT_ATK        = 300,  -- Instinct: shots at an exhausted keeper
    OPPORTUNIST_ATK     = 400,  -- Opportunist: shots while an enemy defender slot is empty
    LAST_MAN_DEF        = 300,  -- Last man: the only card in its owner's defender slots
    COUNTER_PRESS_DEF   = 300,  -- Counter-press: when it covers
    SAFE_HANDS_PER_SAVE = 100,  -- Safe hands: per save this half
    SAFE_HANDS_MAX      = 300,
    ENGINE_ATK          = 100,  -- Engine: striker-slot ATK, either mode (instead of +200)
    ENGINE_DEF          = 100,  -- Engine: defender-slot DEF, either mode (instead of +200)
    OVERLAP_ATK         = 300,  -- Overlap: striker-slot ATK in attack mode (instead of +200)
    BOLT_LINE           = 500,  -- Bolt: toward its keeper's effective DEF (instead of +300)
    CLINICAL_DAMAGE     = 300,  -- Clinical: LP dealt by a shot that ties the keeper's DEF
    METRONOME_SUMMONS   = 1,    -- Metronome: extra summons when controlling midfield
}

```

- [ ] **Step 5: Replace `engine/cards/definitions/strikers.lua` entirely with:**

```lua
return {
    { id="str-target-man",       name="The Target Man",      type="striker",    rarity="common",   stats={ atk=2200, def=600  },
      keyword="AERIAL",       keywordName="Aerial",
      abilityText="Offside can't be activated against this card's attacks." },
    { id="str-poacher",          name="The Poacher",         type="striker",    rarity="common",   stats={ atk=2100, def=500  },
      keyword="OPPORTUNIST",  keywordName="Opportunist",
      abilityText="+400 ATK on shots while at least one enemy defender slot is empty." },
    { id="str-speed-demon",      name="Speed Demon",         type="striker",    rarity="common",   stats={ atk=2150, def=550  },
      keyword="PACE",         keywordName="Pace",
      abilityText="Can attack on the turn it is summoned (attack mode only)." },
    { id="str-clinical-finisher",name="Clinical Finisher",   type="striker",    rarity="rare",     stats={ atk=2300, def=600  },
      keyword="CLINICAL",     keywordName="Clinical",
      abilityText="A shot that exactly ties the keeper's DEF is a goal for 300 LP instead of a tie." },
    { id="str-pacy-winger",      name="Pacy Winger",         type="striker",    rarity="common",   stats={ atk=2050, def=500  },
      keyword="BEAT_THE_MAN", keywordName="Beat the man",
      abilityText="Its attacks into empty slots can't be covered." },
    { id="str-fox-in-the-box",   name="Fox in the Box",      type="striker",    rarity="uncommon", stats={ atk=2150, def=650  },
      keyword="INSTINCT",     keywordName="Instinct",
      abilityText="+300 ATK on shots while the defending keeper is exhausted." },
    { id="str-complete-forward", name="Complete Forward",    type="striker",    rarity="uncommon", stats={ atk=2150, def=900  },
      keyword="LINK_UP",      keywordName="Link-up",
      abilityText="While it is on your pitch, your other striker-slot cards get +150 ATK." },
    { id="str-pressing-forward", name="Pressing Forward",    type="striker",    rarity="common",   stats={ atk=2100, def=700  },
      keyword="PRESS",        keywordName="Press",
      abilityText="When summoned (either mode): exhaust one enemy defender-slot card, the face-up one with the highest DEF if any. It can't cover this turn." },
}
```

- [ ] **Step 6: Replace `engine/cards/definitions/midfielders.lua` entirely with:**

```lua
return {
    { id="mid-box-to-box",          name="Box-to-Box",           type="midfielder", rarity="common",   stats={ atk=1800, def=1500 },
      keyword="ENGINE",        keywordName="Engine",
      abilityText="In your midfielder slot, in either mode: +100 ATK to your striker-slot cards and +100 DEF to your defender-slot cards (instead of the normal +200)." },
    { id="mid-deep-lying-playmaker",name="Deep-Lying Playmaker",  type="midfielder", rarity="common",   stats={ atk=1500, def=1700 },
      keyword="METRONOME",     keywordName="Metronome",
      abilityText="When it gives you midfield control at the start of your turn, you also get +1 summon that turn." },
    { id="mid-pressing-monster",    name="Pressing Monster",      type="midfielder", rarity="common",   stats={ atk=1700, def=1400 },
      keyword="COUNTER_PRESS", keywordName="Counter-press",
      abilityText="+300 DEF when it covers an empty slot." },
    { id="mid-creative-playmaker",  name="Creative Playmaker",    type="midfielder", rarity="rare",     stats={ atk=1600, def=1550 },
      keyword="THROUGH_BALL",  keywordName="Through ball",
      abilityText="Once per turn, one of your striker-slot cards may shoot at the enemy keeper even when both enemy defender slots are filled." },
    { id="mid-direct-support",      name="Direct Support",        type="midfielder", rarity="common",   stats={ atk=1650, def=1450 },
      keyword="OVERLAP",       keywordName="Overlap",
      abilityText="In your midfielder slot in attack mode, your striker-slot cards get +300 ATK instead of +200." },
}
```

- [ ] **Step 7: Replace `engine/cards/definitions/defenders.lua` entirely with:**

```lua
return {
    { id="def-the-rock",           name="The Rock",             type="defender",   rarity="uncommon", stats={ atk=800,  def=2100 },
      keyword="IMMOVABLE",   keywordName="Immovable",
      abilityText="On a tie, attacking or defending, The Rock survives; only the other card is destroyed." },
    { id="def-destroyer",          name="The Destroyer",        type="defender",   rarity="common",   stats={ atk=900,  def=1900 },
      keyword="HARD_TACKLE", keywordName="Hard tackle",
      abilityText="A card that attacks The Destroyer and is not destroyed (it won, or Offside cancelled the attack) can't act on its owner's next turn." },
    { id="def-ball-playing",       name="Ball-Playing Defender",type="defender",   rarity="common",   stats={ atk=1400, def=1700 },
      keyword="BUILD_UP",    keywordName="Build-up",
      abilityText="When it wins a fight (destroys the other card and survives), you draw 1 card." },
    { id="def-stopper",            name="The Stopper",          type="defender",   rarity="uncommon", stats={ atk=850,  def=2000 },
      keyword="LAST_MAN",    keywordName="Last man",
      abilityText="+300 DEF while it is your only card in the defender slots." },
    { id="def-libero",             name="Libero",               type="defender",   rarity="rare",     stats={ atk=1600, def=1500 },
      keyword="SWEEPER",     keywordName="Sweeper",
      abilityText="May cover an empty defender or midfielder slot. Covering doesn't stop it acting on your next turn." },
    { id="def-pressing-back",      name="Pressing Back",        type="defender",   rarity="common",   stats={ atk=950,  def=1800 },
      keyword="INTERCEPT",   keywordName="Intercept",
      abilityText="May also cover an empty defender slot (normal cover rules)." },
    { id="def-catenaccio-anchor",  name="Catenaccio Anchor",   type="defender",   rarity="uncommon", stats={ atk=750,  def=1950 },
      keyword="BOLT",        keywordName="Bolt",
      abilityText="Counts +500 (instead of +300) toward your keeper's effective DEF." },
}
```

- [ ] **Step 8: Replace `engine/cards/definitions/keepers.lua` entirely with:**

```lua
return {
    { id="keeper-the-wall",        name="The Wall",         type="keeper", rarity="legendary", stats={ atk=300, def=2000 },
      keyword="FORTRESS",     keywordName="Fortress",
      abilityText="Penalties face its full effective DEF instead of its base DEF." },
    { id="keeper-iron-fists",      name="Iron Fists",       type="keeper", rarity="rare",      stats={ atk=300, def=1900 },
      keyword="PUNCH_CLEAR",  keywordName="Punch clear",
      abilityText="After it saves a shot, the shooter can't act on its owner's next turn." },
    { id="keeper-sweeper-keeper",  name="Sweeper Keeper",   type="keeper", rarity="uncommon",  stats={ atk=400, def=1800 },
      keyword="OFF_THE_LINE", keywordName="Off the line",
      abilityText="May cover an empty defender slot, fighting with its own DEF; it isn't locked by covering and stays in goal. If it loses, it is destroyed." },
    { id="keeper-reliable-hands",  name="Reliable Hands",   type="keeper", rarity="common",    stats={ atk=300, def=1750 },
      keyword="SAFE_HANDS",   keywordName="Safe hands",
      abilityText="+100 DEF for each save it made this half (max +300)." },
}
```

- [ ] **Step 9: Replace `engine/cards/resolver.lua` entirely with the skeleton.** The dead v2 functions (`preCombat`, `keeperSave`, `formationBonus`) are removed; nothing requires them.

```lua
-- Card abilities (docs/superpowers/specs/2026-09-24-card-abilities-design.md).
-- Every field card has exactly one keyword (definition.keyword); traps and strategies keep
-- their `ability` field and have none. Card definitions only carry data (keyword,
-- keywordName, abilityText); the rules live here and the engine calls these hooks at fixed
-- points (engine/combat.lua, engine/phases.lua, store/match.lua).
--   Pure helpers read pitched cards and pitches only, never matchState.activePlayer, so the
--   AI can call them on the simulator's mirrored view.
--   on* hooks change the match; every ability that fires is logged through R.trigger as an
--   `ability_triggered` event { player, card, name, keyword, hidden, ... }.
local C     = require("engine.constants")
local State = require("engine.state")

local A = C.ABILITY

local R = {}

-- Keyword ids in the spec's order (strikers, midfielders, defenders, keepers).
R.ORDER = {
    "CLINICAL", "AERIAL", "PACE", "LINK_UP", "INSTINCT", "OPPORTUNIST", "PRESS", "BEAT_THE_MAN",
    "ENGINE", "METRONOME", "COUNTER_PRESS", "THROUGH_BALL", "OVERLAP",
    "IMMOVABLE", "LAST_MAN", "BOLT", "HARD_TACKLE", "INTERCEPT", "BUILD_UP", "SWEEPER",
    "FORTRESS", "PUNCH_CLEAR", "OFF_THE_LINE", "SAFE_HANDS",
}

-- Display names (definition.keywordName).
R.NAMES = {
    CLINICAL = "Clinical", AERIAL = "Aerial", PACE = "Pace", LINK_UP = "Link-up",
    INSTINCT = "Instinct", OPPORTUNIST = "Opportunist", PRESS = "Press",
    BEAT_THE_MAN = "Beat the man",
    ENGINE = "Engine", METRONOME = "Metronome", COUNTER_PRESS = "Counter-press",
    THROUGH_BALL = "Through ball", OVERLAP = "Overlap",
    IMMOVABLE = "Immovable", LAST_MAN = "Last man", BOLT = "Bolt", HARD_TACKLE = "Hard tackle",
    INTERCEPT = "Intercept", BUILD_UP = "Build-up", SWEEPER = "Sweeper",
    FORTRESS = "Fortress", PUNCH_CLEAR = "Punch clear", OFF_THE_LINE = "Off the line",
    SAFE_HANDS = "Safe hands",
}

-- ── Reading cards ─────────────────────────────────────────────────────────────

-- Keyword id of a pitched card, or nil.
function R.keyword(pitched)
    return pitched and pitched.definition and pitched.definition.keyword or nil
end

-- True when the pitched card has this keyword.
function R.has(pitched, keyword)
    return pitched ~= nil and R.keyword(pitched) == keyword
end

-- True for a face-down card that has not been revealed (hidden from its opponent).
function R.hidden(pitched)
    return pitched ~= nil and pitched.mode == "defense" and not pitched.revealed
end

-- Every card on a pitch as { card, slotType, index }: keeper, defenders, midfielder,
-- strikers. Numeric loops: a slot may be empty in front of an occupied one.
function R.fieldCards(pitch)
    local out = {}
    if not pitch then return out end
    if pitch.keeper then out[#out + 1] = { card = pitch.keeper, slotType = "keeper", index = 0 } end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders and pitch.defenders[i]
        if c then out[#out + 1] = { card = c, slotType = "defender", index = i } end
    end
    if pitch.midfielder then
        out[#out + 1] = { card = pitch.midfielder, slotType = "midfielder", index = 0 }
    end
    for i = 1, C.PITCH.MAX_STRIKERS do
        local c = pitch.strikers and pitch.strikers[i]
        if c then out[#out + 1] = { card = c, slotType = "striker", index = i } end
    end
    return out
end

-- A stat part: `amount` added by `keyword` on the card `pitched` (the source of the bonus).
function R.part(amount, pitched, keyword)
    return { keyword = keyword, amount = amount, pitched = pitched,
             card = pitched and pitched.definition or nil }
end

-- ── Events ────────────────────────────────────────────────────────────────────

-- Logs one ability that fired. ownerId owns `pitched` (the card with the ability).
-- extra: more payload fields. result (optional): the attack / shot result; the keyword is
-- added to result.abilities for the combat overlay.
function R.trigger(matchState, ownerId, pitched, keyword, extra, result)
    local d = pitched and pitched.definition or {}
    local payload = { player = ownerId, card = d.id, name = d.name, keyword = keyword,
                      hidden = R.hidden(pitched) }
    for k, v in pairs(extra or {}) do payload[k] = v end
    State.log(matchState, "ability_triggered", payload)
    if result then
        result.abilities = result.abilities or {}
        result.abilities[#result.abilities + 1] = keyword
    end
end

-- Logs every keyword part of a stat (parts from R.atkBonus / R.defBonus / keeper DEF).
function R.logParts(matchState, ownerId, parts, result)
    for _, p in ipairs(parts or {}) do
        if p.keyword then
            R.trigger(matchState, ownerId, p.pitched, p.keyword, { amount = p.amount }, result)
        end
    end
end

return R
```

- [ ] **Step 10: `tests/helpers.lua` — keyword cards and triggers.**

Directly after the line `local Store = require("store.match")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

Directly above the final line `return H`, add:

```lua
-- Field-card definition with exact stats and one ability keyword (tests don't depend on
-- card data): H.kw("LINK_UP", "striker", 2150, 900).
function H.kw(keyword, ctype, atk, def)
    local c = H.card(ctype, atk, def)
    c.keyword     = keyword
    c.keywordName = Resolver.NAMES[keyword]
    return c
end

-- Payloads of the ability_triggered events, in order.
function H.triggers(m)
    local out = {}
    for _, e in ipairs(H.events(m, "ability_triggered")) do out[#out + 1] = e.payload end
    return out
end

```

- [ ] **Step 11: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/constants.lua engine/cards/resolver.lua engine/cards/definitions/*.lua tests/helpers.lua && lua tests/run.lua`
Expected: no `luac` output; `286 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0  first-seat match wins=…` with no Lua error.

- [ ] **Step 12: Commit**

```bash
ls luac.out
git add engine/constants.lua engine/cards/resolver.lua engine/cards/definitions/strikers.lua engine/cards/definitions/midfielders.lua engine/cards/definitions/defenders.lua engine/cards/definitions/keepers.lua tests/helpers.lua tests/test_abilities_data.lua tests/test_resolver.lua
git commit -m "Card abilities: keyword data on every field card and the resolver skeleton" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **286**.

---

### Task 2: Fight stat modifiers — Link-up, Last man, Counter-press, Engine, Overlap (spec §1, §2, §3 overlay numbers)

**Files:**
- Rewrite: `engine/combat.lua`
- Modify: `engine/cards/resolver.lua`, `engine/phases.lua`, `store/match.lua`, `ui/card.lua`
- Test: `tests/test_abilities_fight.lua`

- [ ] **Step 1: Write `tests/test_abilities_fight.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")
local Card   = require("ui.card")

-- ── Link-up ───────────────────────────────────────────────────────────────────

-- Player striker (ATK 2000) in slot 1, a Link-up card in slot 2; a face-up 2100-DEF defender.
local function linkUpBoard()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    local cf = H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2100))
    return m, H.store(m), cf
end

T.test("Link-up: the other striker-slot card gets +150 ATK", function()
    local m, s, cf = linkUpBoard()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2150 vs 2100
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "LINK_UP"); T.eq(t[1].card, cf.definition.id)
    T.eq(t[1].player, "player"); T.eq(t[1].amount, 150)
end)

T.test("Link-up: the Link-up card itself gets nothing", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("LINK_UP", "striker", 2100, 900))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2100))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "tie")
    T.eq(#H.triggers(m), 0)
end)

T.test("combat snapshot: the overlay record carries the modified ATK and its tags", function()
    local _, s = linkUpBoard()
    s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    local a = s.combatQueue[1].attacker
    T.eq(a.atk, 2150); T.eq(a.atkBonus, 150)
    T.eq(#a.atkTags, 1); T.eq(a.atkTags[1].keyword, "LINK_UP")
    T.eq(a.atkTags[1].name, "Link-up"); T.eq(a.atkTags[1].amount, 150)
    T.eq(s.combatQueue[1].defender.def, 2100)
end)

-- ── Last man ──────────────────────────────────────────────────────────────────

T.test("Last man: +300 DEF while it is the only card in its defender slots", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)         -- 2200 vs 2300
    T.eq(m.players.player.lp, 3900)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "LAST_MAN"); T.eq(t[1].player, "opponent")
end)

T.test("Last man: no bonus with a second card in the defender slots", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1500))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Counter-press ─────────────────────────────────────────────────────────────

T.test("Counter-press: +300 DEF when it covers", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    T.eq(s.coverWindow.attackerSnap.atk, 1600)
    r = s:resolveCover(H.slot("midfielder"))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)         -- 1600 vs 1400 + 300
    T.eq(m.players.player.pitch.strikers[1], nil)
    local d = s.combatQueue[1].defender
    T.eq(d.def, 1700); T.eq(d.defTags[1].keyword, "COUNTER_PRESS")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "COUNTER_PRESS"); T.eq(t[1].player, "opponent")
end)

T.test("Counter-press: no bonus when it is attacked directly", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("COUNTER_PRESS", "midfielder", 1700, 1400))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("midfielder"))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#H.triggers(m), 0)
end)

-- ── Engine ────────────────────────────────────────────────────────────────────

-- Player midfielder `midDef` in `mode`, a 2000-ATK striker; a face-up 2050-DEF defender.
local function midBoard(midDef, mode)
    local m = H.match()
    H.place(m, "player", "midfielder", 0, midDef, mode)
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2050))
    return m, H.store(m)
end

T.test("Engine: +100 ATK to strikers and +100 DEF to defenders, even face-down", function()
    local m, s = midBoard(H.kw("ENGINE", "midfielder", 1800, 1500), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2100 vs 2050
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 100)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "ENGINE")
end)

T.test("Engine: a plain midfielder keeps the normal mode bonus", function()
    local m, s = midBoard(H.card("midfielder", 1800, 1500), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")                              -- 2000 vs 2050
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Overlap ───────────────────────────────────────────────────────────────────

T.test("Overlap: +300 ATK instead of +200 in attack mode", function()
    local m = H.match()
    H.place(m, "player", "midfielder", 0, H.kw("OVERLAP", "midfielder", 1650, 1450))
    H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2250))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed"); T.eq(r.damage, 50)          -- 2300 vs 2250
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OVERLAP")
end)

T.test("Overlap: nothing extra in defense mode (the normal +200 DEF)", function()
    local m, s = midBoard(H.kw("OVERLAP", "midfielder", 1650, 1450), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(Combat.midfielderCardDefBonus(m.players.player.pitch), 200)
    T.eq(#H.triggers(m), 0)
end)

-- ── Pitch badges ──────────────────────────────────────────────────────────────

T.test("card bonuses: pitch badges include Link-up and Last man", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    local st = H.place(m, "player", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    local pitch = m.players.player.pitch
    T.eq((Card.bonuses(s1, pitch)), 150)
    local _, d = Card.bonuses(st, pitch)
    T.eq(d, 300)
end)

T.test("card bonuses: the opponent's hidden ability sources are not shown", function()
    local m = H.match()
    local s1 = H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "opponent", "defender", 1, H.kw("LINK_UP", "striker", 2150, 900), "defense")
    local pitch = m.players.opponent.pitch
    T.eq((Card.bonuses(s1, pitch)), 150, "its owner sees it")
    T.eq((Card.bonuses(s1, pitch, true)), 0, "hidden from the other side")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 8 `FAIL` lines: both `Link-up … +150` / snapshot tests, the `Last man: +300` test, `Counter-press: +300 DEF when it covers`, `Engine: +100 …`, `Overlap: +300 …`, and both `card bonuses` tests.
- The five "no bonus / plain / nothing extra" tests already pass.
- The run ends with `291 passed, 8 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua` — stat bonuses.** Directly **above** the final line `return R`, insert:

```lua
-- ── Stat bonuses ──────────────────────────────────────────────────────────────

-- Midfielder card bonus for striker-slot ATK (a midfielder-type card in the midfielder
-- slot): +200 in attack mode; Overlap +300 in attack mode; Engine +100 in either mode.
-- visibleOnly: a face-down, unrevealed midfielder gives nothing (its opponent's view).
-- Returns amount, part (a keyword part, or nil for the plain bonus or no bonus).
function R.midfieldAtkBonus(pitch, visibleOnly)
    local mid = pitch and pitch.midfielder
    if not mid or mid.definition.type ~= "midfielder" then return 0, nil end
    if visibleOnly and R.hidden(mid) then return 0, nil end
    local kw = R.keyword(mid)
    if kw == "ENGINE" then return A.ENGINE_ATK, R.part(A.ENGINE_ATK, mid, "ENGINE") end
    if mid.mode ~= "attack" then return 0, nil end
    if kw == "OVERLAP" then return A.OVERLAP_ATK, R.part(A.OVERLAP_ATK, mid, "OVERLAP") end
    return C.COMBAT.MIDFIELDER_CARD_ATK_BONUS, nil
end

-- Midfielder card bonus for defender-slot DEF: +200 in defense mode; Engine +100 in either
-- mode. Returns amount, part.
function R.midfieldDefBonus(pitch, visibleOnly)
    local mid = pitch and pitch.midfielder
    if not mid or mid.definition.type ~= "midfielder" then return 0, nil end
    if visibleOnly and R.hidden(mid) then return 0, nil end
    if R.has(mid, "ENGINE") then return A.ENGINE_DEF, R.part(A.ENGINE_DEF, mid, "ENGINE") end
    if mid.mode ~= "defense" then return 0, nil end
    return C.COMBAT.MIDFIELDER_CARD_DEF_BONUS, nil
end

-- ATK bonus of an attacking card.
--   ctx = { slotType, ownPitch, oppPitch, shot, keeper, visibleOnly }
--   striker slot: the midfielder card bonus (R.midfieldAtkBonus) and Link-up (+150 from
--   each other Link-up card on the attacker's pitch, any slot).
-- Returns total, parts (keyword parts only).
function R.atkBonus(pitched, ctx)
    local total, parts = 0, {}
    local function add(amount, part)
        total = total + amount
        if part then parts[#parts + 1] = part end
    end
    if ctx.slotType == "striker" then
        add(R.midfieldAtkBonus(ctx.ownPitch, ctx.visibleOnly))
        for _, e in ipairs(R.fieldCards(ctx.ownPitch)) do
            local c = e.card
            if c ~= pitched and R.has(c, "LINK_UP") and not (ctx.visibleOnly and R.hidden(c)) then
                add(A.LINK_UP_ATK, R.part(A.LINK_UP_ATK, c, "LINK_UP"))
            end
        end
    end
    return total, parts
end

-- DEF bonus of a defending card.
--   ctx = { slotType, ownPitch, covering, visibleOnly }
--   defender slot: the midfielder card bonus (R.midfieldDefBonus) and Last man (+300 while
--   it is the only card in its owner's defender slots); covering: Counter-press (+300).
-- Returns total, parts.
function R.defBonus(pitched, ctx)
    local total, parts = 0, {}
    local function add(amount, part)
        total = total + amount
        if part then parts[#parts + 1] = part end
    end
    if ctx.slotType == "defender" then
        add(R.midfieldDefBonus(ctx.ownPitch, ctx.visibleOnly))
        if R.has(pitched, "LAST_MAN") then
            local n = 0
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if ctx.ownPitch and ctx.ownPitch.defenders and ctx.ownPitch.defenders[i] then n = n + 1 end
            end
            if n == 1 then add(A.LAST_MAN_DEF, R.part(A.LAST_MAN_DEF, pitched, "LAST_MAN")) end
        end
    end
    if ctx.covering and R.has(pitched, "COUNTER_PRESS") then
        add(A.COUNTER_PRESS_DEF, R.part(A.COUNTER_PRESS_DEF, pitched, "COUNTER_PRESS"))
    end
    return total, parts
end

```

- [ ] **Step 4: Replace `engine/combat.lua` entirely with:**

```lua
local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")

local Combat = {}

-- Base stat of a card: role "attack" → ATK, "defend" → DEF (a defending card always uses
-- its DEF, whatever its mode).
function Combat.getStat(card, role)
    local stats = card.definition.stats or {}
    if role == "attack" then
        return stats.atk or 0
    else
        return stats.def or 0
    end
end

-- ATK an attacking card uses: base ATK + the midfielder card bonus (striker slot) + ability
-- bonuses (engine/cards/resolver.lua R.atkBonus).
--   ownPitch / oppPitch: the attacker's and the defending side's pitches (either may be nil).
--   shot: nil for a fight; { keeper = pitched or nil } for a shot at goal (nil = open goal).
--   visibleOnly: skip bonuses from face-down, unrevealed cards (what their opponent sees).
-- Returns total, parts (keyword parts: { keyword, amount, pitched, card }).
function Combat.attackStat(attacker, slotType, ownPitch, oppPitch, shot, visibleOnly)
    local bonus, parts = Resolver.atkBonus(attacker, {
        slotType = slotType, ownPitch = ownPitch, oppPitch = oppPitch,
        shot = shot ~= nil, keeper = shot and shot.keeper or nil, visibleOnly = visibleOnly,
    })
    return Combat.getStat(attacker, "attack") + bonus, parts
end

-- DEF a defending card uses: base DEF + the midfielder card bonus (defender slot) + ability
-- bonuses (R.defBonus). covering: the card covers an empty slot. Returns total, parts.
function Combat.defendStat(defender, slotType, ownPitch, covering, visibleOnly)
    local bonus, parts = Resolver.defBonus(defender, {
        slotType = slotType, ownPitch = ownPitch, covering = covering, visibleOnly = visibleOnly,
    })
    return Combat.getStat(defender, "defend") + bonus, parts
end

-- Keeper DEF against a shot, with its keyword parts.
--   Effective DEF = base DEF + 300 × active defender-slot cards + 150 × an active
--   midfielder-slot card (any card, either mode). penaltyMode: base DEF only.
--   Active = has not attacked since the start of its owner's latest turn.
-- Returns total, parts.
function Combat.keeperDef(keeper, pitch, penaltyMode, visibleOnly)
    local base = Combat.getStat(keeper, "defend")
    if penaltyMode then return base, {} end
    local bonus = 0
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch and pitch.defenders and pitch.defenders[i]
        if c and not c.usedAsAttacker then bonus = bonus + C.COMBAT.DEFENDER_BONUS end
    end
    local mid = pitch and pitch.midfielder
    if mid and not mid.usedAsAttacker then bonus = bonus + C.COMBAT.MIDFIELDER_BONUS end
    return base + bonus, {}
end

-- Keeper effective DEF as a number (see Combat.keeperDef).
function Combat.keeperEffectiveDef(keeper, pitch)
    return (Combat.keeperDef(keeper, pitch, false))
end

-- Midfield power for tempo control — only actual midfielder-type cards count.
-- Uses ATK if attack mode, DEF if defense mode. Non-midfielder cards in the slot return 0.
function Combat.midfielderPower(pitch)
    local mid = pitch and pitch.midfielder
    if not mid then return 0 end
    if mid.definition.type ~= "midfielder" then return 0 end
    local stats = mid.definition.stats or {}
    return mid.mode == "attack" and (stats.atk or 0) or (stats.def or 0)
end

-- Striker-slot ATK bonus from the midfielder card (+200 in attack mode; Engine, Overlap).
function Combat.midfielderCardAtkBonus(pitch)
    return (Resolver.midfieldAtkBonus(pitch))
end

-- Defender-slot DEF bonus from the midfielder card (+200 in defense mode; Engine).
function Combat.midfielderCardDefBonus(pitch)
    return (Resolver.midfieldDefBonus(pitch))
end

-- Fight: attacker ATK vs defender DEF (Combat.attackStat / defendStat with the slot types
-- and pitches). opts.covering: the defender covers an empty slot.
-- Returns { outcome, margin, defenderDestroyed, attackerDestroyed,
--           atkStat, defStat, atkParts, defParts }
function Combat.resolve(attacker, defender, attackerSlotType, defenderSlotType, atkPitch, defPitch, opts)
    opts = opts or {}
    local atkStat, atkParts = Combat.attackStat(attacker, attackerSlotType, atkPitch, defPitch)
    local defStat, defParts = Combat.defendStat(defender, defenderSlotType, defPitch, opts.covering)

    local margin  = atkStat - defStat

    local outcome
    local defDestroyed = false
    local atkDestroyed = false

    if margin > 0 then
        outcome      = "defender_destroyed"
        defDestroyed = true
    elseif margin == 0 then
        outcome      = "tie"
        defDestroyed = true
        atkDestroyed = true
    else
        outcome = "attacker_exhausted"
        if attacker.exhausted then
            atkDestroyed = true
        end
    end

    return {
        outcome           = outcome,
        margin            = margin,
        defenderDestroyed = defDestroyed,
        attackerDestroyed = atkDestroyed,
        atkStat           = atkStat,
        defStat           = defStat,
        atkParts          = atkParts,
        defParts          = defParts,
    }
end

-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.
-- penaltyMode = true → the keeper's penalty DEF (Combat.keeperDef).
-- attackerSlotType: only a striker-slot shooter gets the midfielder card ATK bonus.
-- Returns { outcome, damage, margin, openGoal, atkStat, defStat, atkParts, defParts }
-- outcome: "damage" | "tie" | "save"
function Combat.resolveShot(striker, keeper, oppPitch, strikerPitch, penaltyMode, attackerSlotType)
    local atkStat, atkParts = Combat.attackStat(striker, attackerSlotType, strikerPitch, oppPitch,
                                                { keeper = keeper })
    if not keeper then
        return { outcome = "damage", damage = atkStat, margin = atkStat, openGoal = true,
                 atkStat = atkStat, atkParts = atkParts, defParts = {} }
    end
    local defStat, defParts = Combat.keeperDef(keeper, oppPitch, penaltyMode)
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

    return { outcome = outcome, damage = damage, margin = margin,
             atkStat = atkStat, defStat = defStat, atkParts = atkParts, defParts = defParts }
end

return Combat
```

- [ ] **Step 5: `engine/phases.lua` — cover flag and parts logging.**

Directly after the line `local Combat = require("engine.combat")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

In `Phases.resolveCover`, replace

```lua
        return Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot, opponentId)
```

with

```lua
        return Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot, opponentId, true)
```

Replace

```lua
-- Full combat resolution between attacker and defender.
function Phases._doCombat(matchState, attacker, defender, attackerSlot, defenderSlot, opponentId)
    attacker.usedAsAttacker = true

    local activeId        = matchState.activePlayer
    local atkPitch        = matchState.players[activeId].pitch
    local defPitch        = matchState.players[opponentId].pitch
    local defenderFaceDown = defender.mode == "defense"

    local result = Combat.resolve(
        attacker, defender,
        attackerSlot.type, defenderSlot.type,
        atkPitch, defPitch
    )
```

with

```lua
-- Full combat resolution between attacker and defender. covering: the defender covers an
-- empty slot (Counter-press).
function Phases._doCombat(matchState, attacker, defender, attackerSlot, defenderSlot, opponentId, covering)
    attacker.usedAsAttacker = true

    local activeId        = matchState.activePlayer
    local atkPitch        = matchState.players[activeId].pitch
    local defPitch        = matchState.players[opponentId].pitch
    local defenderFaceDown = defender.mode == "defense"

    local result = Combat.resolve(
        attacker, defender,
        attackerSlot.type, defenderSlot.type,
        atkPitch, defPitch, { covering = covering }
    )
    -- Stat abilities that changed this fight (Link-up, Last man, Counter-press, Engine, Overlap)
    Resolver.logParts(matchState, activeId, result.atkParts, result)
    Resolver.logParts(matchState, opponentId, result.defParts, result)
```

In `Phases._goalAttempt`, directly after the line `    result.attackerSlot = attackerSlot`, insert:

```lua
    -- Stat abilities that changed this shot (shooter's and keeper's side)
    Resolver.logParts(matchState, activeId, result.atkParts, result)
    Resolver.logParts(matchState, opponentId, result.defParts, result)
```

In `Phases._bestStriker`, replace

```lua
            local atk = Combat.getStat(c, "attack") + Combat.midfielderCardAtkBonus(pitch)
```

with

```lua
            local atk = Combat.attackStat(c, "striker", pitch)
```

- [ ] **Step 6: `store/match.lua` — snapshot with modified stats and tags.**

Directly after the line `local Combat = require("engine.combat")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

In `Store:declareAttack`, replace

```lua
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
```

with

```lua
    -- Snapshot target: if the declared slot is empty and no cover is possible, the attacker
    -- advances to the next occupied line (or the goal), so snap that instead. While a cover
    -- is still possible, snap the attacker's fight ATK (the cover window shows it).
    local snapDefSlot, snapOpts = defenderSlot, nil
    do
        local oppPitch = match.players[opponentId].pitch
        local slotCard = Phases._getSlot(oppPitch, defenderSlot)
        if not slotCard and defenderSlot.type ~= "striker" then
            local coverUsed = match.coverUsed[opponentId]
            local coverers  = Phases._eligibleCoverers(oppPitch, defenderSlot)
            if coverUsed or #coverers == 0 then
                local nextSlot = Phases._nextOccupiedLine(oppPitch, defenderSlot)
                if nextSlot then snapDefSlot = nextSlot end
            else
                snapOpts = { fight = true }
            end
        end
    end

    local snap = self:_snapshotAttack(attackerSlot, snapDefSlot, snapOpts)
```

In `Store:playStrategy`, replace

```lua
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 })
                local keeper = match.players[State.other(activeId)].pitch.keeper
                if c.ability == "PENALTY" and keeper and shotSnap.defender then
                    shotSnap.defender.def = Combat.getStat(keeper, "defend")
                end
```

with

```lua
                shotSnap = self:_snapshotAttack(bestSlot, { type = "keeper", index = 0 },
                                                { penalty = c.ability == "PENALTY" })
```

In `Store:resolveCover`, replace

```lua
    local snap = self:_snapshotAttack(attackerSlot, defSlotForSnap)
```

with

```lua
    local snap = self:_snapshotAttack(attackerSlot, defSlotForSnap,
                                      covererSlot and { covering = true } or nil)
```

In `Store:_pushCombat`, directly after the line `            activePlayer = self.match and self.match.activePlayer or "player",`, add:

```lua
            abilities    = result.abilities or {},   -- keywords that fired (overlay)
```

Replace the whole `function Store:_snapshotAttack(attackerSlot, defenderSlot) … end` with:

```lua
-- Combat snapshot for the overlay, taken before the attack resolves, with the numbers the
-- engine will use (Combat.attackStat / defendStat / keeperDef).
--   opts.covering: the defender slot holds a card covering an empty slot (a fight, also for
--                  an Off the line keeper).
--   opts.fight:    the declared slot is empty and a cover may still happen: the attacker's
--                  fight ATK (the cover window shows it).
--   opts.penalty:  a Penalty (the keeper's penalty DEF).
-- Otherwise a keeper target, or an empty non-striker slot (open goal), is a shot.
-- Each side: { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper,
--              atkTags, defTags } — tags { keyword, name, amount } from ability parts.
function Store:_snapshotAttack(attackerSlot, defenderSlot, opts)
    opts = opts or {}
    local match      = self.match
    local activeId   = match.activePlayer
    local opponentId = State.other(activeId)
    local atkPitch   = match.players[activeId].pitch
    local defPitch   = match.players[opponentId].pitch
    local atkCard    = attackerSlot and Phases._getSlot(atkPitch, attackerSlot) or nil
    local defCard    = defenderSlot and Phases._getSlot(defPitch, defenderSlot) or nil
    local isShot     = defenderSlot ~= nil and not opts.covering and not opts.fight
                       and (defenderSlot.type == "keeper"
                            or (defCard == nil and defenderSlot.type ~= "striker"))

    -- Ability tags for the overlay. A tag whose source is one of the AI's face-down,
    -- unrevealed cards is left out (hidden information); the totals still count it.
    local function tags(parts, ownerId)
        local out = {}
        for _, p in ipairs(parts or {}) do
            if not (ownerId == "opponent" and Resolver.hidden(p.pitched)) then
                out[#out + 1] = { keyword = p.keyword,
                                  name = Resolver.NAMES[p.keyword] or p.keyword,
                                  amount = p.amount }
            end
        end
        return out
    end

    local function base(card, isKeeper)
        local d = card.definition
        return {
            name = d.name, type = d.type, mode = card.mode,
            wasHidden = (card.mode == "defense" and not card.revealed),
            atk = Combat.getStat(card, "attack"), def = Combat.getStat(card, "defend"),
            atkBonus = 0, defBonus = 0, isKeeper = isKeeper, atkTags = {}, defTags = {},
        }
    end

    local attacker
    if atkCard then
        attacker = base(atkCard, false)
        local atk, parts = Combat.attackStat(atkCard, attackerSlot.type, atkPitch, defPitch,
                                             isShot and { keeper = defPitch.keeper } or nil)
        attacker.atkBonus = atk - attacker.atk
        attacker.atk      = atk
        attacker.atkTags  = tags(parts, activeId)
    end

    local defender
    if defCard then
        local isKeeper = defenderSlot.type == "keeper" and not opts.covering
        defender = base(defCard, isKeeper)
        local def, parts
        if isKeeper then
            def, parts = Combat.keeperDef(defCard, defPitch, opts.penalty)
        else
            def, parts = Combat.defendStat(defCard, defenderSlot.type, defPitch, opts.covering)
        end
        defender.defBonus = def - defender.def
        defender.def      = def
        defender.defTags  = tags(parts, opponentId)
    end

    return { attacker = attacker, defender = defender }
end
```

- [ ] **Step 7: `ui/card.lua` — pitch badges from the same numbers.** Replace the whole block, from the comment line `-- Bonuses shown on a pitched card's badges. Pure (unit-tested).` through the end of `function Card.bonuses(pitched, pitch, hideHidden) … end`, with:

```lua
-- Bonuses shown on a pitched card's badges: its always-on bonuses. Pure (unit-tested).
--   striker  → +ATK: midfielder card bonus (Engine / Overlap) and Link-up
--   defender → +DEF: midfielder card bonus (Engine) and Last man
--   keeper   → effective DEF minus base DEF (line, Bolt, midfielder, Safe hands)
-- Situational bonuses (Instinct, Opportunist, Counter-press) are not shown here.
-- hideHidden: the card is the opponent's; bonuses from their face-down, unrevealed cards
-- (a hidden midfielder's bonus, a hidden Link-up or Bolt card) are hidden information.
-- Returns atkBonus, defBonus, atkParts, defParts.
function Card.bonuses(pitched, pitch, hideHidden)
    if not pitch then return 0, 0, {}, {} end
    local st    = pitched.slotType
    local stats = pitched.definition.stats or {}
    if st == "striker" then
        local atk, parts = Combat.attackStat(pitched, "striker", pitch, nil, nil, hideHidden)
        return atk - (stats.atk or 0), 0, parts, {}
    end
    if st == "defender" then
        local def, parts = Combat.defendStat(pitched, "defender", pitch, false, hideHidden)
        return 0, def - (stats.def or 0), {}, parts
    end
    if st == "keeper" then
        local def, parts = Combat.keeperDef(pitched, pitch, false, hideHidden)
        return 0, def - (stats.def or 0), {}, parts
    end
    return 0, 0, {}, {}
end
```

- [ ] **Step 8: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/combat.lua engine/phases.lua engine/cards/resolver.lua store/match.lua ui/card.lua && lua tests/run.lua`
Expected: no `luac` output; `299 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`, with no Lua error.

- [ ] **Step 9: Commit**

```bash
ls luac.out
git add engine/combat.lua engine/cards/resolver.lua engine/phases.lua store/match.lua ui/card.lua tests/test_abilities_fight.lua
git commit -m "Abilities: Link-up, Last man, Counter-press, Engine and Overlap through one stat path" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **299**.

---

### Task 3: Shot and keeper modifiers — Instinct, Opportunist, Safe hands, Bolt, Fortress (spec §1, §2)

**Files:**
- Modify: `engine/cards/resolver.lua`, `engine/combat.lua`, `engine/phases.lua`
- Test: `tests/test_abilities_shots.lua`

- [ ] **Step 1: Write `tests/test_abilities_shots.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Combat = require("engine.combat")

-- ── Instinct ──────────────────────────────────────────────────────────────────

local function instinctBoard(keeperExhausted)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("INSTINCT", "striker", 2150, 650))
    local k = H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 2400))
    k.exhausted = keeperExhausted
    return m, H.store(m)
end

T.test("Instinct: +300 ATK on a shot at an exhausted keeper", function()
    local m, s = instinctBoard(true)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 50)                      -- 2450 vs 2400
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "INSTINCT"); T.eq(t[1].player, "player")
end)

T.test("Instinct: no bonus while the keeper is fresh", function()
    local m, s = instinctBoard(false)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")
    T.eq(#H.triggers(m), 0)
end)

-- ── Opportunist ───────────────────────────────────────────────────────────────

T.test("Opportunist: +400 ATK on a shot while an enemy defender slot is empty", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("OPPORTUNIST", "striker", 2100, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1700))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 500)                     -- 2500 vs 1700 + 300
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OPPORTUNIST")
end)

T.test("Opportunist: no bonus when both enemy defender slots are filled (Direct Free Kick)", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("OPPORTUNIST", "striker", 2100, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local card = H.give(m, "player", H.def("strat-direct-free-kick"))
    local r = H.store(m):playStrategy(card.id)
    T.eq(r.outcome, "tie")                                             -- 2100 vs 1500 + 600
    T.eq(#H.triggers(m), 0)
end)

-- ── Safe hands ────────────────────────────────────────────────────────────────

local function safeHandsBoard(saves)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1900, 500))
    local k = H.place(m, "opponent", "keeper", 0, H.kw("SAFE_HANDS", "keeper", 300, 1750))
    k.saves = saves
    return m, H.store(m), k
end

T.test("Safe hands: +100 DEF per save this half, and a save counts", function()
    local m, s, k = safeHandsBoard(2)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")                                            -- 1900 vs 1750 + 200
    T.eq(k.saves, 3)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "SAFE_HANDS"); T.eq(t[1].amount, 200)
    T.eq(t[1].player, "opponent")
end)

T.test("Safe hands: no bonus before its first save", function()
    local m, s, k = safeHandsBoard(nil)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 150)
    T.eq(k.saves or 0, 0)
    T.eq(#H.triggers(m), 0)
end)

T.test("Safe hands: the bonus stops at +300", function()
    local m, _, k = safeHandsBoard(5)
    T.eq(Combat.keeperEffectiveDef(k, m.players.opponent.pitch), 2050)
end)

-- ── Bolt ──────────────────────────────────────────────────────────────────────

local function boltBoard()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2500, 500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1800))
    local b = H.place(m, "opponent", "defender", 1, H.kw("BOLT", "defender", 750, 1950), "defense")
    return m, H.store(m), b
end

T.test("Bolt: counts +500 toward the keeper's effective DEF", function()
    local m, s = boltBoard()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)                     -- 2500 vs 1800 + 500
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BOLT"); T.eq(t[1].player, "opponent")
end)

T.test("Bolt: a Bolt card that attacked stops counting, like any defender", function()
    local m, s, b = boltBoard()
    b.usedAsAttacker = true
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.damage, 700)
    T.eq(#H.triggers(m), 0)
end)

-- ── Fortress ──────────────────────────────────────────────────────────────────

local function penaltyBoard(keeperDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2300, 500))
    H.place(m, "opponent", "keeper", 0, keeperDef)
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))
    local s = H.store(m)
    local card = H.give(m, "player", H.def("strat-penalty"))
    return m, s, s:playStrategy(card.id)
end

T.test("Fortress: a Penalty faces the full effective DEF", function()
    local m, s, r = penaltyBoard(H.kw("FORTRESS", "keeper", 300, 2000))
    T.eq(r.outcome, "tie")                                             -- 2300 vs 2000 + 300
    T.eq(s.combatQueue[1].defender.def, 2300)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "FORTRESS")
end)

T.test("Fortress: other keepers face a Penalty with base DEF", function()
    local m, s, r = penaltyBoard(H.card("keeper", 300, 2000))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 300)
    T.eq(s.combatQueue[1].defender.def, 2000)
    T.eq(#H.triggers(m), 0)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 6 `FAIL` lines: `Instinct: +300 …`, `Opportunist: +400 …`, `Safe hands: +100 …`, `Safe hands: the bonus stops …`, `Bolt: counts +500 …`, `Fortress: a Penalty faces …`.
- The five non-trigger tests already pass.
- The run ends with `304 passed, 6 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua` — shot and keeper bonuses.**

Replace the whole `function R.atkBonus(pitched, ctx) … end`, including its comment block (from the line `-- ATK bonus of an attacking card.`), with:

```lua
-- ATK bonus of an attacking card.
--   ctx = { slotType, ownPitch, oppPitch, shot, keeper, visibleOnly }
--   striker slot: the midfielder card bonus (R.midfieldAtkBonus) and Link-up (+150 from
--   each other Link-up card on the attacker's pitch, any slot).
--   shots (any slot, strategy shots included): Instinct (+300 while the keeper is
--   exhausted) and Opportunist (+400 while an enemy defender slot is empty).
-- Returns total, parts (keyword parts only).
function R.atkBonus(pitched, ctx)
    local total, parts = 0, {}
    local function add(amount, part)
        total = total + amount
        if part then parts[#parts + 1] = part end
    end
    if ctx.slotType == "striker" then
        add(R.midfieldAtkBonus(ctx.ownPitch, ctx.visibleOnly))
        for _, e in ipairs(R.fieldCards(ctx.ownPitch)) do
            local c = e.card
            if c ~= pitched and R.has(c, "LINK_UP") and not (ctx.visibleOnly and R.hidden(c)) then
                add(A.LINK_UP_ATK, R.part(A.LINK_UP_ATK, c, "LINK_UP"))
            end
        end
    end
    if ctx.shot then
        if R.has(pitched, "INSTINCT") and ctx.keeper and ctx.keeper.exhausted then
            add(A.INSTINCT_ATK, R.part(A.INSTINCT_ATK, pitched, "INSTINCT"))
        end
        if R.has(pitched, "OPPORTUNIST") and R.hasEmptyDefenderSlot(ctx.oppPitch) then
            add(A.OPPORTUNIST_ATK, R.part(A.OPPORTUNIST_ATK, pitched, "OPPORTUNIST"))
        end
    end
    return total, parts
end
```

Directly **above** the final line `return R`, insert:

```lua
-- True when at least one defender slot of the pitch is empty.
function R.hasEmptyDefenderSlot(pitch)
    if not pitch then return false end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not (pitch.defenders and pitch.defenders[i]) then return true end
    end
    return false
end

-- Keeper line bonus of one active card in the defender slots: Bolt +500, else +300.
-- visibleOnly: a face-down, unrevealed Bolt card counts as a plain +300.
-- Returns amount, part.
function R.keeperLineBonus(pitched, visibleOnly)
    if R.has(pitched, "BOLT") and not (visibleOnly and R.hidden(pitched)) then
        return A.BOLT_LINE, R.part(A.BOLT_LINE, pitched, "BOLT")
    end
    return C.COMBAT.DEFENDER_BONUS, nil
end

-- Safe hands: +100 DEF for each save this keeper made this half (max +300). The keeper's
-- own DEF, so it also counts against a Penalty. pitched.saves counts saves
-- (engine/phases.lua _goalAttempt); a new half means a new pitch. Returns amount, part.
function R.keeperOwnBonus(keeper)
    if not R.has(keeper, "SAFE_HANDS") then return 0, nil end
    local n = math.min(A.SAFE_HANDS_MAX, A.SAFE_HANDS_PER_SAVE * (keeper.saves or 0))
    if n <= 0 then return 0, nil end
    return n, R.part(n, keeper, "SAFE_HANDS")
end

-- Fortress: penalties face this keeper's full effective DEF.
function R.penaltyFullDef(keeper)
    return R.has(keeper, "FORTRESS")
end

```

- [ ] **Step 4: `engine/combat.lua` — keeper DEF with Bolt, Safe hands and Fortress.** Replace the whole `function Combat.keeperDef(keeper, pitch, penaltyMode, visibleOnly) … end`, including its comment block (from the line `-- Keeper DEF against a shot, with its keyword parts.`), with:

```lua
-- Keeper DEF against a shot, with its keyword parts.
--   Effective DEF = base DEF + Safe hands + line bonus: each active defender-slot card
--   +300 (Bolt +500), an active midfielder-slot card +150 (any card, either mode).
--   penaltyMode: base DEF + Safe hands only, unless the keeper has Fortress (full DEF).
--   Active = has not attacked since the start of its owner's latest turn.
--   visibleOnly: a face-down, unrevealed Bolt card counts as a plain +300.
-- Returns total, parts.
function Combat.keeperDef(keeper, pitch, penaltyMode, visibleOnly)
    local parts = {}
    local own, ownPart = Resolver.keeperOwnBonus(keeper)
    if ownPart then parts[#parts + 1] = ownPart end
    local base = Combat.getStat(keeper, "defend") + own

    local line, lineParts = 0, {}
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch and pitch.defenders and pitch.defenders[i]
        if c and not c.usedAsAttacker then
            local b, p = Resolver.keeperLineBonus(c, visibleOnly)
            line = line + b
            if p then lineParts[#lineParts + 1] = p end
        end
    end
    local mid = pitch and pitch.midfielder
    if mid and not mid.usedAsAttacker then line = line + C.COMBAT.MIDFIELDER_BONUS end

    if penaltyMode then
        if not Resolver.penaltyFullDef(keeper) then return base, parts end
        parts[#parts + 1] = Resolver.part(line, keeper, "FORTRESS")
    end
    for _, p in ipairs(lineParts) do parts[#parts + 1] = p end
    return base + line, parts
end
```

- [ ] **Step 5: `engine/phases.lua` — count saves.** In `Phases._goalAttempt`, replace

```lua
    else  -- save
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end
```

with

```lua
    else  -- save
        keeper.saves = (keeper.saves or 0) + 1   -- Safe hands
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end
```

- [ ] **Step 6: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/combat.lua engine/phases.lua engine/cards/resolver.lua && lua tests/run.lua`
Expected: no `luac` output; `310 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 7: Commit**

```bash
ls luac.out
git add engine/cards/resolver.lua engine/combat.lua engine/phases.lua tests/test_abilities_shots.lua
git commit -m "Abilities: Instinct, Opportunist, Safe hands, Bolt and Fortress" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **310**.

---

### Task 4: Resolution rules — Clinical, Immovable, Hard tackle, Build-up, Punch clear (spec §1, §2; D2)

**Files:**
- Modify: `engine/cards/resolver.lua`, `engine/combat.lua`, `engine/phases.lua`, `store/match.lua`
- Test: `tests/test_abilities_rules.lua`

- [ ] **Step 1: Write `tests/test_abilities_rules.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")

-- ── Immovable ─────────────────────────────────────────────────────────────────

T.test("Immovable: on a tie The Rock survives and only the attacker is destroyed", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    local rock = H.place(m, "opponent", "defender", 1, H.kw("IMMOVABLE", "defender", 800, 2100))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "tie")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(m.players.opponent.pitch.defenders[1], rock)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "IMMOVABLE"); T.eq(t[1].player, "opponent")
end)

T.test("Immovable: The Rock also survives a tie it starts", function()
    local m = H.match()
    local rock = H.place(m, "player", "defender", 1, H.kw("IMMOVABLE", "defender", 800, 2100))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 800))
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "tie")
    T.eq(m.players.opponent.pitch.strikers[1], nil)
    T.eq(m.players.player.pitch.defenders[1], rock)
    T.eq(rock.exhausted, true)
end)

T.test("Immovable: a plain tie still destroys both cards", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 800, 2100))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(m.players.opponent.pitch.defenders[1], nil)
    T.eq(#H.triggers(m), 0)
end)

-- ── Hard tackle ───────────────────────────────────────────────────────────────

T.test("Hard tackle: an attacker that beats The Destroyer can't act on its owner's next turn", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2100, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(s1.lockedNextTurn, true)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "HARD_TACKLE"); T.eq(t[1].player, "opponent")
    s:endTurn(); s:endTurn()                 -- the opponent's turn, then the player's next turn
    m.phase = "attack"
    local r2, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r2, nil); T.eq(err, "attacker cannot act")
    s:endTurn(); s:endTurn()
    T.eq((Phases.validateAttack(m, H.slot("striker", 1), H.slot("keeper"))), true, "free again")
end)

T.test("Hard tackle: an attacker that loses is just destroyed (no trigger)", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1800, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(m.players.player.pitch.strikers[1], nil)
    T.eq(#H.triggers(m), 0)
end)

T.test("Hard tackle: an attack on The Destroyer cancelled by Offside also locks the attacker", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2300, 500))
    H.place(m, "opponent", "defender", 1, H.kw("HARD_TACKLE", "defender", 900, 1900))
    H.trap(m, "opponent", "trap-offside")
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(s1.exhausted, true); T.eq(s1.lockedNextTurn, true)
end)

-- ── Build-up ──────────────────────────────────────────────────────────────────

T.test("Build-up: winning a fight as the defender draws its owner a card", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
    H.place(m, "opponent", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(#m.players.opponent.hand, 1); T.eq(#m.players.opponent.deck, 9)
    T.eq(H.events(m, "card_drawn")[1].payload.source, "build_up")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BUILD_UP"); T.eq(t[1].player, "opponent")
end)

T.test("Build-up: winning as the attacker draws too", function()
    local m = H.match()
    H.place(m, "player", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    H.place(m, "opponent", "striker", 1, H.card("striker", 2000, 500))
    local r = H.store(m):declareAttack(H.slot("defender", 1), H.slot("striker", 1))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(#m.players.player.hand, 1)
end)

T.test("Build-up: a tie draws nothing", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1700, 500))
    H.place(m, "opponent", "defender", 1, H.kw("BUILD_UP", "defender", 1400, 1700))
    H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(#m.players.opponent.hand, 0)
    T.eq(#H.triggers(m), 0)
end)

-- ── Punch clear ───────────────────────────────────────────────────────────────

local function punchBoard(atk)
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", atk, 500))
    H.place(m, "opponent", "keeper", 0, H.kw("PUNCH_CLEAR", "keeper", 300, 1900))
    return m, H.store(m), s1
end

T.test("Punch clear: after a save the shooter can't act on its owner's next turn", function()
    local m, s, s1 = punchBoard(1800)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "save")
    T.eq(s1.lockedNextTurn, true)
    T.eq(r.abilities[1], "PUNCH_CLEAR")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PUNCH_CLEAR"); T.eq(t[1].player, "opponent")
end)

T.test("Punch clear: a goal leaves the shooter free", function()
    local m, s, s1 = punchBoard(2000)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage")
    T.eq(s1.lockedNextTurn, nil)
    T.eq(#H.triggers(m), 0)
end)

-- ── Clinical ──────────────────────────────────────────────────────────────────

local function clinicalBoard(shooterDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, shooterDef)
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 2000))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900))   -- effective DEF 2300
    return m, H.store(m)
end

T.test("Clinical: a shot that ties the keeper's DEF is a goal for 300", function()
    local m, s = clinicalBoard(H.kw("CLINICAL", "striker", 2300, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 300)
    T.eq(m.players.opponent.lp, 3700)
    T.eq(m.players.player.halfGoals, 1)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "CLINICAL")
end)

T.test("Clinical: other strikers still just tie", function()
    local m, s = clinicalBoard(H.card("striker", 2300, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "tie")
    T.eq(m.players.opponent.lp, 4000)
end)

-- ── End of turn (D2) ──────────────────────────────────────────────────────────

T.test("end of turn: a card behind an empty slot recovers too", function()
    local m = H.match()
    local s2 = H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    local d2 = H.place(m, "player", "defender", 2, H.card("defender", 900, 1500))
    s2.exhausted = true
    d2.cannotActNextTurn = true
    Phases.endTurn(m)
    T.eq(s2.exhausted, false); T.eq(d2.cannotActNextTurn, false)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 9 `FAIL` lines: both `Immovable: … survives` tests, `Hard tackle: … beats …`, `Hard tackle: … Offside …`, both `Build-up: winning …` tests, `Punch clear: after a save …`, `Clinical: a shot that ties …`, and `end of turn: …`.
- Five tests already pass: the plain tie, the Hard tackle loss, the Build-up tie, the Punch clear goal and the Clinical "other strikers" test.
- The run ends with `315 passed, 9 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua` — rule hooks.** Directly **above** the final line `return R`, insert:

```lua
-- ── Rule hooks ────────────────────────────────────────────────────────────────

-- Clinical: a shot tie becomes a goal for C.ABILITY.CLINICAL_DAMAGE (Combat.resolveShot).
function R.clinical(shooter)
    return R.has(shooter, "CLINICAL")
end

-- Immovable: this card survives a tie (engine/phases.lua _doCombat).
function R.survivesTie(pitched)
    return R.has(pitched, "IMMOVABLE")
end

-- After a shot (engine/phases.lua _goalAttempt).
--   Clinical: the tie was turned into a goal (Combat.resolveShot sets result.clinical).
--   Punch clear: after this keeper's save, the shooter can't act on its owner's next turn
--   (pitched.lockedNextTurn, turned into cannotActNextTurn at the end of this turn).
function R.onShotResolved(matchState, shooterId, shooter, keeper, result)
    if result.clinical then R.trigger(matchState, shooterId, shooter, "CLINICAL", nil, result) end
    if result.outcome == "save" and R.has(keeper, "PUNCH_CLEAR") then
        shooter.lockedNextTurn = true
        R.trigger(matchState, State.other(shooterId), keeper, "PUNCH_CLEAR", nil, result)
    end
end

-- After a fight (declared attack, advance or cover), once destroyed cards are gone.
--   f = { attackerId, defenderId, attacker, defender, result }; result.attackerDestroyed /
--   result.defenderDestroyed say who is gone.
--   Hard tackle: an attacker that fought a Hard tackle card and survived is locked for its
--   owner's next turn.
--   Build-up: a Build-up card that destroyed the other card and survived draws its owner
--   1 card (nothing when the deck is empty).
function R.onFightResolved(matchState, f)
    local r = f.result
    if R.has(f.defender, "HARD_TACKLE") and not r.attackerDestroyed then
        f.attacker.lockedNextTurn = true
        R.trigger(matchState, f.defenderId, f.defender, "HARD_TACKLE", nil, r)
    end
    local function buildUp(card, ownerId, won)
        if not (won and R.has(card, "BUILD_UP")) then return end
        local drawn = State.drawCard(matchState, ownerId)
        if not drawn then return end
        R.trigger(matchState, ownerId, card, "BUILD_UP", nil, r)
        State.log(matchState, "card_drawn", { player = ownerId, card = drawn.id, source = "build_up" })
    end
    buildUp(f.attacker, f.attackerId, r.defenderDestroyed and not r.attackerDestroyed)
    buildUp(f.defender, f.defenderId, r.attackerDestroyed and not r.defenderDestroyed)
end

-- Offside cancelled an attack (engine/phases.lua Phases.cancelAttack). Hard tackle: when the
-- declared target is a Hard tackle card, the attacker is locked for its owner's next turn.
function R.onAttackCancelled(matchState, attackerId, attacker, target)
    if not R.has(target, "HARD_TACKLE") then return end
    attacker.lockedNextTurn = true
    R.trigger(matchState, State.other(attackerId), target, "HARD_TACKLE")
end

```

- [ ] **Step 4: `engine/combat.lua` — Clinical.** Replace the whole `function Combat.resolveShot(…) … end`, including its comment block (from the line `-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.`), with:

```lua
-- Resolve a shot at the goal. keeper == nil → open goal: a goal for the full shot ATK.
-- penaltyMode = true → the keeper's penalty DEF (Combat.keeperDef).
-- attackerSlotType: only a striker-slot shooter gets the midfielder card ATK bonus.
-- Clinical: a tie is a goal for C.ABILITY.CLINICAL_DAMAGE (result.clinical = true).
-- Returns { outcome, damage, margin, openGoal, clinical, atkStat, defStat, atkParts, defParts }
-- outcome: "damage" | "tie" | "save"
function Combat.resolveShot(striker, keeper, oppPitch, strikerPitch, penaltyMode, attackerSlotType)
    local atkStat, atkParts = Combat.attackStat(striker, attackerSlotType, strikerPitch, oppPitch,
                                                { keeper = keeper })
    if not keeper then
        return { outcome = "damage", damage = atkStat, margin = atkStat, openGoal = true,
                 atkStat = atkStat, atkParts = atkParts, defParts = {} }
    end
    local defStat, defParts = Combat.keeperDef(keeper, oppPitch, penaltyMode)
    local margin  = atkStat - defStat

    local outcome, damage, clinical
    if margin > 0 then
        outcome = "damage"
        damage  = margin
    elseif margin == 0 then
        if Resolver.clinical(striker) then
            outcome, damage, clinical = "damage", C.ABILITY.CLINICAL_DAMAGE, true
        else
            outcome, damage = "tie", 0
        end
    else
        outcome = "save"
        damage  = 0
    end

    return { outcome = outcome, damage = damage, margin = margin, clinical = clinical,
             atkStat = atkStat, defStat = defStat, atkParts = atkParts, defParts = defParts }
end
```

- [ ] **Step 5: `engine/phases.lua` — ties, fight hooks, shot hooks, Offside, recovery.**

Directly **above** the line `-- ─── ATTACK ───…` (the section header after `Phases.activateTrap`), insert:

```lua
-- An attack cancelled by Offside: the attacker is exhausted but not destroyed; Hard tackle
-- may also lock it. attackerId owns the attacker; defenderSlot is the declared target.
function Phases.cancelAttack(matchState, attackerId, attackerSlot, defenderSlot)
    local attacker = Phases._getSlotForPlayer(matchState, attackerId, attackerSlot)
    if not attacker then return end
    attacker.exhausted = true
    local target = defenderSlot and Phases._getSlotForPlayer(matchState, State.other(attackerId), defenderSlot)
    Resolver.onAttackCancelled(matchState, attackerId, attacker, target)
end

```

In `Phases._doCombat`, replace

```lua
    elseif result.outcome == "tie" then
        Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        Phases._destroyCard(matchState, opponentId, defenderSlot.type, defenderSlot.index or 0)
        State.log(matchState, T.EventType.DEFENDER_DESTROY, { slot = defenderSlot })
```

with

```lua
    elseif result.outcome == "tie" then
        -- Immovable: that card survives a tie; only the other one is destroyed.
        if Resolver.survivesTie(attacker) then
            attacker.exhausted = true
            result.attackerDestroyed = false
            Resolver.trigger(matchState, activeId, attacker, "IMMOVABLE", nil, result)
        else
            Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        end
        if Resolver.survivesTie(defender) then
            result.defenderDestroyed = false
            Resolver.trigger(matchState, opponentId, defender, "IMMOVABLE", nil, result)
        else
            Phases._destroyCard(matchState, opponentId, defenderSlot.type, defenderSlot.index or 0)
            State.log(matchState, T.EventType.DEFENDER_DESTROY, { slot = defenderSlot })
        end
```

Then replace

```lua
    else  -- attacker lost: always destroyed + LP damage (face-down or face-up)
        Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        local penalty = -result.margin  -- margin is negative, so penalty > 0
        State.dealDamage(matchState, opponentId, penalty)
        result.damage = penalty
        State.log(matchState, T.EventType.LP_DAMAGE,
            { dealer = opponentId, damage = penalty,
              remainingLP = matchState.players[activeId].lp,
              source = defenderFaceDown and "facedown_penalty" or "battle_damage" })
    end

    return result
end
```

with

```lua
    else  -- attacker lost: always destroyed + LP damage (face-down or face-up)
        Phases._destroyCard(matchState, activeId, attackerSlot.type, attackerSlot.index or 0)
        result.attackerDestroyed = true
        local penalty = -result.margin  -- margin is negative, so penalty > 0
        State.dealDamage(matchState, opponentId, penalty)
        result.damage = penalty
        State.log(matchState, T.EventType.LP_DAMAGE,
            { dealer = opponentId, damage = penalty,
              remainingLP = matchState.players[activeId].lp,
              source = defenderFaceDown and "facedown_penalty" or "battle_damage" })
    end

    -- Hard tackle, Build-up
    Resolver.onFightResolved(matchState, {
        attackerId = activeId, defenderId = opponentId,
        attacker = attacker, defender = defender, result = result,
    })
    return result
end
```

In `Phases._goalAttempt`, replace

```lua
    else  -- save
        keeper.saves = (keeper.saves or 0) + 1   -- Safe hands
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end

    return result
end
```

with

```lua
    else  -- save
        keeper.saves = (keeper.saves or 0) + 1   -- Safe hands
        State.log(matchState, T.EventType.SHOT,
            { outcome = "save", margin = result.margin })
    end

    -- Clinical, Punch clear
    Resolver.onShotResolved(matchState, activeId, striker, keeper, result)
    return result
end
```

In `Phases.endTurn`, replace

```lua
    -- Only the active player's cards recover
    local function recoverPitch(pitch)
        local function recoverCard(c)
            if c then
                c.exhausted         = false
                c.cannotActNextTurn = false
                c.summonedThisTurn  = false
                c.modeChanged       = false
            end
        end
        recoverCard(pitch.keeper)
        recoverCard(pitch.midfielder)
        for _, c in ipairs(pitch.defenders) do recoverCard(c) end
        for _, c in ipairs(pitch.strikers)  do recoverCard(c) end
    end
```

with

```lua
    -- Only the active player's cards recover. A card locked this turn (Hard tackle, Punch
    -- clear: lockedNextTurn) can't act on its owner's next turn. Numeric loops: a slot may be
    -- empty in front of an occupied one.
    local function recoverPitch(pitch)
        local function recoverCard(c)
            if c then
                c.exhausted         = false
                c.cannotActNextTurn = c.lockedNextTurn == true
                c.lockedNextTurn    = nil
                c.summonedThisTurn  = false
                c.modeChanged       = false
            end
        end
        recoverCard(pitch.keeper)
        recoverCard(pitch.midfielder)
        for i = 1, C.PITCH.MAX_DEFENDERS do recoverCard(pitch.defenders[i]) end
        for i = 1, C.PITCH.MAX_STRIKERS  do recoverCard(pitch.strikers[i])  end
    end
```

- [ ] **Step 6: `store/match.lua` — Offside cancellations go through `Phases.cancelAttack`.**

In `Store:declareAttack` (auto-fire AI Offside), replace

```lua
                local attCard = Phases._getSlotForPlayer(match, "player", attackerSlot)
                if attCard then attCard.exhausted = true end
```

with

```lua
                Phases.cancelAttack(match, "player", attackerSlot, defenderSlot)
```

In `Store:resolveTrap`, `counter_offside` pass branch, replace

```lua
            local attCard = Phases._getSlotForPlayer(match, "player", tw.attackerSlot)
            if attCard then attCard.exhausted = true end
```

with

```lua
            Phases.cancelAttack(match, "player", tw.attackerSlot, tw.defenderSlot)
```

In `Store:resolveTrap`, `pre_attack` OFFSIDE branch, replace

```lua
            local attCard = Phases._getSlotForPlayer(match, opponentId, tw.attackerSlot)
            if attCard then attCard.exhausted = true end
```

with

```lua
            Phases.cancelAttack(match, opponentId, tw.attackerSlot, tw.defenderSlot)
```

- [ ] **Step 7: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/combat.lua engine/phases.lua engine/cards/resolver.lua store/match.lua && lua tests/run.lua`
Expected: no `luac` output; `324 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 8: Commit**

```bash
ls luac.out
git add engine/cards/resolver.lua engine/combat.lua engine/phases.lua store/match.lua tests/test_abilities_rules.lua
git commit -m "Abilities: Clinical, Immovable, Hard tackle, Build-up, Punch clear; recover every slot at end of turn" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **324**.

---

### Task 5: Attack rules — Pace, Through ball, Aerial, Beat the man (spec §1, §2, §4 Pace; D1)

**Files:**
- Modify: `engine/constants.lua`, `engine/cards/resolver.lua`, `engine/phases.lua`, `store/match.lua`, `ai/opponent.lua`, `scenes/match.lua`
- Test: `tests/test_abilities_attack.lua`

- [ ] **Step 1: Write `tests/test_abilities_attack.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local AI     = require("ai.opponent")

-- ── Pace (and D1: summoned cards attack from their next turn) ────────────────

local function summonTurn()
    local m = H.match({ phase = "summon" })
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    return m, H.store(m)
end

T.test("Pace: a Pace card summoned in attack mode attacks at once", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.kw("PACE", "striker", 2150, 550))
    T.eq(s:summonCard(c.id, "striker", 1, "attack"), true)
    s:startAttackPhase()
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PACE"); T.eq(t[1].player, "player")
end)

T.test("Pace: any other card summoned this turn attacks from its next turn", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.card("striker", 2150, 550))
    s:summonCard(c.id, "striker", 1, "attack")
    s:startAttackPhase()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "summoned this turn — attacks next turn")
    s:endTurn(); s:endTurn(); s:drawPhase(); s:startAttackPhase()
    r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "defender_destroyed")
end)

T.test("Pace: attack mode only — summoned face-down it can't attack", function()
    local m, s = summonTurn()
    local c = H.give(m, "player", H.kw("PACE", "striker", 2150, 550))
    s:summonCard(c.id, "striker", 1, "defense")
    s:startAttackPhase()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r, nil); T.eq(err, "card is in defense mode")
end)

T.test("AI Pace: attacks with a fresh Pace card, not with other fresh cards", function()
    local m = H.match({ active = "opponent" })
    local fresh = H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    fresh.summonedThisTurn = true
    H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    T.eq(AI._planNextAttack(m, "medium"), nil)
    local pace = H.place(m, "opponent", "striker", 2, H.kw("PACE", "striker", 2150, 550))
    pace.summonedThisTurn = true
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.attackerSlot.index, 2)
end)

-- ── Through ball ──────────────────────────────────────────────────────────────

local function fullDefence()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 2400, 500))
    H.place(m, "player", "striker", 2, H.card("striker", 2400, 500))
    H.place(m, "opponent", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "opponent", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1500))
    return m, H.store(m)
end

T.test("Through ball: a striker may shoot past a full defence (a normal shot vs effective DEF)", function()
    local m, s = fullDefence()
    local cp = H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 300)                     -- 2400 vs 1500 + 600
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "THROUGH_BALL"); T.eq(t[1].card, cp.definition.id)
end)

T.test("Through ball: once per turn", function()
    local m, s = fullDefence()
    H.place(m, "player", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("keeper")).outcome, "damage")
    local r, err = s:declareAttack(H.slot("striker", 2), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
    Phases.endTurn(m)
    T.eq(m.players.player.pitch.throughBallUsed, nil)
end)

T.test("Through ball: without it a full defence protects the keeper", function()
    local _, s = fullDefence()
    local r, err = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r, nil); T.eq(err, "keeper protected — clear a defender first")
end)

-- ── Aerial ────────────────────────────────────────────────────────────────────

local function offsideBoard(attackerDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, attackerDef)
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "opponent", "trap-offside")
    return m, H.store(m)
end

T.test("Aerial: the AI's Offside can't be used against it", function()
    local m, s = offsideBoard(H.kw("AERIAL", "striker", 2200, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 600)
    T.eq(#m.players.opponent.pitch.traps, 1)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "AERIAL")
end)

T.test("Aerial: a normal striker is still caught offside", function()
    local m, s = offsideBoard(H.card("striker", 2200, 600))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "offside_cancelled")
    T.eq(#m.players.opponent.pitch.traps, 0)
end)

T.test("Aerial: no Offside window opens for the human against the AI's Aerial striker", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.kw("AERIAL", "striker", 2200, 600))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    H.trap(m, "player", "trap-offside")
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("keeper"))
    T.eq(r.outcome, "damage")
    T.eq(s.trapWindow, nil)
end)

-- ── Beat the man ──────────────────────────────────────────────────────────────

local function emptySlotBoard(attackerDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, attackerDef)
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1700, 1400))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1700))
    return m, H.store(m)
end

T.test("Beat the man: its attack into an empty slot can't be covered", function()
    local m, s = emptySlotBoard(H.kw("BEAT_THE_MAN", "striker", 2050, 500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "damage"); T.eq(r.damage, 200)                     -- 2050 vs 1700 + 150
    T.eq(s.coverWindow, nil)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "BEAT_THE_MAN")
end)

T.test("Beat the man: other attacks into an empty slot can be covered", function()
    local _, s = emptySlotBoard(H.card("striker", 2050, 500))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 8 `FAIL` lines: `Pace: a Pace card …`, `Pace: any other card …`, `AI Pace …`, `Through ball: a striker may …`, `Through ball: once per turn`, `Aerial: the AI's Offside …`, `Aerial: no Offside window …`, `Beat the man: its attack …`.
- Four tests already pass.
- The run ends with `328 passed, 8 failed`.

- [ ] **Step 3: `engine/constants.lua` — D1 switch.** Directly after the line `    MULLIGAN_MAX              = 3,    -- cards a player may send back at a half-time break`, add:

```lua
    SUMMONED_CAN_ATTACK       = false, -- false: a field card summoned this turn attacks from its owner's next turn (Pace excepted)
```

- [ ] **Step 4: `engine/cards/resolver.lua` — attack hooks.** Directly **above** the final line `return R`, insert:

```lua
-- ── Attack hooks ──────────────────────────────────────────────────────────────

-- Pace: may attack on the turn it is summoned (attack mode only).
function R.canAttackWhenSummoned(pitched)
    return R.has(pitched, "PACE") and pitched.mode == "attack"
end

-- Through ball: the Through ball card on this pitch (any slot, any mode) while it is unused
-- this turn (pitch.throughBallUsed, cleared by Phases.endTurn), else nil.
function R.throughBall(pitch)
    if not pitch or pitch.throughBallUsed then return nil end
    for _, e in ipairs(R.fieldCards(pitch)) do
        if R.has(e.card, "THROUGH_BALL") then return e.card end
    end
    return nil
end

-- Aerial: Offside can't be activated against this card's attacks.
function R.immuneToOffside(attacker)
    return R.has(attacker, "AERIAL")
end

-- Beat the man: this card's attacks into empty slots can't be covered.
function R.uncoverable(attacker)
    return R.has(attacker, "BEAT_THE_MAN")
end

```

- [ ] **Step 5: `engine/phases.lua` — summoned flag, `canAttackNow`, Through ball, Pace trigger, Beat the man.**

In `Phases.summon`, replace

```lua
    if mode == "defense" then pitched.summonedThisTurn = true end
```

with

```lua
    pitched.summonedThisTurn = true   -- can't flip this turn; attacks next turn unless Pace (D1)
```

Replace the whole `function Phases.validateAttack(…) … end`, including its comment line `-- Checks an attack before any trap or cover window opens. Returns true, or false + reason.`, with:

```lua
-- True when a card can declare an attack right now: attack mode, not exhausted, not locked,
-- and not summoned this turn — unless it has Pace, or C.MATCH.SUMMONED_CAN_ATTACK is on.
-- Pure (engine, AI, scene).
function Phases.canAttackNow(card)
    if not card or card.exhausted or card.cannotActNextTurn or card.mode ~= "attack" then
        return false
    end
    if card.summonedThisTurn and not C.MATCH.SUMMONED_CAN_ATTACK
       and not Resolver.canAttackWhenSummoned(card) then
        return false
    end
    return true
end

-- Through ball: a striker-slot attack on the keeper slot while both enemy defender slots
-- are filled. Returns the Through ball card on the active player's pitch, or nil.
function Phases._throughBallFor(matchState, attackerSlot, defenderSlot)
    if defenderSlot.type ~= "keeper" or attackerSlot.type ~= "striker" then return nil end
    local oppPitch = matchState.players[State.other(matchState.activePlayer)].pitch
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not oppPitch.defenders[i] then return nil end   -- a gap: a normal shot
    end
    return Resolver.throughBall(matchState.players[matchState.activePlayer].pitch)
end

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
    if not Phases.canAttackNow(attacker) then return false, "summoned this turn — attacks next turn" end
    if defenderSlot.type == "keeper" then
        -- Direct shots need a gap in the defender line (occupied or empty keeper slot),
        -- unless a Through ball is on.
        local oppPitch = matchState.players[State.other(matchState.activePlayer)].pitch
        local hasGap = false
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not oppPitch.defenders[i] then hasGap = true; break end
        end
        if not hasGap and not Phases._throughBallFor(matchState, attackerSlot, defenderSlot) then
            return false, "keeper protected — clear a defender first"
        end
    end
    return true
end
```

In `Phases.attack`, replace

```lua
    -- The keeper slot (occupied or empty) is always a shot, never card-vs-card combat.
    if defenderSlot.type == "keeper" then
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    end
```

with

```lua
    -- Pace: a card summoned this turn only gets this far with Pace.
    if attacker.summonedThisTurn and not C.MATCH.SUMMONED_CAN_ATTACK then
        Resolver.trigger(matchState, matchState.activePlayer, attacker, "PACE")
    end

    -- The keeper slot (occupied or empty) is always a shot, never card-vs-card combat.
    if defenderSlot.type == "keeper" then
        -- Through ball: shooting past a full defender line uses it up for this turn.
        local playmaker = Phases._throughBallFor(matchState, attackerSlot, defenderSlot)
        if playmaker then
            matchState.players[matchState.activePlayer].pitch.throughBallUsed = true
            Resolver.trigger(matchState, matchState.activePlayer, playmaker, "THROUGH_BALL")
        end
        return Phases._shootAtGoal(matchState, attacker, attackerSlot, opponentId)
    end
```

In `Phases._handleEmpty`, replace

```lua
    -- LAST_DEFENDER_FOUL bypass: skip cover window for this striker advance
    if matchState.bypassCoverNextStrikerAttack and attackerSlot.type == "striker" then
        matchState.bypassCoverNextStrikerAttack = nil
        return Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
    end

    local oppPitch  = matchState.players[opponentId].pitch
    local coverUsed = matchState.coverUsed[opponentId]
    local coverers  = Phases._eligibleCoverers(oppPitch, emptySlot)

    if not coverUsed and #coverers > 0 then
```

with

```lua
    local oppPitch  = matchState.players[opponentId].pitch
    local coverUsed = matchState.coverUsed[opponentId]
    local coverers  = Phases._eligibleCoverers(oppPitch, emptySlot)
    local canCover  = not coverUsed and #coverers > 0

    -- Beat the man: its attacks into empty slots can't be covered. Checked before the Last
    -- Defender Foul bypass so that bypass is not used up.
    if Resolver.uncoverable(attacker) then
        local r = Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
        if canCover then
            Resolver.trigger(matchState, matchState.activePlayer, attacker, "BEAT_THE_MAN", nil, r)
        end
        return r
    end

    -- LAST_DEFENDER_FOUL bypass: skip cover window for this striker advance
    if matchState.bypassCoverNextStrikerAttack and attackerSlot.type == "striker" then
        matchState.bypassCoverNextStrikerAttack = nil
        return Phases._advanceThrough(matchState, attacker, attackerSlot, emptySlot, opponentId)
    end

    if canCover then
```

In `Phases.endTurn`, directly after the line `    recoverPitch(matchState.players[activeId].pitch)`, add:

```lua
    matchState.players[activeId].pitch.throughBallUsed = nil   -- Through ball: once per turn
```

In `Phases._bestStriker`, replace

```lua
        if c and not c.exhausted and not c.cannotActNextTurn and c.mode == "attack" then
```

with

```lua
        if Phases.canAttackNow(c) then
```

- [ ] **Step 6: `store/match.lua` — Aerial and the Beat-the-man snapshot target.**

In `Store:declareAttack`, replace

```lua
            if coverUsed or #coverers == 0 then
```

with

```lua
            local attackerCard = Phases._getSlotForPlayer(match, activeId, attackerSlot)
            if coverUsed or #coverers == 0 or Resolver.uncoverable(attackerCard) then
```

Directly after the line `    local lastDefender = activeId == "player" and self:_isLastFaceUpDefender(opponentId, defenderSlot)`, insert:

```lua

    -- Aerial: Offside can't be activated against this card's attacks.
    local attackerCard = Phases._getSlotForPlayer(match, activeId, attackerSlot)
    local aerial = Resolver.immuneToOffside(attackerCard)
    if aerial and attackerSlot.type == "striker"
       and self:_findTrap(match.players[opponentId].pitch, "OFFSIDE") then
        Resolver.trigger(match, activeId, attackerCard, "AERIAL")
    end
```

Replace

```lua
    if activeId == "opponent" and attackerSlot.type == "striker" then
```

with

```lua
    if activeId == "opponent" and attackerSlot.type == "striker" and not aerial then
```

and replace

```lua
    if activeId == "player" and attackerSlot.type == "striker" then
```

with

```lua
    if activeId == "player" and attackerSlot.type == "striker" and not aerial then
```

- [ ] **Step 7: `ai/opponent.lua` — fresh cards (D1 / Pace).** In `AI._planNextAttack`, replace

```lua
    local function ready(c)
        return c and not c.exhausted and not c.cannotActNextTurn and c.mode == "attack"
               and c.aiRefusedTag ~= tag
    end
```

with

```lua
    local function ready(c)
        return Phases.canAttackNow(c) and c.aiRefusedTag ~= tag
    end
```

- [ ] **Step 8: `scenes/match.lua` — attacker selection and the Through-ball target.**

Directly after the line `local State         = require("engine.state")`, add:

```lua
local Phases        = require("engine.phases")
local Resolver      = require("engine.cards.resolver")
```

In `Match.getAttackTargetSlots`, replace

```lua
        if hasGap then
            table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
        end
```

with

```lua
        -- Keeper: through a gap, or past a full line with a Through ball (once per turn).
        if hasGap or Resolver.throughBall(match.players.player.pitch) then
            table.insert(slots, { slotType="keeper", slotIndex=0, owner="opponent" })
        end
```

In `Match.mousepressed` (attack phase, select attacker), replace

```lua
                    if not card.exhausted and not card.cannotActNextTurn
                       and card.mode == "attack" and canAttack then
                        if selectedAttackerSlot
                            and selectedAttackerSlot.type == slot.slotType
                            and selectedAttackerSlot.index == slot.slotIndex then
                            selectedAttackerSlot = nil
                        else
                            selectedAttackerSlot = { type=slot.slotType, index=slot.slotIndex }
                        end
                    end
```

with

```lua
                    if canAttack and Phases.canAttackNow(card) then
                        if selectedAttackerSlot
                            and selectedAttackerSlot.type == slot.slotType
                            and selectedAttackerSlot.index == slot.slotIndex then
                            selectedAttackerSlot = nil
                        else
                            selectedAttackerSlot = { type=slot.slotType, index=slot.slotIndex }
                        end
                    elseif canAttack and card.summonedThisTurn and card.mode == "attack" then
                        Match.flash("summoned this turn — attacks next turn")
                    end
```

- [ ] **Step 9: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/constants.lua engine/phases.lua engine/cards/resolver.lua store/match.lua ai/opponent.lua scenes/match.lua && lua tests/run.lua`
Expected: no `luac` output; `336 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 10: Snapshot the summon flow**

Run: `tools/snapshot/snap.sh summon`
Expected: it lists the 8 `summon_*.png` files, with no Lua traceback.

Read `.snapshots/summon_attack.png`. Check:
- the field card placed this turn has **no** yellow selected ring;
- the flash banner reads `SUMMONED THIS TURN — ATTACKS NEXT TURN` (if the placed card is Speed Demon, it has the ring and no banner instead);
- the hint line still reads `First turn of the half: no attacks or shots · END TURN when done`.

Read `summon_aiturn.png` and `summon_myturn.png`: the AI summons on its turn and does not attack with cards it summoned that turn (Speed Demon excepted); your turn starts normally.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add engine/constants.lua engine/cards/resolver.lua engine/phases.lua store/match.lua ai/opponent.lua scenes/match.lua tests/test_abilities_attack.lua
git commit -m "Abilities: Pace (summoned cards attack next turn), Through ball, Aerial, Beat the man" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **336**.

---

### Task 6: Turn abilities — Press and Metronome (spec §1, §2)

**Files:**
- Modify: `engine/cards/resolver.lua`, `engine/phases.lua`, `engine/state.lua`, `ai/opponent.lua`, `ui/match/stats.lua`
- Test: `tests/test_abilities_turn.lua`

- [ ] **Step 1: Write `tests/test_abilities_turn.lua`.**

```lua
local T      = require("tests.t")
local H      = require("tests.helpers")
local Phases = require("engine.phases")
local Stats  = require("ui.match.stats")

-- ── Press ─────────────────────────────────────────────────────────────────────

T.test("Press: summoning it exhausts the enemy's face-up defender with the highest DEF", function()
    local m = H.match({ phase = "summon" })
    local low  = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1500))
    local high = H.place(m, "opponent", "defender", 2, H.card("defender", 900, 1900))
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    T.eq(H.store(m):summonCard(c.id, "striker", 1, "defense"), true)
    T.eq(high.exhausted, true); T.eq(low.exhausted, false)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "PRESS"); T.eq(t[1].target.index, 2)
    -- It can't cover this turn: only `low` may cover an empty midfielder slot.
    T.eq(#Phases._eligibleCoverers(m.players.opponent.pitch, H.slot("midfielder")), 1)
    Phases.endTurn(m)
    T.eq(high.exhausted, false); T.eq(high.pressed, nil)
end)

T.test("Press: with no face-up defender it exhausts a face-down one", function()
    local m = H.match({ phase = "summon" })
    local fd = H.place(m, "opponent", "defender", 1, H.card("defender", 900, 1900), "defense")
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m):summonCard(c.id, "striker", 1, "attack")
    T.eq(fd.exhausted, true)
end)

T.test("Press: nothing to press without enemy defenders", function()
    local m = H.match({ phase = "summon" })
    local c = H.give(m, "player", H.kw("PRESS", "striker", 2100, 700))
    H.store(m):summonCard(c.id, "striker", 1, "attack")
    T.eq(#H.triggers(m), 0)
end)

-- ── Metronome ─────────────────────────────────────────────────────────────────

local function midfieldTurn(myMid)
    local m = H.match({ turn = 3, phase = "draw" })
    H.place(m, "player", "midfielder", 0, myMid, "defense")               -- DEF 1700 in control
    H.place(m, "opponent", "midfielder", 0, H.card("midfielder", 1600, 1400))
    return m, H.store(m)
end

T.test("Metronome: controlling midfield also gives +1 summon this turn", function()
    local m, s = midfieldTurn(H.kw("METRONOME", "midfielder", 1500, 1700))
    s:drawPhase()
    T.eq(m.bonusSummons, 1)
    T.eq(H.triggers(m)[1].keyword, "METRONOME")
    local used, max = Stats.summons(m)
    T.eq(used, 0); T.eq(max, 3)
    H.give(m, "player", H.card("striker", 2000, 500))
    local h = m.players.player.hand                     -- 2 drawn + 1 given
    T.eq(#h, 3)
    T.eq(s:summonCard(h[1].id, "defender", 1, "defense"), true)
    T.eq(s:summonCard(h[1].id, "defender", 2, "defense"), true)
    T.eq(s:summonCard(h[1].id, "striker", 1, "attack"), true)
    H.give(m, "player", H.card("striker", 2000, 500))
    local ok, err = s:summonCard(h[1].id, "striker", 2, "attack")
    T.eq(ok, false); T.eq(err, "summon limit reached")
    Phases.endTurn(m)
    T.eq(m.bonusSummons, 0)
end)

T.test("Metronome: a plain midfielder in control gives no extra summon", function()
    local m, s = midfieldTurn(H.card("midfielder", 1500, 1700))
    s:drawPhase()
    T.eq(m.bonusSummons or 0, 0)
    T.eq(#H.triggers(m), 0)
    T.eq(#m.players.player.hand, 2)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 3 `FAIL` lines: `Press: summoning it …`, `Press: with no face-up …`, `Metronome: controlling …`.
- The run ends with `338 passed, 3 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua` — Press and Metronome.** Directly **above** the final line `return R`, insert:

```lua
-- ── Turn hooks ────────────────────────────────────────────────────────────────

-- Press target on the enemy pitch: the defender-slot index of its face-up (attack or
-- revealed) card with the highest DEF (lowest index on a tie), else its first face-down
-- card; nil when there is none. Cards already pressed this turn are skipped.
function R.pressTarget(oppPitch)
    local best, bestDef = nil, -1
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = oppPitch.defenders[i]
        if c and not c.pressed and not R.hidden(c) then
            local d = c.definition.stats and c.definition.stats.def or 0
            if d > bestDef then best, bestDef = i, d end
        end
    end
    if best then return best end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = oppPitch.defenders[i]
        if c and not c.pressed then return i end
    end
    return nil
end

-- Summon hook (engine/phases.lua Phases.summon), after the card is on the pitch.
--   Press: exhaust one enemy defender-slot card (R.pressTarget) for this turn, so it can't
--   cover; pitched.pressed marks it and Phases.endTurn clears both flags at this turn's end.
function R.onSummon(matchState, ownerId, pitched)
    if not R.has(pitched, "PRESS") then return end
    local oppPitch = matchState.players[State.other(ownerId)].pitch
    local i = R.pressTarget(oppPitch)
    if not i then return end
    local target = oppPitch.defenders[i]
    target.exhausted = true
    target.pressed   = true
    R.trigger(matchState, ownerId, pitched, "PRESS", { target = { type = "defender", index = i } })
end

-- Midfield control hook (engine/phases.lua _midfieldControl) for the player in control.
--   Metronome: a Metronome card in the midfielder slot gives +1 summon this turn
--   (matchState.bonusSummons, reset by Phases.endTurn).
function R.onMidfieldControl(matchState, playerId)
    local mid = matchState.players[playerId].pitch.midfielder
    if not R.has(mid, "METRONOME") then return end
    matchState.bonusSummons = (matchState.bonusSummons or 0) + A.METRONOME_SUMMONS
    R.trigger(matchState, playerId, mid, "METRONOME")
end

```

- [ ] **Step 4: `engine/phases.lua` — hook calls, limit and end of turn.**

In `Phases._midfieldControl`, directly after the line `    if myPow <= oppPow then return end`, add:

```lua
    Resolver.onMidfieldControl(matchState, id)   -- Metronome (even with an empty deck)
```

In `Phases.summon`, replace

```lua
        local limit = player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
```

with

```lua
        local limit = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                    + (matchState.bonusSummons or 0)   -- Metronome
```

Replace

```lua
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = matchState.activePlayer, card = cardId, slot = slotType,
          index = slotIndex, mode = mode })
    return true
end
```

with

```lua
    State.log(matchState, T.EventType.CARD_PLAYED,
        { player = matchState.activePlayer, card = cardId, slot = slotType,
          index = slotIndex, mode = mode })
    Resolver.onSummon(matchState, matchState.activePlayer, pitched)   -- Press
    return true
end
```

In `Phases.endTurn`, replace

```lua
    matchState.coverUsed[activeId]         = false
    matchState.strategyPlayedThisTurn      = false
```

with

```lua
    matchState.coverUsed[activeId]         = false
    matchState.strategyPlayedThisTurn      = false
    matchState.bonusSummons                = 0     -- Metronome: this turn only
    -- Press: the other side's pressed cards were exhausted for this turn only.
    Phases._clearPressed(matchState.players[State.other(activeId)].pitch)
```

Directly after the whole `function Phases._clearAttackerFlags(pitch) … end`, add:

```lua

-- Press: a pressed card was exhausted for the presser's turn only (it can't cover then);
-- clear it at the end of that turn so it acts normally on its own turn.
function Phases._clearPressed(pitch)
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local c = pitch.defenders[i]
        if c and c.pressed then
            c.pressed   = nil
            c.exhausted = false
        end
    end
end
```

- [ ] **Step 5: `engine/state.lua` — `bonusSummons`.**

In `State.newMatch`, directly after the line `        summonCount  = 0,`, add:

```lua
        bonusSummons = 0,          -- extra summons this turn (Metronome)
```

In `State._resetHalf`, directly after the line `    matchState.summonCount  = 0`, add:

```lua
    matchState.bonusSummons = 0
```

- [ ] **Step 6: `ai/opponent.lua` — the AI's summon limit.** In `AI._planSummons`, replace

```lua
    local limit      = player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
```

with

```lua
    local limit      = (player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN)
                     + (match.bonusSummons or 0)   -- Metronome
```

- [ ] **Step 7: `ui/match/stats.lua` — SUMMONS pill.** Replace the whole block from `-- used, max — "SUMMONS used / max".` through the end of `function Stats.summons(match) … end` with:

```lua
-- used, max — "SUMMONS used / max". max is 2, or 1 under the opponent's Time Wasting, plus
-- Metronome's extra summon on your own turn. Midfield control itself gives a card.
function Stats.summons(match)
    local used = match.summonCount or 0
    local max  = match.players.player.nextTurnSummonLimit or C.MATCH.MAX_SUMMONS_PER_TURN
    if match.activePlayer == "player" then max = max + (match.bonusSummons or 0) end
    return used, max
end
```

- [ ] **Step 8: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/phases.lua engine/state.lua engine/cards/resolver.lua ai/opponent.lua ui/match/stats.lua && lua tests/run.lua`
Expected: no `luac` output; `341 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 9: Commit**

```bash
ls luac.out
git add engine/cards/resolver.lua engine/phases.lua engine/state.lua ai/opponent.lua ui/match/stats.lua tests/test_abilities_turn.lua
git commit -m "Abilities: Press and Metronome" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **341**.

---

### Task 7: Cover abilities — Intercept, Sweeper, Off the line (spec §1, §2; D3)

**Files:**
- Modify: `engine/cards/resolver.lua`, `engine/phases.lua`, `ui/overlay/prompts.lua`
- Test: `tests/test_abilities_cover.lua`

- [ ] **Step 1: Write `tests/test_abilities_cover.lua`.**

```lua
local T = require("tests.t")
local H = require("tests.helpers")

-- ── Intercept ─────────────────────────────────────────────────────────────────

T.test("Intercept: it may cover an empty defender slot (and is locked, as usual)", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1700, 500))
    local pb = H.place(m, "opponent", "defender", 2, H.kw("INTERCEPT", "defender", 950, 1800))
    local s = H.store(m)
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed")
    T.eq(r.eligibleCoverers[1].type, "defender"); T.eq(r.eligibleCoverers[1].index, 2)
    r = s:resolveCover(H.slot("defender", 2))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(pb.cannotActNextTurn, true)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "INTERCEPT"); T.eq(t[1].player, "opponent")
end)

T.test("Intercept: a plain defender can't cover an empty defender slot", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1700, 500))
    H.place(m, "opponent", "defender", 2, H.card("defender", 950, 1800))
    local r = H.store(m):declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "damage")                          -- straight through to an open goal
end)

-- ── Sweeper ───────────────────────────────────────────────────────────────────

T.test("Sweeper: covers an empty defender slot and is not locked", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1400, 500))
    local lib = H.place(m, "opponent", "defender", 2, H.kw("SWEEPER", "defender", 1600, 1500))
    local s = H.store(m)
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "cover_needed")
    local r = s:resolveCover(H.slot("defender", 2))
    T.eq(r.outcome, "attacker_exhausted")
    T.eq(lib.cannotActNextTurn, false)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "SWEEPER")
end)

T.test("Sweeper: covering the midfielder slot doesn't lock it either", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1400, 500))
    local lib = H.place(m, "opponent", "defender", 1, H.kw("SWEEPER", "defender", 1600, 1500))
    local s = H.store(m)
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("midfielder")).outcome, "cover_needed")
    T.eq(s:resolveCover(H.slot("defender", 1)).outcome, "attacker_exhausted")
    T.eq(lib.cannotActNextTurn, false)
end)

T.test("Sweeper: a plain defender that covers is locked", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", 1400, 500))
    local d = H.place(m, "opponent", "defender", 1, H.card("defender", 1600, 1500))
    local s = H.store(m)
    s:declareAttack(H.slot("striker", 1), H.slot("midfielder"))
    s:resolveCover(H.slot("defender", 1))
    T.eq(d.cannotActNextTurn, true)
    T.eq(#H.triggers(m), 0)
end)

-- ── Off the line ──────────────────────────────────────────────────────────────

local function keeperBoard(atk, keeperDef)
    local m = H.match()
    H.place(m, "player", "striker", 1, H.card("striker", atk, 500))
    local k = H.place(m, "opponent", "keeper", 0, keeperDef, "defense")
    return m, H.store(m), k
end

T.test("Off the line: the keeper covers an empty defender slot with its DEF and stays ready", function()
    local m, s, k = keeperBoard(1700, H.kw("OFF_THE_LINE", "keeper", 400, 1800))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "cover_needed"); T.eq(r.eligibleCoverers[1].type, "keeper")
    r = s:resolveCover(H.slot("keeper"))
    T.eq(r.outcome, "attacker_exhausted"); T.eq(r.damage, 100)
    T.eq(m.players.opponent.pitch.keeper, k)
    T.eq(k.cannotActNextTurn, false); T.eq(k.exhausted, false); T.eq(k.revealed, true)
    T.eq(m.coverUsed.opponent, true)
    T.eq(s.combatQueue[1].defender.def, 1800); T.eq(s.combatQueue[1].defender.isKeeper, false)
    local t = H.triggers(m)
    T.eq(#t, 1); T.eq(t[1].keyword, "OFF_THE_LINE")
end)

T.test("Off the line: a keeper that loses the cover fight is destroyed like any coverer", function()
    local m, s = keeperBoard(2000, H.kw("OFF_THE_LINE", "keeper", 400, 1800))
    T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "cover_needed")
    local r = s:resolveCover(H.slot("keeper"))
    T.eq(r.outcome, "defender_destroyed")
    T.eq(m.players.opponent.pitch.keeper, nil)
    T.eq(m.players.opponent.lp, 4000)                  -- a defense-mode card: no LP damage
end)

T.test("Off the line: other keepers never cover", function()
    local _, s = keeperBoard(1700, H.card("keeper", 400, 1800))
    local r = s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
    T.eq(r.outcome, "save")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected:
- 5 `FAIL` lines: `Intercept: it may cover …`, both `Sweeper: covers …` / `Sweeper: covering …` tests, `Off the line: the keeper covers …`, `Off the line: a keeper that loses …`.
- The run ends with `344 passed, 5 failed`.

- [ ] **Step 3: `engine/cards/resolver.lua` — cover hooks.** Directly **above** the final line `return R`, insert:

```lua
-- ── Cover hooks ───────────────────────────────────────────────────────────────

-- Extra cover permissions (the normal rule: the midfielder covers an empty defender slot,
-- any defender covers an empty midfielder slot). fromSlotType: the covering card's slot.
--   Intercept: a defender-slot card may cover an empty defender slot.
--   Sweeper: a defender- or midfielder-slot card may cover an empty defender or midfielder slot.
--   Off the line: the keeper may cover an empty defender slot.
function R.canCoverSlot(pitched, fromSlotType, emptySlotType)
    local kw = R.keyword(pitched)
    if kw == "INTERCEPT" then
        return fromSlotType == "defender" and emptySlotType == "defender"
    end
    if kw == "SWEEPER" then
        return (fromSlotType == "defender" or fromSlotType == "midfielder")
           and (emptySlotType == "defender" or emptySlotType == "midfielder")
    end
    if kw == "OFF_THE_LINE" then
        return fromSlotType == "keeper" and emptySlotType == "defender"
    end
    return false
end

-- Covering stops the coverer acting on its owner's next turn, except Sweeper and Off the line.
function R.coverLocks(pitched)
    return not (R.has(pitched, "SWEEPER") or R.has(pitched, "OFF_THE_LINE"))
end

-- The keyword to announce when this card covers, or nil for a plain cover.
function R.coverKeyword(pitched, fromSlotType, emptySlotType)
    local kw = R.keyword(pitched)
    if kw == "SWEEPER" or kw == "OFF_THE_LINE" then return kw end
    if kw == "INTERCEPT" and fromSlotType == "defender" and emptySlotType == "defender" then return kw end
    return nil
end

```

- [ ] **Step 4: `engine/phases.lua` — eligibility and resolution.**

Replace the whole `function Phases._eligibleCoverers(pitch, emptySlot) … end`, including its two comment lines above (`-- Returns eligible covering cards for an empty slot.` …), with:

```lua
-- Returns eligible covering cards for an empty slot: { type, index, card } in slot order
-- (midfielder, defenders, keeper). Every coverer must be ready (not exhausted, not locked).
--   Empty defender slot: the midfielder; an Intercept or Sweeper defender; an Off the line keeper.
--   Empty midfielder slot: any defender.
-- Field coverers must be in attack mode; an Off the line keeper covers in either mode.
function Phases._eligibleCoverers(pitch, emptySlot)
    local coverers = {}
    local et = emptySlot.type
    if et ~= "defender" and et ~= "midfielder" then return coverers end
    local function ready(card)
        return card and not card.exhausted and not card.cannotActNextTurn
    end
    local function add(card, slotType, slotIndex)
        table.insert(coverers, { type = slotType, index = slotIndex, card = card })
    end

    local mid = pitch.midfielder
    if ready(mid) and mid.mode == "attack"
       and (et == "defender" or Resolver.canCoverSlot(mid, "midfielder", et)) then
        add(mid, "midfielder", 0)
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = pitch.defenders[i]
        if ready(d) and d.mode == "attack"
           and (et == "midfielder" or Resolver.canCoverSlot(d, "defender", et)) then
            add(d, "defender", i)
        end
    end
    local k = pitch.keeper
    if ready(k) and Resolver.canCoverSlot(k, "keeper", et) then add(k, "keeper", 0) end
    return coverers
end
```

In `Phases.resolveCover`, replace

```lua
    if covererSlot then
        -- Mark cover as used
        matchState.coverUsed[opponentId] = true
        local coverer = Phases._getSlotForPlayer(matchState, opponentId, covererSlot)
        if not coverer then return nil, "no coverer" end

        -- Coverers are attack-mode cards; mark defensively in case that ever changes
        if coverer.mode == "defense" then coverer.revealed = true end

        -- Covering card cannot act next turn
        coverer.cannotActNextTurn = true

        State.log(matchState, T.EventType.COVER,
            { coverer = covererSlot, emptySlot = originalEmptySlot })

        return Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot, opponentId, true)
```

with

```lua
    if covererSlot then
        -- Mark cover as used (once per turn per side — Off the line included)
        matchState.coverUsed[opponentId] = true
        local coverer = Phases._getSlotForPlayer(matchState, opponentId, covererSlot)
        if not coverer then return nil, "no coverer" end

        -- Coverers are attack-mode cards, except an Off the line keeper (it gets revealed)
        if coverer.mode == "defense" then coverer.revealed = true end

        -- A covering card cannot act next turn — not a Sweeper or an Off the line keeper
        if Resolver.coverLocks(coverer) then coverer.cannotActNextTurn = true end

        State.log(matchState, T.EventType.COVER,
            { coverer = covererSlot, emptySlot = originalEmptySlot })

        local keyword = Resolver.coverKeyword(coverer, covererSlot.type, originalEmptySlot.type)
        local result  = Phases._doCombat(matchState, attacker, coverer, attackerSlot, covererSlot,
                                         opponentId, true)
        if keyword then Resolver.trigger(matchState, opponentId, coverer, keyword, nil, result) end
        return result
```

- [ ] **Step 5: `ui/overlay/prompts.lua` — cover note.** Replace

```lua
        "A covering card can't act next turn.")
```

with

```lua
        "A covering card can't act next turn (Sweeper and Off the line excepted).")
```

- [ ] **Step 6: Run the tests, the syntax check and the smoke run**

Run: `luac -p engine/phases.lua engine/cards/resolver.lua ui/overlay/prompts.lua && lua tests/run.lua`
Expected: no `luac` output; `349 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 7: Snapshot the cover prompt**

Run: `tools/snapshot/snap.sh cover`
Expected: `cover_slide.png`, `cover_panel.png`, with no Lua traceback.

Read `.snapshots/cover_panel.png`. Check:
- the note under the incoming-attack text reads `A covering card can't act next turn (Sweeper and Off the line excepted).`, wrapped inside the white panel;
- it does not run into the option card or the buttons.

- [ ] **Step 8: Commit**

```bash
ls luac.out
git add engine/cards/resolver.lua engine/phases.lua ui/overlay/prompts.lua tests/test_abilities_cover.lua
git commit -m "Abilities: Intercept, Sweeper and Off the line covers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **349**.

---

### Task 8: `ability_triggered` toasts (spec §1 clarifications, §3)

**Files:**
- Modify: `ui/match/toasts.lua`
- Test: `tests/test_ability_toasts.lua`

The `ability_triggered` event itself has been logged since Task 1 (`Resolver.trigger`). `scenes/match.lua` already passes every new log entry to `Toasts.describe`, so no scene change is needed.

- [ ] **Step 1: Write `tests/test_ability_toasts.lua`.**

```lua
local T        = require("tests.t")
local Toasts   = require("ui.match.toasts")
local Resolver = require("engine.cards.resolver")

local function ability(player, keyword, name, hidden)
    return { type = "ability_triggered",
             payload = { player = player, keyword = keyword, name = name, hidden = hidden } }
end

T.test("ability toasts: yours are good, the opponent's bad, with the card name", function()
    local txt, kind = Toasts.describe(ability("player", "PACE", "Speed Demon"))
    T.eq(txt, "Pace: Speed Demon attacks at once"); T.eq(kind, "good")
    txt, kind = Toasts.describe(ability("opponent", "PUNCH_CLEAR", "Iron Fists"))
    T.eq(txt, "Punch clear! Iron Fists"); T.eq(kind, "bad")
end)

T.test("ability toasts: the opponent's face-down card is not named", function()
    local txt = Toasts.describe(ability("opponent", "PRESS", "Pressing Forward", true))
    T.eq(txt, "Press: a face-down card presses a defender")
    txt = Toasts.describe(ability("player", "PRESS", "Pressing Forward", true))
    T.eq(txt, "Press: Pressing Forward presses a defender")
end)

T.test("ability toasts: always-on stat bonuses stay quiet; every other keyword has a text", function()
    for _, kw in ipairs(Resolver.ORDER) do
        local txt = Toasts.describe(ability("player", kw, "Card X"))
        if Toasts.QUIET[kw] then
            T.eq(txt, nil, kw)
        else
            T.ok(type(txt) == "string" and txt:find("Card X", 1, true) ~= nil, kw)
        end
    end
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 3 `FAIL` lines (the `ability toasts` tests); `349 passed, 3 failed`.

- [ ] **Step 3: `ui/match/toasts.lua` — ability texts.**

Directly **above** the line `-- text, kind for a log entry (nil = no toast). kind: good | bad | trap | half | info`, insert:

```lua
-- Ability toasts: "%s" is the card name (spec §3). Always-on stat bonuses (Toasts.QUIET)
-- show as pitch badges and combat-overlay tags instead, so they don't flood the toast stack.
Toasts.ABILITY_TEXT = {
    CLINICAL      = "Clinical: %s scores on a tie",
    AERIAL        = "Aerial: %s beats the offside trap",
    PACE          = "Pace: %s attacks at once",
    INSTINCT      = "Instinct: %s +300 on a tired keeper",
    OPPORTUNIST   = "Opportunist: %s +400 through the gap",
    PRESS         = "Press: %s presses a defender",
    BEAT_THE_MAN  = "Beat the man: %s can't be covered",
    METRONOME     = "Metronome: %s gives +1 summon",
    COUNTER_PRESS = "Counter-press: %s +300 DEF",
    THROUGH_BALL  = "Through ball: %s finds the striker",
    IMMOVABLE     = "Immovable: %s survives the tie",
    HARD_TACKLE   = "Hard tackle: %s benches the attacker",
    INTERCEPT     = "Intercept: %s covers the defence",
    BUILD_UP      = "Build-up: %s draws a card",
    SWEEPER       = "Sweeper: %s covers and stays ready",
    FORTRESS      = "Fortress: %s faces it at full DEF",
    PUNCH_CLEAR   = "Punch clear! %s",
    OFF_THE_LINE  = "Off the line: %s rushes out",
}
Toasts.QUIET = { LINK_UP = true, ENGINE = true, OVERLAP = true, LAST_MAN = true,
                 BOLT = true, SAFE_HANDS = true }

```

In `Toasts.describe`, directly after the line `    if t == "card_drawn" or t == "turn_end" then return nil end`, insert:

```lua
    if t == "ability_triggered" then
        if Toasts.QUIET[p.keyword] then return nil end
        local fmt = Toasts.ABILITY_TEXT[p.keyword]
        if not fmt then return nil end
        -- The opponent's face-down card is hidden information: don't name it.
        local name = (p.hidden and not mine) and "a face-down card" or (p.name or "?")
        return string.format(fmt, name), mine and "good" or "bad"
    end
```

- [ ] **Step 4: Run the tests and the syntax check**

Run: `luac -p ui/match/toasts.lua && lua tests/run.lua`
Expected: no `luac` output; `352 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
ls luac.out
git add ui/match/toasts.lua tests/test_ability_toasts.lua
git commit -m "Ability toasts, with quiet always-on bonuses and hidden opponent cards unnamed" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **352**.

---

### Task 9: Card UI — keyword pill, rules text, zoom lines, combat overlay (spec §3, §5 snapshots)

**Files:**
- Modify: `ui/theme.lua`, `ui/card.lua`, `ui/match/zoom.lua`, `ui/overlay/combatfx.lua`, `ui/overlay/combat.lua`, `tools/snapshot/card_gallery.lua`, `tools/snapshot/scenarios.lua`
- Test: `tests/test_abilities_ui.lua`

- [ ] **Step 1: Write `tests/test_abilities_ui.lua`.**

```lua
local T    = require("tests.t")
local H    = require("tests.helpers")
local Card = require("ui.card")
local Zoom = require("ui.match.zoom")
local Fx   = require("ui.overlay.combatfx")

local SIZES = { { 68, 80 }, { 84, 106 }, { 108, 148 }, { 120, 165 }, { 200, 274 }, { 300, 410 } }

T.test("keyword pill: above the name ribbon, below every status piece, clear of tag, gem and badges", function()
    for _, sz in ipairs(SIZES) do
        local w, h = sz[1], sz[2]
        local L, at = Card.layout(w, h), " at " .. w
        local k = L.kw
        T.ok(k.h >= 9, "legible" .. at)
        T.ok(k.y + k.h <= L.ribbon.y, "above the ribbon" .. at)
        T.ok(k.y >= L.tag.cy + L.tag.h / 2, "below the type tag" .. at)
        T.ok(k.y >= L.gem.cy + L.gem.size, "below the gem" .. at)
        T.ok(k.y >= L.zzz.y + L.zzz.h, "below the exhausted pill" .. at)
        T.ok(k.y >= L.defPill.y + L.defPill.h, "below the revealed DEF pill" .. at)
        T.ok(k.y >= L.flip.y + L.flip.h, "below the TO ATTACK ribbon" .. at)
        T.ok(k.y + k.h <= L.atk.cy - L.atk.size / 2, "above the badges" .. at)
        T.ok(k.maxW > 0 and k.cx - k.maxW / 2 >= 0 and k.cx + k.maxW / 2 <= w, "inside the card" .. at)
    end
end)

T.test("keyword pill text: upper-case keyword name for field cards only", function()
    T.eq(Card.keywordLabel({ type = "striker", keywordName = "Link-up" }), "LINK-UP")
    T.eq(Card.keywordLabel({ type = "keeper", keywordName = "Off the line" }), "OFF THE LINE")
    T.eq(Card.keywordLabel({ type = "trap", keywordName = "X" }), nil)
    T.eq(Card.keywordLabel({ type = "striker" }), nil)
    T.eq(Card.keywordLabel(nil), nil)
end)

local function has(lines, text)
    for _, l in ipairs(lines) do if l.text == text then return true end end
    return false
end

T.test("zoom: stat lines name the ability bonuses", function()
    local m = H.match()
    local s1 = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    H.place(m, "player", "striker", 2, H.kw("LINK_UP", "striker", 2150, 900))
    H.place(m, "player", "midfielder", 0, H.kw("OVERLAP", "midfielder", 1650, 1450))
    local lines = Zoom.statusLines(s1.definition, s1, m.players.player.pitch)
    T.ok(has(lines, "ATK 2000 + 450 = 2450 (Overlap +300, Link-up +150)"))
    T.eq(Zoom.partsText({}), "")
end)

T.test("zoom: locked and just-summoned cards say so (not a Pace card)", function()
    local m = H.match()
    local pitch = m.players.player.pitch
    local c = H.place(m, "player", "striker", 1, H.card("striker", 2000, 500))
    c.lockedNextTurn = true
    T.ok(has(Zoom.statusLines(c.definition, c, pitch), "Cannot act next turn"))
    local fresh = H.place(m, "player", "striker", 2, H.card("striker", 2000, 500))
    fresh.summonedThisTurn = true
    T.ok(has(Zoom.statusLines(fresh.definition, fresh, pitch), "Just summoned: attacks next turn"))
    local pace = H.place(m, "player", "defender", 1, H.kw("PACE", "striker", 2150, 550))
    pace.summonedThisTurn = true
    T.ok(not has(Zoom.statusLines(pace.definition, pace, pitch), "Just summoned: attacks next turn"))
end)

T.test("combat overlay: ability tags read 'NAME +N'", function()
    T.eq(Fx.tagText({ name = "Link-up", amount = 150 }), "LINK-UP +150")
    T.eq(Fx.tagText({ name = "Fortress", amount = 0 }), "FORTRESS")
    local list = Fx.bonusTags({ atkTags = { { name = "Link-up", amount = 150 },
                                            { name = "Instinct", amount = 300 } } }, "atk")
    T.eq(#list, 2); T.eq(list[2], "INSTINCT +300")
    T.eq(#Fx.bonusTags(nil, "atk"), 0)
    local v = Fx.cardView({ name = "X", type = "striker", atk = 2150, def = 500, atkBonus = 150,
                            defBonus = 0, atkTags = { { name = "Link-up", amount = 150 } } }, nil)
    T.eq(v.atkTags[1], "LINK-UP +150"); T.eq(#v.defTags, 0)
end)

T.test("combat overlay: rule abilities that fired are named once; stat ones are tags", function()
    T.eq(Fx.abilityLine({ abilities = { "CLINICAL" } }), "CLINICAL!")
    T.eq(Fx.abilityLine({ abilities = { "PUNCH_CLEAR", "LAST_MAN", "PUNCH_CLEAR" } }), "PUNCH CLEAR!")
    T.eq(Fx.abilityLine({ abilities = { "IMMOVABLE", "HARD_TACKLE" } }), "IMMOVABLE · HARD TACKLE!")
    T.eq(Fx.abilityLine({ abilities = { "BOLT" } }), nil)
    T.eq(Fx.abilityLine({}), nil)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 6 `FAIL` lines (every test in `test_abilities_ui.lua`); `352 passed, 6 failed`.

- [ ] **Step 3: `ui/theme.lua` — pill colour.** Directly after the line `    bonus = { hex("7dff8a"), hex("22b347") },`, add:

```lua
    keyword = { hex("fff3a8"), hex("ffc93a") },   -- ability keyword pills and tags
```

- [ ] **Step 4: `ui/card.lua` — layout, pill and info heading.**

In the header comment, directly after the line `--   Card.layout(w, h)                       pure geometry (unit-tested)`, add:

```lua
--   Card.keywordLabel(cardDef)              keyword pill text or nil (pure, unit-tested)
```

In `Card.layout`, directly **above** its final `    return L`, insert:

```lua
    -- Status pieces drawn over the art (drawExhausted, drawPitched).
    local ph = math.max(10, 16 * s)
    L.zzz     = { y = h * 0.30, h = ph }                  -- exhausted pill
    L.defPill = { y = h * 0.12, h = ph }                  -- revealed card's DEF marker
    L.flip    = { y = h * 0.26, h = math.max(12, 20 * s) }  -- revealed card's TO ATTACK ribbon
    -- Keyword pill: centred just above the name ribbon, below the status pieces; never over
    -- the ribbon, the badges, the type tag or the gem.
    local kwH = math.max(9, 14 * s)
    L.kw = { cx = w / 2, y = L.ribbon.y - kwH - math.max(1, 2 * s), h = kwH, maxW = w - 16 * s }
```

Replace

```lua
local function drawExhausted(L, x, y, alpha)
    local ph = math.max(10, 16 * L.s)
    local pw = ph * 2.4
    Draw.pill(x + (L.w - pw) / 2, y + L.h * 0.30, pw, ph, "zzz", {
```

with

```lua
local function drawExhausted(L, x, y, alpha)
    local ph = L.zzz.h
    local pw = ph * 2.4
    Draw.pill(x + (L.w - pw) / 2, y + L.zzz.y, pw, ph, "zzz", {
```

Directly after the whole `local function drawExhausted(L, x, y, alpha) … end`, add:

```lua

-- Keyword pill ("LINK-UP") centred above the name ribbon; nil label draws nothing.
local function drawKeyword(label, L, x, y, alpha)
    if not label then return end
    local k    = L.kw
    local size = math.max(6, math.floor(k.h * 0.62))
    local tw   = math.min(k.maxW, #label * size * 0.62 + k.h)
    Draw.pill(x + k.cx - tw / 2, y + k.y, tw, k.h, label, {
        fill = Theme.grad.keyword, textColor = Theme.inkText,
        border = math.max(1, math.floor(2 * L.s)), shadow = 0, size = size, alpha = alpha,
    })
end
```

In `Card.drawFace`, replace

```lua
    drawRibbon(cardDef.name, L, x, y, a)
```

with

```lua
    drawRibbon(cardDef.name, L, x, y, a)
    drawKeyword(Card.keywordLabel(cardDef), L, x, y, a)
```

Directly **above** the line `-- True when a pitched card is drawn face-up: attack mode, or a revealed defense-mode`, insert:

```lua
-- Keyword pill text for a field card ("LINK-UP"), or nil (traps, strategies, no keyword).
-- Pure (unit-tested).
function Card.keywordLabel(cardDef)
    local t = cardDef and cardDef.type
    if t ~= "striker" and t ~= "defender" and t ~= "midfielder" and t ~= "keeper" then return nil end
    if not cardDef.keywordName then return nil end
    return string.upper(cardDef.keywordName)
end

```

In `Card.drawPitched`, replace

```lua
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
            Draw.ribbon(x + w / 2, y + h * 0.40, w * 0.9, rh, "TO ATTACK", {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    end
```

with

```lua
    if pitched.mode == "defense" then
        local L  = Card.layout(w, h)
        local ph = L.defPill.h
        local pw = ph * 2.6
        Draw.pill(x + (w - pw) / 2, y + L.defPill.y, pw, ph, "DEF", {
            fill = Theme.grad.def, textColor = Theme.white,
            border = math.max(1, math.floor(2 * L.s)), shadow = 0,
        })
        if opts.canFlip then
            Draw.ribbon(x + w / 2, y + L.flip.y, w * 0.9, L.flip.h, "TO ATTACK", {
                fill = Theme.grad.bonus, textColor = Theme.white,
            })
        end
    end
```

Replace the whole `function Card.infoHeight(cardDef, w) … end` and `function Card.drawInfo(cardDef, x, y, w, extraH) … end`, including the comment line above each, with:

```lua
-- Height of the info sticker for cardDef at width w (wraps the ability text; a field card
-- adds its keyword heading).
function Card.infoHeight(cardDef, w)
    local body = Fonts.body(12)
    local _, lines = body:getWrap(cardDef.abilityText or "", w - INFO_PAD * 2)
    local heading = Card.keywordLabel(cardDef) and 18 or 0
    return INFO_PAD + 22 + 16 + heading + #lines * body:getHeight() + INFO_PAD
end

-- Info sticker: name, type · rarity, keyword heading (field cards), ability text.
-- Returns its height.
function Card.drawInfo(cardDef, x, y, w, extraH)
    local pad = INFO_PAD
    local h = Card.infoHeight(cardDef, w) + (extraH or 0)
    Draw.sticker(x, y, w, h, { r = 12, fill = Theme.white, border = 0, shadow = 4 })
    Draw.text(cardDef.name or "", x + pad, y + pad, w - pad * 2, "left",
        { size = 18, color = Theme.inkText, fit = true })
    local rc = Theme.rarityColors[cardDef.rarity] or Theme.rarityColors.common
    Draw.text(((Theme.typeLabel[cardDef.type] or "") .. " · " .. string.upper(cardDef.rarity or "")),
        x + pad, y + pad + 22, w - pad * 2, "left",
        { size = 11, body = true, color = { rc[1] * 0.6, rc[2] * 0.6, rc[3] * 0.6, 1 } })
    local textY = y + pad + 38
    local kw = Card.keywordLabel(cardDef)
    if kw then
        Draw.text(kw, x + pad, textY, w - pad * 2, "left",
            { size = 14, color = Theme.button.primary.text, fit = true })
        textY = textY + 18
    end
    Draw.text(cardDef.abilityText or "", x + pad, textY, w - pad * 2, "left",
        { size = 12, body = true, color = { 0.35, 0.35, 0.54, 1 } })
    return h
end
```

- [ ] **Step 5: `ui/match/zoom.lua` — ability parts, lock and just-summoned lines.**

Directly after the line `local Layout = require("ui.match.layout")`, add:

```lua
local C        = require("engine.constants")
local Resolver = require("engine.cards.resolver")
```

Replace the whole `function Zoom.statusLines(cardDef, pitched, pitch, hideHidden) … end`, including its two comment lines above, with:

```lua
-- " (Link-up +150, Engine +100)" for a stat line; "" without keyword parts. Pure.
function Zoom.partsText(parts)
    local out = {}
    for _, p in ipairs(parts or {}) do
        if p.keyword then
            out[#out + 1] = (Resolver.NAMES[p.keyword] or p.keyword) .. " +" .. tostring(p.amount or 0)
        end
    end
    if #out == 0 then return "" end
    return " (" .. table.concat(out, ", ") .. ")"
end

-- Extra lines under the ability text: { text, color = ink|bonus|bad|warn }.
-- hideHidden: the card is the opponent's (see Card.bonuses).
function Zoom.statusLines(cardDef, pitched, pitch, hideHidden)
    local lines = {}
    local function add(text, color) lines[#lines + 1] = { text = text, color = color } end
    if cardDef.playstyle then
        local ps = cardDef.playstyle
        add("Style: " .. (type(ps) == "table" and table.concat(ps, " · ") or tostring(ps)), "ink")
    end
    if cardDef.foulTendency then add("Foul tendency: " .. string.upper(tostring(cardDef.foulTendency)), "ink") end
    if not pitched then return lines end

    local st = cardDef.stats or {}
    local atkB, defB, atkParts, defParts = Card.bonuses(pitched, pitch, hideHidden)
    if atkB > 0 then
        add("ATK " .. (st.atk or 0) .. " + " .. atkB .. " = " .. ((st.atk or 0) + atkB)
            .. Zoom.partsText(atkParts), "bonus")
    end
    if defB > 0 then
        local label = pitched.slotType == "keeper" and "Effective DEF " or "DEF "
        add(label .. (st.def or 0) .. " + " .. defB .. " = " .. ((st.def or 0) + defB)
            .. Zoom.partsText(defParts), "bonus")
    end
    local modeText = "Mode: ATTACK"
    if pitched.mode == "defense" then
        modeText = pitched.revealed and "Mode: DEFENSE (revealed)" or "Mode: DEFENSE (face-down)"
    end
    add(modeText, "ink")
    if pitched.exhausted then add("EXHAUSTED", "bad") end
    if pitched.cannotActNextTurn or pitched.lockedNextTurn then add("Cannot act next turn", "bad") end
    if pitched.summonedThisTurn and pitched.mode == "attack" and pitched.slotType ~= "keeper"
       and not C.MATCH.SUMMONED_CAN_ATTACK and not Resolver.canAttackWhenSummoned(pitched) then
        add("Just summoned: attacks next turn", "warn")
    end
    if (pitched.yellowCards or 0) > 0 then add("Yellow cards: " .. pitched.yellowCards, "warn") end
    return lines
end
```

- [ ] **Step 6: `ui/overlay/combatfx.lua` — tag and ability-line helpers.**

Directly after the line `local Theme = require("ui.theme")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

Directly **above** the line `-- ── Card views ───…`, insert:

```lua
-- ── Ability tags ──────────────────────────────────────────────────────────────

-- "LINK-UP +150" for an ability tag { name, amount } (no number when amount is 0).
function Fx.tagText(tag)
    local s = string.upper(tag.name or tag.keyword or "?")
    if (tag.amount or 0) > 0 then s = s .. " +" .. tag.amount end
    return s
end

-- Tag texts for one side of a combat snapshot: which = "atk" (atkTags) or "def" (defTags).
function Fx.bonusTags(snap, which)
    local out = {}
    for _, t in ipairs(snap and snap[which .. "Tags"] or {}) do out[#out + 1] = Fx.tagText(t) end
    return out
end

-- Stat keywords are shown as badge tags, not in the ability line.
Fx.STAT_KEYWORDS = {
    LINK_UP = true, INSTINCT = true, OPPORTUNIST = true, LAST_MAN = true, COUNTER_PRESS = true,
    SAFE_HANDS = true, ENGINE = true, OVERLAP = true, BOLT = true, FORTRESS = true,
}

-- Rule abilities that fired during this attack, as one line ("CLINICAL!",
-- "IMMOVABLE · HARD TACKLE!"), each named once; nil when there are none.
function Fx.abilityLine(rec)
    local names, seen = {}, {}
    for _, kw in ipairs(rec and rec.abilities or {}) do
        if not Fx.STAT_KEYWORDS[kw] and not seen[kw] then
            seen[kw] = true
            names[#names + 1] = string.upper(Resolver.NAMES[kw] or kw)
        end
    end
    if #names == 0 then return nil end
    return table.concat(names, " · ") .. "!"
end

```

In `Fx.cardView`, replace

```lua
        hidden   = snap.wasHidden,
        atk      = snap.atk or 0,
        def      = snap.def or 0,
    }
```

with

```lua
        hidden   = snap.wasHidden,
        atk      = snap.atk or 0,
        def      = snap.def or 0,
        atkTags  = Fx.bonusTags(snap, "atk"),
        defTags  = Fx.bonusTags(snap, "def"),
    }
```

and change its comment line `--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def } | nil` to `--   → { cardDef, stats = { atk, def }, atkBonus, defBonus, hidden, atk, def, atkTags, defTags } | nil`.

- [ ] **Step 7: `ui/overlay/combat.lua` — tags, label and ability pill.**

Replace the header comment lines

```lua
--   rec = { attacker, defender, outcome, margin, damage, activePlayer }   (store:_pushCombat)
--   attacker / defender = { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper }
```

with

```lua
--   rec = { attacker, defender, outcome, margin, damage, activePlayer, abilities }   (store:_pushCombat)
--   attacker / defender = { name, type, mode, wasHidden, atk, def, atkBonus, defBonus, isKeeper,
--                           atkTags, defTags }
```

Replace the whole `local function drawBadges(rec, p, sides) … end`, including its comment line `-- Big ATK / DEF badges that grow and count up, with their labels.`, with:

```lua
local TAG_Y = 462   -- ability tag row, between the cards and the big badges

-- Ability bonus tags ("LINK-UP +150") centred on cx, at most 3.
local function drawTags(tags, cx, alpha)
    local n = math.min(#tags, 3)
    if n == 0 then return end
    local tw, th, gap = 140, 26, 8
    local x0 = cx - (n * tw + (n - 1) * gap) / 2
    for i = 1, n do
        Draw.pill(x0 + (i - 1) * (tw + gap), TAG_Y, tw, th, tags[i], {
            fill = Theme.grad.keyword, textColor = Theme.inkText, size = 14, border = 2, shadow = 3,
            alpha = alpha,
        })
    end
end

-- Big ATK / DEF badges that grow and count up, with their labels and ability tags.
local function drawBadges(rec, p, sides)
    if p.badge <= 0 then return end
    local s = BADGE_S * p.badge
    local labelY = BADGE_Y + BADGE_S / 2 + 12
    local la = math.min(1, p.badge)                  -- labels fade in with the badges
    local a, d = cache.atk, cache.def
    if a then
        local x = sides.atk.cx + p.shake
        Draw.atkBadge(x, BADGE_Y, s, Fx.countValue(a.atk, p.count))
        Draw.pill(x - 60, labelY, 120, 28, a.atkBonus > 0 and ("ATK +" .. a.atkBonus) or "ATK", {
            fill = Theme.white, textColor = Theme.grad.atk[2], size = 16, border = 2, shadow = 3, alpha = la,
        })
        drawTags(a.atkTags, x, la)
    end
    if d then
        local x = sides.def.cx + p.shake
        Draw.defBadge(x, BADGE_Y, s * 0.95, Fx.countValue(d.def, p.count), d.defBonus > 0 and d.defBonus or nil)
        Draw.pill(x - 60, labelY, 120, 28, rec.defender.isKeeper and "EFF. DEF" or "DEF", {
            fill = Theme.white, textColor = Theme.grad.def[2], size = 16, border = 2, shadow = 3, alpha = la,
        })
        drawTags(d.defTags, x, la)
    end
end
```

In `CombatOverlay.draw`, replace

```lua
    if p.hint > 0 then Draw.hintPill(W / 2, 744, "CLICK OR SPACE", p.hint) end
end
```

with

```lua
    -- Rule abilities that fired (Clinical, Immovable, Punch clear …), under the banner.
    local line = Fx.abilityLine(rec)
    if line and p.result > 0 then
        Draw.pill(W / 2 - 180, 98, 360, 36, line, {
            fill = Theme.grad.keyword, textColor = Theme.inkText, size = 20, border = 3, shadow = 4,
            alpha = math.min(1, p.result),
        })
    end
    if p.hint > 0 then Draw.hintPill(W / 2, 744, "CLICK OR SPACE", p.hint) end
end
```

- [ ] **Step 8: `tools/snapshot/card_gallery.lua` — keyword gallery.** Directly **above** the final line `return G`, insert:

```lua

-- Keyword pills: all 24 field cards at small size, then hand, pitch states and zoom + info.
function G.drawKeywords()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    Draw.background(W, H)
    local field = {}
    for _, d in ipairs(defs) do
        if d.type == "striker" or d.type == "midfielder" or d.type == "defender" or d.type == "keeper" then
            field[#field + 1] = d
        end
    end
    for i, d in ipairs(field) do
        local col, row = (i - 1) % 12, math.floor((i - 1) / 12)
        Card.drawFace(d, 30 + col * 102, 30 + row * 150, 84, 106, {})
    end
    local function byId(id) return pick(function(d) return d.id == id end) end
    local y = 340
    Card.drawFace(byId("str-speed-demon"), 30, y, 120, 165, { badges = "left" })
    Card.drawPitched({ definition = byId("keeper-the-wall"), mode = "defense", revealed = true,
                       slotType = "keeper", exhausted = true }, 180, y, {})
    Card.drawPitched({ definition = byId("def-libero"), mode = "defense", revealed = true,
                       slotType = "defender" }, 310, y, { canFlip = true })
    Card.drawFace(byId("mid-pressing-monster"), 440, y, 68, 80, {})
    Card.drawLarge(byId("mid-creative-playmaker"), 560, y, 250)
end
```

- [ ] **Step 9: `tools/snapshot/scenarios.lua` — `keywords` and `abilities` scenarios.** Directly **above** the final line `return S`, insert:

```lua
-- Keyword pills on every field card, the hand size, revealed / exhausted / flip states, a
-- 68×80 card and a zoom card with its info sticker (tools/snapshot/card_gallery.lua).
S.keywords = {
    { 0.3, function() love.draw = require("tools.snapshot.card_gallery").drawKeywords end },
    { 1.0, function(c) c.snap("gallery") end },
    { 1.5, function(c) c.quit() end },
}

-- Abilities through the real engine (harness-only board): pills and bonus badges on the
-- pitch, the zoom's ability line, a real shot with Overlap + Link-up + Opportunist tags, a
-- synthetic Punch clear save for the ability pill, then a real Press summon for the toast.
S.abilities = {
    { 0.3, function() math.randomseed(7) end },
    { 0.5, kickOff },
    { 1.5, function()
        local m = store().match
        local P, O = m.players.player.pitch, m.players.opponent.pitch
        P.strikers[1]  = pitched("str-poacher", "striker")
        P.strikers[2]  = pitched("str-complete-forward", "striker")
        P.midfielder   = pitched("mid-direct-support", "midfielder")
        O.keeper       = pitched("keeper-iron-fists", "keeper", "defense")
        O.defenders[1] = pitched("def-stopper", "defender")
        m.turn, m.phase = 2, "attack"
    end },
    { 1.9, function(c) c.snap("board") end },
    { 2.0, function() move(center(Layout.slot("player", "striker", 1))) end },
    { 2.6, function(c) c.snap("zoom") end },
    { 2.7, function()
        move(640, 60)
        local st = store()
        st:declareAttack({ type = "striker", index = 1 }, { type = "keeper", index = 0 })
        require("scenes.match").debugOverlay("combat", st:popCombat())
    end },
    { 4.1, function(c) c.snap("tags") end },
    { 4.6, function(c) c.snap("result") end },
    { 4.7, function() love.keypressed("space") end },
    { 4.8, combat({
        attacker = snapFrom("str-speed-demon"),
        defender = snapFrom("keeper-iron-fists", { def = 2200, isKeeper = true }),
        outcome = "save", margin = -50, damage = 0, activePlayer = "player",
        abilities = { "PUNCH_CLEAR" } }) },
    { 6.9, function(c) c.snap("punch") end },
    { 7.0, function() love.keypressed("space") end },
    { 7.1, function()
        local st = store()
        local m  = st.match
        m.phase, m.summonCount = "summon", 0
        local pf = defById("str-pressing-forward")
        table.insert(m.players.player.hand, pf)
        st:summonCard(pf.id, "defender", 2, "attack")
    end },
    { 7.6, function(c) c.snap("toasts") end },
    { 7.8, function(c) c.quit() end },
}
```

- [ ] **Step 10: Run the tests and the syntax checks**

Run: `luac -p ui/theme.lua ui/card.lua ui/match/zoom.lua ui/overlay/combatfx.lua ui/overlay/combat.lua tools/snapshot/card_gallery.lua tools/snapshot/scenarios.lua && lua tests/run.lua`
Expected: no `luac` output; `358 passed, 0 failed`.

- [ ] **Step 11: Snapshots**

Run: `for s in keywords abilities cards library home combat; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback.

Read `.snapshots/keywords_gallery.png`. Check:
- **Pills:**
  - every one of the 24 field cards shows a yellow pill with its keyword just above the white name ribbon;
  - no pill touches the ribbon, the type tag, the rarity gem or the ATK/DEF badges;
  - `COUNTER-PRESS`, `BEAT THE MAN`, `OFF THE LINE` and `THROUGH BALL` fit inside their pills.
- **Hand-size Speed Demon:** its pill is clear of both left-paired badges.
- **Revealed, exhausted The Wall:** the DEF marker, the `zzz` pill and the keyword pill don't overlap.
- **Revealed Libero with `TO ATTACK`:** the DEF marker, the ribbon and the pill don't overlap.
- **68×80 Pressing Monster:** its pill is still legible.
- **Creative Playmaker zoom card:** its info sticker shows the `THROUGH BALL` heading above the rules text, all inside the screen.

Read the `abilities_*.png` files. Check:
- **`abilities_board.png`:**
  - pills on the Poacher (`OPPORTUNIST`), Complete Forward (`LINK-UP`), Direct Support (`OVERLAP`) and the opponent's Stopper (`LAST MAN`); the opponent keeper shows its back;
  - the Poacher's ATK badge reads 2550 with a `+450` tag, the Complete Forward's 2450 with `+300`, and the Stopper's DEF 2300 with a `+300` marker.
- **`abilities_zoom.png`:** the zoom's info sticker shows the `OPPORTUNIST` heading, the rules text and the line `ATK 2100 + 450 = 2550 (Overlap +300, Link-up +150)`.
- **`abilities_tags.png`:**
  - the Poacher's badge counts to 2950 with three yellow tags under the card: `OVERLAP +300`, `LINK-UP +150`, `OPPORTUNIST +400`;
  - the keeper side reads `EFF. DEF` 2200 with no tags;
  - the ATK label reads `ATK +850`.
- **`abilities_result.png`:** the `LP DAMAGE -750` ribbon.
- **`abilities_punch.png`:** a `PUNCH CLEAR!` pill under the `YOU ATTACK!` banner and a `KEEPER SAVES` ribbon.
- **`abilities_toasts.png`:**
  - the toasts include `Press: Pressing Forward presses a defender` (green) and `Opportunist: The Poacher +400 through the gap`;
  - the opponent's Stopper shows the `zzz` pill;
  - no `Link-up` or `Overlap` toast appears.

Also check the other scenarios:
- `cards_gallery.png`: keyword pills on the field cards only, none on the trap or strategy; the exhausted Clinical Finisher's `zzz` and pill don't overlap.
- `library_grid.png`: pills on the field cards.
- `library_hover.png`: the zoom info sticker shows the keyword heading.
- `home_deck.png` / `home_deck2.png`: the fanned deck cards show pills.
- `combat_count.png`, `combat_save.png`: ATK labels read `ATK +200` / `ATK` (no `MID`); nothing else changes from the Plan B checklist.

- [ ] **Step 12: Commit**

```bash
ls luac.out
git add ui/theme.lua ui/card.lua ui/match/zoom.lua ui/overlay/combatfx.lua ui/overlay/combat.lua tools/snapshot/card_gallery.lua tools/snapshot/scenarios.lua tests/test_abilities_ui.lua
git commit -m "Ability UI: keyword pills, rules text, zoom lines and combat overlay tags" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **358**.

---

### Task 10: AI awareness (spec §4)

**Files:**
- Modify: `ai/opponent.lua`
- Test: `tests/test_ai_abilities.lua`

Pace (fresh attackers) and the summon limit were already handled in Tasks 5 and 6. The refused-attack guard (`aiRefusedTag`) stays as it is: any attack the engine refuses is still skipped for the rest of the turn.

- [ ] **Step 1: Write `tests/test_ai_abilities.lua`.**

```lua
local T  = require("tests.t")
local H  = require("tests.helpers")
local AI = require("ai.opponent")

T.test("AI Aerial: its Offside policy never targets an Aerial striker", function()
    local m = H.match()
    H.place(m, "player", "striker", 1, H.kw("AERIAL", "striker", 2200, 600))
    H.place(m, "player", "striker", 2, H.card("striker", 2200, 600))
    H.place(m, "opponent", "keeper", 0, H.card("keeper", 300, 1600))
    T.eq(AI.wantsOffside(m, "opponent", H.slot("striker", 1), H.slot("keeper")), false)
    T.eq(AI.wantsOffside(m, "opponent", H.slot("striker", 2), H.slot("keeper")), true)
end)

T.test("AI Beat the man: goes through an empty slot when the shot scores", function()
    local function board(attackerDef)
        local m = H.match({ active = "opponent" })
        H.place(m, "opponent", "striker", 1, attackerDef)
        H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
        H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))   -- effective DEF 1800
        return m
    end
    local a = AI._planNextAttack(board(H.kw("BEAT_THE_MAN", "striker", 2050, 500)), "medium")
    T.eq(a.defenderSlot.type, "defender"); T.eq(a.defenderSlot.index, 2)
    a = AI._planNextAttack(board(H.card("striker", 2050, 500)), "medium")
    T.eq(a.defenderSlot.index, 1, "a plain striker takes the winning fight")
end)

T.test("AI Through ball: shoots past a full defence when the shot scores", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2400, 500))
    H.place(m, "opponent", "midfielder", 0, H.kw("THROUGH_BALL", "midfielder", 1600, 1550), "defense")
    H.place(m, "player", "defender", 1, H.card("defender", 900, 2500))
    H.place(m, "player", "defender", 2, H.card("defender", 900, 2500))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1500))
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.defenderSlot.type, "keeper"); T.eq(a.attackerSlot.type, "striker")
    m.players.opponent.pitch.midfielder = nil
    T.eq(AI._planNextAttack(m, "medium"), nil)
end)

T.test("AI Press: summons its Press striker first when the human shows a defender", function()
    local m = H.match({ active = "opponent", phase = "summon" })
    m.players.opponent.nextTurnSummonLimit = 1
    H.give(m, "opponent", H.card("striker", 2200, 500))
    local press = H.give(m, "opponent", H.kw("PRESS", "striker", 2100, 700))
    local d = H.place(m, "player", "defender", 1, H.card("defender", 900, 1500))
    local acts = AI._planSummons(m)
    T.eq(#acts, 1); T.eq(acts[1].cardId, press.id)
    d.mode = "defense"
    acts = AI._planSummons(m)
    T.ok(acts[1].cardId ~= press.id, "no face-up defender: the stronger striker first")
end)

T.test("AI cover: Counter-press DEF counts in the cover decision", function()
    local function coverChoice(midDef)
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", 1600, 500))
        H.place(m, "opponent", "midfielder", 0, midDef)
        local s = H.store(m)
        s:declareAttack(H.slot("striker", 1), H.slot("defender", 1))
        return AI.decideCover(s)
    end
    T.eq(coverChoice(H.kw("COUNTER_PRESS", "midfielder", 1700, 1400)).type, "midfielder")
    T.eq(coverChoice(H.card("midfielder", 1700, 1400)), nil)
end)

T.test("AI cover: an Off the line keeper covers only when it wins outright", function()
    for _, case in ipairs({ { atk = 1700, covers = true }, { atk = 1800, covers = false },
                            { atk = 1900, covers = false } }) do
        local m = H.match()
        H.place(m, "player", "striker", 1, H.card("striker", case.atk, 500))
        H.place(m, "opponent", "keeper", 0, H.kw("OFF_THE_LINE", "keeper", 400, 1800), "defense")
        local s = H.store(m)
        s.aiDifficulty = "hard"
        T.eq(s:declareAttack(H.slot("striker", 1), H.slot("defender", 1)).outcome, "cover_needed")
        T.eq(AI.decideCover(s) ~= nil, case.covers, "ATK " .. case.atk)
    end
end)

T.test("AI fight estimate: counts a face-up Last man bonus", function()
    local m = H.match({ active = "opponent" })
    H.place(m, "opponent", "striker", 1, H.card("striker", 2200, 500))
    H.place(m, "player", "defender", 1, H.kw("LAST_MAN", "defender", 850, 2000))
    H.place(m, "player", "keeper", 0, H.card("keeper", 300, 1600))
    local a = AI._planNextAttack(m, "medium")
    T.eq(a.defenderSlot.index, 2, "2300 DEF: goes round it")
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `lua tests/run.lua`
Expected: 7 `FAIL` lines (every test in `test_ai_abilities.lua`); `358 passed, 7 failed`.

- [ ] **Step 3: `ai/opponent.lua` — require the resolver.** Directly after the line `local State  = require("engine.state")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

- [ ] **Step 4: Cover decision.** Replace the whole `function AI.decideCover(store) … end` with:

```lua
function AI.decideCover(store)
    local cw = store.coverWindow
    if not cw or #cw.eligibleCoverers == 0 then return nil end

    local match      = store.match
    local activeId   = match.activePlayer
    local defenderId = activeId == "player" and "opponent" or "player"
    if match.coverUsed[defenderId] then return nil end

    local difficulty = store.aiDifficulty or "medium"
    if difficulty == "easy" then return nil end

    local atkStat  = cw.attackerSnap and (cw.attackerSnap.atk or 0) or 0
    local ownPitch = match.players[defenderId].pitch

    -- Best coverer by its covering DEF (Counter-press, Last man, midfielder bonus). On equal
    -- DEF prefer one that covering doesn't lock (Sweeper, Off the line). A keeper (Off the
    -- line) only covers when it wins outright: a lost or tied cover would cost the keeper.
    local best, bestDef = nil, -1
    for _, cov in ipairs(cw.eligibleCoverers) do
        local d = Combat.defendStat(cov.card, cov.type, ownPitch, true)
        local usable = cov.type ~= "keeper" or d > atkStat
        if usable and (d > bestDef or (d == bestDef and best
                and Resolver.coverLocks(best.card) and not Resolver.coverLocks(cov.card))) then
            best, bestDef = cov, d
        end
    end
    if not best then return nil end

    if difficulty == "medium" then
        if atkStat - bestDef <= 0 then
            return { type = best.type, index = best.index }
        end
        return nil
    end

    -- Hard: always cover (even a losing cover blocks damage this turn)
    return { type = best.type, index = best.index }
end
```

- [ ] **Step 5: Press summon priority.** In `AI._planSummons`, replace

```lua
    -- Priority: keeper > striker (by ATK) > midfielder (by ATK) > defender (by DEF) > others
    local typePri = { keeper=5, striker=4, midfielder=3, defender=2, trap=1, strategy=0 }
    table.sort(hand, function(a, b)
        local ap = typePri[a.type] or 0
        local bp = typePri[b.type] or 0
        if ap ~= bp then return ap > bp end
        local aVal = (a.type == "striker" or a.type == "midfielder")
                     and (a.stats and a.stats.atk or 0)
                      or (a.stats and a.stats.def or 0)
        local bVal = (b.type == "striker" or b.type == "midfielder")
                     and (b.stats and b.stats.atk or 0)
                      or (b.stats and b.stats.def or 0)
        return aVal > bVal
    end)
```

with

```lua
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
```

- [ ] **Step 6: Fight evaluation and legal targets.**

Replace the whole `local function evalFight(atkStat, defCard) … end`, including its two comment lines above, with:

```lua
-- Evaluate a fight between atkStat and a defending card in slotType on dPitch, with the
-- bonuses the AI can see (Combat.defendStat, visible only).
-- Returns "win", "tie", "loss", "facedown" (unknown), or "empty".
local function evalFight(atkStat, defCard, slotType, dPitch)
    if not defCard then return "empty" end
    if defCard.mode == "defense" and not defCard.revealed then return "facedown" end
    local d = Combat.defendStat(defCard, slotType, dPitch, false, true)
    if atkStat > d then return "win"
    elseif atkStat == d then return "tie"
    else return "loss"
    end
end
```

Replace the whole `function AI.isLegalTarget(ePitch, attackerType, target) … end`, including its three comment lines above, with:

```lua
-- Can an AI card in attackerType's slot target `target` on the enemy pitch? The same
-- table the human gets (scenes/match.lua getAttackTargetSlots, rules.md "Who Can
-- Attack What"). ownPitch (optional): the AI's pitch, for Through ball.
function AI.isLegalTarget(ePitch, attackerType, target, ownPitch)
    if not target then return false end
    if attackerType == "striker" then
        if target.type == "defender" then return true end
        if target.type == "keeper" then
            return enemyHasGap(ePitch) or (ownPitch ~= nil and Resolver.throughBall(ownPitch) ~= nil)
        end
        if target.type == "midfielder" then
            for i = 1, C.PITCH.MAX_DEFENDERS do
                if ePitch.defenders[i] then return false end
            end
            return true
        end
        return false
    elseif attackerType == "midfielder" then
        return target.type == "midfielder" and ePitch.midfielder ~= nil
    elseif attackerType == "defender" then
        return target.type == "striker"
    end
    return false
end
```

- [ ] **Step 7: Attack planning.** Replace the whole `function AI._planNextAttack(match, difficulty) … end`, including its two comment lines above, with:

```lua
-- Returns a single attack action, trying attackers highest-ATK first.
-- Skips attackers that only have clearly losing targets (on medium/hard).
function AI._planNextAttack(match, difficulty)
    -- No attacks on the opening turn of a half (engine rule).
    if State.isOpeningTurn(match) then return nil end
    local pitch  = match.players.opponent.pitch
    local ePitch = match.players.player.pitch

    -- Every card that may attack now (Phases.canAttackNow: Pace included) and was not
    -- already refused by the store this turn, with its fight ATK (midfielder card and
    -- ability bonuses via Combat.attackStat).
    local tag = AI.planTag(match)
    local function ready(c)
        return Phases.canAttackNow(c) and c.aiRefusedTag ~= tag
    end
    local attackers = {}
    local function add(c, slotType, slotIndex)
        if ready(c) then
            table.insert(attackers, { slotType = slotType, slotIndex = slotIndex, card = c,
                                      atk = Combat.attackStat(c, slotType, pitch, ePitch) })
        end
    end
    for i = 1, C.PITCH.MAX_STRIKERS do add(pitch.strikers[i], "striker", i) end
    add(pitch.midfielder, "midfielder", 0)
    for i = 1, C.PITCH.MAX_DEFENDERS do add(pitch.defenders[i], "defender", i) end

    if #attackers == 0 then return nil end
    table.sort(attackers, function(a, b) return a.atk > b.atk end)

    -- Open goal: the human's keeper slot is empty and a defender slot is open, so a
    -- striker-slot shot scores its full ATK. Always the best move; the highest ATK shoots.
    -- Checked from the AI's own view only (not Phases.validateAttack, which reads
    -- match.activePlayer and so the wrong sides in the simulator's mirrored view).
    if not ePitch.keeper and enemyHasGap(ePitch) then
        for _, a in ipairs(attackers) do
            if a.slotType == "striker" then
                return { type = "attack", attackerSlot = { type = "striker", index = a.slotIndex },
                         defenderSlot = { type = "keeper", index = 0 } }
            end
        end
    end

    -- Try each attacker until one finds a valid target
    for _, best in ipairs(attackers) do
        local target = AI._pickTarget(match, best, difficulty)
        if target and AI.isLegalTarget(ePitch, best.slotType, target, pitch) then
            return {
                type         = "attack",
                attackerSlot = { type = best.slotType, index = best.slotIndex },
                defenderSlot = target,
            }
        end
    end
    return nil
end
```

- [ ] **Step 8: Target choice.** Replace the whole `function AI._pickTarget(match, attacker, difficulty) … end` with:

```lua
function AI._pickTarget(match, attacker, difficulty)
    local dPitch  = match.players.player.pitch
    local oPitch  = match.players.opponent.pitch
    local atkStat = attacker.atk

    -- ── Defenders: attack opposing strikers to remove threats ─────────────────
    if attacker.slotType == "defender" then
        local candidates = {}
        for i = 1, C.PITCH.MAX_STRIKERS do
            local s = dPitch.strikers[i]
            if s then
                local ev  = evalFight(atkStat, s, "striker", dPitch)
                local atk = s.definition.stats and s.definition.stats.atk or 0
                table.insert(candidates, { type = "striker", index = i, ev = ev, threatAtk = atk })
            end
        end
        if #candidates == 0 then return nil end

        if difficulty == "easy" then
            return { type = candidates[math.random(#candidates)].type,
                     index = candidates[math.random(#candidates)].index }
        end

        -- Medium/Hard: prefer winning fights; on hard also consider biggest threat first
        table.sort(candidates, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            -- Tiebreak: hard targets biggest threat; medium targets easiest win
            if difficulty == "hard" then return a.threatAtk > b.threatAtk end
            return (Combat.getStat(dPitch.strikers[a.index], "defend"))
                 < (Combat.getStat(dPitch.strikers[b.index], "defend"))
        end)
        local```lua
 pick = candidates[1]
        -- Medium: skip if best option is a clear loss against a face-up card
        if difficulty == "medium" and pick.ev == "loss" then return nil end
        return { type = pick.type, index = pick.index }
    end

    -- ── Midfielder: only attacks an occupied opposing midfielder ──────────────
    if attacker.slotType == "midfielder" then
        local oMid = dPitch.midfielder
        if not oMid then return nil end
        local ev = evalFight(atkStat, oMid, "midfielder", dPitch)
        -- Medium/Hard: don't attack if it's a face-up losing fight
        if difficulty ~= "easy" and ev == "loss" then return nil end
        return { type = "midfielder", index = 0 }
    end

    -- ── Strikers: advance toward keeper, clearing the path ────────────────────
    local defenders = {}
    for i = 1, C.PITCH.MAX_DEFENDERS do
        local d = dPitch.defenders[i]
        if d then
            local ev  = evalFight(atkStat, d, "defender", dPitch)
            local def = (d.mode ~= "defense" or d.revealed)
                        and Combat.defendStat(d, "defender", dPitch, false, true) or 0
            table.insert(defenders, { type = "defender", index = i, ev = ev, def = def })
        end
    end

    if difficulty == "easy" then
        if #defenders > 0 then
            local pick = defenders[math.random(#defenders)]
            return { type = pick.type, index = pick.index }
        end
        for i = 1, C.PITCH.MAX_DEFENDERS do
            if not dPitch.defenders[i] then return { type = "defender", index = i } end
        end
        return nil
    end

    -- Medium/Hard: prefer winning or unknown fights; route through empty slots
    -- when no winning attack is available rather than suiciding into a stronger defender.
    local winning = {}
    local empty   = {}
    for _, d in ipairs(defenders) do
        if d.ev == "win" or d.ev == "facedown" then table.insert(winning, d) end
    end
    for i = 1, C.PITCH.MAX_DEFENDERS do
        if not dPitch.defenders[i] then table.insert(empty, i) end
    end

    -- This attacker's shot from here: its shot ATK against the keeper's visible DEF
    -- (an empty keeper slot always scores).
    local function shotScores()
        if not attacker.card then return false end
        local k   = dPitch.keeper
        local atk = Combat.attackStat(attacker.card, attacker.slotType, oPitch, dPitch, { keeper = k })
        if not k then return true end
        return atk > Combat.keeperDef(k, dPitch, false, true)
    end

    -- Beat the man: an empty slot can't be covered, so going through it is a clean shot.
    if #empty > 0 and attacker.card and Resolver.uncoverable(attacker.card) and shotScores() then
        return { type = "defender", index = empty[1] }
    end

    if #winning > 0 then
        -- Attack the best candidate: wins sorted by lowest DEF (easiest to clear)
        table.sort(winning, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        return { type = winning[1].type, index = winning[1].index }
    end

    -- Through ball: past a full defence, straight at the keeper when the shot scores.
    if #empty == 0 and attacker.slotType == "striker" and Resolver.throughBall(oPitch)
       and shotScores() then
        return { type = "keeper", index = 0 }
    end

    -- No winning attack — advance through an empty slot instead
    if #empty > 0 then
        return { type = "defender", index = empty[1] }
    end

    -- All defender slots occupied and we'd lose every fight.
    -- Hard will still attack (force cover / trade resources); medium skips.
    if difficulty == "hard" and #defenders > 0 then
        table.sort(defenders, function(a, b)
            local ra, rb = OUTCOME_RANK[a.ev], OUTCOME_RANK[b.ev]
            if ra ~= rb then return ra < rb end
            return a.def < b.def
        end)
        return { type = defenders[1].type, index = defenders[1].index }
    end

    -- Every defender slot is filled, no fight is worth taking and no Through ball: no attack.
    return nil
end
```

- [ ] **Step 9: Strategy, damage estimate and Offside policy.**

In `AI._pickStrategy`, replace

```lua
                        local atk = Combat.getStat(best, "attack")
                                  + Combat.midfielderCardAtkBonus(player.pitch)
```

with

```lua
                        local atk = Combat.attackStat(best, "striker", player.pitch, opponent.pitch,
                                                      { keeper = keeper })
```

Replace the whole `function AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot) … end` with:

```lua
function AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot)
    local aPitch   = match.players[State.other(ownerId)].pitch
    local dPitch   = match.players[ownerId].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if not attacker then return 0 end
    local target = Phases._getSlot(dPitch, defenderSlot)
    if defenderSlot.type == "keeper" then
        local atk = Combat.attackStat(attacker, attackerSlot.type, aPitch, dPitch, { keeper = target })
        if not target then return atk end
        return math.max(0, atk - Combat.keeperEffectiveDef(target, dPitch))
    end
    if not target or target.mode == "defense" then return 0 end
    local atk = Combat.attackStat(attacker, attackerSlot.type, aPitch, dPitch)
    local def = Combat.defendStat(target, defenderSlot.type, dPitch)
    return math.max(0, atk - def)
end
```

Replace the whole `function AI.wantsOffside(match, ownerId, attackerSlot, defenderSlot) … end`, including its two comment lines above, with:

```lua
-- Should ownerId's Offside cancel this striker attack? Never against Aerial (it can't be
-- activated anyway). Yes when it would cost at least OFFSIDE_MIN_DAMAGE LP, or when it goes
-- into an empty slot the owner can't cover (a Beat the man attack can't be covered).
function AI.wantsOffside(match, ownerId, attackerSlot, defenderSlot)
    local aPitch   = match.players[State.other(ownerId)].pitch
    local attacker = Phases._getSlot(aPitch, attackerSlot)
    if Resolver.immuneToOffside(attacker) then return false end
    local dPitch = match.players[ownerId].pitch
    if defenderSlot.type ~= "striker" and not Phases._getSlot(dPitch, defenderSlot) then
        local canCover = not match.coverUsed[ownerId]
                         and #Phases._eligibleCoverers(dPitch, defenderSlot) > 0
                         and not Resolver.uncoverable(attacker)
        return not canCover
    end
    return AI.estimateAttackDamage(match, ownerId, attackerSlot, defenderSlot) >= AI.OFFSIDE_MIN_DAMAGE
end
```

- [ ] **Step 10: Run the tests, the syntax check and the smoke run**

Run: `luac -p ai/opponent.lua && lua tests/run.lua`
Expected: no `luac` output; `365 passed, 0 failed`.

Run: `lua tools/sim/sim.lua n=2 seed=1 | grep '^games='`
Expected: `games=18  stalls=0 …`.

- [ ] **Step 11: Commit**

```bash
ls luac.out
git add ai/opponent.lua tests/test_ai_abilities.lua
git commit -m "AI: ability-aware fights, shots, covers, Press summons and Offside policy" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **365**.

---

### Task 11: Simulator — trigger counts per keyword and each card's win rate when played (spec §5)

**Files:**
- Modify: `tools/sim/sim.lua`

- [ ] **Step 1: Header and arguments.**

Replace

```lua
--   lua tools/sim/sim.lua [n=1000] [seed=20260923] [diff=medium] [decks=a,b,c] [cap=60]
```

with

```lua
--   lua tools/sim/sim.lua [n=1000] [seed=20260923] [diff=medium] [decks=a,b,c] [cap=60] [cardmin=200]
```

Directly after the line `--     cap    safety cap: a half still running after this many rounds counts as a stall`, add:

```lua
--     cardmin  a card's win rate is flagged only with at least this many games played
```

Directly after the line `-- win rate 42–58%; 0 stalls; first-seat match win rate 45–55%.`, add:

```lua
-- Abilities (2026-09-24 spec §5): per-keyword trigger counts (ability_triggered events) and
-- each field card's win rate when played (a seat that summoned it at least once in the
-- match). A card outside 35–65% with at least `cardmin` games is flagged for the owner
-- (ABILITY REVIEW line); acceptance itself is unchanged.
```

Directly after the line `local CAP  = num("cap", 60)`, add:

```lua
local CARD_MIN = num("cardmin", 200)
```

Directly after the line `local Decks = require("data.presetDecks")`, add:

```lua
local Resolver = require("engine.cards.resolver")
```

- [ ] **Step 2: Counters.**

Directly after the line `    openGoals = 0, trapSet = {}, trapAct = {},`, add:

```lua
    kw = {}, cardGames = {}, cardWins = {},
```

In `record`, directly after the line `    local mc, sawExtra = { player = 0, opponent = 0 }, false`, add:

```lua
    local played = { player = {}, opponent = {} }   -- field card ids each seat summoned
```

Replace

```lua
        elseif e.type == "trap_activated" then
            inc(S.trapAct, p.trap)
        end
    end
```

with

```lua
        elseif e.type == "trap_activated" then
            inc(S.trapAct, p.trap)
        elseif e.type == "ability_triggered" then
            inc(S.kw, p.keyword)
        end
        if e.type == "card_played" and p.card and p.slot ~= "trap" and played[p.player] then
            played[p.player][p.card] = true
        end
    end
    for _, seat in ipairs({ "player", "opponent" }) do
        for id in pairs(played[seat]) do
            inc(S.cardGames, id)
            if w == seat then inc(S.cardWins, id) end
        end
    end
```

- [ ] **Step 3: Report.** Directly **above** the line `-- ── Acceptance (spec §6) ───…`, insert:

```lua
-- ── Abilities (2026-09-24 spec §5) ────────────────────────────────────────────

print("ability triggers:")
for _, kw in ipairs(Resolver.ORDER) do
    print(string.format("  %-14s %8d  (%.2f/match)", Resolver.NAMES[kw], S.kw[kw] or 0,
        avg(S.kw[kw] or 0, S.games)))
end
print(string.format("win rate when played (flagged outside 35-65%% with at least %d games):", CARD_MIN))
local flagged = 0
for _, f in ipairs({ "strikers", "midfielders", "defenders", "keepers" }) do
    for _, d in ipairs(require("engine.cards.definitions." .. f)) do
        local g, wn = S.cardGames[d.id] or 0, S.cardWins[d.id] or 0
        local rate  = pct(wn, g)
        local flag  = ""
        if g >= CARD_MIN and (rate > 65 or rate < 35) then
            flag = "  <-- REVIEW"
            flagged = flagged + 1
        end
        print(string.format("  %-22s %-14s %5.1f%%  (%d games)%s", d.name, d.keywordName or "-",
            rate, g, flag))
    end
end

```

Directly after the line `print("ACCEPTANCE: " .. (allPass and "PASS" or "FAIL"))`, add:

```lua
print("ABILITY REVIEW: " .. (flagged == 0 and "OK" or (flagged .. " card(s) outside 35-65%")))
```

- [ ] **Step 4: Smoke run**

Run: `luac -p tools/sim/sim.lua && lua tools/sim/sim.lua n=2 seed=1`
Expected:
- no `luac` output;
- `games=18  stalls=0 …`;
- an `ability triggers:` block with 24 lines, in `Resolver.ORDER`;
- a `win rate when played …` block with 24 lines;
- the last two lines are `ACCEPTANCE: FAIL` (only 18 games) and `ABILITY REVIEW: OK` (no card reaches 200 games);
- no Lua error.

Run: `git status --porcelain`
Expected: only ` M tools/sim/sim.lua`.

- [ ] **Step 5: Commit**

```bash
ls luac.out
git add tools/sim/sim.lua
git commit -m "Simulator: ability trigger counts and per-card win rate when played" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **365**.

---

### Task 12: `rules.md` — Abilities section (spec §5)

**Files:**
- Modify: `rules.md`

- [ ] **Step 1: Header.** Replace

```
This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update).
```

with

```
This is the game **as the code plays it** (engine V3 with the 2026-09-23 rules & balance update
and the 2026-09-24 card abilities).
```

- [ ] **Step 2: Turn structure.** Replace

```
2. **Summon** — place up to **2** field cards in attack or defense mode (1 if the opponent played
   Time Wasting); set trap cards (free, at most 2 on the field); flip your face-down cards to
   attack mode (free); play Substitution.
3. **Attack** — each of your cards may attack **once**; you may play **1** strategy card
   (Direct Free Kick, Penalty, Scout Report, Time Wasting).
```

with

```
2. **Summon** — place up to **2** field cards (+1 with **Metronome**) in attack or defense mode
   (1 if the opponent played Time Wasting); set trap cards (free, at most 2 on the field); flip
   your face-down cards to attack mode (free); play Substitution.
3. **Attack** — each of your cards may attack **once**, except a card summoned this turn: it
   attacks from your next turn (**Pace** excepted; this also applies to the Direct Free Kick and
   Penalty shooter). You may play **1** strategy card (Direct Free Kick, Penalty, Scout Report,
   Time Wasting).
```

- [ ] **Step 3: Stats and combat.**

Replace `A non-midfielder card in the midfielder slot gives no bonus.` with:

```
A non-midfielder card in the midfielder slot gives no bonus. **Engine** and **Overlap** change
this bonus (see **Abilities**).
```

Replace `Destroyed cards are gone for the rest of the match.` with:

```
Destroyed cards are gone for the rest of the match. Abilities can change these numbers and
results (for example **Immovable** on a tie); see **Abilities**.
```

Replace

```
**Exhaustion.** A card that attacked is exhausted until the end of its owner's turn, so each
card attacks once per turn. A card that **covered** cannot act on its owner's next turn.
```

with

```
**Exhaustion.** A card that attacked is exhausted until the end of its owner's turn, so each
card attacks once per turn. A card that **covered** cannot act on its owner's next turn (not a
**Sweeper** or an **Off the line** keeper). **Hard tackle** and **Punch clear** can also stop an
attacker acting on its owner's next turn.
```

- [ ] **Step 4: Targets and covering.**

Replace

```
| Striker | Any opponent defender slot (empty or not); the midfielder slot when the opponent has no defenders; the keeper slot when at least one opponent defender slot is empty |
```

with

```
| Striker | Any opponent defender slot (empty or not); the midfielder slot when the opponent has no defenders; the keeper slot when at least one opponent defender slot is empty (or once per turn with **Through ball**) |
```

Replace

```
- the coverer must be in attack mode, not exhausted, and not blocked by an earlier cover.
```

with

```
- the coverer must be in attack mode, not exhausted, and not blocked by an earlier cover.
- **Intercept**, **Sweeper** and **Off the line** add cover options; a **Beat the man** attack
  can't be covered.
```

Replace

```
A cover is a normal fight against the coverer. The coverer cannot act on its owner's next turn.
```

with

```
A cover is a normal fight against the coverer. The coverer cannot act on its owner's next turn
(not a Sweeper or an Off the line keeper).
```

- [ ] **Step 5: Shots and keeper.**

Replace

```
- **Every attack that reaches the keeper is a shot.** The keeper is **never destroyed**.
```

with

```
- **Every attack that reaches the keeper is a shot.** A shot never destroys the keeper (only a
  lost **Off the line** cover fight can).
```

Replace `The shooter is exhausted either way.` with:

```
The shooter is exhausted either way. Shot abilities: **Clinical**, **Instinct**, **Opportunist**,
**Punch clear**, **Safe hands**, **Fortress** (see **Abilities**).
```

Replace

```
Any card in those slots counts, in either mode. A card that **attacked** stops counting from its
attack until the **start of your next turn** (so it is missing during the opponent's turn).
```

with

```
Any card in those slots counts, in either mode. A card that **attacked** stops counting from its
attack until the **start of your next turn** (so it is missing during the opponent's turn).
**Bolt** counts +500 instead of +300; **Safe hands** adds up to +300.
```

- [ ] **Step 6: Midfield control and Offside.**

Replace

```
revealed, whatever its type), and the match shows **"MIDFIELD CONTROL +1 CARD"**.
```

with

```
revealed, whatever its type), and the match shows **"MIDFIELD CONTROL +1 CARD"**. With
**Metronome** in your midfielder slot you also get **+1 summon** that turn.
```

Replace

```
is cancelled; the attacker is exhausted but not destroyed.
```

with

```
is cancelled; the attacker is exhausted but not destroyed. Not against an **Aerial** card.
Cancelling an attack on **The Destroyer** also triggers **Hard tackle**.
```

- [ ] **Step 7: Abilities section.** Directly **above** the line `## Winning`, insert:

````markdown
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
| Creative Playmaker | **Through ball** | While it is on your pitch, once per turn one of your striker-slot cards may shoot at the keeper slot even when both enemy defender slots are filled (a normal shot vs effective DEF). |
| Direct Support | **Overlap** | In your midfielder slot in attack mode, your striker-slot cards get **+300 ATK** instead of +200. |

### Defenders

| Card | Ability | Rule |
|---|---|---|
| The Rock | **Immovable** | On a tie (attacking or defending) The Rock survives; only the other card is destroyed. |
| The Stopper | **Last man** | **+300 DEF** while it is your only card in the defender slots. |
| Catenaccio Anchor | **Bolt** | Counts **+500** (instead of +300) toward your keeper's effective DEF. |
| The Destroyer | **Hard tackle** | A card that attacks The Destroyer and is not destroyed (it won, survived a tie with Immovable, or Offside cancelled the attack) can't act on its owner's next turn. |
| Pressing Back | **Intercept** | May also cover an empty **defender** slot (normal cover rules). |
| Ball-Playing Defender | **Build-up** | When it wins a fight (destroys the other card and survives), you draw 1 card. |
| Libero | **Sweeper** | May cover an empty defender or midfielder slot; covering doesn't stop it acting next turn. |

### Keepers

| Card | Ability | Rule |
|---|---|---|
| The Wall | **Fortress** | Penalties face its full effective DEF instead of its base DEF. |
| Iron Fists | **Punch clear** | After it saves a shot, the shooter can't act on its owner's next turn. |
| Sweeper Keeper | **Off the line** | May cover an empty defender slot (your one cover this turn) in either mode, fighting with its own DEF (no line bonuses). It isn't locked by covering and stays in goal. If it loses the cover fight it is destroyed like any coverer. |
| Reliable Hands | **Safe hands** | **+100 DEF** for each save it made this half (max +300), Penalties included. |

---

````

- [ ] **Step 8: Not implemented.** Delete the line

```
- Card abilities — every field card's ability text is flavour only.
```

- [ ] **Step 9: Card reference.** Replace the four field-card tables (from the line `**Strikers**` down to the last row `| Reliable Hands | Common | 300 | 1750 |`) with:

```
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
```

- [ ] **Step 10: Check and commit**

Run: `grep -c "Abilities" rules.md && grep -n "flavour only" rules.md`
Expected: a count of at least 5; no `flavour only` line.

```bash
git add rules.md
git commit -m "rules.md: Abilities section and cross-references" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Cumulative tests: **365**.

---

### Task 13: Acceptance run (spec §5)

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

- [ ] **Step 2: If any line reads `FAIL`, or `ABILITY REVIEW` is not `OK`: STOP.**
  1. Report the **full** simulator output to the user, in particular:
     - the deck win rates and the first-seat rate;
     - the stall count;
     - the `ability triggers` block;
     - every `<-- REVIEW` row (card, keyword, win rate, games).
  2. Propose tweaks for the owner **without applying any of them**. For each proposal, name the constant and the value. Examples:
     - a card above 65%: step its `C.ABILITY` number down one notch (e.g. `OPPORTUNIST_ATK` 400 → 300);
     - a card below 35%: step it up one notch;
     - first-seat or deck-rate drift caused by D1: `C.MATCH.SUMMONED_CAN_ATTACK = true` (that also makes Pace do nothing, so it needs the owner's ruling).
  3. **Do not** change any card stat, `C.ABILITY` value, deck list, constant or AI threshold, and do not run what-if variants from a modified tree. Tuning needs the owner's approval.
  4. A non-zero stall count points to a correctness bug (a loop), not balance. Report it the same way and do not fix it without approval.
  5. Continue to Task 14 only after the user says how to proceed.

Nothing to commit. Cumulative tests: **365**.

---

### Task 14: Final check

**Files:** none (verification only)

- [ ] **Step 1: Unit tests**

Run: `lua tests/run.lua`
Expected: `365 passed, 0 failed`

- [ ] **Step 2: Syntax of every changed LÖVE file, and no `luac.out`**

Run: `luac -p engine/*.lua engine/cards/*.lua engine/cards/definitions/*.lua store/match.lua ai/opponent.lua scenes/match.lua ui/card.lua ui/theme.lua ui/match/*.lua ui/overlay/*.lua tools/snapshot/*.lua tools/sim/sim.lua && ls luac.out`
Expected: no `luac` output, then `ls: luac.out: No such file or directory`.

- [ ] **Step 3: Every scenario runs clean**

Run: `for s in home library match cards summon juice debug pause combat trap cover trapwin scout halftime victory defeat revealed midfield keywords abilities; do tools/snapshot/snap.sh $s || echo "FAILED $s"; done`
Expected: every scenario lists its PNGs; no `FAILED` line; no Lua traceback on stderr.

- [ ] **Step 4: Review the PNGs** with the Read tool:
  - **Tasks 5, 7 and 9 checklists:** `summon_attack`, `cover_panel`, `keywords_gallery`, every `abilities_*`, `cards_gallery`, `library_grid`, `library_hover`, `home_deck`, `combat_count`.
  - **Every other scenario:** it still matches its earlier checklist, with keyword pills now on field cards and no pill on a trap, strategy or card back.

- [ ] **Step 5: Simulator acceptance**

Run: `lua tools/sim/sim.lua n=1000 seed=20260923 diff=medium`
Expected: the last two lines are `ACCEPTANCE: PASS` and `ABILITY REVIEW: OK`, or the owner-approved outcome from Task 13.

Run: `git status --porcelain`
Expected: no output.

- [ ] **Step 6: Only the expected areas changed**

Run: `git diff --name-only d4191e0 -- . ':(exclude)docs'`
Expected exactly:

```
ai/opponent.lua
engine/cards/definitions/defenders.lua
engine/cards/definitions/keepers.lua
engine/cards/definitions/midfielders.lua
engine/cards/definitions/strikers.lua
engine/cards/resolver.lua
engine/combat.lua
engine/constants.lua
engine/phases.lua
engine/state.lua
rules.md
scenes/match.lua
store/match.lua
tests/helpers.lua
tests/test_abilities_attack.lua
tests/test_abilities_cover.lua
tests/test_abilities_data.lua
tests/test_abilities_fight.lua
tests/test_abilities_rules.lua
tests/test_abilities_shots.lua
tests/test_abilities_turn.lua
tests/test_abilities_ui.lua
tests/test_ability_toasts.lua
tests/test_ai_abilities.lua
tests/test_resolver.lua
tools/sim/sim.lua
tools/snapshot/card_gallery.lua
tools/snapshot/scenarios.lua
ui/card.lua
ui/match/stats.lua
ui/match/toasts.lua
ui/match/zoom.lua
ui/overlay/combat.lua
ui/overlay/combatfx.lua
ui/overlay/prompts.lua
ui/theme.lua
```

Run: `git diff --stat d4191e0 -- . ':(exclude)docs' | tail -1`
Expected: `36 files changed, …`

- [ ] **Step 7: Report to the user.**
  - **What changed:** summarize per spec section (§1 data, §2 engine, §3 UI, §4 AI, §5 simulator and docs).
  - **Simulator:** paste the deck win rates, the acceptance block, the ability-trigger block and the win-rate-when-played block.
  - **Screenshots:** show `keywords_gallery`, `abilities_board`, `abilities_tags`, `abilities_punch` and `abilities_toasts`.
  - **Owner decisions:** restate D1 (summoned cards attack next turn, behind `C.MATCH.SUMMONED_CAN_ATTACK`), D2 (the `recoverPitch` fix) and D3 (Off the line), plus the clarifications from this plan's header.
  - **Found but not fixed:** the human can summon a keeper face-up; the debug log shows AI card names.

  Tell the user an **interactive play-test is required**, because the harness can't do it. They should play at least one full match with each deck and check:
  - **Pills and text:**
    - every field card in hand, on the pitch, in the library and in the deck-select fans shows its pill;
    - zoom shows the keyword heading and the rules text.
  - **Summoning (D1):** a freshly summoned card can't be selected to attack (flash banner). Speed Demon can.
  - **Offside:** Target Man is never caught offside, and your Offside prompt never opens against the AI's Target Man.
  - **Covering:**
    - Pacy Winger's attacks into empty slots skip the cover prompt;
    - your Pressing Back / Libero / Sweeper Keeper appear as cover options;
    - Libero and Sweeper Keeper can act next turn after covering.
  - **Through ball:** with Creative Playmaker on your pitch, the keeper slot glows once per turn even behind two defenders.
  - **Summon effects:**
    - Pressing Forward exhausts an AI defender (`zzz`) for your turn only;
    - Deep-Lying Playmaker in control shows SUMMONS `/ 3`.
  - **Fight and shot results:**
    - The Rock survives ties;
    - The Destroyer / Iron Fists stop an attacker the next turn (zoom: "Cannot act next turn");
    - Ball-Playing Defender draws on a win;
    - Clinical Finisher scores 300 on a tie.
  - **Combat overlay:** it shows yellow tags (Link-up, Overlap, Engine, Last man, Bolt, Instinct, Opportunist, Counter-press, Safe hands, Fortress) and a rule-ability pill.
  - **Toasts:**
    - toasts appear for the rule abilities;
    - the AI's face-down cards are never named in toasts;
    - the pitch badges of AI cards don't include bonuses from its face-down cards.

---

## Self-review

### Spec coverage — the 24 abilities

| Card | Keyword | Implemented (task: code) | Tests (trigger / non-trigger) |
|---|---|---|---|
| Clinical Finisher | CLINICAL | 4: `R.clinical`, `Combat.resolveShot`, `R.onShotResolved` | 4: ties → 300 / plain tie |
| The Target Man | AERIAL | 5: `R.immuneToOffside`, store Offside branches; 10: `AI.wantsOffside` | 5: AI Offside skipped, no human window / normal striker offside; 10: policy |
| Speed Demon | PACE | 5: `summonedThisTurn`, `Phases.canAttackNow`, trigger in `Phases.attack`, AI `ready`, scene | 5: attacks at once / other fresh card refused, defense mode refused; AI Pace |
| Complete Forward | LINK_UP | 2: `R.atkBonus` | 2: +150 / itself nothing; snapshot; badges |
| Fox in the Box | INSTINCT | 3: `R.atkBonus` (shot) | 3: exhausted keeper / fresh keeper |
| The Poacher | OPPORTUNIST | 3: `R.atkBonus`, `R.hasEmptyDefenderSlot` | 3: gap / full line (DFK) |
| Pressing Forward | PRESS | 6: `R.pressTarget`, `R.onSummon`, `Phases._clearPressed`; 10: summon priority | 6: highest face-up + can't cover + recovers, face-down fallback / no defenders; 10 |
| Pacy Winger | BEAT_THE_MAN | 5: `_handleEmpty`, store snapshot target; 10: targeting, `wantsOffside` | 5: uncovered / plain covered; 10 |
| Box-to-Box | ENGINE | 2: `R.midfieldAtkBonus` / `R.midfieldDefBonus` | 2: +100/+100 face-down / plain mode bonus |
| Deep-Lying Playmaker | METRONOME | 6: `R.onMidfieldControl`, summon limit, `bonusSummons`, `Stats.summons`, AI limit | 6: +1 summon, limit, reset / plain midfielder |
| Pressing Monster | COUNTER_PRESS | 2: `R.defBonus` (covering); 10: `decideCover` | 2: cover +300 / direct attack; 10 |
| Creative Playmaker | THROUGH_BALL | 5: `R.throughBall`, `_throughBallFor`, validate/attack, reset, scene; 10: AI | 5: shot past full line, once per turn / without it; 10 |
| Direct Support | OVERLAP | 2: `R.midfieldAtkBonus` | 2: +300 / defense mode |
| The Rock | IMMOVABLE | 4: `R.survivesTie`, `_doCombat` tie | 4: defending, attacking / plain tie |
| The Stopper | LAST_MAN | 2: `R.defBonus`; 10: AI fight estimate | 2: alone / with partner; badges; 10 |
| Catenaccio Anchor | BOLT | 3: `R.keeperLineBonus`, `Combat.keeperDef` | 3: +500 / after attacking |
| The Destroyer | HARD_TACKLE | 4: `R.onFightResolved`, `R.onAttackCancelled`, `Phases.cancelAttack`, lock in `recoverPitch` | 4: beaten → locked next turn, Offside → locked / attacker loses |
| Pressing Back | INTERCEPT | 7: `R.canCoverSlot`, `_eligibleCoverers`, `R.coverKeyword` | 7: covers + locked / plain defender can't |
| Ball-Playing Defender | BUILD_UP | 4: `R.onFightResolved` | 4: defending, attacking / tie |
| Libero | SWEEPER | 7: `R.canCoverSlot`, `R.coverLocks` | 7: defender slot, midfielder slot unlocked / plain locked |
| The Wall | FORTRESS | 3: `R.penaltyFullDef`, `Combat.keeperDef` | 3: Penalty full DEF / base DEF |
| Iron Fists | PUNCH_CLEAR | 4: `R.onShotResolved` | 4: save → locked / goal free |
| Sweeper Keeper | OFF_THE_LINE | 7: `R.canCoverSlot`, `R.coverLocks`, keeper coverer; 10: keeper cover only when it wins | 7: covers + stays ready, loses → destroyed / plain keeper; 10 |
| Reliable Hands | SAFE_HANDS | 3: `R.keeperOwnBonus`, `keeper.saves` | 3: +200 and counts / first save, cap +300 |

### Spec coverage — sections

| Spec item | Task |
|---|---|
| §1 `keyword`, `keywordName`, rewritten `abilityText`; `ability` reserved for traps/strategies | 1 |
| §1 clarifications: hidden passives apply, visibility is a UI concern | 2 (`visibleOnly`, `Card.bonuses`), 2 (snapshot tag filter), 8 (unnamed toasts), 10 (visible AI estimates) |
| §1 bonuses stack additively | 2, 3 (`R.atkBonus` / `R.defBonus` / `Combat.keeperDef` sums) |
| §1 Destroyer simplified rule (beaten, Offside) | 4 |
| §1 `ability_triggered { player, card, keyword }` | 1 (`R.trigger`, plus `name`, `hidden`, extras) |
| §2 resolver rewritten as the single keyword module, dead v2 code removed | 1–7 |
| §2 hook names fixed and unit-tested | Hook map above; Tasks 1–7 tests |
| §2 combat / keeper / cover / midfield code calls hooks, no hard-coded numbers | 2–7 (`C.ABILITY`) |
| §3 keyword pill at every size, never over badges or ribbon | 9 (`L.kw`, layout test, `keywords` gallery) |
| §3 zoom / info sticker shows the rules text | 9 (`Card.drawInfo` heading, `Zoom.partsText`) |
| §3 toasts on triggers | 8 |
| §3 combat overlay bonus tags where stats changed | 2 (snapshot numbers and tags), 9 (`Fx.bonusTags`, tag row, ability pill) |
| §3 library just shows the keywords | 9 (pill in `Card.drawFace`) |
| §4 Pace, Aerial, Beat the man, Through ball, Press, cover abilities, stat bonuses in estimates | 5, 10 |
| §4 never plans a refused action (refused-attack guard kept) | 5 (`ready` uses `canAttackNow`), 10 (`isLegalTarget` with Through ball) |
| §5 unit tests per ability (trigger and non-trigger) on the real engine | 2–7, 10 |
| §5 snapshot: gallery row with pills; `abilities` scenario with toast and tags | 9 |
| §5 simulator: per-keyword triggers, per-card win rate when played | 11 |
| §5 acceptance unchanged; > 65% / < 35% → report, no tuning | 11 (flag), 13 (STOP) |
| §5 rules.md Abilities section | 12 |
| §6 out of scope (lanes, fouls, stamina, new cards) | not touched |

### Placeholder scan

Every code step has complete code, and every edit names the exact old text and gives the full new text. There is no "TBD", "similar to" or "add appropriate …". Where a function grows over several tasks (`R.atkBonus`, `Combat.keeperDef`, `Combat.resolveShot`), the later task replaces the whole function.

### Name and signature consistency

| Name | Signature | Defined | Used |
|---|---|---|---|
| `R.trigger` | `(matchState, ownerId, pitched, keyword, extra, result)` | 1 | 1–7 |
| `R.logParts` | `(matchState, ownerId, parts, result)` | 1 | 2 (`_doCombat`, `_goalAttempt`) |
| `R.part` | `(amount, pitched, keyword)` | 1 | 2, 3 |
| `R.fieldCards` | `(pitch)` → `{ card, slotType, index }` | 1 | 2, 5 |
| `R.atkBonus` / `R.defBonus` | `(pitched, ctx)` → total, parts | 2 (3 replaces `atkBonus`) | `Combat.attackStat` / `defendStat` |
| `R.midfieldAtkBonus` / `R.midfieldDefBonus` | `(pitch, visibleOnly)` → amount, part | 2 | Combat |
| `R.keeperLineBonus` / `R.keeperOwnBonus` / `R.penaltyFullDef` | `(pitched, visibleOnly)` / `(keeper)` / `(keeper)` | 3 | `Combat.keeperDef` |
| `R.clinical` / `R.survivesTie` | `(pitched)` → bool | 4 | combat, phases |
| `R.onShotResolved` | `(matchState, shooterId, shooter, keeper, result)` | 4 | `_goalAttempt` |
| `R.onFightResolved` | `(matchState, { attackerId, defenderId, attacker, defender, result })` | 4 | `_doCombat` |
| `R.onAttackCancelled` | `(matchState, attackerId, attacker, target)` | 4 | `Phases.cancelAttack` |
| `R.canAttackWhenSummoned` / `R.throughBall` / `R.immuneToOffside` / `R.uncoverable` | `(pitched)` / `(pitch)` → card or nil / `(pitched)` / `(pitched)` | 5 | phases, store, AI, scene, zoom |
| `R.pressTarget` / `R.onSummon` / `R.onMidfieldControl` | `(oppPitch)` / `(matchState, ownerId, pitched)` / `(matchState, playerId)` | 6 | phases |
| `R.canCoverSlot` / `R.coverLocks` / `R.coverKeyword` | `(pitched, fromSlotType, emptySlotType)` / `(pitched)` / `(pitched, from, empty)` | 7 | phases, AI |
| `Combat.attackStat` | `(attacker, slotType, ownPitch, oppPitch, shot, visibleOnly)` → total, parts | 2 | combat, phases, store, card, AI |
| `Combat.defendStat` | `(defender, slotType, ownPitch, covering, visibleOnly)` → total, parts | 2 | combat, store, card, AI |
| `Combat.keeperDef` | `(keeper, pitch, penaltyMode, visibleOnly)` → total, parts | 2 (3 replaces it) | combat, store, card, AI |
| `Combat.resolve` | `(…, atkPitch, defPitch, opts)`, where `opts.covering` | 2 | `_doCombat` |
| `Phases.cancelAttack` | `(matchState, attackerId, attackerSlot, defenderSlot)` | 4 | store (three Offside paths) |
| `Phases.canAttackNow` | `(card)` → bool | 5 | phases, AI, scene |
| `Phases._throughBallFor` | `(matchState, attackerSlot, defenderSlot)` → card or nil | 5 | `validateAttack`, `attack` |
| `Phases._clearPressed` | `(pitch)` | 6 | `endTurn` |
| `Store:_snapshotAttack` | `(attackerSlot, defenderSlot, opts)`, where opts is `{ covering, fight, penalty }` | 2 | `declareAttack`, `resolveCover`, `playStrategy`, tests |
| `Card.bonuses` | `(pitched, pitch, hideHidden)` → atk, def, atkParts, defParts | 2 | pitch, zoom |
| `Card.keywordLabel` | `(cardDef)` → string or nil | 9 | `drawFace`, `infoHeight`, `drawInfo` |
| `Zoom.partsText` | `(parts)` → string | 9 | `statusLines` |
| `Fx.tagText` / `Fx.bonusTags` / `Fx.abilityLine` | `(tag)` / `(snap, "atk" or "def")` / `(rec)` | 9 | `cardView`, combat overlay |
| `AI.isLegalTarget` | `(ePitch, attackerType, target, ownPitch)` | 10 | `_planNextAttack` |
| `H.kw` / `H.triggers` | `(keyword, ctype, atk, def)` / `(m)` | 1 | tests |

- **State fields:**
  - `pitched.lockedNextTurn` is set in Task 4 and consumed by `recoverPitch`;
  - `pitched.saves` (3), `pitched.pressed` (6), `pitch.throughBallUsed` (5), `matchState.bonusSummons` (6).
- **Combat record fields:** `abilities` (2); snapshot `atkTags` / `defTags` (2).
- **Simulator inputs:** the simulator reads `ability_triggered.keyword` and `card_played.card` / `.player` / `.slot` (11).

### Critical Files for Implementation
- /Users/mac/Documents/football-tcg-lua/engine/cards/resolver.lua
- /Users/mac/Documents/football-tcg-lua/engine/phases.lua
- /Users/mac/Documents/football-tcg-lua/engine/combat.lua
- /Users/mac/Documents/football-tcg-lua/store/match.lua
- /Users/mac/Documents/football-tcg-lua/ai/opponent.lua
