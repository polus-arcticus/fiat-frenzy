## Sim tests: the hero's mode. One at a time: on foot, on the bike, on the board, in a seat.
extends TestCase


func _hero_with_everything() -> World:
	var w := World.new()
	w.add_player(Vector2(10, 10), 100.0)
	w.player.carry.add("skateboard", 1)
	w.bike = Bike.new(Vector2(10, 10))
	return w


func test_the_hero_starts_on_foot_and_changes_mode_through_one_door() -> void:
	var w := _hero_with_everything()
	check(w.hero.is_on_foot() and w.hero.why_not(Hero.Mode.RIDING) == "", "on foot, and free to get on a bike")
	check(w.riding.mount().ok and w.hero.mode == Hero.Mode.RIDING and w.riding.riding(), "mounting the bike puts the hero in riding mode")
	check(not w.skating.mount().ok and not w.skating.mounted, "and while riding they cannot get on the board")
	check(w.skating.why_not() == "Get off the bike first.", "(and are told why)")
	w.riding.dismount()
	check(w.hero.is_on_foot() and w.skating.mount().ok and w.hero.mode == Hero.Mode.SKATING, "off the bike, the board takes them")
	check(not w.riding.mount().ok and w.riding.mount().text == "Get off the skateboard first.", "and the bike won't while skating")
	w.skating.dismount()
	check(w.hero.is_on_foot(), "getting off the board puts them back on foot")


func test_a_seated_hero_neither_rides_nor_skates_and_standing_frees_them() -> void:
	var w := _hero_with_everything()
	check(w.hero.enter(Hero.Mode.SEATED) == "" and w.hero.mode == Hero.Mode.SEATED, "they can sit")
	check(not w.riding.mount().ok and not w.skating.mount().ok, "seated, no bike and no board")
	w.hero.stand()
	check(w.riding.mount().ok, "standing frees them")


func test_an_unconscious_hero_cannot_change_mode() -> void:
	var w := _hero_with_everything()
	w.player.care = "down"
	check(w.hero.enter(Hero.Mode.RIDING) == "You're out cold." and w.hero.is_on_foot(), "out cold, they stay as they are")
	check(w.hero.enter(Hero.Mode.ON_FOOT) == "", "but going back on foot is always allowed")


func test_the_bike_does_not_carry_its_own_riding_flag() -> void:
	var w := _hero_with_everything()
	w.riding.mount()
	check(w.riding.riding() and w.riding.speed_factor() > 2.0, "the mode alone says they are riding")
	w.hero.stand()
	check(not w.riding.riding() and w.riding.speed_factor() == 1.0, "and clearing it ends it, with nothing left to fall out of step")
