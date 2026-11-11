## Sim tests: the bus drives itself along the streets with the hero aboard, and the world runs on meanwhile.
extends TestCase


func _stop() -> Array:
	var w := World.new()
	w.roads = Fixtures.l_road()  # along the x axis to (50, 0), then down to (50, 50)
	var bus := w.add_bus(Vector2(2, 0), 0.0)
	w.add_player(Vector2(2, 3))
	return [w, bus]


func test_the_bus_waits_until_someone_boards() -> void:
	var s := _stop()
	var w: World = s[0]
	var bus: Bus = s[1]
	for i in 50:
		w.tick(0.1)
	check(bus.state == Bus.State.AT_STOP and bus.pos == Vector2(2, 0), "it stays at its stop")
	check(w.bus_stop == Vector2(2, 0), "which is where the world says the stop is")
	check(not w.transit.board(Vector2(INF, INF)), "it won't go nowhere")


func test_it_drives_the_streets_and_the_hero_goes_with_it() -> void:
	var s := _stop()
	var w: World = s[0]
	var bus: Bus = s[1]
	check(w.transit.board(Vector2(50, 50)) and bus.state == Bus.State.DRIVING and bus.aboard, "boarding sets it off")
	check(not w.transit.board(Vector2(0, 0)), "and it cannot be boarded again while it is out")
	var passed_corner := false
	var together := true
	var t := 0.0
	while bus.state == Bus.State.DRIVING and t < 60.0:
		w.tick(0.1)
		t += 0.1
		if bus.pos.distance_to(Vector2(50, 0)) < 4.0:
			passed_corner = true
		together = together and w.player.pos == bus.pos
	check(together, "the hero is where the bus is, the whole way")
	check(passed_corner, "it went round the street corner, not across the block")
	check(bus.state == Bus.State.ARRIVED and bus.pos == Vector2(50, 50), "it arrived exactly where it was going")
	check(t > 12.0 and t < 28.0, "about 100 m, setting off gently, slowing for the corner and braking to a stop: %.1f s" % t)
	check(w.quests.done("rode_bus"), "arriving counts as having ridden the bus")
	check(w.events.any(func(e): return e.contains("pulls out")) and w.events.any(func(e): return e.contains("has stopped")), "and the feed says what it did")
	w.transit.disembark()
	var left := w.player.pos
	w.tick(1.0)
	check(not bus.aboard and bus.state == Bus.State.ARRIVED, "getting off leaves the bus where it stopped")
	check(left == Vector2(50, 50), "with the hero beside it")


func test_the_world_keeps_running_during_the_ride() -> void:
	var s := _stop()
	var w: World = s[0]
	var baker := w.add_vendor("bakery", Vector2(20, 5), 0.0, true, true)
	w.machine_of(baker).input.add("flour", 20)
	var before := w.machine_of(baker).crafted_total
	w.transit.board(Vector2(50, 50))
	for i in 100:
		w.tick(0.1)
	check(w.machine_of(baker).crafted_total > before and w.clock.time > 9.0, "the bakery kept baking and the clock ran while the bus was out")


func test_a_first_stretch_that_doubles_back_is_dropped() -> void:
	var w := World.new()
	# a street whose nearest corner to the bus is behind it: (-6, 1), then the way on east
	w.roads = RoadGraph.new()
	w.roads.add_polyline(PackedVector2Array([Vector2(-6, 1), Vector2(30, 1), Vector2(60, 1)]))
	var bus := w.add_bus(Vector2(0, 0), 0.0)
	w.add_player(Vector2(0, 3))
	check(w.transit.board(Vector2(60, 1)), "it sets off")
	check(bus.path.pts.size() > 1 and bus.path.pts[1].x > 0.0, "and its first stretch is forward, not back to the corner behind it")
	var t := 0.0
	while bus.state == Bus.State.DRIVING and t < 60.0:
		w.tick(0.1)
		t += 0.1
	check(bus.state == Bus.State.ARRIVED, "and it gets there")


func test_the_ride_is_smooth() -> void:
	var s := _stop()
	var w: World = s[0]
	var bus: Bus = s[1]
	w.transit.board(Vector2(50, 50))
	var worst_turn := 0.0
	var worst_accel := 0.0
	var last_speed := 0.0
	var last_heading := bus.heading
	var jump := 0.0
	var steps := 0
	while bus.state == Bus.State.DRIVING and steps < 1000:
		w.tick(0.1)
		steps += 1
		worst_turn = maxf(worst_turn, absf(angle_difference(last_heading, bus.heading)))
		if bus.state == Bus.State.DRIVING:  # (stopping at the end is not a jolt: it is already crawling)
			worst_accel = maxf(worst_accel, absf(bus.speed - last_speed) / 0.1)
		jump = maxf(jump, bus.pos.distance_to(bus.prev_pos))
		last_heading = bus.heading
		last_speed = bus.speed
	check(worst_turn < 0.25, "its heading never changes by more than a few degrees a tick (%.3f rad)" % worst_turn)
	check(worst_accel < BusPath.BRAKE + 1.0, "it never speeds up or slows down harder than a bus would (%.2f m/s2)" % worst_accel)
	check(jump <= BusPath.MAX_SPEED * 0.1 + 0.01, "and never moves more than its top speed allows in a tick (%.2f m)" % jump)


func test_the_path_rounds_the_corners_and_has_a_speed_for_every_point() -> void:
	var route := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var path := BusPath.build(route)
	var sharpest := 0.0
	for i in range(1, path.pts.size() - 1):
		var a := (path.pts[i] - path.pts[i - 1]).normalized()
		var b := (path.pts[i + 1] - path.pts[i]).normalized()
		sharpest = maxf(sharpest, acos(clampf(a.dot(b), -1.0, 1.0)))
	check(sharpest < 0.4, "a right angle in the street becomes a curve with no sharp point (%.2f rad)" % sharpest)
	check(path.pos_at(0.0).is_equal_approx(Vector2(0, 0)) and path.pos_at(path.length).is_equal_approx(Vector2(100, 100)), "it still begins and ends where the streets do")
	check(path.speed_at(0.0) < 1.0 and path.speed_at(path.length) < 1.0, "it sets off from rest and comes to rest")
	var corner := path.pos_at(0.0)
	var slowest := INF
	var fastest := 0.0
	for k in 100:
		var v := path.speed_at(path.length * k / 100.0)
		slowest = minf(slowest, v)
		fastest = maxf(fastest, v)
	check(fastest > 8.0 and fastest <= BusPath.MAX_SPEED + 0.01, "it gets up to a good speed on the straight (%.1f m/s)" % fastest)
	var around := path.speed_at(path.cum[path.cum.size() / 2])
	check(around < fastest and around >= BusPath.MIN_SPEED - 0.01, "and slows through the bend (%.1f m/s)" % around)
	check(corner == Vector2.ZERO, "(the first point is the bus)")
