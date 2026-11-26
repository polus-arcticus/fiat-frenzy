# The player: what the hero can do

User space: the hero's controls, screens and vehicles. The engine's rules are in `docs/ENGINE.md`.

## Controls

| key | does |
|---|---|
| WASD, Shift, Space | move, run, jump |
| hold left mouse | spray $1 bills (gift), or charge a contract (invest) |
| scroll | switch gift / invest |
| E | open a stand (trading), the tent city (its tents), a tram, bus or shuttle door |
| Tab | your bag |
| Q | talk |
| F | on and off the bike |
| B | on and off the skateboard |
| U | the money gun's upgrade tree |
| V | first or third person |
| M | the map |
| T | time speed |
| F3 | the inspector |
| Esc | close a screen, or free the mouse |

## The gun (`user/gun/`)

- **The upgrade tree** (U, `user/gun/gun_tree.gd`): four branches, each a ladder climbed one step at a time. The story will unlock
  the steps (`GunTree.unlock`); nothing does yet. The first step of each is today's gun.
  - **Bill size:** $1 → $5 → $20 → $100.
  - **Fire rate:** 6 → 9 → 12 a second.
  - **Ammo:** paper → rolled → feather.
  - **Finance modes:** gift, invest → line of credit.
  The gun reads the bill, the rate and its modes from the tree. Rolled and feather bills, and the line of credit, can be owned
  but do nothing yet.
- **Gift** sprays $1 bills, six a second. A bill that hits someone is theirs. One that misses lands in the street as loose cash:
  the hero picks it up by walking over it, and NPCs fetch it within 14 m. That is also how the hero prints money for themselves.
- **Invest**: hold to charge ($25 up to $250 a shot) and release a contract. One that reaches a business buys a share; anywhere
  else it is void. A runner (the cart pushers) is a business too: a share of one is a share of its $0.40 delivery fees, paid as it
  delivers. Its card (aim at it) says what they haul with, what the business is worth and how much of it you own.
- **A bike for the runner**: give a cart runner enough ($60, on top of the $10 they keep back; the card counts it) and at dawn
  they buy a pedal bike with a trailer: more than twice as fast, 40 units a load instead of 16, and out to bins up to 350 m
  off (waste baskets and fountains), which is new supply for the stands.
- Every dollar given is **experience**, for the receiver and for the hero: $50 to level 2, then 1.5× each level
  (`engine/core/growth.gd`). A business levels with its owner: +25% production and more shelf.
- The heroes together own at most **49%** of any business (`engine/core/equity.gd`).
- Bills never end up where nobody can reach them: one that lands in a building is put on the nearest open ground
  (`Navigation.nearest_open`).

## A new game: where you land (`user/landing/landing_screen.gd`)

New Game opens the landing picker, as in Planet Crafter.
- **Frankfurt · Bahnhofsviertel**: the story.
- **Anywhere on Earth**: a tile of your own, its streets from OpenStreetMap, the atom on it (a tent city, a market, a first
  aid post), no story yet. The hero starts on the street nearest the point chosen, facing the way to the market.
- **The planet:**
  - drag it to turn it, scroll to zoom, and click to choose (or type "lat, lon");
  - it is a globe, or with **Flat map** an azimuthal equidistant map over the north pole (`PlanetProjection`; both drawn by
    `assets/shaders/planet.gdshader`).
  - Zoomed in, the game's tile grid shows (`TileKey`, zoom 16), with the regions (zoom 10) in gold. The chosen tile is pink;
    the panel gives its key, its size, and whether its map is already here.
  - Pins: the story's Frankfurt in gold; green squares for tiles already landed in on this machine.
- **Its pictures** are OpenStreetMap's map tiles (`MapTiles`), fetched two at a time and kept in `user://maptiles`: the whole
  world at zoom 3, and closer tiles where you look. The map is credited in the corner.
