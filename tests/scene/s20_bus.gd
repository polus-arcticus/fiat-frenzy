## Scene suite section: aboard (the tram). The map can be opened from a seat and follows you as it moves, and (below) what
## happens to money fired inside it.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off
## (the tram is at the stop for the European Central Bank, and the hero is free).
extends SceneSection


func run() -> void:
	var p: PlayerController = game.player
	var w: World = game.world
	var mp: MapScreen = game.map_screen
	var car: TramView = game.quest_controller.tram_view()
	var model: Vehicle = w.transit.vehicle(Scenario.TRAM_QUEST)
	var gate: Vector3 = car.kerb_point()
	# in a seat, as the ride leaves them: controls off, the tram carrying them
	p.teleport(car.seat_point(), car.rotation.y + PI)
	p.sit(car, car.seat_local())
	w.hero.enter(Hero.Mode.SEATED)
	p.controls_enabled = false
	game.advance(0.2)
	var map_key := InputEventAction.new()
	map_key.action = "map"
	map_key.pressed = true
	game._unhandled_input(map_key)
	await tree.process_frame
	check(mp.visible and not p.controls_enabled and p.is_seated(), "M opens the map from a seat on the tram, and the hero stays seated")
	var before: Vector2 = p.ground_pos()
	model.pos += Vector2(40, 0)
	model.prev_pos = model.pos
	car.place(model.pos, car.rotation.y)
	p.update_seat()
	await tree.process_frame
	check(p.ground_pos().distance_to(before) > 30.0 and mp.to_screen(p.ground_pos()).distance_to(mp._root.size * 0.5) < 1.0, "it moves 40 m and the map keeps you in the middle: you can watch yourself ride")
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(30, 0)
	mp._dragging = true
	mp._on_gui_input(drag)
	mp._dragging = false
	check(not mp._follow, "dragging the map away stops it following")
	var key_c := InputEventKey.new()
	key_c.pressed = true
	key_c.physical_keycode = KEY_C
	mp._unhandled_input(key_c)
	check(mp._follow and mp.to_screen(p.ground_pos()).distance_to(mp._root.size * 0.5) < 1.0, "C brings it back to you, following again")
	mp.close()
	check(not p.controls_enabled and p.is_seated(), "closing the map leaves the ride as it was: no controls handed back, still seated")
	# Tab opens the bag from the seat: to eat and drink on the way
	w.player.carry.add("bread", 1)
	w.player.bars.hunger = 0.2
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	game.interaction._unhandled_input(tab)
	check(game.inventory.visible and game.inventory.machine == null, "Tab opens the bag from a seat on the tram")
	game.interaction._on_use("bread")
	check(w.player.bars.hunger > 0.2 and w.player.carry.count("bread") == 0, "and eating from it works while it rolls")
	game.inventory.close()
	check(not p.controls_enabled and p.is_seated(), "closing it leaves the ride as it was: still seated, no controls")
	# back as they were
	model.pos -= Vector2(40, 0)
	model.prev_pos = model.pos
	car.place(model.pos, car.rotation.y)
	w.hero.stand()
	p.stand()
	p.teleport(Vector3(gate.x, 0.1, gate.z), 0.0)
	p.controls_enabled = true
	game.advance(0.2)

	# money fired inside: it falls inside, on the floor, and rides with it
	model.aboard = true
	model.speed = 15.0
	w.hero.enter(Hero.Mode.SEATED)
	var fwd := Vector2.from_angle(model.heading)
	var start_local := Vector3(0.2, 1.6, 0.5)
	var bill := w.gun.fire(10.0, "cash")
	var shot := BillProjectile.new().launch(bill, w, car.to_global(start_local), car.global_basis * Vector3(0.0, -1.0, 2.0), Callable())
	game.add_child(shot)
	var drove := 0.0
	var in_frame := false
	for i in 90:  # it drives on at 15 m/s while it is in the air
		model.pos += fwd * 0.25
		model.prev_pos = model.pos
		drove += 0.25
		await tree.physics_frame
		in_frame = in_frame or (is_instance_valid(shot) and shot.frame != null)
		if bill.aboard:
			break
	check(in_frame, "fired from a seat, the shot flies in the tram's own frame")
	check(bill.aboard and bill.ride == model.name and bill.loose and w.bills.has(bill), "it lands on the floor of the tram")
	check(bill.local.distance_to(Vector2(start_local.x, start_local.z)) < 3.0 and drove > 1.0, "near where it was fired, not %.1f m back down the road where the tram was" % drove)
	for i in 3:
		await tree.process_frame
	check(game.bills_view._piles.has(bill) and game.bills_view._piles[bill].get_parent() == car, "its pile is drawn in the tram, on the floor, so it rides with it")
	var kept: Vector2 = bill.local
	model.pos += fwd * 60.0
	model.prev_pos = model.pos
	w.tick(0.1)
	check(bill.local == kept and bill.pos.is_equal_approx(model.to_world(kept)), "60 m on, it is still on the same bit of floor")
	# and out of the open door, the paper is in the street's frame again, with the tram's speed
	var door: CollisionShape3D = car._door_blocks[car.side][1]  # (the front doorway on that side)
	door.disabled = true
	var out_bill := w.gun.fire(4.0, "cash")
	var out_shot := BillProjectile.new().launch(out_bill, w, car.to_global(Vector3(car.side * 0.4, 1.4, TramView.DOOR_Z)), car.global_basis * Vector3(car.side * 6.0, 0.5, 0.0), Callable())
	game.add_child(out_shot)
	var left := false
	for i in 120:
		model.pos += fwd * 0.1
		model.prev_pos = model.pos
		await tree.physics_frame
		if not is_instance_valid(out_shot):
			break
		if out_shot.frame == null:
			left = true
	check(left and not out_bill.aboard and out_bill.loose and w.bills.has(out_bill), "fired out of the open door, it leaves the tram's frame and lands in the street")
	# put it all back
	door.disabled = false
	model.pos -= fwd * (60.0 + drove + 12.0)
	model.prev_pos = model.pos
	model.speed = 0.0
	model.aboard = false
	w.hero.stand()
	w.commerce.scoop_aboard(model)
