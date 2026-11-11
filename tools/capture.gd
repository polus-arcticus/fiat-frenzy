## Plays the game for a few beats and saves a screenshot of each. Needs a real window and GPU.
##   godot --path . --script tools/capture.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_shots"
var game: Node
var aerial: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true  # tools/capture_intro.gd takes the intro
	root.add_child(game)
	aerial = Camera3D.new()
	aerial.far = 1500.0
	root.add_child(aerial)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _aerial(pos: Vector3, target: Vector3) -> void:
	aerial.global_position = pos
	aerial.look_at(target, Vector3.UP)
	aerial.current = true


func _player_view() -> void:
	game.player.camera.current = true


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var hot: Drone = sc.cast.hot_dog
	var mid := Vector3(hot.pos.x + 3.0, 0, hot.pos.y)  # about the middle of the little market
	var street := sc.street_dir()
	var down := Vector2(mid.x, mid.z) - street * 11.0  # on the street, looking along it at the market
	var hot_front: Dictionary = sc.front_of(w.machine_of(hot), 5.0)

	await _shot("01_start")

	game.player.teleport(Vector3(hot_front.pos.x, 0.1, hot_front.pos.y), hot_front.yaw)
	game.player.look_toward(Vector3(hot.pos.x, 1.2, hot.pos.y))
	await _shot("02_hot_dog_vendor")

	_aerial(mid + Vector3(0, 90, 70), mid)
	await _shot("03_aerial_cast")

	_aerial(Vector3(0, 380, 330), Vector3(0, 0, 0))
	await _shot("04_district")

	# fund everyone and let the day run
	_player_view()
	for d in w.drones:
		if d.kind == "vendor":
			game.gun.apply(d, 70.0)
	game.sim.speed = 8.0
	await _frames(500)
	game.player.teleport(Vector3(down.x, 0.1, down.y))
	game.player.look_toward(mid + Vector3(0, 1.0, 0))
	await _shot("05_running")
	_aerial(mid + Vector3(0, 55, 45), mid)
	await _shot("06_aerial_running")

	# the bakery, close up, and its inventory screen
	var baker: Drone = sc.cast.bakery
	var bm := w.machine_of(baker)
	bm.output.add("bread", 7)
	bm.receive("flour", 4, 1.0)
	bm.refresh()
	_player_view()
	var bm_front: Dictionary = sc.front_of(bm, 3.2)
	game.player.teleport(Vector3(bm_front.pos.x, 0.1, bm_front.pos.y), bm_front.yaw)
	game.player.look_toward(Vector3(bm.pos.x, 1.3, bm.pos.y))
	await _frames(8)
	await _shot("09_bakery_close")
	game.interaction.open(bm)
	await _frames(4)
	for k in 3:
		w.commerce.buy(bm, "bread")
	w.commerce.consume("bread")
	game.inventory.refresh("Bought 1 bread for $2.10.")
	await _frames(4)
	await _shot("10_inventory")
	game.inventory.close()

	# survival bars over the NPCs' heads
	var d: Drone = w.drones[5]
	var back: Vector2 = d.pos - (sc._frame.dir as Vector2) * 7.0
	game.player.teleport(Vector3(back.x, 0.1, back.y), 0.0)
	game.player.look_toward(Vector3(d.pos.x, 1.7, d.pos.y))
	w.drones[5].bars.hunger = 0.35
	w.drones[5].bars.thirst = 0.6
	await _frames(10)
	await _shot("11_npc_bars")

	# the food bank, and a cart runner on a delivery
	var fb: FoodBank = w.food_banks[0]
	var fb_spot: Vector2 = fb.pos + fb.front * 7.0
	game.sim.speed = 1.0
	_player_view()
	game.player.teleport(Vector3(fb_spot.x, 0.1, fb_spot.y))
	game.player.look_toward(Vector3(fb.pos.x, 1.4, fb.pos.y))
	await _frames(10)
	await _shot("14_food_bank")
	var runner: Drone = sc.cast.runners[0]
	runner.wallet = 40.0
	for m in w.machines:
		if m.working:
			m.input.take("flour", 12)
			m.input.take("bottled_water", 12)
			m.input.take("sugar", 12)
	game.sim.speed = 4.0
	var carrying := false
	for i in 600:
		await _frames(1)
		if runner.cart.counts.values().any(func(n): return n > 0) and runner.pos.distance_to(runner.home) > 6.0:
			carrying = true
			break
	game.sim.speed = 1.0
	var behind: Vector2 = runner.pos - (sc._frame.dir as Vector2) * 6.0
	game.player.teleport(Vector3(behind.x, 0.1, behind.y))
	game.player.look_toward(Vector3(runner.pos.x, 1.0, runner.pos.y))
	await _frames(6)
	await _shot("15_runner_with_cart")
	print("runner carrying: ", carrying)

	# a level-up: the green bar fills and the stand grows
	game.sim.speed = 1.0
	var hot_front2: Dictionary = sc.front_of(w.machine_of(hot), 6.0)
	game.player.teleport(Vector3(hot_front2.pos.x, 0.1, hot_front2.pos.y), hot_front2.yaw)
	game.player.look_toward(Vector3(hot.pos.x, 1.5, hot.pos.y))
	await _frames(20)
	game.gun.apply(hot, 60.0)  # the first $70 made level 2; this takes the bar past $125
	await _frames(22)
	await _shot("16_level_up")
	await _frames(90)
	await _shot("17_stand_grown")

	# a burst of bills: in the air, then lying in the street
	game.sim.speed = 1.0
	_player_view()
	var ahead: Vector2 = sc.start + (sc._frame.dir as Vector2) * 7.0
	game.player.teleport(Vector3(sc.start.x, 0.1, sc.start.y), sc.start_yaw)
	game.player.look_toward(Vector3(ahead.x, 0.0, ahead.y))
	await _frames(5)
	for k in 26:
		game.gun.shoot()
		await _frames(1)
	await _frames(6)
	await _shot("12_bills_flying")
	await _frames(150)
	await _shot("13_loose_cash")

	# night
	w.clock.time = (Clock.NIGHT_FROM + 0.12) * Clock.DAY_SECONDS
	await _frames(5)
	_player_view()
	game.player.teleport(Vector3(down.x, 0.1, down.y))
	game.player.look_toward(mid + Vector3(0, 1.0, 0))
	await _shot("07_night")
	_aerial(mid + Vector3(0, 60, 50), mid)
	await _shot("08_night_aerial")
	print("done")
	quit()
