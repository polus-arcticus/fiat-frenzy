## Sim tests: money on the floor of the bus. It lies where it fell in the bus's own frame and goes where the bus goes, nobody
## but the hero takes it, and it all adds up.
extends TestCase


func _riding() -> World:
	var w := World.new()
	w.add_player(Vector2(0, 0), 0.0)
	w.add_bus(Vector2(0, 0), 0.0)  # at the origin, pointing along +x
	return w


func test_the_bus_has_its_own_coordinates() -> void:
	var w := _riding()
	var bus := w.bus
	check(bus.to_world(Vector2(0, 3)).is_equal_approx(Vector2(3, 0)), "along the bus is the way it points (y is the front)")
	check(bus.to_world(Vector2(1, 0)).is_equal_approx(Vector2(0, -1)), "x is across: positive is to the left of the way it is going, as the view has it")
	bus.pos = Vector2(40, 10)
	bus.heading = 0.7
	var spot := Vector2(0.6, -2.0)
	check(bus.to_local(bus.to_world(spot)).is_equal_approx(spot), "to the world and back gives the same spot, wherever the bus is and however it points")
	check(Bus.on_the_floor(Vector2(50, -50)).x < Bus.WIDTH * 0.5 and Bus.on_the_floor(Vector2(50, -50)).y > -Bus.LENGTH * 0.5, "a spot in a wall is brought in onto the floor")


func test_a_bill_on_the_floor_goes_where_the_bus_goes() -> void:
	var w := _riding()
	var b := w.gun.land_aboard(w.gun.fire(10.0, "cash"), Vector2(0.4, -1.5))
	check(b.aboard and b.loose and b.pos.is_equal_approx(w.bus.to_world(Vector2(0.4, -1.5))), "it lies on the floor, where it fell")
	check(w.transit.board(Vector2(300, 0)), "the bus sets off")
	for i in 400:
		w.tick(0.1)
	check(w.bus.pos.x > 40.0, "and drives a good way (%.0f m)" % w.bus.pos.x)
	check(b.local.is_equal_approx(Vector2(0.4, -1.5)) and b.pos.is_equal_approx(w.bus.to_world(b.local)), "the bill is still on the same spot of the floor, so it has gone with the bus")
	check(w.bills.has(b) and b.pos.distance_to(Vector2(0.4, -1.5)) > 40.0, "and not left in the street behind it")


func test_nobody_but_the_hero_takes_it() -> void:
	var w := _riding()
	w.add_vendor("hot_dog_stand", Vector2(-20, 0), 10.0)  # (so there is a grid and a town)
	var d := w.add_drifter(Vector2(0.5, -1.0), 0.0)
	var b := w.gun.land_aboard(w.gun.fire(10.0, "cash"), Vector2(0.4, -1.0))
	check(w.cash.nearest_loose(d.pos, 14.0, "district") == null, "a drifter right beside it does not see it as loose money in the street")
	for i in 100:
		w.tick(0.1)
	check(w.bills.has(b) and d.wallet == 0.0, "and does not pick it up")
	var before := w.ledger.player_cash
	w.player.pos = w.bus.to_world(Vector2(0.4, -1.0))
	check(w.cash.collect_for_player() == 10.0 and not w.bills.has(b) and w.ledger.player_cash == before + 10.0, "but the hero, standing by it, does")


func test_getting_off_gathers_what_is_on_the_floor() -> void:
	var w := _riding()
	var printed := w.ledger.printed
	w.gun.land_aboard(w.gun.fire(5.0, "cash"), Vector2(0.3, 3.0))
	w.gun.land_aboard(w.gun.fire(7.0, "cash"), Vector2(-0.4, -4.0))
	var street := w.gun.land(w.gun.fire(3.0, "cash"), Vector2(50, 50))
	var before := w.ledger.player_cash
	check(w.cash.scoop_aboard() == 12.0 and w.ledger.player_cash == before + 12.0, "the bills on the bus's floor all go to the hero ($12)")
	check(w.bills.has(street) and w.bills.size() == 1, "and the one in the street is left")
	check(w.ledger.printed - printed == 15.0, "the money still adds up: $15 was printed, $12 in the hero's pocket, $3 in the street")


func test_bills_that_land_together_make_a_pile() -> void:
	var w := _riding()
	var a := w.gun.land_aboard(w.gun.fire(5.0, "cash"), Vector2(0.2, 1.0))
	var b := w.gun.land_aboard(w.gun.fire(5.0, "cash"), Vector2(0.3, 1.2))
	check(a == b and a.value == 10.0 and w.bills.size() == 1, "two that fall together are one pile of $10")
