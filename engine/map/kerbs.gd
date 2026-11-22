## The kerbs of a district: its pavements raised HEIGHT above the carriageway, made from what the map already has (each
## street's width and how far its pavement runs out to the buildings: OsmImport), so they cost no request. Where a street
## crosses another, the other's pavement is cut away so the road goes through (a junction has no kerb across it). A
## pedestrian street is level paving: no kerb.
## - `pieces`: the raised pavement, as polygons (their tops at HEIGHT);
## - `edges`: the kerb lines, where a pavement drops to a carriageway (what a skateboard grinds: Skating);
## - `height_at(p)`: how high the ground is at a point (HEIGHT on a pavement, else 0), for the views that stand things on it.
## Nothing the sim walks on: Navigation stays flat.
class_name Kerbs
extends RefCounted

const HEIGHT := 0.12          # metres from the carriageway to the top of the kerb
const SIDE_WALK := 3.4        # the pavement both sides take together where the map doesn't say (CityBuilder's rule)
const CELL := 16.0            # the lookup grid's cell, in metres
const LEVEL := ["pedestrian"] # streets that are paved level, with no kerbs
## Surfaces rough to roll on (a street's `surface`): a skateboard is slower on them (Skating.ROUGH).
const ROUGH := ["sett", "cobblestone", "unhewn_cobblestone", "gravel", "pebblestone"]

var pieces: Array[PackedVector2Array] = []
var edges: Array = []          # [{a: Vector2, b: Vector2, side: the unit vector toward the pavement}]
var _cells := {}               # Vector2i -> [piece index]
var _edge_cells := {}          # Vector2i -> [edge index]
var _boxes: Array[Rect2] = []
var _rough: Array[PackedVector2Array] = []  # rough carriageways (ROUGH)
var _rough_cells := {}


## The kerbs of `district`. `hollow` holds the ids of buildings with a door cut into them (CityBuilder's openings): a
## pavement stops at their walls, so their floor inside stays level.
static func of(district: Dictionary, hollow := {}) -> Kerbs:
	var k := Kerbs.new()
	var ways: Array = []    # carriageway quads, [{poly, box, road, seg}]
	var bands: Array = []   # the pavement quads to raise, and the kerb lines along them
	var roads: Array = district.get("roads", [])
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		var pts := _pts(r.pts)
		var width := float(r.w)
		var level := str(r.get("class", "")) in LEVEL
		var reach := [(width + SIDE_WALK) * 0.5, (width + SIDE_WALK) * 0.5]
		var pave: Array = r.get("pave", [])
		if pave.size() == 2:
			reach = [maxf(float(pave[0]), reach[0]), maxf(float(pave[1]), reach[1])]
		for s in pts.size() - 1:
			var p := pts[s]
			var q := pts[s + 1]
			if p.distance_to(q) < 0.1:
				continue
			var dir := (q - p).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var ext := dir * width * 0.35  # (the joints overlap, as the drawn streets' do)
			if str(r.get("surface", "")) in ROUGH:
				k._rough.append(_quad(p - ext, q + ext, nrm, -width * 0.5, width * 0.5))
			if not level:
				var way := _quad(p - ext, q + ext, nrm, -width * 0.5, width * 0.5)
				ways.append({"poly": way, "box": _box(way), "road": ri, "seg": s})
				for side in 2:
					var sgn := 1.0 if side == 1 else -1.0
					var band := _quad(p - ext, q + ext, nrm * sgn, width * 0.5, float(reach[side]))
					var kerb := PackedVector2Array([p + nrm * sgn * width * 0.5, q + nrm * sgn * width * 0.5])
					bands.append({"poly": band, "kerb": kerb, "side": nrm * sgn, "road": ri, "seg": s})
	var way_cells := _index(ways.map(func(w): return w.box))
	var walls: Array = []
	for b in district.get("buildings", []):
		if hollow.has(int(b.id)):
			var poly := _pts(b.poly)
			walls.append({"poly": poly, "box": _box(poly)})
	for band in bands:
		var box := _box(band.poly)
		var cuts: Array = []
		for wi in _near(way_cells, box):
			var w: Dictionary = ways[wi]
			if not (w.road == band.road and w.seg == band.seg) and (w.box as Rect2).intersects(box):
				cuts.append(w.poly)
		var parts: Array = [band.poly]
		var lines: Array = [band.kerb]
		for c in cuts:
			parts = _clip_all(parts, c)
			lines = _clip_lines(lines, c)
		for w in walls:
			if (w.box as Rect2).intersects(box):
				parts = _clip_all(parts, w.poly)
		for part in parts:
			k.pieces.append(part)
		for line in lines:
			if line.size() >= 2 and line[0].distance_to(line[line.size() - 1]) > 0.3:
				k.edges.append({"a": line[0], "b": line[line.size() - 1], "side": band.side})
	k._boxes.assign(k.pieces.map(func(p): return _box(p)))
	k._cells = _index(k._boxes)
	k._edge_cells = _index(k.edges.map(func(e): return Rect2(e.a, Vector2.ZERO).expand(e.b)))
	k._rough_cells = _index(k._rough.map(func(q): return _box(q)))
	return k


