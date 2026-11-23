## Sim tests: logistics. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_nobody_shares_coordinates() -> void:
	note("space: customers, vendors and sleepers each get their own spot")
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0))
	var bakery := w.machine_of(baker)
	var crowd: Array[Drone] = []
	for i in 6:
		var d := w.add_drifter(Vector2(30, 0), 20.0)
		d.bars = Fixtures.bars(0.2, 1.0, 1.0)
		crowd.append(d)
	var stands: Array = []
	for d in crowd:
		d.job = w.logistics.plan(d)  # each plans after the last, so each sees who is already coming
		stands.append(d.job.stand)
	note("    six customers' stand points are at least %.2f m apart" % Fixtures.spread(stands))
	check(Fixtures.spread(stands) >= 0.5, "six customers heading for one bakery each get their own place in front of it")
	check(stands[0].distance_to(bakery.pos) < Logistics.TRADE_REACH, "the first is within trading reach: the rest line up behind (see test_queues)")
	check(baker.pos.distance_to(bakery.pos) < 0.01, "(the vendor starts on the stand)")
	Fixtures.run(w, 5)
	check(baker.pos.distance_to(bakery.pos) >= 1.0, "a vendor minds the stand from behind it, not from inside it (%.1f m)" % baker.pos.distance_to(bakery.pos))
	var tw := World.new()
	var keeper := tw.add_vendor("tent", Vector2(0, 0))
	var tent := tw.machine_of(keeper)
	var sleepers: Array = []
	for i in 6:
		tw.add_drifter(Vector2(randf_range(-4, 4), randf_range(-4, 4)), 20.0)
	tw.lodging.house_everyone(tent)
	for d in tw.lodging.housed(tent):
		tent.shelter.admit(d)
		d.pos = tw.lodging.bed_of(tent, d)
		sleepers.append(d.pos)
	check(sleepers.size() == 7 and Fixtures.spread(sleepers) >= 0.5, "seven sleepers in a tent city of seven tents lie %.1f m apart, each in their own tent" % Fixtures.spread(sleepers))
	check(sleepers.all(func(p): return not tw.nav.blocked(tw.zones.machines_in("district")[0].zone, p)), "and none of them is in a wall's margin, where someone waking up could not find their way out")
	var bw := World.new()
	var a := bw.add_drifter(Vector2(0, 0))
	var b := bw.add_drifter(Vector2(0, 1))
	a.bars = Fixtures.bars(1.0, 1.0, 1.0)
	b.bars = Fixtures.bars(1.0, 1.0, 1.0)
	var bill := bw.gun.fire(2.0, "gift")
	bw.gun.land(bill, Vector2(0, 8))
	a.job = bw.logistics.plan(a)
	b.job = bw.logistics.plan(b)
	check(a.job.stand.distance_to(b.job.stand) >= 0.4, "two drifters after one bill don't aim for the same spot")


func test_the_bins_fill_slowly() -> void:
	note("bins: the town's base inputs gather in them slowly, free to take")
	var w := World.new()
	var bins: Array = w.add_bin_station(Vector2.ZERO)
	bins.append(w.add_bin("fountain", Vector2(8, 0)))
	var kinds: Array = bins.map(func(b): return b.kind)
	check(kinds == ["garbage", "recycling", "organics", "fountain"], "a station of three, and a fountain")
	check(bins.map(func(b): return b.item) == ["scrap", "recyclables", "leftovers", "water"], "scrap, bottles, leftovers, water")
	check(bins.all(func(b): return b.output.count(b.item) == WasteBin.KINDS[b.kind].start and b.price_of(b.item) == 0.0), "each opens with its kind's start, and it is free to take")
	for i in 2:  # (two people about: the recycling fills with what they throw away, and there is no depot to take it to)
		w.add_drifter(Vector2(4 + i, 6), 50.0)
	var heads := w.zones.heads_in(bins[0].zone)
	var start: Array = bins.map(func(b): return b.output.count(b.item))
	Fixtures.run(w, 300, true)
	var made: Array = []
	for i in bins.size():
		made.append(bins[i].output.count(bins[i].item) - start[i])
	var expect: Array = bins.map(func(b): return mini(int(b.per_minute(heads) * 5.0), int(WasteBin.KINDS[b.kind].cap) - int(WasteBin.KINDS[b.kind].start)))  # (rates are a minute's)
	var close := true
	for i in bins.size():
		close = close and absi(made[i] - expect[i]) <= 1
	check(close, "five minutes later each has gathered more, at its own rate, up to its cap (%s)" % str(made))
	Fixtures.run(w, 6000, true)
	check(bins.all(func(b): return b.output.count(b.item) == WasteBin.KINDS[b.kind].cap), "and stops at its cap")


