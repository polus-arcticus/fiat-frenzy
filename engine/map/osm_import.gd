## OpenStreetMap to a district, in the game: an Overpass answer (ways with their geometry) becomes the district the game builds
## and walks on (CityBuilder, Navigation): building footprints with heights, and streets with their widths, bike lanes and how
## far their pavement runs out to the buildings. Everything is in the metres of the tile's region (TileKey.local), so the tiles
## of one region line up, whoever made them.
##
## A building belongs to the tile its middle is in (so two tiles never both have it); a street is kept whole if it comes near the
## tile. The same answer always gives the same district.
##
## The story's Frankfurt is made by the same rules, in its own frame (tools/story_district.gd: `area`).
##
## A building mapped in parts (`building:part` ways: a station's halls, a tower and its nave) keeps them, as `parts`, when they
## cover enough of its outline: the city draws the parts, and everything else walks and collides with the outline as ever.
class_name OsmImport
extends RefCounted

## Storeys a building has when the map does not say, by its kind (each one jittered by a storey either way, by its id).
const DEFAULT_LEVELS := {"apartments": 5, "commercial": 4, "office": 6, "hotel": 5, "public": 3, "residential": 4, "yes": 4}
const STOREY := 3.3
## The carriageway's width by the kind of street (only these kinds are drawn and walked).
const ROAD_WIDTH := {"primary": 12, "secondary": 9, "tertiary": 8, "residential": 7, "unclassified": 6, "pedestrian": 6,
	"service": 4, "living_street": 5}
const MIN_AREA := 15.0       # square metres: anything smaller is not a building worth drawing
## A mapped roof shape (`roof:shape`) as the one CityBuilder draws (Landmarks.roof): the rest are drawn flat.
const ROOF_SHAPES := {"gabled": "gable", "hipped": "hip", "half-hipped": "hip", "gambrel": "hip", "mansard": "hip",
	"pyramidal": "hip", "dome": "dome", "onion": "dome", "round": "round"}
const PARTS_COVER := 0.6     # a building's parts are drawn for it when together they cover this much of its outline
const PART_RISE := 24.0      # metres the tallest part roof rises (a station hall's vault)
const ROOF_STOREY := 2.6     # metres a roof level (`roof:levels`) rises
## What a building's wall looks like by its `building:material`, where it has no `building:colour` of its own.
const MATERIAL_COLOUR := {"brick": Color(0.66, 0.38, 0.30), "stone": Color(0.76, 0.72, 0.64), "sandstone": Color(0.78, 0.58, 0.46),
	"glass": Color(0.56, 0.66, 0.74), "concrete": Color(0.72, 0.71, 0.68), "wood": Color(0.58, 0.44, 0.32), "metal": Color(0.62, 0.64, 0.68)}
const STREET_REACH := 60.0   # a street within this of the tile is kept
const PAVE_REACH := 18.0     # how far out the pavement is looked for
const PAVE_STEP := 8.0       # metres between the samples along a street
const GRID := 40.0           # the cell of the edge grid the pavement search uses


## The district of `tile_key` from `overpass` (the parsed answer: {"elements": [...]}).
static func tile(overpass: Dictionary, tile_key: String) -> Dictionary:
	var region := TileKey.region_of(tile_key)
	var rect := TileKey.rect(tile_key)
	var made := area(overpass, func(lat: float, lon: float) -> Vector2: return TileKey.local(lat, lon, region), rect)
	var nw: Array = TileKey.lat_lon(rect.position, region)
	return {"tile": tile_key, "region": region, "origin": {"lat": nw[0], "lon": nw[1]},
		"bounds": made.bounds, "buildings": made.buildings, "roads": made.roads, "squares": made.squares}


