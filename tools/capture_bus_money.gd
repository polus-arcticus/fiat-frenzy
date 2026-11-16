## Windowed screenshots: money fired inside the moving bus lies on its floor, and the map watches the ride.
##   godot --path . --script tools/capture_bus_money.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/bus_money"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game, out_dir)


func _shot(name: String, dir: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _run(game: Node, dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	var p: PlayerController = game.player
	var bus: BusView = game.bus
	w.gun_owned = true
	game.gun.set_enabled(true)
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	p.teleport(bus.seat_point(), bus.rotation.y + PI)
	p.level_gaze()
	p.sit(bus, BusView.SEAT_LOCAL)
	w.hero.enter(Hero.Mode.SEATED)
	p.controls_enabled = false
	w.transit.board(game.scenario.ecb_stop.bus, "rode_bus", [])
	for i in 200:
		await physics_frame
	# look down at the floor and fire
	p.look(0.0, -0.55)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for k in 8:
		game.gun.bill_value = 5.0
		game.gun.shoot()
		for i in 12:
			await physics_frame
	for i in 60:
		await physics_frame
	var aboard := w.bills.filter(func(b): return b.aboard)
	print("on the floor: %d piles, $%d; the bus has gone %.0f m from its stop; bills left in the street: %d" % [aboard.size(), aboard.reduce(func(a, b): return a + b.value, 0.0), w.bus.pos.distance_to(w.bus_stop), w.bills.filter(func(b): return not b.aboard).size()])
	await _shot("1_floor", dir)
	var key := InputEventAction.new()
	key.action = "map"
	key.pressed = true
	game._unhandled_input(key)
	for i in 30:
		await physics_frame
	await _shot("2_map_riding", dir)
	for i in 120:
		await physics_frame
	await _shot("3_map_later", dir)
	quit()
