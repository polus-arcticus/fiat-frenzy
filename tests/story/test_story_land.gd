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


func test_slow_the_storys_two_markets_keep_their_people_up() -> void:
	var sc := Fixtures.scenario()
	var w := sc.build()
	w.add_player(sc.start, 25.0)
	w.player.make_needless()
	w.passersby.gates.clear()  # (the town's balance is measured by itself: passersby only add to what it sells)
	Atom.grow(w, sc.market)
	for pair in [[Zones.HOME, sc.start], [Scenario.ECB_ZONE, sc.ecb_market.pos]]:
		Cluster.fund(w, pair[0])
		w.player.pos = pair[1]
		var downs := 0
		for i in int(Clock.DAY_SECONDS) * 3:
			w.tick(1.0)
			if i % 60 == 0:
				downs += w.zones.drones_in(pair[0]).filter(func(d): return d.care != "").size()
		check(downs == 0, "funded, nobody of the %s market goes down in three days (%d sightings)" % [pair[0], downs])


func test_tram_11_waits_at_both_ends_of_the_story() -> void:
	var d := Fixtures.district()
	var off := 0.0
	var checked := 0
	for r in d.routes:
		for k in range(0, r.pts.size() - 1, 20):
			var p := Vector2(r.pts[k], r.pts[k + 1])
			var near := INF
			for t in d.rail.tracks:
				for i in t.pts.size() - 1:
					near = minf(near, Geometry2D.get_closest_point_to_segment(p, t.pts[i], t.pts[i + 1]).distance_to(p))
			off = maxf(off, near)
			checked += 1
	check(d.routes.size() == 2 and d.routes.all(func(r): return r.ref == "11" and r.colour == Scenario.TRAM_COLOUR), "the line both ways, in its colour")
	check(checked > 10 and off < 1.0, "its band lies along the mapped tracks (%d places, %.2f m off at worst)" % [checked, off])
	var w := Fixtures.scenario().build()
	for called in ["tram_east", "tram_west"]:
		var tram := w.transit.vehicle(called)
		var way := tram.line.stops.map(func(s): return s.name)
		check(tram.kind == "tram" and tram.line.number == "11" and way.size() == 14 and way[tram.stop] == Scenario.TRAM_WAITS[called], "%s waits at %s (%d stops)" % [called, way[tram.stop], way.size()])
	var east := w.transit.vehicle("tram_east")
	var names: Array = east.line.stops.map(func(s): return s.name)
	check(names.find("Römer/Paulskirche") > east.stop and names.find("Börneplatz") > names.find("Römer/Paulskirche") and names.find("Ostbahnhof/Sonnemannstraße") > names.find("Börneplatz"),
		"from the station past the Paulskirche and Börneplatz to the bank's stop")
	w.add_player(east.pos, 0.0)
	var streets := w.transit.ride(east)
	var stray := 0.0
	for p in east.path.pts:
		stray = maxf(stray, p.distance_to(east.line.pos_at(east.line._project(p).s)))
	check(streets and stray < 2.0, "and it drives its own track there (%.2f m off at worst)" % stray)


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


func test_the_story_town_has_its_fire_and_a_warm_bank() -> void:
	var sc := Fixtures.scenario()
	var town := sc.build()
	var lift: Vector2 = sc.lift.centre
	check(town.heating.is_warm(lift) and town.heating.is_warm((sc.ecb.door as Vector2) - (sc.ecb.out as Vector2) * 3.0), "the bank is warm inside: upstairs by the lift, and in the hall")
	var home := town.fires.filter(func(f): return f.zone == Zones.HOME)
	check(home.size() == 1 and home[0].pos.distance_to(sc.market.pos) < 20.0, "and the first market has its atom's barrel fire, by the tent city (the street's own fires went with the hand-made market)")
