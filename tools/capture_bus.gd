## Windowed screenshots of the bus at its stop and the traffic jam outside Mr. Nobody's house.
##   godot --path . --script tools/capture_bus.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_bus"
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


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _stand(at: Vector2, look_at: Vector2, eye := 1.6) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	game.sim_paused = true
	game.gun.set_enabled(false)
	var stop: Vector2 = sc.bus_stop.pos
	_stand(stop + Vector2(6, 9), stop, 2.0)
	await _shot("1_the_bus_stop")
	game.quest_controller.fast = true
	w.quests.state[QuestBook.LETTER] = "active"
	await game.quest_controller.ride()
	game.sim_paused = true
	var jam: Dictionary = sc.jam
	var door: Vector2 = sc.sage_house.door
	_stand(jam.arrival, door, 1.6)
	game.hud.visible = true
	await _shot("2_stepping_off")
	_stand(door + (sc.sage_house.out as Vector2) * 5.0 - (sc.sage_house.along as Vector2) * 14.0, jam.bus.pos, 3.0)
	await _shot("3_the_jam")
	quit(0)
