## Scene suite section: the kerbs in the real game (Kerbs, CityBuilder, PlayerController's step-up, SkateController): the
## pavements are raised and solid, the hero walks up onto one and down off it, a board rolling into one stops dead, and an
## ollie onto a kerb line grinds it.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func _physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


func run() -> void:
	var w: World = game.world
	var k: Kerbs = game.kerbs
	check(k != null and k.pieces.size() > 1000 and k.edges.size() > 1000, "Frankfurt has its kerbs (%d pavement pieces, %d kerb lines)" % [k.pieces.size(), k.edges.size()])
	check(game.city.get_node_or_null("Pavements") != null, "drawn, as a layer of the city")
	check(Ground.kerbs == k, "and the views stand things on them")
	w.player.make_needless()
	# a long straight kerb line near the hero
	var e := {}
	var longest := 0.0
	for edge in k.edges:
		var l: float = edge.a.distance_to(edge.b)
		if l > longest and ((edge.a + edge.b) * 0.5).distance_to(w.player.pos) < 150.0:
			longest = l
			e = edge
	var along: Vector2 = (e.b - e.a).normalized()
	var mid: Vector2 = (e.a + e.b) * 0.5
	var road: Vector2 = mid - e.side * 1.5
	# walking: up onto the pavement
	game.player.teleport(Vector3(road.x, 0.05, road.y), atan2(-e.side.x, -e.side.y))
	await _physics(4)
	Input.action_press("move_forward")
	var highest := 0.0
	for i in 40:
		await tree.physics_frame
		highest = maxf(highest, game.player.global_position.y)
	Input.action_release("move_forward")
	var at := Vector2(game.player.global_position.x, game.player.global_position.z)
	check(at.distance_to(road) > 2.0 and absf(highest - Kerbs.HEIGHT) < 0.03, "the hero walks up the kerb onto the pavement (%.2f m up, %.1f m on)" % [highest, at.distance_to(road)])
	# the board: into the kerb, it stops
	w.player.gear.add("skateboard", 1)
	game.player.teleport(Vector3(road.x, 0.05, road.y), atan2(-e.side.x, -e.side.y))
	await _physics(4)
	game.skate_controller.toggle()
	w.skating.speed = 6.0
	Input.action_press("move_forward")
	await _physics(40)
	at = Vector2(game.player.global_position.x, game.player.global_position.z)
	check(k.height_at(at) == 0.0 and w.skating.speed < 1.0, "a board rolling into a kerb stops dead (ollie up it)")
	check(w.skating.bails >= 1, "and at that speed you bail")
	var t0 := Time.get_ticks_msec()
	while w.skating.bailing and Time.get_ticks_msec() - t0 < 5000:
		await tree.physics_frame
	check(not w.skating.bailing and game.player.body.rotation.z == 0.0, "then you're up again, on the board")
	# along it, an ollie: a grind
	var start: Vector2 = e.a + along * 2.0 - e.side * 0.35
	game.player.teleport(Vector3(start.x, 0.05, start.y), atan2(-along.x, -along.y))
	w.skating.speed = 9.0
	var printed := w.ledger.printed
	await _physics(4)
	Input.action_press("jump")
	await _physics(12)
	Input.action_release("jump")
	var ground := false
	for i in 90:
		await tree.physics_frame
		ground = ground or w.skating.grinding
	Input.action_release("move_forward")
	check(ground and w.skating.grinds >= 1, "rolling along a kerb, an ollie lands on its edge: a grind")
	check(w.ledger.printed - printed >= 3.0, "dropping bills as it goes ($%d)" % int(w.ledger.printed - printed))
	game.skate_controller.get_off()
	await _physics(4)
