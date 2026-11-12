## Survival and Maslow's order: how the bars drain, and what a drone therefore demands.
##   1. survival, most pressing bar first: food, drink, and warmth (a barrel fire or a tent bed) when
##      it is cold or night is falling
##   2. its vocation: repairing its machine, then keeping its input inventory stocked from suppliers
##   3. a runner's deliveries
##   4. loose money lying nearby
## Survival comes first when it can be answered. When no supply can answer it (nothing for sale, or
## nothing affordable) the drone moves on to its vocation rather than waiting, or a baker too hungry to
## buy flour would starve in a town whose only bread is the bakery's.
class_name Needs
extends RefCounted

const NEED_BELOW := 0.5          # a bar this low sends a drone looking
const NIGHT_SEEKS_WARMTH := 0.8  # at night a drone this cool starts looking for a fire or a bed
const DAY_COOLING := 1800.0      # seconds for a full warmth bar to run out in the day...
const NIGHT_COOLING := 240.0     # ...and at night
const RESERVE := 10.0            # kept back for groceries before a vendor spends on stock or repairs
const RESTOCK_BELOW := 3         # a vendor tops up an input when it holds fewer than this many crafts' worth

var _w: World


func _init(world: World) -> void:
	_w = world


func decay(d: Drone, dt: float) -> void:
	if d.unconscious() or d.needless:
		return  # out cold: nothing drains until the hospital has them up
	d.bars.hunger = maxf(0.0, d.bars.hunger - dt / 600.0)
	d.bars.thirst = maxf(0.0, d.bars.thirst - dt / 420.0)
	var cooling := dt / (NIGHT_COOLING if _w.clock.is_night() else DAY_COOLING)
	d.bars.warmth = clampf(d.bars.warmth + warmth_gain(d) * dt - cooling, 0.0, 1.0)
	if d.bars.hunger <= 0.0 or d.bars.thirst <= 0.0 or d.bars.warmth <= 0.0:
		d.starved_ticks += 1


## Warmth a second this drone feels from the heat sources round it: every fire in range (strongest beside
## it, by Shelter's inverse-square falloff), plus the tent it has a bed in, plus being indoors (see Heating).
func warmth_gain(d: Drone) -> float:
	var g := 0.0
	var range_sq := Shelter.RANGE * Shelter.RANGE
	for f in _w.fires:
		var d2: float = f.pos.distance_squared_to(d.pos)
		if d2 <= range_sq:
			g += f.shelter.gain_at_sq(d2)
	g += _w.heating.gain_at(d.pos)  # indoors: a shop, the sage's house, the bus
	var s: Shelter = d.sheltered_in
	if s != null and not s.open_air:
		g += s.gain_at_sq(s.centre.distance_squared_to(d.pos))
	return g


## Uses up one food or drink item: refills the matching bar. Returns how much it refilled, 0 if the item
## isn't something to eat or drink.
func eat(d: Drone, item: String) -> float:
	if not Catalog.is_consumable(item):
		return 0.0
	var amount: float = Catalog.restores(item)
	match Catalog.class_of(item):
		"food":
			d.bars.hunger = minf(1.0, d.bars.hunger + amount)
		"drink":
			d.bars.thirst = minf(1.0, d.bars.thirst + amount)
		_:
			return 0.0
	return amount


## Sleepers leave their tent or fire at dawn, or once they've warmed through.
func wake_sleepers() -> void:
	var shelters: Array[Shelter] = []
	for z in _w.zones.running():
		for m in _w.zones.machines_in(z):
			if m.shelter != null:
				shelters.append(m.shelter)
		for f in _w.zones.fires_in(z):
			shelters.append(f.shelter)
	for s in shelters:
		for d in s.berths.duplicate():
			if not _w.clock.is_night() or d.bars.warmth >= 0.98:
				s.release(d)


## The demand classes a drone currently has, most pressing first: survival, most pressing bar first,
## then the vocation. Logistics.plan takes the first one a supply exists for.
func demands(d: Drone) -> Array:
	var survival: Array = []
	if d.bars.hunger < NEED_BELOW:
		survival.append(["food", d.bars.hunger])
	if d.bars.thirst < NEED_BELOW:
		survival.append(["drink", d.bars.thirst])
	if d.bars.warmth < NEED_BELOW or (_w.clock.is_night() and d.bars.warmth < NIGHT_SEEKS_WARMTH):
		survival.append(["warmth", d.bars.warmth])
	survival.sort_custom(func(a, b): return a[1] < b[1])
	var out: Array = survival.map(func(x): return x[0])
	var m = _w.machine_of(d)
	if m != null:
		if not m.working:
			if d.wallet >= m.repair_cost + RESERVE:
				out.append("repair")
		elif short_input(m) != "":
			out.append("restock")
	if d.kind == "runner":
		out.append("haul")  # whether there is anything to deliver is for the planner to find out
	if _w.cash.nearest_loose(d.pos, Cash.SCAN, d.zone) != null:
		out.append("cash")  # last: loose money is only worth a detour when there is nothing better to do
	return out


## The input a working machine is most short of (fewest crafts' worth in hand) among those it has to
## buy from another business, or "".
func short_input(m: Machine) -> String:
	var worst := ""
	var low := float(RESTOCK_BELOW)
	for raw in m.recipe:
		if raw in Catalog.free_inputs() or raw in Catalog.relief_goods():
			continue  # found, or delivered for free: nothing for the vendor to go and fetch
		var crafts: float = float(m.input.count(raw)) / float(m.recipe[raw])
		if crafts < low:
			low = crafts
			worst = raw
	return worst
