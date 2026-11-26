# Balance: what was measured

Every number here comes from a bench in `tools/`, run headless. The rules are in `docs/ENGINE.md`. When a rule, the atom or the
cluster changes, run the bench again and update the table.

**The target (the user's, for every atom left alone after one funding):** an expected value of zero collapses, and no real
capital formed for at least a month.

## The benches

| tool | what it runs | how long |
|---|---|---|
| `tools/probe_atomic.gd -- [days=60] [founders=N] [full]` | an atom grown through its founders, funded once; who collapses, what is built, everyone's money | seconds (summary), minutes (full) |
| `tools/probe_camp.gd -- camp=0\|1 atoms=8` | 8 atoms for 60 days in summary, with or without a park camp | about 2 min |
| `tools/bench_economy.gd -- [summary] [nodeposit] [gift] [<days>]` | the standard cluster as found, funded once; a row a day, with who collapsed and why | 30 days: about 3 min in full detail |
| `tools/epoch.gd -- [days=365] [every=10] [dt=1] [full] [csv=<path>] [noup] [nofund] [tents=N]` | the cluster for a long time: build-ups, owners' money, the books | a year in about 12 s (summary) |
| `tools/bench_zones.gd` | many towns, as one zone or a zone each, for the cost of a tick | seconds |
| `tools/make_tile.gd -- lat=… lon=… [days=N]` | a tile from anywhere, its atom put down and run | a minute |

## Now (2026-11-25)

An atom grown through its founders (nine people: the keeper, the depot's attendant, a medic, a runner, and the keepers of the
lemonade stand, bakery, thrift stall, camp and hot dog stand), funded once:

| | atom, 90 days, full detail | atom, 60 days, summary | standard cluster, 120 days, summary |
|---|---|---|---|
| collapses | **0** | 2 (thrift seller day 5, tent keeper day 13) | **0** |
| residents' money | each about $15–35, flat | the same | flat after day 40 |
| new money | | | $112, all by day 40 |
| first build-ups (of scrap) | bike camp day 42, hostel day 51 | bike camp day 44, hostel day 51 | the same |
| built with money | nothing | nothing | nothing in 120 days |

## The levers, and what went wrong without each

The money:
- **The deposit carries the town's money round.** What people spend at the stalls goes into the bottle depot's fund as the goods'
  worth (leftovers $0.75, water $0.50) and comes back out only as deposits, about $7 a resident a day. So the recycling fills
  per resident (`WasteBin.KINDS.recycling.per_head`: 0.83 bottles a minute a head, at $1 each). A fixed trickle left an atom's
  fund full and its people collapsing; fewer bottles starved it (at a quarter of today's rate in dollars, 148 to 465 collapses in
  60 days). $1 a bottle, a quarter as many as at $0.25, is the same money for a quarter of the trips.
- **The deposit is a net, not savings** (`Collecting.ENOUGH`, $25): nobody collects with a few days' food money in hand, nor more
  than brings them back up to it. A bin with fewer than `MIN_PICK` (2) isn't worth the walk.
- **A vendor collects only while the working stand needs it** (empty, or unable to pay for a load); one whose stand is wrecked
  waits for the hero. But **the keeper of a stand nobody in town buys from** (the thrift stall, the camp: the hero is their only
  customer) collects whenever short of food money (`Collecting._sells_to_the_town`), and only then (below `Drone.RESERVE`): left
  out, they starved with full shelves; up to $25, they drained the recycling and the only drink's seller went short.
- **A delivery keeps the shop owner's reserve** (`Hauling.spendable`): cash on delivery once took the baker's last dollar.
- **The delivery fee is $0.40 a trip**: at $1 the runner hoarded it and new money had to be printed. A trip waits for `MIN_LOAD`
  (6): topping stalls up a unit at a time, runners made three times the trips.
- **The price ratchet** (`Pricing.BUFFER`): a price once came down only when the shelf was full, and over a season bread went from
  $2.60 to $20. Now a tenth of the shelf left over brings it down.

The people:
- **The town is its founders.** Residents with no trade outgrow the producers: six drifters beside the founders were 100+
  collapses a season, and the cluster has none (`Cluster.DRIFTERS`). Growth must bring producers.
- **Owners eat from their own shelf** (`Needs._own_shelf`): the lemonade seller collapsed of thirst with money in hand.
- **Nobody sets off on a trip they won't last** (`Needs.would_last`): runners went down on the way back from far bins.
- **The recycling is near** (`SiteFinder.BOTTLE_WALK`, 90 m on foot: people walk there for their next meal); the runners' bins may
  be up to 220 m off (`RECYCLE_WALK`: they wheel them).
- **A hot dog fills 0.9 of the hunger bar**: at 0.65 nobody bought one.
- **Beds and posts keep clear of walls, and a tent is left by its door** (`Residence.bed_pos`, `Footprint.door`): whoever woke in a
  wall's margin couldn't plan a way out and starved in place.

The goods:
- **Every garbage pile in a zone shares one bin's rate** (`Lodging._share`): the thrift stall's and the camp's piles at a full rate
  each had the hostel built of scrap by day 14. A park camp has no pile of its own for the same reason.
- **The hostel takes 320 scrap** (about 35 days of a garbage bin, with the tent keeper's wares taking some): not in the first month.
- **The cluster's organics are 1.2 bins' worth** (`Cluster.ORGANICS`): one bin starved a block, 1.5 left every stall at its floor.

## Cost of a tick (`tools/bench_zones.gd`, 2026-11-18)

Cost per 0.1 s tick, for towns of about 13 people:

| towns | one big zone | a zone each, all running | a zone each, only the hero's running |
|---|---|---|---|
| 1 | 0.18 ms | 0.18 ms | 0.17 ms |
| 4 | 1.4 ms | 0.66 ms | 0.18 ms |
| 10 | 13 ms | 1.6 ms | 0.19 ms |
| 20 | 129 ms | 3.3 ms | 0.21 ms |

In one zone the cost climbs much faster than the population (the haul search is roughly cubic), so a zone should stay
town-sized: about 50 people and 3 or 4 supply chains. An hour in summary sells within about 20% of the same hour in full detail.

## Still open

- **A full town is flat**: no business builds up with money in a season; growth is the hero's money, for now. Wanted: a weak,
  steady growth (one lever: a small share of every deposit printed new).
- No downgrades, credit, repossession or foreclosure (undecided).
- A stand that runs out of inputs doesn't change its price (prices only move when something is made).
