## Sim tests: the street's detail from the map. What OsmImport keeps of how buildings and streets look (roof shapes, colours,
## surfaces, lamps, lanes); the furniture (StreetThings: placed where it would stand, owned by its tile, lamps put up along lit
## streets), kept cheap (StreetThingsBuilder); cobbles slowing a board (Kerbs.rough_at, Skating.ROUGH); and the tile's scrap
## gathering at its real recycling containers (SiteFinder.recycling, TileLanding).
extends TestCase


func _f(fx: float, fy: float) -> Vector2:
	var r := TileKey.rect(Fixtures.tile_key())
	return r.position + r.size * Vector2(fx, fy)


# A street east-west across the middle of the fixture tile, lit, cobbled, with lanes, and a side street north-south; and the
# map's points on and beside them.
func _district() -> Dictionary:
	var w := _f(0.0, 0.5)
	var e := _f(1.0, 0.5)
	var n := _f(0.5, 0.2)
	var s := _f(0.5, 0.5)
	var points := [
		{"kind": "crossing", "at": _f(0.3, 0.5), "tags": {}},
		{"kind": "bus_stop", "at": _f(0.7, 0.5) + Vector2(0, 2), "tags": {}},
		{"kind": "stop_sign", "at": s + Vector2(0, -6), "tags": {}},
		{"kind": "bench", "at": _f(0.2, 0.5) + Vector2(0, 7), "tags": {}},
		{"kind": "lamp", "at": _f(0.8, 0.5) + Vector2(0, 6.5), "tags": {}},
		{"kind": "recycling", "at": _f(0.4, 0.5) + Vector2(0, 8), "tags": {}},
		{"kind": "recycling", "at": _f(0.6, 0.5) + Vector2(0, -8), "tags": {}},
		{"kind": "bench", "at": _f(1.2, 0.5), "tags": {}},  # (in the next tile: not this one's)
	]
	return {"buildings": [], "roads": [
		{"class": "residential", "w": 8.0, "pave": [8.0, 8.0], "lit": true, "surface": "sett", "lanes": 2, "pts": [w.x, w.y, e.x, e.y]},
		{"class": "residential", "w": 7.0, "pave": [7.0, 7.0], "pts": [n.x, n.y, s.x, s.y]},
	], "street": {"points": points, "lines": [{"kind": "hedge", "pts": PackedVector2Array([_f(0.1, 0.7), _f(0.3, 0.7)])}]}}


func test_what_the_map_says_things_look_like() -> void:
	var b := {}
	OsmImport._looks(b, {"roof:shape": "gabled", "roof:levels": "2", "building:material": "brick"})
	check(b.roof == "gable" and is_equal_approx(b.rise, 2.0 * OsmImport.ROOF_STOREY) and b.colour == OsmImport.MATERIAL_COLOUR.brick, "a gabled brick house: its roof, how high, its colour")
	var c := {}
	OsmImport._looks(c, {"roof:shape": "skillion", "building:colour": "#ffffff"})
	check(not c.has("roof") and c.colour == Color.WHITE, "a roof we don't draw stays flat; a colour as mapped")
	var r := OsmImport._road({"highway": "residential", "surface": "sett", "lit": "yes", "lanes": "2"}, PackedVector2Array([_f(0.1, 0.1), _f(0.2, 0.1)]), TileKey.rect(Fixtures.tile_key()))
	check(r.surface == "sett" and r.lit and r.lanes == 2, "a street keeps its surface, its lamps and its lanes")
	check(StreetThings.kind_of({"highway": "crossing", "crossing": "zebra"}) == "crossing" and StreetThings.kind_of({"highway": "crossing", "crossing": "unmarked"}) == "", "a zebra is painted; an unmarked crossing isn't")
	check(StreetThings.kind_of({"amenity": "recycling"}) == "recycling" and StreetThings.kind_of({"amenity": "bicycle_parking"}) == "bike_stand", "recycling, a bike stand")