- **Land here** fetches the tile's streets if they aren't cached ("FETCHING THE MAP OF …" over the loading picture; "THE MAP
  SERVER IS BUSY: ASKING AGAIN IN 8 S" while it backs off). If that fails, the picker stays and says why.
- **The loading picture counts the build:** "1 / 7 · READING THE MAP" up to "7 / 7 · WARMING UP" (`GameController.STEPS`). The
  city's geometry is baked on a worker thread (`CityBuilder.bake`, `OffThread`), so the picture keeps moving.
- **Water is solid** (`engine/map/osm_water.gd`), and comes with the streets, before you land: lakes, ponds, river areas, and
  rivers and canals as wide as they're tagged. One rule: all the water merged, then every street cut out of it, so a
  **bridge** is a street over the water, and a street along the bank stays a street. A low stone wall (0.85 m) runs along
  every edge where water meets land: quays along the banks, parapets along the bridges; an unseen wall above it means you
  can't jump in. The town walks round it (Navigation), and the market is never put in it, nor on a bridge. The map shows it.
  It reaches 60 m past the tile's edge, as far as its streets.
- **The street's detail, from the map** (no extra requests: the street's tags, and points in the land request):
  - **Buildings:** mapped roof shapes (gabled, hipped, domed) instead of flat tops, and mapped colours or materials (brick,
    stone, glass) mixed into the watercolour palette (`OsmImport._looks`).
  - **Streets:** what they're paved with (cobbles and setts darker, paving stones), dashed lines between mapped lanes, and
    **cobbles slow a skateboard** to 60% of its top speed (`Kerbs.rough_at`, `Skating.ROUGH`).
  - **Furniture** (`engine/map/street_things.gd`): street lamps (the mapped ones, and one every 30 m along the streets the map
    says are lit; in the story's Frankfurt along its main streets), bus and tram stops (a shelter and a sign, on the
    pavement facing the road), stop and give-way signs, traffic lights, zebra crossings, bike stands, benches, waste baskets,
    recycling containers, organics bins, drinking fountains, and hedges, walls and fences (hedges and walls are solid). Each kind is one small model, instanced
    (`StreetThingsBuilder`: 18 to 90 triangles each; about 7,000 for a whole tile). At night the lamps glow and throw a soft
    pool of light (group `night_lights`, switched by `DayNight`).
  - **The town's bins are the map's** (`SiteFinder.bins`): what the town runs on gathers in its real bins near the market, up
    to 3 of each kind, sharing the one bin's rate. The waste baskets give the scrap and the organics bins the leftovers (within
    220 m on foot: the runners wheel them on carts), the drinking fountains the water, and the recycling containers the bottles
    (within 90 m: people walk there for their next meal). A kind with none near enough is the atom's own, in its station by
    the market. On the map's bins you see what has gathered in front of each: scrap and an old bike, bottles, leftovers.
- **Parks** (the map's green, `World.parks`) are where the homeless camps go:
  - **A camp at landing:** the park nearest the market gets one, at most 90 m from it on foot (`SiteFinder.camp`; a park
    further round gets none: its people would spend their day on the road). The same spot for everyone. It has its own
    barrel fire, and its keeper lives by it. It shares the market's garbage bin.
  - **Camps of your own:** the tent keeper makes **camp kits** ($20, of scrap). Put one down in a park (only in a park) and
    a newcomer comes to keep it, by its own fire (`Camp.found`).
  - **The night wind:** after dark a park has no walls to cut it: your warmth lasts 60% as long there (`Cold.PARK_NIGHT`),
    unless you're by a fire. The feed says so as you come in. (Only you: the street's people keep their own cold.)
- **The story's Frankfurt has its land too** (`Scenario.load_district`): its water (the Main, solid), parks and trees, and street
  furniture, from one Overpass answer kept in `data/raw/story_land.json` (`tools/story_land.gd` fetches it again), brought into
  the story map's own metres (`MapFrame`).
- **The dressing comes in after you land** (`DressingController`): a tile's parks, pitches, woods and trees
  (`OsmDressing`, `DressingBuilder`; each tree's crown one of seven solids at random, the same for everyone in the tile:
  the five Platonic ones, the cuboctahedron and the icosidodecahedron, `Solids`), fetched in the background a few seconds in, baked off the main thread and laid under
  the streets. It's only looked at: nothing walks round it (yet), so a tile plays the same with or without it.

