## Scene suite section: The inventory screen at the bakery, and buying and eating.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var baker: Drone = game.scenario.cast.bakery
	# the inventory screen at the bakery
	check(w.player.carry.count("bread") == 2 and w.player.carry.count("bottled_water") == 2, "the hero starts with 2 bread and 2 bottled water")
	w.player.carry.counts.clear()  # the next checks are about buying and eating from a bag that starts empty
	var bm: Machine = w.machine_of(baker)
	bm.output.add("bread", 6)
	bm.refresh()
	var front: Dictionary = game.scenario.front_of(bm, 2.5)
	game.player.teleport(Vector3(front.pos.x, 0.1, front.pos.y), front.yaw)
	game.player.look_toward(Vector3(bm.pos.x, 1.2, bm.pos.y))
	for i in 4:
		await tree.physics_frame
	check(game.interaction.aimed_machine() == bm, "aiming at the bakery up close picks it out, even with neighbours a few metres away")
	var down_street: Vector2 = bm.pos + game.scenario.street_dir() * 30.0
	game.player.teleport(Vector3(down_street.x, 0.1, down_street.y))
	game.player.look_toward(Vector3(bm.pos.x, 1.2, bm.pos.y))
	for i in 4:
		await tree.physics_frame
	check(game.interaction.aimed_machine() == null, "but not from 30 m down the street")
	game.player.teleport(Vector3(front.pos.x, 0.1, front.pos.y), front.yaw)
	game.interaction.open(bm)
	await tree.process_frame  # the game copies the player's position into the model every frame
	await tree.process_frame
	var screen: InventoryScreen = game.inventory
	check(screen.visible and not game.player.controls_enabled, "E opens the screen and pauses the player's controls")
	check(screen._bag.get_child_count() == Commerce.CARRY_SLOTS, "the player's bag shows %d slots" % Commerce.CARRY_SLOTS)
	check(screen._wants.get_child_count() == 1, "and the bakery's wants (its input inventory): one row, for flour")
	var flour_row: HBoxContainer = screen._wants.get_child(0)
	check(flour_row.get_child(0).tooltip_text.begins_with("flour"), "that row is a flour slot")
	check(screen._sale.get_child_count() == Stacks.slots_for(bm.capacity()), "the bakery's stock shows one slot per ten loaves of shelf: %d (it has levelled up to %d)" % [Stacks.slots_for(bm.capacity()), bm.level])
	var cash0 := w.ledger.player_cash
	var sale_slot: SlotView = null
	for c in screen._sale.get_children():
		if c.tooltip_text.begins_with("Right-click to buy"):
			sale_slot = c
			break
	check(sale_slot != null, "the bakery's bread is on the right, for sale")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	sale_slot._gui_input(right_click)
	check(w.player.carry.count("bread") == 1 and w.ledger.player_cash < cash0, "right-clicking it buys a loaf: it is in the bag and cash went down")
	check(screen._message.text.begins_with("Bought 1 bread"), "and the screen says so: \"%s\"" % screen._message.text)
	var bag_slot: SlotView = null
	for c in screen._bag.get_children():
		if c.tooltip_text == "Right-click to use":
			bag_slot = c
			break
	check(bag_slot != null, "the loaf shows in the player's bag")
	w.player.bars.hunger = 0.3
	bag_slot._gui_input(right_click)
	check(w.player.carry.count("bread") == 0 and is_equal_approx(w.player.bars.hunger, 0.8), "right-clicking it eats it: hunger 30% to 80%")
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	var before_stock := bm.stock()
	sale_slot._gui_input(left_click)
	check(bm.stock() == before_stock, "a left-click does nothing")
	screen.close()
	check(not screen.visible and game.player.controls_enabled, "closing gives the controls back (mouse mode is checked in the windowed run: it can't be captured headless)")
	game.player.teleport(Vector3(front.pos.x, 0.1, front.pos.y), front.yaw)
	game.interaction.open(bm)
	game.player.teleport(Vector3(down_street.x, 0.1, down_street.y))
	game.world.player.pos = game.player.ground_pos()
	for i in 3:
		await tree.process_frame
	check(not screen.visible, "and walking away closes it")

