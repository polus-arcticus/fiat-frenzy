## Sim tests: core. Each test_* method is run by tests/run.gd, which reseeds the RNG before it.
extends TestCase


func test_inventory_and_flags() -> void:
	note("inventory and logistics flags")
	var a := Inventory.new()
	var b := Inventory.new()
	a.caps["bread"] = 3
	check(a.add("bread", 5) == 3 and a.count("bread") == 3, "a slot with a capacity takes only what fits")
	check(a.move_to(b, "bread", 2) == 2 and b.count("bread") == 2 and a.count("bread") == 1, "items move between inventories")
	var m := Machine.new("bakery", 0, Vector2.ZERO, false)
	check(m.output.offer.is_empty(), "a broken bakery offers nothing")
	m.working = true
	m.refresh()
	check(m.output.offer["bread"] == 25, "a working one offers its output stock (half of 50)")
	check(m.input.want["flour"] == 8 and m.input.caps["flour"] == 12, "and its input inventory wants the flour it has room for (it holds six crafts' worth, 12)")
	check(not ("money" in m.output.counts) and not ("money" in m.input.counts), "money is not an item in any inventory")
	var t := ReliefTruck.new(Vector2.ZERO)
	check(not t.present and t.visits == 0, "the truck starts out of town")
	check("sugar" in Catalog.relief_goods() and Catalog.base_price("sugar") > 0.0, "sugar is a good the truck carries")


func test_components() -> void:
	note("components: the price rule, equity and shelter stand on their own")
	check(is_equal_approx(Pricing.after_craft(2.0, 2.0, 0.1, 0, 5), 2.1), "price rule: empty output, price up a tick")
	check(is_equal_approx(Pricing.after_craft(2.1, 2.0, 0.1, 3, 5), 2.1), "price rule: stock on hand, holds")
	check(is_equal_approx(Pricing.after_craft(2.1, 2.0, 0.1, 5, 5), 2.0), "price rule: full, down a tick")
	check(is_equal_approx(Pricing.after_craft(2.0, 2.0, 0.1, 5, 5), 2.0), "price rule: never below the floor")
	check(is_equal_approx(Pricing.after_craft(1.0, 24.0, 0.1, 3, 5), 24.0), "price rule: a price under the floor is lifted to it")
	var e := Equity.new()
	check(is_equal_approx(e.value(40.0, 0.0), 40.0) and is_equal_approx(e.value(40.0, 60.0), 100.0), "equity: a business is worth its rebuild cost plus the experience (money given) it has had")
	check(is_equal_approx(e.buy(20.0, 40.0, 0.0), 20.0) and is_equal_approx(e.stake, 1.0 / 3.0) and is_equal_approx(e.cut_of(9.0), 3.0), "equity: $20 into a $40 business buys a third, and a third of a $9 sale is $3")
	var took := e.buy(1000.0, 40.0, 20.0)
	check(is_equal_approx(e.stake, 0.49) and is_equal_approx(took, (0.49 - 1.0 / 3.0) * 60.0 / 0.51), "equity: a huge offer only buys up to the 49%% cap, and only that much is accepted ($%.2f)" % took)
	check(e.buy(10.0, 40.0, 20.0) == 0.0 and e.room(40.0, 20.0) == 0.0, "equity: at the cap nothing more is accepted")
	var part := Equity.new()
	part.buy(20.0, 40.0, 0.0)
	check(part.room(40.0, 160.0) > part.room(40.0, 0.0) * 2.0, "equity: under the cap, a business that has had more experience takes more dollars to reach it (more room)")
	check(is_equal_approx(Equity.new().cost_to_reach(0.5, 40.0, 0.0), 40.0), "equity: half of a fresh $40 business would cost $40")
	var sh := Shelter.new(1, 0.002)
	var d := Drone.new(0, Vector2.ZERO)
	check(sh.has_room(), "shelter: has a spot")
	sh.admit(d)
	check(not sh.has_room() and d.sheltered_in == sh, "shelter: admitting a drone fills it and tags the drone")
	sh.release(d)
	check(sh.has_room() and d.sheltered_in == null, "shelter: releasing frees it")
	var rt := ReliefTruck.new(Vector2.ZERO)
	check(rt.load_per_good >= 10 and rt.load_per_good <= 20, "the Red Cross van brings a small free load: %d of each good" % rt.load_per_good)


