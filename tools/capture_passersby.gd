## Windowed screenshots of the station's passersby over the morning rush: the square from the start and from above, a queue at
## the market, and the HUD's count.
##   godot --path . --script tools/capture_passersby.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	game.gun.set_enabled(false)
	var w: World = game.world
	var sc: Scenario = game.scenario
	w.player.make_needless()
	Cluster.fund(w, Zones.HOME)
	for k in 30:
		game.advance(1.0)
		await _frames(1)
	game.sim_paused = false
	_stand(sc.start, sc.market.pos + Vector2(8, 8), 1.8)
	await create_timer(6.0).timeout
	await _shot("1_from_the_start", 5)
	var lemonade: Machine = w.zones.machines_in(Zones.HOME).filter(func(m): return m.kind == "lemonade_stand")[0]
	_stand(lemonade.pos + lemonade.front * 9.0 + lemonade.front.orthogonal() * 7.0, lemonade.pos + lemonade.front * 2.0, 1.2)
	await create_timer(4.0).timeout
	await _shot("2_at_the_market", 5)
	for k in 6:  # a fan of bills in their way
		var b := w.gun.fire(1.0, "cash")
		w.gun.land(b, sc.market.pos + Vector2(-12 + k * 4.0, 6 - k * 1.5))
	await create_timer(3.0).timeout
	await _shot("3_after_the_money", 5)
	game.hud.visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 90.0
	cam.far = 2000.0
	cam.position = Vector3(-340, 600, 105)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	game.add_child(cam)
	cam.make_current()
	await _shot("4_from_above", 20)
	print("about: ", w.visitors.size(), " | ", Passersby.summary(w.passersby.served, w.passersby.lost))
	quit()
