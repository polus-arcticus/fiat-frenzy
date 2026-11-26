## Sim tests: the deposit (see Deposit, Collecting). Whoever is short of cash collects bottles from the recycling and hands them
## in at the bottle depot; the depot pays out of the town's fund first, and prints only when it is empty. Every test checks that
## the money is all accounted for: what is in the world is what was printed.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


## A street with a recycling bin and a depot, and `n` people with `wallet` each: [w, people, depot, bin].
func _street(n := 1, wallet := 0.0) -> Array:
	var w := World.new()
	var people := []
	for i in n:
		people.append(w.add_drifter(Vector2(i * 2.0, 0), wallet))
	w.add_bottle_depot(Vector2(-12, 0))
	var bin := w.add_bin("recycling", Vector2(12, 0), 60)
	w.ledger.printed = w.total_money()
	return [w, people, w.bottle_depots[0], bin]


func test_the_depot_pays_out_of_its_fund_first() -> void:
	var s := _street()
	var w: World = s[0]
	var depot: BottleDepot = s[2]
	var who: Drone = s[1][0]
	var till := w.deposit.attendant(depot)
	till.wallet = 2.0
	w.ledger.printed = w.total_money()
	var paid := w.deposit.redeem(who, depot, 20)
	check(is_equal_approx(paid, 20 * Deposit.DEPOSIT) and is_equal_approx(who.wallet, paid), "twenty bottles are $%.2f, a quarter each" % paid)
	check(is_equal_approx(till.wallet, 0.0) and is_equal_approx(w.ledger.issued, paid - 2.0), "the $2 in the fund went first, and only the rest is new money ($%.2f)" % w.ledger.issued)
	check(depot.taken_in == 20 and is_equal_approx(depot.paid_out, paid) and _accounted(w), "the depot counts what it took in and paid out, and the books balance")
	check(w.deposit.fund("anywhere") == till, "the town's fund is its attendant's till (the home depot's, where a zone has none)")


func test_someone_broke_collects_and_is_paid() -> void:
	var s := _street()
	var w: World = s[0]
	var who: Drone = s[1][0]
	var bin: WasteBin = s[3]
	who.bars = Fixtures.bars(1.0, 1.0, 1.0)
	check(w.needs.demands(who) == ["collect"], "broke, with nothing else to want, they go collecting")
	var job := w.logistics.plan(who)
	check(job["for"] == "collect" and job.stage == "pickup" and job.target == bin and job.qty == Collecting.CARRY, "to the recycling bin, for a bag's worth (%d)" % Collecting.CARRY)
	var t := Fixtures.until(w, func(): return who.wallet > 0.0, 200)
	check(t > 0 and is_equal_approx(who.wallet, Collecting.CARRY * Deposit.DEPOSIT), "walked there and to the depot, and was paid $%.2f (%d s)" % [who.wallet, t])
	check(w.logistics.collecting.held(who) == 0 and w.bottle_depots[0].taken_in == Collecting.CARRY, "and handed every bottle in")
	check(_accounted(w), "the money is accounted for")


func test_who_has_enough_does_not_go() -> void:
	var s := _street(1, Collecting.ENOUGH)
	var w: World = s[0]
	var who: Drone = s[1][0]
	check(not w.logistics.collecting.wants(who), "with a few days' food money, nobody goes collecting")
	w.logistics.collecting._bag(who).add("recyclables", 5)
	check(w.logistics.collecting.wants(who) and w.logistics.collecting.job(who).stage == "redeem", "but bottles in hand are taken in, whatever the wallet")
	var rw := Fixtures.runner_world(20.0)
	var baker: Drone = rw[2]
	var bakery: Machine = rw[3]
	bakery.output.add("bread", 10)
	check(not rw[0].logistics.collecting.wants(baker) or Hauling.spendable(baker) < Hauling.MIN_LOAD * Catalog.base_price("leftovers"), "a vendor whose stand has stock and can pay for its next load stays at it")
	baker.wallet = 40.0
	check(not rw[0].logistics.collecting.wants(baker), "a vendor with money enough never goes")
	baker.wallet = 12.0
	check(rw[0].logistics.collecting.wants(baker), "but one who can't pay for a load of their inputs goes, or the stand runs dry")
	var att := w.deposit.attendant(s[2])
	att.wallet = 0.0
	check(not w.logistics.collecting.wants(att), "and the attendant stays behind the counter")


