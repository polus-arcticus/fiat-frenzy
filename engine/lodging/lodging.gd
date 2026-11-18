## Lodging: the tent as the cluster's drone bay (as in Planet Crafter, where every drone station is a drone). Everyone in a
## cluster has a bed in its tent, their home: at night they sleep in it, free, warmed by its barrels. How many beds the tent has
## is how many people the cluster holds:
##   a free bed     while the tent is working (repaired), a newcomer turns up for it every ARRIVE_EVERY seconds, with
##                  NEWCOMER_PURSE dollars (new money, counted as printed: they brought it), and moves in
##   a bed added    the hero pays for it with the money gun: BED_COST, and BARREL_COST more when it is the first bed of a new
##                  module (each barrel warms the tent's `cap` beds: four for a tent, eight for a hostel). The money is printed
##                  and spent (sunk): the canvas, the cot, the barrel.
##   a bed taken    away: a free bed simply goes. If every bed is taken, the newest drifter packs up and leaves town, and their
##                  money goes with them (sunk). The people who run the town's businesses never leave this way.
## A wrecked tent keeps its beds (and its people), but nobody new comes, and it warms nobody: they go to the barrel fire.
class_name Lodging
extends RefCounted

const MERGE := {"waiting": "max"}  # (see Merge)
const BED_COST := 15.0
const BARREL_COST := 25.0
const ARRIVE_EVERY := 30.0   # seconds between newcomers, while a tent has a free bed
const NEWCOMER_PURSE := 15.0
const NEWCOMER_FROM := 28.0  # metres down the street from the tent that a newcomer walks in from
const NAMES := ["Aylin", "Bruno", "Chiara", "Dimitri", "Elif", "Finn", "Greta", "Hamza", "Ilse", "Jonas", "Kemal", "Lotte",
	"Milan", "Nora", "Olek", "Paula", "Rafa", "Sven", "Tamar", "Ugo", "Vera", "Wim", "Yusuf", "Zora"]

var waiting := {}  # tent uid -> seconds a free bed has waited for its newcomer

var _w: World


func _init(world: World) -> void:
	_w = world


## Everyone who has a bed in `tent`, in the order they came. (Wherever they are: someone who has gone over to the next tile
## keeps their bed at home, so it is not free for a newcomer.)
func housed(tent: Machine) -> Array:
	return _w.drones.filter(func(d): return d.bed == tent.uid)


func free_beds(tent: Machine) -> int:
	return tent.beds - housed(tent).size()


## Gives everyone in `tent`'s zone who has needs and no bed a bed in it (building as many as that takes, free: this is how a
## cluster is laid out, not something the hero buys).
func house_everyone(tent: Machine) -> void:
	for d in _w.zones.drones_in(tent.zone):
		if d.bed == "" and not d.needless and not d.aloof:
			d.bed = tent.uid
	set_beds(tent, maxi(tent.beds, housed(tent).size()))


func set_beds(tent: Machine, n: int) -> void:
	var before := tent.modules()
	tent.beds = n
	tent.set_level(tent.level)
	if tent.modules() != before:
		_w.zones.invalidate()  # (the tent's ground changed: the walkers' grid is redrawn)


## What the next bed costs: a bed, and a barrel too if it starts a new module.
func next_bed_cost(tent: Machine) -> float:
	return BED_COST + (BARREL_COST if tent.beds % tent.beds_per_barrel() == 0 else 0.0)


## The hero adds a bed to `tent`, printing what it costs. Returns what it cost.
func add_bed(tent: Machine) -> float:
	var cost := next_bed_cost(tent)
	_w.ledger.printed += cost
	_w.ledger.sunk += cost
	set_beds(tent, tent.beds + 1)
	_w.events.append("t=%d a bed was added to the %s ($%.0f): %d beds" % [_w.clock.time, tent.display_name(), cost, tent.beds])
	return cost


## Who would leave if a bed were taken from `tent` with none free: the newest fit drifter in it, or null.
func who_would_leave(tent: Machine) -> Drone:
	var people := housed(tent).filter(func(d): return d.kind == "drifter" and d.care == "")
	return people.back() if not people.is_empty() else null


## The hero takes a bed away from `tent`. Returns whoever left for it (null if a bed was free); false if it can't be done
## (no bed free, and nobody who could leave).
func remove_bed(tent: Machine) -> Variant:
	if tent.beds <= 0:
		return false
	if free_beds(tent) > 0:
		set_beds(tent, tent.beds - 1)
		return null
	var leaver := who_would_leave(tent)
	if leaver == null:
		return false
	depart(leaver)
	set_beds(tent, tent.beds - 1)
	return leaver


## `d` packs up and leaves town, with their money (sunk: it is gone from the world).
func depart(d: Drone) -> void:
	if d.sheltered_in != null:
		d.sheltered_in.release(d)
	for m in _w.zones.machines_in(d.zone):
		m.line.erase(d)
	_w.ledger.sunk += d.wallet
	d.wallet = 0.0
	d.job = {}
	d.bed = ""
	d.gone = true
	_w.drones.erase(d)
	_w.reindex()
	_w.events.append("t=%d %s packed up and left town" % [_w.clock.time, d.label if d.label != "" else "a drifter"])


func step(dt: float) -> void:
	var taken := {}  # tent uid -> beds taken (counted once a tick, not once a tent)
	for d in _w.drones:
		if d.bed != "":
			taken[d.bed] = int(taken.get(d.bed, 0)) + 1
	for m in _w.machines:
		if m.shelter == null or m.zone in _w.zones.asleep:
			continue
		if not m.working or m.beds - int(taken.get(m.uid, 0)) <= 0:
			waiting.erase(m.uid)
			continue
		waiting[m.uid] = float(waiting.get(m.uid, 0.0)) + dt
		if waiting[m.uid] >= ARRIVE_EVERY:
			waiting[m.uid] = 0.0
			_newcomer(m)


## Someone turns up for a free bed in `tent`: they walk in from down the street, with a little money.
func _newcomer(tent: Machine) -> void:
	var was := _w.build_zone
	_w.build_zone = tent.zone
	var down_the_street := Vector2(-tent.front.y, tent.front.x) * tent.wing * NEWCOMER_FROM
	var d := _w.add_drifter(tent.pos + down_the_street, NEWCOMER_PURSE)
	_w.build_zone = was
	var taken := _w.zones.drones_in(tent.zone).map(func(o): return o.label)
	var names := NAMES.filter(func(n): return not n in taken)  # (a name nobody here has, while there are any)
	if names.is_empty():
		names = NAMES
	d.label = names[_w.random().randi() % names.size()]
	d.bed = tent.uid
	_w.arrivals.append(d)
	_w.events.append("t=%d %s came to live in the %s" % [_w.clock.time, d.label, tent.display_name()])
