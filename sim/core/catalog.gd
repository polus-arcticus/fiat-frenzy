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
		ItemDef.new("scrap", "material", 1.0),
		ItemDef.new("bread", "food", 2.0, 0.5),  # its price is the bakery's own floor
		ItemDef.new("hot_dog", "food", 0.0, 0.65),
		ItemDef.new("lemonade", "drink", 0.0, 0.6),
		ItemDef.new("bed", "warmth"),
		ItemDef.new("bicycle", "vehicle", 3000.0),  # not food: bought once, and ridden. THE price of a bicycle
		ItemDef.new("letter", "document"),  # carried for a quest, not used up
	]
	for d in defs:
		out[d.id] = d
	for g in ["flour", "protein", "sugar", "bottled_water"]:
		out[g].relief = true
	out["scrap"].found_free = true
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
	var tent := MachineDef.new("tent", "Tent with a barrel fire", "bed")
	tent.inputs = {"scrap": 2}
	tent.rate = 0.4
	tent.cap = 4
	tent.tick = 0.10
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
	for m in [bakery, dogs, lemonade, tent, bikes]:
		out[m.id] = m
	return out


## The shape of things that are not businesses (see MachineDef.footprint for the format). A drone keeps out of
## these (see Footprint).
const FIXTURE_FOOTPRINTS := {
	"fire": {"circles": [[0.0, 0.0, 0.45]]},
	"hospital": {"tent": [2.4, -1.8, 1.95]},
}

static var food_bank: FoodBankDef = _build_food_bank()


static func _build_food_bank() -> FoodBankDef:
	var fb := FoodBankDef.new()
	fb.add("flour", 1.2)
	fb.add("bottled_water", 1.5)
	fb.add("sugar", 0.8)
	fb.add("protein", 0.8)
	return fb


static func item(id: String) -> ItemDef:
	return _items[id]


static func machine(id: String) -> MachineDef:
	return _machines[id]


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


## Raw goods that lie around for free (scrap).
static func free_inputs() -> Array[String]:
	var out: Array[String] = []
	for d in _items.values():
		if d.found_free:
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
