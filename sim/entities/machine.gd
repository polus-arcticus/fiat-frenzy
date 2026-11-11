## A machine, like Planet Crafter's recycler: an input inventory, an output inventory, a recipe.
## Its owner (a vendor drone) keeps the input inventory stocked from suppliers; the recipe turns
## the inputs into the output item at `rate` a minute; the output inventory offers it to drones.
##
## The price follows Pricing.after_craft, and its floor is what the inputs last cost, so a dear
## purchase raises the floor. A craft with an input missing doesn't happen at all.
## A machine that isn't `working` is broken or boarded up: it offers nothing until its owner repairs it.
## It composes an Equity (the player's share) and, for a tent, a Shelter.
class_name Machine
extends RefCounted

## How many crafts' worth of each input a machine can hold (it was 4; a little more room so a van visit
## or a runner's trip goes further).
const INPUT_CRAFTS := 6

var kind: String
var item: String
var owner_id := -1
var zone := "district"  # which patch of the map it stands in (its owner's zone)
var pos := Vector2.ZERO
var working := false
var input := Inventory.new()
var output := Inventory.new()
var recipe := {}
var input_cost := {}  # raw -> what a unit cost last time
var rate_per_min := 6.0
var craft_progress := 0.0
var price := 0.0
var tick := 0.1
var repair_cost := 0.0
var equity := Equity.new()
var growth := Growth.new()  # shared with its owner once it has one (World.add_vendor)
var level := 1              # how far it has expanded; follows the growth level (set_level)
var shelter: Shelter = null  # tents only
var front := Vector2(0, 1):   # unit vector from the stand toward its customers (set by the scenario)
	set(v):
		front = v
		_solid = null
var _solid: Footprint = null

var price_peak := 0.0
var sold_total := 0
var crafted_total := 0
var revenue_total := 0.0


## `stocked`: starts with half a shelf of leftovers in the output inventory, and two crafts' worth of inputs.
func _init(machine_kind: String, owner: int, at: Vector2, is_working := false, stocked := true) -> void:
	var d := Catalog.machine(machine_kind)
	kind = machine_kind
	item = d.item
	owner_id = owner
	pos = at
	working = is_working
	recipe = d.inputs.duplicate()
	rate_per_min = d.rate
	tick = d.tick
	repair_cost = d.repair
	if d.warm > 0.0:
		shelter = Shelter.new(d.cap, d.warm, at)
		shelter.berth_radius = 0.45  # a tent holds its sleepers inside its walls
	output.caps[item] = d.cap
	if stocked:
		output.add(item, maxi(d.cap / 2, 1))
	for raw in recipe:
		input_cost[raw] = Catalog.base_price(raw)
		input.caps[raw] = recipe[raw] * INPUT_CRAFTS
		input.add(raw, recipe[raw] * 2)
	price = Catalog.base_price(item) if d.flat_price else floor_price()  # a flat-price shop keeps the item's price
	price_peak = price
	refresh()


## Where its vendor stands: behind the counter.
## What the stand takes up, for keeping drones out of it.
func solid() -> Footprint:
	if _solid == null:
		_solid = Footprint.of(kind, pos, front)
	return _solid


func post() -> Vector2:
	return pos - front * 1.2


func display_name() -> String:
	return Catalog.machine(kind).name


## What the inputs of one craft cost, at what they last cost.
func floor_price() -> float:
	var t := 0.0
	for raw in recipe:
		t += recipe[raw] * input_cost[raw]
	return t


func stock() -> int:
	return output.count(item)


func capacity() -> int:
	return output.caps[item]


func offers(wanted: String) -> bool:
	return working and wanted == item and stock() >= 1


func price_of(_wanted: String) -> float:
	return price


## What the business is worth: its rebuild cost plus all the money the player has given it.
func value() -> float:
	return equity.value(repair_cost, growth.xp)


## How many more dollars can be invested before the player owns the most they can (49%).
func investable() -> float:
	return equity.room(repair_cost, growth.xp)


## The business expands to `new_level`: more output a minute, one more slot of shelf (a tent: one more bed),
## and room for one more craft's worth of each input, per level above the first.
func set_level(new_level: int) -> void:
	level = new_level
	var d := Catalog.machine(kind)
	rate_per_min = d.rate * pow(1.25, level - 1)
	output.caps[item] = d.cap + (1 if shelter != null else Stacks.SIZE) * (level - 1)
	if shelter != null:
		shelter.capacity = output.caps[item]
	for raw in recipe:
		input.caps[raw] = recipe[raw] * (INPUT_CRAFTS + level - 1)
	refresh()


## Keeps the logistics flags honest: what this machine wants delivered and what it offers.
func refresh() -> void:
	output.offer = {item: stock()} if working else {}
	input.want = {}
	for raw in recipe:
		input.want[raw] = input.room(raw)


## Takes delivery of an input and remembers what it cost.
func receive(raw: String, n: int, unit_price: float) -> void:
	input.add(raw, n)
	input_cost[raw] = unit_price


func step(dt: float) -> void:
	for raw in Catalog.free_inputs():  # scrap is found lying around
		if recipe.has(raw):
			input.add(raw, input.room(raw))
	if working:
		craft_progress += rate_per_min * dt / 60.0
		while craft_progress >= 1.0:
			craft_progress -= 1.0
			craft()
	refresh()


func craft() -> void:
	for raw in recipe:
		if input.count(raw) < recipe[raw]:
			return
	price = Pricing.after_craft(price, floor_price(), tick, stock(), capacity())
	price_peak = maxf(price_peak, price)
	if stock() >= capacity():
		return
	for raw in recipe:
		input.take(raw, recipe[raw])
	output.add(item, 1)
	crafted_total += 1
