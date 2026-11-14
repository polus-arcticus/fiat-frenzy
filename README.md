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

**Folders are by feature.** A feature (hero, bike, skating, portal, transit, sage, medical, relief) lives in `features/<name>/` with its model, view and
controller side by side. What every feature stands on stays in the layer folders (`sim/core`, `sim/systems`, `view/ui`, ...). The model files
(no `_view`, `_controller`, `_rig`, `_model` or `_screen` in the name) stay headless, and `tests/sim/test_architecture.gd` checks it.

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
drains. An idle **ambulance** (`features/medical/ambulance.gd`, run by `features/medical/rescue.gd`) drives to the nearest
collapsed person, loads them and takes them to the **medical tent** (`features/medical/hospital.gd`), but only when
there is a free bed. Care is free: the bars refill and they are discharged at 60%. If the hero passes out, the
screen fades to black (`features/medical/collapse_controller.gd`) and they wake up outside the tent with control back.
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
`features/bike/riding.gd` has the rules, `features/bike/bike_controller.gd` the feel.

## Battonnstraße and Mr. Nobody

The map now runs from the station east through Battonnstraße to the European Central Bank on Sonnemannstraße, 2.5 km
from the start (2,890 buildings, `tools/osm_to_district.py` over `data/raw/district_raw.json`, the merge of the strip and
the ECB fetch; the tests now take about 25 s instead of 10 with the larger city). The converter pins its origin (`--origin`), so growing the map never moves anything already
in it. The ride from the start is about 1.5 km along the streets: roughly 2.5 minutes on the bike.

