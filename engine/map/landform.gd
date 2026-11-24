## MODEL. The shape of the land a map stands on: the one answer to "how high is it here", for the sim, the views and the
## collision alike. It is made from the planet's elevation (Terrarium tiles, Terrain) and the map's streets, buildings and water
## (OsmImport), the way a city is built on a hillside. Three fields on one grid (CELL metres, aligned to the region's metres),
## each read on the cell's two triangles (a-b-d and a-d-c), the ones a mesh of it is made of:
## - the **land**: the elevation smoothed over SMOOTH cells (a 40 m window), so the noise in the source (and the cliffs it has
##   where buildings stand) is gone and the hills are kept;
## - the **surface**: the land with every street levelled across (each point of a street's carriageway and pavements at the
##   height of its centre line, blending back to the land over SHOULDER beside it), then smoothed over a cell once more, so
##   where two streets meet on a slope one ramps into the other instead of stepping. Every street, pavement and kerb is on this
##   one field, so they are flush by construction, at junctions too;
## - the **ground**: the surface, only ever cut down from it: under the deck of a bridge, under the floor of a building (and a
##   cell round it, so it stands in a little cut on a slope), into a basin under water. It never rises through anything.
## Besides: a **bridge** has its own deck, straight from end to end and never down into the land; a **building** stands on a
## pad at the height of the street in front of it, so its door meets the pavement; **water** lies WATER_DROP under the land.
## Heights are metres above the sea. Everything is a function of where a point is on the planet and of what is near it (the
## smoothing reads beyond the map's edge, a building only cuts the ground of the tile that owns all of it and its cut): two
## neighbouring tiles agree where they meet. Without elevation tiles it is flat: every height 0, as the game always was.
class_name Landform
extends RefCounted

const CELL := 8.0         # metres between the grid's points (the source is no finer than 10-30 m)
const SMOOTH := 2         # the land's smoothing, in cells each way (2: a 5 x 5 window, 40 m)
const SETTLE := 1         # the surface's, after the streets are levelled (1: 3 x 3, 24 m: junctions ramp)
const LEVELLINGS := 3     # times the streets are levelled and settled in turn
const KNOT := 16.0        # at most this many metres between a street's knots
const SHOULDER := 8.0     # metres beside a street over which the surface blends back to the land
const SINK := 0.05        # the ground just under a building's floor
const DECK := 0.5         # and the least it is under a bridge's deck
const WATER_DROP := 0.3   # water lies this far under the land at its banks...
const BASIN := 0.6        # ...and the ground this far under the water
const SIDE_WALK := 3.4    # what both pavements take together where the map doesn't say (Kerbs, CityBuilder: the same rule)
const LEVEL := ["pedestrian"]  # streets paved wall to wall, no pavements of their own beyond their width
const PAD_REACH := 40.0   # the furthest a building looks for the street it fronts
const FLOOR_CUT := CELL * 1.42  # how far round a building the ground is kept under its floor (a grid cell's diagonal)
const INDEX := 16.0       # metres a side of the street index's cells
## How far inside the relief that was fetched the grid stops, so the smoothing has elevation all round it.
const INSET := (SMOOTH + 1) * CELL

var flat := true
var rect := Rect2()                   # what the grid covers (its corners are grid points)
var cols := 0
var rows := 0
var land := PackedFloat32Array()      # the three fields, row by row
var surface := PackedFloat32Array()
var ground := PackedFloat32Array()
## Per district road (the same order as district.roads): {knots: PackedVector2Array, d: PackedFloat32Array (metres along),
## h: PackedFloat32Array (the land at each knot; a bridge's deck), reach: [left, right] (metres from the centre line its surface
## runs out to each side: the pavements included), ext: float (how far past its ends it overlaps the next), bridge: bool}.
var streets: Array = []
var pads := {}                        # building id -> the height of its floor
var owned := Rect2()                  # the map's own square (a tile's): only buildings wholly in it cut the ground
var _cells := {}                      # Vector2i -> [[road, knot]]: the street pieces near a cell
var _buildings: Array = []            # [{id, poly, box}]
var _building_cells := {}             # Vector2i -> [index into _buildings]
var _water_pieces: Array = []         # [{poly, box}]
var _plain := PackedByteArray()       # per grid cell: 1 where height_at is just the surface (see `_mark_plain`)


