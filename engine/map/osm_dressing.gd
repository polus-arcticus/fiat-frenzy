## OpenStreetMap to a tile's dressing: what makes it look like the place, and nothing the sim walks on or reads (so it can come
## late, or never, and the town is the same for everyone either way). The green (parks, gardens, grass, pitches, cemeteries),
## woods, and trees scattered in the green with dice of the tile's own (mapped trees aren't fetched: a tile can have
## thousands). Everything is in region metres and cut to the tile's square, as its buildings are owned by it: neighbours
## never draw the same park twice. (Water is not dressing: it's solid, the sim walks round it, so it comes with the streets:
## OsmWater.)
##
## Areas come as closed ways, or as multipolygon relations whose outer ways are joined into rings here (`rings`). The server
## cuts shapes to the tile's box (TileSource), so a ring that can't be closed is left out.
class_name OsmDressing
extends RefCounted

## The Overpass filters for the areas (TileSource asks for ways and relations of each), in the order they're looked at.
const AREAS := [
	"[\"leisure\"~\"^(park|garden|playground|pitch|dog_park)$\"]",
	"[\"landuse\"~\"^(grass|meadow|village_green|recreation_ground|cemetery|forest)$\"]",
	"[\"natural\"~\"^(wood|scrub)$\"]",
]
const TREE_EVERY := {"green": 220.0, "wood": 45.0}  # square metres per tree
const MOST_TREES := 2500  # in a tile's worth of map...
const TILE_AREA := 152000.0  # (square metres: a tile at Frankfurt, 390 m across)
const MOST_TILES := 6.0   # ...and a bigger map (the story's) gets that many more, at most
const KERB_CLEAR := 2.5   # metres a tree keeps from a street's carriageway
const JOIN := 1.0         # metres within which two ways' ends are the same point

## What kind of dressing an area's tags make: "green", "pitch", "wood", or "" (water is OsmWater's).
static func kind_of(tags: Dictionary) -> String:
	if tags.get("leisure", "") in ["pitch", "playground"]:
		return "pitch"
	if tags.get("landuse", "") == "forest" or tags.get("natural", "") in ["wood", "scrub"]:
		return "wood"
	if tags.get("leisure", "") in ["park", "garden", "dog_park"] or tags.get("landuse", "") in ["grass", "meadow", "village_green", "recreation_ground", "cemetery"]:
		return "green"
	return ""


## The dressing of `tile_key` from the raw answer, given the tile's district (trees keep off its streets and out of its
## buildings): {areas: [{kind, poly}], trees: PackedVector2Array}.
static func tile(overpass: Dictionary, tile_key: String, district: Dictionary) -> Dictionary:
	return of(overpass, MapFrame.tile(tile_key), district)


## The same in any frame (MapFrame: the story's Frankfurt is one of its own), cut to what the frame owns.
static func of(overpass: Dictionary, frame: MapFrame, district: Dictionary) -> Dictionary:
	var rect := frame.rect
	var square := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var areas: Array = []
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var kind := kind_of(tags)
		if kind == "":
			continue
		var rings: Array = []
		if e.get("type", "") == "way":
			var pts := points(e.get("geometry", []), frame)
			if pts.size() >= 3:
				rings.append(pts)
		elif e.get("type", "") == "relation":
			rings = OsmDressing.rings(e.get("members", []), frame)
		for ring in rings:
			for part in Geometry2D.intersect_polygons(ring, square):
				if absf(_area(part)) > 4.0:
					areas.append({"kind": kind, "poly": part})
	areas.sort_custom(func(a, b): return _order(a.kind) < _order(b.kind))  # (drawn in this order)
	var most := int(MOST_TREES * clampf(rect.get_area() / TILE_AREA, 1.0, MOST_TILES))
	return {"areas": areas, "trees": _trees(areas, frame.key, district, most)}


static func _order(kind: String) -> int:
	return ["green", "pitch", "wood"].find(kind)


