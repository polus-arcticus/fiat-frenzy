## Windowed screenshots of the second half of the letter quest: Mr. Nobody says farewell, the traffic jam drives off,
## the hero boards the bus again and rides on to the European Central Bank, and steps out at the gate. Needs a window.
##   godot --path . --script tools/capture_ride_on.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_ride_on"
var game: Node
var _shots := {}


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


func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var qc: QuestController = game.quest_controller
	game.gun.set_enabled(false)
	w.quests.state[QuestBook.LETTER] = "active"
	# the first ride, skipped through (it has its own capture tool)
	qc.fast = true
	game.player.teleport(Vector3(w.bus_stop.x, 0.1, w.bus_stop.y + 4.0), 0.0)
	await qc.ride()
	qc.fast = false
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	w.sage.tell(Stories.FIRST)
	# in the jam, looking along the queue
	game.sim.speed = 1.0
	var fwd: Vector2 = sc.jam.fwd
	var bus: BusView = game.bus
	game.player.look_toward(bus.to_global(Vector3(0, 1.5, 18.0)))
	game.hud.visible = true
	await _frames(10)
	await _shot("1_the_jam_before")
	w.quests.farewell_to_sage()
	await _frames(100)
	await _shot("2_the_cars_pull_away")
	await _frames(280)
	await _shot("3_the_street_clearing")
	game.sim.speed = 6.0
	var kerb := bus.kerb_point()
	game.player.teleport(Vector3(kerb.x, 0.1, kerb.z), 0.0)
	await _frames(5)
	print("can board: ", qc.can_board())
	qc.ride_on()
	var t := 0
	while qc.riding_the_bus and t < 6000:
		await process_frame
		t += 1
		if w.bus.state == Bus.State.DRIVING:
			var left: float = w.bus.pos.distance_to(sc.ecb_stop.bus)
			if left < 120.0:
				game.player.look_toward(bus.to_global(Vector3(0, 1.5, 12.0)))
				await _shot("4_the_gate_ahead")
		if w.bus.state == Bus.State.ARRIVED:
			await _shot("5_stopped_at_the_bank")
	await _frames(15)
	var d: Drone = w.ecb_doorman
	await _shot("6_out_on_the_street")
	game.player.look_toward(Vector3(d.pos.x, 1.4, d.pos.y))
	await _frames(10)
	await _shot("7_the_doorman")
	game.player.look_toward(Vector3(sc.ecb.door.x, 30.0, sc.ecb.door.y))
	await _frames(10)
	await _shot("8_the_bank")
	quit(0)
