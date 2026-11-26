## Windowed screenshots of the European Central Bank's security gate: from the bus stop, close to the booth, and from above with
## the shuttle's route drawn, shut and open.
##   godot --path . --script tools/capture_gate.gd -- <output dir>
extends SceneTree

var game: Node


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/gate"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(out_dir)


func _shot(name: String, dir: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _stand(at: Vector2, look_at: Vector3, eye := 1.6) -> void:
	var to := Vector2(look_at.x, look_at.z) - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(look_at)


func _run(dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	var sc: Scenario = game.scenario
	var g: Dictionary = sc.ecb_gate
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	var stop: Vector2 = sc.ecb_stop.at
	var guard: Vector2 = g.guard
	# from the street, where the bus stops, looking at the gate
	_stand(stop + (g.along as Vector2) * 6.0 - (g.into as Vector2) * 3.0, Vector3(guard.x, 1.6, guard.y) + Vector3((g.into as Vector2).x, 0, (g.into as Vector2).y) * 6.0)
	await _shot("1_from_the_street", dir)
	_stand(guard - (g.into as Vector2) * 5.0, Vector3(guard.x, 1.5, guard.y))
	await _shot("2_the_guard", dir)
	# from inside, looking out at the shuttle
	var pad: Vector2 = g.pad
	_stand(pad + (g.into as Vector2) * 4.0, Vector3(pad.x, 0.8, pad.y))
	await _shot("3_the_shuttle", dir)
	# open
	w.quests.set_flag("cleared_gate")
	for i in 240:
		await physics_frame
	_stand(stop + (g.along as Vector2) * 6.0 - (g.into as Vector2) * 3.0, Vector3(guard.x, 1.6, guard.y) + Vector3((g.into as Vector2).x, 0, (g.into as Vector2).y) * 6.0)
	await _shot("4_open", dir)
	quit()