## Screens

- **Trading** (E at a stand, `user/view/ui/inventory_screen.gd`). The bag is on the left; the stand's stock and what it wants are on
  the right. Right-click to buy, or to eat and drink. It is paid from the hero's cash.
- **The tent city** opens on the same trading screen as any stand:
  - **For sale:** its keeper's tents ($15) and barrel fires ($5), made from scrap; right-click to buy one into the bag. Sold out,
    they show greyed.
  - **Wants:** scrap, for the wares and for building it up into a hostel.
  - **A third panel, "Who lives here":**
    - an ID card for each resident (`user/view/ui/id_card.gd`): name, ID number, tent number, level, role, hometown, since when,
      and whether they're home, out or in care;
    - click a card to open out their story (`npc/agents/biography.gd`, the same every time for the same person);
    - **Put up a tent** ($15 of your cash, to its keeper: someone new comes to live in it), and **Sit by the barrels** to warm up.
- **Right-click in the bag** does what the item is for (`ItemDef.use`, one rule): gear is equipped, food and drink are had, a tent
  or a barrel fire is put down. Anything else is only carried.
- **Putting things down** (`user/hero/placing.gd`, `placement_controller.gd`), as in Planet Crafter: the bag closes and a ghost
  stands where the crosshair meets the ground, within 6 m, green where it fits and red (with the reason) where it doesn't: it
  needs open ground, clear of stands, fires and tent rows. Left click puts it down; right click or Esc puts it back. The gun is
  held meanwhile.
  - A **barrel fire** is lit there: anyone near it warms up.
  - A **tent** founds a tent city of its own at tier 0 (`Lodging.found`), its open end toward you, kept by a newcomer who lives
    in it. Put up more tents there (E at it) and others come, as at any tent city.
- **The map** (M): the whole district, places known, the goal, and the hero. It works from a seat.
- **The pause menu** (Esc): save, chapters, the developer jumps.
- Screens never switch the controls or the mouse themselves: they register with `ScreenStack`, which does.

## The hero (`user/hero/`)

`Hero` is how the hero is moving: on foot, riding, skating or seated, one at a time, always through `Hero.enter`. Third person
(V) hangs a camera 3.4 m behind on a spring arm. The hero's skin is one nobody else wears.

When a bar reaches 0 the hero collapses. The ambulance takes them to the medical tent, and they wake at 95% but robbed of their
cash (`user/hero/collapse_controller.gd`).

## Vehicles

Rides are **gear**: they live in the loadout (below), so F or B gets on wherever the hero stands.
- **The bike** (`user/bike/`): $3,000 at the shop; about 2.4× walking; no sprint, jump or gun.
- **The skateboard** (`user/skating/`): $120.
  - **Left click** is a push with the foot: +2.4 m/s at once, at most every 0.3 s (the body leans out of a crouch and back).
    W pushes too, smoothly. Up to 12 m/s. S brakes, A/D steer.
  - Holding the crouch (Space) past a full charge pumps the board along, slowly, up to 60% of the top speed: a fallback.
  - **Bail:** into a wall, or a kerb you didn't ollie, faster than 3 m/s, and you're thrown off: over head first, a log roll
    along the ground, and a moment lying on your side in the recovery position, the top leg crossed over; then up and on
    the board again (`Skating.bump`, `SkateController._bail_pose`). Slower, the board just stops.
  - Hold Space and let go to ollie. Tap Space in the air for a kickflip, which strews $5 in five bills 2 to 4 m round where
    you are (printed, and counted).
  - **Style is strewn, not pocketed:** what a trick prints lands out of your reach (`Commerce.PICKUP_REACH`, 1.4 m), for you
    to go back for, or for whoever gets there first.
  - A wall stops it dead.
  - **Kerbs** (`engine/map/kerbs.gd`): pavements are raised 12 cm, with a lighter kerb stone along the drop. Walking and
    the bike step up onto them (`PlayerController.STEP_UP`); a board rolled into one stops dead, so ollie up it.
  - **Grind:** roll along a kerb, ollie, and come down with the board over the kerb line, running along it (within about
    35°): it locks onto the edge and slides (`Skating`). A $1 bill drops every 2 m, strewn on the pavement 2 or so metres
    behind you: a trail to come back for. The edge slows you:
    flat out it's about 30 m and $15. It carries on round a kerb's joins, ends where the kerb does (at a junction) or when
    you've slowed too much, and Space pops you off.
