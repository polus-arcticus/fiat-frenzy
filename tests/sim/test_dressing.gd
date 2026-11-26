## Sim tests: a tile's dressing (OsmDressing, DressingBuilder) and how the game asks OpenStreetMap for things (Backoff,
## TileSource's layers). A made-up answer in the tile's own coordinates stands in for the server.
extends TestCase


# A made-up Overpass answer for the fixture tile: a park with a building and a street through it, a pond, a lake as a
# relation of two half-ways, a river across the tile, and something that isn't dressing.
func _answer() -> Dictionary:
	var r := TileKey.rect(Fixtures.tile_key())
	var at := func(fx: float, fy: float) -> Dictionary:
		var ll: Array = TileKey.lat_lon(r.position + r.size * Vector2(fx, fy), TileKey.region_of(Fixtures.tile_key()))
		return {"lat": ll[0], "lon": ll[1]}
	var ring := func(pts: Array) -> Array:
		var out := pts.map(func(p): return at.call(p[0], p[1]))
		out.append(out[0])
		return out
	return {"elements": [
		{"type": "way", "id": 1, "tags": {"leisure": "park"}, "geometry": ring.call([[0.1, 0.1], [0.5, 0.1], [0.5, 0.5], [0.1, 0.5]])},
		{"type": "way", "id": 2, "tags": {"natural": "water"}, "geometry": ring.call([[0.6, 0.6], [0.7, 0.6], [0.7, 0.7]])},
		{"type": "relation", "id": 3, "tags": {"natural": "water", "type": "multipolygon"}, "members": [
			{"type": "way", "role": "outer", "geometry": [at.call(0.8, 0.1), at.call(0.9, 0.1), at.call(0.9, 0.2)]},
			{"type": "way", "role": "outer", "geometry": [at.call(0.8, 0.1), at.call(0.8, 0.2), at.call(0.9, 0.2)]},
		]},
		{"type": "way", "id": 4, "tags": {"waterway": "river", "width": "30"}, "geometry": [at.call(-0.5, 0.95), at.call(1.5, 0.95)]},
		{"type": "way", "id": 5, "tags": {"leisure": "park"}, "geometry": ring.call([[-0.4, 0.3], [0.05, 0.3], [0.05, 0.4], [-0.4, 0.4]])},
		{"type": "way", "id": 6, "tags": {"amenity": "bench"}, "geometry": [at.call(0.3, 0.3)]},
	]}


func _district() -> Dictionary:
	var r := TileKey.rect(Fixtures.tile_key())
	var p := func(fx: float, fy: float) -> Vector2: return r.position + r.size * Vector2(fx, fy)
	var a: Vector2 = p.call(0.2, 0.2)
	var b: Vector2 = p.call(0.3, 0.3)
	var s: Vector2 = p.call(0.0, 0.42)
	var e: Vector2 = p.call(1.0, 0.42)
	return {"buildings": [{"id": 9, "poly": [a.x, a.y, b.x, a.y, b.x, b.y, a.x, b.y]}],
		"roads": [{"w": 8.0, "pts": [s.x, s.y, e.x, e.y]}]}


func test_what_is_dressing() -> void:
	check(OsmDressing.kind_of({"leisure": "park"}) == "green" and OsmDressing.kind_of({"waterway": "riverbank"}) == "", "a park is green; water isn't dressing (it's solid: OsmWater)")
	check(OsmDressing.kind_of({"natural": "wood"}) == "wood" and OsmDressing.kind_of({"leisure": "pitch"}) == "pitch", "a wood, a pitch")
	check(OsmDressing.kind_of({"amenity": "bench"}) == "" and OsmDressing.kind_of({"building": "yes"}) == "", "a bench or a building isn't")


func test_areas_and_the_tile_s_square() -> void:
	var d := OsmDressing.tile(_answer(), Fixtures.tile_key(), _district())
	var r := TileKey.rect(Fixtures.tile_key()).grow(0.01)
	var kinds := {}
	for a in d.areas:
		kinds[a.kind] = kinds.get(a.kind, 0) + 1
	check(kinds == {"green": 2}, "two parks, and none of the water (%s)" % kinds)
	var inside: bool = d.areas.all(func(a): return Array(a.poly).all(func(p): return r.has_point(p)))
	check(inside, "every area is cut to the tile's square (the park over its edge too)")
	check(not d.has("rivers"), "no rivers: they're solid, OsmWater's")


