## Planet Crafter's logistics with people as the drones. Machines offer items from their output
## inventories and want items in their input inventories; an idle drone looks for a supply that answers
## its most pressing demand (Needs.demands), walks there, and moves the item, paying with a plain number
## moving between wallets. Also repairs, joining a barrel fire or tent, and a cart runner's deliveries.
class_name Logistics
extends RefCounted

const TRADE_REACH := 2.0
const DISTANCE_COST := 0.02  # a shopper weighs a price against this much per unit of walking
const ARRIVE := 0.3          # close enough to its own stand-off point
const SLOTS := 7             # customers fan out over this many places in front of a stand
const SLOT_RADIUS := 1.5     # how far from a stand they stand (inside TRADE_REACH, and clear of its counter)

var _w: World
var supply: Supply
var hauling: Hauling


func _init(world: World) -> void:
	_w = world
	supply = Supply.new(world)
	hauling = Hauling.new(world)


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
	var stand: Vector2 = d.job.stand
	if d.pos.distance_to(stand) > ARRIVE:
		_w.walking.step(d, stand, dt)
		return
	d.route = PackedVector2Array()
	var done := d.job
	_complete(d, done)
	if is_same(d.job, done):  # a pickup sets up its own drop; anything else is simply finished
		d.job = {}


## Where a drone waits when it has nothing to do: a vendor behind their stand, a keeper behind the food
## bank's counter, a runner at home. Null for everyone else (they stay where they are).
func _idle_post(d: Drone):
	var m = _w.machine_of(d)
	if m != null:
		return m.post()
	var fb = _w.food_bank_of(d)
	if fb != null:
		return fb.post()
	if d.kind == "runner" and d.home.is_finite():
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
			"cash":
				var bill: Bill = _w.cash.nearest_loose(d.pos, Cash.SCAN, d.zone)
				if bill != null:
					job = {"for": "cash", "target": bill, "item": ""}
			_:
				var m := supply.best_supply(d, cls)
				if m:
					job = {"for": cls, "target": m, "item": m.item}
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
		if o != d and not o.job.is_empty() and o.job.target == target:
			rank += 1
	if job["for"] == "repair":
		return target.post()
	if target is Bill:
		return target.pos if rank == 0 else target.pos + Vector2.from_angle(TAU * float(rank) / 5.0) * 0.55
	if target is BarrelFire or (target is Machine and target.shelter != null):
		return target.shelter.berth_pos(target.pos, target.shelter.berths.size() + rank)
	var slot := rank % SLOTS
	var ring := rank / SLOTS
	var angle := (float(slot) - (SLOTS - 1) * 0.5) * 0.36  # fanned out about +-62 degrees round the front: all in front of the counter
	return target.pos + target.front.rotated(angle) * (SLOT_RADIUS + 0.45 * ring)


func _still_valid(job: Dictionary) -> bool:
	var t = job.target
	match job["for"]:
		"haul":
			var dest = job.dest if job.stage == "pickup" else t
			if not dest.working or dest.input.room(job.item) < 1:
				return false
			return t.offers(job.item) if job.stage == "pickup" else true
		"cash":
			return t.loose and _w.bills.has(t)
		"repair":
			return not t.working
		"warmth":
			if t is BarrelFire:
				return t.shelter.has_room()
	return t.offers(job.item)


## At the target: repair the machine, join a barrel fire, or move one item from the supplier's output
## inventory through the drone's hands to where it is going, paying for it.
func _complete(d: Drone, job: Dictionary) -> void:
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
	if t is BarrelFire:
		t.shelter.admit(d)
		d.pos = t.shelter.berth_pos(t.pos, t.shelter.berths.size() - 1)
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
	if Catalog.class_of(item) == "warmth":
		t.shelter.admit(d)
		d.pos = t.shelter.berth_pos(t.pos, t.shelter.berths.size() - 1)
	else:
		_w.needs.eat(d, item)


## A machine's takings go to its owner, less the player's share.
func pay_supplier(s: Machine, price: float) -> void:
	s.sold_total += 1
	s.revenue_total += price
	s.refresh()
	var cut: float = s.equity.cut_of(price)
	_w.ledger.player_cash += cut
	_w.ledger.stake_income += cut
	_w.drones[s.owner_id].wallet += price - cut
