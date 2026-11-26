## People passing through: they come in at one gate (a station's door, a tram stop), cross to another and are gone. Each has
## a level, the cash that goes with it, and their own hunger and thirst. On the way they stoop for any loose money, and call at
## a stand near their way that sells what they are short of, queuing like anyone. One who leaves still short of something they
## never got to buy is a lost sale.
##
## They are drones (they walk, queue, buy, can be given money), but kept in a list of their own (World.visitors), so nothing
## of the town's counts them: no errands, no collapsing, no bed, nothing thrown in the bins. What they need is the town's
## supply: its stands sell them only what they have beyond a reserve (KEEP), and that is made of what the bins give.
##
## Who comes and goes is the landing's to say (`gates`: none, and nobody passes), how many is the hour's (PER_HOUR).
class_name Passersby
extends RefCounted

## How many set out in a game hour, by the hour of the day (the clock's): rush hours morning, midday and evening.
const RUSH := 10.0
const BY_DAY := 3.0
const BY_NIGHT := 0.4
const RUSH_HOURS := [7, 8, 12, 13, 17, 18]
const DAY_HOURS := [6, 21]       # from, until
const MOST := 25                 # about at once, at most
const CLUMP := [2, 5]            # how many step off together at a stop
## Levels, and how likely each is; the cash someone brings is CASH plus CASH_A_LEVEL for each level, give or take CASH_GIVE.
const LEVELS := [0.6, 0.25, 0.1, 0.05]
const CASH := 2.0
const CASH_A_LEVEL := 3.0
const CASH_GIVE := 1.0
const NEEDS := ["hunger", "thirst"]   # theirs (the cold is the residents' business)
const BAR_FROM := 0.2            # each bar starts somewhere from here to full
const WANTS_BELOW := 0.6         # ...and below this they would buy
const DETOUR := 25.0             # metres off their way they will go for it
const KEEP := 3                  # a stand keeps this many back for the town's own
const LONGEST_LINE := 5          # nobody joins a longer queue
const WAIT := 45.0               # seconds they will give a stand
const STAY := 300.0              # and the longest anyone is about
const ARRIVED := 1.5
const LOOKS := ["commuter", "walker", ""]

const MERGE := {"served": "sum", "lost": "sum", "sales": "sum"}

## Where they come and go: [{zone, at: Vector2, kind: "station" | "stop" | "street"}]. A way runs between two kinds. From the
## map, not saved.
var gates: Array = []
var served := {"food": 0, "drink": 0}     # sales to them today...
var lost := {"food": 0, "drink": 0}       # ...and those who left today still wanting, never having had it
var yesterday := {}                       # {served, lost}
var sales := 0                            # every sale to a passerby, all told
var _due := 0.0
var _day := 0
var _had := {}                            # uid -> {class: true}: what each has bought
var _passed := {}                         # uid -> [machine uid]: the lines they gave up on

var _w: World


func _init(world: World) -> void:
	_w = world


## How many set out an hour, at `hour` of the day.
static func rate(hour: float) -> float:
	var h := int(hour)
	if h in RUSH_HOURS:
		return RUSH
	return BY_DAY if h >= DAY_HOURS[0] and h < DAY_HOURS[1] else BY_NIGHT


func step(dt: float) -> void:
	if _w.clock.day() != _day:
		_new_day()
	var running := _w.zones.running()
	var open := gates.filter(func(g): return g.zone in running)
	if not open.is_empty():
		_due += rate(_w.clock.hour()) * dt / (Clock.DAY_SECONDS / 24.0)
		while _due >= 1.0 and _w.visitors.size() < MOST:
			_due -= _set_out(open)
		_due = minf(_due, 1.0)  # (a full street does not save them up)
	for d in _w.visitors.duplicate():
		if d.zone in running:
			_go(d, dt)


## Someone sets out from `from` for `to`: level and cash rolled, hunger and thirst as they happen to be.
func arrive(zone: String, from: Vector2, to: Vector2) -> Drone:
	var dice := _w.rng
	var d := Drone.new(from)
	d.kind = "passerby"
	d.zone = zone
	d.look = LOOKS[dice.randi_range(0, LOOKS.size() - 1)]
	d.home = to
	d.arrived_at = _w.clock.time
	_w.mint(d)
	d.label = Names.of(d.uid)
	var roll := dice.randf()
	var level := 1
	while level < LEVELS.size() and roll > LEVELS[level - 1]:
		roll -= LEVELS[level - 1]
		level += 1
	d.growth.add(Growth.total_for(level))
	d.wallet = snappedf(CASH + CASH_A_LEVEL * level + dice.randf_range(-CASH_GIVE, CASH_GIVE), 0.25)
	for bar in NEEDS:
		d.bars[bar] = dice.randf_range(BAR_FROM, 1.0)
	_w.ledger.brought += d.wallet
	_w.visitors.append(d)
	_w.arrivals.append(d)
	return d


