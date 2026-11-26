## Lodging: the tent city, the cluster's spawn factory (as in Planet Crafter, where every drone station is a drone). It is the
## tent keeper's business (the "tent" kind), tents for one person each: everyone in the cluster lives in one (`Drone.bed`),
## and while the tent city stands it keeps them warm, day and night (`is_housed`). How many tents it has is how many people the
## cluster holds, up to what its tier allows (`MachineDef.cap`: building it up lets it grow):
##   a tent added   the hero pays for it with the money gun: a tent's price (Catalog "tent"), printed and spent (sunk): the
##                  canvas and the cot. (The keeper also sells tents, of scrap, to take away: one put down in the street
##                  founds a tent city of its own, see `found`.)
##   a free tent    while the tent city stands (repaired), the next of its founders comes for it, one every ARRIVE_EVERY
##                  seconds, in their order (FOUNDERS: the town itself, see Atom), and moves in and stays. Once they have all
##                  come, nobody else does: a filled tent city's economy grows on its own trades, slowly. (Mouths with no
##                  trade outgrew the producers: 2026-11-25.)
## Nobody is turned out: there is no taking a tent away. A wrecked tent city keeps its tents and its people, but nobody new comes,
## and it warms nobody.
## (Barrel fires are things the tent keeper sells, for the hero to place: not part of the tent city.)
class_name Lodging
extends RefCounted

const MERGE := {"waiting": "max"}  # (see Merge)
## The first arrivals to a tent city are not mouths but the town, always in this order: each sets up what it keeps (`role`: a
## premises, a business, or a runner's cart) and moves into the tent that was waiting. A business comes wrecked and its keeper
## broke: the hero's money gets it going. Every tent city brings its own (a second one mirrors the first). After them, nobody.
const FOUNDERS := [
	{"role": "bottle_depot"},
	{"role": "first_aid"},
	{"role": "runner"},
	{"role": "lemonade_stand"},
	{"role": "bakery"},
	{"role": "thrift_stall", "label": "Thrift seller", "camp": true},  # (a stall that works the street's scrap: Camp.pitch, its pile beside it)
	{"role": "scrap_camp", "label": "Camp keeper", "camp": true},
	{"role": "hot_dog_stand"},
]
const RUNNER_PURSE := 20.0  # (a runner's cart is no stall to mend: they come with enough to buy a load off a shelf)
const STALL_ROOM := 2.5      # metres a founder's stall needs clear round it
const ARRIVE_EVERY := 30.0   # seconds between founders, while a tent stands empty
const NEWCOMER_PURSE := 15.0  # what the keeper of a tent city put down in the street brings (`found`)

var waiting := {}  # tent city uid -> seconds an empty tent has waited for its newcomer

var _w: World


func _init(world: World) -> void:
	_w = world


## Everyone who lives in `city`, in the order they came: the `i`th of them has the `i`th tent. (Wherever they are: someone who
## has gone over to the next tile keeps their tent at home, so it is not free for a newcomer.)
func housed(city: Machine) -> Array:
	return _w.drones.filter(func(d): return d.bed == city.uid)


func free_tents(city: Machine) -> int:
	return city.residence.tents - housed(city).size()


## Where `d` sleeps in `city`: the middle of their own tent.
func bed_of(city: Machine, d: Drone) -> Vector2:
	return city.residence.bed_pos(city, maxi(0, housed(city).find(d)))


## A tent in `city` for everyone in its zone who has none, but for `except` (the story's own people, say), putting up as many as
## that takes, free: this is how a cluster is laid out, not something the hero buys.
func house_everyone(city: Machine, except: Array = []) -> void:
	for d in _w.zones.drones_in(city.zone):
		if d.bed == "" and not d in except:
			d.bed = city.uid
	set_tents(city, maxi(city.residence.tents, housed(city).size()))


func set_tents(city: Machine, n: int) -> void:
	city.residence.tents = n
	city.set_level(city.level)
	_w.zones.invalidate()  # (the row's ground changed: the walkers' grid is redrawn)


## Does `d` have a tent in a tent city that stands? (Then they are warm.)
func is_housed(d: Drone) -> bool:
	if d.bed == "":
		return false
	var city = _w.thing(d.bed)
	return city is Machine and city.working


## How many more tents `city` may have at its tier (or as its scenario allowed it: `Residence.tents_cap`).
func room_for(city: Machine) -> int:
	return maxi(0, maxi(Catalog.machine(city.kind).cap, city.residence.tents_cap) - city.residence.tents)


func next_tent_cost(_city: Machine) -> float:
	return Catalog.base_price("tent")


## The hero adds a tent to `city`, printing what it costs. Returns what it cost (0: there is no room at its tier).
func add_tent(city: Machine) -> float:
	if room_for(city) <= 0:
		return 0.0
	var cost := next_tent_cost(city)
	_w.ledger.printed += cost
	_w.ledger.sunk += cost
	set_tents(city, city.residence.tents + 1)
	_w.events.append("t=%d a tent was put up in the %s ($%.0f): %d tents" % [_w.clock.time, city.display_name(), cost, city.residence.tents])
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
	keeper.bed = city.uid
	keeper.arrived_at = _w.clock.time
	set_tents(city, 1)
	_w.arrivals.append(city)
	_w.arrivals.append(keeper)
	_w.events.append("t=%d a tent city was founded: %s keeps it" % [_w.clock.time, keeper.label])
	return city


