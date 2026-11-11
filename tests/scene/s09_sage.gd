## Scene suite section: Mr. Nobody: noticing, the invitation, the conversation.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# Mr. Nobody: he notices the gun, walks over, and the conversation opens; Esc and farewell give everything back
	var sage: Drone = game.scenario.cast.sage
	var sage_out: Vector2 = game.scenario.sage_house.out
	var sage_view: DroneView = game.get_children().filter(func(c): return c is DroneView and c.drone == sage)[0]
	check(sage.kind == "sage" and sage_view.find_child("Emblem", true, false) != null, "Mr. Nobody has his red pin on his lapel")
	check(not sage_view._bars.visible and Geometry2D.is_point_in_polygon(sage.pos, game.scenario.sage_house.poly) == false and sage.pos.distance_to(game.scenario.sage_house.door) < 4.0, "he has no bars, and stands outside his door")
	game.dialogue.instant = true
	var far_from_sage: Vector2 = sage.pos + sage_out * 40.0
	game.player.teleport(Vector3(far_from_sage.x, 0.1, far_from_sage.y), 0.0)
	game.advance(1.0)
	check(not w.sage.approaching and not game.dialogue.visible, "far away, he doesn't stir")
	var near_sage: Vector2 = sage.pos + sage_out * 9.0
	game.player.teleport(Vector3(near_sage.x, 0.1, near_sage.y), 0.0)
	game.advance(1.0)
	check(w.sage.approaching, "within 12 m with the gun, he notices and sets out")
	game.advance(30.0)
	var house: Dictionary = game.scenario.sage_house
	check(Geometry2D.is_point_in_polygon(sage.pos, house.poly) and not game.dialogue.visible, "he goes in and waits inside for the hero to follow (he does not come out)")
	var guest: Vector2 = house.door + house.inward * 1.5
	game.player.teleport(Vector3(guest.x, 0.1, guest.y), atan2(-house.inward.x, -house.inward.y))
	game.advance(2.0)
	await tree.process_frame
	await tree.process_frame
	check(game.dialogue.visible and game.dialogue.mode == "read" and game.sim_paused and not game.player.controls_enabled and w.sage.talking, "once the hero has followed him in the conversation opens: the controls and the clock stop")
	check(game.dialogue._text.text.contains("Nobody") and game.dialogue.speaker == "Stranger", "and he introduces himself, still a \"Stranger\" on the label")
	var guard := 0
	while game.dialogue.mode == "read" and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(game.dialogue.mode == "menu" and w.sage.met and w.sage.told.has("who"), "reading the first meeting through gives you the list of things to ask (and makes you met)")
	check(game.dialogue.speaker == "Mr. Nobody" and sage.label == "Mr. Nobody", "and now we know his name")
	w.player.growth = Growth.new()
	game.dialogue.chosen.emit("gold")
	check(game.dialogue.mode == "menu" and not w.sage.told.has("gold"), "asking for a story that isn't open yet at your level just shows the list again")
	game.dialogue.chosen.emit("shell")
	check(game.dialogue.mode == "read" and w.sage.told.has("shell") and game.dialogue._text.text.contains("shell"), "asking about the shell starts that story")
	guard = 0
	while game.dialogue.mode == "read" and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(game.dialogue.mode == "menu", "and when it is over you are back at the list")
	var esc_event := InputEventAction.new()
	esc_event.action = "release"
	esc_event.pressed = true
	game.screens._unhandled_input(esc_event)
	check(not game.dialogue.visible and game.player.controls_enabled and not game.sim_paused and not w.sage.talking, "Esc closes it, and the controls and the clock come back")
	game.advance(60.0)
	check(sage.pos.distance_to(w.sage.home) < 0.8, "and he walks back to his door")
	var talk_spot: Vector2 = sage.pos + sage_out * 2.5
	game.player.teleport(Vector3(talk_spot.x, 0.1, talk_spot.y), atan2(sage_out.x, sage_out.y) + PI)
	game.player.look_toward(Vector3(sage.pos.x, 1.4, sage.pos.y))
	game.advance(0.3)
	await tree.physics_frame
	await tree.physics_frame
	check(game.interaction.aimed_sage(), "once you have met, aiming at him up close offers a chat (Q)")
	var chat_key := InputEventKey.new()
	chat_key.physical_keycode = KEY_Q
	chat_key.pressed = true
	game.interaction._unhandled_input(chat_key)
	check(game.dialogue.visible and game.dialogue.mode == "menu", "and Q opens the list again")
	game.dialogue.chosen.emit(DialogueScreen.FAREWELL)
	check(not game.dialogue.visible and game.player.controls_enabled and not game.sim_paused, "Farewell closes it just the same")

