# Fiat Frenzy

A first-person game about money, set in an abandoned Frankfurt station district (Bahnhofsviertel, from
OpenStreetMap). Everyone left is broke, hungry and cold. You have a money gun: **gift** money to earn rep,
or **invest** to buy a share of someone's business and earn its cash flow forever. Level the district up
into a rejuvenated town.

## Run

    ~/app-port/Godot_v4.7.2-stable_linux.x86_64 --path .

The game opens with a helicopter full of bankers crashing onto the street, and the money gun dropping at your
feet. Space or Enter skips it, and `--skip-intro` (after `--`) starts you with the gun in hand.

WASD move, Shift run, Space jump, hold left mouse to spray (or, in invest mode, to charge), scroll wheel switches gift/invest, **Tab or Q opens your inventory**, **E opens a stand's**, **F gets on and off your bike**, **M opens the map**, T time speed, Esc goes back (closes a screen, or frees the mouse).

The gun has two modes. **Gift** sprays $1 bills (six a second): a bill that hits someone is theirs, and one that
misses lands in the street as loose cash that anyone can pick up: you by walking over it, NPCs by noticing it
within 14 m and fetching it. That is also how you print money for yourself. **Invest** is slower and bigger:
hold to charge (the ring fills, $25 up to $250 a shot), release to spit an investment contract. A contract that
reaches a business buys a share of it; anywhere else it is void, and never lies on the ground.

At a stand, E opens a Planet Crafter-style screen: your inventory on the left, the stand's on the right (what it sells, and what it wants). Right-click its stock to buy one, right-click your own items to eat or drink them. You pay out of your cash flow, the money your stakes earn.

## How it is built: model, view, controller

    sim/          MODEL. Pure RefCounted, no nodes, headless-testable. Knows nothing of rendering or input.
      core/       Inventory, Stacks (slot layout), Catalog (the data) with ItemDef and MachineDef (one definition per kind of item or business), Pricing, Equity, Shelter, RoadGraph, Stories, QuestBook
      entities/   Drone (every NPC), Machine (an autocrafter), FoodBank, BarrelFire, ReliefTruck, Hospital, Ambulance, Bike, Bill, Portal
      systems/    one rule-set each: Clock, Ledger, Needs (Maslow), Logistics (demand meets supply), Walking, Relief, Rescue, Gun, Commerce,
                  Cash, Levels, Chatter, Riding, Sage (Mr. Nobody), Quests, Portals, Zones, Tutorial (objectives, watches only)
      world.gd    the composition root: holds state, owns the systems, ticks them
    view/         VIEW. Nodes that draw the model and only read it.
      ui/         Hud, InventoryScreen, DialogueScreen, MapScreen, FadeScreen, LevelBar, ItemIcon, SlotView
      actors/     DroneView, AmbulanceView, BikeView (+ parts/: BarsRig, Bubble, CartView, Emblem)
      props/      MachineView, FoodBankView, FireView, ReliefView, HospitalView, ShopView, SageHouseView, BusView, PortalView, MarkerView, GunPickupView
      player/     what the hero sees of themselves: GunRig, BikeRig
      fx/         BillsView, BillProjectile, ContractProjectile, PaperProjectile, Effects
      world/      CityBuilder (the district), DayNight, Watercolor (the look)
      look.gd     shared helpers (boxes, labels, materials)
    control/      CONTROLLER. Input and orchestration.
      game_controller.gd   the root: builds the town, the player, the screens and the story in four named steps, and hands the sim to SimLoop (fixed steps, speed, named holds so intro, talks and the bus ride cannot un-pause each other)
      hud_presenter.gd     every frame, tells the HUD what the model says (objective, bars, feed)
      world_views.gd       makes the views for what the world contains
      screen_stack.gd      full-screen screens: owns Esc, and the player's controls and the mouse while one is open
      player/     PlayerController, GunController, BikeController, InteractionController (E, Tab, Q), CollapseController, PortalController, Controls
      story/      Scenario (the starting world), MapSites (map geometry: doors, streets, the jam), IntroController,
                  SageController, QuestController
    data/         the district (bahnhofsviertel.json, from tools/osm_to_district.py)
    tests/        run.gd (the model: sim/test_*.gd, one method per test); smoke_scene.gd runs the real scene headlessly as ordered
                  sections (scene/s01_*.gd ...); smoke_intro.gd; support/ (TestCase, Fixtures)
    tools/        test.sh (all suites at once), osm_to_district.py, capture*.gd (windowed screenshots)

