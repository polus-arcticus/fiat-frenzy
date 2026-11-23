## Windowed screenshots of the shuttle and bus service after the letter quest, in real time, from a camera overhead: the shuttle
## swinging round on the plaza by the bank's door and heading back to the gate, then the bus turning round at the bank's stop
## and pulling up at its stop on Kaiserstraße.
##   godot --path . --script tools/capture_service.gd -- <output dir>
extends SceneTree

var _cam: Camera3D
var _follow: VehicleView


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/.godot/captures/service"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game, out_dir)


func _shot(name: String, dir: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


## The camera hangs above whatever it follows, looking down at it, a little from behind.
func _process(_delta: float) -> bool:
	if _cam != null and _follow != null:
		var at := _follow.global_position
		var back := -_follow.global_basis.z
		_cam.global_position = at + Vector3(0, 30, 0) + back * 8.0
		_cam.look_at(at, Vector3(0, 0, -1) if absf(back.y) > 0.99 else Vector3.UP)
	return false


func _run(game: Node, dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	var sc: Scenario = game.scenario
	game.gun.set_enabled(false)
	w.player.make_needless()
	w.clock.time = 0.3 * Clock.DAY_SECONDS  # (by day)
	for f in ["rode_bus", "jam_cleared", "rode_on", "cleared_gate", "rode_shuttle", "delivered"]:
		w.quests.set_flag(f)
	w.quests.state[QuestBook.LETTER] = "done"
	var qc: QuestController = game.quest_controller
	# the shuttle at the door, as the first ride left it
	var plan: Dictionary = sc.ecb_gate
	var route: PackedVector2Array = plan.route
	w.shuttle.pos = plan.entrance
	w.shuttle.heading = ((plan.entrance as Vector2) - route[route.size() - 1]).angle()
	w.shuttle.prev_pos = w.shuttle.pos
	w.shuttle.prev_heading = w.shuttle.heading
	game.shuttle.place(w.shuttle.pos, VehicleView._yaw_of(w.shuttle.heading))
	# and the bus at the bank's stop, as the ride on left it
	w.bus.pos = sc.ecb_stop.bus
	w.bus.heading = ((sc.ecb_stop.bus as Vector2) - (sc.ecb_stop.via[0] as Vector2)).angle()
	w.bus.prev_pos = w.bus.pos
	w.bus.prev_heading = w.bus.heading
	w.bus.state = Bus.State.ARRIVED
	game.bus.place(w.bus.pos, VehicleView._yaw_of(w.bus.heading))
	_cam = Camera3D.new()
	_cam.fov = 60.0
	game.add_child(_cam)
	_cam.current = true

	_follow = game.shuttle
	var k: Vector3 = game.shuttle.kerb_point()
	game.player.teleport(Vector3(k.x, 0.1, k.z), 0.0)
	game.advance(0.3)
	await physics_frame
	await _shot("1_shuttle_at_the_door", dir)
	qc.shuttle_service()  # (real time: not awaited, so the shots can be taken during it)
	for t in [3.0, 1.5, 1.5, 1.5, 2.0]:
		await create_timer(t).timeout
		_cam.current = true
		await _shot("2_shuttle_turning_%.0f_m" % w.shuttle.s, dir)
	while w.shuttle.state == Bus.State.DRIVING:
		await create_timer(1.0).timeout
	await create_timer(4.0).timeout
	_cam.current = true
	await _shot("3_shuttle_back_at_the_gate", dir)

	_follow = game.bus
	k = game.bus.kerb_point()
	game.player.teleport(Vector3(k.x, 0.1, k.z), 0.0)
	game.advance(0.3)
	await physics_frame
	_cam.current = true
	await _shot("4_bus_at_the_bank", dir)
	qc.bus_service()
	for t in [3.5, 2.0, 2.0, 2.0, 3.0]:
		await create_timer(t).timeout
		_cam.current = true
		await _shot("5_bus_turning_%.0f_m" % w.bus.s, dir)
	while w.bus.state == Bus.State.DRIVING:
		await create_timer(1.0).timeout
	await create_timer(5.0).timeout
	_cam.current = true
	await _shot("6_bus_at_kaiserstrasse", dir)
	print("bus at %s, stop %s, width %.1f" % [w.bus.pos, sc.bus_stop.pos, sc.bus_stop.width])
	quit()
