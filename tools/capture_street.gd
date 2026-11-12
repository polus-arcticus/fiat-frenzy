## Windowed screenshots of the landing street: the pavements out to the buildings, the stalls, tents, bus stop and medical bay,
## and a street with a bike lane. Needs a real window and GPU.
##   godot --path . --script tools/capture_street.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_street"
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


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	var to := Vector2(at.x - from.x, at.z - from.z)
	game.player.teleport(Vector3(from.x, from.y - 1.6, from.z), atan2(-to.x, -to.y))
	game.player.look_toward(at)
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	game.player.camera.far = 900.0
	var sc: Scenario = game.scenario
	var fr: Dictionary = sc._frame
	var dir: Vector2 = fr.dir
	var nrm := Vector2(-dir.y, dir.x)
	var mid: Vector2 = fr.point + dir * 10.0
	# from the middle of the street looking along it, and from above
	var a: Vector2 = fr.point + dir * -40.0
	var b: Vector2 = fr.point + dir * 40.0
	await _shot("1_along_the_street", Vector3(a.x, 2.2, a.y), Vector3(b.x, 1.5, b.y))
	await _shot("2_from_above", Vector3(mid.x, 60.0, mid.y + 0.5), Vector3(mid.x, 0.0, mid.y))
	await _shot("3_the_market", Vector3(mid.x - dir.x * 25.0, 3.0, mid.y - dir.y * 25.0), Vector3(mid.x, 1.5, mid.y))
	# the bus stop from the pavement, and the medical tent with its bay
	var stop: Dictionary = sc.bus_stop
	var bs: Vector2 = stop.pos
	var kerb_side: Vector2 = stop.kerb_side
	await _shot("4_the_bus_stop", Vector3(bs.x + kerb_side.x * 9.0 - (stop.dir as Vector2).x * 6.0, 2.4, bs.y + kerb_side.y * 9.0 - (stop.dir as Vector2).y * 6.0), Vector3(bs.x, 1.4, bs.y))
	var clinic: Hospital = game.world.hospitals[0]
	var bay: Vector2 = clinic.bay()
	await _shot("5_the_medical_tent", Vector3(bay.x + clinic.front.x * 9.0, 3.0, bay.y + clinic.front.y * 9.0), Vector3(clinic.pos.x, 1.2, clinic.pos.y))
	quit(0)
