## Windowed screenshots of the gold glow on people who need help, and the HUD with several goals open together.
##   godot --path . --script tools/capture_aura.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_aura"
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
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _stand(at: Vector2, look_at: Vector2, eye := 1.6) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var cast: Dictionary = game.scenario.cast
	game.sim_paused = true
	var hot: Drone = cast.hot_dog
	_stand(hot.pos + Vector2(-1.5, -9.0), hot.pos, 1.4)
	await _frames(10)
	await _shot("1_the_market_glows")
	# fund the baker: his glow goes out, and the feed says what happened
	w.machine_of(cast.bakery).working = true
	await _frames(10)
	await _shot("2_the_baker_is_funded")
	quit(0)