func test_things_stand_where_they_would() -> void:
	var d := _district()
	var k := Kerbs.of(d)
	var t := StreetThings.of(d, k, Fixtures.tile_key())
	var by := {}
	for x in t.things:
		if not by.has(x.kind):
			by[x.kind] = []
		by[x.kind].append(x)
	var road_y := _f(0.0, 0.5).y
	check(by.crossing.size() == 1 and absf(by.crossing[0].at.y - road_y) < 0.01 and is_equal_approx(by.crossing[0].width, 8.0), "a zebra lies across the road, as wide as it")
	check(by.bus_stop.size() == 1 and k.height_at(by.bus_stop[0].at) == Kerbs.HEIGHT, "a bus stop's shelter is on the pavement, off the road")
	var facing := Vector2(-sin(float(by.bus_stop[0].yaw)), -cos(float(by.bus_stop[0].yaw)))
	check(facing.dot(Vector2(0, road_y) - Vector2(0, by.bus_stop[0].at.y)) > 0.0, "facing the road")
	check(by.has("stop_sign") and k.height_at(by.stop_sign[0].at) == Kerbs.HEIGHT, "a stop sign at the kerb by the junction")
	check(not by.bench.any(func(x): return x.at.x > TileKey.rect(Fixtures.tile_key()).end.x), "what stands in the next tile is that tile's")
	var made: Array = by.lamp.filter(func(x): return x.get("made", false))
	check(made.size() >= 8 and made.all(func(x): return k.height_at(x.at) == Kerbs.HEIGHT), "lamps put up along the lit street, on its pavements (%d)" % made.size())
	check(made.all(func(x): return x.at.distance_to(by.lamp[0].at) >= StreetThings.LAMP_NEAR or x == by.lamp[0]), "none put up beside a mapped lamp")
	var junction := _f(0.5, 0.5)
	check(not made.any(func(x): return x.at.distance_to(junction) < 3.5), "nor in the side street's mouth")
	check(t.lines.size() == 1 and t.lines[0].kind == "hedge", "and the hedge")


func test_the_furniture_stays_cheap() -> void:
	for kind in ["lamp", "bus_stop", "tram_stop", "stop_sign", "give_way", "traffic_light", "bike_stand", "bench", "bin", "recycling"]:
		var n := StreetThingsBuilder.triangles(kind)
		check(n > 0 and n <= 120, "a %s is %d triangles" % [kind, n])
	var baked := StreetThingsBuilder.bake(StreetThings.of(_district(), Kerbs.of(_district()), Fixtures.tile_key()))
	check(baked.places.has("lamp") and baked.heads.size() == (baked.places.lamp as Array).size(), "each lamp has a light for the night")
	check((baked.solid as CityBuilder.Buf).i.size() > 0, "and the hedge is solid")


func test_cobbles_slow_a_board() -> void:
	var k := Kerbs.of(_district())
	check(k.rough_at(_f(0.2, 0.5)) and not k.rough_at(_f(0.5, 0.3)), "the cobbled street is rough; the side street isn't")
	var w := World.new()
	w.add_player(Vector2.ZERO, 100.0)
	w.player.gear.add("skateboard", 1)
	w.skating.mount()
	w.skating.speed = Skating.TOP_SPEED
	for i in 40:
		w.skating.step(0.05, {"push": true, "rough": true}, true, Vector2.ZERO)
	check(is_equal_approx(w.skating.speed, Skating.TOP_SPEED * Skating.ROUGH), "on cobbles, the board can't go flat out (%.1f m/s)" % w.skating.speed)
	for i in 40:
		w.skating.step(0.05, {"push": true}, true, Vector2.ZERO)
	check(is_equal_approx(w.skating.speed, Skating.TOP_SPEED), "off them, it can")


