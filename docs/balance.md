# Balance: what was measured

Every number here comes from a bench in `tools/`, run headless, with what was measured written next to it. The rules are in
`docs/ENGINE.md`. When a rule or the standard cluster changes, run the bench again and update its table.

**The target (the user's, for every atom left alone after one funding):** an expected value of zero collapses, and no real
capital formed for at least a month.

## The benches

| tool | what it runs | how long |
|---|---|---|
| `tools/probe_camp.gd -- camp=0\|1 atoms=8` | 8 atoms for 60 days in summary, with or without a park camp: collapses, builds, residents' money, new money | about 2 min |
| `tools/bench_economy.gd -- [summary] [nodeposit] [gift] [<days>]` | the standard cluster as it is found, funded once by the hero; a row a day, with who collapsed and why | 30 days: about 3 min in full detail, under a second in summary |
| `tools/epoch.gd -- [days=365] [every=10] [dt=1] [full] [csv=<path>] [noup] [nofund] [tents=N]` | the same, for a long time: build-ups, owners' money, the books | a year in about 12 s (summary) |
| `tools/bench_equilibrium.gd` | two saves merged (one town with its bins and runners, one without) | 6 hours of play |
| `tools/bench_zones.gd` | many towns, as one zone or a zone each, for the cost of a tick | seconds |
| `tools/probe_*.gd` | one question each (an atom grown by tents, runners making progress, routes, summary against full detail) | seconds |
| `tools/make_tile.gd -- lat=… lon=… [days=N]` | a tile from anywhere, its atom put down and run | a minute |

## The waste economy (2026-11-23)

The town runs on what it throws away (`WasteBin`): scrap from the garbage, bottles from the recycling, leftovers from the
organics, water from the fountains. Runners haul the scrap, leftovers and water to the stalls; the stalls pay the goods' worth
(leftovers $0.75, water $0.50) into the town's fund, the bottle depot's till. Whoever is short of cash takes bottles to the depot
for $1 each, taking only what brings them back up to $25, paid from the fund first and new money only when it is empty
(`Deposit`, `Collecting`).

| | atom, 8 × 60 days | atom with a park camp | standard cluster, 120 days | the tile by the Main, 20 days in full detail |
|---|---|---|---|---|
| collapses | **0** | **0** | **0** | **0** |
| residents' money | $138 → $163 at day 30 → $163 | $163 → $186 → $187 | everyone about $25–30 | $161 at day 20 |
| new money | $90 an atom | $89 an atom | $212 | $88 |
| bottles handed in | 42 a day | | | 922 in 20 days |
| first build-up | hostel, day 41 | bike camp day 46, hostel day 51 | hostel, day 41 | none in 20 days |

The welfare office it replaced printed $94 an atom and $211 in the cluster's season: the books came out about the same.

**How many cans (2026-11-23).** The bottles carry the whole economy's money back round: what people spend at the stalls goes
into the fund as the goods' worth, and comes back out only as deposits, about $42 a day in an atom. So the number of bottles
can't simply be cut. At $0.25 a bottle (3.3 a minute a resident) the atom collected 168 a day, and in the story's Frankfurt a
drifter spent 27% of their time on bottle runs. Lowering the rate starved it (`.godot/probe/probe_bottles.gd`):

| bottles a minute a resident, at $0.25 | collapses an atom in 60 days |
|---|---|
| 3.3 | 0 |
| 2.0 | 148 |
| 1.2 | 354 |
| 0.8 | 465 |

Instead each bottle is worth $1, a quarter as many come (0.83 a minute a resident, a bin of 50 opening with 30), and people
take only what brings them back up to $25 (a whole bag at $1 overshot: money went $138 → $215 in a month). The same dollars
flow, with a quarter of the trips: a drifter's bottle runs fell to 15% of their time, a runner's from 8% to 4%.

## What the measurements taught

The levers, each with what went wrong without it:
- **The recycling fills per resident** (`KINDS.recycling.per_head`: 0.83 bottles a minute a head, at $1). Spending at the
  stalls comes back to people only through the deposit, about $7 a resident a day. A fixed 5 bottles a day left an atom's fund full and its
  people collapsing about daily; the 20 a minute that kept an atom going left a block of 13 collapsing daily, its fund at $144.
- **The recycling is near** (`SiteFinder.BOTTLE_WALK`, 90 m on foot). The map's containers 200 m off cost 8 collapses in 20
  days: people walk there for their next meal. The runners' bins may be up to 220 m off (`RECYCLE_WALK`): they wheel them.
- **Nobody sets off on a trip they won't last** (`Needs.would_last`). Runners wheeling scrap from 200 m off went down on the way
  back, having set out half empty (12 collapses in 20 days; 0 after).
- **A vendor collects only while the working stand needs it**: empty, or unable to pay for a load of its inputs (the baker sat at
  the $10 reserve with bread on the shelf, and the leftovers never came). One whose stand is wrecked waits by it for the hero.
- **The cluster's organics are 1.2 bins' worth** (`Cluster.ORGANICS`): one bin starved its 13, 1.5 or more left every stall at
  its floor price, earning nothing.
- **A delivery keeps the shop owner's reserve** (`Hauling.spendable`): cash on delivery once took the baker's last dollar, and
  the baker went thirsty.
- **The delivery fee is $0.40 a trip**, just above what a runner needs to eat and drink. At $1 the runner earned twice that and
  hoarded it, and new money had to be printed to keep the stalls going. A trip waits for `MIN_LOAD` (6): topping stalls up a
  unit or two at a time, the runners made three times the trips the town needed.
- **The deposit is a net, not savings** (`Collecting.ENOUGH`, $25): nobody collects with a few days' food money in hand, and
  nobody takes more bottles than bring them back up to it (`Collecting.needed`). A bin with fewer than `MIN_PICK` (2) isn't
  worth the walk: at 4, a broke medic lost every race for the trickle.
  Given to everyone, the welfare office's money printed about $10 a day into a town that was getting by.
- **The hostel takes 320 scrap** (about 35 days of a garbage bin), and the tent keeper's camp kits take some of it too: the
  hostel comes on day 41, not in the first month.
- **A camp is near the market on foot** (`SiteFinder.CAMP_WALK`, 90 m), and has no garbage bin of its own: one 300 m round
  starved its runner, and its own bin doubled the scrap (the bike camp on day 19, capital in the first month).
- **The price ratchet** (`Pricing.BUFFER`): a price came down only when the shelf was full, so every sell-out added a tick for
  good, and over a season bread went from $2.60 to $20. Now a tenth of the shelf left over brings it down.
- **Owners eat from their own shelf** (`Needs._own_shelf`): the lemonade seller collapsed of thirst with money in hand.
- **A hot dog fills 0.9 of the hunger bar**: at 0.65 nobody bought one.
- **Beds and posts keep clear of walls, and a tent is left by its door** (`Machine.bed_pos`, `Footprint.door`): whoever woke in
  a wall's margin, or the medic in the first aid tent, couldn't plan a way out and starved in place.
- **More people need more supply.** Tents alone (`tents=N`) brought collapses by the hundred: the bins can't feed the extra
  mouths. Growing the population means growing supply with it (parked: docs/upgrade_trees.md, the waste ladder).

## Cost of a tick (`tools/bench_zones.gd`)

A town is about 13 people: 4 stands, their bins, 2 runners, 6 drifters. Cost per 0.1 s tick (measured 2026-11-18):

| towns | one big zone | a zone each, all running | a zone each, only the hero's running |
|---|---|---|---|
| 1 | 0.18 ms | 0.18 ms | 0.17 ms |
| 4 | 1.4 ms | 0.66 ms | 0.18 ms |
| 10 | 13 ms | 1.6 ms | 0.19 ms |
| 20 | 129 ms | 3.3 ms | 0.21 ms |

In one zone the cost climbs much faster than the population (the haul search is roughly cubic), so a zone should stay
town-sized: about 50 people and 3 or 4 supply chains. With the rest in summary, a tick costs 0.26 ms at 10 towns and 0.27 ms at
20. An hour in summary sells within about 20% of the same hour in full detail, with the money exact (`tests/sim/test_tiles.gd`).

## Still open

- No stall builds up of its own takings in a season (the lemonade stand gets about halfway to a coffee stop). Growth is for the
  hero to hurry, for now.
- No downgrades, credit, repossession or foreclosure (undecided).
- A stand that runs out of inputs doesn't change its price (prices only move when something is made).
