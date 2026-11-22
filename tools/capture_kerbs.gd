## Windowed screenshots of the kerbs (Kerbs): the raised pavements and a junction, and a skateboard grinding a kerb in third
## person. On the story's Frankfurt, or with `key=` on a cached tile.
##   godot --path . --script tools/capture_kerbs.gd -- <out dir> [key=16/34347/22195]
extends CaptureTool

var key := ""


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	if key != "":
		var m: Array = TileKey.middle(key)
		game.landing = TileLanding.new(key, TileSource.district(key), m[0], m[1])


func _run() -> void:
	await _frames(20)
	var k: Kerbs = game.kerbs
	var near: Vector2 = game.landing.start
	var e := _longest(k, near, 120.0)
	var along: Vector2 = (e.b - e.a).normalized()
	var mid: Vector2 = (e.a + e.b) * 0.5
	# 1: standing on the road by the kerb, looking along it
	_stand(mid - e.side * 1.2 - along * 6.0, mid - e.side * 0.2 + along * 6.0, 1.0)
	await _shot("1_kerb_along", 10)
	# 2: a junction: the nearest kerb line's end, from above the road
	var j: Vector2 = e.b
	game.player.teleport(Vector3(j.x - along.x * 10.0 - e.side.x * 4.0, 0.1, j.y - along.y * 10.0 - e.side.y * 4.0), 0.0)
	game.player.look_toward(Vector3(j.x, 0.0, j.y))
	game.player.head.position.y = 3.2
	await _shot("2_junction", 10)
	game.player.head.position.y = 1.6
	# 3: a grind, third person: roll along the kerb, ollie, and catch it
	game.world.player.gear.add("skateboard", 1)
	var start: Vector2 = e.a + along * 2.0 - e.side * 0.35
	game.player.teleport(Vector3(start.x, 0.05, start.y), atan2(-along.x, -along.y))
	game.player.level_gaze()
	game.skate_controller.toggle()
	game.world.skating.speed = 9.0
	Input.action_press("move_forward")
	await _physics(6)
	Input.action_press("jump")
	await _physics(12)
	Input.action_release("jump")
	await _physics(90)
	print("grinding: ", game.world.skating.grinding, "  ", game.world.skating.last_trick)
	await _shot("3_grind", 1)
	Input.action_release("move_forward")
	# 4: off the end of it, looking back at the trail of bills
	while game.world.skating.grinding:
		await physics_frame
	await _physics(30)
	game.skate_controller.get_off()
	var trail: Array = game.world.bills.filter(func(b): return b.loose)
	if not trail.is_empty():
		var far: Vector2 = trail[0].pos
		game.player.look_toward(Vector3(far.x, 0.0, far.y))
	print("trail: %d bills, $%d picked up so far" % [trail.size(), int(game.world.ledger.player_cash)])
	await _shot("4_trail", 6)
	quit()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _longest(k: Kerbs, near: Vector2, within: float) -> Dictionary:
	var best := {}
	var longest := 0.0
	for e in k.edges:
		var l: float = e.a.distance_to(e.b)
		if l > longest and ((e.a + e.b) * 0.5).distance_to(near) < within:
			longest = l
			best = e
	return best
