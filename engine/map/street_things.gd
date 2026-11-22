## A district's street furniture: the small things that make a street read as one, from the map where it has them (points
## and lines from TileSource's "land" layer: `points`), placed where they would stand, and street lamps along the streets
## that are lit where it hasn't mapped each lamp. Only looked at (StreetThingsBuilder), but for what a skateboard or a walker
## bumps into (hedges and walls are solid). Each thing belongs to the tile it stands in, as its buildings do.
##   lamp  bus_stop  tram_stop  stop_sign  give_way  traffic_light  crossing (a zebra across the road)  bike_stand  bench  bin
##   recycling (also the tile's scrap: SiteFinder.recycling)        and lines: hedge  wall  fence
class_name StreetThings
extends RefCounted

## The Overpass filters for the points (TileSource asks for nodes of each) and the lines (ways).
const NODES := [
	"[\"highway\"~\"^(street_lamp|bus_stop|stop|give_way|traffic_signals|crossing)$\"]",
	"[\"railway\"=\"tram_stop\"]",
	"[\"amenity\"~\"^(bicycle_parking|bench|waste_basket|recycling)$\"]",
]
const LINES := ["[\"barrier\"~\"^(hedge|wall|fence|retaining_wall)$\"]"]
const LAMP_EVERY := 30.0     # metres between the lamps put up along a lit street
const LAMP_IN := 0.5         # metres in from the kerb a lamp stands
const LAMP_NEAR := 14.0      # a mapped lamp this near takes the place of one put up
const STOP_IN := 1.4         # a bus stop's shelter, in from the kerb
const SIGN_IN := 0.4
const MARKED := ["zebra", "marked", "uncontrolled", "traffic_signals"]  # crossings painted on the road
## The story's map says nothing of lamps: its streets of these kinds are lit.
const LIT_KINDS := ["primary", "secondary", "tertiary", "residential", "pedestrian", "living_street"]


## The points and lines of a raw answer, by kind, in region metres: {points: [{kind, at, tags}], lines: [{kind, pts}]}. (What
## TileSource keeps in the district, as "street".)
static func points(overpass: Dictionary, tile_key: String) -> Dictionary:
	var region := TileKey.region_of(tile_key)
	var pts: Array = []
	var lines: Array = []
	for e in overpass.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if e.get("type", "") == "node" and e.has("lat"):
			var kind := kind_of(tags)
			if kind != "":
				pts.append({"kind": kind, "at": TileKey.local(float(e.lat), float(e.lon), region), "tags": tags})
		elif e.get("type", "") == "way" and tags.has("barrier"):
			var kind: String = {"hedge": "hedge", "wall": "wall", "retaining_wall": "wall", "fence": "fence"}.get(str(tags.barrier), "")
			var line := OsmDressing.points(e.get("geometry", []), region)
			if kind != "" and line.size() >= 2:
				lines.append({"kind": kind, "pts": line})
	return {"points": pts, "lines": lines}


## What a mapped point is ("" if nothing we draw).
static func kind_of(tags: Dictionary) -> String:
	match str(tags.get("highway", "")):
		"street_lamp":
			return "lamp"
		"bus_stop":
			return "bus_stop"
		"stop":
			return "stop_sign"
		"give_way":
			return "give_way"
		"traffic_signals":
			return "traffic_light"
		"crossing":
			return "crossing" if str(tags.get("crossing", "")) in MARKED or str(tags.get("crossing:markings", "no")) not in ["no", ""] else ""
	if str(tags.get("railway", "")) == "tram_stop":
		return "tram_stop"
	match str(tags.get("amenity", "")):
		"bicycle_parking":
			return "bike_stand"
		"bench":
			return "bench"
		"waste_basket":
			return "bin"
		"recycling":
			return "recycling"
	return ""