## The district of `overpass` in any frame (`local`: lat, lon -> metres): {buildings, roads, bounds}. With a `rect` (a tile's),
## only the buildings whose middle is in it and the streets that come near it are kept, and the bounds take it in; with none,
## everything is.
static func area(overpass: Dictionary, local: Callable, rect := Rect2()) -> Dictionary:
	var all_buildings: Array = []  # (every one in the answer: the pavement is measured to them, the tile's or not)
	var parts: Array = []
	var roads: Array = []
	var squares: Array = []
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var geom: Array = e.get("geometry", [])
		if e.get("type", "") == "relation" and _paved_area(tags):  # (a square mapped as a relation: its outer rings)
			for ring in OsmDressing.rings_by(e.get("members", []), local):
				_add_square(squares, ring, tags, rect)
		if geom.is_empty():
			continue
		var pts := PackedVector2Array()
		for p in geom:
			pts.append(local.call(float(p.lat), float(p.lon)))
		if _paved_area(tags) and pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.2:
			_add_square(squares, pts.slice(0, pts.size() - 1), tags, rect)
		if tags.has("building"):
			var b := _building(e, tags, pts)
			if not b.is_empty():
				all_buildings.append(b)
		elif tags.has("building:part"):
			var part := _part(e, tags, pts)
			if not part.is_empty():
				parts.append(part)
		elif tags.has("highway"):
			var r := _road(tags, pts, rect)
			if not r.is_empty():
				roads.append(r)
	var grid := _edge_grid(all_buildings)
	for r in roads:
		r["pave"] = _pavement(r, grid)
		r["pts"] = _flat(r["pts"])
	_give_parts(all_buildings, parts)
	var buildings := all_buildings.filter(func(b): return not rect.has_area() or rect.has_point(_middle(b.pts)))
	for b in buildings:
		b["poly"] = _flat(b.pts)
		b.erase("pts")
	var bounds := rect
	for list in [buildings.map(func(b): return b.poly), roads.map(func(r): return r.pts)]:
		for flat in list:
			bounds = bounds.merge(_box(flat)) if bounds.has_area() else _box(flat)
	return {"buildings": buildings, "roads": roads, "squares": squares,
		"bounds": [_r(bounds.position.x), _r(bounds.position.y), _r(bounds.end.x), _r(bounds.end.y)]}


## Is it paving to draw as an area: a pedestrian or footway area, or a square?
static func _paved_area(tags: Dictionary) -> bool:
	if tags.has("building"):
		return false
	if str(tags.get("place", "")) == "square":
		return true
	return str(tags.get("highway", "")) in ["pedestrian", "footway"] and (str(tags.get("area", "")) == "yes" or str(tags.get("type", "")) == "multipolygon")


static func _add_square(squares: Array, ring: PackedVector2Array, tags: Dictionary, rect: Rect2) -> void:
	if ring.size() < 3 or (rect.has_area() and not rect.has_point(_middle(ring))):
		return
	var rounded := PackedVector2Array()
	for p in ring:
		rounded.append(Vector2(_r(p.x), _r(p.y)))
	if Geometry2D.triangulate_polygon(rounded).is_empty():
		return
	squares.append({"poly": _flat(rounded), "surface": str(tags.get("surface", ""))})


## A part of a building: its outline, how high it stands (`h`) and from where up (`min_h`), and its looks. {} if too small.
static func _part(e: Dictionary, tags: Dictionary, raw: PackedVector2Array) -> Dictionary:
	if str(tags["building:part"]) == "no":
		return {}
	var base := _building(e, {"building": "yes"}.merged(tags, true), raw)
	if base.is_empty():
		return {}
	var low := str(tags.get("min_height", "")).split(" ")[0]
	var part := {"pts": base.pts, "h": base.h, "min_h": _r(low.to_float()) if low.is_valid_float() else 0.0}
	for k in ["roof", "rise", "colour"]:
		if base.has(k):
			part[k] = base[k]
	var up := str(tags.get("roof:height", "")).split(" ")[0]
	if part.has("roof") and up.is_valid_float():  # (a mapped height is to the roof's top: the walls stop short of it)
		part["rise"] = clampf(up.to_float(), 1.0, PART_RISE)
		part["h"] = _r(maxf(part.min_h + 1.0, part.h - part.rise))
	return part


