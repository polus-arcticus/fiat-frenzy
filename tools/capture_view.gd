## Windowed screenshots of the third-person view: standing, walking, aiming at someone, and with a wall behind (the arm
## pulls in). Needs a real window and GPU.
##   godot --path . --script tools/capture_view.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_view"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1200, 700)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	var sc: Scenario = game.scenario
	var p: PlayerController = game.player
	game.sim_paused = true
	p.teleport(Vector3(sc.start.x, 0.1, sc.start.y), 0.0)
	var hot: Drone = sc.cast.hot_dog
	p.look_toward(Vector3(hot.pos.x, 1.4, hot.pos.y))
	p.set_third_person(true)
	await _frames(40)
	await _shot("1_standing")
	Input.action_press("move_forward")
	await _frames(45)
	await _shot("2_walking")
	Input.action_release("move_forward")
	await _frames(20)
	# the camera behind them against a wall: stand with their back to a building
	var door: Vector2 = sc.bike_shop.door
	var out: Vector2 = sc.bike_shop.out
	var at: Vector2 = door + out * 2.0 + (sc.bike_shop.along as Vector2) * 5.0
	p.teleport(Vector3(at.x, 0.1, at.y), atan2(out.x, out.y))  # facing out: the wall behind them
	p.level_gaze()
	await _frames(50)
	await _shot("3_back_to_a_wall")
	p.set_third_person(false)
	await _frames(30)
	await _shot("4_first_person_again")
	quit(0)
