## Sim tests: the planet's grid of tiles, and towns on neighbouring tiles. (Merging two saves is test_merge.)
extends TestCase

const FRANKFURT := [50.1086307, 8.6687641]  # the district's origin


func test_a_place_on_the_planet_has_a_tile_and_a_region() -> void:
	var k := TileKey.of(FRANKFURT[0], FRANKFURT[1])
	var region := TileKey.region_of(k)
	check(TileKey.is_tile(k) and k.begins_with("16/") and region.begins_with("10/"), "Frankfurt is in tile %s, region %s" % [k, region])
	var s := TileKey.size_m(region)
	check(s > 380.0 and s < 400.0, "a tile there is about 390 m across (%.1f m)" % s)
	var p := TileKey.local(FRANKFURT[0], FRANKFURT[1], region)
	check(TileKey.rect(k).has_point(p), "the point lies inside its own tile's square (%s in %s)" % [p, TileKey.rect(k)])
	check(TileKey.at(region, p) == k, "and the tile at that point is the same tile")
	var back := TileKey.lat_lon(p, region)
	check(absf(back[0] - FRANKFURT[0]) < 1e-6 and absf(back[1] - FRANKFURT[1]) < 1e-6, "metres go back to the same latitude and longitude")


func test_neighbouring_tiles_line_up_edge_to_edge() -> void:
	var k := TileKey.of(FRANKFURT[0], FRANKFURT[1])
	var n := TileKey.neighbours(k)
	check(n.size() == 4, "a tile inside its region has four neighbours")
	var east := TileKey.key(TileKey.parse(k).x + 1, TileKey.parse(k).y)
	check(east in n, "one of them is the tile to the east")
	check(is_equal_approx(TileKey.rect(k).end.x, TileKey.rect(east).position.x), "whose square starts exactly where this one ends")
	var b := TileKey.border_point(k, east)
	check(is_equal_approx(b.x, TileKey.rect(k).end.x) and TileKey.rect(k).grow(0.01).has_point(b), "the border point is on the shared edge")
	check(not TileKey.border_point(k, TileKey.key(TileKey.parse(k).x + 2, TileKey.parse(k).y)).is_finite(), "tiles that do not touch have no border")


func test_a_dormant_town_lives_in_summary_much_as_it_would_in_full() -> void:
	# (A funded town that keeps going, the standard cluster with its van and bottle depot: a town without them goes broke and
	# collapses, which is a cascade, not a test of the summary.)
	var full := World.new()
	Cluster.build(full, "a", Vector2.ZERO, 6, true, 200.0)
	var summed := World.new()
	Cluster.build(summed, "a", Vector2.ZERO, 6, true, 200.0)
	summed.build_zone = "hero's"
	summed.add_drifter(Vector2(5000, 0)).make_needless()  # (someone where the hero is, so there is a zone to be active)
	summed.zones.active = ["hero's"] as Array[String]
	summed.ledger.printed = summed.total_money()  # (the fountain prints as it goes: what is in the world is what was printed)
	var where: Array = summed.zones.drones_in("a").map(func(d): return d.pos)
	var leaks := 0
	for i in 3600:
		full.tick(1.0)
		summed.tick(1.0)
		if not is_equal_approx(summed.total_money(), summed.ledger.printed):
			leaks += 1
	var a := Fixtures.sold(full, "a")
	var b := Fixtures.sold(summed, "a")
	check(leaks == 0, "in summary, the money in the world is the same on every tick (%d ticks off)" % leaks)
	check(a > 20 and absf(b - a) <= 0.2 * a, "an hour in summary sells about what an hour in full does (%d in full, %d in summary)" % [a, b])
	var hungry := summed.zones.drones_in("a").filter(func(d): return d.bars.hunger <= 0.0 or d.bars.thirst <= 0.0).size()
	note("starving in full: %d, in summary: %d" % [full.zones.drones_in("a").filter(func(d): return d.bars.hunger <= 0.0 or d.bars.thirst <= 0.0).size(), hungry])
	var tent: Hospital = summed.zones.hospitals_in("a")[0]
	var people: Array = summed.zones.drones_in("a")
	var walked := range(people.size()).filter(func(i): return people[i].pos != where[i] and people[i].pos.distance_to(tent.pos) > 6.0)
	check(walked.is_empty(), "and nobody in it walked: the only ones who could have moved are those taken into the medical tent (%d admitted)" % tent.admitted_total)


