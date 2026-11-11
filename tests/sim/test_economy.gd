## Sim tests: economy. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_price_rule_per_craft() -> void:
	note("price rule, one craft at a time, with real inputs")
	var m := Machine.new("bakery", 0, Vector2.ZERO, true, false)
	m.output.caps["bread"] = 3
	m.input.caps["flour"] = 100
	m.input.add("flour", 100)
	var p0 := m.price
	check(is_equal_approx(m.floor_price(), 2.0) and is_equal_approx(p0, 2.0), "bread's floor is its inputs: 2 flour at $1")
	m.craft()
	check(is_equal_approx(m.price, p0 + m.tick) and m.stock() == 1, "empty output: price up one tick, unit made")
	m.craft()
	check(is_equal_approx(m.price, p0 + m.tick) and m.stock() == 2, "stock in the output: price holds")
	m.craft()
	check(m.stock() == 3 and is_equal_approx(m.price, p0 + m.tick), "filling the last slot: price holds")
	m.craft()
	check(is_equal_approx(m.price, p0) and m.stock() == 3, "output full: price down one tick, no unit made")
	m.craft()
	check(is_equal_approx(m.price, p0), "never below the input cost")
	var before := m.input.count("flour")
	m.output.take("bread", 3)
	m.craft()
	check(m.input.count("flour") == before - 2, "a craft consumes the recipe's inputs")
	m.input.take("flour", 1000)
	var made := m.crafted_total
	m.craft()
	check(m.crafted_total == made, "with an input missing nothing is made")
	m.receive("flour", 4, 12.0)
	check(is_equal_approx(m.floor_price(), 24.0), "a dear delivery raises the floor: 2 flour at $12 is $24")
	m.output.take("bread", 3)
	m.craft()
	check(m.price >= 24.0, "and the next craft lifts the price to it")


# ---------------------------------------------------------------- drones and Maslow


func test_truck_fills_input_inventories_twice_a_day() -> void:
	note("the delivery truck comes twice a day and fills up the shops' input inventories, free")
	var w := World.new()
	var baker := w.add_vendor("bakery", Vector2(0, 0), 5.0)
	var hot := w.add_vendor("hot_dog_stand", Vector2(10, 0), 5.0)
	var lem := w.add_vendor("lemonade_stand", Vector2(20, 0), 5.0)
	var broken := w.add_vendor("bakery", Vector2(30, 0), 5.0, false)
	var truck := w.add_relief_truck(Vector2(5, -5))
	Fixtures.empty_shops(w)
	var seen := []
	var was_here := false
	for i in int(Clock.DAY_SECONDS * 1.25):
		w.tick(1.0)
		if truck.present and not was_here:
			seen.append({"start": w.clock.time, "delivered": truck.last_delivery.duplicate()})
		elif not truck.present and was_here:
			seen.back()["end"] = w.clock.time
		was_here = truck.present
	note("    visits: %s" % [seen])
	check(seen.size() == 3 and is_equal_approx(seen[0].start, 90.0) and is_equal_approx(seen[1].start, 300.0) and is_equal_approx(seen[2].start, 690.0), "visits at 15% and 50% of each day")
	check(is_equal_approx(seen[0].end - seen[0].start, 100.0), "it stays 100 seconds")
	var m := w.machine_of(baker)
	check(seen[0].delivered == {"flour": 12, "protein": 6, "bottled_water": 6, "sugar": 6}, "the first visit filled exactly what the three working shops had room for")
	check(w.machine_of(broken).input.count("flour") == 0, "the broken bakery got nothing")
	check(not seen[1].delivered.has("protein"), "and the second visit brought no protein: the hot dog stand was already full of it")
	check(w.machine_of(hot).input.count("bread") == 0, "and bread is not on the truck: the hot dog stand has to buy it")
	check(is_equal_approx(w.total_money(), w.ledger.printed) and w.ledger.sunk == 0.0, "no money changed hands")
	check(is_equal_approx(m.input_cost["flour"], 1.0) and is_equal_approx(m.floor_price(), 2.0), "delivered goods cost their base price")
	check(seen[0].delivered["sugar"] == w.machine_of(lem).input.caps["sugar"], "the lemonade stand's sugar was filled")