func test_the_bottles_gather_at_the_recycling() -> void:
	var d := Fixtures.tile_district()
	var landing := TileLanding.new(Fixtures.tile_key(), d, Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var bare := landing.build()
	var made: Array = bare.bins.filter(func(p): return p.zone == Fixtures.tile_key() and p.kind == "recycling")
	check(made.size() == 1 and made[0].source == "", "no recycling on the map: the atom's own recycling bin")
	var m: Vector2 = landing.market
	var near := [m + Vector2(12, 9), m + Vector2(-15, 10), m + Vector2(20, -12), m + Vector2(-25, -8)]
	d["street"] = {"points": near.map(func(p): return {"kind": "recycling", "at": p, "tags": {}}), "lines": []}
	var with_bins := TileLanding.new(Fixtures.tile_key(), d, Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var w := with_bins.build()
	var piles: Array = w.bins.filter(func(p): return p.zone == Fixtures.tile_key() and p.kind == "recycling")
	check(piles.size() == SiteFinder.RECYCLE_MOST and piles.all(func(p): return p.source == "map"), "at the nearest of the containers (%d of %d), and no made-up bin" % [piles.size(), near.size()])
	var rate := 0.0
	for p in piles:
		rate += p.rate
	check(is_equal_approx(rate, WasteBin.KINDS.recycling.rate), "between them, as many bottles as the one bin gave (the baseline holds)")
	check(w.bins.filter(func(p): return p.zone == Fixtures.tile_key() and p.kind == "garbage").size() == 1, "and the scrap still gathers in the atom's own garbage bin")
	check(piles.all(func(p): return near.any(func(b): return b.distance_to(p.pos) <= SiteFinder.PILE_OUT + 0.01)), "lying in front of each")
	var far := SiteFinder.recycling(d, Fixtures.tile_key(), m, func(_at: Vector2) -> float: return SiteFinder.RECYCLE_WALK + 1.0)
	check(far.is_empty(), "a container too long a walk away isn't used")


func test_every_kind_of_bin_is_the_maps_where_it_has_one() -> void:
	check(StreetThings.kind_of({"amenity": "drinking_water"}) == "fountain" and StreetThings.kind_of({"amenity": "waste_basket"}) == "bin", "a drinking fountain and a waste basket on the map")
	check(StreetThings.kind_of({"amenity": "recycling", "recycling:organic": "yes"}) == "organics" and StreetThings.kind_of({"amenity": "recycling", "recycling:glass_bottles": "yes"}) == "recycling", "a recycling point that takes food is the organics; one for bottles, the recycling")
	var d := Fixtures.tile_district()
	var m: Vector2 = TileLanding.new(Fixtures.tile_key(), d, Fixtures.TILE_LAT, Fixtures.TILE_LON).market
	var pts := [
		{"kind": "bin", "at": m + Vector2(8, 6)}, {"kind": "bin", "at": m + Vector2(-10, 7)},
		{"kind": "fountain", "at": m + Vector2(14, -6)},
		{"kind": "organics", "at": m + Vector2(-18, -5)},
	]
	d["street"] = {"points": pts.map(func(p): return {"kind": p.kind, "at": p.at, "tags": {}}), "lines": []}
	var landing := TileLanding.new(Fixtures.tile_key(), d, Fixtures.TILE_LAT, Fixtures.TILE_LON)
	var w := landing.build()
	var of := func(kind: String) -> Array: return w.bins.filter(func(b): return b.zone == Fixtures.tile_key() and b.kind == kind)
	check(landing.bins.keys().size() == 3 and not landing.bins.has("recycling"), "the map has waste baskets, a fountain and an organics bin near the market, and no recycling (%s)" % [landing.bins.keys()])
	check(of.call("garbage").size() == 2 and of.call("garbage").all(func(b): return b.source == "map"), "the scrap gathers at the two waste baskets")
	var rate := 0.0
	for b in of.call("garbage"):
		rate += b.rate
	check(is_equal_approx(rate, WasteBin.KINDS.garbage.rate), "and between them as fast as the atom's one bin (%.2f a minute)" % rate)
	check(of.call("fountain").size() == 1 and of.call("fountain")[0].source == "map" and of.call("organics").size() == 1 and of.call("organics")[0].source == "map", "the water at the fountain, the leftovers at the organics bin")
	check(of.call("recycling").size() == 1 and of.call("recycling")[0].source == "", "and the bottles in the atom's own recycling bin, the map having none")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "the books balance")