## Two towns on neighbouring tiles: `a` has no food bank (its stands run short), `b` has one, with its runners.
func _neighbours(purse := 200.0) -> Array:
	var a := TileKey.of(FRANKFURT[0], FRANKFURT[1])
	var b := TileKey.key(TileKey.parse(a).x + 1, TileKey.parse(a).y)
	var w := World.new()
	w.zones.add_tile(a)
	w.zones.add_tile(b)
	Cluster.build(w, a, TileKey.rect(a).get_center(), 6, false, purse, false)
	Cluster.build(w, b, TileKey.rect(b).get_center(), 6, true, purse, false)
	return [w, a, b]


func test_goods_and_people_cross_between_dormant_tiles_and_the_money_adds_up() -> void:
	var n := _neighbours()
	var w: World = n[0]
	w.build_zone = "elsewhere"
	w.add_drifter(Vector2.ZERO)
	w.zones.active = ["elsewhere"] as Array[String]  # both towns dormant: in summary
	var money := w.total_money()
	var people := w.zones.drones_in(n[1]).size() + w.zones.drones_in(n[2]).size()
	var leaks := 0
	for i in 1800:
		w.tick(1.0)
		if not is_equal_approx(w.total_money(), money):
			leaks += 1
	check(leaks == 0, "the money in the world is the same on every tick (%d off)" % leaks)
	check(w.borders.carts > 0, "carts of leftovers and the like went over to the town without bins of its own (%d)" % w.borders.carts)
	var in_b := w.zones.drones_in(n[2]).size()
	note("crossings %d; people in a %d, in b %d" % [w.borders.crossings, w.zones.drones_in(n[1]).size(), in_b])
	check(w.borders.crossings > 0 and in_b + w.zones.drones_in(n[1]).size() == people, "people crossed (%d), and nobody was lost on the way (%d)" % [w.borders.crossings, people])


func test_in_a_running_tile_someone_walks_to_the_border_and_steps_over() -> void:
	var n := _neighbours()
	var w: World = n[0]
	var a: String = n[1]
	var b: String = n[2]
	for m in w.zones.machines_in(a):
		m.output.take(m.item, m.stock())  # nothing to eat or drink in a
		m.working = false
	var d: Drone = w.zones.drones_in(a).filter(func(x): return x.kind == "drifter")[0]
	d.bars.hunger = 0.3
	w.zones.active = [a] as Array[String]
	var took := Fixtures.until(w, func(): return d.zone == b, 600)
	check(took >= 0, "a hungry drifter with nothing to buy at home walks over to the next tile (%d s)" % took)
	check(TileKey.rect(b).has_point(d.pos), "and is in it")


func test_a_world_of_tiles_knows_which_tile_someone_is_in() -> void:
	var k := TileKey.of(FRANKFURT[0], FRANKFURT[1])
	var east := TileKey.key(TileKey.parse(k).x + 1, TileKey.parse(k).y)
	var w := World.new()
	w.zones.add_tile(k)
	w.zones.add_tile(east)
	var adj := w.zones.adjacent(k)
	check(adj.size() == 1 and adj[0] == east, "two loaded tiles side by side are adjacent")
	var mid_east := TileKey.rect(east).get_center()
	check(w.zones.zone_for(mid_east, k) == east, "walking into the next tile puts you in its zone")
	var far := TileKey.rect(TileKey.key(TileKey.parse(k).x + 5, TileKey.parse(k).y)).get_center()
	check(w.zones.zone_for(far, east) == east, "off the loaded tiles you stay in the zone you were in")
