# Fiat Frenzy

A first-person game about money, set in Frankfurt's abandoned station district (the Bahnhofsviertel, from OpenStreetMap).
Everyone left is broke, hungry and cold, and the hero has a money gun that cannot be put down. Gift money and people buy food,
fix their stands and get by. Invest and you own a share of what they make. The town is a Planet Crafter-style automation with
people as the drones, and it grows: every business is a trade that its owner builds up, tier by tier. The undertone is that the
gun is a curse (see `docs/story.md`).

## Where to read

| doc | what |
|---|---|
| [docs/ENGINE.md](docs/ENGINE.md) | **the rules of the simulation**: agents, assets, trades and tiers, needs, prices, money, zones, saves (start here) |
| [docs/balance.md](docs/balance.md) | what the benches measured, and the fixes they led to |
| [docs/upgrade_trees.md](docs/upgrade_trees.md) | every trade's ladder, built and to come |
| [docs/player.md](docs/player.md) | the controls, the gun, the screens and the vehicles |
| [docs/story.md](docs/story.md) | the design note, the map, the places, the quests, the scripted cast |
| [docs/coop.md](docs/coop.md) | tiles, merging saves, and co-op to come |
| [docs/review.md](docs/review.md) | the latest code review, and the four code spaces it leads to |

## Run

	~/app-port/Godot_v4.7.2-stable_linux.x86_64 --path .                   # the game (Space skips the intro)
	~/app-port/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skip-intro   # start with the gun in hand
	~/app-port/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skip-intro --stage=gate   # jump ahead (docs/story.md)

The keys are in `docs/player.md`: WASD, the mouse to spray, E to use a stand or tent, Tab for the bag, Q to talk, M for the map,
F3 for the inspector.

**Where you land.** New Game asks: the story's Frankfurt, or anywhere on Earth. Anywhere is picked on a globe (or a flat map
over the north pole) with the game's tile grid on it (`TileKey`: zoom-16 tiles, about 390 m across at Frankfurt). Everyone
who picks a place in the same tile gets the same streets and the same market, so saves fit together. The game uses the
network for two things, both public OpenStreetMap services:
- the picker's map pictures, from `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, two at a time, only where you look, kept
  in `user://maptiles`;
- a tile's map from Overpass (`https://overpass-api.de/api/interpreter`), two requests per tile, ever, both before you land
  (kept in `user://tiles`):
  - its buildings and streets;
  - its land: water (solid), parks (where camps go), and the street's furniture as points (lamps, stops, signs, bike
	stands, benches, recycling), cut to the tile's box by the server. Trees are scattered with the tile's own dice, not
	fetched. (Its file is named by the version of its query: a tile cached with an older one fetches it once more.)

Every request backs off exponentially when the server is busy (`Backoff`: 2 s doubling to 60 s, with jitter; `Retry-After`
honoured). Nothing about the player is sent.

## How it is built

**Model, view, controller.**
- The model is headless: no nodes, no input, no rendering. Views only read it. Controllers turn input into calls on it.
  `tests/sim/test_architecture.gd` checks that model files never touch the scene tree and roll only the world's dice
  (`World.rng`).
- `World` (`engine/world.gd`) is the model's composition root. It holds the state and owns the systems. Each system is one rule set, a
  `RefCounted` that takes the world; if it needs a turn each tick, it is in `World._end_of_tick` with a `step(dt)`.
- **The engine runs on its own.** `World.new(false)` is the simulation and its people only. It has none of the hero's or the
  story's systems, and it is what the benches and a map of anywhere run on (`test_the_engine_runs_without_the_hero_or_the_story`).
  The game's world, `World.new()`, adds the hero's and the story's systems. The hero's own turn (their needs, their zone) is the
  `Hero` system's. The engine only knows which zone is watched (`Zones.focus`).
- Composition, not inheritance: components (Equity, Shelter, Growth) are held by things, and systems by the world. Money is a
  number, never an item.

**Four spaces, one top folder each** (`docs/review.md`). The dependencies point down: a script names no class from a space
after its own. `test_architecture` checks this on every run, and fails on a planted upward reference.

	engine/   the simulation: world, core data, entities, systems, map geometry,     (uses nothing above it)
			  relief, welfare, lodging, portals, and the views of assets and the city
	npc/      what agents decide and do: needs, errands, supply, queues, hauling,      (uses engine)
			  borders, chatter, medical; the drone views
	user/     the hero: hero, gun, commerce, bike, skating, transit, inspector,        (uses engine, npc)
			  saves, the HUD and screens, the game controller
	story/    the scenario and its cast, quests and tutorial, the sage, the ECB,       (uses anything)
			  the story's verbs and set-piece views

