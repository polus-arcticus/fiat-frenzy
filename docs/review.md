# Code review (2026-11-18)

A review of the whole codebase, about 25,000 lines:
- the engine: `sim/`, 3,900;
- features: 8,400;
- `control/` and `view/`: 4,000;
- tests: 5,500;
- tools: 3,300.

Each finding says what is wrong, where, and the fix, by the phase of the plan that makes it:
- **phase 2** moves the code into four spaces without changing behaviour;
- **phase 3** is the unified asset mechanic.

## What holds up well

- **The model is headless and deterministic.**
  - It never touches a node, and rolls only the world's dice; `test_architecture` checks both.
  - Saves and merges rest on it.
  - Keep it.
- **Money has one invariant** (`total_money == printed`), and almost every test that moves money checks it. It has caught every
  leak so far.
- **Each fact is defined once.** The Catalog is data, systems are rules, and per-class `MERGE` tables state how saves combine.
- **Zones and the summary** let hundreds of NPCs exist cheaply.
- **The benches** (`bench_economy`, `epoch`) found real faults that the unit tests could not see: the price ratchet, thin supply,
  the bed in the wall margin.

## Status after phase 2 (2026-11-18)

The four spaces are in place and enforced (`test_no_space_reaches_up`). The benches give byte-identical output before and after.

| finding | status |
|---|---|
| 1. `World` holds the story | **Done for the cast**: `World.cast` is the story's `Cast`, and its builders moved with it. `gun_owned`, `bike`, `bus` and `shuttle` are still on `World` (they are saved as world fields and singles); they move when the hero gets its own state. |
| 2. `Drone` carries every role | Deferred to phase 3, with the residential asset, since both change what a save holds. |
| 3. `Machine` is two assets | Phase 3. |
| 4. The engine reaches up | **Done** (after phase 2). `World.new(false)` is the engine alone, and the benches run on it with byte-identical output. These moved up into user space: the hero's tick (`Hero.step`, which sets `Zones.focus`), the mugging (through `Rescue.on_admitted`), the hero's experience (`Gun.credit_hero`), picking up cash and sitting by a tent (`Commerce`), and heating's bus (now a list of `vehicles`). Funding a cluster is `Levels.give`. What is left: people talk to the hero (`Chatter`, which does nothing without one) and the hero can collapse like anyone (`Rescue`). |
| 5. Tables kept twice | **Done.** `World.SAVED` is the one list of saved systems. Merge finds each one's class from a world and merges by its `MERGE` table. The gun's `MERGE` (a radius) is now `PILE_RADIUS`. `Snapshot.DERIVED` still names fields as strings. |
| 6. `Scenario` does four jobs | **In part.** The map geometry is in `engine/map`, the jam planner takes the street's name, and the set-piece views are in `StoryViews`. The first market is still laid out by hand, not by `Cluster`. |
| 7. Slow tests | **Done, but for a `bench` tier.** The run is about 11 s. The map is parsed once per test process (`Fixtures.district()`, `Fixtures.scenario()`). `Fixtures.town` and `basic_gun_days` (global dice) are gone; their tests use the standard cluster. |
| 8. `tools/` | **In part.** Seven one-off probes deleted (story dice, full against summary, the bankers twice, the tent, the grid's edge, the cost of landing a bill). `CaptureTool` is the shared base for captures; the tent and trades captures use it, and the other 33 move onto it as they are touched. |
| 9. Dead code | **The spawner is gone**: `Spawner`, `MapBlocks`, their test and tools, and the zones' `outlying`, `sites` and `focus`. The bus and shuttle builders moved from `World` to `Transit`. The lodging's bed-cap parts go in phase 3. |
| 10. Global dice in `Scenario` | **Done.** The scenario has its own dice. The story's five rolled people (Edda, Karl and the bank's three visitors) now stand a little differently and carry different pocket money: the old rolls depended on hidden use of the global dice. |
| 11. The README | Done. |

## Findings

### 1. `World` is a god object holding story and hero state (phase 2)
`sim/world.gd` (480 lines) holds several kinds of state that aren't the engine's:
- story cast fields: `sage_drone`, `ecb_doorman`, `ecb_receptionist`, `ecb_technician`, `ecb_lift`;
- story places: `bus_stop`, `bus`, `shuttle`;
- hero state: `gun_owned`, `bike`;
- builders for the scripted cast: `add_sage`, `add_doorman`, `add_receptionist`, `add_technician`.

They are read from `features/story`, `sage`, `hero` and `control`, so the engine "knows" the plot.

**Fix:**
- A cast registry, `world.cast` (name to uid), filled and read by `story/`.
- Hero state (`gun_owned`, `bike`) on `Hero`.
- The cast builders move to `story/`.

### 2. `Drone` carries every role (phase 2)
`sim/entities/drone.gd` mixes fields for every role:
- the agent: needs, wallet, position, job;
- a runner: `cart`, `home`, `delivered_total`, `fees_earned`;
- a vendor: `stand`; a keeper: `bank`;
- the hero: `care_rate`, `wake_at`;
- chatter: `speech`, `speech_ttl`, `speech_seq`, `chat_cooldown`, `event_cooldown`;
- story: `aura`, `aloof`, `face_to`;
- lodging: `bed`, `gone`.

Every role's state is saved and merged on everyone.

**Fix:** `Drone` keeps the agent's fields plus `home` and `work` (asset uids). Role state becomes small components held in an
optional dictionary (`roles`), each with its own `MERGE` table: `Runner`, `Speech`, `Care`.

