## Windowed screenshots of the shuttle ride from the gate to the bank's door, in real time: from the seat as it sets off, going round
## the market hall, along the plaza, and the receptionist at the door.
##   godot --path . --script tools/capture_shuttle.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/shuttle"
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
	var sc: Scenario = game.scenario
	game.gun.set_enabled(false)
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	w.quests.state[QuestBook.LETTER] = "active"
	w.player.carry.add("letter", 1)
	for f in ["rode_bus", "jam_cleared", "rode_on", "cleared_gate"]:
		w.quests.set_flag(f)
	w.sage.tell(Stories.FIRST)
	var cart: ShuttleView = game.shuttle
	var k: Vector3 = cart.kerb_point()
	game.player.teleport(Vector3(k.x, 0.1, k.z), 0.0)
	game.advance(0.3)
	await physics_frame
	game.quest_controller.ride_shuttle()  # (real time: not awaited, so the shots can be taken during it)
	await create_timer(4.0).timeout
	await _shot("1_setting_off", dir)
	for t in [14.0, 14.0, 14.0, 14.0]:
		await create_timer(t).timeout
		await _shot("2_en_route_%d" % int(w.shuttle.s), dir)
		if w.shuttle.state != Bus.State.DRIVING:
			break
	while w.shuttle.state == Bus.State.DRIVING:
		await create_timer(1.0).timeout
	await create_timer(5.0).timeout
	await _shot("3_arrived", dir)
	var desk: Drone = w.ecb_receptionist
	game.player.look_toward(Vector3(desk.pos.x, 1.5, desk.pos.y))
	await _shot("4_the_receptionist", dir)
	quit()
