## Sim tests: the clothing trade (see Catalog "clothing"). A thrift stall stitches old coats from the street's scrap, which runners
## bring it; built up with money it is a clothing shop, which makes proper coats. Clothes are gear: they go in the loadout.
extends TestCase


func _accounted(w: World) -> bool:
	return is_equal_approx(w.total_money(), w.ledger.printed)


func _stall(cash := 100.0) -> Array:
	var w := World.new()
	var stall := Camp.pitch(w, Vector2.ZERO, Vector2(0, 1), 50.0, "thrift_stall", "Thrift seller")
	w.add_runner(Vector2(4, 3), 5.0)
	w.add_player(stall.pos + stall.front * 2.0, 0.0)
	w.player.carry.counts.clear()
	w.player.make_needless()
	w.ledger.player_cash = cash
	w.ledger.printed += cash
	return [w, stall]


func test_runners_bring_scrap_and_the_stall_stitches_coats() -> void:
	var s := _stall()
	var w: World = s[0]
	var stall: Machine = s[1]
	check(stall.recipe.has("scrap"), "a thrift stall makes old coats of scrap")
	var scrap_before := stall.input.count("scrap")
	stall.output.take("old_coat", 100)  # (it opens with a few on the rail: clear them, so it has room to make more)
	Fixtures.run(w, 1800, true)
	var made := stall.crafted_total
	check(made * stall.recipe.scrap > scrap_before, "the runner gathers scrap from the street and the stall stitches coats of it: %d made, more than the %d scrap it began with could make" % [made, scrap_before])
	check(_accounted(w), "the money is accounted for")


func test_the_hero_buys_an_old_coat_and_wears_it() -> void:
	var s := _stall()
	var w: World = s[0]
	var stall: Machine = s[1]
	Fixtures.run(w, 900, true)
	var r := w.commerce.buy(stall, "old_coat")
	check(r.ok and w.player.gear.count("old_coat") == 1 and is_equal_approx(w.ledger.player_cash, 100.0 - Catalog.item("old_coat").price), "an old coat for $%.0f, straight into the loadout: %s" % [Catalog.item("old_coat").price, r.text])
	check(is_equal_approx(w.loadout.insulation(), Catalog.item("old_coat").insulation) and w.loadout.insulation() > 0.0, "and it keeps some cold out (insulation %.1f)" % w.loadout.insulation())
	check(_accounted(w), "the money is accounted for")


func test_built_up_it_is_a_clothing_shop_with_proper_coats() -> void:
	var s := _stall(200.0)
	var w: World = s[0]
	var stall: Machine = s[1]
	var owner := w.drone(stall.owner)
	owner.wallet += 500.0
	w.ledger.printed += 500.0
	w.trades.day = -1
	w.trades.step(1.0)
	check(stall.kind == "clothing_shop" and stall.trade == "clothing" and stall.tier == 1, "with money saved, its owner builds it up into a clothing shop")
	check(is_equal_approx(stall.price, Catalog.item("coat").price), "which sells coats at a coat's price ($%.0f)" % stall.price)
	Fixtures.run(w, 900, true)
	var r := w.commerce.buy(stall, "coat")
	check(r.ok and w.loadout.insulation() >= Catalog.item("coat").insulation, "a coat keeps out more: %s" % r.text)
	check(_accounted(w), "the money is accounted for")
