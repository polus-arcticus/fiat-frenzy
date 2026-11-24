# The engine

The rules of Fiat Frenzy's simulation, stated once, each with the code that implements it. A rule that is not here is either a
detail of one feature (see the feature's own file comment) or story (see `docs/story.md`). Anything marked *(to come)* is designed
and not built.

The engine is headless: no nodes, no input, no rendering (`tests/sim/test_architecture.gd` checks it). Views read it; controllers
call it. Its code is in `engine/`, and what agents decide (needs, errands, hauling) is in `npc/`, on top of it (see "The four spaces" in
`docs/review.md`).

## 1. Things

**1.1 World.** The one container of state and the owner of every system (`engine/world.gd`). It holds lists of agents and assets,
the clock, the ledger, and the systems. Nothing in the engine holds a node.

**1.2 Agent** (`Drone`, `engine/entities/drone.gd`). Someone in the town: the hero, a drifter, a vendor, a cart runner, the
bottle depot's attendant, a medic, a story character. An agent has:
- **needs**: three bars, `hunger`, `thirst` and `warmth`, from 0 to 1 (§3.1);
- a **wallet** (dollars, a plain number);
- a **position** and a **zone** (§6);
- a **job**: the errand it is on (§3.3), or none;
- a **home** (`bed`: the residential asset it sleeps in) and **work** (`stand`: the commercial asset it runs), or none;
- **growth**: experience and level, which is money the hero has given it (`engine/core/growth.gd`).

Flags: `needless` (its bars stay full: the rich shop owners, the depot's attendant, story characters), `aloof` (takes part in no
errands),
`care` (`""` fit, `down`, `carried`, `patient`: §3.6).

What only some agents have is a **component**, null on the rest, saved and merged by its own `MERGE` table: `runner` (a
`Runner`: a cart runner's business, §4.4). What people last said is the chatter's (`Chatter.of`, a `Speech`), not saved.
Assets follow the same rule: a tent city's homes are its `residence` (§3.5).

**1.3 Asset** (`Premises`, `engine/entities/premises.gd`). Property in the town: a stand, a tent, the bottle depot, a first aid post.
Every asset has an `owner` (an agent's uid), a `zone`, a place (`pos`, and `front`, the way it faces the street), and is a
**trade at a tier**: its `kind` is a Catalog id, and `trade` and `tier` say where that kind stands on its ladder (§2). Its
footprint is solid (`solid()`, `engine/core/footprint.gd`).

The classes of asset:

| class | what it does | code |
|---|---|---|
| commercial | crafts an item from its inputs and sells it (§3.2, §4) | `Machine` (`engine/entities/machine.gd`) |
| residential | houses agents and warms them at night (§3.5) | `Machine` with a `Residence` (`engine/lodging/residence.gd`: its row of tents and their `Shelter`); it still crafts and sells the keeper's wares |
| money | the bottle depot: pays the deposit on bottles handed in, out of the town's fund (§5.1) | `BottleDepot` (`engine/deposit/bottle_depot.gd`) |
| medical | looks after the collapsed: a medic's first aid post (one bed; the medic tends those down nearby), then the medical tent (beds and an ambulance) | `Hospital` (`npc/medical/hospital.gd`) |
| camp | the salvage trade: a homeless camp turns scrap into an old skateboard (tier 0); built up of scrap, a bike camp makes an old bike (tier 1). Both are sold to the hero at a flat price, cheap and slow (`ItemDef.speed`) | `Machine`, pitched with its pile by `Camp` (`engine/salvage/camp.gd`) |
| clothing | a thrift stall stitches old coats from scrap (tier 0). Built up with money, it becomes a clothing shop that makes coats (still of scrap, until there is a cloth trade). Flat prices: the hero is the buyer, for now. In a custom game the first arrival to an atom's tent city is its keeper (`Lodging.FOUNDERS`), then a camp's | `Machine`, pitched with its own pile by `Camp.pitch` |

**1.4 Resource.** Something that can be held in an inventory: an **item**, defined once in the Catalog (`ItemDef`), with a
class: `food`, `drink`, `material`, `warmth`, `vehicle`, `board`, `clothes`, `document`.
- An item may *restore* a bar (food, drink).
- It may be *scavenged*: the town's base inputs gather in its bins (§4.3): scrap, recyclables (bottles), leftovers, water.
  Leftovers and water have a worth the stalls pay into the town's fund on delivery; scrap is free; a bottle is worth its deposit.
  The van brings leftovers and water too, free.
- It may be **gear** (`gear`): ridden or worn, in a loadout slot (bikes, boards, clothes). A ride has a `speed`, and clothes have
  `insulation`, which makes a warmth bar last longer in the open (§3.1).

**Money is not an item**: it is a number on a wallet, a hero's pocket, or a bill (§5).

**1.4a The one root: what the town throws away.** At tier 0 everything is made of what is salvaged from the bins: food and drink of
leftovers and water (or of another tier 0's ware: the hot dog stand's bread), everything else (boards, coats, tents) of scrap.
Higher tiers may take other inputs as supply chains grow. `test_trades` checks this rule.

**1.5 Inventory** (`engine/core/inventory.gd`). Counts of items, with per-item capacities. An asset's output inventory *offers*
items (`offer`) and its input inventory *wants* them (`want`); these flags are what supply searches read. Stacks of ten make
slots (`engine/core/stacks.gd`).

**1.6 Catalog** (`engine/core/catalog.gd`). All data: every item (`ItemDef`) and every kind of asset (`MachineDef`), each fact in one
place. (A bin's kinds are in `WasteBin.KINDS`, the one place their rates are set.) Systems read it and never redefine a number in it.

## 2. Ladders: trades and tiers

**2.1** `Catalog.TRADES` names every trade and its tiers in order, by Catalog id. It is the only place that says what climbs to
what. `""` is a tier not built yet. The full ladders, with what each tier should add, are in `docs/upgrade_trees.md`.

**2.2** Each tier has a **build cost** (`MachineDef.build`). An asset climbs one tier when its owner pays the cost of the next
(`Trades`, `engine/systems/trades.gd`):
- at dawn, if the owner has the build cost **plus a float** (`Trades.float_for`: their reserve, and a full input store at base
  prices for the new tier);
- if the asset is working, and the owner is fit and has needs;
- the money is **sunk** (`Ledger.sunk`), like a repair.

**2.3** A climbed asset keeps its uid, owner, place, level, the hero's stakes and its takings (`Machine.retier`). If its item
changes, the old stock goes and the new tier opens with one unit.

**2.4** Nothing comes back down. There is no rent, no tax, no loan, no repossession.

**2.5 Built of scrap.** A tier may instead cost scrap (`MachineDef.build_scrap`): the hostel (320) and the bike camp (60).
- The tier below then has room for that scrap in its input (`Machine.set_level`), on top of its recipe's.
- Runners pool scrap into it (§4.4); the keeper pays only their fee.
- At dawn, once that much is in hand beyond what its recipe keeps, the scrap is used and the asset climbs (`Trades.build`).
  No money is sunk.

Commercial stands are paid in money (2.2); residential assets and camps are paid in scrap. *(A tier costing both is not used yet.)*

## 3. Agents: what they want and do

**3.1 Needs** (`npc/agents/needs.gd`). Bars fall with time: hunger in `HUNGER_SECONDS`, thirst in `THIRST_SECONDS`, warmth
`NIGHT_COOLING / DAY_COOLING` times faster at night. Heat sources add warmth: every barrel fire in range by an inverse-square
falloff (`Shelter.gain_at_sq`), being indoors (`Heating`: shops, houses, the bus and the shuttle), and lying in one's own bed
(`Shelter.warm_rate`). A bar at 0 is a collapse (§3.6).
- **The cold is per drone** (`Drone.cold_spans`: how many seconds a full bar lasts in the open by day and at night; zero is the
  street's hardened usual, `DAY_COOLING` and `NIGHT_COOLING`). Whoever feels it harder also warms that much faster at a heat
  source, so a fire still fills the bar in moments. The hero's is short (`user/hero/cold.gd`).
- **Clothes** stretch the span: it is divided by `1 - Drone.insulation()` (the gear's `insulation` added up, at most
  `MAX_INSULATION`).
- Every atom has a barrel fire by its market (§8.0); its own people are housed, so it is for strangers. A vendor in need takes one of their own stand's items, free (`Needs._own_shelf`).

**3.2 Demands** (`Needs.demands`), in order:
1. **survival**: `food`, `drink`, `warmth` for each bar below `NEED_BELOW` (warmth also below `NIGHT_SEEKS_WARMTH` at night),
   lowest bar first;
2. **vocation**: `repair` (a vendor whose stand is wrecked, who can pay for the repair and keep `RESERVE`), else `restock` (their
   stand is short of a bought input);
3. `haul` for a runner;
4. `collect`: bottles to the depot, for anyone short of cash (`Collecting`, §5.1);
5. `cash`: loose money within `Cash.SCAN`.

Survival comes first only when something can answer it: one who is hungry and can't pay for food goes on to the next demand (to
collect bottles, say).

**3.3 Planning** (`Logistics.plan`, `npc/agents/logistics.gd`). An idle agent takes the first demand that some supply in its
own zone can answer, and makes it its job:
- **food or drink**: the open asset with the best value, `price / restores + DISTANCE_COST × distance + WAIT_COST × queue`, that
  the agent can afford (`Supply.best_supply`);
- **warmth**: its own tent, if the tent city is standing, else the nearest fire with a free spot (`Supply.warmth_job`);
- **restock**: the cheapest offer of the short input, keeping `RESERVE` (`Supply.restock_job`);
- **haul**: a load from a bin to whatever wants it most (`Hauling.haul_job`);
- **collect**: the nearest recycling bin with bottles, then the zone's depot (`Collecting.job`);
- **repair**, **cash**: their own stand, the nearest loose bill.

Nobody sets off on a haul or a bottle run longer than their bars will last (`Needs.would_last`: the walk, reckoned at `DETOUR`
times the straight line, within `TRIP_MARGIN` of what is left of hunger and thirst). They stay near the market and eat first.

**3.4 Carrying out** (`Logistics.act`, `complete`). The agent walks to its stand point (`Walking`, `Navigation`), queues if the
target serves one at a time (`Queueing`), and completes: pays the price (the owner gets it less the heroes' stakes,
`pay_supplier`), takes the item and uses it (`Needs.eat`), or repairs (money sunk), or lies down, or picks up the bill. A job that
is no longer valid (sold out, room gone) is dropped and planned again. Pace follows need (`Needs.pace`). Someone inside a tent
(the medic at the first aid post) leaves by its open front (`Footprint.door`) before the way is planned.

**3.5 Homes: the tent city** (`Lodging`, `engine/lodging/lodging.gd`). The tent keeper's business (the "tent" kind) is the
cluster's **spawn factory**:
- It is tents for one person each, and it stands from the start.
- Everyone in the zone has a tent in it (`Drone.bed`, `Lodging.house_everyone`), the depot's attendant included and the story's
  scripted cast left out. While it stands, a tent keeps its person warm, day and night (`Lodging.is_housed`).
- Its tier holds at most `cap` tents: the first tier an atom's worth (§8.0). A bigger layout gets `Residence.tents_cap`. Growing
  past the cap means building it up (the hostel).
- Putting up a tent (`add_tent`, $15, the gun pays) brings a **newcomer** within `ARRIVE_EVERY` seconds, while the tent city
  stands (§5.3). Who comes is a weighted roll (`Lodging.NEWCOMERS`: drifters and runners for now; more kinds as they exist).
- So the number of tents is the population. Nobody is turned out.

- Its keeper makes **tents** and **barrel fires** from scrap and sells them (its wares, §4.1). A tent put down in the street
  (`Lodging.found`) is a new tent city at tier 0, standing, one tent, kept by a newcomer who lives in it; a barrel fire put down
  is a barrel fire. (The hero does the putting down: `user/hero/placing.gd`.)
- Each resident has a story for their ID card (`npc/agents/biography.gd`, from dice seeded with their uid) and `arrived_at`.

**3.6 Collapse and care** (`npc/medical/rescue.gd`). A bar at 0 and the agent is `down`. An idle ambulance carries them to the
medical tent in their zone; care refills the bars and lets them go at 60% (the hero at 95%, five times as fast, but robbed of
their cash).

## 4. Production and prices

**4.1 Crafting** (`Machine.step`, `craft`). A working commercial asset makes its item at `rate` crafts a minute (25% more per
level) if every input of the recipe is in its input inventory and its shelf has room. A wrecked one makes and offers nothing.
- **Wares** (`MachineDef.wares`): other things it makes and sells besides its item, each from its own recipe, at the item's flat
  price, on a shelf of `ware_cap`. A craft also makes one ware, the emptiest one its inputs allow. Its input store is sized by
  everything it crafts (`Machine.per_craft`). The tent city and the hostel: tents (4 scrap) and barrel fires (2 scrap).
- What an item is for, when the hero uses one from the bag, is the item's own (`ItemDef.use`: equip, consume, place).

**4.2 The price rule** (`Pricing.after_craft`, `engine/core/pricing.gd`). Once per craft:
- shelf empty → up one `tick` (it sold out: too cheap);
- at least `BUFFER` (a tenth) of the shelf left over → down one tick, never below the floor;
- otherwise it holds.

The **floor** is what the inputs last cost (`Machine.floor_price`). A dearer delivery raises it. A flat-price asset (the story's
shops) never changes its price.

**4.3 The bins** (`WasteBin`, `engine/salvage/waste_bin.gd`). What the town throws away is what it runs on. Three bins, as a German
street has them, and a fountain, each gathering its item at its rate (a minute), up to a cap, free to take:
- **garbage**: scrap (tents, camps, coats; what the hostel is built of);
- **recycling**: recyclables, bottles. It fills with what the people round it drink: its rate is a resident's, times the
  zone's residents (`Zones.heads_in`). Bottles are worth their deposit at the depot (§5.1);
- **organics**: leftovers, the food stalls' one input;
- **fountain**: water, the lemonade stand's.

An atom lays out a station of the three and a fountain (`World.add_bin_station`). On a tile, each kind is at the map's own where
it has one near the market (`SiteFinder.bins`, `TileLanding._place_bins`): waste baskets, recycling containers, organics bins
(recycling that takes food or compost), drinking fountains, at most `RECYCLE_MOST` of a kind, sharing the one bin's rate. The
runners' kinds may be up to `RECYCLE_WALK` off; the recycling, which everyone short of cash walks to, only `BOTTLE_WALK`. A
bin on the map draws only what has gathered in front of it: the city draws the container (`StreetThings`).

The **Red Cross van** (`Relief`) brings `load_per_good` of leftovers and water twice a day, free, shared equally among the working
assets that want it.

**4.4 Hauling** (`npc/agents/hauling.gd`). A runner takes a load from a bin (up to `CART_CAPACITY`, free) and wheels it to the
shop that wants it. **Cash on delivery:** the shop pays the goods' worth into the town's fund (`Deposit.fund`, the depot's
attendant's wallet) and a flat `DELIVERY_FEE` ($0.40) to the runner for the trip, whatever the load; the fee is the runner's
income.
- The fee goes into what the shop's inputs cost it (`cost + fee / units`), so into its floor price (§4.2): a baker's bread carries
  its share of the walk. A bigger load is cheaper a unit.
- **A runner's cart is a business** (`Drone.runner`, a `Runner`: its cart, deliveries, fees and `equity`, worth
  `Runner.CART_VALUE` plus its experience, like a machine's repair cost
  plus its experience). The hero can invest in it (§5.2); every fee is then split, the heroes' shares into their pockets.
- How much a shop holds of each input is `MachineDef.stock_crafts` crafts' worth (6; the lemonade stand and coffee stop 16, a
  cartload: their two goods come on two trips, and at six of each the stand sold out all day).
- Scrap goes to whatever has room for it: a camp's input, or a tent city's build stock (§2.5). The keeper pays only the fee.
- A trip is worth making when the destination is `MIN_LOAD` short and its owner can pay for that much (`Hauling.affordable`).
  Scrap goes as the last few of a store's room too: a build is not left waiting on its last pieces.

## 5. Money

**5.1 Where money comes from.** Only three places, each counted in `Ledger.printed`:
- **the gun**: the hero's gift and investment (`Gun`), the kickflip;
- **the seed**: what the map is built with, and what a newcomer brings;
- **the deposit** (`Deposit`, `engine/deposit/deposit.gd`; the people's side is `Collecting`, `npc/agents/collecting.gd`):
  whoever has less than `ENOUGH` ($25) walks to the recycling, takes up to `CARRY` bottles (a runner, a cartload), and hands
  them in at the zone's bottle depot for `DEPOSIT` ($1) each, taking only what brings them back up to `ENOUGH`. The depot pays out of the town's fund first (what its stalls
  paid for their leftovers and water: §4.4); only when that is empty is it new money (`Ledger.issued`). A vendor goes only
  while their working stand needs it (empty, or they can't pay for its next load); one whose stand is wrecked waits by it for
  the hero. So new money is walked for, by who needs it, and bounded by how fast the recycling fills. An atom left alone holds
  just above baseline (docs/balance.md).
- **People's names** are real ones (`Names`, picked by uid); what they do is their profession (`World.profession_of`: the story's
  word for them, else their stand's keeper, `Catalog.KEEPERS`, else their kind's), shown under the name.
- **A tile from anywhere** (§8): its map from OpenStreetMap (`OsmImport`, cached by `TileSource`, fetched by
  `TileFetchController`, `tools/make_tile.gd`), its atom where `SiteFinder` puts it (one site per tile, so two players' tiles
  agree), the hero where they chose (`TileLanding`).

**5.2 Where money goes.** It moves only between wallets, the heroes' pockets (`Ledger.pockets`) and bills. It leaves only into
`Ledger.sunk`: repairs, building up, and tents.

**5.3 The invariant.** `World.total_money() == Ledger.printed`, on every tick, in every test that moves money.

**5.4 Stakes** (`engine/core/equity.gd`, bought through `Gun.business_of`). A business is worth its rebuild cost plus its experience. The heroes together own at most
49%. A sale pays each hero their share into their pocket. A runner's cart is a business too: its book is `Runner.CART_VALUE`, and
each delivery fee is split the same way (§4.4). After a merge, both are put back under the cap (`Merge._cap`).

## 6. Time and space

**6.1 The tick** (`World.tick`), in this order:
1. clock;
2. dormant zones in summary;
3. the relief van;
4. assets step (craft; the bins gather);
5. sleepers wake;
6. agents act, in a shuffled order (`World.shuffle`);
7. needs decay;
8. the end-of-tick systems, in `World._end_of_tick`: the engine's are rescue, borders, trades, lodging and chatter (the
   deposit has no turn of its own: it pays when bottles are handed in). The game's world puts the hero first (`Hero`: their needs, their zone, the zones' `focus`) and the bus second, and
   the story's watchers (sage, quests, attention) last.

**6.1a The engine alone.** `World.new(false)` has only the engine's and the people's systems. A headless run needs nothing
else: a bench, the epoch sim, a map of anywhere. Nothing in `engine/` or `npc/` needs a hero. Where one is about, the hero is an
agent like the others (they can collapse, people talk to them), and which zone runs in full detail is `Zones.focus`, which the
hero's system sets.

A game day is `Clock.DAY_SECONDS` (600 s); night falls at `NIGHT_FROM` of it.

**6.2 Zones** (`engine/systems/zones.gd`). Everything belongs to one zone, and every search looks only in the asker's zone. A zone
runs in one of three ways:
- **full detail**: walking, queues, talk;
- **summary** (`TileSummary`): coarse steps of `COARSE_STEP`, with the same plans and completions without the walk; warmth is kept
  by a fire;
- **asleep**: not at all, until the hero arrives.

`active` (empty means all) says which run in full. Zones meet only
through named ways: rings (`Portals`), `Zones.send`, and the borders between tiles (`Borders`). Money crosses only in wallets.

**6.3 Places.** Positions are metres on the ground plane. A tile is a zoom-16 web-map tile, and positions are metres in its
zoom-10 region (`engine/core/tile_key.gd`). Agents walk on half-metre grids per zone that hold every footprint and building
(`Navigation`), along streets when there is a road graph (`Walking`).

## 7. Determinism, names, saves

**7.1 Dice.** The engine rolls only `World.rng`, and while seeding, a zone's own dice (`World.random()`, seeded by the zone's name).
Never the global `randf` (checked by `test_architecture`).

**7.2 Names** (`World.mint`). Seeded things are `<zone>#<n>`; things made in play are `<author>/<n>`. References between things
are uids.

**7.3 Saves** (`engine/core/snapshot.gd`). The state of a started world, laid over a fresh build of the same map: every script
variable of the things in the world's lists and of the saved systems, by uid.

**7.4 Merge** (`engine/core/merge.gd`). Two saves, three-way against their common seed. Each class's `MERGE` table says how a field
combines (`sum`, `max`, `any`, `union`, else the host's), and `Merge.settle` puts right what adding up can break (stake caps, shelf
room, tiers, levels). The merged world holds exactly host + guest − seed in money.

## 8. Clusters

**8.0 The atom** (`Atom`, `engine/core/atom.gd`). The seed of every new tile, the smallest town that keeps itself going. It has
one of each role, each with a tent:
- the tent keeper (the tent city);
- a bakery and a lemonade stand;
- two runners;
- the bottle depot's attendant;
- a medic with a one-bed first aid post;
- and its bins: a station of garbage, recycling and organics, and a fountain (on a tile, the map's own where it has them, §4.3).

There are no drifters and no van. `Atom.seed(w, zone, at, site)` puts one down, found: the tent city standing, the stands
wrecked, the owners broke. On its own it has no collapses in 120 days. Growth by mouths alone does not hold (§5.3), so growth must
roll producers too. The tutorial's town is a special case: a grown cluster (8.1) plus the story.

**8.1 The standard cluster** (`Cluster`, `engine/core/cluster.gd`). The people a block starts with, defined once:
- four trades at tier 0;
- its bins (garbage, recycling, two organics bins sharing `Cluster.ORGANICS` bins' worth, a fountain) and two runners;
- six drifters;
- a barrel fire and a medical tent;
- the van's stop and a bottle depot.

It is laid out along a street site, everyone housed. It is found wrecked and broke (`found`), and the hero gets it going
(`fund`).

**8.2 Its balance** (`docs/balance.md`). With bottles at $1 and the recycling filling per resident, a funded cluster runs 120
days with no collapses, its tent city built up into a hostel on day 41 (`tools/epoch.gd`, the season test). Changing what is in it
means measuring again.

**8.3 Where clusters stand** *(to come)*. On a map of anywhere, the engine will place clusters on the map's own blocks (buildings with
touching walls), each laid out on a street site (`Cluster.open_site` is the shape of one). A per-block spawner was built once
and taken out (2026-11-18). The town grows by its tents instead.
