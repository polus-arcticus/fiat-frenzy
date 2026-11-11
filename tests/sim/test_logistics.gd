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
	check(stands.all(func(p): return p.distance_to(bakery.pos) < Logistics.TRADE_REACH), "all of them within trading reach")
	check(baker.pos.distance_to(bakery.pos) < 0.01, "(the vendor starts on the stand)")
	Fixtures.run(w, 5)
	check(baker.pos.distance_to(bakery.pos) >= 1.0, "a vendor minds the stand from behind it, not from inside it (%.1f m)" % baker.pos.distance_to(bakery.pos))
	var tw := World.new()
	var keeper := tw.add_vendor("tent", Vector2(0, 0))
	var tent := tw.machine_of(keeper)
	var sleepers: Array = []
	for i in 4:
		var d := tw.add_drifter(Vector2(randf_range(-4, 4), randf_range(-4, 4)), 20.0)
		d.bars = Fixtures.bars(1.0, 1.0, 0.3)
		tent.shelter.admit(d)
		d.pos = tent.shelter.berth_pos(tent.pos, tent.shelter.berths.size() - 1)
		sleepers.append(d.pos)
	check(Fixtures.spread(sleepers) >= 0.5, "four sleepers in a tent sit %.1f m apart, not all on its centre" % Fixtures.spread(sleepers))
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


func test_food_bank_trickles_stock() -> void:
	note("food bank: base materials trickle in slowly, and are sold at cost")
	var w := World.new()
	var keeper := w.add_food_bank(Vector2(0, 0))
	var fb := w.food_bank_of(keeper)
	check(keeper.kind == "keeper" and keeper.depot == 0 and w.food_bank_of(keeper) == fb, "it has a keeper, one to one")
	check(["flour", "bottled_water", "sugar", "protein"].all(func(g): return fb.output.count(g) == 10 and fb.offers(g)), "it opens with ten of each good on the shelves")
	check(keeper.pos.distance_to(fb.pos) >= 1.0, "the keeper stands behind the counter")
	Fixtures.run(w, 300)
	note("    after five minutes: flour %d, water %d, sugar %d, protein %d" % [fb.output.count("flour"), fb.output.count("bottled_water"), fb.output.count("sugar"), fb.output.count("protein")])
	check(fb.output.count("flour") == 16 and fb.output.count("bottled_water") == 17 and fb.output.count("sugar") in [13, 14] and fb.output.count("protein") in [13, 14], "five minutes later it has made a few more of each, at its own slow rates")
	Fixtures.run(w, 3000)
	check(fb.output.count("flour") == 30 and fb.output.count("protein") == 30, "and it stops at its cap of 30")
	check(is_equal_approx(fb.price_of("flour"), Catalog.base_price("flour")) and is_equal_approx(fb.price_of("bottled_water"), 0.5), "it sells at cost")


func test_a_runner_delivers_for_a_fee() -> void:
	note("cart runner: buys a load at the food bank, wheels it to a short shop, and is paid the cost plus a fee")
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var keeper: Drone = rw[1]
	var baker: Drone = rw[2]
	var bakery: Machine = rw[3]
	var runner: Drone = rw[4]
	check(w.needs.demands(runner) == ["haul"], "a runner's demand, with nothing else to want, is deliveries")
	var job := w.logistics.plan(runner)
	check(job["for"] == "haul" and job.stage == "pickup" and job.dest == bakery and job.item == "flour" and job.qty == 10, "it plans a trip: ten flour, the food bank's whole stock, to the bakery")
	var t := Fixtures.until(w, func(): return bakery.input.count("flour") >= 10, 200)
	note("    delivered after %d s; runner now has $%.2f (earned $%.2f in fees); baker $%.2f; keeper $%.2f" % [t, runner.wallet, runner.fees_earned, baker.wallet, keeper.wallet])
	check(t >= 0 and bakery.input.count("flour") == 10 and runner.cart.count("flour") == 0, "the flour went from the food bank, through the cart, into the bakery's input inventory")
	check(is_equal_approx(keeper.wallet, 10.0) and w.food_bank_of(keeper).sold_total == 10, "the food bank took its price: $10 for ten flour at cost")
	check(is_equal_approx(baker.wallet, 40.0 - 13.0), "the baker paid $1.30 a unit: the cost plus the fee")
	check(is_equal_approx(runner.wallet, 20.0 + 3.0) and is_equal_approx(runner.fees_earned, 3.0) and runner.delivered_total == 10, "and the runner kept the $3 difference: that is its revenue")
	check(is_equal_approx(bakery.input_cost["flour"], 1.3) and is_equal_approx(bakery.floor_price(), 2.6), "the fee is part of what the shop's flour costs it, so its floor price is $2.60")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "no money went missing")
	Fixtures.run(w, 40)
	check(runner.pos.distance_to(runner.home) < 1.0, "and the runner wheels the empty cart back home")