## The landform over `rect` (a frame's metres) of `district`, from the elevation pictures `imgs` (Terrain.images). `rect` is
## widened to whole grid cells. With no pictures it is flat. The map's own square is the frame's.
static func of(frame: MapFrame, rect: Rect2, district: Dictionary, imgs: Dictionary) -> Landform:
	var f := Landform.new()
	f.owned = frame.rect
	var origin := (rect.position / CELL).floor() * CELL
	f.cols = ceili((rect.end.x - origin.x) / CELL) + 1
	f.rows = ceili((rect.end.y - origin.y) / CELL) + 1
	f.rect = Rect2(origin, Vector2(f.cols - 1, f.rows - 1) * CELL)
	f.land = _smoothed(frame, f, imgs)
	f.flat = imgs.is_empty()
	f._lay_streets(district.get("roads", []))
	f._index_buildings(district.get("buildings", []))
	f._lay_water(district.get("water", {}).get("pieces", []))
	f.surface = f._levelled()
	f._lay_decks()
	f._lay_pads()
	f.ground = f.surface.duplicate()
	f._cut_ground()
	f._mark_plain()
	return f


## Which cells are plain: no building's, bridge's or water's box touches them, and their ground is the surface at every corner.
## There a street's surface, the ground and so `height_at` are all the surface. (`of` does it; a landform put together by hand,
## as the tests do, calls it once its fields are in.)
func _mark_plain() -> void:
	_plain.resize((cols - 1) * (rows - 1))
	_plain.fill(1 if not flat else 0)
	if flat:
		return
	var boxes: Array[Rect2] = []
	for b in _buildings:
		boxes.append(b.box)
	for w in _water_pieces:
		boxes.append(w.box)
	for st in streets:
		if st.bridge:
			for k in st.knots.size() - 1:
				boxes.append(Rect2(st.knots[k], Vector2.ZERO).expand(st.knots[k + 1]).grow(maxf(st.reach[0], st.reach[1]) + st.ext))
	for box in boxes:
		var lo := ((box.position - rect.position) / CELL).floor()
		var hi := ((box.end - rect.position) / CELL).floor()
		for j in range(maxi(0, int(lo.y)), mini(rows - 2, int(hi.y)) + 1):
			for i in range(maxi(0, int(lo.x)), mini(cols - 2, int(hi.x)) + 1):
				_plain[j * (cols - 1) + i] = 0
	for j in rows - 1:
		for i in cols - 1:
			for c in [j * cols + i, j * cols + i + 1, (j + 1) * cols + i, (j + 1) * cols + i + 1]:
				if ground[c] != surface[c]:
					_plain[j * (cols - 1) + i] = 0


# ---------------------------------------------------------------- what anyone asks

## How high it is at `p`: on a street its surface (a bridge's deck), in a building its floor, else the ground. What the sim and
## the views stand things on (the kerb's own height is Kerbs': this is the street's surface under it). Over most of the map
## (a cell with no building, bridge or water near it, the ground uncut: `_plain`) all three are the surface: one look-up.
func height_at(p: Vector2) -> float:
	if not flat and not _plain.is_empty():
		var g := (p - rect.position) / CELL
		var i := floori(g.x)
		var j := floori(g.y)
		if i >= 0 and j >= 0 and i <= cols - 2 and j <= rows - 2 and _plain[j * (cols - 1) + i] == 1:
			return surface_at(p)
	var s := street_at(p)
	if not is_nan(s):
		return s
	var b := pad_at(p)
	if not is_nan(b):
		return b
	return ground_at(p)


## The street's surface at `p`, or NAN if `p` is not on a street (its carriageway or its pavements). Where a bridge crosses a
## street, the street under it (the sim is flat: it walks under bridges, not over them).
func street_at(p: Vector2) -> float:
	var n := _nearest(p)
	if n.is_empty() or n.gap > 0.0:
		return NAN
	return n.h if n.bridge else surface_at(p)


