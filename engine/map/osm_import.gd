## OpenStreetMap to a district, in the game: an Overpass answer (ways with their geometry) becomes the district the game builds
## and walks on (CityBuilder, Navigation): building footprints with heights, and streets with their widths, bike lanes and how
## far their pavement runs out to the buildings. Everything is in the metres of the tile's region (TileKey.local), so the tiles
## of one region line up, whoever made them.
##
## A building belongs to the tile its middle is in (so two tiles never both have it); a street is kept whole if it comes near the
## tile. The same answer always gives the same district.
##
## The rules are those of tools/osm_to_district.py, which made the Frankfurt district on its own local origin (the story's map,
## not yet moved onto region coordinates): until it is, the rules live in both, and a change to one is a change to the other.
class_name OsmImport
extends RefCounted

## Storeys a building has when the map does not say, by its kind (each one jittered by a storey either way, by its id).
const DEFAULT_LEVELS := {"apartments": 5, "commercial": 4, "office": 6, "hotel": 5, "public": 3, "residential": 4, "yes": 4}
const STOREY := 3.3
## The carriageway's width by the kind of street (only these kinds are drawn and walked).
const ROAD_WIDTH := {"primary": 12, "secondary": 9, "tertiary": 8, "residential": 7, "unclassified": 6, "pedestrian": 6,
	"service": 4, "living_street": 5}
const MIN_AREA := 15.0       # square metres: anything smaller is not a building worth drawing
const STREET_REACH := 60.0   # a street within this of the tile is kept
const PAVE_REACH := 18.0     # how far out the pavement is looked for
const PAVE_STEP := 8.0       # metres between the samples along a street
const GRID := 40.0           # the cell of the edge grid the pavement search uses


## The district of `tile_key` from `overpass` (the parsed answer: {"elements": [...]}).
static func tile(overpass: Dictionary, tile_key: String) -> Dictionary:
	var region := TileKey.region_of(tile_key)
	var rect := TileKey.rect(tile_key)
	var all_buildings: Array = []  # (every one in the answer: the pavement is measured to them, the tile's or not)
	var roads: Array = []
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var geom: Array = e.get("geometry", [])
		if geom.is_empty():
			continue
		var pts := PackedVector2Array()
		for p in geom:
			pts.append(TileKey.local(float(p.lat), float(p.lon), region))
		if tags.has("building"):
			var b := _building(e, tags, pts)
			if not b.is_empty():
				all_buildings.append(b)
		elif tags.has("highway"):
			var r := _road(tags, pts, rect)
			if not r.is_empty():
				roads.append(r)
	var grid := _edge_grid(all_buildings)
	for r in roads:
		r["pave"] = _pavement(r, grid)
		r["pts"] = _flat(r["pts"])
	var buildings := all_buildings.filter(func(b): return rect.has_point(_middle(b.pts)))
	for b in buildings:
		b["poly"] = _flat(b.pts)
		b.erase("pts")
	var bounds := rect
	for b in buildings:
		bounds = bounds.merge(_box(b.poly))
	for r in roads:
		bounds = bounds.merge(_box(r.pts))
	var nw: Array = TileKey.lat_lon(rect.position, region)
	return {"tile": tile_key, "region": region, "origin": {"lat": nw[0], "lon": nw[1]},
		"bounds": [_r(bounds.position.x), _r(bounds.position.y), _r(bounds.end.x), _r(bounds.end.y)],
		"buildings": buildings, "roads": roads}


static func _building(e: Dictionary, tags: Dictionary, raw: PackedVector2Array) -> Dictionary:
	var pts := raw
	if pts.size() > 3 and pts[0].is_equal_approx(pts[pts.size() - 1]):
		pts = pts.slice(0, pts.size() - 1)
	if pts.size() < 3:
		return {}
	var area := _signed_area(pts)
	if absf(area) < MIN_AREA:
		return {}
	if area < 0.0:
		pts.reverse()  # counter-clockwise
	var kind := str(tags.building)
	var h := -1.0
	var levels := 0
	if tags.has("height") and str(tags.height).split(" ")[0].is_valid_float():
		h = str(tags.height).split(" ")[0].to_float()
		levels = maxi(1, roundi(h / STOREY))
	else:
		if tags.has("building:levels") and str(tags["building:levels"]).is_valid_float():
			levels = maxi(1, int(str(tags["building:levels"]).to_float()))
		elif tags.has("building:levels"):
			levels = 4
		else:
			levels = maxi(2, int(DEFAULT_LEVELS.get(kind, 4)) + _jitter(e.id))
		h = levels * STOREY
	if kind == "roof":
		h = 3.5
		levels = 1
	var rounded := PackedVector2Array()
	for p in pts:
		rounded.append(Vector2(_r(p.x), _r(p.y)))
	return {"id": int(e.id), "kind": kind, "levels": levels, "h": _r(h), "pts": rounded}


