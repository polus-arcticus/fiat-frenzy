## A machine, like Planet Crafter's recycler: an input inventory, an output inventory, a recipe.
## Its owner (a vendor drone) keeps the input inventory stocked from suppliers; the recipe turns
## the inputs into the output item at `rate` a minute; the output inventory offers it to drones.
##
## The price follows Pricing.after_craft, and its floor is what the inputs last cost, so a dear
## purchase raises the floor. A craft with an input missing doesn't happen at all.
## A machine that isn't `working` is broken or boarded up: it offers nothing until its owner repairs it.
## It composes an Equity (the player's share) and, for a tent, a Shelter. Where it is, who owns it and what it is (a trade at a
## tier) are its Premises; `retier` turns it into the next tier of its trade.
class_name Machine
extends Premises

var item: String
## How two saves of the same business combine (see Merge): sales add up, it is working if either save repaired it, and it is
## at the higher tier if either save built it up (Merge.settle then makes the rest of it agree: see retier).
const MERGE := {"sold_total": "sum", "crafted_total": "sum", "revenue_total": "sum", "working": "any", "price_peak": "max",
	"tier": "max", "built_total": "sum", "tents": "max"}
## The tent city's tents stand side by side, each this wide (see Lodging).
const TENT_WIDTH := 2.0

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
## The tent city (the "tent" kind, see Lodging): how many tents it has, one person to each, so how many people the cluster
## holds (at most `Catalog.machine(kind).cap` at its tier). The row goes on to its side `wing` (+1 or -1 along its own x: down
## the street, away from the market).
var tents := 0
var tents_cap := 0  # more room than its tier gives, if a scenario laid it out bigger (0: just the tier's)
var wing := 1.0

var price_peak := 0.0
var built_total := 0.0  # what its owners have paid to build it up the tiers, all told (sunk, like a repair)
var sold_total := 0
var crafted_total := 0
var revenue_total := 0.0
var line: Array[Drone] = []   # the customers queuing for it, the one being served first (see Queueing)
var service_left := -1.0      # how long the one at the front still has to be served; below zero: nobody is being


## `stocked`: starts with half a shelf of leftovers in the output inventory, and two crafts' worth of inputs.
func _init(machine_kind := "bakery", owner_uid := "", at := Vector2.ZERO, is_working := false, stocked := true) -> void:
	owner = owner_uid
	pos = at
	working = is_working
	_take_def(machine_kind)
	output.caps[item] = Catalog.machine(kind).cap
	if stocked:
		output.add(item, maxi(capacity() / 2, 1))
	for raw in recipe:
		input_cost[raw] = Catalog.base_price(raw)
		input.add(raw, recipe[raw] * 2)
	price = Catalog.base_price(item) if Catalog.machine(kind).flat_price else floor_price()  # a flat-price shop keeps the item's price
	price_peak = price
	set_level(level)


## Becomes `new_kind` (the next tier of its trade, when its owner builds it up: see Trades). It keeps its name, owner, place,
## level, the hero's stakes, its takings, its shelf if it still makes the same thing (a bakery's bread is the bake shop's),
## and whatever inputs it has that the new recipe uses. If it makes something new, the old stock goes with the old trade (it
## is given away in the change) and it opens with a craft's worth of the new thing. Called with its own kind (after a merge),
## it only puts its numbers right.
func retier(new_kind: String) -> void:
	var old_item := item
	_take_def(new_kind)
	if item != old_item:
		output.caps[item] = Catalog.machine(kind).cap
		output.add(item, 1)
		price = Catalog.base_price(item) if Catalog.machine(kind).flat_price else maxf(price, floor_price())  # (a camp's bike at the bike's price)
	for inv in [output, input]:  # (anything the new tier does not make or use; after a merge, what the lower tier left)
		for k in inv.counts.keys():
			if k != item and not recipe.has(k):
				inv.counts.erase(k)
				inv.caps.erase(k)
	for raw in recipe:
		if not input_cost.has(raw):
			input_cost[raw] = Catalog.base_price(raw)
	set_level(level)
	output.take(item, maxi(0, stock() - capacity()))


## Takes on the numbers of `machine_kind` from the Catalog (what it makes, from what, how fast; its trade and tier).
func _take_def(machine_kind: String) -> void:
	var d := Catalog.machine(machine_kind)
	kind = machine_kind
	trade = d.trade
	tier = d.tier
	item = d.item
	recipe = d.inputs.duplicate()
	rate_per_min = d.rate
	tick = d.tick
	repair_cost = d.repair
	_solid = null
	if d.warm > 0.0:
		if shelter == null:
			shelter = Shelter.new(d.cap, d.warm, pos)
			shelter.berth_radius = 0.45  # a tent holds its sleepers inside its walls
		shelter.warm_rate = d.warm
	for raw in input_cost.keys():
		if not recipe.has(raw):
			input_cost.erase(raw)


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
	return working and shelter == null and wanted == item and stock() >= 1  # (a tent sells nothing: its tents are homes)


## The middle of the `index`th tent in the row, where its person sleeps: the tents side by side down `wing`. (Well clear of the
## walls: Navigation holds a margin round every wall, and someone who woke up in it could not find a way out.)
func bed_pos(index: int) -> Vector2:
	return pos + Vector2(-front.y, front.x) * index * TENT_WIDTH * wing - front * 0.3


## The tent city takes up the ground of its whole row (one long tent, open along the front); anything else, its kind's shape.
func solid() -> Footprint:
	if shelter == null:
		return super()
	if _solid == null:
		var shape: Array = Catalog.footprint_of(kind).tent
		var k := maxi(1, tents)
		var centre := pos + Vector2(-front.y, front.x) * wing * (k - 1) * TENT_WIDTH * 0.5
		_solid = Footprint.new(centre, front)
		_solid.tent(float(shape[0]) + (k - 1) * TENT_WIDTH * 0.5, shape[1], shape[2])
	return _solid


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
	output.caps[item] = d.cap + Stacks.SIZE * (level - 1)
	if shelter != null:
		shelter.capacity = tents  # (a tent city's tents are built, not grown: see Lodging)
		_solid = null
	for raw in recipe:
		input.caps[raw] = recipe[raw] * (d.stock_crafts + level - 1)
	var up := Catalog.next_tier(kind)
	if up != "" and Catalog.machine(up).build_scrap > 0:  # its next tier is built of pooled scrap: room for it, on top
		var crafts: int = recipe.get("scrap", 0) * (d.stock_crafts + level - 1)
		input.caps["scrap"] = crafts + Catalog.machine(up).build_scrap
	refresh()


## Keeps the logistics flags honest: what this machine wants delivered and what it offers.
func refresh() -> void:
	output.offer = {item: stock()} if working and shelter == null else {}
	input.want = {}
	for raw in input.caps:  # (its recipe's inputs, and what its next tier is built of, if that is a good: see build_stock)
		input.want[raw] = input.room(raw)


## Takes delivery of an input and remembers what it cost.
func receive(raw: String, n: int, unit_price: float) -> void:
	input.add(raw, n)
	input_cost[raw] = unit_price


func step(dt: float) -> void:
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