## How high road `ri`'s own surface is at `p` (on or beside it): a bridge's deck, across from `p` on its centre line; any other
## street, the surface. For drawing a street's pieces where streets cross at two heights.
func on_road(ri: int, p: Vector2) -> float:
	if ri < 0 or ri >= streets.size() or not streets[ri].bridge:
		return surface_at(p)
	var st: Dictionary = streets[ri]
	var best := INF
	var h := surface_at(p)
	for k in st.knots.size() - 1:
		var a: Vector2 = st.knots[k]
		var b: Vector2 = st.knots[k + 1]
		var on := Geometry2D.get_closest_point_to_segment(p, a, b)
		if on.distance_to(p) < best:
			best = on.distance_to(p)
			h = lerpf(st.h[k], st.h[k + 1], on.distance_to(a) / maxf(a.distance_to(b), 0.01))
	return h


## Whether road `ri` is a bridge.
func is_bridge(ri: int) -> bool:
	return ri >= 0 and ri < streets.size() and streets[ri].bridge


## The floor of the building `p` is in, or NAN.
func pad_at(p: Vector2) -> float:
	for bi in _building_cells.get(_cell(p), []):
		var b: Dictionary = _buildings[bi]
		if (b.box as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, b.poly):
			return pads.get(b.id, NAN)
	return NAN


## The bare ground at `p`. Outside the grid, as at its nearest edge.
func ground_at(p: Vector2) -> float:
	return _on_grid(ground, p)


## The surface at `p`: what the streets lie on, and the ground too away from buildings, bridges and water.
func surface_at(p: Vector2) -> float:
	return _on_grid(surface, p)


## The smoothed land at `p`, before the city shaped it.
func land_at(p: Vector2) -> float:
	return _on_grid(land, p)


## The surface of water at `p` (if there is water there: the district's pieces say where).
func water_at(p: Vector2) -> float:
	return land_at(p) - WATER_DROP


## Rise over run going `dir` (a unit vector) through `p`: positive uphill. 0 on flat ground.
func grade(p: Vector2, dir: Vector2) -> float:
	if flat:
		return 0.0
	return (height_at(p + dir * 0.75) - height_at(p - dir * 0.75)) / 1.5


## Rise over run going `dir` (a unit vector) at `p` on the surface (the streets' surface, the land between them): the slope of
## the grid triangle `p` is on, one look-up. What walkers climb (Walking): as `grade` on the streets, without its search for
## them, so the sim's hottest path stays cheap however many walk. (Inside a building, or on a bridge's deck, it is the surface
## under them all the same: a walk there is short.)
func walk_grade(p: Vector2, dir: Vector2) -> float:
	if flat:
		return 0.0
	return surface_slope(p).dot(dir)


## The surface's rise over run along x and y at `p`: the slope of its grid triangle there (none beyond the grid's edge, the
## way the surface lies there).
func surface_slope(p: Vector2) -> Vector2:
	if flat or surface.is_empty():
		return Vector2.ZERO
	var g := (p - rect.position) / CELL
	var i := floori(g.x)
	var j := floori(g.y)
	if i < 0 or j < 0 or i > cols - 2 or j > rows - 2:
		return Vector2.ZERO
	var a := surface[j * cols + i]
	var b := surface[j * cols + i + 1]
	var c := surface[(j + 1) * cols + i]
	var d := surface[(j + 1) * cols + i + 1]
	if g.x - i >= g.y - j:  # (a-b-d)
		return Vector2(b - a, d - b) / CELL
	return Vector2(d - c, c - a) / CELL  # (a-d-c)


## How steep it is at `p`, whichever way: the steepest rise over run there.
func slope_at(p: Vector2) -> float:
	if flat:
		return 0.0
	return Vector2(grade(p, Vector2.RIGHT), grade(p, Vector2.DOWN)).length()


## The lowest and highest the ground gets.
func span() -> Vector2:
	var lo := INF
	var hi := -INF
	for h in ground:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return Vector2(lo, hi) if lo <= hi else Vector2.ZERO


## Where a grid point is.
func point(i: int, j: int) -> Vector2:
	return rect.position + Vector2(i, j) * CELL


# ---------------------------------------------------------------- the land

