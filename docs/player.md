# The player: what the hero can do

User space: the hero's controls, screens and vehicles. The engine's rules are in `docs/ENGINE.md`.

## Controls

| key | does |
|---|---|
| WASD, Shift, Space | move, run, jump |
| hold left mouse | spray $1 bills (gift), or charge a contract (invest) |
| scroll | switch gift / invest |
| E | open a stand (trading), the tent city (its tents), the bus or shuttle door |
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
  delivers. Its card (aim at it) says what the cart is worth and how much of it you own.
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
- **Land here** fetches the tile's streets if they aren't cached ("FETCHING THE MAP OF …" over the loading picture). If that
  fails, the picker stays and says why.

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
    - **Put up a tent** (the gun pays: someone new comes to live in it), and **Sit by the barrels** to warm up.
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
  - W pushes (up to 12 m/s), S brakes, A/D steer.
  - Hold Space and let go to ollie. Tap Space in the air for a kickflip, which sprays $25 (printed, and counted).
  - A wall stops it dead.
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
- Shops, the sage's house, the bus and the bank's shuttle are warm inside.
- The feed warns you when the bar falls past 40%. At 0 you collapse (and are robbed).
- Fires (`Scenario.STREET_FIRES`): seven down Kaiserstraße from Moselstraße to Gallusanlage, about 60 m apart; one among the
  bank's stalls by its gate, and one on its plaza by the entrance.

## What the hero sees

- **The money bar over every head** (`engine/core/wealth.gd`). A notch per order of magnitude ($10, $100, $1,000, $10,000), and the
  bar fills toward the next.
- **Chat bubbles** (`npc/agents/chatter.gd`, `npc/agents/lines.gd`). A few lines per kind of person, said now and then.
- **The sky** (`assets/shaders/sky.gdshader`, `DayNight`). A watercolour wash, toon clouds, a sun; stars at night.
- **Warmth indoors** (`engine/systems/heating.gd`). The shops, Mr. Nobody's house, the bus and the shuttle warm whoever is inside.

## The inspector (F3, `user/inspector/`)

A free camera over the live world (the sim keeps running). Click anyone, or N and P to step through, and G to fly to them. The
panel shows their wallet, bars, job, target, route, what they want and what the planner would send them to. If they have stood
still more than 5 s on a job, it says they may be stuck.
