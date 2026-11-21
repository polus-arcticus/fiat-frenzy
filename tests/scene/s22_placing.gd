## Scene suite section: putting things down (see Placing, PlacementController), by the real path: E at the tent city, buy a
## barrel fire and a tent, right-click them in the bag, and the ghost; a left click puts it down, a right click puts it back.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func _click(button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await tree.process_frame
	await tree.process_frame


func _bag_slot(item: String) -> SlotView:
	for c in game.inventory._bag.get_children():
		if c is SlotView and c.tooltip_text != "" and c.item == item:
			return c
	return null


func run() -> void:
	var w: World = game.world
	var city: Machine = w.machine_of(game.scenario.cast.tent)
	w.player.make_needless()
	w.player.needless = false
	w.ledger.player_cash += 40.0
	w.ledger.printed += 40.0
	w.player.carry.counts.clear()
	var at: Vector2 = city.pos + city.front * 2.5
	game.player.teleport(Vector3(at.x, 0.1, at.y), 0.0)
	game.player.look_toward(Vector3(city.pos.x, 1.0, city.pos.y))
	for i in 3:
		await tree.physics_frame
	game.interaction.open(city)
	await tree.process_frame
	var screen: InventoryScreen = game.inventory
	check(screen.visible and screen._residents.visible and screen._cards.get_child_count() >= city.tents, "E at the tent city opens the trading screen, with who lives there")
	for item in ["barrel_fire", "tent"]:
		for c in screen._sale.get_children():
			if c is SlotView and c.item == item and c.tooltip_text.begins_with("Right-click to buy"):
				c.right_clicked.emit()
				break
	check(w.player.carry.count("barrel_fire") == 1 and w.player.carry.count("tent") == 1, "a barrel fire and a tent bought from its shelf, like anything else")
	var slot := _bag_slot("barrel_fire")
	check(slot != null and slot.tooltip_text.contains("put it down"), "in the bag, a barrel fire says it is put down, not eaten")
	slot.right_clicked.emit()
	await tree.process_frame
	await tree.process_frame
	check(not screen.visible and game.placement.placing() and game.player.controls_enabled, "right-clicked: the bag closes and the ghost comes out")
	var street: Vector2 = game.scenario.offset_on_street(game.scenario.start, 14.0, 0.0)
	game.player.teleport(Vector3(street.x, 0.1, street.y), 0.0)
	var ahead: Vector2 = street + game.scenario.street_dir() * 3.0
	game.player.look_toward(Vector3(ahead.x, 0.0, ahead.y))
	for i in 3:
		await tree.process_frame
	await _click(MOUSE_BUTTON_RIGHT)
	check(not game.placement.placing() and w.player.carry.count("barrel_fire") == 1, "a right click puts it back in the bag")
	game.interaction.open_player()
	await tree.process_frame
	_bag_slot("barrel_fire").right_clicked.emit()
	for i in 3:
		await tree.process_frame
	var fires := w.fires.size()
	await _click(MOUSE_BUTTON_LEFT)
	check(w.fires.size() == fires + 1 and w.player.carry.count("barrel_fire") == 0 and not game.placement.placing(), "a left click puts it down: a barrel fire, %.1f m ahead" % w.fires.back().pos.distance_to(street))
	check(game.get_children().any(func(c): return c is FireView and c.fire == w.fires.back()), "and it is drawn")