func test_a_runner_delivers_for_a_fee() -> void:
	note("cart runner: salvages a load from a bin, wheels it to a short shop; the shop pays the goods' worth to the town's fund, and the runner a fee")
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var bin: WasteBin = rw[1]
	var baker: Drone = rw[2]
	var bakery: Machine = rw[3]
	var runner: Drone = rw[4]
	var clerk: Drone = rw[5]
	var room := bakery.input.room("leftovers")
	check(w.needs.demands(runner) == ["haul", "collect"], "a runner's demand, with nothing else to want, is deliveries (and, short of cash, bottles after: Collecting)")
	var job := w.logistics.plan(runner)
	check(job["for"] == "haul" and job.stage == "pickup" and job.target == bin and job.dest == bakery and job.item == "leftovers" and job.qty == room, "it plans a trip: as many leftovers as the bakery has room for (%d), from the organics bin" % room)
	var t := Fixtures.until(w, func(): return bakery.input.count("leftovers") >= room, 200)
	var worth := Catalog.base_price("leftovers") * room
	var fee := Hauling.DELIVERY_FEE
	var cart := runner.runner
	note("    delivered after %d s; runner now has $%.2f (earned $%.2f in fees); baker $%.2f; the fund $%.2f" % [t, runner.wallet, cart.fees_earned, baker.wallet, clerk.wallet])
	check(t >= 0 and bakery.input.count("leftovers") == room and cart.cart.count("leftovers") == 0, "the leftovers went from the bin, through the cart, into the bakery's input inventory")
	check(is_equal_approx(baker.wallet, 40.0 - worth - fee), "cash on delivery: the baker paid their worth ($%.2f) and the $%.2f flat fee" % [worth, fee])
	check(is_equal_approx(clerk.wallet, worth), "their worth went into the town's fund, the bottle depot's (Deposit.fund)")
	check(is_equal_approx(runner.wallet, 20.0 + fee) and is_equal_approx(cart.fees_earned, fee) and cart.delivered_total == room and cart.deliveries == 1, "and the runner kept the fee: that is its revenue")
	var unit := Catalog.base_price("leftovers") + fee / room
	check(is_equal_approx(bakery.input_cost["leftovers"], unit), "the worth and the fee are what the shop's leftovers cost it ($%.3f each)" % unit)
	check(is_equal_approx(w.total_money(), w.ledger.printed), "no money went missing")
	w.bins.erase(bin)  # (nothing more to fetch: the bin's trickle would soon have another load for it)
	w.zones.invalidate()
	var back := Fixtures.until(w, func(): return runner.pos.distance_to(runner.home) < 1.0, 40)
	check(back >= 0, "and with nothing more to fetch, the runner wheels the empty cart back home (%d s)" % back)


