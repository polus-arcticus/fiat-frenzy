## The data: every kind of item and business, each defined once, with everything about it in one place
## (see ItemDef and MachineDef), so a fact like a price can only be set in one spot.
##
## Raw goods arrive on the Red Cross van (flour, protein, bottled water, sugar), free of charge, except
## scrap, which is found lying around and spawns free. Machines turn inputs into one output item. A
## machine's floor price is what its inputs cost it: an item's price for delivered goods, and whatever
## the seller charged for things bought from another business, like bread.
class_name Catalog
extends RefCounted

static var _items: Dictionary[String, ItemDef] = _build_items()
static var _machines: Dictionary[String, MachineDef] = _build_machines()


static func _build_items() -> Dictionary[String, ItemDef]:
	var out: Dictionary[String, ItemDef] = {}
	var defs: Array[ItemDef] = [
		ItemDef.new("flour", "material", 1.0),
		ItemDef.new("protein", "material", 1.5),
		ItemDef.new("bottled_water", "drink", 0.5, 0.5),  # a raw input for lemonade, and fine to drink as it is
		ItemDef.new("sugar", "material", 0.5),
		ItemDef.new("scrap", "material", 0.0),  # lies in the street: free, but someone has to gather it (runners: see ScrapPile)
		ItemDef.new("bread", "food", 2.0, 0.5),  # its price is the bakery's own floor
		ItemDef.new("hot_dog", "food", 0.0, 0.9),  # a loaf and some protein: more filling for the money than bread, or no one buys it
		ItemDef.new("burger", "food", 0.0, 1.0),  # the burger bar's: the same loaf and protein as a hot dog, done better
		ItemDef.new("lemonade", "drink", 0.0, 0.6),
		ItemDef.new("coffee", "drink", 0.0, 0.75),  # the coffee stop's: the same water and sugar as lemonade, and it goes further
		ItemDef.new("bed", "warmth"),
		ItemDef.new("bicycle", "vehicle", 3000.0),  # not food: bought once, and ridden. THE price of a bicycle
		ItemDef.new("skateboard", "board", 120.0),  # a complete board (deck, trucks, wheels), at about what one costs in a shop today
		ItemDef.new("old_skateboard", "board", 15.0),  # a homeless camp's: put together from scrap, cheap and slow
		ItemDef.new("old_bike", "vehicle", 60.0),      # a bike camp's: the same, a bicycle
		ItemDef.new("old_coat", "clothes", 8.0),   # a thrift stall's: stitched from scrap (sacking, tarp, a sleeping bag)
		ItemDef.new("coat", "clothes", 25.0),      # a clothing shop's: a proper coat
		ItemDef.new("letter", "document"),  # carried for a quest, not used up
		ItemDef.new("tent", "camping", 15.0),        # the tent keeper's, of scrap: put down in the street, it founds a tent city
		ItemDef.new("barrel_fire", "camping", 5.0),  # and a barrel to burn scrap in: put down, it is a barrel fire
	]
	for d in defs:
		out[d.id] = d
	for g in ["flour", "protein", "sugar", "bottled_water"]:
		out[g].relief = true
	out["scrap"].scavenged = true
	out["old_skateboard"].speed = 0.6
	out["old_bike"].speed = 0.5
	for g in ["bicycle", "old_bike", "skateboard", "old_skateboard", "old_coat", "coat"]:
		out[g].gear = true
	for g in ["tent", "barrel_fire"]:
		out[g].placeable = true
	out["old_coat"].insulation = 0.3
	out["coat"].insulation = 0.6
	return out