## Gives each building the parts whose middles are in its outline, if they cover PARTS_COVER of it.
static func _give_parts(buildings: Array, parts: Array) -> void:
	if parts.is_empty():
		return
	var cells := {}  # cell -> parts whose middle is there
	for part in parts:
		var m := _middle(part.pts)
		var cell := Vector2i(floori(m.x / GRID), floori(m.y / GRID))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(part)
	for b in buildings:
		var box := _box(_flat(b.pts))
		var mine: Array = []
		var covered := 0.0
		for gx in range(floori(box.position.x / GRID), floori(box.end.x / GRID) + 1):
			for gy in range(floori(box.position.y / GRID), floori(box.end.y / GRID) + 1):
				for part in cells.get(Vector2i(gx, gy), []):
					if Geometry2D.is_point_in_polygon(_middle(part.pts), b.pts):
						mine.append(part)
						if float(part.min_h) <= 0.0:
							covered += absf(_signed_area(part.pts))
		if mine.is_empty() or covered < absf(_signed_area(b.pts)) * PARTS_COVER:
			continue
		b["parts"] = mine.map(func(p):
			var out: Dictionary = p.duplicate()
			out["poly"] = _flat(out.pts)
			out.erase("pts")
			return out)


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
	var b := {"id": int(e.id), "kind": kind, "levels": levels, "h": _r(h), "pts": rounded}
	_looks(b, tags)
	var c := civic(tags)
	if c != "":
		b["civic"] = c
	return b


## What civic kind of building the map says this is (the archetype Archetypes gives a look to), or "" for any other: from its
## `building` value and the `amenity` and `railway` tags on its outline. A civic place mapped as a point inside a building is not
## seen here (that needs its own query). Only the Christian place of worship, for now: a mosque or a synagogue is not a church.
static func civic(tags: Dictionary) -> String:
	var kind := str(tags.get("building", ""))
	var amenity := str(tags.get("amenity", ""))
	if kind in ["church", "cathedral", "chapel"]:
		return "church"
	if amenity == "place_of_worship" and str(tags.get("religion", "christian")) == "christian" and kind in ["yes", "church"]:
		return "church"
	if kind == "train_station" or str(tags.get("railway", "")) == "station" or str(tags.get("public_transport", "")) == "station":
		return "station"
	if kind == "fire_station" or amenity == "fire_station":
		return "fire"
	if amenity == "townhall":
		return "townhall"
	if amenity == "police":
		return "police"
	if kind == "hospital" or amenity == "hospital":
		return "hospital"
	return ""


## What the map says a building looks like, where it says (CityBuilder draws it): its roof's shape and rise, and its walls'
## colour (`building:colour`, or its material's).
static func _looks(b: Dictionary, tags: Dictionary) -> void:
	var shape := str(tags.get("roof:shape", ""))
	if ROOF_SHAPES.has(shape):
		b["roof"] = ROOF_SHAPES[shape]
		var levels := str(tags.get("roof:levels", ""))
		var rise := str(tags.get("roof:height", "")).split(" ")[0]
		if rise.is_valid_float():
			b["rise"] = clampf(rise.to_float(), 1.0, 12.0)
		elif levels.is_valid_float():
			b["rise"] = clampf(levels.to_float() * ROOF_STOREY, 1.5, 12.0)
	var colour := str(tags.get("building:colour", ""))
	if colour != "":
		var c := Color.from_string(colour, Color(0, 0, 0, 0))
		if c.a > 0.0:
			b["colour"] = c
	elif MATERIAL_COLOUR.has(str(tags.get("building:material", ""))):
		b["colour"] = MATERIAL_COLOUR[str(tags["building:material"])]


static func _road(tags: Dictionary, pts: PackedVector2Array, rect: Rect2) -> Dictionary:
	var cls := str(tags.highway)
	if not ROAD_WIDTH.has(cls):
		return {}
	var near := rect.grow(STREET_REACH)
	if rect.has_area() and not Array(pts).any(func(p): return near.has_point(p)):
		return {}
	var rounded := PackedVector2Array()
	for p in pts:
		rounded.append(Vector2(_r(p.x), _r(p.y)))
	var r := {"name": str(tags.get("name", "")), "class": cls, "w": ROAD_WIDTH[cls], "pts": rounded}
	var bike := _bike_lanes(tags)
	if bike != ["", ""]:
		r["bike"] = bike
	if str(tags.get("bridge", "no")) != "no":  # (over water, or a road, or the rails: OsmWater cuts every street out of water)
		r["bridge"] = true
	if tags.has("surface"):  # what it's paved with (CityBuilder's colour; cobbles are rough to skate: Kerbs.rough_at)
		r["surface"] = str(tags.surface)
	if str(tags.get("lit", "no")) in ["yes", "24/7", "automatic", "limited"]:  # it has street lamps (StreetThings puts them up)
		r["lit"] = true
	if str(tags.get("lanes", "")).is_valid_int():
		r["lanes"] = int(str(tags.lanes))
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
