## Windowed screenshot of the inspector on someone with a job.
##   godot --path . --script tools/capture_inspector.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/inspector"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game, out_dir)


func _run(game: Node, out_dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	for d in w.drones:
		d.bars.hunger = 0.3
		d.wallet += 30.0
	for m in w.machines:
		m.working = true
	game.advance(40.0)
	var pick: Drone = null
	for d in w.drones:
		if not d.job.is_empty() and d.job.get("for") != "restock":
			pick = d
			break
	print("picked ", pick.id if pick else "none", " ", pick.job.get("for") if pick else "")
	game.inspector.toggle()
	game.inspector.select(pick)
	game.inspector.go_to_selected()
	for i in 30:
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/inspector.png" % out_dir)
	print("saved")
	quit()
