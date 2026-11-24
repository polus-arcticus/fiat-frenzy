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
var bins := {}  # the map's bins the town's run on, by kind ({kind: [{at, front}]}: SiteFinder.bins); a kind left out is the atom's
var market := Vector2.ZERO
var landform: Landform  # the shape of the tile's land (TileSource.landform): its sites keep off the slopes, its walkers climb


## `district` is the tile's map (OsmImport.tile of the tile that holds lat, lon); `land` the shape of its land (none: flat, as
## the headless tests have it).
func _init(tile_key: String, map: Dictionary, at_lat: float, at_lon: float, land: Landform = null) -> void:
	key = tile_key
	district = map
	lat = at_lat
	lon = at_lon
	landform = land if land != null else Landform.new()
	site = SiteFinder.pick(district, key, landform)
	market = Cluster.spot(site, 0.0, "kerb", 0.6)


func build() -> World:
	var w := World.new()
	w.landform = landform
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
	_place_bins(w)
	var taken: Array[Vector2] = []  # (the camp keeps clear of the atom, and of its tent row as far as it can grow)
	for list in [w.machines, w.hospitals, w.bottle_depots, w.fires, w.bins]:
		for o in list:
			taken.append(o.pos)
	for m in w.machines:
		if m.residence != null:
			for i in Catalog.machine("hostel").cap + 1:
				taken.append(m.residence.bed_pos(m, i))
			for off in m.residence.stall_offsets:  # (and where its first arrivals will pitch their stalls: Lodging.FOUNDERS)
				taken.append(m.pos + Vector2(-m.front.y, m.front.x) * m.residence.wing * float(off))
	camp = SiteFinder.camp(district, key, market, func(at: Vector2) -> float: return walked(w, market, at), taken, landform)
	if not camp.is_empty():  # the park nearest the market has a homeless camp, with its own fire: its keeper lives by it
		w.build_zone = key
		Camp.pitch(w, camp.at, camp.toward, Camp.KEEPER_WALLET, "scrap_camp", "Camp keeper", true)
	for m in w.machines:
		facing[m] = _yaw(m.front)
	for list in [w.hospitals, w.bottle_depots]:
		for o in list:
			facing[o] = _yaw(o.front)
	start = _landing_spot(w)
	var way := w.nav.path(key, start, market)  # (face the way there, not the market through a building)
	var to := (way[0] if not way.is_empty() else market) - start
	start_yaw = atan2(-to.x, -to.y)
	return w


## The tile's bins are its real ones, of each kind that has any near the market (SiteFinder.bins: its waste baskets, recycling
## containers, organics bins and drinking fountains): the atom's own bin of that kind is taken away and one is put at each,
## sharing its rate (so the town has as much of everything as ever). A kind the map has none of near enough keeps the atom's.
func _place_bins(w: World) -> void:
	bins = SiteFinder.bins(district, key, market, func(at: Vector2) -> float: return walked(w, market, at))
	w.build_zone = key
	for kind in bins:
		var found: Array = bins[kind]
		for b in w.bins.filter(func(b): return b.zone == key and b.kind == kind):
			w.bins.erase(b)
		for f in found:
			var b := w.add_bin(kind, f.at)
			b.front = f.front
			b.rate = float(WasteBin.KINDS[kind].rate) / found.size()
			b.output.take(b.item, b.output.count(b.item) - int(WasteBin.KINDS[kind].start) / found.size())  # (and its start)
			b.refresh()
			b.source = "map"
	w.zones.invalidate()


## Metres on foot from `a` to `b` along the town's streets (RoadGraph.route), the way its people go: on a hill, the metres on
## the flat it takes (Walking.effort), so a camp up a slope is as far off as it feels.
static func walked(w: World, a: Vector2, b: Vector2) -> float:
	var points: Array = [a]
	points.append_array(Array(w.roads.route(a, b)))
	return w.walking.effort(points)


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
		if m.kind in ["scrap_camp", "bike_camp", "thrift_stall", "clothing_shop"]:
			marks.append({"pos": m.pos, "label": "camp" if m.kind.ends_with("camp") else "stall", "color": Color(0.45, 0.6, 0.35)})
	return marks


func title() -> String:
	var street := str(site.get("street", ""))
	return "Tile %s%s" % [key, "  ·  the market on " + street if street != "" else ""]


func spec() -> Dictionary:
	return {"kind": "tile", "key": key, "lat": lat, "lon": lon}


static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)
