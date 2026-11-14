## Sim tests: the skateboard's rules: getting on, rolling, the ollie and the double-jump kickflip with its $25.
extends TestCase


func _rider(with_board := true) -> World:
	var w := World.new()
	w.add_player(Vector2(10, 10), 100.0)
	if with_board:
		w.player.carry.add("skateboard", 1)
	return w


func _roll(w: World, seconds: float, input := {"push": true}) -> void:
	for i in int(seconds / 0.05):
		w.skating.step(0.05, input, true, Vector2(10, 10))


func test_you_need_a_board_to_get_on_it() -> void:
	var none := _rider(false)
	check(not none.skating.mount().ok and not none.skating.mounted, "no board, no skating")
	var w := _rider()
	check(w.skating.mount().ok and w.skating.mounted, "with a board in the bag you can get on")
	check(not w.skating.mount().ok, "but not twice")
	w.skating.dismount()
	check(not w.skating.mounted and w.skating.speed == 0.0, "getting off stops it")
	w.player.care = "down"
	check(not w.skating.mount().ok, "and not while out cold")
	w.player.care = ""
	w.bike = Bike.new(Vector2(10, 10))
	w.hero.mode = Hero.Mode.RIDING
	check(not w.skating.mount().ok, "nor on the bike")
	w.hero.stand()
	w.skating.mount()
	check(not w.riding.mount().ok, "and the bike won't take you while you are on the board")


func test_it_rolls_up_to_a_top_speed_and_slows_down() -> void:
	var w := _rider()
	w.skating.mount()
	_roll(w, 0.5)
	check(w.skating.speed > 2.0 and w.skating.speed < Skating.TOP_SPEED, "pushing builds speed (%.1f m/s after half a second)" % w.skating.speed)
	_roll(w, 5.0)
	check(is_equal_approx(w.skating.speed, Skating.TOP_SPEED), "up to a top speed and no more")
	_roll(w, 1.0, {"brake": true})
	var braked: float = w.skating.speed
	check(braked < 1.0, "braking stops it quickly (%.1f)" % braked)
	_roll(w, 4.0)
	_roll(w, 2.0, {})
	check(w.skating.speed < Skating.TOP_SPEED and w.skating.speed > 0.0, "and with no push it coasts down slowly (%.1f)" % w.skating.speed)
	_roll(w, 20.0, {})
	check(w.skating.speed == 0.0 and w.skating.step(0.05, {}, true, Vector2.ZERO).speed >= 0.0, "to a stop: it never rolls backwards")


func test_steering_turns_you_more_when_you_are_moving() -> void:
	var w := _rider()
	w.skating.mount()
	var still := (w.skating.step(0.05, {"steer": 1.0}, true, Vector2.ZERO)).turn as float
	_roll(w, 3.0)
	var moving := (w.skating.step(0.05, {"steer": 1.0, "push": true}, true, Vector2.ZERO)).turn as float
	var right := (w.skating.step(0.05, {"steer": -1.0, "push": true}, true, Vector2.ZERO)).turn as float
	check(still > 0.0 and moving > still and is_equal_approx(moving, Skating.TURN_RATE), "you can turn a little standing still and fully at speed (%.2f, %.2f)" % [still, moving])
	check(right < 0.0 and is_equal_approx(right, -moving), "and right is the other way")


func test_hold_space_and_let_go_for_an_ollie_that_is_higher_the_longer_you_hold() -> void:
	var w := _rider()
	w.skating.mount()
	var jump_after := func(hold: float) -> float:
		w.skating.dismount()
		w.skating.mount()
		for i in int(hold / 0.05):
			var held: Dictionary = w.skating.step(0.05, {"jump_down": true}, true, Vector2.ZERO)
			if held.jump > 0.0:
				return -1.0  # it must not launch while the key is down
		var out: Dictionary = w.skating.step(0.05, {"jump_down": false}, true, Vector2.ZERO)
		return out.jump
	var tap: float = jump_after.call(0.05)
	var half: float = jump_after.call(0.2)
	var full: float = jump_after.call(0.45)
	var forever: float = jump_after.call(2.0)
	check(tap >= Skating.OLLIE_MIN and tap < half and half < full, "a tap is a small hop, holding longer goes higher (%.1f, %.1f, %.1f)" % [tap, half, full])
	check(is_equal_approx(full, Skating.OLLIE_MAX) and is_equal_approx(forever, Skating.OLLIE_MAX), "a full charge is the highest, and holding on longer does not add more")
	check(w.skating.ollies == 4 and w.skating.in_air, "each counts as an ollie, and you are in the air")
	check(w.skating.step(0.05, {}, true, Vector2.ZERO).jump == 0.0, "nothing more launches until you jump again")


func test_a_second_press_in_the_air_is_a_kickflip_that_sprays_25_dollars() -> void:
	var w := _rider()
	w.skating.mount()
	w.skating.step(0.05, {"jump_down": true}, true, Vector2(10, 10))
	var up: Dictionary = w.skating.step(0.05, {}, true, Vector2(10, 10))
	check(up.jump > 0.0 and not up.flip, "an ollie first")
	var printed_before := w.ledger.printed
	var total_before := w.ledger.total(w.drones, w.bills) + 0.0
	var flip: Dictionary = w.skating.step(0.05, {"jump_pressed": true}, false, Vector2(10, 10))
	check(flip.flip and w.skating.kickflips == 1 and w.skating.last_trick.begins_with("Kickflip"), "tapping jump again in the air is a kickflip")
	check(is_equal_approx(w.ledger.printed - printed_before, 25.0), "it prints $25")
	var loose := 0.0
	var piles := 0
	for b in w.bills:
		if b.loose:
			loose += b.value
			piles += 1
			check_quiet_near(b, Vector2(10, 10))
	check(is_equal_approx(loose, 25.0) and piles == 5, "and it lies on the ground round you, in five piles ($%.0f in %d)" % [loose, piles])
	check(is_equal_approx(w.ledger.total(w.drones, w.bills) - total_before, 25.0), "the money is all accounted for: the world total grew by exactly what was printed")
	var again: Dictionary = w.skating.step(0.05, {"jump_pressed": true}, false, Vector2(10, 10))
	check(not again.flip and w.skating.kickflips == 1, "only one kickflip a jump")
	w.skating.step(0.05, {}, true, Vector2(10, 10))
	var next: Dictionary = {}
	w.skating.step(0.05, {"jump_down": true}, true, Vector2(10, 10))
	w.skating.step(0.05, {}, true, Vector2(10, 10))
	next = w.skating.step(0.05, {"jump_pressed": true}, false, Vector2(10, 10))
	check(next.flip and w.skating.kickflips == 2, "after landing you can do it again")


func check_quiet_near(b: Bill, at: Vector2) -> void:
	if b.pos.distance_to(at) > 3.0 or b.pos.distance_to(at) < 0.5:
		check(false, "a bill landed %.1f m away: outside the ring round the board" % b.pos.distance_to(at))


func test_no_kickflip_on_the_ground_and_none_walking_off_nothing() -> void:
	var w := _rider()
	w.skating.mount()
	var out: Dictionary = w.skating.step(0.05, {"jump_pressed": true}, true, Vector2.ZERO)
	check(not out.flip and w.skating.kickflips == 0 and w.ledger.printed == 100.0, "pressing jump on the ground is just the start of a charge, not a trick")
	var off: Dictionary = w.skating.step(0.05, {"jump_pressed": true}, false, Vector2.ZERO)
	check(off.flip, "but rolling off a ledge and pressing jump is a kickflip: you are in the air")
