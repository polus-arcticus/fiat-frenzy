# Code review (2026-11-25)

About 38,000 lines: the four spaces 24,500 (engine 10,200, npc 2,200, user 8,800, story 3,200), tests 9,100, tools 4,700. What holds
up, how the code is split, what is still owed. How it got here is in the git history (the reviews of 11-18 and 11-23, and the
refoundation of 11-25: tests, the economy as data, the atom's founders, the transport, the story on the atom).

## What holds up

- **The model is headless and deterministic.** It never touches a node and rolls only the world's dice (`test_architecture`).
  Saves and merges rest on it.
- **Money has one invariant** (`total_money == printed`), checked by nearly every test that moves money.
- **Each fact is defined once, as data:** items and businesses (Catalog), raw sources (`WasteBin.KINDS`), needs (`Drone.BARS`),
  the atom's founders and their order (`Lodging.FOUNDERS`), the atom's street layout (`Atom.LAYOUT`), how saves combine (per-class
  `MERGE`), what is saved (`World.SAVED`). A new resource, recipe and business is rows only (`test_chains`).
- **One town layout, one transport.** Every town is an atom grown by its founders (a tile's, the story's, the bank's market, the
  bench cluster). Everything ridden is a `Vehicle` on a `Line` or sent, with one ride controller.
- **The engine runs on its own** (`World.new(false)`): benches, a map of anywhere, the epoch sim.
- **The benches** catch what unit tests cannot (the price ratchet, runners setting out on trips they could not last, a medic and
  an ambulance both taking the hero).

## The spaces and the concerns

| space | holds | may use |
|---|---|---|
| `engine/` | World, the Catalog and data types, assets, ledger, clock, zones, navigation, walking, summary, the economy, the atom and the cluster, transport, snapshot and merge, map geometry, the views of assets and the city | nothing above it |
| `npc/` | what agents decide and do: needs, logistics, supply, queueing, hauling, collecting, borders, chatter, rescue; drone views | `engine/` |
| `user/` | the hero, gun, commerce, riding, skating, the hero's rides, portals, inspector, landings, saves, HUD, screens, `GameController` | `engine/`, `npc/` |
| `story/` | the scenario, quests, tutorial, intro, dev stages, the sage, the bank, dialogue, the cast, the landmark styles | anything |

Two composition roots may name every space: `engine/world.gd` and `user/control/game_controller.gd`. Across the spaces,
`test_architecture` keeps three concerns apart: world building (the map's model, the city's views) and the economy name no part of
each other, and nothing below the story reads its state (`.quests`, `.sage`, `.cast`, `.attention`) or names its places (OSM ids,
Frankfurt's streets). What is still owed is listed in the test; a new debt fails it, and so does one paid off but left listed:
- `SiteFinder` lays its street site out by the atom's `LAYOUT` (the atom should be handed the site);
- `HudPresenter` reads `world.quests.objective()` (an `Objectives` stack handed in instead).

## Open

1. **The hero's cold** (Cold) was tuned against fires every 60 m down Kaiserstraße, gone with the hand-made market: away from the
   market's one fire it is harsh. The scene suite hardens the hero. A decision for the story.
2. **A full town is flat**, not weakly growing: no business builds up with money in a season. Wants a lever (docs/balance.md).
3. **The story reads the economy's internals** (`Tutorial`, `Quests`: `Machine.working`, `Ledger`, `Residence`): a small read-only
   facade would let them change apart.
4. **`GameController` wires the story by hand** (`scenario != null` branches): a story bootstrap could take them.
5. **`Snapshot.DERIVED` names fields as strings.** A leading underscore could mark them instead.
6. **`tools/` is one drawer** of about 70 scripts; captures move onto `CaptureTool` as they are touched (most already take the
   story's town grown: `--grown`).
7. Parked, kept with their tests in the slow tier: merging saves (co-op), dormant zones, crossing between tiles.
8. **Logistics at scale: the horizon.** Planet Crafter's autocrafter (every recipe automated, machines pull their inputs) meets
   Factorio's logistic network (requesters and providers with priorities, carriers dispatched to the best match). Today each idle
   runner scans every source against every shop (`Hauling.haul_job`: roughly cubic in a zone, `bench_zones`), greedy and tuned by
   hand (`need × 10 − distance`, `MIN_LOAD`). Before the second or third supply chain: a board of requests and offers, matched in
   batches (sorted once by value, greedy, no reuse), distances cached per source (Dijkstra over the road graph, refreshed with
   navigation), and urgency as data on the request. Walking stays as it is.

## Tests

`tools/test.sh` runs the sim, story, scene and intro suites at once in about 27 s; the scene suite sets the pace. The slow tier
(`test_slow_*`, `tools/test.sh slow`) holds the long simulations and the parked machinery. `tests/expected_checks.json` counts
both. Known broken tools, untouched for a while: `capture_skate.gd`, `fetch_relief.gd`.
