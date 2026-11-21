## Sim tests: trades and tiers (see Premises, Catalog.TRADES, Machine.retier, Trades) and the standard cluster (see Cluster).
## Every test that moves money checks that it is all accounted for.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


## Runs `w` to the next dawn and a tick past it, everyone fed by hand.
func _to_dawn(w: World) -> void:
	var day := w.clock.day()
	while w.clock.day() <= day:
		Fixtures.run(w, 1, true)
	Fixtures.run(w, 1, true)


## A hot dog stand whose owner has `wallet`, fed by hand.
func _stand(wallet: float, kind := "hot_dog_stand") -> Array:
	var w := World.new()
	var v := w.add_vendor(kind, Vector2.ZERO, wallet)
	v.bars = Fixtures.bars(1.0, 1.0, 1.0)
	w.begin_play()
	return [w, v, w.machine_of(v)]


func test_every_trade_is_a_ladder_of_known_tiers() -> void:
	for trade in Catalog.TRADES:
		var ladder: Array = Catalog.TRADES[trade]
		for tier in ladder.size():
			var id: String = ladder[tier]
			if id == "" or id in ["food_bank", "welfare_office", "first_aid", "medical_tent"]:
				continue
			var d := Catalog.machine(id)
			check(d.trade == trade and d.tier == tier, "%s is the %s trade's tier %d" % [id, trade, tier])
			check((d.build > 0.0 or d.build_scrap > 0) == (tier > 0 and ladder[tier - 1] != "") and not (d.build > 0.0 and d.build_scrap > 0), "%s: building it up costs $%.0f or %d scrap (only from a tier below that is built)" % [id, d.build, d.build_scrap])
			check(Catalog.item(d.item) != null and not Catalog.footprint_of(id).is_empty(), "%s makes a known item and has a footprint" % id)
	for trade in Catalog.TRADES:
		var bottom: String = Catalog.TRADES[trade][0]
		if bottom == "" or not Catalog.has_machine(bottom) or Catalog.machine(bottom).inputs.is_empty():
			continue  # (no tier 0 yet, a premises, or makes nothing from anything: the tent city)
		var d := Catalog.machine(bottom)
		var food: bool = Catalog.class_of(d.item) in ["food", "drink"]
		check(food or d.inputs.has("scrap"), "%s: a tier-0 trade that makes no food or drink makes it from scrap (%s)" % [bottom, d.inputs])
	check(Catalog.next_tier("hot_dog_stand") == "burger_bar" and Catalog.next_tier("burger_bar") == "", "a hot dog stand builds up into a burger bar, and that is as far as it goes for now")
	check(Catalog.next_tier("bike_shop") == "" and Catalog.machine("bike_shop").tier == 1, "the bike shop is tier 1, with nothing above it")
	var w := World.new()
	w.add_food_bank(Vector2(10, 0))
	w.add_welfare_office(Vector2(20, 0))
	check(w.food_banks[0].trade == "supply" and w.welfare_offices[0].trade == "money" and w.welfare_offices[0].display_name() == "Welfare office", "the food bank and the welfare office are premises too, each the bottom of its trade")


func test_a_business_built_up_keeps_what_it_had() -> void:
	var s := _stand(0.0, "bakery")
	var w: World = s[0]
	var m: Machine = s[2]
	w.gun.invest(s[1], 30.0)
	m.sold_total = 7
	var uid := m.uid
	var stakes := m.equity.stakes.duplicate()
	var bread := m.stock()
	m.retier("bake_shop")
	check(m.uid == uid and m.owner == s[1].uid and m.pos == Vector2.ZERO, "the bake shop is the same business: its name, owner and place")
	check(m.kind == "bake_shop" and m.trade == "bread" and m.tier == 1 and m.display_name() == "Bake shop", "now tier 1 of the bread trade")
	check(m.equity.stakes == stakes and m.sold_total == 7 and m.growth == s[1].growth, "the hero's stake, its takings and its owner's level stay")
	check(m.stock() == bread and m.capacity() == Catalog.machine("bake_shop").cap and is_equal_approx(m.rate_per_min, Catalog.machine("bake_shop").rate), "it still makes bread, so it keeps its loaves, on a bigger shelf, made faster")
	var t := _stand(0.0)
	var dogs: Machine = t[2]
	dogs.retier("burger_bar")
	check(dogs.item == "burger" and dogs.stock() == 1 and dogs.output.count("hot_dog") == 0, "the hot dog stand's hot dogs go with it: the burger bar opens with one burger")
	check(dogs.input.counts.has("bread") and dogs.input.counts.has("protein") and dogs.floor_price() > 0.0, "and it keeps the bread and protein it had, for the burgers")


func test_an_owner_builds_up_at_dawn_with_their_own_savings() -> void:
	var cost := Catalog.machine("burger_bar").build
	var enough := cost + Trades.float_for("burger_bar")
	var s := _stand(enough + 1.0)
	var w: World = s[0]
	var m: Machine = s[2]
	Fixtures.run(w, 1, true)
	check(m.kind == "hot_dog_stand", "not before dawn")
	_to_dawn(w)
	check(m.kind == "burger_bar" and is_equal_approx(s[1].wallet, enough + 1.0 - cost), "at dawn: a burger bar, and its owner paid the $%.0f it cost" % cost)
	check(is_equal_approx(w.ledger.sunk, cost) and is_equal_approx(m.built_total, cost) and _accounted(w), "the money is sunk (the builders were paid), and accounted for")
	check(w.events.any(func(e): return "built up into a Burger bar" in e), "and the town hears of it")


