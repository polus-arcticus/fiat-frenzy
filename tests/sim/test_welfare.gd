## Sim tests: the welfare office's money fountain (see Welfare). Every test checks that the money is all accounted for: what
## is in the world is what was printed (by the gun, the seed, or the fountain).
extends TestCase


## The standard cluster as it is found, its stalls wrecked and its vendors broke; the hero pays each vendor's repair once.
func _funded_town() -> World:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "town")
	return w


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


## Four people with nothing to buy, fed by hand (someone who collapses is not a resident), and an office.
func _street(n := 4) -> Array:
	var w := World.new()
	var people := []
	for i in n:
		people.append(w.add_drifter(Vector2(i * 2.0, 0), 0.0))
	var clerk := w.add_welfare_office(Vector2(10, 0))
	w.ledger.printed = w.total_money()
	return [w, people, clerk]


func _days(w: World, people: Array, days: int) -> void:
	for i in int(Clock.DAY_SECONDS) * days:
		for d in people:
			d.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
		w.tick(1.0)


func test_the_fountain_gives_about_its_rate_and_it_is_accounted_for() -> void:
	var s := _street()
	var w: World = s[0]
	_days(w, s[1], 5)
	var most := Welfare.DOLLARS_A_DAY * 4 * 5
	var given: float = w.welfare_offices[0].given_out
	check(given > 0.0 and given <= most * 1.4, "in five days it gives out at most about $%.0f for 4 people ($%.2f)" % [most, given])
	check(s[1].all(func(d): return d.wallet < Welfare.ENOUGH + Welfare.GIFT_MAX), "and only until they have enough: a net, not savings (%s)" % [s[1].map(func(d): return roundi(d.wallet))])
	check(is_equal_approx(w.ledger.issued, w.welfare_offices[0].given_out), "all of it new money here: no food bank, no gifts to the clerk")
	check(s[1].all(func(d): return d.wallet > 0.0), "and everyone got some, at random (%s)" % [s[1].map(func(d): return d.wallet)])
	check(_accounted(w), "counted as printed")


func test_who_has_enough_gets_nothing() -> void:
	var s := _street()
	var w: World = s[0]
	for d in s[1]:
		d.wallet += Welfare.ENOUGH
	w.ledger.printed = w.total_money()
	_days(w, s[1], 2)
	check(is_equal_approx(w.welfare_offices[0].given_out, 0.0), "with a few days' food money each, nobody is given anything ($%.2f)" % w.welfare_offices[0].given_out)


func test_the_food_banks_takings_go_out_before_anything_is_printed() -> void:
	var s := _street()
	var w: World = s[0]
	var keeper := w.add_food_bank(Vector2(-10, 0), Welfare.TILL_FLOAT + 500.0)
	keeper.make_needless()
	w.ledger.printed = w.total_money()
	_days(w, s[1], 2)
	check(w.welfare_offices[0].given_out > 0.0 and is_equal_approx(w.ledger.issued, 0.0), "it gave out $%.2f, none of it new" % w.welfare_offices[0].given_out)
	check(is_equal_approx(keeper.wallet, Welfare.TILL_FLOAT + 500.0 - w.welfare_offices[0].given_out), "it came out of the food bank's till")
	check(_accounted(w), "nothing made or lost")


func test_the_poor_are_likelier_to_get_it() -> void:
	var s := _street(6)
	var w: World = s[0]
	for i in 3:
		s[1][i].wallet = 1000.0  # three who are fine
	w.ledger.printed = w.total_money()
	_days(w, s[1], 3)
	var to_poor := 0.0
	for i in range(3, 6):
		to_poor += s[1][i].wallet
	check(to_poor > 0.7 * w.welfare_offices[0].given_out, "most of it ($%.2f of $%.2f) went to the three who had nothing" % [to_poor, w.welfare_offices[0].given_out])
	check(_accounted(w), "nothing made or lost")


func test_a_funded_town_keeps_itself_going_without_the_hero() -> void:
	var w := _funded_town()
	var worst := 1 << 30
	var leaks := 0
	for day in 5:
		var before := Fixtures.sold(w, "town")
		for s in int(Clock.DAY_SECONDS):
			w.tick(1.0)
			if not _accounted(w):
				leaks += 1
		worst = mini(worst, Fixtures.sold(w, "town") - before)
	var down := w.events.filter(func(e): return "collapsed" in e).size()
	check(worst >= 40, "five days on its own, it sells at least 40 things every day (the worst day: %d)" % worst)
	check(down <= 1, "and nobody goes to the medical tent, near enough (%d collapses in five days)" % down)
	check(leaks == 0, "the money is accounted for on every tick (%d off)" % leaks)
	check(w.welfare_offices[0].given_out > 0.0, "the welfare office gave out $%.2f" % w.welfare_offices[0].given_out)


func test_two_saves_with_welfare_offices_merge() -> void:
	var build := func(tiles: Array) -> World:
		var w := World.new()
		for t in tiles:
			w.zones.add_tile(t)
			Fixtures.market_town(w, t, TileKey.rect(t).get_center(), 6, true, 40.0)
			w.add_welfare_office(TileKey.rect(t).get_center() + Vector2(-14, -10))
		return w
	var t0 := TileKey.parse(TileKey.of(50.1086307, 8.6687641))
	var a: World = build.call([TileKey.key(t0.x, t0.y)])
	var b: World = build.call([TileKey.key(t0.x + 1, t0.y)])
	for w in [a, b]:
		w.add_player(Vector2.ZERO, 10.0)
		w.begin_play()
		for i in 1300:
			w.tick(1.0)
	var m := Merge.combine(Snapshot.new(a).capture(), Snapshot.new(b).capture(), build)
	check(m.welfare_offices.size() == 2, "both welfare offices are there")
	check(is_equal_approx(m.total_money(), a.total_money() + b.total_money()) and _accounted(m), "with every dollar of both saves ($%.2f)" % m.total_money())
	check(is_equal_approx(m.ledger.issued, a.ledger.issued + b.ledger.issued), "and what each was issued")
	var given := m.welfare_offices.map(func(o): return o.given_out)
	check(is_equal_approx(given[0] + given[1], a.welfare_offices[0].given_out + b.welfare_offices[0].given_out), "and what each gave out")