### 3. `Machine` is two kinds of asset (phase 3)
The residential tent is a `Machine` with a `Shelter`, so `offers`, `refresh`, `solid` and `set_level` each branch on
`shelter != null`. `beds`, `wing`, `modules()` and `bed_pos()` sit on every machine.

**Fix:** a `Residence` asset (own tent, tiers by scrap) beside the commercial `Machine`, both on `Premises`. This also fits the new
design, a tent per agent.

### 4. The engine reaches up into user space (phase 2)
These engine files are hero logic:
- `sim/systems/commerce.gd` is the hero buying and eating;
- `Levels.credit_player`;
- `Cash.collect_for_player` and `scoop_aboard`;
- `Zones.is_active` reads `player.zone`.

**Fix:**
- Commerce, the hero's levels and the hero's cash go to `user/`.
- Zones is told the hero's zone (`zones.hero_zone`) instead of reading it.
- The engine treats the hero as an agent with a pocket.

### 5. The same tables are kept in several places (phase 2)
These lists must be kept in step by hand:
- `Snapshot.SYSTEMS` (system names);
- `Merge.SYSTEM_CLASSES`;
- `World._end_of_tick`;
- `Snapshot.LISTS` and `SINGLES`;
- `Snapshot.DERIVED`, field names as strings.

Adding `trades`, `spawner` and `lodging` this week meant editing four places each time.

**Fix:** each system declares `const SAVED := true`, `const TICKS := true` and its `MERGE`. The world's list of systems is the one
registry that Snapshot and Merge read. Derived fields are marked by a leading underscore (most already are), not listed by name.

### 6. `Scenario` mixes four jobs (phase 2)
`control/town/scenario.gd` (470 lines) does all of these:
- street geometry (`_spot`, frames);
- the first market's layout (a hand-made copy of what `Cluster` now does);
- the story cast and places (shops, the sage, the ECB, the lift);
- blocks.

**Fix:**
- The geometry (`MapSites`, `MapBlocks`) goes to `engine/map/`.
- The first market is built by `Cluster` on a street site, like any other.
- The cast and places go to `story/town/`.

### 7. Tests are slow, and some depend on the story (done in part)
- **Done:** the whole run went from about 42 s to 11 s (`--fixed-fps`, 4 sim shards, a 120 s timeout instead of hangs).
- **Still slow:** `trades` (5.8 s, a 120-day season), `merge` (5.3 s), `saves` (4.7 s, the Frankfurt scenario parsed and built
  several times).
  - Fix: a cached district loader, so JSON is parsed once per process.
  - Fix: the season and other long balance runs become a `bench` tier, which `tools/test.sh bench` runs on request.
- **Engine tests that use the story:** `test_ecb_market`, `test_saves`. These are story tests and should live with the story.
- **Global dice in tests:** `Fixtures.town` and `hungry_crowd` use `randf_range`. They're only deterministic because the runner
  reseeds before each test. That's fine, but it should say so.

### 8. `tools/` is a drawer (after phase 2)
57 scripts: 32 captures, 15 probes, 4 benches and the rest. Each capture repeats the same `_initialize`, `_shot` and look-at
code.

**Fix:**
- `tools/capture/` with a shared `CaptureKit` (open the game, stand here looking there, shoot).
- `tools/probes/` for the one-off probes. Obsolete ones are deleted after the user agrees: `probe_bankers`, `probe_real_bankers`,
  `probe_land_cost`, `probe_edge`.
- `tools/bench/` for the benches.

### 9. Dead or switched-off code (phase 3)
- `Spawner` and `MapBlocks` are tested, but not called in Frankfurt. Keep them in the engine; they're switched on by a scenario
  flag.
- `Lodging.remove_bed` and the screen's "take a bed away": the user doesn't want a way to make people leave. Remove it.
- `Fixtures.market_town` only wraps `Cluster.build`. Replace its callers.
- The open fire and the tent's barrels both warm. Once every agent has a tent, decide whether the street fire stays (it's the
  homeless camps' heat).

### 10. Global dice in `Scenario` (phase 2)
`Scenario.build` calls `seed(1133)` and rolls the first drifters with the global `randf_range`. It works, because it runs once
per build, but it is the one place outside the model that relies on global dice for world state.

**Fix:** use the world's seeding dice (`w.random()`).

### 11. `README.md` was 690 lines (done)
It was history, measurements and reference in one file. Now the README is short, and the rest is split:
- `docs/ENGINE.md`: the rules;
- `docs/balance.md`: the numbers;
- `docs/story.md`, `docs/player.md`, `docs/coop.md`;
- `docs/upgrade_trees.md`.

## The four spaces (the target of phase 2)

| space | holds | may use |
|---|---|---|
| `engine/` (simulation) | World, the Catalog and data types, assets, ledger, clock, zones, navigation, walking, summary, borders, the economy (trades, welfare, relief, lodging), clusters, snapshot and merge, map geometry, the views of assets | nothing above it |
| `npc/` | what agents decide and do: needs and demands, logistics, supply, queueing, hauling, chatter, rescue, loose cash; drone views | `engine/` |
| `user/` | the hero, gun, commerce, riding, skating, transit boarding, portals, inspector, saves, HUD, screens, `GameController` | `engine/`, `npc/` |
| `story/` | scenario and places, quests, tutorial, intro, dev stages, the sage, the ECB, the bankers, dialogue, the cast registry | anything |

`test_architecture` maps every `class_name` to its space and fails on a reference upward.