## One or a clump of them, from a gate to one of another kind. Returns how many.
func _set_out(open: Array) -> int:
	var dice := _w.rng
	var from: Dictionary = open[dice.randi_range(0, open.size() - 1)]
	var ends := open.filter(func(g): return g.zone == from.zone and g.kind != from.kind)
	if ends.is_empty():
		return 1
	var count := dice.randi_range(CLUMP[0], CLUMP[1]) if from.kind == "stop" else 1
	count = mini(count, MOST - _w.visitors.size())
	for k in count:
		var to: Dictionary = ends[dice.randi_range(0, ends.size() - 1)]
		var spread := Vector2(dice.randf_range(-1.2, 1.2), dice.randf_range(-1.2, 1.2))
		arrive(from.zone, (from.at as Vector2) + spread, (to.at as Vector2) + spread)
	return maxi(1, count)


func _go(d: Drone, dt: float) -> void:
	if _w.clock.time - d.arrived_at > STAY:
		_leave(d)
		return
	if d.job.get("for") != "cash":
		var bill := _w.cash.nearest_loose(d.pos, Cash.SCAN, d.zone)
		if bill != null:  # money in the street comes before anything
			_drop_errand(d)
			d.job = {"for": "cash", "target": bill, "item": ""}
	if d.job.get("for") == "cash":
		var bill: Bill = d.job.target
		if not _w.bills.has(bill) or not bill.loose:
			d.job = {}
		elif d.pos.distance_to(bill.pos) <= Cash.REACH:
			_w.cash.collect(d, bill)
			d.job = {}
		else:
			_w.walking.step(d, bill.pos, dt)
		return
	if d.job.is_empty():
		d.job = _errand(d)
	if not d.job.is_empty():
		_shop(d, dt)
		return
	_w.walking.step(d, d.home, dt)
	if d.pos.distance_to(d.home) <= ARRIVED:
		_leave(d)


## What they would call for on the way: the nearest cheap answer to what they are shortest of, near enough their way. {} if
## there is none.
func _errand(d: Drone) -> Dictionary:
	var short := NEEDS.filter(func(bar): return d.bars[bar] < WANTS_BELOW)
	short.sort_custom(func(a, b): return d.bars[a] < d.bars[b])
	for bar in short:
		var cls: String = Drone.BARS[bar].cls
		var best := {}
		var best_value := INF
		for m in _w.zones.machines_in(d.zone):
			var off := Geometry2D.get_closest_point_to_segment(m.pos, d.pos, d.home).distance_to(m.pos)
			if off > DETOUR or m.uid in _passed.get(d.uid, []) or _w.logistics.queues.length(m) >= LONGEST_LINE:
				continue
			for item in _w.logistics.supply.answering(m, cls):
				if not _sells(m, item, d):
					continue
				var value: float = m.price_of(item) / Catalog.restores(item) + Logistics.DISTANCE_COST * d.pos.distance_to(m.pos)
				if value < best_value:
					best_value = value
					best = {"for": cls, "target": m, "item": item, "since": _w.clock.time}
		if not best.is_empty():
			return best
	return {}


## Will `m` sell `d` an `item`: open, with more than it keeps back, at a price they can pay?
func _sells(m: Machine, item: String, d: Drone) -> bool:
	return m.working and m.offers(item) and m.output.count(item) > KEEP and m.price_of(item) <= d.wallet


func _shop(d: Drone, dt: float) -> void:
	var m: Machine = d.job.target
	var given_up: bool = _w.clock.time - float(d.job.since) > WAIT
	if given_up or not _sells(m, d.job.item, d):
		if given_up:
			if not _passed.has(d.uid):
				_passed[d.uid] = []
			_passed[d.uid].append(m.uid)
		_drop_errand(d)
		return
	if not _w.logistics.queues.wait(d, m, dt, _w.walking, 1.0):
		return
	var cls: String = d.job["for"]
	_w.logistics.complete(d, d.job)
	if not _had.has(d.uid):
		_had[d.uid] = {}
	_had[d.uid][cls] = true
	served[cls] = int(served.get(cls, 0)) + 1
	sales += 1
	_drop_errand(d)


func _drop_errand(d: Drone) -> void:
	var target = d.job.get("target")
	if target is Machine:
		_w.logistics.queues.leave(d, target)
	d.job = {}


## Gone, with what is left of their money. Still short of something they never had here: a lost sale.
func _leave(d: Drone) -> void:
	_drop_errand(d)
	for bar in NEEDS:
		var cls: String = Drone.BARS[bar].cls
		if d.bars[bar] < WANTS_BELOW and not _had.get(d.uid, {}).has(cls):
			lost[cls] = int(lost.get(cls, 0)) + 1
	_had.erase(d.uid)
	_passed.erase(d.uid)
	_w.ledger.taken += d.wallet
	_w.visitors.erase(d)
	_w.forget(d)


func _new_day() -> void:
	_day = _w.clock.day()
	if int(served.food) + int(served.drink) + int(lost.food) + int(lost.drink) > 0:
		yesterday = {"served": served.duplicate(), "lost": lost.duplicate()}
		_w.events.append("Passersby yesterday: %s." % summary(served, lost))
	served = {"food": 0, "drink": 0}
	lost = {"food": 0, "drink": 0}


## "12 served · 5 left thirsty · 2 left hungry"
static func summary(sold: Dictionary, missed: Dictionary) -> String:
	return "%d served · %d left thirsty · %d left hungry" % [int(sold.food) + int(sold.drink), int(missed.drink), int(missed.food)]