## Trees: scattered in the green and the woods, the same for everyone in the tile (dice seeded by the tile and the area),
## off the streets and out of the buildings.
static func _trees(areas: Array, dice: String, district: Dictionary, most := MOST_TREES) -> PackedVector2Array:
	var roads := {}  # grid cell -> [{a, b, clear}]: each street's stretches, in every cell they come near
	for r in district.get("roads", []):
		var pts := _flat_pts(r.pts)
		var clear := float(r.w) * 0.5 + KERB_CLEAR
		for k in pts.size() - 1:
			var seg := {"a": pts[k], "b": pts[k + 1], "clear": clear}
			for c in _cells(Rect2(pts[k], Vector2.ZERO).expand(pts[k + 1]).grow(clear)):
				if not roads.has(c):
					roads[c] = []
				roads[c].append(seg)
	var walls := {}  # grid cell -> [{poly, box}]
	for b in district.get("buildings", []):
		var poly := _flat_pts(b.poly)
		var wall := {"poly": poly, "box": _box(poly)}
		for c in _cells(wall.box):
			if not walls.has(c):
				walls[c] = []
			walls[c].append(wall)
	var out := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	for i in areas.size():
		var a: Dictionary = areas[i]
		if not TREE_EVERY.has(a.kind):
			continue
		var poly: PackedVector2Array = a.poly
		var box := _box(poly)
		var n := mini(int(absf(_area(poly)) / float(TREE_EVERY[a.kind])), most - out.size())
		rng.seed = hash("%s/%d" % [dice, i])
		var tries := n * 3
		while n > 0 and tries > 0:
			tries -= 1
			var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			var c := _cell(p)
			if not Geometry2D.is_point_in_polygon(p, poly) or _on_street(p, roads.get(c, [])) or _in_building(p, walls.get(c, [])):
				continue
			out.append(p)
			n -= 1
	return out


const CELL := 40.0  # metres: the grid the streets and buildings are bucketed in, for the trees


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func _cells(r: Rect2) -> Array:
	var out := []
	var lo := _cell(r.position)
	var hi := _cell(r.end)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			out.append(Vector2i(x, y))
	return out


static func _on_street(p: Vector2, segs: Array) -> bool:
	for s in segs:
		if Geometry2D.get_closest_point_to_segment(p, s.a, s.b).distance_to(p) < s.clear:
			return true
	return false


static func _in_building(p: Vector2, walls: Array) -> bool:
	for w in walls:
		if (w.box as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, w.poly):
			return true
	return false


## A relation's outer ways joined end to end into closed rings (a chain that doesn't close, cut off by the box, is dropped).
## (Also OsmWater's.)
static func rings(members: Array, frame: MapFrame) -> Array:
	var chains: Array = []
	for m in members:
		if m.get("type", "") != "way" or m.get("role", "outer") == "inner":
			continue
		var pts := points(m.get("geometry", []), frame)
		if pts.size() >= 2:
			chains.append(pts)
	var closed: Array = []
	while not chains.is_empty():
		var ring: PackedVector2Array = chains.pop_back()
		var grew := true
		while grew and ring[0].distance_to(ring[ring.size() - 1]) > JOIN:
			grew = false
			for k in chains.size():
				var c: PackedVector2Array = chains[k]
				var tail := ring[ring.size() - 1]
				if c[0].distance_to(tail) <= JOIN:
					ring.append_array(c.slice(1))
				elif c[c.size() - 1].distance_to(tail) <= JOIN:
					var r := c.duplicate()
					r.reverse()
					ring.append_array(r.slice(1))
				else:
					continue
				chains.remove_at(k)
				grew = true
				break
		if ring.size() >= 4 and ring[0].distance_to(ring[ring.size() - 1]) <= JOIN:
			closed.append(ring.slice(0, ring.size() - 1))
	return closed


## A way's points in the frame's metres (a point the server left out, outside the box, is skipped). (Also OsmWater's.)
static func points(geom: Array, frame: MapFrame) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in geom:
		if p is Dictionary and p.has("lat"):
			out.append(frame.local(float(p.lat), float(p.lon)))
	return out


static func _flat_pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(0, flat.size() - 1, 2):
		out.append(Vector2(flat[k], flat[k + 1]))
	return out


static func _box(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5