static func _build_machines() -> Dictionary[String, MachineDef]:
	var out: Dictionary[String, MachineDef] = {}
	var bakery := MachineDef.new("bakery", "Bakery", "bread")
	bakery.inputs = {"flour": 2}
	bakery.cap = 50
	bakery.tick = 0.10
	bakery.repair = 40.0
	var dogs := MachineDef.new("hot_dog_stand", "Hot dog stand", "hot_dog")
	dogs.inputs = {"bread": 1, "protein": 1}
	dogs.cap = 20
	dogs.tick = 0.08
	dogs.repair = 40.0
	var lemonade := MachineDef.new("lemonade_stand", "Lemonade stand", "lemonade")
	lemonade.inputs = {"bottled_water": 1, "sugar": 1}
	lemonade.cap = 20
	lemonade.tick = 0.03
	lemonade.repair = 25.0
	lemonade.stock_crafts = 16  # a runner's cartload of each (water and sugar come on two trips: at six of each it sold out all day)
	# The cluster's home and spawn factory, like Planet Crafter's drone bay: tents for one person each, warm and free (see
	# Lodging). Its beds are not for sale (its `item` is only what it is for); its keeper makes and sells tents and barrel fires,
	# of scrap (its wares, at `rate` a minute). `cap` is the most tents it holds at this tier: the atom's worth (see Atom), so
	# growing past it means building it up. The footprint is one tent's.
	var tent := MachineDef.new("tent", "Tent city", "bed")
	tent.rate = 0.5
	tent.wares = {"tent": {"scrap": 4}, "barrel_fire": {"scrap": 2}}
	tent.cap = Atom.ROLES.size()
	tent.tick = 0.0
	tent.repair = 30.0
	tent.warm = 0.02
	tent.footprint = {"tent": [0.92, -1.12, 1.85]}
	# A real business, in a real building: it makes nothing, it sells one bicycle at the bicycle's price. Its
	# `repair` is what the business is worth before anyone gives it a cent, so a stake in it costs millions:
	# spraying it with money gets you nowhere. The owner is rich and has no needs.
	var bikes := MachineDef.new("bike_shop", "Bike shop", "bicycle")
	bikes.rate = 0.0
	bikes.cap = 1
	bikes.tick = 0.0
	bikes.repair = 2000000.0
	bikes.flat_price = true
	bikes.rich = true
	bikes.footprint = {"boxes": [[0.0, 0.0, 1.6, 0.45]]}
	# The skate shop, beside the bike shop: the same kind of business (a real building, a rich owner, a flat price), with a
	# few boards on the wall instead of one bicycle.
	var skates := MachineDef.new("skate_shop", "Skate shop", "skateboard")
	skates.rate = 0.0
	skates.cap = 6
	skates.tick = 0.0
	skates.repair = 1000000.0
	skates.flat_price = true
	skates.rich = true
	skates.footprint = {"boxes": [[0.0, 0.0, 1.6, 0.45]]}
	# Tier 1 of each trade: its owner builds the stand up into a shop out of their own savings (see Trades). The same inputs
	# as the stand below it, made half again as fast, with a bigger shelf, and (where it makes something new) a little better
	# value for the money. Each stands where its stand stood, on the same ground, for now (a shopfront in the block's wall is
	# to come). What it is worth (`repair`) is the stand plus what it cost to build.
	var bake_shop := MachineDef.new("bake_shop", "Bake shop", "bread")
	bake_shop.inputs = {"flour": 2}
	bake_shop.rate = 9.0
	bake_shop.cap = 80
	bake_shop.tick = 0.10
	bake_shop.build = 250.0
	var burgers := MachineDef.new("burger_bar", "Burger bar", "burger")
	burgers.inputs = {"bread": 1, "protein": 1}
	burgers.rate = 9.0
	burgers.cap = 30
	burgers.tick = 0.08
	burgers.build = 250.0
	var coffee := MachineDef.new("coffee_stop", "Coffee stop", "coffee")
	coffee.inputs = {"bottled_water": 1, "sugar": 1}
	coffee.rate = 9.0
	coffee.cap = 30
	coffee.tick = 0.03
	coffee.build = 200.0
	coffee.stock_crafts = lemonade.stock_crafts
	var hostel := MachineDef.new("hostel", "Hostel", "bed")  # (twice the room)
	hostel.rate = tent.rate
	hostel.wares = tent.wares
	hostel.cap = Atom.ROLES.size() * 2
	hostel.tick = 0.0
	hostel.warm = 0.03
	hostel.build_scrap = 200  # (about 20 days of a pile's scrap: ScrapPile.RATE. Built of scrap the runners pool into the tent city, not of money)
	# The salvage trade: a homeless camp among the bike scrap, where someone puts together old boards from scrap the runners bring
	# (tier 0), and, built up, old bikes (tier 1). Cheap and slow (ItemDef.speed), at the item's flat price.
	var camp := MachineDef.new("scrap_camp", "Homeless camp", "old_skateboard")
	camp.inputs = {"scrap": 3}
	camp.rate = 0.5
	camp.cap = 3
	camp.tick = 0.0
	camp.repair = 20.0
	camp.flat_price = true
	camp.footprint = tent.footprint
	var bike_camp := MachineDef.new("bike_camp", "Bike camp", "old_bike")
	bike_camp.inputs = {"scrap": 6}
	bike_camp.rate = 0.3
	bike_camp.cap = 2
	bike_camp.tick = 0.0
	bike_camp.flat_price = true
	bike_camp.build_scrap = 60
	# The clothing trade: a thrift stall stitches old coats from scrap (tier 0); built up with money, a clothing shop makes coats,
	# still of scrap until there is a cloth trade to buy from. Flat prices: the hero is who buys clothes, for now.
	var thrift := MachineDef.new("thrift_stall", "Thrift stall", "old_coat")
	thrift.inputs = {"scrap": 2}
	thrift.rate = 0.5
	thrift.cap = 4
	thrift.tick = 0.0
	thrift.repair = 20.0
	thrift.flat_price = true
	var clothier := MachineDef.new("clothing_shop", "Clothing shop", "coat")
	clothier.inputs = {"scrap": 3}
	clothier.rate = 0.5
	clothier.cap = 4
	clothier.tick = 0.0
	clothier.flat_price = true
	clothier.build = 120.0
	for pair in [[bakery, bake_shop], [dogs, burgers], [lemonade, coffee], [tent, hostel], [camp, bike_camp], [thrift, clothier]]:
		pair[1].repair = pair[0].repair + pair[1].build
		pair[1].footprint = pair[0].footprint
	for m in [bakery, dogs, lemonade, tent, bikes, skates, bake_shop, burgers, coffee, hostel, camp, bike_camp, thrift, clothier]:
		out[m.id] = m
	for trade in TRADES:
		var ladder: Array = TRADES[trade]
		for tier in ladder.size():
			if out.has(ladder[tier]):
				out[ladder[tier]].trade = trade
				out[ladder[tier]].tier = tier
	return out