func test_trees_are_the_same_for_everyone_and_keep_out_of_the_way() -> void:
	var a := OsmDressing.tile(_answer(), Fixtures.tile_key(), _district())
	var b := OsmDressing.tile(_answer(), Fixtures.tile_key(), _district())
	check(a.trees.size() > 20 and a.trees == b.trees, "%d trees, in the same places every time" % a.trees.size())
	var bd: Dictionary = _district().buildings[0]
	var poly := PackedVector2Array([Vector2(bd.poly[0], bd.poly[1]), Vector2(bd.poly[2], bd.poly[3]), Vector2(bd.poly[4], bd.poly[5]), Vector2(bd.poly[6], bd.poly[7])])
	check(not Array(a.trees).any(func(p): return Geometry2D.is_point_in_polygon(p, poly)), "none in the building in the park")
	var road: Array = _district().roads[0].pts
	var clear: bool = Array(a.trees).all(func(p): return absf(p.y - road[1]) >= 4.0 + OsmDressing.KERB_CLEAR - 0.01)
	check(clear, "none on the street through it")


func test_the_dressing_bakes() -> void:
	var baked := DressingBuilder.bake(OsmDressing.tile(_answer(), Fixtures.tile_key(), _district()), Fixtures.tile_key())
	var dress := OsmDressing.tile(_answer(), Fixtures.tile_key(), _district())
	check((baked.ground as CityBuilder.Buf).i.size() > 0 and DressingBuilder.tree_count(baked) == dress.trees.size(), "ground triangles and a tree for each place")
	check(baked.trees.size() >= 5 and baked.trees.keys().all(func(c): return c in Solids.NAMES), "their crowns all sorts of solids (%s)" % ", ".join(baked.trees.keys()))
	var again := DressingBuilder.bake(dress, Fixtures.tile_key())
	check(baked.trees.keys().all(func(c): return (again.trees[c] as Array).size() == (baked.trees[c] as Array).size()), "the same crown on the same tree every time")


func test_the_solids() -> void:
	var want := {"tetrahedron": [4, 4], "cube": [8, 6], "octahedron": [6, 8], "dodecahedron": [20, 12], "icosahedron": [12, 20],
		"cuboctahedron": [12, 14], "icosidodecahedron": [30, 32]}
	for name in want:
		check(Solids.vertices(name).size() == want[name][0] and Solids.faces(name).size() == want[name][1], "a %s: %d corners, %d faces" % [name, want[name][0], want[name][1]])
	var sides := Solids.faces("icosidodecahedron").map(func(f): return f.size())
	check(sides.count(3) == 20 and sides.count(5) == 12, "the icosidodecahedron's faces: 20 triangles and 12 pentagons")
	var flat := Solids.faces("dodecahedron").all(func(f): return f.all(func(p): return absf((p as Vector3).length() - 1.0) < 1e-4))
	check(flat, "every corner on the unit sphere")


func test_the_backoff() -> void:
	check(is_equal_approx(Backoff.delay(1), Backoff.FIRST) and is_equal_approx(Backoff.delay(3), Backoff.FIRST * 4.0), "2 s, then twice as long each time")
	check(is_equal_approx(Backoff.delay(20), Backoff.MOST), "never longer than a minute")
	check(Backoff.delay(1, 0.0, 0.0) < Backoff.FIRST and Backoff.delay(1, 0.0, 1.0) > Backoff.FIRST, "with jitter, so players don't come back in step")
	check(is_equal_approx(Backoff.delay(1, 30.0), 30.0), "the server's Retry-After is honoured")
	check(Backoff.retry_after(PackedStringArray(["Content-Type: x", "Retry-After: 12"])) == 12.0, "and read from its headers")
	var ok := HTTPRequest.RESULT_SUCCESS
	check(Backoff.retryable(ok, 429) and Backoff.retryable(ok, 504) and Backoff.retryable(HTTPRequest.RESULT_TIMEOUT, 0), "busy, gateway down, timed out: ask again")
	check(not Backoff.retryable(ok, 400) and not Backoff.retryable(ok, 404), "a bad request: don't")


func test_the_two_layers_asked_for() -> void:
	var key := Fixtures.tile_key()
	var base := TileSource.query(key)
	var land := TileSource.query(key, "land")
	check(base.contains("building") and not base.contains("leisure") and not base.contains("waterway"), "the tile: buildings and streets, nothing else")
	check(land.contains("riverbank") and land.contains("waterway") and land.contains("leisure") and not land.contains("building"), "the land: water and green")
	check(land.contains("out geom(") and land.ends_with("out geom;"), "its areas cut to the box, its waterways' centre lines whole")
	check(not land.contains("\"natural\"=\"tree\"") and land.contains("node[\"highway\"") and land.contains("recycling"), "the street's furniture as points, and no single trees asked for")
	check(land.contains("light_rail") and land.contains("\"railway\"") and land.contains("station|halt"), "the railway's tracks and stations (OsmRail)")
	check(TileSource.BEFORE_LANDING == ["osm", "land"], "both before landing: two requests a tile, ever")
	check(TileSource.path(key, "user://x", "land").ends_with(".land%d.json" % TileSource.VERSIONS.land), "each kept in a file of its own, the land's by the version of its query")
