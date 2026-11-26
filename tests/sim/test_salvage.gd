## Sim tests: scrap and the homeless camps (see WasteBin, Camp). Scrap gathers in the garbage bins, free; runners gather it and pool it
## into what wants it: a camp's input, or a tent city being built up into a hostel. A camp sells the hero cheap, slow boards, and
## built up of scrap, cheap, slow bikes.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


## A camp with its pile, a runner, and the hero beside the counter with `cash`.
func _camp(cash := 100.0) -> Array:
	var w := World.new()
	var camp := Camp.pitch(w, Vector2.ZERO, Vector2(0, 1), 50.0)
	var runner := w.add_runner(Vector2(4, 3), 5.0)
	w.add_player(camp.pos + camp.front * 2.0, 0.0)
	w.player.carry.counts.clear()
	w.player.make_needless()  # (the hero waits about while the camp works: these tests are not about the hero's hunger)
	w.ledger.player_cash = cash
	w.ledger.printed += cash
	for d in w.drones:
		d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	return [w, camp, runner]


func test_scrap_gathers_in_the_garbage() -> void:
	var w := World.new()
	var pile := w.add_bin("garbage", Vector2.ZERO, 0)
	var k: Dictionary = WasteBin.KINDS.garbage
	w.add_drifter(Vector2(5, 0)).make_needless()  # (someone about, so the zone runs)
	Fixtures.run(w, 600)
	check(pile.output.count("scrap") == int(k.rate * 10), "a garbage bin gathers %d scrap in ten minutes" % pile.output.count("scrap"))
	Fixtures.run(w, 6000)
	check(pile.output.count("scrap") == k.cap, "up to %d" % k.cap)
	check("scrap" in Catalog.scavenged_goods() and is_equal_approx(pile.price_of("scrap"), 0.0) and Catalog.base_price("scrap") == 0.0, "it is free, and worth nothing to the fund")


func test_a_runner_gathers_scrap_for_the_camp() -> void:
	var c := _camp()
	var w: World = c[0]
	var camp: Machine = c[1]
	var runner: Drone = c[2]
	var job := w.logistics.hauling.haul_job(runner)
	check(not job.is_empty() and job.target is WasteBin and job.dest == camp and job.item == "scrap", "the runner plans a trip: the garbage bin to the camp")
	var keeper := w.drone(camp.owner)
	var wallet := keeper.wallet
	Fixtures.run(w, 300, true)
	check(camp.input.count("scrap") > 0 or camp.crafted_total > 0, "the scrap reaches the camp (%d in hand, %d boards made)" % [camp.input.count("scrap"), camp.crafted_total])
	check(runner.runner.delivered_total > 0 and keeper.wallet < wallet and _accounted(w), "the keeper pays the runner the fee for it, and nothing else: the scrap is free")


func test_the_camp_sells_a_cheap_slow_board() -> void:
	var c := _camp()
	var w: World = c[0]
	var camp: Machine = c[1]
	Fixtures.run(w, 900, true)
	check(camp.offers("old_skateboard"), "the camp has put an old board together")
	var r: Dictionary = w.commerce.buy(camp, "old_skateboard")
	check(r.ok and w.player.gear.count("old_skateboard") == 1 and is_equal_approx(w.ledger.player_cash, 100.0 - Catalog.item("old_skateboard").price), "the hero buys it for $%.0f, into the loadout: %s" % [Catalog.item("old_skateboard").price, r.text])
	check(w.skating.why_not() == "", "and can ride it")
	check(is_equal_approx(w.skating.top_speed(), Skating.TOP_SPEED * Catalog.item("old_skateboard").speed), "but it is slow: %.1f m/s flat out" % w.skating.top_speed())
	w.player.gear.add("skateboard", 1)
	check(is_equal_approx(w.skating.top_speed(), Skating.TOP_SPEED), "with a shop's board too, the good one is ridden")


func test_scrap_builds_the_camp_up_into_a_bike_camp_and_its_bike_is_slow() -> void:
	var c := _camp(500.0)
	var w: World = c[0]
	var camp: Machine = c[1]
	camp.input.add("scrap", camp.input.room("scrap"))
	var pooled := camp.input.count("scrap")
	w.trades.day = -1
	w.trades.step(1.0)
	var built_of: int = Catalog.machine("bike_camp").build_goods.scrap
	check(camp.kind == "bike_camp" and camp.input.count("scrap") == pooled - built_of, "with %d scrap pooled into it, the camp is built up into a bike camp, and the scrap is used" % built_of)
	check(w.events.back().contains("scrap") and is_equal_approx(w.ledger.sunk, 0.0), "of scrap, not money")
	Fixtures.run(w, 900, true)
	check(camp.offers("old_bike"), "it puts an old bike together")
	var r: Dictionary = w.commerce.buy(camp, "old_bike")
	check(r.ok and w.riding.bike() == "old_bike", "the hero buys it: %s" % r.text)
	var on := w.riding.mount()
	check(on.ok and w.riding.speed_factor() > 1.0 and w.riding.speed_factor() < Riding.RIDE_FACTOR, "it is faster than walking but slower than a shop's bike (x%.2f; %s)" % [w.riding.speed_factor(), on.text])


func test_slow_runners_build_a_tent_city_up_with_scrap() -> void:
	var w := World.new(false)
	var city := Fixtures.grown_atom(w)
	w.begin_play()
	Cluster.fund(w, "atom")
	var wares := city.per_craft("scrap") * Catalog.machine("tent").stock_crafts
	check(city.input.caps.get("scrap", 0) == Catalog.machine("hostel").build_goods.scrap + wares, "a tent city wants the scrap its hostel is built of, and its tents' and barrels' (%d)" % city.input.caps.get("scrap", 0))
	var day := Fixtures.until(w, func(): return city.kind == "hostel", int(Clock.DAY_SECONDS) * 60)  # (about day 51: docs/balance.md)
	check(day > 0, "the runner pools it in from the street, and it is built up into a hostel (day %d)" % (day / int(Clock.DAY_SECONDS) + 1))
	check(w.lodging.room_for(city) == Atom.size() and _accounted(w), "with room for an atom's worth more")
