## Sim tests: landing on a tile with no story (see TileLanding, SiteFinder): its atom on the street the rule picks, the same
## for everyone, the hero on the street nearest where they chose, and a town that keeps itself going.
extends TestCase


func test_the_site_is_the_same_every_time() -> void:
	var d := Fixtures.tile_district()
	var a := SiteFinder.pick(d, Fixtures.tile_key())
	var b := SiteFinder.pick(d, Fixtures.tile_key())
	check(a.point == b.point and a.along == b.along and a.street != "", "the same street, the same spot: %s at %s" % [a.street, a.point])


func test_the_atom_stands_on_open_ground() -> void:
	var landing := Fixtures.tile_landing()
	var w := landing.build()
	var key := Fixtures.tile_key()
	var polys: Array = landing.district.buildings.map(func(b): return MapSites.pts(b.poly))
	var things: Array = w.machines + w.hospitals + w.bottle_depots + w.fires + w.bins
	var inside := things.filter(func(o): return polys.any(func(p): return Geometry2D.is_point_in_polygon(o.pos, p)))
	check(things.size() >= 8 and inside.is_empty(), "the atom's %d things stand in the street, none in a building" % things.size())
	check(w.zones.drones_in(key).size() == Atom.ROLES.size() and w.zones.tiles.has(key), "its people are the tile's zone (%s)" % key)
	check(TileKey.rect(key).has_point(landing.market), "and the market is on the tile")


func test_the_hero_lands_where_they_chose() -> void:
	var landing := Fixtures.tile_landing()
	landing.build()
	var chosen := TileKey.local(Fixtures.TILE_LAT, Fixtures.TILE_LON, TileKey.region_of(Fixtures.tile_key()))
	check(landing.start.distance_to(chosen) < 40.0, "on the street nearest the point they chose (%.0f m from it)" % landing.start.distance_to(chosen))
	var other := TileLanding.new(Fixtures.tile_key(), Fixtures.tile_district(), Fixtures.TILE_LAT + 0.002, Fixtures.TILE_LON)
	other.build()
	check(other.market == landing.market and other.start != landing.start, "landing elsewhere on the tile: another spot, the same market")


func test_it_keeps_itself_going() -> void:
	var landing := Fixtures.tile_landing()
	var w := landing.build()
	w.begin_play()
	Cluster.fund(w, Fixtures.tile_key())
	for i in int(Clock.DAY_SECONDS) * 10:
		w.tick(1.0)
	var down := w.events.filter(func(e): return "collapsed" in e).size()
	check(down == 0 and Fixtures.sold(w, Fixtures.tile_key()) > 100, "funded once, it runs ten days: %d collapses, %d sold" % [down, Fixtures.sold(w, Fixtures.tile_key())])
	check(is_equal_approx(w.total_money(), w.ledger.printed), "the money adds up")


func test_a_save_builds_the_same_tile_again() -> void:
	var landing := Fixtures.tile_landing()
	check(landing.spec() == {"kind": "tile", "key": Fixtures.tile_key(), "lat": Fixtures.TILE_LAT, "lon": Fixtures.TILE_LON}, "it says what it is: %s" % [landing.spec()])
	var w := landing.build()
	w.add_player(landing.start)
	w.begin_play()
	Cluster.fund(w, Fixtures.tile_key())
	Fixtures.run(w, 120)
	var data = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var again := TileLanding.new(landing.key, Fixtures.tile_district(), landing.lat, landing.lon)
	var w2 := again.build()
	w2.add_player(again.start)
	Snapshot.new(w2).apply(data)
	check(w2.machines.size() == w.machines.size() and w2.drones.size() == w.drones.size() and is_equal_approx(w2.total_money(), w.total_money()), "built again and the save laid over it: the same town")