func step(dt: float) -> void:
	var taken := {}  # tent city uid -> tents taken (counted once a tick, not once a city)
	for d in _w.drones:
		if d.bed != "":
			taken[d.bed] = int(taken.get(d.bed, 0)) + 1
	for m in _w.machines:
		if m.residence == null or m.zone in _w.zones.asleep:
			continue
		if not m.working or m.residence.tents - int(taken.get(m.uid, 0)) <= 0:
			waiting.erase(m.uid)
			continue
		waiting[m.uid] = float(waiting.get(m.uid, 0.0)) + dt
		if waiting[m.uid] >= ARRIVE_EVERY:
			waiting[m.uid] = 0.0
			_newcomer(m)


## Someone turns up for an empty tent in `city`: the next founder.
func _newcomer(city: Machine) -> void:
	arrive(city)


## Whoever comes for `city`'s empty tent comes now (Atom.grow does not wait for them): the next founder, unless a role in `skip`.
## Returns who came (null if there is no empty tent, no founder left, or nowhere clear for theirs yet: they wait).
func arrive(city: Machine, skip: Array = []) -> Drone:
	if free_tents(city) <= 0:
		return null
	var f := next_founder(city, skip)
	return null if f.is_empty() else _found(city, f)


## The next of FOUNDERS that `city` has not brought yet (nor in `skip`), or {} once it has them all. Every tent city brings its
## own, the same way: a second one is a second town of its own (its own bottle depot too).
func next_founder(city: Machine, skip: Array = []) -> Dictionary:
	var brought := {}
	for d in housed(city):
		brought[role_of(d)] = true
	for f in FOUNDERS:
		if not brought.has(f.role) and not skip.has(f.role):
			return f
	return {}


## Who in `city` holds founder role `role` ("bakery", "runner", ...: Lodging.FOUNDERS), or null if they have not come yet.
func founder(city: Machine, role: String) -> Drone:
	for d in housed(city):
		if role_of(d) == role:
			return d
	return null


## Which founder's role `d` holds: the trade's bottom tier for a business (a bakery built up into a bake shop is still the
## bakery the founder brought), the premises' kind, or "runner".
func role_of(d: Drone) -> String:
	match d.kind:
		"runner":
			return "runner"
		"attendant":
			return "bottle_depot"
		"medic":
			return "first_aid"
	var m = _w.machine_of(d)
	if m == null:
		return ""
	var ladder: Array = Catalog.TRADES.get(Catalog.machine(m.kind).trade, [m.kind])
	return ladder[0] if ladder[0] != "" else m.kind


## Where `city`'s next founder sets up: its slot (Atom.seed laid one out for each), or beside the city along its own street.
func _place_for(city: Machine, role: String) -> Dictionary:
	var res := city.residence
	if res.slots.has(role):
		return res.slots[role]
	var along := Vector2(-city.front.y, city.front.x) * res.wing
	return {"at": city.pos - along * Residence.FOUNDER_STEP * float(res.founded + 1), "front": city.front}


## Founder `f` sets up at their place and moves into `city`'s waiting tent. Null if there is nowhere clear to put it (then an
## ordinary newcomer comes instead, and the founder waits for the next free tent).
func _found(city: Machine, f: Dictionary) -> Drone:
	var place := _place_for(city, f.role)
	var at: Vector2 = place.at
	var front: Vector2 = place.front
	var laid_out := city.residence.slots.has(f.role)  # (a place the atom laid out is clear by design: Atom.LAYOUT)
	if not laid_out and f.role != "runner" and (_w.nav.blocked(city.zone, at) or not _clear(city.zone, at)):
		return null
	var was := _w.build_zone
	_w.build_zone = city.zone
	var keeper: Drone
	var made: Variant = null  # (what they set up, for the views)
	match f.role:
		"bottle_depot":
			keeper = _w.add_bottle_depot(at, front)
			made = _w.bottle_depots[_w.bottle_depots.size() - 1]
		"first_aid":
			keeper = _w.add_first_aid(at, front)
			made = _w.hospitals[_w.hospitals.size() - 1]
		"runner":
			keeper = _w.add_runner(at, RUNNER_PURSE)
		_:
			if f.get("camp", false):
				var stall := Camp.pitch(_w, at, front, 0.0, f.role, f.label, false, city)
				stall.working = false  # (found wrecked, like any business: the hero's money mends it)
				stall.refresh()
				keeper = _w.drone(stall.owner)
				made = stall
				_w.arrivals.append(_w.bins[_w.bins.size() - 1])  # (its pile)
				_share(city.zone, "garbage")
			else:
				keeper = _w.add_vendor(f.role, at, 0.0, false, true)
				var m := _w.machine_of(keeper)
				m.front = front
				keeper.pos = m.post()
				made = m
	_w.build_zone = was
	keeper.bed = city.uid
	keeper.arrived_at = _w.clock.time
	city.residence.founded += 1
	if made != null:
		_w.arrivals.append(made)
	_w.arrivals.append(keeper)
	_w.zones.invalidate()
	_w.events.append("t=%d %s came to live in the %s: %s" % [_w.clock.time, keeper.label, city.display_name(), _w.profession_of(keeper).to_lower()])
	return keeper


## The bins of `kind` in `zone` share one bin's rate (WasteBin.KINDS): a stall's pile beside it shows where the scrap lies, but
## the street throws away no more for it. (Three piles at a full rate each had the hostel built of scrap by day 14.)
func _share(zone: String, kind: String) -> void:
	var same := _w.zones.bins_in(zone).filter(func(b): return b.kind == kind)
	for b in same:
		b.rate = float(WasteBin.KINDS[kind].rate) / same.size()


## Is there room for a stall at `at`: nothing else of the street's within STALL_ROOM of it?
func _clear(zone: String, at: Vector2) -> bool:
	for list in [_w.machines, _w.fires, _w.hospitals, _w.bottle_depots, _w.bins]:
		for o in list:
			if o.zone == zone and o.pos.distance_to(at) < STALL_ROOM:
				return false
	return true
