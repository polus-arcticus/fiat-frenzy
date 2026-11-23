# Code review (2026-11-23)

The whole codebase is about 34,000 lines: the four spaces 22,000, tests and tools the rest. The core mechanics are in place;
what comes next is story and gameplay. This is what holds up, how the code is split, and what is still open. (The first review,
2026-11-18, and the work it led to are in the git history.)

## What holds up well

- **The model is headless and deterministic.** It never touches a node, and rolls only the world's dice; `test_architecture`
  checks both. Saves and merges rest on it.
- **Money has one invariant** (`total_money == printed`), and almost every test that moves money checks it. It has caught every
  leak so far.
- **Each fact is defined once.** The Catalog is data (and `WasteBin.KINDS` the bins'), systems are rules, and per-class `MERGE`
  tables state how saves combine. `World.SAVED` is the one list of saved systems.
- **The engine runs on its own** (`World.new(false)`): the benches, a map of anywhere and the epoch sim run without the hero or
  the story.
- **Zones and the summary** let hundreds of NPCs exist cheaply.
- **The benches** found what unit tests could not: the price ratchet, the fund that filled while the town went broke, runners
  setting out on trips they could not last.
- **Little dead code.** A scan of every function, constant and class (2026-11-23) found four unused definitions, now removed;
  every class is used by the game but `Merge`, which waits for co-op (`docs/coop.md`).

## The four spaces

| space | holds | may use |
|---|---|---|
| `engine/` (simulation) | World, the Catalog and data types, assets, ledger, clock, zones, navigation, walking, summary, the economy (trades, the bins, the deposit, relief, lodging, salvage), clusters and the atom, snapshot and merge, map geometry and the map's frames, the views of assets and the city | nothing above it |
| `npc/` | what agents decide and do: needs and demands, logistics, supply, queueing, hauling, collecting, borders, chatter, rescue, loose cash; drone views | `engine/` |
| `user/` | the hero, gun, commerce, riding, skating, transit, portals, inspector, landing on a tile, saves, HUD, screens, `GameController` | `engine/`, `npc/` |
| `story/` | scenario and places, quests, tutorial, intro, dev stages, the sage, the ECB, dialogue, the cast registry | anything |

`test_architecture` maps every `class_name` to its space and fails on a reference upward. Two composition roots may name every
space: `engine/world.gd` and `user/control/game_controller.gd`.

## Done (2026-11-23)

- **Role components.** A cart runner's business is a `Runner` (`Drone.runner`: cart, deliveries, fees, the heroes' stakes),
  null on everyone else; what people said is the chatter's (`Chatter.of`, a `Speech`), not saved at all. A tent city's homes are
  a `Residence` (`Machine.residence`: the row, its tents and their `Shelter`, `bed_pos`, the footprint), null on every stall;
  `Machine.shelter` is a read-only view of it, so whatever treats a fire and a tent alike still can. Each has its own `MERGE`.
  Save version 6. The benches gave the same numbers before and after.
- What stays on `Drone` on purpose: `care_rate` and `wake_at` (what the medical tent reads of anyone), `aura` and `face_to`
  (the shapes the story writes and the views read, so neither names the other), and `home` (a runner's and a medic's).

## Open

Structural, each changing what a save holds or what the story looks like, so each is planned on its own:
1. **`Scenario` lays the first market out by hand** (551 lines, the biggest file) instead of with `Cluster` on a street site, as
   a tile's atom is. Moving it moves the story's stalls a little.
2. **`World` still holds hero and story state**: `bus`, `shuttle`, `bus_stop`, `gun_owned`. They move with the hero's own state.

Small:
3. **The bus and shuttle service lives in `QuestController`** (451 lines), though it is not quest logic: a story transit
   controller of its own.
4. **`Snapshot.DERIVED` names fields as strings** (now also `Chatter._said` and `Machine.shelter`). A leading underscore could
   mark them instead.
5. **Story tests sit with the engine's** (`test_ecb_market`, `test_saves`, `test_story_land`): `tests/story/`.
6. **`tools/` is one drawer** of about 70 scripts (55 of them captures). Folders (`capture/`, `probe/`, `bench/`) would mean
   changing 121 references to their paths. Captures move onto `CaptureTool` as they are touched.
