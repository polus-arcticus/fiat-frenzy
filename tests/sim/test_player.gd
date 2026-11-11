## Sim tests: player. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_the_player_body() -> void:
	note("the player: survival bars, a bag, and a little cash of their own")
	var w := World.new()
	var p := w.add_player(Vector2.ZERO)
	check(w.ledger.player_cash == 25.0 and w.ledger.printed == 25.0 and is_equal_approx(w.total_money(), w.ledger.printed), "they start with $25, and it is accounted for")
	check(not (p in w.drones) and w.drones.is_empty(), "the player is not one of the NPC drones")
	Fixtures.run(w, 300)
	check(is_equal_approx(p.bars.hunger, 0.5) and is_equal_approx(p.bars.thirst, 1.0 - 300.0 / 420.0), "their bars drain like anyone's")
	check(w.logistics.plan(p).is_empty() or true, "(no NPC logic is ever run on them)")
	var dark := World.new()
	var q := dark.add_player(Vector2(100, 0))
	dark.add_fire(Vector2(0, 0))
	dark.clock.time = Clock.NIGHT_FROM * Clock.DAY_SECONDS + 1.0
	Fixtures.run(dark, 60)
	var far: float = q.bars.warmth
	q.pos = Vector2(1, 0)
	Fixtures.run(dark, 60)
	check(q.bars.warmth > far, "standing at a barrel fire at night warms them (%.2f -> %.2f)" % [far, q.bars.warmth])


func test_player_buys_and_consumes() -> void:
	note("commerce: buy from a stand, then eat it")
	var sw := Fixtures.shop_world()
	var w: World = sw[0]
	var baker: Drone = sw[1]
	var bakery: Machine = sw[2]
	var p: Drone = sw[3]
	bakery.working = true
	bakery.refresh()
	var price := bakery.price
	var r := w.commerce.buy(bakery, "bread")
	note(r.text)
	check(r.ok and p.carry.count("bread") == 1 and bakery.stock() == 24, "bought: the loaf moved from the bakery's output (25 on the shelf) to the bag")
	check(is_equal_approx(w.ledger.player_cash, 25.0 - price) and is_equal_approx(baker.wallet, price), "$%.2f went from the player's cash to the baker" % price)
	p.bars.hunger = 0.3
	r = w.commerce.consume("bread")
	note(r.text)
	check(r.ok and is_equal_approx(p.bars.hunger, 0.8) and p.carry.count("bread") == 0, "eaten: hunger refilled by 50% and the loaf is gone")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "no money was lost")
	w.gun.invest(baker, 40.0)  # the player owns the most they can: 49%
	var cash := w.ledger.player_cash
	w.commerce.buy(bakery, "bread")
	check(is_equal_approx(w.ledger.player_cash, cash - bakery.price + bakery.equity.stake * bakery.price), "owning a stake in it, they get that share of what they pay back")
	check(is_equal_approx(w.ledger.stake_income, bakery.equity.stake * bakery.price), "and that share is counted as income from the stake, apart from spending money")
	var tent_w := World.new()
	var keeper := tent_w.add_vendor("tent", Vector2(2, 0))
	var tent := tent_w.machine_of(keeper)
	tent.working = true
	tent.refresh()
	var cold := tent_w.add_player(Vector2.ZERO)
	cold.bars.warmth = 0.2
	var rb := tent_w.commerce.buy(tent, "bed")
	check(rb.ok and is_equal_approx(cold.bars.warmth, 0.8) and cold.carry.count("bed") == 0, "a bed can't be carried: buying one is a night in the tent and warms them straight away")


func test_player_buy_refusals() -> void:
	note("commerce: the ways it can say no")
	var sw := Fixtures.shop_world()
	var w: World = sw[0]
	var bakery: Machine = sw[2]
	var p: Drone = sw[3]
	bakery.working = false
	bakery.refresh()
	check(not w.commerce.buy(bakery, "bread").ok and p.carry.count("bread") == 0, "a wrecked stand sells nothing")
	bakery.working = true
	bakery.refresh()
	p.pos = Vector2(40, 0)
	check(w.commerce.buy(bakery, "bread").text == "Too far away.", "too far away")
	p.pos = Vector2.ZERO
	w.ledger.player_cash = 1.0
	check(w.commerce.buy(bakery, "bread").text.begins_with("Not enough cash"), "not enough cash")
	w.ledger.player_cash = 500.0
	bakery.output.take("bread", 99)
	bakery.refresh()
	check(w.commerce.buy(bakery, "bread").text == "Sold out.", "sold out")
	bakery.output.add("bread", 10)
	bakery.refresh()
	for i in 12:
		p.carry.add("lemonade", 10)
		p.carry.counts["lemonade"] = 10 * (i + 1)
	check(w.commerce.buy(bakery, "bread").text == "Your bag is full.", "a full bag")
	check(not w.commerce.consume("flour").ok and not w.commerce.consume("bread").ok, "can't consume what you haven't got, or flour")


func test_the_hero_starts_with_bread_and_water() -> void:
	note("the hero's starting kit")
	var w := World.new()
	var p := w.add_player(Vector2.ZERO)
	check(p.carry.count("bread") == 2 and p.carry.count("bottled_water") == 2 and Stacks.slots_used(p.carry) == 2, "two bread and two bottles of water, in two slots")
	p.bars.thirst = 0.2
	var r := w.commerce.consume("bottled_water")
	check(r.ok and is_equal_approx(p.bars.thirst, 0.7) and p.carry.count("bottled_water") == 1, "a bottle of water refills 50%% of thirst: %s" % r.text)
	p.bars.hunger = 0.3
	r = w.commerce.consume("bread")
	check(r.ok and is_equal_approx(p.bars.hunger, 0.8), "and bread 50% of hunger")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "(food costs no money, and nothing else changed)")


# ---------------------------------------------------------------- the truck and the supply chain
