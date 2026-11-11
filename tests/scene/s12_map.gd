## Scene suite section: The map screen.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var esc_event := InputEventAction.new()
	esc_event.action = "release"
	esc_event.pressed = true

	# the map: M opens a flat picture of the district, north up, with the compass and where to go
	game.player.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), game.scenario.start_yaw)
	game.advance(0.2)
	var map_key := InputEventAction.new()
	map_key.action = "map"
	map_key.pressed = true
	game._unhandled_input(map_key)
	await tree.process_frame
	var mp: MapScreen = game.map_screen
	check(mp.visible and not game.player.controls_enabled, "M opens the map and takes the controls")
	var here: Vector2 = game.player.ground_pos()
	check(mp.to_screen(here).distance_to(mp._root.size * 0.5) < 1.0, "it opens centred on you")
	check(mp.to_screen(here + Vector2(0, -100)).y < mp.to_screen(here).y and mp.to_screen(here + Vector2(100, 0)).x > mp.to_screen(here).x, "north is up and east is to the right")
	check(mp._roads != null and mp._roads.get_surface_count() == 1 and mp._buildings.get_surface_count() == 1 and mp._names.size() > 10, "it has streets, buildings and street names (%d)" % mp._names.size())
	check(mp.landmarks.size() >= 4 and mp.landmarks.all(func(m): return m.label != "Mr. Nobody" and m.label != "Stranger"), "it shows the market, medical tent, food bank and bike shop, and not the stranger")
	var scale0: float = mp._scale
	mp._zoom(2.0, mp._root.size * 0.5)
	check(mp._scale > scale0 and mp.to_screen(here).distance_to(mp._root.size * 0.5) < 1.0, "zooming keeps what is under the cursor where it was")
	mp._center += Vector2(500, 0)
	mp._unhandled_input(InputEventKey.new())
	var c_key := InputEventKey.new()
	c_key.physical_keycode = KEY_C
	c_key.pressed = true
	mp._unhandled_input(c_key)
	check(mp._center.distance_to(here) < 0.5, "C brings you back to the middle")
	var objective: Variant = mp.objective.call()
	check(objective == null or objective is Vector2, "it knows where the tutorial wants you to go")
	await tree.process_frame
	game._unhandled_input(map_key)  # does nothing while it is already open
	mp._unhandled_input(map_key)
	check(not mp.visible and game.player.controls_enabled, "M again closes it and gives the controls back")
	game._unhandled_input(map_key)
	await tree.process_frame
	check(mp.visible, "and opens it again")
	game.screens._unhandled_input(esc_event)
	check(not mp.visible and game.player.controls_enabled, "Esc closes it too")
	game.dialogue.visible = true
	game._unhandled_input(map_key)
	check(not mp.visible, "but it won't open over a conversation")
	game.dialogue.visible = false