func test_runners_only_go_where_a_trip_makes_sense() -> void:
	note("cart runner: no trip if there is nothing worth taking, or nobody to pay for it")
	var rw := Fixtures.runner_world()
	rw[3].working = false
	check(rw[0].logistics.plan(rw[4]).is_empty(), "a wrecked shop gets nothing")
	rw = Fixtures.runner_world(0.0)
	check(rw[0].logistics.plan(rw[4]).is_empty(), "nor does a shop whose owner can't pay for it")
	rw = Fixtures.runner_world()
	rw[3].input.add("leftovers", 99)  # full...
	rw[3].input.take("leftovers", 2)  # ...but for two
	check(rw[3].input.room("leftovers") == 2 and rw[0].logistics.plan(rw[4]).is_empty(), "a shop only 2 short isn't worth the walk (a trip needs %d)" % Hauling.MIN_LOAD)
	rw = Fixtures.runner_world()
	rw[1].output.take("leftovers", 99)
	rw[1].refresh()
	check(rw[0].logistics.plan(rw[4]).is_empty(), "and an empty bin gives them nothing to carry")
	rw = Fixtures.runner_world(Drone.RESERVE + Hauling.DELIVERY_FEE + Catalog.base_price("leftovers") * 7.5)
	var job: Dictionary = rw[0].logistics.plan(rw[4])
	check(job.qty == 7, "a shop is only brought what its owner can pay for: seven, with $%.2f to spare" % (Catalog.base_price("leftovers") * 7.5))
	rw = Fixtures.runner_world()
	var hungry: Drone = rw[4]
	hungry.bars = Fixtures.bars(0.2, 1.0, 1.0)
	check(rw[0].needs.demands(hungry).slice(0, 2) == ["food", "haul"], "a hungry runner still wants food before deliveries")
	rw = Fixtures.runner_world()
	var r: Drone = rw[4]
	r.runner.cart.add("leftovers", 6)
	rw[3].input.add("leftovers", 99)  # the bakery is full of leftovers now
	check(rw[0].logistics.plan(r).is_empty(), "a runner holding a load nobody wants holds on to it")
	rw[3].input.take("leftovers", 8)
	var drop: Dictionary = rw[0].logistics.plan(r)
	check(drop.stage == "drop" and drop.target == rw[3] and drop.qty == 6, "until a shop runs short: then it takes the load over")


func test_runners_share_the_work() -> void:
	note("cart runners: two of them don't both bring the same leftovers")
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var bakery: Machine = rw[3]
	var first: Drone = rw[4]
	var second := w.add_runner(Vector2(2, -3), 20.0)
	second.bars = Fixtures.bars(1.0, 1.0, 1.0)
	first.job = w.logistics.plan(first)
	check(not first.job.is_empty(), "the first plans the trip")
	check(w.logistics.plan(second).is_empty(), "the second sees the first is already bringing it, and stays put")
	var room := bakery.input.room("leftovers")
	bakery.rate_per_min = 0.0  # (not baking: no new room opens while they're at it)
	Fixtures.run(w, 90)
	check(first.runner.delivered_total + second.runner.delivered_total == room and bakery.input.count("leftovers") == room, "the bakery was brought its %d leftovers once, not twice" % room)
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and the money adds up")


func test_runners_are_quicker_and_carry_more() -> void:
	note("cart runners: a tad quicker, a tad stronger")
	var w := World.new()
	var runner := w.add_runner(Vector2.ZERO)
	var drifter := w.add_drifter(Vector2.ZERO)
	check(runner.speed > drifter.speed and runner.speed < drifter.speed * 1.5, "a runner walks faster than a drifter, but not by much (%.1f against %.1f m/s)" % [runner.speed, drifter.speed])
	check(Hauling.CART_CAPACITY == 16, "and a cart holds 16 units")