# The elevation at the grid's points, smoothed: sampled on the grid and SMOOTH cells beyond it all round, then averaged over a
# (2 SMOOTH + 1)^2 window. Missing elevation (a tile that did not come) is the average of what did; none at all, 0.
static func _smoothed(frame: MapFrame, f: Landform, imgs: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(f.cols * f.rows)
	if imgs.is_empty():
		return out
	var w := f.cols + 2 * SMOOTH
	var h := f.rows + 2 * SMOOTH
	var raw := PackedFloat32Array()
	raw.resize(w * h)
	var sum := 0.0
	var seen := 0
	var holes: Array[int] = []
	for j in h:
		for i in w:
			var v := Terrain.sea_level(frame, f.rect.position + Vector2(i - SMOOTH, j - SMOOTH) * CELL, imgs)
			if is_nan(v):
				holes.append(j * w + i)
			else:
				raw[j * w + i] = v
				sum += v
				seen += 1
	var mean := sum / seen if seen > 0 else 0.0
	for k in holes:
		raw[k] = mean
	var across := PackedFloat32Array()  # (the window, one way and then the other)
	across.resize(w * h)
	var n := 2 * SMOOTH + 1
	for j in h:
		for i in range(SMOOTH, w - SMOOTH):
			var s := 0.0
			for k in range(-SMOOTH, SMOOTH + 1):
				s += raw[j * w + i + k]
			across[j * w + i] = s / n
	for j in f.rows:
		for i in f.cols:
			var s := 0.0
			for k in range(-SMOOTH, SMOOTH + 1):
				s += across[(j + SMOOTH + k) * w + i + SMOOTH]
			out[j * f.cols + i] = s / n
	return out


# `grid` averaged over a (2 r + 1)^2 window (at the grid's edge, over what of the window is on it).
func _settled(grid: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var across := PackedFloat32Array()
	across.resize(grid.size())
	for j in rows:
		for i in cols:
			var s := 0.0
			var n := 0
			for k in range(maxi(0, i - r), mini(cols, i + r + 1)):
				s += grid[j * cols + k]
				n += 1
			across[j * cols + i] = s / n
	var out := PackedFloat32Array()
	out.resize(grid.size())
	for j in rows:
		for i in cols:
			var s := 0.0
			var n := 0
			for k in range(maxi(0, j - r), mini(rows, j + r + 1)):
				s += across[k * cols + i]
				n += 1
			out[j * cols + i] = s / n
	return out


# A value of `grid` at `p`, on the cell's two triangles.
func _on_grid(grid: PackedFloat32Array, p: Vector2) -> float:
	if grid.is_empty():
		return 0.0
	var g := (p - rect.position) / CELL
	var i := clampi(floori(g.x), 0, cols - 2)
	var j := clampi(floori(g.y), 0, rows - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fy := clampf(g.y - j, 0.0, 1.0)
	var a := grid[j * cols + i]
	var b := grid[j * cols + i + 1]
	var c := grid[(j + 1) * cols + i]
	var d := grid[(j + 1) * cols + i + 1]
	if fx >= fy:
		return a + fx * (b - a) + fy * (d - b)
	return a + fy * (c - a) + fx * (d - c)


# ---------------------------------------------------------------- the streets

## How far a road's surface runs out each side of its centre line, [left, right] (the pavements included): the rule Kerbs and
## CityBuilder draw it by.
static func reach_of(r: Dictionary) -> Array:
	var width := float(r.w)
	var side := (width if str(r.get("class", "")) in LEVEL else width + SIDE_WALK) * 0.5
	var pave: Array = r.get("pave", [])
	if pave.size() == 2:
		return [maxf(float(pave[0]), side), maxf(float(pave[1]), side)]
	return [side, side]


func _lay_streets(roads: Array) -> void:
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		var pts := MapSites.pts(r.pts)
		var knots := PackedVector2Array()
		for s in pts.size() - 1:
			var p := pts[s]
			var q := pts[s + 1]
			var n := maxi(1, ceili(p.distance_to(q) / KNOT))
			for k in n:
				knots.append(p.lerp(q, float(k) / n))
		if not pts.is_empty():
			knots.append(pts[pts.size() - 1])
		var d := PackedFloat32Array()
		var h := PackedFloat32Array()
		var along := 0.0
		for k in knots.size():
			if k > 0:
				along += knots[k - 1].distance_to(knots[k])
			d.append(along)
			h.append(land_at(knots[k]))
		var st := {"knots": knots, "d": d, "h": h, "reach": reach_of(r), "ext": float(r.w) * 0.35, "bridge": r.get("bridge", false)}
		streets.append(st)
		var grow: float = maxf(st.reach[0], st.reach[1]) + st.ext + SHOULDER
		for k in knots.size() - 1:
			var box := Rect2(knots[k], Vector2.ZERO).expand(knots[k + 1]).grow(grow)
			for c in _cells_of(box):
				if not _cells.has(c):
					_cells[c] = []
				_cells[c].append([ri, k])


# The surface: the land with each street levelled across to its centre line (blending back over SHOULDER beside it). The
# levelling (not the land) is settled, so junctions ramp and away from the streets the surface is the land itself; and that is
# done LEVELLINGS times, each levelling to the centre lines of the surface so far, so the settling doesn't undo the level.
func _levelled() -> PackedFloat32Array:
	if flat:
		return land.duplicate()
	var near: Array = []  # (each grid point's nearest street piece: it is the same every round)
	near.resize(land.size())
	for j in rows:
		for i in cols:
			near[j * cols + i] = _nearest(point(i, j), true)
	var out := land.duplicate()
	for _time in LEVELLINGS:
		surface = out
		var change := PackedFloat32Array()
		change.resize(land.size())
		for k in land.size():
			var n: Dictionary = near[k]
			if not n.is_empty():
				var own := out[k]
				change[k] = lerpf(surface_at(n.on), own, smoothstep(0.0, SHOULDER, n.gap)) - own
		change = _settled(change, SETTLE)
		out = out.duplicate()
		for k in out.size():
			out[k] += change[k]
	return out


# A bridge's deck: straight from the surface at one end to the surface at the other, and never down into it between.
func _lay_decks() -> void:
	for st in streets:
		if not st.bridge or st.knots.size() < 2:
			continue
		var last: int = st.knots.size() - 1
		var h0 := surface_at(st.knots[0])
		var h1 := surface_at(st.knots[last])
		for k in st.knots.size():
			st.h[k] = maxf(lerpf(h0, h1, st.d[k] / maxf(st.d[last], 0.01)), surface_at(st.knots[k]))


## The nearest street piece to `p`: {h (its centre line's height there), gap (metres outside its surface; 0 or less is on it),
## road, along (metres along the road), bridge, on (the point of its centre line across from `p`)}, or {} if none is within
## SHOULDER. Where pieces overlap (a junction, a joint),
## the one whose centre line is nearest; where a bridge crosses a street, the street. With `ground_only` bridges don't count.
func _nearest(p: Vector2, ground_only := false) -> Dictionary:
	var best := {}
	var best_key := INF
	for rk in _cells.get(_cell(p), []):
		var st: Dictionary = streets[rk[0]]
		if ground_only and st.bridge:
			continue
		var k: int = rk[1]
		var a: Vector2 = st.knots[k]
		var b: Vector2 = st.knots[k + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var dir := (b - a) / length
		var along := (p - a).dot(dir)
		var across := (p - a).dot(Vector2(-dir.y, dir.x))
		var reach: float = st.reach[1] if across >= 0.0 else st.reach[0]
		var off_end := maxf(maxf(-st.ext - along, along - length - st.ext), 0.0)
		var off_side := absf(across) - reach
		var gap := off_side if off_end <= 0.0 else Vector2(maxf(off_side, 0.0), off_end).length()
		if gap > SHOULDER:
			continue
		# (on the surface, the nearest centre line wins; off it, the nearest surface; a street before a bridge)
		var key := absf(across) + maxf(maxf(-along, along - length), 0.0) if gap <= 0.0 else 1000.0 + gap
		if st.bridge:
			key += 500.0
		if key < best_key:
			var t := clampf(along / length, 0.0, 1.0)
			best_key = key
			best = {"h": lerpf(st.h[k], st.h[k + 1], t), "gap": gap, "road": rk[0], "along": st.d[k] + t * length, "bridge": st.bridge,
				"on": a + dir * t * length}
	return best


# ---------------------------------------------------------------- buildings and water

func _index_buildings(buildings: Array) -> void:
	for b in buildings:
		var poly := MapSites.pts(b.poly)
		var box := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			box = box.expand(q)
		_buildings.append({"id": int(b.id), "poly": poly, "box": box})
		for c in _cells_of(box):
			if not _building_cells.has(c):
				_building_cells[c] = []
			_building_cells[c].append(_buildings.size() - 1)


# Each building's floor: the surface at its front, the point of its walls nearest the street nearest its middle (within
# PAD_REACH; bridges aside), where its door would be; else the surface at its middle.
func _lay_pads() -> void:
	for b in _buildings:
		var mid := Vector2.ZERO
		for q in b.poly:
			mid += q
		mid /= b.poly.size()
		var level := surface_at(mid)
		var near := INF
		var street := Vector2.INF
		for st in streets:
			if st.bridge:
				continue
			for k in st.knots.size() - 1:
				var a: Vector2 = st.knots[k]
				if a.distance_to(mid) > PAD_REACH + KNOT:
					continue
				var on := Geometry2D.get_closest_point_to_segment(mid, a, st.knots[k + 1])
				var dist := on.distance_to(mid)
				if dist < near and dist <= PAD_REACH:
					near = dist
					street = on
		if street != Vector2.INF:
			var front := street
			var closest := INF
			for k in b.poly.size():
				var w := Geometry2D.get_closest_point_to_segment(street, b.poly[k], b.poly[(k + 1) % b.poly.size()])
				if w.distance_to(street) < closest:
					closest = w.distance_to(street)
					front = w
			level = surface_at(front)
		pads[b.id] = level


func _lay_water(pieces: Array) -> void:
	for poly in pieces:
		if poly.is_empty():
			continue
		var box := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			box = box.expand(q)
		_water_pieces.append({"poly": poly, "box": box})


# ---------------------------------------------------------------- the ground

# The ground: the surface, cut down under bridges' decks, buildings' floors and water.
func _cut_ground() -> void:
	if flat:
		return
	for st in streets:
		if not st.bridge:
			continue
		for k in st.knots.size() - 1:
			var a: Vector2 = st.knots[k]
			var b: Vector2 = st.knots[k + 1]
			var dir: Vector2 = (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)  # (the right-hand side, reach[1], as _nearest has it)
			var deck := PackedVector2Array([a + nrm * st.reach[1], b + nrm * st.reach[1], b - nrm * st.reach[0], a - nrm * st.reach[0]])
			var box := Rect2(deck[0], Vector2.ZERO).expand(deck[1]).expand(deck[2]).expand(deck[3])
			var ha: float = st.h[k]
			var hb: float = st.h[k + 1]
			_lower_inside(deck, box, func(p): return lerpf(ha, hb, clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0)) - DECK, CELL * 1.42)
	# Under a floor: the grid points in a building and within a cell's diagonal of it (every grid triangle under its floor has
	# its corners there), so on a slope it stands in a little cut. Only the buildings whose cut stays a cell's diagonal more
	# inside the map's own square (no triangle across its edge is touched), so neighbours agree.
	var keep_in := owned.grow(-FLOOR_CUT - CELL * 1.42) if owned.has_area() else Rect2()
	for b in _buildings:
		if not owned.has_area() or keep_in.encloses(b.box):
			_lower_inside(b.poly, b.box, func(_p): return float(pads[b.id]) - SINK, FLOOR_CUT)
	for w in _water_pieces:  # (and down into a basin under the water)
		_lower_inside(w.poly, w.box, func(p): return water_at(p) - BASIN)


# Lowers the ground at the grid points inside `poly`, or within `margin` of it, to at most `top` (a callable of the point).
func _lower_inside(poly: PackedVector2Array, box: Rect2, top: Callable, margin := 0.0) -> void:
	var lo := ((box.position - Vector2(margin, margin) - rect.position) / CELL).floor()
	var hi := ((box.end + Vector2(margin, margin) - rect.position) / CELL).ceil()
	for j in range(maxi(0, int(lo.y)), mini(rows, int(hi.y) + 1)):
		for i in range(maxi(0, int(lo.x)), mini(cols, int(hi.x) + 1)):
			var p := point(i, j)
			if Geometry2D.is_point_in_polygon(p, poly) or (margin > 0.0 and _within(p, poly, margin)):
				ground[j * cols + i] = minf(ground[j * cols + i], float(top.call(p)))


static func _within(p: Vector2, poly: PackedVector2Array, margin: float) -> bool:
	for k in poly.size():
		if Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()]).distance_to(p) <= margin:
			return true
	return false


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / INDEX), floori(p.y / INDEX))


func _cells_of(box: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := _cell(box.position)
	var b := _cell(box.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			out.append(Vector2i(x, y))
	return out
