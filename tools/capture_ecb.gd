## Windowed screenshots of the European Central Bank end of the letter quest: the doorman at the building's door, the
## building from down the street, and the dialogue. Needs a real window and GPU.
##   godot --path . --script tools/capture_ecb.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_ecb"
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


func _stand(at: Vector2, look_at: Vector2, eye := 1.5) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var out: Vector2 = sc.ecb.out
	var d: Drone = w.ecb_doorman
	game.sim_paused = true
	game.gun.set_enabled(false)
	_stand(d.pos + out * 4.0, d.pos)
	await _shot("doorman")
	_stand(d.pos + out * 60.0, d.pos - out * 20.0, 12.0)
	await _shot("building")
	w.quests.state[QuestBook.LETTER] = "active"
	w.player.carry.add("letter", 1)
	w.quests.set_flag("rode_bus")
	w.sage.tell(Stories.FIRST)
	_stand(d.pos + out * 2.5, d.pos)
	game.hud.visible = true
	game.interaction.talk_requested.emit(d)
	await _shot("dialogue")
	quit()