func test_stacks() -> void:
	note("stacks: one kind of item to a slot, ten to a stack")
	var inv := Inventory.new()
	inv.add("bread", 13)
	inv.add("flour", 4)
	check(Stacks.slots_used(inv) == 3, "13 bread and 4 flour is three slots")
	var layout := Stacks.layout(inv)
	check(layout.size() == 3 and layout[0] == {"item": "bread", "count": 10} and layout[1] == {"item": "bread", "count": 3} and layout[2].item == "flour", "laid out as 10 bread, 3 bread, 4 flour")
	check(Stacks.can_add(inv, "bread", 3), "there is room in the second bread stack even in a full bag")
	check(not Stacks.can_add(inv, "lemonade", 3) and Stacks.can_add(inv, "lemonade", 4), "but a new kind of item needs a free slot")
	inv.add("flour", 6)
	check(Stacks.slots_used(inv) == 3 and not Stacks.can_add(inv, "flour", 3), "a full stack of ten needs a new slot for the eleventh")


func test_everything_is_born_in_the_zone_being_built() -> void:
	var w := World.new()
	var a := w.add_vendor("bakery", Vector2(0, 0), 5.0)
	check(a.zone == "district" and w.machines[a.station].zone == "district", "the default zone is the district")
	w.build_zone = "old_town"
	var b := w.add_vendor("bakery", Vector2(900, 0), 5.0)
	var c := w.add_drifter(Vector2(905, 3))
	check(b.zone == "old_town" and c.zone == "old_town", "people join the zone being built")
	check(w.machines[b.station].zone == "old_town", "and a vendor's stand is in its owner's zone")
	check(a.zone == "district", "earlier ones stay put")


func _two_towns() -> World:
	var w := World.new()
	w.add_vendor("bakery", Vector2(0, 0), 5.0)
	w.add_drifter(Vector2(3, 0), 20.0)
	w.build_zone = "far"
	w.add_vendor("bakery", Vector2(900, 0), 5.0)
	w.add_drifter(Vector2(903, 0), 20.0)
	return w


func test_a_drone_only_shops_in_its_own_zone() -> void:
	var w := _two_towns()
	w.machines[0].output.add("bread", 5)
	w.machines[1].output.add("bread", 5)
	var near := w.logistics.supply.best_supply(w.drones[1], "food")
	var far := w.logistics.supply.best_supply(w.drones[3], "food")
	check(near == w.machines[0], "the district drone is served by the district bakery")
	check(far == w.machines[1], "the far drone by the far one, though nothing else differs")
	w.zones.send(w.drones[3], "district", Vector2(3, 0))
	check(w.logistics.supply.best_supply(w.drones[3], "food") == w.machines[0], "move zone and the choice follows")


func test_only_active_zones_tick() -> void:
	var w := _two_towns()
	w.zones.active = ["district"]
	var before: float = w.drones[3].bars.hunger
	var near_before: float = w.drones[1].bars.hunger
	for i in 30:
		w.tick(1.0)
	check(w.drones[3].bars.hunger == before, "a sleeping zone's people do not get hungry")
	check(w.drones[1].bars.hunger < near_before, "the active zone's people do")
	w.zones.active = []
	w.tick(1.0)
	check(w.drones[3].bars.hunger < before, "with no fence, everyone runs")


func test_the_catalog_is_consistent() -> void:
	for id in ["bakery", "hot_dog_stand", "lemonade_stand", "tent", "bike_shop"]:
		var m := Catalog.machine(id)
		check(Catalog.item(m.item) != null, "%s makes a known item" % id)
		for raw in m.inputs:
			check(Catalog.item(raw) != null and Catalog.base_price(raw) > 0.0, "%s's input %s is a known item with a price" % [id, raw])
		check(not Catalog.footprint_of(id).is_empty(), "%s has a footprint" % id)
	var shop := Machine.new("bike_shop", 0, Vector2.ZERO)
	check(shop.price == Catalog.bike_price(), "the bike shop sells at the bicycle's one price")


