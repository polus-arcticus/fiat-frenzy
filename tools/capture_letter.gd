## Windowed screenshots along the letter quest's way: tram 11 broken down at Börneplatz, Mr. Nobody's door, the stop for the
## bank and the gate across from it, the bank's market, and the golf cart's way from above.
##   godot --path . --script tools/capture_letter.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	game.gun.set_enabled(false)
	game.player.camera.far = 2500.0
	var sc: Scenario = game.scenario
	var w: World = game.world
	var tram := w.transit.vehicle(Scenario.TRAM_QUEST)
	await game.dev_stages.go("breakdown")
	await _frames(240)
	game.sim_paused = true
	game.hud.visible = false
	var dir := Vector2.from_angle(tram.heading)
	var south := dir.rotated(PI * 0.5)
	_stand(tram.pos - dir * 18.0 + south * 12.0, tram.pos, 3.0)
	await _shot("1_broken_down", 60)
	_stand(tram.pos + dir * 6.0 + south * 6.0, sc.sage_house.door, 2.0)
	await _shot("2_toward_mr_nobody", 40)
	game.sim_paused = false
	game.hud.visible = true
	await game.dev_stages.go("gate")
	await _frames(30)
	game.sim_paused = true
	var gate: Dictionary = sc.ecb_gate
	var at: Vector2 = game.player.ground_pos()
	_stand(at, gate.guard, 1.8)
	await _shot("3_off_at_the_banks_stop", 60)
	game.hud.visible = false
	var into: Vector2 = gate.into
	_stand((gate.guard as Vector2) - into * 14.0, gate.pad, 2.0)
	await _shot("4_the_gate", 40)
	_stand(sc.ecb_market.pos - sc.ecb_market.front.rotated(0.6) * -16.0, sc.ecb_market.pos, 1.5)
	await _shot("5_the_banks_market", 60)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 330.0
	cam.far = 2000.0
	cam.position = Vector3(2560, 600, -200)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	game.add_child(cam)
	cam.make_current()
	var way := PackedVector2Array([gate.pad]) + (gate.route as PackedVector2Array) + PackedVector2Array([gate.entrance])
	for k in way.size() - 1:  # (the cart's way, marked for the picture)
		var mid := (way[k] + way[k + 1]) * 0.5
		var leg := way[k + 1] - way[k]
		Look.box(game, Vector3(leg.length(), 0.3, 1.2), Vector3(mid.x, 2.0, mid.y), Color(0.9, 0.1, 0.1), Vector3(0, -leg.angle(), 0))
	await _shot("6_from_above", 40)
	quit()