Two conventions keep the controllers honest. **Screens** (bag, map, conversation) never switch the player's controls or the
mouse themselves: they register with the ScreenStack, which does. **Conversations** are run by a controller that sets
`DialogueScreen.handler` and implements `dialogue_finished`, `dialogue_chosen(id)` and `dialogue_closed`, so two
conversations never answer each other's screens.

Composition, not inheritance: components (Equity, Shelter, Pricing) are held by entities, and systems are
held by the world. Money is a plain number on a drone, never an inventory item.

## The model in one paragraph

Planet Crafter's automation with people as the drones. A Machine has an input and an output inventory and a
recipe; its output inventory *offers* items and its input inventory *wants* them. A Drone has needs, and what
it demands changes with Maslow's order: survival (food, drink, warmth) first, then its vocation (repair its
machine, keep it stocked). An idle drone matches its top demand to a supply, walks there along the streets,
and moves the item, paying with a number. Prices move one tick per craft. Nights are 7.5x colder than days; a barrel fire warms by an inverse-square law (strongest beside it, a quarter as strong at twice the distance), and a tent warms only whoever has bought a bed in it.
The Red Cross van brings a small free load of flour, protein, water and sugar twice a day. A food bank down
the street trickles in the same goods slowly and sells them at cost; cart runners buy a load there and wheel it
to whichever storefront is running short, and the shop pays them the cost plus a small fee per unit.

## Levels, experience and the 49% cap

The level bar has two layers: a thin dark-green strip on top that grows one notch every level you reach (ten levels fill it), and the light-green bar underneath that fills toward the next level and starts again each time it dings (`view/level_bar.gd` in the HUD, the top strip of `view/parts/bars_rig.gd` over heads).

Money given to someone is their **experience**. The green bar over a head fills with it and levels up: level 1 to 2
costs $50, and each level costs 1.5x the one before (`sim/core/growth.gd`). A vendor and their business level
together (`sim/systems/levels.gd`): each level gives +25% production, +10 shelf room (a stack for stalls) and
room for one more craft of inputs. A business is **worth** its rebuild cost plus its experience, so the more
money poured in, the more a share costs. You can own at most **49%** of any business (`sim/core/equity.gd`);
the part of a contract that would go over the cap is void.

## Collapsing, the ambulance and the medical tent

The hero's stay is short and kind: the tent mends them five times as fast and lets them go at 95%, so they wake with their survival bars right up, but mugged: whatever cash they carried went to the nearest drifter (the books still balance). The ambulance goes fast enough that no trip takes more than about 25 s, however far out the hero fell.

When any survival bar reaches zero, that person (the player too) **collapses** where they stand: no plans, nothing
drains. An idle **ambulance** (`sim/entities/ambulance.gd`, run by `sim/systems/rescue.gd`) drives to the nearest
collapsed person, loads them and takes them to the **medical tent** (`sim/entities/hospital.gd`), but only when
there is a free bed. Care is free: the bars refill and they are discharged at 60%. If the hero passes out, the
screen fades to black (`control/collapse_controller.gd`) and they wake up outside the tent with control back.
Cart runners walk a little faster than drifters and their carts hold 16 units.

## Chat bubbles

Everyone has a voice (drifter, vendor, food bank keeper, runner, banker): three things to say when you get
close (`sim/core/lines.gd`, picked at random, not often, never the same one twice running), and one each for
picking up loose money, being given money and being invested in. `sim/systems/chatter.gd` decides who says what
and when; the line sits on the drone, and `view/parts/bubble.gd` floats it over their head.

## Things people can't walk through

`sim/core/footprint.gd` is what a solid thing takes up: tents are three walls with the front open, stalls and the
food bank a counter, barrel fires a circle. Drones go round them (to the nearest corner, and in through the door
for a bed), and `Look.solid_body` makes the same shapes into colliders for the player and the gun's paper.

## The bike shop