func test_a_runner_collects_with_the_cart() -> void:
	var s := _street()
	var w: World = s[0]
	var r := w.add_runner(Vector2(0, 3), 0.0)
	r.bars = Fixtures.bars(1.0, 1.0, 1.0)
	var job := w.logistics.collecting.job(r)
	check(job.qty == int(r.runner.rig().load), "a runner takes a cartload (%d), not a bag" % job.qty)
	w.logistics.complete(r, job)
	check(r.runner.cart.count("recyclables") == int(r.runner.rig().load) and r.job.stage == "redeem", "into the cart, and on to the depot")


func test_the_recycling_fills_with_what_people_throw_away() -> void:
	var w := World.new()
	var bin := w.add_bin("recycling", Vector2.ZERO, 0)
	for i in 6:
		w.add_drifter(Vector2(4 + i, 0)).make_needless()
	w.add_drifter(Vector2(20, 0))
	check(w.zones.heads_in(bin.zone) == 1, "residents are who have needs (%d)" % w.zones.heads_in(bin.zone))
	var lone := World.new()
	var lone_bin := lone.add_bin("recycling", Vector2.ZERO, 0)
	for i in 3:
		lone.add_drifter(Vector2(4 + i, 0))
	var rate := float(WasteBin.KINDS.recycling.rate)
	check(is_equal_approx(lone_bin.per_minute(lone.zones.heads_in(lone_bin.zone)), rate * 3), "a bin among three fills three times as fast as among one: %.1f a minute a head" % rate)
	check(not w.add_bin("organics", Vector2(30, 0)).per_head(), "the organics fill at their own pace, however many are about")


func test_slow_a_funded_town_keeps_itself_going_without_the_hero() -> void:
	var w := World.new()
	Cluster.found(w, "town", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "town")
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
	var depot: BottleDepot = w.bottle_depots[0]
	check(worst >= 40, "five days on its own, it sells at least 40 things every day (the worst day: %d)" % worst)
	check(down <= 1, "and nobody goes to the medical tent, near enough (%d collapses in five days)" % down)
	check(leaks == 0, "the money is accounted for on every tick (%d off)" % leaks)
	check(depot.taken_in > 0, "its people took %d bottles in, for $%.2f" % [depot.taken_in, depot.paid_out])


func test_a_dormant_town_collects_too() -> void:
	var s := _street(3)
	var w: World = s[0]
	for d in s[1]:
		d.bars = Fixtures.bars(1.0, 1.0, 1.0)
	w.build_zone = "elsewhere"
	w.add_drifter(Vector2(9000, 0)).make_needless()
	w.zones.active = ["elsewhere"] as Array[String]
	var bin: WasteBin = s[3]
	var there := bin.output.count("recyclables")
	w.summary.step("district", 1.0)
	var paid: float = s[1].reduce(func(a, d): return a + d.wallet, 0.0)
	var wanted := 3 * Collecting.ENOUGH
	check(is_equal_approx(paid, minf(there, wanted / Deposit.DEPOSIT) * Deposit.DEPOSIT) and s[1].all(func(d): return w.logistics.collecting.held(d) == 0), "in summary each errand is done on the spot: the bottles to the depot (%d there), and paid ($%.2f: %s)" % [there, paid, s[1].map(func(d): return d.wallet)])
	check(s[1].all(func(d): return d.wallet <= Collecting.ENOUGH + 0.01), "nobody takes more than brings them back up to $%.0f: the deposit is a net, not savings" % Collecting.ENOUGH)
	check(_accounted(w), "the money is accounted for")


func test_slow_two_saves_with_bottle_depots_merge() -> void:
	var build := func(tiles: Array) -> World:
		var w := World.new()
		for t in tiles:
			w.zones.add_tile(t)
			Cluster.build(w, t, TileKey.rect(t).get_center(), 6, true, 40.0, false)
			w.add_bottle_depot(TileKey.rect(t).get_center() + Vector2(-14, -10))
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
	check(m.bottle_depots.size() == 2, "both bottle depots are there")
	check(is_equal_approx(m.total_money(), a.total_money() + b.total_money()) and _accounted(m), "with every dollar of both saves ($%.2f)" % m.total_money())
	check(is_equal_approx(m.ledger.issued, a.ledger.issued + b.ledger.issued), "and what each printed")
	var paid := m.bottle_depots.map(func(o): return o.paid_out)
	check(is_equal_approx(paid[0] + paid[1], a.bottle_depots[0].paid_out + b.bottle_depots[0].paid_out), "and what each paid out")
