## Zones fence the town into patches that run separately, so the sim can grow without every system looking at
## everyone. Each drone, machine, food bank, fire, hospital, relief van, bill and ring belongs to one zone, and the
## systems only look at what is in the asker's own zone.
##
## `active` says which zones run in full detail (empty: all of them, the default, so a small town just works).
## A zone that is not active is dormant: nobody in it moves, eats or talks, but its businesses keep producing at a
## coarse step (so shelves are full when you come back) and its money is still counted. The only ways between
## zones are named: a ring (see Portals.cross), or `send`. Money never crosses on its own: it rides in a wallet, so
## the world total is the same before and after, and `books()` shows where it all is.
class_name Zones
extends RefCounted

const COARSE_STEP := 10.0  # a dormant zone's businesses run in jumps of this many seconds

var active: Array[String] = []
var version := 0  # bumps whenever something is added to the world or moves zone: the indexes (and navigation grids) are rebuilt
var _owed := {}  # zone -> seconds of dormant time not yet run
var _index := {}  # zone -> {drones, machines, food_banks, fires, runners}: what a search in that zone looks at
var _dirty := true

var _w: World


func _init(world: World) -> void:
	_w = world


## Something was added to the world, or moved zone: the per-zone lists are rebuilt next time they are asked for.
func invalidate() -> void:
	_dirty = true
	version += 1


## Everyone, every machine, food bank and fire in `zone`. The systems search these, never the world's whole lists,
## so what a search costs depends on the size of its zone and not of the world.
func drones_in(zone: String) -> Array:
	return _of(zone).drones


func runners_in(zone: String) -> Array:
	return _of(zone).runners


func machines_in(zone: String) -> Array:
	return _of(zone).machines


func food_banks_in(zone: String) -> Array:
	return _of(zone).food_banks


func fires_in(zone: String) -> Array:
	return _of(zone).fires


## What is solid in `zone`, for keeping the people in it out of it. Built the first time it is asked for after
## the zone changes, so walking never has to look at the rest of the world.
func solids_in(zone: String) -> Array:
	var e := _of(zone)
	if e.solids == null:
		var out: Array[Footprint] = []
		for m in e.machines:
			out.append(m.solid())
		for fb in e.food_banks:
			out.append(fb.solid())
		for f in e.fires:
			out.append(f.solid())
		for h in e.hospitals:
			out.append(h.solid())
		e.solids = out
	return e.solids


## The zones that are running now.
func running() -> Array:
	if active.is_empty():
		return all_zones()
	return active


func _of(zone: String) -> Dictionary:
	if _dirty:
		_rebuild()
	return _index.get(zone, _EMPTY)


const _EMPTY := {"drones": [], "runners": [], "machines": [], "food_banks": [], "fires": [], "hospitals": [], "solids": []}


func _rebuild() -> void:
	_dirty = false
	_index.clear()
	for d in _w.drones:
		var e := _entry(d.zone)
		e.drones.append(d)
		if d.kind == "runner":
			e.runners.append(d)
	for m in _w.machines:
		_entry(m.zone).machines.append(m)
	for fb in _w.food_banks:
		_entry(fb.zone).food_banks.append(fb)
	for f in _w.fires:
		_entry(f.zone).fires.append(f)
	for h in _w.hospitals:
		_entry(h.zone).hospitals.append(h)


func _entry(zone: String) -> Dictionary:
	if not _index.has(zone):
		_index[zone] = {"drones": [], "runners": [], "machines": [], "food_banks": [], "fires": [], "hospitals": [], "solids": null}
	return _index[zone]


func is_active(zone: String) -> bool:
	return active.is_empty() or zone in active


## Run only the zone the hero is in.
func follow_player() -> void:
	if _w.player != null:
		active = [_w.player.zone] as Array[String]


## Dormant zones: their businesses and food banks catch up in coarse jumps. Called once a tick.
func step_dormant(dt: float) -> void:
	if active.is_empty():
		return
	for zone in all_zones():
		if is_active(zone):
			_owed.erase(zone)
			continue
		_owed[zone] = float(_owed.get(zone, 0.0)) + dt
		if _owed[zone] < COARSE_STEP:
			continue
		var jump: float = _owed[zone]
		_owed[zone] = 0.0
		for m in _w.machines:
			if m.zone == zone:
				m.step(jump)
		for fb in _w.food_banks:
			if fb.zone == zone:
				fb.step(jump)


## Every zone anything belongs to (from the index, so it costs nothing per call).
func all_zones() -> Array:
	if _dirty:
		_rebuild()
	return _index.keys()


## Where the money is, by zone: wallets and loose or flying bills. (The hero's pocket and `sunk` belong to no
## zone, so books() plus those is the ledger's total.)
func books() -> Dictionary:
	var out := {}
	for d in _w.drones:
		out[d.zone] = float(out.get(d.zone, 0.0)) + d.wallet
	for b in _w.bills:
		out[b.zone] = float(out.get(b.zone, 0.0)) + b.value
	return out


## Move someone to another zone, at a place in it. The one legal way for a drone to change zone. A vendor (who owns
## a stand where they are) cannot be sent; money goes with them in their wallet.
func send(d: Drone, zone: String, at: Vector2) -> bool:
	if d.station >= 0 or d.depot >= 0:
		return false
	if d.sheltered_in != null:
		d.sheltered_in.release(d)
	d.zone = zone
	invalidate()
	d.pos = at
	d.job = {}
	d.route = PackedVector2Array()
	return true
