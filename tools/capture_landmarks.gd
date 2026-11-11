## Windowed screenshots of the landmarks: the ECB (towers and market hall), the Paulskirche, the Kaiserdom and the
## Einheitsdenkmal, each from a distance and close up. Needs a real window and GPU.
##   godot --path . --script tools/capture_landmarks.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_landmarks"
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
	game.player.camera.far = 2500.0
	# the ECB: from the gate on the street, then from the south
	var gate: Vector2 = game.scenario.ecb_stop.doorman
	await _shot("ecb_from_the_gate", Vector3(gate.x, 2.0, gate.y), Vector3(2455, 90, -30))
	await _shot("ecb_from_afar", Vector3(2300, 30.0, 150), Vector3(2455, 80, -40))
	await _shot("ecb_hall", Vector3(2440, 12.0, 100), Vector3(2440, 15, -110))
	# the Paulskirche and the Einheitsdenkmal, the Dom
	await _shot("paulskirche", Vector3(790, 22.0, -380), Vector3(853, 14, -284))
	await _shot("einheitsdenkmal", Vector3(868, 3.0, -240), Vector3(885, 2.5, -257))
	await _shot("dom", Vector3(1100, 25.0, -150), Vector3(1181, 30, -226))
	await _shot("dom_close", Vector3(1130, 6.0, -300), Vector3(1170, 30, -240))
	# the Hauptbahnhof: the reception building from the square, and the halls from above the platforms
	await _shot("hbf_front", Vector3(-250, 8.0, 260), Vector3(-330, 18, 235))
	await _shot("hbf_halls", Vector3(-250, 70.0, 150), Vector3(-450, 10, 200))
	await _shot("hbf_side", Vector3(-380, 40.0, 420), Vector3(-450, 10, 250))
	quit(0)
