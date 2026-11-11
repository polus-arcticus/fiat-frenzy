## Sim tests: the bike shop and the bicycle. A business worth millions that sells one bike for $3,000.
extends TestCase


func _shop(cash := Catalog.bike_price()) -> Array:
	var w := World.new()
	var owner := w.add_vendor("bike_shop", Vector2(0, 0), 500.0, true, true)
	var shop := w.machine_of(owner)
	shop.front = Vector2(0, 1)
	w.add_player(Vector2(0, 2.5), 0.0)
	w.ledger.player_cash = cash
	w.ledger.printed += cash
	return [w, owner, shop]


func test_the_shop_is_open_stocked_and_priced() -> void:
	var sw := _shop()
	var shop: Machine = sw[2]
	check(shop.working and shop.stock() == 1 and shop.offers("bicycle"), "the shop starts open, with one bicycle on the floor")
	check(shop.price_of("bicycle") == Catalog.bike_price() and Catalog.bike_price() == shop.price, "a bicycle costs what the catalog says")
	check(not Catalog.is_consumable("bicycle") and Catalog.class_of("bicycle") == "vehicle", "and it isn't something to eat")
	var w: World = sw[0]
	for i in 600:
		w.tick(1.0)
	check(shop.price == Catalog.bike_price() and shop.stock() == 1, "ten minutes on, the price hasn't moved and the shop still has its one bike: it makes nothing")


func test_the_owner_has_no_needs_and_stays_at_the_counter() -> void:
	var sw := _shop()
	var w: World = sw[0]
	var owner: Drone = sw[1]
	var shop: Machine = sw[2]
	for i in 2000:
		w.tick(1.0)
	check(owner.bars.hunger == 1.0 and owner.bars.thirst == 1.0 and owner.bars.warmth == 1.0 and owner.care == "", "three and a half days on, the owner is as well as ever and never collapses")
	check(owner.pos.distance_to(shop.post()) < 0.6, "and is still behind the counter, not wandering off for lunch")


func test_investing_or_gifting_is_futile() -> void:
	var sw := _shop()
	var w: World = sw[0]
	var owner: Drone = sw[1]
	var shop: Machine = sw[2]
	check(shop.value() >= 2000000.0, "the business is worth about $%s" % str(int(shop.value())))
	var r := w.gun.hit_contract(w.gun.fire_contract(GunController.CONTRACT_MAX), owner)
	check(r.result == "invest" and r.stake < 0.0002, "a full $250 contract buys %.4f%% of it" % (r.stake * 100.0))
	check(shop.investable() > 900000.0, "the 49%% cap is $%s away" % str(int(shop.investable())))
	var level0 := shop.level
	for i in 20:
		w.gun.gift(owner, 100.0)
	check(is_equal_approx(shop.price, Catalog.bike_price()) and shop.stock() == 1 and shop.rate_per_min == 0.0 * 1.25, "$2,000 of gifts later the shop is the same: same price, same one bike (level %d)" % shop.level)
	check(is_equal_approx(w.total_money(), w.ledger.printed), "money is conserved")


func test_buying_the_bike() -> void:
	var sw := _shop(2999.0)
	var w: World = sw[0]
	var owner: Drone = sw[1]
	var shop: Machine = sw[2]
	var r := w.commerce.buy(shop, "bicycle")
	check(not r.ok and r.text.begins_with("Not enough cash") and w.bike == null and shop.stock() == 1, "$1 short: refused, and nothing happens")
	w.ledger.player_cash = Catalog.bike_price()
	w.ledger.printed += 1.0
	var owner_before := owner.wallet
	r = w.commerce.buy(shop, "bicycle")
	check(r.ok and w.bike != null and not w.bike.riding, "with $3,000 you get a bike")
	check(w.ledger.player_cash == 0.0 and is_equal_approx(owner.wallet, owner_before + Catalog.bike_price()), "the $3,000 went to the owner")
	check(shop.stock() == 0 and not shop.offers("bicycle"), "and the shop is sold out of bicycles")
	check(w.bike.pos.distance_to(w.player.pos) < 1.5 and w.player.carry.count("bicycle") == 0, "the bike waits beside you; it isn't in your bag")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "money is conserved")
	w.ledger.player_cash = 5000.0
	w.ledger.printed += 5000.0
	check(not w.commerce.buy(shop, "bicycle").ok, "and you can't buy a second one")


func test_riding_the_bike() -> void:
	var sw := _shop()
	var w: World = sw[0]
	check(not w.riding.mount().ok and w.riding.speed_factor() == 1.0, "no bike, nothing to ride")
	w.commerce.buy(sw[2], "bicycle")
	w.player.pos = w.bike.pos + Vector2(Riding.MOUNT_REACH + 2.0, 0)
	check(not w.riding.mount().ok and not w.bike.riding, "you can't get on a bike that is across the street")
	w.player.pos = w.bike.pos + Vector2(1.0, 0)
	var r := w.riding.mount()
	check(r.ok and w.bike.riding and w.riding.riding(), "next to it, you can")
	check(w.riding.speed_factor() > 2.0 and w.riding.speed_factor() < 3.0, "and you go about two and a half times as fast (x%.1f)" % w.riding.speed_factor())
	w.player.pos = Vector2(40, 40)
	w.riding.follow_player()
	check(w.bike.pos == Vector2(40, 40), "the bike goes where you go")
	r = w.riding.dismount(1.5)
	check(r.ok and not w.bike.riding and w.bike.pos == Vector2(40, 40) and w.bike.heading == 1.5 and w.riding.speed_factor() == 1.0, "getting off parks it where you stand")
	check(not w.riding.dismount().ok, "you can't get off what you aren't on")
	w.player.care = "down"
	check(not w.riding.mount().ok, "and you can't get on while you're out cold")


func test_saving_for_the_bike_is_the_tutorial_goal() -> void:
	var sw := _shop(0.0)
	var w: World = sw[0]
	var owner: Drone = sw[1]
	var hot := w.add_vendor("hot_dog_stand", Vector2(20, 0), 0.0, false, false)
	var baker := w.add_vendor("bakery", Vector2(25, 0), 0.0, false, false)
	var tent := w.add_vendor("tent", Vector2(30, 0), 0.0, false, false)
	var t := Tutorial.new(w, {"hot_dog": hot, "bakery": baker, "tent": tent, "bike_shop": owner}, false)
	var save := -1
	for i in t.steps.size():
		var line: Variant = t.steps[i].text
		if (line.call() if line is Callable else line).begins_with("Save $%d" % int(Catalog.bike_price())):
			save = i
	check(save >= 0, "the tutorial has a 'save for a bicycle' step")
	t.index = save
	check(t.text().contains("$0 of $%d" % int(Catalog.bike_price())) and t.marker() == (sw[2] as Machine).pos, "it shows how much you have of $3000, and points at the counter")
	w.ledger.player_cash = 1234.0
	check(t.text().contains("$1234 of $%d" % int(Catalog.bike_price())), "and the number moves with your money")
	t.update(w.player.pos)
	check(t.index == save, "not done until the money is there")
	w.ledger.player_cash = Catalog.bike_price()
	t.update(w.player.pos)
	check(t.index == save + 1 and t.text().contains("press E at the counter"), "with $3000 it moves on to buying the bike")
	w.commerce.buy(sw[2], "bicycle")
	t.update(w.player.pos)
	check(t.index == save + 2 and t.text().contains("Press F"), "once you own it, it tells you to get on")
	w.riding.mount()
	t.update(w.player.pos)
	check(t.index > save + 2, "and once you are riding it moves on")
