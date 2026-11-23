## Sim tests: a tile's water (OsmWater): solid, made by one rule (all the water merged, then every street cut out of it), so a
## bridge is a street over the water and gets parapets, and a street along the bank stays a street. And the tile built on it
## (TileLanding): nobody walks into the river, and the market isn't in it. A made-up answer stands in for the server.
extends TestCase


func _f(fx: float, fy: float) -> Vector2:
	var r := TileKey.rect(Fixtures.tile_key())
	return r.position + r.size * Vector2(fx, fy)


# A made-up Overpass answer: a river across the tile (60 m wide), a pond, a lake as a relation of two half-ways, and a stream
# in a culvert.
func _answer() -> Dictionary:
	var region := TileKey.region_of(Fixtures.tile_key())
	var at := func(fx: float, fy: float) -> Dictionary:
		var ll: Array = TileKey.lat_lon(_f(fx, fy), region)
		return {"lat": ll[0], "lon": ll[1]}
	var ring := func(pts: Array) -> Array:
		var out := pts.map(func(p): return at.call(p[0], p[1]))
		out.append(out[0])
		return out
	return {"elements": [
		{"type": "way", "id": 1, "tags": {"waterway": "river", "width": "60"}, "geometry": [at.call(-1.0, 0.75), at.call(2.0, 0.75)]},
		{"type": "way", "id": 2, "tags": {"natural": "water"}, "geometry": ring.call([[0.1, 0.1], [0.2, 0.1], [0.2, 0.2], [0.1, 0.2]])},
		{"type": "relation", "id": 3, "tags": {"natural": "water", "type": "multipolygon"}, "members": [
			{"type": "way", "role": "outer", "geometry": [at.call(0.8, 0.1), at.call(0.9, 0.1), at.call(0.9, 0.2)]},
			{"type": "way", "role": "outer", "geometry": [at.call(0.8, 0.1), at.call(0.8, 0.2), at.call(0.9, 0.2)]},
		]},
		{"type": "way", "id": 4, "tags": {"waterway": "stream", "tunnel": "culvert"}, "geometry": [at.call(0.0, 0.35), at.call(1.0, 0.35)]},
	]}


# A bridge across the river (north-south through the middle), a street along its north bank where the river's band reaches
# over it.
func _district() -> Dictionary:
	var n := _f(0.5, 0.45)
	var s := _f(0.5, 1.05)
	var w := _f(-0.1, 0.68)
	var e := _f(1.1, 0.68)
	return {"buildings": [], "roads": [
		{"class": "secondary", "w": 10.0, "bridge": true, "pts": [n.x, n.y, s.x, s.y]},
		{"class": "residential", "w": 8.0, "pts": [w.x, w.y, e.x, e.y]},
	]}


func test_the_water_is_where_it_is_and_the_streets_go_through() -> void:
	var water := OsmWater.tile(_answer(), Fixtures.tile_key(), _district())
	check(OsmWater.wet(water, _f(0.25, 0.8)) and OsmWater.wet(water, _f(0.75, 0.8)), "the river, either side of the bridge")
	check(not OsmWater.wet(water, _f(0.5, 0.78)), "the bridge is a street over it: dry")
	check(not OsmWater.wet(water, _f(0.25, 0.68)), "the street along the bank stays a street, though the river's band reaches over it")
	check(OsmWater.wet(water, _f(0.15, 0.15)) and OsmWater.wet(water, _f(0.85, 0.12)), "a pond, and a lake joined from its two halves")
	check(not OsmWater.wet(water, _f(0.3, 0.35)), "a stream in a culvert is underground")
	var size := TileKey.rect(Fixtures.tile_key()).size.x
	check(OsmWater.wet(water, _f(1.0, 0.8) + Vector2(OsmWater.REACH * 0.5, 0)), "it carries on past the tile's edge, as far as its streets do")
	check(not OsmWater.wet(water, _f(1.0, 0.8) + Vector2(OsmWater.REACH + 5.0, 0)), "and no further (%.0f m)" % OsmWater.REACH)
	check(is_equal_approx(OsmWater.width_of({"waterway": "canal"}), 16.0) and OsmWater.width_of({"waterway": "river", "width": "85 m"}) == 85.0, "a waterway as wide as it's tagged, or its kind (size %.0f)" % size)


func test_quays_along_the_banks_and_parapets_along_the_bridge() -> void:
	var water := OsmWater.tile(_answer(), Fixtures.tile_key(), _district())
	var bridge_x := _f(0.5, 0.0).x
	var half := 5.0 + OsmWater.STREET_CUT
	var parapets: Array = water.edges.filter(func(e): return absf(absf((e.a.x + e.b.x) * 0.5 - bridge_x) - half) < 0.2 and absf(e.a.x - e.b.x) < 0.2)
	check(parapets.size() >= 2, "a parapet down each side of the bridge, where it's over the water (%d)" % parapets.size())
	var bank: Array = water.edges.filter(func(e): return absf(e.a.y - e.b.y) < 0.2 and absf((e.a.y + e.b.y) * 0.5 - (_f(0.0, 0.68).y + 4.0 + OsmWater.STREET_CUT)) < 0.3)
	check(not bank.is_empty(), "a quay along the street on the bank")
	var reach := TileKey.rect(Fixtures.tile_key()).grow(OsmWater.REACH)
	var on_rim: Array = water.edges.filter(func(e):
		var m: Vector2 = (e.a + e.b) * 0.5
		return absf(m.x - reach.position.x) < 0.1 or absf(m.x - reach.end.x) < 0.1)
	check(on_rim.is_empty(), "none where the river carries on out of the square")


func test_on_a_tile_nobody_walks_into_the_river() -> void:
	var district := Fixtures.tile_district()
	var region := TileKey.region_of(Fixtures.tile_key())
	var ll: Array = TileKey.lat_lon(_f(0.5, 0.92), region)
	var river := {"elements": [{"type": "way", "id": 1, "tags": {"waterway": "river", "width": "50"}, "geometry": [
		{"lat": ll[0], "lon": TileKey.lat_lon(_f(-0.5, 0.92), region)[1]}, {"lat": ll[0], "lon": TileKey.lat_lon(_f(1.5, 0.92), region)[1]}]}]}
	district["water"] = OsmWater.tile(river, Fixtures.tile_key(), district)
	var landing := TileLanding.new(Fixtures.tile_key(), district, Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var w := landing.build()
	var wet := _f(0.5, 0.92)
	for k in 20:  # (a point in the river away from any street)
		if OsmWater.wet(district.water, wet):
			break
		wet += Vector2(13.0, 0.0)
	check(OsmWater.wet(district.water, wet) and w.nav.unreachable(Fixtures.tile_key(), wet), "the river is solid to the town: nobody can stand in it (Navigation)")
	var things: Array = w.machines + w.bins + w.hospitals + w.bottle_depots + w.fires
	check(things.all(func(o): return not OsmWater.wet(district.water, o.pos)), "nothing of the atom stands in it")
	check(not OsmWater.wet(district.water, landing.start), "nor does the hero land in it")
