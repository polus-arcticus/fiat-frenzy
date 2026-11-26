## Sim tests: lines (Line: the mapped tracks joined end to end, or a route through the streets, and the stops on it) and what runs
## on them (a Vehicle on its line, run by Transit): a train goes from stop to stop carrying the hero, and from the last comes
## round from the line's start; a bus that doesn't go round goes back along the streets, turning in the road.
extends TestCase


func _track(id: int, pts: Array, service := "") -> Dictionary:
	return {"id": id, "kind": "rail", "pts": PackedVector2Array(pts), "service": service != ""}


# Three pieces of one line (the middle one bends a little), a siding off it, and a branch that leaves it at a right angle.
func _rail() -> Dictionary:
	return {"tracks": [
		_track(1, [Vector2(0, 0), Vector2(100, 0)]),
		_track(2, [Vector2(100, 0), Vector2(200, 5)]),
		_track(3, [Vector2(300, 5), Vector2(200, 5)]),  # (drawn the other way round: it is joined all the same)
		_track(4, [Vector2(100, 0), Vector2(100, 40)], "siding"),
		_track(5, [Vector2(200, 5), Vector2(200, 80)]),
	], "stops": [
		{"at": Vector2(50, 12), "name": "Alt", "kind": "station"},
		{"at": Vector2(55, 14), "name": "", "kind": "station"},       # (the same station's other platform)
		{"at": Vector2(250, -10), "name": "Neu", "kind": "halt"},
		{"at": Vector2(500, 500), "name": "Far Away", "kind": "station"},
	]}


func test_the_pieces_are_one_line_with_its_stops() -> void:
	var line := Line.pick(_rail())
	check(line != null and absf(line.length - 300.1) < 1.0, "three pieces make one line of 300 m (%.1f)" % [line.length if line != null else 0.0])
	check(line.stops.size() == 2 and line.stops[0].name == "Alt" and line.stops[1].name == "Neu", "with the two stops that are on it, in order: a station's two platforms are one stop, a far one is none")
	check(line.stops[0].s < line.stops[1].s and (line.stops[0].at as Vector2).distance_to(Vector2(50, 0)) < 0.01, "each on the line itself, where the station's nearest")


func test_a_siding_is_not_a_line_and_a_right_angle_is_not_joined() -> void:
	var line := Line.pick(_rail())
	var ys := Array(line.pts).map(func(p): return p.y)
	check(ys.all(func(y): return y <= 5.001), "the branch off at a right angle and the siding are not part of it")
	check(Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(200, 0)], "yard")], "stops": []}) == null, "a yard alone has no line")
	check(Line.pick({}) == null, "nor has no railway at all")


func test_a_line_with_no_stops_runs_end_to_end() -> void:
	var line := Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(200, 0)])], "stops": []})
	check(line.stops.size() == 2 and absf(line.stops[0].s - Line.END_INSET) < 0.01 and absf(line.stops[1].s - (200.0 - Line.END_INSET)) < 0.01, "its two ends, a little in")
	check(Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(20, 0)])], "stops": []}) == null, "but a stub is not worth a train")
	var one := Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(400, 0)])], "stops": [{"at": Vector2(200, 8), "name": "Mitte"}]})
	check(one.stops.size() == 3 and one.stops[1].name == "Mitte" and one.stops[0].s < one.stops[1].s and one.stops[1].s < one.stops[2].s, "a station alone in the middle has the two ends beyond it")
	var edge := Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(400, 0)])], "stops": [{"at": Vector2(10, 8), "name": "Kopf"}]})
	check(edge.stops.size() == 2 and edge.stops[0].name == "Kopf", "and one at an end only the other end")
	var more := Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(200, 0)])], "stops": []}, [{"at": Vector2(30, 5), "name": "Tram"}, {"at": Vector2(150, -5), "name": "Stop"}])
	check(more.stops.size() == 2 and more.stops[0].name == "Tram", "and the stops of the street layer (a tram's) count too")


func test_the_way_between_stops_follows_the_line() -> void:
	var line := Line.pick(_rail())
	var way := line.between(0, 1)
	check((way[0] as Vector2).is_equal_approx(line.stops[0].at) and (way[way.size() - 1] as Vector2).is_equal_approx(line.stops[1].at), "from one stop to the other")
	check(way.has(Vector2(100, 0)) and way.has(Vector2(200, 5)), "through the corners of the line between")
	var back := line.between(1, 0)
	check((back[0] as Vector2).is_equal_approx(way[way.size() - 1]) and back.size() == way.size(), "and back the same way")
	check(absf(line.heading_at(0, 1) - 0.0) < 0.05 and absf(absf(line.heading_at(0, -1)) - PI) < 0.05, "a train faces on along the line, or back")


func _world() -> World:
	var w := World.new()
	var line := Line.pick(_rail())
	w.add_player(line.stops[0].at, 0.0)
	w.transit.add_on("train", "train", line)
	return w


func _ride(w: World) -> void:
	for i in 1200:
		w.tick(0.1)
		if w.transit.vehicle("train").state != Vehicle.State.DRIVING:
			return


