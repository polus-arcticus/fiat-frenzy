# Upgrade trees

Every business is a **trade** climbing **tiers** (`Catalog.TRADES`). Its owner, an NPC, builds it up one tier at a time out of
their own savings: a one-off build cost, sunk. There is no rent, no tax and no loan, and nothing comes back down (see `Trades`).
The hero can hurry a climb by giving an owner the money.

Only tiers 0 and 1 are built. This note keeps the whole ladders, so each new tier adds a mechanic and not just bigger numbers.

## What the epoch sim says about the ladders

`tools/epoch.gd` runs the standard cluster for a year (`docs/balance.md` has the numbers):
- **The bins are everyone's ceiling.** Every tier 0 is made of what the bins give (leftovers, water, scrap). Under the food bank,
  bread was capped at 25 loaves a day by its flour; now a block needs 1.2 organics bins' worth or its people go hungry
  (docs/balance.md). Every tier above 1 makes more, faster, and needs more coming in: the waste trade has to grow with the
  others, or they starve it.
- **Lodging earns nothing while the barrel fire is free.** The tent city is built up of scrap (the hostel, day 41), not of its
  takings. Lodging needs something only a roof gives: a cold that a fire can't answer, storage, an address.
- **Stalls don't climb on their own takings.** With the bottle depot, everyone is kept at about the line where they stop
  collecting, and the stalls' margins stay thin: in a season only the tent city builds up (of scrap). Under the welfare office
  money piled up after tier 1 instead (about $20,000 in a year). Tiers 2 and up need money to go somewhere: the hero's, for now.

## The ladders

Built tiers are in **bold**. Each tier says what it adds.

### Meat
1. **Hot dog stand** (t0): a cart at the kerb, bread and leftovers into hot dogs.
2. **Burger bar** (t1): a kiosk, the same inputs, half again as fast, and a burger fills more (1.0 against 0.9).
3. Butcher shop (t2): a shopfront in the block's wall. It also **sells meat** to the other food trades of nearby blocks (it
   becomes a supplier, carted across tile borders by `Borders`).
4. Industrial meat packing (t3): a factory. It **employs**: drifters work shifts for a wage, the first job that isn't running.
   It supplies a region and needs a truck route.

### Drinks
1. **Lemonade stand** (t0): fountain water and leftovers.
2. **Coffee stop** (t1): a kiosk, the same inputs, and coffee goes further (0.75 against 0.6).
3. Café (t2): **seats**. Customers stay a while, warm indoors, and talk: the place rumours and quests spread (Chatter).
4. Bar (t3): the **night trade**. It opens after dark, when the stalls close, and the street has a nightlife.

### Bread
1. **Bakery** (t0): a stall, leftovers into bread.
2. **Bake shop** (t1): a kiosk, faster, a bigger shelf.
3. Bakery proper (t2): an oven in the block. It **sells bread wholesale** to the burger bars and cafés of nearby blocks.
4. Bread factory (t3): employs, and needs flour by the truckload (the waste trade's tiers above can't give it: a trade of its own).

### Lodging
1. **Tent city** (t0): a tent for each person, kept warm; it holds an atom's worth. Its keeper makes tents ($15) and barrel
   fires ($5) of scrap; a tent put down in the street founds another tent city at t0.
2. **Hostel** (t1): twice the room. **Built of 320 scrap** the runners pool into it, not money (about day 41 in an atom, day 47 with a park camp: none of its first month).
3. Hotel (t2): **rooms in the block's building**. It is the first business to move in upstairs. A resident with a room has an
   address: newcomers come to a block whose rooms have space (population growth).
4. Real estate seller (t3): buys the block's empty buildings (the map's unclaimed stock) and **sells floors to other owners**,
   so the shopfronts above tier 1 need them. No rent: a floor is bought once.

### Money
1. **Bottle depot** (t0): pays the deposit on the town's bottles, out of the town's fund first (`Deposit`). Whoever is short of
   cash walks bottles to it: the town's one way money comes in, apart from the hero. (It replaced the welfare office's money
   fountain, 2026-11-23.)
2. Loan shark (t1): undecided. Lending (credit, repossession, foreclosure) is held back because it complicates things. A
   tier 1 without credit could be a pawn shop: it buys goods and bikes for cash and sells them back dearer, a way to raise money
   fast.
3. Credit union (t2): pooled savings. Owners in a block put money in, and building up draws on the pool. (It needs credit.)
4. Bank branch (t3): the ECB's own furniture in the street. The story's ending is in sight.

### Waste (built: the bins, `WasteBin`; not a business yet)
1. **The bins** (t0): garbage, recycling and organics, and a fountain; the map's own where it has them. What the town throws
   away gathers in them, and the cart runners salvage it into the stands.
2. Sorting yard (t1): a business at last, with an owner. It takes the bins' loads and **sorts** them: more leftovers and scrap
   out of the same waste, so a block can feed tier 1 and up. This is the tier the others most need.
3. Recycling plant (t2): for a whole tile; it turns bottles and scrap into parts the shops buy (the bike and skate trades), and
   runners become its porters.
4. Waste-to-energy works (t3): a region's waste; it warms the buildings round it (a cold a fire can't answer: see Lodging).

### Salvage (built: `Camp`)
1. **Homeless camp** (t0): among the bike scrap. Runners bring it scrap; it puts together an **old skateboard** ($15, at 60% of a
   board's top speed).
2. **Bike camp** (t1): **built of 60 scrap**. It puts together an **old bike** ($60, about half the shop bike's gain over walking).
3. Scrap yard (t2): to come. It might sell scrap on to the bike and skate shops as parts.

### Bikes and skates (tier 1 is built: the story's shops)
1. Bike stall (t0): bikes rebuilt from scrap, for the homeless trade. (The salvage trade's bike camp does this now; this tier may
   fold into it.)
2. **Bike shop** (t1): the story's shop, a rich owner, a flat $3,000 price.
3. Cycle workshop (t2): repairs, and parts for the bus and the carts.
4. E-bike factory (t3): employs.

The skate trade is the same: a skate stall (t0) → the **skate shop** (t1) → a skate park (t2: a place, where skating warms
and cheers) → a board works (t3).

### Medical (not a trade yet)
The medical tent → a clinic (fewer days in bed) → a hospital (for a whole tile).

### Clothing (built)
1. **Thrift stall** (t0): stitches **old coats** from scrap ($8, insulation 0.3).
2. **Clothing shop** (t1, $120): **coats** ($25, insulation 0.6), still of scrap until a cloth trade exists to buy from.
3. Tailor (t2): to come. It might take cloth from a textile trade and make hats, gloves and boots, the "bling" richer NPCs want.

## Trades to come
- **Builders.** At the moment a build cost is sunk, paid to the world outside. A builders' trade would be paid instead
  (handyman → builder → construction firm → developer), so building up keeps money in the town. The developer is how blocks
  get **skyscrapers**.
- **Groceries.** A corner shop → a supermarket → a **mall complex** (a block-sized business that takes several trades' places
  in one building).
- **A block tier.** Once every trade in a block is at tier 2 the block itself could step up: street market → shopping arcade →
  mall. That is the polymerising: neighbouring blocks at the same tier merge into a district.
