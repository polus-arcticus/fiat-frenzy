## Sim tests: the sim on a hill (World.landform). Walkers keep Tobler's pace (slower up a slope, quickest on a gentle descent,
## slow down a steep one), trips are reckoned in metres on the flat so nobody sets out on a climb they won't last, and the
## market, the camp and what the hero puts down keep off the slopes. On flat ground nothing changes.
extends TestCase

const AREA := Rect2(-200, -200, 400, 400)


func _walk(w: World, from: Vector2, to: Vector2) -> float:
	var d := w.add_drifter(from, 10.0)
	d.make_needless()
	var t := 0.0
	while d.pos.distance_to(to) > 0.05 and t < 600.0:
		w.walking.step(d, to, 0.1)
		t += 0.1
	return t


func test_tobler_sets_the_pace() -> void:
	check(is_equal_approx(Walking.pace(0.0), 1.0), "on the flat, a walker's own pace")
	check(absf(Walking.pace(-0.05) - 1.19) < 0.01, "quickest down a gentle 5%% slope (%.2f)" % Walking.pace(-0.05))
	check(absf(Walking.pace(0.1) - 0.70) < 0.01 and absf(Walking.pace(0.3) - 0.35) < 0.01, "0.70 up 10%%, 0.35 up 30%% (%.2f, %.2f)" % [Walking.pace(0.1), Walking.pace(0.3)])
	check(absf(Walking.pace(-0.3) - 0.50) < 0.01 and Walking.pace(-0.3) < Walking.pace(-0.05), "slower again down a steep one (%.2f)" % Walking.pace(-0.3))
	check(is_equal_approx(Walking.pace(3.0), Walking.SLOWEST), "and never stopped dead, however steep")


func test_walkers_climb_slower_than_they_go_along() -> void:
	var flat := World.new()
	var level := _walk(flat, Vector2.ZERO, Vector2(50, 0))
	var w := World.new()
	w.landform = Fixtures.tilted(AREA, Vector2(0.2, 0.0))  # (rising 20% eastward)
	var up := _walk(w, Vector2.ZERO, Vector2(50, 0))
	var down := _walk(w, Vector2(50, 0), Vector2.ZERO)
	var across := _walk(w, Vector2.ZERO, Vector2(0, 50))
	check(absf(level - 50.0 / Walking.SPEED) < 0.2, "50 m on the flat at a drifter's pace: %.1f s" % level)
	check(absf(up - level / Walking.pace(0.2)) < 1.0, "50 m up a 20%% slope takes %.1f s (Tobler: %.1f)" % [up, level / Walking.pace(0.2)])
	check(down < up and absf(down - level / Walking.pace(-0.2)) < 1.0, "back down it %.1f s (%.1f)" % [down, level / Walking.pace(-0.2)])
	check(absf(across - level) < 0.5, "and along the slope, as on the flat (%.1f s)" % across)


func test_a_trip_is_reckoned_in_metres_on_the_flat() -> void:
	var flat := World.new()
	var trip := [Vector2.ZERO, Vector2(60, 0), Vector2.ZERO]
	check(is_equal_approx(flat.walking.effort(trip), 120.0), "on the flat a trip's effort is its length")
	var w := World.new()
	w.landform = Fixtures.tilted(AREA, Vector2(0.25, 0.0))
	var hill := w.walking.effort(trip)
	check(hill > 150.0, "60 m up a 25%% slope and back is %.0f m on the flat" % hill)
	var runner := w.add_runner(Vector2.ZERO, 10.0)
	runner.bars = Fixtures.bars(1.0, 1.0, 1.0)
	var flat_runner := flat.add_runner(Vector2.ZERO, 10.0)
	flat_runner.bars = runner.bars
	var far := [Vector2.ZERO, Vector2(100, 0), Vector2.ZERO]
	check(flat.needs.would_last(flat_runner, flat.walking.effort(far)) and not w.needs.would_last(runner, w.walking.effort(far)),
		"a runner fed and watered sets out 100 m and back on the flat, but not up a 25%% hill (%.0f m on the flat)" % w.walking.effort(far))


