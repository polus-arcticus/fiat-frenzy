## The food bank: the town's depot of base materials, a store a little way from the market. Flour, protein,
## bottled water and sugar trickle into its stock from nothing at a slow rate each (Catalog.food_bank), up
## to a cap, and it sells them at cost. It is what the cart runners fetch from: they buy a load here and
## wheel it to the storefronts that are short. A keeper (a drone, 1:1) minds it and keeps the takings.
class_name FoodBank
extends RefCounted

var zone := "district"
var pos := Vector2.ZERO
var owner_id := -1
var working := true
var front := Vector2(0, 1):  # unit vector from the store toward its customers
	set(v):
		front = v
		_solid = null
var _solid: Footprint = null
var output := Inventory.new()
var level := 1
var sold_total := 0
var revenue_total := 0.0

var _progress := {}  # good -> how far toward its next unit


func _init(at: Vector2, keeper_id: int) -> void:
	pos = at
	owner_id = keeper_id
	for good in Catalog.food_bank.goods:
		var g: FoodBankDef.Good = Catalog.food_bank.goods[good]
		output.caps[good] = g.cap
		output.add(good, g.start)
		_progress[good] = 0.0
	refresh()


func display_name() -> String:
	return Catalog.food_bank.name


## Where the keeper stands: behind the counter.
func solid() -> Footprint:
	if _solid == null:
		_solid = Footprint.of("food_bank", pos, front)
	return _solid


func post() -> Vector2:
	return pos - front * 1.2


func offers(item: String) -> bool:
	return working and output.count(item) >= 1


## It sells at cost.
func price_of(item: String) -> float:
	return Catalog.base_price(item)


func refresh() -> void:
	output.offer = {}
	if working:
		for good in Catalog.food_bank.goods:
			output.offer[good] = output.count(good)


## The food bank expands with its keeper: stock arrives a quarter faster and the shelves hold another ten of
## each good, per level above the first.
func set_level(new_level: int) -> void:
	level = new_level
	for good in Catalog.food_bank.goods:
		output.caps[good] = Catalog.food_bank.goods[good].cap + Stacks.SIZE * (level - 1)
	refresh()


## The slow trickle of new stock.
func step(dt: float) -> void:
	if working:
		for good in Catalog.food_bank.goods:
			_progress[good] += Catalog.food_bank.goods[good].rate * pow(1.25, level - 1) * dt / 60.0
			while _progress[good] >= 1.0:
				_progress[good] -= 1.0
				output.add(good, 1)
	refresh()