func test_streets() -> void:
	note("streets: the road graph routes round corners, and drones follow it")
	var g := Fixtures.l_road()
	var r := g.route(Vector2(2, 1), Vector2(49, 49))
	check(r.has(Vector2(50, 0)) and r[r.size() - 1] == Vector2(49, 49), "a route goes round the corner and ends exactly at the goal")
	check(g.route(Vector2(0, 0), Vector2(5, 5)).size() == 1, "a short trip is just walked straight")
	var g2 := RoadGraph.new()
	g2.add_polyline(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)]))
	g2.add_polyline(PackedVector2Array([Vector2(10, 0), Vector2(10, 20)]))
	check(g2.point_count() == 4, "streets that cross share a junction (4 points, not 5)")
	var w := World.new()
	w.roads = Fixtures.l_road()
	var baker := w.add_vendor("bakery", Vector2(50, 50))
	w.machine_of(baker).rate_per_min = 0.0
	var eater := w.add_drifter(Vector2(0, 0), 10.0)
	eater.bars = Fixtures.bars(0.2, 1.0, 1.0)
	var closest := INF
	var t := -1
	for i in 150:
		w.tick(1.0)
		closest = minf(closest, eater.pos.distance_to(Vector2(50, 0)))
		if w.machine_of(baker).sold_total > 0:
			t = i
			break
	note("    walked to the bakery in %d s (straight line would be 47 s); closest to the corner %.1f" % [t, closest])
	check(t >= 60 and t <= 80, "it took the long way round the street corner, about 100 m at 1.5 m/s")
	check(closest < 3.0, "and it really did pass the corner instead of cutting through")


func test_hungry_drone_buys_and_eats() -> void:
	note("a hungry drone's demand finds a supply: it walks over and the item and money move")
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0))
	var bakery := w.machine_of(baker)
	bakery.rate_per_min = 0.0
	var eater := w.add_drifter(Vector2(30, 0), 10.0)
	eater.bars = Fixtures.bars(0.2, 1.0, 1.0)
	var t := Fixtures.until(w, func(): return bakery.sold_total > 0, 100)
	note("    bought after %d s; paid %.2f; hunger %.2f" % [t, bakery.revenue_total, eater.bars.hunger])
	check(t >= 15 and t <= 25, "it took a walk (30 units at 1.5 a second)")
	check(bakery.stock() == 24 and eater.carry.count("bread") == 0, "one loaf left the bakery's output and was eaten")
	check(is_equal_approx(eater.wallet, 10.0 - bakery.price) and is_equal_approx(baker.wallet, bakery.price), "the money went wallet to wallet")
	check(eater.bars.hunger > 0.4, "and the hunger bar refilled")


func test_hot_dog_stand_buys_bread_from_the_bakery() -> void:
	note("machine to machine: the hot dog stand wants bread, the bakery offers it")
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0))
	var bakery := w.machine_of(baker)
	bakery.rate_per_min = 0.0
	var seller := w.add_vendor("hot_dog_stand", Vector2(15, 0), 30.0)
	var stand := w.machine_of(seller)
	stand.input.take("bread", 2)
	stand.input.take("leftovers", 2)
	var stock0 := bakery.stock()
	var t := Fixtures.until(w, func(): return stand.input.count("bread") > 0, 100)
	note("    after %d s the stand holds %d bread, paid %.2f" % [t, stand.input.count("bread"), seller.wallet])
	check(t >= 0 and bakery.stock() == stock0 - 1, "a loaf left the bakery's output inventory for the stand's input")
	check(is_equal_approx(baker.wallet, bakery.price) and is_equal_approx(30.0 - seller.wallet, bakery.price), "and the stand's owner paid the baker for it")
	check(is_equal_approx(stand.input_cost["bread"], bakery.price), "the loaf's price is now the stand's cost for bread")


# ---------------------------------------------------------------- vocation


func test_broken_stand_is_repaired_then_produces() -> void:
	note("vocation: a vendor with the money repairs their stand, and it starts producing")
	var w := World.new()
	var v := w.add_vendor("hot_dog_stand", Vector2(0, 0), 20.0, false, false)
	var stand := w.machine_of(v)
	Fixtures.run(w, 60, true)
	check(not stand.working and stand.stock() == 0, "short of the money it stays boarded up and makes nothing")
	w.gun.gift(v, 100.0)
	Fixtures.run(w, 3, true)
	check(stand.working and is_equal_approx(v.wallet, 120.0 - stand.repair_cost) and is_equal_approx(w.ledger.sunk, stand.repair_cost), "gifted the money it repairs the stand and pays for it")
	Fixtures.run(w, 120, true)
	check(stand.stock() >= 1, "and it is producing (%d hot dogs after two minutes)" % stand.stock())


# ---------------------------------------------------------------- the gun