func test_truck_shares_a_short_load() -> void:
	note("when the load is short, each shop that wants a good gets an equal share")
	var w := World.new()
	var a := w.add_vendor("bakery", Vector2(0, 0))
	var b := w.add_vendor("bakery", Vector2(10, 0))
	var c := w.add_vendor("bakery", Vector2(20, 0))
	var truck := w.add_relief_truck(Vector2.ZERO)
	truck.load_per_good = 9
	Fixtures.empty_shops(w)
	var given := truck.deliver(w.machines)
	var counts := [w.machine_of(a).input.count("flour"), w.machine_of(b).input.count("flour"), w.machine_of(c).input.count("flour")]
	check(given["flour"] == 9 and counts == [3, 3, 3], "nine flour, three bakeries, three each: %s" % [counts])
	truck.load_per_good = 100
	given = truck.deliver(w.machines)
	check(given["flour"] == 3 * (12 - 3) and w.machine_of(a).input.count("flour") == 12, "a big load stops once everyone is full")


func test_lemonade_needs_water_and_sugar() -> void:
	note("lemonade: a bottle of water and a spoon of sugar")
	var m := Machine.new("lemonade_stand", 0, Vector2.ZERO, true, false)
	check(m.recipe == {"bottled_water": 1, "sugar": 1} and is_equal_approx(m.floor_price(), 1.0), "the recipe, and a floor of 50c of each")
	m.input.take("sugar", 99)
	var made := m.crafted_total
	m.craft()
	check(m.crafted_total == made, "no sugar, no lemonade")
	m.receive("sugar", 2, 0.5)
	var water_before := m.input.count("bottled_water")
	var sugar_before := m.input.count("sugar")
	m.craft()
	check(m.crafted_total == made + 1, "with both it makes a glass")
	check(m.input.count("bottled_water") == water_before - 1 and m.input.count("sugar") == sugar_before - 1, "using one of each")


func test_the_truck_keeps_shops_running() -> void:
	note("the truck is what keeps the shops stocked: without it they run dry")
	var with_truck := Fixtures.town(true)
	var without := Fixtures.town(false)
	Fixtures.basic_gun_days(with_truck, 3)
	Fixtures.basic_gun_days(without, 3)
	note("    things made over three days: with the truck %d, without %d" % [Fixtures.made(with_truck), Fixtures.made(without)])
	check(Fixtures.made(with_truck) > 2 * Fixtures.made(without), "with deliveries the town makes more than twice as much")
	check(with_truck.machines[0].crafted_total > without.machines[0].crafted_total + 20, "the bakery most of all: it can't bake without flour")
	check(is_equal_approx(with_truck.total_money(), with_truck.ledger.printed) and is_equal_approx(without.total_money(), without.ledger.printed), "money is conserved in both")


func test_a_small_town_runs() -> void:
	note("a small town: every business trades")
	var w := Fixtures.town()
	w.gun.invest(w.drones[0], 30.0)
	Fixtures.basic_gun_days(w, 3)
	var drifters := w.drones.filter(func(d): return d.kind == "drifter")
	var hunger := 0.0
	var starved := 0
	for d in drifters:
		hunger += d.bars.hunger / drifters.size()
		starved += d.starved_ticks
	var s := w.machines.map(func(m): return "%s %d" % [m.kind, m.sold_total])
	note("    sold: %s | fire berths now %d | avg drifter hunger %.2f | starved-ticks %d | player cash %.2f" % [s, w.fires[0].shelter.berths.size(), hunger, starved, w.ledger.player_cash])
	note("    prices now: %s" % [w.machines.map(func(m): return "%s %.2f (floor %.2f)" % [m.kind, m.price, m.floor_price()])])
	# The tent is not counted: the free barrel fire answers the same need, so whether anyone pays for a bed is
	# down to the dice (its own test: night_is_colder_and_tent_docks_drones).
	check(w.machines.all(func(m): return m.kind == "tent" or m.sold_total > 0), "bakery, hot dogs and lemonade all did trade")
	check(w.ledger.player_cash > 0.0, "the player's share of the bakery paid out")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "money is conserved over three days")
	check(w.machines.all(func(m): return m.price >= m.floor_price() - 0.0001), "no price ever fell below its input cost")