static func _road(tags: Dictionary, pts: PackedVector2Array, rect: Rect2) -> Dictionary:
	var cls := str(tags.highway)
	if not ROAD_WIDTH.has(cls):
		return {}
	var near := rect.grow(STREET_REACH)
	if not Array(pts).any(func(p): return near.has_point(p)):
		return {}
	var rounded := PackedVector2Array()
	for p in pts:
		rounded.append(Vector2(_r(p.x), _r(p.y)))
	var r := {"name": str(tags.get("name", "")), "class": cls, "w": ROAD_WIDTH[cls], "pts": rounded}
	var bike := _bike_lanes(tags)
	if bike != ["", ""]:
		r["bike"] = bike
	return r


## [left, right] bike provision of a street from its tags: "", "lane" or "track".
static func _bike_lanes(tags: Dictionary) -> Array:
	var out := ["", ""]
	var sides_of := {"cycleway": [0, 1], "cycleway:both": [0, 1], "cycleway:left": [0], "cycleway:right": [1]}
	for k in tags:
		if not (k == "cycleway" or str(k).begins_with("cycleway:")):
			continue
		var v := str(tags[k])
		if not v in ["lane", "track"]:
			continue
		for i in sides_of.get(k, []):
			if out[i] != "track":
				out[i] = v
	return out


## How far each side's pavement runs out to the building line: the typical (median) distance from the street's middle to the
## first building wall, sampled every PAVE_STEP metres, or just past the kerb where there are no buildings.
static func _pavement(r: Dictionary, grid: Dictionary) -> Array:
	var pts: PackedVector2Array = r.pts
	var sides := [[], []]
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var dir := (b - a) / length
		var nrm := Vector2(-dir.y, dir.x)  # (the right-hand side of the way, as the game's +normal is)
		var n := maxi(1, int(length / PAVE_STEP))
		for k in n:
			var p := a + dir * (k + 0.5) * minf(PAVE_STEP, length / n)
			for side in 2:
				var d := _nearest_wall(p, nrm * (-1.0 if side == 0 else 1.0), grid)
				if d >= 0.0:
					sides[side].append(d)
	var half := float(r.w) / 2.0
	var pave := []
	for side in sides:
		if side.size() >= 2:
			side.sort()
			var m: float = side[side.size() / 2]
			pave.append(_r(maxf(half + 1.7, minf(m - 0.3, 16.0))))
		else:
			pave.append(_r(half + 1.7))
	return pave


static func _edge_grid(buildings: Array) -> Dictionary:
	var grid := {}
	for b in buildings:
		var q: PackedVector2Array = b.pts
		for i in q.size():
			var a := q[i]
			var c := q[(i + 1) % q.size()]
			for gx in range(floori(minf(a.x, c.x) / GRID) - 1, floori(maxf(a.x, c.x) / GRID) + 2):
				for gy in range(floori(minf(a.y, c.y) / GRID) - 1, floori(maxf(a.y, c.y) / GRID) + 2):
					var cell := Vector2i(gx, gy)
					if not grid.has(cell):
						grid[cell] = []
					grid[cell].append([a, c])
	return grid


## Distance from `p` along `n` to the first building edge within PAVE_REACH, or -1.
static func _nearest_wall(p: Vector2, n: Vector2, grid: Dictionary) -> float:
	var best := -1.0
	for seg in grid.get(Vector2i(floori(p.x / GRID), floori(p.y / GRID)), []):
		var a: Vector2 = seg[0]
		var c: Vector2 = seg[1]
		var d := c - a
		var den := n.x * d.y - n.y * d.x
		if absf(den) < 1e-9:
			continue
		var t := ((a.x - p.x) * d.y - (a.y - p.y) * d.x) / den
		var u := ((a.x - p.x) * n.y - (a.y - p.y) * n.x) / den
		if t > 0.3 and t < PAVE_REACH and u >= 0.0 and u <= 1.0 and (best < 0.0 or t < best):
			best = t
	return best


## A storey up or down by the building's id, the same every time (md5 of the id, mod 3, less one).
static func _jitter(id: Variant) -> int:
	var hex := str(int(id)).md5_text()
	var sum := 0
	for ch in hex:  # (16 is 1 mod 3, so a hex number mod 3 is the sum of its digits mod 3)
		sum += ch.hex_to_int()
	return sum % 3 - 1


static func _signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a / 2.0


static func _middle(pts: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += p
	return s / pts.size()


static func _flat(pts: PackedVector2Array) -> Array:
	var out := []
	for p in pts:
		out.append(p.x)
		out.append(p.y)
	return out


static func _box(flat: Array) -> Rect2:
	var r := Rect2(Vector2(flat[0], flat[1]), Vector2.ZERO)
	for i in range(0, flat.size(), 2):
		r = r.expand(Vector2(flat[i], flat[i + 1]))
	return r


static func _r(v: float) -> float:
	return roundf(v * 10.0) / 10.0