On Battonnstraße, in a building a little way from the museum (which is left alone, and never named in the game),
lives **Mr. Nobody**: a vague, whimsical sage in a suit with a small red shield pinned to his lapel, who collects rare insects
and is tiresome about architecture, but only ever says so. He is unassuming: a man in an ordinary suit with a little red pin on his lapel, nothing outside his house gives him away, and he is just a "Stranger" until he says who he is. The one thing that marks him out is that he never bends down for loose money. When you come within 12 m on foot with the money gun, he notices it, goes inside his house and asks you in (he waits in his room, and the talk begins once you have followed him in) (on the bike he calls out to you to step off it). After that, aim at him and press Q to talk again.
He tells stories of the money of all ages (shells, stones, gold, beads, salt, tally sticks, paper, tulips, red
feathers...) from a menu, and what is on it depends on your own level. `features/sage/stories.gd` is data, easy to
rewrite; `features/sage/sage.gd` is who has met whom; `features/sage/dialogue_screen.gd` and `features/sage/sage_controller.gd`
are the conversation (the clock stops while it runs). The stories are about scarcity, trust and promises, never
about what kind of people handle money, and a test keeps it that way. His house (door, floor, and furniture like anyone's: nothing in it gives him away) is `features/sage/sage_house_view.gd`.

**Teleporter rings** are no longer placed anywhere in the town (the shortcut to Mr. Nobody let you skip the bus ride). The
machinery stays, because rings are how zones connect: rule in `features/portal/portal.gd` and `features/portal/portals.gd`, walking
through in `features/portal/portal_controller.gd`, drawing in `features/portal/portal_view.gd`; a scenario can place a pair with `w.portals.add_pair`.

**Your level:** every dollar you give away is experience for you too (the same curve as everyone: $50 to level 2,
then 1.5x each level), shown as a bar under "You" in the corner. Knowledge is the only reward so far.

Next stage (designed, not built): the seven sins and seven virtues. Who you print at is the core (each business
and person has a nature), and so is printing too much at one target at once; what you print decides what world
rises. The sage's upgrades will be earned by bringing him materials (the insects and building materials he wants).

## The hero

`features/hero/`: `Hero` (`hero.gd`) is how the hero is moving about, one mode at a time: on foot, riding, skating or seated. Every
change goes through `Hero.enter`, so "can I get on this?" has one answer (you can't ride and skate at once, or do either while out cold
or seated) and nothing keeps its own "am I riding" flag: `Riding.riding()` and `Skating.mounted` just read the mode. The bike's reach and
the board's tricks stay with their features. The hero's body in third person (`hero_body.gd`) wears a skin nobody else in town does
(black tee, grey trousers), so they are never mistaken for a builder or a banker. `tools/capture_hero.gd` and `tools/capture_skins.gd`
take the pictures. `player_controller.gd` (the first-person body and camera) lives here too.

## Quests: the letter for the bank

A small questing system. `sim/core/quest_book.gd` is the data (who gives a quest, what they say, the objectives in
order) and `sim/systems/quests.gd` is the state (offered, active, done; flags). The first quest comes from the
bankers: once every stand is running and each banker has had a proper meal, they all want a word about a letter for the
European Central Bank (their phones broke in the crash). Aim at **any** of them and press **Q**; reading the request
through accepts it and gives you the letter (an item in your bag). People who still need your help (a vendor whose stand is
wrecked, a banker who has not eaten) glow gold (`sim/systems/attention.gd`, `view/actors/parts/aura.gd`); the glow goes out
when they have what they need, and the feed says what each goal you finish did.

**The tutorial is a set of goals, not a list** (`sim/systems/tutorial.gd`): after meeting the vendors, funding each stand,
feeding the bankers and so on are all open together, shown as the main goal plus "Also open", and the beacon points at the
nearest. What depends on something else (investing needs the bakery open) waits for it.

**The bus** (once you have the letter): go to its stop by the market and press E. The door slides open, you walk in and sit
down, and the bus drives itself 1.5 km along the real streets to the end of a queue of stuck cars on Battonnstraße outside
Mr. Nobody's house, where the door opens and you step out. The drive is smooth: `features/transit/bus_path.gd` rounds the street
corners into curves and gives every point a speed (up from rest, slower through bends, braking to a stop), `features/transit/transit.gd`
moves it along by distance with limited acceleration, and the view draws it between sim ticks (`SimLoop.alpha`) so it never
steps. When you say **farewell to Mr. Nobody** the jam clears (the cars drive off) and the bus waits for you: board it again
(E) and it carries on to the gate on Sonnemannstraße, where the ECB doorman is. **The sim never stops during the ride**:
the town carries on, and you can look about from your seat. The bus is hollow (`features/transit/bus_view.gd`: seats, poles, a
door, see-through windows); the boarding and the ride are `control/story/quest_controller.gd`, and the seated mode is
`PlayerController.sit`. The medical tent sits on the pavement with its ambulance bay on the carriageway, so the bus can pass it.
`tools/capture_ride.gd` plays the whole ride for screenshots; `tools/probe_bus_route.gd` checks the route for clipping.
The objective line and the beacon follow the quest while one is on. The last leg: ride or walk on
east to the bank (the beacon points the way, with the real distance); aim at the **ECB doorman** outside the front wall
(OpenStreetMap building 156432555, the only building given a name in the data) and press Q to hand the letter over. That
completes the quest. `tools/capture_bus.gd` and `tools/capture_ecb.gd` take screenshots. The bank area is still in the
default zone: giving it its own zone (and a gate to it) belongs with the zone work, not the plot.

## Bills and buildings

A bill can no longer end up where nobody can get it. The city's collision now has the **roofs** as well as the walls, so a bill that
arcs over a building stops on its roof instead of dropping through it. And in the model, any bill that comes down somewhere nobody
could stand (inside a building's outline, or in a stand) is put on the nearest open ground (`Navigation.nearest_open`, called from
`Gun.land`), which also covers the kickflip's $25 if you do it beside a wall. Before this, bills fell through the roof into the
footprint and the NPCs pressed against the wall trying to fetch money they could not reach.

## The money bar

Over everyone's head, and on the target card in place of the old reputation bar, is a **money bar** (`sim/core/wealth.gd`), so who is
broke shows from across the street: an empty bar and no dark notches. The dark-green strip above it has **a notch for every order of
magnitude**: one at $10, two at $100, three at $1,000, four at $10,000 (the most it shows). The light bar fills toward the next
order (under $1 it is empty; $1 to $10 fills the first stretch; $55 is half way from $10 to $100) and starts again from empty when
they cross it. The level bar is gone everywhere (overhead, the target card, your own panel): level is just text now ("Lv 2" on the name tag,
"level 2" on the card, "You · Level 2" on your panel). The card lists **reputation in points** ("reputation 37 points", reputation
times 100) where the wallet line used to be, so an exact wallet is no longer shown: the money bar is how you read it. Money still moves only between wallets: a purchase raises the seller's wallet (and so their bar) by the price.

## The sky and the bars overhead

The sky is painted (`assets/shaders/sky.gdshader`, driven by `DayNight`): a gradient laid down in soft bands like a watercolour wash,
toon clouds with a lit and a shaded side (gradient noise, so no hard edges), a sun with a halo, a warm glow along the horizon at dawn and
dusk (lavender over peach), stars at night. The game opens at 6:47 on a lavender-and-peach dawn. The old grey was the fog covering the
whole sky; it now only hazes the far buildings (`fog_sky_affect = 0`). The bars over heads each have a pale border and a solid dark
backing (`BarsRig`), so the dark-green notches stand out from across the street. `tools/capture_sky.gd` shoots the five times of day.

## Warmth indoors

The two shops, Mr. Nobody's house and the bus are warm (`sim/systems/heating.gd`): anyone standing inside, the hero included,
warms at about 0.012 a second (more than the night cools you), without stacking. So a night ride on the bus, or a browse in the
bike shop, warms you up. Fires and a tent's own bed are still the Needs system's.

## Navigation: where people can walk

`sim/systems/navigation.gd`. Each zone has a grid of half-metre cells; everything solid (stands, tents, fires, the hospital, and
the buildings the scenario tells it about) is stamped into it, grown by a body's width, and `Navigation.path` finds a way round
all of it with `AStarGrid2D`, then pulls it straight so people walk in lines. `Walking` checks each leg of a street route against
the grid and swaps in a way round when something is in the way. No shape needs its own rule: a tent's open end is just free
cells. It is built to change, for base building: `imprint(zone, key, polygon)` stamps something down (a wall, a crate that has come
to rest) and `release` takes it away; overlapping things count, so a cell is free only when nothing covers it; every walker
whose way was built over replans (the zone's `version`). Moving things never touch it. The first and last 0.8 m of a walk
ignore the padding (customers stand a step from a stand's front, inside it). `Footprint` keeps the shapes and the last guard
(`slide`). Probes: `tools/probe_runners.gd` (20 sim minutes of the real town: who gets stuck), `probe_routes.gd`, `probe_tent.gd`.

## The landing street

The converter now measures how far each street's pavement runs out to the buildings on either side (`pave`: the carriageway is
only its traffic lanes, the rest to the building line is pavement) and keeps bike lanes and tracks from the OSM tags (`bike`:
301 of the 1,447 roads; the landing stretch is tagged `cycleway:both=no`, so none there). The city builder draws both. The landing
street is laid out across its width (`Scenario._spot`, measured from the real road where it bends): stalls (hot dog, baker,
lemonade, the food bank) at the kerb edge of the pavement serving the walkway, the tent against the buildings with its open end
to the walkway, the walkway between them, the carriageway kept clear (the bus's lane, and room to walk). The **bus stop** has a
shelter, bench and sign on the pavement and a painted bay (`features/transit/bus_stop_view.gd`); the **medical tent** is on the
pavement with the ambulance's painted bay on the road in front of it. `tools/capture_street.gd` takes screenshots.

## First and third person (V)

V toggles the camera. In third person it hangs 3.4 m behind the hero's head and a little to the right (a `SpringArm3D`, so it pulls
in against walls), and the hero is drawn (`features/hero/hero_body.gd`: the builder model with its idle and walk animations).
The gun is held up in front of the hero's head, the aiming reach is counted from the hero and not the camera, and the bicycle
shows under them. It is always first person while sitting on the bus or being moved by a script, and comes back afterwards.
`tools/capture_view.gd` takes screenshots. Not yet: a run animation, hands on the gun, turning the body toward where it
moves instead of where the camera looks (the skateboarding mode will want that).

## Skateboarding (B)

Buy a board at the skate shop ($120) and press **B** to get on, B again to get off. Arcade, pick-up-and-play: **W** pushes (it
builds to a top speed of 12 m/s), **S** brakes, **A/D** steer (and the mouse turns you too), you coast to a stop and never
roll backwards. **Hold Space** to crouch and **let go to ollie**: the longer you held (up to 0.45 s) the higher. **Tap Space
again in the air for a kickflip**, once a jump, which **sprays $25 on the ground** round you in five $5 piles (it is printed, like
the gun's money, and it is counted: the world total grows by exactly $25) and which you can roll over to pick up. Running into a
wall stops the board dead. The rules are the model's (`features/skating/skating.gd`, tested headless); the movement is in
`features/skating/skate_controller.gd` and the player body; the board and the crouch/flip are `features/skating/board_view.gd`. It puts the
camera in third person (a longer arm) and the gun away, and gets you off if you pass out or sit on the bus. The numbers to tune
are the constants at the top of `Skating`. `tools/capture_skate.gd` takes screenshots. Not yet: grinds, manuals, combos and a score,
bailing, and slopes/ramps.

## The skate shop

Next door to the bike shop (the neighbouring building on Kaiserstraße, found by `MapSites.neighbour`) is a **skate shop**: the
same kind of business (a real building with a door, a rich owner, a flat price) selling **complete skateboards at $120**, three
on the wall. The price is set once, on the item (`Catalog`, `skateboard`). You can buy one and it goes in your bag; riding it is
what the planned skateboarding game mode is for. `features/skating/skate_shop_view.gd` dresses the room; `tools/capture_skate_shop.gd`
takes screenshots.

## Landmarks

A few real buildings are drawn with more character than a flat-topped extrusion (`view/world/landmarks.gd`, used by
`CityBuilder`). OpenStreetMap has their outlines and sometimes a height but not their shape, so each gets a style: a height,
colours, a roof (sloping top, hip, dome or gable) and sometimes a tower. Done so far: the **ECB tower** (185 m, glass-blue,
sloping top), its **Grossmarkthalle** (gable), the **Paulskirche** (red sandstone rotunda with a copper-green dome and lantern), the
**Kaiserdom St. Bartholomäus** (red sandstone nave with a 66 m tower and spire at the west end) and a stylised
**Einheitsdenkmal** (stone slabs, placed at its OSM point). The OSM data behind them is in `data/raw/ecb_parts_raw.json` and
`landmarks_raw.json`; only the ECB tower and hall are in `data/bahnhofsviertel.json` with their real tags. Not done: the
ECB twin towers (OSM has one outline). The **Hauptbahnhof** is done too: its one 377-point outline is cut across its long axis, the
city end drawn as the reception building (gable roof) and the rest as the train halls under a row of arched glass vaults. `tools/capture_landmarks.gd` takes screenshots.

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