func test_a_sleeping_zone_keeps_producing_in_jumps() -> void:
	var w := World.new()
	w.add_vendor("bakery", Vector2(0, 0), 5.0)
	w.build_zone = "far"
	var baker := w.add_vendor("bakery", Vector2(900, 0), 5.0)
	var far_shop := w.machine_of(baker)
	far_shop.output.take("bread", far_shop.stock())
	far_shop.input.add("flour", 20)
	var hunger_before: float = baker.bars.hunger
	w.zones.active = ["district"]
	for i in 9:
		w.tick(1.0)
	check(far_shop.stock() == 0, "nothing yet: a dormant zone only runs in coarse jumps")
	for i in 31:
		w.tick(1.0)
	check(far_shop.stock() > 0, "after a while its shelves have filled, though nobody was there")
	check(baker.bars.hunger == hunger_before and baker.pos == Vector2(900, 0), "and its people have not moved")


func test_rings_and_send_carry_people_between_zones_without_losing_money() -> void:
	var w := World.new()
	w.add_player(Vector2.ZERO, 40.0)
	var a := Portal.new(Vector2(0, 0), Vector2(0, 1), "a")
	var b := Portal.new(Vector2(500, 0), Vector2(1, 0), "b")
	b.zone = "far"
	w.portals.add_pair(a, b)
	var before := w.ledger.total(w.drones, w.bills)
	w.portals.cross(w.player, a)
	check(w.player.zone == "far" and w.player.pos.is_equal_approx(b.exit_point()), "walking through a ring takes the hero to the twin's zone")
	var walker := w.add_drifter(Vector2(5, 5), 12.0)
	check(w.zones.send(walker, "far", Vector2(510, 0)) and walker.zone == "far" and walker.wallet == 12.0, "a drifter can be sent, with their money")
	var vendor := w.add_vendor("bakery", Vector2(20, 0), 3.0)
	check(not w.zones.send(vendor, "far", Vector2(1, 1)) and vendor.zone == "district", "but a vendor is tied to their stand")
	w.zones.follow_player()
	check(w.zones.active == ["far"], "the fence can follow the hero")
	check(is_equal_approx(w.ledger.total(w.drones, w.bills), before + 12.0 + 3.0), "money is conserved across the crossing")
	var books := w.zones.books()
	check(is_equal_approx(float(books.get("far", 0.0)), 12.0) and is_equal_approx(float(books.get("district", 0.0)), 3.0), "each zone's books show its own money")


func test_things_in_another_zone_do_not_help_you() -> void:
	var w := World.new()
	var a := w.add_drifter(Vector2(0, 0), 0.0)
	w.build_zone = "far"
	var b := w.add_drifter(Vector2(1, 0), 0.0)
	var bill := Bill.new(5.0, "cash")
	bill.zone = "far"
	bill.loose = true
	bill.pos = Vector2(1, 1)
	w.bills.append(bill)
	check(w.cash.nearest_loose(a.pos, 14.0, a.zone) == null, "loose money in another zone is not noticed")
	check(w.cash.nearest_loose(b.pos, 14.0, b.zone) == bill, "but is by someone in its own")


func test_searches_and_walking_see_only_their_own_zone() -> void:
	var w := _two_towns()
	check(w.zones.machines_in("district").size() == 1 and w.zones.machines_in("far").size() == 1, "each zone lists its own machines")
	check(w.zones.solids_in("district").size() == 1 and w.zones.solids_in("far").size() == 1, "and its own solids: a walker is never tested against the rest of the world")
	check(w.zones.drones_in("far").size() == 2 and w.zones.runners_in("far").is_empty(), "and its own people")
	w.zones.send(w.drones[3], "district", Vector2(3, 0))
	check(w.zones.drones_in("far").size() == 1 and w.zones.drones_in("district").size() == 3, "moving someone updates both lists")
	check(w.zones.machines_in("nowhere").is_empty() and w.zones.all_zones().size() == 2, "an empty zone is just empty")
