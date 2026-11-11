## Windowed screenshots of skateboarding: on the board, rolling, the ollie's crouch, a kickflip in the air and the $25 it
## sprays on the ground. Needs a real window and GPU.
##   godot --path . --script tools/capture_skate.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_skate_trick"
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
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	var sc: Scenario = game.scenario
	var p: PlayerController = game.player
	var w: World = game.world
	game.sim_paused = true
	p.teleport(Vector3(sc.start.x + 14.0, 0.1, sc.start.y), 0.0)
	var street: Vector2 = sc.start + (sc.start - sc.bike_shop.door).normalized() * 0.0
	p.look_toward(Vector3(sc.start.x + 14.0 + (sc._frame.dir as Vector2).x * 30.0, 1.0, sc.start.y + (sc._frame.dir as Vector2).y * 30.0))
	w.player.carry.add("skateboard", 1)
	game.skate_controller.toggle()
	await _frames(40)
	await _shot("1_on_the_board")
	Input.action_press("move_forward")
	await _frames(70)
	await _shot("2_rolling")
	Input.action_press("jump")
	await _frames(14)
	await _shot("3_winding_up_the_ollie")
	Input.action_release("jump")
	await _frames(14)
	await _shot("4_the_ollie")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(6)
	await _shot("5_the_kickflip")
	Input.action_release("move_forward")
	await _frames(100)
	await _shot("6_the_cash_on_the_ground")
	print("cash lying about: $", w.ledger.printed - 25.0)
	quit(0)
