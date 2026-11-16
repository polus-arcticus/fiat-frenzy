## Windowed screenshots of the market across the street from the European Central Bank's gate: from where the bus stops, up close
## at the stands, and from above.
##   godot --path . --script tools/capture_ecb_market.gd -- <output dir>
extends SceneTree

var game: Node


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/ecb_market"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(out_dir)


func _shot(name: String, dir: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _stand(at: Vector2, look_at: Vector3) -> void:
	var to := Vector2(look_at.x, look_at.z) - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(look_at)


func _run(dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	var sc: Scenario = game.scenario
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	var mid: Machine = w.machine_of(sc.cast.ecb_hot_dog)
	var from: Vector2 = sc.ecb_stop.bus
	_stand(from + (mid.front as Vector2) * -1.0, Vector3(mid.pos.x, 1.2, mid.pos.y))
	await _shot("1_from_the_bus", dir)
	_stand(mid.pos + (mid.front as Vector2) * 4.0, Vector3(mid.pos.x, 1.2, mid.pos.y))
	await _shot("2_the_stands", dir)
	var fb: FoodBank = w.food_banks[1]
	_stand(fb.pos + (fb.front as Vector2) * 5.0, Vector3(fb.pos.x, 1.2, fb.pos.y))
	await _shot("3_the_food_bank", dir)
	var h: Hospital = w.hospitals[1]
	_stand(h.pos + (h.toward_street as Vector2) * 5.0 if "toward_street" in h else h.pos + Vector2(5, 0), Vector3(h.pos.x, 1.2, h.pos.y))
	await _shot("4_the_clinic", dir)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 120.0
	cam.far = 2000.0
	game.add_child(cam)
	cam.global_position = Vector3(mid.pos.x, 400, mid.pos.y)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	cam.current = true
	await _shot("5_from_above", dir)
	quit()
