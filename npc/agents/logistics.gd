## Planet Crafter's logistics with people as the drones. Machines offer items from their output
## inventories and want items in their input inventories; an idle drone looks for a supply that answers
## its most pressing demand (Needs.demands), walks there, and moves the item, paying with a plain number
## moving between wallets. Also repairs, joining a barrel fire or tent, a cart runner's deliveries, and collecting bottles for
## the deposit (Collecting).
class_name Logistics
extends RefCounted

const TRADE_REACH := 2.0
const DISTANCE_COST := 0.02  # a shopper weighs a price against this much per unit of walking
const ARRIVE := 0.3          # close enough to its own stand-off point
const SLOT_RADIUS := 1.5     # how far from a stand they stand (inside TRADE_REACH, and clear of its counter)

var _w: World
var supply: Supply
var hauling: Hauling
var collecting: Collecting
var queues := Queueing.new()


func _init(world: World) -> void:
	_w = world
	supply = Supply.new(world)
	hauling = Hauling.new(world)
	collecting = Collecting.new(world)


func act(d: Drone, dt: float) -> void:
	if d.sheltered_in != null or d.unconscious() or d.aloof:
		return
	if d.job.is_empty():
		d.job = plan(d)
	if d.job.is_empty():
		var post = _idle_post(d)
		if post != null and d.pos.distance_to(post) > 0.5:
			_w.walking.step(d, post, dt)
		else:
			d.route = PackedVector2Array()
		return
	if not _still_valid(d.job):
		d.job = {}
		return
	if Queueing.applies(d.job):
		var m: Machine = d.job.target
		if queues.place(d, m) != 0 and _gives_up_place(d):  # (the one at the front is being served: they stay)
			queues.leave(d, m)
			d.job = {}  # next tick they plan again, and what they need most is first
			return
		if not queues.wait(d, m, dt, _w.walking, _w.needs.pace(d, d.job)):
			return
		queues.leave(d, m)
		var served := d.job
		complete(d, served)
		if is_same(d.job, served):
			d.job = {}
		return
	var stand: Vector2 = d.job.stand
	if d.pos.distance_to(stand) > ARRIVE:
		_w.walking.step(d, stand, dt * _w.needs.pace(d, d.job))
		return
	d.route = PackedVector2Array()
	var done := d.job
	complete(d, done)
	if is_same(d.job, done):  # a pickup sets up its own drop; anything else is simply finished
		d.job = {}


## Is someone waiting in a line (or on the way to one) now so much in need of something else that they should leave it? They
## do when another survival bar has fallen below Queueing.LEAVE_BELOW and is clearly lower than the one they are queuing for
## (a drink, while they wait for food), and there is somewhere that can answer it. Back in need of the first, they join its
## line at the back, like anyone arriving.
func _gives_up_place(d: Drone) -> bool:
	var own: String = Needs.NEED_OF.get(d.job["for"], "")
	var own_bar: float = d.bars[own] if own != "" else 1.0
	for cls in Needs.NEED_OF:
		var bar: String = Needs.NEED_OF[cls]
		if cls == d.job["for"] or d.bars[bar] >= Queueing.LEAVE_BELOW or d.bars[bar] > own_bar - Queueing.LEAVE_MARGIN:
			continue
		var answer = supply.warmth_job(d) if cls == "warmth" else supply.best_supply(d, cls)
		if not answer.is_empty() if answer is Dictionary else answer != null:
			return true
	return false


## Where a drone waits when it has nothing to do: a vendor behind their stand, a runner at home. Null for everyone else (they
## stay where they are).
func _idle_post(d: Drone):
	var m = _w.machine_of(d)
	if m != null:
		return m.post()
	if d.kind in ["runner", "medic"] and d.home.is_finite():
		return d.home
	return null


func plan(d: Drone) -> Dictionary:
	for cls in _w.needs.demands(d):
		var job := {}
		match cls:
			"repair":
				job = {"for": "repair", "target": _w.machine_of(d), "item": ""}
			"restock":
				job = supply.restock_job(d)
			"warmth":
				job = supply.warmth_job(d)
			"haul":
				job = hauling.haul_job(d)
			"collect":
				job = collecting.job(d)
			"cash":
				var bill: Bill = _w.cash.nearest_loose(d.pos, Cash.SCAN, d.zone)
				if bill != null:
					job = {"for": "cash", "target": bill, "item": ""}
			_:
				var offer := supply.best_offer(d, cls)
				if not offer.is_empty():
					job = {"for": cls, "target": offer.machine, "item": offer.item}
		if not job.is_empty():
			job["stand"] = stand_point(d, job)
			return job
	return {}


