## Sim tests: the warm indoors: a shop, the sage's house, the bus.
extends TestCase


func _night_world() -> World:
	var w := World.new()
	w.clock.time = 0.9 * Clock.DAY_SECONDS  # night
	w.add_player(Vector2(100, 100), 0.0)
	return w


func _cool(w: World, d: Drone, seconds: int) -> float:
	d.bars.warmth = 0.5
	for i in seconds:
		w.needs.decay(d, 1.0)
	return d.bars.warmth


func test_indoors_is_warm_and_outdoors_is_cold_at_night() -> void:
	var w := _night_world()
	check(w.clock.is_night(), "(it is night)")
	w.heating.add_building(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]))
	var outside := w.add_drifter(Vector2(20, 5), 0.0)
	var inside := w.add_drifter(Vector2(5, 5), 0.0)
	var cold := _cool(w, outside, 60)
	var warm := _cool(w, inside, 60)
	check(cold < 0.5, "outside, at night, the cold wins (%.2f)" % cold)
	check(warm > 0.5, "inside a shop, they warm up (%.2f)" % warm)
	check(w.heating.is_warm(Vector2(5, 5)) and not w.heating.is_warm(Vector2(11, 5)), "the walls are where the warmth stops")
	w.player.pos = Vector2(5, 5)
	var hero := _cool(w, w.player, 60)
	check(hero > 0.5, "and the hero warms up in there too (%.2f)" % hero)


func test_the_bus_is_warm_while_you_are_in_it() -> void:
	var w := _night_world()
	w.add_bus(Vector2(50, 50), 0.0)  # pointing along +x
	w.player.pos = Vector2(50, 50)
	check(w.heating.is_warm(Vector2(54, 50)) and w.heating.is_warm(Vector2(46, 50.8)), "inside the bus's length and width")
	check(not w.heating.is_warm(Vector2(50, 53)) and not w.heating.is_warm(Vector2(57, 50)), "and not beside it or past its ends")
	var aboard := _cool(w, w.player, 60)
	check(aboard > 0.5, "riding it, the hero warms up (%.2f)" % aboard)
	w.bus.pos = Vector2(300, 300)  # the bus drives away without them
	check(not w.heating.is_warm(w.player.pos) and _cool(w, w.player, 60) < 0.5, "left behind in the street, they are cold again")
	w.bus.pos = Vector2(100, 100)
	w.bus.heading = PI * 0.5  # turned: its length now runs along y
	check(w.heating.is_warm(Vector2(100, 104)) and not w.heating.is_warm(Vector2(104, 100)), "it is warm along the bus's own length, however it is turned")


func test_two_warm_places_at_once_do_not_double_it() -> void:
	var w := _night_world()
	var square := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	w.heating.add_building(square)
	w.heating.add_building(square)
	check(is_equal_approx(w.heating.gain_at(Vector2(5, 5)), Heating.GAIN) and w.heating.gain_at(Vector2(50, 5)) == 0.0, "one indoors rate, however many places overlap")
