## Scene suite section: first and third person (V).
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var p: PlayerController = game.player
	p.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), 0.0)  # out in the open street
	for i in 5:
		await tree.physics_frame
	check(not p.third_person and not p.body.visible and p.view_back() < 0.05, "the game begins in first person: no body drawn, camera at the eyes")
	p.set_third_person(true)
	for i in 40:
		await tree.physics_frame
	check(p.third_person and p.body.visible, "V puts the camera behind the hero, and the hero is drawn")
	check(p.view_back() > 2.5 and p.view_back() <= PlayerController.ARM_LENGTH + 0.05, "the camera hangs a few metres behind (%.2f m)" % p.view_back())
	check(game.gun.get_parent() == p.head, "the gun is held up in front of the hero's head")
	var wall_from := Vector3(game.scenario.start.x, 0.1, game.scenario.start.y)
	var open_back := p.view_back()
	p.set_third_person(false)
	for i in 40:
		await tree.physics_frame
	check(not p.third_person and not p.body.visible and p.view_back() < 0.1, "V again goes back to first person")
	check(game.gun.get_parent() == p.camera, "and the gun to the camera")
	# while moved by a script (or sitting on the bus) it is always first person, and returns when that ends
	p.set_third_person(true)
	p.scripted = true
	await tree.physics_frame
	check(not p.third_person, "moved by a script: first person, whatever was asked")
	p.scripted = false
	await tree.physics_frame
	check(p.third_person, "and third person again afterwards")
	p.set_third_person(false)
	for i in 30:
		await tree.physics_frame
	check(wall_from.y > 0.0 and open_back > 2.0, "(the open street gave the camera room)")
