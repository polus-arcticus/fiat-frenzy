## Where two loaded tiles meet (see TileKey, Zones.adjacent), and what crosses between them. This is how separately built
## towns, two players' tiles side by side, grow into one economy and settle into a new balance:
##   people   a drifter who needs food or drink and cannot get it at home (nothing for sale, or nothing they can afford), or
##            would pay more than CROSSING_COST over what the next tile asks, goes over. In a running tile they walk to the
##            border and step across; in a dormant one they are simply sent.
##   goods    a cart runner (from either side) buys a load at one tile's food bank and delivers it to the other tile's short
##            shops, by the ordinary hauling rules (Hauling.haul_job), at most one cart each way per border every CARTS_EVERY
##            seconds (the trip is long).
## Vendors and keepers never cross (they are tied to their stands). Money only moves in wallets, as it always does, so the
## world's total is unchanged. Flows die away by themselves once nobody is short or cheaper over the border: that is the
## balance.
class_name Borders
extends RefCounted

const EVERY := 10.0            # seconds between looks across the borders
const CROSSING_COST := 1.0     # dollars a better price over the border must save before someone goes for it
const MIGRANTS_PER_LOOK := 1   # at most this many people cross each border, each way, per look
const CARTS_EVERY := 120.0     # one cartload across each border, each way, this often
const STEP_IN := 1.5           # how far into the next tile someone arrives
const MERGE := {"crossings": "sum", "carts": "sum"}

var crossings := 0   # people who have crossed a border, since the start
var carts := 0       # cartloads traded across one
var _acc := 0.0
var _cart_clock := {}  # "to<from" -> seconds since a cart last went that way

var _w: World


func _init(world: World) -> void:
	_w = world


func step(dt: float) -> void:
	if _w.zones.tiles.size() < 2:
		return
	_acc += dt
	if _acc < EVERY:
		return
	var span := _acc
	_acc = 0.0
	for a in _w.zones.tiles:
		if a in _w.zones.asleep:
			continue
		for b in _w.zones.adjacent(a):
			if b in _w.zones.asleep:
				continue
			_migrate(a, b)
			_trade(a, b, span)


## `d` steps over the border into tile `to`, just inside it.
func cross(d: Drone, to: String) -> void:
	var from := d.zone
	var into := (TileKey.rect(to).get_center() - TileKey.rect(from).get_center()).normalized()
	if _w.zones.send(d, to, TileKey.border_point(from, to) + into * STEP_IN):
		crossings += 1


# People from `a` who would do better in `b`.
func _migrate(a: String, b: String) -> void:
	var moved := 0
	for d in _w.zones.drones_in(a).duplicate():
		if moved >= MIGRANTS_PER_LOOK:
			return
		if d.kind != "drifter" or d.unconscious() or d.aloof or d.needless or not d.job.is_empty() or d.sheltered_in != null:
			continue
		if not _better_across(d, a, b):
			continue
		moved += 1
		if _w.is_active(a):
			d.job = {"for": "leave", "target": b, "item": "", "stand": TileKey.border_point(a, b)}  # (Logistics walks them there)
		else:
			cross(d, b)


func _better_across(d: Drone, a: String, b: String) -> bool:
	for cls in ["food", "drink"]:
		if d.bars[Needs.NEED_OF[cls]] >= Needs.NEED_BELOW:
			continue
		var there := _w.logistics.supply.best_supply(d, cls, b)
		if there == null:
			continue
		var here := _w.logistics.supply.best_supply(d, cls, a)
		if here == null or here.price - there.price > CROSSING_COST:
			return true
	return false


# One cartload from `from`'s food bank to `to`'s short shops, if one is due and worth it.
func _trade(to: String, from: String, span: float) -> void:
	var key := "%s<%s" % [to, from]
	_cart_clock[key] = float(_cart_clock.get(key, CARTS_EVERY)) + span
	if _cart_clock[key] < CARTS_EVERY:
		return
	for r in _w.zones.runners_in(from) + _w.zones.runners_in(to):
		if r.unconscious() or not r.job.is_empty() or r.cart.counts.values().any(func(n): return n > 0):
			continue
		var job := _w.logistics.hauling.haul_job(r, from, to)
		if job.is_empty():
			continue
		_w.logistics.complete(r, job)  # buys the load (and sets up the drop)...
		if not r.job.is_empty():
			_w.logistics.complete(r, r.job)  # ...and delivers it over the border
		r.job = {}
		carts += 1
		_cart_clock[key] = 0.0
		return
