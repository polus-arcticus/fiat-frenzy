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

**1.2 Agent** (`Drone`, `engine/entities/drone.gd`). Someone in the town: the hero, a drifter, a vendor, the food bank's keeper, a
cart runner, the welfare office's clerk, a story character. An agent has:
- **needs**: three bars, `hunger`, `thirst` and `warmth`, from 0 to 1 (§3.1);
- a **wallet** (dollars, a plain number);
- a **position** and a **zone** (§6);
- a **job**: the errand it is on (§3.3), or none;
- a **home** (`bed`: the residential asset it sleeps in) and **work** (`stand`, `bank`: the commercial or supply asset it runs), or
  none;
- **growth**: experience and level, which is money the hero has given it (`engine/core/growth.gd`).

Flags: `needless` (its bars stay full: the rich shop owners, the clerk, story characters), `aloof` (takes part in no errands),
`care` (`""` fit, `down`, `carried`, `patient`: §3.6).

**1.3 Asset** (`Premises`, `engine/entities/premises.gd`). Property in the town: a stand, a tent, the food bank, the welfare office.
Every asset has an `owner` (an agent's uid), a `zone`, a place (`pos`, and `front`, the way it faces the street), and is a
**trade at a tier**: its `kind` is a Catalog id, and `trade` and `tier` say where that kind stands on its ladder (§2). Its
footprint is solid (`solid()`, `engine/core/footprint.gd`).

The classes of asset:

| class | what it does | code |
|---|---|---|
| commercial | crafts an item from its inputs and sells it (§3.2, §4) | `Machine` (`engine/entities/machine.gd`) |
| residential | houses agents and warms them at night (§3.5) | `Machine` with a `Shelter` (the tent; its own class *(to come)*) |
| supply | stocks base materials from charity and sells them at cost (§4.3) | `FoodBank` (`engine/relief/food_bank.gd`) |
| money | gives money out (§5.1) | `WelfareOffice` (`engine/welfare/welfare_office.gd`) |
| medical | looks after the collapsed: a medic's first aid post (one bed; the medic tends those down nearby), then the medical tent (beds and an ambulance) | `Hospital` (`npc/medical/hospital.gd`) |
| camp | the salvage trade: a homeless camp turns scrap into an old skateboard (tier 0); built up of scrap, a bike camp makes an old bike (tier 1). Both are sold to the hero at a flat price, cheap and slow (`ItemDef.speed`) | `Machine`, pitched with its pile by `Camp` (`engine/salvage/camp.gd`) |
| clothing | a thrift stall stitches old coats from scrap (tier 0). Built up with money, it becomes a clothing shop that makes coats (still of scrap, until there is a cloth trade). Flat prices: the hero is the buyer, for now | `Machine`, pitched with its own pile by `Camp.pitch` |

**1.4 Resource.** Something that can be held in an inventory: an **item**, defined once in the Catalog (`ItemDef`), with a
class: `food`, `drink`, `material`, `warmth`, `vehicle`, `board`, `clothes`, `document`.
- An item may *restore* a bar (food, drink).
- It may be *delivered free* (the relief goods: flour, protein, bottled water, sugar).
- It may be *scavenged* (scrap: it lies in the street and runners gather it, §4.4).
- It may be **gear** (`gear`): ridden or worn, in a loadout slot (bikes, boards, clothes). A ride has a `speed`, and clothes have
  `insulation`, which makes a warmth bar last longer in the open (§3.1).

**Money is not an item**: it is a number on a wallet, a hero's pocket, or a bill (§5).

**1.4a The two roots.** At tier 0, food and drink are made from the relief goods. Everything else (boards, coats, …) is made from
**scrap**. Higher tiers may take other inputs as supply chains grow. `test_trades` checks this rule.

**1.5 Inventory** (`engine/core/inventory.gd`). Counts of items, with per-item capacities. An asset's output inventory *offers*
items (`offer`) and its input inventory *wants* them (`want`); these flags are what supply searches read. Stacks of ten make
slots (`engine/core/stacks.gd`).

**1.6 Catalog** (`engine/core/catalog.gd`). All data: every item (`ItemDef`) and every kind of asset (`MachineDef`, `FoodBankDef`),
each fact in one place. Systems read it and never redefine a number in it.

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

**2.5 Built of scrap.** A tier may instead cost scrap (`MachineDef.build_scrap`): the hostel (200) and the bike camp (60).
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
4. `cash`: loose money within `Cash.SCAN`.

**3.3 Planning** (`Logistics.plan`, `npc/agents/logistics.gd`). An idle agent takes the first demand that some supply in its
own zone can answer, and makes it its job:
- **food or drink**: the open asset with the best value, `price / restores + DISTANCE_COST × distance + WAIT_COST × queue`, that
  the agent can afford (`Supply.best_supply`);
- **warmth**: its own tent, if the tent city is standing, else the nearest fire with a free spot (`Supply.warmth_job`);
- **restock**: the cheapest offer of the short input, keeping `RESERVE` (`Supply.restock_job`);
- **haul**: a load from the food bank, or of scrap from a pile, to whatever wants it most (`Hauling.haul_job`);
- **repair**, **cash**: their own stand, the nearest loose bill.

**3.4 Carrying out** (`Logistics.act`, `complete`). The agent walks to its stand point (`Walking`, `Navigation`), queues if the
target serves one at a time (`Queueing`), and completes: pays the price (the owner gets it less the heroes' stakes,
`pay_supplier`), takes the item and uses it (`Needs.eat`), or repairs (money sunk), or lies down, or picks up the bill. A job that
is no longer valid (sold out, room gone) is dropped and planned again. Pace follows need (`Needs.pace`).

**3.5 Homes: the tent city** (`Lodging`, `engine/lodging/lodging.gd`). The tent keeper's business (the "tent" kind) is the
cluster's **spawn factory**:
- It is tents for one person each, and it stands from the start.
- Everyone in the zone has a tent in it (`Drone.bed`, `Lodging.house_everyone`), the welfare clerk included and the story's
  scripted cast left out. While it stands, a tent keeps its person warm, day and night (`Lodging.is_housed`).
- Its tier holds at most `cap` tents: the first tier an atom's worth (§8.0). A bigger layout gets `Machine.tents_cap`. Growing
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

**4.3 Supply** (`FoodBank`). Base materials trickle in at their rate (`Catalog._build_food_bank`), up to a cap, and sell at cost.
The **Red Cross van** (`Relief`) brings `load_per_good` of each relief good twice a day, free, shared equally among the working
assets that want it.

**4.4 Hauling** (`npc/agents/hauling.gd`). A runner buys a load at the food bank (up to `CART_CAPACITY`) and wheels it to the
shop that wants it. **Cash on delivery:** the shop pays back what the goods cost and a flat `DELIVERY_FEE` ($1) for the trip,
whatever the load; the fee is the runner's income.
- The fee goes into what the shop's inputs cost it (`cost + fee / units`), so into its floor price (§4.2): a baker's bread carries
  its share of the walk. A bigger load is cheaper a unit.
- **A runner's cart is a business** (`Drone.equity`, worth `Drone.CART_VALUE` plus its experience, like a machine's repair cost
  plus its experience). The hero can invest in it (§5.2); every fee is then split, the heroes' shares into their pockets.