## Is the street at `p` paved rough (cobbles, setts, gravel: ROUGH)?
func rough_at(p: Vector2) -> bool:
	for i in _rough_cells.get(_cell(p), []):
		if Geometry2D.is_point_in_polygon(p, _rough[i]):
			return true
	return false


## How high the ground is at `p`: on a raised pavement HEIGHT, else 0.
func height_at(p: Vector2) -> float:
	for i in _cells.get(_cell(p), []):
		if _boxes[i].has_point(p) and Geometry2D.is_point_in_polygon(p, pieces[i]):
			return HEIGHT
	return 0.0


## The kerb lines within `radius` of `p` (their indices into `edges`).
func edges_near(p: Vector2, radius: float) -> Array:
	var out := {}
	var lo := _cell(p - Vector2(radius, radius))
	var hi := _cell(p + Vector2(radius, radius))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for i in _edge_cells.get(Vector2i(x, y), []):
				var e: Dictionary = edges[i]
				if Geometry2D.get_closest_point_to_segment(p, e.a, e.b).distance_to(p) <= radius:
					out[i] = true
	return out.keys()


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


# Cell -> the indices of the boxes that touch it.
static func _index(boxes: Array) -> Dictionary:
	var cells := {}
	for i in boxes.size():
		var b: Rect2 = boxes[i]
		var lo := _cell(b.position)
		var hi := _cell(b.end)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				var c := Vector2i(x, y)
				if not cells.has(c):
					cells[c] = []
				cells[c].append(i)
	return cells


static func _near(cells: Dictionary, box: Rect2) -> Array:
	var out := {}
	var lo := _cell(box.position)
	var hi := _cell(box.end)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for i in cells.get(Vector2i(x, y), []):
				out[i] = true
	return out.keys()


static func _clip_all(parts: Array, cut: PackedVector2Array) -> Array:
	var out: Array = []
	for part in parts:
		for piece in Geometry2D.clip_polygons(part, cut):
			if not Geometry2D.is_polygon_clockwise(piece) and _area(piece) > 0.05:  # (a clockwise result is a hole)
				out.append(piece)
	return out


static func _clip_lines(lines: Array, cut: PackedVector2Array) -> Array:
	var out: Array = []
	for line in lines:
		out.append_array(Geometry2D.clip_polyline_with_polygon(line, cut))  # (the parts outside the carriageway)
	return out


# The quad along p..q from `inner` to `outer` metres to the `side` of the line, counter-clockwise.
static func _quad(p: Vector2, q: Vector2, side: Vector2, inner: float, outer: float) -> PackedVector2Array:
	var poly := PackedVector2Array([p + side * inner, q + side * inner, q + side * outer, p + side * outer])
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	return poly


static func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out


static func _box(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5
