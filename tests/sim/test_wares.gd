## Sim tests: wares, what a stand makes and sells besides its own item (MachineDef.wares). The tent city's keeper makes tents and
## barrel fires of scrap, sold at their flat price like anything on a stand.
extends TestCase


func _city() -> Array:
	var w := World.new()
	var keeper := w.add_vendor("tent", Vector2.ZERO, 0.0, true, true)
	var city := w.machine_of(keeper)
	w.add_player(city.pos + Vector2(0, 2))
	return [w, city, keeper]


func test_the_tent_city_sells_tents_and_barrels() -> void:
	var c := _city()
	var city: Machine = c[1]
	check(city.offers("tent") and city.offers("barrel_fire") and not city.offers("bed"), "its shelf: tents and barrel fires (its beds are homes, not for sale)")
	check(is_equal_approx(city.price_of("tent"), 15.0) and is_equal_approx(city.price_of("barrel_fire"), 5.0), "at their flat prices: a tent $15, a barrel $5")
	check(city.output.offer.has("tent") and city.output.offer.has("barrel_fire"), "and the town can see them on offer")


func test_they_are_made_of_scrap() -> void:
	var c := _city()
	var w: World = c[0]
	var city: Machine = c[1]
	city.output.take("tent", city.output.count("tent"))
	city.output.take("barrel_fire", city.output.count("barrel_fire"))
	city.input.counts["scrap"] = 0
	city.input.add("scrap", 6)
	city.craft()
	city.craft()
	check(city.output.count("tent") == 1 and city.output.count("barrel_fire") == 1 and city.input.count("scrap") == 0, "four scrap make a tent and two a barrel, the emptiest first (%d tents, %d barrels, %d scrap left)" % [city.output.count("tent"), city.output.count("barrel_fire"), city.input.count("scrap")])
	city.craft()
	check(city.output.count("tent") == 1, "and with no scrap, nothing")
	check(city.input.caps["scrap"] == city.per_craft("scrap") * Catalog.machine("tent").stock_crafts + Catalog.machine("hostel").build_scrap, "its store holds the wares' scrap and the hostel's (%d)" % city.input.caps["scrap"])
	var _w := w


func test_the_hero_buys_one_into_the_bag() -> void:
	var c := _city()
	var w: World = c[0]
	var city: Machine = c[1]
	var keeper: Drone = c[2]
	var wallet := keeper.wallet
	var r := w.commerce.buy(city, "tent")
	check(r.ok and w.player.carry.count("tent") == 1, "bought like anything else: it's in the bag (%s)" % r.text)
	check(is_equal_approx(keeper.wallet - wallet, 15.0) and is_equal_approx(w.total_money(), w.ledger.printed), "the keeper has the $15, and the money adds up")


func test_building_up_waits_on_the_wares_scrap() -> void:
	var c := _city()
	var w: World = c[0]
	var city: Machine = c[1]
	city.working = true
	city.input.counts["scrap"] = Catalog.machine("hostel").build_scrap
	check(w.trades.can_build(city) == "", "200 scrap isn't enough while the wares' stock is short")
	city.input.counts["scrap"] = city.input.caps["scrap"]
	check(w.trades.can_build(city) == "hostel", "with its store full, it builds up into a hostel")
