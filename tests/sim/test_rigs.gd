## Sim tests: what runners haul with (Runner.TIERS): buying the next rig at dawn (Trades), what it carries and how fast it
## goes, and the round of bins further out that it opens up (World.open_round).
extends TestCase


## A funded atom with a map round it: food in waste baskets and an organics bin, a fountain, some near and some far.
func _town() -> World:
	var w := World.new()
	var city := Fixtures.grown_atom(w)
	Cluster.fund(w, "atom")
	var points: Array = []
	for spot in [["bin", 60], ["bin", 120], ["bin", 200], ["bin", 260], ["organics", 150], ["fountain", 180], ["fountain", 320], ["bin", 500], ["bin", 20]]:
		points.append({"kind": spot[0], "at": city.pos + Vector2(spot[1], 30)})
	var district := {"roads": [{"pts": [-600.0, 0.0, 600.0, 0.0], "w": 6.0}], "street": {"points": points}}
	w.rounds = SiteFinder.rounds(district, "atom", city.pos, WasteBin.far_kinds(), WasteBin.FAR_MOST)
	w.begin_play()
	return w


func _runner(w: World) -> Drone:
	return w.zones.runners_in("atom")[0]


func test_a_round_is_the_nearest_places_of_the_map_by_turns() -> void:
	var w := _town()
	var city: Machine = Fixtures.tent_city(w, "atom")
	check(w.rounds.size() >= 6 and w.rounds.all(func(r): return r.walk >= SiteFinder.ROUND_FROM), "places to fetch from, none by the market itself (%d)" % w.rounds.size())
	var first: Array = w.rounds.slice(0, 3).map(func(r): return r.kind)
	check(first == ["organics", "fountain", "garbage"], "food, water and scrap take turns at the nearest (%s)" % [first])
	check(["organics", "fountain", "garbage"].all(func(k): return w.rounds.filter(func(r): return r.kind == k).size() <= WasteBin.FAR_MOST), "no more of a kind than the most")
	check(w.rounds.filter(func(r): return r.kind == "organics").any(func(r): return is_equal_approx(r.walk, (Vector2(60, 30)).length())), "a waste basket further out gives food too, where the map has no organics bin")


func test_a_runner_buys_a_bike_at_dawn_once_they_can() -> void:
	var w := _town()
	var d := _runner(w)
	var bins := w.bins.size()
	w.levels.give(d, 65.0 - d.wallet)
	check(d.runner.tier == 0 and not w.trades.can_trade_up(d) and w.profession_of(d) == "Cart runner", "$65 is a bike but no reserve: not yet")
	w.levels.give(d, 10.0)
	var sunk := w.ledger.sunk
	for i in int(Clock.DAY_SECONDS) + 2:
		w.tick(1.0)
		if d.runner.tier > 0:
			break
	check(d.runner.tier == 1 and w.ledger.sunk - sunk >= 60.0 and is_equal_approx(w.total_money(), w.ledger.printed), "at dawn they buy it: $60, spent, and the books balance")
	check(d.speed > 4.0 and int(d.runner.rig().load) == 40 and w.profession_of(d) == "Bike courier", "faster, a bigger load, and a new name for what they do")
	check(d.runner.book_value() == Runner.CART_VALUE + 60.0 and w.events.any(func(e): return e.contains("bought a pedal bike")), "their business is worth more, and the feed says so")
	var out: Array = w.bins.slice(bins)
	check(out.size() >= 5 and out.all(func(b): return b.far > 0.0 and b.far <= 350.0 and b.rate > 0.0), "the places within its reach have bins now (%d), none past it" % out.size())
	check(w.open_round("atom", 350.0).is_empty(), "and once opened, a round is not opened again")


func test_only_a_rig_that_reaches_a_bin_fetches_from_it() -> void:
	var w := _town()
	var d := _runner(w)
	w.open_round("atom", 350.0)
	for b in w.bins:
		if b.far <= 0.0:
			b.output.take(b.item, b.output.count(b.item))
			b.rate = 0.0
			b.refresh()
	for m in w.machines:
		m.input.counts.clear()
	check(w.logistics.hauling.haul_job(d).is_empty(), "with the near bins bare, someone pushing a cart has nothing to fetch")
	d.wallet = 100.0
	w.trades.trade_up(d)
	var job := w.logistics.hauling.haul_job(d)
	check(not job.is_empty() and job.target is WasteBin and job.target.far > 0.0, "on a bike they go out for it")
	check(job.qty > 16 or job.qty == job.target.output.count(job.item) or job.qty == job.dest.input.room(job.item), "and bring back more than a cart holds, if there is more to bring and room for it (%d)" % job.get("qty", 0))


func test_a_pile_at_a_new_camp_leaves_the_rounds_supply_alone() -> void:
	var w := _town()
	w.open_round("atom", 350.0)
	var far: WasteBin = w.bins.filter(func(b): return b.kind == "garbage" and b.far > 0.0)[0]
	var rate := far.rate
	w.lodging._share("atom", "garbage")
	check(is_equal_approx(far.rate, rate), "the near bins share their rate among themselves; a round's is its own")


func test_a_save_keeps_the_rig_and_the_round() -> void:
	var w := _town()
	var d := _runner(w)
	d.wallet = 100.0
	w.trades.trade_up(d)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var fresh := _town()
	Snapshot.new(fresh).apply(doc)
	var again := _runner(fresh)
	check(again.runner.tier == 1 and is_equal_approx(again.speed, d.speed), "still on the bike")
	check(fresh.bins.size() == w.bins.size() and fresh.bins.filter(func(b): return b.far > 0.0).size() == w.bins.filter(func(b): return b.far > 0.0).size(), "with the same bins out on the round")
