## Sim tests: the European Central Bank's gate and shuttle, on the real map. The gate's pieces and the shuttle's whole way stay
## clear of every building, the shuttle gets there, and the gate opens when the doorman has cleared the hero.
extends TestCase


func _scenario() -> Scenario:
	var f := FileAccess.open("res://data/bahnhofsviertel.json", FileAccess.READ)
	return Scenario.new(JSON.parse_string(f.get_as_text()))


## How far `p` is from the nearest building (0 if it is inside one), looking only at buildings near it.
func _clearance(sc: Scenario, p: Vector2) -> float:
	var best := INF
	for bd in sc.district.buildings:
		var poly := MapSites.pts(bd.poly)
		var rect := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			rect = rect.expand(q)
		if not rect.grow(40.0).has_point(p):
			continue
		if Geometry2D.is_point_in_polygon(p, poly):
			return 0.0
		for i in poly.size():
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best


func test_the_gate_is_planned_at_the_stop_facing_into_the_grounds() -> void:
	var sc := _scenario()
	var g: Dictionary = sc.ecb_gate
	check(not g.is_empty() and g.guard.distance_to(sc.ecb_stop.doorman) < 4.0, "the gate is planned, with the guard just by the doorman's old spot, at the bus stop")
	var from_street: Vector2 = (g.pad as Vector2) - (sc.ecb_stop.bus as Vector2)
	check(from_street.dot(g.into) > 10.0, "the shuttle's pad is on the far side of the gate from the street (%.0f m in)" % from_street.dot(g.into))
	check(absf((g.into as Vector2).length() - 1.0) < 0.001 and absf((g.along as Vector2).dot(g.into)) < 0.001, "the gate's frame is a proper one: its two directions are at right angles")
	check(SecurityGate.world_of(g, Vector2.ZERO).is_equal_approx(g.origin) and SecurityGate.world_of(g, Vector2(0, 5)).is_equal_approx((g.origin as Vector2) + (g.into as Vector2) * 5.0), "a spot's v runs into the grounds")


func test_the_gate_and_its_pieces_stand_on_open_ground() -> void:
	var sc := _scenario()
	var g: Dictionary = sc.ecb_gate
	var spots := {"guard": SecurityGate.GUARD, "booth": SecurityGate.BOOTH, "turnstile": SecurityGate.TURNSTILE, "pad": SecurityGate.PAD,
		"barrier": Vector2((SecurityGate.DRIVE_U0 + SecurityGate.DRIVE_U1) * 0.5, SecurityGate.BARRIER_V), "gate": Vector2((SecurityGate.DRIVE_U0 + SecurityGate.DRIVE_U1) * 0.5, SecurityGate.GATE_V)}
	for p in SecurityGate.FLAG_POLES:
		spots["flag %.1f" % p[0]] = Vector2(p[0], p[1])
	for b in SecurityGate.BLOCKS:
		spots["block %.0f" % b.u0] = Vector2((b.u0 + b.u1) * 0.5, b.v)
	for name in spots:
		var at := SecurityGate.world_of(g, spots[name])
		check(_clearance(sc, at) > 3.0, "the %s is clear of every building (%.0f m)" % [name, _clearance(sc, at)])


func test_the_shuttles_way_to_the_door_clears_every_building() -> void:
	var sc := _scenario()
	var g: Dictionary = sc.ecb_gate
	var route: PackedVector2Array = [g.pad]
	route.append_array(g.route)
	route.append(g.entrance)
	var path := BusPath.build(route, 7.0, 1.6, 2.2, 5.0)  # (as the shuttle is driven: the corners rounded)
	var worst := INF
	var at_worst := Vector2.ZERO
	for p in path.pts:
		var c := _clearance(sc, p)
		if c < worst:
			worst = c
			at_worst = p
	note("    the closest the rounded route comes to a wall: %.1f m, at %s; it is %.0f m long" % [worst, at_worst.round(), path.length])
	check(worst > 2.0, "the shuttle never comes within 2 m of a building along its whole way (closest %.1f m)" % worst)
	check(path.length > 250.0 and path.length < 500.0, "and it is a proper little tour, %.0f m" % path.length)
	check(_clearance(sc, g.entrance) > 3.0 and (g.entrance as Vector2).distance_to(sc.ecb.door) < 9.0 and (g.reception as Vector2).distance_to(sc.ecb.door) < 3.5, "it stops in the plaza by the tower's door, with the receptionist just out from it")


func test_the_shuttle_makes_the_trip_at_a_golf_cart_pace() -> void:
	var sc := _scenario()
	var g: Dictionary = sc.ecb_gate
	var w := World.new()
	w.add_player(Vector2(5, 5), 0.0)
	w.add_shuttle(g.pad, g.pad_heading)
	var via: Array = []
	for p in g.route:
		via.append(p)
	check(w.transit.board(g.entrance, "rode_shuttle", via, w.shuttle, true) and w.shuttle.aboard, "the hero gets on")
	var fastest := 0.0
	var seconds := 0.0
	while w.shuttle.state == Bus.State.DRIVING and seconds < 300.0:
		w.tick(0.25)
		seconds += 0.25
		fastest = maxf(fastest, w.shuttle.speed)
		check_once(w.player.pos == w.shuttle.pos, "the hero is where the shuttle is, all the way")
	note("    %.0f s, top speed %.1f m/s" % [seconds, fastest])
	check(w.shuttle.state == Bus.State.ARRIVED and w.shuttle.pos.distance_to(g.entrance) < 0.5 and w.quests.done("rode_shuttle"), "it arrives at the entrance and counts as the shuttle ride")
	check(fastest <= 7.05 and fastest > 5.0, "at a golf cart's pace, not a bus's (top %.1f m/s)" % fastest)
	check(seconds > 40.0 and seconds < 120.0, "about %.0f s: long enough to enjoy, short enough not to drag" % seconds)
	w.transit.disembark(w.shuttle)
	check(not w.shuttle.aboard, "and the hero can get off")


func test_the_gate_is_open_once_the_doorman_has_cleared_the_hero() -> void:
	var w := World.new()
	w.add_player(Vector2.ZERO, 0.0)
	check(not SecurityGate.is_open(w), "shut at the start")
	w.quests.set_flag("cleared_gate")
	check(SecurityGate.is_open(w), "open once he has")


## (a check made once per test, not once per call)
var _done := {}
func check_once(ok: bool, what: String) -> void:
	if not _done.has(what):
		_done[what] = true
		check(ok, what)
	elif not ok:
		check(false, what)
