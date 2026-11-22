## A landing anywhere on the planet: the tile that holds the coordinates the player chose (TileKey), its map from OpenStreetMap
## (OsmImport), and the tile's atom on the street SiteFinder picks for it. The tile and its atom are the same for everyone who
## lands in it (so their saves can be merged); only where the hero sets foot is their own: the street nearest the point they
## chose. No story: no cast, quests or opening crash; the money gun is in hand from the start.
class_name TileLanding
extends Landing

const STARTS_AT := 1.0 / 24.0  # of a day: 07:00 (the clock's day begins at 06:00)
## What the hero brings: a little food and drink (Commerce.START_KIT) and a barrel fire to put down if the market is far off,
## for the cold bites (see Cold).
const KIT := {"barrel_fire": 1}
const STREET_POINTS := 8.0  # metres between the street graph's points (RoadGraph.add_polyline)
const MARKET_REACH := 45.0  # metres within which the town walks straight (RoadGraph.shortcut): the atom's layout, end to end

var key := ""        # the tile, "16/x/y"
var lat := 0.0       # where the player chose to land
var lon := 0.0
var site := {}       # where the atom stands (SiteFinder.pick)
var camp := {}       # where its park's camp is ({at, toward}: SiteFinder.camp), {} if it has no park
var recycling: Array = []  # the recycling containers its scrap gathers at ([{at, front}]: SiteFinder.recycling), or []
var market := Vector2.ZERO


## `district` is the tile's map (OsmImport.tile of the tile that holds lat, lon).
func _init(tile_key: String, map: Dictionary, at_lat: float, at_lon: float) -> void:
	key = tile_key
	district = map
	lat = at_lat
	lon = at_lon
	site = SiteFinder.pick(district, key)
	market = Cluster.spot(site, 0.0, "kerb", 0.6)


func build() -> World:
	var w := World.new()
	w.roads = RoadGraph.new()
	w.roads.shortcut = MARKET_REACH
	for r in district.roads:
		w.roads.add_polyline(MapSites.pts(r.pts), STREET_POINTS)
	w.zones.add_tile(key)
	w.clock.time = STARTS_AT * Clock.DAY_SECONDS
	for b in district.buildings:
		w.nav.add_static(key, MapSites.pts(b.poly))  # (nobody walks through walls)
	for piece in district.get("water", {}).get("pieces", []):
		w.nav.add_static(key, piece)  # (nor into the river: over the bridges, which are streets cut out of it: OsmWater)
	for area in district.get("green", {}).get("areas", []):
		if area.kind == "green":
			w.parks.append(area.poly)
	Atom.seed(w, key, site.point, site)
	_recycle(w)
	var taken: Array[Vector2] = []  # (the camp keeps clear of the atom, and of its tent row as far as it can grow)
	for list in [w.machines, w.food_banks, w.hospitals, w.welfare_offices, w.fires, w.scrap_piles]:
		for o in list:
			taken.append(o.pos)
	for m in w.machines:
		if m.shelter != null:
			for i in Catalog.machine("hostel").cap + 1:
				taken.append(m.bed_pos(i))
	camp = SiteFinder.camp(district, key, market, func(at: Vector2) -> float: return walked(w, market, at), taken)
	if not camp.is_empty():  # the park nearest the market has a homeless camp, with its own fire: its keeper lives by it
		w.build_zone = key
		Camp.pitch(w, camp.at, camp.toward, Camp.KEEPER_WALLET, "scrap_camp", "Camp keeper", true)
	for m in w.machines:
		facing[m] = _yaw(m.front)
	for list in [w.food_banks, w.hospitals, w.welfare_offices]:
		for o in list:
			facing[o] = _yaw(o.front)
	start = _landing_spot(w)
	var way := w.nav.path(key, start, market)  # (face the way there, not the market through a building)
	var to := (way[0] if not way.is_empty() else market) - start
	start_yaw = atan2(-to.x, -to.y)
	return w


## The tile's scrap gathers at its real recycling containers, if any are near the market (SiteFinder.recycling): the atom's
## made-up pile is taken away and one is laid at each, sharing its rate (so the town has as much scrap as ever).
func _recycle(w: World) -> void:
	var bins := SiteFinder.recycling(district, key, market, func(at: Vector2) -> float: return walked(w, market, at))
	if bins.is_empty():
		return
	var made: Array = w.scrap_piles.filter(func(p): return p.zone == key)
	for p in made:
		w.scrap_piles.erase(p)
	w.build_zone = key
	for b in bins:
		var pile := w.add_scrap_pile(b.at)
		pile.front = b.front
		pile.rate = ScrapPile.RATE / bins.size()
		pile.source = "recycling"
	recycling = bins


## Metres on foot from `a` to `b` along the town's streets (RoadGraph.route), the way its people go.
static func walked(w: World, a: Vector2, b: Vector2) -> float:
	var length := 0.0
	var prev := a
	for p in w.roads.route(a, b):
		length += prev.distance_to(p)
		prev = p
	return length


## Where the hero sets foot: on the street nearest the point the player chose (not in a building, not on a stall).
func _landing_spot(_w: World) -> Vector2:
	var chosen := TileKey.local(lat, lon, TileKey.region_of(key))
	var best := Vector2(INF, INF)
	for r in district.roads:
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(chosen, pts[k], pts[k + 1])
			if c.distance_to(chosen) < best.distance_to(chosen):
				best = c
	if not best.is_finite() or best.distance_to(chosen) > 80.0:
		best = market - (site.out as Vector2) * float(site.width)  # (no street near: across from the market)
	return best


func landmarks(w: World) -> Array:
	var marks: Array = [{"pos": market, "label": "market", "color": Color(0.9, 0.7, 0.25)}]
	for m in w.machines:
		if m.shelter != null:
			marks.append({"pos": m.pos, "label": "tent city", "color": Color(0.45, 0.35, 0.6)})
	for h in w.hospitals:
		marks.append({"pos": h.pos, "label": "first aid", "color": Color(0.9, 0.25, 0.25)})
	for m in w.machines:
		if m.kind in ["scrap_camp", "bike_camp"]:
			marks.append({"pos": m.pos, "label": "camp", "color": Color(0.45, 0.6, 0.35)})
	return marks


func title() -> String:
	var street := str(site.get("street", ""))
	return "Tile %s%s" % [key, "  ·  the market on " + street if street != "" else ""]


func spec() -> Dictionary:
	return {"kind": "tile", "key": key, "lat": lat, "lon": lon}


static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)
