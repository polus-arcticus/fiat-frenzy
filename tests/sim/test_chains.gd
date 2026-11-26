## Sim tests: the economy is data. A new raw good, its source, and two businesses that make one thing of another are rows (a
## Catalog item and business each, a source in WasteBin.KINDS) and nothing else; the cart runners carry each leg of the chain:
## wood from its pile to the carpenter, the carpenter's planks off their shelf to the joiner.
extends TestCase


func _add_wood_trade() -> void:
	Catalog.add_item(ItemDef.new("wood", "material", 0.0))
	Catalog.add_item(ItemDef.new("plank", "material", 1.0))
	Catalog.add_item(ItemDef.new("chair", "material", 6.0))
	WasteBin.add_kind("woodpile", {"item": "wood", "rate": 6.0, "cap": 60, "start": 40, "label": "wood", "map": ""})
	var carpenter := MachineDef.new("carpenter", "Carpenter", "plank")
	carpenter.inputs = {"wood": 2}
	carpenter.rate = 3.0
	carpenter.cap = 30
	Catalog.add_machine(carpenter)
	var joiner := MachineDef.new("joiner", "Joiner", "chair")
	joiner.inputs = {"plank": 2}
	joiner.fetch = {"plank": "runner"}  # (the one line that makes it a chain: the runners bring its planks)
	joiner.rate = 2.0
	joiner.cap = 10
	Catalog.add_machine(joiner)


func _take_it_away() -> void:
	WasteBin.remove_kind("woodpile")
	for id in ["wood", "plank", "chair", "carpenter", "joiner"]:
		Catalog.remove(id)


func test_a_new_raw_good_and_two_new_trades_are_only_data() -> void:
	_add_wood_trade()
	var w := World.new()
	var pile := w.add_bin("woodpile", Vector2(-20, 0))
	var carpenter_owner := w.add_vendor("carpenter", Vector2(0, 0), 40.0, true, false)
	var carpenter := w.machine_of(carpenter_owner)
	var joiner_owner := w.add_vendor("joiner", Vector2(20, 0), 40.0, true, false)
	var joiner := w.machine_of(joiner_owner)
	var runner := w.add_runner(Vector2(0, 4), 20.0)
	check(Catalog.item("wood").scavenged and Catalog.machine("carpenter").fetched_by("wood") == "runner", "wood is a raw good from its pile, and the runners bring it")
	check(carpenter.input.caps.has("wood") and joiner.input.caps.has("plank") and carpenter.stock() == 0 and joiner.stock() == 0, "two new businesses, empty-handed")
	Fixtures.run(w, 600, true)
	check(carpenter.crafted_total > 0, "the carpenter made planks of the wood the runner brought from the pile (%d)" % carpenter.crafted_total)
	check(joiner.crafted_total > 0 and joiner.input_cost.has("plank"), "and the joiner made chairs of the planks the runner bought off the carpenter's shelf (%d)" % joiner.crafted_total)
	check(carpenter.sold_total > 0 and carpenter_owner.wallet > 0.0, "the carpenter was paid for them ($%.2f), %d sold" % [carpenter_owner.wallet, carpenter.sold_total])
	check(runner.runner.deliveries >= 2 and pile.output.count("wood") < 60, "the runner made the trips (%d), both legs" % runner.runner.deliveries)
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and the money adds up")
	_take_it_away()