- How much a shop holds of each input is `MachineDef.stock_crafts` crafts' worth (6; the lemonade stand and coffee stop 16, a
  cartload: their two goods come on two trips, and at six of each the stand sold out all day).
- They also gather **scrap** from piles in the street, free (`ScrapPile`, `engine/salvage/scrap_pile.gd`). It gathers `RATE` a
  minute, up to `CAP`. This is a placeholder for how scrap appears, which is still to be designed.
- Scrap goes to whatever has room for it: a camp's input, or a tent city's build stock (§2.5). The keeper pays only the fee.
- A trip is worth making when the destination is `MIN_DELIVERY` short. Free scrap costs only the fee, so it waits for
  `MIN_SCRAP_LOAD`, unless that is more than the room left: a build is not left waiting on its last few pieces.

## 5. Money

**5.1 Where money comes from.** Only three places, each counted in `Ledger.printed`:
- **the gun**: the hero's gift and investment (`Gun`), the kickflip;
- **the seed**: what the map is built with, and what a newcomer brings;
- **the fountain** (`Welfare`, `engine/welfare/welfare.gd`): each office gives, at random, $1–3 to the poorest of `PICKS`
  random residents of its own zone, about `DOLLARS_A_DAY` per resident a day (25% more per office level). It pays first from its
  zone's food bank till (above `TILL_FLOAT`), then from what the hero gave its clerk; only then is it new money
  (`Ledger.issued`).

**5.2 Where money goes.** It moves only between wallets, the heroes' pockets (`Ledger.pockets`) and bills. It leaves only into
`Ledger.sunk`: repairs, building up, and tents.

**5.3 The invariant.** `World.total_money() == Ledger.printed`, on every tick, in every test that moves money.

**5.4 Stakes** (`engine/core/equity.gd`, bought through `Gun.business_of`). A business is worth its rebuild cost plus its experience. The heroes together own at most
49%. A sale pays each hero their share into their pocket. A runner's cart is a business too: its book is `Drone.CART_VALUE`, and
each delivery fee is split the same way (§4.4). After a merge, both are put back under the cap (`Merge._cap`).

## 6. Time and space

**6.1 The tick** (`World.tick`), in this order:
1. clock;
2. dormant zones in summary;
3. the relief van;
4. assets step (craft, trickle);
5. sleepers wake;
6. agents act, in a shuffled order (`World.shuffle`);
7. needs decay;
8. the end-of-tick systems, in `World._end_of_tick`: the engine's are rescue, borders, welfare, trades, lodging, spawner and
   chatter. The game's world puts the hero first (`Hero`: their needs, their zone, the zones' `focus`) and the bus second, and
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
- the food bank's keeper and one runner;
- the welfare clerk;
- a medic with a one-bed first aid post.

There are no drifters and no van. `Atom.seed(w, zone, at, site)` puts one down, found: the tent city standing, the stands
wrecked, the owners broke. On its own it has no collapses in 120 days. Growth by mouths alone does not hold (§5.3), so growth must
roll producers too. The tutorial's town is a special case: a grown cluster (8.1) plus the story.

**8.1 The standard cluster** (`Cluster`, `engine/core/cluster.gd`). The people a block starts with, defined once:
- four trades at tier 0;
- a food bank with its keeper and two runners;
- six drifters;
- a barrel fire and a medical tent;
- the van's stop and a welfare office.

It is laid out along a street site, everyone housed. It is found wrecked and broke (`found`), and the hero gets it going
(`fund`).

**8.2 Its balance** (`docs/balance.md`). With the fountain at $12 a resident a day, a funded cluster runs a year with no
collapses and climbs to tier 1 in about 100 days (`tools/epoch.gd`). Changing what is in it means measuring again.

**8.3 Where clusters stand** *(to come)*. On a map of anywhere, the engine will place clusters on the map's own blocks (buildings with
touching walls), each laid out on a street site (`Cluster.open_site` is the shape of one). A per-block spawner was built once
and taken out (2026-11-18). The town grows by its tents instead.
