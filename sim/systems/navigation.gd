## Where people can walk: a grid per zone that says which half-metre cells are taken, and a path finder over it. Everything
## solid in a zone (stands, tents, fires, the hospital, and whatever the town has been told about, like buildings) is stamped
## into the grid, grown a little for the width of a body; a path from here to there goes round all of it, then is pulled
## straight so people walk in lines, not staircases.
##
## It is built to change: `imprint` stamps something down (a wall the player has built, a crate that has come to rest) and
## `release` takes it away again, and every walker whose way might have changed finds out (see `version`). Moving things
## (people, bills) never touch it. A tent's open end is just free cells, a circle and a box are cells too: no shape needs a
## rule of its own.
class_name Navigation
extends RefCounted

const CELL := 0.5      # metres a cell is across
const PAD := 0.45      # solids are grown by this: a body's radius, and a little room to spare
const MARGIN := 60.0   # the grid reaches this far beyond the solids it holds: streets, and room to go round
const END_SLACK := 0.8 # the room round a solid is not held against the first and last stretch of a walk: goals (the front of a
                       # stand, where customers queue) are placed only a step clear of it, inside that room
const MAX_CELLS := 1200

## One zone's grid.
class Grid:
	var astar := AStarGrid2D.new()
	var origin := Vector2.ZERO
	var size := Vector2i.ZERO
	var cover := PackedInt32Array()  # how many things sit on each cell: it is free again only when none do

	func cell_of(p: Vector2) -> Vector2i:
		return Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))

	func inside(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

	func centre(c: Vector2i) -> Vector2:
		return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

	func solid(c: Vector2i) -> bool:
		return inside(c) and cover[c.y * size.x + c.x] > 0

var _w: World
var _grids := {}      # zone -> Grid
var _statics := {}    # zone -> [{poly, rect}]: things told about once (buildings), stamped in whenever a grid is built
var _placed := {}     # zone -> {key: polygon}: things stamped on and off while the game runs (see imprint)
var _versions := {}   # zone -> int
var _stamp := -1      # the Zones version the grids were built for


func _init(world: World) -> void:
	_w = world


## Tell the zone about something permanent and solid (a building's outline). It need not lie where the grid is: only what
## does is stamped in.
func add_static(zone: String, poly: PackedVector2Array) -> void:
	if not _statics.has(zone):
		_statics[zone] = []
	_statics[zone].append({"poly": poly, "rect": _rect_of(poly)})
	_grids.erase(zone)


## Stamp something solid onto the zone's grid, under `key`, until `release`d. `poly` is its outline.
func imprint(zone: String, key: Variant, poly: PackedVector2Array) -> void:
	if _placed.has(zone) and _placed[zone].has(key):
		release(zone, key)
	var g := _grid(zone)  # (built first: a grid built after would stamp the new one itself, and it would count twice)
	if not _placed.has(zone):
		_placed[zone] = {}
	_placed[zone][key] = poly
	if g != null:
		_stamp_poly(g, poly, 1)
	_bump(zone)


## Take away what was imprinted under `key`.
func release(zone: String, key: Variant) -> void:
	if not _placed.has(zone) or not _placed[zone].has(key):
		return
	var poly: PackedVector2Array = _placed[zone][key]
	var g := _grid(zone)  # (built while it is still counted, so it comes off exactly once)
	_placed[zone].erase(key)
	if g != null:
		_stamp_poly(g, poly, -1)
	_bump(zone)


## Changes every time the zone's solids change. A walker that planned its way under an older version looks again.
func version(zone: String) -> int:
	_grid(zone)  # (so a rebuild has bumped it)
	return int(_versions.get(zone, 0))


## Is this spot taken (in a solid, or in the room round one)?
func blocked(zone: String, p: Vector2) -> bool:
	var g := _grid(zone)
	return g != null and g.solid(g.cell_of(p))


## Is this spot somewhere nobody could ever stand: inside a building (one the town was told about) or a stand?
func unreachable(zone: String, p: Vector2) -> bool:
	if inside_solid(zone, p):
		return true
	for s in _statics.get(zone, []):
		if s.rect.has_point(p) and Geometry2D.is_point_in_polygon(p, s.poly):
			return true
	return false


## The nearest open ground to `p`: the middle of the closest cell that is not solid, searched out to `radius` metres. `p` itself
## if the zone has no grid or nothing open is that near. (Where a bill that came down on a roof gets put: the street.)
func nearest_open(zone: String, p: Vector2, radius := 40.0) -> Vector2:
	var g := _grid(zone)
	if g == null:
		return p
	var c := g.cell_of(p)
	if not g.inside(c):
		return p
	for r in range(0, int(radius / CELL) + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if g.inside(n) and not g.solid(n) and Vector2(dx, dy).length() < best_d:
					best_d = Vector2(dx, dy).length()
					best = n
		if best.x >= 0:
			return g.centre(best)
	return p


## Is this spot inside a solid thing itself (not just in the room round one)? A street's end that ends in a stand is.
func inside_solid(zone: String, p: Vector2) -> bool:
	for s in _w.zones.solids_in(zone):
		for part in s.parts:
			if part.contains(p, 0.1):
				return true
	return false


## Can you walk straight from `a` to `b` without touching anything solid? (True where there is no grid to say.)
func clear(zone: String, a: Vector2, b: Vector2) -> bool:
	var g := _grid(zone)
	if g == null:
		return true
	return _line_clear(g, a, b)


## The way from `a` to `b` round everything solid, as points to walk through in order (not counting `a`): a straight line
## where one will do. An empty list if there is no way; [b] where the zone has no grid.
func path(zone: String, a: Vector2, b: Vector2) -> PackedVector2Array:
	var g := _grid(zone)
	if g == null:
		return PackedVector2Array([b])
	var from := g.cell_of(a)
	var to := g.cell_of(b)
	if not g.inside(from) or not g.inside(to):
		return PackedVector2Array([b])
	if _line_clear(g, a, b):
		return PackedVector2Array([b])
	var start := _free_cell(g, from)
	var goal := _free_cell(g, to)
	if start.x < 0 or goal.x < 0:
		return PackedVector2Array()
	var cells: Array[Vector2i] = g.astar.get_id_path(start, goal)
	if cells.is_empty():
		return PackedVector2Array()
	# the cells' middles, with the ends exactly where we start and end, then pulled straight
	var pts := PackedVector2Array([a])
	for c in cells:
		pts.append(g.centre(c))
	pts.append(b)
	var out := PackedVector2Array()
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _line_clear(g, pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


# -------------------------------------------------------------------------------------------------- the grids

func _bump(zone: String) -> void:
	_versions[zone] = int(_versions.get(zone, 0)) + 1


## The zone's grid, built from its solids and statics if it has changed (or never been built); null if the zone has
## nothing solid to hold.
func _grid(zone: String) -> Grid:
	if _stamp != _w.zones.version:
		_stamp = _w.zones.version
		_grids.clear()
		for z in _versions:
			_bump(z)
	if _grids.has(zone):
		return _grids[zone]
	var polys: Array[PackedVector2Array] = []
	for s in _w.zones.solids_in(zone):
		for part in s.parts:
			polys.append(_part_poly(part))
	if polys.is_empty():
		_grids[zone] = null
		return null
	var rect := _rect_of(polys[0])
	for p in polys:
		rect = rect.merge(_rect_of(p))
	rect = rect.grow(MARGIN)
	var g := Grid.new()
	g.origin = rect.position
	g.size = Vector2i(mini(int(ceil(rect.size.x / CELL)), MAX_CELLS), mini(int(ceil(rect.size.y / CELL)), MAX_CELLS))
	g.cover.resize(g.size.x * g.size.y)
	g.astar.region = Rect2i(Vector2i.ZERO, g.size)
	g.astar.cell_size = Vector2(CELL, CELL)
	g.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.astar.update()
	for p in polys:
		_stamp_poly(g, p, 1)
	var world_rect := Rect2(g.origin, Vector2(g.size) * CELL)
	for s in _statics.get(zone, []):
		if world_rect.intersects(s.rect):
			_stamp_poly(g, s.poly, 1)
	for key in _placed.get(zone, {}):
		_stamp_poly(g, _placed[zone][key], 1)
	_grids[zone] = g
	return g


## A footprint part (a box or a circle), grown by the padding, as a polygon.
func _part_poly(part) -> PackedVector2Array:
	var out := PackedVector2Array()
	if part.r > 0.0:
		var r: float = part.r + PAD
		for k in 12:
			out.append(part.c + Vector2.from_angle(TAU * k / 12.0) * r)
		return out
	var az := Vector2(-part.ax.y, part.ax.x)
	var hx: float = part.half.x + PAD
	var hz: float = part.half.y + PAD
	return PackedVector2Array([part.c + part.ax * hx + az * hz, part.c - part.ax * hx + az * hz, part.c - part.ax * hx - az * hz, part.c + part.ax * hx - az * hz])


static func _rect_of(poly: PackedVector2Array) -> Rect2:
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


## Put `delta` (+1 or -1) on every cell whose middle is inside `poly`. A cell is solid while anything covers it.
func _stamp_poly(g: Grid, poly: PackedVector2Array, delta: int) -> void:
	var rect := _rect_of(poly)
	var lo := g.cell_of(rect.position)
	var hi := g.cell_of(rect.end)
	for y in range(maxi(lo.y, 0), mini(hi.y, g.size.y - 1) + 1):
		for x in range(maxi(lo.x, 0), mini(hi.x, g.size.x - 1) + 1):
			var c := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(g.centre(c), poly):
				var i := y * g.size.x + x
				g.cover[i] = maxi(0, g.cover[i] + delta)
				g.astar.set_point_solid(c, g.cover[i] > 0)


## Is the straight line from `a` to `b` free of solid cells? (The first and last END_SLACK of it are not held against the
## room round a solid: see there.)
func _line_clear(g: Grid, a: Vector2, b: Vector2) -> bool:
	var length := a.distance_to(b)
	var steps := maxi(1, int(length / (CELL * 0.5)))
	for k in range(0, steps + 1):
		var p := a.lerp(b, float(k) / steps)
		if p.distance_to(a) < END_SLACK or p.distance_to(b) < END_SLACK:
			continue
		if g.solid(g.cell_of(p)):
			return false
	return true


## The free cell nearest to `c` (within a few cells), or (-1, -1).
func _free_cell(g: Grid, c: Vector2i) -> Vector2i:
	if g.inside(c) and not g.solid(c):
		return c
	for r in range(1, 12):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if g.inside(n) and not g.solid(n) and Vector2(dx, dy).length() < best_d:
					best_d = Vector2(dx, dy).length()
					best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