A real shop in a real building: OSM building 174326357, with a door cut into its street wall and a floor, ceiling
and inside walls (`CityBuilder.build(district, openings)`). It makes nothing and sells one bicycle for $3,000.
The business is worth $2 million before anyone gives it a cent, so spraying it with money or investing in it
gets you nowhere (a full $250 contract buys 0.01%); its rich owner has no needs and stays at the counter. Save up
(the tutorial's goal: print bills at your feet and pick them up, or live off your stakes), buy the bike at the
counter, and press F next to it to ride: about 2.4x walking speed, no sprint or jump, the gun put away.
`sim/systems/riding.gd` has the rules, `control/bike_controller.gd` the feel.

## Battonnstraße and Mr. Nobody

The map now runs from the station east through Battonnstraße to the European Central Bank on Sonnemannstraße, 2.5 km
from the start (2,890 buildings, `tools/osm_to_district.py` over `data/raw/district_raw.json`, the merge of the strip and
the ECB fetch; the tests now take about 25 s instead of 10 with the larger city). The converter pins its origin (`--origin`), so growing the map never moves anything already
in it. The ride from the start is about 1.5 km along the streets: roughly 2.5 minutes on the bike.

On Battonnstraße, in a building a little way from the museum (which is left alone, and never named in the game),
lives **Mr. Nobody**: a vague, whimsical sage in a suit with a small red shield pinned to his lapel, who collects rare insects
and is tiresome about architecture, but only ever says so. He is unassuming: a man in an ordinary suit with a little red pin on his lapel, nothing outside his house gives him away, and he is just a "Stranger" until he says who he is. The one thing that marks him out is that he never bends down for loose money. When you come within 12 m on foot with the money gun, he notices it, goes inside his house and asks you in (he waits in his room, and the talk begins once you have followed him in) (on the bike he calls out to you to step off it). After that, aim at him and press Q to talk again.
He tells stories of the money of all ages (shells, stones, gold, beads, salt, tally sticks, paper, tulips, red
feathers...) from a menu, and what is on it depends on your own level. `sim/core/stories.gd` is data, easy to
rewrite; `sim/systems/sage.gd` is who has met whom; `view/dialogue_screen.gd` and `control/sage_controller.gd`
are the conversation (the clock stops while it runs). The stories are about scarcity, trust and promises, never
about what kind of people handle money, and a test keeps it that way. His house (door, floor, and furniture like anyone's: nothing in it gives him away) is `view/sage_house_view.gd`.

**The teleporter** is a debug shortcut now: run with `--portals` and two rings stand, one at the kerb behind the start and
one a few steps from Mr. Nobody (walk into either to come out of the other). Rule in `sim/entities/portal.gd` and
`sim/systems/portals.gd`, walking through in `control/portal_controller.gd`, drawing in `view/portal_view.gd`.

**Your level:** every dollar you give away is experience for you too (the same curve as everyone: $50 to level 2,
then 1.5x each level), shown as a bar under "You" in the corner. Knowledge is the only reward so far.

Next stage (designed, not built): the seven sins and seven virtues. Who you print at is the core (each business
and person has a nature), and so is printing too much at one target at once; what you print decides what world
rises. The sage's upgrades will be earned by bringing him materials (the insects and building materials he wants).

## Quests: the letter for the bank

A small questing system. `sim/core/quest_book.gd` is the data (who gives a quest, what they say, the objectives in
order) and `sim/systems/quests.gd` is the state (offered, active, done; flags). The first quest comes from the
bankers: once every stand is running and all the bankers are fed, one of them has a letter for the European Central
Bank (their phones broke in the crash). Aim at him and press **Q**; reading his request through accepts it and gives you
the letter (an item in your bag). Then take the **bus** from its stop by the market (E at it): a short fade, and the
bus is stuck in a traffic jam on Battonnstraße right outside Mr. Nobody's house, where you meet him. The bus, cars and
fade are `view/bus_view.gd` and `view/fade_screen.gd`; the talk and the ride are `control/quest_controller.gd`. The
objective line and the beacon follow the quest while one is on. The last leg: ride or walk on
east to the bank (the beacon points the way, with the real distance); aim at the **ECB doorman** outside the front wall
(OpenStreetMap building 156432555, the only building given a name in the data) and press Q to hand the letter over. That
completes the quest. `tools/capture_bus.gd` and `tools/capture_ecb.gd` take screenshots. The bank area is still in the
default zone: giving it its own zone (and a gate to it) belongs with the zone work, not the plot.

## Scaling: limits and how to fence the sim (a plan, not built)

Measured headless (the model alone, 0.1 s steps cost about ten times a 1 s step): about 0.12 ms per tick at 11 people, 0.8 ms at
111, 3 ms at 411, 7.4 ms at 1,011, so it grows roughly linearly with the number of people. That is fine up to a few hundred
at normal speed and not at x20. The other limits, in the order they will bite: (1) the views (a skinned model, ten bar quads and
two labels per person, all alive at once); (2) the one big city mesh and trimesh collider (2,200 buildings now; collision already
misbehaved far from the origin once); (3) float precision beyond about 5 km from the origin; (4) supply searches that look at
every machine.

The plan is to fence by **zone**: a zone is a patch of the district that owns its people, machines and loose cash and keeps its own
books. Only the zone round the hero runs in full (every drone, every view). Zones further off tick at a coarse step, or as a
summary (output per minute, food per head) with no views at all, and are woken into full detail when the hero comes near. Zones
talk to each other only through named gates (a trade route, the bus, a quest), never by reaching into each other's lists, and the
whole-world "money is conserved" check stays the invariant that catches any leak between them. The map would be built and its
collision made per chunk, with the world origin shifted as the hero moves. **Measured (`tools/bench_zones.gd`: a "town" is 4 stands, a food bank, 2 runners and 6 drifters, about 13 people, cost per 0.1 s tick):**

| towns | one big zone | a zone each, all running | a zone each, only the hero's running |
|---|---|---|---|
| 1 | 0.18 ms | 0.18 ms | 0.17 ms |
| 4 | 1.4 ms | 0.66 ms | 0.18 ms |
| 10 | 13 ms | 1.6 ms | 0.19 ms |
| 20 | 129 ms | 3.3 ms | 0.21 ms |

In one zone the cost climbs much faster than the population (the runners' haul search looks at every food bank, shop and
runner: roughly cubic), so **a zone should stay town-sized: up to about 50 people and 3 or 4 supply chains (about 1.5 ms a
tick)**. With one zone per town the cost is linear in towns running (0.17 ms each) and flat when only the hero's runs. This
needed per-zone indexes (`Zones.drones_in`, `machines_in`, `solids_in` and so on): before them, walking tested every drone
against every solid thing in the world, and the searches walked the world's whole lists. The sim's hard limit is now the
number of zones running at once, not the size of the world.

**Built so far:** every drone, machine, food bank, fire, hospital, relief van, bill and ring has a `zone` (default `"district"`;
a scenario sets `World.build_zone` before building a patch). The `Zones` system owns which zones run (`zones.active`, empty = all;
`follow_player()` fences to the hero's zone). Supply, restock, haul, loose-cash, rescue, relief-van and chatter searches only see
their own zone. A dormant zone is frozen (nobody moves, eats or talks) but its businesses and food bank keep producing in 10 s
jumps. Zones connect only through rings (`Portals.cross`) and `Zones.send` (drifters only; vendors are tied to their stand);
money rides in wallets, so the world total is unchanged, and `Zones.books()` shows each zone's money. Not yet: coarse
summaries of dormant people, per-zone ledgers for `sunk` and the hero's pocket, and the chunked map and origin shifting.

## Tests

    tools/test.sh                      # everything at once, about 10 s (sim, scene, intro in parallel)
    tools/test.sh sim --only=rescue    # just the model tests whose name contains "rescue" (about 1 s)
    godot --headless --path . --script tests/run.gd -- [--only=x] [--verbose] [--update-manifest]
    godot --headless --path . --script tests/smoke_scene.gd    # the real scene, headless (intro skipped)
    godot --headless --path . --script tests/smoke_intro.gd    # the helicopter intro (engine time x4)
    godot --path . --script tools/capture.gd -- /some/dir      # screenshots (opens a window)
    godot --path . --script tools/capture_intro.gd -- /some/dir  # the intro beats (opens a window)
    godot --path . --script tools/capture_rescue.gd -- /some/dir # the ambulance and medical tent

A sim test is a `test_*` method in `tests/sim/test_*.gd` (extends `TestCase`, uses `check(ok, what)` and the
builders in `tests/support/fixtures.gd`). The runner reseeds the RNG before each one, so any test can run
alone. `tests/expected_checks.json` records how many checks each test makes: a test that dies partway (a script
error) fails by name. After adding tests, run `--update-manifest` and read the diff. Scene tests step the game
with `game.advance(seconds)` instead of waiting for frames.

Run `godot --headless --path . --import` after adding a `class_name`.

## Parked

Banks and rent, zombies and abandoned storefronts, tech trees, sins and vices, virtues: all built and tested
once, now in `~/proto/ff3d-parked/` (sim_v1, sim_v2). The core came first.


## The map

M opens a flat map of the whole district (the same data as the city), north up, with N, E, S and W round the
edge and a compass rose, street names, the places you know of, a gold diamond where the tutorial wants you to
go (an arrow at the edge if it is off the map), and you as a red arrow facing the way you face. Scroll zooms,
drag pans, C brings you back, M or Esc closes. It won't open over a conversation or another screen.
