## Lodging: the tent city, the cluster's spawn factory (as in Planet Crafter, where every drone station is a drone). It is the
## tent keeper's business (the "tent" kind), tents for one person each: everyone in the cluster lives in one (`Drone.bed`),
## and while the tent city stands it keeps them warm, day and night (`is_housed`). How many tents it has is how many people the
## cluster holds, up to what its tier allows (`MachineDef.cap`: building it up lets it grow):
##   a tent added   the hero pays for it with the money gun: a tent's price (Catalog "tent"), printed and spent (sunk): the
##                  canvas and the cot. (The keeper also sells tents, of scrap, to take away: one put down in the street
##                  founds a tent city of its own, see `found`.)
##   a free tent    while the tent city stands (repaired), someone comes for it: one every ARRIVE_EVERY seconds, with
##                  NEWCOMER_PURSE dollars (new money, counted as printed: they brought it), who moves in and stays. Who
##                  comes is a weighted roll of the kinds of people there are (NEWCOMERS): the cluster's base set is laid out
##                  by Atom; it is growth that is left to the dice.
## Nobody is turned out: there is no taking a tent away. A wrecked tent city keeps its tents and its people, but nobody new comes,
## and it warms nobody.
## (Barrel fires are things the tent keeper sells, for the hero to place: not part of the tent city.)
class_name Lodging
extends RefCounted

const MERGE := {"waiting": "max"}  # (see Merge)
## Who a newcomer is, by weight: every kind of person there is so far that needs no premises of their own.
const NEWCOMERS := {"drifter": 3.0, "runner": 1.0}
const ARRIVE_EVERY := 30.0   # seconds between newcomers, while a tent stands empty
const NEWCOMER_PURSE := 15.0
const NEWCOMER_FROM := 28.0  # metres down the street from the tents that a newcomer walks in from
const NAMES := ["Aylin", "Bruno", "Chiara", "Dimitri", "Elif", "Finn", "Greta", "Hamza", "Ilse", "Jonas", "Kemal", "Lotte",
	"Milan", "Nora", "Olek", "Paula", "Rafa", "Sven", "Tamar", "Ugo", "Vera", "Wim", "Yusuf", "Zora"]

var waiting := {}  # tent city uid -> seconds an empty tent has waited for its newcomer

var _w: World


func _init(world: World) -> void:
	_w = world


## Everyone who lives in `city`, in the order they came: the `i`th of them has the `i`th tent. (Wherever they are: someone who
## has gone over to the next tile keeps their tent at home, so it is not free for a newcomer.)
func housed(city: Machine) -> Array:
	return _w.drones.filter(func(d): return d.bed == city.uid)


func free_tents(city: Machine) -> int:
	return city.tents - housed(city).size()


## Where `d` sleeps in `city`: the middle of their own tent.
func bed_of(city: Machine, d: Drone) -> Vector2:
	return city.bed_pos(maxi(0, housed(city).find(d)))


## A tent in `city` for everyone in its zone who has none, but for `except` (the story's own people, say), putting up as many as
## that takes, free: this is how a cluster is laid out, not something the hero buys.
func house_everyone(city: Machine, except: Array = []) -> void:
	for d in _w.zones.drones_in(city.zone):
		if d.bed == "" and not d in except:
			d.bed = city.uid
	set_tents(city, maxi(city.tents, housed(city).size()))


func set_tents(city: Machine, n: int) -> void:
	city.tents = n
	city.set_level(city.level)
	_w.zones.invalidate()  # (the row's ground changed: the walkers' grid is redrawn)


## Does `d` have a tent in a tent city that stands? (Then they are warm.)
func is_housed(d: Drone) -> bool:
	if d.bed == "":
		return false
	var city = _w.thing(d.bed)
	return city is Machine and city.working


## How many more tents `city` may have at its tier (or as its scenario allowed it: `Machine.tents_cap`).
func room_for(city: Machine) -> int:
	return maxi(0, maxi(Catalog.machine(city.kind).cap, city.tents_cap) - city.tents)