- **Old ones** from the homeless camps: an old board ($15, 60% of the top speed) and an old bike ($60, about half the gain).
  With more than one equipped, the fastest is ridden.

## The loadout (`user/hero/loadout.gd`)

Planet Crafter's exoskeleton, for the street: `Loadout.SLOTS` (4) generic slots above the 12-slot bag, for anything that can be
ridden or worn (`ItemDef.gear`: bikes, boards, coats from the thrift stall).
- Gear that is bought goes straight into a free slot, or into the bag if the loadout is full.
- In the bag screen (Tab), right-click gear in the bag to equip it, and right-click the loadout to take something off. You can't
  take off what you're riding.
- Clothes carry `ItemDef.insulation` (an old coat 0.3, a coat 0.6; added up, at most 0.9). They keep you warm for longer (below).

## The cold (`user/hero/cold.gd`)

The street's people are hardened to it; the hero is new out here. Without clothes, a full warmth bar lasts about **two blocks**
of walking by day (`Cold.DAY_BLOCKS`, a block being 110 m: about 49 s) and **three quarters of a block** at night (about 18 s).
- An old coat takes it 1.4 times as far, a coat 2.5 times, both 10 times.
- A barrel fire fills the bar in a few seconds, standing beside it. At night you must be within about 3 m to gain on the cold.
- Shops, the sage's house, a tram or bus and the bank's shuttle are warm inside.
- The feed warns you when the bar falls past 40%. At 0 you collapse (and are robbed).
- Fires: every atom has one by its market (in the story, the station forecourt's and the bank's market's), and one stands on the
  bank's plaza by the entrance. The tent keeper sells more, for the hero to put down. (The street fires, every 60 m, went with
  the hand-made market: the hero's cold, tuned against them, is open: docs/review.md.)

## What the hero sees

- **The money bar over every head** (`engine/core/wealth.gd`). A notch per order of magnitude ($10, $100, $1,000, $10,000), and the
  bar fills toward the next.
- **Chat bubbles** (`npc/agents/chatter.gd`, `npc/agents/lines.gd`). A few lines per kind of person, said now and then.
- **The sky** (`assets/shaders/sky.gdshader`, `DayNight`). A watercolour wash, toon clouds, a sun; stars at night.
- **Warmth indoors** (`engine/systems/heating.gd`). The shops, Mr. Nobody's house and any vehicle warm whoever is inside.
- **The bottle depot** (`engine/deposit/`): a kiosk under a green PFAND board, its attendant behind the counter and crates of
  empties by the side, one at each market. Its board says what a bottle is worth ($1) and what it has paid out. Whoever is
  short of cash (under $25) walks to the recycling, takes what brings them back up to $25 (a bag holds 20; a runner's cart
  16) and hands it in there: that is how money
  comes into the town, apart from you. The depot pays out of what the stalls paid for their leftovers and water first, and prints
  only when that is empty.
- **Passersby** (the station): people cross the forecourt between the station's doors and the tram's stops, most at morning,
  midday and evening. Each has a little cash (more at higher levels). They grab any bills in the street, and buy food or drink
  from stands near their way. The HUD counts today's sales to them and the lost ones; each dawn the feed sums up yesterday. A
  stand can only sell what the bins and runners can supply.
- **Getting about**: tram 11 runs both ways, a stop each time you get on (E at a door), and past the last stop it comes round
  from the other end of town. The eastbound tram at the station waits for the letter quest. The shuttle runs between the bank's
  gate and its door.

## The inspector (F3, `user/inspector/`)

A free camera over the live world (the sim keeps running). Click anyone, or N and P to step through, and G to fly to them. The
panel shows their wallet, bars, job, target, route, what they want and what the planner would send them to. If they have stood
still more than 5 s on a job, it says they may be stuck.
