## Windowed screenshots of the rescue: the medical tent, a collapsed drifter, the ambulance on its call,
## patients in cots, and the hero passing out. Needs a real window and GPU.
##   godot --path . --script tools/capture_rescue.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_rescue"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
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


func _stand(spot: Vector2, look_at: Vector2) -> void:
	var to := look_at - spot
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, 1.0, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var h: Hospital = w.hospitals[0]
	var street: Vector2 = game.scenario.street_dir()
	game.sim.speed = 1.0
	# keep the others fed, so the only collapse is the one we cause
	for d in w.drones:
		d.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
	_stand(h.bay() + street * 7.0 + h.front * 1.0, h.pos)
	await _shot("01_medical_tent")

	var down: Drone = w.drones[4]
	down.pos = h.bay() + street * 16.0
	down.bars.hunger = 0.0
	await _frames(40)
	_stand(h.bay() + street * 7.0, down.pos)
	await _shot("02_collapsed")

	game.sim.speed = 1.0
	for i in 600:  # until the ambulance is close to them
		await process_frame
		if w.ambulances[0].job == Ambulance.Job.LOADING:
			break
	_stand(down.pos + street * -6.0 + h.front * 3.0, down.pos)
	await _shot("03_ambulance_arrives")

	game.sim.speed = 4.0
	for i in 1800:
		await process_frame
		if down.care == "patient":
			break
	game.sim.speed = 1.0
	await _frames(60)
	var side := Vector2(-h.front.y, h.front.x)
	_stand(h.pos + h.front * 4.0 - side * 3.5, h.pos)
	await _shot("04_patient_in_a_cot")

	# the hero
	w.player.bars.thirst = 0.0
	await _frames(40)
	await _shot("05_passing_out")
	game.sim.speed = 4.0
	for i in 3000:
		await process_frame
		if w.player.care == "patient":
			break
	await _frames(30)
	game.sim.speed = 1.0
	await _shot("06_on_the_cot")
	game.sim.speed = 6.0
	for i in 3000:
		await process_frame
		if w.player.care == "":
			break
	game.sim.speed = 1.0
	await _frames(90)
	await _shot("07_woken_up")
	quit(0)
