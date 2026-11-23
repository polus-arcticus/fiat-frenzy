## Sim tests: a runner's pay and the hero's stake in it (see Hauling). Cash on delivery: the shop pays the goods' worth into the
## town's fund and a flat fee for the trip to the runner, whatever the load. A runner's cart is a business the hero can invest in, for a share of every fee.
extends TestCase


func test_the_fee_is_flat_whatever_the_load() -> void:
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var bakery: Machine = rw[3]
	var runner: Drone = rw[4]
	var cart := runner.runner
	Fixtures.until(w, func(): return cart.deliveries >= 1, 200)
	var first := cart.fees_earned
	bakery.input.take("leftovers", 6)  # a smaller shortfall: six
	rw[1].output.add("leftovers", 10)
	Fixtures.until(w, func(): return cart.deliveries >= 2, 300)
	check(cart.deliveries == 2 and is_equal_approx(first, Hauling.DELIVERY_FEE) and is_equal_approx(cart.fees_earned, 2.0 * Hauling.DELIVERY_FEE), "ten units or six, a trip pays $%.0f (%d trips, $%.2f)" % [Hauling.DELIVERY_FEE, cart.deliveries, cart.fees_earned])
	check(is_equal_approx(w.total_money(), w.ledger.printed), "no money went missing")


func test_the_hero_can_invest_in_a_runner() -> void:
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var runner: Drone = rw[4]
	w.add_player(Vector2(50, 50))
	var wallet := runner.wallet
	var stake := w.gun.invest(runner, 10.0)
	check(stake > 0.3 and stake < Equity.MAX_STAKE, "$10 into a $%.0f cart buys a third of it (%d%%)" % [Runner.CART_VALUE, roundi(stake * 100.0)])
	check(is_equal_approx(runner.wallet, wallet + 10.0) and runner.growth.xp >= 10.0, "the runner has the money, and it counts as their experience")
	check(w.gun.invest(rw[5], 10.0) < 0.0, "a depot's attendant has no business to buy into: the contract is void")


func test_the_hero_takes_a_share_of_every_fee() -> void:
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var runner: Drone = rw[4]
	w.add_player(Vector2(50, 50))
	var stake := w.gun.invest(runner, 10.0)
	var pocket := w.ledger.player_cash
	var wallet := runner.wallet
	Fixtures.until(w, func(): return runner.runner.deliveries >= 1, 200)
	var cut := stake * Hauling.DELIVERY_FEE
	check(is_equal_approx(w.ledger.player_cash - pocket, cut), "the hero's pocket gets their share of the fee: $%.2f" % cut)
	check(is_equal_approx(runner.wallet - wallet, Hauling.DELIVERY_FEE - cut), "the runner keeps the rest (the goods' cost came back to it in full)")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "no money went missing")


func test_a_runner_is_capped_at_49_percent() -> void:
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var runner: Drone = rw[4]
	w.add_player(Vector2(50, 50))
	var r := w.gun.invest_ex(runner, 1000.0)
	check(is_equal_approx(r.stake, Equity.MAX_STAKE) and r.accepted < 1000.0, "never a majority: $%.0f of the $1000 went in" % r.accepted)


func test_the_stake_is_saved() -> void:
	var rw := Fixtures.runner_world()
	var w: World = rw[0]
	var runner: Drone = rw[4]
	w.add_player(Vector2(50, 50))
	var stake := w.gun.invest(runner, 10.0)
	var data = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var w2: World = Fixtures.runner_world()[0]
	w2.add_player(Vector2(50, 50))
	Snapshot.new(w2).apply(data)
	var again := w2.drones.filter(func(d): return d.kind == "runner")[0] as Drone
	check(is_equal_approx(again.runner.equity.share(w2.ledger.local), stake), "a save keeps the hero's share of the cart (its Runner component, through JSON)")
	var drifter := w2.drones.filter(func(d): return d.kind == "drifter")
	check(drifter.is_empty() or drifter[0].runner == null, "and someone who is not a runner has none")