## Every trade and its tiers, bottom up, by Catalog id: the one place that says what climbs to what. "" is a tier not built
## yet (the bike and skate shops are tier 1: a stall that rebuilds bikes from scrap would be their tier 0). The tiers above
## these, and what each would add, are in docs/upgrade_trees.md.
## The rule for tier 0: a trade whose product is not food or drink makes it from scrap (what the street has: boards, coats).
## Food and drink come from the relief goods. Higher tiers may take other inputs as supply chains grow (test_trades checks it).
const TRADES := {
	"bread": ["bakery", "bake_shop"],
	"salvage": ["scrap_camp", "bike_camp"],
	"clothing": ["thrift_stall", "clothing_shop"],
	"meat": ["hot_dog_stand", "burger_bar"],
	"drinks": ["lemonade_stand", "coffee_stop"],
	"lodging": ["tent", "hostel"],
	"bikes": ["", "bike_shop"],
	"skates": ["", "skate_shop"],
	"supply": ["food_bank"],
	"money": ["welfare_office"],
	"medical": ["first_aid", "medical_tent"],
}
## The names of the premises that are not machines (see Premises.display_name).
const PREMISES_NAMES := {"welfare_office": "Welfare office", "first_aid": "First aid post", "medical_tent": "Medical tent"}


## The Catalog id of the tier above `kind` in its trade, or "" at the top (of what is built).
static func next_tier(kind: String) -> String:
	if not _machines.has(kind):
		return ""
	var ladder: Array = TRADES.get(_machines[kind].trade, [])
	var up: int = _machines[kind].tier + 1
	return ladder[up] if up < ladder.size() and _machines.has(ladder[up]) else ""


## What a business of `kind` is called.
static func name_of(kind: String) -> String:
	if _machines.has(kind):
		return _machines[kind].name
	if kind == "food_bank":
		return food_bank.name
	return PREMISES_NAMES.get(kind, kind)


## The shape of things that are not businesses (see MachineDef.footprint for the format). A drone keeps out of
## these (see Footprint).
const FIXTURE_FOOTPRINTS := {
	"fire": {"circles": [[0.0, 0.0, 0.45]]},
	"medical_tent": {"tent": [2.4, -1.8, 1.95]},
	"first_aid": {"tent": [0.92, -1.12, 1.85]},  # (a tent's size: one bed)
}

static var food_bank: FoodBankDef = _build_food_bank()


static func _build_food_bank() -> FoodBankDef:
	var fb := FoodBankDef.new()
	# Two flour a loaf: a dozen people eat about 24 loaves' worth a day, 48 flour, and the van brings 30 of it.
	fb.add("flour", 3.6)
	# Water and sugar are what lemonade is made of, one each, and thirst is the quickest need: a town of a dozen drinks about
	# 30 lemonades a day (a day is 10 minutes). Less than this left the stand's shelf empty half the day (bench_economy).
	fb.add("bottled_water", 3.0)
	fb.add("sugar", 3.0)  # (at 2.4 a dormant town's lemonade was capped at about 35 a day, against about 31 drunk: no margin)
	fb.add("protein", 0.8)
	return fb


static func item(id: String) -> ItemDef:
	return _items[id]


static func machine(id: String) -> MachineDef:
	return _machines[id]


## Whether `id` is a machine (rather than a premises, like the food bank).
static func has_machine(id: String) -> bool:
	return _machines.has(id)


## What an item costs before anything has been bought (see ItemDef.price).
static func base_price(id: String) -> float:
	return item(id).price


static func bike_price() -> float:
	return item("bicycle").price


static func class_of(id: String) -> String:
	return item(id).cls


static func restores(id: String) -> float:
	return item(id).restores


## Something a drone can use up (as opposed to a raw input like flour, or a bicycle).
static func is_consumable(id: String) -> bool:
	return _items.has(id) and item(id).consumable()


## Raw goods that lie in the street, free, for runners to gather (scrap).
static func scavenged_goods() -> Array[String]:
	var out: Array[String] = []
	for d in _items.values():
		if d.scavenged:
			out.append(d.id)
	return out


## Raw goods the Red Cross van brings.
static func relief_goods() -> Array[String]:
	var out: Array[String] = []
	for d in _items.values():
		if d.relief:
			out.append(d.id)
	return out


## The ground shape of a business or fixture, by kind.
static func footprint_of(kind: String) -> Dictionary:
	if _machines.has(kind):
		return _machines[kind].footprint
	if kind == "food_bank":
		return food_bank.footprint
	return FIXTURE_FOOTPRINTS.get(kind, {})
