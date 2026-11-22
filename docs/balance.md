# Balance: what was measured

Every number here comes from a bench in `tools/`, run headless, with what was measured written next to it. The rules are in
`docs/ENGINE.md`. When a rule or the standard cluster changes, run the bench again and update its table.

## The benches

| tool | what it runs | how long |
|---|---|---|
| `tools/bench_economy.gd -- [summary] [nowelfare] [gift] [<days>]` | the standard cluster as it is found, funded once by the hero; a row a day, with who collapsed and why | 30 days: about 3 min in full detail, under a second in summary |
| `tools/epoch.gd -- [days=365] [every=10] [dt=1] [full] [csv=<path>] [noup] [nofund] [tents=N]` | the same, for a long time: build-ups, owners' money, the books | a year in about 12 s (summary) |
| `tools/bench_equilibrium.gd` | two saves merged (one town with a food bank, one without) | 6 hours of play |
| `tools/bench_zones.gd` | many towns, as one zone or a zone each, for the cost of a tick | seconds |
| `tools/probe_*.gd` | one question each (stuck walkers, summary against full detail, the tent) | seconds |

## The welfare office's rate

The one knob is `Welfare.DOLLARS_A_DAY`. Whatever the fountain gives, people spend at the stands, so vendors gain about as fast
as it pours. Aiming it at the poor only changes how many collapse on the way. The aim is no collapses, the odd one being fine.
30 days of the bench town:

| `DOLLARS_A_DAY` | collapses in 30 days | vendors gain a day |
|---|---|---|
| 5 | 58 | about $15 |
| 6 | 28 | about $25 |
| **12 (chosen)** | **0** (1 in the dormant town) | **about $40** |

(The 5 and 6 rows were measured before the supply fixes below.)

## The atom: just above baseline (2026-11-21)

The user's target for an atom left alone after one funding: **an expected value of zero collapses, and no real capital formed
for at least a month.** Measured over 8 atoms with different dice, 60 days each, in summary (the probe is in the session
notes; `tools/probe_atomic.gd` runs one):

| | before | now |
|---|---|---|
| collapses per atom | 0.25 (the baker, days 1–5) | **0.00** |
| residents' money, day 0 → day 30 | $138 → ~$480 (the runner hoarding ~$8 a day) | $138 → ~$168, then flat |
| money issued by the welfare office | ~$590 in 45 days | ~$95 in 60 days |
| the first building (the hostel) | day 24 | **day 36** (day 41 since the camp kits: below) |

What changed:
- **A runner's delivery keeps the shop owner's reserve** (`Hauling.spendable`): cash on delivery took the baker's last dollar
  for flour, and the baker went thirsty.
- **The delivery fee is $0.40 a trip**, just above what a runner needs to eat and drink (about $7 a day over ~22 trips). At $1
  the runner earned twice that, the stands paid it, and the fountain printed to keep them fed.
- **The welfare office is a net, not savings** (`Welfare.ENOUGH`, $25): it gives only to someone with less than a few days'
  food money. Given to everyone, it printed about $10 a day into a town that was getting by.
- **The hostel takes 320 scrap** (it was 200), about 35 days of a pile's scrap.

The standard cluster (with its drifters, who have no income) still has 0 collapses in 120 days, and its stands build up out of
their own trade (the burger bar on day 16, the bake shop on day 31, the hostel on day 36). **Open:** the lemonade stand's
margin is too thin to build up to a coffee stop in a season now that welfare does not fill its savings. That is for the
growth tuning (SimCity-like balanced growth), left for later.

### With a park camp (2026-11-22)

A tile whose park is near the market gets a homeless camp at landing (a scrap camp with its own fire, its keeper living by
it). `tools/probe_camp.gd -- camp=0|1`, 8 atoms x 60 days in summary:

| | no camp | with a camp |
|---|---|---|
| collapses per atom | 0.00 | **0.00** |
| residents' money, day 0 → 30 → 60 | $138 → $169 → $169 | $163 → $212 → $212 (flat after day 30) |
| issued by the welfare office in 60 days | ~$96 | ~$114 |
| built | the hostel, day 41 | the bike camp day 41, the hostel day 47 |

