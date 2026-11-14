## Windowed screenshot: candidate skins for the hero, in a row beside the NPC builder they must not be mistaken for.
## Needs a real window and GPU.
##   godot --path . --script tools/capture_skins.gd -- <output dir>
extends SceneTree

var out_dir := "/home/thdev/proto/ff3d/captures/skins"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 600)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game)


func _run(game: Node) -> void:
	for i in 20:
		await physics_frame
	game.sim_paused = true
	var sc: Scenario = game.scenario
	var base := Vector3(sc.start.x, 0.0, sc.start.y)
	var skins := [
		["builder", "res://assets/models/builder.glb", Color.WHITE],
		["dealer", "res://assets/models/dealer.glb", Color.WHITE],
		["banker", "res://assets/models/banker.glb", Color.WHITE],
		["builder_blue", "res://assets/models/builder.glb", Color(0.55, 0.75, 1.2)],
		["dealer_blue", "res://assets/models/dealer.glb", Color(0.6, 0.8, 1.2)],
		["banker_red", "res://assets/models/banker.glb", Color(1.25, 0.7, 0.6)],
	]
	var holder := Node3D.new()
	root.add_child(holder)
	var x := -5.0
	for s in skins:
		var m: Node3D = Look.model(load(s[1]))
		if s[2] != Color.WHITE:
			var mat: ShaderMaterial = Watercolor.surface().duplicate()
			mat.set_shader_parameter("tint", s[2])
			Watercolor.apply(m, mat)
		m.position = base + Vector3(x, 0.0, 0.0)
		m.rotation.y = 0.0
		holder.add_child(m)
		print(s[0], " at ", x)
		x += 2.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = base + Vector3(0.0, 1.5, 6.5)
	cam.look_at(base + Vector3(0.0, 1.0, 0.0))
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/skins.png" % out_dir)
	print("saved")
	quit()
