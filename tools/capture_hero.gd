## Windowed screenshot: the hero in third person, beside a builder and a banker, to see they are not mistaken for either.
##   godot --path . --script tools/capture_hero.gd -- <output dir>
extends SceneTree

var out_dir := "/home/thdev/proto/ff3d/captures/hero"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1200, 700)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game)


func _run(game: Node) -> void:
	for i in 20:
		await physics_frame
	var p: PlayerController = game.player
	var sc: Scenario = game.scenario
	game.sim_paused = true
	p.teleport(Vector3(sc.start.x, 0.1, sc.start.y), 0.0)
	p.set_third_person(true)
	for i in 50:
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/hero_walk.png" % out_dir)
	Input.action_press("move_forward")
	for i in 40:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/hero_walk2.png" % out_dir)
	Input.action_release("move_forward")
	print("saved")
	quit()
