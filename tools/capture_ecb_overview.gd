## Windowed screenshot straight down on the European Central Bank site, with the bus stop, doorman and the tower's door marked.
##   godot --path . --script tools/capture_ecb_overview.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/ecb_overview"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 900)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game, out_dir)


func _run(game: Node, dir: String) -> void:
	for i in 20:
		await physics_frame
	game.sim_paused = true
	game.hud.visible = false
	var sc: Scenario = game.scenario
	var marks := {"stop": sc.ecb_stop.at, "doorman": sc.ecb_stop.doorman, "tower door": sc.ecb.door}
	for k in marks:
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.0
		cyl.bottom_radius = 2.0
		cyl.height = 60.0
		m.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.1, 0.1) if k == "stop" else (Color(0.1, 0.4, 1) if k == "doorman" else Color(0.1, 0.9, 0.2))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		m.position = Vector3(marks[k].x, 30.0, marks[k].y)
		game.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 340.0
	cam.far = 2000.0
	game.add_child(cam)
	cam.global_position = Vector3(2410, 600, -140)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	cam.current = true
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/overview.png" % dir)
	print("saved")
	quit()
