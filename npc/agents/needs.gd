## Survival and Maslow's order: how the bars drain, and what a drone therefore demands.
##   1. survival, most pressing bar first: food, drink, and warmth (a barrel fire or a tent bed) when
##      it is cold or night is falling
##   2. its vocation: repairing its machine, then keeping its input inventory stocked from suppliers
##   3. a runner's deliveries
##   4. short of cash: collecting bottles for the deposit (Collecting)
##   5. loose money lying nearby
## Survival comes first when it can be answered. When no supply can answer it (nothing for sale, or
## nothing affordable) the drone moves on to its vocation rather than waiting, or a baker too hungry to
## buy flour would starve in a town whose only bread is the bakery's.
class_name Needs
extends RefCounted

const NEED_BELOW := 0.5          # a bar this low sends a drone looking
const NIGHT_SEEKS_WARMTH := 0.8  # at night a drone this cool starts looking for a fire or a bed
const DAY_COOLING := 1800.0      # seconds for a full warmth bar to run out in the day...
const NIGHT_COOLING := 240.0     # ...and at night
const RESERVE := Drone.RESERVE   # (an agent's: see Drone)
const RESTOCK_BELOW := 3         # a vendor tops up an input when it holds fewer than this many crafts' worth
const SLOWEST_PACE := 0.55       # how fast, against their usual walk, someone barely in need strolls to a stand...
const FASTEST_PACE := 1.35       # ...and someone nearly out hurries. So the thirstiest reach a thin shelf first.
const NEED_OF := {"food": "hunger", "drink": "thirst", "warmth": "warmth"}  # the bar each kind of errand answers
const HUNGER_SECONDS := 600.0    # seconds for a full hunger bar to run out
const THIRST_SECONDS := 420.0    # and a full thirst bar

var _w: World


func _init(world: World) -> void:
	_w = world


func decay(d: Drone, dt: float) -> void:
	if d.unconscious() or d.needless:
		return  # out cold: nothing drains until the hospital has them up
	d.bars.hunger = maxf(0.0, d.bars.hunger - dt / HUNGER_SECONDS)
	d.bars.thirst = maxf(0.0, d.bars.thirst - dt / THIRST_SECONDS)
	if _w.lodging.is_housed(d):
		d.bars.warmth = 1.0  # a tent of their own in a standing tent city keeps them warm (see Lodging)
	else:
		var usual := NIGHT_COOLING if _w.clock.is_night() else DAY_COOLING
		var span := usual
		if d.cold_spans != Vector2.ZERO:
			span = d.cold_spans.y if _w.clock.is_night() else d.cold_spans.x
		var feel := usual / span  # (one who feels the cold harder warms as much faster by a fire: the hero, see Cold)
		var cooling := dt / (span / (1.0 - d.insulation()))  # clothes make a bar last longer in the open
		d.bars.warmth = clampf(d.bars.warmth + warmth_gain(d) * feel * dt - cooling, 0.0, 1.0)
	if d.bars.hunger <= 0.0 or d.bars.thirst <= 0.0 or d.bars.warmth <= 0.0:
		d.starved_ticks += 1
	_own_shelf(d)


## A vendor in need of what their own stand makes takes one off their own shelf: it is theirs, so no money moves, and
## nobody else's stand is needed (the lemonade seller is often the only drink in town, and cannot buy from themselves).
func _own_shelf(d: Drone) -> void:
	if d.bars.hunger >= NEED_BELOW and d.bars.thirst >= NEED_BELOW:
		return
	var m = _w.machine_of(d)
	if m == null or not m.offers(m.item):
		return
	var bar: String = NEED_OF.get(Catalog.class_of(m.item), "")
	if bar in ["hunger", "thirst"] and d.bars[bar] < NEED_BELOW:
		m.output.take(m.item, 1)
		m.refresh()
		eat(d, m.item)


## How fast, against their usual walk, this drone goes after `job`. A survival errand is hurried by how far the bar it answers
## has fallen below the level that sent them looking: barely hungry, a stroll; nearly starving, a rush. (So the ones who need it
## most are first to the counter, and a drone that is nearly full does not stand in the way.) Any other errand is an ordinary walk.
func pace(d: Drone, job: Dictionary) -> float:
	var bar: String = NEED_OF.get(job.get("for", ""), "")
	if bar == "":
		return 1.0
	var below := NIGHT_SEEKS_WARMTH if bar == "warmth" and _w.clock.is_night() else NEED_BELOW
	var urgency := clampf(1.0 - float(d.bars[bar]) / below, 0.0, 1.0)
	return lerpf(SLOWEST_PACE, FASTEST_PACE, urgency)


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
		g += s.warm_rate  # in their bed in a tent: every module has its own barrel, so every bed is as warm (see Lodging)
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


## Sleepers leave their tent or fire at dawn, or once they've warmed through (in the running zones, or the ones given).
func wake_sleepers(zones: Array = []) -> void:
	var shelters: Array[Shelter] = []
	for z in (zones if not zones.is_empty() else _w.zones.running()):
		for m in _w.zones.machines_in(z):
			if m.shelter != null:
				shelters.append(m.shelter)
		for f in _w.zones.fires_in(z):
			shelters.append(f.shelter)
	for s in shelters:
		for d in s.berths.duplicate():
			if not _w.clock.is_night() or d.bars.warmth >= 0.98:
				s.release(d)


## Seconds until `d`'s first bar of hunger or thirst runs out (INF for someone without needs).
func lasts(d: Drone) -> float:
	if d.needless:
		return INF
	return minf(d.bars.hunger * HUNGER_SECONDS, d.bars.thirst * THIRST_SECONDS)


## Would `d` last a walk of `metres` on the flat (a trip they are planning: Walking.effort reckons its hills in), with some to
## spare? A runner low on water doesn't wheel a load
## 200 m off and back: they stay near the market until they have eaten and drunk. (At the tile by the Main the runners went
## down on the way back from its far waste baskets, having set out half empty.)
func would_last(d: Drone, metres: float) -> bool:
	return metres * DETOUR / maxf(d.speed, 0.1) <= lasts(d) * TRIP_MARGIN


const TRIP_MARGIN := 0.6  # of what their bars have left, a trip may take
const DETOUR := 1.8       # the walk through the streets, against the straight line a trip is reckoned in (round the blocks)


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
	if _w.logistics.collecting.wants(d):
		out.append("collect")  # short of cash: bottles to the depot (Collecting)
	if _w.cash.nearest_loose(d.pos, Cash.SCAN, d.zone) != null:
		out.append("cash")  # last: loose money is only worth a detour when there is nothing better to do
	return out


## The input a working machine is most short of (fewest crafts' worth in hand) among those it has to
## buy from another business, or "".
func short_input(m: Machine) -> String:
	var worst := ""
	var low := float(RESTOCK_BELOW)
	for raw in m.recipe:
		if raw in Catalog.scavenged_goods():
			continue  # salvaged from the bins by runners (or brought by the van): nothing for the vendor to go and fetch
		var crafts: float = float(m.input.count(raw)) / float(m.recipe[raw])
		if crafts < low:
			low = crafts
			worst = raw
	return worst