func test_the_train_goes_round_its_line() -> void:
	var w := _world()
	var t := w.transit.vehicle("train")
	check(t != null and t.stop == 0 and t.state == Vehicle.State.AT_STOP and t.next_stop() == 1, "it waits at the first stop, to go to the second")
	check(w.transit.ride(t) and t.aboard and not w.transit.ride(t), "the hero gets on and it sets off, once")
	_ride(w)
	check(t.stop == 1 and t.going == -1 and t.pos.distance_to(t.line.stops[1].at) < 0.5, "it stops at the second")
	check(w.player.pos.distance_to(t.pos) < 0.5, "and the hero is where it is")
	check(t.next_stop() == 0 and t.dir == 1, "the next is the first again, still facing on")


func test_from_the_last_stop_it_comes_round_from_the_start() -> void:
	var w := _world()
	var t := w.transit.vehicle("train")
	w.transit.ride(t)
	_ride(w)
	w.transit.disembark(t)
	var bill := w.gun.land_aboard(w.gun.fire(5.0, "cash"), t, Vector2(0.4, 2.0))
	check(w.transit.ride(t, "went_round"), "off again")
	var far := 0.0
	var jumps := 0
	var backwards := false
	var early := false  # (said before it got there)
	for i in 1200:
		w.tick(0.1)
		far = maxf(far, t.pos.x)
		if t.pos.distance_to(t.prev_pos) > 5.0:
			jumps += 1
		backwards = backwards or cos(t.heading) < 0.9
		if t.state != Vehicle.State.DRIVING:
			break
		early = early or w.quests.done("went_round")
	check(far > t.line.length - 1.0 and jumps == 0 and not backwards and not early,"on to the end of the line, never turning round (%.0f of %.0f m); the jump shows no streak (%d)" % [far, t.line.length, jumps])
	check(t.stop == 0 and t.pos.distance_to(t.line.stops[0].at) < 0.5 and t.then.is_empty() and w.quests.done("went_round"), "and on from its start to the first stop, where it arrives")
	check(w.player.pos.distance_to(t.pos) < 0.5 and bill.pos.is_equal_approx(t.to_world(bill.local)), "the hero with it, and what lies on its floor")


func test_a_tram_is_longer_than_a_bus_and_warm_all_along() -> void:
	var w := World.new()
	var tram := w.transit.add("tram", "tram", Vector2.ZERO, 0.0)
	var bus := w.transit.add("bus", "bus", Vector2(0, 50), 0.0)
	check(float(tram.spec().length) > float(bus.spec().length) * 1.5, "a tram is the longer")
	check(w.heating.is_warm(Vector2(10, 0)) and not w.heating.is_warm(Vector2(10, 50)) and not w.heating.is_warm(Vector2(12, 0)), "10 m along from its middle is inside it, and outside a bus")


func test_a_line_of_one_station_runs_to_its_ends_too() -> void:
	var w := World.new()
	check(w.transit.add_on("train", "train", null) == null and w.transit.vehicle("train") == null, "no line, no train")
	var line := Line.pick({"tracks": [_track(1, [Vector2(0, 0), Vector2(300, 0)])], "stops": [{"at": Vector2(150, 8), "name": "Mitte", "kind": "station"}]})
	var names := line.stops.map(func(s): return s.name) if line != null else []
	check(names == ["the end of the line", "Mitte", "the other end"], "one station mapped on it: its ends are stops as well (%s)" % [names])
	check(w.transit.add_on("train", "train", line) != null and w.transit.vehicle("train").line == line, "so it has a train")


func test_a_bus_runs_a_line_through_the_streets_and_turns_in_the_road() -> void:
	var w := World.new()
	w.roads = Fixtures.l_road()  # along the x axis to (50, 0), then down to (50, 50)
	var route := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(50, 50)])
	var places := [{"at": Vector2(5, 4), "name": "Markt"}, {"at": Vector2(46, 48), "name": "Ende"}, {"at": Vector2(200, 200), "name": "Weit"}]
	var line := Line.through(route, places, "Ende", 10.0, 20.0, 40.0)
	check(line != null and line.stops.map(func(s): return s.name) == ["Markt", "Ende"] and line.name == "Ende", "the places near the route are its stops, in order (%s)" % [line.stops.map(func(s): return s.name) if line != null else []])
	var bus := w.transit.add_on("bus", "bus", line)
	bus.wraps = false  # (one that goes back the way it came, as the story's does)
	w.add_player(bus.pos, 0.0)
	check(w.transit.ride(bus, "rode_the_line") and bus.going == 1, "the hero rides it to the next stop")
	Fixtures.until(w, func(): return bus.state == Vehicle.State.ARRIVED, 60)
	check(bus.stop == 1 and bus.pos.distance_to(line.stops[1].at) < 0.5 and w.quests.done("rode_the_line"), "it gets there, round the corner (and says so: Transit.arrived)")
	w.transit.disembark(bus)
	check(w.transit.ride(bus) and bus.path.pts[1].distance_to(bus.pos) > 1.0 and Vector2.from_angle(bus.heading).dot((bus.path.pts[3] - bus.pos).normalized()) > 0.0, "back: the way is behind it, so it sets off forward and turns in the road (Vehicle.SPECS uturn)")
	Fixtures.until(w, func(): return bus.state == Vehicle.State.ARRIVED, 60)
	check(bus.stop == 0 and bus.pos.distance_to(line.stops[0].at) < 0.5, "and is back at the first stop")