func test_runners_only_go_where_a_trip_makes_sense() -> void:
	note("cart runner: no trip if there is nothing worth taking, or nobody to pay for it")
	var rw := Fixtures.runner_world()
	rw[3].working = false
	check(rw[0].logistics.plan(rw[4]).is_empty(), "a wrecked shop gets nothing")
	rw = Fixtures.runner_world(0.0)
	check(rw[0].logistics.plan(rw[4]).is_empty(), "nor does a shop whose owner can't pay for it")
	rw = Fixtures.runner_world()
	rw[3].input.add("flour", 12)  # full...
	rw[3].input.take("flour", 2)  # ...but for two
	check(rw[3].input.room("flour") == 2 and rw[0].logistics.plan(rw[4]).is_empty(), "a shop only 2 short isn't worth the walk (a trip needs 4)")
	rw = Fixtures.runner_world()
	rw[0].food_bank_of(rw[1]).output.take("flour", 99)
	rw[0].food_bank_of(rw[1]).refresh()
	check(rw[0].logistics.plan(rw[4]).is_empty(), "and an empty food bank gives them nothing to carry")
	rw = Fixtures.runner_world(40.0, 4.0)
	var job: Dictionary = rw[0].logistics.plan(rw[4])
	check(job.qty == 4, "a broke runner only buys what they can afford: four units at $1 with $4")
	rw = Fixtures.runner_world()
	var hungry: Drone = rw[4]
	hungry.bars = Fixtures.bars(0.2, 1.0, 1.0)
	check(rw[0].needs.demands(hungry) == ["food", "haul"], "a hungry runner still wants food before deliveries")
	rw = Fixtures.runner_world()
	var r: Drone = rw[4]
	r.cart.add("flour", 6)
	rw[3].input.add("flour", 12)  # the bakery is full of flour now (12 of 12)
	check(rw[0].logistics.plan(r).is_empty(), "a runner holding a load nobody wants holds on to it")
	rw[3].input.take("flour", 8)
	var drop: Dictionary = rw[0].logistics.plan(r)
	check(drop.stage == "drop" and drop.target == rw[3] and drop.qty == 6, "until a shop runs short: then it takes the load over")


func test_runners_share_the_work() -> void:
	note("cart runners: two of them don't both bring the same flour")
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var bakery: Machine = rw[3]
	var first: Drone = rw[4]
	var second := w.add_runner(Vector2(2, -3), 20.0)
	second.bars = Fixtures.bars(1.0, 1.0, 1.0)
	first.job = w.logistics.plan(first)
	check(not first.job.is_empty(), "the first plans the trip")
	check(w.logistics.plan(second).is_empty(), "the second sees the first is already bringing it, and stays put")
	Fixtures.run(w, 80)  # long enough for the delivery, short of the bakery baking through it and the food bank restocking
	check(first.delivered_total + second.delivered_total == 10 and w.food_banks[0].sold_total == 10, "the bakery was brought its ten units once, not twice")
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
	stand.input.take("protein", 2)
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