func next_tent_cost(_city: Machine) -> float:
	return Catalog.base_price("tent")


## The hero adds a tent to `city`, printing what it costs. Returns what it cost (0: there is no room at its tier).
func add_tent(city: Machine) -> float:
	if room_for(city) <= 0:
		return 0.0
	var cost := next_tent_cost(city)
	_w.ledger.printed += cost
	_w.ledger.sunk += cost
	set_tents(city, city.tents + 1)
	_w.events.append("t=%d a tent was put up in the %s ($%.0f): %d tents" % [_w.clock.time, city.display_name(), cost, city.tents])
	return cost


## A tent put down in the street at `at`, its open end toward `front`: a tent city of its own, at tier 0, standing, with one
## tent, and a newcomer who keeps it and lives in it (a name nobody near has). It grows as any does: a tent put up brings someone
## new. Returns the tent city. (The tent itself was bought: nothing is printed here but the keeper's purse, which they brought.)
func found(at: Vector2, front: Vector2, zone: String) -> Machine:
	var was := _w.build_zone
	_w.build_zone = zone
	var keeper := _w.add_vendor("tent", at, NEWCOMER_PURSE, true, false)
	_w.build_zone = was
	var city := _w.machine_of(keeper)
	city.front = front
	keeper.pos = city.post()
	keeper.label = _free_name(zone)
	keeper.bed = city.uid
	keeper.arrived_at = _w.clock.time
	set_tents(city, 1)
	_w.arrivals.append(city)
	_w.arrivals.append(keeper)
	_w.events.append("t=%d a tent city was founded: %s keeps it" % [_w.clock.time, keeper.label])
	return city


## A name nobody in `zone` has, while there are any.
func _free_name(zone: String) -> String:
	var taken := _w.zones.drones_in(zone).map(func(o): return o.label)
	var names := NAMES.filter(func(n): return not n in taken)
	if names.is_empty():
		names = NAMES
	return names[_w.random().randi() % names.size()]


func step(dt: float) -> void:
	var taken := {}  # tent city uid -> tents taken (counted once a tick, not once a city)
	for d in _w.drones:
		if d.bed != "":
			taken[d.bed] = int(taken.get(d.bed, 0)) + 1
	for m in _w.machines:
		if m.shelter == null or m.zone in _w.zones.asleep:
			continue
		if not m.working or m.tents - int(taken.get(m.uid, 0)) <= 0:
			waiting.erase(m.uid)
			continue
		waiting[m.uid] = float(waiting.get(m.uid, 0.0)) + dt
		if waiting[m.uid] >= ARRIVE_EVERY:
			waiting[m.uid] = 0.0
			_newcomer(m)


## Who the next newcomer is: a weighted roll of NEWCOMERS, with the world's dice.
func _roll() -> String:
	var total := 0.0
	for k in NEWCOMERS:
		total += NEWCOMERS[k]
	var r := _w.rng.randf() * total
	for k in NEWCOMERS:
		r -= NEWCOMERS[k]
		if r < 0.0:
			return k
	return NEWCOMERS.keys().back()


## Someone turns up for an empty tent in `city`: they walk in from down the street, with a little money.
func _newcomer(city: Machine) -> void:
	var was := _w.build_zone
	_w.build_zone = city.zone
	var down_the_street := Vector2(-city.front.y, city.front.x) * city.wing * NEWCOMER_FROM
	var role := _roll()
	var at := city.pos + down_the_street
	var d := _w.add_runner(at, NEWCOMER_PURSE) if role == "runner" else _w.add_drifter(at, NEWCOMER_PURSE)
	_w.build_zone = was
	d.label = _free_name(city.zone)
	d.bed = city.uid
	d.arrived_at = _w.clock.time
	_w.arrivals.append(d)
	_w.events.append("t=%d %s came to live in the %s" % [_w.clock.time, d.label, city.display_name()])
