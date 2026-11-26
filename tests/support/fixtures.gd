## Shared builders for the sim tests: little towns, a clinic, the Frankfurt map, and ways to run the clock.
class_name Fixtures
extends RefCounted

static var _district := {}


## The Frankfurt map, parsed once per test process (2,890 buildings: parsing it again in every test that needs it was most of
## their time). Treat it as read-only.
static func district() -> Dictionary:
	if _district.is_empty():
		_district = Scenario.load_district()  # (with its land: water, green, street furniture)
	return _district


## The story's scenario on the Frankfurt map.
static func scenario() -> Scenario:
	return Scenario.new(district())


## A tile with no story, offline: the zoom-16 tile round the Bahnhofsviertel, imported from the raw OpenStreetMap extract the
## Frankfurt map was made from (it covers the whole tile). Where the hero lands: TILE_LAT, TILE_LON.
const TILE_LAT := 50.1086307
const TILE_LON := 8.6687641
static var _tile_raw := {}


static func tile_key() -> String:
	return TileKey.of(TILE_LAT, TILE_LON)


static func tile_raw() -> Dictionary:
	if _tile_raw.is_empty():
		_tile_raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/bahnhofsviertel_raw.json"))
	return _tile_raw


static func tile_district() -> Dictionary:
	return OsmImport.tile(tile_raw(), tile_key())


static func tile_landing() -> TileLanding:
	return TileLanding.new(tile_key(), tile_district(), TILE_LAT, TILE_LON)


## An atom in `zone` grown through all its founders (as the hero would, a tent at a time: Atom.grow). Returns its tent city.
static func grown_atom(w: World, zone := "atom", at := Vector2.ZERO) -> Machine:
	var city := Atom.seed(w, zone, at)
	Atom.grow(w, city)
	return city


## The tile's world, its atom grown through all its founders.
static func grown_tile(landing: TileLanding) -> World:
	var w := landing.build()
	Atom.grow(w, tent_city(w, landing.key))
	return w


## The tent city of `zone` (its first).
static func tent_city(w: World, zone: String) -> Machine:
	return w.zones.machines_in(zone).filter(func(m): return m.residence != null)[0]


static func run(w: World, seconds: int, keep_fed := false) -> void:
	for i in seconds:
		if keep_fed:
			for d in w.drones:
				d.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
		w.tick(1.0)


## Ticks until `done` is true; returns the seconds it took, or -1.
static func until(w: World, done: Callable, max_seconds: int) -> int:
	for i in max_seconds:
		w.tick(1.0)
		if done.call():
			return i
	return -1


static func bars(h: float, t: float, wm: float) -> Dictionary:
	return {"hunger": h, "thirst": t, "warmth": wm}


# ---------------------------------------------------------------- the foundation


static func sold(w: World, zone: String) -> int:
	var n := 0
	for m in w.zones.machines_in(zone):
		n += m.sold_total
	return n


static func shop_world() -> Array:
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(3, 0))
	var p := w.add_player(Vector2(0, 0))
	p.carry.counts.clear()  # these tests are about buying; the starting kit has its own test
	return [w, baker, w.machine_of(baker), p]


static func spread(points: Array) -> float:
	var low := INF
	for i in points.size():
		for j in range(i + 1, points.size()):
			low = minf(low, (points[i] as Vector2).distance_to(points[j]))
	return low


## A bakery short of what its bread is made of, an organics bin full of it, and a runner between, and a bottle depot (whose
## fund the leftovers' worth is paid into): [w, bin, baker, bakery, runner, attendant].
static func runner_world(owner_wallet := 40.0, runner_wallet := 20.0) -> Array:
	var w := World.new()
	var clerk := w.add_bottle_depot(Vector2(-20, 0))
	var bin := w.add_bin("organics", Vector2(0, 0), 40)
	var baker := w.add_vendor("bakery", Vector2(30, 0), owner_wallet)
	var bakery := w.machine_of(baker)
	bakery.input.take("leftovers", bakery.input.count("leftovers"))  # its leftovers are out
	var runner := w.add_runner(Vector2(2, 3), runner_wallet)
	for d in w.drones:
		d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	return [w, bin, baker, bakery, runner, clerk]


static func l_road() -> RoadGraph:
	var g := RoadGraph.new()
	g.add_polyline(PackedVector2Array([Vector2(0, 0), Vector2(25, 0), Vector2(50, 0), Vector2(50, 25), Vector2(50, 50)]))
	return g


static func clinic() -> World:
	var w := World.new()
	w.add_hospital(Vector2(0, 20), Vector2(0, -1))  # a tent at (0,20), the street to its north
	return w


static func empty_shops(w: World) -> void:
	for m in w.machines:
		for raw in m.recipe:
			m.input.take(raw, 1000)


static func hungry_crowd(w: World, n: int) -> void:
	for i in n:
		var d := w.add_drifter(Vector2(randf_range(-10, 10), randf_range(5, 15)), 20.0)
		d.bars = Fixtures.bars(0.2, 1.0, 1.0)


static func made(w: World) -> int:
	var n := 0
	for m in w.machines:
		n += m.crafted_total
	return n


## A Landform over `rect` whose ground is `height` (a callable of the point), with no streets or buildings of its own: hills
## for the sim's tests, without elevation tiles.
static func landform(rect: Rect2, height: Callable) -> Landform:
	var f := Landform.new()
	f.flat = false
	var origin := (rect.position / Landform.CELL).floor() * Landform.CELL
	f.cols = ceili((rect.end.x - origin.x) / Landform.CELL) + 1
	f.rows = ceili((rect.end.y - origin.y) / Landform.CELL) + 1
	f.rect = Rect2(origin, Vector2(f.cols - 1, f.rows - 1) * Landform.CELL)
	f.land.resize(f.cols * f.rows)
	for j in f.rows:
		for i in f.cols:
			f.land[j * f.cols + i] = float(height.call(f.point(i, j)))
	f.surface = f.land.duplicate()
	f.ground = f.land.duplicate()
	f._mark_plain()
	return f


## A plane rising `rise` (rise over run, x east and y south) over `rect`.
static func tilted(rect: Rect2, rise: Vector2) -> Landform:
	return landform(rect, func(p: Vector2) -> float: return 100.0 + rise.dot(p - rect.position))
