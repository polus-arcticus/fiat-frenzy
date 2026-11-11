## Windowed screenshots of the whole bus ride, played for real (no shortcuts): the door opening, the hero walking in and
## sitting down, the bus on its way, the queue of cars at the jam, and stepping off. Needs a real window and GPU.
##   godot --path . --script tools/capture_ride.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_ride"
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
	game.gun.set_enabled(false)
	game.sim.speed = 6.0
	w.quests.state[QuestBook.LETTER] = "active"
	var stop: Vector2 = sc.bus_stop.pos
	var bus: BusView = game.bus
	# stand on the pavement by the door, looking at the bus
	var kerb := bus.kerb_point()
	game.player.teleport(Vector3(kerb.x, 0.1, kerb.z), 0.0)
	game.player.look_toward(bus.doorway_point() + Vector3(0, 1.0, 0))
	await _frames(5)
	game.quest_controller.ride()  # (not awaited: this tool watches it go)
	var t := 0.0
	var dest: Vector2 = sc.jam.bus.pos
	var asked_window := false
	while game.quest_controller.riding_the_bus and t < 240.0:
		await process_frame
		t += 1.0 / 60.0
		var state: int = w.bus.state
		if state == Bus.State.AT_STOP and t > 1.2:
			await _shot("1_door_open_walking_in")
		if game.player.is_seated() and state == Bus.State.AT_STOP:
			await _shot("2_seated_before_leaving")
		if state == Bus.State.DRIVING:
			var gone: float = w.bus.pos.distance_to(stop)
			var left: float = w.bus.pos.distance_to(dest)
			if gone > 120.0 and not asked_window:
				asked_window = true
				var bs := bus.to_global(Vector3(-6.0, 1.6, 2.0))  # out of the right-hand windows
				game.player.look_toward(bs)
			if gone > 120.0:
				await _shot("3_out_of_the_window")
			if left < 160.0:
				game.player.look_toward(bus.to_global(Vector3(0, 1.5, 12.0)))
				await _shot("4_the_queue_ahead")
			if left < 40.0:
				await _shot("5_nearly_there")
		if state == Bus.State.ARRIVED:
			await _shot("6_stopped_in_traffic")
	await _frames(10)
	game.hud.visible = true
	await _shot("7_standing_on_the_pavement")
	# and the bus from the side, in the jam
	var jam: Dictionary = sc.jam
	var look_at: Vector2 = jam.bus.pos
	game.player.teleport(Vector3(jam.arrival.x, 0.1, jam.arrival.y), 0.0)
	game.player.look_toward(Vector3(look_at.x, 2.0, look_at.y))
	await _frames(5)
	await _shot("8_the_bus_in_the_jam")
	quit(0)
