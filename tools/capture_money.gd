## Windowed screenshots of the money bars: a row of people with $0, $5, $40, $250 and $3,000, from a distance and up close
## on the target card. Needs a real window and GPU.
##   godot --path . --script tools/capture_money.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_money"
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var p: PlayerController = game.player
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = true
	# five drifters in a row in the middle of the street, with different amounts of money
	var dir: Vector2 = sc._frame.dir
	var base: Vector2 = sc.start + dir * 6.0
	var wallets := [0.0, 5.0, 40.0, 250.0, 3000.0]
	var people: Array[Drone] = []
	for i in wallets.size():
		var d := w.add_drifter(base + Vector2(-dir.y, dir.x) * (-4.0 + 2.0 * i), 0.0)
		d.wallet = wallets[i]
		d.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
		d.label = "$%d" % int(wallets[i])
		game.add_drone_view(d)
		people.append(d)
	await _frames(10)
	p.teleport(Vector3(sc.start.x, 0.1, sc.start.y), atan2(-dir.x, -dir.y))
	p.look_toward(Vector3(base.x, 2.2, base.y))
	await _frames(10)
	await _shot("1_across_the_street")
	var near := sc.start + dir * 3.5
	p.teleport(Vector3(near.x, 0.1, near.y), atan2(-dir.x, -dir.y))
	p.look_toward(Vector3(people[3].pos.x, 1.6, people[3].pos.y))
	await _frames(10)
	await _shot("2_the_target_card")
	quit(0)