## Where each thing stands: {things: [{kind, at, yaw, width}], lines: [{kind, pts}]}, those of `tile_key` only ("" for a map
## that isn't a tile: all of it, the story's). `kerbs` (the district's) puts them on the pavement, facing the road.
static func of(district: Dictionary, kerbs: Kerbs, tile_key := "") -> Dictionary:
	var street: Dictionary = district.get("street", {"points": [], "lines": []})
	var owned := TileKey.rect(tile_key) if tile_key != "" else Rect2(-1e7, -1e7, 2e7, 2e7)
	var things: Array = []
	var lamps: Array[Vector2] = []
	for p in street.points:
		var at: Vector2 = p.at
		if not owned.has_point(at):
			continue
		match p.kind:
			"crossing":
				var road := _nearest_road(district, at)
				if not road.is_empty() and road.d < float(road.w):
					things.append({"kind": "crossing", "at": road.c, "yaw": _yaw(road.dir), "width": float(road.w)})
			"stop_sign", "give_way", "traffic_light":
				var e := _nearest_kerb(kerbs, at, 12.0)
				if not e.is_empty():
					things.append({"kind": p.kind, "at": e.c + (e.side as Vector2) * SIGN_IN, "yaw": _yaw(-(e.side as Vector2))})
			"bus_stop", "tram_stop":
				var e := _nearest_kerb(kerbs, at, 15.0)
				if not e.is_empty():
					things.append({"kind": p.kind, "at": e.c + (e.side as Vector2) * STOP_IN, "yaw": _yaw(-(e.side as Vector2))})
			_:
				var e := _nearest_kerb(kerbs, at, 3.0)  # (a lamp or a bench mapped in the road: onto the pavement beside it)
				var spot := at
				var yaw := 0.0
				if not e.is_empty():
					yaw = _yaw(-(e.side as Vector2))
					if kerbs.height_at(at) == 0.0 and _in_road(district, at):
						spot = e.c + (e.side as Vector2) * LAMP_IN
				things.append({"kind": p.kind, "at": spot, "yaw": yaw})
				if p.kind == "lamp":
					lamps.append(spot)
	# lamps along the lit streets, where the map hasn't put its own
	var story := tile_key == ""
	for r in district.get("roads", []):
		if not (r.get("lit", false) or (story and str(r.get("class", "")) in LIT_KINDS)):
			continue
		var pts := MapSites.pts(r.pts)
		var half := float(r.w) * 0.5
		var side := 1.0
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var length := a.distance_to(b)
			if length < 1.0:
				continue
			var dir := (b - a) / length
			var n := Vector2(-dir.y, dir.x)
			var t := LAMP_EVERY * 0.5
			while t < length:
				var at := a + dir * t + n * side * (half + LAMP_IN)
				side = -side
				t += LAMP_EVERY
				if not owned.has_point(at) or (kerbs != null and kerbs.height_at(at) == 0.0 and str(r.get("class", "")) != "pedestrian"):
					continue  # (only on a pavement: not over a junction, not in a building)
				if lamps.any(func(l): return l.distance_to(at) < LAMP_NEAR):
					continue
				lamps.append(at)
				things.append({"kind": "lamp", "at": at, "yaw": _yaw(-n * signf(-side)), "made": true})
	var lines: Array = []
	var square := PackedVector2Array([owned.position, Vector2(owned.end.x, owned.position.y), owned.end, Vector2(owned.position.x, owned.end.y)])
	for l in street.lines:
		for piece in Geometry2D.intersect_polyline_with_polygon(l.pts, square):
			if piece.size() >= 2:
				lines.append({"kind": l.kind, "pts": piece})
	return {"things": things, "lines": lines}


static func _yaw(facing: Vector2) -> float:
	return atan2(-facing.x, -facing.y)


static func _nearest_kerb(kerbs: Kerbs, at: Vector2, radius: float) -> Dictionary:
	if kerbs == null:
		return {}
	var best := {}
	var best_d := INF
	for i in kerbs.edges_near(at, radius):
		var e: Dictionary = kerbs.edges[i]
		var c := Geometry2D.get_closest_point_to_segment(at, e.a, e.b)
		if c.distance_to(at) < best_d:
			best_d = c.distance_to(at)
			best = {"c": c, "side": e.side}
	return best


static func _nearest_road(district: Dictionary, at: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for r in district.get("roads", []):
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(at, pts[k], pts[k + 1])
			if c.distance_to(at) < best_d and pts[k].distance_to(pts[k + 1]) > 0.1:
				best_d = c.distance_to(at)
				best = {"c": c, "d": best_d, "dir": (pts[k + 1] - pts[k]).normalized(), "w": float(r.w)}
	return best


static func _in_road(district: Dictionary, at: Vector2) -> bool:
	var r := _nearest_road(district, at)
	return not r.is_empty() and r.d < float(r.w) * 0.5
