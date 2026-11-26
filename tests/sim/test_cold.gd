## Sim tests: the cold, for the hero (see Cold). Without clothes a full warmth bar lasts about two blocks' walk by day and under
## one at night; clothes stretch it; a fire still warms them up in moments. The street's own people are hardened to it.
extends TestCase


## How far the hero gets walking straight out from a barrel fire, from a full bar to nothing. In blocks.
func _reach(night: bool, wear: Array = []) -> float:
	var w := World.new()
	var p := w.add_player(Vector2.ZERO)
	for item in wear:
		p.gear.add(item, 1)
	w.add_fire(Vector2(-1, 0))
	w.clock.time = (Clock.NIGHT_FROM + 0.05 if night else 0.3) * Clock.DAY_SECONDS
	for n in ["hunger", "thirst"]:
		p.bars[n] = 1.0
	var dt := 0.1
	while p.bars.warmth > 0.0 and p.pos.x < 20.0 * Cold.BLOCK:
		p.pos.x += Cold.WALK * dt
		w.tick(dt)
	return p.pos.x / Cold.BLOCK


func test_by_day_the_hero_gets_about_two_blocks() -> void:
	var r := _reach(false)
	check(r > 1.8 and r < 2.4, "out from a fire, walking, by day: %.2f blocks before the warmth runs out" % r)


func test_at_night_less_than_one() -> void:
	var r := _reach(true)
	check(r >= 0.5 and r <= 1.0, "at night: %.2f blocks" % r)


func test_clothes_go_further() -> void:
	var bare := _reach(true)
	var old := _reach(true, ["old_coat"])
	var coat := _reach(true, ["coat"])
	check(old > bare * 1.3 and coat > old * 1.5, "at night: %.2f blocks bare, %.2f in an old coat, %.2f in a coat" % [bare, old, coat])
	var w := World.new()
	var p := w.add_player(Vector2.ZERO)
	for item in ["coat", "coat"]:
		p.gear.add(item, 1)
	check(is_equal_approx(p.insulation(), Drone.MAX_INSULATION), "however many coats, the cold still gets in (%.2f)" % p.insulation())


func test_a_fire_warms_the_hero_up_in_moments() -> void:
	var w := World.new()
	var p := w.add_player(Vector2(1, 0))
	w.add_fire(Vector2.ZERO)
	w.clock.time = (Clock.NIGHT_FROM + 0.05) * Clock.DAY_SECONDS
	p.bars.warmth = 0.2
	Fixtures.run(w, 10)
	check(p.bars.warmth > 0.95, "ten seconds beside a fire at night and they are warm again (%.2f)" % p.bars.warmth)
	p.pos = Vector2(4, 0)
	var before: float = p.bars.warmth
	Fixtures.run(w, 5)
	check(p.bars.warmth < before, "but four metres off, at night, it doesn't keep up with the cold (%.2f -> %.2f)" % [before, p.bars.warmth])


func test_the_feed_warns_as_it_gets_cold() -> void:
	var w := World.new()
	var p := w.add_player(Vector2(500, 0))
	w.clock.time = 0.3 * Clock.DAY_SECONDS
	Fixtures.run(w, 40)
	check(w.events.any(func(e): return "getting cold" in e), "the feed says so when the warmth falls past %d%%" % roundi(Hero.COLD_WARNING * 100.0))


func test_the_street_is_hardened_to_it() -> void:
	var w := World.new()
	var d := w.add_drifter(Vector2(500, 0), 5.0)
	d.aloof = true
	w.clock.time = 0.3 * Clock.DAY_SECONDS
	d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	Fixtures.run(w, 60)
	check(is_equal_approx(d.bars.warmth, 1.0 - 60.0 / Needs.DAY_COOLING), "a minute in the open costs a drifter a thirtieth of the bar, as ever (%.3f)" % d.bars.warmth)


func test_the_atom_has_a_fire() -> void:
	var w := World.new(false)
	Atom.seed(w, "atom", Vector2.ZERO)
	check(w.fires.size() == 1, "an atom has a barrel fire by its market")
