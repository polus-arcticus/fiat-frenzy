## OpenStreetMap to a tile's water: solid, so the sim walks round it (Navigation) and the hero can't walk into it. It comes with
## the tile's streets, before anyone lands (TileSource's "water" layer), and is the same for everyone in the tile.
##
## One rule makes it: all the tile's water, merged into one (lakes, ponds and river areas, and rivers and canals as a band
## along their centre line, as wide as they're tagged), cut to the tile's square and REACH past it (as far as its streets go),
## and then **every street cut out of it**.
## So a bridge is just a street over water (and it gets parapets, below), and a street along the river stays a street even
## where the river's band, drawn from its centre line, would reach over it.
## - `pieces`: the water left, as polygons (it's solid);
## - `edges`: where it meets land: a quay wall along the bank, a parapet along a bridge. Not along the edge of its square, where
##   the water carries on.
class_name OsmWater
extends RefCounted

## The Overpass filters for water areas (TileSource asks for ways and relations of each).
const AREAS := ["[\"natural\"=\"water\"]", "[\"waterway\"=\"riverbank\"]"]
## A waterway's width by kind when it isn't tagged, in metres.
const RIVER_WIDTH := {"river": 40.0, "canal": 16.0, "stream": 3.0}
const STREET_CUT := 3.0   # metres either side of a carriageway that are cut out of the water too (the pavements)
const MIN_AREA := 2.0     # square metres: smaller scraps of water are dropped
const ON_EDGE := 0.05     # metres from the edge of the water's square that count as on it
const REACH := 60.0       # metres past the tile's edge the water reaches: as far as its streets do (the margin TileSource
                          # asks for), so a river doesn't stop dead at the tile's square


## The water of `tile_key` from the raw answer, given the tile's district (its streets cut through it): {pieces, edges}.
static func tile(overpass: Dictionary, tile_key: String, district: Dictionary) -> Dictionary:
	var region := TileKey.region_of(tile_key)
	var rect := TileKey.rect(tile_key).grow(REACH)
	var square := _rect_poly(rect)
	var shapes: Array = []
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if tags.get("tunnel", "no") != "no" or tags.get("covered", "no") == "yes":
			continue  # (a stream in a culvert: underground)
		if e.get("type", "") == "way" and RIVER_WIDTH.has(str(tags.get("waterway", ""))):
			shapes.append_array(_band(OsmDressing.points(e.get("geometry", []), region), width_of(tags)))
		elif tags.get("natural", "") == "water" or tags.get("waterway", "") == "riverbank":
			if e.get("type", "") == "way":
				var pts := OsmDressing.points(e.get("geometry", []), region)
				if pts.size() >= 3:
					shapes.append(pts)
			elif e.get("type", "") == "relation":
				shapes.append_array(OsmDressing.rings(e.get("members", []), region))
	var water: Array = []
	for s in shapes:
		for part in Geometry2D.intersect_polygons(s, square):
			if not Geometry2D.is_polygon_clockwise(part):
				water.append(part)
	water = _union(water)
	for cut in _streets(district):
		water = _clip(water, cut)
	water = water.filter(func(p): return _area(p) >= MIN_AREA)
	return {"pieces": water, "edges": _edges(water, rect)}


## How wide a waterway is: its `width` tag, or its kind's.
static func width_of(tags: Dictionary) -> float:
	var w := str(tags.get("width", "")).split(" ")[0]
	if w.is_valid_float():
		return clampf(w.to_float(), 1.0, 400.0)
	return float(RIVER_WIDTH.get(str(tags.get("waterway", "")), 10.0))


## Whether a point is in the water.
static func wet(water: Dictionary, p: Vector2) -> bool:
	for poly in water.get("pieces", []):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


# A centre line as quads `w` wide, one a segment, overlapping at the joints (merged after, so the bends close).
static func _band(pts: PackedVector2Array, w: float) -> Array:
	var out: Array = []
	for k in pts.size() - 1:
		var e := pts[k + 1] - pts[k]
		if e.length() < 0.1:
			continue
		var d := e.normalized()
		var n := Vector2(-d.y, d.x) * w * 0.5
		var a := pts[k] - d * w * 0.5
		var b := pts[k + 1] + d * w * 0.5
		var quad := PackedVector2Array([a + n, a - n, b - n, b + n])
		if Geometry2D.is_polygon_clockwise(quad):
			quad.reverse()  # (counter-clockwise: a clockwise result of the clipping is a hole)
		out.append(quad)
	return out


# Every street's carriageway and pavements, as quads a segment.
static func _streets(district: Dictionary) -> Array:
	var out: Array = []
	for r in district.get("roads", []):
		var flat: Array = r.pts
		var half := float(r.w) * 0.5 + STREET_CUT
		for k in range(0, flat.size() - 3, 2):
			var p := Vector2(flat[k], flat[k + 1])
			var q := Vector2(flat[k + 2], flat[k + 3])
			if p.distance_to(q) < 0.1:
				continue
			var d := (q - p).normalized()
			var n := Vector2(-d.y, d.x) * half
			var ext := d * float(r.w) * 0.35  # (the joints overlap, as the drawn streets' do)
			out.append(PackedVector2Array([p - ext + n, p - ext - n, q + ext - n, q + ext + n]))
	return out


# The polygons merged where they touch (holes, islands, are dropped: the water fills them).
static func _union(polys: Array) -> Array:
	var out: Array = []
	for p in polys:
		var merged: PackedVector2Array = p
		var keep: Array = []
		for o in out:
			if _box(o).intersects(_box(merged), true):
				var m := Geometry2D.merge_polygons(merged, o).filter(func(x): return not Geometry2D.is_polygon_clockwise(x))
				if m.size() == 1:
					merged = m[0]
					continue
			keep.append(o)
		keep.append(merged)
		out = keep
	return out


# The polygons with `cut` taken out of them.
static func _clip(polys: Array, cut: PackedVector2Array) -> Array:
	var box := _box(cut)
	var out: Array = []
	for p in polys:
		if not _box(p).intersects(box, true):
			out.append(p)
			continue
		for piece in Geometry2D.clip_polygons(p, cut):
			if not Geometry2D.is_polygon_clockwise(piece):
				out.append(piece)
	return out


# The edges of the water where it meets land: all its edges but those along the tile's square.
static func _edges(water: Array, rect: Rect2) -> Array:
	var out: Array = []
	for poly in water:
		for i in poly.size():
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % poly.size()]
			if a.distance_to(b) < 0.05 or (_on_side(a, rect) and _on_side(b, rect) and _same_side(a, b, rect)):
				continue
			out.append({"a": a, "b": b})
	return out


static func _on_side(p: Vector2, r: Rect2) -> bool:
	return absf(p.x - r.position.x) < ON_EDGE or absf(p.x - r.end.x) < ON_EDGE or absf(p.y - r.position.y) < ON_EDGE or absf(p.y - r.end.y) < ON_EDGE


static func _same_side(a: Vector2, b: Vector2, r: Rect2) -> bool:
	for x in [r.position.x, r.end.x]:
		if absf(a.x - x) < ON_EDGE and absf(b.x - x) < ON_EDGE:
			return true
	for y in [r.position.y, r.end.y]:
		if absf(a.y - y) < ON_EDGE and absf(b.y - y) < ON_EDGE:
			return true
	return false


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


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