What it took:
- **A camp near enough on foot** (`SiteFinder.CAMP_WALK`, 90 m along the streets). The first try put it in a riverside park
  103 m away, a 300 m walk round: the runner hauling its scrap and its keeper fetching food ran dry on the way (the runner
  went down every few hours).
- **No scrap pile of its own.** With one, the runner hauled twice as much: the bike camp came on day 19 and the hostel on
  day 23 (capital in the first month), and the runner held $61 of fees.
- The tent keeper's **camp kits** (a third ware of scrap) moved the hostel from day 36 to day 41, in either case.

## The standard cluster over 30 days

`tools/bench_economy.gd`: all stalls wrecked and vendors broke; the hero pays each repair once, then leaves.

| | no welfare office | welfare office |
|---|---|---|
| sales a day, day 1 / 10 / 30 | 74 / 9 / 10 | 81 / 76 / 74 |
| collapses in 30 days | 514 (about 20 a day from day 5) | 0 |
| vendors' money, day 10 / 30 | $17 / $148 (the keeper holds the rest) | $355 / $703 (after $250 into building up) |
| prices, day 30 | at the floor | at the floor (lemonade $1.60) |
| new money from the fountain | — | $1,768 |
| money not accounted for | 0 | 0 |

In summary (dormant), the same town has 1 collapse in 30 days (on day 1).

## A year (`tools/epoch.gd`)

| | |
|---|---|
| burger bar built | day 20 |
| bake shop | day 28 |
| coffee stop | day 71 |
| hostel | day 106 (every trade at tier 1) |
| collapses in 365 days | 0 (also 0 in full detail over 150 days) |
| printed in a year | $20,940: $333 by the hero, $20,607 by the fountain |
| sunk into building up | $950 |
| day 365 | residents hold about $9,900, owners about $9,900 |

- **After every trade is at tier 1, money piles up.** The fountain gives about $12 a resident a day and people spend about half.
  Higher tiers are where it should go.
- **Unfunded** (`nofund`): 99 collapses in the first 5 days and 6 more by day 10, while the fountain's gifts (the broke owners are
  the poorest) pay for the repairs. After that it runs like a funded one. Funding a block when it is found spares it that week.
- **More people** (`tents=N`; measured with the earlier bed-cap prototype): +8 gives about 250 collapses every 30 days, and +20 about 900. Supply
  can't feed the extra people; prices climb and the money pools with the bread and drink sellers. Growing the population means
  growing supply with it. Parked: no scaling of NPCs or food balance for now.

## What the benches found and fixed

- **The price ratchet.** A price came down only when the shelf was full, then half full. A stand short of inputs never got there,
  so every sell-out added a tick for good. Over a season bread went from $2.60 to $20 and the town starved about every 90 days.
  Now a tenth of the shelf left over brings it down (`Pricing.BUFFER`).
- **Thin supply.**
  - Flour is 3.6 a minute (it was 2.4: bread was capped at 25 a day, and the hot dog stand took 22).
  - Sugar and water are 3.0.
  - Any thin margin turns into a shortage, then a price climb, then collapses.
- **Owners eat from their own shelf** (`Needs._own_shelf`). The lemonade seller used to collapse of thirst with money in hand.
- **A hot dog fills 0.9 of the hunger bar.** At 0.65 nobody ever bought one.
- **Beds away from the walls** (`Machine.bed_pos`). A bed in the margin that Navigation keeps round a wall left whoever woke there
  unable to plan a way out; they starved in place (20 collapses in 5 days).

## Two saves merged (`tools/bench_equilibrium.gd`)

Save A is a town with no food bank; save B, the tile east of it, has one.
- Without welfare offices the merged towns **stall**: B's runners go broke ($1.29 between them), the food bank sits full while the
  shops are empty.
- With an office in each, people keep moving toward B (by hour 6, 20 of the 25 are there), carts cross now and then, and no tick
  is ever off. One food bank for 20 people is short, though: B's food costs $10 to $14. (Measured before the flour and price
  fixes.)

## Cost of a tick (`tools/bench_zones.gd`)

A town is about 13 people: 4 stands, a food bank, 2 runners, 6 drifters. Cost per 0.1 s tick:

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

- No downgrades, credit, repossession or foreclosure (undecided).
- A stand that runs out of inputs doesn't change its price (prices only move when something is made).