func test_the_market_keeps_off_a_slope() -> void:
	var d := Fixtures.tile_district()
	var key := Fixtures.tile_key()
	var level := SiteFinder.pick(d, key)
	var c: Vector2 = level.point
	# a steep knoll (30%) where the market would have gone, level ground beyond it
	var knoll := Fixtures.landform(TileKey.rect(key).grow(100.0), func(p: Vector2) -> float: return 100.0 + 0.3 * maxf(0.0, 60.0 - p.distance_to(c)))
	var moved := SiteFinder.pick(d, key, knoll)
	check(not moved.is_empty() and (moved.point as Vector2).distance_to(c) > 20.0, "a knoll where the market would stand: it goes to another street (%.0f m off)" % (moved.point as Vector2).distance_to(c))
	check(SiteFinder.steepest(moved, knoll) <= SiteFinder.MAX_GRADE, "where its stalls stand on ground no steeper than %.0f%% (%.1f%%)" % [100.0 * SiteFinder.MAX_GRADE, 100.0 * SiteFinder.steepest(moved, knoll)])
	var steep := Fixtures.tilted(TileKey.rect(key).grow(100.0), Vector2(0.3, 0.0))
	var anyway := SiteFinder.pick(d, key, steep)
	check(anyway.get("street", "") != "" and (anyway.point as Vector2).is_equal_approx(c), "on a tile that is steep all over it still has its market, where the flat rule puts it")
	check(SiteFinder.pick(d, key, Landform.new()).point == c, "and on flat ground the rule is as it was")


func test_with_no_street_to_stand_on_it_finds_level_ground() -> void:
	var key := Fixtures.tile_key()
	var rect := TileKey.rect(key)
	var nothing := {"roads": [], "buildings": []}
	var middle := SiteFinder.pick(nothing, key)
	check((middle.point as Vector2).is_equal_approx(rect.get_center()), "no streets on flat ground: the open site in the middle, as ever")
	var shelf := rect.position + Vector2(80, 80)
	# a 30% mountainside with one level shelf on it, away from the middle
	var side := Fixtures.landform(rect.grow(100.0), func(p: Vector2) -> float: return 100.0 + 0.3 * p.x if p.distance_to(shelf) > 45.0 else 100.0 + 0.3 * shelf.x)
	var open := SiteFinder.pick(nothing, key, side)
	check((open.point as Vector2).distance_to(shelf) < 30.0 and SiteFinder.steepest(open, side) <= SiteFinder.MAX_GRADE,
		"on a mountainside it is the level shelf (%.0f m from it, %.0f%% steep)" % [(open.point as Vector2).distance_to(shelf), 100.0 * SiteFinder.steepest(open, side)])
	var steep := Fixtures.tilted(rect.grow(100.0), Vector2(0.3, 0.0))
	check(not SiteFinder.pick(nothing, key, steep).is_empty(), "and steep all over, still somewhere")


func test_the_landing_brings_its_land_into_the_world() -> void:
	var flat := Fixtures.tile_landing().build()
	check(flat.landform.flat, "a tile landed without relief is flat, as the tests have it")
	var land := Fixtures.tilted(TileKey.rect(Fixtures.tile_key()).grow(100.0), Vector2(0.02, 0.01))
	var m: Array = TileKey.middle(Fixtures.tile_key())
	var landing := TileLanding.new(Fixtures.tile_key(), Fixtures.tile_district(), m[0], m[1], land)
	var w := landing.build()
	check(w.landform == land and not w.landform.flat, "with it, the world stands on its hills")
	var mid := TileKey.rect(Fixtures.tile_key()).get_center()
	check(absf(w.landform.height_at(mid) - (100.0 + Vector2(0.02, 0.01).dot(mid - land.rect.position))) < 1.0, "and knows how high anywhere is, metres above the sea")


func test_nothing_is_put_down_on_a_steep_bank() -> void:
	var w := World.new()
	w.add_player(Vector2.ZERO).make_needless()
	w.player.carry.add("barrel_fire", 1)
	w.landform = Fixtures.tilted(AREA, Vector2(0.3, 0.0))
	check(w.placing.why_not("barrel_fire", Vector2(3, 0)).begins_with("Too steep"), "not on a 30%% bank: %s" % w.placing.why_not("barrel_fire", Vector2(3, 0)))
	w.landform = Fixtures.tilted(AREA, Vector2(0.1, 0.0))
	check(w.placing.can_place("barrel_fire", Vector2(3, 0)), "a 10%% slope will do: %s" % w.placing.why_not("barrel_fire", Vector2(3, 0)))