## Where this drone will stand to do its job: its own place near the target, so nobody ends up on
## anyone else's coordinates. The place is picked by how many other drones are already heading for the
## same target (so it is deterministic, and costs one pass over the drones). Customers of a stand fan out
## in front of it, sleepers take the next free seat round a fire or tent, bill-fetchers stand a step apart,
## and a vendor repairing their own stand stands at their post behind it.
func stand_point(d: Drone, job: Dictionary) -> Vector2:
	var target = job.target
	var rank := 0
	for o in _w.zones.drones_in(d.zone):
		if o != d and not o.job.is_empty() and is_same(o.job.target, target):  # (a target may be a tile's name: see Borders)
			rank += 1
	if job["for"] == "repair":
		return target.post()
	if target is Bill:
		return target.pos if rank == 0 else target.pos + Vector2.from_angle(TAU * float(rank) / 5.0) * 0.55
	if target is BarrelFire:
		return target.shelter.berth_pos(target.pos, target.shelter.berths.size() + rank)
	if target is Machine and target.shelter != null:
		return _w.lodging.bed_of(target, d)  # (their own tent)
	if Queueing.applies(job):
		return Queueing.spot(target, rank)  # the back of the line (see Queueing)
	return target.pos + target.front * SLOT_RADIUS


func _still_valid(job: Dictionary) -> bool:
	var t = job.target
	match job["for"]:
		"haul":
			var dest = job.dest if job.stage == "pickup" else t
			if not dest.working or dest.input.room(job.item) < 1:
				return false
			return t.offers(job.item) if job.stage == "pickup" else true
		"collect":
			return t.offers(job.item) if job.stage == "pickup" else _w.bottle_depots.has(t)
		"cash":
			return t.loose and _w.bills.has(t)
		"repair":
			return not t.working
		"warmth":
			if t is BarrelFire:
				return t.shelter.has_room()
			if t is Machine and t.shelter != null:
				return t.working and t.shelter.has_room()
		"leave":
			return true  # walking to the border with the next tile (see Borders)
	return t.offers(job.item)


## At the target: repair the machine, join a barrel fire, or move one item from the supplier's output
## inventory through the drone's hands to where it is going, paying for it. (A dormant tile's summary calls this too, with no
## walk first: see TileSummary.)
func complete(d: Drone, job: Dictionary) -> void:
	var t = job.target
	if job["for"] == "repair":
		if d.wallet < t.repair_cost:
			return
		d.wallet -= t.repair_cost
		_w.ledger.sunk += t.repair_cost
		t.working = true
		t.refresh()
		_w.events.append("t=%d the %s is repaired" % [_w.clock.time, t.display_name()])
		return
	if job["for"] == "cash":
		_w.cash.collect(d, t)
		return
	if job["for"] == "haul":
		hauling.complete(d, job)
		return
	if job["for"] == "collect":
		collecting.complete(d, job)
		return
	if job["for"] == "leave":
		_w.borders.cross(d, t)  # at the border: over into the next tile
		return
	if t is BarrelFire:
		t.shelter.admit(d)
		d.pos = t.shelter.berth_pos(t.pos, t.shelter.berths.size() - 1)
		return
	if job["for"] == "warmth" and t is Machine and t.shelter != null:  # into their own bed (free: see Lodging)
		if t.working and t.shelter.has_room():
			t.shelter.admit(d)
			d.pos = _w.lodging.bed_of(t, d)
		return
	var item: String = job.item
	var price: float = t.price_of(item)
	if d.wallet < price:
		return
	t.output.move_to(d.carry, item, 1)
	d.wallet -= price
	pay_supplier(t, price)
	if job["for"] == "restock":
		_w.machine_of(d).receive(item, d.carry.take(item, 1), price)
		return
	d.carry.take(item, 1)  # and use it
	_w.needs.eat(d, item)


## A machine's takings go to its owner, less the heroes' shares (each into their own pocket, whether or not they are here).
func pay_supplier(s: Machine, price: float) -> void:
	s.sold_total += 1
	s.revenue_total += price
	s.refresh()
	var paid := 0.0
	var cuts := s.equity.cuts(price)
	for hero in cuts:
		_w.ledger.pay(hero, cuts[hero])
		paid += cuts[hero]
	_w.drone(s.owner).wallet += price - paid
