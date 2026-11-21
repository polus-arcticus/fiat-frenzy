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
	Atom.seed(w, key, site.point, site)
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
	return marks


func title() -> String:
	var street := str(site.get("street", ""))
	return "Tile %s%s" % [key, "  ·  the market on " + street if street != "" else ""]


func spec() -> Dictionary:
	return {"kind": "tile", "key": key, "lat": lat, "lon": lon}


static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)
