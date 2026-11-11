## Windowed screenshots of the map (M): at the start, zoomed out over the whole district, and out at Battonnstraße.
## Needs a real window and GPU.   godot --path . --script tools/capture_map.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_map"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1400, 800)
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


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	game.sim_paused = true
	game.hud.visible = false
	game.map_screen.open()
	await _frames(5)
	await _shot("1_at_the_start")
	game.map_screen._scale = 0.36
	game.map_screen._center = Vector2(700, -200)
	await _shot("2_whole_district")
	var sage: Drone = game.scenario.cast.sage
	game.player.teleport(Vector3(sage.pos.x - 60, 0.1, sage.pos.y + 20), PI * 0.5)  # facing west, near the sage
	game.advance(0.1)
	game.map_screen._center = game.player.ground_pos()
	game.map_screen._scale = 1.4
	await _shot("3_at_battonnstrasse")
	quit(0)
