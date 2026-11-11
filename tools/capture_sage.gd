## Windowed screenshots of Mr. Nobody: his shield up close, his house from the street and inside, the first
## page of the conversation and the list of stories, and the ride's far marker. Needs a real window and GPU.
##   godot --path . --script tools/capture_sage.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_sage"
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


func _stand(at: Vector2, look_at: Vector2, eye := 1.3) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var sage: Drone = sc.cast.sage
	var house: Dictionary = sc.sage_house
	var out: Vector2 = house.out
	var inward: Vector2 = house.inward
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	sage.face_to = sage.pos + out * 20.0
	_stand(sage.pos + out * 3.2, sage.pos, 1.45)
	await _frames(40)
	await _shot("1_the_shield")
	sage.face_to = sage.pos + out * 20.0
	_stand(sage.pos + out * 3.0 + Vector2(-out.y, out.x) * 0.0, sage.pos, 1.45)
	_stand(house.door + out * 14.0, house.door, 2.0)
	await _shot("2_house_from_the_street")
	_stand(house.door + inward * 1.2, house.door + inward * 8.0, 1.4)
	await _shot("3_inside_looking_in")
	_stand(house.door + inward * 8.5 + Vector2(-inward.y, inward.x) * 2.0, house.door + inward * 5.0 + Vector2(-inward.y, inward.x) * 6.0, 1.3)
	await _shot("4_the_table_and_the_cases")
	game.hud.visible = true
	w.player.growth.add(Growth.total_for(8))
	_stand(sage.pos + out * 2.5, sage.pos, 1.5)
	game.dialogue.instant = true
	game.sage_controller._begin()
	await _frames(6)
	await _shot("5_the_first_words")
	while game.dialogue.mode == "read":
		game.dialogue.advance()
	await _frames(4)
	await _shot("6_what_to_ask")
	quit(0)
