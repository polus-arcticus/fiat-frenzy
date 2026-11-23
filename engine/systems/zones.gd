## Zones fence the town into patches that run separately, so the sim can grow without every system looking at
## everyone. Each drone, machine, bin, fire, hospital, relief van, bill and ring belongs to one zone, and the
## systems only look at what is in the asker's own zone.
##
## `active` says which zones run in full detail (empty: all of them, the default, so a small town just works).
## A zone that is not active is dormant: it runs in summary at a coarse step (see TileSummary): nobody walks or talks, but
## businesses produce and people eat, buy, restock and haul by the same rules, so the town has lived when you come back,
## and its money is still counted. The only ways between
## zones are named: a ring (see Portals.cross), or `send`. Money never crosses on its own: it rides in a wallet, so
## the world total is the same before and after, and `books()` shows where it all is.
class_name Zones
extends RefCounted

const COARSE_STEP := 10.0  # a dormant zone's businesses run in jumps of this many seconds

const HOME := "district"  # the zone of the starting town, and where the hero is when they are in no region
const MERGE := {"tiles": "union"}  # two saves combined hold both saves' tiles (see Merge)

var active: Array[String] = []
## Zones nobody has been to yet: they do not run at all (so their people are fresh, and fed, when the hero arrives) until the
## hero's own zone is one of them (see `wake`).
var asleep: Array[String] = []
var regions := {}  # zone -> Rect2: a patch of the map that is a zone of its own (see zone_for). Told by whoever lays the map out.
## The tiles of the planet this world has loaded (see TileKey), each a zone named by its key, and the region they are all in
## (positions are metres in it). Neighbouring tiles that are both loaded share a border (see Borders).
var region := ""
var tiles := {}  # tile key -> true
var version := 0  # bumps whenever something is added to the world or moves zone: the indexes (and navigation grids) are rebuilt
var _owed := {}  # zone -> seconds of dormant time not yet run
var _index := {}  # zone -> {drones, machines, bins, fires, runners}: what a search in that zone looks at
var _dirty := true

var _w: World


func _init(world: World) -> void:
	_w = world


## Something was added to the world, or moved zone: the per-zone lists are rebuilt next time they are asked for.
func invalidate() -> void:
	_dirty = true
	version += 1


## Everyone, every machine, bin and fire in `zone`. The systems search these, never the world's whole lists,
## so what a search costs depends on the size of its zone and not of the world.
func drones_in(zone: String) -> Array:
	return _of(zone).drones


func runners_in(zone: String) -> Array:
	return _of(zone).runners


func machines_in(zone: String) -> Array:
	return _of(zone).machines


## The zone's bins and fountains (WasteBin): its base inputs.
func bins_in(zone: String) -> Array:
	return _of(zone).bins


## How many live in `zone`: everyone with needs (not the depot's attendant, the story's doorman and the like, nor the hero).
## What its recycling fills with (WasteBin.per_head).
func heads_in(zone: String) -> int:
	var n := 0
	for d in _of(zone).drones:
		if not d.needless and d.kind != "player":
			n += 1
	return n


func fires_in(zone: String) -> Array:
	return _of(zone).fires


func hospitals_in(zone: String) -> Array:
	return _of(zone).hospitals


## What is solid in `zone`, for keeping the people in it out of it. Built the first time it is asked for after
## the zone changes, so walking never has to look at the rest of the world.
func solids_in(zone: String) -> Array:
	var e := _of(zone)
	if e.solids == null:
		var out: Array[Footprint] = []
		for m in e.machines:
			out.append(m.solid())
		for f in e.fires:
			out.append(f.solid())
		for h in e.hospitals:
			out.append(h.solid())
		e.solids = out
	return e.solids


## The zones that are running now.
func running() -> Array:
	var out: Array = all_zones() if active.is_empty() else active
	if asleep.is_empty():
		return out
	return out.filter(func(z): return not z in asleep)


## The hero is in `zone`: if it was asleep, it starts running now.
func wake(zone: String) -> void:
	if zone in asleep:
		asleep.erase(zone)


func _of(zone: String) -> Dictionary:
	if _dirty:
		_rebuild()
	return _index.get(zone, _EMPTY)


const _EMPTY := {"drones": [], "runners": [], "machines": [], "bins": [], "fires": [], "hospitals": [], "solids": []}


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
	for b in _w.bins:
		_entry(b.zone).bins.append(b)
	for f in _w.fires:
		_entry(f.zone).fires.append(f)
	for h in _w.hospitals:
		_entry(h.zone).hospitals.append(h)


func _entry(zone: String) -> Dictionary:
	if not _index.has(zone):
		_index[zone] = {"drones": [], "runners": [], "machines": [], "bins": [], "fires": [], "hospitals": [], "solids": null}
	return _index[zone]


func is_active(zone: String) -> bool:
	if zone in asleep:
		return false
	return active.is_empty() or zone in active


## Which zone someone standing at `p` belongs to, who is in `current` now. Inside a region it is that region's zone; leave it
## and they are home again; with no region about, wherever they were. (The hero's zone follows where they walk or ride, so
## the people and the money of the place they are in are the ones that answer them.)
func zone_for(p: Vector2, current: String) -> String:
	for z in regions:
		if (regions[z] as Rect2).has_point(p):
			return z
	if not tiles.is_empty():
		var t := TileKey.at(region, p)
		if tiles.has(t):
			return t
	return HOME if regions.has(current) else current


## Loads tile `key` as a zone of its own (every tile of a world is in one region).
func add_tile(key: String) -> void:
	var r := TileKey.region_of(key)
	assert(region == "" or region == r, "tile %s is not in this world's region %s" % [key, region])
	region = r
	tiles[key] = true


## The loaded tiles that share an edge with `zone` (none, if it is not a tile).
func adjacent(zone: String) -> Array[String]:
	var out: Array[String] = []
	if tiles.has(zone):
		for n in TileKey.neighbours(zone):
			if tiles.has(n):
				out.append(n)
	return out


## Run only `zone` in full detail (the one being watched: the hero's, say).
func follow(zone: String) -> void:
	active = [zone] as Array[String]


## Dormant zones run in summary, in coarse jumps (see TileSummary). Called once a tick.
func step_dormant(dt: float) -> void:
	if active.is_empty():
		return
	for zone in all_zones():
		if zone in asleep:
			continue
		if is_active(zone):
			_owed.erase(zone)
			continue
		_owed[zone] = float(_owed.get(zone, 0.0)) + dt
		if _owed[zone] < COARSE_STEP:
			continue
		var jump: float = _owed[zone]
		_owed[zone] = 0.0
		_w.summary.step(zone, jump)


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
	if d.stand != "":
		return false
	if d.sheltered_in != null:
		d.sheltered_in.release(d)
	d.zone = zone
	invalidate()
	d.pos = at
	d.job = {}
	d.route = PackedVector2Array()
	return true