Inside a space, features have their own folders (`user/gun/`, `story/sage/`), with model, view and controller side by side.
Presentation is in a `view/` or `control/` folder, or named for it (`_view`, `_controller`, `_screen`, ...). Everything else is
model, headless.

**Two composition roots** may name every space: `engine/world.gd` (it owns every system) and `user/control/game_controller.gd`
(it builds the app: the hero's controls and screens, and the story's controllers and views). Everywhere else, the user space
reaches the story only through shapes the user space defines:
- `Objectives`, which the tutorial fills in;
- `InteractionController.add_verb`, which the story's talks use (`StoryVerbs`);
- `PauseScreen.stages`, which is handed the developer jumps.

The world holds the story's scripted cast (`World.cast`, a story `Cast`) without looking inside.

**Conventions that keep it honest.**
- **Each fact is defined once.** Prices, rates and costs live in the Catalog (`engine/core/catalog.gd`); trades and their tiers in
  `Catalog.TRADES`; how a field merges in its class's `MERGE` table.
- **Money is conserved.** It enters only by the gun, the seed or the welfare fountain, all counted in `Ledger.printed`. Every test
  that moves money checks `total_money == ledger.printed`.
- **Everything has a uid** (`World.mint`): `<zone>#n` while the map is seeded, `<author>/n` in play. References are uids, so
  saves combine (`docs/coop.md`).
- **Screens never switch the controls or the mouse themselves.** They register with `ScreenStack`, which also owns Esc.
- **Conversations are run by a controller** that sets `DialogueScreen.handler`, so two conversations never answer each other's
  screens.

**Adding a feature:**
1. Pick its space (what it may depend on decides it), and make `<space>/<name>/` with its model (a system that takes the
   `World`), its view and its controller.
2. In `engine/world.gd`: add a typed field and a `.new(self)`. If it ticks, add it to `_end_of_tick`. If it has state, add it to
   `World.SAVED`. That one list is what Snapshot saves; Merge merges it by its class's `MERGE` table if it has one.
3. Its controller is made in `GameController`. New things it makes in play go in `World.arrivals`, and views appear for them
   (`WorldViews.add`).
4. Run `godot --headless --path . --import` after adding a `class_name`.

## Tests

	tools/test.sh                    # everything, about 11 s: 4 sim shards, the scene and the intro, all at once
	tools/test.sh sim --only=trades  # the sim tests whose name contains "trades", in one process
	tools/test.sh scene | intro      # one suite
	godot --headless --path . --script tests/run.gd -- [--only=x] [--verbose] [--update-manifest] [--shard=i/n]

- **The sim suite** (`tests/sim/test_*.gd`): one method per test, extending `TestCase` and calling `check(ok, what)`, with the
  builders in `tests/support/fixtures.gd` and the standard cluster (`Cluster`). The runner reseeds the RNG before each test, so
  any test can run alone.
- **`tests/expected_checks.json`** holds how many checks each test makes. A test that dies partway fails by name. After adding
  tests, run with `--update-manifest` and read the diff.
- **The scene suite** (`tests/smoke_scene.gd`, sections `tests/scene/s*.gd`) drives the real game headless, and prints its slowest
  sections. **The intro suite** (`smoke_intro.gd`) plays the helicopter crash.
- **Timing.** Both run with `--fixed-fps 60`, so frames don't wait on the clock. Each process has a 120 s timeout, because a
  script that does not compile leaves Godot waiting instead of quitting.

## Tools

- `tools/bench_*.gd` and `tools/epoch.gd`: the economy over days, a year, merged saves, many towns (`docs/balance.md`).
- `tools/capture*.gd`: windowed screenshots of one thing each, `-- <output dir>`. A new one extends `CaptureTool`
  (`tools/capture_tool.gd`) and writes only its `_run()`.
- `tools/probe_*.gd`: one question each, asked of the model.
- `tools/check_stages.gd`: every developer jump.
- `tools/osm_to_district.py`: the map from OpenStreetMap. It names its Overpass URLs before fetching anything.
- `tools/make_tile.gd -- lat=… lon=… [days=N] [offline]`: fetch (or read from the cache) a tile, put its atom on it and run it.
- `tools/capture_globe.gd`, `tools/capture_newgame.gd`: the landing picker, and starting a game from the title on a tile.