func test_who_does_not_build_up() -> void:
	var cost := Catalog.machine("burger_bar").build
	var short := _stand(cost + Trades.float_for("burger_bar") - 1.0)
	_to_dawn(short[0])
	check(short[2].kind == "hot_dog_stand", "an owner who would be left without their float waits")
	var wrecked := _stand(10000.0)
	wrecked[2].working = false
	check(wrecked[0].trades.can_build(wrecked[2]) == "", "a wrecked stand is repaired first")
	var rich := World.new()
	var shop := rich.machine_of(rich.add_vendor("bike_shop", Vector2.ZERO, 1e6, true, true))
	_to_dawn(rich)
	check(shop.kind == "bike_shop", "and the bike shop has nowhere to go")
	var given := _stand(0.0)
	given[0].gun.gift(given[1], cost + Trades.float_for("burger_bar"))
	_to_dawn(given[0])
	check(given[2].kind == "burger_bar", "the hero can hurry it, by giving the owner the money")


func test_a_built_up_business_is_saved_and_merged() -> void:
	var build := func(tiles: Array) -> World:
		var w := World.new()
		for t in tiles:
			w.zones.add_tile(t)
			Cluster.build(w, t, TileKey.rect(t).get_center(), Cluster.DRIFTERS, true, 40.0)
		return w
	var t0 := TileKey.parse(TileKey.of(50.1086307, 8.6687641))
	var tile := TileKey.key(t0.x, t0.y)
	var a: World = build.call([tile])
	var b: World = build.call([tile])
	for w in [a, b]:
		w.add_player(Vector2.ZERO, 10.0)
		w.begin_play()
	var stand := func(w: World) -> Machine: return w.zones.machines_in(tile).filter(func(m): return m.trade == "meat")[0]
	var owner: Drone = a.drone(stand.call(a).owner)
	a.gun.gift(owner, 1000.0)
	for w in [a, b]:
		for i in 700:
			w.tick(1.0)
	check(stand.call(a).kind == "burger_bar" and stand.call(b).kind == "hot_dog_stand", "one save built the stand up, the other did not")
	var data: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.new(a).capture()))
	var fresh: World = build.call([tile])
	fresh.add_player(Vector2.ZERO, 0.0)
	Snapshot.new(fresh).apply(data)
	check(stand.call(fresh).kind == "burger_bar" and stand.call(fresh).item == "burger" and fresh.trades.day == a.trades.day, "the burger bar loads as a burger bar")
	var m := Merge.combine(Snapshot.new(a).capture(), Snapshot.new(b).capture(), build)
	var merged: Machine = stand.call(m)
	check(merged.kind == "burger_bar" and merged.tier == 1 and merged.item == "burger" and merged.recipe == Catalog.machine("burger_bar").inputs, "merged, it is the burger bar, all of it")
	check(merged.output.count("hot_dog") == 0 and is_equal_approx(merged.built_total, stand.call(a).built_total), "with no hot dogs left over, and what it cost to build once")
	check(_accounted(m) and is_equal_approx(m.ledger.sunk, a.ledger.sunk + b.ledger.sunk), "and the money is accounted for, what was sunk into building it up included")


func test_the_standard_cluster_as_it_is_found_and_funded() -> void:
	var w := World.new()
	Cluster.found(w, "block", Vector2.ZERO)
	var vendors := w.zones.drones_in("block").filter(func(d): return d.kind == "vendor")
	check(vendors.size() == Cluster.STANDS.size() and vendors.all(func(d): return d.wallet == 0.0 and w.machine_of(d).working == (w.machine_of(d).shelter != null)), "as it is found: every stand wrecked but the tent city, every owner broke")
	check(w.food_banks.size() == 1 and w.welfare_offices.size() == 1 and w.relief_trucks.size() == 1 and w.zones.runners_in("block").size() == Cluster.RUNNERS, "with its food bank, runners, the van's stop and the welfare office")
	check(_accounted(w), "the books balance")
	w.begin_play()
	Cluster.fund(w, "block")
	check(vendors.all(func(d): return w.machine_of(d).working or w.needs.demands(d).has("repair")), "funded once, every owner with a wrecked stand can repair it")
	check(_accounted(w), "and the hero's money is counted as printed")


## The balance point, over a season: the standard cluster, funded once, run on its own in summary (as a block the hero is not in)
## for 120 days. Nobody goes to the medical tent, and every trade is built up, slowly (tools/epoch.gd prints the same).
func test_a_season_of_the_standard_cluster() -> void:
	var w := World.new()
	Cluster.found(w, "block", Vector2.ZERO)
	w.begin_play()
	Cluster.fund(w, "block")
	w.build_zone = "elsewhere"
	w.add_drifter(Vector2(9000, 0)).make_needless()
	w.zones.active = ["elsewhere"] as Array[String]
	var built := {}
	var leaks := 0
	for day in 120:
		for s in int(Clock.DAY_SECONDS):
			w.tick(1.0)
		for m in w.zones.machines_in("block"):
			if m.tier > 0 and not built.has(m.trade):
				built[m.trade] = day + 1
		if not _accounted(w):
			leaks += 1
	var down := w.events.filter(func(e): return "collapsed" in e).size()
	check(down <= 1, "120 days on its own and nobody goes to the medical tent, near enough (%d collapses)" % down)
	check(built.size() == 4, "every trade built up to tier 1 (on days %s)" % [built])
	check(built.values().all(func(d): return d >= 10), "but none of them in the first ten days")
	check(leaks == 0, "and the money is accounted for every day")
