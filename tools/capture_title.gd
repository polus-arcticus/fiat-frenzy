## Windowed screenshots of the welcome screen and the loading cinematic.
##   godot --path . --script tools/capture_title.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/title"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	_run(out_dir)


func _shot(name: String, dir: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _run(dir: String) -> void:
	var title: Control = load("res://title.tscn").instantiate()
	root.add_child(title)
	await create_timer(0.6).timeout
	await _shot("1_title", dir)
	var loading := LoadingScreen.new()
	root.add_child(loading)
	var last := 0.0
	for t in [0.9, 1.7, 2.05, 2.7, 3.4]:
		await create_timer(t - last).timeout
		last = t
		if t >= 2.05 and t < 2.5:
			loading.holding = true
		if t > 2.5:
			loading.release()
		await _shot("2_loading_%03d" % int(t * 100), dir)
	quit()
