## Sim tests: putting things down in the street (see Placing): a barrel fire from the bag is a fire that warms; a tent founds a
## tent city of its own at tier 0, kept by a newcomer. What a right-click in the bag does is the item's to say (ItemDef.use).
extends TestCase


func _world() -> World:
	var w := World.new()
	w.add_player(Vector2.ZERO).make_needless()
	return w


func test_each_item_says_what_using_it_does() -> void:
	check(Catalog.item("bread").use() == "consume" and Catalog.item("bottled_water").use() == "consume", "bread and water are eaten and drunk")
	check(Catalog.item("old_coat").use() == "equip" and Catalog.item("old_bike").use() == "equip", "a coat and a bike go into the loadout")
	check(Catalog.item("barrel_fire").use() == "place" and Catalog.item("tent").use() == "place", "a barrel fire and a tent are put down")
	check(Catalog.item("scrap").use() == "" and Catalog.item("letter").use() == "", "scrap and a letter are only carried")
	var w := _world()
	w.player.carry.add("barrel_fire", 1)
	check(not w.commerce.consume("barrel_fire").ok and w.player.carry.count("barrel_fire") == 1, "a barrel fire is not eaten")


func test_a_barrel_put_down_is_a_fire() -> void:
	var w := _world()
	w.player.carry.add("barrel_fire", 1)
	var fires := w.fires.size()
	var r := w.placing.place("barrel_fire", Vector2(3, 0))
	check(r.ok and w.fires.size() == fires + 1 and w.player.carry.count("barrel_fire") == 0, "it's a barrel fire, out of the bag (%s)" % r.text)
	check(w.fires.back().pos == Vector2(3, 0) and w.arrivals.has(w.fires.back()), "where it was put, and the views are told")
	var cold := w.add_drifter(Vector2(3.8, 0), 0.0)
	cold.aloof = true
	cold.bars.warmth = 0.3
	w.clock.time = (Clock.NIGHT_FROM + 0.05) * Clock.DAY_SECONDS
	Fixtures.run(w, 10)
	check(cold.bars.warmth > 0.3, "and it warms whoever is beside it (%.2f)" % cold.bars.warmth)


func test_not_just_anywhere() -> void:
	var w := _world()
	w.player.carry.add("barrel_fire", 2)
	check(not w.placing.can_place("barrel_fire", Vector2(20, 0)), "not out of reach: %s" % w.placing.why_not("barrel_fire", Vector2(20, 0)))
	w.add_vendor("bakery", Vector2(0, 4), 5.0)
	check(not w.placing.can_place("barrel_fire", Vector2(0, 4.5)), "not on a stand: %s" % w.placing.why_not("barrel_fire", Vector2(0, 4.5)))
	w.nav.add_static("district", PackedVector2Array([Vector2(-3, -5), Vector2(3, -5), Vector2(3, -3), Vector2(-3, -3)]))
	check(not w.placing.can_place("barrel_fire", Vector2(0, -4)), "not in a wall: %s" % w.placing.why_not("barrel_fire", Vector2(0, -4)))
	check(w.placing.can_place("barrel_fire", Vector2(-3, 1)), "but on open ground, yes")
	check(not w.placing.can_place("tent", Vector2(-3, 1)), "and only what you have: %s" % w.placing.why_not("tent", Vector2(-3, 1)))


func test_a_tent_put_down_founds_a_tent_city() -> void:
	var w := _world()
	w.player.carry.add("tent", 1)
	var printed := w.ledger.printed
	var r := w.placing.place("tent", Vector2(4, 0), Vector2(-1, 0))
	var city: Machine = w.machines.back()
	var keeper := w.drone(city.owner)
	check(r.ok and city.kind == "tent" and city.tier == 0 and city.working and city.residence.tents == 1, "a tent city of its own, tier 0, standing, one tent (%s)" % r.text)
	check(keeper != null and keeper.bed == city.uid and keeper.label != "" and keeper.arrived_at >= 0.0 and w.lodging.is_housed(keeper), "kept by a newcomer, %s, who lives in it" % (keeper.label if keeper else "?"))
	check(city.front == Vector2(-1, 0) and w.arrivals.has(city) and w.arrivals.has(keeper), "its open end toward the hero, and the views are told")
	check(is_equal_approx(w.ledger.printed - printed, Lodging.NEWCOMER_PURSE) and is_equal_approx(w.total_money(), w.ledger.printed), "nothing printed but the purse its keeper brought")
	check(w.lodging.add_tent(city),"and it grows as any does: a tent put up there")
	w.begin_play()
	Fixtures.run(w, int(Lodging.ARRIVE_EVERY) + 2)
	check(w.lodging.housed(city).size() == 2, "brings someone new to live in it")


func test_it_is_saved() -> void:
	var w := _world()
	w.player.carry.add("tent", 1)
	w.player.carry.add("barrel_fire", 1)
	w.placing.place("tent", Vector2(4, 0))
	w.placing.place("barrel_fire", Vector2(-3, 0))
	var data = JSON.parse_string(JSON.stringify(Snapshot.new(w).capture()))
	var w2 := World.new()
	w2.add_player(Vector2.ZERO)
	Snapshot.new(w2).apply(data)
	var cities := w2.machines.filter(func(m): return m.kind == "tent")
	check(cities.size() == 1 and w2.fires.size() == 1 and w2.lodging.housed(cities[0]).size() == 1, "a save keeps the tent city, its keeper and the fire")
