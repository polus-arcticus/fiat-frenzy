## Windowed screenshots of the sky at dawn, noon, dusk and night, and of the bars over heads close up. Needs a real window and GPU.
##   godot --path . --script tools/capture_sky.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_sky"
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
	var w: World = game.world
	var sc: Scenario = game.scenario
	var p: PlayerController = game.player
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	p.camera.far = 900.0
	var dir: Vector2 = sc._frame.dir
	p.teleport(Vector3(sc.start.x, 0.1, sc.start.y), atan2(-dir.x, -dir.y))
	p.look_toward(Vector3(sc.start.x + dir.x * 50.0, 22.0, sc.start.y + dir.y * 50.0))
	for pair in [["1_dawn", 0.033], ["2_morning", 0.2], ["3_noon", 0.5], ["4_dusk", 0.585], ["5_night", 0.9]]:
		w.clock.time = float(pair[1]) * Clock.DAY_SECONDS
		await _frames(6)
		await _shot(pair[0])
	quit(0)
