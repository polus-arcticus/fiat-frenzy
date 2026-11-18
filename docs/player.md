# The player: what the hero can do

User space: the hero's controls, screens and vehicles. The engine's rules are in `docs/ENGINE.md`.

## Controls

| key | does |
|---|---|
| WASD, Shift, Space | move, run, jump |
| hold left mouse | spray $1 bills (gift), or charge a contract (invest) |
| scroll | switch gift / invest |
| E | open a stand (trading), a tent (its beds), the bus or shuttle door |
| Tab | your bag |
| Q | talk |
| F | on and off the bike |
| B | on and off the skateboard |
| V | first or third person |
| M | the map |
| T | time speed |
| F3 | the inspector |
| Esc | close a screen, or free the mouse |

## The gun (`user/gun/`)

- **Gift** sprays $1 bills, six a second. A bill that hits someone is theirs. One that misses lands in the street as loose cash:
  the hero picks it up by walking over it, and NPCs fetch it within 14 m. That is also how the hero prints money for themselves.
- **Invest**: hold to charge ($25 up to $250 a shot) and release a contract. One that reaches a business buys a share; anywhere
  else it is void.
- Every dollar given is **experience**, for the receiver and for the hero: $50 to level 2, then 1.5× each level
  (`engine/core/growth.gd`). A business levels with its owner: +25% production and more shelf.
- The heroes together own at most **49%** of any business (`engine/core/equity.gd`).
- Bills never end up where nobody can reach them: one that lands in a building is put on the nearest open ground
  (`Navigation.nearest_open`).

## Screens

- **Trading** (E at a stand, `user/view/ui/inventory_screen.gd`). The bag is on the left; the stand's stock and what it wants are on
  the right. Right-click to buy, or to eat and drink. It is paid from the hero's cash.
- **The tent** (E at a tent, `user/view/ui/tent_screen.gd`):
  - its beds, how many are free, its barrels and who sleeps there;
  - add a bed (the gun pays);
  - sit by the barrels to warm up.
- **The map** (M): the whole district, places known, the goal, and the hero. It works from a seat.
- **The pause menu** (Esc): save, chapters, the developer jumps.
- Screens never switch the controls or the mouse themselves: they register with `ScreenStack`, which does.

## The hero (`user/hero/`)

`Hero` is how the hero is moving: on foot, riding, skating or seated, one at a time, always through `Hero.enter`. Third person
(V) hangs a camera 3.4 m behind on a spring arm. The hero's skin is one nobody else wears.

When a bar reaches 0 the hero collapses. The ambulance takes them to the medical tent, and they wake at 95% but robbed of their
cash (`user/hero/collapse_controller.gd`).

## Vehicles

- **The bike** (`user/bike/`): $3,000 at the shop; about 2.4× walking; no sprint, jump or gun.
- **The skateboard** (`user/skating/`): $120.
  - W pushes (up to 12 m/s), S brakes, A/D steer.
  - Hold Space and let go to ollie. Tap Space in the air for a kickflip, which sprays $25 (printed, and counted).
  - A wall stops it dead.
- *(To come)* a slow skateboard and a slow bike from the homeless camps, cheap (see `docs/ENGINE.md` §1.3).

## What the hero sees

- **The money bar over every head** (`engine/core/wealth.gd`). A notch per order of magnitude ($10, $100, $1,000, $10,000), and the
  bar fills toward the next.
- **Chat bubbles** (`npc/agents/chatter.gd`, `npc/agents/lines.gd`). A few lines per kind of person, said now and then.
- **The sky** (`assets/shaders/sky.gdshader`, `DayNight`). A watercolour wash, toon clouds, a sun; stars at night.
- **Warmth indoors** (`engine/systems/heating.gd`). The shops, Mr. Nobody's house and the bus warm whoever is inside.

## The inspector (F3, `user/inspector/`)

A free camera over the live world (the sim keeps running). Click anyone, or N and P to step through, and G to fly to them. The
panel shows their wallet, bars, job, target, route, what they want and what the planner would send them to. If they have stood
still more than 5 s on a job, it says they may be stuck.
