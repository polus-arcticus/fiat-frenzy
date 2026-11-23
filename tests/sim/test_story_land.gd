## Sim tests: the story's Frankfurt has its land like any tile (Scenario.load_district: water, green and trees, street furniture,
## from data/raw/story_land.json, fetched once by tools/story_land.gd), brought into the district's own metres (MapFrame).
extends TestCase


func test_a_frame_round_trips_and_a_tile_frame_is_the_tiles() -> void:
	var d := Fixtures.district()
	var f := MapFrame.of_district(d, "story")
	check(f.local(float(d.origin.lat), float(d.origin.lon)).length() < 0.001, "the story's frame is centred on the district's origin")
	var p := Vector2(1234.5, -678.9)
	var ll := f.lat_lon(p)
	check(f.local(ll[0], ll[1]).distance_to(p) < 0.01, "and a point goes to the planet and back to within a centimetre")
	var t := MapFrame.tile(Fixtures.tile_key())
	var region := TileKey.region_of(Fixtures.tile_key())
	check(t.local(50.11, 8.67) == TileKey.local(50.11, 8.67, region) and t.rect == TileKey.rect(Fixtures.tile_key()), "a tile's frame is the tile's region metres and its square, as before")


func test_the_story_has_its_green_and_trees() -> void:
	var d := Fixtures.district()
	var green: Dictionary = d.get("green", {})
	check(not green.is_empty() and green.areas.any(func(a): return a.kind == "green") and green.areas.any(func(a): return a.kind == "wood"), "parks and woods: %d areas" % green.get("areas", []).size())
	var trees: PackedVector2Array = green.get("trees", PackedVector2Array())
	check(trees.size() > 1000, "and %d trees in them" % trees.size())
	var walls: Array = d.buildings.map(func(b): return MapSites.pts(b.poly))
	var inside := 0
	for k in range(0, trees.size(), 25):
		if walls.any(func(w): return Geometry2D.is_point_in_polygon(trees[k], w)):
			inside += 1
	check(inside == 0, "none of them in a building")
	var again := Scenario.load_district()
	check(again.green.trees == trees, "the same trees every time, for everyone")
	var kinds := {}
	for pt in d.street.points:
		kinds[pt.kind] = true
	check(kinds.has("lamp") and kinds.has("bench") and kinds.has("bus_stop") and kinds.has("recycling"), "and its street furniture from the map: %s" % [kinds.keys()])


func test_the_main_is_solid_and_where_it_should_be() -> void:
	var d := Fixtures.district()
	var pieces: Array = d.get("water", {}).get("pieces", [])
	check(not pieces.is_empty(), "the Main is in it (%d pieces)" % pieces.size())
	var sc := Fixtures.scenario()
	var near := INF
	for piece in pieces:
		for q in piece:
			near = minf(near, (q as Vector2).distance_to(sc.ecb.door))
	check(near < 300.0, "beside the European Central Bank, which stands on its bank (%.0f m from the door): the land is in the buildings' metres" % near)
	var w := sc.build()
	var biggest: PackedVector2Array = pieces[0]
	for piece in pieces:
		if piece.size() > biggest.size():
			biggest = piece
	var wet := Vector2.ZERO
	var tries := 0
	var box := Rect2(biggest[0], Vector2.ZERO)
	for q in biggest:
		box = box.expand(q)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while tries < 500:
		tries += 1
		wet = Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if OsmWater.wet(d.water, wet):
			break
	check(OsmWater.wet(d.water, wet) and w.nav.unreachable("district", wet), "nobody can walk into it (Navigation)")
	var things: Array = w.machines + w.bins + w.hospitals + w.bottle_depots + w.fires
	check(things.all(func(o): return not OsmWater.wet(d.water, o.pos)) and w.drones.all(func(x): return not OsmWater.wet(d.water, x.pos)), "nothing and nobody of the story stands in it")
	check(Array(sc.ecb_gate.route).all(func(q): return not OsmWater.wet(d.water, q)), "nor does the shuttle drive through it")
	check(not w.parks.is_empty() and not w.in_park(sc.start), "the parks are the town's (cold for the hero), and the hero doesn't start in one")
