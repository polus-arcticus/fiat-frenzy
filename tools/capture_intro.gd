## Plays the helicopter intro in a real window and saves a screenshot of each beat.
##   godot --path . --script tools/capture_intro.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_intro"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await create_timer(1.3).timeout
	await _shot("1_falling")
	await create_timer(2.4).timeout
	await _shot("2_impact")
	await create_timer(1.2).timeout
	await _shot("3_aftermath")
	await create_timer(3.4).timeout
	await _shot("4_gun_at_feet")
	print("done")
	quit()
